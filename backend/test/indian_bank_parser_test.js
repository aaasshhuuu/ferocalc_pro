// Indian Bank parser regression tests.
// Fixtures are synthetic deterministic representations of official public pages.
// Tests verify card rates vs annualized yield, senior citizen rates (+0.50% spread, +0.75% for > 5 yrs),
// super senior citizen rates (+0.75% spread, +1.00% for > 5 yrs),
// special schemes (IND Supreme 2.0, Ind Green, Ind Grow, Ind Prosper),
// calendar tenure extraction, exclusion of bulk tables, savings, and foreclosure charges,
// contiguous tenure coverage, customer eligibility restrictions, fail-closed safety, and registry integration.
// Also tests live-fetch failure, fallback rejection, stale snapshot, wrong effective date,
// changed special-scheme date, missing rates, duplicates, and incorrect rates.

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const {
  IndianBankRateParser,
  normalizeTenureLabel,
  extractCalendarTenure,
  extractSchemeDate,
  EXPECTED_CALLABLE_ROWS,
  SOURCE_URL,
} = require('../parsers/indian_bank_parser');
const { getParserForBank } = require('../parsers/parser_factory');
const { defaultRegistry } = require('../collectors/source_registry');
const {
  verifyContent,
  runVerification,
} = require('../scripts/verify_indian_bank_live_source');

// 18 rows of Table 0 (Domestic Retail Term Deposits < Rs. 3 Crore w.e.f. 23.10.2026)
const CALLABLE_ROWS = [
  '<tr><td>7 days to 14 days</td><td>2.80</td><td>2.80</td></tr>',
  '<tr><td>15 days to 29 days</td><td>2.80</td><td>2.80</td></tr>',
  '<tr><td>30 days to 45 days</td><td>3.00</td><td>3.00</td></tr>',
  '<tr><td>46 days to 90 days</td><td>3.25</td><td>3.25</td></tr>',
  '<tr><td>91 days to 120 days</td><td>3.50</td><td>3.50</td></tr>',
  '<tr><td>121 days to 180 days</td><td>3.85</td><td>3.85</td></tr>',
  '<tr><td>181 days to less than 9 months</td><td>4.50</td><td>4.50</td></tr>',
  '<tr><td>9 months to less than 1 year</td><td>4.75</td><td>4.75</td></tr>',
  '<tr><td>IND Supreme 2.0(300 days)</td><td>6.20</td><td>6.20</td></tr>',
  '<tr><td>1 year</td><td>6.10</td><td>6.10</td></tr>',
  '<tr><td>Above 1 year to less than 2 years</td><td>6.20</td><td>6.20</td></tr>',
  '<tr><td>Ind Green (500 Days)</td><td>6.40</td><td>6.40</td></tr>',
  '<tr><td>Ind Grow (555 Days)</td><td>6.65</td><td>6.80</td></tr>',
  '<tr><td>2 years to less than 3 years</td><td>6.15</td><td>6.15</td></tr>',
  '<tr><td>Ind Prosper(777 Days)</td><td>6.60</td><td>6.75</td></tr>',
  '<tr><td>3 years to less than 5 years</td><td>6.05</td><td>6.05</td></tr>',
  '<tr><td>5 year</td><td>6.00</td><td>6.00</td></tr>',
  '<tr><td>Above 5 years</td><td>6.00</td><td>6.00</td></tr>',
];

const FIXTURE = [
  '<!DOCTYPE html><html><body>',
  '<h1>Deposit Rates</h1>',
  '<!-- Table 0: Domestic Retail Term Deposits (< Rs. 3 Crore) w.e.f. 23.10.2026 -->',
  '<table>',
  '<thead>',
  '<tr><th colspan="3">Interest Rates on Domestic Retail Term Deposits</th></tr>',
  '<tr><th>Period / Tenor of Deposit</th><th colspan="2">Less than Rs.3 crore</th></tr>',
  '<tr><th></th><th>Existing Rate</th><th>Revised Rate (w.e.f 23.10.2026)</th></tr>',
  '<tr><th></th><th>(% per annum )</th><th>(% per annum )</th></tr>',
  '</thead>',
  '<tbody>',
  CALLABLE_ROWS.join('\n'),
  '</tbody>',
  '</table>',
  '<!-- Table 1: IND Supreme 2.0 Details (300 Days) -->',
  '<table>',
  '<tr><th colspan="2">IND Supreme 2.0 Term Deposit Interest Rates</th></tr>',
  '<tr><th>Category</th><th>Rate of Interest (% p.a) w.e.f 04.08.2026</th></tr>',
  '<tr><td>Public</td><td>6.20%</td></tr>',
  '<tr><td>Senior Citizen</td><td>6.70%</td></tr>',
  '<tr><td>Super Senior Citizen</td><td>6.95%</td></tr>',
  '</table>',
  '<!-- Table 2: IND GROW Details (555 Days) -->',
  '<table>',
  '<tr><th colspan="2">IND GROW Term Deposit Interest Rates</th></tr>',
  '<tr><th>Category</th><th>Rate of Interest (% p.a) w.e.f 23.10.2026</th></tr>',
  '<tr><td>Public</td><td>6.80%</td></tr>',
  '<tr><td>Senior Citizen</td><td>7.30%</td></tr>',
  '<tr><td>Super Senior Citizen</td><td>7.55%</td></tr>',
  '</table>',
  '<!-- Table 3: IND Proposer Details (777 Days) -->',
  '<table>',
  '<tr><th colspan="2">IND Proposer Term Deposit Interest Rates</th></tr>',
  '<tr><th>Category</th><th>Rate of Interest (% p.a) w.e.f 23.10.2026</th></tr>',
  '<tr><td>Public</td><td>6.75%</td></tr>',
  '<tr><td>Senior Citizen</td><td>7.25%</td></tr>',
  '<tr><td>Super Senior Citizen</td><td>7.50%</td></tr>',
  '</table>',
  '<!-- Table 4: IND GREEN Details (500 Days) -->',
  '<table>',
  '<tr><th colspan="2">IND GREEN Term Deposit Interest Rates</th></tr>',
  '<tr><th>Category</th><th>Rate of Interest (% p.a) w.e.f 05.06.2026</th></tr>',
  '<tr><td>Public</td><td>6.40%</td></tr>',
  '<tr><td>Senior Citizen</td><td>6.90%</td></tr>',
  '<tr><td>Super Senior Citizen</td><td>7.15%</td></tr>',
  '</table>',
  '<!-- Table 5: Bulk Deposits Rs. 3 Cr - Rs. 5 Cr (Excluded) -->',
  '<table>',
  '<tr><th colspan="3">Revision of Interest Rates for Bulk Term Deposits (Rs.3 Cr – Rs.5 Cr) as on 23.10.2026</th></tr>',
  '<tr><th>Period</th><th>Callable</th><th>Non- Callable</th></tr>',
  '<tr><td>7 days to 14 days</td><td>4.50</td><td>4.50</td></tr>',
  '<tr><td>1 year</td><td>6.00</td><td>6.05</td></tr>',
  '</table>',
  '<!-- Table 6: Savings Bank Deposits (Excluded) -->',
  '<table>',
  '<tr><th>Balance (Rs.)</th><th>Revised Rate of Interest % per annum</th></tr>',
  '<tr><td>Up to Rs.10 lakh</td><td>2.50%</td></tr>',
  '</table>',
  '<!-- Table 7: Foreclosure Charges (Excluded) -->',
  '<table>',
  '<tr><th>Period Run</th><th>Deposits upto Rs. 5 lakhs</th><th>Deposits above Rs. 5 lakhs</th></tr>',
  '<tr><td>&lt; 7 days</td><td>No interest</td><td>No interest</td></tr>',
  '</table>',
  '<div>',
  '<p>Senior Citizen Accounts: Additional rate of interest payable would be 0.50% p.a. for Domestic Retail Term Deposit (Less than 3 Crore in a day).</p>',
  '<p>A special offer for Senior Citizens (Aged 60 years & above) : An additional 0.25% higher rate of interest over & above the additional rate that is presently being offered for normal Senior Citizen on Term Deposit (0.50+0.25 = 0.75) for deposit bucket “above 5 Years up to 10 Years”.</p>',
  '<p>“IB – Golden Ager” – A Special Term Deposit Account for Super Senior Citizen” (Age 80 years and above) is offering additional 0.25% higher rate of interest over & above the additional rate that is presently being offered for normal Senior Citizen on Term Deposit for all deposit buckets.</p>',
  '<p>NRE term deposits should be opened for a minimum term of one year.</p>',
  '</div>',
  '</body></html>',
].join('\n');

const hash = crypto.createHash('sha256').update(FIXTURE).digest('hex');
const parser = new IndianBankRateParser();
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
  console.log('Indian Bank Parser Regression Test Suite');

  // 1. Full extraction from fixture
  await run('extracts all 18 callable retail rows yielding 54 candidates across Regular, Senior Citizen, and Super Senior Citizen', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.success, true, res.errors.join('; '));
    assert.strictEqual(res.effectiveFrom, '2026-10-23');
    assert.strictEqual(res.metadata.extractedRowCount, 18);
    assert.strictEqual(res.metadata.validRowCount, 18);
    assert.strictEqual(res.metadata.standardRowCount, 14);
    assert.strictEqual(res.metadata.specialSchemeCount, 4);
    assert.strictEqual(res.candidates.length, 54);
  });

  // 2. Card rate extraction
  await run('extracts card interest rates and strictly sets yieldIncludedAsRate to false', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.metadata.yieldIncludedAsRate, false);

    // 1 year: Regular 6.10%, Senior 6.60%, Super Senior 6.85%
    const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '1 year');
    assert.ok(reg1y, '1 Year regular candidate should exist');
    assert.strictEqual(reg1y.interestRate, 6.10);

    const sr1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '1 year');
    assert.ok(sr1y, '1 Year senior candidate should exist');
    assert.strictEqual(sr1y.interestRate, 6.60);

    const ssr1y = res.candidates.find(c => c.customerType === 'SUPER_SENIOR_CITIZEN' && c.tenureLabel === '1 year');
    assert.ok(ssr1y, '1 Year super senior candidate should exist');
    assert.strictEqual(ssr1y.interestRate, 6.85);
  });

  // 3. Senior Citizen rates (+0.50% spread below 5 years, +0.75% for above 5 years)
  await run('verifies senior rates have +0.50% spread below 5 years, and +0.75% for above 5 years', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
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
      if (/^Above\s+5\s*years?$/i.test(label)) {
        assert.strictEqual(spread, 0.75, `Senior spread for Above 5 years should be +0.75, got ${spread}`);
      } else {
        assert.strictEqual(spread, 0.50, `Senior spread for "${label}" should be +0.50, got ${spread}`);
      }
    }
  });

  // 4. Super Senior Citizen rates (+0.75% spread below 5 years, +1.00% for above 5 years)
  await run('verifies super senior rates have +0.75% spread below 5 years, and +1.00% for above 5 years', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const byTenure = new Map();
    for (const c of res.candidates) {
      if (!byTenure.has(c.tenureLabel)) byTenure.set(c.tenureLabel, {});
      byTenure.get(c.tenureLabel)[c.customerType] = c.interestRate;
    }

    for (const [label, rates] of byTenure.entries()) {
      assert.ok(rates.SUPER_SENIOR_CITIZEN !== undefined, `Missing super senior rate for ${label}`);

      const spread = Math.round((rates.SUPER_SENIOR_CITIZEN - rates.REGULAR) * 100) / 100;
      if (/^Above\s+5\s*years?$/i.test(label)) {
        assert.strictEqual(spread, 1.00, `Super Senior spread for Above 5 years should be +1.00, got ${spread}`);
      } else {
        assert.strictEqual(spread, 0.75, `Super Senior spread for "${label}" should be +0.75, got ${spread}`);
      }
    }
  });

  // 5. Special Schemes tagging & dynamic dates
  await run('correctly tags IND Supreme 2.0, Ind Green, Ind Grow, and Ind Prosper special schemes with dynamic dates', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

    // IND Supreme 2.0 (300 days)
    const supreme = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'IND_SUPREME_300');
    assert.ok(supreme, 'IND Supreme 2.0 regular candidate should exist');
    assert.strictEqual(supreme.interestRate, 6.20);
    assert.strictEqual(supreme.seniorCitizenRate, 6.70);
    assert.strictEqual(supreme.superSeniorRate, 6.95);
    assert.strictEqual(supreme.rateCategory, 'SPECIAL_SCHEME');
    assert.strictEqual(supreme.minTenureDays, 300);
    assert.strictEqual(supreme.maxTenureDays, 300);
    assert.strictEqual(supreme.effectiveFrom, '2026-08-04');
    assert.strictEqual(supreme.isBespokeTenure, true);

    // Ind Green (500 days)
    const green = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'IND_GREEN_500');
    assert.ok(green, 'Ind Green regular candidate should exist');
    assert.strictEqual(green.interestRate, 6.40);
    assert.strictEqual(green.seniorCitizenRate, 6.90);
    assert.strictEqual(green.superSeniorRate, 7.15);
    assert.strictEqual(green.effectiveFrom, '2026-06-05');
    assert.strictEqual(green.isBespokeTenure, true);

    // Ind Grow (555 days)
    const grow = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'IND_GROW_555');
    assert.ok(grow, 'Ind Grow regular candidate should exist');
    assert.strictEqual(grow.interestRate, 6.80);
    assert.strictEqual(grow.seniorCitizenRate, 7.30);
    assert.strictEqual(grow.superSeniorRate, 7.55);
    assert.strictEqual(grow.effectiveFrom, '2026-10-23');
    assert.strictEqual(grow.isBespokeTenure, true);

    // Ind Prosper (777 days)
    const prosper = res.candidates.find(c => c.customerType === 'REGULAR' && c.schemeName === 'IND_PROSPER_777');
    assert.ok(prosper, 'Ind Prosper regular candidate should exist');
    assert.strictEqual(prosper.interestRate, 6.75);
    assert.strictEqual(prosper.seniorCitizenRate, 7.25);
    assert.strictEqual(prosper.superSeniorRate, 7.50);
    assert.strictEqual(prosper.effectiveFrom, '2026-10-23');
    assert.strictEqual(prosper.isBespokeTenure, true);
  });

  // 6. Exclusion of bulk, savings, and foreclosure tables
  await run('strictly isolates and excludes bulk deposits (Rs. 3 Cr - Rs. 5 Cr), savings deposits, and foreclosure charges', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.metadata.bulkRatesIncluded, false);
    assert.strictEqual(res.metadata.nonCallableRatesIncluded, false);

    // Bulk rate of 4.50 for 7-14 days or 6.00 for 1 year must NOT replace standard retail 2.80 or 6.10
    const row7 = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '7 days to 14 days');
    assert.strictEqual(row7.interestRate, 2.80);

    const row1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '1 year');
    assert.strictEqual(row1y.interestRate, 6.10);
  });

  // 7. Structured calendar tenure fields
  await run('extracts structured calendar tenure fields correctly for calendar slabs', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

    // 1 year
    const c1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '1 year');
    assert.strictEqual(c1y.tenureDomain, 'CALENDAR');
    assert.strictEqual(c1y.minYears, 1);
    assert.strictEqual(c1y.minMonths, 12);
    assert.strictEqual(c1y.maxYears, 1);
    assert.strictEqual(c1y.maxMonths, 12);

    // Above 1 year to less than 2 years
    const c1to2 = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === 'Above 1 year to less than 2 years');
    assert.strictEqual(c1to2.tenureDomain, 'CALENDAR');
    assert.strictEqual(c1to2.minYears, 1);
    assert.strictEqual(c1to2.minMonths, 12);
    assert.strictEqual(c1to2.minDaysCal, 1);
    assert.strictEqual(c1to2.maxYears, 2);
    assert.strictEqual(c1to2.maxMonths, 24);
    assert.strictEqual(c1to2.maxOperator, '<');

    // Above 5 years
    const cabove5 = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === 'Above 5 years');
    assert.strictEqual(cabove5.tenureDomain, 'CALENDAR');
    assert.strictEqual(cabove5.minYears, 5);
    assert.strictEqual(cabove5.minMonths, 60);
    assert.strictEqual(cabove5.maxYears, 10);
    assert.strictEqual(cabove5.maxMonths, 120);

    // 7 days to 14 days should have tenureDomain: DAYS
    const c7d = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '7 days to 14 days');
    assert.strictEqual(c7d.tenureDomain, 'DAYS');
    assert.strictEqual(c7d.minYears, null);
  });

  // 8. Contiguous tenure coverage
  await run('verifies contiguous tenure coverage without gaps or overlaps across all 18 slabs', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const regular = res.candidates.filter(c => c.customerType === 'REGULAR');
    assert.strictEqual(regular.length, 18);

    const standard = regular.filter(c => c.rateCategory === 'STANDARD');
    assert.strictEqual(standard.length, 14);

    // Check contiguous chain for standard rows
    for (let i = 0; i < standard.length - 1; i++) {
      const cur = standard[i];
      const next = standard[i + 1];
      const diff = next.minTenureDays - cur.maxTenureDays;
      assert.ok(diff >= 0 && diff <= 1,
        `Gap or overlap between "${cur.tenureLabel}" (${cur.minTenureDays}-${cur.maxTenureDays}) and "${next.tenureLabel}" (${next.minTenureDays}-${next.maxTenureDays})`
      );
    }
  });

  // 9. Customer eligibility notes
  await run('enforces customer eligibility restrictions in candidate notes', () => {
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

    // Sub-one-year candidate notes
    const sub1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel === '7 days to 14 days');
    assert.ok(sub1y.notes.includes('Sub-one-year tenures are not eligible for NRE deposits'));

    // Senior candidate notes
    const sr = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.tenureLabel === '1 year');
    assert.ok(sr.notes.includes('60 years and above'));
    assert.ok(sr.notes.includes('Strictly not applicable to NRE/NRO or HUF accounts'));

    // Super Senior candidate notes
    const ssr = res.candidates.find(c => c.customerType === 'SUPER_SENIOR_CITIZEN' && c.tenureLabel === '1 year');
    assert.ok(ssr.notes.includes('IB Golden Ager, 80+'));
    assert.ok(ssr.notes.includes('Strictly not applicable to NRE/NRO or HUF accounts'));
  });

  // 10. Fail-closed: missing effective date
  await run('fails closed when effective date is missing from Table 0 header', () => {
    const badFixture = FIXTURE.replace(/w\.e\.f 23\.10\.2026/g, 'Revised Rate');
    const res = parser.parse(badFixture, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.success, false);
    assert.ok(res.errors.some(e => e.includes('effective date')));
    assert.strictEqual(res.candidates.length, 0);
  });

  // 11. Fail-closed: missing table
  await run('fails closed when Table 0 is missing', () => {
    const res = parser.parse('<html><body><p>No rates</p></body></html>', { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.success, false);
    assert.strictEqual(res.candidates.length, 0);
  });

  // 12. Fail-closed: corrupted row count
  await run('fails closed when callable retail row count is corrupted', () => {
    const corruptedRows = CALLABLE_ROWS.slice(0, 10).join('\n');
    const badFixture = FIXTURE.replace(CALLABLE_ROWS.join('\n'), corruptedRows);
    const res = parser.parse(badFixture, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.success, false);
    assert.ok(res.errors.some(e => e.includes('Expected 18 callable retail rows')));
  });

  // 13. Fail-closed: corrupted rate cell
  await run('fails closed when a rate cell is corrupt or missing', () => {
    const badFixture = FIXTURE.replace('<td>2.80</td><td>2.80</td>', '<td>N/A</td><td>--</td>');
    const res = parser.parse(badFixture, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(res.success, false);
    assert.ok(res.errors.some(e => e.includes('Missing regular interest rate')));
  });

  // 14. Parser factory integration
  await run('resolves IndianBankRateParser via parser factory', () => {
    const factoryParser = getParserForBank('INDIAN_BANK');
    assert.ok(factoryParser, 'Factory should return parser for INDIAN_BANK');
    assert.strictEqual(factoryParser.bankCode, 'INDIAN_BANK');
    assert.strictEqual(factoryParser.id, 'indian_bank_retail_html');
  });

  // 15. Source registry integration
  await run('registers indian-bank-retail-domestic as disabled in source registry', () => {
    const src = defaultRegistry.getSource('indian-bank-retail-domestic');
    assert.ok(src, 'Source indian-bank-retail-domestic should be registered');
    assert.strictEqual(src.bankCode, 'INDIAN_BANK');
    assert.strictEqual(src.enabled, false, 'Source must remain disabled');
    assert.strictEqual(src.parserId, 'indian_bank_retail_html');
  });

  // 16. Baseline JSON match
  await run('matches official baseline JSON values for all 18 tenures and 54 rates', () => {
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const res = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });

    assert.strictEqual(res.effectiveFrom, baseline.effectiveFrom);
    assert.strictEqual(baseline.tenures.length, 18);

    for (const bt of baseline.tenures) {
      const reg = res.candidates.find(c => c.tenureLabel === bt.label && c.customerType === 'REGULAR');
      assert.ok(reg, `Missing regular candidate for ${bt.label}`);
      assert.strictEqual(reg.interestRate, bt.regular, `Regular rate mismatch for ${bt.label}`);
      assert.strictEqual(reg.minTenureDays, bt.minDays, `Min days mismatch for ${bt.label}`);
      assert.strictEqual(reg.maxTenureDays, bt.maxDays, `Max days mismatch for ${bt.label}`);

      const sen = res.candidates.find(c => c.tenureLabel === bt.label && c.customerType === 'SENIOR_CITIZEN');
      assert.ok(sen, `Missing senior candidate for ${bt.label}`);
      assert.strictEqual(sen.interestRate, bt.senior, `Senior rate mismatch for ${bt.label}`);

      const ssr = res.candidates.find(c => c.tenureLabel === bt.label && c.customerType === 'SUPER_SENIOR_CITIZEN');
      assert.ok(ssr, `Missing super senior candidate for ${bt.label}`);
      assert.strictEqual(ssr.interestRate, bt.superSenior, `Super senior rate mismatch for ${bt.label}`);
    }
  });

  // 17. Live-fetch failure handling (fails closed without snapshot fallback)
  await run('live-fetch failure fails closed and exits non-zero without snapshot fallback', async () => {
    const res = await runVerification({
      mockFetchFailure: 'Connection refused by remote host (ECONNREFUSED)',
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

  // 18. Fallback rejection: archived snapshot cannot produce live-source PASS
  await run('fallback rejection: archived snapshot cannot produce live-source PASS', async () => {
    const res = await runVerification({ offline: true, body: Buffer.from(FIXTURE) });
    assert.strictEqual(res.report.isLiveRun, false);
    assert.strictEqual(res.report.sourceFetchStatus, 'OFFLINE_LOADED');
    assert.strictEqual(res.report.fetchMethod, 'OFFLINE_FIXTURE');
    assert.strictEqual(res.report.httpStatus, null, 'Must not fabricate HTTP 200 for local file');
    assert.notStrictEqual(res.report.parityStatus, 'PASS', 'Offline fixture must never produce live PASS');
    assert.strictEqual(res.report.parityStatus, 'OFFLINE_BASELINE_PASS');
    assert.strictEqual(res.report.activationApproved, false);
  });

  // 19. Stale snapshot: outdated effective date fails closed in verifier
  await run('stale snapshot: outdated effective date fails closed in verifier', () => {
    const staleParsed = parser.parse(FIXTURE.replace(/23\.10\.2026/g, '01.01.2024'), { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const res = verifyContent(staleParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Main effective date mismatch')));
  });

  // 20. Wrong effective date in main table fails closed
  await run('wrong effective date in main table fails closed', () => {
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const parsed = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const tamperedParsed = { ...parsed, effectiveFrom: '2026-01-01' };
    const res = verifyContent(tamperedParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Main effective date mismatch: expected 2026-10-23, got 2026-01-01')));
  });

  // 21. Changed special-scheme effective date fails closed
  await run('changed special-scheme effective date fails closed', () => {
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const parsed = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const tamperedParsed = {
      ...parsed,
      metadata: {
        ...parsed.metadata,
        effectiveDatesByTable: {
          ...parsed.metadata.effectiveDatesByTable,
          indSupreme300: '2026-01-01',
        },
      },
    };
    const res = verifyContent(tamperedParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Scheme indSupreme300 effective date mismatch: expected 2026-08-04, got 2026-01-01')));
  });

  // 22. Missing rates: missing rate cell fails closed in parser and verifier
  await run('missing rates: missing rate cell fails closed in parser and verifier', () => {
    const missingRateFixture = FIXTURE.replace('<td>2.80</td><td>2.80</td>', '<td></td><td></td>');
    const parsed = parser.parse(missingRateFixture, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    assert.strictEqual(parsed.success, false);
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const res = verifyContent(parsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Parser failed closed')));
  });

  // 23. Duplicate candidate row fails closed with duplicate candidate mismatch
  await run('duplicate candidate row fails closed with duplicate candidate mismatch', () => {
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const parsed = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const dupParsed = {
      ...parsed,
      candidates: [...parsed.candidates, parsed.candidates[0]],
    };
    const res = verifyContent(dupParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('Duplicate candidate for tenure')));
    assert.ok(res.mismatches.some(m => m.includes('Candidate count mismatch')));
  });

  // 24. Incorrect rate value fails closed with rate mismatch
  await run('incorrect rate value fails closed with rate mismatch', () => {
    const baselinePath = path.join(__dirname, '../review/indian_bank_official_baseline_2026-10-23.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf-8'));
    const parsed = parser.parse(FIXTURE, { sourceContentHash: hash, sourceUrl: SOURCE_URL });
    const tamperedCandidates = parsed.candidates.map(c => {
      if (c.tenureLabel === '1 year' && c.customerType === 'REGULAR') {
        return { ...c, interestRate: 6.99 };
      }
      return c;
    });
    const tamperedParsed = { ...parsed, candidates: tamperedCandidates };
    const res = verifyContent(tamperedParsed, baseline);
    assert.ok(res.mismatches.some(m => m.includes('1 year regular mismatch: expected 6.1, got 6.99')));
  });

  const passed = tests.filter(Boolean).length;
  const total = tests.length;
  console.log(`\nIndian Bank suite completed: ${passed}/${total} tests passed.`);
  if (passed !== total) process.exit(1);
}

main().catch(err => {
  console.error('Fatal test runner error:', err);
  process.exit(1);
});
