// FeroCalc Phase 4.1 — Safe Stale Tenure-Anomaly Reconciliation Regression Test Suite
//
// Verifies safe, narrowly-scoped reconciliation of obsolete ANOMALY_TENURE_DISAPPEARED
// review flags on staged candidates while enforcing all mandatory safety rules:
//
// 1. Exact unchanged candidate with only stale tenure anomaly is reconciled to DRAFT in live mode.
// 2. Candidate with any additional anomaly has only the tenure flag cleared and remains IN_REVIEW.
// 3. Candidate with changed rate remains IN_REVIEW.
// 4. Candidate with changed tenure identity remains IN_REVIEW.
// 5. Candidate with invalid validation status remains unchanged.
// 6. Unrelated bank candidates remain untouched.
// 7. Dry-run mode performs zero reconciliation writes.
// 8. Database update failure fails closed (status: ERROR).
// 9. Repeated execution is idempotent.
// 10. Verified-rate promotion safety: verified_fd_rates is never modified, promotedCount = 0.
// 11. Candidate with manual review hold (MANUAL_REVIEW in notes) remains IN_REVIEW.
// 12. Fresh extraction that still has ANOMALY_TENURE_DISAPPEARED does NOT reconcile.

'use strict';

const assert = require('assert');
const { PipelineSchedulerService } = require('../scheduling/pipeline_scheduler_service');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');

// ----------------------------------------------------------------
// Test Harness Helpers
// ----------------------------------------------------------------

let passedTests = 0;
let failedTests = 0;

function runTest(description, testFn) {
  try {
    testFn();
    console.log(`  PASS: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`  FAIL: ${description}`);
    console.error(`    ${err.message}`);
    failedTests++;
  }
}

async function runTestAsync(description, testFn) {
  try {
    await testFn();
    console.log(`  PASS: ${description}`);
    passedTests++;
  } catch (err) {
    console.error(`  FAIL: ${description}`);
    console.error(`    ${err.message}`);
    failedTests++;
  }
}

// ----------------------------------------------------------------
// Mock Database & Service Fixtures
// ----------------------------------------------------------------

function createMockDb(initialRows = []) {
  const rows = JSON.parse(JSON.stringify(initialRows));
  const updateLogs = [];

  return {
    rows,
    updateLogs,
    from(table) {
      if (table === 'staged_rate_candidates') {
        return {
          select(fields) {
            return {
              in(col, values) {
                return {
                  in(col2, values2) {
                    const filtered = rows.filter(r => values.includes(r[col]) && values2.includes(r[col2]));
                    return Promise.resolve({ data: filtered, error: null });
                  }
                };
              },
              eq(col, val) {
                return {
                  maybeSingle() {
                    const row = rows.find(r => r[col] === val);
                    return Promise.resolve({ data: row ? JSON.parse(JSON.stringify(row)) : null, error: null });
                  }
                };
              }
            };
          },
          update(payload) {
            return {
              eq(col, val) {
                updateLogs.push({ col, val, payload });
                const row = rows.find(r => r[col] === val);
                if (row) {
                  Object.assign(row, payload);
                }
                return Promise.resolve({ error: null });
              }
            };
          }
        };
      }

      if (table === 'fd_rates') {
        return {
          select() {
            return {
              eq() {
                return {
                  eq() {
                    return Promise.resolve({ data: [], error: null });
                  }
                };
              }
            };
          }
        };
      }

      return {
        select() { return Promise.resolve({ data: [], error: null }); },
        update() { return { eq() { return Promise.resolve({ error: null }); } }; },
        insert() { return Promise.resolve({ data: [], error: null }); },
      };
    }
  };
}

function createSyntheticActiveRates() {
  return [
    {
      id: 'active_canara_1y',
      bank_id: 'b1111111-2222-3333-4444-555555555555',
      bankCode: 'CANARA',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      interest_rate: 6.5,
      tenure_domain: 'CALENDAR',
      min_years: 1,
      min_months: 0,
      min_days_cal: 0,
      min_operator: 'GTE',
      max_years: 2,
      max_months: 0,
      max_days_cal: 0,
      max_operator: 'LT',
      source_tenure_text: '1 Year to less than 2 Years',
      is_callable: true,
      status: 'VERIFIED',
    },
    {
      id: 'active_canara_444d',
      bank_id: 'b1111111-2222-3333-4444-555555555555',
      bankCode: 'CANARA',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      interest_rate: 7.25,
      tenure_domain: 'DAYS',
      min_tenure_days: 444,
      max_tenure_days: 444,
      source_tenure_text: '444 Days',
      is_callable: true,
      status: 'VERIFIED',
    }
  ];
}

// ----------------------------------------------------------------
// Main Test Runner
// ----------------------------------------------------------------

async function runAllTests() {
  console.log('================================================================');
  console.log('FeroCalc Phase 4.1 Stale Review Reconciliation Regression Suite');
  console.log('================================================================\n');

  const diffEngine = new RateDiffEngine();
  const policyEngine = new PromotionPolicyEngine();
  const activeRates = createSyntheticActiveRates();

  // --- Group 1: Live Mode Reconciliations & Eligibility ---
  console.log('--- Group 1: Live Mode Reconciliations & Eligibility ---');

  await runTestAsync('1.1 Exact unchanged candidate with only stale tenure anomaly is reconciled in live mode', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_1y_001',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
      notes: null,
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_1y_001',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNCHANGED, 'Candidate must be UNCHANGED vs baseline');

    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, true, 'Reconciliation must return true');
    assert.strictEqual(mockDb.rows[0].staging_status, 'DRAFT', 'Staging status must transition to DRAFT');
    assert.deepStrictEqual(mockDb.rows[0].anomaly_flags, [], 'Obsolete anomaly flag must be cleared');
    assert.strictEqual(candidate.stagingStatus, 'DRAFT', 'In-memory stagingStatus must be updated to DRAFT');
  });

  await runTestAsync('1.2 Candidate with additional anomaly preserves IN_REVIEW and only clears tenure flag', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_1y_002',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: [
        'ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction',
        'ANOMALY_LARGE_RATE_DELTA: Rate changed significantly'
      ],
      staging_status: 'IN_REVIEW',
      notes: null,
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_1y_002',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'Candidate with other anomaly must NOT be reconciled to DRAFT');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW', 'Staging status must remain IN_REVIEW');
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW', 'In-memory stagingStatus must remain IN_REVIEW for manual hold');
    assert.deepStrictEqual(mockDb.rows[0].anomaly_flags, ['ANOMALY_LARGE_RATE_DELTA: Rate changed significantly'], 'Only the tenure anomaly must be removed');
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW', 'In-memory stagingStatus must remain IN_REVIEW');
  });

  await runTestAsync('1.3 Candidate with changed rate remains IN_REVIEW (not UNCHANGED)', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_1y_003',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.75, // Rate changed vs active baseline (6.50)
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_1y_003',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.75,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED, 'Diff must be RATE_CHANGED');

    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'Changed rate candidate must NOT be reconciled');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW', 'Staging status must remain IN_REVIEW');
  });

  await runTestAsync('1.4 Candidate with changed tenure identity remains IN_REVIEW', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_new_tenure',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '999 Days Special',
      tenure_domain: 'DAYS',
      min_tenure_days: 999,
      max_tenure_days: 999,
      interest_rate: 7.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_new_tenure',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '999 Days Special',
      tenureDomain: 'DAYS',
      minTenureDays: 999,
      maxTenureDays: 999,
      interestRate: 7.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW, 'Diff must be NEW for unseen tenure slab');

    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'New tenure candidate must NOT be reconciled');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW', 'Staging status must remain IN_REVIEW');
  });

  await runTestAsync('1.5 Candidate with invalid validation status remains unchanged', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_invalid_001',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'INVALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_invalid_001',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'INVALID',
      anomalyFlags: [],
      stagingStatus: 'INVALID',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'INVALID candidate must NOT be reconciled');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'Zero database updates must occur for INVALID candidate');
    assert.strictEqual(candidate.stagingStatus, 'INVALID', 'In-memory stagingStatus must remain INVALID');
  });

  // --- Group 2: Safety Boundaries & Fail-Closed Behavior ---
  console.log('\n--- Group 2: Safety Boundaries & Fail-Closed Behavior ---');

  await runTestAsync('2.1 Dry-run performs zero reconciliation writes', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_dryrun_001',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_dryrun_001',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: true,
    });

    assert.strictEqual(result.reconciled, false, 'Dry-run must return reconciled: false');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'Dry-run must execute zero database updates');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW', 'Staging status in DB must remain IN_REVIEW');
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW', 'In-memory stagingStatus must remain IN_REVIEW in dry-run');
  });

  await runTestAsync('2.2 Database update failure fails closed', async () => {
    const errorDb = {
      from(table) {
        return {
          update() {
            return {
              eq() {
                return Promise.resolve({ error: new Error('Simulated database connection timeout') });
              }
            };
          }
        };
      }
    };

    const scheduler = new PipelineSchedulerService({
      supabaseClient: errorDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_dberr_001',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: {
        id: 'staged_canara_dberr_001',
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      },
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false);
    assert.ok(result.error, 'Result must contain fail-closed error');
    assert.ok(result.error.includes('Simulated database connection timeout'));
  });

  await runTestAsync('2.3 Repeated execution is idempotent', async () => {
    // Row is already in DRAFT after first reconciliation
    const initialStagedRows = [{
      id: 'staged_canara_idempotent_001',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: [],
      staging_status: 'DRAFT',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_idempotent_001',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'Second run must be a no-op');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'Zero database updates must be executed');
  });

  await runTestAsync('2.4 Unrelated bank candidates remain untouched', async () => {
    const initialStagedRows = [
      {
        id: 'staged_canara_001',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '1 Year to less than 2 Years',
        tenure_domain: 'CALENDAR',
        min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
        max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
        interest_rate: 6.5,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
      },
      {
        id: 'staged_pnb_001',
        bank_code: 'PNB',
        customer_type: 'REGULAR',
        tenure_label: '1 Year',
        tenure_domain: 'DAYS',
        min_tenure_days: 365,
        max_tenure_days: 365,
        interest_rate: 6.8,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_LARGE_RATE_DELTA: Unrelated review issue'],
        staging_status: 'IN_REVIEW',
      }
    ];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const canaraCandidate = {
      id: 'staged_canara_001',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(canaraCandidate, activeRates);
    await scheduler._reconcileCandidateReviewStatus({
      candidate: canaraCandidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(mockDb.rows[0].staging_status, 'DRAFT', 'Canara candidate must be reconciled');
    assert.strictEqual(mockDb.rows[1].staging_status, 'IN_REVIEW', 'PNB candidate must remain IN_REVIEW');
    assert.deepStrictEqual(mockDb.rows[1].anomaly_flags, ['ANOMALY_LARGE_RATE_DELTA: Unrelated review issue'], 'PNB anomaly flags must remain untouched');
  });

  await runTestAsync('2.5 Candidate with MANUAL_REVIEW in notes remains IN_REVIEW', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_manual_hold',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
      notes: 'Operator requested MANUAL_REVIEW for audit',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_manual_hold',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: [] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'Manual hold candidate must NOT be reconciled');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW', 'Staging status must remain IN_REVIEW');
  });

  await runTestAsync('2.6 Fresh extraction that still has tenure anomaly blocks reconciliation', async () => {
    const initialStagedRows = [{
      id: 'staged_canara_still_anomaly',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(initialStagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'staged_canara_still_anomaly',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: ['ANOMALY_TENURE_DISAPPEARED: Fresh batch still missing tenures'],
      stagingStatus: 'IN_REVIEW',
      _matchedRow: initialStagedRows[0],
    };

    const diff = diffEngine.diffCandidate(candidate, activeRates);
    const result = await scheduler._reconcileCandidateReviewStatus({
      candidate,
      diff,
      stageResult: { anomalies: { flags: ['ANOMALY_TENURE_DISAPPEARED: Fresh batch still missing tenures'] } },
      dryRun: false,
    });

    assert.strictEqual(result.reconciled, false, 'Candidate with ongoing tenure anomaly must NOT be reconciled');
    assert.strictEqual(mockDb.rows[0].staging_status, 'IN_REVIEW');
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW', 'In-memory stagingStatus must remain IN_REVIEW for ongoing tenure anomaly');
  });

  // --- Group 3: End-to-End Source Processing Integration ---
  console.log('\n--- Group 3: End-to-End Source Processing Integration ---');

  await runTestAsync('3.1 End-to-end source processing reconciles stale reviews and updates telemetry', async () => {
    const stagedRows = [
      {
        id: 'cand_canara_e2e_1',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '1 Year to less than 2 Years',
        tenure_domain: 'CALENDAR',
        min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
        max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
        interest_rate: 6.5,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
      },
      {
        id: 'cand_canara_e2e_2',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '444 Days',
        tenure_domain: 'DAYS',
        min_tenure_days: 444,
        max_tenure_days: 444,
        interest_rate: 7.25,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
      }
    ];

    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidates = [
      {
        id: 'cand_canara_e2e_1',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '1 Year to less than 2 Years',
        tenureDomain: 'CALENDAR',
        minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
        maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
        interestRate: 6.5,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: [],
        stagingStatus: 'DRAFT',
        _matchedRow: stagedRows[0],
      },
      {
        id: 'cand_canara_e2e_2',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '444 Days',
        tenureDomain: 'DAYS',
        minTenureDays: 444,
        maxTenureDays: 444,
        interestRate: 7.25,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: [],
        stagingStatus: 'DRAFT',
        _matchedRow: stagedRows[1],
      }
    ];

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash1', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates,
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_e2e',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.unchangedRatesCount, 2, 'Both rates must be unchanged');
    assert.strictEqual(result.reconciledStaleReviewCount, 2, 'Both stale review candidates must be reconciled');
    assert.strictEqual(result.promotedCount, 0, 'Zero rates must be promoted');
    assert.strictEqual(stagedRows[0].staging_status, 'DRAFT', 'Row 1 must be DRAFT');
    assert.strictEqual(stagedRows[1].staging_status, 'DRAFT', 'Row 2 must be DRAFT');
    assert.deepStrictEqual(stagedRows[0].anomaly_flags, [], 'Row 1 anomalies must be cleared');
    assert.deepStrictEqual(stagedRows[1].anomaly_flags, [], 'Row 2 anomalies must be cleared');
  });

  await runTestAsync('3.2 Promotion safety: verified_fd_rates is never modified, promotedCount = 0', async () => {
    const stagedRows = [{
      id: 'cand_canara_promo_safety',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    let promotionCalled = false;
    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidates = [{
      id: 'cand_canara_promo_safety',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
      _matchedRow: stagedRows[0],
    }];

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash1', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates,
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      promoteCandidate: async () => {
        promotionCalled = true;
        return { promoted: true };
      },
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_promo_safety',
      dryRun: false,
    });

    assert.strictEqual(promotionCalled, false, 'promoteCandidate must NEVER be called for unchanged candidates');
    assert.strictEqual(result.promotedCount, 0, 'promotedCount must be exactly 0');
  });

  // --- Group 4: End-to-End Safety Audit & Ineligible Case Status Preservation ---
  console.log('\n--- Group 4: End-to-End Safety Audit & Ineligible Case Status Preservation ---');

  await runTestAsync('4.1 Dry-run end-to-end preserves candidate IN_REVIEW status, performs zero DB writes, and reports reconciledStaleReviewCount: 0', async () => {
    const stagedRows = [
      {
        id: 'cand_canara_dryrun_e2e_1',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '1 Year to less than 2 Years',
        tenure_domain: 'CALENDAR',
        min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
        max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
        interest_rate: 6.5,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
      },
      {
        id: 'cand_canara_dryrun_e2e_2',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '444 Days',
        tenure_domain: 'DAYS',
        min_tenure_days: 444,
        max_tenure_days: 444,
        interest_rate: 7.25,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
      }
    ];

    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidates = [
      {
        id: 'cand_canara_dryrun_e2e_1',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '1 Year to less than 2 Years',
        tenureDomain: 'CALENDAR',
        minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
        maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
        interestRate: 6.5,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: [],
        stagingStatus: 'IN_REVIEW',
        _matchedRow: stagedRows[0],
      },
      {
        id: 'cand_canara_dryrun_e2e_2',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '444 Days',
        tenureDomain: 'DAYS',
        minTenureDays: 444,
        maxTenureDays: 444,
        interestRate: 7.25,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: [],
        stagingStatus: 'IN_REVIEW',
        _matchedRow: stagedRows[1],
      }
    ];

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash_dry', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates,
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_dryrun_e2e',
      dryRun: true,
    });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.unchangedRatesCount, 2);
    assert.strictEqual(result.reconciledStaleReviewCount, 0, 'Zero candidates must be counted as reconciled in dry run');
    assert.strictEqual(result.promotedCount, 0, 'Zero rates must be promoted in dry run');
    assert.strictEqual(candidates[0].stagingStatus, 'IN_REVIEW', 'Candidate 1 must preserve IN_REVIEW in dry run');
    assert.strictEqual(candidates[1].stagingStatus, 'IN_REVIEW', 'Candidate 2 must preserve IN_REVIEW in dry run');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'Zero database writes must occur in dry run');
    assert.strictEqual(stagedRows[0].staging_status, 'IN_REVIEW', 'DB row 1 must remain IN_REVIEW');
    assert.strictEqual(stagedRows[1].staging_status, 'IN_REVIEW', 'DB row 2 must remain IN_REVIEW');
  });

  await runTestAsync('4.2 Manual MANUAL_REVIEW hold preserves IN_REVIEW status in end-to-end live run', async () => {
    const stagedRows = [{
      id: 'cand_canara_hold_e2e',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
      notes: 'MANUAL_REVIEW: Operator investigation pending',
    }];

    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'cand_canara_hold_e2e',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'IN_REVIEW',
      notes: 'MANUAL_REVIEW: Operator investigation pending',
      _matchedRow: stagedRows[0],
    };

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash_hold', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_hold_e2e',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.unchangedRatesCount, 1);
    assert.strictEqual(result.reconciledStaleReviewCount, 0, 'Manual hold must NOT increment reconciled count');
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW', 'Manual hold candidate must preserve IN_REVIEW in memory');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'Zero database writes must occur for manual hold');
    assert.strictEqual(stagedRows[0].staging_status, 'IN_REVIEW', 'DB row must remain IN_REVIEW');
  });

  await runTestAsync('4.3 Candidate with additional anomalies preserves IN_REVIEW in end-to-end live run', async () => {
    const stagedRows = [{
      id: 'cand_canara_multi_e2e',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: [
        'ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction',
        'ANOMALY_LARGE_RATE_DELTA: Rate delta requires review'
      ],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'cand_canara_multi_e2e',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: ['ANOMALY_LARGE_RATE_DELTA: Rate delta requires review'],
      stagingStatus: 'IN_REVIEW',
      _matchedRow: stagedRows[0],
    };

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash_multi', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_multi_e2e',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.unchangedRatesCount, 1);
    assert.strictEqual(result.reconciledStaleReviewCount, 0, 'Multi-anomaly candidate must NOT increment reconciled count');
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW', 'Candidate must preserve IN_REVIEW status in memory');
    assert.deepStrictEqual(candidate.anomalyFlags, ['ANOMALY_LARGE_RATE_DELTA: Rate delta requires review'], 'Tenure flag cleared, remaining flag preserved');
    assert.strictEqual(stagedRows[0].staging_status, 'IN_REVIEW', 'DB staging_status must remain IN_REVIEW');
    assert.deepStrictEqual(stagedRows[0].anomaly_flags, ['ANOMALY_LARGE_RATE_DELTA: Rate delta requires review'], 'DB anomaly_flags must retain only non-tenure flag');
  });

  await runTestAsync('4.4 Invalid candidate never transitions to DRAFT and performs zero DB writes', async () => {
    const stagedRows = [{
      id: 'cand_canara_invalid_e2e',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'INVALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'cand_canara_invalid_e2e',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'INVALID',
      anomalyFlags: [],
      stagingStatus: 'INVALID',
      _matchedRow: stagedRows[0],
    };

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash_invalid', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_invalid_e2e',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.reconciledStaleReviewCount, 0, 'INVALID candidate must NOT be reconciled');
    assert.strictEqual(candidate.stagingStatus, 'INVALID', 'INVALID candidate must retain INVALID status');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'Zero database writes must occur for INVALID candidate');
    assert.strictEqual(stagedRows[0].staging_status, 'IN_REVIEW', 'DB row must remain untouched');
  });

  await runTestAsync('4.5 Database error during reconciliation fails closed (result.status = ERROR)', async () => {
    const stagedRows = [{
      id: 'cand_canara_dberr_e2e',
      bank_code: 'CANARA',
      customer_type: 'REGULAR',
      tenure_label: '1 Year to less than 2 Years',
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.5,
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
      staging_status: 'IN_REVIEW',
    }];

    const failingDb = {
      from() {
        return {
          update() {
            return {
              eq() {
                return Promise.resolve({ error: new Error('Simulated database deadlock during reconciliation') });
              }
            };
          }
        };
      }
    };

    const scheduler = new PipelineSchedulerService({
      supabaseClient: failingDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidate = {
      id: 'cand_canara_dberr_e2e',
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureLabel: '1 Year to less than 2 Years',
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.5,
      isCallable: true,
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'IN_REVIEW',
      _matchedRow: stagedRows[0],
    };

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash_err', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_dberr_e2e',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'ERROR', 'Database error must fail-closed with status ERROR');
    assert.ok(result.error.includes('Simulated database deadlock'), 'Error message must reflect DB failure');
  });

  await runTestAsync('4.6 Mixed batch telemetry: strictly counts only successful database updates', async () => {
    const stagedRows = [
      {
        id: 'cand_mixed_1_eligible',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '1 Year to less than 2 Years',
        tenure_domain: 'CALENDAR',
        min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
        max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
        interest_rate: 6.5,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
      },
      {
        id: 'cand_mixed_2_hold',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '444 Days',
        tenure_domain: 'DAYS',
        min_tenure_days: 444,
        max_tenure_days: 444,
        interest_rate: 7.25,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction'],
        staging_status: 'IN_REVIEW',
        notes: 'Operator requested MANUAL_REVIEW',
      },
      {
        id: 'cand_mixed_3_multianomaly',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        tenure_label: '1 Year to less than 2 Years',
        tenure_domain: 'CALENDAR',
        min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
        max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
        interest_rate: 6.5,
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: [
          'ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing in new extraction',
          'ANOMALY_LARGE_RATE_DELTA: Rate delta flag'
        ],
        staging_status: 'IN_REVIEW',
      }
    ];

    const mockDb = createMockDb(stagedRows);
    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      diffEngine,
      policyEngine,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const candidates = [
      {
        id: 'cand_mixed_1_eligible',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '1 Year to less than 2 Years',
        tenureDomain: 'CALENDAR',
        minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
        maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
        interestRate: 6.5,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: [],
        stagingStatus: 'IN_REVIEW',
        _matchedRow: stagedRows[0],
      },
      {
        id: 'cand_mixed_2_hold',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '444 Days',
        tenureDomain: 'DAYS',
        minTenureDays: 444,
        maxTenureDays: 444,
        interestRate: 7.25,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: [],
        stagingStatus: 'IN_REVIEW',
        notes: 'Operator requested MANUAL_REVIEW',
        _matchedRow: stagedRows[1],
      },
      {
        id: 'cand_mixed_3_multianomaly',
        bankCode: 'CANARA',
        customerType: 'REGULAR',
        tenureLabel: '1 Year to less than 2 Years',
        tenureDomain: 'CALENDAR',
        minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
        maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
        interestRate: 6.5,
        isCallable: true,
        validationStatus: 'VALID',
        anomalyFlags: ['ANOMALY_LARGE_RATE_DELTA: Rate delta flag'],
        stagingStatus: 'IN_REVIEW',
        _matchedRow: stagedRows[2],
      }
    ];

    scheduler.collectionService = {
      collectSource: async () => ({ status: 'SUCCESS', httpStatus: 200, contentHash: 'hash_mixed', changed: true }),
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates,
        anomalies: { hasAnomalies: false, flags: [] },
      }),
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => activeRates,
      handleSourceFailure: async () => {},
    };

    const source = { bankCode: 'CANARA', id: 'canara-retail-domestic', sourceUrl: 'https://canarabank.com' };
    const result = await scheduler._processSingleSource({
      source,
      jobId: 'job_test_mixed_e2e',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.unchangedRatesCount, 3);
    assert.strictEqual(result.reconciledStaleReviewCount, 1, 'Only the single eligible candidate must be counted as reconciled');
    assert.strictEqual(candidates[0].stagingStatus, 'DRAFT', 'Eligible candidate must transition to DRAFT');
    assert.strictEqual(candidates[1].stagingStatus, 'IN_REVIEW', 'Manual hold candidate must preserve IN_REVIEW');
    assert.strictEqual(candidates[2].stagingStatus, 'IN_REVIEW', 'Multi-anomaly candidate must preserve IN_REVIEW');
    assert.strictEqual(stagedRows[0].staging_status, 'DRAFT', 'DB row 1 must transition to DRAFT');
    assert.strictEqual(stagedRows[1].staging_status, 'IN_REVIEW', 'DB row 2 must remain IN_REVIEW');
    assert.strictEqual(stagedRows[2].staging_status, 'IN_REVIEW', 'DB row 3 must remain IN_REVIEW');
  });

  // ----------------------------------------------------------------
  // Summary
  // ----------------------------------------------------------------
  console.log('\n================================================================');
  console.log(`Results: ${passedTests} passed, ${failedTests} failed (Total: ${passedTests + failedTests})`);
  console.log('================================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runAllTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
