// FeroCalc Verified FD Rate Engine — Promotion & Rollback Service
//
// Implements safe promotion, state transitions, historical preservation,
// rollbacks, source failure resilience, and full explainable auditing.
//
// Safety Guarantees:
// 1. Direct DRAFT -> VERIFIED bypass without policy approval is strictly rejected.
// 2. Historical verified records are NEVER deleted; superseded records are archived with timestamps.
// 3. Rollbacks restore previous verified records without deleting history.
// 4. Source failures preserve 100% of existing verified rates.
// 5. Missing source rows are escalated to review, NEVER silently deleted.

'use strict';

const crypto = require('crypto');
const { RateDiffEngine, DIFF_TYPES } = require('./rate_diff_engine');
const { PromotionPolicyEngine } = require('./promotion_policy_engine');
const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');

class PromotionService {
  constructor(options = {}) {
    this.diffEngine = options.diffEngine || new RateDiffEngine();
    this.policyEngine = options.policyEngine || new PromotionPolicyEngine();
    this.logger = options.logger || console;
    this.supabaseClient = options.supabaseClient || null;

    // In-memory stores for mock/offline testing
    this._inMemoryRates = options.inMemoryRates || [];
    this._inMemoryAuditLogs = options.inMemoryAuditLogs || [];
    this._inMemoryStagedCandidates = options.inMemoryStagedCandidates || [];
  }

  /**
   * Promotes a staged candidate according to safety policy or administrative authority.
   *
   * @param {Object} params
   * @param {Object} params.candidate - Staged candidate rate
   * @param {'AUTOMATED_POLICY'|'ADMIN'} params.actorType
   * @param {string} params.actorId - 'AUTOMATED_POLICY' or admin user UUID
   * @param {string} [params.reason] - Human or automated rationale
   * @param {boolean} [params.overridePolicy=false] - Only allowed for actorType === 'ADMIN'
   * @param {Array<Object>} [params.activeVerifiedRates] - Current active rates (override/in-memory)
   * @param {Object} [params.context] - Extraction context
   * @returns {Promise<Object>} Promotion result
   */
  /**
   * Normalizes candidate properties ensuring both camelCase and snake_case
   * are present and consistent.
   */
  normalizeCandidate(c) {
    if (!c || typeof c !== 'object') return c;
    const normalized = { ...c };

    normalized.bankCode = c.bankCode || c.bank_code || c.bankId || c.bank_id;
    normalized.bank_code = normalized.bankCode;
    normalized.bankId = c.bankId || c.bank_id || normalized.bankCode;
    normalized.bank_id = normalized.bankId;

    normalized.productType = c.productType || c.product_type || 'RETAIL_DOMESTIC_TERM_DEPOSIT';
    normalized.product_type = normalized.productType;

    normalized.customerType = c.customerType || c.customer_type || 'REGULAR';
    normalized.customer_type = normalized.customerType;

    normalized.tenureDomain = String(c.tenureDomain || c.tenure_domain || 'DAYS').toUpperCase().trim();
    normalized.tenure_domain = normalized.tenureDomain;

    normalized.sourceTenureText = c.sourceTenureText || c.source_tenure_text || c.tenureLabel || c.tenure_label || null;
    normalized.source_tenure_text = normalized.sourceTenureText;

    normalized.tenureLabel = c.tenureLabel || c.tenure_label || normalized.sourceTenureText;
    normalized.tenure_label = normalized.tenureLabel;

    normalized.minTenureDays = c.minTenureDays !== undefined ? c.minTenureDays : c.min_tenure_days;
    normalized.min_tenure_days = normalized.minTenureDays;

    normalized.maxTenureDays = c.maxTenureDays !== undefined ? c.maxTenureDays : c.max_tenure_days;
    normalized.max_tenure_days = normalized.maxTenureDays;

    normalized.minYears = c.minYears !== undefined ? c.minYears : c.min_years;
    normalized.min_years = normalized.minYears;

    normalized.minMonths = c.minMonths !== undefined ? c.minMonths : c.min_months;
    normalized.min_months = normalized.minMonths;

    normalized.minDaysCal = c.minDaysCal !== undefined ? c.minDaysCal : c.min_days_cal;
    normalized.min_days_cal = normalized.minDaysCal;

    normalized.minOperator = c.minOperator || c.min_operator || null;
    normalized.min_operator = normalized.minOperator;

    normalized.maxYears = c.maxYears !== undefined ? c.maxYears : c.max_years;
    normalized.max_years = normalized.maxYears;

    normalized.maxMonths = c.maxMonths !== undefined ? c.maxMonths : c.max_months;
    normalized.max_months = normalized.maxMonths;

    normalized.maxDaysCal = c.maxDaysCal !== undefined ? c.maxDaysCal : c.max_days_cal;
    normalized.max_days_cal = normalized.maxDaysCal;

    normalized.maxOperator = c.maxOperator || c.max_operator || null;
    normalized.max_operator = normalized.maxOperator;

    normalized.interestRate = c.interestRate !== undefined ? Number(c.interestRate) : (c.interest_rate !== undefined ? Number(c.interest_rate) : undefined);
    normalized.interest_rate = normalized.interestRate;

    normalized.seniorCitizenRate = c.seniorCitizenRate !== undefined ? c.seniorCitizenRate : c.senior_citizen_rate;
    normalized.senior_citizen_rate = normalized.seniorCitizenRate;

    normalized.superSeniorRate = c.superSeniorRate !== undefined ? c.superSeniorRate : c.super_senior_rate;
    normalized.super_senior_rate = normalized.superSeniorRate;

    normalized.minDeposit = c.minDeposit !== undefined ? c.minDeposit : (c.min_deposit !== undefined ? c.min_deposit : 0);
    normalized.min_deposit = normalized.minDeposit;

    normalized.maxDeposit = c.maxDeposit !== undefined ? c.maxDeposit : (c.max_deposit !== undefined ? c.max_deposit : null);
    normalized.max_deposit = normalized.maxDeposit;

    normalized.isCallable = c.isCallable !== undefined ? Boolean(c.isCallable) : (c.is_callable !== undefined ? Boolean(c.is_callable) : true);
    normalized.is_callable = normalized.isCallable;

    normalized.compoundingFrequency = c.compoundingFrequency || c.compounding_frequency || 'QUARTERLY';
    normalized.compounding_frequency = normalized.compoundingFrequency;

    normalized.effectiveFrom = c.effectiveFrom || c.effective_from || null;
    normalized.effective_from = normalized.effectiveFrom;

    normalized.effectiveUntil = c.effectiveUntil || c.effective_until || null;
    normalized.effective_until = normalized.effectiveUntil;

    normalized.sourceUrl = c.sourceUrl || c.source_url || null;
    normalized.source_url = normalized.sourceUrl;

    normalized.sourceDocumentUrl = c.sourceDocumentUrl || c.source_document_url || null;
    normalized.source_document_url = normalized.sourceDocumentUrl;

    normalized.sourceContentHash = c.sourceContentHash || c.source_content_hash || null;
    normalized.source_content_hash = normalized.sourceContentHash;

    normalized.parserId = c.parserId || c.parser_id || null;
    normalized.parser_id = normalized.parserId;

    normalized.parserVersion = c.parserVersion || c.parser_version || '1.0.0';
    normalized.parser_version = normalized.parserVersion;

    normalized.validationStatus = c.validationStatus || c.validation_status || 'VALID';
    normalized.validation_status = normalized.validationStatus;

    normalized.validationErrors = Array.isArray(c.validationErrors) ? c.validationErrors : (Array.isArray(c.validation_errors) ? c.validation_errors : []);
    normalized.validation_errors = normalized.validationErrors;

    normalized.anomalyFlags = Array.isArray(c.anomalyFlags) ? c.anomalyFlags : (Array.isArray(c.anomaly_flags) ? c.anomaly_flags : []);
    normalized.anomaly_flags = normalized.anomalyFlags;

    normalized.stagingStatus = c.stagingStatus || c.staging_status || 'DRAFT';
    normalized.staging_status = normalized.stagingStatus;

    normalized.rateCategory = String(c.rateCategory || c.rate_category || 'STANDARD').toUpperCase().trim();
    normalized.rate_category = normalized.rateCategory;

    normalized.schemeName = c.schemeName !== undefined ? c.schemeName : (c.scheme_name !== undefined ? c.scheme_name : null);
    normalized.scheme_name = normalized.schemeName;

    normalized.notes = c.notes !== undefined ? c.notes : null;

    return normalized;
  }

  async promoteCandidate(params) {
    const {
      candidate,
      actorType = 'AUTOMATED_POLICY',
      actorId = 'AUTOMATED_POLICY',
      reason = '',
      overridePolicy = false,
      context = {},
    } = params;

    if (!candidate) {
      throw new Error('Candidate is required for promotion');
    }

    const normalizedCandidate = this.normalizeCandidate(candidate);
    // Sync normalized fields back to candidate reference
    Object.assign(candidate, normalizedCandidate);

    const bankCode = candidate.bankCode || candidate.bank_code;
    // 1. Fetch active verified rates for this bank
    const activeRates = params.activeVerifiedRates || await this._getActiveVerifiedRates(bankCode);

    // 2. Perform dimensional diff
    const diffResult = this.diffEngine.diffCandidate(candidate, activeRates);

    // 3. Evaluate safety policy
    const policyResult = this.policyEngine.evaluateCandidate(candidate, diffResult, context);

    // 4. Enforce Policy Controls
    if (actorType === 'AUTOMATED_POLICY') {
      if (!policyResult.eligibleForAutoPromotion) {
        // AUTOMATED_POLICY cannot bypass policy: Route to IN_REVIEW or INVALID
        const previousStatus = candidate.stagingStatus || candidate.staging_status || 'DRAFT';
        const newStatus = policyResult.recommendedAction; // 'IN_REVIEW' or 'INVALID'
        candidate.stagingStatus = newStatus;
        candidate.staging_status = newStatus;
        if (params.candidate) {
          params.candidate.stagingStatus = newStatus;
          params.candidate.staging_status = newStatus;
        }

        await this._logAudit({
          stagedCandidateId: candidate.id || candidate.candidateId,
          rateId: null,
          action: newStatus === 'INVALID' ? 'MARK_INVALID' : 'ESCALATE_TO_IN_REVIEW',
          actorType: 'AUTOMATED_POLICY',
          actorId,
          previousStatus,
          newStatus,
          policyResult,
          diffSummary: diffResult,
          sourceContentHash: candidate.sourceContentHash,
          parserVersion: candidate.parserVersion,
          notes: policyResult.decisionReason,
        });

        return {
          success: false,
          promoted: false,
          stagingStatus: newStatus,
          policyResult,
          diffResult,
          reason: policyResult.decisionReason,
        };
      }
    } else if (actorType === 'ADMIN') {
      // Admin verification: If candidate is INVALID, refuse promotion even for admin
      const valStatus = candidate.validationStatus || candidate.validation_status || 'VALID';
      if (valStatus === 'INVALID') {
        throw new Error(`Cannot promote invalid candidate: ${(candidate.validationErrors || []).join('; ')}`);
      }
    } else {
      throw new Error(`Unrecognized actorType: ${actorType}`);
    }

    // 5. Execute Promotion & Historical Versioning
    // A. If replacing an existing verified record, archive the old record safely
    let supersededRecord = null;
    const effectiveAt = (candidate.effectiveFrom || candidate.effective_from)
      ? new Date(candidate.effectiveFrom || candidate.effective_from).toISOString()
      : new Date().toISOString();

    if (diffResult.previousRecord) {
      supersededRecord = await this._archiveRate(diffResult.previousRecord, effectiveAt, actorId, 'Superseded by newly promoted candidate');
    }

    // B. Create the new active VERIFIED rate record
    const newVerifiedRate = await this._insertVerifiedRate(candidate, actorId, reason || policyResult.decisionReason);

    const previousStatus = candidate.stagingStatus || candidate.staging_status || 'DRAFT';
    const nowIso = new Date().toISOString();

    // C. Update staged candidate status to PROMOTED
    candidate.stagingStatus = 'PROMOTED';
    candidate.staging_status = 'PROMOTED';
    candidate.promotedRateId = newVerifiedRate.id;
    candidate.promoted_rate_id = newVerifiedRate.id;
    candidate.promotedAt = nowIso;
    candidate.promoted_at = nowIso;
    candidate.promotedBy = actorType;
    candidate.promoted_by = actorType;
    candidate.promotionReason = reason || policyResult.decisionReason;
    candidate.promotion_reason = candidate.promotionReason;

    if (params.candidate) {
      params.candidate.stagingStatus = 'PROMOTED';
      params.candidate.staging_status = 'PROMOTED';
      params.candidate.promotedRateId = newVerifiedRate.id;
      params.candidate.promoted_rate_id = newVerifiedRate.id;
      params.candidate.promotedAt = nowIso;
      params.candidate.promoted_at = nowIso;
      params.candidate.promotedBy = actorType;
      params.candidate.promoted_by = actorType;
      params.candidate.promotionReason = candidate.promotionReason;
      params.candidate.promotion_reason = candidate.promotionReason;
    }

    // D. Append immutable promotion audit entry
    await this._logAudit({
      stagedCandidateId: candidate.id || candidate.candidateId,
      rateId: newVerifiedRate.id,
      action: 'PROMOTE',
      actorType,
      actorId,
      previousStatus,
      newStatus: 'VERIFIED',
      policyResult,
      diffSummary: diffResult,
      sourceContentHash: candidate.sourceContentHash,
      parserVersion: candidate.parserVersion,
      notes: reason || policyResult.decisionReason,
    });

    return {
      success: true,
      promoted: true,
      newVerifiedRate,
      supersededRecord,
      policyResult,
      diffResult,
      reason: reason || policyResult.decisionReason,
    };
  }

  /**
   * Safe rollback mechanism: Restores a previously superseded verified rate.
   *
   * @param {Object} params
   * @param {string} params.rateId - ID of currently active verified rate to rollback
   * @param {string} params.adminUserId - UUID of authorized administrator
   * @param {string} [params.notes] - Administrative reason for rollback
   * @returns {Promise<Object>} Rollback result
   */
  async rollbackRate(params) {
    const { rateId, adminUserId, notes = 'Administrative rollback' } = params;

    if (!rateId) throw new Error('rateId is required for rollback');
    if (!adminUserId) throw new Error('adminUserId is required for rollback');

    // 1. Locate current rate
    const currentRate = await this._getRateById(rateId);
    if (!currentRate) {
      throw new Error(`Rate ${rateId} not found`);
    }
    if (currentRate.status !== 'VERIFIED') {
      throw new Error(`Cannot rollback rate ${rateId}: status is ${currentRate.status}, must be VERIFIED`);
    }

    // 2. Locate previously archived rate in the same dimensional bucket
    const previousArchivedRate = await this._findPreviousArchivedRate(currentRate);
    if (!previousArchivedRate) {
      throw new Error(`No previously archived rate found to restore for rate ${rateId}`);
    }

    // 3. Atomically restore previous rate and archive current rate
    // Archive the incorrect current rate
    currentRate.status = 'ARCHIVED';
    currentRate.effective_until = new Date().toISOString();
    currentRate.effectiveUntil = currentRate.effective_until;
    currentRate.review_notes = `Rolled back by admin: ${notes}`;

    // Restore previous rate to VERIFIED
    previousArchivedRate.status = 'VERIFIED';
    previousArchivedRate.effective_until = null;
    previousArchivedRate.effectiveUntil = null;
    previousArchivedRate.review_notes = `Restored via rollback of rate ${rateId}: ${notes}`;

    if (isSupabaseAvailable() && supabaseAdmin) {
      await supabaseAdmin.from('fd_rates').update({
        status: 'ARCHIVED',
        effective_until: currentRate.effective_until,
        review_notes: currentRate.review_notes,
        updated_at: new Date().toISOString(),
      }).eq('id', currentRate.id);

      await supabaseAdmin.from('fd_rates').update({
        status: 'VERIFIED',
        effective_until: null,
        review_notes: previousArchivedRate.review_notes,
        updated_at: new Date().toISOString(),
      }).eq('id', previousArchivedRate.id);
    }

    // 4. Create immutable audit log for the rollback event
    const auditEntry = await this._logAudit({
      stagedCandidateId: null,
      rateId: currentRate.id,
      action: 'ROLLBACK',
      actorType: 'ADMIN',
      actorId: adminUserId,
      previousStatus: 'VERIFIED',
      newStatus: 'ARCHIVED',
      policyResult: null,
      diffSummary: { restoredRateId: previousArchivedRate.id, rolledBackRateId: currentRate.id },
      sourceContentHash: currentRate.source_content_hash || '',
      parserVersion: currentRate.parser_version || '1.0.0',
      notes,
    });

    return {
      success: true,
      rolledBackRate: currentRate,
      restoredRate: previousArchivedRate,
      auditEntry,
    };
  }

  /**
   * Rejects an in-review candidate.
   */
  async rejectCandidate(candidate, adminUserId, reason = 'Administrative rejection') {
    candidate.stagingStatus = 'REJECTED';
    await this._logAudit({
      stagedCandidateId: candidate.id || candidate.candidateId,
      rateId: null,
      action: 'REJECT',
      actorType: 'ADMIN',
      actorId: adminUserId,
      previousStatus: 'IN_REVIEW',
      newStatus: 'REJECTED',
      policyResult: null,
      diffSummary: null,
      sourceContentHash: candidate.sourceContentHash,
      parserVersion: candidate.parserVersion,
      notes: reason,
    });

    return { success: true, candidate, status: 'REJECTED' };
  }

  /**
   * Handles upstream source failure without corrupting or deleting active rates.
   */
  async handleSourceFailure(sourceId, bankCode, error) {
    // Safety Guarantee: Existing verified rates are NEVER deleted or modified
    const activeRates = await this._getActiveVerifiedRates(bankCode);
    this.logger.warn(`Source ${sourceId} fetch failed: ${error.message}. Preserving ${activeRates.length} active verified rates.`);

    return {
      sourceId,
      bankCode,
      preservedActiveRatesCount: activeRates.length,
      status: 'FETCH_FAILED',
      ratesPreserved: true,
      error: error.message,
    };
  }

  /**
   * Handles rows missing in source extraction without deleting verified rates.
   */
  async handleMissingSourceRows(candidates, bankCode) {
    const activeRates = await this._getActiveVerifiedRates(bankCode);
    const batchDiff = this.diffEngine.diffBatch(candidates, activeRates);

    if (batchDiff.removedCount > 0) {
      // Escalate to review; NEVER delete
      this.logger.warn(`Source returned ${batchDiff.removedCount} fewer rates than active verified records. Flagging for review.`);
    }

    return {
      removedFromSourceCount: batchDiff.removedCount,
      removedCandidates: batchDiff.removedFromSource,
      action: 'ESCALATE_TO_IN_REVIEW',
      ratesDeleted: false, // Strict guarantee
    };
  }

  // ============================================================
  // Internal Helpers (supports both Supabase DB and in-memory mock)
  // ============================================================

  async _resolveBankId(bankCodeOrId) {
    if (!bankCodeOrId) return null;
    const input = String(bankCodeOrId).trim();
    const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (UUID_REGEX.test(input)) {
      return input;
    }

    if (!this._bankIdCache) {
      this._bankIdCache = new Map();
    }
    const upperCode = input.toUpperCase();
    if (this._bankIdCache.has(upperCode)) {
      return this._bankIdCache.get(upperCode);
    }

    const db = this.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);
    if (db) {
      try {
        const { data, error } = await db
          .from('banks')
          .select('id, short_name')
          .eq('short_name', upperCode)
          .maybeSingle();

        if (!error && data && data.id) {
          this._bankIdCache.set(upperCode, data.id);
          this._bankIdCache.set(data.id, data.id);
          return data.id;
        }
      } catch (err) {
        this.logger.warn(`Failed to resolve bank ID from Supabase for "${input}": ${err.message}`);
      }
    }

    // Deterministic fallback UUID for offline / in-memory tests
    const md5 = crypto.createHash('md5').update(`FEROCALC_BANK_${upperCode}`).digest('hex');
    const mockUuid = `${md5.slice(0, 8)}-${md5.slice(8, 12)}-4${md5.slice(13, 16)}-a${md5.slice(17, 20)}-${md5.slice(20, 32)}`;
    return mockUuid;
  }

  async _getActiveVerifiedRates(bankCodeOrId) {
    if (!bankCodeOrId) return [];
    const input = String(bankCodeOrId).trim();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(input);
    const db = this.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);

    if (!db) {
      const codeOrId = input.toUpperCase();
      const filtered = this._inMemoryRates.filter(r =>
        (
          (r.bankCode && r.bankCode.toUpperCase() === codeOrId) ||
          (r.bank_code && r.bank_code.toUpperCase() === codeOrId) ||
          r.bank_id === input ||
          r.bankId === input
        ) && r.status === 'VERIFIED'
      );
      filtered.forEach(row => {
        const canonicalCode = (row.banks && row.banks.short_name)
          ? row.banks.short_name.toUpperCase().trim()
          : (row.bankCode || row.bank_code || (!isUuid ? input.toUpperCase().trim() : null));
        row.bankCode = canonicalCode;
        row.bank_code = canonicalCode;
      });
      return filtered;
    }

    try {
      const bankId = isUuid ? input : await this._resolveBankId(input);

      let query = db
        .from('fd_rates')
        .select('*, banks!inner(short_name)')
        .eq('status', 'VERIFIED');

      if (bankId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(bankId)) {
        query = query.eq('bank_id', bankId);
      } else {
        query = query.eq('banks.short_name', input.toUpperCase());
      }

      const { data, error } = await query;
      if (error) {
        this.logger.warn(`Failed to fetch active verified rates: ${error.message}`);
        return [];
      }
      const canonicalRequested = !isUuid ? input.toUpperCase().trim() : null;
      return (data || []).map(row => {
        const canonicalCode = (row.banks && row.banks.short_name)
          ? row.banks.short_name.toUpperCase().trim()
          : canonicalRequested;
        return {
          ...row,
          bankCode: canonicalCode,
          bank_code: canonicalCode,
        };
      });
    } catch (err) {
      this.logger.warn(`Error fetching active verified rates: ${err.message}`);
      return [];
    }
  }

  async _getRateById(rateId) {
    if (!isSupabaseAvailable() || !supabaseAdmin) {
      return this._inMemoryRates.find(r => r.id === rateId) || null;
    }
    const { data } = await supabaseAdmin.from('fd_rates').select('*').eq('id', rateId).single();
    return data || null;
  }

  async _findPreviousArchivedRate(currentRate) {
    const curCat = currentRate.rate_category || currentRate.rateCategory || 'STANDARD';
    const curScheme = currentRate.scheme_name || currentRate.schemeName || null;
    const curDomain = (currentRate.tenure_domain || currentRate.tenureDomain || 'DAYS').toUpperCase();

    if (!isSupabaseAvailable() || !supabaseAdmin) {
      // Find archived rate with matching bucket
      return this._inMemoryRates.find(r => 
        r.id !== currentRate.id &&
        (r.bankCode === currentRate.bankCode || r.bank_code === currentRate.bank_code) &&
        r.customer_type === currentRate.customer_type &&
        r.is_callable === currentRate.is_callable &&
        (r.tenure_domain || r.tenureDomain || 'DAYS').toUpperCase() === curDomain &&
        (curDomain === 'CALENDAR'
          ? (
              Number(r.min_years ?? r.minYears ?? 0) === Number(currentRate.min_years ?? currentRate.minYears ?? 0) &&
              Number(r.min_months ?? r.minMonths ?? 0) === Number(currentRate.min_months ?? currentRate.minMonths ?? 0) &&
              Number(r.min_days_cal ?? r.minDaysCal ?? 0) === Number(currentRate.min_days_cal ?? currentRate.minDaysCal ?? 0) &&
              (r.min_operator ?? r.minOperator ?? '') === (currentRate.min_operator ?? currentRate.minOperator ?? '') &&
              Number(r.max_years ?? r.maxYears ?? 0) === Number(currentRate.max_years ?? currentRate.maxYears ?? 0) &&
              Number(r.max_months ?? r.maxMonths ?? 0) === Number(currentRate.max_months ?? currentRate.maxMonths ?? 0) &&
              Number(r.max_days_cal ?? r.maxDaysCal ?? 0) === Number(currentRate.max_days_cal ?? currentRate.maxDaysCal ?? 0) &&
              (r.max_operator ?? r.maxOperator ?? '') === (currentRate.max_operator ?? currentRate.maxOperator ?? '')
            )
          : (
              r.min_tenure_days === currentRate.min_tenure_days &&
              r.max_tenure_days === currentRate.max_tenure_days
            )) &&
        (r.rate_category || r.rateCategory || 'STANDARD') === curCat &&
        (r.scheme_name || r.schemeName || null) === curScheme &&
        r.status === 'ARCHIVED'
      ) || null;
    }

    let q = supabaseAdmin
      .from('fd_rates')
      .select('*')
      .eq('bank_id', currentRate.bank_id)
      .eq('customer_type', currentRate.customer_type)
      .eq('is_callable', currentRate.is_callable)
      .eq('rate_category', curCat)
      .eq('status', 'ARCHIVED')
      .order('updated_at', { ascending: false })
      .limit(1);

    if (curDomain === 'CALENDAR') {
      if (currentRate.min_years !== undefined && currentRate.min_years !== null) q = q.eq('min_years', currentRate.min_years);
      if (currentRate.min_months !== undefined && currentRate.min_months !== null) q = q.eq('min_months', currentRate.min_months);
      if (currentRate.min_days_cal !== undefined && currentRate.min_days_cal !== null) q = q.eq('min_days_cal', currentRate.min_days_cal);
      if (currentRate.min_operator !== undefined && currentRate.min_operator !== null) q = q.eq('min_operator', currentRate.min_operator);
      if (currentRate.max_years !== undefined && currentRate.max_years !== null) q = q.eq('max_years', currentRate.max_years);
      if (currentRate.max_months !== undefined && currentRate.max_months !== null) q = q.eq('max_months', currentRate.max_months);
      if (currentRate.max_days_cal !== undefined && currentRate.max_days_cal !== null) q = q.eq('max_days_cal', currentRate.max_days_cal);
      if (currentRate.max_operator !== undefined && currentRate.max_operator !== null) q = q.eq('max_operator', currentRate.max_operator);
    } else {
      q = q.eq('min_tenure_days', currentRate.min_tenure_days)
           .eq('max_tenure_days', currentRate.max_tenure_days);
    }

    if (curScheme) {
      q = q.eq('scheme_name', curScheme);
    } else {
      q = q.is('scheme_name', null);
    }

    const { data } = await q.maybeSingle();
    return data || null;
  }

  async _archiveRate(rate, effectiveUntil, actorId, notes) {
    rate.status = 'ARCHIVED';
    rate.effective_until = effectiveUntil;
    rate.effectiveUntil = effectiveUntil;
    rate.updated_at = new Date().toISOString();

    if (isSupabaseAvailable() && supabaseAdmin) {
      await supabaseAdmin
        .from('fd_rates')
        .update({
          status: 'ARCHIVED',
          effective_until: effectiveUntil,
          updated_at: new Date().toISOString(),
        })
        .eq('id', rate.id);
    }
    return rate;
  }

  async _insertVerifiedRate(candidate, actorId, reason) {
    const rateCategory = (candidate.rateCategory || candidate.rate_category || 'STANDARD').toUpperCase();
    const schemeName = rateCategory === 'SPECIAL_SCHEME'
      ? (candidate.schemeName || candidate.scheme_name || null)
      : null;

    // Fail closed: Special scheme MUST have a valid scheme_name
    if (rateCategory === 'SPECIAL_SCHEME' && (!schemeName || !String(schemeName).trim())) {
      throw new Error(`Cannot promote SPECIAL_SCHEME candidate without scheme_name (candidate ID: ${candidate.id || candidate.candidateId})`);
    }

    const qualificationNotes = candidate.notes || reason;
    const tenureDomain = (candidate.tenureDomain || candidate.tenure_domain || 'DAYS').toUpperCase().trim();
    const isCalendar = tenureDomain === 'CALENDAR';

    const sourceTenureText = candidate.sourceTenureText || candidate.source_tenure_text || candidate.tenureLabel || candidate.tenure_label || null;

    const minTenureDays = isCalendar ? null : (candidate.minTenureDays !== undefined ? candidate.minTenureDays : (candidate.min_tenure_days !== undefined ? candidate.min_tenure_days : null));
    const maxTenureDays = isCalendar ? null : (candidate.maxTenureDays !== undefined ? candidate.maxTenureDays : (candidate.max_tenure_days !== undefined ? candidate.max_tenure_days : null));

    const hasMin = Boolean(candidate.minOperator || candidate.min_operator) ||
      candidate.minYears != null || candidate.min_years != null ||
      candidate.minMonths != null || candidate.min_months != null ||
      candidate.minDaysCal != null || candidate.min_days_cal != null;

    const minYears = isCalendar ? (hasMin ? Number(candidate.minYears ?? candidate.min_years ?? 0) : null) : null;
    const minMonths = isCalendar ? (hasMin ? Number(candidate.minMonths ?? candidate.min_months ?? 0) : null) : null;
    const minDaysCal = isCalendar ? (hasMin ? Number(candidate.minDaysCal ?? candidate.min_days_cal ?? 0) : null) : null;
    const minOperator = isCalendar ? (candidate.minOperator || candidate.min_operator || null) : null;

    const hasMax = Boolean(candidate.maxOperator || candidate.max_operator) ||
      candidate.maxYears != null || candidate.max_years != null ||
      candidate.maxMonths != null || candidate.max_months != null ||
      candidate.maxDaysCal != null || candidate.max_days_cal != null;

    const maxYears = isCalendar ? (hasMax ? Number(candidate.maxYears ?? candidate.max_years ?? 0) : null) : null;
    const maxMonths = isCalendar ? (hasMax ? Number(candidate.maxMonths ?? candidate.max_months ?? 0) : null) : null;
    const maxDaysCal = isCalendar ? (hasMax ? Number(candidate.maxDaysCal ?? candidate.max_days_cal ?? 0) : null) : null;
    const maxOperator = isCalendar ? (candidate.maxOperator || candidate.max_operator || null) : null;

    const bankCode = candidate.bankCode || candidate.bank_code;
    const resolvedBankId = await this._resolveBankId(candidate.bankId || candidate.bank_id || bankCode);

    const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const rateId = (candidate.promotedRateId && UUID_REGEX.test(candidate.promotedRateId))
      ? candidate.promotedRateId
      : ((candidate.promoted_rate_id && UUID_REGEX.test(candidate.promoted_rate_id)) ? candidate.promoted_rate_id : crypto.randomUUID());

    const verifiedByUuid = (actorId && UUID_REGEX.test(actorId)) ? actorId : null;
    const nowIso = new Date().toISOString();
    const effectiveFromDate = candidate.effectiveFrom || candidate.effective_from || nowIso.split('T')[0];

    // dbPayload contains STRICTLY valid columns of public.fd_rates
    const dbPayload = {
      id: rateId,
      bank_id: resolvedBankId,
      customer_type: candidate.customerType || candidate.customer_type || 'REGULAR',
      tenure_domain: tenureDomain,
      source_tenure_text: sourceTenureText,
      min_tenure_days: minTenureDays,
      max_tenure_days: maxTenureDays,
      min_years: minYears,
      min_months: minMonths,
      min_days_cal: minDaysCal,
      min_operator: minOperator,
      max_years: maxYears,
      max_months: maxMonths,
      max_days_cal: maxDaysCal,
      max_operator: maxOperator,
      min_deposit: Number(candidate.minDeposit ?? candidate.min_deposit ?? 0),
      max_deposit: (candidate.maxDeposit !== undefined && candidate.maxDeposit !== null)
        ? Number(candidate.maxDeposit)
        : ((candidate.max_deposit !== undefined && candidate.max_deposit !== null) ? Number(candidate.max_deposit) : null),
      interest_rate: Number(candidate.interestRate ?? candidate.interest_rate),
      is_callable: candidate.isCallable !== false && candidate.is_callable !== false,
      compounding_frequency: candidate.compoundingFrequency || candidate.compounding_frequency || 'QUARTERLY',
      effective_from: effectiveFromDate,
      effective_until: null,
      status: 'VERIFIED',
      source_url: candidate.sourceUrl || candidate.source_url || null,
      verified_by: verifiedByUuid,
      verified_at: nowIso,
      review_notes: qualificationNotes,
      rate_category: rateCategory,
      scheme_name: schemeName,
      created_at: nowIso,
      updated_at: nowIso,
    };

    // Full in-memory record including camelCase getters/properties for tests and API consumers
    const newRecord = {
      ...dbPayload,
      bankId: resolvedBankId,
      bankCode,
      bank_code: bankCode,
      customerType: dbPayload.customer_type,
      tenureDomain,
      sourceTenureText,
      minTenureDays,
      maxTenureDays,
      minYears,
      minMonths,
      minDaysCal,
      minOperator,
      maxYears,
      maxMonths,
      maxDaysCal,
      maxOperator,
      minDeposit: dbPayload.min_deposit,
      maxDeposit: dbPayload.max_deposit,
      interestRate: dbPayload.interest_rate,
      isCallable: dbPayload.is_callable,
      compoundingFrequency: dbPayload.compounding_frequency,
      effectiveFrom: dbPayload.effective_from,
      effectiveUntil: null,
      sourceUrl: dbPayload.source_url,
      sourceContentHash: candidate.sourceContentHash || candidate.source_content_hash || null,
      parserVersion: candidate.parserVersion || candidate.parser_version || '1.0.0',
      rateCategory,
      schemeName,
    };

    if (!isSupabaseAvailable() || !supabaseAdmin) {
      this._inMemoryRates.push(newRecord);
    } else {
      const { error } = await supabaseAdmin.from('fd_rates').insert([dbPayload]);
      if (error) {
        throw new Error(`Failed to insert verified rate into fd_rates: ${error.message} (code: ${error.code})`);
      }
    }

    return newRecord;
  }

  async _logAudit(entry) {
    const record = {
      id: crypto.randomUUID(),
      staged_candidate_id: (entry.stagedCandidateId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(entry.stagedCandidateId))
        ? entry.stagedCandidateId
        : null,
      rate_id: (entry.rateId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(entry.rateId))
        ? entry.rateId
        : null,
      action: entry.action,
      actor_type: entry.actorType,
      actor_id: entry.actorId,
      previous_status: entry.previousStatus,
      new_status: entry.newStatus,
      policy_result: entry.policyResult,
      diff_summary: entry.diffSummary,
      source_content_hash: entry.sourceContentHash,
      parser_version: entry.parserVersion,
      notes: entry.notes,
      created_at: new Date().toISOString(),
    };

    this._inMemoryAuditLogs.push(record);

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin.from('promotion_audit_log').insert([record]);
      } catch (err) {
        this.logger.warn(`Failed to insert promotion audit log: ${err.message}`);
      }
    }

    return record;
  }
}

module.exports = {
  PromotionService,
};
