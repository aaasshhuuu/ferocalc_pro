// FeroCalc Verified FD Rate Engine — UCO Bank retail FD parser
// Parses only the published domestic/NRO callable table for deposits below Rs. 3 crore.
// Non-callable tables and bulk tables (Rs. 3 Cr and above) are strictly excluded.
// Source is intentionally disabled in source_registry until special scheme validity conflicts
// (333-day and 444-day expired schemes) are officially resolved and human review is complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://uco.bank.in/web/guest/interest-rates-on-deposit-schemes';
const EXPECTED_TOTAL_ROWS = 26;

function normalizeTenureLabel(raw) {
  let s = String(raw || '')
    .replace(/[–—−]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();

  // Strip '(Green Deposit)' suffix for tenure parsing
  s = s.replace(/\s*\(Green Deposit\)/i, '');

  // 'Above 3000 days' -> 3001 days to 10 years (3650 days)
  if (/^Above\s+3000\s*days/i.test(s)) {
    return '3001 days to 10 years';
  }

  // 'Above 1 year-443 days' -> '1 year 1 day to 443 days'
  if (/^Above\s+1\s*(?:year|yr)\s*[-to]\s*(\d+)\s*days/i.test(s)) {
    return s.replace(/^Above\s+1\s*(?:year|yr)\s*[-to]\s*(\d+)\s*days/i, '1 year 1 day to $1 days');
  }

  // 'Above 2 years - 999 days' -> '2 years 1 day to 999 days'
  if (/^Above\s+2\s*(?:years|yrs)\s*[-to]\s*(\d+)\s*days/i.test(s)) {
    return s.replace(/^Above\s+2\s*(?:years|yrs)\s*[-to]\s*(\d+)\s*days/i, '2 years 1 day to $1 days');
  }

  // 'Above 3 years - 5 years' -> '3 years 1 day to 5 years'
  if (/^Above\s+(\d+)\s*(?:years|yrs)\s*[-to]\s*(\d+)\s*(?:years|yrs)/i.test(s)) {
    return s.replace(/^Above\s+(\d+)\s*(?:years|yrs)\s*[-to]\s*(\d+)\s*(?:years|yrs)/i, '$1 years 1 day to $2 years');
  }

  // 'Above 5 years - 1999 days' -> '5 years 1 day to 1999 days'
  if (/^Above\s+(\d+)\s*(?:years|yrs)\s*[-to]\s*(\d+)\s*days/i.test(s)) {
    return s.replace(/^Above\s+(\d+)\s*(?:years|yrs)\s*[-to]\s*(\d+)\s*days/i, '$1 years 1 day to $2 days');
  }

  // '334 days-364 days' -> '334 days to 364 days'
  s = s.replace(/(\d+)\s*days?\s*-\s*(\d+)\s*days?/i, '$1 days to $2 days');

  return s;
}

function addRateSpread(baseRate, spread) {
  return Math.round((Number(baseRate) + Number(spread)) * 100) / 100;
}

class UcoRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'uco_retail_html',
      version: '1.0.0',
      bankCode: 'UCO',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'uco-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on UCO Bank rate page');

    // Locate the primary callable retail table (< Rs. 3 Crore).
    // Must strictly exclude bulk tables (Rs. 3 Cr and above) and non-callable tables.
    const targetTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasMaturityAnchor = flat.includes('maturity period');
      const hasRoiGeneralAnchor = flat.includes('roi for general customer') || flat.includes('rate % p.a.');
      const hasYieldAnchor = flat.includes('yield in %');
      const hasTenureAnchors = flat.includes('7-14 days') && flat.includes('3000 days');

      const isBulkTable = flat.includes('single term deposit rs. 3 cr') || flat.includes('bulk term deposits') || flat.includes('above rs. 10.00 crs');
      const isNonCallable = flat.includes('non-callable bulk term deposit') || flat.includes('non-callable');

      return hasMaturityAnchor &&
        hasRoiGeneralAnchor &&
        hasYieldAnchor &&
        hasTenureAnchors &&
        !isBulkTable &&
        !isNonCallable;
    });

    if (!targetTable) {
      return fail('Could not identify the primary callable retail FD table by anchors and scope exclusions', tables.length);
    }

    // Scoped Effective Date Extraction:
    // Extract the effective date scoped strictly to the callable retail section.
    // E.g. "Rate(s) of interest on Domestic Term Deposits less than Rs.3 Crore (including NRO Deposits) : Revised w.e.f. 21.05.2026"
    // Must NOT adopt the bulk deposit table's 23.10.2026 date!
    const normalizedHtml = html.replace(/\u00a0|&nbsp;/g, ' ');
    const callableScopeMatch = normalizedHtml.match(
      /(?:Domestic\s+Term\s+Deposits\s+less\s+than\s+Rs\.?\s*3\s*Crore|less\s+than\s+Rs\.?\s*3\s*Crore)[^<>]*Revised\s+w\.?e\.?f\.?\s*<b>?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i
    ) || normalizedHtml.match(
      /Revised\s+w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})[\s\S]{0,300}Maturity\s+Period/i
    );

    let effectiveFrom = callableScopeMatch ? this.parseEffectiveDate(callableScopeMatch[1]) : null;

    // Detect column indexes from Table 1 header rows
    // In UCO Table 1:
    // Row 0: ['Maturity Period', 'ROI for General Customer'] (rowspan/colspan)
    // Row 1: ['Rate % p.a.', 'Yield in %']
    // Data rows (Row 2+): [Maturity Period, Rate % p.a., Yield in %]
    let colPeriod = 0;
    let colRate = 1;
    let colYield = 2;
    let headerRowIndex = 1;

    // Verify header presence
    for (let r = 0; r < Math.min(3, targetTable.length); r++) {
      const row = targetTable[r].map(c => String(c).toLowerCase().trim());
      if (row.some(c => c.includes('rate % p.a.') || c.includes('yield in %'))) {
        headerRowIndex = Math.max(headerRowIndex, r);
      }
    }

    const candidates = [];
    const errors = [];
    const blockedSchemes = [];
    let extractedRows = 0;
    let validRows = 0;
    let hasExpiredSchemeDiscrepancy = false;

    // Table 2 / Table 4 Senior Citizen additional interest:
    // Up to 1 Year (<= 365 days): +0.25%
    // Above 1 Year (> 365 days): +0.50%
    // Resident Senior Citizens only; not applicable to NRE/NRO deposits.

    for (let rowIndex = headerRowIndex + 1; rowIndex < targetTable.length; rowIndex++) {
      const row = targetTable[rowIndex];
      if (!row || row.length <= colPeriod) continue;

      const rawLabel = String(row[colPeriod] || '').trim();
      if (!rawLabel || /^(?:sl\.?\s*no|maturity\s*period|tenure)$/i.test(rawLabel)) continue;
      extractedRows++;

      // Critical Fail-Closed Boundary: Check for expired special schemes (333 days and 444 days)
      // Official scheme particulars confirm validity expired on 30.06.2026.
      // Rate table still publishes them without an authoritative current renewal notice.
      // We must fail closed and NOT emit active candidates for these expired schemes.
      const is333 = /^333\s*days?$/i.test(rawLabel.trim());
      const is444 = /^444\s*days?$/i.test(rawLabel.trim());

      if (is333) {
        const msg = 'Special scheme validity conflict: UCO 333 scheme expired on 30.06.2026 but is still published in Table 1 @ 6.30% without official renewal; blocked from activation pending official clarification.';
        errors.push(msg);
        blockedSchemes.push({ label: rawLabel, reason: msg, expiredDate: '2026-06-30' });
        hasExpiredSchemeDiscrepancy = true;
        continue;
      }

      if (is444) {
        const msg = 'Special scheme validity conflict: UCO 444 scheme expired on 30.06.2026 but is still published in Table 1 @ 6.45% without official renewal; blocked from activation pending official clarification.';
        errors.push(msg);
        blockedSchemes.push({ label: rawLabel, reason: msg, expiredDate: '2026-06-30' });
        hasExpiredSchemeDiscrepancy = true;
        continue;
      }

      const normalized = normalizeTenureLabel(rawLabel);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid callable tenure label: "${rawLabel}" (normalized: "${normalized}")`);
        continue;
      }

      // Card Rate (Col 1) is the genuine interest rate.
      // Yield (Col 2) is compound annualized yield and MUST NOT be used as the interest rate.
      const regularRate = this.parseRateWithMarker(row[colRate]);
      if (regularRate.value === null) {
        errors.push(`Missing regular card interest rate for row "${rawLabel}"`);
        continue;
      }

      // Determine Senior Citizen additional interest
      const seniorSpread = tenure.maxTenureDays <= 365 ? 0.25 : 0.50;
      const seniorRateValue = addRateSpread(regularRate.value, seniorSpread);

      validRows++;

      // Detect special schemes
      const is535 = /^535\s*days?$/i.test(rawLabel.trim());
      const isGreenDeposit = /green\s*deposit/i.test(rawLabel);

      let schemeName = null;
      let rateCategory = 'STANDARD';

      if (is535) {
        schemeName = 'UCO_535';
        rateCategory = 'SPECIAL_SCHEME';
      } else if (isGreenDeposit) {
        schemeName = 'UCO_GREEN_DEPOSIT';
        rateCategory = 'SPECIAL_SCHEME';
      }

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
        isBespokeTenure: tenure.isBespoke || is535 || isGreenDeposit,
        rateCategory,
        schemeName,
        validationStatus: 'PENDING',
      };

      // 1. Regular Customer
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regularRate.value,
        seniorCitizenRate: seniorRateValue,
        rawRateText: regularRate.rawText,
        footnoteMarker: regularRate.marker,
        notes: is535
          ? 'UCO 535 Special Scheme (valid through 31.03.2027). Callable retail domestic/NRO FD below Rs. 3 Crore.'
          : isGreenDeposit
            ? 'UCO Green Deposit Scheme. Callable retail domestic/NRO FD below Rs. 3 Crore (includes 20 bps green premium).'
            : 'UCO Callable Retail Domestic/NRO FD below Rs. 3 Crore.',
      }));

      // 2. Senior Citizen (Resident Indian only; not applicable to NRE/NRO deposits)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: seniorRateValue,
        seniorCitizenRate: seniorRateValue,
        rawRateText: String(seniorRateValue) + '%',
        footnoteMarker: null,
        notes: is535
          ? 'UCO 535 Special Scheme (valid through 31.03.2027). Resident Senior Citizen (additional 0.50% p.a.). Not applicable to NRE/NRO deposits.'
          : isGreenDeposit
            ? 'UCO Green Deposit Scheme. Resident Senior Citizen (additional 0.50% p.a. over card rate). Not applicable to NRE/NRO deposits.'
            : `Resident Senior Citizen (additional ${seniorSpread.toFixed(2)}% p.a. for tenure ${tenure.maxTenureDays <= 365 ? '<= 1 yr' : '> 1 yr'}). Not applicable to NRE/NRO deposits.`,
      }));
    }

    if (!effectiveFrom) {
      errors.push('Missing explicit callable retail FD effective date scoped to the table headers');
    }
    if (extractedRows === 0) {
      errors.push('No retail FD rate rows were extracted from the target table');
    }
    if (extractedRows !== EXPECTED_TOTAL_ROWS) {
      errors.push(`Published row count changed: expected ${EXPECTED_TOTAL_ROWS}, found ${extractedRows}`);
    }

    // Fail-Closed: If any expired-scheme discrepancy exists, or any extraction error occurred, mark success: false.
    const success = errors.length === 0 && !hasExpiredSchemeDiscrepancy && validRows === EXPECTED_TOTAL_ROWS;

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
        productScope: 'CALLABLE_RETAIL_DOMESTIC_NRO_BELOW_3_CRORE',
        extractedRows,
        validRows,
        blockedRows: blockedSchemes.length,
        blockedSchemes,
        hasExpiredSchemeDiscrepancy,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        nonCallableRatesIncluded: false,
      },
    });
  }
}

module.exports = {
  UcoRateParser,
  normalizeTenureLabel,
  EXPECTED_TOTAL_ROWS,
};
