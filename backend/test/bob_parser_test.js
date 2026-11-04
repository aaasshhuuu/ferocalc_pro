// Bank of Baroda parser regression tests.
// Tests verify parsing of Table 0 (Callable domestic deposits < 3 Crore),
// tenure domain mapping (DAYS vs CALENDAR), senior citizen rates,
// special schemes (Square Drive 444d, Golden Goal 555d), fail-closed safety, and registry integration.

'use strict';

const assert = require('assert');
const { BobRateParser, parseBobTenure } = require('../parsers/bob_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');

const BOB_FIXTURE_HTML = `
<!DOCTYPE html>
<html>
<body>
  <h2>Domestic Term Deposits including NRO Deposits below ₹ 3.00 Crores, ROI in % p.a [Fresh & Renewal] - (w.e.f 12-06-2026)</h2>
  <table>
    <tr>
      <th>Tenors</th>
      <th>Residents / General Public</th>
      <th>Resident Indian Sr. Citizen</th>
      <th>Resident Super Senior Citizen</th>
    </tr>
    <tr><td>7 days to 14 days</td><td>3.50</td><td>4.00*</td><td>4.00*</td></tr>
    <tr><td>15 days to 45 days</td><td>3.50</td><td>4.00*</td><td>4.00*</td></tr>
    <tr><td>46 days to 90 days</td><td>5.00</td><td>5.50*</td><td>5.50*</td></tr>
    <tr><td>91 days to 180 days</td><td>5.00</td><td>5.50*</td><td>5.50*</td></tr>
    <tr><td>181 days to 210 days</td><td>5.50</td><td>6.00*</td><td>6.00*</td></tr>
    <tr><td>211 days to 270 days</td><td>5.75</td><td>6.25*</td><td>6.25*</td></tr>
    <tr><td>271 days & above and less than 1 year</td><td>6.00</td><td>6.50*</td><td>6.50*</td></tr>
    <tr><td>1 year</td><td>6.25</td><td>6.75*</td><td>6.75*</td></tr>
    <tr><td>Above 1 year to 400 days</td><td>6.25</td><td>6.75*</td><td>6.85 $</td></tr>
    <tr><td>Above 400 days and upto 2 Years (except 444 and 555 Days)</td><td>6.25</td><td>6.75*</td><td>6.85 $</td></tr>
    <tr><td>Above 2 Years and upto 3 Years</td><td>6.25</td><td>6.75*</td><td>6.85 $</td></tr>
    <tr><td>Above 3 Years and upto 5 Years</td><td>6.30</td><td>6.90 #</td><td>7.00 $</td></tr>
    <tr><td>Above 5 Years and upto 10 Years</td><td>6.00</td><td>7.00**</td><td>7.00**</td></tr>
    <tr><td>Above 10 years (MACAD only)</td><td>5.50</td><td>6.00*</td><td>6.00*</td></tr>
    <tr><td>bob Square Drive Deposit Scheme (444 Days)</td><td>6.45</td><td>6.95*</td><td>7.05$</td></tr>
    <tr><td>bob Golden Goal deposit Scheme (555 Days)</td><td>6.75</td><td>7.25*</td><td>7.35$</td></tr>
  </table>
  <p>(* incl. additional ROI 0.50% for RTD upto 3 Years)</p>
</body>
</html>
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

console.log('======================================================');
console.log('Bank of Baroda Parser Test Suite                      ');
console.log('======================================================');

// Group 1: Tenure Parsing
console.log('\nGroup 1: BOB Tenure Normalization...');

runTest('1. Short tenures map to DAYS domain', () => {
  const t7 = parseBobTenure('7 days to 14 days');
  assert.strictEqual(t7.isValid, true);
  assert.strictEqual(t7.tenureDomain, 'DAYS');
  assert.strictEqual(t7.minTenureDays, 7);
  assert.strictEqual(t7.maxTenureDays, 14);

  const t46 = parseBobTenure('46 days to 90 days');
  assert.strictEqual(t46.minTenureDays, 46);
  assert.strictEqual(t46.maxTenureDays, 90);

  const t271 = parseBobTenure('271 days & above and less than 1 year');
  assert.strictEqual(t271.minTenureDays, 271);
  assert.strictEqual(t271.maxTenureDays, 364);
  assert.strictEqual(t271.tenureDomain, 'DAYS');
});

runTest('2. Calendar tenures map to CALENDAR domain with null day bounds', () => {
  const t1y = parseBobTenure('1 year');
  assert.strictEqual(t1y.isValid, true);
  assert.strictEqual(t1y.tenureDomain, 'CALENDAR');
  assert.strictEqual(t1y.minTenureDays, null);
  assert.strictEqual(t1y.maxTenureDays, null);
  assert.strictEqual(t1y.minYears, 1);
  assert.strictEqual(t1y.maxYears, 1);

  const t2y = parseBobTenure('Above 2 Years and upto 3 Years');
  assert.strictEqual(t2y.tenureDomain, 'CALENDAR');
  assert.strictEqual(t2y.minYears, 2);
  assert.strictEqual(t2y.maxYears, 3);
  assert.strictEqual(t2y.minTenureDays, null);
});

runTest('3. Special schemes correctly recognized', () => {
  const sq = parseBobTenure('bob Square Drive Deposit Scheme (444 Days)');
  assert.strictEqual(sq.isValid, true);
  assert.strictEqual(sq.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sq.schemeName, 'bob Square Drive Deposit Scheme');
  assert.strictEqual(sq.minTenureDays, 444);
  assert.strictEqual(sq.maxTenureDays, 444);

  const gg = parseBobTenure('bob Golden Goal deposit Scheme (555 Days)');
  assert.strictEqual(gg.isValid, true);
  assert.strictEqual(gg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(gg.schemeName, 'bob Golden Goal Deposit Scheme');
  assert.strictEqual(gg.minTenureDays, 555);
});

// Group 2: Extraction
console.log('\nGroup 2: Extraction & Candidate Validation...');

runTest('4. Parser extracts exactly 30 candidates (15 regular + 15 senior)', () => {
  const parser = new BobRateParser();
  const res = parser.parse(BOB_FIXTURE_HTML);
  assert.strictEqual(res.success, true);
  assert.strictEqual(res.errors.length, 0);
  assert.strictEqual(res.candidates.length, 30);
  assert.strictEqual(res.effectiveFrom, '2026-06-12');

  const regular = res.candidates.filter(c => c.customerType === 'REGULAR');
  const senior = res.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(regular.length, 15);
  assert.strictEqual(senior.length, 15);
});

runTest('5. Rates and qualifications match official published schedule', () => {
  const parser = new BobRateParser();
  const res = parser.parse(BOB_FIXTURE_HTML);

  // 1-year rate
  const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '1 year');
  assert.ok(reg1y);
  assert.strictEqual(reg1y.interestRate, 6.25);

  const sen1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '1 year');
  assert.ok(sen1y);
  assert.strictEqual(sen1y.interestRate, 6.75);

  // 555 days Golden Goal
  const reg555 = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'bob Golden Goal Deposit Scheme');
  assert.ok(reg555);
  assert.strictEqual(reg555.interestRate, 6.75);
  assert.strictEqual(reg555.rateCategory, 'SPECIAL_SCHEME');

  const sen555 = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.schemeName === 'bob Golden Goal Deposit Scheme');
  assert.ok(sen555);
  assert.strictEqual(sen555.interestRate, 7.25);
  assert.strictEqual(sen555.rateCategory, 'SPECIAL_SCHEME');
});

runTest('6. MACAD only tenure is excluded from retail deposit candidates', () => {
  const parser = new BobRateParser();
  const res = parser.parse(BOB_FIXTURE_HTML);
  const macad = res.candidates.find(c => c.tenureLabel.includes('MACAD'));
  assert.strictEqual(macad, undefined);
});

// Group 3: Registry and Factory
console.log('\nGroup 3: Factory and Registry Integration...');

runTest('7. Parser factory resolves BobRateParser for "BOB"', () => {
  const parser = getParserForBank('BOB');
  assert.ok(parser instanceof BobRateParser);
  assert.strictEqual(parser.bankCode, 'BOB');
});

runTest('8. Source registry contains bob-retail-domestic', () => {
  const src = defaultRegistry.getSource('bob-retail-domestic');
  assert.ok(src);
  assert.strictEqual(src.bankCode, 'BOB');
  assert.strictEqual(typeof src.enabled, 'boolean');
});

console.log(`\n======================================================`);
console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
console.log(`======================================================\n`);

if (failed > 0) process.exit(1);
