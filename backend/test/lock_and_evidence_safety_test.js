// FeroCalc Verified FD Rate Engine — Phase 3C.5.16C Safety Regression Test Suite
//
// Tests all required remediation capabilities:
// 1. JobLockManager atomic stale lock reclamation (race condition prevention)
// 2. JobLockManager fail-closed behavior on database error / timeout (no silent fallback)
// 3. JobLockManager guarded release (stale owner cannot delete newer owner's lease)
// 4. JobLockManager re-entrant lock acquisition
// 5. JobLockManager pre-write lock verification (verifyLock)
// 6. JobLockManager atomic renewal (renewLock)
// 7. CandidateStagingService pre-write lock check assertion
// 8. StagingRetryCoordinator timeout reconciliation (ALREADY_COMMITTED idempotent recovery)
// 9. StagingRetryCoordinator partial insert detection (fails closed)
// 10. StagingRetryCoordinator candidate identity mismatch detection (fails closed)
// 11. StagingRetryCoordinator write receipt validation and mismatched receipt rejection
// 12. StagingRetryCoordinator exact-ID safe rollback (asserts DRAFT, no promoted_rate_id, expected bank)
// 13. StagingRetryCoordinator rollback aborted when rows do not match receipt
// 14. ContentAddressedSnapshotStorage hash reproducibility from normalized content
// 15. ContentAddressedSnapshotStorage hash mismatch detection on save (throws on tamper)
// 16. ContentAddressedSnapshotStorage verifies raw content without normalization does NOT match normalized hash
// 17. ContentAddressedSnapshotStorage reports historical hash as unreproducible when bytes absent

'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { JobLockManager, DEFAULT_LOCK_NAME } = require('../monitoring/job_lock_manager');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const {
  StagingRetryCoordinator,
  getCandidateIdentityKey,
} = require('../staging/staging_retry_coordinator');
const {
  ContentAddressedSnapshotStorage,
} = require('../collectors/snapshot_storage');
const { BaseCollector } = require('../collectors/base_collector');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passedTests++;
  } catch (err) {
    failedTests++;
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
  }
}

async function runTestAsync(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passedTests++;
  } catch (err) {
    failedTests++;
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
  }
}

/**
 * Creates an in-memory mock Supabase client for testing rate_pipeline_locks queries.
 */
function createMockSupabaseLockClient(initialRows = []) {
  const store = new Map();
  for (const r of initialRows) {
    store.set(r.lock_name, { ...r });
  }

  return {
    from: (table) => {
      if (table !== 'rate_pipeline_locks') {
        throw new Error(`Unsupported mock table: ${table}`);
      }

      let filterLockName = null;
      let filterLockedBy = null;
      let filterLteExpiresAt = null;
      let filterGtExpiresAt = null;

      const queryBuilder = {
        select: (cols) => queryBuilder,
        eq: (col, val) => {
          if (col === 'lock_name') filterLockName = val;
          if (col === 'locked_by_job_id') filterLockedBy = val;
          return queryBuilder;
        },
        lte: (col, val) => {
          if (col === 'expires_at') filterLteExpiresAt = new Date(val).getTime();
          return queryBuilder;
        },
        gt: (col, val) => {
          if (col === 'expires_at') filterGtExpiresAt = new Date(val).getTime();
          return queryBuilder;
        },
        maybeSingle: async () => {
          if (filterLockName && store.has(filterLockName)) {
            return { data: { ...store.get(filterLockName) }, error: null };
          }
          return { data: null, error: null };
        },
        insert: async (records) => {
          const rec = records[0];
          if (store.has(rec.lock_name)) {
            return {
              data: null,
              error: { message: `duplicate key value violates unique constraint on "${rec.lock_name}"`, code: '23505' },
            };
          }
          store.set(rec.lock_name, { ...rec });
          return { data: [{ ...rec }], error: null };
        },
        update: (updates) => {
          return {
            eq: (col, val) => {
              if (col === 'lock_name') filterLockName = val;
              if (col === 'locked_by_job_id') filterLockedBy = val;
              return {
                eq: (c2, v2) => {
                  if (c2 === 'locked_by_job_id') filterLockedBy = v2;
                  return {
                    lte: (colLte, valLte) => {
                      filterLteExpiresAt = new Date(valLte).getTime();
                      return {
                        select: async () => executeUpdate(updates),
                      };
                    },
                    gt: (colGt, valGt) => {
                      filterGtExpiresAt = new Date(valGt).getTime();
                      return {
                        select: async () => executeUpdate(updates),
                      };
                    },
                    select: async () => executeUpdate(updates),
                  };
                },
                lte: (colLte, valLte) => {
                  filterLteExpiresAt = new Date(valLte).getTime();
                  return {
                    select: async () => executeUpdate(updates),
                  };
                },
                gt: (colGt, valGt) => {
                  filterGtExpiresAt = new Date(valGt).getTime();
                  return {
                    select: async () => executeUpdate(updates),
                  };
                },
                select: async () => executeUpdate(updates),
              };
            },
          };

          async function executeUpdate(updates) {
            if (!filterLockName || !store.has(filterLockName)) {
              return { data: [], error: null };
            }
            const row = store.get(filterLockName);
            if (filterLockedBy && row.locked_by_job_id !== filterLockedBy) {
              return { data: [], error: null };
            }
            const expTime = new Date(row.expires_at).getTime();
            if (filterLteExpiresAt !== null && expTime > filterLteExpiresAt) {
              // Conditional check failed: lock is NOT stale (already updated/renewed)
              return { data: [], error: null };
            }
            if (filterGtExpiresAt !== null && expTime <= filterGtExpiresAt) {
              // Conditional check failed: lock has expired
              return { data: [], error: null };
            }

            const updated = { ...row, ...updates };
            store.set(filterLockName, updated);
            return { data: [{ ...updated }], error: null };
          }
        },
        delete: () => {
          return {
            eq: (col1, val1) => {
              if (col1 === 'lock_name') filterLockName = val1;
              if (col1 === 'locked_by_job_id') filterLockedBy = val1;
              return {
                eq: (col2, val2) => {
                  if (col2 === 'lock_name') filterLockName = val2;
                  if (col2 === 'locked_by_job_id') filterLockedBy = val2;
                  return {
                    select: async () => executeDelete(),
                  };
                },
                select: async () => executeDelete(),
              };
            },
          };

          async function executeDelete() {
            if (!filterLockName || !store.has(filterLockName)) {
              return { data: [], error: null };
            }
            const row = store.get(filterLockName);
            if (filterLockedBy && row.locked_by_job_id !== filterLockedBy) {
              // Guard: Not owned by this jobId!
              return { data: [], error: null };
            }
            store.delete(filterLockName);
            return { data: [{ ...row }], error: null };
          }
        },
      };

      return queryBuilder;
    },
    _getStore: () => store,
  };
}

async function run() {
  console.log('======================================================');
  console.log('FeroCalc Phase 3C.5.16C Safety Regression Test Suite  ');
  console.log('======================================================\n');

  // ------------------------------------------------------------------
  // Group 1: JobLockManager Concurrency & Atomic Reclamation
  // ------------------------------------------------------------------
  console.log('Group 1: JobLockManager Atomic Reclamation & Guards...');

  await runTestAsync('1. Two concurrent attempts to reclaim same expired lease: exactly one succeeds', async () => {
    const expiredTime = new Date(Date.now() - 60000).toISOString();
    const mockClient = createMockSupabaseLockClient([
      {
        lock_name: 'rate_pipeline_global',
        locked_by_job_id: 'job_crashed_old',
        acquired_at: new Date(Date.now() - 120000).toISOString(),
        expires_at: expiredTime,
      },
    ]);

    const lockManagerA = new JobLockManager({ supabaseClient: mockClient });
    const lockManagerB = new JobLockManager({ supabaseClient: mockClient });

    // Process A and Process B concurrently attempt to reclaim
    const [resA, resB] = await Promise.all([
      lockManagerA.acquireLock('job_A_reclaim'),
      lockManagerB.acquireLock('job_B_reclaim'),
    ]);

    // Exactly one must acquire, the other must lose the race cleanly
    const acquiredCount = (resA.acquired ? 1 : 0) + (resB.acquired ? 1 : 0);
    assert.strictEqual(acquiredCount, 1, 'Exactly one concurrent reclaim attempt must succeed');

    const winner = resA.acquired ? 'A' : 'B';
    const loserRes = resA.acquired ? resB : resA;
    assert.strictEqual(loserRes.acquired, false, 'Loser must have acquired: false');
    assert(loserRes.reason.includes('race lost') || loserRes.reason.includes('currently running'), 'Loser reason indicates race lost');
  });

  await runTestAsync('2. Database lock error fails closed without silent in-memory fallback', async () => {
    const errorClient = {
      from: () => ({
        select: () => ({
          eq: () => ({
            maybeSingle: async () => ({ data: null, error: { message: 'Database connection timeout 504' } }),
          }),
        }),
      }),
    };

    const lockManager = new JobLockManager({ supabaseClient: errorClient, allowInMemoryFallback: false });
    const res = await lockManager.acquireLock('job_db_err');

    assert.strictEqual(res.acquired, false, 'Database error must fail closed');
    assert(res.reason.includes('Failed to query rate_pipeline_locks'), 'Reason reflects DB failure');
    assert.strictEqual(lockManager._inMemoryLock, null, 'Must NOT fall back to in-memory lock');
  });

  await runTestAsync('3. Guarded release: stale owner cannot delete a newer owner lease', async () => {
    const activeFutureTime = new Date(Date.now() + 600000).toISOString();
    const mockClient = createMockSupabaseLockClient([
      {
        lock_name: 'rate_pipeline_global',
        locked_by_job_id: 'job_new_owner_B',
        acquired_at: new Date().toISOString(),
        expires_at: activeFutureTime,
      },
    ]);

    // Stale owner A tries to release its old expired lock
    const lockManagerOldA = new JobLockManager({ supabaseClient: mockClient });
    const releaseRes = await lockManagerOldA.releaseLock('job_old_stale_A');

    assert.strictEqual(releaseRes.released, false, 'Stale owner release must fail');
    assert(releaseRes.reason.includes('Lock not held by "job_old_stale_A"'), 'Reason indicates lock held by another process');

    // Confirm job B still securely holds the lock in the database
    const store = mockClient._getStore();
    assert(store.has('rate_pipeline_global'), 'Lock row must still exist');
    assert.strictEqual(store.get('rate_pipeline_global').locked_by_job_id, 'job_new_owner_B', 'Lock must still belong to Job B');
  });

  await runTestAsync('4. Re-entrant acquisition succeeds for same jobId without deadlock', async () => {
    const activeFutureTime = new Date(Date.now() + 600000).toISOString();
    const mockClient = createMockSupabaseLockClient([
      {
        lock_name: 'rate_pipeline_global',
        locked_by_job_id: 'job_nested_123',
        acquired_at: new Date().toISOString(),
        expires_at: activeFutureTime,
      },
    ]);

    const lockManager = new JobLockManager({ supabaseClient: mockClient });
    const res = await lockManager.acquireLock('job_nested_123');

    assert.strictEqual(res.acquired, true, 'Re-entrant acquire must succeed');
    assert.strictEqual(res.isReentrant, true, 'isReentrant flag must be true');
  });

  await runTestAsync('5. verifyLock asserts ownership and rejects expired or wrong owner', async () => {
    const mockClient = createMockSupabaseLockClient([
      {
        lock_name: 'rate_pipeline_global',
        locked_by_job_id: 'job_valid_owner',
        acquired_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 60000).toISOString(),
      },
    ]);

    const lockManager = new JobLockManager({ supabaseClient: mockClient });

    // Valid check
    const checkValid = await lockManager.verifyLock('job_valid_owner');
    assert.strictEqual(checkValid.valid, true);
    assert(checkValid.remainingMs > 0);

    // Wrong owner check
    const checkWrong = await lockManager.verifyLock('job_imposter');
    assert.strictEqual(checkWrong.valid, false);
    assert(checkWrong.reason.includes('Lock held by "job_valid_owner"'));

    // Expired check
    mockClient._getStore().get('rate_pipeline_global').expires_at = new Date(Date.now() - 5000).toISOString();
    const checkExpired = await lockManager.verifyLock('job_valid_owner');
    assert.strictEqual(checkExpired.valid, false);
    assert(checkExpired.reason.includes('expired'));
  });

  await runTestAsync('6. renewLock atomically extends lease only if still held', async () => {
    const mockClient = createMockSupabaseLockClient([
      {
        lock_name: 'rate_pipeline_global',
        locked_by_job_id: 'job_renew_test',
        acquired_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 30000).toISOString(),
      },
    ]);

    const lockManager = new JobLockManager({ supabaseClient: mockClient });
    const renewRes = await lockManager.renewLock('job_renew_test', 60000);

    assert.strictEqual(renewRes.renewed, true, 'Active lock renewal must succeed');
    assert(renewRes.expiresAt.getTime() > Date.now() + 50000, 'Expiry extended into future');

    // Attempt renewal with wrong owner
    const renewWrong = await lockManager.renewLock('job_other');
    assert.strictEqual(renewWrong.renewed, false, 'Renewal by wrong owner must fail');
  });

  await runTestAsync('6b. CandidateStagingService pre-write lock check fails closed if lock expired or held by another', async () => {
    const mockClient = createMockSupabaseLockClient([
      {
        lock_name: 'rate_pipeline_global',
        locked_by_job_id: 'job_other_owner',
        acquired_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 60000).toISOString(),
      },
    ]);

    const lockManager = new JobLockManager({ supabaseClient: mockClient });
    const stagingService = new CandidateStagingService({ logger: { log: () => {}, warn: () => {}, error: () => {} } });

    const candidates = [
      {
        sourceId: 'sbi-test',
        bankCode: 'SBI',
        productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customerType: 'REGULAR',
        tenureLabel: '7 days to 45 days',
        minTenureDays: 7,
        maxTenureDays: 45,
        interestRate: 3.05,
        stagingStatus: 'DRAFT',
      },
    ];

    const result = await stagingService._persistCandidates(candidates, {
      lockManager,
      jobId: 'job_attempting_write',
    });

    assert.strictEqual(result.persistedCount, 0, 'Must persist zero candidates when lock check fails');
    assert(result.error.includes('Pre-write lock verification failed'), 'Error reflects pre-write lock failure');
  });

  // ------------------------------------------------------------------
  // Group 2: Staging Retry & Rollback Coordinator
  // ------------------------------------------------------------------
  console.log('\nGroup 2: Staging Retry & Fail-Closed Rollback...');

  const coordinator = new StagingRetryCoordinator();

  const mockApprovedCandidates = [
    {
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 45,
      interestRate: 3.05,
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      minDeposit: 1000,
      maxDeposit: 29999999,
    },
    {
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'SENIOR_CITIZEN',
      minTenureDays: 7,
      maxTenureDays: 45,
      interestRate: 3.55,
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      minDeposit: 1000,
      maxDeposit: 29999999,
    },
  ];

  await runTestAsync('7. reconcileStagingState detects CLEAN_FOR_INSERT on empty table', async () => {
    const mockDb = {
      from: () => ({
        select: () => ({
          eq: () => ({
            eq: async () => ({ data: [], error: null }),
          }),
        }),
      }),
    };

    const res = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_test_clean',
      expectedCandidates: mockApprovedCandidates,
    });

    assert.strictEqual(res.status, 'CLEAN_FOR_INSERT');
  });

  await runTestAsync('8. Insert timeout recovery: reconcileStagingState detects ALREADY_COMMITTED', async () => {
    const committedRows = [
      {
        id: 'c82736b4-1111-4444-9999-aaaaaaaaaaaa',
        bank_code: 'SBI',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 45,
        interest_rate: 3.05,
        is_callable: true,
        rate_category: 'STANDARD',
        scheme_name: null,
        min_deposit: 1000,
        max_deposit: 29999999,
        staging_status: 'DRAFT',
        promoted_rate_id: null,
      },
      {
        id: 'c82736b4-2222-4444-9999-bbbbbbbbbbbb',
        bank_code: 'SBI',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'SENIOR_CITIZEN',
        min_tenure_days: 7,
        max_tenure_days: 45,
        interest_rate: 3.55,
        is_callable: true,
        rate_category: 'STANDARD',
        scheme_name: null,
        min_deposit: 1000,
        max_deposit: 29999999,
        staging_status: 'DRAFT',
        promoted_rate_id: null,
      },
    ];

    const mockDb = {
      from: () => ({
        select: () => ({
          eq: () => ({
            eq: async () => ({ data: committedRows, error: null }),
          }),
        }),
      }),
    };

    const res = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_test_timeout_recovery',
      expectedCandidates: mockApprovedCandidates,
    });

    assert.strictEqual(res.status, 'ALREADY_COMMITTED', 'Must recognize all rows committed in DRAFT');
    assert.strictEqual(res.writeReceipt.length, 2, 'Must capture write receipt of committed UUIDs');
    assert.strictEqual(res.writeReceipt[0].id, 'c82736b4-1111-4444-9999-aaaaaaaaaaaa');
  });

  await runTestAsync('9. reconcileStagingState detects PARTIAL_INSERT_DETECTED and fails closed', async () => {
    // Only 1 of 2 rows committed
    const partialRows = [
      {
        id: 'c82736b4-1111-4444-9999-aaaaaaaaaaaa',
        bank_code: 'SBI',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 45,
        staging_status: 'DRAFT',
      },
    ];

    const mockDb = {
      from: () => ({
        select: () => ({
          eq: () => ({
            eq: async () => ({ data: partialRows, error: null }),
          }),
        }),
      }),
    };

    const res = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_partial',
      expectedCandidates: mockApprovedCandidates,
    });

    assert.strictEqual(res.status, 'PARTIAL_INSERT_DETECTED', 'Must fail closed on partial insert');
    assert(res.reason.includes('Incomplete batch detected'));
  });

  await runTestAsync('10. reconcileStagingState detects IDENTITY_MISMATCH and fails closed', async () => {
    const wrongKeysRows = [
      {
        id: 'c82736b4-1111-4444-9999-aaaaaaaaaaaa',
        bank_code: 'SBI',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        min_tenure_days: 180, // Mismatched tenure!
        max_tenure_days: 210,
        staging_status: 'DRAFT',
      },
      {
        id: 'c82736b4-2222-4444-9999-bbbbbbbbbbbb',
        bank_code: 'SBI',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'SENIOR_CITIZEN',
        min_tenure_days: 7,
        max_tenure_days: 45,
        staging_status: 'DRAFT',
      },
    ];

    const mockDb = {
      from: () => ({
        select: () => ({
          eq: () => ({
            eq: async () => ({ data: wrongKeysRows, error: null }),
          }),
        }),
      }),
    };

    const res = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_mismatch',
      expectedCandidates: mockApprovedCandidates,
    });

    assert.strictEqual(res.status, 'IDENTITY_MISMATCH', 'Must fail closed on key mismatch');
  });

  await runTestAsync('11. verifyWriteReceipt validates row count and UUIDs, rejecting mismatches', async () => {
    const validRows = [
      { id: '11111111-1111-4111-8111-111111111111', min_tenure_days: 7, customer_type: 'REGULAR' },
      { id: '22222222-2222-4222-8222-222222222222', min_tenure_days: 7, customer_type: 'SENIOR_CITIZEN' },
    ];

    const receipt = coordinator.verifyWriteReceipt({ attemptedCount: 2, insertedRows: validRows });
    assert.strictEqual(receipt.valid, true);
    assert.strictEqual(receipt.writeReceipt.length, 2);

    // Mismatched count
    const mismatchedReceipt = coordinator.verifyWriteReceipt({ attemptedCount: 3, insertedRows: validRows });
    assert.strictEqual(mismatchedReceipt.valid, false);
    assert(mismatchedReceipt.reason.includes('Mismatched row count'));
  });

  await runTestAsync('12. safeRollback deletes ONLY exact UUIDs in DRAFT and never touches fd_rates', async () => {
    let deletedQueryIds = null;
    const mockDb = {
      from: (table) => {
        assert.strictEqual(table, 'staged_rate_candidates', 'Must NEVER touch fd_rates during candidate rollback');
        return {
          select: () => ({
            in: async (col, ids) => ({
              data: [
                { id: ids[0], bank_code: 'SBI', staging_status: 'DRAFT', promoted_rate_id: null },
                { id: ids[1], bank_code: 'SBI', staging_status: 'DRAFT', promoted_rate_id: null },
              ],
              error: null,
            }),
          }),
          delete: () => ({
            in: (col, ids) => {
              deletedQueryIds = ids;
              return {
                select: async () => ({ data: ids.map(id => ({ id })), error: null }),
              };
            },
          }),
        };
      },
    };

    const targetReceipt = [
      { id: '11111111-1111-4111-8111-111111111111' },
      { id: '22222222-2222-4222-8222-222222222222' },
    ];

    const rollbackRes = await coordinator.safeRollback({
      supabaseClient: mockDb,
      writeReceipt: targetReceipt,
      expectedBankCode: 'SBI',
    });

    assert.strictEqual(rollbackRes.rolledBack, true);
    assert.strictEqual(rollbackRes.deletedCount, 2);
    assert.deepStrictEqual(deletedQueryIds, ['11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222']);
  });

  await runTestAsync('13. safeRollback aborts if any candidate has been promoted or is not in DRAFT', async () => {
    const mockDb = {
      from: () => ({
        select: () => ({
          in: async () => ({
            data: [
              { id: '11111111-1111-4111-8111-111111111111', bank_code: 'SBI', staging_status: 'PROMOTED', promoted_rate_id: 'some_rate_uuid' },
            ],
            error: null,
          }),
        }),
      }),
    };

    const rollbackRes = await coordinator.safeRollback({
      supabaseClient: mockDb,
      writeReceipt: [{ id: '11111111-1111-4111-8111-111111111111' }],
      expectedBankCode: 'SBI',
    });

    assert.strictEqual(rollbackRes.rolledBack, false);
    assert(rollbackRes.reason.includes('already been promoted') || rollbackRes.reason.includes('status "PROMOTED"'));
  });

  // ------------------------------------------------------------------
  // Group 3: Source Evidence Capture & Hash Reproducibility
  // ------------------------------------------------------------------
  console.log('\nGroup 3: Source Evidence Snapshot Reproducibility...');

  const snapshotStorage = new ContentAddressedSnapshotStorage({ inMemoryOnly: true });

  const rawHtmlSample = `
    <html>
      <head>
        <script>var session = "token_abc_123";</script>
        <style>.advert { display: none; }</style>
      </head>
      <body>
        <table>
          <tr><td>7 days to 45 days</td><td>3.05%</td></tr>
        </table>
      </body>
    </html>
  `;

  const collector = new BaseCollector({
    id: 'sbi-retail-domestic',
    bankCode: 'SBI',
    sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
  });

  const normalizedBuffer = collector.normalize(Buffer.from(rawHtmlSample, 'utf8'));
  const calculatedHash = crypto.createHash('sha256').update(normalizedBuffer).digest('hex');

  await runTestAsync('14. saveSnapshot stores exact normalized bytes and verifies hash reproducibility', async () => {
    const meta = await snapshotStorage.saveSnapshot({
      sourceId: 'sbi-retail-domestic',
      contentHash: calculatedHash,
      normalizedContent: normalizedBuffer,
      rawContent: Buffer.from(rawHtmlSample, 'utf8'),
      bankCode: 'SBI',
      effectiveFrom: '2025-12-15',
    });

    assert.strictEqual(meta.contentHash, calculatedHash);
    assert.strictEqual(meta.hasRawSupplement, true);

    // Verify snapshot reproduction
    const verifyRes = await snapshotStorage.verifySnapshot(calculatedHash);
    assert.strictEqual(verifyRes.verified, true, 'Stored snapshot must reproduce the exact hash');
    assert.strictEqual(verifyRes.reproducedHash, calculatedHash);
  });

  await runTestAsync('15. saveSnapshot throws error if computed hash does not match declared hash', async () => {
    let threw = false;
    try {
      await snapshotStorage.saveSnapshot({
        sourceId: 'sbi-retail-domestic',
        contentHash: 'wrong_tampered_hash_000000000000000000000000000000000000000000000000',
        normalizedContent: normalizedBuffer,
      });
    } catch (err) {
      threw = true;
      assert(err.message.includes('Snapshot integrity verification failed'));
    }
    assert.strictEqual(threw, true, 'Must reject tampered snapshot on save');
  });

  await runTestAsync('16. Raw content without normalization produces DIFFERENT hash (proving normalized bytes are mandatory)', async () => {
    const rawBuffer = Buffer.from(rawHtmlSample, 'utf8');
    const rawHash = crypto.createHash('sha256').update(rawBuffer).digest('hex');

    assert.notStrictEqual(rawHash, calculatedHash, 'Raw hash must differ from normalized hash due to script/style content');
  });

  await runTestAsync('17. verifySnapshot reports historical hash 60f22ac7... as unreproducible when bytes absent', async () => {
    const historicalHash = '60f22ac7e904ff7dea15814e540681947f97b6edc8fc76cb57845592b5fe88d2';
    const checkRes = await snapshotStorage.verifySnapshot(historicalHash);

    assert.strictEqual(checkRes.verified, false);
    assert(checkRes.error.includes('Historical snapshots from Phase 1 were not retained'));
  });

  // ------------------------------------------------------------------
  // Summary
  // ------------------------------------------------------------------
  console.log('\n======================================================');
  console.log(`Results: ${passedTests} passed, ${failedTests} failed (Total: ${totalTests})`);
  console.log('======================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  run().catch(err => {
    console.error('Fatal test error:', err);
    process.exit(1);
  });
}

module.exports = { run };
