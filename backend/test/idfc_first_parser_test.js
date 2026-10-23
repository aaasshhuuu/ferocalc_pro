// IDFC FIRST Bank parser regression tests.
// Fixture is deterministic and based on the official page's published table shape.
// It verifies parser behavior only; it is not a retained raw-source snapshot or approval to enable the collector.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { IdfcFirstRateParser } = require('../parsers/idfc_first_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');

const SOURCE_URL = 'https://www.idfcfirst.bank.in/personal-banking/deposits/fixed-deposit/fd-interest-rates';
const FIXTURE = `
<html><body>
<p>Interest Rates for Domestic / NRO / NRE Fixed Deposits of less than ₹3 Crore w.e.f. 25th July 2026*</p>
<p>Note: Senior Citizen rates are not applicable for NRI customers. Minimum tenure for NRE FD is 1 year.</p>
<table>
<tr><th>Tenure</th><th colspan="2">Rate of Interest (per annum)</th></tr>
<tr><th>General</th><th>Senior Citizen</th><th></th></tr>
<tr><td>7 days – 29 days</td><td>3.25%</td><td>3.50%</td></tr>
<tr><td>30 days – 45 days</td><td>3.50%</td><td>3.75%</td></tr>
<tr><td>46 days – 90 days</td><td>4.50%</td><td>4.75%</td></tr>
<tr><td>91 days – 180 days</td><td>5.00%</td><td>5.25%</td></tr>
<tr><td>181 days – less than 1 Year</td><td>6.50%</td><td>6.75%</td></tr>
<tr><td>1 year – 370 days</td><td>6.50%</td><td>6.75%</td></tr>
<tr><td>371 days – 499 days</td><td>7.00%</td><td>7.25%</td></tr>
<tr><td>500 days – 3 years</td><td>7.25%</td><td>7.50%</td></tr>
<tr><td>3 years 1 day – 5 years</td><td>6.75%</td><td>7.00%</td></tr>
<tr><td>5 years 1 day – 10 years</td><td>6.00%</td><td>6.25%</td></tr>
</table>
</body></html>`;

function run(name, fn) {
  try {
    fn();
    console.log('  PASS: ' + name);
    return true;
  } catch (error) {
    console.error('  FAIL: ' + name + ': ' + error.message);
    return false;
  }
}

const htmlHash = crypto.createHash('sha256').update(FIXTURE, 'utf8').digest('hex');
const parser = new IdfcFirstRateParser();
const result = parser.parse(FIXTURE, {
  sourceId: 'idfc-first-retail-domestic',
  sourceUrl: SOURCE_URL,
  sourceContentHash: htmlHash,
  extractedAt: '2026-10-23T00:00:00.000Z',
});

const outcomes = [];
outcomes.push(run('selects the retail FD table and extracts all 10 fixture rows', () => {
  assert.strictEqual(result.success, true, result.errors.join('; '));
  assert.strictEqual(result.effectiveFrom, '2026-07-25');
  assert.strictEqual(result.metadata.extractedRows, 10);
  assert.strictEqual(result.candidates.length, 20);
}));

outcomes.push(run('preserves General and Senior Citizen values as separate customer candidates', () => {
  const regular = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('500 days'));
  const senior = result.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel.includes('500 days'));
  assert.ok(regular);
  assert.ok(senior);
  assert.strictEqual(regular.interestRate, 7.25);
  assert.strictEqual(regular.seniorCitizenRate, 7.50);
  assert.strictEqual(senior.interestRate, 7.50);
  assert.strictEqual(senior.stagingStatus, 'DRAFT');
  assert.ok(senior.notes.includes('not applicable to NRI'));
}));

outcomes.push(run('normalizes en dashes while preserving the raw published tenure label', () => {
  const first = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('7 days'));
  assert.ok(first);
  assert.strictEqual(first.minTenureDays, 7);
  assert.strictEqual(first.maxTenureDays, 29);
  assert.strictEqual(first.tenureLabel, '7 days – 29 days');
}));

outcomes.push(run('keeps adjacent 1-year boundary buckets separate', () => {
  const lower = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('181 days'));
  const oneYear = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('1 year'));
  const next = result.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.startsWith('371 days'));
  assert.strictEqual(lower.maxTenureDays, 364);
  assert.strictEqual(oneYear.minTenureDays, 365);
  assert.strictEqual(oneYear.maxTenureDays, 370);
  assert.strictEqual(next.minTenureDays, 371);
}));

outcomes.push(run('fails closed when the effective-date heading is absent', () => {
  const noDate = FIXTURE.replace('w.e.f. 25th July 2026', 'revised rates');
  const res = parser.parse(noDate, { sourceUrl: SOURCE_URL, sourceContentHash: htmlHash });
  assert.strictEqual(res.success, false);
  assert.ok(res.errors.some(e => e.includes('effective date')));
}));

outcomes.push(run('fails closed if the expected retail table is missing', () => {
  const res = parser.parse('<html><body><p>No retail rates</p></body></html>', { sourceUrl: SOURCE_URL, sourceContentHash: htmlHash });
  assert.strictEqual(res.success, false);
  assert.strictEqual(res.candidates.length, 0);
}));

outcomes.push(run('parser factory exposes IDFC_FIRST without enabling source ingestion', () => {
  assert.ok(getParserForBank(' idfc_first '));
  const source = defaultRegistry.getSource('idfc-first-retail-domestic');
  assert.ok(source);
  assert.strictEqual(source.enabled, false);
  assert.ok(!defaultRegistry.getEnabledSources().some(s => s.id === source.id));
  for (const c of result.candidates) assert.notStrictEqual(c.stagingStatus, 'VERIFIED');
}));

if (outcomes.some(passed => !passed)) process.exit(1);
console.log('Results: ' + outcomes.filter(Boolean).length + ' passed, 0 failed (Total: ' + outcomes.length + ')');
