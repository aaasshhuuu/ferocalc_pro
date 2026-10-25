// FeroCalc Verified FD Rate Engine — IndusInd Bank retail FD parser
// Parses only the published domestic/NRO/NRE callable table for deposits below Rs. 3 crore.
// Non-callable tables (Premature Withdrawal Not Allowed) and bulk tables are strictly excluded.
// Source is intentionally disabled in source_registry until live HTML parity and human review are complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.indusind.bank.in/in/en/personal/fixed-deposit-interest-rate.html';
const EXPECTED_ROWS = 17;

function normalizeTenureLabel(value) {
  return String(value || '')
    .replace(/[–—−]/g, '-')
    .replace(/^above\s+(\d+)\s*(?:yrs?|years?)\s+up\s+to\s+below\s+/i, (_, p) => p + ' years 1 day to less than ')
    .replace(/^above\s+(\d+)\s*(?:yrs?|years?)\s+to\s+/i, (_, p) => p + ' years 1 day to ')
    .replace(/\bbelow\b/gi, 'less than')
    .replace(/\bup\s+to\s+less\s+than\b/gi, 'to less than')
    .replace(/^(\d+)\s*months?\s+and\s+above$/i, (_, p) => p + ' months to 10 years')
    .replace(/^tax\s*saver\s*\((\d+)\s*(?:years?|yrs?)\)$/i, (_, p) => p + ' years')
    .replace(/\byrs?\b/gi, 'years')
    .replace(/\s+/g, ' ')
    .trim();
}

class IndusIndRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'indusind_retail_html',
      version: '1.0.0',
      bankCode: 'INDUSIND',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'indusind-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on IndusInd rate page');

    // Locate the primary callable retail table (< Rs. 3 Crore).
    // Must strictly exclude non-callable tables (Premature Withdrawal Not Allowed) and high-value bulk tables.
    const targetTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const hasAmountAnchor = flat.includes('< 3 cr') || flat.includes('less than 3 cr') || flat.includes('below ₹3 crore');
      const hasDomesticAnchor = flat.includes('domestic') && flat.includes('resident');
      const hasSeniorAnchor = flat.includes('senior citizen');
      const hasTenureAnchors = flat.includes('7 days to 30 days') && flat.includes('tax saver');

      const isNonCallable = flat.includes('premature withdrawal not allowed') || flat.includes('non-callable') || flat.includes('non callable');
      const isHighValue = flat.includes('above 1 crore to less than 3 crores') || flat.includes('high value deposit');

      return hasAmountAnchor &&
        hasDomesticAnchor &&
        hasSeniorAnchor &&
        hasTenureAnchors &&
        !isNonCallable &&
        !isHighValue;
    });

    if (!targetTable) {
      return fail('Could not identify the primary callable retail FD table by anchors and scope exclusions', tables.length);
    }

    // Scoped Effective Date Extraction:
    // Extract the effective date scoped strictly to the callable retail section.
    // E.g. "Term Deposit Interest Rates revision is <b>w.e.f. 24/07/2026</b>"
    // Must NOT adopt the non-callable table's 13/10/2026 date!
    const normalizedHtml = html.replace(/\u00a0|&nbsp;/g, ' ');
    const callableScopeMatch = normalizedHtml.match(
      /Term\s+Deposit\s+Interest\s+Rates\s+revision\s+is\s+<b>\s*w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4}|\d{1,2}(?:st|nd|rd|th)?\s+[a-z]+(?:’|\s*)\d{2,4})/i
    ) || normalizedHtml.match(
      /(?:callable|term\s+deposit)[^<>]*interest\s+rates?[^<>]*w\.?e\.?f\.?\s*<b>?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i
    );

    let effectiveFrom = callableScopeMatch ? this.parseEffectiveDate(callableScopeMatch[1]) : null;

    // Reconcile against known non-callable notice:
    // Notice of 13 October 2026 applies only to non-callable FDs and must not override callable table.
    if (effectiveFrom === '2026-10-13') {
      return fail('Erroneously extracted non-callable policy change date (2026-10-13) for callable table');
    }

    const candidates = [];
    const errors = [];
    let extractedRows = 0;

    // Table 0 structure:
    // Row 0: Headers ("< 3 Cr* DOMESTIC...", "< 3 Cr* (Senior Citizen)...")
    // Row 1: Subheaders ("Tenure", "Rate", "Rate")
    // Row 2+: Tenure data rows
    for (let rowIndex = 2; rowIndex < targetTable.length; rowIndex++) {
      const row = targetTable[rowIndex];
      if (!row || row.length < 3) continue;

      const rawLabel = String(row[0] || '').trim();
      if (!rawLabel || /^(?:tenure|period)$/i.test(rawLabel)) continue;
      extractedRows++;

      const normalized = normalizeTenureLabel(rawLabel);
      const tenure = parseTenureRange(normalized);
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push(`Invalid callable tenure label: "${rawLabel}" (normalized: "${normalized}")`);
        continue;
      }

      const regular = this.parseRateWithMarker(row[1]);
      const senior = this.parseRateWithMarker(row[2]);

      if (regular.value === null) {
        errors.push(`Missing regular public rate for row "${rawLabel}"`);
        continue;
      }
      if (senior.value === null) {
        errors.push(`Missing senior citizen rate for row "${rawLabel}"`);
        continue;
      }

      const isTaxSaver = /tax\s*saver/i.test(rawLabel);
      const isBespokeSingleton = tenure.minTenureDays === tenure.maxTenureDays || isTaxSaver || rawLabel.includes('61 Months');
      const schemeName = isTaxSaver ? 'TAX_SAVER' : null;
      const rateCategory = isTaxSaver ? 'SPECIAL_SCHEME' : 'STANDARD';

      // NRE 1-year minimum tenure rule:
      const isNreEligible = tenure.minTenureDays >= 365;

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
        isBespokeTenure: tenure.isBespoke || isBespokeSingleton,
        rateCategory,
        schemeName,
        validationStatus: 'PENDING',
      };

      // 1. Regular / Public (Domestic Resident & NRO/NRE)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: regular.value,
        seniorCitizenRate: senior.value,
        superSeniorRate: null,
        rawRateText: regular.rawText,
        footnoteMarker: regular.marker,
        notes: isTaxSaver
          ? 'Tax Saver 5 Year Fixed Deposit scheme below Rs. 3 Crore.'
          : (isNreEligible
            ? 'Domestic Resident, NRO, and NRE callable fixed deposits below Rs. 3 Crore.'
            : 'Domestic Resident and NRO callable fixed deposits below Rs. 3 Crore. NRE deposits require minimum tenure of 1 year.'),
      }));

      // 2. Senior Citizen (Resident Senior Citizens only; NOT applicable for NRE/NRO)
      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: senior.value,
        seniorCitizenRate: senior.value,
        superSeniorRate: null,
        rawRateText: senior.rawText,
        footnoteMarker: senior.marker,
        notes: 'Resident Senior Citizen customers (aged 60 years and above). Senior citizen rates are NOT applicable to NRE/NRO deposits.',
      }));
    }

    if (!effectiveFrom) {
      errors.push('Missing explicit callable retail FD effective date scoped to the table headers');
    }
    if (extractedRows === 0) {
      errors.push('No retail FD rate rows were extracted from the target table');
    }
    if (extractedRows !== EXPECTED_ROWS) {
      errors.push(`Published row count changed: expected ${EXPECTED_ROWS}, found ${extractedRows}`);
    }

    const success = candidates.length === (EXPECTED_ROWS * 2) && errors.length === 0;

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
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        nonCallableRatesIncluded: false,
        policyNoticeReconciled: 'Non-callable senior policy notice (13 Oct 2026) verified and excluded from callable card rates',
      },
    });
  }
}

module.exports = {
  IndusIndRateParser,
  normalizeTenureLabel,
  EXPECTED_ROWS,
};
