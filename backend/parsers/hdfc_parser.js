// FeroCalc Verified FD Rate Engine — HDFC Parser
// Parses official HDFC retail domestic deposits (< 3 Crore) HTML page.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');
const { getCanonicalSlabByLabel } = require('./hdfc_canonical_tenure');

class HdfcRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'hdfc_retail_html',
      version: '1.0.0',
      bankCode: 'HDFC',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');

    const sourceUrl = context.sourceUrl || 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate';
    const sourceContentHash = context.sourceContentHash || '';
    const sourceId = context.sourceId || 'hdfc-retail-domestic';

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
        errors: ['No HTML tables found on HDFC page'],
      });
    }

    // Try to extract effective date specific to the target table (< 3 Crore)
    let effectiveFrom = null;

    // Look for the date preceding the "< 3 Crore" table
    const tableRegex = /<table[^>]*>[\s\S]*?(?:<\s*3\s*crore|less\s+than\s+3\s*crore|tenure\s+bucket)[\s\S]*?<\/table>/i;
    const tableMatch = tableRegex.exec(html);
    if (tableMatch) {
      const tableStart = tableMatch.index;
      const preText = html.substring(Math.max(0, tableStart - 15000), tableStart);
      const dateRegex = /(?:applicable\s+from|effective\s+from|w\.e\.f\.?)\s*([^<>\n\r]{1,40})/gi;
      let m;
      let lastDateStr = null;
      while ((m = dateRegex.exec(preText)) !== null) {
        lastDateStr = m[1];
      }
      if (lastDateStr) {
        effectiveFrom = this.parseEffectiveDate(lastDateStr);
      }
    }

    // Fallback: Global page match if table-specific heading not found
    if (!effectiveFrom) {
      const dateMatch = html.match(/(?:applicable\s+from|effective\s+from|w\.e\.f\.?)\s*([^<>\n\r]{1,40})/i);
      if (dateMatch) {
        effectiveFrom = this.parseEffectiveDate(dateMatch[1]);
      }
    }

    // Identify Table 1: "< 3 Crore" or "Tenure Bucket" with "Senior Citizen Rates"
    let targetTable = null;
    let headerRowIdx = -1;

    for (const table of tables) {
      // Look across first 3 rows of each table
      for (let r = 0; r < Math.min(3, table.length); r++) {
        const rowText = table[r].join(' ').toLowerCase();
        if ((rowText.includes('< 3 crore') || rowText.includes('less than 3 crore') || rowText.includes('tenure bucket')) &&
            table.some(row => row.some(c => c.toLowerCase().includes('senior')))) {
          targetTable = table;
          headerRowIdx = r;
          break;
        }
      }
      if (targetTable) break;
    }

    // Fallback: If table 1 has tenure and senior
    if (!targetTable && tables.length > 0) {
      const firstTable = tables[0];
      if (firstTable.some(row => row.some(c => c.toLowerCase().includes('senior')))) {
        targetTable = firstTable;
        headerRowIdx = 1;
      }
    }

    if (!targetTable) {
      return new ExtractionResult({
        sourceId,
        bankCode: this.bankCode,
        parserId: this.id,
        parserVersion: this.version,
        sourceContentHash,
        sourceUrl,
        success: false,
        rawTableCount: tables.length,
        errors: ['HDFC retail domestic deposit table (< 3 Crore) could not be identified'],
      });
    }

    // In HDFC Table 1:
    // Row 0 is often ["Tenure Bucket", "< 3 Crore"]
    // Row 1 is often ["", "Interest Rate (per annum)", "**Senior Citizen Rates (per annum)"]
    let regularColIdx = 1;
    let seniorColIdx = 2;

    // Scan headers to confirm column indices
    for (let r = 0; r <= Math.min(2, targetTable.length - 1); r++) {
      targetTable[r].forEach((cell, idx) => {
        const lower = cell.toLowerCase();
        if (lower.includes('senior')) {
          seniorColIdx = idx;
        } else if (lower.includes('interest rate') || lower.includes('general')) {
          regularColIdx = idx;
        }
      });
    }

    const startDataRow = (targetTable[0].some(c => c.toLowerCase().includes('days')) ? 0 :
                          (targetTable[1] && targetTable[1].some(c => c.toLowerCase().includes('days')) ? 1 : 2));

    const footnotes = this.extractFootnotes(html);
    const candidates = [];
    const errors = [];

    for (let r = startDataRow; r < targetTable.length; r++) {
      const row = targetTable[r];
      if (row.length <= 1) continue;

      const tenureLabel = row[0];
      if (!tenureLabel || tenureLabel.toLowerCase().includes('tenure') || tenureLabel.toLowerCase().includes('tenor')) {
        continue; // Header row repetition
      }

      const tenure = parseTenureRange(tenureLabel);
      if (!tenure.isValid) {
        errors.push(`Row ${r}: Unable to parse tenure "${tenureLabel}": ${tenure.error}`);
        continue;
      }

      const rawRegular = row[regularColIdx] || null;
      const rawSenior = row[seniorColIdx] || null;

      const regularParsed = this.parseRateWithMarker(rawRegular);
      const seniorParsed = this.parseRateWithMarker(rawSenior);

      const regularRate = regularParsed.value;
      const seniorRate = seniorParsed.value;

      if (regularRate === null && seniorRate === null) {
        errors.push(`Row ${r}: No rate found for tenure "${tenureLabel}"`);
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
          const associatedFootnote = footnotes[markerSymbolMatch] || null;
          const resolvedScheme = this.resolveSchemeName(markerSymbolMatch, associatedFootnote, tenure);

          if (resolvedScheme) {
            seniorRateCategory = 'SPECIAL_SCHEME';
            seniorSchemeName = resolvedScheme;
            seniorNotes = associatedFootnote;
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

      const canonicalSlab = getCanonicalSlabByLabel(tenureLabel);
      const tenureDomain = canonicalSlab ? canonicalSlab.tenureDomain : 'DAYS';
      const sourceTenureText = canonicalSlab ? canonicalSlab.publishedTenureLabel : tenure.rawLabel;
      const minYears = canonicalSlab ? canonicalSlab.minYears : null;
      const minMonths = canonicalSlab ? canonicalSlab.minMonths : null;
      const minDaysCal = canonicalSlab ? canonicalSlab.minDaysCal : null;
      const minOperator = canonicalSlab ? canonicalSlab.minOperator : null;
      const maxYears = canonicalSlab ? canonicalSlab.maxYears : null;
      const maxMonths = canonicalSlab ? canonicalSlab.maxMonths : null;
      const maxDaysCal = canonicalSlab ? canonicalSlab.maxDaysCal : null;
      const maxOperator = canonicalSlab ? canonicalSlab.maxOperator : null;

      // Regular Candidate
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
          seniorCitizenRate: standardCoPublishedSeniorRate, // Null if senior rate is special-scheme or ambiguous
          minDeposit: '5000.00',
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
          // Migration 009 Calendar Tenure Fields
          tenureDomain,
          sourceTenureText,
          minYears,
          minMonths,
          minDaysCal,
          minOperator,
          maxYears,
          maxMonths,
          maxDaysCal,
          maxOperator,
          canonicalTenure: canonicalSlab,
        }));
      }

      // Senior Citizen Candidate
      if (seniorRate !== null) {
        const residentSeniorEligibilityNote = seniorNotes || 'Applicable to resident senior citizens only (does not apply to NRIs per HDFC policy)';
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
          minDeposit: '5000.00',
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
          notes: residentSeniorEligibilityNote,
          rawRateText: seniorParsed.rawText,
          footnoteMarker: seniorParsed.marker,
          // Migration 009 Calendar Tenure Fields
          tenureDomain,
          sourceTenureText,
          minYears,
          minMonths,
          minDaysCal,
          minOperator,
          maxYears,
          maxMonths,
          maxDaysCal,
          maxOperator,
          canonicalTenure: canonicalSlab,
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
   * Scrapes footnotes and qualification disclaimers from the HDFC HTML document.
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

    // 2. Search for explicit Senior Citizen Care footnote text anywhere in HTML as positive reference
    const hdfcCareRegex = /(?:([*^#†‡]+)\s*)?(?:an\s+additional\s+premium|special\s+drive\s+offer)[\s\S]{0,100}senior\s+citizen\s+care/i;
    const match = html.match(hdfcCareRegex);
    if (match) {
      const explicitMarker = match[1] || '*';
      let text = match[0].replace(/<[^>]+>/g, '').replace(/[\u00a0\s]+/g, ' ').trim();
      if (!text.startsWith(explicitMarker)) {
        text = explicitMarker + ' ' + text;
      }
      if (!footnotes[explicitMarker]) {
        footnotes[explicitMarker] = text;
      }
      footnotes['senior_citizen_care'] = text;
    }

    return footnotes;
  }

  /**
   * Resolves a qualification marker and its footnote text to a known HDFC scheme name.
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

    // 1. Positive identification for HDFC Senior Citizen Care FD
    // Requires: Footnote explicitly mentions "Senior Citizen Care" AND tenure slab is within 5 to 10 years (1825-3650 days)
    if (/senior\s+citizen\s+care/i.test(cleanFootnote)) {
      if (tenure && tenure.minTenureDays >= 1825 && tenure.maxTenureDays <= 3650) {
        return 'HDFC Senior Citizen Care';
      }
      // If footnote mentions scheme but tenure does not match 5-10 years, fail closed (contradictory)
      return null;
    }

    // Contradictory, generic, or unknown footnote (e.g. "Rates subject to change", "# Disclaimer")
    // Fails closed - returns null
    return null;
  }
}

module.exports = {
  HdfcRateParser,
};
