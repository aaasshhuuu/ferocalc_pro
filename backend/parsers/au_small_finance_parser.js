// FeroCalc Verified FD Rate Engine — AU Small Finance Bank retail FD parser
// Parses only the published domestic/NRE/NRO callable table for deposits below Rs. 3 crore.
// Non-callable tables (>= 1 Cr to < 3 Cr), bulk tables (>= 3 Cr), and monthly-payout tables are strictly excluded.
// Annualized yield is strictly ignored and never emitted as the interest rate.
// Source is intentionally disabled in source_registry until live HTML parity and human review are complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.au.bank.in/interest-rates/fixed-deposit-interest-rates';
const EXPECTED_ROWS = 12;

function normalizeTenureLabel(raw) {
  return String(raw || '')
    .replace(/[–—−]/g, '-')
    .replace(/\s+/g, ' ')
    .replace(/(\d+)\s*months?\s*1\s*days?\s*to\s*less\s+than\s*(\d+)\s*months?/i, '$1 months 1 day to less than $2 months')
    .replace(/(\d+)\s*months?\s*1\s*days?\s*to\s*(\d+)\s*months?/i, '$1 months 1 day to $2 months')
    .trim();
}

/**
 * Extracts structured calendar tenure bounds from AU tenure labels.
 */
function extractCalendarTenure(label) {
  const norm = normalizeTenureLabel(label);
  const isLessThan = /less\s+than/i.test(norm);

  // Pattern: "7 Days to 1 Month 15 Days"
  if (/^7\s*days\s*to\s*1\s*month\s*15\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 0, minMonths: 0, minDaysCal: 7, minOperator: '>=',
      maxYears: 0, maxMonths: 1, maxDaysCal: 15, maxOperator: '<=',
    };
  }

  // Pattern: "1 Month 16 Days to 3 Months"
  if (/^1\s*month\s*16\s*days\s*to\s*3\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 0, minMonths: 1, minDaysCal: 16, minOperator: '>=',
      maxYears: 0, maxMonths: 3, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  // Pattern: "(\d+) Months? 1 Day to (\d+) Months"
  const m1Match = norm.match(/^(\d+)\s*months?\s*1\s*days?\s*to\s*(\d+)\s*months$/i);
  if (m1Match) {
    const minMo = parseInt(m1Match[1], 10);
    const maxMo = parseInt(m1Match[2], 10);
    return {
      tenureDomain: 'CALENDAR',
      minYears: Math.floor(minMo / 12), minMonths: minMo, minDaysCal: 1, minOperator: '>=',
      maxYears: Math.floor(maxMo / 12), maxMonths: maxMo, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  // Pattern: "(\d+) Months? 1 Day to less than (\d+) Months"
  const ltMatch = norm.match(/^(\d+)\s*months?\s*1\s*days?\s*to\s*less\s+than\s*(\d+)\s*months$/i);
  if (ltMatch) {
    const minMo = parseInt(ltMatch[1], 10);
    const maxMo = parseInt(ltMatch[2], 10);
    return {
      tenureDomain: 'CALENDAR',
      minYears: Math.floor(minMo / 12), minMonths: minMo, minDaysCal: 1, minOperator: '>=',
      maxYears: Math.floor(maxMo / 12), maxMonths: maxMo, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "(\d+) Months to (\d+) Months"
  const m2Match = norm.match(/^(\d+)\s*months?\s*to\s*(\d+)\s*months$/i);
  if (m2Match) {
    const minMo = parseInt(m2Match[1], 10);
    const maxMo = parseInt(m2Match[2], 10);
    return {
      tenureDomain: 'CALENDAR',
      minYears: Math.floor(minMo / 12), minMonths: minMo, minDaysCal: 0, minOperator: '>=',
      maxYears: Math.floor(maxMo / 12), maxMonths: maxMo, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  return {
    tenureDomain: 'DAYS',
    minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
    maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
  };
}

class AuSmallFinanceRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'au_small_finance_retail_html',
      version: '1.0.0',
      bankCode: 'AU_SMALL_FINANCE',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'au-small-finance-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on AU Small Finance Bank rate page');

    // Cleaned plain text for scoped date and section regex extraction
    const textOnly = html
      .replace(/<[^>]+>/g, ' ')
      .replace(/\u00a0|&nbsp;/g, ' ')
      .replace(/\s+/g, ' ');

    const cleanDateText = (s) => (s ? s.replace(/(\d{1,2})\s*(?:st|nd|rd|th)\b/i, '$1') : '');

    // 1. Identify Table 0: Regular Callable Retail Table (< Rs. 3 Crore)
    // Anchors: 'Domestic, NRE' and 'amounts less than INR 3 Crore'
    // Exclude: 'Non-callable', 'Monthly payout', 'Senior Citizen'
    const regularTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasTenureAnchor = flat.includes('7 days to 1 month 15 days') && flat.includes('60 months to 120 months');
      const hasRateHeader = flat.includes('interest rates (per annum)');
      const hasYieldHeader = flat.includes('annualized yield');
      const isNonCallable = flat.includes('annualised rate');
      const isMonthly = flat.includes('monthly payout');
      const isSenior = flat.includes('4.00%');

      return hasTenureAnchor && hasRateHeader && hasYieldHeader && !isNonCallable && !isMonthly && !isSenior;
    });

    if (!regularTable) {
      return fail('Could not identify the primary regular callable retail FD table (< Rs. 3 Crore)', tables.length);
    }

    // 2. Identify Table 2: Senior Citizen Callable Retail Table (< Rs. 3 Crore)
    const seniorTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasTenureAnchor = flat.includes('7 days to 1 month 15 days') && flat.includes('60 months to 120 months');
      const hasRateHeader = flat.includes('interest rates (per annum)');
      const hasYieldHeader = flat.includes('annualized yield');
      const isNonCallable = flat.includes('annualised rate');
      const isMonthly = flat.includes('monthly payout');
      const hasSeniorRate = flat.includes('4.00%');

      return hasTenureAnchor && hasRateHeader && hasYieldHeader && hasSeniorRate && !isNonCallable && !isMonthly && table !== regularTable;
    });

    if (!seniorTable) {
      return fail('Could not identify the senior citizen callable retail FD table (< Rs. 3 Crore)', tables.length);
    }

    // Scoped Effective Dates
    // 1. Regular table effective date (Table 0: Section 1.a)
    const regularDateMatch = textOnly.match(
      /(?:1\.a\)|Domestic,\s*NRE[^\n]{0,100}?(?:Retail\s*Fixed\s*Deposit|Fixed\s*Deposit\s*-\s*Interest\s*Rates))(?:(?!Non-callable|Senior|Monthly).){0,250}?w\.?e\.?f\.?\s*(\d{1,2}(?:\s*(?:st|nd|rd|th))?\s+[a-z]+[,\s]+\d{4}|\d{1,2}[./-]\d{1,2}[./-]\d{4})/i
    );
    const regularEffectiveFrom = regularDateMatch ? this.parseEffectiveDate(cleanDateText(regularDateMatch[1])) : null;

    // 2. Senior table effective date (Table 2: Section 2)
    const seniorDateMatch = textOnly.match(
      /(?:2\.\s*)?Senior\s*Citizen\s*Fixed\s*Deposit(?:(?!Monthly|Non-callable|Domestic).){0,250}?w\.?e\.?f\.?\s*(\d{1,2}(?:\s*(?:st|nd|rd|th))?\s+[a-z]+[,\s]+\d{4}|\d{1,2}[./-]\d{1,2}[./-]\d{4})/i
    );
    const seniorEffectiveFrom = seniorDateMatch ? this.parseEffectiveDate(cleanDateText(seniorDateMatch[1])) : null;

    // 3. Non-callable table effective date (Table 1: Section 1.b)
    const nonCallableDateMatch = textOnly.match(
      /Non-callable\s*rates(?:(?!Senior|Monthly|1\.a).){0,250}?w\.?e\.?f\.?\s*(\d{1,2}(?:\s*(?:st|nd|rd|th))?\s+[a-z]+[,\s]+\d{4}|\d{1,2}[./-]\d{1,2}[./-]\d{4})/i
    );
    const nonCallableEffectiveFrom = nonCallableDateMatch ? this.parseEffectiveDate(cleanDateText(nonCallableDateMatch[1])) : null;

    // 4. Monthly payout table effective date (Table 3: Section 3)
    const monthlyDateMatch = textOnly.match(
      /Monthly\s*Payout\s*Fixed\s*Deposits(?:(?!Non-callable|Senior|1\.a).){0,250}?w\.?e\.?f\.?\s*(\d{1,2}(?:\s*(?:st|nd|rd|th))?\s+[a-z]+[,\s]+\d{4}|\d{1,2}[./-]\d{1,2}[./-]\d{4})/i
    );
    const monthlyEffectiveFrom = monthlyDateMatch ? this.parseEffectiveDate(cleanDateText(monthlyDateMatch[1])) : null;

    const errors = [];
    if (!regularEffectiveFrom) {
      errors.push('Missing explicit regular callable retail FD effective date scoped to Table 0');
    }
    if (!seniorEffectiveFrom) {
      errors.push('Missing explicit senior citizen callable retail FD effective date scoped to Table 2');
    }

    // Excluded tables auditing
    let excludedTableCount = 0;
    const excludedTables = [];
    for (const t of tables) {
      if (t === regularTable || t === seniorTable) continue;
      excludedTableCount++;
      const flat = t.flat().join(' ').toLowerCase();
      let reason = 'Unrelated table';
      if (flat.includes('annualised rate') || flat.includes('non-callable')) {
        reason = 'Non-callable retail deposits (>= 1 Cr to < 3 Cr)';
      } else if (flat.includes('monthly payout')) {
        reason = 'Monthly payout discounted rate table';
      } else if (flat.includes('bulk')) {
        reason = 'Bulk deposit table';
      }
      excludedTables.push({ rowCount: t.length, reason });
    }

    const candidates = [];
    const regularRows = regularTable.slice(1); // skip header row
    const seniorRows = seniorTable.slice(1);   // skip header row

    if (regularRows.length !== EXPECTED_ROWS) {
      errors.push(`Published regular row count mismatch: expected ${EXPECTED_ROWS}, found ${regularRows.length}`);
    }
    if (seniorRows.length !== EXPECTED_ROWS) {
      errors.push(`Published senior row count mismatch: expected ${EXPECTED_ROWS}, found ${seniorRows.length}`);
    }

    const rowCount = Math.min(regularRows.length, seniorRows.length);
    let extractedRows = 0;
    let validRows = 0;

    for (let i = 0; i < rowCount; i++) {
      const regRow = regularRows[i];
      const srRow = seniorRows[i];

      const rawLabelReg = String(regRow[0] || '').trim();
      const rawLabelSr = String(srRow[0] || '').trim();

      if (!rawLabelReg) continue;
      extractedRows++;

      // Verify label parity between regular and senior tables
      if (normalizeTenureLabel(rawLabelReg).toLowerCase() !== normalizeTenureLabel(rawLabelSr).toLowerCase()) {
        errors.push(`Tenure label mismatch between regular ("${rawLabelReg}") and senior ("${rawLabelSr}") tables at index ${i}`);
        continue;
      }

      const normalized = normalizeTenureLabel(rawLabelReg);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid callable tenure label: "${rawLabelReg}" (normalized: "${normalized}")`);
        continue;
      }

      // Card Rate (Col 1) is the genuine interest rate.
      // Col 2 (Yield) is compound annualized yield and MUST NOT be used as the interest rate.
      const regularRate = this.parseRateWithMarker(regRow[1]);
      const seniorRate = this.parseRateWithMarker(srRow[1]);

      if (regularRate.value === null) {
        errors.push(`Missing regular card interest rate for row "${rawLabelReg}"`);
        continue;
      }
      if (seniorRate.value === null) {
        errors.push(`Missing senior citizen card interest rate for row "${rawLabelSr}"`);
        continue;
      }

      validRows++;

      const calFields = extractCalendarTenure(rawLabelReg);

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
        tenureLabel: rawLabelReg,
        sourceTenureText: rawLabelReg,
        minDeposit: null,
        maxDeposit: '29999999.00',
        isCallable: true,
        compoundingFrequency: 'QUARTERLY',
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

      // 1. Regular Customer (Domestic / NRO / NRE)
      // NRE fixed deposits have a minimum tenure of 12 months 1 day.
      const isSubOneYear = tenure.maxTenureDays < 365;
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regularRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: regularRate.rawText,
        footnoteMarker: regularRate.marker,
        effectiveFrom: regularEffectiveFrom,
        notes: isSubOneYear
          ? 'AU Small Finance Bank callable retail FD below Rs. 3 Crore. Applicable to Domestic & NRO deposits. Sub-one-year tenures are not eligible for NRE deposits.'
          : 'AU Small Finance Bank callable retail FD below Rs. 3 Crore. Applicable to Domestic, NRE, and NRO deposits.',
      }));

      // 2. Senior Citizen (Resident Indian Senior Citizens with banking relationship only)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorRate.value,
        seniorCitizenRate: seniorRate.value,
        rawRateText: seniorRate.rawText,
        footnoteMarker: seniorRate.marker,
        effectiveFrom: seniorEffectiveFrom,
        notes: 'Senior Citizen rates apply strictly to Resident Indian Senior Citizens (aged 60 years and above) who maintain a banking relationship with AU Small Finance Bank. Strictly not applicable to NRE/NRO deposits.',
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
      effectiveFrom: regularEffectiveFrom,
      rawTableCount: tables.length,
      candidates,
      success,
      errors,
      metadata: {
        productScope: 'CALLABLE_RETAIL_DOMESTIC_NRO_NRE_BELOW_3_CRORE',
        extractedRows,
        validRows,
        expectedRows: EXPECTED_ROWS,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        nonCallableRatesIncluded: false,
        monthlyPayoutRatesIncluded: false,
        yieldIncludedAsRate: false,
        effectiveDatesByTable: {
          regularCallable: regularEffectiveFrom,
          seniorCitizenCallable: seniorEffectiveFrom,
          nonCallableRetail: nonCallableEffectiveFrom,
          monthlyPayoutRetail: monthlyEffectiveFrom,
        },
        excludedTableCount,
        excludedTables,
      },
    });
  }
}

module.exports = {
  AuSmallFinanceRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_ROWS,
};
