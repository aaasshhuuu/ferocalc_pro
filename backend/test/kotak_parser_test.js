// FeroCalc Verified FD Rate Engine — Kotak Mahindra Bank Parser & Pipeline Reliability Test Suite
// Covers:
// 1. Valid official source (HTML & document.write)
// 2. Regular and Senior Citizen slabs
// 3. DAY-based and CALENDAR-based tenure domains
// 4. Missing tenure detection
// 5. Missing effective date handling
// 6. Duplicate slabs prevention
// 7. Malformed source content handling
// 8. Large rate changes & anomaly detection (forcing IN_REVIEW)
// 9. Source timeout or unavailable response handling
// 10. Empty extraction handling
// 11. Registry and Factory integration

'use strict';

const assert = require('assert');
const { KotakRateParser, parseKotakTenure } = require('../parsers/kotak_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const { CandidateValidator } = require('../validators/candidate_validator');
const { AnomalyDetector } = require('../validators/anomaly_detector');
const { BaseCollector } = require('../collectors/base_collector');
const { CandidateRate } = require('../parsers/base_parser');

const KOTAK_OFFICIAL_FIXTURE_HTML = `
document.write("<table width='100%' border='0' cellspacing='1' cellpadding='3' class='table_1 table table-bordered'>" +
"<tr><td colspan='11' class='td_wht' style='background-color:#cccccc!important;'><b>Fixed Deposits Interest Rates for Domestic/ NRO / NRE effective from 4th Nov 2026. (Rates are subject to change from time to time)</b></td></tr>" +
"<tr><td class='td_wht'></td><td colspan='2' class='td_wht'><b>Regular</b></td><td colspan='2' class='td_wht'><b>Senior Citizen*</b></td></tr>" +
"<tr><td class='td_wht'><b>Maturity Periods - Premature Withdrawal Allowed</b></td><td class='td_wht'><b>Less than Rs.3 Crore#</b></td><td class='td_wht'><b>Rs. 3 Cr. & above but less than Rs. 5 Cr.</b></td><td class='td_wht'><b>Less than Rs.3 Crore#</b></td><td class='td_wht'><b>Rs. 3 Cr. & above but less than Rs. 5 Cr.</b></td></tr>" +
"<tr><td class='td_wht' width='33%'>7 - 14 Days</td><td class='td_wht'>2.75%</td><td class='td_wht'>2.75%</td><td class='td_wht'>3.25%</td><td class='td_wht'>2.75%</td></tr>" +
"<tr><td class='td_wht' width='33%'>15 - 30 Days</td><td class='td_wht'>2.75%</td><td class='td_wht'>2.75%</td><td class='td_wht'>3.25%</td><td class='td_wht'>2.75%</td></tr>" +
"<tr><td class='td_wht' width='33%'>31 - 45 Days</td><td class='td_wht'>3.00%</td><td class='td_wht'>3.00%</td><td class='td_wht'>3.50%</td><td class='td_wht'>3.00%</td></tr>" +
"<tr><td class='td_wht' width='33%'>46 - 90 Days</td><td class='td_wht'>3.50%</td><td class='td_wht'>3.50%</td><td class='td_wht'>4.00%</td><td class='td_wht'>3.50%</td></tr>" +
"<tr><td class='td_wht' width='33%'>91 Days</td><td class='td_wht'>4.00%</td><td class='td_wht'>4.00%</td><td class='td_wht'>4.50%</td><td class='td_wht'>4.00%</td></tr>" +
"<tr><td class='td_wht' width='33%'>92 Days - 179 Days</td><td class='td_wht'>4.25%</td><td class='td_wht'>4.25%</td><td class='td_wht'>4.75%</td><td class='td_wht'>4.25%</td></tr>" +
"<tr><td class='td_wht' width='33%'>180 Days</td><td class='td_wht'>5.00%</td><td class='td_wht'>5.00%</td><td class='td_wht'>5.50%</td><td class='td_wht'>5.00%</td></tr>" +
"<tr><td class='td_wht' width='33%'>181 Days to 269 Days</td><td class='td_wht'>5.50%</td><td class='td_wht'>5.50%</td><td class='td_wht'>6.00%</td><td class='td_wht'>5.50%</td></tr>" +
"<tr><td class='td_wht' width='33%'>270 Days</td><td class='td_wht'>5.50%</td><td class='td_wht'>5.50%</td><td class='td_wht'>6.00%</td><td class='td_wht'>5.50%</td></tr>" +
"<tr><td class='td_wht' width='33%'>271 Days to 363 Days</td><td class='td_wht'>6.00%</td><td class='td_wht'>6.00%</td><td class='td_wht'>6.50%</td><td class='td_wht'>6.00%</td></tr>" +
"<tr><td class='td_wht' width='33%'>364 Days</td><td class='td_wht'>6.00%</td><td class='td_wht'>6.00%</td><td class='td_wht'>6.50%</td><td class='td_wht'>6.00%</td></tr>" +
"<tr><td class='td_wht' width='33%'>365 Days to less than 15 Months</td><td class='td_wht'>6.45%</td><td class='td_wht'>6.45%</td><td class='td_wht'>7.20%</td><td class='td_wht'>6.45%</td></tr>" +
"<tr><td class='td_wht' width='33%'>15 Months - less than 18 Months</td><td class='td_wht'>6.60%</td><td class='td_wht'>6.60%</td><td class='td_wht'>7.35%</td><td class='td_wht'>6.60%</td></tr>" +
"<tr><td class='td_wht' width='33%'>18 months - less than 2 years</td><td class='td_wht'>6.55%</td><td class='td_wht'>6.55%</td><td class='td_wht'>7.30%</td><td class='td_wht'>6.55%</td></tr>" +
"<tr><td class='td_wht' width='33%'>2 years- less than 3 years</td><td class='td_wht'>6.80%</td><td class='td_wht'>6.80%</td><td class='td_wht'>7.55%</td><td class='td_wht'>6.80%</td></tr>" +
"<tr><td class='td_wht' width='33%'>3 years and above but less than 4 years</td><td class='td_wht'>6.40%</td><td class='td_wht'>6.40%</td><td class='td_wht'>6.90%</td><td class='td_wht'>6.40%</td></tr>" +
"<tr><td class='td_wht' width='33%'>4 years and above but less than 5 years</td><td class='td_wht'>6.40%</td><td class='td_wht'>6.40%</td><td class='td_wht'>6.90%</td><td class='td_wht'>6.40%</td></tr>" +
"<tr><td class='td_wht' width='33%'>5 years and above upto and inclusive of 10 years</td><td class='td_wht'>6.25%</td><td class='td_wht'>6.25%</td><td class='td_wht'>6.75%</td><td class='td_wht'>6.25%</td></tr>" +
"</table>");
`;

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
  console.log('Kotak Mahindra Bank Parser & Reliability Test Suite    ');
  console.log('======================================================');

  // Group 1: Tenure Parsing
  console.log('\nGroup 1: Kotak Tenure Normalization...');

  runTest('1. Day-based tenures map to DAYS domain', () => {
    const t7 = parseKotakTenure('7 - 14 Days');
    assert.strictEqual(t7.isValid, true);
    assert.strictEqual(t7.tenureDomain, 'DAYS');
    assert.strictEqual(t7.minTenureDays, 7);
    assert.strictEqual(t7.maxTenureDays, 14);

    const t91 = parseKotakTenure('91 Days');
    assert.strictEqual(t91.isValid, true);
    assert.strictEqual(t91.minTenureDays, 91);
    assert.strictEqual(t91.maxTenureDays, 91);
    assert.strictEqual(t91.isBespoke, true);

    const t364 = parseKotakTenure('364 Days');
    assert.strictEqual(t364.isValid, true);
    assert.strictEqual(t364.minTenureDays, 364);
    assert.strictEqual(t364.maxTenureDays, 364);
  });

  runTest('2. Calendar-based tenures map to CALENDAR domain', () => {
    const t1y = parseKotakTenure('365 Days to less than 15 Months');
    assert.strictEqual(t1y.isValid, true);
    assert.strictEqual(t1y.tenureDomain, 'CALENDAR');
    assert.strictEqual(t1y.minYears, 1);
    assert.strictEqual(t1y.minMonths, 0);
    assert.strictEqual(t1y.maxYears, 1);
    assert.strictEqual(t1y.maxMonths, 3);
    assert.strictEqual(t1y.canonicalTenure, '1Y_1Y3M');

    const t15m = parseKotakTenure('15 Months - less than 18 Months');
    assert.strictEqual(t15m.tenureDomain, 'CALENDAR');
    assert.strictEqual(t15m.minYears, 1);
    assert.strictEqual(t15m.minMonths, 3);
    assert.strictEqual(t15m.maxYears, 1);
    assert.strictEqual(t15m.maxMonths, 6);

    const t2y = parseKotakTenure('2 years- less than 3 years');
    assert.strictEqual(t2y.tenureDomain, 'CALENDAR');
    assert.strictEqual(t2y.minYears, 2);
    assert.strictEqual(t2y.maxYears, 3);

    const t5y = parseKotakTenure('5 years and above upto and inclusive of 10 years');
    assert.strictEqual(t5y.tenureDomain, 'CALENDAR');
    assert.strictEqual(t5y.minYears, 5);
    assert.strictEqual(t5y.maxYears, 10);
    assert.strictEqual(t5y.maxOperator, 'LTE');
  });

  // Group 2: Extraction & Rates Validation
  console.log('\nGroup 2: Extraction & Candidate Validation...');

  runTest('3. Parser extracts exactly 36 candidates (18 regular + 18 senior)', () => {
    const parser = new KotakRateParser();
    const result = parser.parse(KOTAK_OFFICIAL_FIXTURE_HTML, {
      sourceUrl: 'https://www.kotak.bank.in/bank/mailers/intrates/get_all_variable_data_latest.php?section=NRO_Term_Deposit',
      sourceContentHash: 'a'.repeat(64),
    });

    assert.strictEqual(result.success, true, `Parse failed: ${result.errors.join('; ')}`);
    assert.strictEqual(result.candidates.length, 36);

    const regular = result.candidates.filter(c => c.customerType === 'REGULAR');
    const senior = result.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');

    assert.strictEqual(regular.length, 18);
    assert.strictEqual(senior.length, 18);
    assert.strictEqual(result.effectiveFrom, '2026-11-04');
  });

  runTest('4. Regular and senior citizen rates match official published schedule', () => {
    const parser = new KotakRateParser();
    const result = parser.parse(KOTAK_OFFICIAL_FIXTURE_HTML, {
      sourceContentHash: 'b'.repeat(64),
    });

    const regMap = new Map();
    for (const c of result.candidates.filter(c => c.customerType === 'REGULAR')) {
      regMap.set(c.tenureLabel, c.interestRate);
    }

    const senMap = new Map();
    for (const c of result.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN')) {
      senMap.set(c.tenureLabel, c.interestRate);
    }

    assert.strictEqual(regMap.get('7 - 14 Days'), 2.75);
    assert.strictEqual(senMap.get('7 - 14 Days'), 3.25); // +0.50%

    assert.strictEqual(regMap.get('180 Days'), 5.00);
    assert.strictEqual(senMap.get('180 Days'), 5.50); // +0.50%

    assert.strictEqual(regMap.get('2 years- less than 3 years'), 6.80);
    assert.strictEqual(senMap.get('2 years- less than 3 years'), 7.55); // +0.75%

    assert.strictEqual(regMap.get('5 years and above upto and inclusive of 10 years'), 6.25);
    assert.strictEqual(senMap.get('5 years and above upto and inclusive of 10 years'), 6.75); // +0.50%
  });

  runTest('5. Product attributes: callable, retail < 3 Crore deposit caps enforced', () => {
    const parser = new KotakRateParser();
    const result = parser.parse(KOTAK_OFFICIAL_FIXTURE_HTML, {
      sourceContentHash: 'c'.repeat(64),
    });

    for (const c of result.candidates) {
      assert.strictEqual(c.isCallable, true);
      assert.strictEqual(c.maxDeposit, '30000000.00');
      assert.strictEqual(c.productType, 'RETAIL_DOMESTIC_TERM_DEPOSIT');
      assert.strictEqual(c.bankCode, 'KOTAK');
    }
  });

  // Group 3: Failure Modes & Anomaly Defenses
  console.log('\nGroup 3: Parser Failure Modes & Anomaly Defenses...');

  runTest('6. Missing tenure detection: invalid labels fail closed', () => {
    const badTenure = parseKotakTenure('Invalid Random Tenure Text');
    assert.strictEqual(badTenure.isValid, false);
    assert.ok(badTenure.error.includes('Unrecognized Kotak tenure label'));

    const badHtml = `
    <table>
      <tr><td>Unrecognized Strange Tenure Label</td><td>6.00%</td><td>6.00%</td><td>6.50%</td><td>6.00%</td></tr>
    </table>
    `;
    const parser = new KotakRateParser();
    const result = parser.parse(badHtml);
    assert.strictEqual(result.success, false);
    assert.ok(result.errors.some(e => e.includes('Unrecognized Kotak tenure label')));
  });

  runTest('7. Missing effective date handles gracefully', () => {
    const noDateHtml = KOTAK_OFFICIAL_FIXTURE_HTML.replace('effective from 4th Nov 2026', '');
    const parser = new KotakRateParser();
    const result = parser.parse(noDateHtml);
    assert.strictEqual(result.success, true);
    assert.strictEqual(result.effectiveFrom, null);
  });

  runTest('8. Duplicate slabs prevention via CandidateValidator', () => {
    const validator = new CandidateValidator();
    const candidate1 = new CandidateRate({
      bankCode: 'KOTAK',
      sourceUrl: 'https://www.kotak.bank.in/rates',
      sourceContentHash: 'd'.repeat(64),
      customerType: 'REGULAR',
      tenureLabel: '7 - 14 Days',
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 2.75,
    });
    const candidate2 = new CandidateRate({
      bankCode: 'KOTAK',
      sourceUrl: 'https://www.kotak.bank.in/rates',
      sourceContentHash: 'd'.repeat(64),
      customerType: 'REGULAR',
      tenureLabel: '7 - 14 Days',
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 2.80, // conflicting rate for duplicate tenure
    });

    const valResult = validator.validateBatch([candidate1, candidate2]);
    assert.strictEqual(valResult.duplicateCount, 1);
    assert.strictEqual(valResult.success, false);
    assert.ok(valResult.errors.some(e => e.includes('Duplicate candidate detected')));
  });

  runTest('9. Malformed source content handling (non-numeric rate strings)', () => {
    const malformedHtml = KOTAK_OFFICIAL_FIXTURE_HTML.replace('2.75%', 'N/A or corrupt');
    const parser = new KotakRateParser();
    const result = parser.parse(malformedHtml);
    assert.strictEqual(result.success, false);
    assert.ok(result.errors.some(e => e.includes('Missing or invalid regular interest rate')));
  });

  runTest('10. Empty extraction handling', () => {
    const parser = new KotakRateParser();
    const result1 = parser.parse('');
    assert.strictEqual(result1.success, false);
    assert.strictEqual(result1.candidates.length, 0);

    const result2 = parser.parse('<html><body><p>No tables here</p></body></html>');
    assert.strictEqual(result2.success, false);
    assert.strictEqual(result2.candidates.length, 0);
  });

  runTest('11. Large rate changes & anomaly detection forces IN_REVIEW', () => {
    const detector = new AnomalyDetector();
    const previousBaseline = [
      {
        customer_type: 'REGULAR',
        tenure_label: '7 - 14 Days',
        tenure_domain: 'DAYS',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: 2.75,
        is_callable: true,
      },
    ];

    // Candidate with a 150 bps spike (from 2.75% to 4.25%)
    const candidateSpike = new CandidateRate({
      bankCode: 'KOTAK',
      customerType: 'REGULAR',
      tenureLabel: '7 - 14 Days',
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 4.25,
      isCallable: true,
      sourceUrl: 'https://www.kotak.bank.in/rates',
      sourceContentHash: 'e'.repeat(64),
    });

    const report = detector.detectAnomalies([candidateSpike], previousBaseline);
    assert.strictEqual(report.hasAnomalies, true);
    assert.strictEqual(candidateSpike.stagingStatus, 'IN_REVIEW');
    assert.ok(report.flags.some(f => f.includes('ANOMALY_LARGE_RATE_DELTA')));
  });

  await runAsyncTest('12. Source timeout / unavailable handling returns FETCH_FAILED without corrupting data', async () => {
    const collector = new BaseCollector({
      id: 'kotak-retail-domestic',
      bankCode: 'KOTAK',
      sourceUrl: 'https://www.kotak.bank.in/bank/mailers/intrates/get_all_variable_data_latest.php?section=NRO_Term_Deposit',
      sourceType: 'HTML',
    });

    // Mock a timed out / unavailable network response
    const mockTimeoutFetcher = async () => {
      const err = new Error('Request timed out after 15000ms');
      err.code = 'TIMEOUT';
      throw err;
    };

    const result = await collector.collect({
      previousHash: 'previously_verified_hash_123',
      fetchFunc: mockTimeoutFetcher,
    });

    assert.strictEqual(result.status, 'FETCH_FAILED');
    assert.strictEqual(result.previousHash, 'previously_verified_hash_123');
    assert.strictEqual(result.changed, false);
    assert.strictEqual(result.contentHash, null);
    assert.strictEqual(result.bodyBuffer, null);
    assert.ok(result.error.includes('timed out'));
  });

  // Group 4: Factory and Registry Integration
  console.log('\nGroup 4: Factory and Registry Integration...');

  runTest('13. Parser factory resolves KotakRateParser for "KOTAK"', () => {
    const parser = getParserForBank('KOTAK');
    assert.ok(parser);
    assert.strictEqual(parser.id, 'kotak_retail_html');
    assert.strictEqual(parser.bankCode, 'KOTAK');
  });

  runTest('14. Source registry contains official kotak-retail-domestic source', () => {
    const sources = defaultRegistry.getByBankCode('KOTAK');
    assert.strictEqual(sources.length, 1);
    const src = sources[0];
    assert.strictEqual(src.id, 'kotak-retail-domestic');
    assert.strictEqual(src.bankCode, 'KOTAK');
    assert.ok(src.sourceUrl.includes('kotak.bank.in'));
    assert.strictEqual(src.enabled, false); // Safe: automation disabled
  });

  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
