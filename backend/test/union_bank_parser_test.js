// Union Bank adapter tests use a deterministic fixture matching the official table shape.
'use strict';
const assert = require('assert');
const crypto = require('crypto');
const { UnionBankRateParser } = require('../parsers/union_bank_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const SOURCE_URL = 'https://www.unionbankofindia.bank.in/en/details/rate-of-interest';
const rows = [
  "<tr><td>7-14 Days</td><td>2.70</td><td>NO SLAB</td></tr>",
  "<tr><td>15 -30 Days</td><td>2.80</td><td>NO SLAB</td></tr>",
  "<tr><td>31-45 Days</td><td>3.00</td><td>NO SLAB</td></tr>",
  "<tr><td>46 -90 Days</td><td>4.00</td><td>NO SLAB</td></tr>",
  "<tr><td>91-120 Days</td><td>4.30</td><td>NO SLAB</td></tr>",
  "<tr><td>121-180 Days</td><td>4.75</td><td>NO SLAB</td></tr>",
  "<tr><td>181 -270 Days</td><td>5.40</td><td>NO SLAB</td></tr>",
  "<tr><td>271-364 Days</td><td>5.60</td><td>NO SLAB</td></tr>",
  "<tr><td>1 Yr to 399 days</td><td>6.20</td><td>NO SLAB</td></tr>",
  "<tr><td>400 Days</td><td>6.25</td><td>6.75</td></tr>",
  "<tr><td>401 to 443 days</td><td>6.25</td><td>NO SLAB</td></tr>",
  "<tr><td>444 days</td><td>6.50</td><td>6.80</td></tr>",
  "<tr><td>445 Days to 554 Days</td><td>6.15</td><td>NO SLAB</td></tr>",
  "<tr><td>555 Days</td><td>6.55</td><td>6.65</td></tr>",
  "<tr><td>556 Days to 996 days</td><td>6.15</td><td>NO SLAB</td></tr>",
  "<tr><td>997 days</td><td>6.10</td><td>NO SLAB</td></tr>",
  "<tr><td>998 days to 3 Yrs</td><td>6.10</td><td>NO SLAB</td></tr>",
  "<tr><td>&gt; 3 Yrs to 10 Yrs</td><td>6.00</td><td>NO SLAB</td></tr>"
];
const FIXTURE = [
  '<html><body><p>Revised interest rates effective from 4<sup>th</sup> August 2026 are given below:</p>',
  '<table><tr><th>Period/Tenor</th><th>Callable Deposits</th><th>Non - Callable Deposits</th></tr>',
  '<tr><th>Revised Interest Rate</th><th>Interest Rate</th></tr>',
  '<tr><td>&lt; Rs. 3 Cr</td><td>&gt;1 Cr to &lt;3 Cr</td></tr>',
  rows.join(''), '</table></body></html>'
].join('');
const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const result = new UnionBankRateParser().parse(FIXTURE, { sourceId: 'union-bank-retail-callable', sourceUrl: SOURCE_URL, sourceContentHash: hash, extractedAt: '2026-10-23T00:00:00.000Z' });
const tests = [];
function run(name, fn) { try { fn(); console.log('  PASS: ' + name); tests.push(true); } catch (e) { console.error('  FAIL: ' + name + ': ' + e.message); tests.push(false); } }
run('parses effective date and all 18 callable regular rows', () => {
  assert.strictEqual(result.success, true, result.errors.join('; '));
  assert.strictEqual(result.effectiveFrom, '2026-08-04');
  assert.strictEqual(result.candidates.length, 18);
  assert.strictEqual(result.metadata.extractedRows, 18);
});
run('does not consume non-callable column or infer senior rates', () => {
  const row400 = result.candidates.find(c => c.tenureLabel === '400 Days');
  assert.ok(row400);
  assert.strictEqual(row400.interestRate, 6.25);
  assert.strictEqual(row400.seniorCitizenRate, null);
  assert.strictEqual(row400.isCallable, true);
  assert.strictEqual(row400.customerType, 'REGULAR');
  assert.strictEqual(result.metadata.nonCallableRatesIncluded, false);
  assert.strictEqual(result.metadata.seniorRatesInferred, false);
});
run('normalizes strict >3-year boundary without overlap', () => {
  const three = result.candidates.find(c => c.tenureLabel === '998 days to 3 Yrs');
  const above = result.candidates.find(c => c.tenureLabel === '> 3 Yrs to 10 Yrs');
  assert.ok(three && above);
  assert.strictEqual(three.maxTenureDays, 1095);
  assert.strictEqual(above.minTenureDays, 1096);
  assert.strictEqual(above.maxTenureDays, 3650);
});
run('preserves exact 400/444/555-day singletons', () => {
  for (const label of ['400 Days','444 days','555 Days']) {
    const c = result.candidates.find(x => x.tenureLabel === label);
    assert.ok(c, label);
    assert.strictEqual(c.minTenureDays, c.maxTenureDays);
    assert.strictEqual(c.isBespokeTenure, true);
  }
});
run('fails closed when effective date is missing', () => {
  const bad = FIXTURE.replace('effective from 4<sup>th</sup> August 2026 are given below:', 'rates below');
  const out = new UnionBankRateParser().parse(bad, {sourceUrl: SOURCE_URL, sourceContentHash: hash});
  assert.strictEqual(out.success, false);
  assert.ok(out.errors.some(e => e.includes('effective date')));
});
run('fails closed when a published tenure row disappears', () => {
  const bad = FIXTURE.replace(rows[rows.length - 1], '');
  const out = new UnionBankRateParser().parse(bad, {sourceUrl: SOURCE_URL, sourceContentHash: hash});
  assert.strictEqual(out.success, false);
  assert.ok(out.errors.some(e => e.includes('row count')));
});
run('parser is available but collector source remains disabled', () => {
  assert.ok(getParserForBank('union_bank'));
  const src = defaultRegistry.getSource('union-bank-retail-callable');
  assert.ok(src);
  assert.strictEqual(src.enabled, false);
  assert.ok(!defaultRegistry.getEnabledSources().some(s => s.id === src.id));
  for (const c of result.candidates) assert.notStrictEqual(c.stagingStatus, 'VERIFIED');
});
if (tests.some(x => !x)) process.exit(1);
console.log('Results: ' + tests.filter(Boolean).length + ' passed, 0 failed (Total: ' + tests.length + ')');
