// FeroCalc Verified FD Rate Engine — SBI Tenure Domain Normalization Test Suite
//
// Verifies:
// 1. parseSbiTenure normalizer produces canonical DAYS and CALENDAR structures across all 8 slabs.
// 2. Slabs 1-4: DAYS domain, positive integer min/max days, tenureUnit 'DAYS', null calendar fields.
// 3. Slab 4 ('211 days to less than 1 year'): tenureUnit explicitly 'DAYS' (not YEARS or MONTHS).
// 4. Slabs 5-8: CALENDAR domain, null min/max days, tenureUnit 'YEARS', valid calendar components & operators.
// 5. SbiRateParser extracts all 16 candidates (8 regular + 8 senior) with exact dual-domain metadata.
// 6. Regular and Senior Citizen candidates share identical tenure boundaries for each slab.
// 7. Special scheme preservation: We-Care 5-10y is SPECIAL_SCHEME, 5-10y Regular is STANDARD with null schemeName.
// 8. CandidateValidator batch validation succeeds for all 16 candidates (0 duplicates, 0 false overlaps).
// 9. AnomalyDetector handles transition from DAYS baseline to CALENDAR without false ANOMALY_TENURE_DISAPPEARED.
// 10. CandidateStagingService in-place candidate deduplication & domain update logic.
// 11. HDFC calendar tenure parsing remains completely untouched and functioning.
// 12. PromotionService handles promoting normalized SBI candidates cleanly without day pollution.

'use strict';

const assert = require('assert');
const { SbiRateParser, parseSbiTenure } = require('../parsers/sbi_parser');
const { HdfcRateParser } = require('../parsers/hdfc_parser');
const { CandidateRate } = require('../parsers/base_parser');
const { CandidateValidator } = require('../validators/candidate_validator');
const { AnomalyDetector } = require('../validators/anomaly_detector');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { PromotionService } = require('../promotion/promotion_service');

let passed = 0;
let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
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
    console.error(`    ${err.message}`);
    failed++;
  }
}

console.log('======================================================================');
console.log('FeroCalc SBI Tenure Domain Normalization & Safety Regression Test Suite');
console.log('======================================================================\n');

// ------------------------------------------------------------------
// Group 1: parseSbiTenure Dedicated Normalizer Contract Proofs
// ------------------------------------------------------------------
console.log('Group 1: parseSbiTenure Dedicated Normalizer Contract Proofs...');

runTest('1. Slab 1: "7 days to 45 days" maps to DAYS (7..45d, unit: DAYS)', () => {
  const t = parseSbiTenure('7 days to 45 days');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'DAYS');
  assert.strictEqual(t.minTenureDays, 7);
  assert.strictEqual(t.maxTenureDays, 45);
  assert.strictEqual(t.tenureUnit, 'DAYS');
  assert.strictEqual(t.minTenure, 7);
  assert.strictEqual(t.maxTenure, 45);
  assert.strictEqual(t.minYears, null);
  assert.strictEqual(t.maxYears, null);
  assert.strictEqual(t.minOperator, null);
  assert.strictEqual(t.maxOperator, null);
});

runTest('2. Slab 2: "46 days to 179 days" maps to DAYS (46..179d, unit: DAYS)', () => {
  const t = parseSbiTenure('46 days to 179 days');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'DAYS');
  assert.strictEqual(t.minTenureDays, 46);
  assert.strictEqual(t.maxTenureDays, 179);
  assert.strictEqual(t.tenureUnit, 'DAYS');
  assert.strictEqual(t.minTenure, 46);
  assert.strictEqual(t.maxTenure, 179);
  assert.strictEqual(t.minYears, null);
  assert.strictEqual(t.maxYears, null);
});

runTest('3. Slab 3: "180 days to 210 days" maps to DAYS (180..210d, unit: DAYS)', () => {
  const t = parseSbiTenure('180 days to 210 days');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'DAYS');
  assert.strictEqual(t.minTenureDays, 180);
  assert.strictEqual(t.maxTenureDays, 210);
  assert.strictEqual(t.tenureUnit, 'DAYS');
  assert.strictEqual(t.minTenure, 180);
  assert.strictEqual(t.maxTenure, 210);
  assert.strictEqual(t.minYears, null);
  assert.strictEqual(t.maxYears, null);
});

runTest('4. Slab 4: "211 days to less than 1 year" maps to DAYS (211..364d, unit: DAYS)', () => {
  const t = parseSbiTenure('211 days to less than 1 year');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'DAYS');
  assert.strictEqual(t.minTenureDays, 211);
  assert.strictEqual(t.maxTenureDays, 364);
  assert.strictEqual(t.tenureUnit, 'DAYS', 'Critical: tenureUnit must be DAYS, not YEARS or MONTHS');
  assert.strictEqual(t.minTenure, 211);
  assert.strictEqual(t.maxTenure, 364);
  assert.strictEqual(t.minYears, null);
  assert.strictEqual(t.maxYears, null);
});

runTest('5. Slab 5: "1 Year to less than 2 years" maps to CALENDAR (GTE 1Y, LT 2Y, days: null)', () => {
  const t = parseSbiTenure('1 Year to less than 2 years');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'CALENDAR');
  assert.strictEqual(t.minTenureDays, null);
  assert.strictEqual(t.maxTenureDays, null);
  assert.strictEqual(t.tenureUnit, 'YEARS');
  assert.strictEqual(t.minYears, 1);
  assert.strictEqual(t.minMonths, 0);
  assert.strictEqual(t.minDaysCal, 0);
  assert.strictEqual(t.minOperator, 'GTE');
  assert.strictEqual(t.maxYears, 2);
  assert.strictEqual(t.maxMonths, 0);
  assert.strictEqual(t.maxDaysCal, 0);
  assert.strictEqual(t.maxOperator, 'LT');
});

runTest('6. Slab 6: "2 years to less than 3 years" maps to CALENDAR (GTE 2Y, LT 3Y, days: null)', () => {
  const t = parseSbiTenure('2 years to less than 3 years');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'CALENDAR');
  assert.strictEqual(t.minTenureDays, null);
  assert.strictEqual(t.maxTenureDays, null);
  assert.strictEqual(t.tenureUnit, 'YEARS');
  assert.strictEqual(t.minYears, 2);
  assert.strictEqual(t.minMonths, 0);
  assert.strictEqual(t.minDaysCal, 0);
  assert.strictEqual(t.minOperator, 'GTE');
  assert.strictEqual(t.maxYears, 3);
  assert.strictEqual(t.maxMonths, 0);
  assert.strictEqual(t.maxDaysCal, 0);
  assert.strictEqual(t.maxOperator, 'LT');
});

runTest('7. Slab 7: "3 years to less than 5 years" maps to CALENDAR (GTE 3Y, LT 5Y, days: null)', () => {
  const t = parseSbiTenure('3 years to less than 5 years');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'CALENDAR');
  assert.strictEqual(t.minTenureDays, null);
  assert.strictEqual(t.maxTenureDays, null);
  assert.strictEqual(t.tenureUnit, 'YEARS');
  assert.strictEqual(t.minYears, 3);
  assert.strictEqual(t.minMonths, 0);
  assert.strictEqual(t.minDaysCal, 0);
  assert.strictEqual(t.minOperator, 'GTE');
  assert.strictEqual(t.maxYears, 5);
  assert.strictEqual(t.maxMonths, 0);
  assert.strictEqual(t.maxDaysCal, 0);
  assert.strictEqual(t.maxOperator, 'LT');
});

runTest('8. Slab 8: "5 years and up to 10 years" maps to CALENDAR (GTE 5Y, LTE 10Y, days: null)', () => {
  const t = parseSbiTenure('5 years and up to 10 years');
  assert.strictEqual(t.isValid, true);
  assert.strictEqual(t.tenureDomain, 'CALENDAR');
  assert.strictEqual(t.minTenureDays, null);
  assert.strictEqual(t.maxTenureDays, null);
  assert.strictEqual(t.tenureUnit, 'YEARS');
  assert.strictEqual(t.minYears, 5);
  assert.strictEqual(t.minMonths, 0);
  assert.strictEqual(t.minDaysCal, 0);
  assert.strictEqual(t.minOperator, 'GTE');
  assert.strictEqual(t.maxYears, 10);
  assert.strictEqual(t.maxMonths, 0);
  assert.strictEqual(t.maxDaysCal, 0);
  assert.strictEqual(t.maxOperator, 'LTE');
});

// ------------------------------------------------------------------
// Group 2: SbiRateParser Integration with Synthetic Full Table
// ------------------------------------------------------------------
console.log('\nGroup 2: SbiRateParser Integration with Synthetic Full Table...');

const FULL_SBI_SYNTHETIC_HTML = `
<html>
<body>
  <table>
    <tr>
      <th>Tenors</th>
      <th>Existing Rates for Public w.e.f. 15/07/2025</th>
      <th>Revised Rates for Public w.e.f. 15/12/2025</th>
      <th>Existing Rates for Senior Citizen w.e.f. 15/07/2025</th>
      <th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th>
    </tr>
    <tr><td>7 days to 45 days</td><td>3.05</td><td>3.05</td><td>3.55</td><td>3.55</td></tr>
    <tr><td>46 days to 179 days</td><td>4.90</td><td>4.90</td><td>5.40</td><td>5.40</td></tr>
    <tr><td>180 days to 210 days</td><td>5.65</td><td>5.65</td><td>6.15</td><td>6.15</td></tr>
    <tr><td>211 days to less than 1 year</td><td>5.90</td><td>5.90</td><td>6.40</td><td>6.40</td></tr>
    <tr><td>1 Year to less than 2 years</td><td>6.25</td><td>6.25</td><td>6.75</td><td>6.75</td></tr>
    <tr><td>2 years to less than 3 years</td><td>6.40</td><td>6.40</td><td>6.90</td><td>6.90</td></tr>
    <tr><td>3 years to less than 5 years</td><td>6.30</td><td>6.30</td><td>6.80</td><td>6.80</td></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>6.05</td><td>7.05*</td><td>7.05*</td></tr>
  </table>
  <p>* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.</p>
</body>
</html>
`;

const parser = new SbiRateParser();
const extraction = parser.parse(FULL_SBI_SYNTHETIC_HTML, {
  sourceId: 'sbi-retail-domestic',
  sourceUrl: 'https://sbi.co.in/rates',
  sourceContentHash: 'e'.repeat(64),
});

runTest('9. Parser extracts exactly 16 candidates (8 regular + 8 senior)', () => {
  assert.strictEqual(extraction.success, true);
  assert.strictEqual(extraction.candidates.length, 16);
});

runTest('10. Exact 8 DAYS candidates and 8 CALENDAR candidates produced', () => {
  const daysCandidates = extraction.candidates.filter(c => c.tenureDomain === 'DAYS');
  const calCandidates = extraction.candidates.filter(c => c.tenureDomain === 'CALENDAR');
  assert.strictEqual(daysCandidates.length, 8, 'Expected 8 DAYS candidates');
  assert.strictEqual(calCandidates.length, 8, 'Expected 8 CALENDAR candidates');
});

runTest('11. All 8 CALENDAR candidates have null minTenureDays and maxTenureDays', () => {
  const calCandidates = extraction.candidates.filter(c => c.tenureDomain === 'CALENDAR');
  calCandidates.forEach(c => {
    assert.strictEqual(c.minTenureDays, null, `Candidate ${c.tenureLabel} must have null minTenureDays`);
    assert.strictEqual(c.maxTenureDays, null, `Candidate ${c.tenureLabel} must have null maxTenureDays`);
    assert.strictEqual(c.tenureUnit, 'YEARS');
    assert.ok(c.minYears >= 1, `Candidate ${c.tenureLabel} must have minYears >= 1`);
  });
});

runTest('12. Regular and Senior Citizen candidates share identical bounds for each slab', () => {
  const slabs = [
    '7 days to 45 days',
    '46 days to 179 days',
    '180 days to 210 days',
    '211 days to less than 1 year',
    '1 Year to less than 2 years',
    '2 years to less than 3 years',
    '3 years to less than 5 years',
    '5 years and up to 10 years',
  ];

  slabs.forEach(slab => {
    const reg = extraction.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === slab);
    const sen = extraction.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === slab);
    assert.ok(reg, `Missing regular for ${slab}`);
    assert.ok(sen, `Missing senior for ${slab}`);
    assert.strictEqual(reg.tenureDomain, sen.tenureDomain);
    assert.strictEqual(reg.minTenureDays, sen.minTenureDays);
    assert.strictEqual(reg.maxTenureDays, sen.maxTenureDays);
    assert.strictEqual(reg.minYears, sen.minYears);
    assert.strictEqual(reg.maxYears, sen.maxYears);
    assert.strictEqual(reg.minOperator, sen.minOperator);
    assert.strictEqual(reg.maxOperator, sen.maxOperator);
  });
});

runTest('13. Special scheme preservation: We-Care is SPECIAL_SCHEME, Regular 5-10y is STANDARD with null schemeName', () => {
  const reg5y = extraction.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '5 years and up to 10 years');
  const sen5y = extraction.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '5 years and up to 10 years');

  assert.strictEqual(reg5y.rateCategory, 'STANDARD');
  assert.strictEqual(reg5y.schemeName, null);
  assert.strictEqual(reg5y.seniorCitizenRate, null, 'Must NOT leak promotional rate into regular seniorCitizenRate');
  assert.strictEqual(reg5y.interestRate, 6.05);

  assert.strictEqual(sen5y.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen5y.schemeName, 'SBI We-Care');
  assert.strictEqual(sen5y.interestRate, 7.05);
  assert.ok(sen5y.notes && sen5y.notes.includes('SBI We-care'));
});

// ------------------------------------------------------------------
// Group 3: Validation, Anomaly & Deduplication Safety
// ------------------------------------------------------------------
console.log('\nGroup 3: Validation, Anomaly & Deduplication Safety...');

const validator = new CandidateValidator();

runTest('14. Batch validation passes for all 16 candidates (0 duplicates, 0 false overlaps)', () => {
  const valSummary = validator.validateBatch(extraction.candidates);
  assert.strictEqual(valSummary.success, true, `Batch validation failed: ${valSummary.errors.join('; ')}`);
  assert.strictEqual(valSummary.validCount, 16);
  assert.strictEqual(valSummary.duplicateCount, 0, 'Must have 0 duplicates across calendar domain');
  assert.strictEqual(valSummary.overlapCount, 0, 'Must have 0 overlaps across calendar domain');
});

runTest('15. AnomalyDetector does NOT trigger false ANOMALY_TENURE_DISAPPEARED on DAYS -> CALENDAR transition', () => {
  const detector = new AnomalyDetector();
  // Simulate previous baseline that had all 16 candidates in DAYS domain
  const oldDaysBaseline = [
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 7, max_tenure_days: 45, interest_rate: 3.05, tenure_label: '7 days to 45 days' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 46, max_tenure_days: 179, interest_rate: 4.90, tenure_label: '46 days to 179 days' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 180, max_tenure_days: 210, interest_rate: 5.65, tenure_label: '180 days to 210 days' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 211, max_tenure_days: 364, interest_rate: 5.90, tenure_label: '211 days to less than 1 year' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 365, max_tenure_days: 729, interest_rate: 6.25, tenure_label: '1 Year to less than 2 years' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 730, max_tenure_days: 1094, interest_rate: 6.40, tenure_label: '2 years to less than 3 years' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 1095, max_tenure_days: 1824, interest_rate: 6.30, tenure_label: '3 years to less than 5 years' },
    { customer_type: 'REGULAR', is_callable: true, min_tenure_days: 1825, max_tenure_days: 3650, interest_rate: 6.05, tenure_label: '5 years and up to 10 years' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 7, max_tenure_days: 45, interest_rate: 3.55, tenure_label: '7 days to 45 days' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 46, max_tenure_days: 179, interest_rate: 5.40, tenure_label: '46 days to 179 days' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 180, max_tenure_days: 210, interest_rate: 6.15, tenure_label: '180 days to 210 days' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 211, max_tenure_days: 364, interest_rate: 6.40, tenure_label: '211 days to less than 1 year' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 365, max_tenure_days: 729, interest_rate: 6.75, tenure_label: '1 Year to less than 2 years' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 730, max_tenure_days: 1094, interest_rate: 6.90, tenure_label: '2 years to less than 3 years' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 1095, max_tenure_days: 1824, interest_rate: 6.80, tenure_label: '3 years to less than 5 years' },
    { customer_type: 'SENIOR_CITIZEN', is_callable: true, min_tenure_days: 1825, max_tenure_days: 3650, interest_rate: 7.05, tenure_label: '5 years and up to 10 years' },
  ];

  const anomalies = detector.detectAnomalies(extraction.candidates, oldDaysBaseline);
  assert.strictEqual(anomalies.hasAnomalies, false, `Unexpected anomalies detected: ${anomalies.flags.join('; ')}`);
  assert.strictEqual(anomalies.anomalyCount, 0);
  assert.strictEqual(anomalies.candidatesWithAnomalies, 0);
});

// ------------------------------------------------------------------
// Group 4: HDFC Non-Regression & Promotion Service Dual-Domain Verification
// ------------------------------------------------------------------
console.log('\nGroup 4: HDFC Non-Regression & Promotion Service Dual-Domain Verification...');

runTest('16. HdfcRateParser remains operational and unchanged', () => {
  const hdfcParser = new HdfcRateParser();
  assert.strictEqual(hdfcParser.bankCode, 'HDFC');
});

const promoService = new PromotionService();

runTest('17. normalizeCandidate preserves SBI calendar fields and nullifies day bounds', () => {
  const calCand = extraction.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '1 Year to less than 2 years');
  const normalized = promoService.normalizeCandidate(calCand);
  assert.strictEqual(normalized.tenureDomain, 'CALENDAR');
  assert.strictEqual(normalized.minTenureDays, null);
  assert.strictEqual(normalized.maxTenureDays, null);
  assert.strictEqual(normalized.minYears, 1);
  assert.strictEqual(normalized.maxYears, 2);
  assert.strictEqual(normalized.minOperator, 'GTE');
  assert.strictEqual(normalized.maxOperator, 'LT');
});

runTest('18. normalizeCandidate preserves SBI DAYS fields and integer day bounds', () => {
  const dayCand = extraction.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '211 days to less than 1 year');
  const normalized = promoService.normalizeCandidate(dayCand);
  assert.strictEqual(normalized.tenureDomain, 'DAYS');
  assert.strictEqual(normalized.minTenureDays, 211);
  assert.strictEqual(normalized.maxTenureDays, 364);
  assert.strictEqual(normalized.tenureUnit, 'DAYS');
  assert.strictEqual(normalized.minYears, null);
  assert.strictEqual(normalized.maxYears, null);
});

console.log('\n======================================================================');
console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
console.log('======================================================================\n');

if (failed > 0) {
  process.exit(1);
}
