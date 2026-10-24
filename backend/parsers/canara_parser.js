// FeroCalc Verified FD Rate Engine — Canara Bank retail FD parser
// Parses only the published domestic callable table for deposits below Rs. 3 crore.
// Non-callable columns (Above 1 Cr to < 3 Cr), annualized yields, and bulk tables (>= 3 Cr) are strictly excluded.
// Source is intentionally disabled in source_registry until live HTML parity and human review are complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.canarabank.bank.in/term-deposits-rate-of-interest-p.a.';
const EXPECTED_ROWS = 12;

function normalizeTenureLabel(raw) {
  return String(raw || '')
    .replace(/[*#$]/g, '')
    .replace(/\(except[^\)]*\)/gi, '')
    .replace(/& above/gi, '')
    .replace(/\bonly\b/gi, '')
    .replace(/[–—−]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Extracts structured calendar tenure bounds from Canara tenure labels.
 */
function extractCalendarTenure(label) {
  const norm = normalizeTenureLabel(label);

  // Pattern: "7 Days to 45 Days"
  if (/^7\s*days\s*to\s*45\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    };
  }

  // Pattern: "46 Days to 90 Days"
  if (/^46\s*days\s*to\s*90\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    };
  }

  // Pattern: "91 Days to 179 Days"
  if (/^91\s*days\s*to\s*179\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    };
  }

  // Pattern: "180 Days to 269 Days"
  if (/^180\s*days\s*to\s*269\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    };
  }

  // Pattern: "270 Days to less than 1 Year"
  if (/^270\s*days\s*to\s*less\s+than\s*1\s*year$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 0, minMonths: 9, minDaysCal: 0, minOperator: '>=',
      maxYears: 1, maxMonths: 12, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "1 Year to 1 year 3 months"
  if (/^1\s*year\s*to\s*1\s*year\s*3\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 12, minDaysCal: 0, minOperator: '>=',
      maxYears: 1, maxMonths: 15, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  // Pattern: "444 Days"
  if (/^444\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    };
  }

  // Pattern: "555 Days"
  if (/^555\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    };
  }

  // Pattern: "Above 1 Year 3 months to less than 2 Years"
  if (/^above\s*1\s*year\s*3\s*months\s*to\s*less\s+than\s*2\s*years$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 15, minDaysCal: 1, minOperator: '>=',
      maxYears: 2, maxMonths: 24, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "2 Years to less than 3 Years"
  if (/^2\s*years\s*to\s*less\s+than\s*3\s*years$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 2, minMonths: 24, minDaysCal: 0, minOperator: '>=',
      maxYears: 3, maxMonths: 36, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "3 Years to less than 5 Years"
  if (/^3\s*years\s*to\s*less\s+than\s*5\s*years$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 3, minMonths: 36, minDaysCal: 0, minOperator: '>=',
      maxYears: 5, maxMonths: 60, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "5 Years to 10 Years"
  if (/^5\s*years\s*to\s*10\s*years$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 5, minMonths: 60, minDaysCal: 0, minOperator: '>=',
      maxYears: 10, maxMonths: 120, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  return {
    tenureDomain: 'DAYS',
    minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
    maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
  };
}

class CanaraRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'canara_retail_html',
      version: '1.0.0',
      bankCode: 'CANARA',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'canara-retail-domestic';
    const sourceContentHash = context.sourceContentHash || '';

    const fail = (message, rawTableCount = 0) => new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceUrl,
      sourceContentHash,
      success: false,
      rawTableCount,
      candidates: [],
      errors: [message],
    });

    if (!html.trim()) return fail('Source document is empty');

    const tables = parseHtmlTables(html);
    if (!tables.length) return fail('No HTML tables found on Canara Bank rate page');

    // 1. Identify Table 0: Primary Domestic Retail Table (< Rs. 3 Crore)
    // Anchors: 'Rate of Interest' and 'less than Rs.3 Crore' and 'Callable' and '444 Days'
    const retailTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasTitle = flat.includes('less than rs.3 crore') || flat.includes('less than rs. 3 crore');
      const hasCallable = flat.includes('callable');
      const hasSchemes = flat.includes('444 days') && flat.includes('555 days');
      const isBulkOnly = flat.includes('3 crore & above') || flat.includes('3 crore - less than 10 crore');

      return hasTitle && hasCallable && hasSchemes && !isBulkOnly;
    });

    if (!retailTable) {
      return fail('Could not identify the primary callable retail term deposit table (< Rs. 3 Crore)', tables.length);
    }

    // Scoped Effective Date: Table 0 header contains "w.e.f. 17.03.2026"
    const textOnly = html
      .replace(/<[^>]+>/g, ' ')
      .replace(/\u00a0|&nbsp;/g, ' ')
      .replace(/\s+/g, ' ');

    const dateMatch = textOnly.match(
      /(?:For\s*Deposits\s*less\s*than\s*Rs\.?\s*3\s*Crore|Domestic[^\n]{0,80}?less\s*than\s*Rs\.?\s*3\s*Crore)[^\n]{0,100}?w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{1,2}(?:\s*(?:st|nd|rd|th))?\s+[a-z]+[,\s]+\d{4})/i
    );
    const effectiveFrom = dateMatch ? this.parseEffectiveDate(dateMatch[1].replace(/(\d{1,2})\s*(?:st|nd|rd|th)\b/i, '$1')) : null;

    const errors = [];
    if (!effectiveFrom) {
      errors.push('Missing explicit callable retail term deposit effective date scoped to Table 0');
    }

    // Excluded tables auditing
    let excludedTableCount = 0;
    const excludedTables = [];
    for (const t of tables) {
      if (t === retailTable) continue;
      excludedTableCount++;
      const flat = t.flat().join(' ').toLowerCase();
      let reason = 'Unrelated table';
      if (flat.includes('green deposits')) {
        reason = 'Canara Retail Green Deposits';
      } else if (flat.includes('3 crore') || flat.includes('bulk')) {
        reason = 'Bulk deposits table (>= 3 Crore)';
      }
      excludedTables.push({ rowCount: t.length, reason });
    }

    // Locate data rows:
    // Header rows in Table 0:
    // Row 0: Table Title
    // Row 1: A. Domestic
    // Row 2: Less than Rs. 3 Crore
    // Row 3: Callable | Non Callable
    // Row 4: General Public | Senior Citizen | General Public | Senior Citizen
    // Row 5: Rate of Interest | Annualised yield | Rate of Interest | Annualised yield ...
    // Row 6: Term Deposits (All Maturities) header
    // Rows 7 to 18: The 12 callable tenure rows
    let dataRows = [];
    for (let r = 0; r < retailTable.length; r++) {
      const row = retailTable[r];
      const label = String(row[0] || '').trim();
      if (/^\d+\s*days/i.test(label) || /^[1-9]\s*year/i.test(label) || /^above\s*1\s*year/i.test(label)) {
        dataRows.push(row);
      }
    }

    if (dataRows.length !== EXPECTED_ROWS) {
      errors.push(`Published callable retail row count mismatch: expected ${EXPECTED_ROWS}, found ${dataRows.length}`);
    }

    const candidates = [];
    let extractedRows = 0;
    let validRows = 0;

    for (const row of dataRows) {
      const rawLabel = String(row[0] || '').trim();
      if (!rawLabel) continue;
      extractedRows++;

      const normalized = normalizeTenureLabel(rawLabel);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid callable tenure label: "${rawLabel}" (normalized: "${normalized}")`);
        continue;
      }

      // Card Rates:
      // Col 1 is Regular Card Rate (Rate of Interest % p.a.)
      // Col 2 is Regular Annualised Interest Yield (MUST BE EXCLUDED)
      // Col 3 is Senior Citizen Card Rate (Rate of Interest % p.a. #)
      // Col 4 is Senior Citizen Annualised Interest Yield (MUST BE EXCLUDED)
      // Col 5-8 are Non-Callable rates (MUST BE EXCLUDED)
      const regularRate = this.parseRateWithMarker(row[1]);
      const seniorRate = this.parseRateWithMarker(row[3]);

      if (regularRate.value === null) {
        errors.push(`Missing regular card interest rate for row "${rawLabel}"`);
        continue;
      }
      if (seniorRate.value === null) {
        errors.push(`Missing senior citizen card interest rate for row "${rawLabel}"`);
        continue;
      }

      validRows++;

      const calFields = extractCalendarTenure(rawLabel);

      // Check for special schemes
      let isSpecialScheme = false;
      let schemeName = null;
      let rateCategory = 'STANDARD';
      if (/444\s*days/i.test(rawLabel)) {
        isSpecialScheme = true;
        schemeName = 'CANARA_444';
        rateCategory = 'SPECIAL_SCHEME';
      } else if (/555\s*days/i.test(rawLabel)) {
        isSpecialScheme = true;
        schemeName = 'CANARA_555';
        rateCategory = 'SPECIAL_SCHEME';
      }

      const isSubOneYear = tenure.maxTenureDays < 365;

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
        tenureLabel: rawLabel,
        sourceTenureText: rawLabel,
        minDeposit: null,
        maxDeposit: '29999999.00',
        isCallable: true,
        compoundingFrequency: 'QUARTERLY',
        effectiveFrom,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: tenure.isBespoke || isSpecialScheme,
        rateCategory,
        schemeName,
        validationStatus: 'PENDING',
        ...calFields,
      };

      // 1. Regular Customer
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regularRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: regularRate.rawText,
        footnoteMarker: regularRate.marker,
        notes: isSubOneYear
          ? 'Canara Bank callable retail domestic term deposit below Rs. 3 Crore. Sub-one-year tenures are not eligible for NRE deposits.'
          : 'Canara Bank callable retail domestic term deposit below Rs. 3 Crore.',
      }));

      // 2. Senior Citizen
      const seniorSpread = Math.round((seniorRate.value - regularRate.value) * 100) / 100;
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: seniorRate.rawText,
        footnoteMarker: seniorRate.marker,
        notes: seniorSpread > 0
          ? 'Senior Citizen rates (+0.50%) apply strictly to domestic term deposits of 180 days and above for Resident Indian Senior Citizens. Strictly not applicable to NRO, NRE, or Capital Gains deposits.'
          : 'For tenures below 180 days, senior citizen rates are identical to general public card rates.',
      }));
    }

    const success = errors.length === 0 && validRows === EXPECTED_ROWS;

    return new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceContentHash,
      sourceUrl,
      extractedAt: context.extractedAt || new Date().toISOString(),
      effectiveFrom,
      rawTableCount: tables.length,
      candidates,
      success,
      errors,
      metadata: {
        productScope: 'CALLABLE_RETAIL_DOMESTIC_BELOW_3_CRORE',
        extractedRows,
        validRows,
        expectedRows: EXPECTED_ROWS,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        nonCallableRatesIncluded: false,
        yieldIncludedAsRate: false,
        bulkTablesExcluded: true,
        specialSchemesExtracted: ['CANARA_444', 'CANARA_555'],
        excludedTableCount,
        excludedTables,
      },
    });
  }
}

module.exports = {
  CanaraRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_ROWS,
};
