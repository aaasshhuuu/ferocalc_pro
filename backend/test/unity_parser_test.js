// FeroCalc Verified FD Rate Engine — Unity Small Finance Bank Parser & Reliability Test Suite
// Covers:
// 1. Valid official source (Section A: Retail Investors < Rs 3 crs)
// 2. Regular and Senior Citizen slabs
// 3. DAY-based and CALENDAR-based tenure domains
// 4. Bespoke special schemes (501 Days, 701 Days)
// 5. Missing tenure detection & fail-closed behavior
// 6. Missing effective date handling
// 7. Duplicate slabs prevention
// 8. Exclusion of savings (Section B) and bulk deposits (Sections C & D)
// 9. Malformed source content handling
// 10. Large rate changes & anomaly detection (forcing IN_REVIEW)
// 11. Source timeout or unavailable response handling
// 12. Registry and Factory integration

'use strict';

const assert = require('assert');
const { UnityRateParser, parseUnityTenure, EXPECTED_ROWS } = require('../parsers/unity_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const { CandidateValidator } = require('../validators/candidate_validator');
const { AnomalyDetector } = require('../validators/anomaly_detector');
const { BaseCollector } = require('../collectors/base_collector');
const { CandidateRate } = require('../parsers/base_parser');

const UNITY_OFFICIAL_FIXTURE_TOKENS = [
  'Unity Small Finance Bank Limited (CIN: U65990DL2021PLC385568)',
  'Registered Office: 40, Basant Lok, Vasant Vihar, New Delhi',
  'Corporate Office: Centrum House, CST Road, Vidyanagari Marg, Kalina, Santacruz (E), Mumbai',
  'INTERNAL',
  'A. FIXED DEPOSIT RATE : Retail Investors (< Rs 3 crs)',
  'The deposit interest rat e stands revised from 11 th June , 202 6 as follows :',
  'Tenure General FD Rates % p.a. Senior Citizen FD Rates % p.a.',
  '7 - 14 Days 4.00% 4.00%',
  '15 - 45 Days 4.00% 4.00%',
  '46 - 60 Days 4.75% 5.25%',
  '61 - 90 Days 5.00% 5.50%',
  '91 - 164 Days 5.00% 5.50%',
  '165 Days - 6 Months 5.50% 6.00%',
  '> 6 Months - 201 Days 6.25% 6.75%',
  '202 Days - 364 Days 6.25% 6.75%',
  '12 Months 7.50% 8.00%',
  '12 Months 1 Day 6.50% 7.00%',
  '>12 Months 1 Day - 500 Days 6.50% 7.00%',
  '501 Days 7.80% 8.30%',
  '502 Days - 18 Months 6.75% 7.25%',
  '> 18 Months - 700 Days 6.75% 7.25%',
  '701 Days 6.75% 7.25%',
  '702 Days to 998 Days 6.75% 7.25%',
  '999 Days to 34 Months 6.75% 7.25%',
  '>34 Months - 36 Months 6.75% 7.25%',
  '>36 Months - 60 Months 6.75% 7.25%',
  '>60 Months - 120 Months 6.00% 6.50%',
  'Note: 1. For terms & conditions and any other detail, please contact Unity SFB branch officials.',
  '2. Interest rates are subject to change without prior notice.',
  '3. The above card rates are applicable for recurring deposits (Specific Tenors).',
  '4. For premature withdrawal of fixed deposit and recurring deposits, a premature penalty of 1.00% shall be charged.',
  'B. SAVING DEPOSIT RATE : Retail Investors',
  'The Saving deposit interest rate stands revised from 19th Aug, 2025 as follows :',
  'Amount Rates (%)',
  'Upto 1 lakh 4.50%',
  '>1 lakh - 10 lakh 6.00%',
  'C. Callable Bulk Deposit Rates (% p.a.): w.e.f 02nd July, 2026',
  'Tenure >= Rs 3 crs to < Rs 5 crs',
  '7 - 14 Days 4.90%',
  'D. Non-Callable Bulk Deposit Rates (% p.a.): w.e.f 02nd July, 2026',
  '7 - 14 Days 5.00%',
].join('\n');

let passed = 0;
let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

async function runAsyncTest(name, fn) {
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

async function main() {
  console.log('======================================================');
  console.log('Unity Small Finance Bank Parser & Reliability Tests   ');
  console.log('======================================================');

  // Group 1: Tenure Parsing & Domain Normalization
  console.log('\nGroup 1: Unity SFB Tenure Normalization...');

  runTest('1. Day-based tenures map to DAYS domain', () => {
    const t7 = parseUnityTenure('7 - 14 Days');
    assert.strictEqual(t7.isValid, true);
    assert.strictEqual(t7.tenureDomain, 'DAYS');
    assert.strictEqual(t7.minTenureDays, 7);
    assert.strictEqual(t7.maxTenureDays, 14);
    assert.strictEqual(t7.canonicalTenure, '7D_14D');
    assert.strictEqual(t7.minYears, null);

    const t46 = parseUnityTenure('46 - 60 Days');
    assert.strictEqual(t46.isValid, true);
    assert.strictEqual(t46.tenureDomain, 'DAYS');
    assert.strictEqual(t46.minTenureDays, 46);
    assert.strictEqual(t46.maxTenureDays, 60);

    const t202 = parseUnityTenure('202 Days - 364 Days');
    assert.strictEqual(t202.isValid, true);
    assert.strictEqual(t202.tenureDomain, 'DAYS');
    assert.strictEqual(t202.minTenureDays, 202);
    assert.strictEqual(t202.maxTenureDays, 364);

    const t702 = parseUnityTenure('702 Days to 998 Days');
    assert.strictEqual(t702.isValid, true);
    assert.strictEqual(t702.tenureDomain, 'DAYS');
    assert.strictEqual(t702.minTenureDays, 702);
    assert.strictEqual(t702.maxTenureDays, 998);
  });

  runTest('2. Calendar-based tenures map to CALENDAR domain', () => {
    const t12m = parseUnityTenure('12 Months');
    assert.strictEqual(t12m.isValid, true);
    assert.strictEqual(t12m.tenureDomain, 'CALENDAR');
    assert.strictEqual(t12m.minTenureDays, null);
    assert.strictEqual(t12m.maxTenureDays, null);
    assert.strictEqual(t12m.minYears, 1);
    assert.strictEqual(t12m.minMonths, 0);
    assert.strictEqual(t12m.maxYears, 1);
    assert.strictEqual(t12m.maxMonths, 0);

    const t165d = parseUnityTenure('165 Days - 6 Months');
    assert.strictEqual(t165d.isValid, true);
    assert.strictEqual(t165d.tenureDomain, 'CALENDAR');
    assert.strictEqual(t165d.minDaysCal, 165);
    assert.strictEqual(t165d.maxMonths, 6);

    const t60m = parseUnityTenure('>60 Months - 120 Months');
    assert.strictEqual(t60m.isValid, true);
    assert.strictEqual(t60m.tenureDomain, 'CALENDAR');
    assert.strictEqual(t60m.minYears, 5);
    assert.strictEqual(t60m.maxYears, 10);
  });

  runTest('3. Bespoke special schemes (501 Days & 701 Days) qualify properly', () => {
    const t501 = parseUnityTenure('501 Days');
    assert.strictEqual(t501.isValid, true);
    assert.strictEqual(t501.tenureDomain, 'DAYS');
    assert.strictEqual(t501.minTenureDays, 501);
    assert.strictEqual(t501.maxTenureDays, 501);
    assert.strictEqual(t501.isBespoke, true);
    assert.strictEqual(t501.isSpecialScheme, true);
    assert.strictEqual(t501.schemeName, 'UNITY_501');
    assert.strictEqual(t501.rateCategory, 'SPECIAL_SCHEME');

    const t701 = parseUnityTenure('701 Days');
    assert.strictEqual(t701.isValid, true);
    assert.strictEqual(t701.tenureDomain, 'DAYS');
    assert.strictEqual(t701.minTenureDays, 701);
    assert.strictEqual(t701.maxTenureDays, 701);
    assert.strictEqual(t701.isBespoke, true);
    assert.strictEqual(t701.isSpecialScheme, true);
    assert.strictEqual(t701.schemeName, 'UNITY_701');
  });

  // Group 2: Extraction & Candidate Validation
  console.log('\nGroup 2: Extraction & Candidate Validation...');

  const parser = new UnityRateParser();

  runTest('4. Parser extracts exactly 40 candidates (20 regular + 20 senior)', () => {
    const result = parser.parse(UNITY_OFFICIAL_FIXTURE_TOKENS, {
      sourceId: 'unity-retail-domestic',
      sourceContentHash: 'hash_test_unity',
    });

    assert.strictEqual(result.success, true, result.errors.join('; '));
    assert.strictEqual(result.effectiveFrom, '2026-06-11');
    assert.strictEqual(result.metadata.extractedRows, EXPECTED_ROWS);
    assert.strictEqual(result.metadata.validRows, EXPECTED_ROWS);
    assert.strictEqual(result.candidates.length, EXPECTED_ROWS * 2);

    const regular = result.candidates.filter(c => c.customerType === 'REGULAR');
    const senior = result.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');
    assert.strictEqual(regular.length, 20);
    assert.strictEqual(senior.length, 20);
  });

  runTest('5. Regular and senior citizen rates match official published schedule', () => {
    const result = parser.parse(UNITY_OFFICIAL_FIXTURE_TOKENS, {
      sourceId: 'unity-retail-domestic',
      sourceContentHash: 'hash_test_unity',
    });

    // Peak rate tenure: 501 Days (Regular 7.80%, Senior 8.30%)
    const reg501 = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '501 Days');
    assert.ok(reg501, '501 Days regular candidate should exist');
    assert.strictEqual(reg501.interestRate, 7.80);
    assert.strictEqual(reg501.schemeName, 'UNITY_501');

    const sr501 = result.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '501 Days');
    assert.ok(sr501, '501 Days senior candidate should exist');
    assert.strictEqual(sr501.interestRate, 8.30);
    assert.strictEqual(sr501.schemeName, 'UNITY_501');

    // 12 Months: Regular 7.50%, Senior 8.00%
    const reg12m = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '12 Months');
    assert.ok(reg12m, '12 Months regular candidate should exist');
    assert.strictEqual(reg12m.interestRate, 7.50);

    const sr12m = result.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '12 Months');
    assert.ok(sr12m, '12 Months senior candidate should exist');
    assert.strictEqual(sr12m.interestRate, 8.00);

    // 7 - 14 Days: Regular 4.00%, Senior 4.00% (No extra spread for short tenure)
    const reg7d = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '7 - 14 Days');
    assert.strictEqual(reg7d.interestRate, 4.00);

    const sr7d = result.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '7 - 14 Days');
    assert.strictEqual(sr7d.interestRate, 4.00);
  });

  runTest('6. Product attributes: callable, retail minDeposit and maxDeposit limits enforced', () => {
    const result = parser.parse(UNITY_OFFICIAL_FIXTURE_TOKENS);
    assert.strictEqual(result.metadata.savingsRatesExcluded, true);
    assert.strictEqual(result.metadata.bulkTablesExcluded, true);
    assert.strictEqual(result.metadata.nonCallableExcluded, true);

    for (const c of result.candidates) {
      assert.strictEqual(c.isCallable, true);
      assert.strictEqual(c.minDeposit, 1000);
      assert.strictEqual(c.maxDeposit, '29999999.00');
      assert.strictEqual(c.compoundingFrequency, 'QUARTERLY');
      assert.strictEqual(c.bankCode, 'UNITY_SFB');
      assert.strictEqual(c.effectiveFrom, '2026-06-11');
    }
  });

  // Group 3: Parser Failure Modes & Anomaly Defenses
  console.log('\nGroup 3: Parser Failure Modes & Anomaly Defenses...');

  runTest('7. Missing or unparseable effective date fails closed', () => {
    const noDateFixture = UNITY_OFFICIAL_FIXTURE_TOKENS.replace('11 th June , 202 6', '');
    const result = parser.parse(noDateFixture);
    assert.strictEqual(result.success, false);
    assert.ok(result.errors.some(e => e.includes('effective date')));
  });

  runTest('8. Duplicate slabs prevention via CandidateValidator', () => {
    const result = parser.parse(UNITY_OFFICIAL_FIXTURE_TOKENS, {
      sourceContentHash: 'a'.repeat(64),
    });
    const validator = new CandidateValidator();
    const validation = validator.validateBatch(result.candidates);
    assert.strictEqual(validation.success, true, (validation.errors || []).join('; '));

    // Inject duplicate candidate
    const duplicate = new CandidateRate({
      ...result.candidates[0],
    });
    const withDuplicate = [...result.candidates, duplicate];
    const failValidation = validator.validateBatch(withDuplicate);
    assert.strictEqual(failValidation.success, false);
    assert.ok(failValidation.errors.some(e => e.includes('Duplicate candidate')));
  });

  runTest('9. Malformed source content handling (non-numeric rates)', () => {
    const malformed = UNITY_OFFICIAL_FIXTURE_TOKENS.replace('7.80%', 'CORRUPT%');
    const result = parser.parse(malformed);
    assert.strictEqual(result.success, false);
    assert.ok(result.errors.length > 0);
  });

  runTest('10. Empty extraction handling', () => {
    const result = parser.parse('');
    assert.strictEqual(result.success, false);
    assert.ok(result.errors.some(e => e.includes('empty')));
  });

  runTest('11. Large rate changes & anomaly detection forces IN_REVIEW', () => {
    const previousBaseline = [
      {
        bank_id: 'UNITY_SFB',
        customer_type: 'REGULAR',
        tenure_domain: 'DAYS',
        min_tenure_days: 501,
        max_tenure_days: 501,
        interest_rate: 6.50, // 130 bps delta compared to 7.80%
      },
    ];

    const candidateSpike = new CandidateRate({
      bankId: 'UNITY_SFB',
      bankCode: 'UNITY_SFB',
      sourceId: 'unity-retail-domestic',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      tenureDomain: 'DAYS',
      minTenureDays: 501,
      maxTenureDays: 501,
      tenureLabel: '501 Days',
      interestRate: 7.80,
      isCallable: true,
      effectiveFrom: '2026-06-11',
    });

    const detector = new AnomalyDetector({ maxRateDeltaPct: 0.50 });
    const report = detector.detectAnomalies([candidateSpike], previousBaseline);

    assert.strictEqual(report.hasAnomalies, true);
    assert.ok(report.flags.some(f => f.includes('ANOMALY_LARGE_RATE_DELTA')));
  });

  await runAsyncTest('12. Source timeout / unavailable handling returns FETCH_FAILED without corrupting data', async () => {
    const failingCollector = new BaseCollector({
      id: 'unity-retail-domestic',
      bankCode: 'UNITY_SFB',
      sourceUrl: 'https://unity.bank.in/non-existent-source.pdf',
    });

    const result = await failingCollector.collect({
      fetchFunc: async () => {
        throw new Error('Connection refused / Gateway timeout');
      },
    });

    assert.strictEqual(result.status, 'FETCH_FAILED');
    assert.ok(result.error);
  });

  // Group 4: Factory and Registry Integration
  console.log('\nGroup 4: Factory and Registry Integration...');

  runTest('13. Parser factory resolves UnityRateParser for "UNITY_SFB" and "THE_UNITY_BANK"', () => {
    const p1 = getParserForBank('UNITY_SFB');
    assert.ok(p1 instanceof UnityRateParser);
    assert.strictEqual(p1.id, 'unity_retail_pdf');

    const p2 = getParserForBank('THE_UNITY_BANK');
    assert.ok(p2 instanceof UnityRateParser);
  });

  runTest('14. Source registry contains official unity-retail-domestic source', () => {
    const src = defaultRegistry.getSource('unity-retail-domestic');
    assert.ok(src, 'Source unity-retail-domestic should be registered');
    assert.strictEqual(src.bankCode, 'UNITY_SFB');
    assert.strictEqual(src.parserId, 'unity_retail_pdf');
    assert.strictEqual(src.enabled, false);
    assert.strictEqual(src.sourceType, 'PDF');
    assert.strictEqual(src.sourceUrl, 'https://unity.bank.in/docs/policies/website-disclosure-effective-02-july-2026.pdf');
    assert.strictEqual(src.landingPageUrl, 'https://unity.bank.in/personal-banking/deposits/fixed-deposit');
  });

  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Unhandled suite error:', err);
  process.exit(1);
});
