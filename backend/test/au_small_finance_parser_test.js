// AU Small Finance Bank parser regression tests.
// Fixtures are synthetic deterministic representations of official public pages.
// Tests verify card rates vs annualized yield, senior citizen rates, calendar tenure extraction,
// isolation of non-callable and monthly-payout tables, customer eligibility restrictions,
// fail-closed safety, parser factory registration, and source registry status.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const {
  AuSmallFinanceRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_ROWS,
} = require('../parsers/au_small_finance_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const { runVerification, verifyContent } = require('../scripts/verify_au_small_finance_live_source');

const SOURCE_URL = 'https://www.au.bank.in/interest-rates/fixed-deposit-interest-rates';

const REGULAR_ROWS = [
  '<tr><td>7 Days to 1 Month 15 Days</td><td>3.50%</td><td>-</td></tr>',
  '<tr><td>1 Month 16 Days to 3 Months</td><td>4.75%</td><td>-</td></tr>',
  '<tr><td>3 Month 1 Day to 6 Months</td><td>5.25%</td><td>5.35%</td></tr>',
  '<tr><td>6 Months 1 Day to 12 Months</td><td>6.35%</td><td>6.50%</td></tr>',
  '<tr><td>12 Months 1 Day to 15 Months</td><td>7.10%</td><td>7.29%</td></tr>',
  '<tr><td>15 Months 1 Day to 18 Months</td><td>7.00%</td><td>7.19%</td></tr>',
  '<tr><td>18 months 1 days to 24 months</td><td>7.00%</td><td>7.19%</td></tr>',
  '<tr><td>24 Months 1 Day to 30 Months</td><td>7.10%</td><td>7.29%</td></tr>',
  '<tr><td>30 Months 1 Day to 36 Months</td><td>7.40%</td><td>7.61%</td></tr>',
  '<tr><td>36 Months 1 Day to 45 Months</td><td>7.00%</td><td>7.19%</td></tr>',
  '<tr><td>45 Months 1 Day to less than 60 Months</td><td>6.75%</td><td>6.92%</td></tr>',
  '<tr><td>60 Months to 120 Months</td><td>6.75%</td><td>6.92%</td></tr>',
];

const SENIOR_ROWS = [
  '<tr><td>7 Days to 1 Month 15 Days</td><td>4.00%</td><td>-</td></tr>',
  '<tr><td>1 Month 16 Days to 3 Months</td><td>5.25%</td><td>-</td></tr>',
  '<tr><td>3 Month 1 Day to 6 Months</td><td>5.75%</td><td>5.88%</td></tr>',
  '<tr><td>6 Months 1 Day to 12 Months</td><td>6.85%</td><td>7.03%</td></tr>',
  '<tr><td>12 Months 1 Day to 15 Months</td><td>7.60%</td><td>7.82%</td></tr>',
  '<tr><td>15 Months 1 Day to 18 Months</td><td>7.50%</td><td>7.71%</td></tr>',
  '<tr><td>18 months 1 days to 24 months</td><td>7.50%</td><td>7.71%</td></tr>',
  '<tr><td>24 Months 1 Day to 30 Months</td><td>7.60%</td><td>7.82%</td></tr>',
  '<tr><td>30 Months 1 Day to 36 Months</td><td>7.90%</td><td>8.14%</td></tr>',
  '<tr><td>36 Months 1 Day to 45 Months</td><td>7.50%</td><td>7.71%</td></tr>',
  '<tr><td>45 Months 1 Day to less than 60 Months</td><td>7.25%</td><td>7.45%</td></tr>',
  '<tr><td>60 Months to 120 Months</td><td>7.25%</td><td>7.45%</td></tr>',
];

const NON_CALLABLE_ROWS = [
  '<tr><td>12 Months 1 Day to 15 Months</td><td>7.35%</td><td>7.55%</td></tr>',
  '<tr><td>15 Months 1 Day to 18 Months</td><td>7.25%</td><td>7.45%</td></tr>',
  '<tr><td>18 months 1 days to 24 months</td><td>7.25%</td><td>7.45%</td></tr>',
  '<tr><td>24 Months 1 Day to 30 Months</td><td>7.35%</td><td>7.55%</td></tr>',
  '<tr><td>30 Months 1 Day to 36 Months</td><td>7.65%</td><td>7.87%</td></tr>',
];

const MONTHLY_PAYOUT_ROWS = [
  '<tr><td>7 Days to 1 Month 15 Days</td><td>3.50%</td></tr>',
  '<tr><td>1 Month 16 Days to 3 Months</td><td>4.73%</td></tr>',
  '<tr><td>3 Month 1 Day to 6 Months</td><td>5.23%</td></tr>',
  '<tr><td>6 Months 1 Day to 12 Months</td><td>6.32%</td></tr>',
  '<tr><td>12 Months 1 Day to 15 Months</td><td>7.06%</td></tr>',
  '<tr><td>15 Months 1 Day to 18 Months</td><td>6.96%</td></tr>',
  '<tr><td>18 months 1 days to 24 months</td><td>6.96%</td></tr>',
  '<tr><td>24 Months 1 Day to 30 Months</td><td>7.06%</td></tr>',
  '<tr><td>30 Months 1 Day to 36 Months</td><td>7.35%</td></tr>',
  '<tr><td>36 Months 1 Day to 45 Months</td><td>6.96%</td></tr>',
  '<tr><td>45 Months 1 Day to less than 60 Months</td><td>6.71%</td></tr>',
  '<tr><td>60 Months to 120 Months</td><td>6.71%</td></tr>',
];

const FIXTURE = [
  '<!DOCTYPE html><html><body>',
  '<h1>Fixed Deposit Interest Rates</h1>',
  '<p>Domestic, NRE and NRO Fixed Deposit - Interest Rates for amounts less than INR 3 Crore w.e.f. 1<sup>st</sup> September, 2026</p>',
  '<table>',
  '<thead><tr><th>Maturity Period</th><th>Interest Rates (per annum)</th><th>Annualized Yield</th></tr></thead>',
  '<tbody>',
  REGULAR_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<p>Interest Rates on Domestic, NRE and NRO Non-callable rates for amounts INR 1 Crore to less than INR 3 Crore w.e.f. 10<sup>th</sup> June, 2026</p>',
  '<table>',
  '<thead><tr><th>Maturity Period</th><th>Interest Rates (per annum)</th><th>Annualised Rate</th></tr></thead>',
  '<tbody>',
  NON_CALLABLE_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<p>Senior Citizen Fixed Deposit - Interest Rates for amounts less than INR 3 Crore w.e.f. 10<sup>th</sup> June, 2026</p>',
  '<table>',
  '<thead><tr><th>Maturity Period</th><th>Interest Rates (per annum)</th><th>Annualized Yield</th></tr></thead>',
  '<tbody>',
  SENIOR_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<p>Monthly Payout Fixed Deposits for amounts less than INR 3 Crore w.e.f. 1<sup>st</sup> September, 2026</p>',
  '<table>',
  '<thead><tr><th>Maturity Period</th><th>Monthly Payout Rate (per annum)</th></tr></thead>',
  '<tbody>',
  MONTHLY_PAYOUT_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<div>',
  '<p>Senior Citizen rates are applicable only to Resident Indian Senior Citizens (aged 60 years and above) who maintain a banking relationship with AU Small Finance Bank.</p>',
  '<p>Senior Citizen rates are not applicable to NRE or NRO deposits.</p>',
  '<p>NRE fixed deposits require a minimum tenure of 12 months 1 day. Sub-one-year slabs are not eligible for NRE deposits.</p>',
  '</div>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const parser = new AuSmallFinanceRateParser();
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
console.log('AU Small Finance Bank Parser Regression Test Suite');

// 1. Full extraction from fixture
await run('extracts all 12 callable retail rows yielding 24 candidates across Regular and Senior Citizen', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, true, res.errors.join('; '));
  assert.strictEqual(res.effectiveFrom, '2026-09-01');
  assert.strictEqual(res.rawTableCount, 4);
  assert.strictEqual(res.metadata.extractedRows, 12);
  assert.strictEqual(res.metadata.validRows, 12);
  assert.strictEqual(res.candidates.length, 24);
  assert.strictEqual(res.metadata.excludedTableCount, 2);
});

// 2. Card rate vs Annualized yield separation
run('extracts card interest rates and strictly ignores annualized yield column', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.yieldIncludedAsRate, false);

  // 30 Months 1 Day to 36 Months: Regular Card Rate 7.40%, Yield 7.61%
  const reg30m = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('30 Months 1 Day'));
  assert.ok(reg30m, '30 Months regular candidate should exist');
  assert.strictEqual(reg30m.interestRate, 7.4);
  assert.notStrictEqual(reg30m.interestRate, 7.61);

  // Senior Card Rate 7.90%, Yield 8.14%
  const sr30m = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('30 Months 1 Day'));
  assert.ok(sr30m, '30 Months senior candidate should exist');
  assert.strictEqual(sr30m.interestRate, 7.9);
  assert.notStrictEqual(sr30m.interestRate, 8.14);

  // 12 Months 1 Day to 15 Months: Regular 7.10% (Yield 7.29%), Senior 7.60% (Yield 7.82%)
  const reg12m = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('12 Months 1 Day'));
  assert.strictEqual(reg12m.interestRate, 7.1);
  const sr12m = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('12 Months 1 Day'));
  assert.strictEqual(sr12m.interestRate, 7.6);
});

// 3. Senior Citizen rates and spread verification
run('verifies senior rates are exactly +0.50% above regular rates across all 12 rows', () => {
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
    const spread = Math.round((rates.SENIOR_CITIZEN - rates.REGULAR) * 100) / 100;
    assert.strictEqual(spread, 0.50, `Senior spread for ${label} should be 0.50, got ${spread}`);
  }
});

// 4. Scoped table effective dates
run('properly scopes effective dates for Regular (2026-09-01) and Senior (2026-06-10) tables', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const regularCandidates = res.candidates.filter(c => c.customerType === 'REGULAR');
  const seniorCandidates = res.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');

  for (const c of regularCandidates) {
    assert.strictEqual(c.effectiveFrom, '2026-09-01');
  }
  for (const c of seniorCandidates) {
    assert.strictEqual(c.effectiveFrom, '2026-06-10');
  }

  assert.strictEqual(res.metadata.effectiveDatesByTable.regularCallable, '2026-09-01');
  assert.strictEqual(res.metadata.effectiveDatesByTable.seniorCitizenCallable, '2026-06-10');
  assert.strictEqual(res.metadata.effectiveDatesByTable.nonCallableRetail, '2026-06-10');
  assert.strictEqual(res.metadata.effectiveDatesByTable.monthlyPayoutRetail, '2026-09-01');
});

// 5. Excluded tables isolation
run('strictly isolates and excludes non-callable and monthly-payout tables', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.nonCallableRatesIncluded, false);
  assert.strictEqual(res.metadata.monthlyPayoutRatesIncluded, false);
  assert.strictEqual(res.metadata.excludedTableCount, 2);

  // Non-callable rates (e.g. 7.35%, 7.65%) must not exist as callable regular rates
  const nonCallableRate = res.candidates.find(c => c.interestRate === 7.65);
  assert.strictEqual(nonCallableRate, undefined, 'Non-callable rate 7.65% should not exist');

  // Monthly payout rates (e.g. 4.73%, 6.32%) must not exist
  const monthlyRate = res.candidates.find(c => c.interestRate === 4.73);
  assert.strictEqual(monthlyRate, undefined, 'Monthly payout rate 4.73% should not exist');
});

// 6. Structured calendar tenure bounds
run('extracts structured calendar tenure fields correctly for various tenure formats', () => {
  // Test 7 Days to 1 Month 15 Days
  const cal1 = extractCalendarTenure('7 Days to 1 Month 15 Days');
  assert.strictEqual(cal1.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal1.minDaysCal, 7);
  assert.strictEqual(cal1.maxMonths, 1);
  assert.strictEqual(cal1.maxDaysCal, 15);

  // Test 1 Month 16 Days to 3 Months
  const cal2 = extractCalendarTenure('1 Month 16 Days to 3 Months');
  assert.strictEqual(cal2.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal2.minMonths, 1);
  assert.strictEqual(cal2.minDaysCal, 16);
  assert.strictEqual(cal2.maxMonths, 3);
  assert.strictEqual(cal2.maxDaysCal, 0);

  // Test 12 Months 1 Day to 15 Months
  const cal3 = extractCalendarTenure('12 Months 1 Day to 15 Months');
  assert.strictEqual(cal3.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal3.minMonths, 12);
  assert.strictEqual(cal3.minDaysCal, 1);
  assert.strictEqual(cal3.maxMonths, 15);
  assert.strictEqual(cal3.maxOperator, '<=');

  // Test 45 Months 1 Day to less than 60 Months
  const cal4 = extractCalendarTenure('45 Months 1 Day to less than 60 Months');
  assert.strictEqual(cal4.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal4.minMonths, 45);
  assert.strictEqual(cal4.minDaysCal, 1);
  assert.strictEqual(cal4.maxMonths, 60);
  assert.strictEqual(cal4.maxOperator, '<');

  // Test 60 Months to 120 Months
  const cal5 = extractCalendarTenure('60 Months to 120 Months');
  assert.strictEqual(cal5.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal5.minMonths, 60);
  assert.strictEqual(cal5.minDaysCal, 0);
  assert.strictEqual(cal5.maxMonths, 120);
});

// 7. Customer eligibility restrictions
run('enforces customer eligibility restrictions in candidate notes', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // Senior citizen candidate
  const senior = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');
  assert.ok(senior.notes.includes('Resident Indian Senior Citizens'));
  assert.ok(senior.notes.includes('banking relationship'));
  assert.ok(senior.notes.includes('Strictly not applicable to NRE/NRO'));

  // Sub-1-year regular candidate
  const subOneYear = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('7 Days'));
  assert.ok(subOneYear.notes.includes('Sub-one-year tenures are not eligible for NRE'));

  // Multi-year regular candidate
  const multiYear = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('12 Months'));
  assert.ok(multiYear.notes.includes('Applicable to Domestic, NRE, and NRO'));
});

// 8. Fail-closed on missing regular effective date
run('fails closed when regular effective date heading is missing', () => {
  const broken = FIXTURE.replace(/w\.e\.f\.\s*1<sup>st<\/sup>\s*September,\s*2026/i, '');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
});

// 9. Fail-closed on missing senior table
run('fails closed when senior citizen table is missing', () => {
  const broken = FIXTURE.replace(/<p>Senior Citizen Fixed Deposit[\s\S]*?<\/table>/i, '');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('senior citizen')));
});

// 10. Fail-closed on row count mismatch
run('fails closed when regular table row count is corrupted', () => {
  const corrupted = FIXTURE.replace('<tr><td>15 Months 1 Day to 18 Months</td><td>7.00%</td><td>7.19%</td></tr>', '');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('row count mismatch') || e.includes('label mismatch')));
});

// 11. Parser Factory integration
run('resolves AuSmallFinanceRateParser via parser factory', () => {
  const p = getParserForBank('AU_SMALL_FINANCE');
  assert.ok(p instanceof AuSmallFinanceRateParser);
  assert.strictEqual(p.bankCode, 'AU_SMALL_FINANCE');
});

// 12. Source Registry integration
run('registers au-small-finance-retail-domestic as disabled in source registry', () => {
  const src = defaultRegistry.getSource('au-small-finance-retail-domestic');
  assert.ok(src, 'Source should exist in registry');
  assert.strictEqual(src.bankCode, 'AU_SMALL_FINANCE');
  assert.strictEqual(src.enabled, false, 'Source must remain disabled');
  assert.strictEqual(src.sourceType, 'HTML');
  assert.strictEqual(src.sourceUrl, SOURCE_URL);
});

// 13. Baseline comparison test with official baseline file
run('matches official baseline JSON values for all 12 tenures and 24 rates', () => {
  const baseline = require('../review/au_small_finance_official_baseline_2026-09-01.json');
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
console.log(`\nAU Small Finance Bank suite completed: ${passed}/${tests.length} tests passed.`);
if (passed !== tests.length) {
  process.exit(1);
}
})();
