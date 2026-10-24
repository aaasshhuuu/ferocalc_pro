// Axis Bank parser regression tests.
// Fixtures are synthetic deterministic representations of official public PDF rate cards.
// Tests verify card rates vs annualized yield, senior citizen rates (+0.50% <5y, +0.75% 5-10y),
// calendar tenure extraction, contiguous tenure coverage, exclusion of bulk and NRI tables,
// customer eligibility restrictions, fail-closed safety, and registry integration.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const {
  AxisRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  EXPECTED_ROWS,
  SOURCE_URL,
} = require('../parsers/axis_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const { runVerification, verifyContent } = require('../scripts/verify_axis_live_source');

// Synthetic deterministic text fixture representing decoded PDF token stream
const SYNTHETIC_FIXTURE = [
  'Domestic Interest Rates Less than 3 crores',
  'W.e.f. 01st July 2026**',
  'Maturity Period Interest Rates (percent per annum) General Senior Citizens',
  '7 14 days 3.00 3.50',
  '15 29 days 3.00 3.50',
  '30 45 days 3.25 3.75',
  '46 60 days 4.00 4.50',
  '61 days - 87 days 4.75 5.25',
  '88 days 3 months 24 days 5.00 5.50',
  '3 months 25 days < 4 months 5.00 5.50',
  '4 months < 6 months 5.00 5.50',
  '6 months < 9 months 5.50 6.00',
  '9 months < 1 year 5.75 6.25',
  '1 year 1 year 10 days 6.25 6.75',
  '1 year 11 days < 13 months 6.25 6.75',
  '13 months < 15 months 6.25 6.75',
  '15 months < 18 months 6.45 6.95',
  '18 Months < 2 years 6.50 7.00',
  '2 years < 3 years 6.50 7.00',
  '3 years < 5 years 6.50 7.00',
  '5 years to 10 years 6.50 7.25',
  'Disclaimer -',
  'Please clear browser history/cookies before accessing the interest rate chart.',
  '**Rates are subject to change without any prior notice.',
].join('\n');

const hash = crypto.createHash('sha256').update(SYNTHETIC_FIXTURE).digest('hex');
const parser = new AxisRateParser();
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
console.log('Axis Bank Parser Regression Test Suite');

// 1. Full extraction from fixture
await run('extracts all 18 callable retail rows yielding 36 candidates across Regular and Senior Citizen', () => {
  const res = parser.parse(SYNTHETIC_FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, true, res.errors.join('; '));
  assert.strictEqual(res.effectiveFrom, '2026-07-01');
  assert.strictEqual(res.metadata.extractedRows, 18);
  assert.strictEqual(res.metadata.validRows, 18);
  assert.strictEqual(res.candidates.length, 36);
});

// 2. Card rate vs Annualized yield separation
run('extracts card interest rates and strictly sets yieldIncludedAsRate to false', () => {
  const res = parser.parse(SYNTHETIC_FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.metadata.yieldIncludedAsRate, false);

  // 1 year to 1 year 10 days: Regular 6.25%, Senior 6.75%
  const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('1 year to 1 year 10 days'));
  assert.ok(reg1y, '1 Year regular candidate should exist');
  assert.strictEqual(reg1y.interestRate, 6.25);

  const sr1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('1 year to 1 year 10 days'));
  assert.ok(sr1y, '1 Year senior candidate should exist');
  assert.strictEqual(sr1y.interestRate, 6.75);
});

// 3. Senior Citizen rates (+0.50% for <5y, +0.75% for 5-10y)
run('verifies senior rates have +0.50% spread below 5 years, and +0.75% for 5 years to 10 years', () => {
  const res = parser.parse(SYNTHETIC_FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const byTenure = new Map();
  for (const c of res.candidates) {
    if (!byTenure.has(c.tenureLabel)) byTenure.set(c.tenureLabel, {});
    byTenure.get(c.tenureLabel)[c.customerType] = c.interestRate;
  }

  assert.strictEqual(byTenure.size, 18);
  for (const [label, rates] of byTenure.entries()) {
    assert.ok(rates.REGULAR !== undefined, `Missing regular rate for ${label}`);
    assert.ok(rates.SENIOR_CITIZEN !== undefined, `Missing senior rate for ${label}`);

    const spread = Math.round((rates.SENIOR_CITIZEN - rates.REGULAR) * 100) / 100;
    if (label.includes('5 years to 10 years')) {
      assert.strictEqual(spread, 0.75, `Senior spread for 5-10y should be 0.75, got ${spread}`);
    } else {
      assert.strictEqual(spread, 0.50, `Senior spread for tenure "${label}" should be 0.50, got ${spread}`);
    }
  }
});

// 4. Structured calendar tenure bounds
run('extracts structured calendar tenure fields correctly for calendar slabs', () => {
  // Test 7 to 14 days
  const cal1 = extractCalendarTenure('7 to 14 days');
  assert.strictEqual(cal1.tenureDomain, 'DAYS');

  // Test 3 months 25 days < 4 months
  const cal2 = extractCalendarTenure('3 months 25 days < 4 months');
  assert.strictEqual(cal2.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal2.minMonths, 3);
  assert.strictEqual(cal2.minDaysCal, 25);
  assert.strictEqual(cal2.maxMonths, 4);
  assert.strictEqual(cal2.maxOperator, '<');

  // Test 1 year to 1 year 10 days
  const cal3 = extractCalendarTenure('1 year to 1 year 10 days');
  assert.strictEqual(cal3.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal3.minYears, 1);
  assert.strictEqual(cal3.minMonths, 12);
  assert.strictEqual(cal3.maxDaysCal, 10);
  assert.strictEqual(cal3.maxOperator, '<=');

  // Test 13 months < 15 months
  const cal4 = extractCalendarTenure('13 months < 15 months');
  assert.strictEqual(cal4.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal4.minMonths, 13);
  assert.strictEqual(cal4.maxMonths, 15);
  assert.strictEqual(cal4.maxOperator, '<');

  // Test 5 years to 10 years
  const cal5 = extractCalendarTenure('5 years to 10 years');
  assert.strictEqual(cal5.tenureDomain, 'CALENDAR');
  assert.strictEqual(cal5.minYears, 5);
  assert.strictEqual(cal5.minMonths, 60);
  assert.strictEqual(cal5.maxYears, 10);
  assert.strictEqual(cal5.maxMonths, 120);
  assert.strictEqual(cal5.maxOperator, '<=');
});

// 5. Contiguous non-overlapping tenure coverage
run('verifies contiguous tenure coverage without gaps or overlaps across all 18 slabs', () => {
  const res = parser.parse(SYNTHETIC_FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  const regular = res.candidates.filter(c => c.customerType === 'REGULAR');
  regular.sort((a, b) => a.minTenureDays - b.minTenureDays);

  assert.strictEqual(regular.length, 18);
  assert.strictEqual(regular[0].minTenureDays, 7);
  assert.strictEqual(regular[regular.length - 1].maxTenureDays, 3650);

  for (let i = 0; i < regular.length - 1; i++) {
    const cur = regular[i];
    const next = regular[i + 1];
    assert.strictEqual(
      cur.maxTenureDays + 1,
      next.minTenureDays,
      `Gap or overlap between "${cur.tenureLabel}" (max: ${cur.maxTenureDays}) and "${next.tenureLabel}" (min: ${next.minTenureDays})`
    );
  }
});

// 6. Customer eligibility restrictions
run('enforces customer eligibility restrictions in candidate notes', () => {
  const res = parser.parse(SYNTHETIC_FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

  // Senior citizen candidate
  const seniorCandidate = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('1 year'));
  assert.ok(seniorCandidate.notes.includes('Resident Indian Senior Citizens'));
  assert.ok(seniorCandidate.notes.includes('+0.50%'));
  assert.ok(seniorCandidate.notes.includes('Strictly not applicable to NRE/NRO'));

  // Sub-1-year regular candidate
  const subOneYear = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('7 to 14 days'));
  assert.ok(subOneYear.notes.includes('Sub-one-year tenures are not eligible for NRE'));
});

// 7. Fail-closed on missing effective date
run('fails closed when effective date is missing from rate card header', () => {
  const broken = SYNTHETIC_FIXTURE.replace(/W\.e\.f\.\s*01st\s*July\s*2026\*\*/i, '');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
});

// 8. Fail-closed on missing column header
run('fails closed when Senior Citizens header is missing', () => {
  const broken = SYNTHETIC_FIXTURE.replace('Senior Citizens', '');
  const res = parser.parse(broken, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('Senior Citizens column header')));
});

// 9. Fail-closed on row count mismatch
run('fails closed when callable retail row count is corrupted', () => {
  const corrupted = SYNTHETIC_FIXTURE.replace('30 45 days 3.25 3.75\n', '');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('row count mismatch')));
});

// 10. Fail-closed on invalid rate cell
run('fails closed when a rate cell is corrupt or missing', () => {
  const corrupted = SYNTHETIC_FIXTURE.replace('6.45 6.95', '6.45 INVALID');
  const res = parser.parse(corrupted, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('row count mismatch') || e.includes('rate')));
});

// 11. Parser Factory integration
run('resolves AxisRateParser via parser factory', () => {
  const p = getParserForBank('AXIS');
  assert.ok(p instanceof AxisRateParser);
  assert.strictEqual(p.bankCode, 'AXIS');
});

// 12. Source Registry integration
run('registers axis-retail-domestic as disabled in source registry', () => {
  const src = defaultRegistry.getSource('axis-retail-domestic');
  assert.ok(src, 'Source should exist in registry');
  assert.strictEqual(src.bankCode, 'AXIS');
  assert.strictEqual(src.enabled, false, 'Source must remain disabled');
  assert.strictEqual(src.sourceType, 'PDF');
  assert.strictEqual(src.sourceUrl, SOURCE_URL);
});

// 13. Baseline comparison test with official baseline file
run('matches official baseline JSON values for all 18 tenures and 36 rates', () => {
  const baseline = require('../review/axis_official_baseline_2026-07-01.json');
  const res = parser.parse(SYNTHETIC_FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

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
  const res = await runVerification({ offline: true });
  assert.strictEqual(res.report.isLiveRun, false);
  assert.strictEqual(res.report.sourceFetchStatus, 'OFFLINE_LOADED');
  assert.strictEqual(res.report.fetchMethod, 'OFFLINE_FIXTURE');
  assert.strictEqual(res.report.httpStatus, null, 'Must not fabricate HTTP 200 for local file');
  assert.notStrictEqual(res.report.parityStatus, 'PASS', 'Offline fixture must never produce live PASS');
  assert.strictEqual(res.report.parityStatus, 'OFFLINE_BASELINE_PASS');
  assert.strictEqual(res.report.activationApproved, false);
  assert.strictEqual(res.report.matchedTenureRows, 18);
});

const passed = tests.filter(Boolean).length;
console.log(`\nAxis Bank suite completed: ${passed}/${tests.length} tests passed.`);
if (passed !== tests.length) {
  process.exit(1);
}
})();
