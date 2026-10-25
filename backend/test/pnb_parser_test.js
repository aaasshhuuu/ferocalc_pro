// PNB parser regression tests.
// Fixtures are deterministic and verify parser extraction, table isolation,
// customer-type separation, bespoke tenure preservation, and critical fail-closed behavior.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { PnbRateParser, normalizeTenureLabel } = require('../parsers/pnb_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');

const SOURCE_URL = 'https://www.pnb.bank.in/Interest-Rates-Deposit.html';

// 23 official published rows (including row 10 with ambiguous label "304 Days to >1 Year")
const OFFICIAL_ROWS = [
  '<tr><td>1</td><td>7 to 14 Days</td><td>3.00</td><td>3.50</td><td>3.80</td></tr>',
  '<tr><td>2</td><td>15 to 45 Days</td><td>3.00</td><td>3.50</td><td>3.80</td></tr>',
  '<tr><td>3</td><td>46 to 90 Days</td><td>4.50</td><td>5.00</td><td>5.30</td></tr>',
  '<tr><td>4</td><td>91 to 154 Days</td><td>4.90</td><td>5.40</td><td>5.70</td></tr>',
  '<tr><td>5</td><td>155 Days</td><td>5.55</td><td>6.05</td><td>6.35</td></tr>',
  '<tr><td>6</td><td>156 Days to 179 Days</td><td>4.90</td><td>5.40</td><td>5.70</td></tr>',
  '<tr><td>7</td><td>180 to 270 Days</td><td>5.60</td><td>6.10</td><td>6.40</td></tr>',
  '<tr><td>8</td><td>271 Days to 302 Days</td><td>5.60</td><td>6.10</td><td>6.40</td></tr>',
  '<tr><td>9</td><td>303 Days</td><td>5.55</td><td>6.05</td><td>6.35</td></tr>',
  '<tr><td>10</td><td>304 Days to >1 Year</td><td>5.60</td><td>6.10</td><td>6.40</td></tr>',
  '<tr><td>11</td><td>1 Year</td><td>6.25</td><td>6.75</td><td>7.05</td></tr>',
  '<tr><td>12</td><td>>1 Year to 389 Days</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>13</td><td>390 Days</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>14</td><td>391 Days to 443 Days</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>15</td><td>444 Days</td><td>6.60</td><td>7.10</td><td>7.40</td></tr>',
  '<tr><td>16</td><td>445 Days to 665 Days</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>17</td><td>666 Days</td><td>6.50</td><td>7.00</td><td>7.30</td></tr>',
  '<tr><td>18</td><td>667 Days to 2 Years</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>19</td><td>>2 to 3 Years</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>20</td><td>>3 Years to 1203 Days</td><td>6.35</td><td>6.85</td><td>7.15</td></tr>',
  '<tr><td>21</td><td>1204 Days</td><td>6.30</td><td>6.80</td><td>7.10</td></tr>',
  '<tr><td>22</td><td>1205 Days to 5 Years</td><td>6.35</td><td>6.85</td><td>7.15</td></tr>',
  '<tr><td>23</td><td>>5 Years to 10 Years</td><td>6.00</td><td>6.80</td><td>6.80</td></tr>',
];

const OFFICIAL_PAGE_FIXTURE = [
  '<html><body>',
  '<p>Interest rates revised w.e.f. 01.06.2026</p>',
  '<table>',
  '<tr><th colspan="5">Domestic/NRO $ Fixed Deposit Scheme</th></tr>',
  '<tr><th>Sl. No</th><th>Period</th><th>Revised Rates For Public w.e.f. 01.06.2026</th><th>*Revised Rates for Senior Citizens w.e.f. 01.06.2026</th><th>#Revised Rates for Super Senior Citizens w.e.f. 01.06.2026</th></tr>',
  OFFICIAL_ROWS.join('\n'),
  '</table>',
  '<p>*Senior Citizen-Age 60 Year and upto &lt; 80 Year, #Super Senior Citizen- Age 80 Year and above.</p>',
  '<p>**The additional rate of interest applicable on domestic deposits accepted from senior citizens is not applicable for NRO deposits.</p>',
  '<p>**Two buckets of 1204 days & 1895 days have been specifically identified under the PNB Palaash scheme, to commemorate our Banks’s foundation day, i.e. 12th of April, 1895.</p>',
  '<table>',
  '<tr><th colspan="5">PNB Uttam (Non-Callable) Fixed Deposit Scheme( for Deposit above Rs. 1 Crore to less than Rs 3 Crore)</th></tr>',
  '<tr><th>Sl. No</th><th>Period</th><th>Revised Rates For Public w.e.f. 01.06.2026</th><th>*Revised Rates for Senior Citizens w.e.f. 01.06.2026</th><th>#Revised Rates for Super Senior Citizens w.e.f. 01.06.2026</th></tr>',
  '<tr><td>1</td><td>91 to 154 Days</td><td>5.00</td><td>5.50</td><td>5.80</td></tr>',
  '</table>',
  '<table>',
  '<tr><th colspan="5">Domestic TD Rs.3 Cr. To 10 Cr.</th></tr>',
  '<tr><th>Sl. No</th><th>Period</th><th>Revised Rates For Public w.e.f. 14.03.2026</th><th>Existing Rates</th><th>NRO</th></tr>',
  '<tr><td>1</td><td>7 days to 14 days</td><td>4.50</td><td>4.50</td><td>4.50</td></tr>',
  '</table>',
  '<table>',
  '<tr><th colspan="4">“PNB TAX SAVER FIXED DEPOSIT SCHEME” with effect from 01.02.2026</th></tr>',
  '<tr><td>5 Years</td><td>6.10</td><td>6.60</td><td>7.10</td></tr>',
  '</table>',
  '<table>',
  '<tr><th colspan="4">NRE Term Deposit</th></tr>',
  '<tr><td>1 Year</td><td>6.25</td><td>6.25</td><td>6.25</td></tr>',
  '</table>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(OFFICIAL_PAGE_FIXTURE).digest('hex');
const parser = new PnbRateParser();
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

// 1. Critical Fail-Closed Case on Ambiguous Row
run('fails closed on contradictory "304 Days to >1 Year" label without guessing', () => {
  const res = parser.parse(OFFICIAL_PAGE_FIXTURE, {
    sourceId: 'pnb-retail-domestic',
    sourceUrl: SOURCE_URL,
    sourceContentHash: hash,
  });

  assert.strictEqual(res.success, false, 'Expected parser to fail closed on ambiguous label');
  assert.strictEqual(res.effectiveFrom, '2026-06-01');
  assert.strictEqual(res.metadata.hasAmbiguity, true);
  assert.strictEqual(res.metadata.extractedRows, 23);
  assert.strictEqual(res.metadata.validRows, 22);
  assert.strictEqual(res.candidates.length, 66); // 22 valid rows * 3 customer types
  assert.ok(res.errors.some(e => e.includes('304 Days to >1 Year') && e.includes('conflicting boundary')));
  // Verify NO candidate was emitted for the ambiguous row
  const ambiguousCand = res.candidates.find(c => c.tenureLabel.includes('304 Days'));
  assert.strictEqual(ambiguousCand, undefined, 'Must not emit candidate for ambiguous row');
});

// 2. Separation of Public, Senior, and Super Senior Citizen rates
run('separates Public, Senior, and Super Senior Citizen rates into distinct candidates', () => {
  const res = parser.parse(OFFICIAL_PAGE_FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  const row1Y = res.candidates.filter(c => c.tenureLabel === '1 Year');
  assert.strictEqual(row1Y.length, 3);

  const regular = row1Y.find(c => c.customerType === 'REGULAR');
  const senior = row1Y.find(c => c.customerType === 'SENIOR_CITIZEN');
  const superSenior = row1Y.find(c => c.customerType === 'SUPER_SENIOR_CITIZEN');

  assert.ok(regular && senior && superSenior);
  assert.strictEqual(regular.interestRate, 6.25);
  assert.strictEqual(regular.seniorCitizenRate, 6.75);
  assert.strictEqual(regular.superSeniorRate, 7.05);

  assert.strictEqual(senior.interestRate, 6.75);
  assert.ok(senior.notes.includes('Age 60') && senior.notes.includes('not applicable for NRO'));

  assert.strictEqual(superSenior.interestRate, 7.05);
  assert.ok(superSenior.notes.includes('Age 80') && superSenior.notes.includes('not applicable for NRO'));
});

// 3. Bespoke day slabs and exact boundaries
run('preserves bespoke day slabs and strict boundaries without rounding', () => {
  const res = parser.parse(OFFICIAL_PAGE_FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });

  // 155 Days singleton
  const c155 = res.candidates.find(c => c.tenureLabel === '155 Days' && c.customerType === 'REGULAR');
  assert.ok(c155);
  assert.strictEqual(c155.minTenureDays, 155);
  assert.strictEqual(c155.maxTenureDays, 155);
  assert.strictEqual(c155.isBespokeTenure, true);
  assert.strictEqual(c155.interestRate, 5.55);

  // 303 Days singleton
  const c303 = res.candidates.find(c => c.tenureLabel === '303 Days' && c.customerType === 'REGULAR');
  assert.ok(c303);
  assert.strictEqual(c303.minTenureDays, 303);
  assert.strictEqual(c303.maxTenureDays, 303);
  assert.strictEqual(c303.isBespokeTenure, true);
  assert.strictEqual(c303.interestRate, 5.55);

  // >1 Year to 389 Days strict boundary
  const c389 = res.candidates.find(c => c.tenureLabel === '>1 Year to 389 Days' && c.customerType === 'REGULAR');
  assert.ok(c389);
  assert.strictEqual(c389.minTenureDays, 366);
  assert.strictEqual(c389.maxTenureDays, 389);
  assert.strictEqual(c389.isBespokeTenure, true);

  // 390 Days singleton
  const c390 = res.candidates.find(c => c.tenureLabel === '390 Days' && c.customerType === 'REGULAR');
  assert.ok(c390);
  assert.strictEqual(c390.minTenureDays, 390);
  assert.strictEqual(c390.maxTenureDays, 390);
  assert.strictEqual(c390.isBespokeTenure, true);

  // 444 Days singleton
  const c444 = res.candidates.find(c => c.tenureLabel === '444 Days' && c.customerType === 'REGULAR');
  assert.ok(c444);
  assert.strictEqual(c444.minTenureDays, 444);
  assert.strictEqual(c444.maxTenureDays, 444);
  assert.strictEqual(c444.isBespokeTenure, true);

  // 666 Days singleton
  const c666 = res.candidates.find(c => c.tenureLabel === '666 Days' && c.customerType === 'REGULAR');
  assert.ok(c666);
  assert.strictEqual(c666.minTenureDays, 666);
  assert.strictEqual(c666.maxTenureDays, 666);
  assert.strictEqual(c666.isBespokeTenure, true);

  // >2 to 3 Years boundary
  const c2to3Y = res.candidates.find(c => c.tenureLabel === '>2 to 3 Years' && c.customerType === 'REGULAR');
  assert.ok(c2to3Y);
  assert.strictEqual(c2to3Y.minTenureDays, 731);
  assert.strictEqual(c2to3Y.maxTenureDays, 1095);

  // >3 Years to 1203 Days boundary
  const c3Yto1203 = res.candidates.find(c => c.tenureLabel === '>3 Years to 1203 Days' && c.customerType === 'REGULAR');
  assert.ok(c3Yto1203);
  assert.strictEqual(c3Yto1203.minTenureDays, 1096);
  assert.strictEqual(c3Yto1203.maxTenureDays, 1203);

  // 1205 Days to 5 Years boundary
  const c1205 = res.candidates.find(c => c.tenureLabel === '1205 Days to 5 Years' && c.customerType === 'REGULAR');
  assert.ok(c1205);
  assert.strictEqual(c1205.minTenureDays, 1205);
  assert.strictEqual(c1205.maxTenureDays, 1825);

  // >5 Years to 10 Years boundary
  const c5to10Y = res.candidates.find(c => c.tenureLabel === '>5 Years to 10 Years' && c.customerType === 'REGULAR');
  assert.ok(c5to10Y);
  assert.strictEqual(c5to10Y.minTenureDays, 1826);
  assert.strictEqual(c5to10Y.maxTenureDays, 3650);
});

// 4. Special Scheme Classification (PNB Palaash 1204 days)
run('correctly tags 1204-day PNB Palaash foundation day special scheme', () => {
  const res = parser.parse(OFFICIAL_PAGE_FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  const palaash = res.candidates.filter(c => c.tenureLabel === '1204 Days');
  assert.strictEqual(palaash.length, 3);

  for (const c of palaash) {
    assert.strictEqual(c.rateCategory, 'SPECIAL_SCHEME');
    assert.strictEqual(c.schemeName, 'PNB_PALAASH');
    assert.strictEqual(c.isBespokeTenure, true);
    assert.strictEqual(c.minTenureDays, 1204);
    assert.strictEqual(c.maxTenureDays, 1204);
    assert.ok(c.notes.includes('Palaash'));
  }

  // Standard slabs must NOT be tagged with special scheme
  const standard = res.candidates.find(c => c.tenureLabel === '1 Year');
  assert.strictEqual(standard.rateCategory, 'STANDARD');
  assert.strictEqual(standard.schemeName, null);
});

// 5. Unambiguous Fixture Passes Fully
run('succeeds with 69 candidates when all 23 rows are unambiguous', () => {
  const cleanFixture = OFFICIAL_PAGE_FIXTURE.replace(
    '<tr><td>10</td><td>304 Days to >1 Year</td><td>5.60</td><td>6.10</td><td>6.40</td></tr>',
    '<tr><td>10</td><td>304 Days to 364 Days</td><td>5.60</td><td>6.10</td><td>6.40</td></tr>'
  );
  const cleanHash = crypto.createHash('sha256').update(cleanFixture).digest('hex');
  const res = parser.parse(cleanFixture, { sourceUrl: SOURCE_URL, sourceContentHash: cleanHash });

  assert.strictEqual(res.success, true, res.errors.join('; '));
  assert.strictEqual(res.metadata.hasAmbiguity, false);
  assert.strictEqual(res.metadata.extractedRows, 23);
  assert.strictEqual(res.metadata.validRows, 23);
  assert.strictEqual(res.candidates.length, 69);
});

// 6. Table Isolation: Excludes PNB Uttam, Bulk, Tax Saver, and NRE tables
run('strictly isolates callable retail domestic/NRO table from PNB Uttam and bulk tables', () => {
  const res = parser.parse(OFFICIAL_PAGE_FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.metadata.nonCallableRatesIncluded, false);

  // Check no PNB Uttam candidate rate was extracted
  const uttam = res.candidates.find(c => (c.notes || '').includes('Uttam') || c.schemeName === 'PNB_UTTAM');
  assert.strictEqual(uttam, undefined);

  // Check all candidates are callable and capped at < 3 Crore
  for (const c of res.candidates) {
    assert.strictEqual(c.isCallable, true);
    assert.strictEqual(c.maxDeposit, '29999999.00');
    assert.strictEqual(c.productType, 'RETAIL_DOMESTIC_TERM_DEPOSIT');
    assert.notStrictEqual(c.stagingStatus, 'VERIFIED');
  }
});

// 7. Fail-Closed on Missing Effective Date
run('fails closed when effective date is missing from table header', () => {
  const noDate = OFFICIAL_PAGE_FIXTURE
    .replace(/w\.e\.f\.\s*01\.06\.2026/g, '')
    .replace('Interest rates revised w.e.f. 01.06.2026', 'Interest rates');
  const res = parser.parse(noDate, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
});

// 8. Fail-Closed on Corrupted Rates or Missing Rate Columns
run('fails closed when a rate cell is corrupt or missing', () => {
  const badRate = OFFICIAL_PAGE_FIXTURE.replace('<td>4.50</td><td>5.00</td><td>5.30</td>', '<td>INVALID</td><td>5.00</td><td>5.30</td>');
  const res = parser.parse(badRate, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('Missing regular public interest rate')));
});

// 9. Fail-Closed when Published Row Count Changes
run('fails closed when published row count changes unexpectedly', () => {
  const missingRow = OFFICIAL_PAGE_FIXTURE.replace(OFFICIAL_ROWS[1], '');
  const res = parser.parse(missingRow, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('Published row count changed')));
});

// 10. Source Registry & Factory Verification
run('parser is registered in factory and source is present but disabled in registry', () => {
  const p = getParserForBank('pnb');
  assert.ok(p, 'getParserForBank("pnb") should return parser');
  assert.strictEqual(p.bankCode, 'PNB');

  const src = defaultRegistry.getSource('pnb-retail-domestic');
  assert.ok(src, 'pnb-retail-domestic source should be registered');
  assert.strictEqual(src.enabled, false, 'PNB source must be disabled');
  assert.ok(!defaultRegistry.getEnabledSources().some(s => s.id === src.id));
});

if (tests.some(x => !x)) process.exit(1);
console.log('Results: ' + tests.filter(Boolean).length + ' passed, 0 failed (Total: ' + tests.length + ')');
