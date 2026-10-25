// Canara Bank parser regression tests.
// Fixtures are synthetic deterministic representations of official public pages.
// Tests verify card rates vs annualized yield, senior citizen rates (<180d equal, >=180d +0.50%),
// special schemes (CANARA_444, CANARA_555), calendar tenure extraction, exclusion of non-callable
// and bulk tables, customer eligibility restrictions, fail-closed safety, and registry integration.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const {
  CanaraRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_ROWS,
} = require('../parsers/canara_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const { runVerification, verifyContent } = require('../scripts/verify_canara_live_source');

const SOURCE_URL = 'https://www.canarabank.bank.in/term-deposits-rate-of-interest-p.a.';

const CALLABLE_ROWS = [
  '<tr><td>7 Days to 45 Days*</td><td>3.00</td><td>3.03</td><td>3.00</td><td>3.03</td><td>NA</td><td>NA</td><td>NA</td><td>NA</td></tr>',
  '<tr><td>46 Days to 90 Days</td><td>4.00</td><td>4.06</td><td>4.00</td><td>4.06</td><td>4.10</td><td>4.16</td><td>4.10</td><td>4.16</td></tr>',
  '<tr><td>91 Days to 179 Days</td><td>4.25</td><td>4.32</td><td>4.25</td><td>4.32</td><td>4.35</td><td>4.42</td><td>4.35</td><td>4.42</td></tr>',
  '<tr><td>180 Days to 269 Days</td><td>5.25</td><td>5.35</td><td>5.75</td><td>5.87</td><td>5.35</td><td>5.46</td><td>5.85</td><td>5.98</td></tr>',
  '<tr><td>270 Days to less than 1 Year</td><td>5.50</td><td>5.61</td><td>6.00</td><td>6.14</td><td>5.60</td><td>5.72</td><td>6.10</td><td>6.24</td></tr>',
  '<tr><td>1 Year & above to 1 year 3 months Only (Except 444 days)</td><td>6.25</td><td>6.40</td><td>6.75</td><td>6.92</td><td>6.35</td><td>6.50</td><td>6.85</td><td>7.03</td></tr>',
  '<tr><td>444 Days ##</td><td>6.50</td><td>6.66</td><td>7.00</td><td>7.19</td><td>6.60</td><td>6.77</td><td>7.10</td><td>7.29</td></tr>',
  '<tr><td>555 Days ##</td><td>6.60</td><td>6.77</td><td>7.10</td><td>7.29</td><td>6.70</td><td>6.87</td><td>7.20</td><td>7.40</td></tr>',
  '<tr><td>Above 1 Year 3 months to less than 2 Years (Except 555 days)</td><td>6.25</td><td>6.40</td><td>6.75</td><td>6.92</td><td>6.35</td><td>6.50</td><td>6.85</td><td>7.03</td></tr>',
  '<tr><td>2 Years & above to less than 3 Years</td><td>6.25</td><td>6.40</td><td>6.75</td><td>6.92</td><td>6.35</td><td>6.50</td><td>6.85</td><td>7.03</td></tr>',
  '<tr><td>3 Years & above to less than 5 Years</td><td>6.25</td><td>6.40</td><td>6.75</td><td>6.92</td><td>NA</td><td>NA</td><td>NA</td><td>NA</td></tr>',
  '<tr><td>5 Years & above to 10 Years</td><td>6.25</td><td>6.40</td><td>6.75</td><td>6.92</td><td>NA</td><td>NA</td><td>NA</td><td>NA</td></tr>',
];

const FIXTURE = [
  '<!DOCTYPE html><html><body>',
  '<h1>TERM DEPOSITS-Rate of Interest (%) p.a.</h1>',
  '<table>',
  '<thead>',
  '<tr><th colspan="9">2. TERM DEPOSITS Rate of Interest (%) p.a. For Deposits less than Rs.3 Crore w.e.f. 17.03.2026</th></tr>',
  '<tr><th colspan="9">A. Domestic</th></tr>',
  '<tr><th colspan="9">Less than Rs.3 Crore</th></tr>',
  '<tr><th colspan="5">Callable</th><th colspan="4">Non Callable ( Above Rs.1 Crore ) $</th></tr>',
  '<tr><th rowspan="2">Maturity Period</th><th colspan="2">General Public</th><th colspan="2">Senior Citizen</th><th colspan="2">General Public</th><th colspan="2">Senior Citizen</th></tr>',
  '<tr><th>Rate of Interest (% p.a.)</th><th>Annualised Interest yield (% p.a.) **</th><th>Rate of Interest (% p.a.) #</th><th>Annualised Interest yield (% p.a.) **</th><th>Rate of Interest (% p.a.)</th><th>Annualised Interest yield (% p.a.) **</th><th>Rate of Interest (% p.a.) #</th><th>Annualised Interest yield (% p.a.) **</th></tr>',
  '<tr><th>Term Deposits (All Maturities)</th><th>—</th><th>—</th><th>—</th><th>—</th><th>—</th><th>—</th><th>—</th><th>—</th></tr>',
  '</thead>',
  '<tbody>',
  CALLABLE_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<div>',
  '<p># Additional 0.50% interest is offered to Senior Citizens for domestic term deposits of less than Rs. 3 Crore with tenure of 180 days and above.</p>',
  '<p>Senior Citizen rates are not applicable to NRO, NRE, or Capital Gains deposits.</p>',
  '<p>NRE fixed deposits require a minimum tenure of 1 year. Sub-one-year slabs are not eligible for NRE deposits.</p>',
  '</div>',
  '<h3>ROI on Canara Retail Green Deposits w.e.f.17.03.2026</h3>',
  '<table>',
  '<tr><th>Period of Deposit</th><th>ROI (%)</th></tr>',
  '<tr><td>1111 days</td><td>6.10</td></tr>',
  '<tr><td>2222 days</td><td>6.05</td></tr>',
  '<tr><td>3333 days</td><td>6.05</td></tr>',
  '</table>',
  '<h3>Callable Deposits w.e.f. 23.10.2026 (Rs. 3 Crore & above)</h3>',
  '<table>',
  '<tr><th>Period</th><th>3 Crore - less than 10 Crore</th></tr>',
  '<tr><td>7 Days to 14 Days</td><td>3.00</td></tr>',
  '<tr><td>1 Year Only</td><td>6.20</td></tr>',
  '</table>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const parser = new CanaraRateParser();
const tests = [];

async function run(name, fn) {
  try {
    await fn();
    console.log('  PASS: ' + name);
    tests.push(true);
  } catch (e) {
    console.error('  FAIL: ' + name + ': ' + e.message);
    tests.push(false);
  }
}

(async () => {
console.log('Canara Bank Parser Regression Test Suite');

// 1. Full extraction from fixture
await run('extracts all 12 callable retail rows yielding 24 candidates across Regular and Senior Citizen', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, true, res.errors.join('; '));
  assert.strictEqual(res.effectiveFrom, '2026-03-17');
  assert.strictEqual(res.rawTableCount, 3);
  assert.strictEqual(res.metadata.extractedRows, 12);
  assert.strictEqual(res.metadata.validRows, 12);
  assert.strictEqual(res.candidates.length, 24);
  assert.strictEqual(res.metadata.excludedTableCount, 2);
});

// 2. Card rate vs Annualized yield separation
run('extracts card interest rates from Col 1 & 3 and strictly ignores annualized yield columns', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.yieldIncludedAsRate, false);

  // 1 Year & above to 1 year 3 months: Regular Card 6.25% (Yield 6.40%), Senior Card 6.75% (Yield 6.92%)
  const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('1 Year & above'));
  assert.ok(reg1y, '1 Year regular candidate should exist');
  assert.strictEqual(reg1y.interestRate, 6.25);
  assert.notStrictEqual(reg1y.interestRate, 6.40);

  const sr1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('1 Year & above'));
  assert.ok(sr1y, '1 Year senior candidate should exist');
  assert.strictEqual(sr1y.interestRate, 6.75);
  assert.notStrictEqual(sr1y.interestRate, 6.92);

  // 180 Days to 269 Days: Regular Card 5.25% (Yield 5.35%), Senior Card 5.75% (Yield 5.87%)
  const reg180 = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('180 Days'));
  assert.strictEqual(reg180.interestRate, 5.25);
  assert.notStrictEqual(reg180.interestRate, 5.35);

  const sr180 = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('180 Days'));
  assert.strictEqual(sr180.interestRate, 5.75);
  assert.notStrictEqual(sr180.interestRate, 5.87);
});

// 3. Senior Citizen rates (< 180 days equal to regular, >= 180 days +0.50%)
run('verifies senior rates equal regular rates below 180 days, and have exactly +0.50% spread for 180 days and above', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const byTenure = new Map();
  for (const c of res.candidates) {
    if (!byTenure.has(c.tenureLabel)) byTenure.set(c.tenureLabel, {});
    byTenure.get(c.tenureLabel)[c.customerType] = c.interestRate;
  }

  assert.strictEqual(byTenure.size, 12);
  for (const [label, rates] of byTenure.entries()) {
    assert.ok(rates.REGULAR !== undefined, `Missing regular rate for ${label}`);
    assert.ok(rates.SENIOR_CITIZEN !== undefined, `Missing senior rate for ${label}`);

    const isSub180Days = label.includes('7 Days') || label.includes('46 Days') || label.includes('91 Days');
    const spread = Math.round((rates.SENIOR_CITIZEN - rates.REGULAR) * 100) / 100;

    if (isSub180Days) {
      assert.strictEqual(spread, 0.0, `Senior spread for sub-180-day tenure "${label}" should be 0.0, got ${spread}`);
      assert.strictEqual(rates.SENIOR_CITIZEN, rates.REGULAR);
    } else {
      assert.strictEqual(spread, 0.50, `Senior spread for tenure "${label}" should be 0.50, got ${spread}`);
    }
  }
});

// 4. Special Schemes CANARA_444 and CANARA_555
run('correctly tags Canara 444 and Canara 555 special schemes', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // Canara 444
  const c444Reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('444 Days'));
  assert.ok(c444Reg, '444 Days regular candidate should exist');
  assert.strictEqual(c444Reg.interestRate, 6.50);
  assert.strictEqual(c444Reg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c444Reg.schemeName, 'CANARA_444');
  assert.strictEqual(c444Reg.minTenureDays, 444);
  assert.strictEqual(c444Reg.maxTenureDays, 444);

  const c444Sr = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('444 Days'));
  assert.ok(c444Sr, '444 Days senior candidate should exist');
  assert.strictEqual(c444Sr.interestRate, 7.00);
  assert.strictEqual(c444Sr.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c444Sr.schemeName, 'CANARA_444');

  // Canara 555
  const c555Reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('555 Days'));
  assert.ok(c555Reg, '555 Days regular candidate should exist');
  assert.strictEqual(c555Reg.interestRate, 6.60);
  assert.strictEqual(c555Reg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c555Reg.schemeName, 'CANARA_555');
  assert.strictEqual(c555Reg.minTenureDays, 555);
  assert.strictEqual(c555Reg.maxTenureDays, 555);

  const c555Sr = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('555 Days'));
  assert.ok(c555Sr, '555 Days senior candidate should exist');
  assert.strictEqual(c555Sr.interestRate, 7.10);
  assert.strictEqual(c555Sr.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c555Sr.schemeName, 'CANARA_555');
});

// 5. Excluded tables and non-callable columns isolation
run('strictly isolates and excludes non-callable columns and bulk tables', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.nonCallableRatesIncluded, false);
  assert.strictEqual(res.metadata.bulkTablesExcluded, true);
  assert.strictEqual(res.metadata.excludedTableCount, 2);

  // Non-callable distinct rates (e.g. 4.10% for 46-90d, 4.35% for 91-179d) must not exist
  const ncRate1 = res.candidates.find(c => c.interestRate === 4.10);
  assert.strictEqual(ncRate1, undefined, 'Non-callable rate 4.10% should not exist');

  const ncRate2 = res.candidates.find(c => c.interestRate === 4.35);
  assert.strictEqual(ncRate2, undefined, 'Non-callable rate 4.35% should not exist');

  // Bulk rate (6.20% for 1 Year bulk) must not exist
  const bulkCandidate = res.candidates.find(c => c.tenureLabel === '1 Year Only');
  assert.strictEqual(bulkCandidate, undefined, 'Bulk row 1 Year Only should not exist');
});

// 6. Structured calendar tenure bounds
run('extracts structured calendar tenure fields correctly for various tenure formats', () => {
  // Test 7 Days to 45 Days
  const cal1 = extractCalendarTenure('7 Days to 45 Days*');
  assert.strictEqual(cal1.tenureDomain, 'DAYS');

  // Test 270 Days to less than 1 Year
  const cal2 = extractCalendarTenure('270 Days to less than 1 Year');
  assert.strictEqual(cal2.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal2.minMonths, 9);
  assert.strictEqual(cal2.maxMonths, 12);
  assert.strictEqual(cal2.maxOperator, '<');

  // Test 1 Year & above to 1 year 3 months Only
  const cal3 = extractCalendarTenure('1 Year & above to 1 year 3 months Only (Except 444 days)');
  assert.strictEqual(cal3.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal3.minYears, 1);
  assert.strictEqual(cal3.minMonths, 12);
  assert.strictEqual(cal3.maxYears, 1);
  assert.strictEqual(cal3.maxMonths, 15);
  assert.strictEqual(cal3.maxOperator, '<=');

  // Test Above 1 Year 3 months to less than 2 Years
  const cal4 = extractCalendarTenure('Above 1 Year 3 months to less than 2 Years (Except 555 days)');
  assert.strictEqual(cal4.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal4.minMonths, 15);
  assert.strictEqual(cal4.minDaysCal, 1);
  assert.strictEqual(cal4.maxMonths, 24);
  assert.strictEqual(cal4.maxOperator, '<');

  // Test 5 Years & above to 10 Years
  const cal5 = extractCalendarTenure('5 Years & above to 10 Years');
  assert.strictEqual(cal5.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal5.minYears, 5);
  assert.strictEqual(cal5.minMonths, 60);
  assert.strictEqual(cal5.maxYears, 10);
  assert.strictEqual(cal5.maxMonths, 120);
});

// 7. Customer eligibility restrictions
run('enforces customer eligibility restrictions in candidate notes', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // Senior citizen candidate with spread
  const senior180 = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('180 Days'));
  assert.ok(senior180.notes.includes('Resident Indian Senior Citizens'));
  assert.ok(senior180.notes.includes('+0.50%'));
  assert.ok(senior180.notes.includes('Strictly not applicable to NRO, NRE'));

  // Senior citizen sub-180 days (equal rate)
  const senior7d = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('7 Days'));
  assert.ok(senior7d.notes.includes('identical to general public card rates'));

  // Sub-1-year regular candidate
  const subOneYear = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('7 Days'));
  assert.ok(subOneYear.notes.includes('Sub-one-year tenures are not eligible for NRE'));
});

// 8. Fail-closed on missing effective date
run('fails closed when effective date is missing from Table 0 header', () => {
  const broken = FIXTURE.replace(/w\.e\.f\.\s*17\.03\.2026/i, '');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
});

// 9. Fail-closed on row count mismatch
run('fails closed when callable retail row count is corrupted', () => {
  const corrupted = FIXTURE.replace('<tr><td>444 Days ##</td><td>6.50</td><td>6.66</td><td>7.00</td><td>7.19</td><td>6.60</td><td>6.77</td><td>7.10</td><td>7.29</td></tr>', '');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('row count mismatch')));
});

// 10. Fail-closed on corrupted rate cell
run('fails closed when a rate cell is empty or corrupt', () => {
  const corrupted = FIXTURE.replace('<td>6.50</td><td>6.66</td>', '<td>INVALID</td><td>6.66</td>');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('rate') || e.includes('row count mismatch')));
});

// 11. Parser Factory integration
run('resolves CanaraRateParser via parser factory', () => {
  const p = getParserForBank('CANARA');
  assert.ok(p instanceof CanaraRateParser);
  assert.strictEqual(p.bankCode, 'CANARA');
});

// 12. Source Registry integration
run('registers canara-retail-domestic as disabled in source registry', () => {
  const src = defaultRegistry.getSource('canara-retail-domestic');
  assert.ok(src, 'Source should exist in registry');
  assert.strictEqual(src.bankCode, 'CANARA');
  assert.strictEqual(src.enabled, false, 'Source must remain disabled');
  assert.strictEqual(src.sourceType, 'HTML');
  assert.strictEqual(src.sourceUrl, SOURCE_URL);
});

// 13. Baseline comparison test with official baseline file
run('matches official baseline JSON values for all 12 tenures and 24 rates', () => {
  const baseline = require('../review/canara_official_baseline_2026-03-17.json');
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  assert.strictEqual(res.effectiveFrom, baseline.effectiveFrom);
  assert.strictEqual(res.metadata.validRows, baseline.tenures.length);

  const actualMap = new Map();
  for (const c of res.candidates) {
    const k = normalizeTenureLabel(c.tenureLabel).toLowerCase();
    if (!actualMap.has(k)) actualMap.set(k, {});
    actualMap.get(k)[c.customerType] = c.interestRate;
  }

  for (const row of baseline.tenures) {
    const k = normalizeTenureLabel(row.label).toLowerCase();
    const actual = actualMap.get(k);
    assert.ok(actual, `Missing tenure in actual: ${row.label}`);
    assert.strictEqual(actual.REGULAR, row.regular, `Regular rate mismatch for ${row.label}`);
    assert.strictEqual(actual.SENIOR_CITIZEN, row.senior, `Senior rate mismatch for ${row.label}`);
  }
});

// 14. Fail-closed: live-fetch failure exits non-zero without snapshot fallback
await run('live-fetch failure fails closed and exits non-zero without snapshot fallback', async () => {
  const res = await runVerification({
    mockFetchFailure: 'Connection timed out (ETIMEDOUT)',
    mockHttpStatus: null,
  });
  assert.strictEqual(res.success, false);
  assert.strictEqual(res.exitCode, 1);
  assert.strictEqual(res.report.sourceFetchStatus, 'FAILED');
  assert.strictEqual(res.report.parityStatus, 'FAIL_CLOSED');
  assert.strictEqual(res.report.httpStatus, null);
  assert.strictEqual(res.report.fetchMethod, 'NONE');
  assert.ok(res.report.mismatches.some(m => m.includes('Live official source fetch failed')));
});

// 15. Fallback rejection: offline fixture cannot produce live PASS
await run('fallback rejection: offline fixture cannot produce live-source PASS', async () => {
  const res = await runVerification({ offline: true, body: Buffer.from(FIXTURE) });
  assert.strictEqual(res.report.isLiveRun, false);
  assert.strictEqual(res.report.sourceFetchStatus, 'OFFLINE_LOADED');
  assert.strictEqual(res.report.fetchMethod, 'OFFLINE_FIXTURE');
  assert.strictEqual(res.report.httpStatus, null, 'Must not fabricate HTTP 200 for local file');
  assert.notStrictEqual(res.report.parityStatus, 'PASS', 'Offline fixture must never produce live PASS');
  assert.strictEqual(res.report.parityStatus, 'OFFLINE_BASELINE_PASS');
  assert.strictEqual(res.report.activationApproved, false);
  assert.strictEqual(res.report.matchedTenureRows, 12);
});

const passed = tests.filter(Boolean).length;
console.log(`\nCanara Bank suite completed: ${passed}/${tests.length} tests passed.`);
if (passed !== tests.length) {
  process.exit(1);
}
})();
