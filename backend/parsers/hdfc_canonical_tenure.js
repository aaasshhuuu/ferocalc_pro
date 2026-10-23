// FeroCalc Verified FD Rate Engine — HDFC Canonical Tenure Model
//
// Implements the canonical calendar tenure bucket semantics for HDFC Bank
// callable retail domestic term deposits (< ₹3 Crore) across 19 published slabs.
//
// Complies with:
// - Migration 009 dual-domain architecture (DAYS vs CALENDAR)
// - HDFC published rate card boundary operators and units
// - Standard Indian banking end-of-month date arithmetic
// - Leap-year and variable month length resilience

'use strict';

/**
 * Standard Indian banking calendar date addition for calendar months.
 * Snaps to end of month if the target month has fewer days than the start day.
 * (e.g. Jan 31 + 1 month = Feb 28 in common year, Feb 29 in leap year; Mar 31 + 1 month = Apr 30)
 *
 * @param {string|Date} dateInput - ISO date string "YYYY-MM-DD" or Date object
 * @param {number} months - Number of calendar months to add
 * @returns {string} Target ISO date string "YYYY-MM-DD"
 */
function addMonths(dateInput, months) {
  const dateStr = typeof dateInput === 'string' ? dateInput.split('T')[0] : dateInput.toISOString().split('T')[0];
  const [y, m, d] = dateStr.split('-').map(Number);
  const targetMonthIndex = (m - 1) + months;
  const targetYear = y + Math.floor(targetMonthIndex / 12);
  const targetMonth = ((targetMonthIndex % 12) + 12) % 12 + 1;
  const daysInTargetMonth = new Date(Date.UTC(targetYear, targetMonth, 0)).getUTCDate();
  const targetDay = Math.min(d, daysInTargetMonth);
  return `${targetYear}-${String(targetMonth).padStart(2, '0')}-${String(targetDay).padStart(2, '0')}`;
}

/**
 * Adds exact days to a date.
 *
 * @param {string|Date} dateInput - ISO date string "YYYY-MM-DD" or Date object
 * @param {number} days - Number of days to add
 * @returns {string} Target ISO date string "YYYY-MM-DD"
 */
function addDays(dateInput, days) {
  const dateStr = typeof dateInput === 'string' ? dateInput.split('T')[0] : dateInput.toISOString().split('T')[0];
  const [y, m, d] = dateStr.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + days));
  return dt.toISOString().split('T')[0];
}

/**
 * Adds calendar years to a date (equivalent to years * 12 months).
 * Correctly maps Feb 29 in a leap year to Feb 28 in non-leap years.
 *
 * @param {string|Date} dateInput - ISO date string "YYYY-MM-DD" or Date object
 * @param {number} years - Number of calendar years to add
 * @returns {string} Target ISO date string "YYYY-MM-DD"
 */
function addYears(dateInput, years) {
  return addMonths(dateInput, years * 12);
}

/**
 * Evaluates a canonical boundary expression from a start date.
 *
 * Supported expressions:
 * - "N days"
 * - "N calendar months"
 * - "N calendar months + 1 day"
 * - "N calendar years"
 * - "N calendar years + 1 day"
 *
 * @param {string|Date} startDate
 * @param {string} boundaryExpr
 * @returns {string} Boundary date as "YYYY-MM-DD"
 */
function calculateBoundaryDate(startDate, boundaryExpr) {
  const s = String(boundaryExpr).trim().toLowerCase();

  // Pattern: "N calendar years + 1 day"
  const yrPlusDay = s.match(/^(\d+)\s+calendar\s+years?\s*\+\s*1\s+day$/);
  if (yrPlusDay) {
    const yr = parseInt(yrPlusDay[1], 10);
    return addDays(addYears(startDate, yr), 1);
  }

  // Pattern: "N calendar months + 1 day"
  const moPlusDay = s.match(/^(\d+)\s+calendar\s+months?\s*\+\s*1\s+day$/);
  if (moPlusDay) {
    const mo = parseInt(moPlusDay[1], 10);
    return addDays(addMonths(startDate, mo), 1);
  }

  // Pattern: "N calendar years"
  const yrMatch = s.match(/^(\d+)\s+calendar\s+years?$/);
  if (yrMatch) {
    const yr = parseInt(yrMatch[1], 10);
    return addYears(startDate, yr);
  }

  // Pattern: "N calendar months"
  const moMatch = s.match(/^(\d+)\s+calendar\s+months?$/);
  if (moMatch) {
    const mo = parseInt(moMatch[1], 10);
    return addMonths(startDate, mo);
  }

  // Pattern: "N days"
  const dayMatch = s.match(/^(\d+)\s+days?$/);
  if (dayMatch) {
    const days = parseInt(dayMatch[1], 10);
    return addDays(startDate, days);
  }

  throw new Error(`Unrecognized canonical boundary expression: "${boundaryExpr}"`);
}

/**
 * Canonical 19-slab definitions for HDFC Bank callable retail domestic term deposits (< ₹3 Crore).
 * Sourced from official HDFC rate card applicable from 19 August 2026.
 */
const HDFC_CANONICAL_SLABS = [
  {
    slabNumber: 1,
    reviewIds: ['REV_017', 'REV_018'],
    candidateIds: ['cand_hdfc_01', 'cand_hdfc_02'],
    publishedTenureLabel: '7 - 14 days',
    tenureDomain: 'DAYS',
    boundaryUnit: 'DAYS',
    lowerBoundary: '7 days',
    lowerInclusive: true,
    upperBoundary: '14 days',
    upperInclusive: true,
    minYears: 0,
    minMonths: 0,
    minDaysCal: 7,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 0,
    maxDaysCal: 14,
    maxOperator: 'LTE',
    approxMinDays: 7,
    approxMaxDays: 14,
    regularRate: 2.75,
    seniorRate: 3.25,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 2,
    reviewIds: ['REV_019', 'REV_020'],
    candidateIds: ['cand_hdfc_03', 'cand_hdfc_04'],
    publishedTenureLabel: '15-29 days',
    tenureDomain: 'DAYS',
    boundaryUnit: 'DAYS',
    lowerBoundary: '15 days',
    lowerInclusive: true,
    upperBoundary: '29 days',
    upperInclusive: true,
    minYears: 0,
    minMonths: 0,
    minDaysCal: 15,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 0,
    maxDaysCal: 29,
    maxOperator: 'LTE',
    approxMinDays: 15,
    approxMaxDays: 29,
    regularRate: 2.75,
    seniorRate: 3.25,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 3,
    reviewIds: ['REV_021', 'REV_022'],
    candidateIds: ['cand_hdfc_05', 'cand_hdfc_06'],
    publishedTenureLabel: '30-45 days',
    tenureDomain: 'DAYS',
    boundaryUnit: 'DAYS',
    lowerBoundary: '30 days',
    lowerInclusive: true,
    upperBoundary: '45 days',
    upperInclusive: true,
    minYears: 0,
    minMonths: 0,
    minDaysCal: 30,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 0,
    maxDaysCal: 45,
    maxOperator: 'LTE',
    approxMinDays: 30,
    approxMaxDays: 45,
    regularRate: 3.25,
    seniorRate: 3.75,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 4,
    reviewIds: ['REV_023', 'REV_024'],
    candidateIds: ['cand_hdfc_07', 'cand_hdfc_08'],
    publishedTenureLabel: '46-60 days',
    tenureDomain: 'DAYS',
    boundaryUnit: 'DAYS',
    lowerBoundary: '46 days',
    lowerInclusive: true,
    upperBoundary: '60 days',
    upperInclusive: true,
    minYears: 0,
    minMonths: 0,
    minDaysCal: 46,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 0,
    maxDaysCal: 60,
    maxOperator: 'LTE',
    approxMinDays: 46,
    approxMaxDays: 60,
    regularRate: 4.25,
    seniorRate: 4.75,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 5,
    reviewIds: ['REV_025', 'REV_026'],
    candidateIds: ['cand_hdfc_09', 'cand_hdfc_10'],
    publishedTenureLabel: '61-89 days',
    tenureDomain: 'DAYS',
    boundaryUnit: 'DAYS',
    lowerBoundary: '61 days',
    lowerInclusive: true,
    upperBoundary: '89 days',
    upperInclusive: true,
    minYears: 0,
    minMonths: 0,
    minDaysCal: 61,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 0,
    maxDaysCal: 89,
    maxOperator: 'LTE',
    approxMinDays: 61,
    approxMaxDays: 89,
    regularRate: 4.25,
    seniorRate: 4.75,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 6,
    reviewIds: ['REV_027', 'REV_028'],
    candidateIds: ['cand_hdfc_11', 'cand_hdfc_12'],
    publishedTenureLabel: '90 days <= 6 months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'MIXED_CALENDAR_AND_DAYS',
    lowerBoundary: '90 days',
    lowerInclusive: true,
    upperBoundary: '6 calendar months',
    upperInclusive: true,
    minYears: 0,
    minMonths: 0,
    minDaysCal: 90,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 6,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 90,
    approxMaxDays: 182,
    regularRate: 4.25,
    seniorRate: 4.75,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 7,
    reviewIds: ['REV_029', 'REV_030'],
    candidateIds: ['cand_hdfc_13', 'cand_hdfc_14'],
    publishedTenureLabel: '6 months 1 day <=9 months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS_AND_DAYS',
    lowerBoundary: '6 calendar months + 1 day',
    lowerInclusive: true,
    upperBoundary: '9 calendar months',
    upperInclusive: true,
    minYears: 0,
    minMonths: 6,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 0,
    maxMonths: 9,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 183,
    approxMaxDays: 274,
    regularRate: 5.50,
    seniorRate: 6.00,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 8,
    reviewIds: ['REV_031', 'REV_032'],
    candidateIds: ['cand_hdfc_15', 'cand_hdfc_16'],
    publishedTenureLabel: '9 months 1 day to < 1 Year',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS_AND_YEARS',
    lowerBoundary: '9 calendar months + 1 day',
    lowerInclusive: true,
    upperBoundary: '1 calendar year',
    upperInclusive: false,
    minYears: 0,
    minMonths: 9,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 1,
    maxMonths: 0,
    maxDaysCal: 0,
    maxOperator: 'LT',
    approxMinDays: 275,
    approxMaxDays: 364,
    regularRate: 5.75,
    seniorRate: 6.25,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 9,
    reviewIds: ['REV_033', 'REV_034'],
    candidateIds: ['cand_hdfc_17', 'cand_hdfc_18'],
    publishedTenureLabel: '1 Year to < 15 months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS_AND_YEARS',
    lowerBoundary: '1 calendar year',
    lowerInclusive: true,
    upperBoundary: '15 calendar months',
    upperInclusive: false,
    minYears: 1,
    minMonths: 0,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 1,
    maxMonths: 3,
    maxDaysCal: 0,
    maxOperator: 'LT',
    approxMinDays: 365,
    approxMaxDays: 455,
    regularRate: 6.25,
    seniorRate: 6.75,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 10,
    reviewIds: ['REV_035', 'REV_036'],
    candidateIds: ['cand_hdfc_19', 'cand_hdfc_20'],
    publishedTenureLabel: '15 months to < 18 months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS',
    lowerBoundary: '15 calendar months',
    lowerInclusive: true,
    upperBoundary: '18 calendar months',
    upperInclusive: false,
    minYears: 1,
    minMonths: 3,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 1,
    maxMonths: 6,
    maxDaysCal: 0,
    maxOperator: 'LT',
    approxMinDays: 456,
    approxMaxDays: 547,
    regularRate: 6.35,
    seniorRate: 6.85,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 11,
    reviewIds: ['REV_037', 'REV_038'],
    candidateIds: ['cand_hdfc_21', 'cand_hdfc_22'],
    publishedTenureLabel: '18 months to < 21 months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS',
    lowerBoundary: '18 calendar months',
    lowerInclusive: true,
    upperBoundary: '21 calendar months',
    upperInclusive: false,
    minYears: 1,
    minMonths: 6,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 1,
    maxMonths: 9,
    maxDaysCal: 0,
    maxOperator: 'LT',
    approxMinDays: 548,
    approxMaxDays: 638,
    regularRate: 6.45,
    seniorRate: 6.95,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 12,
    reviewIds: ['REV_039', 'REV_040'],
    candidateIds: ['cand_hdfc_23', 'cand_hdfc_24'],
    publishedTenureLabel: '21 months to 2 years',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS_AND_YEARS',
    lowerBoundary: '21 calendar months',
    lowerInclusive: true,
    upperBoundary: '2 calendar years',
    upperInclusive: true,
    minYears: 1,
    minMonths: 9,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 2,
    maxMonths: 0,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 639,
    approxMaxDays: 730,
    regularRate: 6.45,
    seniorRate: 6.95,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 13,
    reviewIds: ['REV_041', 'REV_042'],
    candidateIds: ['cand_hdfc_25', 'cand_hdfc_26'],
    publishedTenureLabel: '2 Years 1 day to < 2 Year 11 Months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_YEARS_AND_MONTHS',
    lowerBoundary: '2 calendar years + 1 day',
    lowerInclusive: true,
    upperBoundary: '35 calendar months',
    upperInclusive: false,
    minYears: 2,
    minMonths: 0,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 2,
    maxMonths: 11,
    maxDaysCal: 0,
    maxOperator: 'LT',
    approxMinDays: 731,
    approxMaxDays: 1064,
    regularRate: 6.45,
    seniorRate: 6.95,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 14,
    reviewIds: ['REV_043', 'REV_044'],
    candidateIds: ['cand_hdfc_27', 'cand_hdfc_28'],
    publishedTenureLabel: '2 Years 11 Months (35 months)',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'EXACT_CALENDAR_MONTH_TENOR',
    lowerBoundary: '35 calendar months',
    lowerInclusive: true,
    upperBoundary: '35 calendar months',
    upperInclusive: true,
    minYears: 2,
    minMonths: 11,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 2,
    maxMonths: 11,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 1065,
    approxMaxDays: 1065,
    regularRate: 6.45,
    seniorRate: 6.95,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 15,
    reviewIds: ['REV_045', 'REV_046'],
    candidateIds: ['cand_hdfc_29', 'cand_hdfc_30'],
    publishedTenureLabel: '2 Years 11 Months 1 day <= 3 Year',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS_AND_YEARS',
    lowerBoundary: '35 calendar months + 1 day',
    lowerInclusive: true,
    upperBoundary: '3 calendar years',
    upperInclusive: true,
    minYears: 2,
    minMonths: 11,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 3,
    maxMonths: 0,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 1066,
    approxMaxDays: 1095,
    regularRate: 6.45,
    seniorRate: 6.95,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 16,
    reviewIds: ['REV_047', 'REV_048'],
    candidateIds: ['cand_hdfc_31', 'cand_hdfc_32'],
    publishedTenureLabel: '3 Years 1 day to < 4 Years 7 Months',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_YEARS_AND_MONTHS',
    lowerBoundary: '3 calendar years + 1 day',
    lowerInclusive: true,
    upperBoundary: '55 calendar months',
    upperInclusive: false,
    minYears: 3,
    minMonths: 0,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 4,
    maxMonths: 7,
    maxDaysCal: 0,
    maxOperator: 'LT',
    approxMinDays: 1096,
    approxMaxDays: 1672,
    regularRate: 6.50,
    seniorRate: 7.10,
    seniorSpreadBps: 60,
  },
  {
    slabNumber: 17,
    reviewIds: ['REV_049', 'REV_050'],
    candidateIds: ['cand_hdfc_33', 'cand_hdfc_34'],
    publishedTenureLabel: '4 Year 7 Months (55 months)',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'EXACT_CALENDAR_MONTH_TENOR',
    lowerBoundary: '55 calendar months',
    lowerInclusive: true,
    upperBoundary: '55 calendar months',
    upperInclusive: true,
    minYears: 4,
    minMonths: 7,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 4,
    maxMonths: 7,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 1673,
    approxMaxDays: 1673,
    regularRate: 6.40,
    seniorRate: 6.90,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 18,
    reviewIds: ['REV_051', 'REV_052'],
    candidateIds: ['cand_hdfc_35', 'cand_hdfc_36'],
    publishedTenureLabel: '4 Year 7 Months 1 day <=5 Years',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_MONTHS_AND_YEARS',
    lowerBoundary: '55 calendar months + 1 day',
    lowerInclusive: true,
    upperBoundary: '5 calendar years',
    upperInclusive: true,
    minYears: 4,
    minMonths: 7,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 5,
    maxMonths: 0,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 1674,
    approxMaxDays: 1825,
    regularRate: 6.40,
    seniorRate: 6.90,
    seniorSpreadBps: 50,
  },
  {
    slabNumber: 19,
    reviewIds: ['REV_053', 'REV_054'],
    candidateIds: ['cand_hdfc_37', 'cand_hdfc_38'],
    publishedTenureLabel: '5 Years 1 day to 10 Years',
    tenureDomain: 'CALENDAR',
    boundaryUnit: 'CALENDAR_YEARS',
    lowerBoundary: '5 calendar years + 1 day',
    lowerInclusive: true,
    upperBoundary: '10 calendar years',
    upperInclusive: true,
    minYears: 5,
    minMonths: 0,
    minDaysCal: 1,
    minOperator: 'GTE',
    maxYears: 10,
    maxMonths: 0,
    maxDaysCal: 0,
    maxOperator: 'LTE',
    approxMinDays: 1826,
    approxMaxDays: 3650,
    regularRate: 6.15,
    seniorRate: 6.65,
    seniorSpreadBps: 50,
  },
];

/**
 * Normalizes tenure strings for fuzzy matching across spacing variations.
 */
function normalizeLabelKey(label) {
  return String(label || '')
    .toLowerCase()
    .replace(/<=/g, ' <= ')
    .replace(/</g, ' < ')
    .replace(/-/g, ' - ')
    .replace(/\s+/g, ' ')
    .trim();
}

const LABEL_LOOKUP = new Map();
for (const slab of HDFC_CANONICAL_SLABS) {
  LABEL_LOOKUP.set(slab.publishedTenureLabel, slab);
  LABEL_LOOKUP.set(normalizeLabelKey(slab.publishedTenureLabel), slab);
}

/**
 * Resolves a published table label to its canonical 19-slab record.
 *
 * @param {string} label
 * @returns {Object|null}
 */
function getCanonicalSlabByLabel(label) {
  if (!label) return null;
  if (LABEL_LOOKUP.has(label)) return LABEL_LOOKUP.get(label);
  const norm = normalizeLabelKey(label);
  if (LABEL_LOOKUP.has(norm)) return LABEL_LOOKUP.get(norm);
  return null;
}

/**
 * Matches a specific deposit start date and maturity date to the applicable HDFC tenure slab.
 *
 * @param {string|Date} startDate - Booking / value date
 * @param {string|Date} maturityDate - Maturity / end date
 * @returns {Object|null} The matching canonical slab or null if out of bounds
 */
function matchHdfcTenureSlab(startDate, maturityDate) {
  const sStr = typeof startDate === 'string' ? startDate.split('T')[0] : startDate.toISOString().split('T')[0];
  const mStr = typeof maturityDate === 'string' ? maturityDate.split('T')[0] : maturityDate.toISOString().split('T')[0];

  for (const slab of HDFC_CANONICAL_SLABS) {
    const lowerDate = calculateBoundaryDate(sStr, slab.lowerBoundary);
    const upperDate = calculateBoundaryDate(sStr, slab.upperBoundary);

    const lowerOk = slab.lowerInclusive ? mStr >= lowerDate : mStr > lowerDate;
    const upperOk = slab.upperInclusive ? mStr <= upperDate : mStr < upperDate;

    if (lowerOk && upperOk) {
      return slab;
    }
  }

  return null;
}

/**
 * Validates that for a given deposit start date, every published boundary
 * (boundary - 1d, boundary, boundary + 1d) resolves cleanly with zero gaps
 * and zero overlaps across contiguous slabs.
 *
 * @param {string} startDate - "YYYY-MM-DD"
 * @returns {{ valid: boolean, errors: string[] }}
 */
function verifyBoundaryContinuity(startDate) {
  const errors = [];
  for (let i = 0; i < HDFC_CANONICAL_SLABS.length; i++) {
    const current = HDFC_CANONICAL_SLABS[i];
    const lowerDate = calculateBoundaryDate(startDate, current.lowerBoundary);
    const upperDate = calculateBoundaryDate(startDate, current.upperBoundary);

    // Check match at lower bound
    const matchLower = matchHdfcTenureSlab(startDate, lowerDate);
    if (!matchLower || matchLower.slabNumber !== current.slabNumber) {
      errors.push(`Slab ${current.slabNumber} lower bound ${lowerDate} failed: expected Slab ${current.slabNumber}, got ${matchLower ? matchLower.slabNumber : null}`);
    }

    // Check match at upper bound
    if (current.upperInclusive) {
      const matchUpper = matchHdfcTenureSlab(startDate, upperDate);
      if (!matchUpper || matchUpper.slabNumber !== current.slabNumber) {
        errors.push(`Slab ${current.slabNumber} inclusive upper bound ${upperDate} failed: expected Slab ${current.slabNumber}, got ${matchUpper ? matchUpper.slabNumber : null}`);
      }

      // If next slab exists, day after upper must match next slab
      if (i < HDFC_CANONICAL_SLABS.length - 1) {
        const dayAfterUpper = addDays(upperDate, 1);
        const matchAfter = matchHdfcTenureSlab(startDate, dayAfterUpper);
        if (!matchAfter || matchAfter.slabNumber !== current.slabNumber + 1) {
          errors.push(`Slab ${current.slabNumber} day after inclusive upper ${dayAfterUpper} failed: expected next Slab ${current.slabNumber + 1}, got ${matchAfter ? matchAfter.slabNumber : null}`);
        }
      }
    } else {
      // Exclusive upper bound: upperDate belongs to next slab
      const matchUpper = matchHdfcTenureSlab(startDate, upperDate);
      if (!matchUpper || matchUpper.slabNumber !== current.slabNumber + 1) {
        errors.push(`Slab ${current.slabNumber} exclusive upper bound ${upperDate} failed: expected next Slab ${current.slabNumber + 1}, got ${matchUpper ? matchUpper.slabNumber : null}`);
      }
      // Day before exclusive upper belongs to current slab
      const dayBeforeUpper = addDays(upperDate, -1);
      const matchBefore = matchHdfcTenureSlab(startDate, dayBeforeUpper);
      if (!matchBefore || matchBefore.slabNumber !== current.slabNumber) {
        errors.push(`Slab ${current.slabNumber} day before exclusive upper ${dayBeforeUpper} failed: expected Slab ${current.slabNumber}, got ${matchBefore ? matchBefore.slabNumber : null}`);
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

module.exports = {
  HDFC_CANONICAL_SLABS,
  addMonths,
  addDays,
  addYears,
  calculateBoundaryDate,
  getCanonicalSlabByLabel,
  matchHdfcTenureSlab,
  verifyBoundaryContinuity,
};
