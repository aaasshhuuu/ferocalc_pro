// FeroCalc Phase 3C.5.38 — SBI Qualified Senior-Rate Parser Regression Test Suite
//
// Regression tests verifying:
// 1. Unmarked standard senior rates continue to populate regular candidate seniorCitizenRate
// 2. Qualified SBI We-Care senior cell (7.05*) does NOT leak into regular candidate seniorCitizenRate (remains null)
// 3. Senior scheme candidate remains SPECIAL_SCHEME with schemeName='SBI We-Care' and qualification notes
// 4. Parsing a deterministic synthetic table fixture reproduces expected classification across all 16 candidates
// 5. Existing approved rates and tenure boundaries for REV_001–REV_015 remain 100% concordant
// 6. Ambiguous or malformed qualification markers fail closed rather than treating promotional rates as standard
// 7. Whitespace variations (&nbsp;, tabs, trailing spaces) are handled safely without leakage
// 8. Quarantined scheme candidate (REV_016) remains strictly excluded from the approved Batch 1A candidate set

'use strict';

const assert = require('assert');
const { SbiRateParser } = require('../parsers/sbi_parser');
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
console.log('FeroCalc Phase 3C.5.38 SBI Qualified Senior-Rate Parser Regression Tests');
console.log('======================================================================\n');

const parser = new SbiRateParser();
const validator = new CandidateValidator();

// ------------------------------------------------------------------
// Group 1: Standard vs. Qualified Senior Rate Differentiation
// ------------------------------------------------------------------
console.log('Group 1: Standard vs. Qualified Senior Rate Differentiation...');

const STANDARD_FIXTURE_HTML = `
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

const resFixture = parser.parse(STANDARD_FIXTURE_HTML, {
  sourceId: 'sbi-retail-domestic',
  sourceUrl: 'https://sbi.co.in/rates',
  sourceContentHash: 'a'.repeat(64),
});

runTest('1. Unmarked standard senior rate (7-45d) populates regular candidate seniorCitizenRate', () => {
  const reg7d = resFixture.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 7);
  assert.ok(reg7d, 'Regular 7-45d candidate not found');
  assert.strictEqual(reg7d.interestRate, 3.05);
  assert.strictEqual(reg7d.seniorCitizenRate, 3.55);
  assert.strictEqual(reg7d.rateCategory, 'STANDARD');
  assert.strictEqual(reg7d.schemeName, null);
});

runTest('2. Unmarked standard senior rate (1-2y) populates regular candidate seniorCitizenRate', () => {
  const reg1y = resFixture.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 365);
  assert.ok(reg1y, 'Regular 1-2y candidate not found');
  assert.strictEqual(reg1y.interestRate, 6.25);
  assert.strictEqual(reg1y.seniorCitizenRate, 6.75);
  assert.strictEqual(reg1y.rateCategory, 'STANDARD');
});

runTest('3. Qualified SBI We-Care senior cell (7.05*) does NOT leak into 5-10y regular candidate (seniorCitizenRate === null)', () => {
  const reg5y = resFixture.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 1825);
  assert.ok(reg5y, 'Regular 5-10y candidate not found');
  assert.strictEqual(reg5y.interestRate, 6.05, 'Regular interest rate must remain 6.05%');
  assert.strictEqual(reg5y.seniorCitizenRate, null, 'Senior citizen rate must be null (no 7.05% promotional leakage)');
  assert.strictEqual(reg5y.rateCategory, 'STANDARD', 'Regular candidate must remain STANDARD');
  assert.strictEqual(reg5y.schemeName, null, 'Regular candidate must have schemeName=null');
});

runTest('4. Corresponding 5-10y senior candidate is marked SPECIAL_SCHEME with SBI We-Care identity', () => {
  const sen5y = resFixture.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 1825);
  assert.ok(sen5y, 'Senior 5-10y candidate not found');
  assert.strictEqual(sen5y.interestRate, 7.05);
  assert.strictEqual(sen5y.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen5y.schemeName, 'SBI We-Care');
  assert.ok(sen5y.notes && sen5y.notes.includes('SBI We-care'), 'Must contain We-Care qualification footnote');
});

// ------------------------------------------------------------------
// Group 2: Saved Official Synthetic Fixture Parsing & Batch Reconciliation
// ------------------------------------------------------------------
console.log('\nGroup 2: Official Snapshot Parsing & Parity...');

// Deterministic synthetic fixture for parser classification and rate-field mapping.
// Values below are test inputs; this fixture is not an official SBI evidence snapshot.
const SBI_BATCH_1A_FIXTURE_HTML = `
<html>
<body>
  <table>
    <tr>
      <th>Tenors</th>
      <th>Revised Rates for Public w.e.f. 15/12/2025</th>
      <th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th>
    </tr>
    <tr><td>7 days to 45 days</td><td>3.05</td><td>3.55</td></tr>
    <tr><td>46 days to 179 days</td><td>4.90</td><td>5.40</td></tr>
    <tr><td>180 days to 364 days</td><td>5.65</td><td>6.15</td></tr>
    <tr><td>365 days to 729 days</td><td>5.90</td><td>6.40</td></tr>
    <tr><td>730 days to 1094 days</td><td>6.25</td><td>6.75</td></tr>
    <tr><td>1095 days to 1459 days</td><td>6.40</td><td>6.90</td></tr>
    <tr><td>1460 days to 1824 days</td><td>6.30</td><td>6.80</td></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>7.05*</td></tr>
  </table>
  <p>* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.</p>
</body>
</html>
`;

const fixtureHash = require('crypto').createHash('sha256').update(SBI_BATCH_1A_FIXTURE_HTML, 'utf8').digest('hex');
const fixtureResult = parser.parse(SBI_BATCH_1A_FIXTURE_HTML, {
  sourceId: 'sbi-retail-domestic',
  sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
  sourceContentHash: fixtureHash,
});

runTest('5. Synthetic fixture produces exactly 16 candidates (8 regular + 8 senior)', () => {
  assert.strictEqual(fixtureResult.success, true);
  assert.strictEqual(fixtureResult.candidates.length, 16);
});

runTest('6. Fixture rows 1-7 regular candidates preserve co-published standard senior rates', () => {
  const expectedStandardSeniorRates = [3.55, 5.40, 6.15, 6.40, 6.75, 6.90, 6.80];
  const regularSlabs1to7 = fixtureResult.candidates.filter(c => c.customerType === 'REGULAR' && c.minTenureDays < 1825);
  assert.strictEqual(regularSlabs1to7.length, 7);

  regularSlabs1to7.forEach((c, idx) => {
    assert.strictEqual(c.seniorCitizenRate, expectedStandardSeniorRates[idx], `Slab ${idx + 1} regular seniorCitizenRate mismatch`);
    assert.strictEqual(c.rateCategory, 'STANDARD');
    assert.strictEqual(c.schemeName, null);
  });
});

runTest('7. Fixture final row regular candidate (REV_015) has interestRate=6.05 and seniorCitizenRate=null', () => {
  const regSlab8 = fixtureResult.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 1825);
  assert.ok(regSlab8);
  assert.strictEqual(regSlab8.interestRate, 6.05);
  assert.strictEqual(regSlab8.seniorCitizenRate, null, 'Must NOT leak 7.05% into regular candidate');
  assert.strictEqual(regSlab8.rateCategory, 'STANDARD');
  assert.strictEqual(regSlab8.schemeName, null);
});

runTest('8. Fixture final row senior candidate (REV_016) has interestRate=7.05 and SPECIAL_SCHEME', () => {
  const senSlab8 = fixtureResult.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 1825);
  assert.ok(senSlab8);
  assert.strictEqual(senSlab8.interestRate, 7.05);
  assert.strictEqual(senSlab8.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(senSlab8.schemeName, 'SBI We-Care');
});

runTest('9. Standard card rates (rateCategory === "STANDARD") yield exactly the 15 approved Batch 1A candidates', () => {
  const standardCandidates = fixtureResult.candidates.filter(c => c.rateCategory === 'STANDARD');
  assert.strictEqual(standardCandidates.length, 15, 'Exactly 15 STANDARD candidates must be produced');

  // Quarantined candidate 16 is excluded
  const specialCandidates = fixtureResult.candidates.filter(c => c.rateCategory === 'SPECIAL_SCHEME');
  assert.strictEqual(specialCandidates.length, 1, 'Exactly 1 SPECIAL_SCHEME candidate produced');
  assert.strictEqual(specialCandidates[0].schemeName, 'SBI We-Care');
});

// ------------------------------------------------------------------
// Group 3: Whitespace, Formatting & Malformed Marker Safety (Fail-Closed)
// ------------------------------------------------------------------
console.log('\nGroup 3: Formatting & Malformed Marker Safety (Fail-Closed)...');

runTest('10. Whitespace variations (&nbsp;, tabs, padded asterisk) do NOT leak promotional rate', () => {
  const htmlWhitespace = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public w.e.f.15/12/2025</th><th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>&nbsp; 7.05 * &nbsp;</td></tr>
  </table>
  <p>* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.</p>
  `;
  const res = parser.parse(htmlWhitespace, { sourceContentHash: 'b'.repeat(64) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  assert.ok(reg);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Padded/NBSP asterisk must not leak');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');
  assert.ok(sen);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, 'SBI We-Care');
});

runTest('11. Ambiguous qualification marker on non-WeCare slab fails closed without treating rate as standard', () => {
  const htmlAmbiguous = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public w.e.f.15/12/2025</th><th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th></tr>
    <tr><td>1 Year to less than 2 years</td><td>6.25</td><td>6.75*</td></tr>
  </table>
  <!-- No footnote provided -->
  `;
  const res = parser.parse(htmlAmbiguous, { sourceContentHash: 'c'.repeat(64) });

  // 1. Regular candidate must NOT inherit 6.75* as an unqualified standard senior rate
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  assert.ok(reg);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Ambiguous marked senior rate must not populate regular candidate');

  // 2. Senior candidate must NOT be treated as STANDARD
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');
  assert.ok(sen);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null, 'Unresolved schemeName must remain null');

  // 3. Fails closed in CandidateValidator under Rule 7
  const valRes = validator.validateCandidate(sen);
  assert.strictEqual(valRes.isValid, false, 'Candidate with unresolved SPECIAL_SCHEME must fail validation');
  assert.ok(valRes.errors.some(e => e.includes('Missing required schemeName')));
});

runTest('12. Alternative qualification marker (#) fails closed without leaking into regular candidate', () => {
  const htmlAltMarker = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public w.e.f.15/12/2025</th><th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th></tr>
    <tr><td>2 years to less than 3 years</td><td>6.40</td><td>6.90#</td></tr>
  </table>
  `;
  const res = parser.parse(htmlAltMarker, { sourceContentHash: 'd'.repeat(64) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  assert.ok(reg);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Senior rate marked with # must not leak into regular candidate');

  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');
  assert.ok(sen);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null);
});

// ------------------------------------------------------------------
// Group 4: Batch 1A Concordance with Remediated Staging Row
// ------------------------------------------------------------------
console.log('\nGroup 4: Batch 1A Concordance & Non-Inferrence Guard...');

runTest('13. Parser does NOT infer 6.55% when senior rate is null', () => {
  const reg5y = fixtureResult.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 1825);
  assert.strictEqual(reg5y.seniorCitizenRate, null);
  assert.notStrictEqual(reg5y.seniorCitizenRate, 6.55, 'Must not infer 6.55%');
});

runTest('14. Parsed 5-10y regular candidate matches the remediated staging row state (REV_015)', () => {
  const reg5y = fixtureResult.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 1825);
  assert.strictEqual(reg5y.bankCode, 'SBI');
  assert.strictEqual(reg5y.productType, 'RETAIL_DOMESTIC_TERM_DEPOSIT');
  assert.strictEqual(reg5y.customerType, 'REGULAR');
  assert.strictEqual(reg5y.minTenureDays, 1825);
  assert.strictEqual(reg5y.maxTenureDays, 3650);
  assert.strictEqual(reg5y.interestRate, 6.05);
  assert.strictEqual(reg5y.seniorCitizenRate, null);
  assert.strictEqual(reg5y.rateCategory, 'STANDARD');
  assert.strictEqual(reg5y.schemeName, null);
  assert.strictEqual(reg5y.isCallable, true);
});

// ------------------------------------------------------------------
// Group 5: Phase 3C.5.39 Adversarial Marker & Footnote Classification Audit
// ------------------------------------------------------------------
console.log('\nGroup 5: Phase 3C.5.39 Adversarial Marker & Footnote Classification Audit...');

// Scenario 1: Documented SBI We-Care marker and positively identified We-Care footnote
runTest('15. Scenario 1: Documented We-Care marker (*) + positive footnote classifies as SBI We-Care', () => {
  const htmlScen1 = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public</th><th>Revised Rates for Senior Citizen</th></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>7.05*</td></tr>
  </table>
  <p>* Including additional premium of 50 bps under 'SBI We-care' deposit scheme.</p>
  `;
  const res = parser.parse(htmlScen1, { sourceContentHash: '1'.repeat(64) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(reg && sen);
  // Regular candidate remains STANDARD card rate with no leakage
  assert.strictEqual(reg.interestRate, 6.05);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Must NOT leak into regular seniorCitizenRate');
  assert.strictEqual(reg.rateCategory, 'STANDARD');
  assert.strictEqual(reg.schemeName, null);

  // Senior candidate is positively identified as SBI We-Care
  assert.strictEqual(sen.interestRate, 7.05);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, 'SBI We-Care');
  assert.ok(sen.notes && sen.notes.includes('SBI We-care'));

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, true, 'Positively identified We-Care candidate must pass validation');
});

// Scenario 2: Unknown marker (#) on 5-10y slab with no known We-Care footnote -> fails closed
runTest('16. Scenario 2: Unknown marker (#) on 5-10y slab fails closed (schemeName=null, fails validation)', () => {
  const htmlScen2 = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public</th><th>Revised Rates for Senior Citizen</th></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>7.05#</td></tr>
  </table>
  <p># Rates applicable for new accounts only.</p>
  `;
  const res = parser.parse(htmlScen2, { sourceContentHash: '2'.repeat(64) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(reg && sen);
  // Regular candidate has no senior rate leakage
  assert.strictEqual(reg.interestRate, 6.05);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Unknown marker must not leak into regular candidate');
  assert.strictEqual(reg.rateCategory, 'STANDARD');

  // Senior candidate must NOT be labelled SBI We-Care; fails closed with schemeName=null
  assert.strictEqual(sen.interestRate, 7.05);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null, 'Unknown marker MUST fail closed with schemeName=null');
  assert.strictEqual(sen.notes, '# Rates applicable for new accounts only.');

  // CandidateValidator fails closed on Rule 7
  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, false, 'Unresolved SPECIAL_SCHEME candidate must fail validation');
  assert.ok(valSen.errors.some(e => e.includes('Missing required schemeName')));

  // Error is logged
  assert.ok(res.errors.some(e => e.includes('could not be positively identified to a valid scheme (fail-closed)')));
});

// Scenario 3: Different known marker (^) mapped to a different scheme (Amrit Vrishti)
runTest('17. Scenario 3: Marker (^) mapped to different known scheme (Amrit Vrishti) resolves accurately', () => {
  const htmlScen3 = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public</th><th>Revised Rates for Senior Citizen</th></tr>
    <tr><td>444 Days</td><td>7.25</td><td>7.75^</td></tr>
  </table>
  <p>^ Specific tenure scheme 'Amrit Vrishti' at 7.75% for senior citizens.</p>
  `;
  const res = parser.parse(htmlScen3, { sourceContentHash: '3'.repeat(64) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(reg && sen);
  assert.strictEqual(reg.interestRate, 7.25);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Special scheme rate must not leak into regular candidate');

  assert.strictEqual(sen.interestRate, 7.75);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, 'Amrit Vrishti', 'Must resolve to Amrit Vrishti');
  assert.ok(sen.notes && sen.notes.includes('Amrit Vrishti'));

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, true, 'Positively identified Amrit Vrishti must pass validation');
});

// Scenario 4: Malformed or contradictory footnote (* on 5-10y slab with non-WeCare footnote) -> fails closed
runTest('18. Scenario 4: Contradictory footnote (* on 5-10y slab) fails closed (schemeName=null, not We-Care)', () => {
  const htmlScen4 = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public</th><th>Revised Rates for Senior Citizen</th></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>7.05*</td></tr>
  </table>
  <p>* Rates subject to revision without prior notice.</p>
  `;
  const res = parser.parse(htmlScen4, { sourceContentHash: '4'.repeat(64) });
  const reg = res.candidates.find(c => c.customerType === 'REGULAR');
  const sen = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN');

  assert.ok(reg && sen);
  assert.strictEqual(reg.seniorCitizenRate, null, 'Contradictory marked senior cell must not leak into regular candidate');

  // Must NOT classify as SBI We-Care simply because slab is 5-10y!
  assert.strictEqual(sen.interestRate, 7.05);
  assert.strictEqual(sen.rateCategory, 'SPECIAL_SCHEME');
  assert.strictEqual(sen.schemeName, null, 'Contradictory footnote must NOT be labelled SBI We-Care');
  assert.strictEqual(sen.notes, '* Rates subject to revision without prior notice.');

  const valSen = validator.validateCandidate(sen);
  assert.strictEqual(valSen.isValid, false, 'Unresolved candidate must fail validation');
  assert.ok(valSen.errors.some(e => e.includes('Missing required schemeName')));
});

// Scenario 5: Unmarked standard senior rate on normal slab and on 5-10y slab without marker/footnote
runTest('19. Scenario 5: Unmarked standard senior rate on normal slab populates seniorCitizenRate', () => {
  const htmlScen5 = `
  <table>
    <tr><th>Tenors</th><th>Revised Rates for Public</th><th>Revised Rates for Senior Citizen</th></tr>
    <tr><td>1 Year to less than 2 years</td><td>6.25</td><td>6.75</td></tr>
    <tr><td>5 years and up to 10 years</td><td>6.05</td><td>6.55</td></tr>
  </table>
  `;
  const res = parser.parse(htmlScen5, { sourceContentHash: '5'.repeat(64) });

  // 1. Normal slab (1-2y)
  const reg1y = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 365);
  const sen1y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 365);
  assert.ok(reg1y && sen1y);
  assert.strictEqual(reg1y.interestRate, 6.25);
  assert.strictEqual(reg1y.seniorCitizenRate, 6.75);
  assert.strictEqual(reg1y.rateCategory, 'STANDARD');
  assert.strictEqual(sen1y.interestRate, 6.75);
  assert.strictEqual(sen1y.rateCategory, 'STANDARD');
  assert.strictEqual(sen1y.schemeName, null);

  // 2. 5-10y slab without qualification marker is treated as standard (not falsely assumed We-Care)
  const reg5y = res.candidates.find(c => c.customerType === 'REGULAR' && c.minTenureDays === 1825);
  const sen5y = res.candidates.find(c => c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 1825);
  assert.ok(reg5y && sen5y);
  assert.strictEqual(reg5y.interestRate, 6.05);
  assert.strictEqual(reg5y.seniorCitizenRate, 6.55);
  assert.strictEqual(reg5y.rateCategory, 'STANDARD');
  assert.strictEqual(sen5y.interestRate, 6.55);
  assert.strictEqual(sen5y.rateCategory, 'STANDARD');
  assert.strictEqual(sen5y.schemeName, null);
});

console.log('\n======================================================================');
console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
console.log('======================================================================\n');

if (failed > 0) {
  process.exit(1);
}
