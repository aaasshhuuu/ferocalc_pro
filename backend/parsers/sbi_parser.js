// FeroCalc Verified FD Rate Engine — SBI Parser
// Parses official SBI retail domestic term deposits (< 3 Crore) HTML page.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');


/**
 * Normalizes an SBI retail tenure label into canonical DAYS or CALENDAR domain representation.
 *
 * Slabs:
 * DAYS domain:
 * 1. "7 days to 45 days" -> min: 7, max: 45 days, unit: 'DAYS'
 * 2. "46 days to 179 days" -> min: 46, max: 179 days, unit: 'DAYS'
 * 3. "180 days to 210 days" -> min: 180, max: 210 days, unit: 'DAYS'
 * 4. "211 days to less than 1 year" -> min: 211, max: 364 days, unit: 'DAYS'
 *
 * CALENDAR domain:
 * 5. "1 Year to less than 2 years" -> GTE 1Y, LT 2Y, unit: 'YEARS', days: null
 * 6. "2 years to less than 3 years" -> GTE 2Y, LT 3Y, unit: 'YEARS', days: null
 * 7. "3 years to less than 5 years" -> GTE 3Y, LT 5Y, unit: 'YEARS', days: null
 * 8. "5 years and up to 10 years" -> GTE 5Y, LTE 10Y, unit: 'YEARS', days: null
 *
 * @param {string} label
 * @returns {Object} Structured canonical tenure object
 */
function parseSbiTenure(label) {
  if (!label || typeof label !== 'string') {
    return {
      rawLabel: '',
      tenureDomain: 'DAYS',
      minTenureDays: 0,
      maxTenureDays: 0,
      tenureUnit: 'DAYS',
      minTenure: 0,
      maxTenure: 0,
      minYears: null,
      minMonths: null,
      minDaysCal: null,
      minOperator: null,
      maxYears: null,
      maxMonths: null,
      maxDaysCal: null,
      maxOperator: null,
      isBespoke: false,
      isValid: false,
      error: 'Empty tenure label',
    };
  }

  const clean = label.replace(/[\u00a0\s]+/g, ' ').trim();
  const lower = clean.toLowerCase();

  // 1. "7 days to 45 days"
  if (/^7\s*days?\s*to\s*45\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 45,
      tenureUnit: 'DAYS',
      minTenure: 7,
      maxTenure: 45,
      minYears: null,
      minMonths: null,
      minDaysCal: null,
      minOperator: null,
      maxYears: null,
      maxMonths: null,
      maxDaysCal: null,
      maxOperator: null,
      isBespoke: false,
      isValid: true,
    };
  }

  // 2. "46 days to 179 days"
  if (/^46\s*days?\s*to\s*179\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 46,
      maxTenureDays: 179,
      tenureUnit: 'DAYS',
      minTenure: 46,
      maxTenure: 179,
      minYears: null,
      minMonths: null,
      minDaysCal: null,
      minOperator: null,
      maxYears: null,
      maxMonths: null,
      maxDaysCal: null,
      maxOperator: null,
      isBespoke: false,
      isValid: true,
    };
  }

  // 3. "180 days to 210 days"
  if (/^180\s*days?\s*to\s*210\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 180,
      maxTenureDays: 210,
      tenureUnit: 'DAYS',
      minTenure: 180,
      maxTenure: 210,
      minYears: null,
      minMonths: null,
      minDaysCal: null,
      minOperator: null,
      maxYears: null,
      maxMonths: null,
      maxDaysCal: null,
      maxOperator: null,
      isBespoke: false,
      isValid: true,
    };
  }

  // 4. "211 days to less than 1 year"
  if (/^211\s*days?\s*to\s*less\s+than\s*1\s*year$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 211,
      maxTenureDays: 364,
      tenureUnit: 'DAYS',
      minTenure: 211,
      maxTenure: 364,
      minYears: null,
      minMonths: null,
      minDaysCal: null,
      minOperator: null,
      maxYears: null,
      maxMonths: null,
      maxDaysCal: null,
      maxOperator: null,
      isBespoke: false,
      isValid: true,
    };
  }

  // 5. "1 Year to less than 2 years"
  if (/^1\s*years?\s*to\s*less\s+than\s*2\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 1,
      maxTenure: 2,
      minYears: 1,
      minMonths: 0,
      minDaysCal: 0,
      minOperator: 'GTE',
      maxYears: 2,
      maxMonths: 0,
      maxDaysCal: 0,
      maxOperator: 'LT',
      isBespoke: false,
      isValid: true,
    };
  }

  // 6. "2 years to less than 3 years"
  if (/^2\s*years?\s*to\s*less\s+than\s*3\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 2,
      maxTenure: 3,
      minYears: 2,
      minMonths: 0,
      minDaysCal: 0,
      minOperator: 'GTE',
      maxYears: 3,
      maxMonths: 0,
      maxDaysCal: 0,
      maxOperator: 'LT',
      isBespoke: false,
      isValid: true,
    };
  }

  // 7. "3 years to less than 5 years"
  if (/^3\s*years?\s*to\s*less\s+than\s*5\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 3,
      maxTenure: 5,
      minYears: 3,
      minMonths: 0,
      minDaysCal: 0,
      minOperator: 'GTE',
      maxYears: 5,
      maxMonths: 0,
      maxDaysCal: 0,
      maxOperator: 'LT',
      isBespoke: false,
      isValid: true,
    };
  }

  // 8. "5 years and up to 10 years"
  if (/^5\s*years?\s*(?:and\s+)?up\s+to\s*10\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 5,
      maxTenure: 10,
      minYears: 5,
      minMonths: 0,
      minDaysCal: 0,
      minOperator: 'GTE',
      maxYears: 10,
      maxMonths: 0,
      maxDaysCal: 0,
      maxOperator: 'LTE',
      isBespoke: false,
      isValid: true,
    };
  }

  // Fallback to general tenure parser if label is non-standard
  const fallback = parseTenureRange(clean);
  return {
    rawLabel: clean,
    tenureDomain: 'DAYS',
    minTenureDays: fallback.minTenureDays,
    maxTenureDays: fallback.maxTenureDays,
    tenureUnit: fallback.tenureUnit,
    minTenure: fallback.minTenure,
    maxTenure: fallback.maxTenure,
    minYears: null,
    minMonths: null,
    minDaysCal: null,
    minOperator: null,
    maxYears: null,
    maxMonths: null,
    maxDaysCal: null,
    maxOperator: null,
    isBespoke: fallback.isBespoke,
    isValid: fallback.isValid,
    error: fallback.error,
  };
}

class SbiRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'sbi_retail_html',
      version: '1.0.0',
      bankCode: 'SBI',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');

    const sourceUrl = context.sourceUrl || 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits';
    const sourceContentHash = context.sourceContentHash || '';
    const sourceId = context.sourceId || 'sbi-retail-domestic';

    if (!html) {
      return new ExtractionResult({
        sourceId,
        bankCode: this.bankCode,
        parserId: this.id,
        parserVersion: this.version,
        sourceContentHash,
        sourceUrl,
        success: false,
        errors: ['Source document is empty'],
      });
    }

    const tables = parseHtmlTables(html);
    if (tables.length === 0) {
      return new ExtractionResult({
        sourceId,
        bankCode: this.bankCode,
        parserId: this.id,
        parserVersion: this.version,
        sourceContentHash,
        sourceUrl,
        success: false,
        rawTableCount: 0,
        errors: ['No HTML tables found on SBI page'],
      });
    }

    // Look for the retail domestic deposit table (< 3 Crore)
    // Table 1 on SBI contains "Tenors", "Public", "Senior Citizen"
    let targetTable = null;
    let headerRowIdx = -1;

    for (const table of tables) {
      for (let r = 0; r < Math.min(3, table.length); r++) {
        const rowText = table[r].join(' ').toLowerCase();
        if ((rowText.includes('tenor') || rowText.includes('tenure')) && 
            (rowText.includes('public') || rowText.includes('senior') || rowText.includes('general') || rowText.includes('rate'))) {
          targetTable = table;
          headerRowIdx = r;
          break;
        }
      }
      if (targetTable) break;
    }

    if (!targetTable || headerRowIdx === -1) {
      return new ExtractionResult({
        sourceId,
        bankCode: this.bankCode,
        parserId: this.id,
        parserVersion: this.version,
        sourceContentHash,
        sourceUrl,
        success: false,
        rawTableCount: tables.length,
        errors: ['SBI Retail Term Deposits table could not be identified by header matching'],
      });
    }

    const headerRow = targetTable[headerRowIdx];
    let regularColIdx = -1;
    let seniorColIdx = -1;
    let effectiveFrom = null;

    // Identify active revised rate columns & prioritize revised effective date
    headerRow.forEach((cell, idx) => {
      const lower = cell.toLowerCase();

      // Check revised vs existing
      if (lower.includes('revised') && (lower.includes('public') || lower.includes('regular') || lower.includes('general'))) {
        regularColIdx = idx;
        const revDate = this.parseEffectiveDate(cell);
        if (revDate) effectiveFrom = revDate;
      } else if (lower.includes('revised') && lower.includes('senior')) {
        seniorColIdx = idx;
        const revDate = this.parseEffectiveDate(cell);
        if (revDate && !effectiveFrom) effectiveFrom = revDate;
      } else if (!effectiveFrom) {
        effectiveFrom = this.parseEffectiveDate(cell);
      }
    });

    // Fallback if revised columns not found (e.g. single rate columns)
    if (regularColIdx === -1 || seniorColIdx === -1) {
      headerRow.forEach((cell, idx) => {
        const lower = cell.toLowerCase();
        if (regularColIdx === -1 && (lower.includes('public') || lower.includes('regular') || lower.includes('general'))) {
          regularColIdx = idx;
        } else if (seniorColIdx === -1 && lower.includes('senior')) {
          seniorColIdx = idx;
        }
      });
    }

    // Default column indices for standard SBI 5-column layout if still unresolved
    if (regularColIdx === -1 && headerRow.length >= 5) regularColIdx = 2;
    if (seniorColIdx === -1 && headerRow.length >= 5) seniorColIdx = 4;
    if (regularColIdx === -1 && headerRow.length === 3) regularColIdx = 1;
    if (seniorColIdx === -1 && headerRow.length === 3) seniorColIdx = 2;

    const footnotes = this.extractFootnotes(html);
    const candidates = [];
    const errors = [];

    // Process data rows
    for (let r = headerRowIdx + 1; r < targetTable.length; r++) {
      const row = targetTable[r];
      if (row.length <= Math.max(regularColIdx, seniorColIdx)) continue;

      const tenureLabel = row[0];
      const tenure = parseSbiTenure(tenureLabel);
      if (!tenure.isValid) {
        errors.push(`Row ${r}: Unable to parse tenure label "${tenureLabel}": ${tenure.error}`);
        continue;
      }

      const rawRegular = regularColIdx !== -1 ? row[regularColIdx] : null;
      const rawSenior = seniorColIdx !== -1 ? row[seniorColIdx] : null;

      const regularParsed = this.parseRateWithMarker(rawRegular);
      const seniorParsed = this.parseRateWithMarker(rawSenior);

      const regularRate = regularParsed.value;
      const seniorRate = seniorParsed.value;

      if (regularRate === null && seniorRate === null) {
        errors.push(`Row ${r}: No valid rate found in row: ${JSON.stringify(row)}`);
        continue;
      }

      // Analyze senior rate qualification & special scheme markers safely
      const rawSeniorClean = String(rawSenior || '').replace(/[\u00a0\s]+/g, ' ').trim();
      const markerSymbolMatch = seniorParsed.marker || (rawSeniorClean.match(/[*^#†‡]+/) ? rawSeniorClean.match(/[*^#†‡]+/)[0] : null);
      const seniorHasMarker = Boolean(markerSymbolMatch);

      let standardCoPublishedSeniorRate = null;
      let seniorRateCategory = 'STANDARD';
      let seniorSchemeName = null;
      let seniorNotes = null;

      if (seniorRate !== null) {
        if (seniorHasMarker) {
          // Identify associated footnote text for this specific marker
          const associatedFootnote = footnotes[markerSymbolMatch] || null;
          const resolvedScheme = this.resolveSchemeName(markerSymbolMatch, associatedFootnote, tenure);

          if (resolvedScheme) {
            seniorRateCategory = 'SPECIAL_SCHEME';
            seniorSchemeName = resolvedScheme;
            seniorNotes = associatedFootnote || (resolvedScheme === 'SBI We-Care' ? "* Including additional premium of 50 bps under 'SBI We-care' deposit scheme." : null);
            // Do NOT copy promotional special scheme rate into standard regular candidate (remains null)
            standardCoPublishedSeniorRate = null;
          } else {
            // Ambiguous, unknown, or contradictory qualification marker on senior rate (fail closed)
            seniorRateCategory = 'SPECIAL_SCHEME';
            seniorSchemeName = null; // Unresolved schemeName fails closed in CandidateValidator Rule 7
            seniorNotes = associatedFootnote;
            standardCoPublishedSeniorRate = null;
            errors.push(`Row ${r}: Senior rate "${rawSeniorClean}" has qualification marker "${markerSymbolMatch}" for tenure "${tenureLabel}" but could not be positively identified to a valid scheme (fail-closed)`);
          }
        } else {
          // Genuinely unqualified standard card rate
          standardCoPublishedSeniorRate = seniorRate;
        }
      }

      // 1. Regular Candidate (always STANDARD card rate)
      if (regularRate !== null) {
        candidates.push(new CandidateRate({
          bankId: this.bankCode,
          bankCode: this.bankCode,
          sourceId,
          productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
          customerType: 'REGULAR',
          tenureUnit: tenure.tenureUnit,
          minTenure: tenure.minTenure,
          maxTenure: tenure.maxTenure,
          minTenureDays: tenure.minTenureDays,
          maxTenureDays: tenure.maxTenureDays,
          tenureLabel: tenure.rawLabel,
          interestRate: regularRate,
          seniorCitizenRate: standardCoPublishedSeniorRate, // Null if senior rate is special-scheme-qualified or ambiguous
          minDeposit: '1000.00',
          maxDeposit: '29999999.00', // < 3 Crore
          isCallable: true,
          compoundingFrequency: 'QUARTERLY',
          effectiveFrom,
          sourceUrl,
          sourceContentHash,
          parserId: this.id,
          parserVersion: this.version,
          isBespokeTenure: tenure.isBespoke,
          rateCategory: 'STANDARD',
          schemeName: null,
          notes: null,
          rawRateText: regularParsed.rawText,
          footnoteMarker: regularParsed.marker,
          // Migration 009 / 017 Dual-Domain Tenure Fields
          tenureDomain: tenure.tenureDomain,
          sourceTenureText: tenure.rawLabel,
          minYears: tenure.minYears,
          minMonths: tenure.minMonths,
          minDaysCal: tenure.minDaysCal,
          minOperator: tenure.minOperator,
          maxYears: tenure.maxYears,
          maxMonths: tenure.maxMonths,
          maxDaysCal: tenure.maxDaysCal,
          maxOperator: tenure.maxOperator,
        }));
      }

      // 2. Senior Citizen Candidate
      if (seniorRate !== null) {
        candidates.push(new CandidateRate({
          bankId: this.bankCode,
          bankCode: this.bankCode,
          sourceId,
          productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
          customerType: 'SENIOR_CITIZEN',
          tenureUnit: tenure.tenureUnit,
          minTenure: tenure.minTenure,
          maxTenure: tenure.maxTenure,
          minTenureDays: tenure.minTenureDays,
          maxTenureDays: tenure.maxTenureDays,
          tenureLabel: tenure.rawLabel,
          interestRate: seniorRate,
          seniorCitizenRate: seniorRate,
          minDeposit: '1000.00',
          maxDeposit: '29999999.00',
          isCallable: true,
          compoundingFrequency: 'QUARTERLY',
          effectiveFrom,
          sourceUrl,
          sourceContentHash,
          parserId: this.id,
          parserVersion: this.version,
          isBespokeTenure: tenure.isBespoke,
          rateCategory: seniorRateCategory,
          schemeName: seniorSchemeName,
          notes: seniorNotes,
          rawRateText: seniorParsed.rawText,
          footnoteMarker: seniorParsed.marker,
          // Migration 009 / 017 Dual-Domain Tenure Fields
          tenureDomain: tenure.tenureDomain,
          sourceTenureText: tenure.rawLabel,
          minYears: tenure.minYears,
          minMonths: tenure.minMonths,
          minDaysCal: tenure.minDaysCal,
          minOperator: tenure.minOperator,
          maxYears: tenure.maxYears,
          maxMonths: tenure.maxMonths,
          maxDaysCal: tenure.maxDaysCal,
          maxOperator: tenure.maxOperator,
        }));
      }
    }

    const success = candidates.length > 0;
    if (!success) {
      errors.push('Parser produced zero rate candidates (treated as failure)');
    }

    return new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceContentHash,
      sourceUrl,
      success,
      candidates,
      rawTableCount: tables.length,
      effectiveFrom,
      errors,
      metadata: {
        tableRows: targetTable.length,
        regularColIdx,
        seniorColIdx,
      },
    });
  }

  /**
   * Scrapes footnotes and qualification disclaimers from the SBI HTML document.
   * Extracts paragraphs, list items, table cells, or divs starting with marker symbols.
   *
   * @param {string} html
   * @returns {Object<string, string>} Map of marker -> footnote text
   */
  extractFootnotes(html) {
    const footnotes = {};
    if (!html || typeof html !== 'string') return footnotes;

    // 1. Scrape paragraphs, list items, table cells, spans, or divs starting with marker symbols (*, ^, #, †, ‡)
    const paraMatches = html.match(/<(?:p|li|div|td|span)[^>]*>\s*([*^#†‡]+)[\s\S]*?<\/(?:p|li|div|td|span)>/gi);
    if (paraMatches) {
      for (const p of paraMatches) {
        const text = p.replace(/<[^>]+>/g, '').replace(/[\u00a0\s]+/g, ' ').trim();
        const markerMatch = text.match(/^([*^#†‡]+)/);
        if (markerMatch) {
          const marker = markerMatch[1];
          if (!footnotes[marker]) {
            footnotes[marker] = text;
          }
        }
      }
    }

    // 2. Search for explicit We-Care footnote text anywhere in the HTML as positive reference
    const weCareRegex = /(?:([*^#†‡]+)\s*)?Including\s+additional\s+premium\s+of\s+50\s+bps\s+under\s+[“”"']?SBI\s+We-care[“”"']?\s+deposit\s+scheme\.?/i;
    const match = html.match(weCareRegex);
    if (match) {
      const explicitMarker = match[1] || '*';
      let text = match[0].replace(/<[^>]+>/g, '').replace(/[\u00a0\s]+/g, ' ').trim();
      if (!text.startsWith(explicitMarker)) {
        text = explicitMarker + ' ' + text;
      }
      if (!footnotes[explicitMarker]) {
        footnotes[explicitMarker] = text;
      }
      footnotes['wecare'] = text;
    }

    return footnotes;
  }

  /**
   * Resolves a qualification marker and its footnote text to a known scheme name.
   * Only returns a scheme name if positive evidence exists.
   * If marker is unknown, footnote is missing, or footnote is contradictory/unrecognized,
   * returns null (fail-closed).
   *
   * @param {string|null} marker - The marker character (e.g. '*', '^', '#')
   * @param {string|null} footnoteText - The associated footnote text
   * @param {Object} tenure - The parsed tenure object
   * @returns {string|null} The resolved schemeName or null
   */
  resolveSchemeName(marker, footnoteText, tenure) {
    if (!footnoteText || typeof footnoteText !== 'string') {
      return null;
    }

    const cleanFootnote = footnoteText.replace(/[\u00a0\s]+/g, ' ').trim();

    // 1. Positive identification for SBI We-Care
    // Requires: Footnote explicitly mentions We-Care AND tenure slab is within 5 to 10 years (1825-3650 days)
    if (/we[- ]?care/i.test(cleanFootnote)) {
      const isFiveToTenYears =
        (tenure && tenure.minTenureDays >= 1825 && tenure.maxTenureDays <= 3650) ||
        (tenure && tenure.tenureDomain === 'CALENDAR' && tenure.minYears === 5 && tenure.maxYears === 10) ||
        (tenure && tenure.minYears === 5 && tenure.maxYears === 10);
      if (isFiveToTenYears) {
        return 'SBI We-Care';
      }
      // If footnote mentions We-Care but tenure does not match 5-10 years, fail closed (contradictory)
      return null;
    }

    // 2. Positive identification for Amrit Vrishti (444 days or specific scheme)
    if (/amrit\s+vrishti/i.test(cleanFootnote)) {
      return 'Amrit Vrishti';
    }

    // 3. Positive identification for Amrit Kalash (400 days or specific scheme)
    if (/amrit\s+kalash/i.test(cleanFootnote)) {
      return 'Amrit Kalash';
    }

    // 4. Positive identification for Sarvottam
    if (/sarvottam/i.test(cleanFootnote)) {
      return 'SBI Sarvottam';
    }

    // Contradictory, generic, or unknown footnote (e.g. "Rates subject to change", "# Disclaimer")
    // Fails closed - returns null
    return null;
  }
}

module.exports = {
  SbiRateParser,
  parseSbiTenure,
};
