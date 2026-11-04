// FeroCalc Verified FD Rate Engine — Bank of Baroda (BOB) Parser
// Parses official Bank of Baroda domestic retail callable fixed deposit rates.
// Source: https://bankofbaroda.bank.in/interest-rate-and-service-charges/deposits-interest-rates/fixed-deposits-callable-and-non-callable-upto-ten-crores

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { parseHtmlTables } = require('./html_table_parser');

function parseBobTenure(label) {
  if (!label || typeof label !== 'string') {
    return { isValid: false, error: 'Empty tenure label' };
  }

  const clean = label.replace(/[\u00a0\s]+/g, ' ').trim();
  const lower = clean.toLowerCase();

  // 1. "7 days to 14 days"
  if (/^7\s*days?\s*to\s*14\s*days?$/i.test(lower)) {
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
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 2. "15 days to 45 days"
  if (/^15\s*days?\s*to\s*45\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 15,
      maxTenureDays: 45,
      tenureUnit: 'DAYS',
      minTenure: 15,
      maxTenure: 45,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 3. "46 days to 90 days"
  if (/^46\s*days?\s*to\s*90\s*days?$/i.test(lower)) {
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
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 4. "91 days to 180 days"
  if (/^91\s*days?\s*to\s*180\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 91,
      maxTenureDays: 180,
      tenureUnit: 'DAYS',
      minTenure: 91,
      maxTenure: 180,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 5. "181 days to 210 days"
  if (/^181\s*days?\s*to\s*210\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 181,
      maxTenureDays: 210,
      tenureUnit: 'DAYS',
      minTenure: 181,
      maxTenure: 210,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 6. "211 days to 270 days"
  if (/^211\s*days?\s*to\s*270\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 211,
      maxTenureDays: 270,
      tenureUnit: 'DAYS',
      minTenure: 211,
      maxTenure: 270,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 7. "271 days & above and less than 1 year"
  if (/^271\s*days?\s*(&|and)\s*above\s*and\s*less\s*than\s*1\s*year$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 271,
      maxTenureDays: 364,
      tenureUnit: 'DAYS',
      minTenure: 271,
      maxTenure: 364,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 8. "1 year"
  if (/^1\s*year$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 1,
      maxTenure: 1,
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 9. "Above 1 year to 400 days"
  if (/^above\s*1\s*year\s*to\s*400\s*days?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 366,
      maxTenureDays: 400,
      tenureUnit: 'DAYS',
      minTenure: 366,
      maxTenure: 400,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: true,
      isValid: true,
      error: null,
    };
  }

  // 10. "Above 400 days and upto 2 Years (except 444 and 555 Days)"
  if (/^above\s*400\s*days?\s*and\s*upto\s*2\s*years/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 1,
      maxTenure: 2,
      minYears: 1, minMonths: 1, minDaysCal: 5, minOperator: 'GT',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 11. "Above 2 Years and upto 3 Years"
  if (/^above\s*2\s*years?\s*and\s*upto\s*3\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 2,
      maxTenure: 3,
      minYears: 2, minMonths: 0, minDaysCal: 0, minOperator: 'GT',
      maxYears: 3, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 12. "Above 3 Years and upto 5 Years"
  if (/^above\s*3\s*years?\s*and\s*upto\s*5\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 3,
      maxTenure: 5,
      minYears: 3, minMonths: 0, minDaysCal: 0, minOperator: 'GT',
      maxYears: 5, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 13. "Above 5 Years and upto 10 Years"
  if (/^above\s*5\s*years?\s*and\s*upto\s*10\s*years?$/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      tenureUnit: 'YEARS',
      minTenure: 5,
      maxTenure: 10,
      minYears: 5, minMonths: 0, minDaysCal: 0, minOperator: 'GT',
      maxYears: 10, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      isBespoke: false,
      isValid: true,
      error: null,
    };
  }

  // 14. "bob Square Drive Deposit Scheme (444 Days)"
  if (/bob\s*square\s*drive/i.test(lower) || /444\s*days/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 444,
      maxTenureDays: 444,
      tenureUnit: 'DAYS',
      minTenure: 444,
      maxTenure: 444,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: true,
      schemeName: 'bob Square Drive Deposit Scheme',
      rateCategory: 'SPECIAL_SCHEME',
      isValid: true,
      error: null,
    };
  }

  // 15. "bob Golden Goal deposit Scheme (555 Days)"
  if (/bob\s*golden\s*goal/i.test(lower) || /555\s*days/i.test(lower)) {
    return {
      rawLabel: clean,
      tenureDomain: 'DAYS',
      minTenureDays: 555,
      maxTenureDays: 555,
      tenureUnit: 'DAYS',
      minTenure: 555,
      maxTenure: 555,
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
      isBespoke: true,
      schemeName: 'bob Golden Goal Deposit Scheme',
      rateCategory: 'SPECIAL_SCHEME',
      isValid: true,
      error: null,
    };
  }

  // Excluded or unhandled tenures
  return {
    rawLabel: clean,
    isValid: false,
    error: `Unrecognized Bank of Baroda tenure label: "${clean}"`,
  };
}

class BobRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'bob_retail_html',
      version: '1.0.0',
      bankCode: 'BOB',
    });
  }

  parse(sourceDocument, context = {}) {
    const html = typeof sourceDocument === 'string'
      ? sourceDocument
      : (sourceDocument ? sourceDocument.toString('utf-8') : '');

    const sourceUrl = context.sourceUrl || 'https://bankofbaroda.bank.in/interest-rate-and-service-charges/deposits-interest-rates/fixed-deposits-callable-and-non-callable-upto-ten-crores';
    const sourceContentHash = context.sourceContentHash || '';
    const sourceId = context.sourceId || 'bob-retail-domestic';

    if (!html) {
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
        errors: ['No HTML tables found on Bank of Baroda page'],
      });
    }

    // Extract effective date
    let effectiveFrom = null;
    const dateMatch = html.match(/(?:w\.e\.f\.?|effective\s+from|applicable\s+(?:from|w\.e\.f\.?))\s*[:\-]?\s*([0-9]{1,2}[\.\-\/][0-9]{1,2}[\.\-\/][0-9]{4})/i);
    if (dateMatch) {
      effectiveFrom = this.parseEffectiveDate(dateMatch[1]);
    } else {
      effectiveFrom = '2026-06-12'; // Fallback from verified heading
    }

    // Identify Table 0 (Residents / General Public & Sr. Citizen)
    let targetTable = null;
    for (const table of tables) {
      if (table.length >= 10 && table[0]) {
        const headerStr = table[0].join(' ').toLowerCase();
        if (headerStr.includes('resident') && headerStr.includes('general public')) {
          targetTable = table;
          break;
        }
      }
    }

    if (!targetTable) {
      targetTable = tables[0];
    }

    const candidates = [];
    const errors = [];

    // Columns:
    // 0: Tenors
    // 1: Residents / General Public
    // 2: Resident Indian Sr. Citizen
    // 3: Resident Super Senior Citizen
    for (let r = 1; r < targetTable.length; r++) {
      const row = targetTable[r];
      if (row.length < 2) continue;

      const rawLabel = row[0];
      if (!rawLabel || rawLabel.toLowerCase().includes('tenors') || rawLabel.toLowerCase().includes('macad only')) {
        continue; // Exclude MACAD only / headers
      }

      const tenure = parseBobTenure(rawLabel);
      if (!tenure.isValid) {
        errors.push(`Row ${r}: ${tenure.error}`);
        continue;
      }

      const rawRegular = (row[1] || '').replace(/[*#$]/g, '').trim();
      const rawSenior = (row[2] || '').replace(/[*#$]/g, '').trim();
      const rawSuperSenior = (row[3] || '').replace(/[*#$]/g, '').trim();

      const regularRate = parseFloat(rawRegular);
      const seniorRate = parseFloat(rawSenior);
      const superSeniorRate = rawSuperSenior ? parseFloat(rawSuperSenior) : null;

      if (isNaN(regularRate)) {
        errors.push(`Row ${r}: Invalid regular rate "${row[1]}" for tenure "${rawLabel}"`);
        continue;
      }

      const isSpecialScheme = tenure.rateCategory === 'SPECIAL_SCHEME';
      const schemeName = tenure.schemeName || null;

      // Regular Candidate
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
        seniorCitizenRate: !isNaN(seniorRate) ? seniorRate : null,
        superSeniorRate: superSeniorRate && !isNaN(superSeniorRate) ? superSeniorRate : null,
        minDeposit: '1000.00',
        maxDeposit: '30000000.00', // Below Rs 3 Crore
        isCallable: true,
        compoundingFrequency: 'QUARTERLY',
        effectiveFrom,
        sourceUrl,
        sourceContentHash,
        parserId: this.id,
        parserVersion: this.version,
        isBespokeTenure: tenure.isBespoke,
        rateCategory: isSpecialScheme ? 'SPECIAL_SCHEME' : 'STANDARD',
        schemeName: schemeName,
        notes: isSpecialScheme ? `Bank of Baroda special scheme ${schemeName} callable retail deposit below Rs. 3 Crore.` : null,
        rawRateText: row[1],
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
      }));

      // Senior Citizen Candidate
      if (!isNaN(seniorRate)) {
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
          superSeniorRate: superSeniorRate && !isNaN(superSeniorRate) ? superSeniorRate : null,
          minDeposit: '1000.00',
          maxDeposit: '30000000.00',
          isCallable: true,
          compoundingFrequency: 'QUARTERLY',
          effectiveFrom,
          sourceUrl,
          sourceContentHash,
          parserId: this.id,
          parserVersion: this.version,
          isBespokeTenure: tenure.isBespoke,
          rateCategory: isSpecialScheme ? 'SPECIAL_SCHEME' : 'STANDARD',
          schemeName: schemeName,
          notes: isSpecialScheme ? `Bank of Baroda special scheme ${schemeName} for Resident Indian Senior Citizens.` : (seniorRate > regularRate ? 'Senior citizen additional rate applies to Resident Indian Senior Citizens.' : null),
          rawRateText: row[2],
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
      effectiveFrom,
      rawTableCount: tables.length,
      extractedRowCount: targetTable.length - 1,
      validCandidateCount: candidates.length,
      candidates,
      errors,
    });
  }
}

module.exports = {
  BobRateParser,
  parseBobTenure,
};
