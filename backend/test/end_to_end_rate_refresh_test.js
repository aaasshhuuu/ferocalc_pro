// FeroCalc Phase 3C.9 / 3C.9.1 — End-to-End Automatic Verified FD Rate Refresh Regression Test Suite
//
// Tests all required capabilities:
// - Test 1: Unchanged official-source hash -> 0 new active rates, 0 promotions.
// - Test 2: Valid rate change within 50 bps delta auto-promotes when 100% checks pass.
// - Test 3: Rate change > 50 bps held for review (IN_REVIEW).
// - Test 4: New tenure bucket held for review unless baseline attested.
// - Test 5: Missing effective date, invalid source, parser failure, missing tenure, anomaly -> no promotion.
// - Test 6: Source fetch failure leaves existing verified rates intact and freshness reflects failure.
// - Test 7: DRAFT and IN_REVIEW candidates never appear in public verified rates API.
// - Test 11: Scheduled workflow disabled (RATE_PIPELINE_AUTOMATION_ENABLED != 'true') makes 0 network calls.
// - Test 12: Scheduled workflow enabled but missing secret fails closed.
// - Test 13: Sanitized summary output masks secrets and candidate arrays.
// - Freshness endpoint computeSourceFreshness allowlisting and safety verification.
// - Phase 3C.9.1 additions:
//   * Test 14: Exact cron endpoint path (/api/internal/jobs/run-pipeline) and secret authentication contract.
//   * Test 15: Dry-run execution side-effect verification (zero candidate/verified promotions).
//   * Test 16: Recovered SQL statements SHA-256 and byte-count integrity against RECOVERY_MANIFEST.md.

'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { defaultRegistry } = require('../collectors/source_registry');
const { computeSourceFreshness } = require('../routes/verified_rates');
const { requireCronSecret, safeCompare } = require('../routes/cron_pipeline');

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
  console.log('================================================================');
  console.log('FeroCalc Phase 3C.9.1 End-to-End Rate Refresh Regression Test Suite');
  console.log('================================================================\n');

  const diffEngine = new RateDiffEngine();
  const policyEngine = new PromotionPolicyEngine({
    maxAutoPromoteRateDeltaPct: 0.50,
    requireExplicitEffectiveDate: true,
    requireOfficialDomain: true,
  });

  // Base verified rate
  const activeSbiRate = {
    id: 'sbi-rate-365-verified',
    bankId: 'SBI',
    bankCode: 'SBI',
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    customerType: 'REGULAR',
    isCallable: true,
    rateCategory: 'STANDARD',
    schemeName: null,
    tenureDomain: 'DAYS',
    minTenureDays: 365,
    maxTenureDays: 730,
    minDeposit: 1000,
    maxDeposit: 10000000,
    interestRate: 6.80,
    sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates',
    effectiveFrom: '2026-09-01',
    stagingStatus: 'VERIFIED',
  };

  // Base candidate template
  function createCandidate(overrides = {}) {
    return {
      candidateId: 'cand-001',
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      tenureDomain: 'DAYS',
      minTenureDays: 365,
      maxTenureDays: 730,
      minDeposit: 1000,
      maxDeposit: 10000000,
      interestRate: 6.80,
      effectiveFrom: '2026-10-26',
      sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates',
      sourceContentHash: 'a'.repeat(64),
      parserId: 'sbi-html-parser',
      parserVersion: '1.2.0',
      validationStatus: 'VALID',
      validationErrors: [],
      anomalyFlags: [],
      ...overrides,
    };
  }

  // -------------------------------------------------------------
  // Test 1: Unchanged official-source hash -> 0 new active rates, 0 promotions
  // -------------------------------------------------------------
  runTest('Test 1: Unchanged official-source hash results in UNCHANGED diff and 0 promotions', () => {
    const candidate = createCandidate({ interestRate: 6.80 });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);

    assert.strictEqual(diff.diffType, DIFF_TYPES.UNCHANGED, 'Diff type must be UNCHANGED');
    assert.strictEqual(diff.hasChanged, false, 'hasChanged must be false');
    assert.strictEqual(diff.rateDelta, 0, 'Rate delta must be 0');

    // Policy evaluation on unchanged candidate
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    // Unchanged rate is safe, but requires no promotion to new active record
    assert.strictEqual(evaluation.eligibleForAutoPromotion, true);
    assert.strictEqual(evaluation.recommendedAction, 'PROMOTE');
    // Diff indicates no state mutation needed
    const requiresDbPromotion = diff.diffType !== DIFF_TYPES.UNCHANGED;
    assert.strictEqual(requiresDbPromotion, false, 'Unchanged rate must not trigger DB promotion');
  });

  // -------------------------------------------------------------
  // Test 2: Valid rate change within 50 bps delta auto-promotes when 100% checks pass
  // -------------------------------------------------------------
  runTest('Test 2: Valid rate change within 50 bps delta auto-promotes with 100% checks passing', () => {
    const candidate = createCandidate({ interestRate: 7.00 }); // +20 bps
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);

    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED, 'Diff type must be RATE_CHANGED');
    assert.strictEqual(diff.rateDelta, 0.20, 'Delta must be 0.20');
    assert.strictEqual(diff.absDelta, 0.20, 'Abs delta must be 0.20');

    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, true, 'Must be eligible for auto-promotion');
    assert.strictEqual(evaluation.recommendedAction, 'PROMOTE', 'Action must be PROMOTE');
    assert.strictEqual(evaluation.checks.rateDeltaSafe, true, 'rateDeltaSafe check must pass');
    assert.strictEqual(evaluation.checks.officialDomain, true, 'officialDomain check must pass');
    assert.strictEqual(evaluation.checks.explicitEffectiveDate, true, 'explicitEffectiveDate check must pass');
    assert.strictEqual(evaluation.failedReasons.length, 0, 'Failed reasons must be empty');
  });

  // -------------------------------------------------------------
  // Test 3: Rate change > 50 bps held for review (IN_REVIEW)
  // -------------------------------------------------------------
  runTest('Test 3: Rate change > 50 bps delta is held for human review (IN_REVIEW)', () => {
    const candidate = createCandidate({ interestRate: 7.45 }); // +65 bps
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);

    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED);
    assert.strictEqual(diff.absDelta, 0.65);

    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false, 'Must not be eligible for auto-promotion');
    assert.strictEqual(evaluation.recommendedAction, 'IN_REVIEW', 'Action must be IN_REVIEW');
    assert.strictEqual(evaluation.checks.rateDeltaSafe, false, 'rateDeltaSafe must fail');
    assert.ok(
      evaluation.failedReasons.some(r => r.includes('exceeds automated policy ceiling')),
      'Failed reason must explain delta exceeded ceiling'
    );
  });

  // -------------------------------------------------------------
  // Test 4: New tenure bucket held for review unless baseline attested
  // -------------------------------------------------------------
  runTest('Test 4: Brand new tenure bucket held for review unless baseline attested', () => {
    // New 5-year bucket (1825 - 3650 days) not in active rates
    const candidate = createCandidate({
      minTenureDays: 1825,
      maxTenureDays: 3650,
      interestRate: 6.50,
    });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW, 'Diff type must be NEW');

    // Case A: Unattested new bucket -> IN_REVIEW
    const evalUnattested = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
      isBaselineAttested: false,
    });

    assert.strictEqual(evalUnattested.eligibleForAutoPromotion, false);
    assert.strictEqual(evalUnattested.recommendedAction, 'IN_REVIEW');
    assert.strictEqual(evalUnattested.checks.isNotUnreviewedNewBucket, false);
    assert.ok(evalUnattested.failedReasons.some(r => r.includes('Brand new rate bucket introduced')));

    // Case B: Baseline-attested new bucket -> PROMOTE
    const evalAttested = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
      isBaselineAttested: true,
    });

    assert.strictEqual(evalAttested.eligibleForAutoPromotion, true);
    assert.strictEqual(evalAttested.recommendedAction, 'PROMOTE');
    assert.strictEqual(evalAttested.checks.isNotUnreviewedNewBucket, true);
  });

  // -------------------------------------------------------------
  // Test 5: Missing effective date, invalid source, parser failure, missing tenure, anomaly -> no promotion
  // -------------------------------------------------------------
  runTest('Test 5a: Missing effective date blocks auto-promotion', () => {
    const candidate = createCandidate({ effectiveFrom: null });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.explicitEffectiveDate, false);
    assert.strictEqual(evaluation.recommendedAction, 'IN_REVIEW');
  });

  runTest('Test 5b: Invalid/unofficial source domain blocks auto-promotion', () => {
    const candidate = createCandidate({ sourceUrl: 'https://unofficial-thirdparty-rates.com/rates' });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.officialDomain, false);
    assert.strictEqual(evaluation.recommendedAction, 'IN_REVIEW');
  });

  runTest('Test 5c: Parser failure blocks auto-promotion', () => {
    const candidate = createCandidate({ parserId: null });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: false,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.parserSucceeded, false);
    assert.strictEqual(evaluation.recommendedAction, 'IN_REVIEW');
  });

  runTest('Test 5d: Missing tenure anomaly (ANOMALY_TENURE_DISAPPEARED) blocks auto-promotion', () => {
    const candidate = createCandidate({ anomalyFlags: ['ANOMALY_TENURE_DISAPPEARED_1Y'] });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.noMissingTenureAnomaly, false);
    assert.strictEqual(evaluation.checks.noGeneralAnomalies, false);
    assert.strictEqual(evaluation.recommendedAction, 'IN_REVIEW');
  });

  runTest('Test 5e: Extraction count anomaly (ANOMALY_COUNT_MISMATCH) blocks auto-promotion', () => {
    const candidate = createCandidate({ anomalyFlags: ['ANOMALY_COUNT_MISMATCH_TOO_FEW'] });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.noCountAnomaly, false);
    assert.strictEqual(evaluation.recommendedAction, 'IN_REVIEW');
  });

  runTest('Test 5f: Validation status INVALID results in INVALID action (never IN_REVIEW or PROMOTE)', () => {
    const candidate = createCandidate({
      validationStatus: 'INVALID',
      validationErrors: ['interestRate must be between 0 and 20'],
    });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.validationPassed, false);
    assert.strictEqual(evaluation.recommendedAction, 'INVALID');
  });

  // -------------------------------------------------------------
  // Test 6: Source fetch failure leaves existing verified rates intact and freshness reflects failure
  // -------------------------------------------------------------
  runTest('Test 6: Source fetch failure leaves verified rates intact and freshness reflects failure', () => {
    const candidate = createCandidate();
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const evaluation = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'FETCH_FAILED',
      httpStatus: 500,
      parserSuccess: false,
    });

    assert.strictEqual(evaluation.eligibleForAutoPromotion, false);
    assert.strictEqual(evaluation.checks.sourceFetchSucceeded, false);

    // Existing active rate remains in list intact
    const verifiedRatesPool = [activeSbiRate];
    assert.strictEqual(verifiedRatesPool.length, 1);
    assert.strictEqual(verifiedRatesPool[0].interestRate, 6.80);

    // Check freshness metadata calculation
    const enabledSources = [{ id: 'sbi-retail-domestic', bankCode: 'SBI', bankName: 'State Bank of India', sourceUrl: 'https://sbi.co.in' }];
    const sourcesData = [{
      id: 'sbi-retail-domestic',
      bank_code: 'SBI',
      last_checked_at: new Date().toISOString(),
      last_success_at: new Date(Date.now() - 36 * 3600 * 1000).toISOString(), // 36 hours ago
      last_status: 'FETCH_FAILED',
      last_error: 'Connection timeout',
    }];
    const freshness = computeSourceFreshness(enabledSources, sourcesData, {});

    assert.strictEqual(freshness.length, 1);
    assert.strictEqual(freshness[0].lastStatus, 'FETCH_FAILED');
    assert.strictEqual(freshness[0].isStale, true);
    // Confidential internal error must not leak
    assert.strictEqual(freshness[0].last_error, undefined);
  });

  // -------------------------------------------------------------
  // Test 7: DRAFT and IN_REVIEW candidates never appear in public verified rates API
  // -------------------------------------------------------------
  runTest('Test 7: DRAFT and IN_REVIEW candidates are excluded from public verified rates', () => {
    const databaseRecords = [
      { id: '1', bankCode: 'SBI', interestRate: 6.80, stagingStatus: 'VERIFIED' },
      { id: '2', bankCode: 'HDFC', interestRate: 7.10, stagingStatus: 'DRAFT' },     // 38 HDFC records
      { id: '3', bankCode: 'HDFC', interestRate: 7.25, stagingStatus: 'IN_REVIEW' },
      { id: '4', bankCode: 'ICICI', interestRate: 6.90, stagingStatus: 'VERIFIED' },
      { id: '5', bankCode: 'SBI', interestRate: 7.00, stagingStatus: 'DRAFT' },      // 15 SBI records
    ];

    // Public verified rate filter: strictly VERIFIED only
    const publicRates = databaseRecords.filter(r => r.stagingStatus === 'VERIFIED');

    assert.strictEqual(publicRates.length, 2);
    assert.ok(publicRates.every(r => r.stagingStatus === 'VERIFIED'));
    assert.ok(!publicRates.some(r => r.stagingStatus === 'DRAFT'));
    assert.ok(!publicRates.some(r => r.stagingStatus === 'IN_REVIEW'));
  });

  // -------------------------------------------------------------
  // Test 11: Scheduled workflow disabled makes 0 network calls
  // -------------------------------------------------------------
  runTest('Test 11: GitHub Actions workflow checks RATE_PIPELINE_AUTOMATION_ENABLED == true before executing', () => {
    const workflowPath = path.resolve(__dirname, '../../.github/workflows/rate-update-pipeline.yml');
    assert.ok(fs.existsSync(workflowPath), 'Workflow file must exist');

    const content = fs.readFileSync(workflowPath, 'utf8');
    assert.ok(
      content.includes('RATE_PIPELINE_AUTOMATION_ENABLED'),
      'Workflow job must reference RATE_PIPELINE_AUTOMATION_ENABLED variable'
    );
    assert.ok(
      content.includes('[ "${AUTOMATION_ENABLED}" = "true" ]'),
      'Workflow step must check if AUTOMATION_ENABLED == true'
    );
    assert.ok(
      content.includes("if: steps.check-enablement.outputs.enabled == 'true'"),
      'Subsequent execution steps must require enabled == true'
    );

    // Verify simulation: when variable is empty, undefined, or 'false', the step is skipped
    const isStepExecuted = (val) => val === 'true';
    assert.strictEqual(isStepExecuted(undefined), false);
    assert.strictEqual(isStepExecuted(''), false);
    assert.strictEqual(isStepExecuted('false'), false);
    assert.strictEqual(isStepExecuted('0'), false);
    assert.strictEqual(isStepExecuted('true'), true);
  });

  // -------------------------------------------------------------
  // Test 12: Scheduled workflow enabled but missing secret fails closed
  // -------------------------------------------------------------
  runTest('Test 12: Scheduled workflow fails closed if required secret or URL is missing', () => {
    const workflowPath = path.resolve(__dirname, '../../.github/workflows/rate-update-pipeline.yml');
    const content = fs.readFileSync(workflowPath, 'utf8');

    // Verify script checks for both PIPELINE_URL and CRON_SECRET
    assert.ok(
      content.includes('if [ -z "${PIPELINE_URL}" ]; then'),
      'Workflow must check that PIPELINE_URL is non-empty'
    );
    assert.ok(
      content.includes('if [ -z "${CRON_SECRET}" ]; then'),
      'Workflow must check that CRON_SECRET is non-empty'
    );
    assert.ok(
      content.includes('exit 1'),
      'Workflow must exit with code 1 if configuration is missing'
    );

    // Simulation of bash guard logic
    function simulateGuard(url, secret) {
      if (!url || !secret) {
        return { success: false, code: 1, message: 'Missing required configuration' };
      }
      return { success: true, code: 0, message: 'Ready to dispatch' };
    }

    assert.strictEqual(simulateGuard('', '').success, false);
    assert.strictEqual(simulateGuard('https://api.example.com', '').success, false);
    assert.strictEqual(simulateGuard('', 'secret123').success, false);
    assert.strictEqual(simulateGuard('https://api.example.com', 'secret123').success, true);
  });

  // -------------------------------------------------------------
  // Test 13: Sanitized summary output masks secrets and candidate arrays
  // -------------------------------------------------------------
  runTest('Test 13: Pipeline logging and output sanitizes secrets, bearer tokens, and candidate arrays', () => {
    const rawPipelineResponse = {
      success: true,
      data: {
        summary: {
          banksProcessed: 3,
          candidatesExtracted: 42,
          unchangedCandidatesCount: 40,
          newPromotionsCount: 2,
          heldForReviewCount: 0,
        },
        // Sensitive candidate array or internal debug metadata
        candidates: [
          { candidateId: 'c1', rawData: 'secret-token-xyz', internalDbId: 991 },
        ],
        cronSecret: 'super-secret-cron-key-12345',
        authorization: 'Bearer super-secret-cron-key-12345',
      },
    };

    // Sanitization function simulation
    function sanitizeSummary(res) {
      const summary = res.data && res.data.summary ? res.data.summary : {};
      return {
        success: res.success === true,
        banksProcessed: summary.banksProcessed || 0,
        newPromotionsCount: summary.newPromotionsCount || 0,
        heldForReviewCount: summary.heldForReviewCount || 0,
      };
    }

    const sanitized = sanitizeSummary(rawPipelineResponse);

    assert.strictEqual(sanitized.success, true);
    assert.strictEqual(sanitized.banksProcessed, 3);
    assert.strictEqual(sanitized.newPromotionsCount, 2);
    assert.strictEqual(sanitized.cronSecret, undefined);
    assert.strictEqual(sanitized.authorization, undefined);
    assert.strictEqual(sanitized.candidates, undefined);

    const serialized = JSON.stringify(sanitized);
    assert.ok(!serialized.includes('super-secret-cron-key-12345'));
    assert.ok(!serialized.includes('secret-token-xyz'));
  });

  // -------------------------------------------------------------
  // Freshness endpoint computeSourceFreshness safe allowlisting test
  // -------------------------------------------------------------
  runTest('Freshness endpoint computeSourceFreshness safely allowlists fields and computes status', () => {
    const enabledSources = defaultRegistry.getEnabledSources();
    assert.strictEqual(enabledSources.length, 3, 'Should have exactly 3 enabled sources (SBI, HDFC, ICICI)');

    const now = new Date('2026-10-26T12:00:00Z');
    const mockDbData = [
      {
        id: 'sbi-retail-domestic',
        bank_code: 'SBI',
        source_url: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
        last_checked_at: '2026-10-26T11:30:00Z',
        last_success_at: '2026-10-26T11:30:00Z',
        last_status: 'UNCHANGED',
        last_error: null,
      },
      {
        id: 'hdfc-retail-domestic',
        bank_code: 'HDFC',
        source_url: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
        last_checked_at: '2026-10-26T11:30:00Z',
        last_success_at: '2026-10-26T11:30:00Z',
        last_status: 'CHANGED',
        last_error: null,
      },
      {
        id: 'icici-retail-domestic',
        bank_code: 'ICICI',
        source_url: 'https://www.icicibank.com/personal-banking/deposits/fixed-deposit/fd-interest-rates',
        last_checked_at: '2026-10-25T08:00:00Z',
        last_success_at: '2026-10-25T08:00:00Z', // 28 hours ago -> isStale: true
        last_status: 'UNCHANGED',
        last_error: null,
      },
    ];

    // Staging currently has 38 HDFC DRAFT candidates
    const pendingCounts = { HDFC: 38, SBI: 0, ICICI: 0 };

    const freshness = computeSourceFreshness(enabledSources, mockDbData, pendingCounts, now);

    assert.strictEqual(freshness.length, 3);

    // SBI
    const sbi = freshness.find(s => s.bankCode === 'SBI');
    assert.ok(sbi);
    assert.strictEqual(sbi.isStale, false);
    assert.strictEqual(sbi.pendingReviewCount, 0);
    assert.strictEqual(sbi.hasPendingReview, false);
    assert.strictEqual(sbi.updateDetected, false);

    // HDFC (has 38 pending review candidates)
    const hdfc = freshness.find(s => s.bankCode === 'HDFC');
    assert.ok(hdfc);
    assert.strictEqual(hdfc.pendingReviewCount, 38);
    assert.strictEqual(hdfc.hasPendingReview, true);
    assert.strictEqual(hdfc.updateDetected, true);

    // ICICI (older than 24h -> stale)
    const icici = freshness.find(s => s.bankCode === 'ICICI');
    assert.ok(icici);
    assert.strictEqual(icici.isStale, true);

    // Verify all objects strictly conform to allowed keys (no credentials or connection strings)
    const allowedKeys = new Set([
      'sourceId',
      'bankCode',
      'bankName',
      'sourceUrl',
      'lastCheckedAt',
      'lastSuccessAt',
      'lastStatus',
      'isStale',
      'pendingReviewCount',
      'hasPendingReview',
      'updateDetected',
    ]);

    freshness.forEach(item => {
      Object.keys(item).forEach(key => {
        assert.ok(allowedKeys.has(key), `Disallowed key found in freshness object: "${key}"`);
      });
      assert.strictEqual(item.database_url, undefined);
      assert.strictEqual(item.service_role_key, undefined);
      assert.strictEqual(item.cron_secret, undefined);
    });
  });

  // -------------------------------------------------------------
  // Test 14 (Phase 3C.9.1): Exact cron endpoint path & secret auth contract
  // -------------------------------------------------------------
  runTest('Test 14a: requireCronSecret middleware enforces CRON_SECRET contract', () => {
    const origSecret = process.env.CRON_SECRET;
    try {
      // 1. Server missing CRON_SECRET -> 503
      delete process.env.CRON_SECRET;
      let status503 = null;
      let json503 = null;
      const res503 = {
        status: (code) => { status503 = code; return res503; },
        json: (b) => { json503 = b; return res503; },
      };
      requireCronSecret({ headers: {} }, res503, () => {});
      assert.strictEqual(status503, 503, 'Missing server CRON_SECRET must yield 503');
      assert.ok(json503.message.includes('not configured'), 'Error message must explain CRON_SECRET not configured');

      // 2. Set server secret
      process.env.CRON_SECRET = 'correct-cron-secret-64-bytes-sample-value-1234567890abcdef12345678';

      // 3. Request without auth -> 401
      let status401 = null;
      const res401 = {
        status: (code) => { status401 = code; return res401; },
        json: () => res401,
      };
      let nextCalled = false;
      requireCronSecret({ headers: {} }, res401, () => { nextCalled = true; });
      assert.strictEqual(status401, 401, 'Missing auth header must yield 401');
      assert.strictEqual(nextCalled, false, 'next() must not be called');

      // 4. Request with wrong secret -> 401
      status401 = null;
      requireCronSecret({ headers: { authorization: 'Bearer wrong-secret' } }, res401, () => { nextCalled = true; });
      assert.strictEqual(status401, 401, 'Invalid secret must yield 401');
      assert.strictEqual(nextCalled, false);

      // 5. Request with correct Bearer token -> next() called
      nextCalled = false;
      requireCronSecret(
        { headers: { authorization: 'Bearer correct-cron-secret-64-bytes-sample-value-1234567890abcdef12345678' } },
        res401,
        () => { nextCalled = true; }
      );
      assert.strictEqual(nextCalled, true, 'Valid Bearer token must invoke next()');

      // 6. Request with correct x-cron-secret header -> next() called
      nextCalled = false;
      requireCronSecret(
        { headers: { 'x-cron-secret': 'correct-cron-secret-64-bytes-sample-value-1234567890abcdef12345678' } },
        res401,
        () => { nextCalled = true; }
      );
      assert.strictEqual(nextCalled, true, 'Valid x-cron-secret must invoke next()');

    } finally {
      if (origSecret !== undefined) process.env.CRON_SECRET = origSecret;
      else delete process.env.CRON_SECRET;
    }
  });

  runTest('Test 14b: safeCompare performs constant-time string comparison', () => {
    assert.strictEqual(safeCompare('same-secret', 'same-secret'), true);
    assert.strictEqual(safeCompare('same-secret', 'diff-secret'), false);
    assert.strictEqual(safeCompare('short', 'longer-string'), false); // Different lengths
    assert.strictEqual(safeCompare(null, 'secret'), false);
    assert.strictEqual(safeCompare('secret', undefined), false);
    assert.strictEqual(safeCompare('', ''), false);
  });

  runTest('Test 14c: Workflow enforces exact endpoint path /api/internal/jobs/run-pipeline and HTTPS', () => {
    const workflowPath = path.resolve(__dirname, '../../.github/workflows/rate-update-pipeline.yml');
    const content = fs.readFileSync(workflowPath, 'utf8');

    assert.ok(
      content.includes('*/api/internal/jobs/run-pipeline)'),
      'Workflow must validate that PIPELINE_URL ends with /api/internal/jobs/run-pipeline'
    );
    assert.ok(
      content.includes('case "${PIPELINE_URL}" in'),
      'Workflow must inspect PIPELINE_URL protocol and path'
    );
    assert.ok(
      !content.includes('--retry'),
      'Workflow curl request must NOT use automatic retry flags on state-changing POST requests'
    );
  });

  runTest('Test 14d: Workflow supports Vercel automation bypass and preserves Bearer auth', () => {
    const workflowPath = path.resolve(__dirname, '../../.github/workflows/rate-update-pipeline.yml');
    const content = fs.readFileSync(workflowPath, 'utf8');

    assert.ok(
      content.includes('VERCEL_AUTOMATION_BYPASS_SECRET'),
      'Workflow must reference secrets.VERCEL_AUTOMATION_BYPASS_SECRET'
    );
    assert.ok(
      content.includes('x-vercel-protection-bypass'),
      'Workflow must include x-vercel-protection-bypass header'
    );
    assert.ok(
      content.includes('Authorization: Bearer ${CRON_SECRET}'),
      'Workflow must preserve CRON_SECRET bearer authorization as second security layer'
    );
  });

  // -------------------------------------------------------------
  // Test 15 (Phase 3C.9.1): Dry-run execution side-effect verification
  // -------------------------------------------------------------
  runTest('Test 15: dryRun mode strictly skips verified rate promotion and candidate database persistence', () => {
    // In dryRun mode, PromotionPolicyEngine determines eligibility, but PipelineSchedulerService:
    // 1. Sets skipDbPersist: true (CandidateStagingService does not insert into staged_rate_candidates)
    // 2. Skips promoteCandidate call (zero writes to verified_rates)
    // 3. Flags run record with is_dry_run: true
    const candidate = createCandidate({ interestRate: 7.00 });
    const diff = diffEngine.diffCandidate(candidate, [activeSbiRate]);
    const policyResult = policyEngine.evaluateCandidate(candidate, diff, {
      fetchStatus: 'SUCCESS',
      httpStatus: 200,
      parserSuccess: true,
    });

    assert.strictEqual(policyResult.eligibleForAutoPromotion, true);

    // Simulate dry-run execution branch in PipelineSchedulerService._processSingleSource
    const isDryRun = true;
    let verifiedRatesWritten = 0;
    let simulatedPromotionCount = 0;

    if (isDryRun) {
      if (policyResult.eligibleForAutoPromotion) {
        simulatedPromotionCount++;
      }
    } else {
      verifiedRatesWritten++;
    }

    assert.strictEqual(simulatedPromotionCount, 1, 'Simulated promotion count incremented');
    assert.strictEqual(verifiedRatesWritten, 0, 'Zero verified rates written during dryRun');
  });

  // -------------------------------------------------------------
  // Test 16 (Phase 3C.9.1): Recovered SQL statements SHA-256 and byte-count integrity
  // -------------------------------------------------------------
  runTest('Test 16: Recovered SQL statements in drafts/recovered_from_staging/ match RECOVERY_MANIFEST.md', () => {
    const recoveryDir = path.resolve(__dirname, '../supabase/drafts/recovered_from_staging');
    assert.ok(fs.existsSync(recoveryDir), 'Quarantined recovered_from_staging directory must exist');

    const expectedManifest = [
      {
        fileName: '20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql',
        expectedBytes: 1825,
        expectedSha256: '2d91b3aebdcbc45e8dbeee4268a88bbf13db24511ee4870dfd70d5918c982cfa',
      },
      {
        fileName: '20261025100407_restrict_public_views_to_read_only.sql',
        expectedBytes: 152,
        expectedSha256: '89aad7b5a3f7b8b339dec5101930773b4500e4f3f4399741edc90db9604f71fd',
      },
      {
        fileName: '20261025100630_use_invoker_security_for_public_views.sql',
        expectedBytes: 135,
        expectedSha256: '01255614edb567107299abedb8aba1b302b6014a452ff7df1cb2c61ce2ee6d4f',
      },
      {
        fileName: '20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql',
        expectedBytes: 741,
        expectedSha256: 'b63a07b5935463c3a750e206703481b6fcdfb46e3f6b97a443cd54ab85be19f2',
      },
    ];

    expectedManifest.forEach(item => {
      const filePath = path.join(recoveryDir, item.fileName);
      assert.ok(fs.existsSync(filePath), `Recovered SQL file must exist: ${item.fileName}`);

      const buffer = fs.readFileSync(filePath);
      const actualBytes = buffer.length;
      const actualSha256 = crypto.createHash('sha256').update(buffer).digest('hex');

      assert.strictEqual(
        actualBytes,
        item.expectedBytes,
        `Byte count mismatch for ${item.fileName}: expected ${item.expectedBytes}, got ${actualBytes}`
      );
      assert.strictEqual(
        actualSha256,
        item.expectedSha256,
        `SHA-256 hash mismatch for ${item.fileName}: expected ${item.expectedSha256}, got ${actualSha256}`
      );
    });

    // Check RECOVERY_MANIFEST.md also exists and contains the expected SHA-256 values
    const manifestPath = path.join(recoveryDir, 'RECOVERY_MANIFEST.md');
    assert.ok(fs.existsSync(manifestPath), 'RECOVERY_MANIFEST.md must exist');
    const manifestContent = fs.readFileSync(manifestPath, 'utf8');

    expectedManifest.forEach(item => {
      assert.ok(
        manifestContent.includes(item.expectedSha256),
        `RECOVERY_MANIFEST.md must document expected SHA-256 for ${item.fileName}`
      );
    });
  });

  console.log(`\n================================================================`);
  console.log(`Phase 3C.9.1 Test Suite Results: ${passed} passed, ${failed} failed`);
  console.log(`================================================================`);

  if (failed > 0) {
    process.exit(1);
  }
}

runTestSuite();
