// FeroCalc Verified FD Rate Engine — Central Bank of India retail FD parser
// Parses only the published domestic callable retail table (< Rs. 3 crore) and callable special schemes (333, 444, 555 days).
// Non-callable tables (above 1 Cr to < 3 Cr), bulk tables (>= 3 Cr), green deposits, and floating deposits are strictly excluded.
// Annualized yield is strictly ignored and never emitted as the interest rate.
// Source is intentionally disabled in source_registry until live HTML parity and human review are complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.centralbank.bank.in/en/interest-rates-on-deposit';
const EXPECTED_STANDARD_ROWS = 12;
const EXPECTED_SPECIAL_SCHEMES = 3;

function normalizeTenureLabel(raw) {
  return String(raw || '')
    .replace(/[–—−]/g, '-')
    .replace(/(\d+)\s*-\s*(\d+)/g, '$1 to $2')
    .replace(/^(\d+)\s*$/, '$1 days')
    .replace(/\byrs?\b/gi, 'years')
    .replace(/& above upto/gi, 'to')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Extracts structured calendar tenure bounds from Central Bank tenure labels.
 */
function extractCalendarTenure(label) {
  const norm = normalizeTenureLabel(label);

  // Pattern: "1 years to less than 2 years"
  if (/^1\s*years?\s*to\s*less\s+than\s*2\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 12, minDaysCal: 0, minOperator: '>=',
      maxYears: 2, maxMonths: 24, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "2 years to less than 3 years"
  if (/^2\s*years?\s*to\s*less\s+than\s*3\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 2, minMonths: 24, minDaysCal: 0, minOperator: '>=',
      maxYears: 3, maxMonths: 36, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "3 years to less than 5 years"
  if (/^3\s*years?\s*to\s*less\s+than\s*5\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 3, minMonths: 36, minDaysCal: 0, minOperator: '>=',
      maxYears: 5, maxMonths: 60, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "5 years to 10 years"
  if (/^5\s*years?\s*to\s*10\s*years?$/i.test(norm)) {
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

class CentralBankRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'central_bank_retail_html',
      version: '1.0.0',
      bankCode: 'CENTRAL_BANK',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'central-bank-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on Central Bank of India rate page');

    const errors = [];

    // 1. Identify Standard Callable Retail Table (< Rs. 3 Crore)
    // Anchors: 'Rates for Deposits less than Rs. 3 Crore' and '7 -14 days' and '5 years & above upto 10 years'
    // Exclude: tables mentioning '3 Cr to Rs. 10 Cr' or 'Non-Callable' or 'GREEN' or 'FLOATING'
    const standardTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasRetailScope = flat.includes('deposits less than rs. 3 crore') || flat.includes('less than rs. 3 crore as of');
      const hasTenureRange = flat.includes('7 -14 days') && flat.includes('5 years & above upto 10 years');
      const isNotBulk = !flat.includes('rs. 3 cr to rs. 10 cr') && !flat.includes('above 10 crores');
      const isNotNonCallable = !flat.includes('non-callable');

      return hasRetailScope && hasTenureRange && isNotBulk && isNotNonCallable;
    });

    if (!standardTable) {
      return fail('Could not identify the standard callable retail table (< Rs. 3 Crore)', tables.length);
    }

    // Scoped Effective Date for Standard Retail Table
    const standardFlat = standardTable.flat().join(' ');
    const stdDateMatch = standardFlat.match(/w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i);
    const standardEffectiveFrom = stdDateMatch ? this.parseEffectiveDate(stdDateMatch[1]) : null;

    if (!standardEffectiveFrom) {
      errors.push('Missing explicit standard callable retail effective date in table header');
    }

    // 2. Identify Callable Special Schemes (333, 444, 555 days)
    // Table 5: 333 Days (Cent 333 / Cent Yuva)
    // Table 7: 444 Days (Cent 444)
    // Table 9: 555 Days (Cent 555)
    // Each must have 'Callable' header and MUST NOT be 'Non-Callable'
    function findCallableSpecialTable(days) {
      return tables.find((t) => {
        const flat = t.flat().join(' ').toLowerCase();
        const hasDays = flat.includes(String(days));
        const isCallable = flat.includes('callable') && !flat.includes('non-callable');
        const hasWef = flat.includes('w.e.f');
        const isSmall = t.length <= 4;
        return hasDays && isCallable && hasWef && isSmall;
      });
    }

    const table333 = findCallableSpecialTable('333');
    const table444 = findCallableSpecialTable('444');
    const table555 = findCallableSpecialTable('555');

    if (!table333) errors.push('Missing callable 333-day special scheme table');
    if (!table444) errors.push('Missing callable 444-day special scheme table');
    if (!table555) errors.push('Missing callable 555-day special scheme table');

    // Scoped dates for special schemes
    function extractSchemeDate(table) {
      if (!table) return null;
      const flat = table.flat().join(' ');
      const m = flat.match(/w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i);
      return m ? m[1] : null;
    }

    const date333Str = extractSchemeDate(table333);
    const effective333 = date333Str ? this.parseEffectiveDate(date333Str) : null;
    if (!effective333) errors.push('Missing explicit effective date for callable 333-day scheme');

    const date444Str = extractSchemeDate(table444);
    const effective444 = date444Str ? this.parseEffectiveDate(date444Str) : null;
    if (!effective444) errors.push('Missing explicit effective date for callable 444-day scheme');

    const date555Str = extractSchemeDate(table555);
    const effective555 = date555Str ? this.parseEffectiveDate(date555Str) : null;
    if (!effective555) errors.push('Missing explicit effective date for callable 555-day scheme');

    // Excluded tables auditing
    let excludedTableCount = 0;
    const excludedTables = [];
    for (const t of tables) {
      if (t === standardTable || t === table333 || t === table444 || t === table555) continue;
      excludedTableCount++;
      const flat = t.flat().join(' ').toLowerCase();
      let reason = 'Unrelated table';
      if (flat.includes('non-callable')) {
        reason = 'Non-callable deposits (> 1 Cr to < 3 Cr)';
      } else if (flat.includes('10 crore') || flat.includes('3 cr to rs. 10 cr')) {
        reason = 'Bulk deposits table (>= 3 Crore)';
      } else if (flat.includes('green deposit')) {
        reason = 'Cent Green Deposit scheme';
      } else if (flat.includes('floating deposit')) {
        reason = 'Cent Floating Deposit scheme';
      } else if (flat.includes('savings deposits')) {
        reason = 'Savings account deposit rates';
      } else if (flat.includes('callable – period (days)') && flat.includes('333') && flat.includes('444')) {
        reason = 'Summary special scheme table without individual effective dates';
      }
      excludedTables.push({ rowCount: t.length, reason });
    }

    const candidates = [];
    let extractedRows = 0;
    let validStandardRows = 0;

    // Process Standard Table (Table 4)
    // Row 0-2: Headers
    // Rows 3-14: Data rows
    const stdDataRows = standardTable.slice(3);
    if (stdDataRows.length !== EXPECTED_STANDARD_ROWS) {
      errors.push(`Published standard row count mismatch: expected ${EXPECTED_STANDARD_ROWS}, found ${stdDataRows.length}`);
    }

    for (const row of stdDataRows) {
      const rawLabel = String(row[0] || '').trim();
      if (!rawLabel) continue;
      extractedRows++;

      const normalized = normalizeTenureLabel(rawLabel);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid callable tenure label: "${rawLabel}" (normalized: "${normalized}")`);
        continue;
      }

      // Col 1: General Card Rate; Col 2: General Yield (excluded)
      // Col 3: Senior Card Rate;  Col 4: Senior Yield (excluded)
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

      validStandardRows++;

      const calFields = extractCalendarTenure(rawLabel);
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
        effectiveFrom: standardEffectiveFrom,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: tenure.isBespoke,
        rateCategory: 'STANDARD',
        schemeName: null,
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
          ? 'Central Bank of India callable retail domestic term deposit below Rs. 3 Crore. Sub-one-year tenures are not eligible for NRE deposits.'
          : 'Central Bank of India callable retail domestic term deposit below Rs. 3 Crore.',
      }));

      // 2. Senior Citizen (+0.50% across all callable slabs)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: seniorRate.rawText,
        footnoteMarker: seniorRate.marker,
        notes: 'Senior Citizen rates (+0.50%) apply strictly to Resident Indian Senior Citizens (aged 60 years and above). Super Senior Citizens (80 years and above) receive additional 0.75%. Strictly not applicable to NRE/NRO.',
      }));
    }

    // Process Special Schemes (333, 444, 555 days)
    const specialConfigs = [
      { table: table333, days: 333, scheme: 'CENT_333', effective: effective333, label: '333' },
      { table: table444, days: 444, scheme: 'CENT_444', effective: effective444, label: '444' },
      { table: table555, days: 555, scheme: 'CENT_555', effective: effective555, label: '555' },
    ];

    let validSpecialSchemes = 0;

    for (const sc of specialConfigs) {
      if (!sc.table) continue;
      // Data row is row index 2 in 3-row table
      const dataRow = sc.table.find(r => r.length >= 4 && String(r[0] || '').trim() === String(sc.days));
      if (!dataRow) {
        errors.push(`Could not find data row for ${sc.days}-day scheme in its dedicated table`);
        continue;
      }

      extractedRows++;

      const regularRate = this.parseRateWithMarker(dataRow[1]);
      const seniorRate = this.parseRateWithMarker(dataRow[3]);

      if (regularRate.value === null) {
        errors.push(`Missing regular rate for special scheme ${sc.scheme}`);
        continue;
      }
      if (seniorRate.value === null) {
        errors.push(`Missing senior rate for special scheme ${sc.scheme}`);
        continue;
      }

      validSpecialSchemes++;

      const common = {
        bankCode: this.bankCode,
        bankId: this.bankCode,
        sourceId,
        productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        tenureUnit: 'DAYS',
        minTenure: sc.days,
        maxTenure: sc.days,
        minTenureDays: sc.days,
        maxTenureDays: sc.days,
        tenureLabel: sc.label,
        sourceTenureText: `${sc.days} Days (${sc.scheme})`,
        minDeposit: null,
        maxDeposit: '29999999.00',
        isCallable: true,
        compoundingFrequency: 'QUARTERLY',
        effectiveFrom: sc.effective,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: true,
        rateCategory: 'SPECIAL_SCHEME',
        schemeName: sc.scheme,
        validationStatus: 'PENDING',
        tenureDomain: 'DAYS',
        minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
        maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      };

      // 1. Regular Special Scheme
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regularRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: regularRate.rawText,
        footnoteMarker: regularRate.marker,
        notes: `Central Bank of India special scheme ${sc.scheme} (${sc.days} Days) callable retail deposit below Rs. 3 Crore.`,
      }));

      // 2. Senior Citizen Special Scheme
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: seniorRate.rawText,
        footnoteMarker: seniorRate.marker,
        notes: `Central Bank of India special scheme ${sc.scheme} (${sc.days} Days) for Resident Indian Senior Citizens. Strictly not applicable to NRE/NRO.`,
      }));
    }

    const success = errors.length === 0 &&
      validStandardRows === EXPECTED_STANDARD_ROWS &&
      validSpecialSchemes === EXPECTED_SPECIAL_SCHEMES;

    return new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceContentHash,
      sourceUrl,
      extractedAt: context.extractedAt || new Date().toISOString(),
      effectiveFrom: standardEffectiveFrom,
      rawTableCount: tables.length,
      candidates,
      success,
      errors,
      metadata: {
        productScope: 'CALLABLE_RETAIL_DOMESTIC_BELOW_3_CRORE',
        extractedRows,
        validStandardRows,
        validSpecialSchemes,
        expectedStandardRows: EXPECTED_STANDARD_ROWS,
        expectedSpecialSchemes: EXPECTED_SPECIAL_SCHEMES,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        nonCallableRatesIncluded: false,
        yieldIncludedAsRate: false,
        bulkTablesExcluded: true,
        greenDepositsExcluded: true,
        floatingDepositsExcluded: true,
        specialSchemesExtracted: ['CENT_333', 'CENT_444', 'CENT_555'],
        effectiveDatesByTable: {
          standardCallableRetail: standardEffectiveFrom,
          cent333Callable: effective333,
          cent444Callable: effective444,
          cent555Callable: effective555,
        },
        excludedTableCount,
        excludedTables,
      },
    });
  }
}

module.exports = {
  CentralBankRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_STANDARD_ROWS,
  EXPECTED_SPECIAL_SCHEMES,
};
