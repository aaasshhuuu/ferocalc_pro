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

class CandidateStagingService {
  constructor(options = {}) {
    this.validator = options.validator || new CandidateValidator();
    this.anomalyDetector = options.anomalyDetector || new AnomalyDetector();
    this.logger = options.logger || console;
    this.supabaseClient = options.supabaseClient || null;
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
        .select('customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable')
        .eq('banks.code', bankCode)
        .eq('status', 'VERIFIED');

      if (!error && Array.isArray(data) && data.length > 0) {
        return data;
      }

      // 2. Fallback: Check most recent staged candidates
      const { data: stagedData } = await db
        .from('staged_rate_candidates')
        .select('customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable')
        .eq('bank_code', bankCode)
        .eq('validation_status', 'VALID')
        .order('extracted_at', { ascending: false })
        .limit(40);

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

      const { data, error } = await db
        .from('staged_rate_candidates')
        .insert(records)
        .select('id, bank_code, product_type, customer_type, min_tenure_days, max_tenure_days, interest_rate, is_callable, source_content_hash, staging_status');

      if (error) {
        this.logger.warn(`Failed to persist staged candidates to DB: ${error.message}`);
        return { persistedCount: 0, insertedRows: [], error: error.message };
      }

      return {
        persistedCount: (data && data.length) ? data.length : records.length,
        insertedRows: data || [],
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
    const parser = getParserForSource(collectionResult);
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
    const baselineRates = options.baselineRates || await this._fetchBaselineRates(bankCode);
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
}

module.exports = {
  CandidateStagingService,
};
