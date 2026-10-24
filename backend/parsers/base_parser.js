// FeroCalc Verified FD Rate Engine — Base Parser & Data Models
//
// Rules:
// 1. Never derive senior rates by adding a generic percentage.
// 2. Never invent missing fields.
// 3. Never convert bespoke tenures into 1y/2y/3y/5y.
// 4. Preserve exact source tenure ranges and labels.
// 5. Zero rates extracted is treated as parser failure.
// 6. Extracted status is NEVER set to VERIFIED.

'use strict';

/**
 * Standardized FD rate candidate produced by parsers.
 */
class CandidateRate {
  constructor(data = {}) {
    this.bankId = data.bankId || data.bankCode || '';
    this.bankCode = data.bankCode || this.bankId;
    this.sourceId = data.sourceId || '';
    this.productType = data.productType || 'RETAIL_DOMESTIC_TERM_DEPOSIT';
    this.customerType = data.customerType || 'REGULAR'; // 'REGULAR' | 'SENIOR_CITIZEN' | 'SUPER_SENIOR_CITIZEN'
    this.tenureUnit = data.tenureUnit || 'DAYS';
    this.minTenure = data.minTenure !== undefined ? data.minTenure : 0;
    this.maxTenure = data.maxTenure !== undefined ? data.maxTenure : 0;
    this.minTenureDays = data.minTenureDays !== undefined ? data.minTenureDays : 0;
    this.maxTenureDays = data.maxTenureDays !== undefined ? data.maxTenureDays : 0;
    this.tenureLabel = data.tenureLabel || '';
    this.interestRate = data.interestRate !== undefined ? data.interestRate : null;
    this.seniorCitizenRate = data.seniorCitizenRate !== undefined ? data.seniorCitizenRate : null;
    this.superSeniorRate = data.superSeniorRate !== undefined ? data.superSeniorRate : null;
    this.minDeposit = data.minDeposit !== undefined ? data.minDeposit : null;
    this.maxDeposit = data.maxDeposit !== undefined ? data.maxDeposit : null;
    this.isCallable = data.isCallable !== undefined ? data.isCallable : true;
    this.compoundingFrequency = data.compoundingFrequency || 'QUARTERLY';
    this.effectiveFrom = data.effectiveFrom || null;
    this.effectiveUntil = data.effectiveUntil || null;
    this.sourceUrl = data.sourceUrl || '';
    this.sourceDocumentUrl = data.sourceDocumentUrl || null;
    this.sourceContentHash = data.sourceContentHash || '';
    this.extractedAt = data.extractedAt || new Date().toISOString();
    this.parserId = data.parserId || '';
    this.parserVersion = data.parserVersion || '1.0.0';
    this.isBespokeTenure = Boolean(data.isBespokeTenure);
    this.notes = data.notes || null;
    this.rateCategory = data.rateCategory || 'STANDARD'; // 'STANDARD' | 'SPECIAL_SCHEME'
    this.schemeName = data.schemeName || null;
    this.rawRateText = data.rawRateText !== undefined ? data.rawRateText : null;
    this.footnoteMarker = data.footnoteMarker || null;

    // Migration 009 Calendar Tenure Fields
    this.tenureDomain = data.tenureDomain || 'DAYS';
    this.sourceTenureText = data.sourceTenureText || this.tenureLabel;
    this.minYears = data.minYears !== undefined ? data.minYears : null;
    this.minMonths = data.minMonths !== undefined ? data.minMonths : null;
    this.minDaysCal = data.minDaysCal !== undefined ? data.minDaysCal : null;
    this.minOperator = data.minOperator || null;
    this.maxYears = data.maxYears !== undefined ? data.maxYears : null;
    this.maxMonths = data.maxMonths !== undefined ? data.maxMonths : null;
    this.maxDaysCal = data.maxDaysCal !== undefined ? data.maxDaysCal : null;
    this.maxOperator = data.maxOperator || null;
    this.canonicalTenure = data.canonicalTenure || null;

    // Validation & Anomaly state
    this.validationErrors = Array.isArray(data.validationErrors) ? [...data.validationErrors] : [];
    this.anomalyFlags = Array.isArray(data.anomalyFlags) ? [...data.anomalyFlags] : [];
    this.validationStatus = data.validationStatus || 'PENDING'; // 'VALID' | 'INVALID' | 'WARNING'

    // Staging status: STRICT GUARANTEE: NEVER 'VERIFIED'
    this.stagingStatus = 'DRAFT';
  }

  toJSON() {
    return { ...this };
  }
}

/**
 * Output of a parser run.
 */
class ExtractionResult {
  constructor(data = {}) {
    this.sourceId = data.sourceId || '';
    this.bankCode = data.bankCode || '';
    this.parserId = data.parserId || '';
    this.parserVersion = data.parserVersion || '1.0.0';
    this.sourceContentHash = data.sourceContentHash || '';
    this.sourceUrl = data.sourceUrl || '';
    this.extractedAt = data.extractedAt || new Date().toISOString();
    this.success = Boolean(data.success);
    this.candidates = Array.isArray(data.candidates) ? data.candidates : [];
    this.rawTableCount = data.rawTableCount || 0;
    this.effectiveFrom = data.effectiveFrom || null;
    this.errors = Array.isArray(data.errors) ? [...data.errors] : [];
    this.metadata = data.metadata || {};
  }
}

/**
 * Abstract Base Rate Parser.
 */
class BaseRateParser {
  constructor(options = {}) {
    this.id = options.id || 'base_parser';
    this.version = options.version || '1.0.0';
    this.bankCode = options.bankCode || 'UNKNOWN';
  }

  /**
   * Safely parses a rate string, extracting both the numeric rate and any
   * footnote marker (e.g. '*', '**', '^', '#').
   * Preserves the raw text and marker-to-footnote relationship.
   *
   * @param {string|number} raw
   * @returns {{ value: number|null, rawText: string, marker: string|null }}
   */
  parseRateWithMarker(raw) {
    if (raw === null || raw === undefined) {
      return { value: null, rawText: '', marker: null };
    }
    if (typeof raw === 'number') {
      return { value: isNaN(raw) ? null : raw, rawText: String(raw), marker: null };
    }

    const s = String(raw).trim();
    if (!s || s === '-' || s.toUpperCase() === 'NA' || s.toUpperCase() === 'N/A') {
      return { value: null, rawText: s, marker: null };
    }

    // Capture footnote markers (e.g. '*', '**', '^', '#')
    const markerMatch = s.match(/([*^#]+)/);
    const marker = markerMatch ? markerMatch[1] : null;

    // Clean numeric content
    const cleaned = s
      .replace(/%/g, '')
      .replace(/[*^#]/g, '')
      .replace(/highest/gi, '')
      .replace(/p\.a\.?/gi, '')
      .trim();

    const val = parseFloat(cleaned);
    return {
      value: isNaN(val) ? null : val,
      rawText: s,
      marker,
    };
  }

  /**
   * Safely parses a rate string into a floating-point percentage.
   * Strips artifacts like '%', '*', 'HIGHEST', spaces.
   * Returns null if unparseable or explicitly 'NA' / '-'.
   *
   * @param {string|number} raw
   * @returns {number|null}
   */
  parseRateValue(raw) {
    return this.parseRateWithMarker(raw).value;
  }

  /**
   * Parses common Indian bank date representations into ISO YYYY-MM-DD.
   * Supports:
   * - 15/12/2025
   * - October 7, 2026
   * - 6th Mar, 2026 / 19th August, 2026
   *
   * @param {string} text
   * @returns {string|null}
   */
  parseEffectiveDate(text) {
    if (!text || typeof text !== 'string') return null;

    // Pattern 1: DD/MM/YYYY or DD-MM-YYYY
    const dmyMatch = text.match(/(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})/);
    if (dmyMatch) {
      const day = dmyMatch[1].padStart(2, '0');
      const month = dmyMatch[2].padStart(2, '0');
      const year = dmyMatch[3];
      return `${year}-${month}-${day}`;
    }

    // Pattern 2: "October 7, 2026" or "7th October 2026" or "6th Mar, 2026"
    const months = {
      jan: '01', feb: '02', mar: '03', apr: '04', may: '05', jun: '06',
      jul: '07', aug: '08', sep: '09', oct: '10', nov: '11', dec: '12',
      january: '01', february: '02', march: '03', april: '04', june: '06',
      july: '07', august: '08', september: '09', october: '10', november: '11', december: '12'
    };

    // e.g. "October 7, 2026"
    const monthFirstMatch = text.match(/([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?,\s*(\d{4})/i);
    if (monthFirstMatch) {
      const mName = monthFirstMatch[1].toLowerCase();
      if (months[mName]) {
        const day = monthFirstMatch[2].padStart(2, '0');
        const year = monthFirstMatch[3];
        return `${year}-${months[mName]}-${day}`;
      }
    }

    // e.g. "6th Mar, 2026" or "19th August, 2026"
    const dayFirstMatch = text.match(/(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]+),?\s*(\d{4})/i);
    if (dayFirstMatch) {
      const mName = dayFirstMatch[2].toLowerCase();
      if (months[mName]) {
        const day = dayFirstMatch[1].padStart(2, '0');
        const year = dayFirstMatch[3];
        return `${year}-${months[mName]}-${day}`;
      }
    }

    return null;
  }

  /**
   * Main parse interface. Subclasses must implement this.
   *
   * @param {string|Buffer} sourceDocument
   * @param {Object} context
   * @returns {Promise<ExtractionResult>|ExtractionResult}
   */
  parse(sourceDocument, context = {}) {
    throw new Error(`Parser ${this.id} must implement parse(sourceDocument, context)`);
  }
}

module.exports = {
  CandidateRate,
  ExtractionResult,
  BaseRateParser,
};
