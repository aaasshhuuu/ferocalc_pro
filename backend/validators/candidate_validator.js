// FeroCalc Verified FD Rate Engine — Candidate Validator
//
// Validation rules:
// - Interest rate is numeric and plausible (configurable, not hardcoded 2.5-10.5%)
// - Tenure min/max is valid (minTenure <= maxTenure, positive days)
// - No impossible negative values
// - Customer type is known
// - Duplicate candidates are detected
// - Overlapping candidates are detected
// - Source URL exists and starts with http(s)
// - Source hash exists (64-char SHA-256)
// - Sufficient information to identify rate
// - Parser returning zero rates is treated as parser failure
// - Suspicious extraction counts flagged

'use strict';

const DEFAULT_VALIDATION_CONFIG = {
  minAllowedRate: 0.05,
  maxAllowedRate: 20.0,
  minAllowedTenureDays: 1,
  maxAllowedTenureDays: 36525, // 100 years
  minExpectedCandidateCount: 2,
  maxExpectedCandidateCount: 200,
  allowedCustomerTypes: ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN', 'STAFF', 'NRE', 'NRO'],
};

class CandidateValidator {
  constructor(customConfig = {}) {
    this.config = { ...DEFAULT_VALIDATION_CONFIG, ...customConfig };
  }

  /**
   * Validates an individual candidate record.
   *
   * @param {CandidateRate} candidate
   * @returns {{ isValid: boolean, errors: string[] }}
   */
  validateCandidate(candidate) {
    const errors = [];

    // 1. Bank identification
    if (!candidate.bankCode && !candidate.bankId) {
      errors.push('Missing bank identification (bankId or bankCode)');
    }

    // 2. Source metadata
    if (!candidate.sourceUrl || !/^https?:\/\//i.test(candidate.sourceUrl)) {
      errors.push(`Invalid or missing sourceUrl: "${candidate.sourceUrl}"`);
    }

    if (!candidate.sourceContentHash || !/^[0-9a-f]{64}$/i.test(candidate.sourceContentHash)) {
      errors.push(`Missing or invalid SHA-256 sourceContentHash: "${candidate.sourceContentHash}"`);
    }

    // 3. Customer Type
    if (!candidate.customerType || !this.config.allowedCustomerTypes.includes(candidate.customerType)) {
      errors.push(`Unknown customerType: "${candidate.customerType}"`);
    }

    // 4. Interest Rate Validation
    if (typeof candidate.interestRate !== 'number' || isNaN(candidate.interestRate)) {
      errors.push(`Interest rate must be a valid number, got: ${candidate.interestRate}`);
    } else {
      if (candidate.interestRate < 0) {
        errors.push(`Impossible negative interest rate: ${candidate.interestRate}`);
      } else if (candidate.interestRate < this.config.minAllowedRate) {
        errors.push(`Interest rate ${candidate.interestRate}% is below minimum plausible threshold ${this.config.minAllowedRate}%`);
      } else if (candidate.interestRate > this.config.maxAllowedRate) {
        errors.push(`Interest rate ${candidate.interestRate}% exceeds maximum plausible ceiling ${this.config.maxAllowedRate}%`);
      }
    }

    // 5. Senior citizen rate (if present, must also be valid)
    if (candidate.seniorCitizenRate !== null && candidate.seniorCitizenRate !== undefined) {
      if (typeof candidate.seniorCitizenRate !== 'number' || isNaN(candidate.seniorCitizenRate)) {
        errors.push(`Senior citizen rate must be numeric if present, got: ${candidate.seniorCitizenRate}`);
      } else if (candidate.seniorCitizenRate < 0) {
        errors.push(`Impossible negative senior citizen rate: ${candidate.seniorCitizenRate}`);
      } else if (candidate.seniorCitizenRate > this.config.maxAllowedRate) {
        errors.push(`Senior citizen rate ${candidate.seniorCitizenRate}% exceeds ceiling ${this.config.maxAllowedRate}%`);
      }
    }

    // 6. Tenure Range Validation
    if (!candidate.tenureLabel || !String(candidate.tenureLabel).trim()) {
      errors.push('Missing tenureLabel');
    }

    if (candidate.tenureDomain === 'CALENDAR') {
      if (!candidate.sourceTenureText && !candidate.tenureLabel) {
        errors.push('CALENDAR candidate missing required sourceTenureText / tenureLabel');
      }
      if (candidate.minOperator && !['GTE', 'GT'].includes(candidate.minOperator)) {
        errors.push(`Invalid minOperator: "${candidate.minOperator}"`);
      }
      if (candidate.maxOperator && !['LTE', 'LT'].includes(candidate.maxOperator)) {
        errors.push(`Invalid maxOperator: "${candidate.maxOperator}"`);
      }
      // If minTenureDays / maxTenureDays are provided for backward compatibility, validate them
      if (candidate.minTenureDays !== null && candidate.minTenureDays !== undefined) {
        if (typeof candidate.minTenureDays !== 'number' || candidate.minTenureDays < this.config.minAllowedTenureDays) {
          errors.push(`minTenureDays must be >= ${this.config.minAllowedTenureDays}, got: ${candidate.minTenureDays}`);
        }
        if (typeof candidate.maxTenureDays !== 'number' || candidate.maxTenureDays < candidate.minTenureDays) {
          errors.push(`maxTenureDays (${candidate.maxTenureDays}) must be >= minTenureDays (${candidate.minTenureDays})`);
        }
        if (candidate.maxTenureDays > this.config.maxAllowedTenureDays) {
          errors.push(`maxTenureDays exceeds upper limit of ${this.config.maxAllowedTenureDays}`);
        }
      }
    } else {
      if (typeof candidate.minTenureDays !== 'number' || candidate.minTenureDays < this.config.minAllowedTenureDays) {
        errors.push(`minTenureDays must be >= ${this.config.minAllowedTenureDays}, got: ${candidate.minTenureDays}`);
      }

      if (typeof candidate.maxTenureDays !== 'number' || candidate.maxTenureDays < candidate.minTenureDays) {
        errors.push(`maxTenureDays (${candidate.maxTenureDays}) must be >= minTenureDays (${candidate.minTenureDays})`);
      }

      if (candidate.maxTenureDays > this.config.maxAllowedTenureDays) {
        errors.push(`maxTenureDays exceeds upper limit of ${this.config.maxAllowedTenureDays}`);
      }
    }

    // 7. Special Scheme / Rate Category Integrity
    const rateCategory = (candidate.rateCategory || 'STANDARD').toUpperCase().trim();
    const rawScheme = candidate.schemeName !== undefined && candidate.schemeName !== null ? candidate.schemeName : '';
    const cleanedScheme = String(rawScheme).replace(/[\t\r\n\u00a0\v\f]+/g, ' ').trim();

    if (rateCategory === 'SPECIAL_SCHEME') {
      if (!cleanedScheme) {
        errors.push('Missing required schemeName for candidate marked as SPECIAL_SCHEME');
      }
      if (!candidate.notes || !String(candidate.notes).trim()) {
        errors.push('Missing required qualification notes / footnote for candidate marked as SPECIAL_SCHEME');
      }
    } else if (rateCategory === 'STANDARD') {
      if (cleanedScheme) {
        errors.push(`Candidate marked as STANDARD cannot have schemeName: "${candidate.schemeName}"`);
      }
    } else {
      errors.push(`Invalid rateCategory: "${candidate.rateCategory}". Must be STANDARD or SPECIAL_SCHEME.`);
    }

    // Update candidate validation state
    const isValid = errors.length === 0;
    candidate.validationErrors = [...errors];
    candidate.validationStatus = isValid ? 'VALID' : 'INVALID';
    if (!isValid) {
      candidate.stagingStatus = 'INVALID';
    }

    return { isValid, errors };
  }

  /**
   * Validates an entire batch of candidates, detecting duplicates and overlaps.
   *
   * @param {CandidateRate[]} candidates
   * @param {Object} context
   * @returns {Object} Validation summary
   */
  validateBatch(candidates, context = {}) {
    const summary = {
      total: candidates.length,
      validCount: 0,
      invalidCount: 0,
      duplicateCount: 0,
      overlapCount: 0,
      errors: [],
      warnings: [],
      success: false,
    };

    // 1. Zero-rates check: Treated as parser failure, not valid empty dataset
    if (!candidates || candidates.length === 0) {
      summary.errors.push('Parser returned zero rate candidates (treated as extraction failure)');
      summary.success = false;
      return summary;
    }

    // 2. Suspicious count check
    if (candidates.length < this.config.minExpectedCandidateCount) {
      summary.warnings.push(`Extracted candidate count (${candidates.length}) is below expected minimum (${this.config.minExpectedCandidateCount})`);
    } else if (candidates.length > this.config.maxExpectedCandidateCount) {
      summary.warnings.push(`Extracted candidate count (${candidates.length}) is above expected maximum (${this.config.maxExpectedCandidateCount})`);
    }

    // 3. Individual candidate validation
    for (const candidate of candidates) {
      const res = this.validateCandidate(candidate);
      if (res.isValid) {
        summary.validCount++;
      } else {
        summary.invalidCount++;
      }
    }

    // 4. Duplicate Detection
    // Candidates with identical (bankCode, productType, customerType, isCallable, rateCategory, schemeName, minTenureDays, maxTenureDays)
    const seenMap = new Map();
    for (let i = 0; i < candidates.length; i++) {
      const c = candidates[i];
      const cat = (c.rateCategory || 'STANDARD').toUpperCase();
      const scheme = (c.schemeName || '').toUpperCase();
      const key = `${c.bankCode}|${c.productType}|${c.customerType}|${c.isCallable}|${cat}|${scheme}|${c.minTenureDays}|${c.maxTenureDays}|${c.minDeposit}|${c.maxDeposit}`;
      if (seenMap.has(key)) {
        summary.duplicateCount++;
        const errMsg = `Duplicate candidate detected: identical tenure [${c.minTenureDays}..${c.maxTenureDays}] for ${c.customerType} (${c.tenureLabel})`;
        c.validationErrors.push(errMsg);
        c.validationStatus = 'INVALID';
        c.stagingStatus = 'INVALID';
        summary.errors.push(errMsg);
      } else {
        seenMap.set(key, i);
      }
    }

    // 5. Overlapping Tenure Range Detection
    // Group by (bankCode, productType, customerType, isCallable, rateCategory, schemeName)
    const groups = new Map();
    for (const c of candidates) {
      const cat = (c.rateCategory || 'STANDARD').toUpperCase();
      const scheme = (c.schemeName || '').toUpperCase();
      const gKey = `${c.bankCode}|${c.productType}|${c.customerType}|${c.isCallable}|${cat}|${scheme}`;
      if (!groups.has(gKey)) groups.set(gKey, []);
      groups.get(gKey).push(c);
    }

    for (const [, groupList] of groups.entries()) {
      for (let i = 0; i < groupList.length; i++) {
        for (let j = i + 1; j < groupList.length; j++) {
          const a = groupList[i];
          const b = groupList[j];

          // Check if identical duplicate (already handled)
          if (a.minTenureDays === b.minTenureDays && a.maxTenureDays === b.maxTenureDays) {
            continue;
          }

          // Check interval overlap: [a.min, a.max] overlaps [b.min, b.max]
          // Note: Standard buckets ending on day X and starting on day X+1 do NOT overlap.
          // Overlap occurs if a.min <= b.max && b.min <= a.max
          if (a.minTenureDays <= b.maxTenureDays && b.minTenureDays <= a.maxTenureDays) {
            summary.overlapCount++;
            const errMsg = `Overlapping tenure range detected: "${a.tenureLabel}" [${a.minTenureDays}..${a.maxTenureDays}d] overlaps with "${b.tenureLabel}" [${b.minTenureDays}..${b.maxTenureDays}d] for ${a.customerType}`;
            a.validationErrors.push(errMsg);
            b.validationErrors.push(errMsg);
            a.validationStatus = 'INVALID';
            b.validationStatus = 'INVALID';
            a.stagingStatus = 'INVALID';
            b.stagingStatus = 'INVALID';
            summary.errors.push(errMsg);
          }
        }
      }
    }

    // Recalculate validCount
    summary.validCount = candidates.filter(c => c.validationStatus === 'VALID').length;
    summary.invalidCount = candidates.filter(c => c.validationStatus !== 'VALID').length;
    summary.success = summary.invalidCount === 0;

    return summary;
  }
}

module.exports = {
  CandidateValidator,
  DEFAULT_VALIDATION_CONFIG,
};
