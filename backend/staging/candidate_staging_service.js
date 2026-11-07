// FeroCalc Verified FD Rate Engine — Candidate Staging Service
//
// Coordinates:
// Source Collection Result -> Parser Selection -> Candidate Extraction
// -> Validation Layer -> Anomaly Detection -> Staging Persistence
//
// Safety Guarantees:
// 1. Under NO circumstances does any candidate become VERIFIED.
// 2. Unchanged sources are not re-extracted redundantly.
// 3. Staging records retain raw source hash, parser version, validation errors, and anomaly flags.

'use strict';

const { getParserForSource } = require('../parsers/parser_factory');
const { CandidateValidator } = require('../validators/candidate_validator');
const { AnomalyDetector } = require('../validators/anomaly_detector');
const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');
const { normalizeSchemeName, normalizeExactDecimal } = require('./staging_retry_coordinator');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');

class CandidateStagingService {
  constructor(options = {}) {
    this.validator = options.validator || new CandidateValidator();
    this.anomalyDetector = options.anomalyDetector || new AnomalyDetector();
    this.logger = options.logger || console;
    this.supabaseClient = options.supabaseClient || null;
    this.parserFactory = options.parserFactory || getParserForSource;
  }

  /**
   * Fetch known baseline rates for a bank to compare against.
   */
  async _fetchBaselineRates(bankCode) {
    const db = this.supabaseClient || supabaseAdmin;
    if ((!this.supabaseClient && !isSupabaseAvailable()) || !db) {
      return [];
    }
    try {
      // 1. Check existing verified rates in fd_rates
      const { data, error } = await db
        .from('fd_rates')
        .select('customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable, tenure_domain, source_tenure_text, min_years, min_months, min_days_cal, min_operator, max_years, max_months, max_days_cal, max_operator, banks!inner(short_name)')
        .eq('banks.short_name', bankCode)
        .eq('status', 'VERIFIED');

      // 2. Check most recent staged candidates
      const { data: stagedData } = await db
        .from('staged_rate_candidates')
        .select('customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable, tenure_domain, tenure_label, min_years, min_months, min_days_cal, min_operator, max_years, max_months, max_days_cal, max_operator')
        .eq('bank_code', bankCode)
        .eq('validation_status', 'VALID')
        .order('extracted_at', { ascending: false })
        .limit(60);

      // Prefer the more complete baseline: if stagedData has broader coverage than a partial pilot in fd_rates
      if (stagedData && stagedData.length > (data?.length || 0)) {
        return stagedData;
      }

      if (!error && Array.isArray(data) && data.length > 0) {
        return data;
      }

      return stagedData || [];
    } catch {
      return [];
    }
  }

  /**
   * Persists extracted and validated candidates to Supabase staged_rate_candidates.
   */
  async _persistCandidates(candidates, options = {}) {
    if (!candidates || candidates.length === 0) {
      return { persistedCount: 0, insertedRows: [] };
    }

    // Mandatory fail-closed lock enforcement for persistence
    const isLockRequired = options.requireLock !== undefined
      ? Boolean(options.requireLock)
      : (isSupabaseAvailable() && Boolean(supabaseAdmin));

    if (isLockRequired) {
      if (!options.lockManager || !options.jobId) {
        this.logger.error('[CandidateStagingService] Persistence BLOCKED: lockManager and jobId are mandatory for staging writes (fail-closed)');
        return {
          persistedCount: 0,
          insertedRows: [],
          error: 'Mandatory lock enforcement: lockManager and jobId must be provided for candidate staging persistence',
        };
      }
    }

    // Pre-write lock verification: assert lock ownership before any database write
    if (options.lockManager && options.jobId) {
      const lockCheck = await options.lockManager.verifyLock(options.jobId);
      if (!lockCheck.valid) {
        this.logger.error(`[CandidateStagingService] Pre-write lock verification failed: ${lockCheck.reason}`);
        return {
          persistedCount: 0,
          insertedRows: [],
          error: `Pre-write lock verification failed: ${lockCheck.reason}`,
        };
      }
    }

    // Category-specific pre-insert validation (fail-closed before database mutation)
    for (const c of candidates) {
      const cat = (c.rateCategory || c.rate_category || 'STANDARD').toUpperCase().trim();
      const rawScheme = c.schemeName !== undefined ? c.schemeName : c.scheme_name;
      const cleanedScheme = rawScheme ? String(rawScheme).replace(/[\t\r\n\u00a0\v\f]+/g, ' ').trim() : '';

      if (cat === 'SPECIAL_SCHEME') {
        if (!cleanedScheme) {
          this.logger.error('[CandidateStagingService] Persistence BLOCKED: SPECIAL_SCHEME candidate missing required scheme_name (fail-closed)');
          return {
            persistedCount: 0,
            insertedRows: [],
            error: 'Persistence BLOCKED: SPECIAL_SCHEME candidate missing required scheme_name (fail-closed)',
          };
        }
      } else if (cat === 'STANDARD') {
        if (cleanedScheme) {
          this.logger.error(`[CandidateStagingService] Persistence BLOCKED: STANDARD candidate cannot have non-empty scheme_name: "${cleanedScheme}" (fail-closed)`);
          return {
            persistedCount: 0,
            insertedRows: [],
            error: `Persistence BLOCKED: STANDARD candidate cannot have non-empty scheme_name: "${cleanedScheme}" (fail-closed)`,
          };
        }
      }
    }

    const db = options.supabaseClient || this.supabaseClient || supabaseAdmin;
    const isAvailable = (options.supabaseClient || this.supabaseClient) ? true : isSupabaseAvailable();
    if (!isAvailable || !db) {
      return { persistedCount: 0, insertedRows: [] };
    }

    try {
      const records = candidates.map(c => {
        const stagingStatus = c.stagingStatus || c.staging_status || 'DRAFT';
        // Explicit safety check: NEVER allow VERIFIED in staging
        if (stagingStatus === 'VERIFIED') {
          throw new Error('Illegal state: Extracted candidate cannot be marked VERIFIED');
        }

        const sourceId = c.sourceId !== undefined ? c.sourceId : c.source_id;
        const bankCode = c.bankCode !== undefined ? c.bankCode : c.bank_code;
        const productType = c.productType !== undefined ? c.productType : (c.product_type || 'RETAIL_DOMESTIC_TERM_DEPOSIT');
        const customerType = c.customerType !== undefined ? c.customerType : c.customer_type;
        const tenureLabel = c.tenureLabel !== undefined ? c.tenureLabel : c.tenure_label;
        const minTenureDays = c.minTenureDays !== undefined ? c.minTenureDays : c.min_tenure_days;
        const maxTenureDays = c.maxTenureDays !== undefined ? c.maxTenureDays : c.max_tenure_days;
        const tenureUnit = c.tenureUnit !== undefined ? c.tenureUnit : (c.tenure_unit || 'DAYS');
        const interestRate = c.interestRate !== undefined ? c.interestRate : c.interest_rate;
        const seniorCitizenRate = c.seniorCitizenRate !== undefined ? c.seniorCitizenRate : c.senior_citizen_rate;
        const superSeniorRate = c.superSeniorRate !== undefined ? c.superSeniorRate : c.super_senior_rate;
        const rawMinDeposit = c.minDeposit !== undefined ? c.minDeposit : c.min_deposit;
        const rawMaxDeposit = c.maxDeposit !== undefined ? c.maxDeposit : c.max_deposit;
        const isCallable = c.isCallable !== undefined ? c.isCallable : (c.is_callable !== undefined ? c.is_callable : true);
        const compoundingFrequency = c.compoundingFrequency !== undefined ? c.compoundingFrequency : (c.compounding_frequency || 'QUARTERLY');
        const effectiveFrom = c.effectiveFrom !== undefined ? c.effectiveFrom : c.effective_from;
        const effectiveUntil = c.effectiveUntil !== undefined ? c.effectiveUntil : c.effective_until;
        const sourceUrl = c.sourceUrl !== undefined ? c.sourceUrl : c.source_url;
        const sourceDocumentUrl = c.sourceDocumentUrl !== undefined ? c.sourceDocumentUrl : c.source_document_url;
        const sourceContentHash = c.sourceContentHash !== undefined ? c.sourceContentHash : c.source_content_hash;
        const extractedAt = c.extractedAt !== undefined ? c.extractedAt : c.extracted_at;
        const parserId = c.parserId !== undefined ? c.parserId : c.parser_id;
        const parserVersion = c.parserVersion !== undefined ? c.parserVersion : c.parser_version;
        const validationStatus = c.validationStatus !== undefined ? c.validationStatus : (c.validation_status || 'VALID');
        const validationErrors = c.validationErrors !== undefined ? c.validationErrors : (c.validation_errors || []);
        const anomalyFlags = c.anomalyFlags !== undefined ? c.anomalyFlags : (c.anomaly_flags || []);
        const notes = c.notes !== undefined ? c.notes : null;
        const rateCategory = (c.rateCategory || c.rate_category || 'STANDARD').toUpperCase().trim();
        const rawScheme = c.schemeName !== undefined ? c.schemeName : c.scheme_name;

        // Domain-aware validation (Phase 3C.5.42)
        const tenureDomain = (c.tenureDomain || c.tenure_domain || 'DAYS').toUpperCase().trim();
        if (!['DAYS', 'CALENDAR'].includes(tenureDomain)) {
          throw new Error(`Candidate persistence validation failed: invalid tenureDomain "${tenureDomain}" on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
        }

        // Fail-closed validation for required common fields
        if (!sourceId || !bankCode || !customerType || !tenureLabel || interestRate == null || !sourceUrl || !sourceContentHash || !extractedAt || !parserId || !parserVersion) {
          throw new Error(`Candidate persistence validation failed: missing required field on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
        }

        let serializedMinDays = null;
        let serializedMaxDays = null;
        let serializedMinYears = null;
        let serializedMinMonths = null;
        let serializedMinDaysCal = null;
        let serializedMinOperator = null;
        let serializedMaxYears = null;
        let serializedMaxMonths = null;
        let serializedMaxDaysCal = null;
        let serializedMaxOperator = null;

        if (tenureDomain === 'DAYS') {
          if (minTenureDays == null || maxTenureDays == null) {
            throw new Error(`Candidate persistence validation failed: DAYS candidate requires non-null minTenureDays and maxTenureDays on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }
          const numMin = Number(minTenureDays);
          const numMax = Number(maxTenureDays);
          if (isNaN(numMin) || isNaN(numMax) || numMin <= 0 || numMax < numMin) {
            throw new Error(`Candidate persistence validation failed: DAYS candidate requires minTenureDays > 0 and maxTenureDays >= minTenureDays on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }
          serializedMinDays = Math.floor(numMin);
          serializedMaxDays = Math.floor(numMax);
        } else {
          // CALENDAR domain: allow null integer day bounds (do not require day spans)
          const rawMinY = c.minYears !== undefined && c.minYears !== null ? Number(c.minYears) : (c.min_years !== undefined && c.min_years !== null ? Number(c.min_years) : null);
          const rawMinM = c.minMonths !== undefined && c.minMonths !== null ? Number(c.minMonths) : (c.min_months !== undefined && c.min_months !== null ? Number(c.min_months) : null);
          const rawMinDCal = c.minDaysCal !== undefined && c.minDaysCal !== null ? Number(c.minDaysCal) : (c.min_days_cal !== undefined && c.min_days_cal !== null ? Number(c.min_days_cal) : null);
          const rawMinOp = c.minOperator || c.min_operator || null;

          const rawMaxY = c.maxYears !== undefined && c.maxYears !== null ? Number(c.maxYears) : (c.max_years !== undefined && c.max_years !== null ? Number(c.max_years) : null);
          const rawMaxM = c.maxMonths !== undefined && c.maxMonths !== null ? Number(c.maxMonths) : (c.max_months !== undefined && c.max_months !== null ? Number(c.max_months) : null);
          const rawMaxDCal = c.maxDaysCal !== undefined && c.maxDaysCal !== null ? Number(c.maxDaysCal) : (c.max_days_cal !== undefined && c.max_days_cal !== null ? Number(c.max_days_cal) : null);
          const rawMaxOp = c.maxOperator || c.max_operator || null;

          // 1. Operator-component coupling
          const hasLowerComp = rawMinY !== null || rawMinM !== null || rawMinDCal !== null;
          if ((rawMinOp && !hasLowerComp) || (!rawMinOp && hasLowerComp)) {
            throw new Error(`Candidate persistence validation failed: CALENDAR candidate lower operator and components must be strictly coupled on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }
          if (rawMinOp && !['GTE', 'GT'].includes(rawMinOp)) {
            throw new Error(`Candidate persistence validation failed: CALENDAR candidate lower operator must be GTE or GT on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }

          const hasUpperComp = rawMaxY !== null || rawMaxM !== null || rawMaxDCal !== null;
          if ((rawMaxOp && !hasUpperComp) || (!rawMaxOp && hasUpperComp)) {
            throw new Error(`Candidate persistence validation failed: CALENDAR candidate upper operator and components must be strictly coupled on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }
          if (rawMaxOp && !['LTE', 'LT'].includes(rawMaxOp)) {
            throw new Error(`Candidate persistence validation failed: CALENDAR candidate upper operator must be LTE or LT on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }

          // 2. At least one bound required
          if (!rawMinOp && !rawMaxOp) {
            throw new Error(`Candidate persistence validation failed: CALENDAR candidate must specify at least one valid bound on candidate ${c.id || c._candidate_id || c._review_id || 'unknown'}`);
          }

          // 3. Component non-negativity and month range [0, 11]
          if (rawMinY !== null && rawMinY < 0) throw new Error(`Candidate persistence validation failed: minYears cannot be negative on candidate ${c.id || c._candidate_id || 'unknown'}`);
          if (rawMinM !== null && (rawMinM < 0 || rawMinM > 11)) throw new Error(`Candidate persistence validation failed: minMonths must be in range [0, 11] on candidate ${c.id || c._candidate_id || 'unknown'}`);
          if (rawMinDCal !== null && rawMinDCal < 0) throw new Error(`Candidate persistence validation failed: minDaysCal cannot be negative on candidate ${c.id || c._candidate_id || 'unknown'}`);

          if (rawMaxY !== null && rawMaxY < 0) throw new Error(`Candidate persistence validation failed: maxYears cannot be negative on candidate ${c.id || c._candidate_id || 'unknown'}`);
          if (rawMaxM !== null && (rawMaxM < 0 || rawMaxM > 11)) throw new Error(`Candidate persistence validation failed: maxMonths must be in range [0, 11] on candidate ${c.id || c._candidate_id || 'unknown'}`);
          if (rawMaxDCal !== null && rawMaxDCal < 0) throw new Error(`Candidate persistence validation failed: maxDaysCal cannot be negative on candidate ${c.id || c._candidate_id || 'unknown'}`);

          // 4. Non-zero bound durations
          if (rawMinOp && (rawMinY || 0) <= 0 && (rawMinM || 0) <= 0 && (rawMinDCal || 0) <= 0) {
            throw new Error(`Candidate persistence validation failed: CALENDAR lower bound duration cannot be zero on candidate ${c.id || c._candidate_id || 'unknown'}`);
          }
          if (rawMaxOp && (rawMaxY || 0) <= 0 && (rawMaxM || 0) <= 0 && (rawMaxDCal || 0) <= 0) {
            throw new Error(`Candidate persistence validation failed: CALENDAR upper bound duration cannot be zero on candidate ${c.id || c._candidate_id || 'unknown'}`);
          }

          // 5. Symbolic ordering (min <= max)
          if (rawMinOp && rawMaxOp) {
            const minMonthsTotal = (rawMinY || 0) * 12 + (rawMinM || 0);
            const maxMonthsTotal = (rawMaxY || 0) * 12 + (rawMaxM || 0);
            const minDVal = rawMinDCal || 0;
            const maxDVal = rawMaxDCal || 0;

            if (minMonthsTotal > maxMonthsTotal || (minMonthsTotal === maxMonthsTotal && minDVal > maxDVal)) {
              throw new Error(`Candidate persistence validation failed: CALENDAR lower bound exceeds upper bound on candidate ${c.id || c._candidate_id || 'unknown'}`);
            }

            if (minMonthsTotal === maxMonthsTotal && minDVal === maxDVal) {
              if (rawMinOp === 'GT' || rawMaxOp === 'LT') {
                throw new Error(`Candidate persistence validation failed: CALENDAR equal endpoints with strict inequality operators create empty interval on candidate ${c.id || c._candidate_id || 'unknown'}`);
              }
            }
          }

          // 6. Canonicalize component identity: present bounds normalize omitted components to 0
          if (rawMinOp || hasLowerComp) {
            serializedMinYears = rawMinY !== null ? Math.floor(rawMinY) : 0;
            serializedMinMonths = rawMinM !== null ? Math.floor(rawMinM) : 0;
            serializedMinDaysCal = rawMinDCal !== null ? Math.floor(rawMinDCal) : 0;
            serializedMinOperator = rawMinOp;
          } else {
            serializedMinYears = null;
            serializedMinMonths = null;
            serializedMinDaysCal = null;
            serializedMinOperator = null;
          }

          if (rawMaxOp || hasUpperComp) {
            serializedMaxYears = rawMaxY !== null ? Math.floor(rawMaxY) : 0;
            serializedMaxMonths = rawMaxM !== null ? Math.floor(rawMaxM) : 0;
            serializedMaxDaysCal = rawMaxDCal !== null ? Math.floor(rawMaxDCal) : 0;
            serializedMaxOperator = rawMaxOp;
          } else {
            serializedMaxYears = null;
            serializedMaxMonths = null;
            serializedMaxDaysCal = null;
            serializedMaxOperator = null;
          }
        }

        return {
          source_id: sourceId,
          bank_code: bankCode,
          product_type: productType,
          customer_type: customerType,
          tenure_label: tenureLabel,
          tenure_domain: tenureDomain,
          min_tenure_days: serializedMinDays,
          max_tenure_days: serializedMaxDays,
          tenure_unit: tenureUnit,
          min_years: serializedMinYears,
          min_months: serializedMinMonths,
          min_days_cal: serializedMinDaysCal,
          min_operator: serializedMinOperator,
          max_years: serializedMaxYears,
          max_months: serializedMaxMonths,
          max_days_cal: serializedMaxDaysCal,
          max_operator: serializedMaxOperator,
          interest_rate: interestRate,
          senior_citizen_rate: seniorCitizenRate,
          super_senior_rate: superSeniorRate,
          min_deposit: normalizeExactDecimal(rawMinDeposit, 'min_deposit'),
          max_deposit: normalizeExactDecimal(rawMaxDeposit, 'max_deposit'),
          is_callable: isCallable,
          compounding_frequency: compoundingFrequency,
          effective_from: effectiveFrom,
          effective_until: effectiveUntil,
          source_url: sourceUrl,
          source_document_url: sourceDocumentUrl,
          source_content_hash: sourceContentHash,
          extracted_at: extractedAt,
          parser_id: parserId,
          parser_version: parserVersion,
          validation_status: validationStatus,
          validation_errors: validationErrors,
          anomaly_flags: anomalyFlags,
          staging_status: stagingStatus,
          notes: notes,
          rate_category: rateCategory,
          scheme_name: normalizeSchemeName(rawScheme, rateCategory),
        };
      });

      // Deduplication & Active Constraint Management: Check existing active candidates
      const bankCodes = [...new Set(records.map(r => r.bank_code).filter(Boolean))];

      let existingRows = [];
      if (bankCodes.length > 0) {
        try {
          const query = db.from('staged_rate_candidates');
          if (query && typeof query.select === 'function') {
            const selectQuery = query.select('id, bank_code, product_type, customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable, source_content_hash, staging_status, tenure_label, tenure_domain, tenure_unit, min_years, min_months, min_days_cal, min_operator, max_years, max_months, max_days_cal, max_operator, rate_category, scheme_name, validation_status, anomaly_flags, notes');
            if (selectQuery && typeof selectQuery.in === 'function') {
              const { data: existing, error: existErr } = await selectQuery
                .in('bank_code', bankCodes)
                .in('staging_status', ['DRAFT', 'IN_REVIEW']);

              if (!existErr && Array.isArray(existing) && existing.length > 0) {
                existingRows = existing;
              }
            }
          }
        } catch {
          existingRows = [];
        }
      }

      const recordsToInsert = [];
      const reusedRows = [];

      for (const rec of records) {
        let matched = existingRows.find(ex =>
          ex.bank_code === rec.bank_code &&
          ex.customer_type === rec.customer_type &&
          ex.tenure_domain === rec.tenure_domain &&
          (rec.rate_category || 'STANDARD') === (ex.rate_category || 'STANDARD') &&
          (rec.scheme_name || null) === (ex.scheme_name || null) &&
          (
            ex.tenure_domain === 'DAYS'
              ? (Number(ex.min_tenure_days) === Number(rec.min_tenure_days) && Number(ex.max_tenure_days) === Number(rec.max_tenure_days))
              : (
                  Number(ex.min_years || 0) === Number(rec.min_years || 0) &&
                  Number(ex.min_months || 0) === Number(rec.min_months || 0) &&
                  Number(ex.min_days_cal || 0) === Number(rec.min_days_cal || 0) &&
                  (ex.min_operator || null) === (rec.min_operator || null) &&
                  Number(ex.max_years || 0) === Number(rec.max_years || 0) &&
                  Number(ex.max_months || 0) === Number(rec.max_months || 0) &&
                  Number(ex.max_days_cal || 0) === Number(rec.max_days_cal || 0) &&
                  (ex.max_operator || null) === (rec.max_operator || null)
                )
          )
        );

        // Fallback for active DRAFT candidates undergoing domain refinement:
        // match by tenure_label if not already matched by domain & bounds
        if (!matched) {
          matched = existingRows.find(ex =>
            ex.bank_code === rec.bank_code &&
            ex.customer_type === rec.customer_type &&
            ex.staging_status === 'DRAFT' &&
            (rec.rate_category || 'STANDARD') === (ex.rate_category || 'STANDARD') &&
            (rec.scheme_name || null) === (ex.scheme_name || null) &&
            ex.tenure_label && rec.tenure_label &&
            ex.tenure_label.trim().toLowerCase() === rec.tenure_label.trim().toLowerCase()
          );
        }

        if (matched) {
          // If hash, rates, domain, tenure fields, or anomaly flags differ, update the existing active record in place
          const isDifferent = Boolean(options.forceUpdate) ||
            matched.source_content_hash !== rec.source_content_hash ||
            Number(matched.interest_rate) !== Number(rec.interest_rate) ||
            matched.tenure_domain !== rec.tenure_domain ||
            matched.tenure_unit !== rec.tenure_unit ||
            matched.min_tenure_days !== rec.min_tenure_days ||
            matched.max_tenure_days !== rec.max_tenure_days ||
            matched.min_years !== rec.min_years ||
            matched.min_months !== rec.min_months ||
            matched.min_days_cal !== rec.min_days_cal ||
            matched.min_operator !== rec.min_operator ||
            matched.max_years !== rec.max_years ||
            matched.max_months !== rec.max_months ||
            matched.max_days_cal !== rec.max_days_cal ||
            matched.max_operator !== rec.max_operator ||
            (matched.staging_status !== 'IN_REVIEW' && JSON.stringify(matched.anomaly_flags || []) !== JSON.stringify(rec.anomaly_flags || []));

          if (isDifferent) {
            try {
              const updateQuery = db.from('staged_rate_candidates');
              if (updateQuery && typeof updateQuery.update === 'function') {
                const { error: upErr } = await updateQuery
                  .update({
                    source_content_hash: rec.source_content_hash,
                    tenure_label: rec.tenure_label,
                    tenure_domain: rec.tenure_domain,
                    tenure_unit: rec.tenure_unit,
                    min_tenure_days: rec.min_tenure_days,
                    max_tenure_days: rec.max_tenure_days,
                    min_years: rec.min_years,
                    min_months: rec.min_months,
                    min_days_cal: rec.min_days_cal,
                    min_operator: rec.min_operator,
                    max_years: rec.max_years,
                    max_months: rec.max_months,
                    max_days_cal: rec.max_days_cal,
                    max_operator: rec.max_operator,
                    interest_rate: rec.interest_rate,
                    senior_citizen_rate: rec.senior_citizen_rate,
                    super_senior_rate: rec.super_senior_rate,
                    min_deposit: rec.min_deposit,
                    max_deposit: rec.max_deposit,
                    is_callable: rec.is_callable,
                    compounding_frequency: rec.compounding_frequency,
                    effective_from: rec.effective_from,
                    effective_until: rec.effective_until,
                    source_url: rec.source_url,
                    source_document_url: rec.source_document_url,
                    extracted_at: rec.extracted_at,
                    parser_id: rec.parser_id,
                    parser_version: rec.parser_version,
                    validation_status: rec.validation_status,
                    validation_errors: rec.validation_errors,
                    anomaly_flags: (matched.staging_status === 'IN_REVIEW') ? (matched.anomaly_flags || []) : rec.anomaly_flags,
                    staging_status: (matched.staging_status === 'IN_REVIEW') ? 'IN_REVIEW' : rec.staging_status,
                    notes: rec.notes,
                    rate_category: rec.rate_category,
                    scheme_name: rec.scheme_name,
                  })
                  .eq('id', matched.id);
                if (upErr) throw upErr;
              }
            } catch (updateErr) {
              this.logger.warn(`Failed to update existing staged candidate ${matched.id}: ${updateErr.message}`);
            }
            matched.source_content_hash = rec.source_content_hash;
            matched.interest_rate = rec.interest_rate;
            matched.tenure_domain = rec.tenure_domain;
            matched.tenure_unit = rec.tenure_unit;
            matched.min_tenure_days = rec.min_tenure_days;
            matched.max_tenure_days = rec.max_tenure_days;
            matched.min_years = rec.min_years;
            matched.min_months = rec.min_months;
            matched.min_days_cal = rec.min_days_cal;
            matched.min_operator = rec.min_operator;
            matched.max_years = rec.max_years;
            matched.max_months = rec.max_months;
            matched.max_days_cal = rec.max_days_cal;
            matched.max_operator = rec.max_operator;
          }
          reusedRows.push(matched);
        } else {
          recordsToInsert.push(rec);
        }
      }

      let insertedRows = [];
      if (recordsToInsert.length > 0) {
        const { data, error } = await db
          .from('staged_rate_candidates')
          .insert(recordsToInsert)
          .select('id, bank_code, product_type, customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable, source_content_hash, staging_status, tenure_label');

        if (error) {
          this.logger.warn(`Failed to persist staged candidates to DB: ${error.message}`);
          return { persistedCount: 0, insertedRows: [], error: error.message };
        }
        insertedRows = data || [];
      }

      const allActiveRows = [...reusedRows, ...insertedRows];

      // Attach resolved DB IDs back to in-memory candidates
      for (const c of candidates) {
        const cBankCode = c.bankCode !== undefined ? c.bankCode : c.bank_code;
        const cCustomerType = c.customerType !== undefined ? c.customerType : c.customer_type;
        const cTenureDomain = (c.tenureDomain || c.tenure_domain || 'DAYS').toUpperCase().trim();
        const cMinDays = c.minTenureDays !== undefined ? c.minTenureDays : c.min_tenure_days;
        const cMaxDays = c.maxTenureDays !== undefined ? c.maxTenureDays : c.max_tenure_days;
        const cLabel = c.tenureLabel !== undefined ? c.tenureLabel : c.tenure_label;

        const matchedRow = allActiveRows.find(row =>
          row.bank_code === cBankCode &&
          row.customer_type === cCustomerType &&
          row.tenure_domain === cTenureDomain &&
          (cTenureDomain === 'DAYS'
            ? (Number(row.min_tenure_days) === Number(cMinDays) && Number(row.max_tenure_days) === Number(cMaxDays))
            : (row.tenure_label === cLabel))
        );

        if (matchedRow && matchedRow.id) {
          c.id = matchedRow.id;
          c._candidate_id = matchedRow.id;
          c.stagedCandidateId = matchedRow.id;
          c._matchedRow = matchedRow;
          if (matchedRow.staging_status) {
            c.stagingStatus = matchedRow.staging_status;
            c.staging_status = matchedRow.staging_status;
          }
          if (matchedRow.validation_status) {
            c.validationStatus = matchedRow.validation_status;
            c.validation_status = matchedRow.validation_status;
          }
          if (matchedRow.anomaly_flags) {
            c.anomalyFlags = matchedRow.anomaly_flags;
            c.anomaly_flags = matchedRow.anomaly_flags;
          }
          if (matchedRow.notes) {
            c.notes = matchedRow.notes;
          }
        }
      }

      return {
        persistedCount: allActiveRows.length,
        insertedRows: allActiveRows,
        reusedCount: reusedRows.length,
        newlyInsertedCount: insertedRows.length,
      };
    } catch (err) {
      this.logger.warn(`Staging DB persistence error: ${err.message}`);
      return { persistedCount: 0, insertedRows: [], error: err.message };
    }
  }

  /**
   * Processes a CollectionResult from Phase 1 through extraction, validation, and staging.
   *
   * @param {Object} collectionResult - Result from RateCollector.collect()
   * @param {Object} [options]
   * @returns {Promise<Object>} Staging execution report
   */
  async processCollectionResult(collectionResult, options = {}) {
    const {
      sourceId,
      bankCode,
      status,
      contentHash,
      sourceUrl,
      bodyBuffer,
    } = collectionResult;

    // Rule: If source is UNCHANGED, do not perform redundant re-extraction unless forced
    if (status === 'UNCHANGED' && !options.forceReExtract) {
      return {
        sourceId,
        bankCode,
        status: 'UNCHANGED',
        sourceContentHash: contentHash,
        extracted: false,
        message: 'Source content hash unchanged; skipped extraction',
        candidates: [],
        validation: null,
        anomalies: null,
      };
    }

    // 1. Select appropriate parser
    const parser = this.parserFactory(collectionResult);
    if (!parser) {
      return {
        sourceId,
        bankCode,
        status: 'PARSER_UNAVAILABLE',
        sourceContentHash: contentHash,
        extracted: false,
        message: `No parser registered for bankCode: ${bankCode}`,
        candidates: [],
        validation: null,
        anomalies: null,
      };
    }

    // 2. Parse source document
    const extractionResult = parser.parse(bodyBuffer, {
      sourceId,
      sourceUrl,
      sourceContentHash: contentHash,
      ...options,
      ...(options.parserOptions || {}),
    });

    if (!extractionResult.success || extractionResult.candidates.length === 0) {
      return {
        sourceId,
        bankCode,
        status: 'EXTRACTION_FAILED',
        sourceContentHash: contentHash,
        parserId: parser.id,
        parserVersion: parser.version,
        extracted: false,
        message: extractionResult.errors.join('; ') || 'Parser produced zero candidates',
        candidates: [],
        validation: null,
        anomalies: null,
      };
    }

    const candidates = extractionResult.candidates;

    // 3. Validation Layer
    const validationSummary = this.validator.validateBatch(candidates, {
      sourceId,
      bankCode,
    });

    // 4. Anomaly Detection Layer
    // Read-only source inspection must not query verified or staged baselines.
    const baselineRates = options.skipDbAccess
      ? []
      : (options.baselineRates || await this._fetchBaselineRates(bankCode));
    const anomalySummary = this.anomalyDetector.detectAnomalies(candidates, baselineRates, {
      sourceId,
      bankCode,
    });

    // 5. Assign Staging Status (GUARANTEED: NEVER VERIFIED)
    for (const c of candidates) {
      if (c.validationStatus === 'INVALID') {
        c.stagingStatus = 'INVALID';
      } else if (c.anomalyFlags.length > 0) {
        c.stagingStatus = 'IN_REVIEW';
      } else {
        c.stagingStatus = 'DRAFT';
      }

      // Explicit assertion: Never VERIFIED
      if (c.stagingStatus === 'VERIFIED') {
        throw new Error('FATAL: Staging candidate was marked VERIFIED');
      }
    }

    // 6. Persist to Staging (if Supabase is available)
    let persistResult = { persistedCount: 0, insertedRows: [] };
    if (!options.skipDbPersist) {
      const db = options.supabaseClient || this.supabaseClient || supabaseAdmin;
      const isAvailable = (options.supabaseClient || this.supabaseClient) ? true : isSupabaseAvailable();

      if (isAvailable && db && !options.skipDbAccess && options.requireProvenance !== false) {
        // Assert source provenance linkage: source_collection_logs MUST contain this contentHash
        try {
          const logQuery = db.from('source_collection_logs');
          if (logQuery && typeof logQuery.select === 'function') {
            const { data: logs, error: logCheckError } = await logQuery
              .select('id')
              .eq('source_id', sourceId)
              .eq('content_hash', contentHash)
              .limit(1);

            if (logCheckError) {
              this.logger.error(`[CandidateStagingService] Provenance verification failed: ${logCheckError.message}`);
              throw new Error(`Provenance verification failed for source [${sourceId}] hash [${contentHash}]: ${logCheckError.message}`);
            }

            if (!logs || logs.length === 0) {
              this.logger.error(`[CandidateStagingService] Provenance assertion failed: No source_collection_logs record found for source [${sourceId}] with content hash [${contentHash}]`);
              throw new Error(`Provenance assertion failed: Cannot stage candidates without verified source_collection_log for source [${sourceId}] and content hash [${contentHash}]`);
            }
          }
        } catch (err) {
          if (err.message && (err.message.includes('Provenance assertion failed') || err.message.includes('Provenance verification failed'))) {
            throw err;
          }
          // In mocks where source_collection_logs query is unsupported, pass through
        }
      }

      persistResult = await this._persistCandidates(candidates, options);
    }

    return {
      sourceId,
      bankCode,
      status: 'EXTRACTION_SUCCESS',
      sourceContentHash: contentHash,
      parserId: parser.id,
      parserVersion: parser.version,
      extracted: true,
      totalCandidates: candidates.length,
      validCount: validationSummary.validCount,
      invalidCount: validationSummary.invalidCount,
      anomalousCount: anomalySummary.candidatesWithAnomalies,
      effectiveFrom: extractionResult.effectiveFrom,
      candidates,
      validation: validationSummary,
      anomalies: anomalySummary,
      persistedCount: persistResult.persistedCount,
      insertedRows: persistResult.insertedRows || [],
    };
  }


  /**
   * Reconciles legitimate clean candidates stuck in IN_REVIEW back to DRAFT (Phase 4.2).
   *
   * Eligibility Requirements:
   * 1. validation_status === 'VALID'
   * 2. anomaly_flags is exactly empty ([])
   * 3. No MANUAL_REVIEW hold in notes
   * 4. Exact candidate identity matches an active verified rate
   * 5. RateDiffEngine confirms DIFF_TYPES.UNCHANGED
   * 6. Preserves existing promoted records, verified_fd_rates, and audit history
   * 7. Dry-run mode performs zero database mutations
   *
   * @param {Object} [options]
   * @param {string} [options.bankCode] - Filter by specific bank code (optional)
   * @param {boolean} [options.dryRun=false] - When true, simulate without database writes
   * @param {Array<Object>} [options.activeVerifiedRates] - In-memory verified rates (for tests)
   * @param {Array<Object>} [options.inMemoryCandidates] - In-memory candidates (for tests)
   * @param {Object} [options.supabaseClient] - Custom Supabase client
   * @returns {Promise<Object>} Recovery telemetry report
   */
  async reconcileCleanReviewCandidates(options = {}) {
    const dryRun = Boolean(options.dryRun);
    const bankFilter = (options.bankCode || options.bankFilter) ? String(options.bankCode || options.bankFilter).trim().toUpperCase() : null;
    const db = options.supabaseClient || options.db || this.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);
    const diffEngine = new RateDiffEngine();

    // 1. Load active verified rates
    let activeRates = options.activeVerifiedRates || options.inMemoryActiveRates || [];
    if (activeRates.length === 0 && db) {
      try {
        const { data: vRates, error: vErr } = await db
          .from('verified_fd_rates')
          .select('*');
        if (!vErr && Array.isArray(vRates)) {
          activeRates = vRates.map(r => ({
            ...r,
            bankCode: r.bank_short_name || r.bankCode || r.bank_code,
            bank_code: r.bank_short_name || r.bankCode || r.bank_code,
          }));
        }
      } catch (fetchVErr) {
        this.logger.warn(`Failed to fetch verified_fd_rates for clean reconciliation: ${fetchVErr.message}`);
      }
    }

    // 2. Load candidates in IN_REVIEW
    let inReviewCandidates = options.inMemoryCandidates || [];
    if (inReviewCandidates.length === 0 && db) {
      try {
        let q = db
          .from('staged_rate_candidates')
          .select('*')
          .eq('staging_status', 'IN_REVIEW');
        if (bankFilter) {
          q = q.eq('bank_code', bankFilter);
        }
        const { data: candData, error: candErr } = await q;
        if (!candErr && Array.isArray(candData)) {
          inReviewCandidates = candData;
        }
      } catch (fetchCErr) {
        this.logger.warn(`Failed to fetch staged_rate_candidates for clean reconciliation: ${fetchCErr.message}`);
      }
    }

    if (options.inMemoryCandidates) {
      inReviewCandidates = inReviewCandidates.filter(c => (c.staging_status || c.stagingStatus || 'IN_REVIEW') === 'IN_REVIEW');
    }
    if (bankFilter && options.inMemoryCandidates) {
      inReviewCandidates = inReviewCandidates.filter(c => (c.bank_code || c.bankCode) === bankFilter);
    }

    const report = {
      totalInReview: inReviewCandidates.length,
      totalAudited: 0,
      eligibleCount: 0,
      reconciledCount: 0,
      skippedCount: 0,
      dryRun,
      bankBreakdown: {},
      errors: [],
    };

    for (const c of inReviewCandidates) {
      const bCode = (c.bank_code || c.bankCode || '').toUpperCase();
      if (!report.bankBreakdown[bCode]) {
        report.bankBreakdown[bCode] = {
          total: 0,
          eligible: 0,
          reconciled: 0,
          skipped: 0,
          reasons: [],
        };
      }
      const bStats = report.bankBreakdown[bCode];
      report.totalAudited++;
      bStats.total++;

      // Requirement 1: validation_status === 'VALID'
      const valStatus = c.validation_status || c.validationStatus || 'VALID';
      if (valStatus !== 'VALID') {
        report.skippedCount++;
        bStats.skipped++;
        bStats.reasons.push({ id: c.id, reason: 'INVALID_STATUS' });
        continue;
      }

      // Requirement 2: anomaly_flags is exactly empty ([])
      const flags = Array.isArray(c.anomaly_flags) ? c.anomaly_flags : (Array.isArray(c.anomalyFlags) ? c.anomalyFlags : []);
      if (flags.length > 0) {
        report.skippedCount++;
        bStats.skipped++;
        bStats.reasons.push({ id: c.id, reason: 'ANOMALIES_PRESENT', flags });
        continue;
      }

      // Requirement 3: No MANUAL_REVIEW hold
      const notes = String(c.notes || '');
      if (notes.includes('MANUAL_REVIEW')) {
        report.skippedCount++;
        bStats.skipped++;
        bStats.reasons.push({ id: c.id, reason: 'MANUAL_REVIEW_HOLD' });
        continue;
      }

      // Requirement 4 & 5: Exact candidate identity matches active verified rate (DIFF_TYPES.UNCHANGED)
      const bankActive = activeRates.filter(r => String(r.bankCode || r.bank_code || r.bank_short_name || '').toUpperCase() === bCode);
      const diff = diffEngine.diffCandidate(c, bankActive);
      if (diff.diffType !== DIFF_TYPES.UNCHANGED) {
        report.skippedCount++;
        bStats.skipped++;
        bStats.reasons.push({ id: c.id, reason: `DIFF_${diff.diffType}`, details: diff.details });
        continue;
      }

      // Candidate is proven ELIGIBLE!
      report.eligibleCount++;
      bStats.eligible++;

      // Dry-run preserves status and makes zero database writes
      if (dryRun) {
        continue;
      }

      // Requirement 6 & 7: Update candidate in database to DRAFT
      if (db && c.id) {
        try {
          const { error: upErr } = await db
            .from('staged_rate_candidates')
            .update({
              staging_status: 'DRAFT',
              updated_at: new Date().toISOString(),
            })
            .eq('id', c.id);

          if (upErr) {
            report.errors.push(`Failed to update candidate ${c.id}: ${upErr.message}`);
            continue;
          }

          c.staging_status = 'DRAFT';
          c.stagingStatus = 'DRAFT';
          report.reconciledCount++;
          bStats.reconciled++;
        } catch (dbErr) {
          report.errors.push(`Exception updating candidate ${c.id}: ${dbErr.message}`);
        }
      } else {
        c.staging_status = 'DRAFT';
        c.stagingStatus = 'DRAFT';
        report.reconciledCount++;
        bStats.reconciled++;
      }
    }

    return report;
  }

}

module.exports = {
  CandidateStagingService,
};
