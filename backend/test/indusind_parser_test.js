// IndusInd Bank parser regression tests.
// Fixtures are deterministic and verify parser extraction, table isolation,
// customer-type separation, policy notice reconciliation, and fail-closed safety.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { IndusIndRateParser, normalizeTenureLabel } = require('../parsers/indusind_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');

const SOURCE_URL = 'https://www.indusind.bank.in/in/en/personal/fixed-deposit-interest-rate.html';

const ROWS = [
  '<tr><td>7 days to 30 days</td><td>3.25</td><td>3.75</td></tr>',
  '<tr><td>31 days to 45 days</td><td>3.50</td><td>4.00</td></tr>',
  '<tr><td>46 days to 60 days</td><td>4.50</td><td>5.00</td></tr>',
  '<tr><td>61 days to 90 days</td><td>4.75</td><td>5.25</td></tr>',
  '<tr><td>91 days to 120 days</td><td>5.00</td><td>5.50</td></tr>',
  '<tr><td>121 days to 179 days</td><td>5.00</td><td>5.50</td></tr>',
  '<tr><td>180 days</td><td>6.00</td><td>6.50</td></tr>',
  '<tr><td>181 days to 210 days</td><td>5.75</td><td>6.25</td></tr>',
  '<tr><td>211 days to 269 days</td><td>6.00</td><td>6.50</td></tr>',
  '<tr><td>270 days to 364 days</td><td>6.25</td><td>6.75</td></tr>',
  '<tr><td>1 Year to below 1 Year 6 Month</td><td>6.75</td><td>7.25</td></tr>',
  '<tr><td>1 Year 6 months to below 1 Year 7 months</td><td>6.90</td><td>7.40</td></tr>',
  '<tr><td>1 Year 7 months to below 2 Years</td><td>6.90</td><td>7.40</td></tr>',
  '<tr><td>2 Years to 3 Years</td><td>7.00</td><td>7.75</td></tr>',
  '<tr><td>Above 3 Years up to below 61 Months</td><td>6.65</td><td>7.15</td></tr>',
  '<tr><td>61 Months and above</td><td>6.50</td><td>7.00</td></tr>',
  '<tr><td>Tax Saver (5 years)</td><td>6.65</td><td>7.15</td></tr>',
];

const FIXTURE = [
  '<html><body>',
  '<p>Term Deposit Interest Rates revision is <b>w.e.f. 24/07/2026</b></p>',
  '<table>',
  '<tr><th></th><th>&lt; 3 Cr* DOMESTIC (RESIDENT) NRE/NRO deposits</th><th>&lt; 3 Cr* (Senior Citizen) Not applicable for NRE/NRO deposits</th></tr>',
  '<tr><th>Tenure</th><th>Rate</th><th>Rate</th></tr>',
  ROWS.join('\n'),
  '</table>',
  '<table><tr><th>Senior Citizens - Additional interest rate on Domestic Term Deposits</th></tr>',
  '<tr><td>*Resident Senior Citizen customers (aged 60 years and above) are eligible for an additional interest benefit on Callable Term Deposits. For deposits below ₹3 Crore, an additional interest benefit of 0.75% p.a. over and above the applicable card rate shall be applicable for tenures of 2 years to 3 years, while an additional 0.50% p.a. shall be applicable for all other eligible tenures. These benefits are not applicable to NRE/NRO deposits.</td></tr>',
  '</table>',
  '<p>Domestic /NRO/ NRE Fixed Deposit Rates (all in %) w.e.f.<b> 13/10/2026</b></p>',
  '<table>',
  '<tr><th></th><th>Above 1 crore to less than 3 crores (Domestic /NRO/NRE deposits) - Premature Withdrawal Not Allowed***</th></tr>',
  '<tr><th>Tenure</th><th>Rate</th><th>Annualized Yield</th></tr>',
  '<tr><td>7 days to 14 days</td><td>4.50</td><td>4.50</td></tr>',
  '<tr><td>15 days to 30 days</td><td>4.60</td><td>4.60</td></tr>',
  '</table>',
  '<table><tr><th>Method of Calculation of Interest, Penalty on Premature Withdrawal and Other Terms & Conditions</th></tr>',
  '<tr><td>Effective 13 October 2026, additional interest rate benefits for Resident Senior Citizen customers (aged 60 years and above) shall be applicable only on Callable Fixed Deposits and shall not be available on Non-Callable Fixed Deposits.</td></tr>',
  '</table>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const parser = new IndusIndRateParser();
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

// 1. Primary table extraction and slab count
run('selects the callable retail FD table and extracts all 17 fixture rows', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.success, true, res.errors.join('; '));
  assert.strictEqual(res.effectiveFrom, '2026-07-24');
  assert.strictEqual(res.metadata.extractedRows, 17);
  assert.strictEqual(res.candidates.length, 34); // 17 rows * 2 customer types
});

// 2. Separation of Public and Senior Citizen candidates
run('preserves Public and Senior Citizen values as separate customer candidates', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  const row2to3Y = res.candidates.filter(c => c.tenureLabel === '2 Years to 3 Years');
  assert.strictEqual(row2to3Y.length, 2);

  const regular = row2to3Y.find(c => c.customerType === 'REGULAR');
  const senior = row2to3Y.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(regular && senior);
  assert.strictEqual(regular.interestRate, 7.00);
  assert.strictEqual(regular.seniorCitizenRate, 7.75);
  assert.strictEqual(senior.interestRate, 7.75);
  assert.strictEqual(senior.seniorCitizenRate, 7.75);
  assert.strictEqual(senior.stagingStatus, 'DRAFT');
  assert.ok(senior.notes.includes('NOT applicable to NRE/NRO'));
});

// 3. Exact contiguous boundaries with zero gaps and zero overlaps
run('normalizes adjacent boundaries with exact integer days and zero overlaps', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  const c1Y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('1 Year to below 1 Year 6'));
  const c1Y6M = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('1 Year 6 months to below 1 Year 7'));
  const c1Y7M = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('1 Year 7 months to below 2 Years'));
  const c2Y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '2 Years to 3 Years');
  const cAbove3Y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('Above 3 Years'));
  const c61M = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('61 Months'));

  assert.ok(c1Y && c1Y6M && c1Y7M && c2Y && cAbove3Y && c61M);

  assert.strictEqual(c1Y.minTenureDays, 365);
  assert.strictEqual(c1Y.maxTenureDays, 547);

  assert.strictEqual(c1Y6M.minTenureDays, 548);
  assert.strictEqual(c1Y6M.maxTenureDays, 577);

  assert.strictEqual(c1Y7M.minTenureDays, 578);
  assert.strictEqual(c1Y7M.maxTenureDays, 729);

  assert.strictEqual(c2Y.minTenureDays, 730);
  assert.strictEqual(c2Y.maxTenureDays, 1095);

  assert.strictEqual(cAbove3Y.minTenureDays, 1096);
  assert.strictEqual(cAbove3Y.maxTenureDays, 1854);

  assert.strictEqual(c61M.minTenureDays, 1855);
  assert.strictEqual(c61M.maxTenureDays, 3650);
});

// 4. Bespoke tenure classification
run('preserves bespoke singleton day 180 and long tenure 61 Months as bespoke', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  const c180 = res.candidates.find(c => c.tenureLabel === '180 days');
  assert.ok(c180);
  assert.strictEqual(c180.minTenureDays, 180);
  assert.strictEqual(c180.maxTenureDays, 180);
  assert.strictEqual(c180.isBespokeTenure, true);

  const c61M = res.candidates.find(c => c.tenureLabel === '61 Months and above');
  assert.ok(c61M);
  assert.strictEqual(c61M.isBespokeTenure, true);
});

// 5. Special scheme classification (Tax Saver)
run('correctly tags Tax Saver 5-year scheme as SPECIAL_SCHEME', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  const taxSaver = res.candidates.filter(c => c.tenureLabel.includes('Tax Saver'));
  assert.strictEqual(taxSaver.length, 2);

  for (const c of taxSaver) {
    assert.strictEqual(c.rateCategory, 'SPECIAL_SCHEME');
    assert.strictEqual(c.schemeName, 'TAX_SAVER');
    assert.strictEqual(c.isBespokeTenure, true);
    assert.strictEqual(c.minTenureDays, 1825);
    assert.strictEqual(c.maxTenureDays, 1825);
  }

  const standard = res.candidates.find(c => c.tenureLabel === '7 days to 30 days');
  assert.strictEqual(standard.rateCategory, 'STANDARD');
  assert.strictEqual(standard.schemeName, null);
});

// 6. Critical date/policy isolation: ignores 13 October 2026 non-callable notice
run('extracts callable effective date 2026-07-24 and excludes non-callable notice date', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.effectiveFrom, '2026-07-24');
  assert.strictEqual(res.metadata.nonCallableRatesIncluded, false);
});

// 7. Table isolation: Non-callable (Table 3) and bulk tables excluded
run('strictly isolates callable retail deposits from non-callable and bulk tables', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  for (const c of res.candidates) {
    assert.strictEqual(c.isCallable, true);
    assert.strictEqual(c.maxDeposit, '29999999.00');
    assert.strictEqual(c.productType, 'RETAIL_DOMESTIC_TERM_DEPOSIT');
    assert.notStrictEqual(c.stagingStatus, 'VERIFIED');
  }
});

// 8. Eligibility restrictions (Senior Citizen & NRE 1-year rule)
run('enforces senior restriction to resident seniors and NRE 1-year minimum tenure', () => {
  const res = parser.parse(FIXTURE, { sourceUrl: SOURCE_URL, sourceContentHash: hash });

  // Sub-1-year regular candidate notes mention NRE 1-year min tenure
  const sub1Y = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays < 365);
  assert.ok(sub1Y.notes.includes('NRE deposits require minimum tenure of 1 year'));

  // 1-year regular candidate notes include NRE
  const above1Y = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays >= 365 && !c.schemeName);
  assert.ok(above1Y.notes.includes('NRE callable fixed deposits'));

  // Senior citizen candidate notes
  const senior = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');
  assert.ok(senior.notes.includes('NOT applicable to NRE/NRO deposits'));
});

// 9. Fail-closed on missing effective date
run('fails closed when callable effective date is missing', () => {
  const bad = FIXTURE.replace('Term Deposit Interest Rates revision is <b>w.e.f. 24/07/2026</b>', 'Term Deposit Rates');
  const res = parser.parse(bad, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
});

// 10. Fail-closed on missing table or changed row count
run('fails closed when published row count changes', () => {
  const bad = FIXTURE.replace(ROWS[1], '');
  const res = parser.parse(bad, { sourceUrl: SOURCE_URL, sourceContentHash: hash });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('Published row count changed')));
});

// 11. Source Registry & Factory Verification
run('parser is registered in factory and source is present but disabled in registry', () => {
  const p = getParserForBank('indusind');
  assert.ok(p, 'getParserForBank("indusind") should return parser');
  assert.strictEqual(p.bankCode, 'INDUSIND');

  const src = defaultRegistry.getSource('indusind-retail-domestic');
  assert.ok(src, 'indusind-retail-domestic source should be registered');
  assert.strictEqual(src.enabled, false, 'IndusInd source must be disabled');
  assert.ok(!defaultRegistry.getEnabledSources().some(s => s.id === src.id));
});

if (tests.some(x => !x)) process.exit(1);
console.log('Results: ' + tests.filter(Boolean).length + ' passed, 0 failed (Total: ' + tests.length + ')');
