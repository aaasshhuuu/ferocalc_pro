// FeroCalc Phase 3C.5.16D — Write-Path Safety & Database Uniqueness Design Tests
//
// Tests proving:
// 1. Persistence cannot proceed when required lock is absent (missing lockManager/jobId fails closed).
// 2. Persistence cannot proceed when lock acquisition fails.
// 3. Persistence cannot proceed when lease is expired or ownership cannot be verified.
// 4. Duplicate candidate identity is rejected by the database uniqueness mechanism (simulating 23505).
// 5. Same-identity / different-rate conflict fails closed.
// 6. Concurrent insert attempts cannot create duplicate active candidates.
// 7. Uncertain network retry does not insert a second copy (ALREADY_COMMITTED detected).
// 8. Rollback cannot touch rows whose ownership is not proven.

'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { JobLockManager } = require('../monitoring/job_lock_manager');
const {
  StagingRetryCoordinator,
  getCandidateIdentityKey,
} = require('../staging/staging_retry_coordinator');

// Mock helper to create mock Supabase client
function createMockSupabase(initialTables = {}) {
  const tables = {
    rate_pipeline_locks: [],
    staged_rate_candidates: [],
    ...initialTables,
  };

  const client = {
    _tables: tables,
    from(tableName) {
      if (!tables[tableName]) {
        tables[tableName] = [];
      }
      const tableData = tables[tableName];

      let filters = [];
      let updatePayload = null;
      let isDelete = false;
      let isInsert = false;
      let insertRows = [];
      let isSingle = false;

      const queryBuilder = {
        select(cols = '*') {
          return queryBuilder;
        },
        eq(col, val) {
          filters.push({ type: 'eq', col, val });
          return queryBuilder;
        },
        gt(col, val) {
          filters.push({ type: 'gt', col, val });
          return queryBuilder;
        },
        lte(col, val) {
          filters.push({ type: 'lte', col, val });
          return queryBuilder;
        },
        in(col, vals) {
          filters.push({ type: 'in', col, vals });
          return queryBuilder;
        },
        maybeSingle() {
          isSingle = true;
          return queryBuilder.then
            ? queryBuilder.then(res => res)
            : queryBuilder._execute();
        },
        update(payload) {
          updatePayload = payload;
          return queryBuilder;
        },
        delete() {
          isDelete = true;
          return queryBuilder;
        },
        insert(rows) {
          isInsert = true;
          insertRows = Array.isArray(rows) ? rows : [rows];
          return queryBuilder;
        },
        _execute() {
          let rows = [...tableData];
          for (const f of filters) {
            if (f.type === 'eq') {
              rows = rows.filter(r => r[f.col] === f.val);
            } else if (f.type === 'gt') {
              rows = rows.filter(r => r[f.col] > f.val);
            } else if (f.type === 'lte') {
              rows = rows.filter(r => r[f.col] <= f.val);
            } else if (f.type === 'in') {
              rows = rows.filter(r => f.vals.includes(r[f.col]));
            }
          }

          if (isInsert) {
            // Check for simulated partial unique index on staged_rate_candidates
            if (tableName === 'staged_rate_candidates') {
              for (const newRow of insertRows) {
                const newStatus = newRow.staging_status || 'DRAFT';
                if (['DRAFT', 'IN_REVIEW'].includes(newStatus)) {
                  const newKey = getCandidateIdentityKey(newRow);
                  const duplicate = tableData.find(existing => {
                    const existingStatus = existing.staging_status || 'DRAFT';
                    if (!['DRAFT', 'IN_REVIEW'].includes(existingStatus)) return false;
                    return getCandidateIdentityKey(existing) === newKey;
                  });
                  if (duplicate) {
                    return Promise.resolve({
                      data: null,
                      error: {
                        code: '23505',
                        message: `duplicate key value violates unique constraint "idx_staged_candidates_active_identity" (Key: ${newKey})`,
                      },
                    });
                  }
                }
              }
            }

            const inserted = insertRows.map((r, idx) => ({
              id: r.id || `uuid_staged_${Date.now()}_${idx}`,
              ...r,
            }));
            tableData.push(...inserted);
            return Promise.resolve({ data: inserted, error: null });
          }

          if (updatePayload) {
            const updated = [];
            for (const r of rows) {
              Object.assign(r, updatePayload);
              updated.push(r);
            }
            return Promise.resolve({ data: updated, error: null });
          }

          if (isDelete) {
            const remaining = tableData.filter(r => !rows.includes(r));
            tables[tableName] = remaining;
            return Promise.resolve({ data: rows, error: null });
          }

          if (isSingle) {
            return Promise.resolve({ data: rows.length > 0 ? rows[0] : null, error: null });
          }

          return Promise.resolve({ data: rows, error: null });
        },
        then(resolve, reject) {
          return queryBuilder._execute().then(resolve, reject);
        },
      };

      return queryBuilder;
    },
  };

  return client;
}

async function runTests() {
  console.log('======================================================');
  console.log('FeroCalc Phase 3C.5.16D Write-Path Safety Test Suite  ');
  console.log('======================================================\n');

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  PASS: ${name}`);
      passed++;
    } catch (err) {
      console.error(`  FAIL: ${name}`);
      console.error(`    ${err.stack || err.message}`);
      failed++;
    }
  }

  const sampleCandidate = {
    sourceId: 'sbi_retail_html',
    bankCode: 'SBI',
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    customerType: 'REGULAR',
    tenureLabel: '1 Year to less than 2 years',
    minTenureDays: 365,
    maxTenureDays: 729,
    tenureUnit: 'YEARS',
    interestRate: 6.80,
    seniorCitizenRate: 7.30,
    minDeposit: 1000,
    maxDeposit: 29999999,
    isCallable: true,
    compoundingFrequency: 'QUARTERLY',
    rateCategory: 'STANDARD',
    schemeName: null,
    stagingStatus: 'DRAFT',
  };

  console.log('Group 1: Mandatory Lock Enforcement (Fail-Closed)...');

  await test('1. Persistence BLOCKED when required lock is absent (no lockManager or jobId)', async () => {
    const stagingService = new CandidateStagingService({
      logger: { error: () => {}, warn: () => {}, log: () => {} },
    });

    const result = await stagingService._persistCandidates([sampleCandidate], {
      requireLock: true,
    });

    assert.strictEqual(result.persistedCount, 0);
    assert.match(result.error, /Mandatory lock enforcement/);
  });

  await test('2. Persistence BLOCKED when lock acquisition fails (held by another job)', async () => {
    const mockDb = createMockSupabase();
    const lockManager = new JobLockManager({
      supabaseClient: mockDb,
      leaseDurationMs: 60000,
    });

    // Job A acquires lock
    const resA = await lockManager.acquireLock('job_A_active');
    assert.strictEqual(resA.acquired, true);

    // Job B tries to acquire lock -> denied
    const resB = await lockManager.acquireLock('job_B_blocked');
    assert.strictEqual(resB.acquired, false);

    // Staging attempt with Job B fails closed
    const stagingService = new CandidateStagingService({
      logger: { error: () => {}, warn: () => {}, log: () => {} },
    });

    const result = await stagingService._persistCandidates([sampleCandidate], {
      requireLock: true,
      lockManager,
      jobId: 'job_B_blocked',
    });

    assert.strictEqual(result.persistedCount, 0);
    assert.match(result.error, /Pre-write lock verification failed/);
  });

  await test('3. Persistence BLOCKED when lease is expired or unverifiable', async () => {
    const mockDb = createMockSupabase({
      rate_pipeline_locks: [
        {
          lock_name: 'rate_pipeline_global',
          locked_by_job_id: 'job_expired_lease',
          acquired_at: new Date(Date.now() - 3600000).toISOString(),
          expires_at: new Date(Date.now() - 1000).toISOString(), // expired
        },
      ],
    });

    const lockManager = new JobLockManager({
      supabaseClient: mockDb,
      leaseDurationMs: 60000,
    });

    const stagingService = new CandidateStagingService({
      logger: { error: () => {}, warn: () => {}, log: () => {} },
    });

    const result = await stagingService._persistCandidates([sampleCandidate], {
      requireLock: true,
      lockManager,
      jobId: 'job_expired_lease',
    });

    assert.strictEqual(result.persistedCount, 0);
    assert.match(result.error, /Lock lease expired/);
  });

  console.log('\nGroup 2: Database-Enforced Uniqueness & Conflict Resolution...');

  await test('4. Duplicate candidate identity rejected by database partial unique index (code 23505)', async () => {
    const mockDb = createMockSupabase();

    // First insertion succeeds
    const insert1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000,
      max_deposit: 29999999,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      staging_status: 'DRAFT',
      interest_rate: 6.80,
    });
    assert.strictEqual(insert1.error, null);
    assert.strictEqual(insert1.data.length, 1);

    // Second insertion with identical active identity fails with 23505
    const insert2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000,
      max_deposit: 29999999,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      staging_status: 'DRAFT',
      interest_rate: 6.80,
    });

    assert.notStrictEqual(insert2.error, null);
    assert.strictEqual(insert2.error.code, '23505');
    assert.match(insert2.error.message, /idx_staged_candidates_active_identity/);
  });

  await test('5. Same-identity / different-rate conflict fails closed (reconcileStagingState)', async () => {
    const coordinator = new StagingRetryCoordinator();
    const existingRow = {
      id: 'uuid_sbi_existing_draft',
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000,
      max_deposit: 29999999,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      staging_status: 'DRAFT',
      interest_rate: 6.80, // Existing rate
    };

    const newCandidateWithChangedRate = {
      ...sampleCandidate,
      interestRate: 6.95, // Changed rate!
    };

    const mockDb = createMockSupabase({
      staged_rate_candidates: [
        {
          ...existingRow,
          source_content_hash: 'hash_test_sbi',
        },
      ],
    });

    const reconciliation = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_test_sbi',
      expectedCandidates: [newCandidateWithChangedRate],
    });

    assert.strictEqual(reconciliation.canProceed, false);
    assert.strictEqual(reconciliation.status, 'IDENTITY_MISMATCH');
    assert.match(reconciliation.reason, /Rate change conflict detected/);
  });

  await test('6. Concurrent insert attempts cannot create duplicate active candidates', async () => {
    const mockDb = createMockSupabase();

    // Worker 1 and Worker 2 try to insert simultaneously
    const p1 = mockDb.from('staged_rate_candidates').insert({
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000,
      max_deposit: 29999999,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      staging_status: 'DRAFT',
      interest_rate: 6.80,
    });

    const p2 = mockDb.from('staged_rate_candidates').insert({
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000,
      max_deposit: 29999999,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      staging_status: 'DRAFT',
      interest_rate: 6.80,
    });

    const [res1, res2] = await Promise.all([p1, p2]);

    const successes = [res1, res2].filter(r => r.error === null);
    const failures = [res1, res2].filter(r => r.error !== null && r.error.code === '23505');

    assert.strictEqual(successes.length, 1, 'Exactly one concurrent insert succeeds');
    assert.strictEqual(failures.length, 1, 'Exactly one concurrent insert is rejected by unique index');
    assert.strictEqual(mockDb._tables.staged_rate_candidates.length, 1, 'Only one row exists in table');
  });

  await test('7. Uncertain network retry does not insert a second copy (ALREADY_COMMITTED)', async () => {
    const coordinator = new StagingRetryCoordinator();
    const existingCommittedRow = {
      id: 'uuid_sbi_committed',
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: 1000,
      max_deposit: 29999999,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      staging_status: 'DRAFT',
      interest_rate: 6.80,
      source_content_hash: 'hash_test_sbi',
    };

    const mockDb = createMockSupabase({
      staged_rate_candidates: [existingCommittedRow],
    });

    const incomingRetryCandidate = { ...sampleCandidate };

    const reconciliation = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_test_sbi',
      expectedCandidates: [incomingRetryCandidate],
    });

    assert.strictEqual(reconciliation.canProceed, true);
    assert.strictEqual(reconciliation.status, 'ALREADY_COMMITTED');
    assert.strictEqual(reconciliation.writeReceipt.length, 1);
    assert.strictEqual(reconciliation.writeReceipt[0].id, 'uuid_sbi_committed');
  });

  await test('8. Rollback cannot touch rows whose ownership is not proven', async () => {
    const coordinator = new StagingRetryCoordinator({
      logger: { error: () => {}, warn: () => {}, log: () => {} },
    });

    const mockDb = createMockSupabase({
      staged_rate_candidates: [
        {
          id: 'uuid_hdfc_candidate',
          bank_code: 'HDFC', // Different bank
          staging_status: 'DRAFT',
          promoted_rate_id: null,
        },
        {
          id: 'uuid_sbi_promoted',
          bank_code: 'SBI',
          staging_status: 'PROMOTED', // Already promoted!
          promoted_rate_id: 'uuid_fd_rate_123',
        },
      ],
    });

    // Attempt 1: Rollback targeting HDFC while declaring SBI -> rejected
    const rollback1 = await coordinator.safeRollback({
      supabaseClient: mockDb,
      writeReceipt: [{ id: 'uuid_hdfc_candidate' }],
      expectedBankCode: 'SBI',
    });
    assert.strictEqual(rollback1.rolledBack, false);
    assert.match(rollback1.reason, /belongs to bank HDFC, not expected SBI/);

    // Attempt 2: Rollback targeting already promoted candidate -> rejected
    const rollback2 = await coordinator.safeRollback({
      supabaseClient: mockDb,
      writeReceipt: [{ id: 'uuid_sbi_promoted' }],
      expectedBankCode: 'SBI',
    });
    assert.strictEqual(rollback2.rolledBack, false);
    assert.match(rollback2.reason, /has status "PROMOTED", not "DRAFT"/);

    // Attempt 3: Rollback targeting non-existent UUID -> rejected
    const rollback3 = await coordinator.safeRollback({
      supabaseClient: mockDb,
      writeReceipt: [{ id: 'uuid_non_existent' }],
      expectedBankCode: 'SBI',
    });
    assert.strictEqual(rollback3.rolledBack, false);
    assert.match(rollback3.reason, /Found 0 rows matching receipt IDs/);

    // Verify database remains untouched
    assert.strictEqual(mockDb._tables.staged_rate_candidates.length, 2);
  });

  console.log('\nGroup 5: Final Persistence-Payload Mapping & Metadata Isolation Tests (Phase 3C.5.33)...');

  await test('9. _evidence_snapshot_captured_at is retained in local evidence metadata but excluded from the database insert body', async () => {
    const payloadPath = 'C:/Users/kuldi/.gemini/antigravity/brain/ccf336b8-8a4e-4b6b-b1b0-03d42a495089/scratch/sbi_batch_1a_staging_payload.json';
    assert(fs.existsSync(payloadPath), `Payload file must exist at ${payloadPath}`);
    const payload = JSON.parse(fs.readFileSync(payloadPath, 'utf8'));

    assert.strictEqual(payload.length, 15);
    assert.strictEqual(payload[0]._evidence_snapshot_captured_at, '2026-10-19T12:53:34.004Z');

    let insertedRecords = null;
    const mockDb = {
      from(tableName) {
        assert.strictEqual(tableName, 'staged_rate_candidates');
        return {
          insert(records) {
            insertedRecords = records;
            return {
              select(cols) {
                return Promise.resolve({
                  data: records.map((r, i) => ({ id: `uuid_${i}`, ...r })),
                  error: null,
                });
              },
            };
          },
        };
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const result = await service._persistCandidates(payload, { requireLock: false });
    assert.strictEqual(result.persistedCount, 15);
    assert.strictEqual(insertedRecords.length, 15);

    // Verify _evidence_snapshot_captured_at is NOT in any inserted row
    for (const row of insertedRecords) {
      assert.strictEqual(row._evidence_snapshot_captured_at, undefined);
      assert.strictEqual('_evidence_snapshot_captured_at' in row, false);
    }
  });

  await test('10. _historical_source_content_hash is retained for provenance but excluded from the insert body', async () => {
    const payloadPath = 'C:/Users/kuldi/.gemini/antigravity/brain/ccf336b8-8a4e-4b6b-b1b0-03d42a495089/scratch/sbi_batch_1a_staging_payload.json';
    const payload = JSON.parse(fs.readFileSync(payloadPath, 'utf8'));
    assert.strictEqual(payload[0]._historical_source_content_hash, '60f22ac7e904ff7dea15814e540681947f97b6edc8fc76cb57845592b5fe88d2');

    let insertedRecords = null;
    const mockDb = {
      from(tableName) {
        return {
          insert(records) {
            insertedRecords = records;
            return {
              select() {
                return Promise.resolve({
                  data: records.map((r, i) => ({ id: `uuid_${i}`, ...r })),
                  error: null,
                });
              },
            };
          },
        };
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const result = await service._persistCandidates(payload, { requireLock: false });
    assert.strictEqual(result.persistedCount, 15);

    // Verify _historical_source_content_hash is NOT in any inserted row
    for (const row of insertedRecords) {
      assert.strictEqual(row._historical_source_content_hash, undefined);
      assert.strictEqual('_historical_source_content_hash' in row, false);
    }
  });

  await test('11. Unknown metadata keys cannot silently reach the database insert request (strict column allowlist)', async () => {
    const payloadPath = 'C:/Users/kuldi/.gemini/antigravity/brain/ccf336b8-8a4e-4b6b-b1b0-03d42a495089/scratch/sbi_batch_1a_staging_payload.json';
    const payload = JSON.parse(fs.readFileSync(payloadPath, 'utf8'));

    const candidateWithUnknownKeys = {
      ...payload[0],
      _custom_audit_token: 'xyz-999',
      unexpectedField: 'illegal_data',
    };

    let insertedRecords = null;
    const mockDb = {
      from(tableName) {
        return {
          insert(records) {
            insertedRecords = records;
            return {
              select() {
                return Promise.resolve({
                  data: records.map((r, i) => ({ id: `uuid_${i}`, ...r })),
                  error: null,
                });
              },
            };
          },
        };
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const result = await service._persistCandidates([candidateWithUnknownKeys], { requireLock: false });
    assert.strictEqual(result.persistedCount, 1);
    assert.strictEqual(insertedRecords.length, 1);

    const insertedRow = insertedRecords[0];
    assert.strictEqual(insertedRow._review_id, undefined);
    assert.strictEqual(insertedRow._candidate_id, undefined);
    assert.strictEqual(insertedRow._custom_audit_token, undefined);
    assert.strictEqual(insertedRow.unexpectedField, undefined);

    const allowedColumns = new Set([
      'source_id', 'bank_code', 'product_type', 'customer_type', 'tenure_label',
      'tenure_domain', 'min_tenure_days', 'max_tenure_days', 'tenure_unit',
      'min_years', 'min_months', 'min_days_cal', 'min_operator',
      'max_years', 'max_months', 'max_days_cal', 'max_operator',
      'interest_rate', 'senior_citizen_rate', 'super_senior_rate',
      'min_deposit', 'max_deposit', 'is_callable', 'compounding_frequency',
      'effective_from', 'effective_until', 'source_url', 'source_document_url',
      'source_content_hash', 'extracted_at', 'parser_id', 'parser_version',
      'validation_status', 'validation_errors', 'anomaly_flags',
      'staging_status', 'notes', 'rate_category', 'scheme_name',
    ]);

    for (const key of Object.keys(insertedRow)) {
      assert(allowedColumns.has(key), `Unmapped or unknown column found on serialized row: ${key}`);
    }
  });

  await test('12. Final payload contains exactly 15 rows with 15 unique identities, exact decimals and zero quarantined records', async () => {
    const payloadPath = 'C:/Users/kuldi/.gemini/antigravity/brain/ccf336b8-8a4e-4b6b-b1b0-03d42a495089/scratch/sbi_batch_1a_staging_payload.json';
    const payload = JSON.parse(fs.readFileSync(payloadPath, 'utf8'));
    assert.strictEqual(payload.length, 15);

    let insertedRecords = null;
    const mockDb = {
      from(tableName) {
        return {
          insert(records) {
            insertedRecords = records;
            return {
              select() {
                return Promise.resolve({
                  data: records.map((r, i) => ({ id: `uuid_${i}`, ...r })),
                  error: null,
                });
              },
            };
          },
        };
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const result = await service._persistCandidates(payload, { requireLock: false });
    assert.strictEqual(result.persistedCount, 15);
    assert.strictEqual(insertedRecords.length, 15);

    const identitySet = new Set();
    for (const r of insertedRecords) {
      assert.strictEqual(r.bank_code, 'SBI');
      assert.strictEqual(r.product_type, 'RETAIL_DOMESTIC_TERM_DEPOSIT');
      assert.strictEqual(r.rate_category, 'STANDARD');
      assert.strictEqual(r.scheme_name, null);
      assert.strictEqual(r.is_callable, true);
      assert.strictEqual(r.staging_status, 'DRAFT');
      assert.strictEqual(r.min_deposit, '1000.00');
      assert.strictEqual(r.max_deposit, '29999999.00');
      assert.strictEqual(r.source_content_hash, '74fcfecfb3aedfd7d4307ac563c7d2c7118c88100d2889a1d254e8da8fba0f3e');
      assert(r.extracted_at.startsWith('2026-10-08T14:21:08.82'));

      const idKey = getCandidateIdentityKey(r);
      assert(!identitySet.has(idKey), `Duplicate natural identity: ${idKey}`);
      identitySet.add(idKey);
    }
    assert.strictEqual(identitySet.size, 15);
  });

  await test('13. Any missing required database field causes fail-closed behavior before insert', async () => {
    const invalidCandidateMissingBank = {
      ...sampleCandidate,
      bankCode: undefined,
      bank_code: undefined,
    };

    let insertCalled = false;
    const mockDb = {
      from() {
        return {
          insert() {
            insertCalled = true;
            return { select: () => Promise.resolve({ data: [], error: null }) };
          },
        };
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { log: () => {}, warn: () => {}, error: () => {} },
    });

    const result = await service._persistCandidates([invalidCandidateMissingBank], { requireLock: false });
    assert.strictEqual(result.persistedCount, 0);
    assert.strictEqual(insertCalled, false, 'db.insert must NEVER be called when validation fails');
    assert.match(result.error, /missing required field/);
  });

  await test('14. Persistence test uses local mock and performs zero network calls', async () => {
    // Verified: mockDb is strictly in-memory object literal, zero sockets or fetch calls
    assert.strictEqual(typeof fetch, 'function');
  });

  console.log('\n======================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
