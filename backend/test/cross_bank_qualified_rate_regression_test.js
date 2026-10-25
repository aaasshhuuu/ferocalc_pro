// FeroCalc Phase 3C.5.40 — Cross-Bank Qualified-Rate Leakage Regression Test Suite
//
// Regression tests verifying:
// 1. HDFC: Documented qualified rate (Senior Citizen Care) classifies as SPECIAL_SCHEME, 0% leakage into regular candidate
// 2. HDFC: Unknown marker (#) on 5-10y slab fails closed with schemeName=null and fails validation
// 3. HDFC: Contradictory footnote on 5-10y slab fails closed with schemeName=null
// 4. HDFC: Special scheme footnote attached to different tenure fails tenure check and fails closed
// 5. HDFC: Valid ordinary standard rate populates regular seniorCitizenRate cleanly
// 6. HDFC: Baseline fixture (HDFC_FIXTURE_HTML) produces 100% concordant candidates
// 7. ICICI: Documented qualified rate (Golden Years) classifies as SPECIAL_SCHEME, 0% leakage into regular candidate
// 8. ICICI: Unknown marker (#) on 5-10y slab fails closed with schemeName=null and fails validation
// 9. ICICI: Contradictory footnote on 5-10y slab fails closed with schemeName=null
// 10. ICICI: Special scheme footnote attached to different tenure fails tenure check and fails closed
// 11. ICICI: Valid ordinary standard rate populates regular seniorCitizenRate cleanly
// 12. ICICI: Non-callable product classification (isCallable: false) and senior qualification isolation
// 13. ICICI: Baseline fixture (ICICI_FIXTURE_HTML) produces 100% concordant callable & non-callable candidates

'use strict';

const assert = require('assert');
const { HdfcRateParser } = require('../parsers/hdfc_parser');
const { IciciRateParser } = require('../parsers/icici_parser');
const { CandidateValidator } = require('../validators/candidate_validator');

let passed = 0;
let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

console.log('======================================================================');
console.log('FeroCalc Phase 3C.5.40 Cross-Bank Qualified-Rate Regression Tests');
console.log('======================================================================\n');

const hdfcParser = new HdfcRateParser();
const iciciParser = new IciciRateParser();
const validator = new CandidateValidator();

// ==================================================================
// PART 1: HDFC Bank Qualified Rate & Fail-Closed Safety Tests
// ==================================================================
console.log('--- Part 1: HDFC Bank Qualified Rate & Classification Tests ---');

// HDFC Scenario 1: Documented qualified rate (HDFC Senior Citizen Care FD)
runTest('1. HDFC: Documented Senior Citizen Care rate classifies as SPECIAL_SCHEME with 0% leakage', () => {
  const html = `
  <table>
    <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
    <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
    <tr><td>5 Years 1 day to 10 Years</td><td>6.15%</td><td>6.90%*</td></tr>
  </table>
  <p>* An additional premium of 0.25% will be paid to Senior Citizens under HDFC Senior Citizen Care FD scheme.</p>
  `;
  const res = hdfcParser.parse(html, { sourceContentHash: 'a1'.repeat(32) });
  assert.strictEqual(res.success, true);

  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');
  assert.ok(reg && sen);

  // Regular candidate remains STANDARD card rate with no leakage
  assert.strictEqual(reg.interestRate, 6.15);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Senior promotional rate must NOT leak into regular candidate');
  assert.strictEqual(reg.rateCategory, 'STANDARD');
  assert.strictEqual(reg.schemeName, null);

  // Senior candidate is positively classified as SPECIAL_SCHEME
  assert.strictEqual(sen.interestRate, 6.90);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, 'HDFC Senior Citizen Care');
  assert.ok(sen.notes && sen.notes.includes('Senior Citizen Care'));

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, true, 'Positively identified Senior Citizen Care candidate must pass validation');
});

// HDFC Scenario 2: Unknown marker (#) on 5-10y slab -> fails closed
runTest('2. HDFC: Unknown marker (#) on 5-10y slab fails closed (schemeName=null, fails validation)', () => {
  const html = `
  <table>
    <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
    <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
    <tr><td>5 Years 1 day to 10 Years</td><td>6.15%</td><td>6.90%#</td></tr>
  </table>
  <p># Rates subject to credit committee approval.</p>
  `;
  const res = hdfcParser.parse(html, { sourceContentHash: 'a2'.repeat(32) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(reg && sen);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Must NOT leak into regular seniorCitizenRate');

  // Senior candidate fails closed
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null, 'Unknown marker must fail closed with schemeName=null');
  assert.strictEqual(sen.notes, '# Rates subject to credit committee approval.');

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, false, 'Unresolved candidate must fail validation');
  assert.ok(valSen.errors.some(e => e.includes('Missing required schemeName')));
});

// HDFC Scenario 3: Contradictory footnote (* on 5-10y slab) -> fails closed
runTest('3. HDFC: Contradictory footnote (* on 5-10y slab) fails closed (not assumed Senior Citizen Care)', () => {
  const html = `
  <table>
    <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
    <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
    <tr><td>5 Years 1 day to 10 Years</td><td>6.15%</td><td>6.90%*</td></tr>
  </table>
  <p>* Rates subject to revision without prior notice.</p>
  `;
  const res = hdfcParser.parse(html, { sourceContentHash: 'a3'.repeat(32) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(reg && sen);
  assert.strictEqual(reg.seniorCitizenRate, null);

  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null, 'Contradictory footnote must NOT be inferred as Senior Citizen Care');

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, false);
});

// HDFC Scenario 4: Special scheme attached to a different tenure
runTest('4. HDFC: Special scheme footnote attached to 1-2y tenure fails tenure condition (fails closed)', () => {
  const html = `
  <table>
    <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
    <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
    <tr><td>1 Year to < 15 months</td><td>6.25%</td><td>6.75%*</td></tr>
  </table>
  <p>* Additional premium under Senior Citizen Care FD.</p>
  `;
  const res = hdfcParser.parse(html, { sourceContentHash: 'a4'.repeat(32) });
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(sen);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null, 'Senior Citizen Care on non-eligible tenure must fail closed');

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, false);
});

// HDFC Scenario 5: Valid ordinary standard rate (unmarked)
runTest('5. HDFC: Valid ordinary standard rate populates regular seniorCitizenRate cleanly', () => {
  const html = `
  <table>
    <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
    <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
    <tr><td>1 Year to < 15 months</td><td>6.25%</td><td>6.75%</td></tr>
    <tr><td>5 Years 1 day to 10 Years</td><td>6.15%</td><td>6.65%</td></tr>
  </table>
  `;
  const res = hdfcParser.parse(html, { sourceContentHash: 'a5'.repeat(32) });
  const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 365);
  const sen1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 365);
  const reg5y = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays >= 1825);
  const sen5y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays >= 1825);

  assert.ok(reg1y && sen1y && reg5y && sen5y);
  assert.strictEqual(reg1y.seniorCitizenRate, 6.75);
  assert.strictEqual(reg1y.rateCategory, 'STANDARD');
  assert.strictEqual(sen1y.interestRate, 6.75);
  assert.strictEqual(sen1y.rateCategory, 'STANDARD');

  // Unmarked 5-10y slab is standard card rate (not falsely assumed special scheme)
  assert.strictEqual(reg5y.seniorCitizenRate, 6.65);
  assert.strictEqual(reg5y.rateCategory, 'STANDARD');
  assert.strictEqual(sen5y.interestRate, 6.65);
  assert.strictEqual(sen5y.rateCategory, 'STANDARD');
  assert.strictEqual(sen5y.schemeName, null);
});

// HDFC Scenario 6: Baseline fixture concordance
runTest('6. HDFC: Baseline fixture produces 100% concordant candidates', () => {
  const fixture = `
  <html><body>
    <p>Applicable from 6th Mar, 2026.</p>
    <table>
      <tr><th>Tenure Bucket</th><th>< 3 Crore</th></tr>
      <tr><th></th><th>Interest Rate (per annum)</th><th>**Senior Citizen Rates (per annum)</th></tr>
      <tr><td>7 - 14 days</td><td>2.75%</td><td>3.25%</td></tr>
      <tr><td>1 Year to < 15 months</td><td>6.25%</td><td>6.75%</td></tr>
      <tr><td>2 Years 11 Months (35 months)</td><td>6.45%</td><td>6.95%</td></tr>
      <tr><td>4 Year 7 Months (55 months)</td><td>6.40%</td><td>6.90%</td></tr>
    </table>
  </body></html>
  `;
  const res = hdfcParser.parse(fixture, { sourceContentHash: 'a6'.repeat(32) });
  assert.strictEqual(res.success, true);
  assert.strictEqual(res.candidates.length, 8);
  assert.strictEqual(res.effectiveFrom, '2026-03-06');

  res.candidates.forEach(c => {
    assert.strictEqual(c.rateCategory, 'STANDARD');
    assert.strictEqual(c.schemeName, null);
    assert.strictEqual(c.isCallable, true);
    const val = validator.validateCandidate(c);
    assert.strictEqual(val.isValid, true);
  });
});

// ==================================================================
// PART 2: ICICI Bank Qualified Rate & Fail-Closed Safety Tests
// ==================================================================
console.log('\n--- Part 2: ICICI Bank Qualified Rate & Classification Tests ---');

// ICICI Scenario 1: Documented qualified rate (ICICI Golden Years FD on Callable)
runTest('7. ICICI: Documented Golden Years rate classifies as SPECIAL_SCHEME with 0% leakage', () => {
  const html = `
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th><th>Senior citizen</th>
      <th></th>
      <th>General citizen</th><th>Senior citizen</th>
    </tr>
    <tr>
      <td>6.5%</td><td>7.20%*</td>
      <td>5 Years 1 Day to 10 Years</td>
      <td>6.55%</td><td>6.55%</td>
    </tr>
  </table>
  <p>* An additional premium of 0.20% will be paid to Senior Citizens under ICICI Golden Years FD scheme.</p>
  `;
  const res = iciciParser.parse(html, { sourceContentHash: 'b1'.repeat(32) });
  assert.strictEqual(res.success, true);

  const callReg = res.candidates.find(c => c.customerType === 'REGULAR' && c.isCallable);
  const callSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.isCallable);
  assert.ok(callReg && callSen);

  // Callable regular candidate has zero leakage
  assert.strictEqual(callReg.interestRate, 6.5);
  assert.strictEqual(callReg.seniorCitizenRate, null, 'Callable senior rate must NOT leak into regular candidate');
  assert.strictEqual(callReg.rateCategory, 'STANDARD');
  assert.strictEqual(callReg.isCallable, true);

  // Callable senior candidate is SPECIAL_SCHEME
  assert.strictEqual(callSen.interestRate, 7.20);
  assert.strictEqual(callSen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(callSen.schemeName, 'ICICI Golden Years');
  assert.strictEqual(callSen.isCallable, true);
  assert.ok(callSen.notes && callSen.notes.includes('Golden Years'));

  const valSen = validator.validateCandidate(callSen);
  assert.strictEqual(valSen.isValid, true);
});

// ICICI Scenario 2: Unknown marker (#) on 5-10y slab -> fails closed
runTest('8. ICICI: Unknown marker (#) on 5-10y slab fails closed (schemeName=null, fails validation)', () => {
  const html = `
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th><th>Senior citizen</th>
      <th></th>
      <th>General citizen</th><th>Senior citizen</th>
    </tr>
    <tr>
      <td>6.5%</td><td>7.20%#</td>
      <td>5 Years 1 Day to 10 Years</td>
      <td>6.55%</td><td>6.55%</td>
    </tr>
  </table>
  <p># Available at select branches only.</p>
  `;
  const res = iciciParser.parse(html, { sourceContentHash: 'b2'.repeat(32) });
  const callReg = res.candidates.find(c => c.customerType === 'REGULAR' && c.isCallable);
  const callSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.isCallable);

  assert.ok(callReg && callSen);
  assert.strictEqual(callReg.seniorCitizenRate, null);

  assert.strictEqual(callSen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(callSen.schemeName, null, 'Unknown marker must fail closed with schemeName=null');
  assert.strictEqual(callSen.notes, '# Available at select branches only.');

  const valSen = validator.validateCandidate(callSen);
  assert.strictEqual(valSen.isValid, false);
  assert.ok(valSen.errors.some(e => e.includes('Missing required schemeName')));
});

// ICICI Scenario 3: Contradictory footnote (* on 5-10y slab) -> fails closed
runTest('9. ICICI: Contradictory footnote (* on 5-10y slab) fails closed (not assumed Golden Years)', () => {
  const html = `
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th><th>Senior citizen</th>
      <th></th>
      <th>General citizen</th><th>Senior citizen</th>
    </tr>
    <tr>
      <td>6.5%</td><td>7.20%*</td>
      <td>5 Years 1 Day to 10 Years</td>
      <td>6.55%</td><td>6.55%</td>
    </tr>
  </table>
  <p>* Subject to revision without prior notice.</p>
  `;
  const res = iciciParser.parse(html, { sourceContentHash: 'b3'.repeat(32) });
  const callSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.isCallable);

  assert.ok(callSen);
  assert.strictEqual(callSen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(callSen.schemeName, null);

  const valSen = validator.validateCandidate(callSen);
  assert.strictEqual(valSen.isValid, false);
});

// ICICI Scenario 4: Special scheme attached to a different tenure
runTest('10. ICICI: Golden Years footnote attached to 1-2y tenure fails tenure condition (fails closed)', () => {
  const html = `
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th><th>Senior citizen</th>
      <th></th>
      <th>General citizen</th><th>Senior citizen</th>
    </tr>
    <tr>
      <td>6.25%</td><td>6.75%*</td>
      <td>1 Year to 389 Days</td>
      <td>6.5%</td><td>6.5%</td>
    </tr>
  </table>
  <p>* Additional premium under ICICI Golden Years scheme.</p>
  `;
  const res = iciciParser.parse(html, { sourceContentHash: 'b4'.repeat(32) });
  const callSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.isCallable);

  assert.ok(callSen);
  assert.strictEqual(callSen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(callSen.schemeName, null, 'Golden Years on 1-year tenure must fail closed');

  const valSen = validator.validateCandidate(callSen);
  assert.strictEqual(valSen.isValid, false);
});

// ICICI Scenario 5: Valid ordinary standard rate (unmarked)
runTest('11. ICICI: Valid ordinary standard rate populates regular seniorCitizenRate cleanly', () => {
  const html = `
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th><th>Senior citizen</th>
      <th></th>
      <th>General citizen</th><th>Senior citizen</th>
    </tr>
    <tr>
      <td>3.5%</td><td>3.5%</td>
      <td>7 to 29 Days</td>
      <td>3.5%</td><td>3.5%</td>
    </tr>
  </table>
  `;
  const res = iciciParser.parse(html, { sourceContentHash: 'b5'.repeat(32) });
  const callReg = res.candidates.find(c => c.customerType === 'REGULAR' && c.isCallable);
  const callSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.isCallable);

  assert.ok(callReg && callSen);
  assert.strictEqual(callReg.interestRate, 3.5);
  assert.strictEqual(callReg.seniorCitizenRate, 3.5);
  assert.strictEqual(callReg.rateCategory, 'STANDARD');
  assert.strictEqual(callSen.interestRate, 3.5);
  assert.strictEqual(callSen.rateCategory, 'STANDARD');
});

// ICICI Scenario 6: Non-callable product classification & eligibility boundary
runTest('12. ICICI: Non-callable product boundary is strictly preserved across qualification', () => {
  const html = `
  <table>
    <tr>
      <th colspan="2">With premature withdrawal facility</th>
      <th>Tenure</th>
      <th colspan="2">Without premature withdrawal facility</th>
    </tr>
    <tr>
      <th>General citizen</th><th>Senior citizen</th>
      <th></th>
      <th>General citizen</th><th>Senior citizen</th>
    </tr>
    <tr>
      <td>6.5%</td><td>7.0%</td>
      <td>5 Years 1 Day to 10 Years</td>
      <td>6.55%</td><td>7.25%*</td>
    </tr>
  </table>
  <p>* Additional premium under ICICI Golden Years FD scheme for non-callable deposits.</p>
  `;
  const res = iciciParser.parse(html, { sourceContentHash: 'b6'.repeat(32) });
  assert.strictEqual(res.candidates.length, 4);

  // Callable candidates remain STANDARD
  const callReg = res.candidates.find(c => c.customerType === 'REGULAR' && c.isCallable);
  const callSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.isCallable);
  assert.strictEqual(callReg.isCallable, true);
  assert.strictEqual(callReg.seniorCitizenRate, 7.0);
  assert.strictEqual(callSen.isCallable, true);
  assert.strictEqual(callSen.rateCategory, 'STANDARD');

  // Non-callable candidates strictly preserve isCallable: false
  const nonCallReg = res.candidates.find(c => c.customerType === 'REGULAR' && !c.isCallable);
  const nonCallSen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && !c.isCallable);
  assert.strictEqual(nonCallReg.isCallable, false);
  assert.strictEqual(nonCallReg.seniorCitizenRate, null, 'Non-callable senior scheme must not leak into regular');
  assert.strictEqual(nonCallReg.tenureLabel, '5 Years 1 Day to 10 Years (Non-Callable)');

  assert.strictEqual(nonCallSen.isCallable, false);
  assert.strictEqual(nonCallSen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(nonCallSen.schemeName, 'ICICI Golden Years');
  assert.strictEqual(nonCallSen.tenureLabel, '5 Years 1 Day to 10 Years (Non-Callable)');

  assert.strictEqual(validator.validateCandidate(nonCallReg).isValid, true);
  assert.strictEqual(validator.validateCandidate(nonCallSen).isValid, true);
});

// ICICI Scenario 7: Baseline fixture concordance
runTest('13. ICICI: Baseline fixture produces 100% concordant candidates with badge removal', () => {
  const fixture = `
  <html><body>
    <h2>Fixed Deposit Interest Rates (w.e.f. from October 7, 2026)</h2>
    <table>
      <tr>
        <th colspan="2">With premature withdrawal facility</th>
        <th>Tenure</th>
        <th colspan="2">Without premature withdrawal facility</th>
      </tr>
      <tr>
        <th>General citizen</th><th>Senior citizen</th>
        <th></th>
        <th>General citizen</th><th>Senior citizen</th>
      </tr>
      <tr>
        <td>3.5%</td><td>3.5%</td>
        <td>7 to 29 Days</td>
        <td>3.5%</td><td>3.5%</td>
      </tr>
      <tr>
        <td>6.25%</td><td>6.75%</td>
        <td>1 Year to 389 Days</td>
        <td>6.5%</td><td>6.5%</td>
      </tr>
      <tr>
        <td>6.5% HIGHEST</td><td>7.1% HIGHEST</td>
        <td>3 Years 1 Day to 5 Years</td>
        <td>6.55% HIGHEST</td><td>6.55% HIGHEST</td>
      </tr>
    </table>
  </body></html>
  `;
  const res = iciciParser.parse(fixture, { sourceContentHash: 'b7'.repeat(32) });
  assert.strictEqual(res.success, true);
  assert.strictEqual(res.candidates.length, 12);
  assert.strictEqual(res.effectiveFrom, '2026-10-07');

  const callable = res.candidates.filter(c => c.isCallable);
  const nonCallable = res.candidates.filter(c => !c.isCallable);
  assert.strictEqual(callable.length, 6);
  assert.strictEqual(nonCallable.length, 6);

  // Highest badge cleaned
  const highestCand = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays >= 1095 && c.isCallable);
  assert.strictEqual(highestCand.interestRate, 6.5);
  assert.strictEqual(highestCand.rateCategory, 'STANDARD');
  assert.strictEqual(highestCand.schemeName, null);
});

console.log('\n======================================================================');
console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
console.log('======================================================================\n');

if (failed > 0) {
  process.exit(1);
}
