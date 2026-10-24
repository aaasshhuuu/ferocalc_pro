// FeroCalc Verified FD Rate Engine — Safe Promotion Policy Engine
//
// Explicit rules determining whether a staged candidate can be automatically promoted
// to VERIFIED, or must be escalated to human IN_REVIEW, or marked INVALID.
//
// Rules:
// 1. Never assume every successful extraction is safe.
// 2. An automated promotion requires 100% of safety checks to pass.
// 3. Any anomaly or excessive rate delta (> maxAutoPromoteRateDeltaPct) forces IN_REVIEW.
// 4. Invalid candidates are never promoted.

const ALLOWED_SOURCE_DOMAINS = [
  'sbi.co.in',
  'hdfcbank.com',
  'hdfc.bank.in',
  'icicibank.com',
  'axisbank.com',
  'theunitybank.com',
  'idfcfirst.bank.in',
  'unionbankofindia.bank.in',
  'pnb.bank.in',
  'indusind.bank.in',
  'uco.bank.in',
  'ucobank.com',
  'au.bank.in',
  'aubank.in',
  'canarabank.bank.in',
  'canarabank.com',
];

function isOfficialDomain(url) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.toLowerCase().replace(/^www\./, '');
    return ALLOWED_SOURCE_DOMAINS.some(d => host === d || host.endsWith('.' + d));
  } catch {
    return false;
  }
}

const DEFAULT_POLICY_CONFIG = {
  maxAutoPromoteRateDeltaPct: 0.50, // 50 basis points max change for automated promotion
  requireExplicitEffectiveDate: true,
  requireOfficialDomain: true,
};

class PromotionPolicyEngine {
  constructor(customConfig = {}) {
    this.config = { ...DEFAULT_POLICY_CONFIG, ...customConfig };
  }

  /**
   * Evaluates policy compliance for a candidate and its diff result.
   *
   * @param {Object} candidate - Staged rate candidate
   * @param {Object} diffResult - Diff output from RateDiffEngine.diffCandidate()
   * @param {Object} context - Source collection & parser execution metadata
   * @returns {Object} Policy evaluation result
   */
  evaluateCandidate(candidate, diffResult = {}, context = {}) {
    const checks = {};
    const failedReasons = [];

    // 1. Source Fetch Check
    const fetchStatus = context.fetchStatus || candidate.fetchStatus || 'FIRST_SEEN';
    checks.sourceFetchSucceeded = fetchStatus !== 'FETCH_FAILED' && context.httpStatus !== 500 && context.httpStatus !== 0;
    if (!checks.sourceFetchSucceeded) {
      failedReasons.push(`Source fetch failed or returned error HTTP status (${context.httpStatus || 'N/A'})`);
    }

    // 2. Parser Execution Check
    checks.parserSucceeded = Boolean(candidate.parserId && candidate.parserVersion && context.parserSuccess !== false);
    if (!checks.parserSucceeded) {
      failedReasons.push('Parser execution did not complete successfully or parser ID is missing');
    }

    // 3. Data Validation Check
    const isValidationValid = candidate.validationStatus === 'VALID' &&
      (!candidate.validationErrors || candidate.validationErrors.length === 0);
    checks.validationPassed = isValidationValid;
    if (!checks.validationPassed) {
      failedReasons.push(`Candidate failed data validation: ${(candidate.validationErrors || []).join('; ')}`);
    }

    // 4. Source Content Hash Check
    const hash = candidate.sourceContentHash || context.sourceContentHash;
    checks.sourceHashValid = Boolean(hash && /^[0-9a-f]{64}$/i.test(hash));
    if (!checks.sourceHashValid) {
      failedReasons.push(`Invalid or missing sourceContentHash: "${hash}"`);
    }

    // 5. Official Source Domain Check
    const url = candidate.sourceUrl || context.sourceUrl;
    if (this.config.requireOfficialDomain) {
      checks.officialDomain = Boolean(url && isOfficialDomain(url));
      if (!checks.officialDomain) {
        failedReasons.push(`Source URL is not from a registered official bank domain: "${url}"`);
      }
    } else {
      checks.officialDomain = true;
    }

    // 6. Extraction Count Anomaly Check
    const anomalyFlags = candidate.anomalyFlags || [];
    checks.noCountAnomaly = !anomalyFlags.some(f => f.includes('ANOMALY_COUNT_MISMATCH'));
    if (!checks.noCountAnomaly) {
      failedReasons.push('Batch exhibited dramatic candidate count mismatch anomaly');
    }

    // 7. Missing Tenure Anomaly Check
    checks.noMissingTenureAnomaly = !anomalyFlags.some(f => f.includes('ANOMALY_TENURE_DISAPPEARED'));
    if (!checks.noMissingTenureAnomaly) {
      failedReasons.push('Batch exhibited unexpected disappearance of previously active tenures');
    }

    // 8. Effective Date Check
    if (this.config.requireExplicitEffectiveDate) {
      checks.explicitEffectiveDate = Boolean(candidate.effectiveFrom && /^\d{4}-\d{2}-\d{2}$/.test(candidate.effectiveFrom));
      if (!checks.explicitEffectiveDate) {
        failedReasons.push('Candidate does not have a verified, explicitly sourced effectiveFrom date');
      }
    } else {
      checks.explicitEffectiveDate = true;
    }

    // 9. Rate Delta Safety Check
    const diffType = diffResult.diffType || 'NEW';
    if (diffType === 'RATE_CHANGED') {
      const absDelta = diffResult.absDelta !== undefined
        ? diffResult.absDelta
        : Math.abs(Number(diffResult.rateDelta || 0));

      checks.rateDeltaSafe = absDelta <= this.config.maxAutoPromoteRateDeltaPct;
      if (!checks.rateDeltaSafe) {
        failedReasons.push(`Rate change delta (${absDelta.toFixed(2)}%) exceeds automated policy ceiling (${this.config.maxAutoPromoteRateDeltaPct}%)`);
      }
    } else if (diffType === 'NEW') {
      // New rate bucket: requires human verification for safety
      checks.rateDeltaSafe = true;
      // Note: Brand new tenure buckets require review before becoming active,
      // UNLESS part of an officially attested source baseline batch.
      const isAttested = Boolean(context.isBaselineAttested);
      checks.isNotUnreviewedNewBucket = isAttested;
      if (!checks.isNotUnreviewedNewBucket) {
        failedReasons.push('Brand new rate bucket introduced (requires initial human review)');
      }
    } else if (diffType === 'UNRESOLVED_DOMAIN_CONFLICT') {
      checks.rateDeltaSafe = false;
      failedReasons.push(diffResult.details || 'Unresolved domain conflict with active verified rate');
    } else {
      checks.rateDeltaSafe = true;
    }

    // 10. No General Anomaly Flags Check
    checks.noGeneralAnomalies = anomalyFlags.length === 0;
    if (!checks.noGeneralAnomalies) {
      failedReasons.push(`Candidate has active anomaly flags: ${anomalyFlags.join(', ')}`);
    }

    // 11. Special Scheme Qualification Integrity Check
    const rateCategory = (candidate.rateCategory || candidate.rate_category || 'STANDARD').toUpperCase();
    if (rateCategory === 'SPECIAL_SCHEME') {
      const schemeName = candidate.schemeName || candidate.scheme_name;
      const notes = candidate.notes;
      const hasSchemeName = Boolean(schemeName && String(schemeName).trim().length > 0);
      const hasNotes = Boolean(notes && String(notes).trim().length > 0);
      checks.specialSchemeQualified = hasSchemeName && hasNotes;
      if (!checks.specialSchemeQualified) {
        failedReasons.push(
          `Candidate marked as SPECIAL_SCHEME lacks required scheme metadata (schemeName: "${schemeName || ''}", notes: "${notes || ''}")`
        );
      }
    } else {
      const schemeName = candidate.schemeName || candidate.scheme_name;
      checks.specialSchemeQualified = !schemeName;
      if (!checks.specialSchemeQualified) {
        failedReasons.push(
          `Candidate marked as STANDARD cannot have schemeName: "${schemeName}"`
        );
      }
    }

    // Determine final recommended action
    const allPassed = Object.values(checks).every(Boolean);

    let recommendedAction = 'IN_REVIEW';
    if (!checks.validationPassed) {
      recommendedAction = 'INVALID';
    } else if (allPassed) {
      recommendedAction = 'PROMOTE';
    } else {
      recommendedAction = 'IN_REVIEW';
    }

    return {
      eligibleForAutoPromotion: allPassed,
      recommendedAction,
      checks,
      failedReasons,
      decisionReason: allPassed
        ? 'All automated safety policy checks passed successfully'
        : `Escalated to ${recommendedAction}: ${failedReasons.join('; ')}`,
      evaluatedAt: new Date().toISOString(),
    };
  }
}

module.exports = {
  PromotionPolicyEngine,
  DEFAULT_POLICY_CONFIG,
};
