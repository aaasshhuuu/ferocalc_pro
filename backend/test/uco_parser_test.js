// UCO Bank parser regression tests.
// Fixtures are synthetic deterministic representations of official public pages.
// Tests verify card rate vs yield, senior premiums, boundaries, 333/444 fail-closed,
// 535 validity, green deposits, bulk exclusion, and parser registry integration.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { UcoRateParser, normalizeTenureLabel, EXPECTED_TOTAL_ROWS } = require('../parsers/uco_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');

const SOURCE_URL = 'https://uco.bank.in/web/guest/interest-rates-on-deposit-schemes';

const ROWS = [
  '<tr><td>7-14 days</td><td>2.90%</td><td>2.90%</td></tr>',
  '<tr><td>15-29 days</td><td>2.90%</td><td>2.90%</td></tr>',
  '<tr><td>30-45 days</td><td>3.00%</td><td>3.00%</td></tr>',
  '<tr><td>46-60 days</td><td>3.50%</td><td>3.50%</td></tr>',
  '<tr><td>61-90 days</td><td>3.50%</td><td>3.50%</td></tr>',
  '<tr><td>91-120 days</td><td>4.25%</td><td>4.25%</td></tr>',
  '<tr><td>121-150 days</td><td>4.25%</td><td>4.26%</td></tr>',
  '<tr><td>151-180 days</td><td>4.75%</td><td>4.77%</td></tr>',
  '<tr><td>181-332 days</td><td>5.00%</td><td>5.03%</td></tr>',
  '<tr><td>333 days</td><td>6.30%</td><td>6.44%</td></tr>',
  '<tr><td>334 days-364 days</td><td>5.00%</td><td>5.09%</td></tr>',
  '<tr><td>1 year</td><td>6.10%</td><td>6.24%</td></tr>',
  '<tr><td>Above 1 year-443 days</td><td>6.10%</td><td>6.24%</td></tr>',
  '<tr><td>444 days</td><td>6.45%</td><td>6.83%</td></tr>',
  '<tr><td>445 days to 534 days</td><td>6.10%</td><td>6.64%</td></tr>',
  '<tr><td>535 days</td><td>6.60%</td><td>6.88%</td></tr>',
  '<tr><td>536 days to 2 years</td><td>6.10%</td><td>6.34%</td></tr>',
  '<tr><td>Above 2 years - 999 days</td><td>6.00%</td><td>6.33%</td></tr>',
  '<tr><td>1000 days (Green Deposit)</td><td>6.20%</td><td>6.71%</td></tr>',
  '<tr><td>1001 days to 3 years</td><td>6.00%</td><td>6.48%</td></tr>',
  '<tr><td>Above 3 years - 5 years</td><td>6.00%</td><td>6.53%</td></tr>',
  '<tr><td>Above 5 years - 1999 days</td><td>6.00%</td><td>6.95%</td></tr>',
  '<tr><td>2000 days (Green Deposit)</td><td>6.20%</td><td>7.33%</td></tr>',
  '<tr><td>2001 days to 2999 days</td><td>6.00%</td><td>7.06%</td></tr>',
  '<tr><td>3000 days (Green Deposit)</td><td>6.20%</td><td>8.04%</td></tr>',
  '<tr><td>Above 3000 days</td><td>6.00%</td><td>7.71%</td></tr>',
];

const FIXTURE = [
  '<html><body>',
  '<table><tr><td>Savings Account</td><td>2.60%</td></tr></table>',
  '<h4><strong>Rate(s) of interest on Domestic Term Deposits less than Rs.3 Crore (including NRO Deposits) : Revised w.e.f. 21.05.2026</strong></h4>',
  '<table>',
  '<thead>',
  '<tr><th rowspan="2">Maturity Period</th><th colspan="2">ROI for General Customer</th></tr>',
  '<tr><th>Rate % p.a.</th><th>Yield in %</th></tr>',
  '</thead>',
  '<tbody>',
  ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<p><strong>Note) 444 Day Special Scheme is also valid for NRE / NRO Term Deposit Scheme.</strong></p>',
  '<table>',
  '<thead><tr><th></th><th>Tenor Up to One Year</th><th>Tenor above One Year</th></tr></thead>',
  '<tbody>',
  '<tr><td>Senior Citizen</td><td>0.25%</td><td>0.50%</td></tr>',
  '<tr><td>Staff</td><td>1.00%</td><td>1.00%</td></tr>',
  '</tbody>',
  '</table>',
  '<h3>UCO GREEN DEPOSIT SCHEME</h3>',
  '<table>',
  '<tr><td>1000 Days</td><td>6.20% (Card Rate+20 bps)</td></tr>',
  '<tr><td>2000 Days</td><td>6.20% (Card Rate+20 bps)</td></tr>',
  '<tr><td>3000 Days</td><td>6.20% (Card Rate+20 bps)</td></tr>',
  '</table>',
  '<p>BULK TERM DEPOSITS (including NRO) Rs.3.00 Cr & above and up to & including Rs.10 Cr w.e.f. 23.10.2026</p>',
  '<table>',
  '<tr><th>Deposit period</th><th>Single Term Deposit Rs. 3 Cr and above</th></tr>',
  '<tr><td>7-14 days</td><td>4.50%</td></tr>',
  '</table>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const parser = new UcoRateParser();
const tests = [];

function run(name, fn) {
  try {
    fn();
    console.log('  PASS: ' + name);
    tests.push(true);
  } catch (e) {
    console.error('  FAIL: ' + name + ': ' + e.message);
    tests.push(false);
  }
}

// 1. General customer card rates vs yield
run('parses general customer card rates from Col 1 and strictly ignores Col 2 yield', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.effectiveFrom, '2026-05-21');
  assert.strictEqual(res.metadata.extractedRows, 26);
  assert.strictEqual(res.metadata.validRows, 24);
  assert.strictEqual(res.metadata.blockedRows, 2);

  // 1 year: Card Rate 6.10%, Yield 6.24%
  const c1yReg = res.candidates.find(c => c.tenureLabel === '1 year' && c.customerType === 'REGULAR');
  assert.ok(c1yReg, '1 year regular candidate should exist');
  assert.strictEqual(c1yReg.interestRate, 6.1);
  assert.notStrictEqual(c1yReg.interestRate, 6.24);

  // 7-14 days: Card Rate 2.90%
  const c7d = res.candidates.find(c => c.tenureLabel === '7-14 days' && c.customerType === 'REGULAR');
  assert.strictEqual(c7d.interestRate, 2.9);

  // Above 3000 days: Card Rate 6.00%, Yield 7.71%
  const c3000d = res.candidates.find(c => c.tenureLabel === 'Above 3000 days' && c.customerType === 'REGULAR');
  assert.strictEqual(c3000d.interestRate, 6.0);
  assert.notStrictEqual(c3000d.interestRate, 7.71);
});

// 2. Senior-citizen premiums by tenor
run('applies senior premium (+0.25% <= 1yr, +0.50% > 1yr) without NRE/NRO leakage', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // 1 year (<= 365 days): 6.10 + 0.25 = 6.35%
  const c1ySr = res.candidates.find(c => c.tenureLabel === '1 year' && c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(c1ySr.interestRate, 6.35);

  // 46-60 days (<= 365 days): 3.50 + 0.25 = 3.75%
  const c46dSr = res.candidates.find(c => c.tenureLabel === '46-60 days' && c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(c46dSr.interestRate, 3.75);

  // Above 1 year-443 days (> 365 days): 6.10 + 0.50 = 6.60%
  const cAbove1ySr = res.candidates.find(c => c.tenureLabel === 'Above 1 year-443 days' && c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(cAbove1ySr.interestRate, 6.6);

  // Above 2 years - 999 days (> 365 days): 6.00 + 0.50 = 6.50%
  const cAbove2ySr = res.candidates.find(c => c.tenureLabel === 'Above 2 years - 999 days' && c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(cAbove2ySr.interestRate, 6.5);

  // Notes confirm Resident Senior Citizen restriction
  assert.ok(c1ySr.notes.includes('Resident Senior Citizen'));
  assert.ok(c1ySr.notes.includes('Not applicable to NRE/NRO'));
});

// 3. Exact tenure parsing and contiguous range boundaries
run('normalizes adjacent boundaries with exact integer days and zero overlaps', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const byLabel = new Map(res.candidates.map(c => [c.tenureLabel, c]));

  // Check 1 year adjacent to Above 1 year-443 days
  const r1y = byLabel.get('1 year');
  const rAbove1y = byLabel.get('Above 1 year-443 days');
  assert.strictEqual(r1y.minTenureDays, 365);
  assert.strictEqual(r1y.maxTenureDays, 365);
  assert.strictEqual(rAbove1y.minTenureDays, 366);
  assert.strictEqual(rAbove1y.maxTenureDays, 443);
  assert.strictEqual(rAbove1y.minTenureDays, r1y.maxTenureDays + 1);

  // Check 445 days to 534 days adjacent to 535 days
  const r445d = byLabel.get('445 days to 534 days');
  const r535d = byLabel.get('535 days');
  const r536d = byLabel.get('536 days to 2 years');
  assert.strictEqual(r445d.minTenureDays, 445);
  assert.strictEqual(r445d.maxTenureDays, 534);
  assert.strictEqual(r535d.minTenureDays, 535);
  assert.strictEqual(r535d.maxTenureDays, 535);
  assert.strictEqual(r536d.minTenureDays, 536);
  assert.strictEqual(r536d.maxTenureDays, 730);

  // Check Above 3000 days: 3001 to 3650 days
  const r3000d = byLabel.get('Above 3000 days');
  assert.strictEqual(r3000d.minTenureDays, 3001);
  assert.strictEqual(r3000d.maxTenureDays, 3650);
});

// 4. 333-day and 444-day expired-scheme conflicts fail closed
run('fails closed on expired 333-day and 444-day schemes without promoting them', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false, 'Parser must fail closed when expired schemes are published');
  assert.strictEqual(res.metadata.hasExpiredSchemeDiscrepancy, true);
  assert.strictEqual(res.metadata.blockedRows, 2);

  // Verify errors mention expiry on 30.06.2026
  assert.ok(res.errors.some(e => e.includes('333') && e.includes('30.06.2026')));
  assert.ok(res.errors.some(e => e.includes('444') && e.includes('30.06.2026')));

  // Verify NO candidates generated for 333 or 444
  const c333 = res.candidates.find(c => c.tenureLabel.includes('333'));
  const c444 = res.candidates.find(c => c.tenureLabel.includes('444'));
  assert.strictEqual(c333, undefined, 'Expired 333-day scheme must NOT generate candidates');
  assert.strictEqual(c444, undefined, 'Expired 444-day scheme must NOT generate candidates');
});

// 5. 535-day scheme identity and validity handling
run('correctly tags 535-day scheme with UCO_535 identity and valid status', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const c535Reg = res.candidates.find(c => c.tenureLabel === '535 days' && c.customerType === 'REGULAR');
  const c535Sr = res.candidates.find(c => c.tenureLabel === '535 days' && c.customerType === 'SENIOR_CITIZEN');

  assert.ok(c535Reg, '535-day regular candidate should exist');
  assert.strictEqual(c535Reg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c535Reg.schemeName, 'UCO_535');
  assert.strictEqual(c535Reg.isBespokeTenure, true);
  assert.strictEqual(c535Reg.interestRate, 6.6);

  assert.ok(c535Sr, '535-day senior candidate should exist');
  assert.strictEqual(c535Sr.interestRate, 7.1); // 6.60 + 0.50%
  assert.ok(c535Sr.notes.includes('valid through 31.03.2027'));
});

// 6. Green Deposit rows remain distinct and are not double-counted
run('extracts 1000, 2000, 3000 days as UCO_GREEN_DEPOSIT without duplicate rows', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const greenCands = res.candidates.filter(c => c.schemeName === 'UCO_GREEN_DEPOSIT');
  assert.strictEqual(greenCands.length, 6, 'Should have exactly 6 Green Deposit candidates (3 tenures * 2 customer types)');

  const c1000Reg = greenCands.find(c => c.tenureLabel === '1000 days (Green Deposit)' && c.customerType === 'REGULAR');
  const c1000Sr = greenCands.find(c => c.tenureLabel === '1000 days (Green Deposit)' && c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(c1000Reg.interestRate, 6.2);
  assert.strictEqual(c1000Sr.interestRate, 6.7);
  assert.strictEqual(c1000Reg.minTenureDays, 1000);
  assert.strictEqual(c1000Reg.maxTenureDays, 1000);

  // Check 2000 and 3000
  const c2000Reg = greenCands.find(c => c.tenureLabel === '2000 days (Green Deposit)' && c.customerType === 'REGULAR');
  const c3000Reg = greenCands.find(c => c.tenureLabel === '3000 days (Green Deposit)' && c.customerType === 'REGULAR');
  assert.strictEqual(c2000Reg.interestRate, 6.2);
  assert.strictEqual(c3000Reg.interestRate, 6.2);
});

// 7. Isolation of callable retail table from bulk tables
run('strictly isolates callable retail table and excludes bulk tables (>= 3 Cr)', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  // Bulk table has 7-14 days @ 4.50% (Table 5)
  // Retail table has 7-14 days @ 2.90%
  const c7d = res.candidates.find(c => c.tenureLabel === '7-14 days' && c.customerType === 'REGULAR');
  assert.strictEqual(c7d.interestRate, 2.9);
  assert.notStrictEqual(c7d.interestRate, 4.5);
  assert.strictEqual(res.effectiveFrom, '2026-05-21');
  assert.notStrictEqual(res.effectiveFrom, '2026-10-23');
});

// 8. Fails closed when effective date is missing
run('fails closed when callable retail effective date is missing', () => {
  const badFixture = FIXTURE.replace(/Revised\s+w\.?e\.?f\.?\s*21\.05\.2026/gi, '');
  const res = parser.parse(badFixture, { sourceContentHash: 'bad', sourceUrl: SOURCE_URL });
  assert.strictEqual(res.effectiveFrom, null);
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('Missing explicit callable retail FD effective date')));
});

// 9. Fails closed when row count changes
run('fails closed when published row count changes unexpectedly', () => {
  const truncatedFixture = FIXTURE.replace('<tr><td>Above 3000 days</td><td>6.00%</td><td>7.71%</td></tr>', '');
  const res = parser.parse(truncatedFixture, { sourceContentHash: 'bad2', sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('Published row count changed')));
});

// 10. Parser factory exposes UCO without enabling source ingestion
run('parser is registered in factory and source is present but disabled in registry', () => {
  const p = getParserForBank('uco');
  assert.ok(p, 'getParserForBank("uco") should return parser');
  assert.strictEqual(p.id, 'uco_retail_html');
  assert.strictEqual(p.bankCode, 'UCO');

  const src = defaultRegistry.getSource('uco-retail-domestic');
  assert.ok(src, 'uco-retail-domestic source should be registered');
  assert.strictEqual(src.enabled, false, 'UCO source MUST be disabled');
  assert.strictEqual(src.bankCode, 'UCO');
});

// Summary
const total = tests.length;
const passed = tests.filter(Boolean).length;
const failed = total - passed;

console.log(`Results: ${passed} passed, ${failed} failed (Total: ${total})`);
if (failed > 0) process.exitCode = 1;
