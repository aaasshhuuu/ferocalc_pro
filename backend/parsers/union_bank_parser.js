// Union Bank of India parser — callable retail FD rates for below INR 3 crore.
// Senior/super-senior premiums and non-callable rates are deliberately not inferred.
'use strict';
const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables } = require('./html_table_parser');
const { parseTenureRange } = require('./tenure_parser');
const SOURCE_URL = 'https://www.unionbankofindia.bank.in/en/details/rate-of-interest';
const EXPECTED_ROWS = 18;

function normalizeTenureLabel(value) {
  return String(value || '')
    .replace(/[–—−]/g, '-')
    .replace(/(\d+)\s*-\s*(\d+)/g, '$1 to $2')
    .replace(/^>\s*(\d+)\s*(?:yrs?|years?)\s+to\s+/i, '$1 years 1 day to ')
    .replace(/\byrs?\b/gi, 'years')
    .replace(/\s+/g, ' ')
    .trim();
}
class UnionBankRateParser extends BaseRateParser {
  constructor() {
    super({ id: 'union_bank_callable_retail_html', version: '1.0.0', bankCode: 'UNION_BANK' });
  }
  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string' ? sourceDocument : (sourceDocument ? sourceDocument.toString('utf-8') : '');
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'union-bank-retail-callable';
    const sourceContentHash = context.sourceContentHash || '';
    const fail = (message, rawTableCount = 0) => new ExtractionResult({
      sourceId, bankCode: this.bankCode, parserId: this.id, parserVersion: this.version,
      sourceUrl, sourceContentHash, success: false, rawTableCount, candidates: [], errors: [message]
    });
    if (!html.trim()) return fail('Source document is empty');
    const tables = parseHtmlTables(html);
    if (!tables.length) return fail('No HTML tables found on Union Bank rate page');
    const target = tables.find(table => {
      const flat = table.flat().join(' ').toLowerCase();
      return flat.includes('period/tenor') && flat.includes('callable deposits') &&
        flat.includes('non') && flat.includes('555 days') && flat.includes('998 days');
    });
    if (!target) return fail('Unable to identify callable retail table by headers and tenure anchors', tables.length);
    const pageText = html.replace(/<[^>]*>/g, ' ').replace(/&nbsp;|&#160;/gi, ' ').replace(/\s+/g, ' ')
      .replace(/(\d{1,2})\s+(st|nd|rd|th)\b/gi, '$1$2');
    const dateMatch = pageText.match(/effective\s+from\s+(\d{1,2}(?:st|nd|rd|th)?\s+[a-z]+\s+\d{4})\s+are\s+given\s+below/i);
    const effectiveFrom = dateMatch ? this.parseEffectiveDate(dateMatch[1]) : null;
    const candidates = [], errors = [];
    let parsedRowCount = 0;
    for (const row of target.slice(3)) {
      if (!row || row.length < 2) continue;
      const rawLabel = String(row[0] || '').trim();
      const rate = this.parseRateWithMarker(row[1]);
      if (!rawLabel || rate.value === null) continue;
      const tenure = parseTenureRange(normalizeTenureLabel(rawLabel));
      if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
        errors.push('Invalid callable tenure label: ' + rawLabel);
        continue;
      }
      parsedRowCount++;
      candidates.push(new CandidateRate({
        bankCode: this.bankCode, bankId: this.bankCode, sourceId,
        productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT', customerType: 'REGULAR',
        tenureUnit: tenure.tenureUnit, minTenure: tenure.minTenure, maxTenure: tenure.maxTenure,
        minTenureDays: tenure.minTenureDays, maxTenureDays: tenure.maxTenureDays,
        tenureLabel: rawLabel, sourceTenureText: rawLabel, minDeposit: null, maxDeposit: '29999999.00',
        isCallable: true, effectiveFrom, sourceUrl, sourceContentHash,
        parserId: this.id, parserVersion: this.version, isBespokeTenure: tenure.isBespoke,
        rateCategory: 'STANDARD', schemeName: null, interestRate: rate.value,
        seniorCitizenRate: null, superSeniorRate: null, rawRateText: rate.rawText,
        footnoteMarker: rate.marker,
        notes: 'Callable retail regular rate only. Senior and non-callable rates are not inferred by this parser.',
        validationStatus: 'PENDING'
      }));
    }
    if (!effectiveFrom) errors.push('Missing explicit callable FD effective date');
    if (parsedRowCount !== EXPECTED_ROWS) errors.push('Callable retail row count changed: expected ' + EXPECTED_ROWS + ', got ' + parsedRowCount);
    return new ExtractionResult({
      sourceId, bankCode: this.bankCode, parserId: this.id, parserVersion: this.version,
      sourceUrl, sourceContentHash, extractedAt: context.extractedAt || new Date().toISOString(),
      effectiveFrom, rawTableCount: tables.length, candidates,
      success: candidates.length === EXPECTED_ROWS && errors.length === 0, errors,
      metadata: { productScope: 'CALLABLE_RETAIL_BELOW_3_CRORE', extractedRows: parsedRowCount,
        customerTypes: ['REGULAR'], seniorRatesInferred: false, nonCallableRatesIncluded: false }
    });
  }
}
module.exports = { UnionBankRateParser, normalizeTenureLabel };
