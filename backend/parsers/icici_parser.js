// FeroCalc Verified FD Rate Engine — ICICI Parser
// Parses official ICICI domestic fixed deposit rates HTML page.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

class IciciRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'icici_retail_html',
      version: '1.0.0',
      bankCode: 'ICICI',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');

    const sourceUrl = context.sourceUrl || 'https://www.icicibank.com/personal-banking/deposits/fixed-deposit/fd-interest-rates';
    const sourceContentHash = context.sourceContentHash || '';
    const sourceId = context.sourceId || 'icici-retail-domestic';

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
        errors: ['No HTML tables found on ICICI page'],
      });
    }

    // Try to extract effective date from page text (e.g. "w.e.f. from October 7, 2026")
    let effectiveFrom = null;
    const dateMatch = html.match(/(?:w\.e\.f\.?\s*(?:from)?|effective\s+from)\s*([a-z0-9,\s]{3,30}\d{4})/i);
    if (dateMatch) {
      effectiveFrom = this.parseEffectiveDate(dateMatch[1]);
    }

    // Identify Table 1: Contains "premature withdrawal" or "Tenure"
    let targetTable = null;
    for (const table of tables) {
      for (let r = 0; r < Math.min(3, table.length); r++) {
        const rowText = table[r].join(' ').toLowerCase();
        if (rowText.includes('premature withdrawal') || (rowText.includes('tenure') && rowText.includes('general citizen'))) {
          targetTable = table;
          break;
        }
      }
      if (targetTable) break;
    }

    // Fallback: table 0
    if (!targetTable && tables.length > 0) {
      targetTable = tables[0];
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
        errors: ['ICICI domestic fixed deposit table could not be identified'],
      });
    }

    // In ICICI Table 1:
    // Row 0: ["With premature withdrawal facility", "Tenure", "Without premature withdrawal facility"]
    // Row 1: ["General citizen", "Senior citizen", "", "General citizen", "Senior citizen"]
    // Data rows:
    // Col 0: Callable Regular
    // Col 1: Callable Senior
    // Col 2: Tenure label
    // Col 3: Non-callable Regular
    // Col 4: Non-callable Senior
    const callableRegularCol = 0;
    const callableSeniorCol = 1;
    const tenureCol = 2;
    const nonCallableRegularCol = 3;
    const nonCallableSeniorCol = 4;

    const footnotes = this.extractFootnotes(html);
    const startDataRow = 2; // Data begins at row 2
    const candidates = [];
    const errors = [];

    for (let r = startDataRow; r < targetTable.length; r++) {
      const row = targetTable[r];
      if (row.length <= tenureCol) continue;

      const tenureLabel = row[tenureCol];
      if (!tenureLabel || tenureLabel.toLowerCase().includes('tenure')) continue;

      const tenure = parseTenureRange(tenureLabel);
      if (!tenure.isValid) {
        errors.push(`Row ${r}: Unable to parse tenure "${tenureLabel}": ${tenure.error}`);
        continue;
      }

      // 1. Callable (With premature withdrawal facility)
      const rawCallableRegular = row[callableRegularCol] || null;
      const rawCallableSenior = row[callableSeniorCol] || null;

      const callableRegularParsed = this.parseRateWithMarker(rawCallableRegular);
      const callableSeniorParsed = this.parseRateWithMarker(rawCallableSenior);

      const callableRegularRate = callableRegularParsed.value;
      const callableSeniorRate = callableSeniorParsed.value;

      // Analyze callable senior rate qualification safely
      const rawCallableSeniorClean = String(rawCallableSenior || '').replace(/[\u00a0\s]+/g, ' ').trim();
      const callableMarkerMatch = callableSeniorParsed.marker || (rawCallableSeniorClean.match(/[*^#†‡]+/) ? rawCallableSeniorClean.match(/[*^#†‡]+/)[0] : null);
      const callableSeniorHasMarker = Boolean(callableMarkerMatch);

      let callableStandardCoPublishedSeniorRate = null;
      let callableSeniorRateCategory = 'STANDARD';
      let callableSeniorSchemeName = null;
      let callableSeniorNotes = null;

      if (callableSeniorRate !== null) {
        if (callableSeniorHasMarker) {
          const associatedFootnote = footnotes[callableMarkerMatch] || null;
          const resolvedScheme = this.resolveSchemeName(callableMarkerMatch, associatedFootnote, tenure);

          if (resolvedScheme) {
            callableSeniorRateCategory = 'SPECIAL_SCHEME';
            callableSeniorSchemeName = resolvedScheme;
            callableSeniorNotes = associatedFootnote;
            callableStandardCoPublishedSeniorRate = null;
          } else {
            // Ambiguous, unknown, or contradictory qualification marker on senior rate (fail closed)
            callableSeniorRateCategory = 'SPECIAL_SCHEME';
            callableSeniorSchemeName = null; // Unresolved schemeName fails closed in CandidateValidator Rule 7
            callableSeniorNotes = associatedFootnote;
            callableStandardCoPublishedSeniorRate = null;
            errors.push(`Row ${r}: Callable Senior rate "${rawCallableSeniorClean}" has qualification marker "${callableMarkerMatch}" for tenure "${tenureLabel}" but could not be positively identified to a valid scheme (fail-closed)`);
          }
        } else {
          callableStandardCoPublishedSeniorRate = callableSeniorRate;
        }
      }

      if (callableRegularRate !== null) {
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
          interestRate: callableRegularRate,
          seniorCitizenRate: callableStandardCoPublishedSeniorRate,
          minDeposit: '10000.00',
          maxDeposit: '20000000.00', // Retail deposit limit
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
          rawRateText: callableRegularParsed.rawText,
          footnoteMarker: callableRegularParsed.marker,
        }));
      }

      if (callableSeniorRate !== null) {
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
          interestRate: callableSeniorRate,
          seniorCitizenRate: callableSeniorRate,
          minDeposit: '10000.00',
          maxDeposit: '20000000.00',
          isCallable: true,
          compoundingFrequency: 'QUARTERLY',
          effectiveFrom,
          sourceUrl,
          sourceContentHash,
          parserId: this.id,
          parserVersion: this.version,
          isBespokeTenure: tenure.isBespoke,
          rateCategory: callableSeniorRateCategory,
          schemeName: callableSeniorSchemeName,
          notes: callableSeniorNotes,
          rawRateText: callableSeniorParsed.rawText,
          footnoteMarker: callableSeniorParsed.marker,
        }));
      }

      // 2. Non-Callable (Without premature withdrawal facility) if columns exist
      if (row.length > nonCallableRegularCol) {
        const rawNonCallableRegular = row[nonCallableRegularCol] || null;
        const rawNonCallableSenior = row[nonCallableSeniorCol] || null;

        const nonCallableRegularParsed = this.parseRateWithMarker(rawNonCallableRegular);
        const nonCallableSeniorParsed = this.parseRateWithMarker(rawNonCallableSenior);

        const nonCallableRegularRate = nonCallableRegularParsed.value;
        const nonCallableSeniorRate = nonCallableSeniorParsed.value;

        // Analyze non-callable senior rate qualification safely
        const rawNonCallableSeniorClean = String(rawNonCallableSenior || '').replace(/[\u00a0\s]+/g, ' ').trim();
        const nonCallableMarkerMatch = nonCallableSeniorParsed.marker || (rawNonCallableSeniorClean.match(/[*^#†‡]+/) ? rawNonCallableSeniorClean.match(/[*^#†‡]+/)[0] : null);
        const nonCallableSeniorHasMarker = Boolean(nonCallableMarkerMatch);

        let nonCallableStandardCoPublishedSeniorRate = null;
        let nonCallableSeniorRateCategory = 'STANDARD';
        let nonCallableSeniorSchemeName = null;
        let nonCallableSeniorNotes = null;

        if (nonCallableSeniorRate !== null) {
          if (nonCallableSeniorHasMarker) {
            const associatedFootnote = footnotes[nonCallableMarkerMatch] || null;
            const resolvedScheme = this.resolveSchemeName(nonCallableMarkerMatch, associatedFootnote, tenure);

            if (resolvedScheme) {
              nonCallableSeniorRateCategory = 'SPECIAL_SCHEME';
              nonCallableSeniorSchemeName = resolvedScheme;
              nonCallableSeniorNotes = associatedFootnote;
              nonCallableStandardCoPublishedSeniorRate = null;
            } else {
              nonCallableSeniorRateCategory = 'SPECIAL_SCHEME';
              nonCallableSeniorSchemeName = null;
              nonCallableSeniorNotes = associatedFootnote;
              nonCallableStandardCoPublishedSeniorRate = null;
              errors.push(`Row ${r}: Non-Callable Senior rate "${rawNonCallableSeniorClean}" has qualification marker "${nonCallableMarkerMatch}" for tenure "${tenureLabel}" but could not be positively identified to a valid scheme (fail-closed)`);
            }
          } else {
            nonCallableStandardCoPublishedSeniorRate = nonCallableSeniorRate;
          }
        }

        if (nonCallableRegularRate !== null) {
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
            tenureLabel: `${tenure.rawLabel} (Non-Callable)`,
            interestRate: nonCallableRegularRate,
            seniorCitizenRate: nonCallableStandardCoPublishedSeniorRate,
            minDeposit: '10000.00',
            maxDeposit: '20000000.00',
            isCallable: false,
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
            rawRateText: nonCallableRegularParsed.rawText,
            footnoteMarker: nonCallableRegularParsed.marker,
          }));
        }

        if (nonCallableSeniorRate !== null) {
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
            tenureLabel: `${tenure.rawLabel} (Non-Callable)`,
            interestRate: nonCallableSeniorRate,
            seniorCitizenRate: nonCallableSeniorRate,
            minDeposit: '10000.00',
            maxDeposit: '20000000.00',
            isCallable: false,
            compoundingFrequency: 'QUARTERLY',
            effectiveFrom,
            sourceUrl,
            sourceContentHash,
            parserId: this.id,
            parserVersion: this.version,
            isBespokeTenure: tenure.isBespoke,
            rateCategory: nonCallableSeniorRateCategory,
            schemeName: nonCallableSeniorSchemeName,
            notes: nonCallableSeniorNotes,
            rawRateText: nonCallableSeniorParsed.rawText,
            footnoteMarker: nonCallableSeniorParsed.marker,
          }));
        }
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
      },
    });
  }

  /**
   * Scrapes footnotes and qualification disclaimers from the ICICI HTML document.
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

    // 2. Search for explicit Golden Years footnote text anywhere in HTML as positive reference
    const iciciGoldenYearsRegex = /(?:([*^#†‡]+)\s*)?(?:additional\s+premium|golden\s+years)[\s\S]{0,100}golden\s+years/i;
    const match = html.match(iciciGoldenYearsRegex);
    if (match) {
      const explicitMarker = match[1] || '*';
      let text = match[0].replace(/<[^>]+>/g, '').replace(/[\u00a0\s]+/g, ' ').trim();
      if (!text.startsWith(explicitMarker)) {
        text = explicitMarker + ' ' + text;
      }
      if (!footnotes[explicitMarker]) {
        footnotes[explicitMarker] = text;
      }
      footnotes['golden_years'] = text;
    }

    return footnotes;
  }

  /**
   * Resolves a qualification marker and its footnote text to a known ICICI scheme name.
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

    // 1. Positive identification for ICICI Golden Years FD
    // Requires: Footnote explicitly mentions "Golden Years" AND tenure slab is within 5 to 10 years (1825-3650 days)
    if (/golden\s+years/i.test(cleanFootnote)) {
      if (tenure && tenure.minTenureDays >= 1825 && tenure.maxTenureDays <= 3650) {
        return 'ICICI Golden Years';
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
  IciciRateParser,
};
