// FeroCalc HDFC live-source verifier and parser regression tests.
// Fixtures are deterministic representations of official public pages.
// Tests verify:
// 1. All 19 published callable retail slabs (< Rs. 3 Crore) yielding 38 candidates across Regular and Senior Citizen.
// 2. Exact card interest rates and spreads (+50 bps on slabs 1-15 & 17-19; +60 bps on slab 16).
// 3. Dual-domain calendar tenure fields (DAYS for slabs 1-5; CALENDAR for slabs 6-19).
// 4. Resident senior citizen eligibility restrictions and minimum deposit ₹5,000.
// 5. Official baseline JSON matching across all 19 tenures and 38 rates.
// 6. Strict fail-closed verifier behavior on live-fetch failure, fallback rejection,
//    wrong effective date, missing row, corrupted rate, spread mismatch, and duplicates.

'use strict';

const assert = require('assert');
const path = require('path');
const fs = require('fs');
const { HdfcRateParser } = require('../parsers/hdfc_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const {
  verifyContent,
  runVerification,
} = require('../scripts/verify_hdfc_live_source');

const BASELINE_PATH = path.join(__dirname, '../review/hdfc_official_baseline_2026-08-19.json');
const baseline = JSON.parse(fs.readFileSync(BASELINE_PATH, 'utf-8'));

// Build deterministic synthetic HTML matching HDFC Table 1 structure
const TABLE_ROWS = [
  '<tr><td>7 - 14 days</td><td>2.75%</td><td>3.25%</td></tr>',
  '<tr><td>15-29 days</td><td>2.75%</td><td>3.25%</td></tr>',
  '<tr><td>30-45 days</td><td>3.25%</td><td>3.75%</td></tr>',
  '<tr><td>46-60 days</td><td>4.25%</td><td>4.75%</td></tr>',
  '<tr><td>61-89 days</td><td>4.25%</td><td>4.75%</td></tr>',
  '<tr><td>90 days <= 6 months</td><td>4.25%</td><td>4.75%</td></tr>',
  '<tr><td>6 months 1 day <=9 months</td><td>5.50%</td><td>6.00%</td></tr>',
  '<tr><td>9 months 1 day to < 1 Year</td><td>5.75%</td><td>6.25%</td></tr>',
  '<tr><td>1 Year to < 15 months</td><td>6.25%</td><td>6.75%</td></tr>',
  '<tr><td>15 months to < 18 months</td><td>6.35%</td><td>6.85%</td></tr>',
  '<tr><td>18 months to < 21 months</td><td>6.45%</td><td>6.95%</td></tr>',
  '<tr><td>21 months to 2 years</td><td>6.45%</td><td>6.95%</td></tr>',
  '<tr><td>2 Years 1 day to < 2 Year 11 Months</td><td>6.45%</td><td>6.95%</td></tr>',
  '<tr><td>2 Years 11 Months (35 months)</td><td>6.45%</td><td>6.95%</td></tr>',
  '<tr><td>2 Years 11 Months 1 day <= 3 Year</td><td>6.45%</td><td>6.95%</td></tr>',
  '<tr><td>3 Years 1 day to < 4 Years 7 Months</td><td>6.50%</td><td>7.10%</td></tr>',
  '<tr><td>4 Year 7 Months (55 months)</td><td>6.40%</td><td>6.90%</td></tr>',
  '<tr><td>4 Year 7 Months 1 day <=5 Years</td><td>6.40%</td><td>6.90%</td></tr>',
  '<tr><td>5 Years 1 day to 10 Years</td><td>6.15%</td><td>6.65%</td></tr>',
];

const FIXTURE = [
  '<!DOCTYPE html><html><body>',
  '<h1>Fixed Deposit Interest Rate</h1>',
  '<p>Applicable from 19 August 2026</p>',
  '<table>',
  '<thead>',
  '<tr><th colspan="3">Fixed Deposit Interest Rates < 3 Crore</th></tr>',
  '<tr><th>Tenure Bucket</th><th>Interest Rate (per annum)</th><th>Senior Citizen Rates (per annum)</th></tr>',
  '</thead>',
  '<tbody>',
  TABLE_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<p>* An additional premium of 0.25% (over and above the existing 0.50%) will be given to Senior Citizens who wish to book the Fixed Deposit less than 5 crores for tenure of 5 (five) years one day to 10 Years; under special drive offer Senior Citizen Care.</p>',
  '<p>Applicable to resident senior citizens only (does not apply to NRIs per HDFC policy).</p>',
  '</body></html>',
].join('\n');

const parser = new HdfcRateParser();
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

async function main() {
  console.log('HDFC Bank Live Source Verifier & Regression Test Suite');

  // 1. Parser extracts 19 slabs yielding 38 candidates
  await run('extracts all 19 callable retail rows yielding 38 candidates across Regular and Senior Citizen', () => {
    const res = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    assert.strictEqual(res.success, true, (res.errors || []).join('; '));
    assert.strictEqual(res.effectiveFrom, '2026-08-19');
    assert.strictEqual(res.candidates.length, 38);

    const regular = res.candidates.filter(c => c.customerType === 'REGULAR');
    const senior = res.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');
    assert.strictEqual(regular.length, 19);
    assert.strictEqual(senior.length, 19);
  });

  // 2. Minimum deposit ₹5,000 and max deposit < ₹3 Crore
  await run('strictly enforces minimum deposit of 5000.00 and max deposit 29999999.00', () => {
    const res = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    for (const c of res.candidates) {
      assert.strictEqual(c.minDeposit, '5000.00', `Min deposit mismatch for ${c.tenureLabel}`);
      assert.strictEqual(c.maxDeposit, '29999999.00', `Max deposit mismatch for ${c.tenureLabel}`);
    }
  });

  // 3. Spreads check: 50 bps on slabs 1-15 & 17-19; 60 bps on slab 16
  await run('verifies 50 bps senior spread on slabs 1-15 & 17-19, and 60 bps on slab 16', () => {
    const res = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    const byTenure = new Map();
    for (const c of res.candidates) {
      if (!byTenure.has(c.tenureLabel)) byTenure.set(c.tenureLabel, {});
      byTenure.get(c.tenureLabel)[c.customerType] = c.interestRate;
    }

    assert.strictEqual(byTenure.size, 19);
    for (const [label, rates] of byTenure.entries()) {
      assert.ok(rates.REGULAR !== undefined, `Missing regular rate for ${label}`);
      assert.ok(rates.SENIOR_CITIZEN !== undefined, `Missing senior rate for ${label}`);

      const spreadBps = Math.round((rates.SENIOR_CITIZEN - rates.REGULAR) * 100);
      if (label.includes('3 Years 1 day to < 4 Years 7 Months')) {
        assert.strictEqual(spreadBps, 60, `Slab 16 spread must be 60 bps, got ${spreadBps}`);
      } else {
        assert.strictEqual(spreadBps, 50, `Slab "${label}" spread must be 50 bps, got ${spreadBps}`);
      }
    }
  });

  // 4. Dual-domain calendar mapping
  await run('extracts dual-domain calendar tenure fields (DAYS for slabs 1-5; CALENDAR for slabs 6-19)', () => {
    const res = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    for (let i = 0; i < 5; i++) {
      const reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === baseline.tenures[i].label);
      assert.ok(reg, `Missing regular candidate for slab ${i + 1}`);
      assert.strictEqual(reg.tenureDomain, 'DAYS', `Slab ${i + 1} domain must be DAYS`);
    }
    for (let i = 5; i < 19; i++) {
      const reg = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === baseline.tenures[i].label);
      assert.ok(reg, `Missing regular candidate for slab ${i + 1}`);
      assert.strictEqual(reg.tenureDomain, 'CALENDAR', `Slab ${i + 1} domain must be CALENDAR`);
    }
  });

  // 5. Senior eligibility notes
  await run('enforces resident senior citizen eligibility restrictions in senior candidate notes', () => {
    const res = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    const seniors = res.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');
    for (const s of seniors) {
      assert.ok(
        s.notes.includes('Applicable to resident senior citizens only') || s.notes.includes('NRIs'),
        `Resident senior restriction note missing for ${s.tenureLabel}`
      );
    }
  });

  // 6. Baseline JSON matching
  await run('matches official baseline JSON values for all 19 tenures and 38 rates', () => {
    const res = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    const ver = verifyContent(res, baseline);
    assert.strictEqual(ver.mismatches.length, 0, ver.mismatches.join('; '));
    assert.strictEqual(ver.effectiveDateMatched, true);
    assert.strictEqual(ver.allTenuresReconciled, true);
    assert.strictEqual(ver.spreadsReconciled, true);
    assert.strictEqual(ver.eligibilityNotesVerified, true);
    assert.strictEqual(ver.matchedTenureRows, 19);
    assert.strictEqual(ver.comparedRateValues, 38);
  });

  // 7. Parser factory integration
  await run('resolves HdfcRateParser via parser factory', () => {
    const factoryParser = getParserForBank('HDFC');
    assert.ok(factoryParser, 'Factory should return parser for HDFC');
    assert.strictEqual(factoryParser.bankCode, 'HDFC');
    assert.strictEqual(factoryParser.id, 'hdfc_retail_html');
  });

  // 8. Source registry integration
  await run('registers hdfc-retail-domestic in source registry', () => {
    const src = defaultRegistry.getSource('hdfc-retail-domestic');
    assert.ok(src, 'Source hdfc-retail-domestic should be registered');
    assert.strictEqual(src.bankCode, 'HDFC');
    assert.strictEqual(src.parserId, 'hdfc_retail_html');
  });

  // 9. Fail-closed: live-fetch failure exits non-zero without snapshot fallback
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

  // 10. Fallback rejection: offline fixture cannot produce live PASS
  await run('fallback rejection: offline fixture cannot produce live-source PASS', async () => {
    const res = await runVerification({ offline: true, body: Buffer.from(FIXTURE) });
    assert.strictEqual(res.report.isLiveRun, false);
    assert.strictEqual(res.report.sourceFetchStatus, 'OFFLINE_LOADED');
    assert.strictEqual(res.report.fetchMethod, 'OFFLINE_FIXTURE');
    assert.strictEqual(res.report.httpStatus, null, 'Must not fabricate HTTP 200 for local file');
    assert.notStrictEqual(res.report.parityStatus, 'PASS', 'Offline fixture must never produce live PASS');
    assert.strictEqual(res.report.parityStatus, 'OFFLINE_BASELINE_PASS');
    assert.strictEqual(res.report.activationApproved, false);
    assert.strictEqual(res.report.matchedTenureRows, 19);
  });

  // 11. Stale snapshot / wrong effective date fails closed
  await run('stale snapshot or wrong effective date fails closed in verifier', () => {
    const badParsed = parser.parse(FIXTURE.replace('19 August 2026', '01 January 2024'), { sourceUrl: baseline.sourceUrl });
    const res = verifyContent(badParsed, baseline);
    assert.strictEqual(res.effectiveDateMatched, false);
    assert.ok(res.mismatches.some(m => m.includes('Effective date mismatch')));
  });

  // 12. Missing slab row fails closed
  await run('missing tenure slab row fails closed in verifier', () => {
    const missingSlabFixture = FIXTURE.replace('<tr><td>7 - 14 days</td><td>2.75%</td><td>3.25%</td></tr>\n', '');
    const badParsed = parser.parse(missingSlabFixture, { sourceUrl: baseline.sourceUrl });
    const res = verifyContent(badParsed, baseline);
    assert.strictEqual(res.allTenuresReconciled, false);
    assert.ok(res.mismatches.some(m => m.includes('Missing tenure row: "7 - 14 days"')));
    assert.ok(res.mismatches.some(m => m.includes('Candidate count mismatch')));
  });

  // 13. Corrupted rate value fails closed
  await run('corrupted rate value fails closed in verifier', () => {
    const badRateFixture = FIXTURE.replace('<td>2.75%</td><td>3.25%</td>', '<td>9.99%</td><td>3.25%</td>');
    const badParsed = parser.parse(badRateFixture, { sourceUrl: baseline.sourceUrl });
    const res = verifyContent(badParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Regular rate mismatch: expected 2.75%, got 9.99%')));
  });

  // 14. Senior spread mismatch fails closed
  await run('senior spread mismatch fails closed in verifier', () => {
    // Tamper slab 16 to have 50 bps spread instead of 60 bps (e.g. senior rate 7.00% instead of 7.10%)
    const badSpreadFixture = FIXTURE.replace('<td>6.50%</td><td>7.10%</td>', '<td>6.50%</td><td>7.00%</td>');
    const badParsed = parser.parse(badSpreadFixture, { sourceUrl: baseline.sourceUrl });
    const res = verifyContent(badParsed, baseline);
    assert.strictEqual(res.spreadsReconciled, false);
    assert.ok(res.mismatches.some(m => m.includes('Senior spread mismatch: expected 60 bps, got 50 bps')));
  });

  // 15. Duplicate candidate row fails closed
  await run('duplicate candidate row fails closed in verifier', () => {
    const parsed = parser.parse(FIXTURE, { sourceUrl: baseline.sourceUrl });
    const dupParsed = {
      ...parsed,
      candidates: [...parsed.candidates, parsed.candidates[0]],
    };
    const res = verifyContent(dupParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Duplicate candidate for tenure')));
    assert.ok(res.mismatches.some(m => m.includes('Candidate count mismatch')));
  });

  const passedCount = tests.filter(Boolean).length;
  const totalCount = tests.length;
  console.log(`\nHDFC Bank verifier suite completed: ${passedCount}/${totalCount} tests passed.`);
  if (passedCount !== totalCount) process.exit(1);
}

main().catch(err => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
