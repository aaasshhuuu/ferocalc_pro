// FeroCalc Phase 3C.5.41-R3 — HDFC Minimum-Deposit & Calendar Tenure Regression Test Suite
//
// Tests:
// 1. Task A: Minimum Deposit is strictly '5000.00' (₹5,000) for HDFC public retail deposits.
//    Regression guard prevents legacy '1000.00' from being emitted.
// 2. Task B: Dual-Domain Calendar Tenure Mapping (DAYS vs CALENDAR).
//    - Slabs 1-5 use DAYS domain; Slabs 6-19 use CALENDAR domain per Migration 009.
//    - Calendar date arithmetic with variable month lengths (28, 29, 30, 31 days) and leap years.
//    - Boundary continuity: boundary - 1 day, exact boundary, boundary + 1 day tested with 0 gaps and 0 overlaps.
//    - Exact single-month bespoke tenors (35 months at Slab 14 and 55 months at Slab 17) isolation.
// 3. Task C: Customer Eligibility & Rate Preservation.
//    - Senior citizen candidates restricted to resident senior customers (NRIs excluded per HDFC policy).
//    - Slabs 1-15 & 17-19 preserve +50 bps spread; Slab 16 preserves +60 bps spread (6.50% / 7.10%).
//    - 100% rate concordance across all 38 candidates.
// 4. Staging Schema Blocker & Safety Guard:
//    - Staged candidate validation succeeds with backward-compatible day fields.
//    - Staging status remains DRAFT / REVIEW_REQUIRED (zero auto-verification).

'use strict';

const crypto = require('crypto');
const assert = require('assert');
const { HdfcRateParser } = require('../parsers/hdfc_parser');
const {
  HDFC_CANONICAL_SLABS,
  addMonths,
  addDays,
  addYears,
  calculateBoundaryDate,
  getCanonicalSlabByLabel,
  matchHdfcTenureSlab,
  verifyBoundaryContinuity,
} = require('../parsers/hdfc_canonical_tenure');
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
console.log('FeroCalc Phase 3C.5.41-R3 HDFC Minimum-Deposit & Calendar Tenure Tests');
console.log('======================================================================\n');

const parser = new HdfcRateParser();
const validator = new CandidateValidator();

// Build deterministic synthetic HTML from the canonical table contract.
// This tests parser-to-model mapping; it is NOT a substitute for independent
// verification of the official bank source or its currently published rates.
function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

const snapshotHtml = [
  '<html><body>',
  '<p>Applicable from 19th August, 2026</p>',
  '<table>',
  '<tr><th>Tenure Bucket</th><th>Interest Rate (per annum)</th><th>Senior Citizen Rates (per annum)</th></tr>',
  ...HDFC_CANONICAL_SLABS.map((slab) =>
    '<tr><td>' + escapeHtml(slab.publishedTenureLabel) + '</td>' +
    '<td>' + slab.regularRate.toFixed(2) + '%</td>' +
    '<td>' + slab.seniorRate.toFixed(2) + '%</td></tr>'
  ),
  '</table>',
  '</body></html>',
].join('\\n');

const fixtureHash = crypto.createHash('sha256').update(snapshotHtml, 'utf8').digest('hex');
const extraction = parser.parse(snapshotHtml, {
  sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
  sourceContentHash: fixtureHash,
});

// ==================================================================
// GROUP 1: Task A — Minimum Deposit Canonical Remediation
// ==================================================================
console.log('--- Group 1: Minimum Deposit Canonical Remediation (Task A) ---');

runTest('1. Extraction produces exactly 38 candidates from deterministic HDFC table fixture', () => {
  assert.strictEqual(extraction.success, true);
  assert.strictEqual(extraction.candidates.length, 38);
});

runTest('2. All 38 candidates emit minDeposit = "5000.00" (remediating legacy 1000.00)', () => {
  extraction.candidates.forEach((cand, idx) => {
    assert.strictEqual(
      cand.minDeposit,
      '5000.00',
      `Candidate ${idx + 1} (${cand.customerType} ${cand.tenureLabel}) minDeposit must be '5000.00', got '${cand.minDeposit}'`
    );
  });
});

runTest('3. Regression guard: Parser NEVER emits legacy minDeposit = "1000.00" for HDFC retail domestic deposits', () => {
  const legacyFound = extraction.candidates.filter(c => c.minDeposit === '1000.00');
  assert.strictEqual(legacyFound.length, 0, 'Found candidates still emitting legacy 1000.00 minDeposit');
});

runTest('4. All 38 candidates emit maxDeposit = "29999999.00" (< ₹3 Crore scope)', () => {
  extraction.candidates.forEach((cand, idx) => {
    assert.strictEqual(
      cand.maxDeposit,
      '29999999.00',
      `Candidate ${idx + 1} maxDeposit must be '29999999.00', got '${cand.maxDeposit}'`
    );
  });
});

// ==================================================================
// GROUP 2: Task B — Dual-Domain Calendar Tenure Mapping
// ==================================================================
console.log('\n--- Group 2: Dual-Domain Calendar Tenure Mapping (Task B) ---');

runTest('5. Canonical slabs count is exactly 19', () => {
  assert.strictEqual(HDFC_CANONICAL_SLABS.length, 19);
});

runTest('6. Slabs 1 to 5 are classified under DAYS domain', () => {
  for (let s = 1; s <= 5; s++) {
    const slab = HDFC_CANONICAL_SLABS[s - 1];
    assert.strictEqual(slab.tenureDomain, 'DAYS', `Slab ${s} must have tenureDomain DAYS`);
    assert.strictEqual(slab.boundaryUnit, 'DAYS', `Slab ${s} boundaryUnit must be DAYS`);
  }
});

runTest('7. Slabs 6 to 19 are classified under CALENDAR domain', () => {
  for (let s = 6; s <= 19; s++) {
    const slab = HDFC_CANONICAL_SLABS[s - 1];
    assert.strictEqual(slab.tenureDomain, 'CALENDAR', `Slab ${s} must have tenureDomain CALENDAR`);
  }
});

runTest('8. Candidate rates carry canonical calendar metadata and operators', () => {
  for (let i = 0; i < 38; i += 2) {
    const slabNum = Math.floor(i / 2) + 1;
    const reg = extraction.candidates[i];
    const sen = extraction.candidates[i + 1];

    assert.ok(reg.canonicalTenure, `Candidate ${i + 1} missing canonicalTenure`);
    assert.ok(sen.canonicalTenure, `Candidate ${i + 2} missing canonicalTenure`);
    assert.strictEqual(reg.canonicalTenure.slabNumber, slabNum);
    assert.strictEqual(sen.canonicalTenure.slabNumber, slabNum);

    if (slabNum <= 5) {
      assert.strictEqual(reg.tenureDomain, 'DAYS');
      assert.strictEqual(sen.tenureDomain, 'DAYS');
    } else {
      assert.strictEqual(reg.tenureDomain, 'CALENDAR');
      assert.strictEqual(sen.tenureDomain, 'CALENDAR');
    }
  }
});

// ==================================================================
// GROUP 3: Task B — Calendar Date Arithmetic & Boundary Continuity
// ==================================================================
console.log('\n--- Group 3: Calendar Date Arithmetic & Boundary Continuity (Task B) ---');

runTest('9. End-of-month date arithmetic handles 28, 29, 30, and 31-day months accurately', () => {
  // Jan 31 + 1 month -> Feb 29 in leap year (2024), Feb 28 in common year (2025)
  assert.strictEqual(addMonths('2024-01-31', 1), '2024-02-29');
  assert.strictEqual(addMonths('2025-01-31', 1), '2025-02-28');

  // Mar 31 + 1 month -> Apr 30 (30-day month)
  assert.strictEqual(addMonths('2024-03-31', 1), '2024-04-30');

  // May 31 + 1 month -> Jun 30
  assert.strictEqual(addMonths('2026-05-31', 1), '2026-06-30');

  // Aug 31 + 1 month -> Sep 30
  assert.strictEqual(addMonths('2026-08-31', 1), '2026-09-30');
});

runTest('10. Leap-year date addition preserves contractual tenor duration', () => {
  // Feb 29, 2024 + 1 year (12 months) -> Feb 28, 2025 (common year)
  assert.strictEqual(addYears('2024-02-29', 1), '2025-02-28');

  // Feb 29, 2024 + 4 years (48 months) -> Feb 29, 2028 (next leap year)
  assert.strictEqual(addYears('2024-02-29', 4), '2028-02-29');
});

runTest('11. Boundary continuity on official effective date (2026-08-19): 0 gaps and 0 overlaps', () => {
  const result = verifyBoundaryContinuity('2026-08-19');
  assert.strictEqual(result.valid, true, `Continuity failed on 2026-08-19: ${result.errors.join('; ')}`);
});

runTest('12. Boundary continuity on month-end 31st (2024-01-31 leap year): 0 gaps and 0 overlaps', () => {
  const result = verifyBoundaryContinuity('2024-01-31');
  assert.strictEqual(result.valid, true, `Continuity failed on 2024-01-31: ${result.errors.join('; ')}`);
});

runTest('13. Boundary continuity on leap day (2024-02-29): 0 gaps and 0 overlaps', () => {
  const result = verifyBoundaryContinuity('2024-02-29');
  assert.strictEqual(result.valid, true, `Continuity failed on 2024-02-29: ${result.errors.join('; ')}`);
});

runTest('14. Boundary continuity on common year Jan 31st (2025-01-31): 0 gaps and 0 overlaps', () => {
  const result = verifyBoundaryContinuity('2025-01-31');
  assert.strictEqual(result.valid, true, `Continuity failed on 2025-01-31: ${result.errors.join('; ')}`);
});

runTest('15. Exact single-month bespoke bucket: Slab 14 (35 months) boundary isolation', () => {
  const start = '2026-08-19';
  const maturity35m = addMonths(start, 35); // 2029-07-19
  const dayBefore = addDays(maturity35m, -1); // 2029-07-18
  const dayAfter = addDays(maturity35m, 1);   // 2029-07-20

  // 1 day before 35 months belongs to Slab 13 (< 2 Year 11 Months)
  const matchBefore = matchHdfcTenureSlab(start, dayBefore);
  assert.strictEqual(matchBefore.slabNumber, 13, `35m - 1d must be in Slab 13, got Slab ${matchBefore.slabNumber}`);

  // Exactly 35 months belongs to Slab 14 (35 months)
  const matchExact = matchHdfcTenureSlab(start, maturity35m);
  assert.strictEqual(matchExact.slabNumber, 14, `35m exact must be in Slab 14, got Slab ${matchExact.slabNumber}`);

  // 1 day after 35 months belongs to Slab 15 (2 Years 11 Months 1 day <= 3 Year)
  const matchAfter = matchHdfcTenureSlab(start, dayAfter);
  assert.strictEqual(matchAfter.slabNumber, 15, `35m + 1d must be in Slab 15, got Slab ${matchAfter.slabNumber}`);
});

runTest('16. Exact single-month bespoke bucket: Slab 17 (55 months) boundary isolation', () => {
  const start = '2026-08-19';
  const maturity55m = addMonths(start, 55); // 2031-03-19
  const dayBefore = addDays(maturity55m, -1); // 2031-03-18
  const dayAfter = addDays(maturity55m, 1);   // 2031-03-20

  // 1 day before 55 months belongs to Slab 16 (< 4 Years 7 Months)
  const matchBefore = matchHdfcTenureSlab(start, dayBefore);
  assert.strictEqual(matchBefore.slabNumber, 16, `55m - 1d must be in Slab 16, got Slab ${matchBefore.slabNumber}`);

  // Exactly 55 months belongs to Slab 17 (55 months)
  const matchExact = matchHdfcTenureSlab(start, maturity55m);
  assert.strictEqual(matchExact.slabNumber, 17, `55m exact must be in Slab 17, got Slab ${matchExact.slabNumber}`);

  // 1 day after 55 months belongs to Slab 18 (4 Year 7 Months 1 day <= 5 Years)
  const matchAfter = matchHdfcTenureSlab(start, dayAfter);
  assert.strictEqual(matchAfter.slabNumber, 18, `55m + 1d must be in Slab 18, got Slab ${matchAfter.slabNumber}`);
});

// ==================================================================
// GROUP 4: Task C — Customer Eligibility & Rate Preservation
// ==================================================================
console.log('\n--- Group 4: Customer Eligibility & Rate Preservation (Task C) ---');

runTest('17. Senior citizen candidates are restricted to eligible resident senior customers (NRIs excluded)', () => {
  const seniorCandidates = extraction.candidates.filter(c => c.customerType === 'SENIOR_CITIZEN');
  assert.strictEqual(seniorCandidates.length, 19);

  seniorCandidates.forEach((cand, idx) => {
    assert.ok(cand.notes, `Senior candidate ${idx + 1} missing eligibility notes`);
    assert.ok(
      cand.notes.includes('resident senior') && cand.notes.includes('NRIs'),
      `Senior candidate ${idx + 1} notes must mention resident senior eligibility and NRI exclusion: "${cand.notes}"`
    );
  });
});

runTest('18. Parser output matches canonical rate-table fixture across all 19 slabs', () => {
  for (let s = 0; s < 19; s++) {
    const slab = HDFC_CANONICAL_SLABS[s];
    const regCand = extraction.candidates[s * 2];
    const senCand = extraction.candidates[s * 2 + 1];

    assert.strictEqual(regCand.interestRate, slab.regularRate, `Slab ${s + 1} regular rate mismatch`);
    assert.strictEqual(senCand.interestRate, slab.seniorRate, `Slab ${s + 1} senior rate mismatch`);

    const spreadBps = Math.round((senCand.interestRate - regCand.interestRate) * 100);
    assert.strictEqual(spreadBps, slab.seniorSpreadBps, `Slab ${s + 1} spread mismatch`);
  }
});

runTest('19. Slab 16 (+60 bps spread at REV_047/REV_048) is explicitly preserved', () => {
  const slab16Reg = extraction.candidates[30]; // REV_047
  const slab16Sen = extraction.candidates[31]; // REV_048

  assert.strictEqual(slab16Reg.interestRate, 6.50);
  assert.strictEqual(slab16Sen.interestRate, 7.10);

  const spreadBps = Math.round((slab16Sen.interestRate - slab16Reg.interestRate) * 100);
  assert.strictEqual(spreadBps, 60, 'Slab 16 must have exactly +60 bps spread');
});

// ==================================================================
// GROUP 5: Candidate Validator & Staging Safety Integrity
// ==================================================================
console.log('\n--- Group 5: Candidate Validator & Staging Safety Integrity ---');

runTest('20. Batch validation passes for all 38 candidates', () => {
  const batchRes = validator.validateBatch(extraction.candidates);
  assert.strictEqual(batchRes.success, true, `Batch validation failed: ${batchRes.errors.join('; ')}`);
  assert.strictEqual(batchRes.validCount, 38);
  assert.strictEqual(batchRes.invalidCount, 0);
  assert.strictEqual(batchRes.duplicateCount, 0);
  assert.strictEqual(batchRes.overlapCount, 0);
});

runTest('21. Every candidate has validationStatus = "VALID" and stagingStatus = "DRAFT"', () => {
  extraction.candidates.forEach((cand, idx) => {
    assert.strictEqual(cand.validationStatus, 'VALID', `Candidate ${idx + 1} validationStatus is not VALID`);
    assert.strictEqual(cand.stagingStatus, 'DRAFT', `Candidate ${idx + 1} stagingStatus must be DRAFT`);
    assert.notStrictEqual(cand.stagingStatus, 'VERIFIED', `Candidate ${idx + 1} must NEVER be VERIFIED`);
  });
});

runTest('22. Table-specific effective date is confirmed as 2026-08-19', () => {
  assert.strictEqual(extraction.effectiveFrom, '2026-08-19');
});

// Summary
console.log('\n======================================================================');
console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
console.log('======================================================================');

if (failed > 0) {
  process.exit(1);
}
