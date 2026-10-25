// FeroCalc Verified FD Rate Engine — Axis Bank Retail FD Parser
// Parses Axis Bank callable retail domestic fixed deposit schedule (< Rs. 3 crore) from official PDF rate card.
// Extracts only domestic callable retail table.
// Bulk tables (>= 3 crore), Fixed Deposit Plus, non-callable, and NRI rate tables are strictly excluded.
// Annualized yield is strictly ignored and never emitted as interest rate.
// Source is intentionally disabled in source_registry until live PDF parity and human review are complete.

'use strict';

const { BaseRateParser, CandidateRate, ExtractionResult } = require('./base_parser');
const { extractPdfTokens } = require('./pdf_text_extractor');
const { parseTenureRange } = require('./tenure_parser');

const SOURCE_URL = 'https://www.axis.bank.in/docs/default-source/default-document-library/interest-rates/domestic-fixed-deposit-interest-rates-less-than-3-crores-08-october-2026.pdf?sfvrsn=15a73678_1';
const LANDING_PAGE_URL = 'https://www.axis.bank.in/deposits/fixed-deposits/fd-interest-rates';
const EXPECTED_ROWS = 18;

const MONTH_MAP = {
  jan: '01', january: '01',
  feb: '02', february: '02',
  mar: '03', march: '03',
  apr: '04', april: '04',
  may: '05',
  jun: '06', june: '06',
  jul: '07', july: '07',
  aug: '08', august: '08',
  sep: '09', sept: '09', september: '09',
  oct: '10', october: '10',
  nov: '11', november: '11',
  dec: '12', december: '12',
};

function normalizeTenureLabel(raw) {
  let s = String(raw || '').trim();
  s = s.replace(/[–—−]/g, '-');
  s = s.replace(/^(\d+)\s+(\d+)\s+days$/i, '$1 to $2 days');
  s = s.replace(/(\d+)\s*days?\s*-\s*(\d+)\s*days?/i, '$1 to $2 days');
  s = s.replace(/^(\d+\s*days?)\s+(\d+\s*months?.*)$/i, '$1 to $2');
  s = s.replace(/^(\d+\s*years?)\s+(\d+\s*years?.*)$/i, '$1 to $2');
  s = s.replace(/\byrs?\b/gi, 'years');
  s = s.replace(/\s+/g, ' ').trim();
  return s;
}

function extractCalendarTenure(label) {
  const norm = normalizeTenureLabel(label);

  if (/^3\s*months\s*25\s*days\s*<\s*4\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 3, minDaysCal: 25, minOperator: '>=',
      maxYears: null, maxMonths: 4, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^4\s*months\s*<\s*6\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 4, minDaysCal: 0, minOperator: '>=',
      maxYears: null, maxMonths: 6, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^6\s*months\s*<\s*9\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 6, minDaysCal: 0, minOperator: '>=',
      maxYears: null, maxMonths: 9, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^9\s*months\s*<\s*1\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 9, minDaysCal: 0, minOperator: '>=',
      maxYears: 1, maxMonths: 12, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^1\s*years?\s*to\s*1\s*years?\s*10\s*days$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 12, minDaysCal: 0, minOperator: '>=',
      maxYears: 1, maxMonths: 12, maxDaysCal: 10, maxOperator: '<=',
    };
  }

  if (/^1\s*years?\s*11\s*days\s*<\s*13\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 12, minDaysCal: 11, minOperator: '>=',
      maxYears: null, maxMonths: 13, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^13\s*months\s*<\s*15\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 13, minDaysCal: 0, minOperator: '>=',
      maxYears: null, maxMonths: 15, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^15\s*months\s*<\s*18\s*months$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 15, minDaysCal: 0, minOperator: '>=',
      maxYears: null, maxMonths: 18, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^18\s*months\s*<\s*2\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: null, minMonths: 18, minDaysCal: 0, minOperator: '>=',
      maxYears: 2, maxMonths: 24, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^2\s*years?\s*<\s*3\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 2, minMonths: 24, minDaysCal: 0, minOperator: '>=',
      maxYears: 3, maxMonths: 36, maxDaysCal: 0, maxOperator: '<',
    };
  }

  if (/^3\s*years?\s*<\s*5\s*years?$/i.test(norm)) {
    return {
      tenureDomain: 'CALENDAR',
      minYears: 3, minMonths: 36, minDaysCal: 0, minOperator: '>=',
      maxYears: 5, maxMonths: 60, maxDaysCal: 0, maxOperator: '<',
    };
  }

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

class AxisRateParser extends BaseRateParser {
  constructor() {
    super({
      id: 'axis_retail_pdf',
      version: '1.0.0',
      bankCode: 'AXIS',
    });
  }

  parseEffectiveDate(str) {
    if (!str) return null;
    const mWord = str.match(/(\d{1,2})\s*(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})/i);
    if (mWord) {
      const day = mWord[1].padStart(2, '0');
      const month = MONTH_MAP[mWord[2].toLowerCase()];
      const year = mWord[3];
      if (month) return `${year}-${month}-${day}`;
    }
    const mNum = str.match(/(\d{1,2})[./-](\d{1,2})[./-](\d{4})/);
    if (mNum) {
      const day = mNum[1].padStart(2, '0');
      const month = mNum[2].padStart(2, '0');
      const year = mNum[3];
      return `${year}-${month}-${day}`;
    }
    return null;
  }

  parse(sourceDocument, context = {}) {
    const sourceUrl = context.sourceUrl || SOURCE_URL;
    const sourceId = context.sourceId || 'axis-retail-domestic';
    const sourceContentHash = context.sourceContentHash || '';

    const fail = (message) => new ExtractionResult({
      sourceId,
      bankCode: this.bankCode,
      parserId: this.id,
      parserVersion: this.version,
      sourceUrl,
      sourceContentHash,
      success: false,
      candidates: [],
      errors: [message],
    });

    if (!sourceDocument || (typeof sourceDocument === 'string' && !sourceDocument.trim())) {
      return fail('Source document is empty');
    }

    let tokens;
    try {
      tokens = extractPdfTokens(sourceDocument);
    } catch (e) {
      return fail('Failed to extract PDF text tokens: ' + e.message);
    }

    if (!tokens || tokens.length === 0) {
      return fail('No text tokens extracted from Axis Bank PDF rate card');
    }

    const textJoined = tokens.join(' ');
    const errors = [];

    // 1. Validate Document Scope
    const hasDomestic = /domestic/i.test(textJoined);
    const hasRetailScope = /less than/i.test(textJoined) && /3 crores/i.test(textJoined);
    if (!hasDomestic || !hasRetailScope) {
      errors.push('Document scope mismatch: expected Domestic Retail < 3 Crores');
    }

    if (/3 crores and above/i.test(textJoined) && !/less than.*3 crores/i.test(textJoined)) {
      errors.push('Document contains bulk deposit rates (>= 3 Crores)');
    }

    // 2. Extract Published Effective Date
    const dateMatch = textJoined.match(/w\.?e\.?f\.?\s*(\d{1,2}\s*(?:st|nd|rd|th)?\s+[A-Za-z]+\s+\d{4})/i) ||
                      textJoined.match(/w\.?e\.?f\.?\s*(\d{1,2}[./-]\d{1,2}[./-]\d{4})/i);
    if (!dateMatch) {
      errors.push('Missing published effective date in rate card header');
    }

    const effectiveFrom = dateMatch ? this.parseEffectiveDate(dateMatch[1]) : null;
    if (dateMatch && !effectiveFrom) {
      errors.push(`Could not parse published effective date: "${dateMatch[1]}"`);
    }

    // 3. Locate Table Slabs
    let startIdx = tokens.findIndex(t => t.toLowerCase().includes('senior citizen'));
    if (startIdx === -1) {
      const pairIdx = tokens.findIndex((t, idx) => {
        return t.toLowerCase() === 'senior' && idx + 1 < tokens.length && tokens[idx + 1].toLowerCase().startsWith('citizen');
      });
      if (pairIdx !== -1) {
        startIdx = pairIdx + 1;
      }
    }
    if (startIdx === -1) {
      errors.push('Could not find Senior Citizens column header in PDF table');
    }

    let endIdx = tokens.findIndex(t => t.toLowerCase().includes('disclaimer'));
    if (endIdx === -1) endIdx = tokens.length;

    const candidates = [];
    let extractedRows = 0;
    let validRows = 0;
    let tenureTokens = [];

    if (startIdx !== -1) {
      for (let i = startIdx + 1; i < endIdx; i++) {
        const t = tokens[i];
        const isRate = /^\d+\.\d{2}$/.test(t);

        if (isRate && i + 1 < endIdx && /^\d+\.\d{2}$/.test(tokens[i + 1])) {
          extractedRows++;
          const regularVal = parseFloat(t);
          const seniorVal = parseFloat(tokens[i + 1]);
          const rawTenure = tenureTokens.join(' ').trim();
          tenureTokens = [];
          i++; // skip senior rate token

          if (!rawTenure) {
            errors.push(`Missing tenure label for rate pair ${regularVal} / ${seniorVal}`);
            continue;
          }

          const normalized = normalizeTenureLabel(rawTenure);
          const tenure = parseTenureRange(normalized);
          if (!tenure.isValid || tenure.minTenureDays <= 0 || tenure.maxTenureDays < tenure.minTenureDays) {
            errors.push(`Invalid callable tenure label: "${rawTenure}" (normalized: "${normalized}")`);
            continue;
          }

          validRows++;
          const calFields = extractCalendarTenure(rawTenure);
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
            tenureLabel: normalized,
            sourceTenureText: rawTenure,
            minDeposit: null,
            maxDeposit: '29999999.00',
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
            validationStatus: 'PENDING',
            ...calFields,
          };

          // 1. Regular Customer
          candidates.push(new CandidateRate({
            ...common,
            customerType: 'REGULAR',
            interestRate: regularVal,
            seniorCitizenRate: seniorVal,
            rawRateText: t,
            notes: isSubOneYear
              ? 'Axis Bank callable retail domestic term deposit below Rs. 3 Crore. Sub-one-year tenures are not eligible for NRE deposits.'
              : 'Axis Bank callable retail domestic term deposit below Rs. 3 Crore.',
          }));

          // 2. Senior Citizen Customer
          const spread = Math.round((seniorVal - regularVal) * 100) / 100;
          candidates.push(new CandidateRate({
            ...common,
            customerType: 'SENIOR_CITIZEN',
            interestRate: seniorVal,
            seniorCitizenRate: seniorVal,
            rawRateText: tokens[i],
            notes: `Senior Citizen rates (+${spread.toFixed(2)}%) apply strictly to Resident Indian Senior Citizens. Strictly not applicable to NRE/NRO.`,
          }));
        } else {
          // Ignore stray decorative characters (e.g. icon / currency placeholders)
          if (t !== '`' && t !== '²') {
            tenureTokens.push(t);
          }
        }
      }
    }

    if (validRows !== EXPECTED_ROWS) {
      errors.push(`Published row count mismatch: expected ${EXPECTED_ROWS}, found ${validRows}`);
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
      effectiveFrom,
      rawTableCount: 1,
      candidates,
      success,
      errors,
      metadata: {
        productScope: 'CALLABLE_RETAIL_DOMESTIC_BELOW_3_CRORE',
        sourceType: 'PDF',
        landingPageUrl: LANDING_PAGE_URL,
        publicationDate: '2026-10-08',
        extractedRows,
        validRows,
        expectedRows: EXPECTED_ROWS,
        customerTypes: ['REGULAR', 'SENIOR_CITIZEN'],
        seniorRatesInferred: false,
        yieldIncludedAsRate: false,
        nonCallableRatesIncluded: false,
        bulkTablesExcluded: true,
      },
    });
  }
}

module.exports = {
  AxisRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_ROWS,
  SOURCE_URL,
  LANDING_PAGE_URL,
};
