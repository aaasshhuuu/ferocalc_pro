// FeroCalc Verified FD Rate Engine — Tenure Parser
// Parses diverse Indian bank tenure expressions without losing bespoke tenures.
//
// Rules:
// 1. Never convert bespoke tenures (e.g. 35 months, 389 days, 55 months) into standard 1y/2y buckets.
// 2. Preserve the exact source tenure string.
// 3. Return both calculated min/max days for comparison and raw bounds.

'use strict';

const DAYS_PER_YEAR = 365;
const DAYS_PER_MONTH = 30.4167; // Astronomical / average month length for Indian bank buckets

/**
 * Converts a compound duration string (e.g. "2 Years 11 Months 1 day") to integer days.
 */
function parseDurationComponentToDays(str) {
  if (!str) return 0;
  let days = 0;
  const s = String(str).toLowerCase().trim();

  const yrMatch = s.match(/(\d+)\s*(?:year|yr)s?/);
  const moMatch = s.match(/(\d+)\s*(?:month|mo)s?/);
  const dyMatch = s.match(/(\d+)\s*(?:day|d)s?/);

  if (yrMatch) days += parseInt(yrMatch[1], 10) * DAYS_PER_YEAR;
  if (moMatch) days += Math.round(parseInt(moMatch[1], 10) * DAYS_PER_MONTH);
  if (dyMatch) days += parseInt(dyMatch[1], 10);

  // Fallback: If only a bare number is present
  if (!yrMatch && !moMatch && !dyMatch) {
    const numOnly = s.match(/^(\d+)$/);
    if (numOnly) {
      days = parseInt(numOnly[1], 10);
    }
  }

  return days;
}

/**
 * Detects the primary unit of a duration string.
 */
function detectTenureUnit(str) {
  const s = String(str).toLowerCase();
  if (s.includes('year') || s.includes('yr')) return 'YEARS';
  if (s.includes('month') || s.includes('mo')) return 'MONTHS';
  return 'DAYS';
}

/**
 * Determines whether a tenure expression represents a bespoke/special non-standard bucket.
 */
function isBespokeTenure(label) {
  const s = String(label).toLowerCase();
  if (s.includes('(') && s.includes(')')) return true; // e.g. (35 months), (55 months), (444 days)
  if (s.includes('155') || s.includes('180') || s.includes('303') || s.includes('389') || s.includes('390') || s.includes('400') || s.includes('444') || s.includes('555') || s.includes('666') || s.includes('777') || s.includes('1204')) return true;
  if (s.includes('11 month') || s.includes('7 month')) return true;
  return false;
}

/**
 * Parses a bank tenure label into structured tenure properties.
 *
 * @param {string} label - e.g. "7 - 14 days", "2 Years 11 Months (35 months)", "1 Year to 389 Days"
 * @returns {Object} Structured tenure object
 */
function parseTenureRange(label) {
  if (!label || typeof label !== 'string') {
    return {
      rawLabel: '',
      minTenureDays: 0,
      maxTenureDays: 0,
      tenureUnit: 'DAYS',
      isBespoke: false,
      isValid: false,
      error: 'Empty tenure label',
    };
  }

  const clean = label.replace(/\s+/g, ' ').trim();
  const bespoke = isBespokeTenure(clean);

  // Pattern 1: Exact single-point bespoke duration with parentheses
  // e.g., "2 Years 11 Months (35 months)" or "4 Year 7 Months (55 months)"
  const parenMatch = clean.match(/^([^(]+)\((\d+)\s*(months?|days?|years?)\)$/i);
  if (parenMatch) {
    const count = parseInt(parenMatch[2], 10);
    const unitWord = parenMatch[3].toLowerCase();
    let unit = 'DAYS';
    let days = count;

    if (unitWord.startsWith('month')) {
      unit = 'MONTHS';
      days = Math.round(count * DAYS_PER_MONTH);
    } else if (unitWord.startsWith('year')) {
      unit = 'YEARS';
      days = count * DAYS_PER_YEAR;
    }

    return {
      rawLabel: clean,
      minTenureDays: days,
      maxTenureDays: days,
      minTenure: count,
      maxTenure: count,
      tenureUnit: unit,
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // Pattern 2: Normal range with separators
  const isLessThan = /(?:less\s+than(?!\s*or\s*equal)|<(?!=))/i.test(clean);
  let normalized = clean
    .replace(/\s*to\s+less\s+than\s*/gi, ' __SPLIT__ ')
    .replace(/\s*to\s*<\s*/gi, ' __SPLIT__ ')
    .replace(/\s*<=\s*/gi, ' __SPLIT__ ')
    .replace(/\s*<(?!=)\s*/gi, ' __SPLIT__ ')
    .replace(/\s*and\s+up\s+to\s*/gi, ' __SPLIT__ ')
    .replace(/\s*\bto\b\s*/gi, ' __SPLIT__ ')
    .replace(/(\d+)\s*-\s*(\d+)/g, '$1 __SPLIT__ $2');

  const parts = normalized.split(/\s+__SPLIT__\s+/);

  if (parts.length === 2) {
    const startStr = parts[0].trim();
    const endStr = parts[1].trim();

    // If start has no unit but end has unit (e.g. "7 - 14 days" or "15 to 29 days")
    const endUnitMatch = endStr.match(/(days?|months?|years?)/i);
    let fullStartStr = startStr;
    if (endUnitMatch && !startStr.match(/(days?|months?|years?)/i)) {
      fullStartStr = `${startStr} ${endUnitMatch[0]}`;
    }

    let minDays = parseDurationComponentToDays(fullStartStr);
    let maxDays = parseDurationComponentToDays(endStr);

    if (isLessThan && maxDays > minDays) {
      maxDays = maxDays - 1;
    }

    const isValid = minDays > 0 && maxDays >= minDays;

    return {
      rawLabel: clean,
      minTenureDays: minDays,
      maxTenureDays: maxDays,
      minTenure: minDays,
      maxTenure: maxDays,
      tenureUnit: 'DAYS',
      isBespoke: bespoke,
      isValid,
      error: isValid ? null : `Invalid range: min=${minDays}, max=${maxDays}`,
    };
  }

  // Pattern 3: Single boundary, e.g. "Above 5 Years" or "Up to 10 Years"
  const upToMatch = clean.match(/^(?:up\s+to|less\s+than|<)\s*(.+)$/i);
  if (upToMatch) {
    const maxDays = parseDurationComponentToDays(upToMatch[1]);
    return {
      rawLabel: clean,
      minTenureDays: 1,
      maxTenureDays: maxDays,
      minTenure: 1,
      maxTenure: maxDays,
      tenureUnit: detectTenureUnit(clean),
      isBespoke: bespoke,
      isValid: maxDays > 0,
      error: maxDays > 0 ? null : 'Could not parse max days',
    };
  }

  // Pattern 4: Single duration point, e.g. "1 Year", "2 Years", "400 Days"
  const singleDurationDays = parseDurationComponentToDays(clean);
  if (singleDurationDays > 0) {
    return {
      rawLabel: clean,
      minTenureDays: singleDurationDays,
      maxTenureDays: singleDurationDays,
      minTenure: singleDurationDays,
      maxTenure: singleDurationDays,
      tenureUnit: detectTenureUnit(clean),
      isBespoke: bespoke,
      isValid: true,
      error: null,
    };
  }

  return {
    rawLabel: clean,
    minTenureDays: 0,
    maxTenureDays: 0,
    tenureUnit: 'DAYS',
    isBespoke: bespoke,
    isValid: false,
    error: `Could not parse tenure expression: "${clean}"`,
  };
}

module.exports = {
  parseTenureRange,
  parseDurationComponentToDays,
  detectTenureUnit,
  isBespokeTenure,
  DAYS_PER_YEAR,
  DAYS_PER_MONTH,
};
