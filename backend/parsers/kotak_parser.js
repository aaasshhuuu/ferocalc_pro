// FeroCalc Verified FD Rate Engine — Kotak Mahindra Bank (KOTAK) Parser
// Parses official Kotak Mahindra Bank domestic retail callable fixed deposit rates.
// Source: https://www.kotak.bank.in/bank/mailers/intrates/get_all_variable_data_latest.php?section=NRO_Term_Deposit
// Portal landing: https://www.kotak.com/en/personal-banking/deposits/fixed-deposit/fixed-deposit-interest-rates.html

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables } = require('./html_table_parser');

/**
 * Normalizes and parses tenure strings from Kotak Mahindra Bank FD schedules.
 *
 * Slabs supported:
 * 1. 7 - 14 Days
 * 2. 15 - 30 Days
 * 3. 31 - 45 Days
 * 4. 46 - 90 Days
 * 5. 91 Days
 * 6. 92 Days - 179 Days
 * 7. 180 Days
 * 8. 181 Days to 269 Days
 * 9. 270 Days
 * 10. 271 Days to 363 Days
 * 11. 364 Days
 * 12. 365 Days to less than 15 Months
 * 13. 15 Months - less than 18 Months
 * 14. 18 months - less than 2 years
 * 15. 2 years- less than 3 years
 * 16. 3 years and above but less than 4 years
 * 17. 4 years and above but less than 5 years
 * 18. 5 years and above upto and inclusive of 10 years
 *
 * @param {string} label
 * @returns {Object}
 */
function parseKotakTenure(label) {
  if (!label || typeof label !== 'string') {
    return { isValid: false, error: 'Empty tenure label' };
  }

  const clean = label
    .replace(/[\u00a0\s]+/g, ' ')
    .replace(/–|—/g, '-')
    .trim();
  const lower = clean.toLowerCase();

  // 1. "7 - 14 Days"
  if (/^7\s*-\s*14\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 14,
      tenureUnit: 'DAYS',
      minTenure: 7,
      maxTenure: 14,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '7D_14D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 2. "15 - 30 Days"
  if (/^15\s*-\s*30\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 15,
      maxTenureDays: 30,
      tenureUnit: 'DAYS',
      minTenure: 15,
      maxTenure: 30,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '15D_30D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 3. "31 - 45 Days"
  if (/^31\s*-\s*45\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 31,
      maxTenureDays: 45,
      tenureUnit: 'DAYS',
      minTenure: 31,
      maxTenure: 45,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '31D_45D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 4. "46 - 90 Days"
  if (/^46\s*-\s*90\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 46,
      maxTenureDays: 90,
      tenureUnit: 'DAYS',
      minTenure: 46,
      maxTenure: 90,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '46D_90D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 5. "91 Days"
  if (/^91\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 91,
      maxTenureDays: 91,
      tenureUnit: 'DAYS',
      minTenure: 91,
      maxTenure: 91,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '91D',
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // 6. "92 Days - 179 Days"
  if (/^92\s*days?\s*-\s*179\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 92,
      maxTenureDays: 179,
      tenureUnit: 'DAYS',
      minTenure: 92,
      maxTenure: 179,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '92D_179D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 7. "180 Days"
  if (/^180\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 180,
      maxTenureDays: 180,
      tenureUnit: 'DAYS',
      minTenure: 180,
      maxTenure: 180,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '180D',
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // 8. "181 Days to 269 Days"
  if (/^181\s*days?\s*(?:to|-)\s*269\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 181,
      maxTenureDays: 269,
      tenureUnit: 'DAYS',
      minTenure: 181,
      maxTenure: 269,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '181D_269D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 9. "270 Days"
  if (/^270\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 270,
      maxTenureDays: 270,
      tenureUnit: 'DAYS',
      minTenure: 270,
      maxTenure: 270,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '270D',
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // 10. "271 Days to 363 Days"
  if (/^271\s*days?\s*(?:to|-)\s*363\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 271,
      maxTenureDays: 363,
      tenureUnit: 'DAYS',
      minTenure: 271,
      maxTenure: 363,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '271D_363D',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 11. "364 Days"
  if (/^364\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 364,
      maxTenureDays: 364,
      tenureUnit: 'DAYS',
      minTenure: 364,
      maxTenure: 364,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      canonicalTenure: '364D',
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // 12. "365 Days to less than 15 Months"
  if (/^365\s*days?\s*to\s*less\s*than\s*15\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 12,
      maxTenure: 15,
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
      canonicalTenure: '1Y_1Y3M',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 13. "15 Months - less than 18 Months"
  if (/^15\s*months?\s*-\s*less\s*than\s*18\s*months?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 15,
      maxTenure: 18,
      minYears: 1, minMonths: 3, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 6, maxDaysCal: 0, maxOperator: 'LT',
      canonicalTenure: '1Y3M_1Y6M',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 14. "18 months - less than 2 years"
  if (/^18\s*months?\s*-\s*less\s*than\s*2\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'MONTHS',
      minTenure: 18,
      maxTenure: 24,
      minYears: 1, minMonths: 6, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      canonicalTenure: '1Y6M_2Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 15. "2 years- less than 3 years"
  if (/^2\s*years?\s*-\s*less\s*than\s*3\s*years?$/i.test(lower) || /^2\s*years?-\s*less\s*than\s*3\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 2,
      maxTenure: 3,
      minYears: 2, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 3, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      canonicalTenure: '2Y_3Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 16. "3 years and above but less than 4 years"
  if (/^3\s*years?\s*and\s*above\s*but\s*less\s*than\s*4\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 3,
      maxTenure: 4,
      minYears: 3, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 4, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      canonicalTenure: '3Y_4Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 17. "4 years and above but less than 5 years"
  if (/^4\s*years?\s*and\s*above\s*but\s*less\s*than\s*5\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 4,
      maxTenure: 5,
      minYears: 4, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 5, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      canonicalTenure: '4Y_5Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 18. "5 years and above upto and inclusive of 10 years"
  if (/^5\s*years?\s*and\s*above\s*upto\s*(?:and\s*inclusive\s*of)?\s*10\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 5,
      maxTenure: 10,
      minYears: 5, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 10, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      canonicalTenure: '5Y_10Y',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  return {
    isValid: false,
    error: `Unrecognized Kotak tenure label: "${label}"`,
  };
}

class KotakRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'kotak_retail_html',
      version: '1.0.0',
      bankCode: 'KOTAK',
    });
  }

  /**
   * Parses official Kotak Mahindra Bank HTML rate table.
   *
   * @param {string|Buffer} sourceDocument
   * @param {Object} context
   * @returns {ExtractionResult}
   */
  parse(sourceDocument, context = {}) {
    let html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');

    const sourceUrl = context.sourceUrl || 'https://www.kotak.bank.in/bank/mailers/intrates/get_all_variable_data_latest.php?section=NRO_Term_Deposit';
    const sourceContentHash = context.sourceContentHash || '';
    const sourceId = context.sourceId || 'kotak-retail-domestic';

    if (!html || !html.trim()) {
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

    // If wrapped in document.write("..."), unwrap it safely
    if (html.includes('document.write')) {
      const dwMatch = html.match(/document\.write\(\s*["']([\s\S]*?)["']\s*\)/i);
      if (dwMatch) {
        html = dwMatch[1].replace(/\\'/g, "'").replace(/\\"/g, '"');
      }
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
        errors: ['No HTML tables found in Kotak Mahindra source content'],
      });
    }

    // Locate the domestic retail table
    let targetTable = null;
    for (const table of tables) {
      if (table.length >= 10) {
        const text = table.map(r => r.join(' ')).join(' ').toLowerCase();
        if (text.includes('premature withdrawal allowed') || text.includes('less than rs.3 crore') || text.includes('regular')) {
          targetTable = table;
          break;
        }
      }
    }

    if (!targetTable) {
      targetTable = tables[0];
    }

    // Extract effective date
    let effectiveFrom = null;
    const fullText = targetTable.map(r => r.join(' ')).join(' ');
    const dateMatch = fullText.match(/effective\s+(?:from|w\.e\.f\.?)\s*[:\-]?\s*([0-9]{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]+,?\s+[0-9]{4})/i) ||
      html.match(/effective\s+(?:from|w\.e\.f\.?)\s*[:\-]?\s*([0-9]{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]+,?\s+[0-9]{4})/i) ||
      html.match(/(?:w\.e\.f\.?|effective\s+from)\s*[:\-]?\s*([0-9]{1,2}[\.\-\/][0-9]{1,2}[\.\-\/][0-9]{4})/i);

    if (dateMatch) {
      effectiveFrom = this.parseEffectiveDate(dateMatch[1]);
    }

    const candidates = [];
    const errors = [];

    // Target columns for retail < 3 Crore:
    // Column 0: Maturity Periods - Premature Withdrawal Allowed
    // Column 1: Regular (Less than Rs.3 Crore#)
    // Column 3: Senior Citizen* (Less than Rs.3 Crore#)
    // Note: Column 2 and Column 4 are bulk rates (3 Cr to 5 Cr) and must be excluded.
    let regularColIdx = 1;
    let seniorColIdx = 3;

    for (let r = 0; r < targetTable.length; r++) {
      const row = targetTable[r];
      if (row.length < 2) continue;

      const rawLabel = (row[0] || '').trim();
      if (!rawLabel) continue;

      const lowerLabel = rawLabel.toLowerCase();
      // Skip header rows
      if (lowerLabel.includes('fixed deposits interest rates') ||
          lowerLabel.includes('maturity periods') ||
          lowerLabel.includes('regular') ||
          lowerLabel.includes('senior citizen')) {
        continue;
      }

      const tenure = parseKotakTenure(rawLabel);
      if (!tenure.isValid) {
        errors.push(`Row ${r}: ${tenure.error}`);
        continue;
      }

      const rawRegular = (row[regularColIdx] || '').trim();
      const rawSenior = (row[seniorColIdx] || '').trim();

      const regularRate = this.parseRateValue(rawRegular);
      const seniorRate = this.parseRateValue(rawSenior);

      if (regularRate === null || isNaN(regularRate)) {
        errors.push(`Row ${r}: Missing or invalid regular interest rate "${rawRegular}" for tenure "${rawLabel}"`);
        continue;
      }

      // Regular candidate
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
        interestRate: regularRate,
        seniorCitizenRate: seniorRate !== null && !isNaN(seniorRate) ? seniorRate : null,
        superSeniorRate: null,
        minDeposit: '5000.00',
        maxDeposit: '30000000.00', // Retail: Less than Rs. 3 Crore
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
        notes: 'Callable domestic retail fixed deposit below Rs. 3 Crore.',
        rawRateText: rawRegular,
        footnoteMarker: null,
        tenureDomain: tenure.tenureDomain,
        sourceTenureText: tenure.rawLabel,
        minYears: tenure.minYears,
        minMonths: tenure.minMonths,
        minDaysCal: tenure.minDaysCal,
        minOperator: tenure.minOperator,
        maxYears: tenure.maxYears,
        maxMonths: tenure.maxMonths,
        maxDaysCal: tenure.maxDaysCal,
        maxOperator: tenure.maxOperator,
        canonicalTenure: tenure.canonicalTenure,
      }));

      // Senior citizen candidate
      if (seniorRate !== null && !isNaN(seniorRate)) {
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
          interestRate: seniorRate,
          seniorCitizenRate: seniorRate,
          superSeniorRate: null,
          minDeposit: '5000.00',
          maxDeposit: '30000000.00',
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
          notes: 'Callable domestic retail fixed deposit for Senior Citizens below Rs. 3 Crore.',
          rawRateText: rawSenior,
          footnoteMarker: null,
          tenureDomain: tenure.tenureDomain,
          sourceTenureText: tenure.rawLabel,
          minYears: tenure.minYears,
          minMonths: tenure.minMonths,
          minDaysCal: tenure.minDaysCal,
          minOperator: tenure.minOperator,
          maxYears: tenure.maxYears,
          maxMonths: tenure.maxMonths,
          maxDaysCal: tenure.maxDaysCal,
          maxOperator: tenure.maxOperator,
          canonicalTenure: tenure.canonicalTenure,
        }));
      }
    }

    const success = candidates.length > 0 && errors.length === 0;

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
        totalRowsProcessed: targetTable.length,
        candidateCount: candidates.length,
        regularCandidateCount: candidates.filter(c => c.customerType === 'REGULAR').length,
        seniorCandidateCount: candidates.filter(c => c.customerType === 'SENIOR_CITIZEN').length,
      },
    });
  }
}

module.exports = {
  parseKotakTenure,
  KotakRateParser,
};
