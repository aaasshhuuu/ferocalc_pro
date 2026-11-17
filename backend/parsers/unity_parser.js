// FeroCalc Verified FD Rate Engine — Unity Small Finance Bank (UNITY_SFB) Parser
// Parses official Unity Small Finance Bank callable retail domestic fixed deposit schedule (< Rs. 3 Crore).
// Source PDF: https://unity.bank.in/docs/policies/website-disclosure-effective-02-july-2026.pdf
// Portal landing: https://unity.bank.in/personal-banking/deposits/fixed-deposit
//
// Rules:
// - Extracts only Section A: "FIXED DEPOSIT RATE : Retail Investors (< Rs 3 crs)".
// - Strictly excludes Savings account rates (Section B) and Bulk rates (Section C & D).
// - Preserves regular and senior citizen rate differentiation.
// - Accurately normalizes DAYS and CALENDAR tenure domains.

'use strict';

const crypto = require('crypto');
const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { extractPdfTokens } = require('./pdf_text_extractor');

const DEFAULT_SOURCE_URL = 'https://unity.bank.in/docs/policies/website-disclosure-effective-02-july-2026.pdf';
const LANDING_PAGE_URL = 'https://unity.bank.in/personal-banking/deposits/fixed-deposit';
const EXPECTED_ROWS = 20;

const MONTH_MAP = {
  jan: '01', january: '01',
  feb: '02', february: '02',
  mar: '03', march: '03',
  apr: '04', april: '04',
  may: '05',
  jun: '06', june: '06',
  jul: '07', july: '07',
  aug: '08', august: '08',
  sep: '09', sept: '09', september: '09',
  oct: '10', october: '10',
  nov: '11', november: '11',
  dec: '12', december: '12',
};

/**
 * Normalizes tenure labels and maps them to DAYS or CALENDAR domain.
 *
 * @param {string} label
 * @returns {Object}
 */
function parseUnityTenure(label) {
  if (!label || typeof label !== 'string') {
    return { isValid: false, error: 'Empty tenure label' };
  }

  const clean = label
    .replace(/[\u00a0\s]+/g, ' ')
    .replace(/[–—−]/g, '-')
    .replace(/\bM\s+onths?\b/gi, 'Months')
    .replace(/\bD\s+ays?\b/gi, 'Days')
    .replace(/\bMonths\s+s\b/gi, 'Months')
    .replace(/\bt\b/gi, 'to')
    .replace(/\s+/g, ' ')
    .trim();

  const lower = clean.toLowerCase();

  // 1. "7 - 14 Days"
  if (/^7\s*-\s*14\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 14,
      tenureUnit: 'DAYS',
      minTenure: 7,
      maxTenure: 14,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '7D_14D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 2. "15 - 45 Days"
  if (/^15\s*-\s*45\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 15,
      maxTenureDays: 45,
      tenureUnit: 'DAYS',
      minTenure: 15,
      maxTenure: 45,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '15D_45D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 3. "46 - 60 Days"
  if (/^46\s*-\s*60\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 46,
      maxTenureDays: 60,
      tenureUnit: 'DAYS',
      minTenure: 46,
      maxTenure: 60,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '46D_60D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 4. "61 - 90 Days"
  if (/^61\s*-\s*90\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 61,
      maxTenureDays: 90,
      tenureUnit: 'DAYS',
      minTenure: 61,
      maxTenure: 90,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '61D_90D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 5. "91 - 164 Days"
  if (/^91\s*-\s*164\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 91,
      maxTenureDays: 164,
      tenureUnit: 'DAYS',
      minTenure: 91,
      maxTenure: 164,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '91D_164D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 6. "165 Days - 6 Months"
  if (/^165\s*days?\s*-\s*6\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 5,
      maxTenure: 6,
      minYears: 0, minMonths: 0, minDaysCal: 165, minOperator: 'GTE',
      maxYears: 0, maxMonths: 6, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '165D_6M',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 7. "> 6 Months - 201 Days"
  if (/^>\s*6\s*months?\s*-\s*201\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 6,
      maxTenure: 7,
      minYears: 0, minMonths: 6, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 0, maxMonths: 0, maxDaysCal: 201, maxOperator: 'LTE',
      canonicalTenure: '6M1D_201D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 8. "202 Days - 364 Days"
  if (/^202\s*days?\s*-\s*364\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 202,
      maxTenureDays: 364,
      tenureUnit: 'DAYS',
      minTenure: 202,
      maxTenure: 364,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '202D_364D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 9. "12 Months"
  if (/^12\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 1,
      maxTenure: 1,
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '1Y_1Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 10. "12 Months to 1 Days" or "12 Months 1 Day"
  if (/^12\s*months?\s*(?:to\s*1\s*days?|1\s*day|\+\s*1\s*day)$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 1,
      maxTenure: 1,
      minYears: 1, minMonths: 0, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 1, maxMonths: 0, maxDaysCal: 1, maxOperator: 'LTE',
      canonicalTenure: '1Y1D_1Y1D',
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // 11. ">12 Months 1 Day - 500 Days"
  if (/^>\s*12\s*months?\s*1\s*days?\s*-\s*500\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 1,
      maxTenure: 1,
      minYears: 1, minMonths: 0, minDaysCal: 2, minOperator: 'GTE',
      maxYears: 0, maxMonths: 0, maxDaysCal: 500, maxOperator: 'LTE',
      canonicalTenure: '1Y2D_500D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 12. "501 Days" (Special scheme)
  if (/^501\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 501,
      maxTenureDays: 501,
      tenureUnit: 'DAYS',
      minTenure: 501,
      maxTenure: 501,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '501D_501D',
      isBespoke: true,
      isSpecialScheme: true,
      schemeName: 'UNITY_501',
      rateCategory: 'SPECIAL_SCHEME',
      isValid: true,
      error: null,
    };
  }

  // 13. "502 Days - 18 Months"
  if (/^502\s*days?\s*-\s*18\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 16,
      maxTenure: 18,
      minYears: 0, minMonths: 0, minDaysCal: 502, minOperator: 'GTE',
      maxYears: 1, maxMonths: 6, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '502D_1Y6M',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 14. "> 18 Months - 700 Days"
  if (/^>\s*18\s*months?\s*-\s*700\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 18,
      maxTenure: 23,
      minYears: 1, minMonths: 6, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 0, maxMonths: 0, maxDaysCal: 700, maxOperator: 'LTE',
      canonicalTenure: '1Y6M1D_700D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 15. "701 Days" (Special scheme)
  if (/^701\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 701,
      maxTenureDays: 701,
      tenureUnit: 'DAYS',
      minTenure: 701,
      maxTenure: 701,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '701D_701D',
      isBespoke: true,
      isSpecialScheme: true,
      schemeName: 'UNITY_701',
      rateCategory: 'SPECIAL_SCHEME',
      isValid: true,
      error: null,
    };
  }

  // 16. "702 Days to 998 Days"
  if (/^702\s*days?\s*(?:to|-)\s*998\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 702,
      maxTenureDays: 998,
      tenureUnit: 'DAYS',
      minTenure: 702,
      maxTenure: 998,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '702D_998D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 17. "999 Days to 34 Months"
  if (/^999\s*days?\s*(?:to|-)\s*34\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 32,
      maxTenure: 34,
      minYears: 0, minMonths: 0, minDaysCal: 999, minOperator: 'GTE',
      maxYears: 2, maxMonths: 10, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '999D_2Y10M',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 18. ">34 Months - 36 Months"
  if (/^>\s*34\s*months?\s*-\s*36\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 34,
      maxTenure: 36,
      minYears: 2, minMonths: 10, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 3, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '2Y10M1D_3Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 19. ">36 Months - 60 Months"
  if (/^>\s*36\s*months?\s*-\s*60\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 3,
      maxTenure: 5,
      minYears: 3, minMonths: 0, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 5, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '3Y1D_5Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 20. ">60 Months - 120 Months"
  if (/^>\s*60\s*months?\s*-\s*120\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 5,
      maxTenure: 10,
      minYears: 5, minMonths: 0, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 10, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '5Y1D_10Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  return {
    rawLabel: clean,
    isValid: false,
    error: `Unrecognized Unity SFB tenure label: "${label}"`,
  };
}

class UnityRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'unity_retail_pdf',
      version: '1.0.0',
      bankCode: 'UNITY_SFB',
    });
  }

  /**
   * Parse effective date string into ISO YYYY-MM-DD.
   *
   * @param {string} str
   * @returns {string|null}
   */
  parseEffectiveDate(str) {
    if (!str) return null;
    // Collapse any spaces between digits, e.g. "202 6" -> "2026", "1 1" -> "11"
    let clean = str.replace(/(\d)\s+(?=\d)/g, '$1');
    clean = clean.replace(/[,\s]+/g, ' ').trim();

    // "11th June 2026" or "11 th June 2026"
    const m = clean.match(/(\d{1,2})\s*(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})/i);
    if (m) {
      const day = m[1].padStart(2, '0');
      const monStr = m[2].toLowerCase();
      const month = MONTH_MAP[monStr];
      const year = m[3];
      if (month) return `${year}-${month}-${day}`;
    }

    // "DD/MM/YYYY" or "DD-MM-YYYY" or "DD.MM.YYYY"
    const m2 = clean.match(/(\d{1,2})[./-](\d{1,2})[./-](\d{4})/);
    if (m2) {
      const day = m2[1].padStart(2, '0');
      const month = m2[2].padStart(2, '0');
      const year = m2[3];
      return `${year}-${month}-${day}`;
    }

    return null;
  }

  /**
   * Parse Unity SFB official rates schedule from PDF buffer or text tokens.
   *
   * @param {Buffer|string|string[]} sourceDocument
   * @param {Object} context
   * @returns {ExtractionResult}
   */
  parse(sourceDocument, context = {}) {
    const sourceUrl = context.sourceUrl || DEFAULT_SOURCE_URL;
    const sourceContentHash = context.sourceContentHash ||
      crypto.createHash('sha256').update(typeof sourceDocument === 'string' ? sourceDocument : Buffer.from(sourceDocument)).digest('hex');
    const sourceId = context.sourceId || 'unity-retail-domestic';

    const fail = (msg, extra = {}) => new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceContentHash,
      sourceUrl,
      success: false,
      errors: [msg],
      metadata: {
        extractedRows: 0,
        validRows: 0,
        candidateCount: 0,
        yieldIncludedAsRate: false,
        savingsRatesExcluded: true,
        bulkTablesExcluded: true,
        nonCallableExcluded: true,
        landingPageUrl: LANDING_PAGE_URL,
      },
      ...extra,
    });

    if (!sourceDocument || (typeof sourceDocument === 'string' && !sourceDocument.trim())) {
      return fail('Source document is empty');
    }

    let tokens;
    try {
      tokens = extractPdfTokens(sourceDocument);
    } catch (e) {
      return fail('Failed to extract PDF text tokens: ' + e.message);
    }

    if (!tokens || tokens.length === 0) {
      return fail('No text tokens extracted from Unity Small Finance Bank PDF rate card');
    }

    const textJoined = tokens.join(' ');
    const errors = [];

    // 1. Validate Document Scope
    const hasFixedDeposit = /fixed deposit/i.test(textJoined);
    const hasRetailScope = /retail investors/i.test(textJoined) && /<\s*rs\s*3\s*crs?/i.test(textJoined);
    if (!hasFixedDeposit || !hasRetailScope) {
      errors.push('Document scope mismatch: expected Fixed Deposit Retail Investors (< Rs 3 crs)');
    }

    // 2. Locate Section A (Retail Investors < Rs 3 crs) column headers
    let seniorIdx = -1;
    for (let i = 0; i < tokens.length - 1; i++) {
      const t = tokens[i].toLowerCase();
      const next = (tokens[i + 1] || '').toLowerCase();
      if (t === 'senior' && (next === 'citizen' || next.startsWith('citizen'))) {
        seniorIdx = i;
        break;
      }
    }

    if (seniorIdx === -1) {
      seniorIdx = tokens.findIndex(t => t.toLowerCase().includes('senior'));
    }

    if (seniorIdx === -1) {
      errors.push('Could not find Senior Citizen column header in Section A table');
    }

    // 3. Extract Published Effective Date from Section A Header ONLY (preventing cross-table leakage)
    const headerLimit = seniorIdx !== -1 ? seniorIdx : tokens.length;
    const headerText = tokens.slice(0, headerLimit).join(' ');

    const dateMatch = headerText.match(/revised\s+from\s*(\d{1,2}\s*(?:st|nd|rd|th)?\s+[A-Za-z]+[,\s]+(?:\d{4}|\d(?:\s*\d){3}))/i) ||
                      headerText.match(/w\.?e\.?f\.?\s*(\d{1,2}\s*(?:st|nd|rd|th)?\s+[A-Za-z]+[,\s]+(?:\d{4}|\d(?:\s*\d){3}))/i) ||
                      headerText.match(/revised\s+from\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i) ||
                      headerText.match(/w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i);

    let effectiveFrom = null;
    if (dateMatch) {
      effectiveFrom = this.parseEffectiveDate(dateMatch[1]);
    }

    if (!dateMatch || !effectiveFrom) {
      errors.push('Missing or unparseable published effective date in rate card header');
    }

    // Locate start of rate rows after "% p.a." in column header
    let tableStartIdx = -1;
    if (seniorIdx !== -1) {
      for (let i = seniorIdx + 1; i < Math.min(seniorIdx + 10, tokens.length); i++) {
        if (tokens[i].toLowerCase().includes('p.a.')) {
          tableStartIdx = i + 1;
          break;
        }
      }
      if (tableStartIdx === -1) {
        tableStartIdx = seniorIdx + 2;
      }
    }

    // Locate boundary ending Section A: "Note:" or "B. SAVING"
    let endIdx = -1;
    if (tableStartIdx !== -1) {
      for (let i = tableStartIdx; i < tokens.length; i++) {
        const t = tokens[i];
        if (t === 'Note:' || t.includes('SAVING DEPOSIT') || (t === 'B.' && (tokens[i + 1] || '').includes('SAVING'))) {
          endIdx = i;
          break;
        }
      }
    }
    if (endIdx === -1) {
      endIdx = tokens.length;
    }

    if (tableStartIdx !== -1 && tableStartIdx >= endIdx) {
      errors.push('Malformed Section A table boundaries');
    }

    if (errors.length > 0) {
      return fail('Validation failed before table extraction: ' + errors.join('; '));
    }

    // Normalize Section A token stream into row text
    let sectionAText = tokens.slice(tableStartIdx, endIdx).join(' ');

    // Normalize fragmented decimal numbers in token stream
    // e.g. "7. 5 0 %", "8 . 00 %", "7 . 80 %"
    sectionAText = sectionAText.replace(/(\d+)\s*\.\s*(\d+)\s*(\d+)\s*%/g, '$1.$2$3%');
    sectionAText = sectionAText.replace(/(\d+)\s*\.\s*(\d+)\s*%/g, '$1.$2%');
    sectionAText = sectionAText.replace(/(\d+)\s*\.\s+(\d{2})\s*%/g, '$1.$2%');
    // Ensure whole integers like "8%" become "8.00%" without touching existing decimals like "4.00%"
    sectionAText = sectionAText.replace(/(\d+)\s*%/g, (m, d, offset, str) => {
      if (offset > 0 && str[offset - 1] === '.') return m;
      return d + '.00%';
    });

    // Normalize words
    sectionAText = sectionAText.replace(/\bM\s+onths?\b/gi, 'Months');
    sectionAText = sectionAText.replace(/\bD\s+ays?\b/gi, 'Days');
    sectionAText = sectionAText.replace(/\bMonths\s+s\b/gi, 'Months');
    sectionAText = sectionAText.replace(/\bt\b/gi, 'to');
    sectionAText = sectionAText.replace(/\s+/g, ' ');

    // Extract rows matching: <tenure> <regularRate>% <seniorRate>%
    const rowRegex = /(.*?)\s+(\d+\.\d{2})%\s+(\d+\.\d{2})%/g;
    const candidates = [];
    let extractedRows = 0;
    let validRows = 0;
    let match;

    while ((match = rowRegex.exec(sectionAText)) !== null) {
      extractedRows++;
      const rawTenure = match[1].trim();
      const regularVal = parseFloat(match[2]);
      const seniorVal = parseFloat(match[3]);

      if (!rawTenure) {
        errors.push(`Row ${extractedRows}: Missing tenure label for rate pair ${regularVal} / ${seniorVal}`);
        continue;
      }

      if (isNaN(regularVal) || regularVal <= 0 || regularVal > 25) {
        errors.push(`Row ${extractedRows}: Invalid regular rate: ${match[2]}`);
        continue;
      }

      if (isNaN(seniorVal) || seniorVal <= 0 || seniorVal > 25) {
        errors.push(`Row ${extractedRows}: Invalid senior citizen rate: ${match[3]}`);
        continue;
      }

      const tenure = parseUnityTenure(rawTenure);
      if (!tenure.isValid) {
        errors.push(`Row ${extractedRows}: Invalid tenure: ${tenure.error}`);
        continue;
      }

      validRows++;

      const isSubOneYear = tenure.tenureDomain === 'DAYS' && tenure.maxTenureDays < 365;

      const common = {
        bankCode: this.bankCode,
        bankId: this.bankCode,
        sourceId,
        productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        tenureUnit: tenure.tenureUnit,
        minTenure: tenure.minTenure,
        maxTenure: tenure.maxTenure,
        minTenureDays: tenure.minTenureDays,
        maxTenureDays: tenure.maxTenureDays,
        tenureLabel: tenure.rawLabel,
        sourceTenureText: rawTenure,
        minDeposit: 1000,
        maxDeposit: '29999999.00',
        isCallable: true,
        compoundingFrequency: 'QUARTERLY',
        effectiveFrom,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: tenure.isBespoke,
        rateCategory: tenure.rateCategory || 'STANDARD',
        schemeName: tenure.schemeName || null,
        validationStatus: 'PENDING',
        stagingStatus: 'DRAFT',
        tenureDomain: tenure.tenureDomain,
        minYears: tenure.minYears,
        minMonths: tenure.minMonths,
        minDaysCal: tenure.minDaysCal,
        minOperator: tenure.minOperator,
        maxYears: tenure.maxYears,
        maxMonths: tenure.maxMonths,
        maxDaysCal: tenure.maxDaysCal,
        maxOperator: tenure.maxOperator,
        canonicalTenure: tenure.canonicalTenure,
      };

      // 1. Regular Depositor
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regularVal,
        seniorCitizenRate: seniorVal,
        rawRateText: `${regularVal.toFixed(2)}%`,
        notes: isSubOneYear
          ? 'Unity SFB callable retail domestic fixed deposit (< Rs. 3 Crore). Sub-one-year tenures are not eligible for NRE deposits.'
          : 'Unity SFB callable retail domestic fixed deposit (< Rs. 3 Crore).',
      }));

      // 2. Senior Citizen Depositor
      const spread = Math.round((seniorVal - regularVal) * 100) / 100;
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorVal,
        seniorCitizenRate: seniorVal,
        rawRateText: `${seniorVal.toFixed(2)}%`,
        notes: spread > 0
          ? `Senior Citizen rates (+${spread.toFixed(2)}%) apply strictly to Resident Indian Senior Citizens. Strictly not applicable to non-resident depositors.`
          : 'Resident Indian Senior Citizens rate (no additional spread for this tenure slab). Strictly not applicable to non-resident depositors.',
      }));
    }

    if (validRows !== EXPECTED_ROWS) {
      errors.push(`Published callable retail row count mismatch: expected ${EXPECTED_ROWS}, found ${validRows}`);
    }

    const success = errors.length === 0 && validRows === EXPECTED_ROWS && candidates.length === EXPECTED_ROWS * 2;

    return new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceContentHash,
      sourceUrl,
      effectiveFrom,
      extractedAt: new Date().toISOString(),
      success,
      errors,
      candidates: success ? candidates : [],
      metadata: {
        extractedRows,
        validRows,
        candidateCount: candidates.length,
        yieldIncludedAsRate: false,
        savingsRatesExcluded: true,
        bulkTablesExcluded: true,
        nonCallableExcluded: true,
        landingPageUrl: LANDING_PAGE_URL,
      },
    });
  }
}

module.exports = {
  UnityRateParser,
  parseUnityTenure,
  EXPECTED_ROWS,
  DEFAULT_SOURCE_URL,
  LANDING_PAGE_URL,
};
