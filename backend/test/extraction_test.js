// FeroCalc Verified FD Rate Engine — Phase 2 Extraction & Validation Test Suite
//
// Tests all 16 required Phase 2 capabilities:
// 1. SBI extraction
// 2. HDFC extraction
// 3. ICICI extraction
// 4. Senior rate extraction when explicitly present
// 5. Bespoke tenure extraction
// 6. Missing optional fields
// 7. Malformed rate handling
// 8. Malformed tenure handling
// 9. Duplicate candidate detection
// 10. Overlapping candidate detection
// 11. Zero-result parser failure
// 12. Large rate delta anomaly
// 13. Large extraction-count anomaly
// 14. Unchanged source handling
// 15. Changed source handling
// 16. Strict no-automatic-VERIFIED status transition guarantee

'use strict';

const assert = require('assert');
const { SbiRateParser } = require('../parsers/sbi_parser');
const { HdfcRateParser } = require('../parsers/hdfc_parser');
const { IciciRateParser } = require('../parsers/icici_parser');
const { parseTenureRange } = require('../parsers/tenure_parser');
const { CandidateRate } = require('../parsers/base_parser');
const { CandidateValidator } = require('../validators/candidate_validator');
const { AnomalyDetector } = require('../validators/anomaly_detector');
const { CandidateStagingService } = require('../staging/candidate_staging_service');

// ============================================================
// Deterministic HTML Fixtures
// ============================================================

const SBI_FIXTURE_HTML = `
<html>
<body>
  <table>
    <tr>
      <th>Tenors</th>
      <th>Existing Rates for Public w.e.f. 15/07/2025</th>
      <th>Revised Rates for Public w.e.f.15/12/2025</th>
      <th>Existing Rates for Senior Citizen w.e.f. 15/07/2025</th>
      <th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th>
    </tr>
    <tr>
      <td>7 days to 45 days</td>
      <td>3.05</td>
      <td>3.05</td>
      <td>3.55</td>
      <td>3.55</td>
    </tr>
    <tr>
      <td>46 days to 179 days</td>
      <td>4.90</td>
      <td>4.90</td>
      <td>5.40</td>
      <td>5.40</td>
    </tr>
    <tr>
      <td>1 Year to less than 2 years</td>
      <td>6.25</td>
      <td>6.25</td>
      <td>6.75</td>
      <td>6.75</td>
    </tr>
    <tr>
      <td>5 years and up to 10 years</td>
      <td>6.05</td>
      <td>6.05</td>
      <td>7.05*</td>
      <td>7.05*</td>
    </tr>
  </table>
  <p>* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.</p>
</body>
</html>
`;

const HDFC_FIXTURE_HTML = `
<html>
<body>
  <p>Applicable from 6th Mar, 2026.</p>
  <table>
    <tr>
      <th>Tenure Bucket</th>
      <th>< 3 Crore</th>
    </tr>
    <tr>
      <th></th>
      <th>Interest Rate (per annum)</th>
      <th>**Senior Citizen Rates (per annum)</th>
    </tr>
    <tr>
      <td>7 - 14 days</td>
      <td>2.75%</td>
      <td>3.25%</td>
    </tr>
    <tr>
      <td>1 Year to < 15 months</td>
      <td>6.25%</td>
      <td>6.75%</td>
    </tr>
    <tr>
      <td>2 Years 11 Months (35 months)</td>
      <td>6.45%</td>
      <td>6.95%</td>
    </tr>
    <tr>
      <td>4 Year 7 Months (55 months)</td>
      <td>6.40%</td>
      <td>6.90%</td>
    </tr>
  </table>
</body>
</html>
`;

const ICICI_FIXTURE_HTML = `
<html>
<body>
  <h2>Fixed Deposit Interest Rates (w.e.f. from October 7, 2026)</h2>
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th>
      <th>Senior citizen</th>
      <th></th>
      <th>General citizen</th>
      <th>Senior citizen</th>
    </tr>
    <tr>
      <td>3.5%</td>
      <td>3.5%</td>
      <td>7 to 29 Days</td>
      <td>3.5%</td>
      <td>3.5%</td>
    </tr>
    <tr>
      <td>6.25%</td>
      <td>6.75%</td>
      <td>1 Year to 389 Days</td>
      <td>6.5%</td>
      <td>6.5%</td>
    </tr>
    <tr>
      <td>6.5% HIGHEST</td>
      <td>7.1% HIGHEST</td>
      <td>3 Years 1 Day to 5 Years</td>
      <td>6.55% HIGHEST</td>
      <td>6.55% HIGHEST</td>
    </tr>
  </table>
</body>
</html>
`;

// Helper test tracker
let passed = 0;
let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

async function runTestAsync(name, fn) {
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

async function runTestSuite() {
  console.log('======================================================');
  console.log('FeroCalc Phase 2 Extraction & Validation Test Suite');
  console.log('======================================================\n');

  // ----------------------------------------------------------------
  // Group 1: SBI Extraction
  // ----------------------------------------------------------------
  console.log('Group 1: SBI Extraction...');
  const sbiParser = new SbiRateParser();
  const sbiResult = sbiParser.parse(SBI_FIXTURE_HTML, {
    sourceId: 'sbi-retail-domestic',
    sourceUrl: 'https://sbi.co.in/rates',
    sourceContentHash: 'a'.repeat(64),
  });

  runTest('1. SBI extraction succeeds', () => {
    assert.strictEqual(sbiResult.success, true);
    assert.strictEqual(sbiResult.bankCode, 'SBI');
    assert.strictEqual(sbiResult.candidates.length, 8); // 4 rows * 2 customer types
  });

  runTest('SBI parses effective date accurately', () => {
    assert.strictEqual(sbiResult.effectiveFrom, '2025-12-15');
  });

  runTest('SBI cleans asterisk footnote from senior rate', () => {
    const senior5y = sbiResult.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays >= 1825);
    assert.ok(senior5y, 'Senior 5y candidate found');
    assert.strictEqual(senior5y.interestRate, 7.05);
  });

  // ----------------------------------------------------------------
  // Group 2: HDFC Extraction
  // ----------------------------------------------------------------
  console.log('\nGroup 2: HDFC Extraction...');
  const hdfcParser = new HdfcRateParser();
  const hdfcResult = hdfcParser.parse(HDFC_FIXTURE_HTML, {
    sourceId: 'hdfc-retail-domestic',
    sourceUrl: 'https://hdfcbank.com/rates',
    sourceContentHash: 'b'.repeat(64),
  });

  runTest('2. HDFC extraction succeeds', () => {
    assert.strictEqual(hdfcResult.success, true);
    assert.strictEqual(hdfcResult.bankCode, 'HDFC');
    assert.strictEqual(hdfcResult.candidates.length, 8); // 4 rows * 2 customer types
  });

  runTest('HDFC parses effective date from text', () => {
    assert.strictEqual(hdfcResult.effectiveFrom, '2026-03-06');
  });

  // ----------------------------------------------------------------
  // Group 3: ICICI Extraction
  // ----------------------------------------------------------------
  console.log('\nGroup 3: ICICI Extraction...');
  const iciciParser = new IciciRateParser();
  const iciciResult = iciciParser.parse(ICICI_FIXTURE_HTML, {
    sourceId: 'icici-retail-domestic',
    sourceUrl: 'https://icicibank.com/rates',
    sourceContentHash: 'c'.repeat(64),
  });

  runTest('3. ICICI extraction succeeds', () => {
    assert.strictEqual(iciciResult.success, true);
    assert.strictEqual(iciciResult.bankCode, 'ICICI');
    // 3 rows * 2 customer types * 2 callable modes = 12 candidates
    assert.strictEqual(iciciResult.candidates.length, 12);
  });

  runTest('ICICI parses effective date w.e.f text', () => {
    assert.strictEqual(iciciResult.effectiveFrom, '2026-10-07');
  });

  runTest('ICICI strips promotional badges ("6.5% HIGHEST" -> 6.5)', () => {
    const highestCand = iciciResult.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays >= 1095 && c.isCallable);
    assert.ok(highestCand);
    assert.strictEqual(highestCand.interestRate, 6.5);
  });

  runTest('ICICI captures both callable and non-callable options', () => {
    const callable = iciciResult.candidates.filter(c => c.isCallable === true);
    const nonCallable = iciciResult.candidates.filter(c => c.isCallable === false);
    assert.strictEqual(callable.length, 6);
    assert.strictEqual(nonCallable.length, 6);
  });

  // ----------------------------------------------------------------
  // Group 4: Senior Rate Extraction (Rule 1: Never derive with generic addition)
  // ----------------------------------------------------------------
  console.log('\nGroup 4: Senior Rate Extraction Rules...');
  runTest('4. Senior rate extracted when explicitly present', () => {
    const cand = sbiResult.candidates.find(c => c.customerType === 'REGULAR' && c.tenureLabel.includes('7 days'));
    assert.strictEqual(cand.interestRate, 3.05);
    assert.strictEqual(cand.seniorCitizenRate, 3.55);
  });

  runTest('Senior rate is NOT derived by adding a fixed 0.50% when missing', () => {
    const noSeniorHtml = `
      <table>
        <tr><th>Tenure</th><th>General Rate</th></tr>
        <tr><td>1 Year</td><td>6.00%</td></tr>
      </table>`;
    const parser = new SbiRateParser();
    const res = parser.parse(noSeniorHtml, { sourceContentHash: 'd'.repeat(64) });
    assert.strictEqual(res.candidates.length, 1);
    assert.strictEqual(res.candidates[0].customerType, 'REGULAR');
    assert.strictEqual(res.candidates[0].interestRate, 6.00);
    assert.strictEqual(res.candidates[0].seniorCitizenRate, null, 'Senior rate must be null, not 6.50%');
  });

  // ----------------------------------------------------------------
  // Group 5: Bespoke Tenure Extraction (Rules 3, 4, 5)
  // ----------------------------------------------------------------
  console.log('\nGroup 5: Bespoke Tenure Extraction...');
  runTest('5. Bespoke tenure "2 Years 11 Months (35 months)" extracted without loss', () => {
    const cand35m = hdfcResult.candidates.find(c => c.tenureLabel.includes('35 months'));
    assert.ok(cand35m, 'Candidate found');
    assert.strictEqual(cand35m.isBespokeTenure, true);
    assert.strictEqual(cand35m.tenureLabel, '2 Years 11 Months (35 months)');
    assert.strictEqual(cand35m.minTenureDays, 1065);
    assert.strictEqual(cand35m.maxTenureDays, 1065);
  });

  runTest('Bespoke tenure "1 Year to 389 Days" preserves exact days', () => {
    const cand389 = iciciResult.candidates.find(c => c.tenureLabel.includes('389 Days'));
    assert.ok(cand389);
    assert.strictEqual(cand389.minTenureDays, 365);
    assert.strictEqual(cand389.maxTenureDays, 389);
    assert.strictEqual(cand389.isBespokeTenure, true);
    assert.strictEqual(cand389.tenureUnit, 'DAYS');
  });

  // ----------------------------------------------------------------
  // Group 5.1: Tenure Parser Metadata & Unit Integrity (Phase 3C.5.2)
  // ----------------------------------------------------------------
  console.log('\nGroup 5.1: Tenure Parser Metadata & Unit Integrity...');
  runTest('Target 1: "211 days to less than 1 year" returns tenureUnit: DAYS', () => {
    const res = parseTenureRange('211 days to less than 1 year');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 211);
    assert.strictEqual(res.maxTenure, 364);
    assert.strictEqual(res.minTenureDays, 211);
    assert.strictEqual(res.maxTenureDays, 364);
    assert.strictEqual(res.tenureUnit, 'DAYS');
  });

  runTest('Target 2: "2 Years 1 day to < 2 Year 11 Months" returns tenureUnit: DAYS', () => {
    const res = parseTenureRange('2 Years 1 day to < 2 Year 11 Months');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 731);
    assert.strictEqual(res.maxTenure, 1064);
    assert.strictEqual(res.minTenureDays, 731);
    assert.strictEqual(res.maxTenureDays, 1064);
    assert.strictEqual(res.tenureUnit, 'DAYS');
  });

  runTest('Target 3: "3 Years 1 day to < 4 Years 7 Months" returns tenureUnit: DAYS', () => {
    const res = parseTenureRange('3 Years 1 day to < 4 Years 7 Months');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 1096);
    assert.strictEqual(res.maxTenure, 1672);
    assert.strictEqual(res.minTenureDays, 1096);
    assert.strictEqual(res.maxTenureDays, 1672);
    assert.strictEqual(res.tenureUnit, 'DAYS');
  });

  runTest('Target 4: "390 Days to < 18 Months" returns tenureUnit: DAYS', () => {
    const res = parseTenureRange('390 Days to < 18 Months');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 390);
    assert.strictEqual(res.maxTenure, 547);
    assert.strictEqual(res.minTenureDays, 390);
    assert.strictEqual(res.maxTenureDays, 547);
    assert.strictEqual(res.tenureUnit, 'DAYS');
  });

  runTest('Day-only ranges return tenureUnit: DAYS', () => {
    const res1 = parseTenureRange('7 - 14 days');
    assert.strictEqual(res1.isValid, true);
    assert.strictEqual(res1.minTenure, 7);
    assert.strictEqual(res1.maxTenure, 14);
    assert.strictEqual(res1.minTenureDays, 7);
    assert.strictEqual(res1.maxTenureDays, 14);
    assert.strictEqual(res1.tenureUnit, 'DAYS');

    const res2 = parseTenureRange('7 to 29 Days');
    assert.strictEqual(res2.isValid, true);
    assert.strictEqual(res2.minTenure, 7);
    assert.strictEqual(res2.maxTenure, 29);
    assert.strictEqual(res2.minTenureDays, 7);
    assert.strictEqual(res2.maxTenureDays, 29);
    assert.strictEqual(res2.tenureUnit, 'DAYS');
  });

  runTest('Year-normalized range returns tenureUnit: DAYS', () => {
    const res = parseTenureRange('1 Year to less than 2 years');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 365);
    assert.strictEqual(res.maxTenure, 729);
    assert.strictEqual(res.minTenureDays, 365);
    assert.strictEqual(res.maxTenureDays, 729);
    assert.strictEqual(res.tenureUnit, 'DAYS');
  });

  runTest('Month/year mixed ranges return tenureUnit: DAYS', () => {
    const res1 = parseTenureRange('1 Year to < 15 months');
    assert.strictEqual(res1.isValid, true);
    assert.strictEqual(res1.minTenure, 365);
    assert.strictEqual(res1.maxTenure, 455);
    assert.strictEqual(res1.minTenureDays, 365);
    assert.strictEqual(res1.maxTenureDays, 455);
    assert.strictEqual(res1.tenureUnit, 'DAYS');

    const res2 = parseTenureRange('15 months to < 18 months');
    assert.strictEqual(res2.isValid, true);
    assert.strictEqual(res2.minTenure, 456);
    assert.strictEqual(res2.maxTenure, 547);
    assert.strictEqual(res2.minTenureDays, 456);
    assert.strictEqual(res2.maxTenureDays, 547);
    assert.strictEqual(res2.tenureUnit, 'DAYS');
  });

  runTest('Pattern 1 bespoke scalar "2 Years 11 Months (35 months)" preserves MONTHS', () => {
    const res = parseTenureRange('2 Years 11 Months (35 months)');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 35);
    assert.strictEqual(res.maxTenure, 35);
    assert.strictEqual(res.minTenureDays, 1065);
    assert.strictEqual(res.maxTenureDays, 1065);
    assert.strictEqual(res.tenureUnit, 'MONTHS');
    assert.strictEqual(res.isBespoke, true);
  });

  runTest('Pattern 1 bespoke scalar "4 Year 7 Months (55 months)" preserves MONTHS', () => {
    const res = parseTenureRange('4 Year 7 Months (55 months)');
    assert.strictEqual(res.isValid, true);
    assert.strictEqual(res.minTenure, 55);
    assert.strictEqual(res.maxTenure, 55);
    assert.strictEqual(res.minTenureDays, 1673);
    assert.strictEqual(res.maxTenureDays, 1673);
    assert.strictEqual(res.tenureUnit, 'MONTHS');
    assert.strictEqual(res.isBespoke, true);
  });

  // ----------------------------------------------------------------
  // Group 5.2: Explicit '<' vs '<=' & Contiguity Regression Tests (Phase 3C.5.11A)
  // ----------------------------------------------------------------
  console.log('\nGroup 5.2: Explicit "<" vs "<=" & Contiguity Regression Tests...');
  runTest('Phase 3C.5.11A: "<=" preserves inclusive boundary without off-by-one reduction', () => {
    // 90 days <= 6 months must end at 183 days, not 182 days
    const res6m = parseTenureRange('90 days <= 6 months');
    assert.strictEqual(res6m.isValid, true);
    assert.strictEqual(res6m.minTenureDays, 90);
    assert.strictEqual(res6m.maxTenureDays, 183);

    // 6 months 1 day <=9 months must end at 274 days, not 273 days
    const res9m = parseTenureRange('6 months 1 day <=9 months');
    assert.strictEqual(res9m.isValid, true);
    assert.strictEqual(res9m.minTenureDays, 184);
    assert.strictEqual(res9m.maxTenureDays, 274);

    // 2 Years 11 Months 1 day <= 3 Year must end at 1095 days, not 1094 days
    const res3y = parseTenureRange('2 Years 11 Months 1 day <= 3 Year');
    assert.strictEqual(res3y.isValid, true);
    assert.strictEqual(res3y.minTenureDays, 1066);
    assert.strictEqual(res3y.maxTenureDays, 1095);

    // 4 Year 7 Months 1 day <=5 Years must end at 1825 days, not 1824 days
    const res5y = parseTenureRange('4 Year 7 Months 1 day <=5 Years');
    assert.strictEqual(res5y.isValid, true);
    assert.strictEqual(res5y.minTenureDays, 1674);
    assert.strictEqual(res5y.maxTenureDays, 1825);
  });

  runTest('Phase 3C.5.11A: Strict "<" and "less than" preserve off-by-one reduction', () => {
    // Strict "<" should decrement maxTenureDays by 1
    const resStrict6m = parseTenureRange('90 days < 6 months');
    assert.strictEqual(resStrict6m.isValid, true);
    assert.strictEqual(resStrict6m.minTenureDays, 90);
    assert.strictEqual(resStrict6m.maxTenureDays, 182);

    const resStrict9m = parseTenureRange('6 months 1 day < 9 months');
    assert.strictEqual(resStrict9m.isValid, true);
    assert.strictEqual(resStrict9m.minTenureDays, 184);
    assert.strictEqual(resStrict9m.maxTenureDays, 273);

    const resStrict3y = parseTenureRange('2 Years 11 Months 1 day < 3 Year');
    assert.strictEqual(resStrict3y.isValid, true);
    assert.strictEqual(resStrict3y.minTenureDays, 1066);
    assert.strictEqual(resStrict3y.maxTenureDays, 1094);

    const resStrict5y = parseTenureRange('4 Year 7 Months 1 day < 5 Years');
    assert.strictEqual(resStrict5y.isValid, true);
    assert.strictEqual(resStrict5y.minTenureDays, 1674);
    assert.strictEqual(resStrict5y.maxTenureDays, 1824);
  });

  runTest('Phase 3C.5.11A: HDFC adjacent slabs achieve 100% contiguity across corrected boundaries', () => {
    // Boundary 1: Slab 6 (90d <= 6m) -> Slab 7 (6m 1d <= 9m)
    const slab6 = parseTenureRange('90 days <= 6 months');
    const slab7 = parseTenureRange('6 months 1 day <=9 months');
    assert.strictEqual(slab6.maxTenureDays + 1, slab7.minTenureDays, 'Slab 6 to 7 must be contiguous (183 + 1 = 184)');

    // Boundary 2: Slab 7 (6m 1d <= 9m) -> Slab 8 (9 months 1 day to < 1 Year)
    const slab8 = parseTenureRange('9 months 1 day to < 1 Year');
    assert.strictEqual(slab7.maxTenureDays + 1, slab8.minTenureDays, 'Slab 7 to 8 must be contiguous (274 + 1 = 275)');

    // Boundary 3: Slab 15 (2Y 11M 1d <= 3Y) -> Slab 16 (3 Years 1 day to < 4 Years 7 Months)
    const slab15 = parseTenureRange('2 Years 11 Months 1 day <= 3 Year');
    const slab16 = parseTenureRange('3 Years 1 day to < 4 Years 7 Months');
    assert.strictEqual(slab15.maxTenureDays + 1, slab16.minTenureDays, 'Slab 15 to 16 must be contiguous (1095 + 1 = 1096)');

    // Boundary 4: Slab 18 (4Y 7M 1d <= 5Y) -> Slab 19 (5 Years 1 day to 10 Years)
    const slab18 = parseTenureRange('4 Year 7 Months 1 day <=5 Years');
    const slab19 = parseTenureRange('5 Years 1 day to 10 Years');
    assert.strictEqual(slab18.maxTenureDays + 1, slab19.minTenureDays, 'Slab 18 to 19 must be contiguous (1825 + 1 = 1826)');
  });

  runTest('Phase 3C.5.11A: Complete HDFC 19-slab sequence is strictly contiguous from 7 to 3650 days', () => {
    const hdfcSlabs = [
      '7 - 14 days',
      '15 - 29 days',
      '30 - 45 days',
      '46 - 60 days',
      '61 - 89 days',
      '90 days <= 6 months',
      '6 months 1 day <=9 months',
      '9 months 1 day to < 1 Year',
      '1 Year to < 15 months',
      '15 months to < 18 months',
      '18 months to < 21 months',
      '21 months to 2 years',
      '2 Years 1 day to < 2 Year 11 Months',
      '2 Years 11 Months (35 months)',
      '2 Years 11 Months 1 day <= 3 Year',
      '3 Years 1 day to < 4 Years 7 Months',
      '4 Year 7 Months (55 months)',
      '4 Year 7 Months 1 day <=5 Years',
      '5 Years 1 day to 10 Years',
    ];

    const parsedSlabs = hdfcSlabs.map(label => parseTenureRange(label));
    assert.strictEqual(parsedSlabs.length, 19);
    assert.strictEqual(parsedSlabs[0].minTenureDays, 7);
    assert.strictEqual(parsedSlabs[18].maxTenureDays, 3650);

    for (let i = 0; i < parsedSlabs.length - 1; i++) {
      const curr = parsedSlabs[i];
      const next = parsedSlabs[i + 1];
      assert.strictEqual(
        curr.maxTenureDays + 1,
        next.minTenureDays,
        `Contiguity broken between slab ${i} ("${curr.rawLabel}" [${curr.minTenureDays}..${curr.maxTenureDays}]) and slab ${i + 1} ("${next.rawLabel}" [${next.minTenureDays}..${next.maxTenureDays}])`
      );
    }
  });

  // ----------------------------------------------------------------
  // Group 6: Missing Optional Fields (Rule 2)
  // ----------------------------------------------------------------
  console.log('\nGroup 6: Missing Optional Fields...');
  runTest('6. Missing superSeniorRate and effectiveUntil remain null without inventing', () => {
    const cand = sbiResult.candidates[0];
    assert.strictEqual(cand.superSeniorRate, null);
    assert.strictEqual(cand.effectiveUntil, null);
    assert.strictEqual(cand.sourceDocumentUrl, null);
  });

  // ----------------------------------------------------------------
  // Group 7: Malformed Rate & Tenure Validation
  // ----------------------------------------------------------------
  console.log('\nGroup 7: Malformed Rate & Tenure Handling...');
  const validator = new CandidateValidator();

  runTest('7. Malformed rate fails validation (negative or non-numeric)', () => {
    const invalidRateCand = new CandidateRate({
      bankCode: 'SBI',
      sourceUrl: 'https://sbi.co.in',
      sourceContentHash: 'e'.repeat(64),
      customerType: 'REGULAR',
      tenureLabel: '1 Year',
      minTenureDays: 365,
      maxTenureDays: 365,
      interestRate: -4.5, // Negative impossible rate
    });
    const res = validator.validateCandidate(invalidRateCand);
    assert.strictEqual(res.isValid, false);
    assert.ok(res.errors.some(e => e.includes('negative')));
    assert.strictEqual(invalidRateCand.validationStatus, 'INVALID');
  });

  runTest('8. Malformed tenure fails validation (min > max or 0 days)', () => {
    const invalidTenureCand = new CandidateRate({
      bankCode: 'SBI',
      sourceUrl: 'https://sbi.co.in',
      sourceContentHash: 'f'.repeat(64),
      customerType: 'REGULAR',
      tenureLabel: 'Invalid Tenure',
      minTenureDays: 500,
      maxTenureDays: 200, // min > max
      interestRate: 6.5,
    });
    const res = validator.validateCandidate(invalidTenureCand);
    assert.strictEqual(res.isValid, false);
    assert.ok(res.errors.some(e => e.includes('maxTenureDays')));
  });

  // ----------------------------------------------------------------
  // Group 8: Duplicate & Overlapping Candidate Detection
  // ----------------------------------------------------------------
  console.log('\nGroup 8: Duplicate & Overlap Detection...');
  runTest('9. Duplicate candidate detected in batch', () => {
    const candA = new CandidateRate({
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 730,
      tenureLabel: '1 to 2 Years',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in',
      sourceContentHash: '1'.repeat(64),
    });
    const candB = new CandidateRate({
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 730, // Duplicate!
      tenureLabel: '1 to 2 Years copy',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in',
      sourceContentHash: '1'.repeat(64),
    });

    const summary = validator.validateBatch([candA, candB]);
    assert.strictEqual(summary.duplicateCount, 1);
    assert.strictEqual(summary.success, false);
    assert.ok(candB.validationErrors.some(e => e.includes('Duplicate')));
  });

  runTest('10. Overlapping candidate detected in batch', () => {
    const cand1 = new CandidateRate({
      bankCode: 'HDFC',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 7,
      maxTenureDays: 45, // 7..45
      tenureLabel: '7 to 45 Days',
      interestRate: 3.0,
      sourceUrl: 'https://hdfcbank.com',
      sourceContentHash: '2'.repeat(64),
    });
    const cand2 = new CandidateRate({
      bankCode: 'HDFC',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 30, // Overlaps with 7..45!
      maxTenureDays: 60,
      tenureLabel: '30 to 60 Days',
      interestRate: 3.5,
      sourceUrl: 'https://hdfcbank.com',
      sourceContentHash: '2'.repeat(64),
    });

    const summary = validator.validateBatch([cand1, cand2]);
    assert.strictEqual(summary.overlapCount, 1);
    assert.strictEqual(summary.success, false);
    assert.ok(cand1.validationErrors.some(e => e.includes('Overlapping')));
  });

  // ----------------------------------------------------------------
  // Group 9: Zero-Result Parser Failure
  // ----------------------------------------------------------------
  console.log('\nGroup 9: Zero-Result Parser Failure...');
  runTest('11. Parser returning zero rates is treated as failure', () => {
    const emptyHtml = '<html><body><div>No rate tables here</div></body></html>';
    const parser = new SbiRateParser();
    const res = parser.parse(emptyHtml, { sourceContentHash: '3'.repeat(64) });
    assert.strictEqual(res.success, false);
    assert.strictEqual(res.candidates.length, 0);
    assert.ok(res.errors.length > 0);

    const batchSummary = validator.validateBatch(res.candidates);
    assert.strictEqual(batchSummary.success, false);
    assert.ok(batchSummary.errors.some(e => e.includes('zero rate candidates')));
  });

  // ----------------------------------------------------------------
  // Group 10: Anomaly Detection
  // ----------------------------------------------------------------
  console.log('\nGroup 10: Anomaly Detection...');
  const anomalyDetector = new AnomalyDetector({ maxRateDeltaPct: 1.00 });

  runTest('12. Large rate delta anomaly (> 1.00%) flagged and moves status to IN_REVIEW', () => {
    const newCand = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 730,
      tenureLabel: '1 to 2 Years',
      interestRate: 8.50, // Massive spike from 6.25%
      sourceUrl: 'https://sbi.co.in',
      sourceContentHash: '4'.repeat(64),
    });

    const baseline = [
      { customerType: 'REGULAR', isCallable: true, minTenureDays: 365, maxTenureDays: 730, interestRate: 6.25 }
    ];

    const anomalies = anomalyDetector.detectAnomalies([newCand], baseline);
    assert.strictEqual(anomalies.hasAnomalies, true);
    assert.ok(anomalies.flags.some(f => f.includes('ANOMALY_LARGE_RATE_DELTA')));
    assert.strictEqual(newCand.stagingStatus, 'IN_REVIEW');
  });

  runTest('13. Large extraction-count anomaly flagged and prevents auto-DRAFT', () => {
    // Current extraction returns only 2 candidates when previously there were 10
    const fewCandidates = [
      new CandidateRate({ bankCode: 'SBI', customerType: 'REGULAR', minTenureDays: 7, maxTenureDays: 14, interestRate: 3.0, sourceContentHash: '5'.repeat(64), sourceUrl: 'https://sbi.co.in' }),
      new CandidateRate({ bankCode: 'SBI', customerType: 'REGULAR', minTenureDays: 15, maxTenureDays: 30, interestRate: 3.5, sourceContentHash: '5'.repeat(64), sourceUrl: 'https://sbi.co.in' }),
    ];
    const largeBaseline = Array.from({ length: 10 }, (_, i) => ({
      customerType: 'REGULAR',
      minTenureDays: (i + 1) * 30,
      maxTenureDays: (i + 2) * 30,
      interestRate: 5.0,
    }));

    const anomalies = anomalyDetector.detectAnomalies(fewCandidates, largeBaseline);
    assert.strictEqual(anomalies.hasAnomalies, true);
    assert.ok(anomalies.flags.some(f => f.includes('ANOMALY_COUNT_MISMATCH')));
    assert.ok(fewCandidates.every(c => c.stagingStatus === 'IN_REVIEW'));
  });

  // ----------------------------------------------------------------
  // Group 11: Staging Orchestration Workflow
  // ----------------------------------------------------------------
  console.log('\nGroup 11: Change vs Unchanged Source Workflow...');
  const stagingService = new CandidateStagingService({ skipDbPersist: true });

  await runTestAsync('14. Unchanged source skips re-extraction cleanly', async () => {
    const unchangedResult = {
      sourceId: 'sbi-retail-domestic',
      bankCode: 'SBI',
      status: 'UNCHANGED',
      contentHash: '6'.repeat(64),
      sourceUrl: 'https://sbi.co.in',
      bodyBuffer: Buffer.from(SBI_FIXTURE_HTML),
    };

    const stageRes = await stagingService.processCollectionResult(unchangedResult, { forceReExtract: false, skipDbPersist: true });
    assert.strictEqual(stageRes.status, 'UNCHANGED');
    assert.strictEqual(stageRes.extracted, false);
    assert.strictEqual(stageRes.candidates.length, 0);
  });

  await runTestAsync('15. Changed source triggers extraction, validation and staging', async () => {
    const changedResult = {
      sourceId: 'sbi-retail-domestic',
      bankCode: 'SBI',
      status: 'CHANGED',
      contentHash: '7'.repeat(64),
      sourceUrl: 'https://sbi.co.in',
      bodyBuffer: Buffer.from(SBI_FIXTURE_HTML),
    };

    const stageRes = await stagingService.processCollectionResult(changedResult, { skipDbPersist: true });
    assert.strictEqual(stageRes.status, 'EXTRACTION_SUCCESS');
    assert.strictEqual(stageRes.extracted, true);
    assert.strictEqual(stageRes.totalCandidates, 8);
    assert.strictEqual(stageRes.validCount, 8);
    assert.strictEqual(stageRes.invalidCount, 0);
  });

  // ----------------------------------------------------------------
  // Group 12: Strict No-Auto-Verified Guarantee
  // ----------------------------------------------------------------
  console.log('\nGroup 12: No Automatic VERIFIED Status Guarantee...');
  await runTestAsync('16. Under NO circumstances does any candidate become VERIFIED', async () => {
    const collectionResult = {
      sourceId: 'hdfc-retail-domestic',
      bankCode: 'HDFC',
      status: 'FIRST_SEEN',
      contentHash: '8'.repeat(64),
      sourceUrl: 'https://hdfcbank.com',
      bodyBuffer: Buffer.from(HDFC_FIXTURE_HTML),
    };

    const stageRes = await stagingService.processCollectionResult(collectionResult, { skipDbPersist: true });
    assert.ok(stageRes.candidates.length > 0);
    for (const c of stageRes.candidates) {
      assert.notStrictEqual(c.stagingStatus, 'VERIFIED', 'Candidate must NEVER be VERIFIED');
      assert.ok(['DRAFT', 'IN_REVIEW', 'INVALID', 'REJECTED'].includes(c.stagingStatus));
    }
  });

  // Summary
  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runTestSuite().catch(err => {
  console.error('Test suite uncaught error:', err);
  process.exit(1);
});
