// FeroCalc Verified FD Rate Engine — Phase 3A Review Queue & Safe Promotion Test Suite
//
// Tests all 22 required capabilities:
// 1. Safe unchanged candidate
// 2. Safe new rate
// 3. Safe small rate change
// 4. Suspicious large rate change
// 5. Extraction count anomaly
// 6. Missing tenure anomaly
// 7. Parser failure
// 8. Source fetch failure
// 9. Duplicate candidate
// 10. Overlapping candidate
// 11. DRAFT -> VERIFIED through policy
// 12. DRAFT -> IN_REVIEW
// 13. DRAFT -> INVALID
// 14. IN_REVIEW -> VERIFIED via admin
// 15. IN_REVIEW -> REJECTED
// 16. Historical rate preservation
// 17. Rollback creates audit event
// 18. Source failure preserves old VERIFIED rate
// 19. Missing source row does not delete verified rate
// 20. Direct bypass of policy is rejected
// 21. Audit record contains promotion reason
// 22. Different callable/product/customer dimensions are not incorrectly merged

'use strict';

const assert = require('assert');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { PromotionService } = require('../promotion/promotion_service');
const { CandidateRate } = require('../parsers/base_parser');

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

async function runPromotionTestSuite() {
  console.log('======================================================');
  console.log('FeroCalc Phase 3A Review Queue & Promotion Test Suite');
  console.log('======================================================\n');

  const diffEngine = new RateDiffEngine();
  const policyEngine = new PromotionPolicyEngine({
    maxAutoPromoteRateDeltaPct: 0.50, // 50 bps threshold
    requireOfficialDomain: true,
  });

  // Base verified rate record for testing
  const baseVerifiedRate = {
    id: 'rate-uuid-001',
    bankId: 'SBI',
    bankCode: 'SBI',
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    customerType: 'REGULAR',
    isCallable: true,
    minTenureDays: 365,
    maxTenureDays: 729,
    minDeposit: 1000,
    maxDeposit: 29999999,
    interestRate: 6.25,
    status: 'VERIFIED',
    effectiveFrom: '2025-07-15',
    effectiveUntil: null,
  };

  // ----------------------------------------------------------------
  // Tests 1-4: Diff & Policy on Rates
  // ----------------------------------------------------------------
  console.log('Group 1: Diff Engine & Policy Sanity...');

  runTest('1. Safe unchanged candidate produces UNCHANGED diff and passes policy', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 29999999,
      interestRate: 6.25, // Unchanged!
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'a'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const diff = diffEngine.diffCandidate(candidate, [baseVerifiedRate]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNCHANGED);
    assert.strictEqual(diff.rateDelta, 0);

    const policy = policyEngine.evaluateCandidate(candidate, diff, { httpStatus: 200, parserSuccess: true });
    assert.strictEqual(policy.eligibleForAutoPromotion, true);
    assert.strictEqual(policy.recommendedAction, 'PROMOTE');
  });

  runTest('2. Safe new rate identifies as NEW bucket and routes to IN_REVIEW for initial check', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 1825,
      maxTenureDays: 3650, // 5y to 10y (New bucket not in base)
      interestRate: 6.05,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'a'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const diff = diffEngine.diffCandidate(candidate, [baseVerifiedRate]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW);

    const policy = policyEngine.evaluateCandidate(candidate, diff, { httpStatus: 200, parserSuccess: true });
    // New rate bucket requires human confirmation
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'IN_REVIEW');
  });

  runTest('3. Safe small rate change (+0.25%) passes policy for automated promotion', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 29999999,
      interestRate: 6.50, // Changed from 6.25 to 6.50 (+0.25% <= 0.50%)
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'b'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const diff = diffEngine.diffCandidate(candidate, [baseVerifiedRate]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED);
    assert.strictEqual(diff.rateDelta, 0.25);

    const policy = policyEngine.evaluateCandidate(candidate, diff, { httpStatus: 200, parserSuccess: true });
    assert.strictEqual(policy.eligibleForAutoPromotion, true);
    assert.strictEqual(policy.recommendedAction, 'PROMOTE');
  });

  runTest('4. Suspicious large rate change (+1.25%) fails policy and escalates to IN_REVIEW', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 29999999,
      interestRate: 7.50, // Massive change (+1.25% > 0.50%)
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'b'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const diff = diffEngine.diffCandidate(candidate, [baseVerifiedRate]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED);

    const policy = policyEngine.evaluateCandidate(candidate, diff, { httpStatus: 200, parserSuccess: true });
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'IN_REVIEW');
    assert.ok(policy.failedReasons.some(r => r.includes('exceeds automated policy ceiling')));
  });

  // ----------------------------------------------------------------
  // Tests 5-10: Anomaly & Failure Handling in Policy
  // ----------------------------------------------------------------
  console.log('\nGroup 2: Anomaly, Failure & Validation Safeguards...');

  runTest('5. Extraction count anomaly escalates candidate to IN_REVIEW', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'c'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      anomalyFlags: ['ANOMALY_COUNT_MISMATCH: Count dropped from 20 to 5'],
    });

    const diff = diffEngine.diffCandidate(candidate, [baseVerifiedRate]);
    const policy = policyEngine.evaluateCandidate(candidate, diff, { httpStatus: 200, parserSuccess: true });
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'IN_REVIEW');
    assert.ok(policy.failedReasons.some(r => r.includes('count mismatch')));
  });

  runTest('6. Missing tenure anomaly escalates candidate to IN_REVIEW', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'c'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      anomalyFlags: ['ANOMALY_TENURE_DISAPPEARED: 3 tenures disappeared'],
    });

    const diff = diffEngine.diffCandidate(candidate, [baseVerifiedRate]);
    const policy = policyEngine.evaluateCandidate(candidate, diff, { httpStatus: 200, parserSuccess: true });
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'IN_REVIEW');
    assert.ok(policy.failedReasons.some(r => r.includes('disappearance of previously active tenures')));
  });

  runTest('7. Parser failure in context fails promotion policy', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'c'.repeat(64),
      validationStatus: 'VALID',
    });
    const policy = policyEngine.evaluateCandidate(candidate, {}, { parserSuccess: false });
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'IN_REVIEW');
  });

  runTest('8. Source fetch failure (HTTP 500) fails promotion policy', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'c'.repeat(64),
      validationStatus: 'VALID',
    });
    const policy = policyEngine.evaluateCandidate(candidate, {}, { httpStatus: 500, fetchStatus: 'FETCH_FAILED' });
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'IN_REVIEW');
  });

  runTest('9. Duplicate candidate is marked INVALID by policy', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'c'.repeat(64),
      validationStatus: 'INVALID',
      validationErrors: ['Duplicate candidate detected'],
    });
    const policy = policyEngine.evaluateCandidate(candidate, {});
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'INVALID');
  });

  runTest('10. Overlapping candidate is marked INVALID by policy', () => {
    const candidate = new CandidateRate({
      bankCode: 'SBI',
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'c'.repeat(64),
      validationStatus: 'INVALID',
      validationErrors: ['Overlapping tenure range detected'],
    });
    const policy = policyEngine.evaluateCandidate(candidate, {});
    assert.strictEqual(policy.eligibleForAutoPromotion, false);
    assert.strictEqual(policy.recommendedAction, 'INVALID');
  });

  // ----------------------------------------------------------------
  // Tests 11-15: State Machine Transitions
  // ----------------------------------------------------------------
  console.log('\nGroup 3: State Machine & Promotion Workflow...');

  const promotionService = new PromotionService({
    diffEngine,
    policyEngine,
    inMemoryRates: [{ ...baseVerifiedRate }],
  });

  await runTestAsync('11. DRAFT -> VERIFIED through policy promotes safe candidate', async () => {
    const safeCandidate = new CandidateRate({
      candidateId: 'cand-001',
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 29999999,
      interestRate: 6.40, // +0.15% change (safe)
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'd'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const res = await promotionService.promoteCandidate({
      candidate: safeCandidate,
      actorType: 'AUTOMATED_POLICY',
      context: { httpStatus: 200, parserSuccess: true },
    });

    assert.strictEqual(res.success, true);
    assert.strictEqual(res.promoted, true);
    assert.strictEqual(safeCandidate.stagingStatus, 'PROMOTED');
    assert.strictEqual(res.newVerifiedRate.status, 'VERIFIED');
    assert.strictEqual(res.newVerifiedRate.interest_rate, 6.40);
  });

  await runTestAsync('12. DRAFT -> IN_REVIEW: Unsafe candidate is halted at IN_REVIEW', async () => {
    const unsafeCandidate = new CandidateRate({
      candidateId: 'cand-002',
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 729,
      interestRate: 8.00, // Spike to 8.00%
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'e'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const res = await promotionService.promoteCandidate({
      candidate: unsafeCandidate,
      actorType: 'AUTOMATED_POLICY',
      context: { httpStatus: 200, parserSuccess: true },
    });

    assert.strictEqual(res.success, false);
    assert.strictEqual(res.promoted, false);
    assert.strictEqual(unsafeCandidate.stagingStatus, 'IN_REVIEW');
  });

  await runTestAsync('13. DRAFT -> INVALID: Malformed candidate is marked INVALID', async () => {
    const invalidCandidate = new CandidateRate({
      candidateId: 'cand-003',
      bankCode: 'SBI',
      interestRate: -5.0,
      validationStatus: 'INVALID',
      validationErrors: ['Impossible negative rate: -5.0'],
    });

    const res = await promotionService.promoteCandidate({
      candidate: invalidCandidate,
      actorType: 'AUTOMATED_POLICY',
    });

    assert.strictEqual(res.success, false);
    assert.strictEqual(invalidCandidate.stagingStatus, 'INVALID');
  });

  await runTestAsync('14. IN_REVIEW -> VERIFIED via admin manual approval', async () => {
    const inReviewCandidate = new CandidateRate({
      candidateId: 'cand-004',
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 1825,
      maxTenureDays: 3650,
      interestRate: 6.05,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: 'f'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      stagingStatus: 'IN_REVIEW',
    });

    const res = await promotionService.promoteCandidate({
      candidate: inReviewCandidate,
      actorType: 'ADMIN',
      actorId: 'admin-user-uuid',
      reason: 'Admin verified against official SBI press release',
      overridePolicy: true,
    });

    assert.strictEqual(res.success, true);
    assert.strictEqual(res.promoted, true);
    assert.strictEqual(inReviewCandidate.stagingStatus, 'PROMOTED');
    assert.strictEqual(res.newVerifiedRate.status, 'VERIFIED');
  });

  await runTestAsync('15. IN_REVIEW -> REJECTED via admin rejection', async () => {
    const inReviewCandidate = new CandidateRate({
      candidateId: 'cand-005',
      stagingStatus: 'IN_REVIEW',
      sourceContentHash: 'f'.repeat(64),
      parserVersion: '1.0.0',
    });

    const res = await promotionService.rejectCandidate(inReviewCandidate, 'admin-user-uuid', 'Duplicate scheme rejected');
    assert.strictEqual(res.success, true);
    assert.strictEqual(inReviewCandidate.stagingStatus, 'REJECTED');
  });

  // ----------------------------------------------------------------
  // Tests 16-19: Historical Versioning, Rollback & Resilience
  // ----------------------------------------------------------------
  console.log('\nGroup 4: Historical Versioning & Resilience Safeguards...');

  await runTestAsync('16. Historical rate preservation: Superseded rate is archived, NOT deleted', async () => {
    const oldRate = {
      id: 'old-rate-100',
      bankCode: 'HDFC',
      customer_type: 'REGULAR',
      is_callable: true,
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 2.75,
      status: 'VERIFIED',
      effective_until: null,
    };

    const service = new PromotionService({
      diffEngine,
      policyEngine,
      inMemoryRates: [oldRate],
    });

    const newCandidate = new CandidateRate({
      bankCode: 'HDFC',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.00,
      sourceUrl: 'https://hdfcbank.com/rates',
      sourceContentHash: '1'.repeat(64),
      effectiveFrom: '2026-03-06',
      parserId: 'hdfc_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const res = await service.promoteCandidate({
      candidate: newCandidate,
      actorType: 'AUTOMATED_POLICY',
      context: { httpStatus: 200, parserSuccess: true },
    });

    assert.strictEqual(res.success, true);
    assert.strictEqual(oldRate.status, 'ARCHIVED', 'Old rate must be ARCHIVED');
    assert.ok(oldRate.effective_until, 'Old rate must have effective_until set');
    assert.strictEqual(res.newVerifiedRate.status, 'VERIFIED');
  });

  await runTestAsync('17. Rollback restores previous archived record and creates audit event', async () => {
    const archivedPastRate = {
      id: 'archived-rate-50',
      bankCode: 'ICICI',
      customer_type: 'REGULAR',
      is_callable: true,
      min_tenure_days: 30,
      max_tenure_days: 45,
      interest_rate: 4.25,
      status: 'ARCHIVED',
      effective_until: '2026-10-01T00:00:00Z',
    };

    const faultyActiveRate = {
      id: 'faulty-rate-51',
      bankCode: 'ICICI',
      customer_type: 'REGULAR',
      is_callable: true,
      min_tenure_days: 30,
      max_tenure_days: 45,
      interest_rate: 5.50,
      status: 'VERIFIED',
      effective_until: null,
    };

    const service = new PromotionService({
      diffEngine,
      policyEngine,
      inMemoryRates: [archivedPastRate, faultyActiveRate],
    });

    const rollbackRes = await service.rollbackRate({
      rateId: 'faulty-rate-51',
      adminUserId: 'admin-123',
      notes: 'Rollback erroneous rate promotion',
    });

    assert.strictEqual(rollbackRes.success, true);
    assert.strictEqual(rollbackRes.rolledBackRate.status, 'ARCHIVED');
    assert.strictEqual(rollbackRes.restoredRate.status, 'VERIFIED');
    assert.strictEqual(rollbackRes.restoredRate.effective_until, null);
    assert.strictEqual(rollbackRes.auditEntry.action, 'ROLLBACK');
    assert.strictEqual(rollbackRes.auditEntry.actor_id, 'admin-123');
  });

  await runTestAsync('18. Source failure preserves 100% of old VERIFIED rates', async () => {
    const existingRate = {
      id: 'sbi-rate-01',
      bankCode: 'SBI',
      customer_type: 'REGULAR',
      is_callable: true,
      interest_rate: 6.25,
      status: 'VERIFIED',
    };

    const service = new PromotionService({
      diffEngine,
      policyEngine,
      inMemoryRates: [existingRate],
    });

    const failureRes = await service.handleSourceFailure('sbi-retail-domestic', 'SBI', new Error('HTTP 500 Internal Server Error'));
    assert.strictEqual(failureRes.status, 'FETCH_FAILED');
    assert.strictEqual(failureRes.ratesPreserved, true);
    assert.strictEqual(failureRes.preservedActiveRatesCount, 1);
    assert.strictEqual(existingRate.status, 'VERIFIED', 'Existing rate must remain active');
  });

  await runTestAsync('19. Missing source row does not delete verified rate', async () => {
    const activeRate = {
      id: 'active-rate-01',
      bankCode: 'SBI',
      customer_type: 'REGULAR',
      is_callable: true,
      min_tenure_days: 365,
      max_tenure_days: 729,
      interest_rate: 6.25,
      status: 'VERIFIED',
    };

    const service = new PromotionService({
      diffEngine,
      policyEngine,
      inMemoryRates: [activeRate],
    });

    // Empty extraction simulates missing rows from source
    const missingRes = await service.handleMissingSourceRows([], 'SBI');
    assert.strictEqual(missingRes.ratesDeleted, false, 'Missing rows must NEVER cause deletion');
    assert.strictEqual(missingRes.action, 'ESCALATE_TO_IN_REVIEW');
    assert.strictEqual(activeRate.status, 'VERIFIED', 'Rate must remain VERIFIED until reviewed');
  });

  // ----------------------------------------------------------------
  // Tests 20-22: Policy Bypass, Audit & Dimensional Integrity
  // ----------------------------------------------------------------
  console.log('\nGroup 5: Policy Bypass, Audit Details & Dimensional Separation...');

  await runTestAsync('20. Direct bypass of policy by automated actor is rejected', async () => {
    const unsafeCand = new CandidateRate({
      bankCode: 'SBI',
      customerType: 'REGULAR',
      interestRate: 14.5, // Blatant anomaly
      validationStatus: 'VALID',
    });

    const service = new PromotionService({ diffEngine, policyEngine });
    const res = await service.promoteCandidate({
      candidate: unsafeCand,
      actorType: 'AUTOMATED_POLICY',
    });

    assert.strictEqual(res.success, false);
    assert.strictEqual(res.promoted, false);
    assert.strictEqual(unsafeCand.stagingStatus, 'IN_REVIEW');
  });

  await runTestAsync('21. Audit record contains promotion reason and full policy results', async () => {
    const cand = new CandidateRate({
      candidateId: 'cand-audit-check',
      bankCode: 'SBI',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: 1000,
      maxDeposit: 29999999,
      interestRate: 6.25,
      sourceUrl: 'https://sbi.co.in/rates',
      sourceContentHash: '2'.repeat(64),
      effectiveFrom: '2025-12-15',
      parserId: 'sbi_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
    });

    const auditLogList = [];
    const service = new PromotionService({
      diffEngine,
      policyEngine,
      inMemoryRates: [{ ...baseVerifiedRate }],
      inMemoryAuditLogs: auditLogList,
    });

    await service.promoteCandidate({
      candidate: cand,
      actorType: 'AUTOMATED_POLICY',
      context: { httpStatus: 200, parserSuccess: true },
    });

    assert.strictEqual(auditLogList.length, 1);
    const audit = auditLogList[0];
    assert.strictEqual(audit.action, 'PROMOTE');
    assert.strictEqual(audit.actor_type, 'AUTOMATED_POLICY');
    assert.ok(audit.notes.includes('passed successfully'), 'Audit notes must contain rationale');
    assert.ok(audit.policy_result, 'Audit must contain policy result');
    assert.ok(audit.diff_summary, 'Audit must contain diff summary');
  });

  runTest('22. Different callable/product/customer dimensions are not incorrectly merged', () => {
    const regularCallable = {
      bankCode: 'ICICI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      isCallable: true,
      minTenureDays: 365,
      maxTenureDays: 389,
      interestRate: 6.25,
    };

    const seniorNonCallable = {
      bankCode: 'ICICI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'SENIOR_CITIZEN',
      isCallable: false,
      minTenureDays: 365,
      maxTenureDays: 389,
      interestRate: 6.50,
    };

    const regularKey = diffEngine.getBucketKey(regularCallable);
    const seniorKey = diffEngine.getBucketKey(seniorNonCallable);

    assert.notStrictEqual(regularKey, seniorKey, 'Keys must be separate across dimensions');

    const diff = diffEngine.diffCandidate(seniorNonCallable, [regularCallable]);
    // Since regularCallable is a different customer type and callable dimension, it must NOT match as an identical bucket
    assert.notStrictEqual(diff.diffType, DIFF_TYPES.UNCHANGED);
    assert.notStrictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED);
  });

  // Summary
  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

runPromotionTestSuite().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
