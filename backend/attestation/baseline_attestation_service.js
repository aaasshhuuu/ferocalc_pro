// FeroCalc Verified FD Rate Engine — Initial Baseline Attestation Service
//
// Manages source-level baseline attestations and safe batch promotion for initial
// bank datasets.
//
// Safety Guarantees:
// 1. DO NOT TRUST HASH ALONE: Source attestation requires official domain, valid parser,
//    non-zero extraction, zero validation failures, and zero critical anomalies.
// 2. NO POLICY BYPASS: Even after source attestation, individual candidates must pass
//    data integrity, domain verification, and anomaly checks before promotion.
// 3. IDEMPOTENT PROMOTION: Re-promoting an attested baseline never creates duplicate
//    active verified records or duplicate promotions.
// 4. NON-DESTRUCTIVE: Unpromoted or rejected candidates remain safely in review without
//    corrupting historical rates.

'use strict';

const crypto = require('crypto');
const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { PromotionService } = require('../promotion/promotion_service');

const ATTESTATION_STATUS = {
  PENDING: 'PENDING',
  ATTESTED: 'ATTESTED',
  REJECTED: 'REJECTED',
  SUPERSEDED: 'SUPERSEDED',
};

const PROMOTION_STATUS = {
  UNPROMOTED: 'UNPROMOTED',
  PROMOTED: 'PROMOTED',
  PARTIALLY_PROMOTED: 'PARTIALLY_PROMOTED',
};

const ALLOWED_OFFICIAL_DOMAINS = [
  'sbi.co.in',
  'hdfcbank.com',
  'icicibank.com',
  'axisbank.com',
  'theunitybank.com',
];

function isOfficialBankDomain(url) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
    return ALLOWED_OFFICIAL_DOMAINS.some(d => host === d || host.endsWith('.' + d));
  } catch {
    return false;
  }
}

function normalizeIsCallableFilter(val) {
  if (val === undefined || val === null || val === '') return null;
  if (val === true || val === 1) return true;
  if (val === false || val === 0) return false;
  if (typeof val === 'string') {
    const s = val.trim().toLowerCase();
    if (s === 'true' || s === '1') return true;
    if (s === 'false' || s === '0') return false;
    if (s === 'all') return null;
  }
  throw new Error(`Invalid isCallable parameter: "${val}". Must be one of: true, false, all.`);
}

function isCandidateCallable(c) {
  if (c.isCallable !== undefined) return Boolean(c.isCallable);
  if (c.is_callable !== undefined) return Boolean(c.is_callable);
  return true;
}

class BaselineAttestationService {
  constructor(options = {}) {
    this.diffEngine = options.diffEngine || new RateDiffEngine();
    this.policyEngine = options.policyEngine || new PromotionPolicyEngine();
    this.promotionService = options.promotionService || new PromotionService({
      diffEngine: this.diffEngine,
      policyEngine: this.policyEngine,
      logger: options.logger || console,
      inMemoryRates: options.inMemoryRates,
      inMemoryAuditLogs: options.inMemoryAuditLogs,
    });
    this.logger = options.logger || console;

    // In-memory registry for mock tests and offline environments
    this._inMemoryAttestations = options.inMemoryAttestations || new Map();
    this._inMemoryCandidates = options.inMemoryCandidates || new Map();
  }

  /**
   * Generates a deterministic batch ID for an attestation snapshot.
   */
  generateBatchId(bankCode, sourceId, contentHash) {
    const cleanBank = (bankCode || 'BANK').toLowerCase().trim();
    const cleanSource = (sourceId || 'source').replace(/[^a-zA-Z0-9_-]/g, '_');
    const hashSnippet = (contentHash || 'unknown').substring(0, 12);
    return `baseline_${cleanBank}_${cleanSource}_${hashSnippet}`;
  }

  /**
   * Evaluates if a candidate batch meets the rigorous criteria required for baseline attestation.
   */
  evaluateAttestationEligibility(attestationData) {
    const issues = [];

    // 1. Official bank domain validation
    if (!attestationData.sourceUrl || !isOfficialBankDomain(attestationData.sourceUrl)) {
      issues.push(`Source URL is not on an approved official bank domain: "${attestationData.sourceUrl}"`);
    }

    // 2. Hash integrity
    if (!attestationData.sourceContentHash || !/^[0-9a-f]{64}$/i.test(attestationData.sourceContentHash)) {
      issues.push(`Invalid or missing SHA-256 source content hash: "${attestationData.sourceContentHash}"`);
    }

    // 3. Parser integrity
    if (!attestationData.parserId || !attestationData.parserVersion) {
      issues.push('Missing parser identifier or parser version');
    }

    // 4. Non-zero candidates
    if (!attestationData.candidateCount || attestationData.candidateCount <= 0) {
      issues.push('Candidate batch contains zero extracted rates (cannot attest empty table)');
    }

    // 5. Validation failures
    if (attestationData.invalidCandidateCount > 0) {
      issues.push(`Batch contains ${attestationData.invalidCandidateCount} invalid candidates failing schema validation`);
    }

    // 6. Critical anomalies
    if (attestationData.anomalousCandidateCount > 0) {
      issues.push(`Batch contains ${attestationData.anomalousCandidateCount} candidates with active anomaly flags`);
    }

    return {
      eligible: issues.length === 0,
      issues,
    };
  }

  /**
   * Creates or registers a baseline attestation batch from an extraction run.
   */
  async createBaselineBatch({
    bankCode,
    sourceId,
    sourceUrl,
    sourceType = 'HTML',
    sourceContentHash,
    fetchedAt = new Date().toISOString(),
    parserId,
    parserVersion = '1.0.0',
    candidates = [],
    validationSummary = {},
    anomalySummary = {},
    effectiveFrom = null,
    notes = '',
  }) {
    if (!bankCode) throw new Error('bankCode is required');
    if (!sourceId) throw new Error('sourceId is required');
    if (!sourceContentHash) throw new Error('sourceContentHash is required');

    const batchId = this.generateBatchId(bankCode, sourceId, sourceContentHash);
    const existing = await this.getAttestationByBatchId(batchId);
    if (existing) {
      return existing;
    }

    const candidateCount = candidates.length;
    const invalidCandidateCount = validationSummary.invalidCount !== undefined
      ? validationSummary.invalidCount
      : candidates.filter(c => c.validationStatus === 'INVALID').length;
    const validCandidateCount = candidateCount - invalidCandidateCount;
    const anomalousCandidateCount = anomalySummary.candidatesWithAnomalies !== undefined
      ? anomalySummary.candidatesWithAnomalies
      : candidates.filter(c => c.anomalyFlags && c.anomalyFlags.length > 0).length;

    const eligibility = this.evaluateAttestationEligibility({
      sourceUrl,
      sourceContentHash,
      parserId,
      parserVersion,
      candidateCount,
      invalidCandidateCount,
      anomalousCandidateCount,
    });

    const record = {
      id: crypto.randomUUID(),
      batchId,
      batch_id: batchId,
      bankCode,
      bank_code: bankCode,
      sourceId,
      source_id: sourceId,
      sourceUrl,
      source_url: sourceUrl,
      sourceType,
      source_type: sourceType,
      sourceContentHash,
      source_content_hash: sourceContentHash,
      fetchedAt,
      fetched_at: fetchedAt,
      parserId,
      parser_id: parserId,
      parserVersion,
      parser_version: parserVersion,
      candidateCount,
      candidate_count: candidateCount,
      validCandidateCount,
      valid_candidate_count: validCandidateCount,
      invalidCandidateCount,
      invalid_candidate_count: invalidCandidateCount,
      anomalousCandidateCount,
      anomalous_candidate_count: anomalousCandidateCount,
      effectiveFrom: effectiveFrom || null,
      effective_from: effectiveFrom || null,
      attestationStatus: ATTESTATION_STATUS.PENDING,
      attestation_status: ATTESTATION_STATUS.PENDING,
      attestedAt: null,
      attested_at: null,
      attestedBy: null,
      attested_by: null,
      rejectionReason: null,
      rejection_reason: null,
      promotionStatus: PROMOTION_STATUS.UNPROMOTED,
      promotion_status: PROMOTION_STATUS.UNPROMOTED,
      promotedAt: null,
      promoted_at: null,
      promotedBy: null,
      promoted_by: null,
      promotedCount: 0,
      promoted_count: 0,
      notes,
      metadata: {
        eligibility,
        validationSummary,
        anomalySummary,
      },
      createdAt: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    // Store candidates in registry
    this._inMemoryCandidates.set(batchId, candidates);
    this._inMemoryAttestations.set(record.id, record);

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin.from('baseline_source_attestations').insert([{
          id: record.id,
          batch_id: record.batchId,
          bank_code: record.bankCode,
          source_id: record.sourceId,
          source_url: record.sourceUrl,
          source_type: record.sourceType,
          source_content_hash: record.sourceContentHash,
          fetched_at: record.fetchedAt,
          parser_id: record.parserId,
          parser_version: record.parserVersion,
          candidate_count: record.candidateCount,
          valid_candidate_count: record.validCandidateCount,
          invalid_candidate_count: record.invalidCandidateCount,
          anomalous_candidate_count: record.anomalousCandidateCount,
          effective_from: record.effectiveFrom,
          attestation_status: record.attestationStatus,
          notes: record.notes,
          metadata: record.metadata,
        }]);
      } catch (err) {
        this.logger.warn(`Failed to persist baseline attestation to Supabase: ${err.message}`);
      }
    }

    return record;
  }

  /**
   * Attests a baseline batch by an authorized administrator.
   */
  async attestBaseline({ attestationId, adminUserId, notes = '' }) {
    if (!attestationId) throw new Error('attestationId is required');
    if (!adminUserId) throw new Error('adminUserId is required');

    const attestation = await this.getAttestationById(attestationId);
    if (!attestation) {
      throw new Error(`Baseline attestation not found: ${attestationId}`);
    }

    if (attestation.attestationStatus === ATTESTATION_STATUS.REJECTED) {
      throw new Error(`Cannot attest rejected baseline: ${attestation.rejectionReason || 'Rejected'}`);
    }
    if (attestation.attestationStatus === ATTESTATION_STATUS.SUPERSEDED) {
      throw new Error('Cannot attest superseded baseline');
    }

    // Verify strict attestation eligibility
    const eligibility = this.evaluateAttestationEligibility(attestation);
    if (!eligibility.eligible) {
      throw new Error(`Baseline attestation failed integrity requirements: ${eligibility.issues.join('; ')}`);
    }

    const now = new Date().toISOString();
    attestation.attestationStatus = ATTESTATION_STATUS.ATTESTED;
    attestation.attestation_status = ATTESTATION_STATUS.ATTESTED;
    attestation.attestedAt = now;
    attestation.attested_at = now;
    attestation.attestedBy = adminUserId;
    attestation.attested_by = adminUserId;
    attestation.notes = notes || attestation.notes;
    attestation.updatedAt = now;
    attestation.updated_at = now;

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin
          .from('baseline_source_attestations')
          .update({
            attestation_status: ATTESTATION_STATUS.ATTESTED,
            attested_at: now,
            attested_by: adminUserId,
            notes: attestation.notes,
            updated_at: now,
          })
          .eq('id', attestationId);
      } catch (err) {
        this.logger.warn(`Failed to update baseline attestation in DB: ${err.message}`);
      }
    }

    return attestation;
  }

  /**
   * Rejects a baseline batch by an administrator.
   */
  async rejectBaseline({ attestationId, adminUserId, rejectionReason = 'Administrative rejection', notes = '' }) {
    if (!attestationId) throw new Error('attestationId is required');
    if (!adminUserId) throw new Error('adminUserId is required');

    const attestation = await this.getAttestationById(attestationId);
    if (!attestation) {
      throw new Error(`Baseline attestation not found: ${attestationId}`);
    }

    const now = new Date().toISOString();
    attestation.attestationStatus = ATTESTATION_STATUS.REJECTED;
    attestation.attestation_status = ATTESTATION_STATUS.REJECTED;
    attestation.rejectionReason = rejectionReason;
    attestation.rejection_reason = rejectionReason;
    attestation.notes = notes || attestation.notes;
    attestation.updatedAt = now;
    attestation.updated_at = now;

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin
          .from('baseline_source_attestations')
          .update({
            attestation_status: ATTESTATION_STATUS.REJECTED,
            rejection_reason: rejectionReason,
            notes: attestation.notes,
            updated_at: now,
          })
          .eq('id', attestationId);
      } catch (err) {
        this.logger.warn(`Failed to reject baseline attestation in DB: ${err.message}`);
      }
    }

    return attestation;
  }

  /**
   * Safely promotes candidates in an attested baseline batch.
   */
  async promoteBaseline({ attestationId, adminUserId, dryRun = false, isCallable }) {
    if (!attestationId) throw new Error('attestationId is required');
    if (!adminUserId) throw new Error('adminUserId is required');

    const filterValue = normalizeIsCallableFilter(isCallable);

    const attestation = await this.getAttestationById(attestationId);
    if (!attestation) {
      throw new Error(`Baseline attestation not found: ${attestationId}`);
    }

    // 1. Verify attestation status
    if (attestation.attestationStatus !== ATTESTATION_STATUS.ATTESTED) {
      throw new Error(`Cannot promote baseline with status "${attestation.attestationStatus}". Baseline must be ATTESTED first.`);
    }

    // 2. Idempotency Check: If already fully promoted and not dry-run, return safe idempotent result
    if (attestation.promotionStatus === PROMOTION_STATUS.PROMOTED && !dryRun) {
      return {
        success: true,
        alreadyPromoted: true,
        attestationId,
        batchId: attestation.batchId,
        message: 'Baseline batch has already been promoted',
        promotedCount: attestation.promotedCount,
        reviewCount: 0,
        invalidCount: 0,
      };
    }

    // 3. Load all candidates for this batch
    const allBatchCandidates = await this.getCandidatesForBatch(attestation.batchId, attestation.bankCode, attestation.sourceContentHash);
    if (allBatchCandidates.length === 0) {
      throw new Error(`No staged candidates found for batch "${attestation.batchId}"`);
    }

    // 4. Verify hash and parser binding
    for (const c of allBatchCandidates) {
      if (c.sourceContentHash !== attestation.sourceContentHash) {
        throw new Error(`Candidate hash mismatch: expected "${attestation.sourceContentHash}", found "${c.sourceContentHash}"`);
      }
      if (c.parserVersion !== attestation.parserVersion) {
        throw new Error(`Candidate parser version mismatch: expected "${attestation.parserVersion}", found "${c.parserVersion}"`);
      }
    }

    // 5. Filter candidates if isCallable filter was provided
    let candidatesToEvaluate = allBatchCandidates;
    if (filterValue !== null) {
      candidatesToEvaluate = allBatchCandidates.filter(c => isCandidateCallable(c) === filterValue);
    }

    const activeRates = await this.promotionService._getActiveVerifiedRates(attestation.bankCode);
    const results = {
      attestationId,
      batchId: attestation.batchId,
      bankCode: attestation.bankCode,
      totalCandidates: candidatesToEvaluate.length,
      totalBatchCandidates: allBatchCandidates.length,
      promotedCount: 0,
      reviewCount: 0,
      invalidCount: 0,
      dryRun: Boolean(dryRun),
      promotedRates: [],
      inReviewCandidates: [],
      invalidCandidates: [],
    };

    // 6. Evaluate and promote each candidate through Phase 3A Policy
    for (const candidate of candidatesToEvaluate) {
      // Skip already promoted candidates safely
      if (candidate.stagingStatus === 'PROMOTED' || candidate.staging_status === 'PROMOTED') {
        continue;
      }

      // Direct validation check
      if (candidate.validationStatus === 'INVALID') {
        candidate.stagingStatus = 'INVALID';
        candidate.staging_status = 'INVALID';
        results.invalidCount++;
        results.invalidCandidates.push(candidate);
        continue;
      }

      // Compute diff
      const diff = this.diffEngine.diffCandidate(candidate, activeRates);

      // Evaluate policy with context: isBaselineAttested: true
      const policyResult = this.policyEngine.evaluateCandidate(candidate, diff, {
        isBaselineAttested: true,
        httpStatus: 200,
        fetchStatus: 'FIRST_SEEN',
        parserSuccess: true,
        sourceContentHash: attestation.sourceContentHash,
        sourceUrl: attestation.sourceUrl,
      });

      if (!policyResult.eligibleForAutoPromotion) {
        // Candidate failed one of the other safety checks
        candidate.stagingStatus = 'IN_REVIEW';
        candidate.staging_status = 'IN_REVIEW';
        results.reviewCount++;
        results.inReviewCandidates.push({
          candidate,
          reason: policyResult.decisionReason,
        });
        continue;
      }

      if (dryRun) {
        results.promotedCount++;
        results.promotedRates.push({
          candidateId: candidate.id || candidate.candidateId,
          tenure: candidate.tenureLabel,
          rate: candidate.interestRate,
          simulated: true,
        });
        continue;
      }

      // Live Promotion through PromotionService
      const promoRes = await this.promotionService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: adminUserId,
        reason: `Initial official baseline promotion for ${attestation.batchId}`,
        activeVerifiedRates: activeRates,
        context: { isBaselineAttested: true, batchId: attestation.batchId },
      });

      if (promoRes.promoted) {
        results.promotedCount++;
        results.promotedRates.push(promoRes.newVerifiedRate);
        candidate.stagingStatus = 'PROMOTED';
        candidate.staging_status = 'PROMOTED';
        // Keep activeRates updated for sequential candidate diffs
        activeRates.push(promoRes.newVerifiedRate);

        if (isSupabaseAvailable() && supabaseAdmin && candidate.id) {
          try {
            await supabaseAdmin
              .from('staged_rate_candidates')
              .update({
                staging_status: 'PROMOTED',
                promoted_rate_id: promoRes.newVerifiedRate?.id,
                promoted_at: new Date().toISOString(),
                promoted_by: adminUserId,
              })
              .eq('id', candidate.id);
          } catch (err) {
            this.logger.warn(`Failed to update staged candidate status in DB: ${err.message}`);
          }
        }
      } else {
        results.reviewCount++;
        results.inReviewCandidates.push({
          candidate,
          reason: promoRes.reason,
        });
      }
    }

    // 7. Update Attestation Promotion State (calculated against COMPLETE batch)
    if (!dryRun) {
      const now = new Date().toISOString();
      const totalBatchCount = allBatchCandidates.length;
      const totalPromotedInBatch = allBatchCandidates.filter(c =>
        c.stagingStatus === 'PROMOTED' || c.staging_status === 'PROMOTED'
      ).length;

      let newPromotionStatus = PROMOTION_STATUS.UNPROMOTED;
      if (totalPromotedInBatch === totalBatchCount && totalBatchCount > 0) {
        newPromotionStatus = PROMOTION_STATUS.PROMOTED;
      } else if (totalPromotedInBatch > 0) {
        newPromotionStatus = PROMOTION_STATUS.PARTIALLY_PROMOTED;
      }

      attestation.promotionStatus = newPromotionStatus;
      attestation.promotion_status = newPromotionStatus;
      attestation.promotedAt = now;
      attestation.promoted_at = now;
      attestation.promotedBy = adminUserId;
      attestation.promoted_by = adminUserId;
      attestation.promotedCount = totalPromotedInBatch;
      attestation.promoted_count = totalPromotedInBatch;
      attestation.updatedAt = now;
      attestation.updated_at = now;

      results.totalPromotedInBatch = totalPromotedInBatch;
      results.promotionStatus = newPromotionStatus;

      if (isSupabaseAvailable() && supabaseAdmin) {
        try {
          await supabaseAdmin
            .from('baseline_source_attestations')
            .update({
              promotion_status: newPromotionStatus,
              promoted_at: now,
              promoted_by: adminUserId,
              promoted_count: totalPromotedInBatch,
              updated_at: now,
            })
            .eq('id', attestationId);
        } catch (err) {
          this.logger.warn(`Failed to update baseline promotion status in DB: ${err.message}`);
        }
      }
    } else {
      results.promotionStatus = attestation.promotionStatus;
    }

    return results;
  }

  /**
   * Helper: Get attestation by ID.
   */
  async getAttestationById(id) {
    if (this._inMemoryAttestations.has(id)) {
      return this._inMemoryAttestations.get(id);
    }

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        const { data } = await supabaseAdmin
          .from('baseline_source_attestations')
          .select('*')
          .eq('id', id)
          .maybeSingle();

        if (data) {
          const mapped = {
            id: data.id,
            batchId: data.batch_id,
            bankCode: data.bank_code,
            sourceId: data.source_id,
            sourceUrl: data.source_url,
            sourceType: data.source_type,
            sourceContentHash: data.source_content_hash,
            fetchedAt: data.fetched_at,
            parserId: data.parser_id,
            parserVersion: data.parser_version,
            candidateCount: data.candidate_count,
            validCandidateCount: data.valid_candidate_count,
            invalidCandidateCount: data.invalid_candidate_count,
            anomalousCandidateCount: data.anomalous_candidate_count,
            effectiveFrom: data.effective_from,
            attestationStatus: data.attestation_status,
            attestedAt: data.attested_at,
            attestedBy: data.attested_by,
            rejectionReason: data.rejection_reason,
            promotionStatus: data.promotion_status,
            promotedAt: data.promoted_at,
            promotedBy: data.promoted_by,
            promotedCount: data.promoted_count,
            notes: data.notes,
            metadata: data.metadata,
          };
          this._inMemoryAttestations.set(id, mapped);
          return mapped;
        }
      } catch {
        return null;
      }
    }

    return null;
  }

  /**
   * Helper: Get attestation by batch ID.
   */
  async getAttestationByBatchId(batchId) {
    for (const item of this._inMemoryAttestations.values()) {
      if (item.batchId === batchId || item.batch_id === batchId) {
        return item;
      }
    }

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        const { data } = await supabaseAdmin
          .from('baseline_source_attestations')
          .select('*')
          .eq('batch_id', batchId)
          .maybeSingle();

        if (data) {
          return this.getAttestationById(data.id);
        }
      } catch {
        return null;
      }
    }

    return null;
  }

  /**
   * Helper: List all baseline attestations.
   */
  async listAttestations(filters = {}) {
    const list = Array.from(this._inMemoryAttestations.values());
    let filtered = list;

    if (filters.bankCode) {
      filtered = filtered.filter(a => a.bankCode === filters.bankCode || a.bank_code === filters.bankCode);
    }
    if (filters.status) {
      filtered = filtered.filter(a => a.attestationStatus === filters.status || a.attestation_status === filters.status);
    }

    return filtered;
  }

  /**
   * Helper: Get candidates for a batch.
   */
  async getCandidatesForBatch(batchId, bankCode, sourceContentHash) {
    if (this._inMemoryCandidates.has(batchId)) {
      return this._inMemoryCandidates.get(batchId);
    }

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        const { data } = await supabaseAdmin
          .from('staged_rate_candidates')
          .select('*')
          .eq('bank_code', bankCode)
          .eq('source_content_hash', sourceContentHash);

        if (Array.isArray(data) && data.length > 0) {
          return data;
        }
      } catch {
        return [];
      }
    }

    return [];
  }
}

module.exports = {
  BaselineAttestationService,
  ATTESTATION_STATUS,
  PROMOTION_STATUS,
  ALLOWED_OFFICIAL_DOMAINS,
  isOfficialBankDomain,
  normalizeIsCallableFilter,
  isCandidateCallable,
};
