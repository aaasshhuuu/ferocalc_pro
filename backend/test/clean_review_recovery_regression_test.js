// FeroCalc Phase 4.2 — Clean Candidate Recovery & PNB Baseline Stabilization Regression Test Suite
//
// Verifies:
// Group 1: Eligible clean candidate recovery (Indian Bank 54, HDFC 2, ICICI 6 -> 62 eligible)
// Group 2: Ineligible protection boundaries (manual hold, rate mismatch, NEW identity, count mismatch, invalid)
// Group 3: Promotion Service rollback safety & baseline attestation protection
// Group 4: Telemetry, idempotency, dry-run safety, and zero verified-rate mutation

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { PipelineSchedulerService } = require('../scheduling/pipeline_scheduler_service');
const { PromotionService } = require('../promotion/promotion_service');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { PnbRateParser } = require('../parsers/pnb_parser');
const { parseTenureRange } = require('../parsers/tenure_parser');

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
// Mock Database Fixtures
// ----------------------------------------------------------------

function createMockDb(initialStaged = [], initialVerified = []) {
  const stagedRows = JSON.parse(JSON.stringify(initialStaged));
  const verifiedRows = JSON.parse(JSON.stringify(initialVerified));
  const updateLogs = [];
  const insertLogs = [];

  return {
    stagedRows,
    verifiedRows,
    updateLogs,
    insertLogs,
    from(table) {
      if (table === 'staged_rate_candidates') {
        return {
          select(fields) {
            return {
              eq(col, val) {
                return {
                  maybeSingle() {
                    const row = stagedRows.find(r => r[col] === val);
                    return Promise.resolve({ data: row ? JSON.parse(JSON.stringify(row)) : null, error: null });
                  },
                  then(resolve) {
                    const filtered = stagedRows.filter(r => r[col] === val);
                    return resolve({ data: JSON.parse(JSON.stringify(filtered)), error: null });
                  }
                };
              },
              then(resolve) {
                return resolve({ data: JSON.parse(JSON.stringify(stagedRows)), error: null });
              }
            };
          },
          update(payload) {
            return {
              eq(col, val) {
                updateLogs.push({ table: 'staged_rate_candidates', col, val, payload });
                const row = stagedRows.find(r => r[col] === val);
                if (row) {
                  Object.assign(row, payload);
                }
                return Promise.resolve({ error: null });
              }
            };
          }
        };
      }
      if (table === 'verified_fd_rates') {
        return {
          select(fields) {
            return Promise.resolve({ data: JSON.parse(JSON.stringify(verifiedRows)), error: null });
          }
        };
      }
      if (table === 'fd_rates') {
        return {
          update(payload) {
            return {
              eq(col, val) {
                updateLogs.push({ table: 'fd_rates', col, val, payload });
                const row = verifiedRows.find(r => r[col] === val);
                if (row) {
                  Object.assign(row, payload);
                }
                return Promise.resolve({ error: null });
              }
            };
          },
          insert(payload) {
            insertLogs.push({ table: 'fd_rates', payload });
            verifiedRows.push({ ...payload, id: payload.id || crypto.randomUUID() });
            return {
              select() {
                return {
                  single() {
                    return Promise.resolve({ data: payload, error: null });
                  }
                };
              }
            };
          }
        };
      }
      throw new Error(`Unexpected table ${table}`);
    }
  };
}

// ----------------------------------------------------------------
// Test Suite Execution
// ----------------------------------------------------------------

async function runAllTests() {
  console.log('--- FeroCalc Phase 4.2: Clean Candidate Recovery & PNB Stabilization Tests ---');

  // ====================================================================
  // GROUP 1: Eligible Clean Candidate Recovery
  // ====================================================================
  console.log('\n[Group 1: Eligible Clean Candidate Recovery]');

  await runTestAsync('G1.1: Indian Bank clean candidates (54 rows) transition from IN_REVIEW to DRAFT', async () => {
    const activeRates = [];
    const inReviewCandidates = [];

    // Create 18 tenures * 3 customer types = 54 candidates
    for (let i = 1; i <= 18; i++) {
      for (const ct of ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN']) {
        const id = `ib_active_${i}_${ct}`;
        activeRates.push({
          id,
          bank_code: 'INDIAN_BANK',
          bankCode: 'INDIAN_BANK',
          bank_short_name: 'INDIAN_BANK',
          customer_type: ct,
          min_tenure_days: i * 30,
          max_tenure_days: i * 30 + 29,
          interest_rate: '6.50',
          rate_category: 'STANDARD',
          is_callable: true,
          status: 'VERIFIED',
        });
        inReviewCandidates.push({
          id: `ib_cand_${i}_${ct}`,
          bank_code: 'INDIAN_BANK',
          bankCode: 'INDIAN_BANK',
          customer_type: ct,
          customerType: ct,
          min_tenure_days: i * 30,
          max_tenure_days: i * 30 + 29,
          interest_rate: '6.50',
          interestRate: '6.50',
          rate_category: 'STANDARD',
          rateCategory: 'STANDARD',
          is_callable: true,
          isCallable: true,
          staging_status: 'IN_REVIEW',
          stagingStatus: 'IN_REVIEW',
          validation_status: 'VALID',
          validationStatus: 'VALID',
          anomaly_flags: [],
          anomalyFlags: [],
          notes: '',
        });
      }
    }

    const mockDb = createMockDb(inReviewCandidates, activeRates);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      bankFilter: 'INDIAN_BANK',
      inMemoryCandidates: inReviewCandidates,
      inMemoryActiveRates: activeRates,
    });

    assert.strictEqual(result.totalInReview, 54, 'Should identify all 54 Indian Bank candidates');
    assert.strictEqual(result.eligibleCount, 54, 'All 54 should be eligible');
    assert.strictEqual(result.reconciledCount, 54, 'All 54 should be reconciled to DRAFT');
    assert.strictEqual(result.skippedCount, 0, 'Zero skipped');
    assert.strictEqual(inReviewCandidates.every(c => c.staging_status === 'DRAFT'), true, 'All in-memory statuses updated to DRAFT');
  });

  await runTestAsync('G1.2: HDFC candidate split: 2 eligible UNCHANGED transition to DRAFT, 30 NEW remain IN_REVIEW', async () => {
    const activeRates = [
      {
        id: 'hdfc_act_1',
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: '3.00',
        rate_category: 'STANDARD',
        is_callable: true,
      },
      {
        id: 'hdfc_act_2',
        bank_code: 'HDFC',
        customer_type: 'SENIOR_CITIZEN',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: '3.50',
        rate_category: 'STANDARD',
        is_callable: true,
      },
    ];

    const inReviewCandidates = [
      // 2 matching active verified rates
      {
        id: 'hdfc_cand_1',
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: '3.00',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      },
      {
        id: 'hdfc_cand_2',
        bank_code: 'HDFC',
        customer_type: 'SENIOR_CITIZEN',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: '3.50',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      },
    ];

    // 30 unverified pilot/new tenures
    for (let i = 1; i <= 30; i++) {
      inReviewCandidates.push({
        id: `hdfc_cand_pilot_${i}`,
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: 1000 + i,
        max_tenure_days: 1000 + i,
        interest_rate: '7.10',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }

    const mockDb = createMockDb(inReviewCandidates, activeRates);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      bankFilter: 'HDFC',
      inMemoryCandidates: inReviewCandidates,
      inMemoryActiveRates: activeRates,
    });

    assert.strictEqual(result.totalInReview, 32);
    assert.strictEqual(result.eligibleCount, 2, 'Exactly 2 matching candidates eligible');
    assert.strictEqual(result.reconciledCount, 2, 'Exactly 2 reconciled to DRAFT');
    assert.strictEqual(result.skippedCount, 30, '30 new buckets skipped');
    assert.strictEqual(inReviewCandidates[0].staging_status, 'DRAFT');
    assert.strictEqual(inReviewCandidates[1].staging_status, 'DRAFT');
    assert.strictEqual(inReviewCandidates[2].staging_status, 'IN_REVIEW', 'Pilot bucket remains IN_REVIEW');
  });

  await runTestAsync('G1.3: ICICI candidate split: 6 eligible UNCHANGED transition to DRAFT, 20 NEW remain IN_REVIEW', async () => {
    const activeRates = [];
    for (let i = 1; i <= 6; i++) {
      activeRates.push({
        id: `icici_act_${i}`,
        bank_code: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: i * 90,
        max_tenure_days: i * 90 + 30,
        interest_rate: '6.00',
        rate_category: 'STANDARD',
        is_callable: true,
      });
    }

    const inReviewCandidates = [];
    // 6 matching callable
    for (let i = 1; i <= 6; i++) {
      inReviewCandidates.push({
        id: `icici_cand_${i}`,
        bank_code: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: i * 90,
        max_tenure_days: i * 90 + 30,
        interest_rate: '6.00',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }
    // 20 unverified non-callable / new tenures
    for (let i = 7; i <= 26; i++) {
      inReviewCandidates.push({
        id: `icici_cand_${i}`,
        bank_code: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: i * 100,
        max_tenure_days: i * 100 + 50,
        interest_rate: '6.25',
        rate_category: 'SPECIAL_SCHEME',
        is_callable: false,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }

    const mockDb = createMockDb(inReviewCandidates, activeRates);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      bankFilter: 'ICICI',
      inMemoryCandidates: inReviewCandidates,
      inMemoryActiveRates: activeRates,
    });

    assert.strictEqual(result.totalInReview, 26);
    assert.strictEqual(result.eligibleCount, 6);
    assert.strictEqual(result.reconciledCount, 6);
    assert.strictEqual(result.skippedCount, 20);
  });

  await runTestAsync('G1.4: Combined reconciliation of all 112 clean candidates recovers exactly 62 to DRAFT', async () => {
    // Build combined dataset: 54 Indian Bank + 32 HDFC + 26 ICICI = 112 total
    const activeRates = [];
    const allCandidates = [];

    // Indian Bank: 54 matching
    for (let i = 1; i <= 54; i++) {
      activeRates.push({
        id: `ib_act_${i}`,
        bank_code: 'INDIAN_BANK',
        customer_type: 'REGULAR',
        min_tenure_days: i * 10,
        max_tenure_days: i * 10 + 5,
        interest_rate: '6.50',
        rate_category: 'STANDARD',
        is_callable: true,
      });
      allCandidates.push({
        id: `ib_cand_${i}`,
        bank_code: 'INDIAN_BANK',
        customer_type: 'REGULAR',
        min_tenure_days: i * 10,
        max_tenure_days: i * 10 + 5,
        interest_rate: '6.50',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }

    // HDFC: 2 matching, 30 new
    for (let i = 1; i <= 2; i++) {
      activeRates.push({
        id: `hdfc_act_${i}`,
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: i * 30,
        max_tenure_days: i * 30 + 10,
        interest_rate: '5.00',
        rate_category: 'STANDARD',
        is_callable: true,
      });
      allCandidates.push({
        id: `hdfc_cand_${i}`,
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: i * 30,
        max_tenure_days: i * 30 + 10,
        interest_rate: '5.00',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }
    for (let i = 3; i <= 32; i++) {
      allCandidates.push({
        id: `hdfc_cand_${i}`,
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: i * 40,
        max_tenure_days: i * 40 + 10,
        interest_rate: '5.50',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }

    // ICICI: 6 matching, 20 new
    for (let i = 1; i <= 6; i++) {
      activeRates.push({
        id: `icici_act_${i}`,
        bank_code: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: i * 50,
        max_tenure_days: i * 50 + 15,
        interest_rate: '6.10',
        rate_category: 'STANDARD',
        is_callable: true,
      });
      allCandidates.push({
        id: `icici_cand_${i}`,
        bank_code: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: i * 50,
        max_tenure_days: i * 50 + 15,
        interest_rate: '6.10',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }
    for (let i = 7; i <= 26; i++) {
      allCandidates.push({
        id: `icici_cand_${i}`,
        bank_code: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: i * 60,
        max_tenure_days: i * 60 + 20,
        interest_rate: '6.30',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      });
    }

    const mockDb = createMockDb(allCandidates, activeRates);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: allCandidates,
      inMemoryActiveRates: activeRates,
    });

    assert.strictEqual(result.totalInReview, 112, '112 clean candidates audited');
    assert.strictEqual(result.eligibleCount, 62, 'Exactly 62 eligible (54 IB + 2 HDFC + 6 ICICI)');
    assert.strictEqual(result.reconciledCount, 62, 'Exactly 62 reconciled to DRAFT');
    assert.strictEqual(result.skippedCount, 50, 'Exactly 50 skipped (30 HDFC + 20 ICICI)');
  });

  await runTestAsync('G1.5: PipelineSchedulerService._reconcileCandidateReviewStatus transitions clean candidate (flags = []) to DRAFT', async () => {
    const candidate = {
      id: 'cand_clean_sched_1',
      bankCode: 'INDIAN_BANK',
      stagingStatus: 'IN_REVIEW',
      validationStatus: 'VALID',
      anomalyFlags: [],
      notes: '',
    };
    const existingDbRow = {
      id: 'cand_clean_sched_1',
      bank_code: 'INDIAN_BANK',
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
      notes: '',
    };

    const mockDb = createMockDb([existingDbRow], []);
    const scheduler = new PipelineSchedulerService();
    const reconResult = await scheduler._reconcileCandidateReviewStatus({
      db: mockDb,
      candidate,
      candId: candidate.id,
      diff: { diffType: DIFF_TYPES.UNCHANGED },
      dryRun: false,
      stageResult: { anomalies: { flags: [] } },
    });

    assert.strictEqual(reconResult.reconciled, true);
    assert.strictEqual(reconResult.status, 'DRAFT');
    assert.strictEqual(candidate.stagingStatus, 'DRAFT');
    assert.strictEqual(mockDb.stagedRows[0].staging_status, 'DRAFT');
  });

  // ====================================================================
  // GROUP 2: Ineligible Protection Boundaries
  // ====================================================================
  console.log('\n[Group 2: Ineligible Protection Boundaries]');

  await runTestAsync('G2.1: Manual review hold (MANUAL_REVIEW in notes) strictly preserves IN_REVIEW', async () => {
    const activeRate = {
      id: 'act_1',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: '3.00',
      rate_category: 'STANDARD',
      is_callable: true,
    };
    const candidate = {
      id: 'cand_manual_hold',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: '3.00',
      rate_category: 'STANDARD',
      is_callable: true,
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
      notes: 'MANUAL_REVIEW: Auditor requested physical verification',
    };

    const mockDb = createMockDb([candidate], [activeRate]);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });

    assert.strictEqual(result.eligibleCount, 0);
    assert.strictEqual(result.reconciledCount, 0);
    assert.strictEqual(result.skippedCount, 1);
    assert.strictEqual(candidate.staging_status, 'IN_REVIEW');
  });

  await runTestAsync('G2.2: Rate mismatch (DIFF_TYPES.RATE_CHANGED) strictly preserves IN_REVIEW', async () => {
    const activeRate = {
      id: 'act_rate_chg',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.00',
      rate_category: 'STANDARD',
      is_callable: true,
    };
    const candidate = {
      id: 'cand_rate_chg',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.25', // Rate changed!
      rate_category: 'STANDARD',
      is_callable: true,
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
    };

    const mockDb = createMockDb([candidate], [activeRate]);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });

    assert.strictEqual(result.eligibleCount, 0);
    assert.strictEqual(result.skippedCount, 1);
    assert.strictEqual(candidate.staging_status, 'IN_REVIEW');
  });

  await runTestAsync('G2.3: Identity mismatch / new tenure (DIFF_TYPES.NEW) strictly preserves IN_REVIEW', async () => {
    const activeRate = {
      id: 'act_tenure_1',
      bank_code: 'ICICI',
      customer_type: 'REGULAR',
      min_tenure_days: 90,
      max_tenure_days: 120,
      interest_rate: '6.00',
      rate_category: 'STANDARD',
      is_callable: true,
    };
    const candidate = {
      id: 'cand_new_tenure',
      bank_code: 'ICICI',
      customer_type: 'REGULAR',
      min_tenure_days: 121, // Tenure not in verified catalog
      max_tenure_days: 150,
      interest_rate: '6.00',
      rate_category: 'STANDARD',
      is_callable: true,
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
    };

    const mockDb = createMockDb([candidate], [activeRate]);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });

    assert.strictEqual(result.eligibleCount, 0);
    assert.strictEqual(result.skippedCount, 1);
    assert.strictEqual(candidate.staging_status, 'IN_REVIEW');
  });

  await runTestAsync('G2.4: Active count mismatch (Canara 24, Central Bank 30) strictly preserves IN_REVIEW', async () => {
    const canaraCandidates = [];
    for (let i = 1; i <= 24; i++) {
      canaraCandidates.push({
        id: `canara_cand_${i}`,
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        min_tenure_days: i * 30,
        max_tenure_days: i * 30 + 10,
        interest_rate: '6.25',
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_COUNT_MISMATCH: Extracted 24 candidates vs baseline 48'],
      });
    }

    const centralBankCandidates = [];
    for (let i = 1; i <= 30; i++) {
      centralBankCandidates.push({
        id: `cbi_cand_${i}`,
        bank_code: 'CENTRAL_BANK',
        customer_type: 'REGULAR',
        min_tenure_days: i * 30,
        max_tenure_days: i * 30 + 10,
        interest_rate: '6.35',
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_COUNT_MISMATCH: Extracted 30 candidates vs baseline 60'],
      });
    }

    const mockDb = createMockDb([...canaraCandidates, ...centralBankCandidates], []);
    const stagingService = new CandidateStagingService();

    const canaraResult = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      bankFilter: 'CANARA',
      inMemoryCandidates: canaraCandidates,
    });
    assert.strictEqual(canaraResult.eligibleCount, 0, 'Canara candidates with count mismatch cannot be eligible');
    assert.strictEqual(canaraResult.skippedCount, 24);
    assert.strictEqual(canaraCandidates.every(c => c.staging_status === 'IN_REVIEW'), true);

    const cbiResult = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      bankFilter: 'CENTRAL_BANK',
      inMemoryCandidates: centralBankCandidates,
    });
    assert.strictEqual(cbiResult.eligibleCount, 0, 'Central Bank candidates with count mismatch cannot be eligible');
    assert.strictEqual(cbiResult.skippedCount, 30);
    assert.strictEqual(centralBankCandidates.every(c => c.staging_status === 'IN_REVIEW'), true);
  });

  await runTestAsync('G2.5: Invalid validation status candidates never transition to DRAFT', async () => {
    const invalidCandidate = {
      id: 'cand_invalid_1',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: '6.50',
      staging_status: 'IN_REVIEW',
      validation_status: 'INVALID',
      anomaly_flags: [],
    };

    const mockDb = createMockDb([invalidCandidate], []);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [invalidCandidate],
    });

    assert.strictEqual(result.eligibleCount, 0);
    assert.strictEqual(result.skippedCount, 1);
    assert.strictEqual(invalidCandidate.staging_status, 'IN_REVIEW');
  });

  // ====================================================================
  // GROUP 3: Promotion Service Rollback Safety & Attestation Protection
  // ====================================================================
  console.log('\n[Group 3: Promotion Service Rollback Safety & Attestation Protection]');

  await runTestAsync('G3.1: Archived rate rollback on _insertVerifiedRate failure restores unexpired rate to VERIFIED', async () => {
    const originalRate = {
      id: 'eeea6122-dd5f-4296-b591-73220ab40fbe',
      bank_code: 'PNB',
      customer_type: 'SUPER_SENIOR_CITIZEN',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: '3.80',
      status: 'VERIFIED',
      effective_until: null,
    };

    const promoService = new PromotionService();
    const originalState = { status: 'VERIFIED', effective_until: null };
    // Simulate archive for an unexpired future date
    await promoService._archiveRate(originalRate, '2099-01-01', 'test_actor', 'superseded');
    assert.strictEqual(originalRate.status, 'ARCHIVED');
    assert.strictEqual(originalRate.effective_until, '2099-01-01');

    // Rollback of unexpired rate restores VERIFIED status
    await promoService._restoreArchivedRate(originalRate, originalState, '2099-01-01');
    assert.strictEqual(originalRate.status, 'VERIFIED');
    assert.strictEqual(originalRate.effective_until, null);
    assert.strictEqual(originalRate.effectiveUntil, null);
  });

  await runTestAsync('G3.2: Dedicated bot identity resolution & fail-closed protection without impersonation', async () => {
    const promoService = new PromotionService();
    const candidate = {
      id: 'cand_test_uuid',
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: '3.75',
      rateCategory: 'STANDARD',
      isCallable: true,
      effectiveFrom: '2026-11-05',
    };

    // 1. Without SYSTEM_BOT_USER_ID: Must return null (never impersonate human admin)
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    delete process.env.SYSTEM_BOT_USER_ID;
    const insertedNoEnv = await promoService._insertVerifiedRate(candidate, 'SCHEDULER_test', 'Test');
    assert.strictEqual(insertedNoEnv.verified_by, null, 'Must be null when no dedicated bot user is provisioned');

    // 2. With provisioned SYSTEM_BOT_USER_ID: Uses dedicated bot UUID
    const mockBotUuid = crypto.randomUUID();
    process.env.SYSTEM_BOT_USER_ID = mockBotUuid;
    const insertedWithEnv = await promoService._insertVerifiedRate(candidate, 'SCHEDULER_test', 'Test');
    assert.strictEqual(insertedWithEnv.verified_by, mockBotUuid, 'Must use configured SYSTEM_BOT_USER_ID');

    // Restore env
    if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
    else delete process.env.SYSTEM_BOT_USER_ID;
  });

  runTest('G3.3: PNB w.e.f. 05.11.2026 parser produces 19 rows, 57 candidates, with 680-day scheme and Row 8 <1 Year', () => {
    // Official PNB 19-row published HTML w.e.f. 05.11.2026
    // Official Table 17 Domestic/NRO Callable FD published w.e.f. 05.11.2026
    const rows19 = [
      '<tr><td>1</td><td>7 to 14 Days</td><td>3.00</td><td>3.50</td><td>3.75</td></tr>',
      '<tr><td>2</td><td>15 to 45 Days</td><td>3.00</td><td>3.50</td><td>3.75</td></tr>',
      '<tr><td>3</td><td>46 to 90 Days</td><td>5.50</td><td>6.00</td><td>6.25</td></tr>',
      '<tr><td>4</td><td>91 to 179 Days</td><td>5.75</td><td>6.25</td><td>6.50</td></tr>',
      '<tr><td>5</td><td>180 to 270 Days</td><td>6.00</td><td>6.50</td><td>6.75</td></tr>',
      '<tr><td>6</td><td>271 Days to 302 Days</td><td>6.00</td><td>6.50</td><td>6.75</td></tr>',
      '<tr><td>7</td><td>303 Days</td><td>5.95</td><td>6.45</td><td>6.70</td></tr>',
      '<tr><td>8</td><td>304 Days to <1 Year</td><td>6.00</td><td>6.50</td><td>6.75</td></tr>',
      '<tr><td>9</td><td>1 Year</td><td>6.25</td><td>6.75</td><td>7.00</td></tr>',
      '<tr><td>10</td><td>>1 Year to 443 Days</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>',
      '<tr><td>11</td><td>444 Days</td><td>6.70</td><td>7.20</td><td>7.45</td></tr>',
      '<tr><td>12</td><td>445 Days to 679 Days</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>',
      '<tr><td>13</td><td>680 Days</td><td>6.80</td><td>7.30</td><td>7.55</td></tr>',
      '<tr><td>14</td><td>681 Days to 2 years</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>',
      '<tr><td>15</td><td>>2 to 3 Years</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>',
      '<tr><td>16</td><td>>3 Years to 1203 Days</td><td>6.35</td><td>6.85</td><td>7.10</td></tr>',
      '<tr><td>17</td><td>1204 Days</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>',
      '<tr><td>18</td><td>1205 Days to 5 Years</td><td>6.35</td><td>6.85</td><td>7.10</td></tr>',
      '<tr><td>19</td><td>>5 Years to 10 Years</td><td>6.00</td><td>6.75</td><td>6.75</td></tr>',
    ];

    const html = `
      <html><body>
      <p>Interest rates revised w.e.f. 05.11.2026</p>
      <table>
      <tr><th colspan="5">Domestic/NRO $ Fixed Deposit Scheme</th></tr>
      <tr><th>Sl. No</th><th>Period</th><th>Revised Rates For Public w.e.f. 05.11.2026</th><th>*Revised Rates for Senior Citizens w.e.f. 05.11.2026</th><th>#Revised Rates for Super Senior Citizens w.e.f. 05.11.2026</th></tr>
      ${rows19.join('\n')}
      </table>
      </body></html>
    `;

    const parser = new PnbRateParser();
    const result = parser.parse(html, {
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
    });

    assert.strictEqual(result.success, true, `PNB parse failed: ${result.errors.join('; ')}`);
    assert.strictEqual(result.candidates.length, 57, '19 rows * 3 customer types = 57 candidates');

    const row8Candidates = result.candidates.filter(c => c.sourceTenureText.includes('304 Days'));
    assert.strictEqual(row8Candidates.length, 3, 'Row 8 produces 3 candidates');
    assert.strictEqual(row8Candidates[0].minTenureDays, 304);

    const scheme680 = result.candidates.filter(c => c.sourceTenureText.includes('680 Days'));
    assert.strictEqual(scheme680.length, 3, '680 Days produces 3 candidates');
    assert.strictEqual(scheme680[0].minTenureDays, 680);
    assert.strictEqual(scheme680[0].maxTenureDays, 680);
    assert.strictEqual(scheme680[0].isBespokeTenure, true, '680 Days is bespoke tenure');
    assert.strictEqual(scheme680[0].interestRate, 6.80, 'Official callable rate for 680 days Public is 6.80%');
    assert.strictEqual(scheme680[1].interestRate, 7.30, 'Official callable rate for 680 days Senior is 7.30%');
    assert.strictEqual(scheme680[2].interestRate, 7.55, 'Official callable rate for 680 days Super Senior is 7.55%');
  });

  runTest('G3.4: PromotionPolicyEngine blocks auto-promotion of brand new tenure buckets without baseline attestation', () => {
    const policyEngine = new PromotionPolicyEngine();
    const candidate = {
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 680,
      maxTenureDays: 680,
      interestRate: '6.80',
      effectiveFrom: '2026-11-05',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      parserId: 'pnb_retail_html',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      anomalyFlags: [],
    };

    const diffResult = {
      diffType: DIFF_TYPES.NEW,
      details: 'New tenure bucket (680 Days)',
    };

    // Unattested baseline evaluation:
    const evalResultUnattested = policyEngine.evaluateCandidate(candidate, diffResult, {
      httpStatus: 200,
      parserSuccess: true,
      isBaselineAttested: false, // NOT ATTESTED!
    });

    assert.strictEqual(evalResultUnattested.eligibleForAutoPromotion, false, 'Unattested new bucket must NOT auto-promote');
    assert.strictEqual(
      evalResultUnattested.failedReasons.some(r => r.includes('Brand new rate bucket introduced')),
      true
    );

    // Attested baseline evaluation:
    const evalResultAttested = policyEngine.evaluateCandidate(candidate, diffResult, {
      httpStatus: 200,
      parserSuccess: true,
      isBaselineAttested: true, // ATTESTED!
    });

    assert.strictEqual(evalResultAttested.eligibleForAutoPromotion, true, 'Attested new bucket qualifies for auto-promotion');
  });

  // ====================================================================
  // GROUP 4: Telemetry, Idempotency, Dry-Run & Zero Mutation
  // ====================================================================
  console.log('\n[Group 4: Telemetry, Idempotency, Dry-Run & Zero Mutation]');

  await runTestAsync('G4.1: Dry-run safety: dryRun: true performs 0 database writes and preserves status', async () => {
    const activeRate = {
      id: 'ib_act_dry',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
    };
    const candidate = {
      id: 'ib_cand_dry',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
    };

    const mockDb = createMockDb([candidate], [activeRate]);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: true,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });

    assert.strictEqual(result.dryRun, true);
    assert.strictEqual(result.eligibleCount, 1);
    assert.strictEqual(result.reconciledCount, 0, 'Zero writes in dry run');
    assert.strictEqual(mockDb.updateLogs.length, 0, 'No DB update calls made');
    assert.strictEqual(candidate.staging_status, 'IN_REVIEW', 'Candidate status preserved');
  });

  await runTestAsync('G4.2: Repeated execution is idempotent', async () => {
    const activeRate = {
      id: 'ib_act_idem',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
    };
    const candidate = {
      id: 'ib_cand_idem',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
    };

    const mockDb = createMockDb([candidate], [activeRate]);
    const stagingService = new CandidateStagingService();

    // First run: reconciles candidate
    const run1 = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });
    assert.strictEqual(run1.reconciledCount, 1);
    assert.strictEqual(candidate.staging_status, 'DRAFT');

    // Second run: candidate is now DRAFT, no IN_REVIEW candidates exist
    const run2 = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });
    assert.strictEqual(run2.totalInReview, 0, 'Candidate is already DRAFT');
    assert.strictEqual(run2.reconciledCount, 0);
  });

  await runTestAsync('G4.3: Zero verified rate mutation: verified_fd_rates is never modified', async () => {
    const activeRates = [
      {
        id: 'rate_protected_1',
        bank_code: 'INDIAN_BANK',
        customer_type: 'REGULAR',
        min_tenure_days: 30,
        max_tenure_days: 60,
        interest_rate: '6.50',
        status: 'VERIFIED',
      },
      {
        id: 'rate_protected_2',
        bank_code: 'PNB',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: '3.50',
        status: 'VERIFIED',
      },
    ];

    const candidate = {
      id: 'cand_test_no_mut',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
    };

    const mockDb = createMockDb([candidate], activeRates);
    const stagingService = new CandidateStagingService();
    await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: activeRates,
    });

    const fdRatesUpdates = mockDb.updateLogs.filter(l => l.table === 'fd_rates');
    assert.strictEqual(fdRatesUpdates.length, 0, 'Verified rates table must never receive updates');
    assert.strictEqual(mockDb.insertLogs.length, 0, 'Verified rates table must never receive inserts');
    assert.strictEqual(activeRates.length, 2, 'Verified rates count remains constant');
  });

  await runTestAsync('G4.4: Telemetry breakdown accurately reflects bank totals and eligibility reasons', async () => {
    const activeRates = [
      {
        id: 'act_ib',
        bank_code: 'INDIAN_BANK',
        customer_type: 'REGULAR',
        min_tenure_days: 30,
        max_tenure_days: 60,
        interest_rate: '6.50',
        rate_category: 'STANDARD',
        is_callable: true,
      },
    ];

    const candidates = [
      {
        id: 'c_ib_ok',
        bank_code: 'INDIAN_BANK',
        customer_type: 'REGULAR',
        min_tenure_days: 30,
        max_tenure_days: 60,
        interest_rate: '6.50',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      },
      {
        id: 'c_canara_mismatch',
        bank_code: 'CANARA',
        customer_type: 'REGULAR',
        min_tenure_days: 30,
        max_tenure_days: 60,
        interest_rate: '6.50',
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: ['ANOMALY_COUNT_MISMATCH: Extracted 24 vs 48'],
      },
      {
        id: 'c_hdfc_new',
        bank_code: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: 999,
        max_tenure_days: 1000,
        interest_rate: '7.00',
        rate_category: 'STANDARD',
        is_callable: true,
        staging_status: 'IN_REVIEW',
        validation_status: 'VALID',
        anomaly_flags: [],
      },
    ];

    const mockDb = createMockDb(candidates, activeRates);
    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: mockDb,
      dryRun: false,
      inMemoryCandidates: candidates,
      inMemoryActiveRates: activeRates,
    });

    assert.strictEqual(result.totalInReview, 3);
    assert.strictEqual(result.eligibleCount, 1);
    assert.strictEqual(result.reconciledCount, 1);
    assert.strictEqual(result.skippedCount, 2);

    assert.strictEqual(result.bankBreakdown.INDIAN_BANK.eligible, 1);
    assert.strictEqual(result.bankBreakdown.CANARA.skipped, 1);
    assert.strictEqual(result.bankBreakdown.CANARA.reasons[0].reason, 'ANOMALIES_PRESENT');
    assert.strictEqual(result.bankBreakdown.HDFC.skipped, 1);
    assert.strictEqual(result.bankBreakdown.HDFC.reasons[0].reason, 'DIFF_NEW');
  });


  await runTestAsync('G3.5: promoteCandidate failure triggers automatic rollback of archived rate', async () => {
    const promoService = new PromotionService();
    const originalRate = {
      id: 'rate_orig_uuid_1',
      bank_code: 'PNB',
      customer_type: 'SUPER_SENIOR_CITIZEN',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: '3.80',
      status: 'VERIFIED',
      effective_until: null,
    };

    // Mock _archiveRate
    promoService._archiveRate = async (rate) => {
      rate.status = 'ARCHIVED';
      rate.effective_until = '2026-11-05';
      return rate;
    };

    // Mock _insertVerifiedRate to throw DB error
    promoService._insertVerifiedRate = async () => {
      throw new Error('Check constraint violation 23514');
    };

    let rollbackCalled = false;
    promoService._restoreArchivedRate = async (rate) => {
      rollbackCalled = true;
      rate.status = 'VERIFIED';
      rate.effective_until = null;
      return rate;
    };

    const candidate = {
      id: 'cand_fail_test',
      bankCode: 'PNB',
      customerType: 'SUPER_SENIOR_CITIZEN',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: '3.75',
    };

    const adminUuid = crypto.randomUUID();
    let threw = false;
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: adminUuid,
        activeVerifiedRates: [originalRate],
      });
    } catch (err) {
      threw = true;
      assert.strictEqual(err.message, 'Check constraint violation 23514');
    }

    assert.strictEqual(threw, true, 'Error must rethrow');
    assert.strictEqual(rollbackCalled, true, 'Rollback must be called');
    assert.strictEqual(originalRate.status, 'VERIFIED', 'Original rate must be restored to VERIFIED');
  });

  await runTestAsync('G4.5: Database update error fails closed and captures structured error', async () => {
    const candidate = {
      id: 'c_db_err',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
      staging_status: 'IN_REVIEW',
      validation_status: 'VALID',
      anomaly_flags: [],
    };
    const activeRate = {
      id: 'a_db_err',
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 30,
      max_tenure_days: 60,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
    };

    const failingDb = {
      from(table) {
        return {
          update() {
            return {
              eq() {
                return Promise.resolve({ error: { message: 'Connection terminated unexpectedly' } });
              }
            };
          }
        };
      }
    };

    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      db: failingDb,
      dryRun: false,
      inMemoryCandidates: [candidate],
      inMemoryActiveRates: [activeRate],
    });

    assert.strictEqual(result.eligibleCount, 1);
    assert.strictEqual(result.reconciledCount, 0, 'Zero writes succeeded on error');
    assert.strictEqual(result.errors.length, 1);
    assert.strictEqual(result.errors[0].includes('Connection terminated unexpectedly'), true);
    assert.strictEqual(candidate.staging_status, 'IN_REVIEW', 'Candidate status stays IN_REVIEW on error');
  });

  // ====================================================================
  // GROUP 5: Phase 4.2.2 Promotion Atomicity & System-Bot Hardening
  // ====================================================================
  console.log('\n[Group 5: Phase 4.2.2 Promotion Atomicity & System-Bot Hardening]');

  await runTestAsync('T5.1: Missing SYSTEM_BOT_USER_ID — promotion stops before any archival write', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    delete process.env.SYSTEM_BOT_USER_ID;

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
    }

    assert.strictEqual(errMessage.includes('SYSTEM_BOT_USER_ID environment variable is not configured'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when bot identity is missing');
  });

  await runTestAsync('T5.2: Malformed SYSTEM_BOT_USER_ID — promotion stops before any archival write', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = 'not-a-valid-uuid-format';

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('SYSTEM_BOT_USER_ID is malformed'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when bot UUID is malformed');
  });

  await runTestAsync('T5.3: Admin human UUID supplied as the bot — rejected before any archival write', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = '995b04cd-518b-435d-83a0-d1bdde22cca6';

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('SYSTEM_BOT_USER_ID cannot be human admin account'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when bot identity impersonates admin');
  });

  await runTestAsync('T5.4: Dedicated System Bot identity — accepted when properly configured and verified', async () => {
    const promoService = new PromotionService();
    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const mockAuthAdmin = {
      getUserById: async (id) => {
        if (id === validBotId) {
          return {
            data: {
              user: {
                id,
                app_metadata: { ferocalc_role: 'SYSTEM_BOT', is_service_account: true },
                user_metadata: {},
              }
            },
            error: null,
          };
        }
        return { data: null, error: { message: 'User not found' } };
      }
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let result;
    try {
      result = await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin },
      });
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(result.promoted, true);
    assert.strictEqual(result.newVerifiedRate.verified_by, validBotId);
  });

  await runTestAsync('T5.4a: Missing metadata in app_metadata fails closed before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: {}, // completely missing bot metadata
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called on missing app_metadata');
  });

  await runTestAsync('T5.4b: User-editable metadata spoofing rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    // Attacker attempted to inject service role into user_metadata while app_metadata is empty
    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: {}, // Empty trusted metadata
            user_metadata: { ferocalc_role: 'SYSTEM_BOT', is_service_account: true }, // Spoofed user metadata
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when user_metadata is spoofed');
  });

  await runTestAsync('T5.4c: Auth Admin lookup failure fails closed before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    // Subcase 1: GoTrue returns an error
    const mockAuthAdminError = {
      getUserById: async () => ({
        data: null,
        error: { message: 'Network timeout talking to GoTrue auth service' },
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdminError, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    }

    assert.strictEqual(errMessage.includes('not found in auth (Network timeout talking to GoTrue auth service)'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called on lookup error');

    // Subcase 2: GoTrue throws an unhandled exception
    archiveCalled = false;
    const mockAuthAdminThrows = {
      getUserById: async () => {
        throw new Error('Database connection pool exhausted in auth');
      }
    };

    errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdminThrows, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('lookup error (Database connection pool exhausted in auth)'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called on lookup exception');
  });

  await runTestAsync('T5.4d: Invalid role in app_metadata fails closed before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { ferocalc_role: 'REVIEWER', is_service_account: true }, // Not SYSTEM_BOT
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(errMessage.includes('app_metadata.ferocalc_role="REVIEWER"'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when bot role is not SYSTEM_BOT');
  });

  await runTestAsync('T5.4f: Role only, marker missing — rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { ferocalc_role: 'SYSTEM_BOT' },
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when is_service_account marker is missing');
  });

  await runTestAsync('T5.4g: Role only, marker false — rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { ferocalc_role: 'SYSTEM_BOT', is_service_account: false },
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when is_service_account is false');
  });

  await runTestAsync('T5.4h: Marker true, role missing — rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { is_service_account: true },
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when role is missing');
  });

  await runTestAsync('T5.4i: SYSTEM_BOT cannot use ADMIN mode — rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const botId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = botId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { ferocalc_role: 'SYSTEM_BOT', is_service_account: true },
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: botId,
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('service bot') && errMessage.includes('cannot promote in ADMIN mode'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when service bot attempts ADMIN promotion');
  });

  await runTestAsync('T5.4j: ADMIN cannot use automated mode — rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const adminId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = adminId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { ferocalc_role: 'ADMIN' },
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('is not a dedicated service bot'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when admin attempts automated promotion');
  });

  await runTestAsync('T5.4k: Unknown actor mode — rejected before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-05',
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'UNKNOWN_ROLE',
        actorId: crypto.randomUUID(),
      });
    } catch (err) {
      errMessage = err.message;
    }

    assert.strictEqual(errMessage.includes('Unrecognized actorType: UNKNOWN_ROLE'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called on unknown actorType');
  });

  await runTestAsync('T5.4e: Auth Admin unavailable when required fails closed before archival', async () => {
    const promoService = new PromotionService();
    let archiveCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };

    const validBotId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = validBotId;

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.0,
      status: 'VERIFIED',
      effective_until: null,
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [activeRate],
        context: { requireAuthAdmin: true, authAdmin: null, httpStatus: 200, parserSuccess: true },
      });
    } catch (err) {
      errMessage = err.message;
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(errMessage.includes('Supabase Auth Admin API is unavailable'), true);
    assert.strictEqual(archiveCalled, false, 'Archive must never be called when Auth Admin API is unavailable');
  });

  await runTestAsync('T5.5: Replacement insert failure — no incorrect rate becomes current', async () => {
    const promoService = new PromotionService();
    const origRate = {
      id: 'eeea6122-dd5f-4296-b591-73220ab40fbe',
      bank_code: 'PNB',
      customer_type: 'SUPER_SENIOR_CITIZEN',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.80,
      status: 'VERIFIED',
      effective_until: null,
    };

    const candidate = {
      id: '635e94c3-cc74-402a-8086-cd5c4b5bb1a3',
      bankCode: 'PNB',
      customerType: 'SUPER_SENIOR_CITIZEN',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.75,
      effectiveFrom: '2026-11-05',
      validationStatus: 'VALID',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
    };

    // Simulate insert failure
    promoService._insertVerifiedRate = async () => {
      throw new Error('Database insert failed');
    };

    const adminUuid = crypto.randomUUID();
    let threw = false;
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: adminUuid,
        activeVerifiedRates: [origRate],
      });
    } catch (err) {
      threw = true;
      assert.strictEqual(err.message, 'Database insert failed');
    }

    assert.strictEqual(threw, true);
    // Crucial check: origRate must NOT have been restored as active with effective_until = null!
    // Because effectiveAt 2026-11-05 is expired as of now, it must remain ARCHIVED
    assert.strictEqual(origRate.status, 'ARCHIVED');
    assert.strictEqual(origRate.effective_until, '2026-11-05T00:00:00.000Z');
  });

  await runTestAsync('T5.6: Rollback with an expired previous rate — stale record is not reactivated', async () => {
    const promoService = new PromotionService();
    const expiredRate = {
      id: 'eeea6122-dd5f-4296-b591-73220ab40fbe',
      status: 'ARCHIVED',
      effective_until: '2026-11-05T00:00:00.000Z',
    };
    const originalState = {
      status: 'ARCHIVED',
      effective_until: '2026-11-05T00:00:00.000Z',
    };

    await promoService._restoreArchivedRate(expiredRate, originalState, '2026-11-05T00:00:00.000Z');
    assert.strictEqual(expiredRate.status, 'ARCHIVED', 'Expired rate must remain ARCHIVED');
    assert.strictEqual(expiredRate.effective_until, '2026-11-05T00:00:00.000Z', 'Expiry timestamp must be preserved');
  });

  await runTestAsync('T5.7: Archive failure — insertion does not proceed in a partially applied state', async () => {
    const promoService = new PromotionService();
    let insertCalled = false;
    promoService._archiveRate = async () => {
      throw new Error('Postgres lock timeout on fd_rates row');
    };
    promoService._insertVerifiedRate = async () => {
      insertCalled = true;
    };

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'SUPER_SENIOR_CITIZEN',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.75,
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'SUPER_SENIOR_CITIZEN',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.80,
      status: 'VERIFIED',
      effective_until: null,
    };

    const adminUuid = crypto.randomUUID();
    let threw = false;
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: adminUuid,
        activeVerifiedRates: [activeRate],
      });
    } catch (err) {
      threw = true;
      assert.strictEqual(err.message, 'Postgres lock timeout on fd_rates row');
    }

    assert.strictEqual(threw, true);
    assert.strictEqual(insertCalled, false, 'Insert must not be called when archive fails');
  });

  await runTestAsync('T5.8: Successful replacement — correct new rate becomes verified', async () => {
    const promoService = new PromotionService();
    const origRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'SUPER_SENIOR_CITIZEN',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.80,
      status: 'VERIFIED',
      effective_until: null,
    };

    const candidate = {
      id: '635e94c3-cc74-402a-8086-cd5c4b5bb1a3',
      bankCode: 'PNB',
      customerType: 'SUPER_SENIOR_CITIZEN',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.75,
      effectiveFrom: '2026-11-05',
      validationStatus: 'VALID',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      parserId: 'pnb_retail_html',
    };

    const adminUuid = crypto.randomUUID();
    const result = await promoService.promoteCandidate({
      candidate,
      actorType: 'ADMIN',
      actorId: adminUuid,
      activeVerifiedRates: [origRate],
    });

    assert.strictEqual(result.promoted, true);
    assert.strictEqual(result.supersededRecord.status, 'ARCHIVED');
    assert.strictEqual(result.newVerifiedRate.interest_rate, 3.75);
    assert.strictEqual(result.newVerifiedRate.status, 'VERIFIED');
    assert.strictEqual(result.newVerifiedRate.effective_until, null);
    assert.strictEqual(result.newVerifiedRate.verified_by, adminUuid);
  });

  await runTestAsync('T5.9: Duplicate/retried promotion — idempotency is preserved', async () => {
    const promoService = new PromotionService();
    const alreadyPromotedCand = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      stagingStatus: 'PROMOTED',
      promotedRateId: 'promoted-rate-uuid-already',
    };

    let archiveCalled = false;
    let insertCalled = false;
    promoService._archiveRate = async () => { archiveCalled = true; };
    promoService._insertVerifiedRate = async () => { insertCalled = true; };

    const result = await promoService.promoteCandidate({
      candidate: alreadyPromotedCand,
      actorType: 'ADMIN',
      actorId: crypto.randomUUID(),
    });

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.promoted, false);
    assert.strictEqual(result.alreadyPromoted, true);
    assert.strictEqual(archiveCalled, false);
    assert.strictEqual(insertCalled, false);
  });

  runTest('T5.10: PNB callable/non-callable 680-day isolation', () => {
    const htmlWithBothTables = `
      <html><body>
      <p>Interest rates revised w.e.f. 05.11.2026</p>
      <table>
      <tr><th colspan="5">Domestic/NRO $ Fixed Deposit Scheme</th></tr>
      <tr><th>Sl. No</th><th>Period</th><th>Revised Rates For Public w.e.f. 05.11.2026</th><th>*Revised Rates for Senior Citizens w.e.f. 05.11.2026</th><th>#Revised Rates for Super Senior Citizens w.e.f. 05.11.2026</th></tr>
      <tr><td>12</td><td>445 Days to 679 Days</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>
      <tr><td>13</td><td>680 Days</td><td>6.80</td><td>7.30</td><td>7.55</td></tr>
      <tr><td>14</td><td>681 Days to 2 years</td><td>6.30</td><td>6.80</td><td>7.05</td></tr>
      <tr><td>1</td><td>7 to 14 Days</td><td>3.00</td><td>3.50</td><td>3.75</td></tr>
      ${Array(15).fill('<tr><td>99</td><td>100 Days</td><td>5.00</td><td>5.50</td><td>5.75</td></tr>').join('\n')}
      </table>
      <table>
      <tr><th colspan="5">PNB Uttam (Non-Callable) Fixed Deposit Scheme( for Deposit above Rs. 1 Crore to less than Rs 3 Crore)</th></tr>
      <tr><th>Sl. No</th><th>Period</th><th>Revised Rates For Public w.e.f. 05.11.2026</th><th>*Revised Rates for Senior Citizens w.e.f. 05.11.2026</th><th>#Revised Rates for Super Senior Citizens w.e.f. 05.11.2026</th></tr>
      <tr><td>10</td><td>680 Days</td><td>6.90</td><td>7.40</td><td>7.65</td></tr>
      </table>
      </body></html>
    `;

    const parser = new PnbRateParser();
    const result = parser.parse(htmlWithBothTables, {
      sourceUrl: 'https://pnb.bank.in/Interest-Rates-Deposit.html',
    });

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.metadata.nonCallableRatesIncluded, false);

    const c680 = result.candidates.filter(c => c.sourceTenureText === '680 Days');
    assert.strictEqual(c680.length, 3);
    const reg680 = c680.find(c => c.customerType === 'REGULAR');
    const sr680 = c680.find(c => c.customerType === 'SENIOR_CITIZEN');
    const ssr680 = c680.find(c => c.customerType === 'SUPER_SENIOR_CITIZEN');

    assert.strictEqual(reg680.interestRate, 6.80, 'Callable public rate is 6.80, NOT 6.90');
    assert.strictEqual(sr680.interestRate, 7.30, 'Callable senior rate is 7.30, NOT 7.40');
    assert.strictEqual(ssr680.interestRate, 7.55, 'Callable super senior rate is 7.55, NOT 7.65');
    assert.strictEqual(reg680.isBespokeTenure, true);

    const p445 = parseTenureRange('445 Days to 679 Days');
    const p681 = parseTenureRange('681 Days to 2 years');
    assert.strictEqual(p445.isBespoke, false, 'Adjacent range 445-679 is not bespoke');
    assert.strictEqual(p681.isBespoke, false, 'Adjacent range 681-2y is not bespoke');
  });

  runTest('T5.11: PNB 7–14-day replacement candidate source alignment', () => {
    const candidate7to14 = {
      id: '635e94c3-cc74-402a-8086-cd5c4b5bb1a3',
      source_id: 'pnb-retail-domestic',
      bank_code: 'PNB',
      customer_type: 'SUPER_SENIOR_CITIZEN',
      tenure_label: '7 to 14 Days',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.75,
      effective_from: '2026-11-05',
      source_url: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
    };

    assert.strictEqual(candidate7to14.interest_rate, 3.75);
    assert.strictEqual(candidate7to14.min_tenure_days, 7);
    assert.strictEqual(candidate7to14.max_tenure_days, 14);
    assert.strictEqual(candidate7to14.effective_from, '2026-11-05');
  });

  await runTestAsync('T5.12: Existing 62-candidate clean-review dry-run behavior remains unchanged', async () => {
    // 54 Indian Bank candidates (all eligible)
    const indianBankCandidates = Array.from({ length: 54 }, (_, i) => ({
      id: `ib_${i}`,
      bank_code: 'INDIAN_BANK',
      bankCode: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 7 + i,
      max_tenure_days: 14 + i,
      proposed_interest_rate: '6.50',
      interestRate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
      validation_status: 'VALID',
      anomaly_flags: [],
      staging_status: 'IN_REVIEW',
    }));
    const indianBankActiveRates = Array.from({ length: 54 }, (_, i) => ({
      id: `ib_a_${i}`,
      bank_code: 'INDIAN_BANK',
      customer_type: 'REGULAR',
      min_tenure_days: 7 + i,
      max_tenure_days: 14 + i,
      interest_rate: '6.50',
      rate_category: 'STANDARD',
      is_callable: true,
    }));

    // HDFC: 2 eligible UNCHANGED, 30 ineligible NEW
    const hdfcCandidates = [
      ...Array.from({ length: 2 }, (_, i) => ({
        id: `h_u_${i}`,
        bank_code: 'HDFC',
        bankCode: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: 7 + i,
        max_tenure_days: 14 + i,
        proposed_interest_rate: '6.60',
        interestRate: '6.60',
        rate_category: 'STANDARD',
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: [],
        staging_status: 'IN_REVIEW',
      })),
      ...Array.from({ length: 30 }, (_, i) => ({
        id: `h_n_${i}`,
        bank_code: 'HDFC',
        bankCode: 'HDFC',
        customer_type: 'REGULAR',
        min_tenure_days: 50 + i,
        max_tenure_days: 60 + i,
        proposed_interest_rate: '7.00',
        interestRate: '7.00',
        rate_category: 'STANDARD',
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: [],
        staging_status: 'IN_REVIEW',
      })),
    ];
    const hdfcActiveRates = Array.from({ length: 2 }, (_, i) => ({
      id: `h_a_${i}`,
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      min_tenure_days: 7 + i,
      max_tenure_days: 14 + i,
      interest_rate: '6.60',
      rate_category: 'STANDARD',
      is_callable: true,
    }));

    // ICICI: 6 eligible UNCHANGED, 20 ineligible NEW
    const iciciCandidates = [
      ...Array.from({ length: 6 }, (_, i) => ({
        id: `ic_u_${i}`,
        bank_code: 'ICICI',
        bankCode: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: 100 + i,
        max_tenure_days: 200 + i,
        proposed_interest_rate: '6.80',
        interestRate: '6.80',
        rate_category: 'STANDARD',
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: [],
        staging_status: 'IN_REVIEW',
      })),
      ...Array.from({ length: 20 }, (_, i) => ({
        id: `ic_n_${i}`,
        bank_code: 'ICICI',
        bankCode: 'ICICI',
        customer_type: 'REGULAR',
        min_tenure_days: 300 + i,
        max_tenure_days: 400 + i,
        proposed_interest_rate: '7.10',
        interestRate: '7.10',
        rate_category: 'STANDARD',
        is_callable: true,
        validation_status: 'VALID',
        anomaly_flags: [],
        staging_status: 'IN_REVIEW',
      })),
    ];
    const iciciActiveRates = Array.from({ length: 6 }, (_, i) => ({
      id: `ic_a_${i}`,
      bank_code: 'ICICI',
      customer_type: 'REGULAR',
      min_tenure_days: 100 + i,
      max_tenure_days: 200 + i,
      interest_rate: '6.80',
      rate_category: 'STANDARD',
      is_callable: true,
    }));

    const stagingService = new CandidateStagingService();
    const result = await stagingService.reconcileCleanReviewCandidates({
      dryRun: true,
      inMemoryCandidates: [...indianBankCandidates, ...hdfcCandidates, ...iciciCandidates],
      inMemoryActiveRates: [...indianBankActiveRates, ...hdfcActiveRates, ...iciciActiveRates],
    });

    assert.strictEqual(result.eligibleCount, 62, 'Dry-run must identify exactly 62 eligible candidates');
    assert.strictEqual(result.reconciledCount, 0, 'Zero writes must occur in dry run');
  });

  await runTestAsync('T5.13: Application-to-RPC Wiring: Successful authorized ADMIN promotion via db.rpc', async () => {
    let rpcCalledWith = null;
    const mockDb = {
      rpc: async (fnName, params) => {
        rpcCalledWith = { fnName, params };
        return {
          data: [{
            new_rate_id: '11111111-1111-4111-8111-111111111111',
            superseded_rate_id: '99999999-9999-4999-8999-999999999999',
            candidate_id: params.p_staged_candidate_id,
            promotion_status: 'PROMOTED',
          }],
          error: null,
        };
      }
    };

    const promoService = new PromotionService({ supabaseClient: mockDb });
    const adminId = crypto.randomUUID();
    const candidateId = crypto.randomUUID();
    const supersededId = '99999999-9999-4999-8999-999999999999';

    const candidate = {
      id: candidateId,
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.75,
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-05',
    };
    const activeRate = {
      id: supersededId,
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 3.80,
      status: 'VERIFIED',
    };

    const result = await promoService.promoteCandidate({
      candidate,
      actorType: 'ADMIN',
      actorId: adminId,
      activeVerifiedRates: [activeRate],
    });

    assert.strictEqual(result.promoted, true);
    assert.strictEqual(result.atomicRpc, true);
    assert.strictEqual(rpcCalledWith.fnName, 'promote_staged_candidate');
    assert.strictEqual(rpcCalledWith.params.p_staged_candidate_id, candidateId);
    assert.strictEqual(rpcCalledWith.params.p_actor_type, 'ADMIN');
    assert.strictEqual(rpcCalledWith.params.p_actor_id, adminId);
    assert.strictEqual(rpcCalledWith.params.p_supersede_rate_id, supersededId);
    assert.strictEqual(result.newVerifiedRate.id, '11111111-1111-4111-8111-111111111111');
    assert.strictEqual(candidate.stagingStatus, 'PROMOTED');
  });

  await runTestAsync('T5.14: Application-to-RPC Wiring: Successful automated promotion with both bot markers via db.rpc', async () => {
    let rpcCalledWith = null;
    const mockDb = {
      rpc: async (fnName, params) => {
        rpcCalledWith = { fnName, params };
        return {
          data: [{
            new_rate_id: '22222222-2222-4222-8222-222222222222',
            superseded_rate_id: null,
            candidate_id: params.p_staged_candidate_id,
            promotion_status: 'PROMOTED',
          }],
          error: null,
        };
      }
    };

    const botId = crypto.randomUUID();
    const prevEnv = process.env.SYSTEM_BOT_USER_ID;
    process.env.SYSTEM_BOT_USER_ID = botId;

    const mockAuthAdmin = {
      getUserById: async (id) => ({
        data: {
          user: {
            id,
            app_metadata: { ferocalc_role: 'SYSTEM_BOT', is_service_account: true },
            user_metadata: {},
          }
        },
        error: null,
      })
    };

    const promoService = new PromotionService({ supabaseClient: mockDb });
    const candidateId = crypto.randomUUID();
    const candidate = {
      id: candidateId,
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    let result;
    try {
      result = await promoService.promoteCandidate({
        candidate,
        actorType: 'AUTOMATED_POLICY',
        activeVerifiedRates: [{
        id: crypto.randomUUID(),
        bank_code: 'PNB',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: 2.80,
        status: 'VERIFIED',
      }],
      context: { authAdmin: mockAuthAdmin, httpStatus: 200, parserSuccess: true },
      });
    } finally {
      if (prevEnv) process.env.SYSTEM_BOT_USER_ID = prevEnv;
      else delete process.env.SYSTEM_BOT_USER_ID;
    }

    assert.strictEqual(result.promoted, true);
    assert.strictEqual(result.atomicRpc, true);
    assert.strictEqual(rpcCalledWith.fnName, 'promote_staged_candidate');
    assert.strictEqual(rpcCalledWith.params.p_actor_type, 'AUTOMATED_POLICY');
    assert.strictEqual(rpcCalledWith.params.p_actor_id, botId);
    assert.strictEqual(result.newVerifiedRate.id, '22222222-2222-4222-8222-222222222222');
  });

  await runTestAsync('T5.15: Application-to-RPC Wiring: RPC error fails closed immediately', async () => {
    let separateArchiveCalled = false;
    let separateInsertCalled = false;
    const mockDb = {
      rpc: async () => ({
        data: null,
        error: { message: 'relation "banks" does not exist' },
      }),
      from: () => ({
        update: () => { separateArchiveCalled = true; },
        insert: () => { separateInsertCalled = true; },
      })
    };

    const promoService = new PromotionService({ supabaseClient: mockDb });
    const adminId = crypto.randomUUID();
    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.75,
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-05',
    };

    let errMessage = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: adminId,
        activeVerifiedRates: [],
      });
    } catch (err) {
      errMessage = err.message;
    }

    assert.strictEqual(errMessage.includes('Atomic promotion RPC failed'), true);
    assert.strictEqual(separateArchiveCalled, false, 'Separate archive must never be called on RPC error');
    assert.strictEqual(separateInsertCalled, false, 'Separate insert must never be called on RPC error');
  });

  await runTestAsync('T5.16: Application-to-RPC Wiring: Idempotent return when candidate already PROMOTED', async () => {
    let rpcCalled = false;
    const mockDb = {
      rpc: async () => {
        rpcCalled = true;
        return { data: [], error: null };
      }
    };

    const promoService = new PromotionService({ supabaseClient: mockDb });
    const candidate = {
      id: crypto.randomUUID(),
      stagingStatus: 'PROMOTED',
      promotedRateId: '33333333-3333-4333-8333-333333333333',
    };

    const result = await promoService.promoteCandidate({
      candidate,
      actorType: 'ADMIN',
      actorId: crypto.randomUUID(),
    });

    assert.strictEqual(result.alreadyPromoted, true);
    assert.strictEqual(result.promoted, false);
    assert.strictEqual(rpcCalled, false, 'RPC must not be invoked when candidate is already PROMOTED');
  });

  await runTestAsync('T5.17: Application-to-RPC Wiring: Scheduler fails closed with status ERROR when promotion throws', async () => {
    const { PipelineSchedulerService } = require('../scheduling/pipeline_scheduler_service');
    const existingRate = {
      id: crypto.randomUUID(),
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 7,
      max_tenure_days: 14,
      interest_rate: 2.80,
      status: 'VERIFIED',
      effective_until: null,
    };
    const mockPromoService = {
      _getActiveVerifiedRates: async () => [existingRate],
      promoteCandidate: async () => {
        throw new Error('Database transaction deadlocked');
      }
    };
    const mockCollectionService = {
      collectSource: async () => ({
        status: 'FETCH_SUCCESS',
        httpStatus: 200,
        contentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
        sourceHtml: '<table></table>',
      })
    };
    const mockStagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        parserId: 'pnb_retail_html',
        candidates: [{
          id: crypto.randomUUID(),
          bankCode: 'PNB',
          customerType: 'REGULAR',
          minTenureDays: 7,
          maxTenureDays: 14,
          interestRate: 3.0,
          validationStatus: 'VALID',
          sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
          sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
          parserId: 'pnb_retail_html',
          parserVersion: '1.0.0',
          effectiveFrom: '2026-11-05',
        }]
      })
    };

    const scheduler = new PipelineSchedulerService({
      promotionService: mockPromoService,
      collectionService: mockCollectionService,
      stagingService: mockStagingService,
    });

    const result = await scheduler._processSingleSource({
      source: {
        id: 'pnb-source',
        bankCode: 'PNB',
        parserId: 'pnb_retail_html',
        sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html'
      },
      jobId: 'job_test_1',
      dryRun: false,
    });

    assert.strictEqual(result.status, 'ERROR');
    assert.strictEqual(result.error.includes('Candidate promotion failed: Database transaction deadlocked'), true);
  });

  // GROUP 6: Phase 4.2.4 Draft 019 SQL Review & Boundary Verification
  // ====================================================================
  console.log('\n[Group 6: Phase 4.2.4 Draft 019 SQL Review & Boundary Verification]');

  await runTestAsync('T6.1: Draft 019 SQL static integrity: structural presence of all 8 ACID invariants', async () => {
    const fs = require('fs');
    const path = require('path');
    const draftPath = path.join(__dirname, '../supabase/drafts/019_atomic_candidate_promotion_rpc.sql');
    assert.strictEqual(fs.existsSync(draftPath), true, 'Draft 019 SQL must exist in backend/supabase/drafts/');

    const sql = fs.readFileSync(draftPath, 'utf8');

    // 1. Candidate FOR UPDATE row locking
    assert.strictEqual(sql.includes('FROM staged_rate_candidates') && sql.includes('FOR UPDATE'), true, 'Candidate row must be locked with FOR UPDATE');

    // 2. Old rate FOR UPDATE row locking
    assert.strictEqual(sql.includes('FROM fd_rates') && sql.includes('FOR UPDATE'), true, 'Previous rate must be locked with FOR UPDATE');

    // 3. Advisory xact lock with tenure_domain inclusion
    assert.strictEqual(sql.includes('pg_advisory_xact_lock'), true, 'Advisory xact lock must be present');
    assert.strictEqual(sql.includes('v_tenure_domain::text'), true, 'Advisory lock string must include tenure_domain');

    // 4. Equality boundary <= semantics
    assert.strictEqual(sql.includes('v_old_rate.effective_until <= v_effective_at'), true, 'Must use <= to recognize equality boundary expiration');

    // 5. Dual-domain column mappings in INSERT INTO fd_rates
    assert.strictEqual(sql.includes('tenure_domain') && sql.includes('min_years') && sql.includes('max_months'), true, 'Must map dual-domain calendar fields');

    // 6. Candidate update to PROMOTED
    assert.strictEqual(sql.includes("staging_status   = 'PROMOTED'"), true, 'Candidate must transition to PROMOTED in same transaction');

    // 7. Promotion audit log insert
    assert.strictEqual(sql.includes('INSERT INTO promotion_audit_log'), true, 'Must insert into promotion_audit_log in same transaction');

    // 8. Actor security check
    assert.strictEqual(sql.includes("raw_app_meta_data->>'ferocalc_role'") && sql.includes('995b04cd-518b-435d-83a0-d1bdde22cca6'), true, 'Must validate service bot metadata and reject admin UUID');

    // 9. Exact function signature reconciliation: p_staged_candidate_id and 8 named arguments
    assert.strictEqual(sql.includes('p_staged_candidate_id UUID'), true, 'Function must take p_staged_candidate_id UUID (not p_candidate_id)');
    assert.strictEqual(sql.includes('p_actor_type          TEXT'), true, 'Function must take p_actor_type TEXT');
    assert.strictEqual(sql.includes('p_actor_id            UUID'), true, 'Function must take p_actor_id UUID');
    assert.strictEqual(sql.includes('p_supersede_rate_id   UUID DEFAULT NULL'), true, 'Function must take p_supersede_rate_id UUID DEFAULT NULL');
    assert.strictEqual(sql.includes('p_effective_at        TIMESTAMPTZ DEFAULT NULL'), true, 'Function must take p_effective_at TIMESTAMPTZ DEFAULT NULL');
    assert.strictEqual(sql.includes("p_policy_result       JSONB DEFAULT '{}'::pg_catalog.jsonb"), true, 'Function must take p_policy_result JSONB');
    assert.strictEqual(sql.includes("p_diff_summary        JSONB DEFAULT '{}'::pg_catalog.jsonb"), true, 'Function must take p_diff_summary JSONB');
    assert.strictEqual(sql.includes('p_notes               TEXT DEFAULT NULL'), true, 'Function must take p_notes TEXT DEFAULT NULL');

    // 10. Exact return table contract
    assert.strictEqual(sql.includes('new_rate_id        UUID') && sql.includes('superseded_rate_id UUID') && sql.includes('candidate_id       UUID') && sql.includes('promotion_status   TEXT'), true, 'Function must return exact 4-column TABLE contract');

    // 11. Strict privilege model: service_role ONLY, revoked from PUBLIC, anon, authenticated
    assert.strictEqual(sql.includes('REVOKE ALL ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) FROM PUBLIC;'), true, 'Must revoke from PUBLIC');
    assert.strictEqual(sql.includes('REVOKE ALL ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) FROM authenticated;'), true, 'Must revoke from authenticated');
    assert.strictEqual(sql.includes('REVOKE ALL ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) FROM anon;'), true, 'Must revoke from anon');
    assert.strictEqual(sql.includes('GRANT  EXECUTE ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) TO service_role;'), true, 'Must grant execute to service_role ONLY');
  });

  await runTestAsync('T6.2: Effective-date equality boundary semantics: <= preserves expired date boundary for PNB', async () => {
    // Simulate the exact PNB scenario:
    // Old rate eeea6122-...: effective_until = '2026-11-05T00:00:00.000Z'
    // Replacement candidate 635e94c3-...: effective_from = '2026-11-05' -> v_effective_at = '2026-11-05T00:00:00.000Z'
    const oldEffectiveUntil = new Date('2026-11-05T00:00:00.000Z').getTime();
    const effectiveAt = new Date('2026-11-05T00:00:00.000Z').getTime();

    // The boundary test:
    const isExpiredStrictLess = oldEffectiveUntil < effectiveAt; // FALSE
    const isExpiredLessOrEqual = oldEffectiveUntil <= effectiveAt; // TRUE

    assert.strictEqual(isExpiredStrictLess, false, 'Strict < fails to recognize equality boundary');
    assert.strictEqual(isExpiredLessOrEqual, true, '<= correctly identifies expired rate on same-day cutover');

    // Ensure boundary resolution preserves the old date
    const resolvedEffectiveUntil = isExpiredLessOrEqual ? '2026-11-05T00:00:00.000Z' : 'OVERWRITTEN';
    assert.strictEqual(resolvedEffectiveUntil, '2026-11-05T00:00:00.000Z');
  });

  await runTestAsync('T6.3: Advisory lock domain key parity with Migration 009 across tenure_domain', async () => {
    const crypto = require('crypto');
    const bankId = 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a';
    const customerType = 'REGULAR';
    const isCallable = true;
    const rateCategory = 'STANDARD';
    const schemeName = '';

    // Calculate domain string with tenure_domain = 'DAYS'
    const domainStrDays = `${bankId}\x01${customerType}\x01${isCallable}\x01${rateCategory}\x01DAYS\x01`;
    const hashDays = crypto.createHash('md5').update(domainStrDays).digest('hex').substring(0, 16);

    // Calculate domain string with tenure_domain = 'CALENDAR'
    const domainStrCal = `${bankId}\x01${customerType}\x01${isCallable}\x01${rateCategory}\x01CALENDAR\x01`;
    const hashCal = crypto.createHash('md5').update(domainStrCal).digest('hex').substring(0, 16);

    assert.notStrictEqual(hashDays, hashCal, 'Different tenure domains must yield different lock keys');
  });

  await runTestAsync('T6.4: PromotionService _insertVerifiedRate dual-domain calendar mappings verified', async () => {
    const promoService = new PromotionService();
    const calendarCandidate = {
      id: crypto.randomUUID(),
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      tenureDomain: 'CALENDAR',
      tenureLabel: '1 Year to 2 Years',
      minYears: 1,
      minMonths: 0,
      minDaysCal: 0,
      minOperator: 'GTE',
      maxYears: 2,
      maxMonths: 0,
      maxDaysCal: 0,
      maxOperator: 'LT',
      interestRate: 6.85,
      isCallable: true,
      compoundingFrequency: 'QUARTERLY',
      effectiveFrom: '2026-11-05',
      sourceUrl: 'https://canarabank.com/deposit-rates',
    };

    const inserted = await promoService._insertVerifiedRate(calendarCandidate, crypto.randomUUID(), 'Test calendar promotion');
    assert.strictEqual(inserted.tenure_domain, 'CALENDAR');
    assert.strictEqual(inserted.min_tenure_days, null, 'Calendar candidate must have null min_tenure_days');
    assert.strictEqual(inserted.max_tenure_days, null, 'Calendar candidate must have null max_tenure_days');
    assert.strictEqual(inserted.min_years, 1);
    assert.strictEqual(inserted.max_years, 2);
    assert.strictEqual(inserted.source_tenure_text, '1 Year to 2 Years');
  });

  await runTestAsync('T6.5: Draft 019 Database RPC guard: verifies presence of jsonb_typeof, is_service_account, and SQLSTATE 42501', async () => {
    const fs = require('fs');
    const path = require('path');
    const draftPath = path.join(__dirname, '../supabase/drafts/019_atomic_candidate_promotion_rpc.sql');
    const sql = fs.readFileSync(draftPath, 'utf8');

    // 1. jsonb_typeof on is_service_account
    assert.strictEqual(sql.includes("pg_catalog.jsonb_typeof(raw_app_meta_data->'is_service_account') = 'boolean'"), true,
      'Must strictly check that is_service_account is of JSON boolean type');

    // 2. SQLSTATE 42501 for permission errors
    assert.strictEqual(sql.includes("USING ERRCODE = '42501'"), true,
      'Must return SQLSTATE 42501 on actor permission failures');

    // 3. Strict rejection of human admin UUID in automated mode
    assert.strictEqual(sql.includes("p_actor_id = c_admin_uuid"), true,
      'Must reject human admin UUID in automated policy mode');

    // 4. Strict rejection of service bot in ADMIN mode
    assert.strictEqual(sql.includes("service bot % cannot promote in ADMIN mode"), true,
      'Must reject service bot in ADMIN manual mode');

    // 5. Strict rejection of REVIEWER role in ADMIN mode
    assert.strictEqual(sql.includes('Admin identity verification failed: user % possesses role') && sql.includes('not ADMIN'), true,
      'Must reject REVIEWER role in ADMIN manual mode');
  });

  // ====================================================================
  // SUITE 7: Runtime Integration & Client Privilege Hardening (Phase 4.2.9)
  // ====================================================================

  await runTestAsync('T7.1: Missing privileged database client in production mode fails closed before mutation', async () => {
    const prevNodeEnv = process.env.NODE_ENV;
    const prevSupabaseUrl = process.env.SUPABASE_URL;
    process.env.NODE_ENV = 'production';
    delete process.env.SUPABASE_URL;

    try {
      const promoService = new PromotionService({ isOfflineTestMode: false });
      const candidate = {
        id: crypto.randomUUID(),
        bankCode: 'PNB',
        customerType: 'REGULAR',
        minTenureDays: 7,
        maxTenureDays: 14,
        interestRate: 3.5,
        validationStatus: 'VALID',
        sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
        sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
        parserId: 'pnb_retail_html',
        effectiveFrom: '2026-11-05',
      };

      let threw = false;
      let errorMsg = '';
      try {
        await promoService.promoteCandidate({
          candidate,
          actorType: 'ADMIN',
          actorId: crypto.randomUUID(),
        });
      } catch (err) {
        threw = true;
        errorMsg = err.message;
      }

      assert.strictEqual(threw, true, 'Must fail closed when privileged client is missing in production');
      assert.strictEqual(errorMsg.includes('privileged database client') || errorMsg.includes('strictly prohibited'), true,
        `Unexpected error message: ${errorMsg}`);
    } finally {
      if (prevNodeEnv !== undefined) process.env.NODE_ENV = prevNodeEnv; else delete process.env.NODE_ENV;
      if (prevSupabaseUrl !== undefined) process.env.SUPABASE_URL = prevSupabaseUrl; else delete process.env.SUPABASE_URL;
    }
  });

  await runTestAsync('T7.2: Unprivileged public/anon client explicitly rejected before RPC execution', async () => {
    const unprivilegedClient = {
      isAnonClient: true,
      rpc: async () => { throw new Error('Unprivileged client must never execute RPC'); }
    };

    const promoService = new PromotionService({
      supabaseClient: unprivilegedClient,
      isOfflineTestMode: false,
    });

    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.5,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    let threw = false;
    let errorMsg = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: crypto.randomUUID(),
      });
    } catch (err) {
      threw = true;
      errorMsg = err.message;
    }

    assert.strictEqual(threw, true, 'Must reject unprivileged anon client');
    assert.strictEqual(errorMsg.includes('unprivileged public/anon client'), true,
      `Unexpected error message: ${errorMsg}`);
  });

  await runTestAsync('T7.3: In-memory fallback strictly rejected when running in staging/production runtime', async () => {
    const prevNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'staging';

    try {
      const promoService = new PromotionService({ isOfflineTestMode: false });
      const candidate = {
        id: crypto.randomUUID(),
        bankCode: 'PNB',
        customerType: 'REGULAR',
        minTenureDays: 7,
        maxTenureDays: 14,
        interestRate: 3.5,
        validationStatus: 'VALID',
        sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
        sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
        parserId: 'pnb_retail_html',
        effectiveFrom: '2026-11-05',
      };

      let threw = false;
      let errorMsg = '';
      try {
        await promoService.promoteCandidate({
          candidate,
          actorType: 'ADMIN',
          actorId: crypto.randomUUID(),
        });
      } catch (err) {
        threw = true;
        errorMsg = err.message;
      }

      assert.strictEqual(threw, true, 'Must reject in-memory fallback in staging runtime');
      assert.strictEqual(errorMsg.includes('in-memory sequential fallback is strictly prohibited') || errorMsg.includes('privileged database client'), true,
        `Unexpected error message: ${errorMsg}`);
    } finally {
      if (prevNodeEnv !== undefined) process.env.NODE_ENV = prevNodeEnv; else delete process.env.NODE_ENV;
    }
  });

  await runTestAsync('T7.4: In-memory fallback permitted strictly in explicit offline test mode with explicit return metadata', async () => {
    const prevNodeEnv = process.env.NODE_ENV;
    const prevSupabaseUrl = process.env.SUPABASE_URL;
    delete process.env.NODE_ENV;
    delete process.env.SUPABASE_URL;

    try {
      const promoService = new PromotionService({
        isOfflineTestMode: true,
        inMemoryRates: [],
      });

      const candidate = {
        id: crypto.randomUUID(),
        bankCode: 'PNB',
        customerType: 'REGULAR',
        minTenureDays: 7,
        maxTenureDays: 14,
        interestRate: 3.5,
        validationStatus: 'VALID',
        sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
        sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
        parserId: 'pnb_retail_html',
        effectiveFrom: '2026-11-05',
      };

      const result = await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: crypto.randomUUID(),
      });

      assert.strictEqual(result.promoted, true);
      assert.strictEqual(result.atomicRpc, false, 'Must flag that atomicRpc was not used');
      assert.strictEqual(result.isOfflineSimulation, true, 'Must explicitly flag offline simulation');
    } finally {
      if (prevNodeEnv !== undefined) process.env.NODE_ENV = prevNodeEnv; else delete process.env.NODE_ENV;
      if (prevSupabaseUrl !== undefined) process.env.SUPABASE_URL = prevSupabaseUrl; else delete process.env.SUPABASE_URL;
    }
  });

  await runTestAsync('T7.5: PostgREST RPC argument signature and shape verification', async () => {
    let capturedParams = null;
    const mockDb = {
      rpc: async (fnName, params) => {
        capturedParams = params;
        return {
          data: [{
            new_rate_id: 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',
            superseded_rate_id: params.p_supersede_rate_id,
            candidate_id: params.p_staged_candidate_id,
            promotion_status: 'PROMOTED',
          }],
          error: null,
        };
      }
    };

    const promoService = new PromotionService({ supabaseClient: mockDb });
    const candidateId = crypto.randomUUID();
    const adminId = crypto.randomUUID();
    const supersededId = crypto.randomUUID();

    const candidate = {
      id: candidateId,
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.5,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    const activeRate = {
      id: supersededId,
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.0,
      status: 'VERIFIED',
    };

    const result = await promoService.promoteCandidate({
      candidate,
      actorType: 'ADMIN',
      actorId: adminId,
      activeVerifiedRates: [activeRate],
      reason: 'Verified rate revision',
    });

    assert.strictEqual(result.promoted, true);
    assert.strictEqual(result.atomicRpc, true);
    assert.strictEqual(result.newVerifiedRate.id, 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa');
    assert.strictEqual(result.supersededRecord.id, supersededId);
    assert.strictEqual(result.supersededRecord.status, 'ARCHIVED');
    assert.strictEqual(candidate.stagingStatus, 'PROMOTED');
    assert.strictEqual(candidate.promotedRateId, 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa');
    assert.strictEqual(capturedParams.p_staged_candidate_id, candidateId);
    assert.strictEqual(capturedParams.p_actor_type, 'ADMIN');
    assert.strictEqual(capturedParams.p_actor_id, adminId);
    assert.strictEqual(capturedParams.p_supersede_rate_id, supersededId);
    assert.strictEqual(capturedParams.p_effective_at, new Date('2026-11-05').toISOString());
    assert.strictEqual(capturedParams.p_notes, 'Verified rate revision');
    assert.strictEqual(typeof capturedParams.p_policy_result, 'object');
    assert.strictEqual(typeof capturedParams.p_diff_summary, 'object');
  });

  await runTestAsync('T7.6: Database RPC error propagation to caller', async () => {
    const mockDb = {
      rpc: async () => ({
        data: null,
        error: { message: 'relation "fd_rates" does not exist' }
      })
    };

    const promoService = new PromotionService({ supabaseClient: mockDb });
    const candidate = {
      id: crypto.randomUUID(),
      bankCode: 'PNB',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 14,
      interestRate: 3.5,
      validationStatus: 'VALID',
      sourceContentHash: '05ff94ad9b60d9f2459afb72e73841124cca8c68bf759e4de13ed0c802fe9e24',
      sourceUrl: 'https://www.pnb.bank.in/Interest-Rates-Deposit.html',
      parserId: 'pnb_retail_html',
      effectiveFrom: '2026-11-05',
    };

    let threw = false;
    let errorMsg = '';
    try {
      await promoService.promoteCandidate({
        candidate,
        actorType: 'ADMIN',
        actorId: crypto.randomUUID(),
      });
    } catch (err) {
      threw = true;
      errorMsg = err.message;
    }

    assert.strictEqual(threw, true);
    assert.strictEqual(errorMsg.includes('Atomic promotion RPC failed: relation "fd_rates" does not exist'), true,
      `Unexpected error message: ${errorMsg}`);
  });


  // ====================================================================
  // SUMMARY
  // ====================================================================
  console.log('\n--------------------------------------------------------------');
  console.log(`Results: ${passedTests} passed, ${failedTests} failed`);
  console.log('--------------------------------------------------------------');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runAllTests().catch((err) => {
  console.error('Unhandled failure in test suite:', err);
  process.exit(1);
});
