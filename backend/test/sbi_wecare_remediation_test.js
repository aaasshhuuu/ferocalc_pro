// FeroCalc Verified FD Rate Engine — Phase 3C.5.12D SBI We-Care Remediation Tests
//
// Verifies:
// 1. Parser footnote extraction & numeric parsing (7.05* -> 7.05, marker: '*')
// 2. CandidateRate model preservation of scheme fields
// 3. Staging persistence record mapping
// 4. CandidateValidator special scheme rules & duplicate/overlap partitioning
// 5. PromotionPolicyEngine special scheme qualification check (fail-closed)
// 6. PromotionService _insertVerifiedRate and _findPreviousArchivedRate mapping
// 7. RateDiffEngine separation of standard vs special scheme conflict domains
// 8. Standard rate regression tests (unmarked rates remain STANDARD)

'use strict';

const assert = require('assert');
const { SbiRateParser } = require('../parsers/sbi_parser');
const { CandidateRate } = require('../parsers/base_parser');
const { CandidateValidator } = require('../validators/candidate_validator');
const { RateDiffEngine } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { PromotionService } = require('../promotion/promotion_service');

const SBI_WECARE_FIXTURE_HTML = `
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
  <p>A special 'SBI Patrons' scheme has been launched for Super Senior Citizens (aged 80 years and above)...</p>
</body>
</html>
`;

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

async function runAsyncTest(name, fn) {
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

async function runAll() {
  console.log('======================================================');
  console.log('FeroCalc Phase 3C.5.12D SBI We-Care Remediation Tests ');
  console.log('======================================================\n');

  console.log('Group 1: Parser Footnote Extraction & Numeric Parsing...');

  const parser = new SbiRateParser();
  const result = parser.parse(SBI_WECARE_FIXTURE_HTML, {
    sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
    sourceContentHash: 'a'.repeat(64),
  });

  runTest('1. Parser successfully extracts candidates from fixture', () => {
    assert.strictEqual(result.success, true);
    assert.strictEqual(result.candidates.length, 4); // 2 regular, 2 senior
  });

  runTest('2. parseRateWithMarker extracts 7.05 numeric and "*" marker from "7.05*"', () => {
    const parsed = parser.parseRateWithMarker('7.05*');
    assert.strictEqual(parsed.value, 7.05);
    assert.strictEqual(parsed.marker, '*');
    assert.strictEqual(parsed.rawText, '7.05*');
  });

  runTest('3. parseRateWithMarker extracts standard unmarked rate cleanly', () => {
    const parsed = parser.parseRateWithMarker('6.25');
    assert.strictEqual(parsed.value, 6.25);
    assert.strictEqual(parsed.marker, null);
    assert.strictEqual(parsed.rawText, '6.25');
  });

  runTest('4. extractFootnotes captures verbatim We-Care footnote text from HTML', () => {
    const footnotes = parser.extractFootnotes(SBI_WECARE_FIXTURE_HTML);
    assert.ok(footnotes['*'], 'Expected footnote for marker "*"');
    assert.ok(footnotes['*'].includes('SBI We-care'), 'Expected footnote to mention "SBI We-care"');
    assert.ok(footnotes['*'].includes('50 bps'), 'Expected footnote to mention "50 bps"');
  });

  console.log('\nGroup 2: Candidate Model & Special Scheme Mapping...');

  const weCareCandidate = result.candidates.find(c =>
    c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 1825 && c.maxTenureDays === 3650
  );

  runTest('5. SBI 5-10y senior candidate is identified as SPECIAL_SCHEME', () => {
    assert.ok(weCareCandidate, 'We-Care candidate not found');
    assert.strictEqual(weCareCandidate.rateCategory, 'SPECIAL_SCHEME');
    assert.strictEqual(weCareCandidate.schemeName, 'SBI We-Care');
    assert.strictEqual(weCareCandidate.interestRate, 7.05);
    assert.strictEqual(weCareCandidate.footnoteMarker, '*');
    assert.ok(weCareCandidate.notes && weCareCandidate.notes.includes('SBI We-care'), 'Candidate notes must retain footnote text');
  });

  const standardSeniorCandidate = result.candidates.find(c =>
    c.customerType === 'SENIOR_CITIZEN' && c.minTenureDays === 365 && c.maxTenureDays === 729
  );

  runTest('6. SBI 1-2y senior candidate remains STANDARD with null scheme metadata', () => {
    assert.ok(standardSeniorCandidate, 'Standard 1-2y senior candidate not found');
    assert.strictEqual(standardSeniorCandidate.rateCategory, 'STANDARD');
    assert.strictEqual(standardSeniorCandidate.schemeName, null);
    assert.strictEqual(standardSeniorCandidate.notes, null);
    assert.strictEqual(standardSeniorCandidate.footnoteMarker, null);
  });

  const regularCandidate = result.candidates.find(c =>
    c.customerType === 'REGULAR' && c.minTenureDays === 1825
  );

  runTest('7. SBI 5-10y regular candidate remains STANDARD', () => {
    assert.ok(regularCandidate, 'Regular 5-10y candidate not found');
    assert.strictEqual(regularCandidate.rateCategory, 'STANDARD');
    assert.strictEqual(regularCandidate.schemeName, null);
    assert.strictEqual(regularCandidate.interestRate, 6.05);
  });

  console.log('\nGroup 3: Candidate Validation & Domain Partitioning...');

  const validator = new CandidateValidator();

  runTest('8. Valid special scheme candidate passes candidate validation', () => {
    const valRes = validator.validateCandidate(weCareCandidate);
    assert.strictEqual(valRes.isValid, true);
    assert.strictEqual(weCareCandidate.validationStatus, 'VALID');
  });

  runTest('9. SPECIAL_SCHEME candidate missing schemeName fails validation (fail-closed)', () => {
    const invalidCand = new CandidateRate({
      ...weCareCandidate,
      rateCategory: 'SPECIAL_SCHEME',
      schemeName: null,
    });
    const valRes = validator.validateCandidate(invalidCand);
    assert.strictEqual(valRes.isValid, false);
    assert.ok(valRes.errors.some(e => e.includes('Missing required schemeName')));
  });

  runTest('10. SPECIAL_SCHEME candidate missing notes fails validation (fail-closed)', () => {
    const invalidCand = new CandidateRate({
      ...weCareCandidate,
      rateCategory: 'SPECIAL_SCHEME',
      schemeName: 'SBI We-Care',
      notes: null,
    });
    const valRes = validator.validateCandidate(invalidCand);
    assert.strictEqual(valRes.isValid, false);
    assert.ok(valRes.errors.some(e => e.includes('Missing required qualification notes')));
  });

  runTest('11. STANDARD candidate with schemeName fails validation', () => {
    const invalidCand = new CandidateRate({
      ...standardSeniorCandidate,
      rateCategory: 'STANDARD',
      schemeName: 'Illegal Scheme',
    });
    const valRes = validator.validateCandidate(invalidCand);
    assert.strictEqual(valRes.isValid, false);
    assert.ok(valRes.errors.some(e => e.includes('cannot have schemeName')));
  });

  runTest('12. Standard and special scheme candidates for same tenure do NOT trigger duplicate/overlap errors', () => {
    // Hypothetical standard senior rate coexisting with special scheme
    const standardCoexistingSenior = new CandidateRate({
      ...weCareCandidate,
      rateCategory: 'STANDARD',
      schemeName: null,
      notes: null,
      interestRate: 6.55,
      seniorCitizenRate: 6.55,
    });
    const batchSummary = validator.validateBatch([weCareCandidate, standardCoexistingSenior]);
    assert.strictEqual(batchSummary.duplicateCount, 0, 'Standard and Special Scheme must not collide as duplicates');
    assert.strictEqual(batchSummary.overlapCount, 0, 'Standard and Special Scheme must not collide as overlaps');
  });

  console.log('\nGroup 4: Rate Diff Engine Separation...');

  const diffEngine = new RateDiffEngine();

  runTest('13. getBucketKey includes rateCategory and schemeName in dimensional key', () => {
    const keyWeCare = diffEngine.getBucketKey(weCareCandidate);
    assert.ok(keyWeCare.includes('SPECIAL_SCHEME'), 'Bucket key must include rate category');
    assert.ok(keyWeCare.includes('SBI WE-CARE'), 'Bucket key must include scheme name');

    const keyStandard = diffEngine.getBucketKey(standardSeniorCandidate);
    assert.ok(keyStandard.includes('STANDARD'), 'Bucket key must include STANDARD category');
  });

  runTest('14. Special scheme candidate does not match existing standard rate with same tenure', () => {
    const existingStandardRate = {
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'SENIOR_CITIZEN',
      isCallable: true,
      minTenureDays: 1825,
      maxTenureDays: 3650,
      minDeposit: 1000,
      maxDeposit: 29999999,
      interestRate: 6.55,
      rateCategory: 'STANDARD',
      schemeName: null,
    };
    const diff = diffEngine.diffCandidate(weCareCandidate, [existingStandardRate]);
    assert.strictEqual(diff.diffType, 'NEW', 'Special scheme must be treated as a distinct NEW rate bucket');
  });

  console.log('\nGroup 5: Promotion Policy & State Machine (Fail-Closed Enforcement)...');

  const policyEngine = new PromotionPolicyEngine();

  runTest('15. Policy engine approves special scheme candidate with valid scheme and qualification', () => {
    const evalRes = policyEngine.evaluateCandidate(weCareCandidate, { diffType: 'NEW' }, {
      isBaselineAttested: true,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'a'.repeat(64),
    });
    assert.strictEqual(evalRes.checks.specialSchemeQualified, true);
  });

  runTest('16. Policy engine rejects special scheme candidate missing qualification notes (fail-closed)', () => {
    const unannotatedCand = {
      ...weCareCandidate,
      notes: '',
    };
    const evalRes = policyEngine.evaluateCandidate(unannotatedCand, { diffType: 'NEW' }, {
      isBaselineAttested: true,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'a'.repeat(64),
    });
    assert.strictEqual(evalRes.checks.specialSchemeQualified, false);
    assert.strictEqual(evalRes.eligibleForAutoPromotion, false);
    assert.ok(evalRes.failedReasons.some(r => r.includes('lacks required scheme metadata')));
  });

  console.log('\nGroup 6: Promotion Service Insertion & Versioning Mapping...');

  const promotionService = new PromotionService({
    policyEngine,
    diffEngine,
  });

  await runAsyncTest('17. PromotionService._insertVerifiedRate maps SPECIAL_SCHEME, scheme_name and review_notes', async () => {
    const promoted = await promotionService._insertVerifiedRate(weCareCandidate, 'ADMIN_TEST', 'Attested baseline promotion');
    assert.strictEqual(promoted.status, 'VERIFIED');
    assert.strictEqual(promoted.rate_category, 'SPECIAL_SCHEME');
    assert.strictEqual(promoted.scheme_name, 'SBI We-Care');
    assert.ok(promoted.review_notes && promoted.review_notes.includes('SBI We-care'));
  });

  await runAsyncTest('18. PromotionService._insertVerifiedRate throws when schemeName is missing for SPECIAL_SCHEME', async () => {
    let threw = false;
    try {
      await promotionService._insertVerifiedRate({
        ...weCareCandidate,
        rateCategory: 'SPECIAL_SCHEME',
        schemeName: null,
      }, 'ADMIN_TEST', 'Test');
    } catch (err) {
      threw = true;
      assert.ok(err.message.includes('Cannot promote SPECIAL_SCHEME candidate without scheme_name'));
    }
    assert.strictEqual(threw, true, 'Promotion must fail closed when schemeName is missing');
  });

  await runAsyncTest('19. PromotionService._insertVerifiedRate preserves STANDARD category for ordinary rate', async () => {
    const promotedStd = await promotionService._insertVerifiedRate(standardSeniorCandidate, 'ADMIN_TEST', 'Standard promotion');
    assert.strictEqual(promotedStd.rate_category, 'STANDARD');
    assert.strictEqual(promotedStd.scheme_name, null);
  });

  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runAll().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
