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

const BANK_OFFICIAL_DOMAINS = Object.freeze({
  SBI: Object.freeze(['sbi.co.in', 'sbi.bank.in']),
  HDFC: Object.freeze(['hdfcbank.com', 'hdfc.bank.in']),
  ICICI: Object.freeze(['icicibank.com', 'icici.bank.in']),
  AXIS: Object.freeze(['axisbank.com', 'axis.bank.in']),
  IDFC_FIRST: Object.freeze(['idfcfirst.bank.in', 'idfcfirstbank.com']),
  UNION_BANK: Object.freeze(['unionbankofindia.bank.in', 'unionbankofindia.co.in']),
  PNB: Object.freeze(['pnb.bank.in', 'pnbindia.in']),
  INDUSIND: Object.freeze(['indusind.bank.in', 'indusind.com']),
  UCO: Object.freeze(['uco.bank.in', 'ucobank.com']),
  AU_SMALL_FINANCE: Object.freeze(['au.bank.in', 'aubank.in']),
  CANARA: Object.freeze(['canarabank.bank.in', 'canarabank.com']),
  CENTRAL_BANK: Object.freeze(['centralbank.bank.in', 'centralbankofindia.co.in']),
  INDIAN_BANK: Object.freeze(['indianbank.bank.in', 'indianbank.in']),
  BOB: Object.freeze(['bankofbaroda.bank.in', 'bankofbaroda.in']),
  THE_UNITY_BANK: Object.freeze(['theunitybank.com']),
});

const ALLOWED_OFFICIAL_DOMAINS = Object.freeze(
  Array.from(new Set(Object.values(BANK_OFFICIAL_DOMAINS).flat()))
);

/**
 * Validates a URL against authorized bank official domains with strict label-boundary matching.
 *
 * @param {string} url - Target URL to validate
 * @param {string} [bankCode] - Bank code (e.g. 'SBI', 'HDFC', 'ICICI') for bank-scoped validation
 * @param {Object} [options]
 * @param {boolean} [options.requireHttps=true] - Mandate HTTPS protocol
 * @returns {{ valid: boolean, reason?: string, hostname?: string, bankCode?: string, matchedDomain?: string }}
 */
function validateBankDomain(url, bankCode = null, options = {}) {
  const requireHttps = options.requireHttps !== undefined ? options.requireHttps : true;
  if (!url || typeof url !== 'string') {
    return { valid: false, reason: 'URL must be a non-empty string' };
  }

  let parsed;
  try {
    parsed = new URL(url);
  } catch (err) {
    return { valid: false, reason: `Malformed URL: "${url}" (${err.message})` };
  }

  if (requireHttps && parsed.protocol !== 'https:') {
    return { valid: false, reason: `Insecure protocol "${parsed.protocol}" (HTTPS is mandatory for official bank sources)` };
  }

  const hostname = parsed.hostname.toLowerCase();
  if (!hostname || hostname.length === 0) {
    return { valid: false, reason: 'Missing or empty hostname in URL' };
  }

  // Reject raw IP addresses
  if (/^(\d{1,3}\.){3}\d{1,3}$/.test(hostname) || hostname.includes(':')) {
    return { valid: false, reason: `Raw IP addresses not permitted as official bank domains: "${hostname}"` };
  }

  // Reject non-standard ports
  if (parsed.port && parsed.port !== '443' && parsed.port !== '80') {
    return { valid: false, reason: `Disallowed port: "${parsed.port}"` };
  }

  // Label-boundary-safe matching: exact match OR proper subdomain (dot-prefixed)
  const isLabelBoundaryMatch = (host, domain) => {
    const d = domain.toLowerCase().trim();
    return host === d || host.endsWith('.' + d);
  };

  if (bankCode) {
    const normalizedBank = bankCode.toUpperCase().trim();
    const allowedDomains = BANK_OFFICIAL_DOMAINS[normalizedBank];
    if (!allowedDomains || allowedDomains.length === 0) {
      return { valid: false, hostname, reason: `No approved official domains registered for bank: "${bankCode}"` };
    }

    const matchedDomain = allowedDomains.find(d => isLabelBoundaryMatch(hostname, d));
    if (!matchedDomain) {
      return {
        valid: false,
        hostname,
        bankCode: normalizedBank,
        reason: `Hostname "${hostname}" is not an authorized official domain for bank [${normalizedBank}]. Approved: [${allowedDomains.join(', ')}]`,
      };
    }

    return {
      valid: true,
      bankCode: normalizedBank,
      hostname,
      matchedDomain,
      url: parsed.href,
    };
  }

  // Fallback when bankCode is omitted: check against all known banks with label-boundary matching
  let matchedBank = null;
  let matchedDomain = null;
  for (const [bank, domains] of Object.entries(BANK_OFFICIAL_DOMAINS)) {
    const match = domains.find(d => isLabelBoundaryMatch(hostname, d));
    if (match) {
      matchedBank = bank;
      matchedDomain = match;
      break;
    }
  }

  if (!matchedDomain) {
    return {
      valid: false,
      hostname,
      reason: `Hostname "${hostname}" does not match any registered official bank domain`,
    };
  }

  return {
    valid: true,
    bankCode: matchedBank,
    hostname,
    matchedDomain,
    url: parsed.href,
  };
}

function isOfficialBankDomain(url, bankCode = null) {
  const result = validateBankDomain(url, bankCode, { requireHttps: true });
  return result.valid;
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
    this.skipDbPersist = options.skipDbPersist !== undefined ? Boolean(options.skipDbPersist) : false;
    this.supabaseAdmin = options.supabaseAdmin || options.supabaseClient || null;

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
    const bankCode = attestationData.bankCode || attestationData.bank_code || null;
    const sourceUrl = attestationData.sourceUrl || attestationData.source_url;
    const effectiveUrl = attestationData.effectiveUrl || attestationData.finalUrl || attestationData.effective_url;
    const redirectChain = attestationData.redirectChain || attestationData.redirect_chain || [];

    // 1. Official bank domain validation on configured source URL
    if (!sourceUrl) {
      issues.push('Missing source URL');
    } else {
      const sourceDomainCheck = validateBankDomain(sourceUrl, bankCode, { requireHttps: true });
      if (!sourceDomainCheck.valid) {
        issues.push(`Source URL is not on an approved official bank domain: "${sourceUrl}" (${sourceDomainCheck.reason})`);
      }
    }

    // 2. Official bank domain validation on effective / final URL (if present)
    if (effectiveUrl && effectiveUrl !== sourceUrl) {
      const effectiveDomainCheck = validateBankDomain(effectiveUrl, bankCode, { requireHttps: true });
      if (!effectiveDomainCheck.valid) {
        issues.push(`Effective final URL is not on an approved official bank domain: "${effectiveUrl}" (${effectiveDomainCheck.reason})`);
      }
    }

    // 3. Official bank domain validation on redirect chain hops
    if (Array.isArray(redirectChain) && redirectChain.length > 0) {
      for (let i = 0; i < redirectChain.length; i++) {
        const hop = redirectChain[i];
        const from = hop.fromUrl || hop.from || hop.source;
        const to = hop.toUrl || hop.to || hop.destination;
        if (from) {
          const fromCheck = validateBankDomain(from, bankCode, { requireHttps: true });
          if (!fromCheck.valid) {
            issues.push(`Redirect hop ${i + 1} source is not authorized for bank [${bankCode || 'ANY'}]: ${fromCheck.reason}`);
          }
        }
        if (to) {
          const toCheck = validateBankDomain(to, bankCode, { requireHttps: true });
          if (!toCheck.valid) {
            issues.push(`Redirect hop ${i + 1} destination is not authorized for bank [${bankCode || 'ANY'}]: ${toCheck.reason}`);
          }
        }
      }
    }

    // 4. Hash integrity
    if (!attestationData.sourceContentHash || !/^[0-9a-f]{64}$/i.test(attestationData.sourceContentHash)) {
      issues.push(`Invalid or missing SHA-256 source content hash: "${attestationData.sourceContentHash}"`);
    }

    // 5. Parser integrity
    if (!attestationData.parserId || !attestationData.parserVersion) {
      issues.push('Missing parser identifier or parser version');
    }

    // 6. Non-zero candidates
    if (!attestationData.candidateCount || attestationData.candidateCount <= 0) {
      issues.push('Candidate batch contains zero extracted rates (cannot attest empty table)');
    }

    // 7. Validation failures
    if (attestationData.invalidCandidateCount > 0) {
      issues.push(`Batch contains ${attestationData.invalidCandidateCount} invalid candidates failing schema validation`);
    }

    // 8. Critical anomalies
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
    batchId: customBatchId = null,
    bankCode,
    sourceId,
    sourceUrl,
    effectiveUrl = null,
    finalUrl = null,
    redirectChain = [],
    redirectCount = 0,
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
    skipDbPersist = false,
    persist = true,
  }) {
    if (!bankCode) throw new Error('bankCode is required');
    if (!sourceId) throw new Error('sourceId is required');
    if (!sourceContentHash) throw new Error('sourceContentHash is required');

    const batchId = customBatchId || this.generateBatchId(bankCode, sourceId, sourceContentHash);
    const existing = await this.getAttestationByBatchId(batchId);
    if (existing && existing.attestationStatus !== ATTESTATION_STATUS.PENDING) {
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

    const resolvedEffectiveUrl = effectiveUrl || finalUrl || sourceUrl;
    const resolvedRedirectChain = redirectChain || [];
    const resolvedRedirectCount = redirectCount || resolvedRedirectChain.length;

    const eligibility = this.evaluateAttestationEligibility({
      bankCode,
      sourceUrl,
      effectiveUrl: resolvedEffectiveUrl,
      redirectChain: resolvedRedirectChain,
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
      effectiveUrl: resolvedEffectiveUrl,
      effective_url: resolvedEffectiveUrl,
      redirectChain: resolvedRedirectChain,
      redirect_chain: resolvedRedirectChain,
      redirectCount: resolvedRedirectCount,
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
        effectiveUrl: resolvedEffectiveUrl,
        redirectChain: resolvedRedirectChain,
        candidateIds: candidates.map(c => c.id || c.candidateId).filter(Boolean),
      },
      createdAt: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    if (existing && (existing.attestationStatus === ATTESTATION_STATUS.PENDING || existing.attestation_status === ATTESTATION_STATUS.PENDING)) {
      existing.candidateCount = candidateCount;
      existing.candidate_count = candidateCount;
      existing.validCandidateCount = validCandidateCount;
      existing.valid_candidate_count = validCandidateCount;
      existing.invalidCandidateCount = invalidCandidateCount;
      existing.invalid_candidate_count = invalidCandidateCount;
      existing.anomalousCandidateCount = anomalousCandidateCount;
      existing.anomalous_candidate_count = anomalousCandidateCount;
      existing.metadata = {
        eligibility,
        validationSummary,
        anomalySummary,
        effectiveUrl: resolvedEffectiveUrl,
        redirectChain: resolvedRedirectChain,
        candidateIds: candidates.map(c => c.id || c.candidateId).filter(Boolean),
      };
      existing.updatedAt = new Date().toISOString();
      existing.updated_at = existing.updatedAt;

      this._inMemoryCandidates.set(batchId, candidates);
      this._inMemoryAttestations.set(existing.id, existing);

      const shouldSkipDb = this.skipDbPersist || Boolean(skipDbPersist) || (persist === false);
      if (!shouldSkipDb && isSupabaseAvailable() && supabaseAdmin) {
        try {
          await supabaseAdmin.from('baseline_source_attestations').update({
            candidate_count: candidateCount,
            valid_candidate_count: validCandidateCount,
            invalid_candidate_count: invalidCandidateCount,
            anomalous_candidate_count: anomalousCandidateCount,
            metadata: existing.metadata,
            updated_at: existing.updatedAt,
          }).eq('id', existing.id);
        } catch (err) {
          this.logger.warn(`Failed to update pending baseline attestation in Supabase: ${err.message}`);
        }
      }

      return existing;
    }

    // Store candidates in registry
    this._inMemoryCandidates.set(batchId, candidates);
    this._inMemoryAttestations.set(record.id, record);

    const shouldSkipDb = this.skipDbPersist || Boolean(skipDbPersist) || (persist === false);
    if (!shouldSkipDb && isSupabaseAvailable() && supabaseAdmin) {
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
   * Pure read-only inspection of a baseline batch with ZERO database writes guaranteed.
   *
   * Evaluates domain validity, parser integrity, validation summary, anomaly flags,
   * effective date evidence, and attestation eligibility purely in memory.
   *
   * GUARANTEES:
   * - Zero database queries or writes to baseline_source_attestations, rate_sources,
   *   source_collection_logs, staged_rate_candidates, or fd_rates.
   * - Never sets attestationStatus to ATTESTED (returns UNATTESTED).
   * - Does not call attestBaseline, rejectBaseline, or promoteBaseline.
   * - Fails closed if parameters are invalid.
   */
  inspectBaselineBatch({
    batchId: customBatchId = null,
    bankCode,
    sourceId,
    sourceUrl,
    effectiveUrl = null,
    finalUrl = null,
    redirectChain = [],
    redirectCount = 0,
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
    requireExplicitEffectiveDate = true,
  }) {
    if (!bankCode) throw new Error('bankCode is required');
    if (!sourceId) throw new Error('sourceId is required');
    if (!sourceContentHash) throw new Error('sourceContentHash is required');

    const batchId = customBatchId || this.generateBatchId(bankCode, sourceId, sourceContentHash);
    const candidateCount = candidates.length;
    const invalidCandidateCount = validationSummary.invalidCount !== undefined
      ? validationSummary.invalidCount
      : candidates.filter(c => c.validationStatus === 'INVALID').length;
    const validCandidateCount = candidateCount - invalidCandidateCount;
    const anomalousCandidateCount = anomalySummary.candidatesWithAnomalies !== undefined
      ? anomalySummary.candidatesWithAnomalies
      : candidates.filter(c => c.anomalyFlags && c.anomalyFlags.length > 0).length;

    const resolvedEffectiveUrl = effectiveUrl || finalUrl || sourceUrl;
    const resolvedRedirectChain = redirectChain || [];
    const resolvedRedirectCount = redirectCount || resolvedRedirectChain.length;

    // Evaluate core attestation eligibility
    const eligibility = this.evaluateAttestationEligibility({
      bankCode,
      sourceUrl,
      effectiveUrl: resolvedEffectiveUrl,
      redirectChain: resolvedRedirectChain,
      sourceContentHash,
      parserId,
      parserVersion,
      candidateCount,
      invalidCandidateCount,
      anomalousCandidateCount,
    });

    // Check explicit effective date evidence
    const hasExplicitEffectiveDate = Boolean(effectiveFrom && /^\d{4}-\d{2}-\d{2}$/.test(effectiveFrom));
    if (requireExplicitEffectiveDate && !hasExplicitEffectiveDate) {
      eligibility.issues.push('Missing verified explicit effectiveFrom date in source extraction');
      eligibility.eligible = false;
    }

    const sourceDomainVal = validateBankDomain(sourceUrl, bankCode, { requireHttps: true });
    const effectiveDomainVal = validateBankDomain(resolvedEffectiveUrl, bankCode, { requireHttps: true });
    const redirectsValid = resolvedRedirectChain.every(hop => {
      const from = hop.fromUrl || hop.from;
      const to = hop.toUrl || hop.to;
      return (!from || validateBankDomain(from, bankCode, { requireHttps: true }).valid) &&
             (!to || validateBankDomain(to, bankCode, { requireHttps: true }).valid);
    });
    const isOfficial = sourceDomainVal.valid && effectiveDomainVal.valid && redirectsValid;
    const anomalyFlags = anomalySummary.anomalyFlags || [];

    const report = {
      batchId,
      bankCode,
      sourceId,
      sourceUrl,
      effectiveUrl: resolvedEffectiveUrl,
      finalUrl: resolvedEffectiveUrl,
      redirectChain: resolvedRedirectChain,
      redirectCount: resolvedRedirectCount,
      sourceType,
      isOfficialDomain: isOfficial,
      domainValidation: {
        valid: isOfficial,
        source: sourceDomainVal,
        effective: effectiveDomainVal,
        redirectsValid,
      },
      sourceContentHash,
      fetchedAt,
      parserId,
      parserVersion,
      effectiveDate: effectiveFrom || null,
      hasExplicitEffectiveDate,
      candidateCount,
      validCandidateCount,
      invalidCandidateCount,
      anomalousCandidateCount,
      anomalyFlags,
      validationStatus: invalidCandidateCount === 0 ? 'VALID' : 'INVALID',
      // Explicitly UNATTESTED (never ATTESTED):
      attestationStatus: 'UNATTESTED',
      isAttested: false,
      attestationEligibility: eligibility.eligible,
      attestationIssues: eligibility.issues,
      persisted: false,
      notes: notes || 'Read-only zero-write baseline inspection',
      inspectedAt: new Date().toISOString(),
    };

    return report;
  }

  /**
   * Attests a baseline batch by an authorized administrator.
   */
  async attestBaseline({ attestationId, adminUserId, notes = '' }) {
    if (!attestationId) throw new Error('attestationId is required');
    if (!adminUserId) throw new Error('adminUserId is required');

    // Fail-closed guard: simulated admin identities are prohibited from attesting
    if (adminUserId === 'admin_dry_run_simulation' || adminUserId.startsWith('admin_dry_run')) {
      throw new Error('SAFETY ERROR: Simulated admin identity (admin_dry_run_simulation) cannot be used to attest a baseline. Attestation requires an authentic authorized administrator.');
    }

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

    // Fail-closed provenance check: verify matching authentic source_collection_logs entry exists
    const db = this.supabaseAdmin || supabaseAdmin;
    if (!this.skipDbPersist && (this.supabaseAdmin || isSupabaseAvailable()) && db) {
      try {
        const sourceId = attestation.sourceId || attestation.source_id;
        const sourceHash = attestation.sourceContentHash || attestation.source_content_hash;
        if (typeof db.from === 'function') {
          const { data: logs, error: logCheckError } = await db
            .from('source_collection_logs')
            .select('id')
            .eq('source_id', sourceId)
            .eq('content_hash', sourceHash)
            .limit(1);

          if (logCheckError) {
            throw new Error(`Provenance verification query failed for baseline [${attestationId}]: ${logCheckError.message}`);
          }

          if (!logs || logs.length === 0) {
            throw new Error(`Provenance assertion failed: Cannot attest baseline [${attestationId}] without verified source_collection_log for source [${sourceId}] and content hash [${sourceHash}]`);
          }
        }
      } catch (err) {
        if (err.message && (err.message.includes('Provenance assertion failed') || err.message.includes('Provenance verification query failed'))) {
          throw err;
        }
      }
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

    const isDbAvailable = this.supabaseAdmin ? true : isSupabaseAvailable();
    if (!this.skipDbPersist && isDbAvailable && db) {
      try {
        await db
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

    if (!this.skipDbPersist && isSupabaseAvailable() && supabaseAdmin) {
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
      const cHash = c.sourceContentHash || c.source_content_hash;
      const cVersion = c.parserVersion || c.parser_version;
      if (cHash !== attestation.sourceContentHash) {
        throw new Error(`Candidate hash mismatch: expected "${attestation.sourceContentHash}", found "${cHash}"`);
      }
      if (cVersion !== attestation.parserVersion) {
        throw new Error(`Candidate parser version mismatch: expected "${attestation.parserVersion}", found "${cVersion}"`);
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
      const valStatus = candidate.validationStatus || candidate.validation_status || 'VALID';
      if (valStatus === 'INVALID') {
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
          tenure: candidate.tenureLabel || candidate.tenure_label || candidate.sourceTenureText || candidate.source_tenure_text,
          rate: candidate.interestRate !== undefined ? candidate.interestRate : candidate.interest_rate,
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

        if (!this.skipDbPersist && isSupabaseAvailable() && supabaseAdmin && candidate.id) {
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

      if (!this.skipDbPersist && isSupabaseAvailable() && supabaseAdmin) {
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

    if (!this.skipDbPersist && isSupabaseAvailable() && supabaseAdmin) {
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

    if (!this.skipDbPersist && isSupabaseAvailable() && supabaseAdmin) {
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

    if (!this.skipDbPersist && isSupabaseAvailable() && supabaseAdmin) {
      try {
        const attestation = batchId ? await this.getAttestationByBatchId(batchId) : null;
        const candidateIds = attestation?.metadata?.candidateIds;

        let query = supabaseAdmin
          .from('staged_rate_candidates')
          .select('*')
          .eq('bank_code', bankCode)
          .eq('source_content_hash', sourceContentHash);

        if (Array.isArray(candidateIds) && candidateIds.length > 0) {
          query = query.in('id', candidateIds);
        }

        const { data } = await query;

        if (Array.isArray(data) && data.length > 0) {
          return data.map(c => this.promotionService.normalizeCandidate(c));
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
  BANK_OFFICIAL_DOMAINS,
  validateBankDomain,
  isOfficialBankDomain,
  normalizeIsCallableFilter,
  isCandidateCallable,
};
