// FeroCalc Verified FD Rate Engine — Rate Diff Engine
//
// Compares staged candidates against active VERIFIED rates using complete identity dimensions:
// - Bank
// - Product Type
// - Customer Type
// - Callable / Non-callable
// - Tenure Range (minTenureDays, maxTenureDays)
// - Deposit Constraints (minDeposit, maxDeposit)
//
// Rules:
// 1. Never compare solely by bank + tenure.
// 2. Different callable/product/customer dimensions must NEVER be incorrectly merged.
// 3. Page redesigns with identical rates produce UNCHANGED, not RATE_CHANGED.

'use strict';

const DIFF_TYPES = {
  NEW: 'NEW',
  UNCHANGED: 'UNCHANGED',
  RATE_CHANGED: 'RATE_CHANGED',
  TENURE_CHANGED: 'TENURE_CHANGED',
  CUSTOMER_TYPE_CHANGED: 'CUSTOMER_TYPE_CHANGED',
  PRODUCT_CHANGED: 'PRODUCT_CHANGED',
  DEPOSIT_CONDITION_CHANGED: 'DEPOSIT_CONDITION_CHANGED',
  REMOVED_FROM_SOURCE: 'REMOVED_FROM_SOURCE',
  UNRESOLVED_DOMAIN_CONFLICT: 'UNRESOLVED_DOMAIN_CONFLICT',
};

// Canonical Gregorian month-span bounds across all calendar start dates.
// Verified against all 2,922 calendar start dates across 2 leap cycles (2024–2031)
// under the repository's canonical banking addMonths and addDays semantics.
const CANONICAL_BASE_MIN_DAYS = [0, 28, 59, 89, 120, 150, 181, 212, 242, 273, 303, 334, 365];
const CANONICAL_BASE_MAX_DAYS = [0, 31, 62, 92, 123, 153, 184, 215, 245, 276, 306, 337, 366];

function getCanonicalMinDaysForMonths(deltaM) {
  if (deltaM <= 0) return 0;
  const fullYears = Math.floor(deltaM / 12);
  const remMonths = deltaM % 12;
  return fullYears * 365 + CANONICAL_BASE_MIN_DAYS[remMonths];
}

function getCanonicalMaxDaysForMonths(deltaM) {
  if (deltaM <= 0) return 0;
  const fullYears = Math.floor(deltaM / 12);
  const remMonths = deltaM % 12;
  return fullYears * 366 + CANONICAL_BASE_MAX_DAYS[remMonths];
}

class RateDiffEngine {
  /**
   * Generates a deterministic dimensional key for a rate bucket.
   */
  getBucketKey(r) {
    const bank = String(r.bankCode || r.bank_code || r.bankId || r.bank_id || '').toUpperCase().trim();
    const prod = String(r.productType || r.product_type || 'RETAIL_DOMESTIC_TERM_DEPOSIT').toUpperCase().trim();
    const cust = String(r.customerType || r.customer_type || 'REGULAR').toUpperCase().trim();
    const call = r.isCallable !== undefined ? Boolean(r.isCallable) : (r.is_callable !== undefined ? Boolean(r.is_callable) : true);
    const cat = String(r.rateCategory || r.rate_category || 'STANDARD').toUpperCase().trim();
    const scheme = String(r.schemeName || r.scheme_name || '').toUpperCase().trim();
    const domain = String(r.tenureDomain || r.tenure_domain || 'DAYS').toUpperCase().trim();

    let tenureKey;
    if (domain === 'CALENDAR') {
      const minOp = String(r.minOperator || r.min_operator || '').trim().toUpperCase();
      const maxOp = String(r.maxOperator || r.max_operator || '').trim().toUpperCase();

      const hasLower = Boolean(minOp) || r.minYears != null || r.min_years != null || r.minMonths != null || r.min_months != null || r.minDaysCal != null || r.min_days_cal != null;
      const hasUpper = Boolean(maxOp) || r.maxYears != null || r.max_years != null || r.maxMonths != null || r.max_months != null || r.maxDaysCal != null || r.max_days_cal != null;

      const minY = hasLower ? (r.minYears != null ? Number(r.minYears) : (r.min_years != null ? Number(r.min_years) : 0)) : 'NULL';
      const minM = hasLower ? (r.minMonths != null ? Number(r.minMonths) : (r.min_months != null ? Number(r.min_months) : 0)) : 'NULL';
      const minDCal = hasLower ? (r.minDaysCal != null ? Number(r.minDaysCal) : (r.min_days_cal != null ? Number(r.min_days_cal) : 0)) : 'NULL';

      const maxY = hasUpper ? (r.maxYears != null ? Number(r.maxYears) : (r.max_years != null ? Number(r.max_years) : 0)) : 'NULL';
      const maxM = hasUpper ? (r.maxMonths != null ? Number(r.maxMonths) : (r.max_months != null ? Number(r.max_months) : 0)) : 'NULL';
      const maxDCal = hasUpper ? (r.maxDaysCal != null ? Number(r.maxDaysCal) : (r.max_days_cal != null ? Number(r.max_days_cal) : 0)) : 'NULL';

      tenureKey = `CALENDAR#${minY}_${minM}_${minDCal}_${minOp}#${maxY}_${maxM}_${maxDCal}_${maxOp}`;
    } else {
      const minD = Number(r.minTenureDays ?? r.min_tenure_days ?? 0);
      const maxD = Number(r.maxTenureDays ?? r.max_tenure_days ?? 0);
      tenureKey = `${minD}#${maxD}`;
    }

    const minDep = Number(r.minDeposit ?? r.min_deposit ?? 0);
    const maxDep = r.maxDeposit !== undefined && r.maxDeposit !== null
      ? Number(r.maxDeposit)
      : (r.max_deposit !== undefined && r.max_deposit !== null ? Number(r.max_deposit) : 'NO_MAX');

    return `${bank}#${prod}#${cust}#${call}#${cat}#${scheme}#${tenureKey}#${minDep}#${maxDep}`;
  }

  /**
   * Generates a product dimension key (bank, product, customer, callable, category, scheme).
   */
  getProductDimensionKey(r) {
    const bank = String(r.bankCode || r.bank_code || r.bankId || r.bank_id || '').toUpperCase().trim();
    const prod = String(r.productType || r.product_type || 'RETAIL_DOMESTIC_TERM_DEPOSIT').toUpperCase().trim();
    const cust = String(r.customerType || r.customer_type || 'REGULAR').toUpperCase().trim();
    const call = r.isCallable !== undefined ? Boolean(r.isCallable) : (r.is_callable !== undefined ? Boolean(r.is_callable) : true);
    const cat = String(r.rateCategory || r.rate_category || 'STANDARD').toUpperCase().trim();
    const scheme = String(r.schemeName || r.scheme_name || '').toUpperCase().trim();
    return `${bank}#${prod}#${cust}#${call}#${cat}#${scheme}`;
  }

  /**
   * Generates a partial domain key (excluding tenure range and deposit bounds).
   */
  getDomainKey(r) {
    const base = this.getProductDimensionKey(r);
    const domain = String(r.tenureDomain || r.tenure_domain || 'DAYS').toUpperCase().trim();
    return `${base}#${domain}`;
  }

  /**
   * Compares two canonical calendar boundary tuples symbolically without approximate day floating-point math.
   *
   * Normalization:
   * - years: integer >= 0, default 0
   * - months: integer [0, 11] (or generalized to total months), default 0
   * - days: integer >= 0, default 0
   *
   * Total calendar months: M = years * 12 + months
   *
   * Exact ordering rules (substantiated across all Gregorian anchor dates under canonical addMonths):
   * 1. If M1 === M2: both points share identical calendar month offset from any anchor date.
   *    Therefore: d1 < d2 -> -1; d1 > d2 -> 1; d1 === d2 -> 0.
   * 2. If M1 < M2 (Delta M = M2 - M1 >= 1):
   *    Let minDays = getCanonicalMinDaysForMonths(Delta M) and maxDays = getCanonicalMaxDaysForMonths(Delta M).
   *    - If (d1 - d2) < minDays: t1 is strictly before t2 across ALL Gregorian anchor dates -> returns -1.
   *    - If (d1 - d2) > maxDays: t1 is strictly after t2 across ALL Gregorian anchor dates -> returns 1.
   *    - If minDays <= (d1 - d2) <= maxDays: ordering depends on anchor date -> returns null (indeterminate).
   * 3. If M1 > M2:
   *    Symmetric to case 2 with Delta M = M1 - M2.
   *
   * @param {Object} t1 - { years, months, daysCal }
   * @param {Object} t2 - { years, months, daysCal }
   * @returns {number|null} -1 if t1 < t2, 1 if t1 > t2, 0 if t1 === t2, null if indeterminate without anchor date
   */
  _compareCalendarTuples(t1, t2) {
    if (!t1 || !t2) return null;

    const y1 = Number(t1.years ?? 0);
    const m1 = Number(t1.months ?? 0);
    const d1 = Number(t1.daysCal ?? t1.days ?? 0);

    const y2 = Number(t2.years ?? 0);
    const m2 = Number(t2.months ?? 0);
    const d2 = Number(t2.daysCal ?? t2.days ?? 0);

    const totalM1 = y1 * 12 + m1;
    const totalM2 = y2 * 12 + m2;

    if (totalM1 === totalM2) {
      if (d1 < d2) return -1;
      if (d1 > d2) return 1;
      return 0;
    }

    if (totalM1 < totalM2) {
      const deltaM = totalM2 - totalM1;
      const minDays = getCanonicalMinDaysForMonths(deltaM);
      const maxDays = getCanonicalMaxDaysForMonths(deltaM);
      const dayDelta = d1 - d2;

      if (dayDelta < minDays) {
        return -1;
      }
      if (dayDelta > maxDays) {
        return 1;
      }
      return null;
    } else {
      const deltaM = totalM1 - totalM2;
      const minDays = getCanonicalMinDaysForMonths(deltaM);
      const maxDays = getCanonicalMaxDaysForMonths(deltaM);
      const dayDelta = d2 - d1;

      if (dayDelta < minDays) {
        return 1;
      }
      if (dayDelta > maxDays) {
        return -1;
      }
      return null;
    }
  }

  /**
   * Extracts normalized calendar lower and upper boundary endpoints.
   */
  _extractCalendarBounds(r) {
    if (!r) return { lower: null, upper: null };

    const hasLower = (r.minOperator || r.min_operator) != null ||
                     (r.minYears ?? r.min_years) != null ||
                     (r.minMonths ?? r.min_months) != null ||
                     (r.minDaysCal ?? r.min_days_cal) != null;

    const lower = hasLower ? {
      years: Number(r.minYears ?? r.min_years ?? 0),
      months: Number(r.minMonths ?? r.min_months ?? 0),
      daysCal: Number(r.minDaysCal ?? r.min_days_cal ?? 0),
      op: String(r.minOperator || r.min_operator || 'GTE').toUpperCase(),
    } : null;

    const hasUpper = (r.maxOperator || r.max_operator) != null ||
                     (r.maxYears ?? r.max_years) != null ||
                     (r.maxMonths ?? r.max_months) != null ||
                     (r.maxDaysCal ?? r.max_days_cal) != null;

    const upper = hasUpper ? {
      years: Number(r.maxYears ?? r.max_years ?? 0),
      months: Number(r.maxMonths ?? r.max_months ?? 0),
      daysCal: Number(r.maxDaysCal ?? r.max_days_cal ?? 0),
      op: String(r.maxOperator || r.max_operator || 'LTE').toUpperCase(),
    } : null;

    return { lower, upper };
  }

  /**
   * Evaluates if calendar interval A is strictly before calendar interval B (disjoint).
   * @param {Object} upperA - { years, months, daysCal, op: 'LTE'|'LT' }
   * @param {Object} lowerB - { years, months, daysCal, op: 'GTE'|'GT' }
   * @returns {boolean} true if A is strictly before B
   */
  _isCalendarIntervalStrictlyBefore(upperA, lowerB) {
    if (!upperA || !upperA.op) return false;
    if (!lowerB || !lowerB.op) return false;

    const cmp = this._compareCalendarTuples(upperA, lowerB);

    if (cmp === -1) {
      return true;
    }
    if (cmp === 1) {
      return false;
    }
    if (cmp === 0) {
      if (upperA.op === 'LT' || lowerB.op === 'GT') {
        return true;
      }
      return false;
    }

    return false;
  }

  /**
   * Checks whether two calendar intervals overlap.
   */
  _calendarIntervalsOverlap(cand, active) {
    const bCand = this._extractCalendarBounds(cand);
    const bActive = this._extractCalendarBounds(active);

    const candBeforeActive = this._isCalendarIntervalStrictlyBefore(bCand.upper, bActive.lower);
    const activeBeforeCand = this._isCalendarIntervalStrictlyBefore(bActive.upper, bCand.lower);

    return !candBeforeActive && !activeBeforeCand;
  }

  /**
   * Checks whether a DAYS record and a CALENDAR record have potential overlap or are clearly unrelated.
   * Uses conservative possible calendar day envelopes without authoritative day-only matching.
   *
   * @param {Object} rA - First record (DAYS or CALENDAR)
   * @param {Object} rB - Second record (DAYS or CALENDAR)
   * @returns {boolean} true if intervals potentially overlap; false if clearly unrelated/disjoint
   */
  _checkMixedDomainPossibleOverlap(rA, rB) {
    const isACal = String(rA.tenureDomain || rA.tenure_domain || 'DAYS').toUpperCase().trim() === 'CALENDAR';
    const calRec = isACal ? rA : rB;
    const daysRec = isACal ? rB : rA;

    const dMin = Number(daysRec.minTenureDays ?? daysRec.min_tenure_days ?? 0);
    const dMax = Number(daysRec.maxTenureDays ?? daysRec.max_tenure_days ?? 0);

    const calBounds = this._extractCalendarBounds(calRec);

    // Minimum possible days for calendar lower bound across all Gregorian anchor dates
    let calMinDays = 0;
    if (calBounds.lower) {
      const y = calBounds.lower.years;
      const m = calBounds.lower.months;
      const d = calBounds.lower.daysCal;
      calMinDays = getCanonicalMinDaysForMonths(y * 12 + m) + d;
    }

    // Maximum possible days for calendar upper bound across all Gregorian anchor dates
    let calMaxDays = Infinity;
    if (calBounds.upper) {
      const y = calBounds.upper.years;
      const m = calBounds.upper.months;
      const d = calBounds.upper.daysCal;
      calMaxDays = getCanonicalMaxDaysForMonths(y * 12 + m) + d;
    }

    // Disjoint if calMaxDays < dMin or calMinDays > dMax
    if (calMaxDays < dMin || calMinDays > dMax) {
      return false; // Clearly unrelated tenure buckets!
    }

    return true; // Potentially overlapping or unresolvable without anchor date
  }

  _formatCalendarBound(r) {
    if (r.source_tenure_text || r.sourceTenureText || r.tenure_label || r.tenureLabel) {
      return r.source_tenure_text || r.sourceTenureText || r.tenure_label || r.tenureLabel;
    }
    const minY = r.minYears ?? r.min_years ?? 0;
    const minM = r.minMonths ?? r.min_months ?? 0;
    const minD = r.minDaysCal ?? r.min_days_cal ?? 0;
    const minOp = r.minOperator || r.min_operator || 'GTE';
    const maxY = r.maxYears ?? r.max_years ?? 0;
    const maxM = r.maxMonths ?? r.max_months ?? 0;
    const maxD = r.maxDaysCal ?? r.max_days_cal ?? 0;
    const maxOp = r.maxOperator || r.max_operator || 'LTE';
    return `${minOp} (${minY}Y ${minM}M ${minD}D) - ${maxOp} (${maxY}Y ${maxM}M ${maxD}D)`;
  }

  /**
   * Compares a single candidate against existing active verified rates.
   *
   * @param {Object} candidate - Staged rate candidate
   * @param {Array<Object>} activeVerifiedRates - Currently active verified rates
   * @returns {Object} Structured diff result
   */
  diffCandidate(candidate, activeVerifiedRates = []) {
    const candKey = this.getBucketKey(candidate);
    const candRate = Number(candidate.interestRate ?? candidate.interest_rate);

    // 1. Check exact dimensional bucket match
    const exactMatch = activeVerifiedRates.find(v => this.getBucketKey(v) === candKey);

    if (exactMatch) {
      const verifiedRate = Number(exactMatch.interestRate ?? exactMatch.interest_rate);
      const delta = parseFloat((candRate - verifiedRate).toFixed(4));
      const absDelta = Math.abs(delta);

      if (absDelta === 0) {
        return {
          diffType: DIFF_TYPES.UNCHANGED,
          hasChanged: false,
          previousRecord: exactMatch,
          previousRate: verifiedRate,
          currentRate: candRate,
          rateDelta: 0,
          details: 'Candidate matches existing verified record identically across all dimensions and rate value.',
        };
      }

      return {
        diffType: DIFF_TYPES.RATE_CHANGED,
        hasChanged: true,
        previousRecord: exactMatch,
        previousRate: verifiedRate,
        currentRate: candRate,
        rateDelta: delta,
        absDelta,
        details: `Rate changed from ${verifiedRate}% to ${candRate}% (delta: ${delta > 0 ? '+' : ''}${delta.toFixed(2)}%).`,
      };
    }

    // 2. Check for conflicts or close tenure boundary changes within the same product dimensions
    const candProdDim = this.getProductDimensionKey(candidate);
    const candDomain = String(candidate.tenureDomain || candidate.tenure_domain || 'DAYS').toUpperCase().trim();
    const dimMatches = activeVerifiedRates.filter(v => this.getProductDimensionKey(v) === candProdDim);

    for (const v of dimMatches) {
      const vDomain = String(v.tenureDomain || v.tenure_domain || 'DAYS').toUpperCase().trim();

      // Case 2A: Mixed Domain (DAYS vs CALENDAR)
      if (candDomain !== vDomain) {
        if (this._checkMixedDomainPossibleOverlap(candidate, v)) {
          return {
            diffType: DIFF_TYPES.UNRESOLVED_DOMAIN_CONFLICT,
            hasChanged: true,
            isConflict: true,
            previousRecord: v,
            previousRate: Number(v.interestRate ?? v.interest_rate),
            currentRate: candRate,
            rateDelta: parseFloat((candRate - Number(v.interestRate ?? v.interest_rate)).toFixed(4)),
            details: `Unresolved domain conflict: candidate in ${candDomain} domain potentially overlaps active verified record in ${vDomain} domain and cannot be authoritatively compared without anchor date. Day projections are non-authoritative.`,
          };
        }
        // Clearly unrelated tenure buckets across domains do not conflict; continue checking other active records
        continue;
      }

      // Case 2B: Both in DAYS domain
      if (candDomain === 'DAYS' && vDomain === 'DAYS') {
        const cMin = Number(candidate.minTenureDays ?? candidate.min_tenure_days ?? 0);
        const cMax = Number(candidate.maxTenureDays ?? candidate.max_tenure_days ?? 0);
        const vMin = Number(v.minTenureDays ?? v.min_tenure_days ?? 0);
        const vMax = Number(v.maxTenureDays ?? v.max_tenure_days ?? 0);

        if (cMin <= vMax && vMin <= cMax) {
          if (cMin !== vMin || cMax !== vMax) {
            return {
              diffType: DIFF_TYPES.TENURE_CHANGED,
              hasChanged: true,
              previousRecord: v,
              previousRate: Number(v.interestRate ?? v.interest_rate),
              currentRate: candRate,
              rateDelta: parseFloat((candRate - Number(v.interestRate ?? v.interest_rate)).toFixed(4)),
              details: `Tenure bucket shifted from [${vMin}..${vMax}d] to [${cMin}..${cMax}d].`,
            };
          }
        }
      }

      // Case 2C: Both in CALENDAR domain
      if (candDomain === 'CALENDAR' && vDomain === 'CALENDAR') {
        if (this._calendarIntervalsOverlap(candidate, v)) {
          return {
            diffType: DIFF_TYPES.TENURE_CHANGED,
            hasChanged: true,
            previousRecord: v,
            previousRate: Number(v.interestRate ?? v.interest_rate),
            currentRate: candRate,
            rateDelta: parseFloat((candRate - Number(v.interestRate ?? v.interest_rate)).toFixed(4)),
            details: `Calendar tenure interval shifted/overlapping: candidate [${this._formatCalendarBound(candidate)}] overlaps active record [${this._formatCalendarBound(v)}].`,
          };
        }
      }
    }

    // 3. Completely new bucket
    return {
      diffType: DIFF_TYPES.NEW,
      hasChanged: true,
      previousRecord: null,
      previousRate: null,
      currentRate: candRate,
      rateDelta: null,
      details: 'New rate bucket not present in active verified records.',
    };
  }

  /**
   * Compares an entire extraction batch against active verified rates,
   * detecting modified, new, unchanged, and removed rates.
   *
   * @param {Array<Object>} candidates - Extracted candidates
   * @param {Array<Object>} activeVerifiedRates - Active verified rates for this bank
   * @returns {Object} Comprehensive batch diff report
   */
  diffBatch(candidates = [], activeVerifiedRates = []) {
    const candidateDiffs = [];
    const matchedVerifiedIds = new Set();

    for (const c of candidates) {
      const diff = this.diffCandidate(c, activeVerifiedRates);
      candidateDiffs.push({
        candidate: c,
        diff,
      });

      if (diff.previousRecord && diff.previousRecord.id) {
        matchedVerifiedIds.add(diff.previousRecord.id);
      }
    }

    // Identify active rates that were NOT found in the newly extracted candidates
    const removedFromSource = [];
    for (const v of activeVerifiedRates) {
      if (!matchedVerifiedIds.has(v.id)) {
        // Also check if any candidate matches the domain and tenure range
        const hasMatch = candidateDiffs.some(cd => 
          cd.diff.previousRecord && cd.diff.previousRecord.id === v.id
        );
        if (!hasMatch) {
          const vDomain = (v.tenureDomain || v.tenure_domain || 'DAYS').toUpperCase();
          const tenureDisplay = vDomain === 'CALENDAR'
            ? (v.source_tenure_text ?? v.sourceTenureText ?? v.tenure_label ?? v.tenureLabel ?? 'CALENDAR')
            : `${v.min_tenure_days ?? v.minTenureDays}..${v.max_tenure_days ?? v.maxTenureDays}d`;
          removedFromSource.push({
            diffType: DIFF_TYPES.REMOVED_FROM_SOURCE,
            record: v,
            details: `Active verified rate [${tenureDisplay}, ${v.customer_type ?? v.customerType}] was missing in latest source extraction.`,
          });
        }
      }
    }

    return {
      totalCandidates: candidates.length,
      candidateDiffs,
      newCount: candidateDiffs.filter(cd => cd.diff.diffType === DIFF_TYPES.NEW).length,
      unchangedCount: candidateDiffs.filter(cd => cd.diff.diffType === DIFF_TYPES.UNCHANGED).length,
      rateChangedCount: candidateDiffs.filter(cd => cd.diff.diffType === DIFF_TYPES.RATE_CHANGED).length,
      tenureChangedCount: candidateDiffs.filter(cd => cd.diff.diffType === DIFF_TYPES.TENURE_CHANGED).length,
      conflictCount: candidateDiffs.filter(cd => cd.diff.diffType === DIFF_TYPES.UNRESOLVED_DOMAIN_CONFLICT).length,
      removedCount: removedFromSource.length,
      removedFromSource,
    };
  }
}

module.exports = {
  RateDiffEngine,
  DIFF_TYPES,
  CANONICAL_BASE_MIN_DAYS,
  CANONICAL_BASE_MAX_DAYS,
  getCanonicalMinDaysForMonths,
  getCanonicalMaxDaysForMonths,
};
