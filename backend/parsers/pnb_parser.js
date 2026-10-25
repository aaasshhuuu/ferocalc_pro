// FeroCalc Verified FD Rate Engine — Punjab National Bank (PNB) retail FD parser
// Parses only the published domestic/NRO callable table for deposits below Rs. 3 crore.
// PNB Uttam (non-callable), bulk (>Rs. 3 Cr), and Tax Saver tables are strictly excluded.
// Source is intentionally disabled in source_registry until live HTML parity and ambiguity issues are resolved.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.pnb.bank.in/Interest-Rates-Deposit.html';
const EXPECTED_TOTAL_ROWS = 23;

function normalizeTenureLabel(value) {
  return String(value || '')
    .replace(/[–—−]/g, '-')
    .replace(/^>\s*(\d+)\s*(?:yrs?|years?)\s+to\s+(\d+)\s*(?:yrs?|years?)/i, (_, p1, p2) => p1 + ' years 1 day to ' + p2 + ' years')
    .replace(/^>\s*(\d+)\s+to\s+(\d+)\s*(?:yrs?|years?)/i, (_, p1, p2) => p1 + ' years 1 day to ' + p2 + ' years')
    .replace(/^>\s*(\d+)\s*(?:yrs?|years?)\s+to\s+/i, (_, p1) => p1 + ' years 1 day to ')
    .replace(/\byrs?\b/gi, 'years')
    .replace(/\s+/g, ' ')
    .trim();
}

class PnbRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'pnb_retail_html',
      version: '1.0.0',
      bankCode: 'PNB',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'pnb-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on PNB rate page');

    // Locate the primary callable domestic/NRO table (< Rs. 3 Crore).
    // Must strictly exclude PNB Uttam (Non-Callable), Tax Saver, Bulk (>Rs. 3 Cr), and NRE.
    const targetTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasDomesticNro = flat.includes('domestic/nro') || (flat.includes('domestic') && flat.includes('nro'));
      const hasFixedDeposit = flat.includes('fixed deposit');
      const hasRateHeaders = flat.includes('revised rates for public') &&
        flat.includes('senior citizen') &&
        flat.includes('super senior citizen');
      const hasTenureAnchors = flat.includes('7 to 14 days');

      const isNonCallable = flat.includes('pnb uttam') || flat.includes('non-callable') || flat.includes('non callable');
      const isBulk = flat.includes('rs.3 cr') || flat.includes('rs. 3 cr') || flat.includes('3 crore to 10 crore') || flat.includes('above rs. 1 crore');
      const isTaxSaver = flat.includes('tax saver');
      const isNre = flat.includes('nre term deposit');

      return hasDomesticNro &&
        hasFixedDeposit &&
        hasRateHeaders &&
        hasTenureAnchors &&
        !isNonCallable &&
        !isBulk &&
        !isTaxSaver &&
        !isNre;
    });

    if (!targetTable) {
      return fail('Could not identify the primary callable retail FD table by anchors and scope exclusions', tables.length);
    }

    // Extract effective date scoped strictly to the primary retail table headers or caption.
    // E.g. "Revised Rates For Public w.e.f. 01.06.2026"
    const headerSlice = targetTable.slice(0, 3).flat().join(' ');
    const dateMatch = headerSlice.match(/w\.e\.f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{1,2}(?:st|nd|rd|th)?\s+[a-z]+\s+\d{4})/i);
    const effectiveFrom = dateMatch ? this.parseEffectiveDate(dateMatch[1]) : null;

    // Identify header row column indices for Period, Public, Senior, Super Senior
    let colPeriod = 1;
    let colPublic = 2;
    let colSenior = 3;
    let colSuperSenior = 4;
    let headerRowIndex = 1;

    for (let r = 0; r < Math.min(3, targetTable.length); r++) {
      const row = targetTable[r].map(c => String(c).toLowerCase().trim());
      const pIdx = row.findIndex(c => c.includes('period') || c.includes('tenor') || c.includes('tenure'));
      const pubIdx = row.findIndex(c => c.includes('public') && (c.includes('rate') || c.includes('revised')));
      const srIdx = row.findIndex(c => c.includes('senior citizen') && !c.includes('super'));
      const ssrIdx = row.findIndex(c => c.includes('super senior citizen'));

      if (pIdx !== -1 && pubIdx !== -1) {
        colPeriod = pIdx;
        colPublic = pubIdx;
        if (srIdx !== -1) colSenior = srIdx;
        if (ssrIdx !== -1) colSuperSenior = ssrIdx;
        headerRowIndex = r;
        break;
      }
    }

    const candidates = [];
    const errors = [];
    let extractedRows = 0;
    let validRows = 0;
    let hasAmbiguity = false;

    for (let rowIndex = headerRowIndex + 1; rowIndex < targetTable.length; rowIndex++) {
      const row = targetTable[rowIndex];
      if (!row || row.length <= colPeriod) continue;

      const rawLabel = String(row[colPeriod] || '').trim();
      if (!rawLabel || /^(?:sl\.?\s*no|period|tenure)$/i.test(rawLabel)) continue;
      extractedRows++;

      // Critical Fail-Closed Boundary: Check for ambiguous boundary expressions like "304 Days to >1 Year"
      if (/to\s*>/i.test(rawLabel) || /304\s*days\s*to\s*>\s*1\s*year/i.test(rawLabel)) {
        errors.push(
          `Ambiguous tenure label with conflicting boundary: "${rawLabel}". ` +
          `Official source publishes contradictory boundary ("to >1 Year") adjacent to "1 Year" row.`
        );
        hasAmbiguity = true;
        continue; // Do NOT emit a candidate for this ambiguous row
      }

      const normalized = normalizeTenureLabel(rawLabel);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid callable tenure label: "${rawLabel}" (normalized: "${normalized}")`);
        continue;
      }

      const regular = this.parseRateWithMarker(row[colPublic]);
      const senior = this.parseRateWithMarker(row[colSenior]);
      const superSenior = this.parseRateWithMarker(row[colSuperSenior]);

      if (regular.value === null) {
        errors.push(`Missing regular public interest rate for row "${rawLabel}"`);
        continue;
      }
      if (senior.value === null) {
        errors.push(`Missing senior citizen interest rate for row "${rawLabel}"`);
        continue;
      }
      if (superSenior.value === null) {
        errors.push(`Missing super senior citizen interest rate for row "${rawLabel}"`);
        continue;
      }

      validRows++;

      const isPalaash = rawLabel.includes('1204');
      const schemeName = isPalaash ? 'PNB_PALAASH' : null;
      const rateCategory = isPalaash ? 'SPECIAL_SCHEME' : 'STANDARD';

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
        isBespokeTenure: tenure.isBespoke || isPalaash,
        rateCategory,
        schemeName,
        validationStatus: 'PENDING',
      };

      // 1. Regular / Public
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regular.value,
        seniorCitizenRate: senior.value,
        superSeniorRate: superSenior.value,
        rawRateText: regular.rawText,
        footnoteMarker: regular.marker,
        notes: isPalaash
          ? 'PNB Palaash foundation day special scheme (1204 days). Callable retail below Rs. 3 Crore.'
          : 'PNB Callable Retail Domestic/NRO FD below Rs. 3 Crore.',
      }));

      // 2. Senior Citizen (Age 60 to <80 years; not applicable for NRO)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: senior.value,
        seniorCitizenRate: senior.value,
        superSeniorRate: superSenior.value,
        rawRateText: senior.rawText,
        footnoteMarker: senior.marker,
        notes: isPalaash
          ? 'PNB Palaash foundation day special scheme (1204 days). Senior Citizen Age 60 Year and upto < 80 Year. Additional rate not applicable for NRO deposits.'
          : 'Senior Citizen Age 60 Year and upto < 80 Year. Additional rate not applicable for NRO deposits.',
      }));

      // 3. Super Senior Citizen (Age 80 years and above; not applicable for NRO)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SUPER_SENIOR_CITIZEN',
        interestRate: superSenior.value,
        seniorCitizenRate: senior.value,
        superSeniorRate: superSenior.value,
        rawRateText: superSenior.rawText,
        footnoteMarker: superSenior.marker,
        notes: isPalaash
          ? 'PNB Palaash foundation day special scheme (1204 days). Super Senior Citizen Age 80 Year and above. Additional rate not applicable for NRO deposits.'
          : 'Super Senior Citizen Age 80 Year and above. Additional rate not applicable for NRO deposits.',
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

    // Fail-Closed: If any ambiguity exists, or any extraction error occurred, mark success: false.
    const success = errors.length === 0 && !hasAmbiguity && validRows === EXPECTED_TOTAL_ROWS;

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
        hasAmbiguity,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        nonCallableRatesIncluded: false,
      },
    });
  }
}

module.exports = {
  PnbRateParser,
  normalizeTenureLabel,
  EXPECTED_TOTAL_ROWS,
};
