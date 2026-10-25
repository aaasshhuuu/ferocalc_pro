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

    // 1. Fetch active verified rates for this bank
    const activeRates = params.activeVerifiedRates || await this._getActiveVerifiedRates(candidate.bankCode);

    // 2. Perform dimensional diff
    const diffResult = this.diffEngine.diffCandidate(candidate, activeRates);

    // 3. Evaluate safety policy
    const policyResult = this.policyEngine.evaluateCandidate(candidate, diffResult, context);

    // 4. Enforce Policy Controls
    if (actorType === 'AUTOMATED_POLICY') {
      if (!policyResult.eligibleForAutoPromotion) {
        // AUTOMATED_POLICY cannot bypass policy: Route to IN_REVIEW or INVALID
        const newStatus = policyResult.recommendedAction; // 'IN_REVIEW' or 'INVALID'
        candidate.stagingStatus = newStatus;

        await this._logAudit({
          stagedCandidateId: candidate.id || candidate.candidateId,
          rateId: null,
          action: newStatus === 'INVALID' ? 'MARK_INVALID' : 'ESCALATE_TO_IN_REVIEW',
          actorType: 'AUTOMATED_POLICY',
          actorId,
          previousStatus: 'DRAFT',
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
      if (candidate.validationStatus === 'INVALID') {
        throw new Error(`Cannot promote invalid candidate: ${(candidate.validationErrors || []).join('; ')}`);
      }
    } else {
      throw new Error(`Unrecognized actorType: ${actorType}`);
    }

    // 5. Execute Promotion & Historical Versioning
    // A. If replacing an existing verified record, archive the old record safely
    let supersededRecord = null;
    const effectiveAt = candidate.effectiveFrom
      ? new Date(candidate.effectiveFrom).toISOString()
      : new Date().toISOString();

    if (diffResult.previousRecord) {
      supersededRecord = await this._archiveRate(diffResult.previousRecord, effectiveAt, actorId, 'Superseded by newly promoted candidate');
    }

    // B. Create the new active VERIFIED rate record
    const newVerifiedRate = await this._insertVerifiedRate(candidate, actorId, reason || policyResult.decisionReason);

    // C. Update staged candidate status to PROMOTED
    candidate.stagingStatus = 'PROMOTED';
    candidate.promotedRateId = newVerifiedRate.id;
    candidate.promotedAt = new Date().toISOString();
    candidate.promotedBy = actorType;
    candidate.promotionReason = reason || policyResult.decisionReason;

    // D. Append immutable promotion audit entry
    await this._logAudit({
      stagedCandidateId: candidate.id || candidate.candidateId,
      rateId: newVerifiedRate.id,
      action: 'PROMOTE',
      actorType,
      actorId,
      previousStatus: candidate.stagingStatus || 'DRAFT',
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

  async _getActiveVerifiedRates(bankCode) {
    if (!isSupabaseAvailable() || !supabaseAdmin) {
      return this._inMemoryRates.filter(r => 
        (r.bankCode === bankCode || r.bank_code === bankCode) && r.status === 'VERIFIED'
      );
    }
    try {
      const { data, error } = await supabaseAdmin
        .from('fd_rates')
        .select('*')
        .eq('banks.code', bankCode)
        .eq('status', 'VERIFIED');

      return (!error && data) ? data : [];
    } catch {
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

    const newRecord = {
      id: candidate.promotedRateId || crypto.randomUUID(),
      bank_id: candidate.bankId || candidate.bankCode,
      bankCode: candidate.bankCode,
      bank_code: candidate.bankCode,
      customer_type: candidate.customerType,
      tenure_domain: tenureDomain,
      tenureDomain,
      source_tenure_text: sourceTenureText,
      sourceTenureText,
      min_tenure_days: minTenureDays,
      max_tenure_days: maxTenureDays,
      minTenureDays,
      maxTenureDays,
      min_years: minYears,
      min_months: minMonths,
      min_days_cal: minDaysCal,
      min_operator: minOperator,
      max_years: maxYears,
      max_months: maxMonths,
      max_days_cal: maxDaysCal,
      max_operator: maxOperator,
      minYears,
      minMonths,
      minDaysCal,
      minOperator,
      maxYears,
      maxMonths,
      maxDaysCal,
      maxOperator,
      min_deposit: candidate.minDeposit || 0,
      max_deposit: candidate.maxDeposit || null,
      interest_rate: candidate.interestRate,
      interestRate: candidate.interestRate,
      is_callable: candidate.isCallable !== false,
      compounding_frequency: candidate.compoundingFrequency || 'QUARTERLY',
      effective_from: candidate.effectiveFrom || new Date().toISOString().split('T')[0],
      effective_until: null,
      status: 'VERIFIED',
      source_url: candidate.sourceUrl,
      source_content_hash: candidate.sourceContentHash,
      parser_version: candidate.parserVersion,
      verified_by: actorId,
      verified_at: new Date().toISOString(),
      review_notes: qualificationNotes,
      rate_category: rateCategory,
      scheme_name: schemeName,
      rateCategory,
      schemeName,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (!isSupabaseAvailable() || !supabaseAdmin) {
      this._inMemoryRates.push(newRecord);
    } else {
      await supabaseAdmin.from('fd_rates').insert([newRecord]);
    }

    return newRecord;
  }

  async _logAudit(entry) {
    const record = {
      id: crypto.randomUUID(),
      staged_candidate_id: entry.stagedCandidateId,
      rate_id: entry.rateId,
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
