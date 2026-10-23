// FeroCalc Verified FD Rate Engine — IDFC FIRST Bank retail FD parser
// Parses only the published domestic/NRO/NRE table for deposits below Rs. 3 crore.
// This source is intentionally disabled in source_registry until live HTML parity is verified.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables, cleanCellText } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.idfcfirst.bank.in/personal-banking/deposits/fixed-deposit/fd-interest-rates';

function normalizeTenureLabel(value) {
  return String(value || '')
    .replace(/[\u2012\u2013\u2014\u2212]/g, ' to ')
    .replace(/\s+/g, ' ')
    .trim();
}

class IdfcFirstRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'idfc_first_retail_html',
      version: '1.0.0',
      bankCode: 'IDFC_FIRST',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'idfc-first-retail-domestic';
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
    if (!tables.length) return fail('No HTML tables found on IDFC FIRST rate page');

    // Do not select the Tax Saver / Green Deposit tables by position.
    // Require the retail tenure buckets and the explicit General + Senior headers.
    const targetTable = tables.find((table) => {
      const flat = table.flat().join(' ').toLowerCase();
      const normalized = normalizeTenureLabel(flat);
      return flat.includes('tenure') &&
        flat.includes('general') &&
        flat.includes('senior citizen') &&
        normalized.includes('181 days') &&
        normalized.includes('500 days') &&
        normalized.includes('10 years');
    });

    if (!targetTable) {
      return fail('Could not identify the primary retail FD table by tenure/header anchors', tables.length);
    }

    // Scope the effective date to the primary retail table heading. Never reuse
    // the page's blog/footer dates as an effective date.
    const pageText = cleanCellText(html);
    const dateScope = pageText.match(
      /Interest Rates for Domestic\s*\/\s*NRO\s*\/\s*NRE Fixed Deposits of less than\s*₹\s*3\s*Crore\s*w\.e\.f\.?\s*([^*]{1,50})/i
    );
    const effectiveFrom = dateScope ? this.parseEffectiveDate(dateScope[1]) : null;

    const candidates = [];
    const errors = [];
    let extractedRows = 0;

    for (let rowIndex = 0; rowIndex < targetTable.length; rowIndex++) {
      const row = targetTable[rowIndex];
      let matched = null;

      // The source table has a tenure label followed by General and Senior Citizen
      // rates. Locate the triplet rather than assuming multi-row header indices.
      for (let colIndex = 0; colIndex <= row.length - 3; colIndex++) {
        const rawLabel = row[colIndex];
        const normalizedLabel = normalizeTenureLabel(rawLabel);
        const tenure = parseTenureRange(normalizedLabel);
        if (!tenure.isValid) continue;

        const regular = this.parseRateWithMarker(row[colIndex + 1]);
        const senior = this.parseRateWithMarker(row[colIndex + 2]);
        if (regular.value === null || senior.value === null) continue;

        matched = { rawLabel, tenure, regular, senior };
        break;
      }

      if (!matched) continue;
      extractedRows++;

      const common = {
        bankCode: this.bankCode,
        bankId: this.bankCode,
        sourceId,
        productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        tenureUnit: matched.tenure.tenureUnit,
        minTenure: matched.tenure.minTenure,
        maxTenure: matched.tenure.maxTenure,
        minTenureDays: matched.tenure.minTenureDays,
        maxTenureDays: matched.tenure.maxTenureDays,
        tenureLabel: matched.rawLabel,
        sourceTenureText: matched.rawLabel,
        minDeposit: null,
        maxDeposit: '29999999.00',
        isCallable: true,
        compoundingFrequency: 'QUARTERLY',
        effectiveFrom,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: matched.tenure.isBespoke,
        rateCategory: 'STANDARD',
        schemeName: null,
        validationStatus: 'PENDING',
      };

      candidates.push(new CandidateRate({
        ...common,
        customerType: 'REGULAR',
        interestRate: matched.regular.value,
        seniorCitizenRate: matched.senior.value,
        superSeniorRate: null,
        rawRateText: matched.regular.rawText,
        footnoteMarker: matched.regular.marker,
      }));

      candidates.push(new CandidateRate({
        ...common,
        customerType: 'SENIOR_CITIZEN',
        interestRate: matched.senior.value,
        seniorCitizenRate: matched.senior.value,
        superSeniorRate: null,
        notes: 'Source states senior-citizen rates are not applicable to NRI customers; use only for eligible resident senior citizens.',
        rawRateText: matched.senior.rawText,
        footnoteMarker: matched.senior.marker,
      }));
    }

    if (!effectiveFrom) errors.push('Missing explicit effective date scoped to the primary retail FD rate table');
    if (extractedRows === 0) errors.push('No retail FD rate rows were extracted');
    if (candidates.length !== extractedRows * 2) errors.push('A retail FD row did not yield exactly one General and one Senior Citizen candidate');

    return new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceContentHash,
      sourceUrl,
      extractedAt: context.extractedAt || new Date().toISOString(),
      success: candidates.length > 0 && errors.length === 0,
      candidates,
      rawTableCount: tables.length,
      effectiveFrom,
      errors,
      metadata: {
        extractedRows,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        amountLimit: 'LESS_THAN_3_CRORE',
        liveSourceParityVerified: false,
      },
    });
  }
}

module.exports = {
  IdfcFirstRateParser,
  normalizeTenureLabel,
};
