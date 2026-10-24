// Central Bank of India parser regression tests.
// Fixtures are synthetic deterministic representations of official public pages.
// Tests verify card rates vs annualized yield, senior citizen rates (+0.50% spread),
// special schemes (CENT_333, CENT_444, CENT_555 with individual effective dates),
// calendar tenure extraction, exclusion of non-callable, bulk, green, and floating tables,
// customer eligibility restrictions, fail-closed safety, and registry integration.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const {
  CentralBankRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_STANDARD_ROWS,
  EXPECTED_SPECIAL_SCHEMES,
} = require('../parsers/central_bank_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const { runVerification, verifyContent } = require('../scripts/verify_central_bank_live_source');

const SOURCE_URL = 'https://www.centralbank.bank.in/en/interest-rates-on-deposit';

// 12 rows of Table 4 (Standard callable retail below Rs. 3 Crore w.e.f. 10.08.2026)
const STANDARD_ROWS = [
  '<tr><td>7 -14 days</td><td>3.00</td><td>3.00</td><td>3.50</td><td>3.50</td></tr>',
  '<tr><td>15 – 30 days</td><td>3.50</td><td>3.50</td><td>4.00</td><td>4.00</td></tr>',
  '<tr><td>31 - 45 days</td><td>3.50</td><td>3.50</td><td>4.00</td><td>4.00</td></tr>',
  '<tr><td>46 – 59 days</td><td>4.25</td><td>4.25</td><td>4.75</td><td>4.75</td></tr>',
  '<tr><td>60 – 90 days</td><td>4.00</td><td>4.00</td><td>4.50</td><td>4.50</td></tr>',
  '<tr><td>91 – 179 days</td><td>4.25</td><td>4.25</td><td>4.75</td><td>4.75</td></tr>',
  '<tr><td>180 – 270 days</td><td>5.50</td><td>5.61</td><td>6.00</td><td>6.14</td></tr>',
  '<tr><td>271 – 364 days</td><td>6.00</td><td>6.14</td><td>6.50</td><td>6.66</td></tr>',
  '<tr><td>1 yr to less than 2 yrs</td><td>6.10</td><td>6.24</td><td>6.60</td><td>6.77</td></tr>',
  '<tr><td>2 yr to less than 3 years</td><td>6.25</td><td>6.40</td><td>6.75</td><td>6.92</td></tr>',
  '<tr><td>3 yr to less than 5 years</td><td>6.00</td><td>6.14</td><td>6.50</td><td>6.66</td></tr>',
  '<tr><td>5 years & above upto 10 years</td><td>6.00</td><td>6.14</td><td>6.50</td><td>6.66</td></tr>',
];

const FIXTURE = [
  '<!DOCTYPE html><html><body>',
  '<h1>Interest Rates on Deposit</h1>',
  '<!-- Table 0: Bulk >= 10 Cr (Excluded) -->',
  '<table><tr><th colspan="2">Bulk Deposits above 10 Crores w.e.f. 10.08.2026</th></tr><tr><td>7-14 days</td><td>5.00</td></tr></table>',
  '<!-- Table 1: Bulk 3 Cr to 10 Cr (Excluded) -->',
  '<table><tr><th colspan="2">Deposits of Rs. 3 Cr to Rs. 10 Cr w.e.f. 10.08.2026</th></tr><tr><td>7-14 days</td><td>5.25</td></tr></table>',
  '<!-- Table 2: Summary / Other table (Excluded) -->',
  '<table>',
  '<tr><th>Callable – Period (days)</th><th>General Public</th><th>Senior Citizen</th></tr>',
  '<tr><th>Rates</th><th>Annualised yield</th><th>Rates</th><th>Annualised yield</th></tr>',
  '<tr><td>333</td><td>6.50%</td><td>6.66%</td><td>7.00%</td><td>7.19%</td></tr>',
  '<tr><td>444</td><td>6.75%</td><td>6.92%</td><td>7.25%</td><td>7.45%</td></tr>',
  '<tr><td>555</td><td>6.30%</td><td>6.45%</td><td>6.80%</td><td>6.98%</td></tr>',
  '</table>',
  '<!-- Table 3: Non-Callable Special 333 (Excluded) -->',
  '<table><tr><th colspan="4">Cent 333 Non-Callable Deposits (Above 1 Cr to < 3 Cr)</th></tr><tr><td>333</td><td>6.65</td><td>6.82</td><td>—</td></tr></table>',
  '<!-- Table 4: Callable Retail Domestic Standard (< Rs. 3 Crore) w.e.f. 10.08.2026 -->',
  '<table>',
  '<thead>',
  '<tr><th colspan="5">Rates for Deposits less than Rs. 3 Crore as of w.e.f. 10.08.2026</th></tr>',
  '<tr><th rowspan="2">Maturity Period</th><th colspan="2">Card Rate (General)</th><th colspan="2">Senior Citizen (Card Rate)</th></tr>',
  '<tr><th>Rate of Interest (%)</th><th>Annualised Yield (%)</th><th>Rate of Interest (%)</th><th>Annualised Yield (%)</th></tr>',
  '</thead>',
  '<tbody>',
  STANDARD_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<!-- Table 5: Cent 333 Callable (< Rs. 3 Crore) w.e.f. 10.06.2026 -->',
  '<table>',
  '<tr><th colspan="5">Callable</th></tr>',
  '<tr><th>Period (days)</th><th>Revised Rates w.e.f. 10.06.2026</th><th>Annualised yield</th><th>Revised Rates w.e.f. 10.06.2026</th><th>Annualised yield</th></tr>',
  '<tr><td>333</td><td>6.50%</td><td>6.66%</td><td>7.00%</td><td>7.19%</td></tr>',
  '</table>',
  '<!-- Table 6: Non-Callable Special 444 (Excluded) -->',
  '<table><tr><th colspan="4">Cent 444 Non-Callable Deposits (Above 1 Cr to < 3 Cr)</th></tr><tr><td>444</td><td>6.90</td><td>7.08</td><td>—</td></tr></table>',
  '<!-- Table 7: Cent 444 Callable (< Rs. 3 Crore) w.e.f. 10.08.2026 -->',
  '<table>',
  '<tr><th colspan="5">Callable</th></tr>',
  '<tr><th>Period (days)</th><th>Revised Rates w.e.f. 10.08.2026</th><th>Annualised yield</th><th>Revised Rates w.e.f. 10.08.2026</th><th>Annualised yield</th></tr>',
  '<tr><td>444</td><td>6.75%</td><td>6.92%</td><td>7.25%</td><td>7.45%</td></tr>',
  '</table>',
  '<!-- Table 8: Non-Callable Special 555 (Excluded) -->',
  '<table><tr><th colspan="4">Cent 555 Non-Callable Deposits (Above 1 Cr to < 3 Cr)</th></tr><tr><td>555</td><td>6.45</td><td>6.61</td><td>—</td></tr></table>',
  '<!-- Table 9: Cent 555 Callable (< Rs. 3 Crore) w.e.f. 10.12.2025 -->',
  '<table>',
  '<tr><th colspan="5">Callable</th></tr>',
  '<tr><th>Period (days)</th><th>Revised Rates w.e.f. 10.12.2025</th><th>Annualised yield</th><th>Revised Rates w.e.f. 10.12.2025</th><th>Annualised yield</th></tr>',
  '<tr><td>555</td><td>6.30%</td><td>6.45%</td><td>6.80%</td><td>6.98%</td></tr>',
  '</table>',
  '<!-- Table 10: Non-Callable Special (Excluded) -->',
  '<table><tr><th colspan="4">Cent Green Non-Callable Deposits</th></tr><tr><td>1111</td><td>6.15</td><td>6.29</td><td>—</td></tr></table>',
  '<!-- Table 11: Cent Green Deposit (Excluded) -->',
  '<table><tr><th colspan="2">Cent Green Deposit w.e.f. 10.08.2026</th></tr><tr><td>1111 days</td><td>6.00</td></tr><tr><td>2222 days</td><td>6.00</td></tr><tr><td>3333 days</td><td>6.00</td></tr></table>',
  '<!-- Table 12: Cent Floating Deposit (Excluded) -->',
  '<table><tr><th colspan="2">Cent Floating Deposit Scheme</th></tr><tr><td>1 year</td><td>Repo - 0.25%</td></tr></table>',
  '<!-- Table 13: Savings Deposits (Excluded) -->',
  '<table><tr><th colspan="2">Savings Deposits Interest Rates</th></tr><tr><td>Up to 1 Lakh</td><td>2.75</td></tr></table>',
  '<div>',
  '<p>Additional 0.50% interest is offered to Senior Citizens across domestic term deposits of less than Rs. 3 Crore.</p>',
  '<p>Super Senior Citizens (80 years and above) receive an additional 0.75% interest per policy notice.</p>',
  '<p>Senior Citizen rates are strictly not applicable to NRE or NRO deposits.</p>',
  '<p>NRE fixed deposits require a minimum tenure of 1 year. Sub-one-year slabs are not eligible for NRE deposits.</p>',
  '</div>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const parser = new CentralBankRateParser();
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
console.log('Central Bank of India Parser Regression Test Suite');

// 1. Full extraction from fixture
await run('extracts 12 standard rows and 3 special schemes yielding 30 candidates across Regular and Senior Citizen', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, true, res.errors.join('; '));
  assert.strictEqual(res.effectiveFrom, '2026-08-10');
  assert.strictEqual(res.rawTableCount, 14);
  assert.strictEqual(res.metadata.extractedRows, 15);
  assert.strictEqual(res.metadata.validStandardRows, 12);
  assert.strictEqual(res.metadata.validSpecialSchemes, 3);
  assert.strictEqual(res.candidates.length, 30);
  assert.strictEqual(res.metadata.excludedTableCount, 10);
});

// 2. Card rate vs Annualized yield separation
run('extracts card interest rates from Col 1 & 3 and strictly ignores annualized yield columns', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.yieldIncludedAsRate, false);

  // 1 yr to less than 2 yrs: Regular Card 6.10% (Yield 6.24%), Senior Card 6.60% (Yield 6.77%)
  const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('1 yr to less than 2 yrs'));
  assert.ok(reg1y, '1 Year regular candidate should exist');
  assert.strictEqual(reg1y.interestRate, 6.10);
  assert.notStrictEqual(reg1y.interestRate, 6.24);

  const sr1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('1 yr to less than 2 yrs'));
  assert.ok(sr1y, '1 Year senior candidate should exist');
  assert.strictEqual(sr1y.interestRate, 6.60);
  assert.notStrictEqual(sr1y.interestRate, 6.77);

  // 180 – 270 days: Regular Card 5.50% (Yield 5.61%), Senior Card 6.00% (Yield 6.14%)
  const reg180 = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('180 – 270 days'));
  assert.strictEqual(reg180.interestRate, 5.50);
  assert.notStrictEqual(reg180.interestRate, 5.61);

  const sr180 = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('180 – 270 days'));
  assert.strictEqual(sr180.interestRate, 6.00);
  assert.notStrictEqual(sr180.interestRate, 6.14);
});

// 3. Senior Citizen rates (+0.50% spread across all callable slabs)
run('verifies senior rates have exactly +0.50% spread across all callable slabs', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const byTenure = new Map();
  for (const c of res.candidates) {
    if (!byTenure.has(c.tenureLabel)) byTenure.set(c.tenureLabel, {});
    byTenure.get(c.tenureLabel)[c.customerType] = c.interestRate;
  }

  assert.strictEqual(byTenure.size, 15);
  for (const [label, rates] of byTenure.entries()) {
    assert.ok(rates.REGULAR !== undefined, `Missing regular rate for ${label}`);
    assert.ok(rates.SENIOR_CITIZEN !== undefined, `Missing senior rate for ${label}`);

    const spread = Math.round((rates.SENIOR_CITIZEN - rates.REGULAR) * 100) / 100;
    assert.strictEqual(spread, 0.50, `Senior spread for tenure "${label}" should be 0.50, got ${spread}`);
  }
});

// 4. Special Schemes CENT_333, CENT_444, and CENT_555 with individual effective dates
run('correctly tags Cent 333, 444, and 555 special schemes with their respective effective dates', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // Cent 333 (w.e.f. 2026-06-10)
  const c333Reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'CENT_333');
  assert.ok(c333Reg, 'Cent 333 regular candidate should exist');
  assert.strictEqual(c333Reg.interestRate, 6.50);
  assert.strictEqual(c333Reg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c333Reg.minTenureDays, 333);
  assert.strictEqual(c333Reg.maxTenureDays, 333);
  assert.strictEqual(c333Reg.effectiveFrom, '2026-06-10');

  const c333Sr = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.schemeName === 'CENT_333');
  assert.ok(c333Sr, 'Cent 333 senior candidate should exist');
  assert.strictEqual(c333Sr.interestRate, 7.00);
  assert.strictEqual(c333Sr.effectiveFrom, '2026-06-10');

  // Cent 444 (w.e.f. 2026-08-10)
  const c444Reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'CENT_444');
  assert.ok(c444Reg, 'Cent 444 regular candidate should exist');
  assert.strictEqual(c444Reg.interestRate, 6.75);
  assert.strictEqual(c444Reg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c444Reg.minTenureDays, 444);
  assert.strictEqual(c444Reg.maxTenureDays, 444);
  assert.strictEqual(c444Reg.effectiveFrom, '2026-08-10');

  const c444Sr = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.schemeName === 'CENT_444');
  assert.ok(c444Sr, 'Cent 444 senior candidate should exist');
  assert.strictEqual(c444Sr.interestRate, 7.25);
  assert.strictEqual(c444Sr.effectiveFrom, '2026-08-10');

  // Cent 555 (w.e.f. 2025-12-10)
  const c555Reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'CENT_555');
  assert.ok(c555Reg, 'Cent 555 regular candidate should exist');
  assert.strictEqual(c555Reg.interestRate, 6.30);
  assert.strictEqual(c555Reg.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(c555Reg.minTenureDays, 555);
  assert.strictEqual(c555Reg.maxTenureDays, 555);
  assert.strictEqual(c555Reg.effectiveFrom, '2025-12-10');

  const c555Sr = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.schemeName === 'CENT_555');
  assert.ok(c555Sr, 'Cent 555 senior candidate should exist');
  assert.strictEqual(c555Sr.interestRate, 6.80);
  assert.strictEqual(c555Sr.effectiveFrom, '2025-12-10');
});

// 5. Excluded tables and non-callable isolation
run('strictly isolates and excludes non-callable, bulk, green, and floating deposit tables', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.nonCallableRatesIncluded, false);
  assert.strictEqual(res.metadata.bulkTablesExcluded, true);
  assert.strictEqual(res.metadata.greenDepositsExcluded, true);
  assert.strictEqual(res.metadata.floatingDepositsExcluded, true);
  assert.strictEqual(res.metadata.excludedTableCount, 10);

  // Non-callable distinct rates (6.65% for non-callable 333, 6.90% for non-callable 444, 6.45% for non-callable 555) must not exist
  assert.strictEqual(res.candidates.find(c => c.interestRate === 6.65), undefined);
  assert.strictEqual(res.candidates.find(c => c.interestRate === 6.90), undefined);
  assert.strictEqual(res.candidates.find(c => c.interestRate === 6.45), undefined);

  // Bulk rate (5.25% for 7-14d bulk) must not exist
  assert.strictEqual(res.candidates.find(c => c.interestRate === 5.25), undefined);
});

// 6. Structured calendar tenure bounds
run('extracts structured calendar tenure fields correctly for standard slabs', () => {
  // Test 7 -14 days
  const cal1 = extractCalendarTenure('7 -14 days');
  assert.strictEqual(cal1.tenureDomain, 'DAYS');

  // Test 1 yr to less than 2 yrs
  const cal2 = extractCalendarTenure('1 yr to less than 2 yrs');
  assert.strictEqual(cal2.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal2.minYears, 1);
  assert.strictEqual(cal2.minMonths, 12);
  assert.strictEqual(cal2.maxYears, 2);
  assert.strictEqual(cal2.maxMonths, 24);
  assert.strictEqual(cal2.maxOperator, '<');

  // Test 2 yr to less than 3 years
  const cal3 = extractCalendarTenure('2 yr to less than 3 years');
  assert.strictEqual(cal3.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal3.minYears, 2);
  assert.strictEqual(cal3.minMonths, 24);
  assert.strictEqual(cal3.maxYears, 3);
  assert.strictEqual(cal3.maxMonths, 36);
  assert.strictEqual(cal3.maxOperator, '<');

  // Test 3 yr to less than 5 years
  const cal4 = extractCalendarTenure('3 yr to less than 5 years');
  assert.strictEqual(cal4.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal4.minYears, 3);
  assert.strictEqual(cal4.minMonths, 36);
  assert.strictEqual(cal4.maxYears, 5);
  assert.strictEqual(cal4.maxMonths, 60);
  assert.strictEqual(cal4.maxOperator, '<');

  // Test 5 years & above upto 10 years
  const cal5 = extractCalendarTenure('5 years & above upto 10 years');
  assert.strictEqual(cal5.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal5.minYears, 5);
  assert.strictEqual(cal5.minMonths, 60);
  assert.strictEqual(cal5.maxYears, 10);
  assert.strictEqual(cal5.maxMonths, 120);
  assert.strictEqual(cal5.maxOperator, '<=');
});

// 7. Customer eligibility restrictions
run('enforces customer eligibility restrictions in candidate notes', () => {
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // Senior citizen candidate
  const seniorStandard = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('1 yr'));
  assert.ok(seniorStandard.notes.includes('Resident Indian Senior Citizens'));
  assert.ok(seniorStandard.notes.includes('+0.50%'));
  assert.ok(seniorStandard.notes.includes('Strictly not applicable to NRE/NRO'));

  // Sub-1-year regular candidate
  const subOneYear = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('7 -14'));
  assert.ok(subOneYear.notes.includes('Sub-one-year tenures are not eligible for NRE'));
});

// 8. Fail-closed on missing standard effective date
run('fails closed when effective date is missing from Table 4 header', () => {
  const broken = FIXTURE.replace('Rates for Deposits less than Rs. 3 Crore as of w.e.f. 10.08.2026', 'Rates for Deposits less than Rs. 3 Crore as of');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
});

// 9. Fail-closed on missing special scheme table
run('fails closed when a special scheme table is missing', () => {
  const broken = FIXTURE.replace(/<!-- Table 7: Cent 444 Callable[\s\S]*?<\/table>/i, '');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('callable 444-day special scheme table')));
});

// 10. Fail-closed on row count mismatch
run('fails closed when standard callable retail row count is corrupted', () => {
  const corrupted = FIXTURE.replace('<tr><td>15 – 30 days</td><td>3.50</td><td>3.50</td><td>4.00</td><td>4.00</td></tr>', '');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('row count mismatch')));
});

// 11. Fail-closed on corrupted rate cell
run('fails closed when a rate cell is invalid', () => {
  const corrupted = FIXTURE.replace('<td>6.10</td><td>6.24</td>', '<td>INVALID</td><td>6.24</td>');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('rate')));
});

// 12. Parser Factory integration
run('resolves CentralBankRateParser via parser factory', () => {
  const p = getParserForBank('CENTRAL_BANK');
  assert.ok(p instanceof CentralBankRateParser);
  assert.strictEqual(p.bankCode, 'CENTRAL_BANK');
});

// 13. Source Registry integration
run('registers central-bank-retail-domestic as disabled in source registry', () => {
  const src = defaultRegistry.getSource('central-bank-retail-domestic');
  assert.ok(src, 'Source should exist in registry');
  assert.strictEqual(src.bankCode, 'CENTRAL_BANK');
  assert.strictEqual(src.enabled, false, 'Source must remain disabled');
  assert.strictEqual(src.sourceType, 'HTML');
  assert.strictEqual(src.sourceUrl, SOURCE_URL);
});

// 14. Baseline comparison test with official baseline file
run('matches official baseline JSON values for all 15 tenures and 30 rates', () => {
  const baseline = require('../review/central_bank_official_baseline_2026-08-10.json');
  const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  assert.strictEqual(res.effectiveFrom, baseline.effectiveFrom);
  assert.strictEqual(res.metadata.extractedRows, baseline.tenures.length);

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

// 15. Fail-closed: live-fetch failure exits non-zero without snapshot fallback
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

// 16. Fallback rejection: offline fixture cannot produce live PASS
await run('fallback rejection: offline fixture cannot produce live-source PASS', async () => {
  const res = await runVerification({ offline: true, body: Buffer.from(FIXTURE) });
  assert.strictEqual(res.report.isLiveRun, false);
  assert.strictEqual(res.report.sourceFetchStatus, 'OFFLINE_LOADED');
  assert.strictEqual(res.report.fetchMethod, 'OFFLINE_FIXTURE');
  assert.strictEqual(res.report.httpStatus, null, 'Must not fabricate HTTP 200 for local file');
  assert.notStrictEqual(res.report.parityStatus, 'PASS', 'Offline fixture must never produce live PASS');
  assert.strictEqual(res.report.parityStatus, 'OFFLINE_BASELINE_PASS');
  assert.strictEqual(res.report.activationApproved, false);
  assert.strictEqual(res.report.matchedTenureRows, 15);
});

const passed = tests.filter(Boolean).length;
console.log(`\nCentral Bank of India suite completed: ${passed}/${tests.length} tests passed.`);
if (passed !== tests.length) {
  process.exit(1);
}
})();
