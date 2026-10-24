// FeroCalc Verified FD Rate Engine — Indian Bank retail FD parser
// Parses only the published domestic callable retail table (< Rs. 3 crore) and callable special schemes.
// Bulk tables (>= 3 Cr), non-callable options, savings deposits, and foreclosure charges are strictly excluded.
// Annualized yield is strictly ignored and never emitted as the interest rate.
// Source is intentionally disabled in source_registry until live HTML parity and human review are complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://indianbank.bank.in/en/deposit-rates';
const EXPECTED_CALLABLE_ROWS = 18;

function normalizeTenureLabel(raw) {
  let s = String(raw || '')
    .replace(/[–—−]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();

  // Normalize special scheme labels with parentheses spacing
  s = s.replace(/IND\s*Supreme\s*2\.0\s*\(\s*(\d+)\s*days\s*\)/i, 'IND Supreme 2.0 ($1 days)');
  s = s.replace(/Ind\s*Green\s*\(\s*(\d+)\s*days\s*\)/i, 'Ind Green ($1 days)');
  s = s.replace(/Ind\s*Grow\s*\(\s*(\d+)\s*days\s*\)/i, 'Ind Grow ($1 days)');
  s = s.replace(/Ind\s*Prosper\s*\(\s*(\d+)\s*days\s*\)/i, 'Ind Prosper ($1 days)');

  // Normalize single bound "Above 5 years" to "5 years 1 day to 10 years"
  if (/^Above\s+5\s*years?$/i.test(s)) {
    return '5 years 1 day to 10 years';
  }

  // Normalize "5 year" to "5 years"
  if (/^5\s*year$/i.test(s)) {
    return '5 years';
  }

  // Normalize "Above 1 year to less than 2 years" to "1 year 1 day to less than 2 years"
  if (/^Above\s+1\s*year\s+to\s+less\s+than\s+2\s*years$/i.test(s)) {
    return '1 year 1 day to less than 2 years';
  }

  return s;
}

/**
 * Extracts structured calendar tenure bounds from Indian Bank tenure labels.
 */
function extractCalendarTenure(label) {
  const norm = String(label || '').replace(/[–—−]/g, '-').replace(/\s+/g, ' ').trim();

  // Pattern: "181 days to less than 9 months"
  if (/^181\s*days\s*to\s*less\s+than\s*9\s*months?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 0, minMonths: 0, minDaysCal: 181, minOperator: '>=',
      maxYears: 0, maxMonths: 9, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "9 months to less than 1 year"
  if (/^9\s*months?\s*to\s*less\s+than\s*1\s*year$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 0, minMonths: 9, minDaysCal: 0, minOperator: '>=',
      maxYears: 1, maxMonths: 12, maxDaysCal: 0, maxOperator: '<',
    };
  }

  // Pattern: "1 year"
  if (/^1\s*year$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 12, minDaysCal: 0, minOperator: '>=',
      maxYears: 1, maxMonths: 12, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  // Pattern: "Above 1 year to less than 2 years"
  if (/^Above\s+1\s*year\s*to\s*less\s+than\s*2\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 12, minDaysCal: 1, minOperator: '>=',
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

  // Pattern: "5 year" or "5 years"
  if (/^5\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 5, minMonths: 60, minDaysCal: 0, minOperator: '>=',
      maxYears: 5, maxMonths: 60, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  // Pattern: "Above 5 years"
  if (/^Above\s+5\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 5, minMonths: 60, minDaysCal: 1, minOperator: '>=',
      maxYears: 10, maxMonths: 120, maxDaysCal: 0, maxOperator: '<=',
    };
  }

  return {
    tenureDomain: 'DAYS',
    minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
    maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
  };
}

function addRateSpread(baseRate, spread) {
  return Math.round((Number(baseRate) + Number(spread)) * 100) / 100;
}

/**
 * Extracts an explicit scheme effective date (w.e.f DD.MM.YYYY) from the HTML content
 * following a given scheme identifier.
 */
function extractSchemeDate(html, schemePattern) {
  if (!html) return null;
  // Locate the dedicated scheme section following Table 0
  const t0End = html.indexOf('</table>');
  const searchArea = t0End !== -1 ? html.slice(t0End) : html;
  const p = searchArea.search(schemePattern);
  if (p === -1) return null;
  const chunk = searchArea.slice(p, p + 2500);
  const m = chunk.match(/Rate\s+of\s+Interest[^<]*?w\.e\.f\s*[:.]?\s*(\d{2})[./-](\d{2})[./-](\d{4})/i);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  return null;
}

class IndianBankRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'indian_bank_retail_html',
      version: '1.0.0',
      bankCode: 'INDIAN_BANK',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'indian-bank-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on Indian Bank rate page');

    const errors = [];

    // 1. Identify Standard Callable Retail Table (< Rs. 3 Crore)
    // Anchors: 'Interest Rates on Domestic Retail Term Deposits' AND 'Less than Rs.3 crore'
    // Exclude: tables mentioning 'Bulk Term Deposits' or 'Savings Bank' or 'Foreclosure'
    const retailTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasRetailTitle = flat.includes('interest rates on domestic retail term deposits');
      const hasRetailScope = flat.includes('less than rs.3 crore') || flat.includes('less than rs. 3 crore');
      const hasRevisedHeader = flat.includes('revised rate');
      const isNotBulk = !flat.includes('bulk term deposits') && !flat.includes('callable') && !flat.includes('non- callable');
      return hasRetailTitle && hasRetailScope && hasRevisedHeader && isNotBulk;
    });

    if (!retailTable) {
      return fail('Could not find Indian Bank Domestic Retail Term Deposits (< Rs. 3 crore) table', tables.length);
    }

    // 2. Extract Effective Date from Table 0 header
    // Expected in header rows: e.g. "Revised Rate (w.e.f 23.10.2026)"
    const headerText = retailTable.slice(0, 4).flat().join(' ');
    const dateMatch = headerText.match(/w\.e\.f\s*[:.]?\s*(\d{2})[./-](\d{2})[./-](\d{4})/i);
    if (!dateMatch) {
      return fail('Could not find explicit effective date (w.e.f DD.MM.YYYY) in Indian Bank retail table header', tables.length);
    }

    const effectiveFrom = `${dateMatch[3]}-${dateMatch[2]}-${dateMatch[1]}`;

    // Extract special scheme effective dates directly from HTML content if published
    const indSupremeDate = extractSchemeDate(html, /IND\s*Supreme\s*2\.0/i);
    const indGreenDate = extractSchemeDate(html, /IND\s*GREEN/i);
    const indGrowDate = extractSchemeDate(html, /IND\s*GROW/i);
    const indProsperDate = extractSchemeDate(html, /IND\s*Proposer|IND\s*Prosper/i);

    const effectiveDatesByTable = {
      standardCallableRetail: effectiveFrom,
      indSupreme300: indSupremeDate || '2026-08-04',
      indGreen500: indGreenDate || '2026-06-05',
      indGrow555: indGrowDate || effectiveFrom,
      indProsper777: indProsperDate || effectiveFrom,
    };

    const schemeEffectiveDatesSource = {
      indSupreme300: indSupremeDate ? 'EXTRACTED_FROM_SOURCE' : 'BASELINE_METADATA_FALLBACK',
      indGreen500: indGreenDate ? 'EXTRACTED_FROM_SOURCE' : 'BASELINE_METADATA_FALLBACK',
      indGrow555: indGrowDate ? 'EXTRACTED_FROM_SOURCE' : 'BASELINE_METADATA_FALLBACK',
      indProsper777: indProsperDate ? 'EXTRACTED_FROM_SOURCE' : 'BASELINE_METADATA_FALLBACK',
    };

    // 3. Locate column indices for Period and Revised Rate
    let colPeriod = -1;
    let colRevisedRate = -1;
    let headerRowIndex = -1;

    for (let r = 0; r < Math.min(4, retailTable.length); r++) {
      const row = retailTable[r];
      row.forEach((cell, idx) => {
        const text = String(cell || '').toLowerCase();
        if (text.includes('period') || text.includes('tenor')) {
          colPeriod = idx;
        }
        if (text.includes('revised rate')) {
          colRevisedRate = idx;
        }
      });
      if (colPeriod !== -1 && colRevisedRate !== -1) {
        headerRowIndex = r;
        break;
      }
    }

    if (colPeriod === -1) {
      // In Indian Bank Table 0:
      // Row 1: ["Period / Tenor of Deposit", "Less than Rs.3 crore"]
      // Row 2: ["Existing Rate", "Revised Rate (w.e.f 23.10.2026)"]
      // colPeriod is 0, colRevisedRate is 1 in Row 2 (or 2 if col 0 has empty existing rate)
      colPeriod = 0;
    }
    if (colRevisedRate === -1) {
      // Check Row 2
      if (retailTable[2] && retailTable[2].length >= 2) {
        colRevisedRate = retailTable[2].length - 1;
        headerRowIndex = 2;
      }
    }

    // Determine data start index: row after (% per annum) row or headerRowIndex
    let dataStartIndex = -1;
    for (let r = 0; r < retailTable.length; r++) {
      const firstCell = String(retailTable[r][0] || '').trim();
      if (/^7\s*days/i.test(firstCell)) {
        dataStartIndex = r;
        break;
      }
    }

    if (dataStartIndex === -1) {
      return fail('Could not locate start of tenure data rows (expected "7 days to 14 days")', tables.length);
    }

    const dataRows = retailTable.slice(dataStartIndex);
    if (dataRows.length !== EXPECTED_CALLABLE_ROWS) {
      errors.push(`Expected ${EXPECTED_CALLABLE_ROWS} callable retail rows, found ${dataRows.length}`);
    }

    const candidates = [];
    let extractedRows = 0;
    let validRows = 0;
    let standardRowCount = 0;
    let specialSchemeCount = 0;

    for (let i = 0; i < dataRows.length; i++) {
      const row = dataRows[i];
      if (!row || row.length < 2) continue;

      const rawLabel = String(row[0] || '').trim();
      if (!rawLabel) continue;
      extractedRows++;

      // Revised rate is in the last column
      const rateCol = row.length - 1;
      const regularRate = this.parseRateWithMarker(row[rateCol]);

      if (regularRate.value === null) {
        errors.push(`Missing regular interest rate for row "${rawLabel}"`);
        continue;
      }

      // Check special scheme identification
      const isIndSupreme = /IND\s*Supreme\s*2\.0/i.test(rawLabel);
      const isIndGreen = /Ind\s*Green/i.test(rawLabel);
      const isIndGrow = /Ind\s*Grow/i.test(rawLabel);
      const isIndProsper = /Ind\s*Prosper/i.test(rawLabel);
      const isSpecialScheme = isIndSupreme || isIndGreen || isIndGrow || isIndProsper;

      let schemeName = null;
      let rateCategory = 'STANDARD';
      let rowEffectiveFrom = effectiveFrom;
      let isBespokeTenure = false;

      if (isIndSupreme) {
        schemeName = 'IND_SUPREME_300';
        rateCategory = 'SPECIAL_SCHEME';
        rowEffectiveFrom = effectiveDatesByTable.indSupreme300;
        isBespokeTenure = true;
        specialSchemeCount++;
      } else if (isIndGreen) {
        schemeName = 'IND_GREEN_500';
        rateCategory = 'SPECIAL_SCHEME';
        rowEffectiveFrom = effectiveDatesByTable.indGreen500;
        isBespokeTenure = true;
        specialSchemeCount++;
      } else if (isIndGrow) {
        schemeName = 'IND_GROW_555';
        rateCategory = 'SPECIAL_SCHEME';
        rowEffectiveFrom = effectiveDatesByTable.indGrow555;
        isBespokeTenure = true;
        specialSchemeCount++;
      } else if (isIndProsper) {
        schemeName = 'IND_PROSPER_777';
        rateCategory = 'SPECIAL_SCHEME';
        rowEffectiveFrom = effectiveDatesByTable.indProsper777;
        isBespokeTenure = true;
        specialSchemeCount++;
      } else {
        standardRowCount++;
      }

      // Parse tenure
      const normalized = normalizeTenureLabel(rawLabel);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid tenure range for label "${rawLabel}" (normalized: "${normalized}")`);
        continue;
      }

      const calFields = extractCalendarTenure(rawLabel);

      // Senior and Super Senior spread rules:
      // Policy:
      // 1) Senior Citizens (60+): +0.50% p.a. for domestic term deposits < Rs. 3 Crore.
      // 2) Special offer for Senior Citizens for "above 5 Years up to 10 Years": additional 0.25% (total +0.75%).
      // 3) Super Senior Citizens (80+) "IB - Golden Ager": additional 0.25% higher rate over normal Senior Citizen
      //    rate for all deposit buckets (total +0.75% for <= 5 years, +1.00% for > 5 years).
      const isAbove5Years = /^Above\s+5\s*years?$/i.test(rawLabel);
      const seniorSpread = isAbove5Years ? 0.75 : 0.50;
      const superSeniorSpread = isAbove5Years ? 1.00 : 0.75;

      const seniorRateVal = addRateSpread(regularRate.value, seniorSpread);
      const superSeniorRateVal = addRateSpread(regularRate.value, superSeniorSpread);

      validRows++;

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
        effectiveFrom: rowEffectiveFrom,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: tenure.isBespoke || isBespokeTenure,
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
        seniorCitizenRate: seniorRateVal,
        superSeniorRate: superSeniorRateVal,
        rawRateText: regularRate.rawText,
        footnoteMarker: regularRate.marker,
        notes: isSubOneYear
          ? 'Indian Bank callable retail domestic term deposit below Rs. 3 Crore. Sub-one-year tenures are not eligible for NRE deposits.'
          : (isSpecialScheme
            ? `Indian Bank ${schemeName} special retail callable deposit below Rs. 3 Crore.`
            : 'Indian Bank callable retail domestic term deposit below Rs. 3 Crore.'),
      }));

      // 2. Senior Citizen (Aged 60 years and above)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorRateVal,
        seniorCitizenRate: seniorRateVal,
        superSeniorRate: superSeniorRateVal,
        rawRateText: String(seniorRateVal),
        footnoteMarker: regularRate.marker,
        notes: isAbove5Years
          ? 'Senior Citizen rates include additional 0.75% (+0.50% standard plus special offer +0.25% for > 5 years up to 10 years). Strictly not applicable to NRE/NRO or HUF accounts.'
          : 'Senior Citizen rates (+0.50%) apply strictly to Resident Indian Senior Citizens (aged 60 years and above). Strictly not applicable to NRE/NRO or HUF accounts.',
      }));

      // 3. Super Senior Citizen (Aged 80 years and above) — IB Golden Ager
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SUPER_SENIOR_CITIZEN',
        interestRate: superSeniorRateVal,
        seniorCitizenRate: seniorRateVal,
        superSeniorRate: superSeniorRateVal,
        rawRateText: String(superSeniorRateVal),
        footnoteMarker: regularRate.marker,
        notes: isAbove5Years
          ? 'Super Senior Citizen (IB Golden Ager, 80+) rates include additional 1.00% (+0.75% senior plus +0.25% super senior for > 5 years up to 10 years). Strictly not applicable to NRE/NRO or HUF accounts.'
          : 'Super Senior Citizen (IB Golden Ager, 80+) rates include additional 0.25% over normal Senior Citizen (+0.75% total). Strictly not applicable to NRE/NRO or HUF accounts.',
      }));
    }

    if (errors.length > 0 && validRows === 0) {
      return fail(`Failed to extract valid Indian Bank retail rates: ${errors.join('; ')}`, tables.length);
    }

    return new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceUrl,
      sourceContentHash,
      success: errors.length === 0,
      rawTableCount: tables.length,
      effectiveFrom,
      candidates,
      errors,
      metadata: {
        tableIndex: 0,
        extractedRowCount: extractedRows,
        validRowCount: validRows,
        standardRowCount,
        specialSchemeCount,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN'],
        yieldIncludedAsRate: false,
        nonCallableRatesIncluded: false,
        bulkRatesIncluded: false,
        effectiveDatesByTable,
        schemeEffectiveDatesSource,
      },
    });
  }
}

module.exports = {
  IndianBankRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  extractSchemeDate,
  SOURCE_URL,
  EXPECTED_CALLABLE_ROWS,
};
