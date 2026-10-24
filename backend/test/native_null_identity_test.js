// FeroCalc Phase 3C.5.18 — Native NULLS NOT DISTINCT Identity & Precheck Test Suite
//
// NOTE: These are local unit and mock tests simulating PostgreSQL 15+ NULLS NOT DISTINCT
// and SQL GROUP BY grouping semantics. ZERO remote database connections or live mutations.
//
// Verifies:
// 1. Two candidates with otherwise equal identity and both nullable deposit fields NULL: duplicate.
// 2. NULL minimum deposit versus explicit zero: distinct identities.
// 3. NULL maximum deposit versus explicit negative one: distinct identities (with documented schema-derived rule).
// 4. NULL callable flag versus true: distinct identities.
// 5. Canonical scheme NULL policy: empty string canonicalizes to NULL matching Migration 015 constraints.
// 6. Scheme names differing only by case or surrounding whitespace: same normalized identity.
// 7. Different source hashes with the same natural identity: duplicate identity, with evidence fingerprints independently represented.
// 8. PROMOTED, REJECTED, and INVALID historical records remain outside the partial unique-index scope.
// 9. SQL duplicate precheck grouping semantics mirror the proposed index.
// 10. Unique-violation retry behavior remains safe and idempotent.

'use strict';

const assert = require('assert');
const {
  StagingRetryCoordinator,
  getCandidateIdentityKey,
  computeCandidateIdentity,
  normalizeSchemeName,
} = require('../staging/staging_retry_coordinator');

// Mock Supabase client simulating PostgreSQL 15+ NULLS NOT DISTINCT partial unique index
function createMockSupabase(initialRows = []) {
  const tableData = [...initialRows];

  const client = {
    _rows: tableData,
    from(tableName) {
      if (tableName !== 'staged_rate_candidates') {
        throw new Error(`Unexpected table: ${tableName}`);
      }

      let filters = [];
      let isInsert = false;
      let insertRows = [];

      const queryBuilder = {
        select(cols = '*') {
          return queryBuilder;
        },
        eq(col, val) {
          filters.push({ type: 'eq', col, val });
          return queryBuilder;
        },
        in(col, vals) {
          filters.push({ type: 'in', col, vals });
          return queryBuilder;
        },
        insert(rows) {
          isInsert = true;
          insertRows = Array.isArray(rows) ? rows : [rows];
          return queryBuilder;
        },
        then(resolve) {
          return Promise.resolve(queryBuilder._execute()).then(resolve);
        },
        _execute() {
          if (isInsert) {
            // Simulate PostgreSQL 15+ NULLS NOT DISTINCT partial unique index:
            // CREATE UNIQUE INDEX idx_staged_candidates_active_identity
            //   ON staged_rate_candidates (
            //     bank_code, product_type, customer_type, min_tenure_days, max_tenure_days,
            //     min_deposit, max_deposit, is_callable, rate_category, (upper(btrim(scheme_name)))
            //   )
            //   NULLS NOT DISTINCT
            //   WHERE staging_status IN ('DRAFT', 'IN_REVIEW');
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
                  return {
                    data: null,
                    error: {
                      code: '23505',
                      message: `duplicate key value violates unique constraint "idx_staged_candidates_active_identity" (Key: ${newKey})`,
                    },
                  };
                }
              }
            }

            const inserted = insertRows.map((r, idx) => ({
              id: r.id || `uuid_staged_${Date.now()}_${idx}`,
              ...r,
            }));
            tableData.push(...inserted);
            return { data: inserted, error: null };
          }

          // SELECT query
          let rows = [...tableData];
          for (const f of filters) {
            if (f.type === 'eq') {
              rows = rows.filter(r => r[f.col] === f.val);
            } else if (f.type === 'in') {
              rows = rows.filter(r => f.vals.includes(r[f.col]));
            }
          }
          return { data: rows, error: null };
        },
      };

      return queryBuilder;
    },
  };

  return client;
}

// Simulates PostgreSQL SQL GROUP BY semantics for Check 4 of 016_staging_precheck.sql
function simulatePrecheckCheck4(rows) {
  // WHERE staging_status IN ('DRAFT', 'IN_REVIEW')
  const activeRows = rows.filter(r => ['DRAFT', 'IN_REVIEW'].includes(r.staging_status));

  // SQL GROUP BY treats NULL values as equal to each other, but distinct from non-NULL values
  const groups = new Map();

  for (const r of activeRows) {
    const bank_code = r.bank_code;
    const product_type = r.product_type;
    const customer_type = r.customer_type;
    const min_tenure_days = r.min_tenure_days;
    const max_tenure_days = r.max_tenure_days;
    const min_deposit = r.min_deposit !== undefined ? r.min_deposit : null;
    const max_deposit = r.max_deposit !== undefined ? r.max_deposit : null;
    const is_callable = r.is_callable !== undefined ? r.is_callable : null;
    const rate_category = r.rate_category;
    const norm_scheme_name = (r.scheme_name !== null && r.scheme_name !== undefined)
      ? normalizeSchemeName(r.scheme_name)
      : null;

    // Grouping key serialized with exact types preserved (mirrors SQL GROUP BY)
    const groupKey = JSON.stringify([
      bank_code,
      product_type,
      customer_type,
      min_tenure_days,
      max_tenure_days,
      min_deposit,
      max_deposit,
      is_callable,
      rate_category,
      norm_scheme_name,
    ]);

    if (!groups.has(groupKey)) {
      groups.set(groupKey, []);
    }
    groups.get(groupKey).push(r);
  }

  // HAVING count(*) > 1
  const duplicates = [];
  for (const [key, groupRows] of groups.entries()) {
    if (groupRows.length > 1) {
      duplicates.push({
        groupKey: key,
        duplicate_count: groupRows.length,
        candidate_ids: groupRows.map(r => r.id),
        statuses: groupRows.map(r => r.staging_status),
      });
    }
  }

  return duplicates;
}

async function runTests() {
  console.log('======================================================');
  console.log('FeroCalc Phase 3C.5.18 Native NULLS NOT DISTINCT Tests');
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
      console.error(`        ${err.message}`);
      failed++;
    }
  }

  const baseCandidate = {
    bankCode: 'SBI',
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    customerType: 'REGULAR',
    minTenureDays: 365,
    maxTenureDays: 729,
    minDeposit: null,
    maxDeposit: null,
    isCallable: true,
    rateCategory: 'STANDARD',
    schemeName: null,
    stagingStatus: 'DRAFT',
    interestRate: 6.80,
    sourceContentHash: 'hash_test_sha256_initial',
  };

  console.log('Group 1: Native NULL-Preserving Identity Key Derivation...');

  await test('1. Two candidates with otherwise equal identity and both nullable deposit fields NULL: duplicate', async () => {
    const c1 = { ...baseCandidate, minDeposit: null, maxDeposit: null };
    const c2 = { ...baseCandidate, minDeposit: null, maxDeposit: null };

    const key1 = getCandidateIdentityKey(c1);
    const key2 = getCandidateIdentityKey(c2);

    assert.strictEqual(key1, key2, 'Keys must be identical for matching NULL deposits');

    // Verify database partial unique index rejects second insert
    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: c1.bankCode,
      product_type: c1.productType,
      customer_type: c1.customerType,
      min_tenure_days: c1.minTenureDays,
      max_tenure_days: c1.maxTenureDays,
      min_deposit: c1.minDeposit,
      max_deposit: c1.maxDeposit,
      is_callable: c1.isCallable,
      rate_category: c1.rateCategory,
      scheme_name: c1.schemeName,
      staging_status: c1.stagingStatus,
    });
    assert.strictEqual(res1.error, null);

    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: c2.bankCode,
      product_type: c2.productType,
      customer_type: c2.customerType,
      min_tenure_days: c2.minTenureDays,
      max_tenure_days: c2.maxTenureDays,
      min_deposit: c2.minDeposit,
      max_deposit: c2.maxDeposit,
      is_callable: c2.isCallable,
      rate_category: c2.rateCategory,
      scheme_name: c2.schemeName,
      staging_status: c2.stagingStatus,
    });
    assert.notStrictEqual(res2.error, null);
    assert.strictEqual(res2.error.code, '23505');
  });

  await test('2. NULL minimum deposit versus explicit zero: distinct identities', async () => {
    const cNull = { ...baseCandidate, minDeposit: null };
    const cZero = { ...baseCandidate, minDeposit: 0 };

    const keyNull = getCandidateIdentityKey(cNull);
    const keyZero = getCandidateIdentityKey(cZero);

    assert.notStrictEqual(keyNull, keyZero, 'NULL minDeposit must not collapse into explicit 0');

    // Both should insert without uniqueness conflict
    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cNull.bankCode,
      product_type: cNull.productType,
      customer_type: cNull.customerType,
      min_tenure_days: cNull.minTenureDays,
      max_tenure_days: cNull.maxTenureDays,
      min_deposit: cNull.minDeposit,
      max_deposit: cNull.maxDeposit,
      is_callable: cNull.isCallable,
      rate_category: cNull.rateCategory,
      scheme_name: cNull.schemeName,
      staging_status: 'DRAFT',
    });
    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cZero.bankCode,
      product_type: cZero.productType,
      customer_type: cZero.customerType,
      min_tenure_days: cZero.minTenureDays,
      max_tenure_days: cZero.maxTenureDays,
      min_deposit: cZero.minDeposit,
      max_deposit: cZero.maxDeposit,
      is_callable: cZero.isCallable,
      rate_category: cZero.rateCategory,
      scheme_name: cZero.schemeName,
      staging_status: 'DRAFT',
    });

    assert.strictEqual(res1.error, null);
    assert.strictEqual(res2.error, null);
    assert.strictEqual(mockDb._rows.length, 2);
  });

  await test('3. NULL maximum deposit versus explicit negative one: distinct identities (schema rule documented)', async () => {
    // Schema Rule Documented:
    // staged_rate_candidates (Migration 011/015) has NO check constraint rejecting negative deposit amounts.
    // (Check constraint fd_rates_deposit_max_gte_min exists on fd_rates, NOT staged_rate_candidates).
    // Therefore, NULL max_deposit and explicit -1 are distinct in both SQL and application key.
    const cNull = { ...baseCandidate, maxDeposit: null };
    const cNegOne = { ...baseCandidate, maxDeposit: -1 };

    const keyNull = getCandidateIdentityKey(cNull);
    const keyNegOne = getCandidateIdentityKey(cNegOne);

    assert.notStrictEqual(keyNull, keyNegOne, 'NULL maxDeposit must not collapse into synthetic sentinel -1');

    // Both should insert without uniqueness conflict
    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cNull.bankCode,
      product_type: cNull.productType,
      customer_type: cNull.customerType,
      min_tenure_days: cNull.minTenureDays,
      max_tenure_days: cNull.maxTenureDays,
      min_deposit: cNull.minDeposit,
      max_deposit: cNull.maxDeposit,
      is_callable: cNull.isCallable,
      rate_category: cNull.rateCategory,
      scheme_name: cNull.schemeName,
      staging_status: 'DRAFT',
    });
    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cNegOne.bankCode,
      product_type: cNegOne.productType,
      customer_type: cNegOne.customerType,
      min_tenure_days: cNegOne.minTenureDays,
      max_tenure_days: cNegOne.maxTenureDays,
      min_deposit: cNegOne.minDeposit,
      max_deposit: cNegOne.maxDeposit,
      is_callable: cNegOne.isCallable,
      rate_category: cNegOne.rateCategory,
      scheme_name: cNegOne.schemeName,
      staging_status: 'DRAFT',
    });

    assert.strictEqual(res1.error, null);
    assert.strictEqual(res2.error, null);
    assert.strictEqual(mockDb._rows.length, 2);
  });

  await test('4. NULL callable flag versus true: distinct identities', async () => {
    const cNull = { ...baseCandidate, isCallable: null };
    const cTrue = { ...baseCandidate, isCallable: true };

    const keyNull = getCandidateIdentityKey(cNull);
    const keyTrue = getCandidateIdentityKey(cTrue);

    assert.notStrictEqual(keyNull, keyTrue, 'NULL isCallable must not collapse into boolean true');

    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cNull.bankCode,
      product_type: cNull.productType,
      customer_type: cNull.customerType,
      min_tenure_days: cNull.minTenureDays,
      max_tenure_days: cNull.maxTenureDays,
      min_deposit: cNull.minDeposit,
      max_deposit: cNull.maxDeposit,
      is_callable: cNull.isCallable,
      rate_category: cNull.rateCategory,
      scheme_name: cNull.schemeName,
      staging_status: 'DRAFT',
    });
    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cTrue.bankCode,
      product_type: cTrue.productType,
      customer_type: cTrue.customerType,
      min_tenure_days: cTrue.minTenureDays,
      max_tenure_days: cTrue.maxTenureDays,
      min_deposit: cTrue.minDeposit,
      max_deposit: cTrue.maxDeposit,
      is_callable: cTrue.isCallable,
      rate_category: cTrue.rateCategory,
      scheme_name: cTrue.schemeName,
      staging_status: 'DRAFT',
    });

    assert.strictEqual(res1.error, null);
    assert.strictEqual(res2.error, null);
    assert.strictEqual(mockDb._rows.length, 2);
  });

  await test('5. Canonical scheme NULL policy: empty string canonicalizes to NULL matching Migration 015 constraints', async () => {
    // Migration 015 / Migration 007 Check Constraints:
    // - staged_rates_scheme_name_standard_null: CHECK (rate_category <> 'STANDARD' OR scheme_name IS NULL)
    // - staged_rates_scheme_name_required: CHECK (rate_category <> 'SPECIAL_SCHEME' OR (scheme_name IS NOT NULL AND btrim(scheme_name) <> ''))
    // Empty string '' is strictly illegal across all tables and categories.
    // Therefore, empty string canonicalizes to NULL in application and database key.
    const cNull = { ...baseCandidate, schemeName: null };
    const cEmpty = { ...baseCandidate, schemeName: '' };
    const cWhitespace = { ...baseCandidate, schemeName: '   \t\n  ' };

    assert.strictEqual(normalizeSchemeName(''), null, 'Empty string must canonicalize to NULL');
    assert.strictEqual(normalizeSchemeName('   \t\n  '), null, 'Whitespace-only string must canonicalize to NULL');

    const keyNull = getCandidateIdentityKey(cNull);
    const keyEmpty = getCandidateIdentityKey(cEmpty);
    const keyWhitespace = getCandidateIdentityKey(cWhitespace);

    assert.strictEqual(keyNull, keyEmpty, 'NULL schemeName and empty schemeName share the same canonical identity');
    assert.strictEqual(keyNull, keyWhitespace, 'Whitespace-only schemeName shares the same canonical identity');

    // Inserting both active records in DRAFT triggers uniqueness constraint
    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cNull.bankCode,
      product_type: cNull.productType,
      customer_type: cNull.customerType,
      min_tenure_days: cNull.minTenureDays,
      max_tenure_days: cNull.maxTenureDays,
      min_deposit: cNull.minDeposit,
      max_deposit: cNull.maxDeposit,
      is_callable: cNull.isCallable,
      rate_category: cNull.rateCategory,
      scheme_name: cNull.schemeName,
      staging_status: 'DRAFT',
    });
    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: cEmpty.bankCode,
      product_type: cEmpty.productType,
      customer_type: cEmpty.customerType,
      min_tenure_days: cEmpty.minTenureDays,
      max_tenure_days: cEmpty.maxTenureDays,
      min_deposit: cEmpty.minDeposit,
      max_deposit: cEmpty.maxDeposit,
      is_callable: cEmpty.isCallable,
      rate_category: cEmpty.rateCategory,
      scheme_name: cEmpty.schemeName,
      staging_status: 'DRAFT',
    });

    assert.strictEqual(res1.error, null);
    assert.notStrictEqual(res2.error, null);
    assert.strictEqual(res2.error.code, '23505', 'Duplicate active record with empty scheme rejected as duplicate of NULL scheme');
    assert.strictEqual(mockDb._rows.length, 1);
  });

  await test('6. Scheme names differing only by case or surrounding whitespace: same normalized identity', async () => {
    const c1 = { ...baseCandidate, rateCategory: 'SPECIAL_SCHEME', schemeName: 'SBI We-Care' };
    const c2 = { ...baseCandidate, rateCategory: 'SPECIAL_SCHEME', schemeName: '   sbi we-care   ' };

    const key1 = getCandidateIdentityKey(c1);
    const key2 = getCandidateIdentityKey(c2);

    assert.strictEqual(key1, key2, 'Case and whitespace must be normalized identically');

    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: c1.bankCode,
      product_type: c1.productType,
      customer_type: c1.customerType,
      min_tenure_days: c1.minTenureDays,
      max_tenure_days: c1.maxTenureDays,
      min_deposit: c1.minDeposit,
      max_deposit: c1.maxDeposit,
      is_callable: c1.isCallable,
      rate_category: c1.rateCategory,
      scheme_name: c1.schemeName,
      staging_status: 'DRAFT',
    });
    assert.strictEqual(res1.error, null);

    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: c2.bankCode,
      product_type: c2.productType,
      customer_type: c2.customerType,
      min_tenure_days: c2.minTenureDays,
      max_tenure_days: c2.maxTenureDays,
      min_deposit: c2.minDeposit,
      max_deposit: c2.maxDeposit,
      is_callable: c2.isCallable,
      rate_category: c2.rateCategory,
      scheme_name: c2.schemeName,
      staging_status: 'DRAFT',
    });
    assert.notStrictEqual(res2.error, null);
    assert.strictEqual(res2.error.code, '23505');
  });

  await test('7. Different source hashes with the same natural identity: duplicate identity, evidence fingerprints distinct', async () => {
    const c1 = { ...baseCandidate, sourceContentHash: 'hash_sha256_v1' };
    const c2 = { ...baseCandidate, sourceContentHash: 'hash_sha256_v2' };

    const key1 = getCandidateIdentityKey(c1);
    const key2 = getCandidateIdentityKey(c2);

    assert.strictEqual(key1, key2, 'Candidate natural identity must be independent of source hash');
    assert.notStrictEqual(c1.sourceContentHash, c2.sourceContentHash, 'Evidence fingerprints remain distinct');

    const mockDb = createMockSupabase();
    const res1 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: c1.bankCode,
      product_type: c1.productType,
      customer_type: c1.customerType,
      min_tenure_days: c1.minTenureDays,
      max_tenure_days: c1.maxTenureDays,
      min_deposit: c1.minDeposit,
      max_deposit: c1.maxDeposit,
      is_callable: c1.isCallable,
      rate_category: c1.rateCategory,
      scheme_name: c1.schemeName,
      staging_status: 'DRAFT',
      source_content_hash: c1.sourceContentHash,
    });
    assert.strictEqual(res1.error, null);

    // Second active insert fails unique index even with changed source hash
    const res2 = await mockDb.from('staged_rate_candidates').insert({
      bank_code: c2.bankCode,
      product_type: c2.productType,
      customer_type: c2.customerType,
      min_tenure_days: c2.minTenureDays,
      max_tenure_days: c2.maxTenureDays,
      min_deposit: c2.minDeposit,
      max_deposit: c2.maxDeposit,
      is_callable: c2.isCallable,
      rate_category: c2.rateCategory,
      scheme_name: c2.schemeName,
      staging_status: 'DRAFT',
      source_content_hash: c2.sourceContentHash,
    });
    assert.notStrictEqual(res2.error, null);
    assert.strictEqual(res2.error.code, '23505');
  });

  console.log('\nGroup 2: Lifecycle Scope & SQL Precheck Grouping Semantics...');

  await test('8. PROMOTED, REJECTED, and INVALID historical records remain outside the partial unique-index scope', async () => {
    const mockDb = createMockSupabase();

    // 1. Insert historical PROMOTED row
    const resPromoted = await mockDb.from('staged_rate_candidates').insert({
      bank_code: baseCandidate.bankCode,
      product_type: baseCandidate.productType,
      customer_type: baseCandidate.customerType,
      min_tenure_days: baseCandidate.minTenureDays,
      max_tenure_days: baseCandidate.maxTenureDays,
      min_deposit: baseCandidate.minDeposit,
      max_deposit: baseCandidate.maxDeposit,
      is_callable: baseCandidate.isCallable,
      rate_category: baseCandidate.rateCategory,
      scheme_name: baseCandidate.schemeName,
      staging_status: 'PROMOTED',
    });
    assert.strictEqual(resPromoted.error, null);

    // 2. Insert historical REJECTED row
    const resRejected = await mockDb.from('staged_rate_candidates').insert({
      bank_code: baseCandidate.bankCode,
      product_type: baseCandidate.productType,
      customer_type: baseCandidate.customerType,
      min_tenure_days: baseCandidate.minTenureDays,
      max_tenure_days: baseCandidate.maxTenureDays,
      min_deposit: baseCandidate.minDeposit,
      max_deposit: baseCandidate.maxDeposit,
      is_callable: baseCandidate.isCallable,
      rate_category: baseCandidate.rateCategory,
      scheme_name: baseCandidate.schemeName,
      staging_status: 'REJECTED',
    });
    assert.strictEqual(resRejected.error, null);

    // 3. Insert historical INVALID row
    const resInvalid = await mockDb.from('staged_rate_candidates').insert({
      bank_code: baseCandidate.bankCode,
      product_type: baseCandidate.productType,
      customer_type: baseCandidate.customerType,
      min_tenure_days: baseCandidate.minTenureDays,
      max_tenure_days: baseCandidate.maxTenureDays,
      min_deposit: baseCandidate.minDeposit,
      max_deposit: baseCandidate.maxDeposit,
      is_callable: baseCandidate.isCallable,
      rate_category: baseCandidate.rateCategory,
      scheme_name: baseCandidate.schemeName,
      staging_status: 'INVALID',
    });
    assert.strictEqual(resInvalid.error, null);

    // 4. Insert active DRAFT row (succeeds because historical rows are outside predicate)
    const resDraft = await mockDb.from('staged_rate_candidates').insert({
      bank_code: baseCandidate.bankCode,
      product_type: baseCandidate.productType,
      customer_type: baseCandidate.customerType,
      min_tenure_days: baseCandidate.minTenureDays,
      max_tenure_days: baseCandidate.maxTenureDays,
      min_deposit: baseCandidate.minDeposit,
      max_deposit: baseCandidate.maxDeposit,
      is_callable: baseCandidate.isCallable,
      rate_category: baseCandidate.rateCategory,
      scheme_name: baseCandidate.schemeName,
      staging_status: 'DRAFT',
    });
    assert.strictEqual(resDraft.error, null);

    // 5. Insert second active row IN_REVIEW (fails because DRAFT is already active)
    const resInReview = await mockDb.from('staged_rate_candidates').insert({
      bank_code: baseCandidate.bankCode,
      product_type: baseCandidate.productType,
      customer_type: baseCandidate.customerType,
      min_tenure_days: baseCandidate.minTenureDays,
      max_tenure_days: baseCandidate.maxTenureDays,
      min_deposit: baseCandidate.minDeposit,
      max_deposit: baseCandidate.maxDeposit,
      is_callable: baseCandidate.isCallable,
      rate_category: baseCandidate.rateCategory,
      scheme_name: baseCandidate.schemeName,
      staging_status: 'IN_REVIEW',
    });
    assert.notStrictEqual(resInReview.error, null);
    assert.strictEqual(resInReview.error.code, '23505');
  });

  await test('9. SQL duplicate precheck grouping semantics mirror the proposed index', async () => {
    // Populate rows with various combinations
    const rows = [
      // Pair 1: Two identical DRAFT candidates with NULL deposits -> DUPLICATE
      { id: 'row1', bank_code: 'SBI', product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT', customer_type: 'REGULAR', min_tenure_days: 365, max_tenure_days: 729, min_deposit: null, max_deposit: null, is_callable: true, rate_category: 'STANDARD', scheme_name: null, staging_status: 'DRAFT' },
      { id: 'row2', bank_code: 'SBI', product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT', customer_type: 'REGULAR', min_tenure_days: 365, max_tenure_days: 729, min_deposit: null, max_deposit: null, is_callable: true, rate_category: 'STANDARD', scheme_name: null, staging_status: 'IN_REVIEW' },

      // Row 3: min_deposit: 0 (explicit) -> distinct from Pair 1
      { id: 'row3', bank_code: 'SBI', product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT', customer_type: 'REGULAR', min_tenure_days: 365, max_tenure_days: 729, min_deposit: 0, max_deposit: null, is_callable: true, rate_category: 'STANDARD', scheme_name: null, staging_status: 'DRAFT' },

      // Row 4: is_callable: null -> distinct from true
      { id: 'row4', bank_code: 'SBI', product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT', customer_type: 'REGULAR', min_tenure_days: 365, max_tenure_days: 729, min_deposit: null, max_deposit: null, is_callable: null, rate_category: 'STANDARD', scheme_name: null, staging_status: 'DRAFT' },

      // Row 5: PROMOTED row with same identity as Pair 1 -> excluded by WHERE predicate
      { id: 'row5', bank_code: 'SBI', product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT', customer_type: 'REGULAR', min_tenure_days: 365, max_tenure_days: 729, min_deposit: null, max_deposit: null, is_callable: true, rate_category: 'STANDARD', scheme_name: null, staging_status: 'PROMOTED' },
    ];

    const duplicateGroups = simulatePrecheckCheck4(rows);

    // Exactly one duplicate group should be detected (Pair 1: row1 and row2)
    assert.strictEqual(duplicateGroups.length, 1, 'Precheck must detect exactly 1 duplicate group');
    assert.strictEqual(duplicateGroups[0].duplicate_count, 2);
    assert.deepStrictEqual(duplicateGroups[0].candidate_ids, ['row1', 'row2']);
    assert.deepStrictEqual(duplicateGroups[0].statuses, ['DRAFT', 'IN_REVIEW']);
  });

  await test('10. Unique-violation retry behavior remains safe and idempotent', async () => {
    const coordinator = new StagingRetryCoordinator();

    // Setup: Table already contains committed row under hash H
    const committedRow = {
      id: 'uuid_committed_row_1',
      bank_code: 'SBI',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      min_tenure_days: 365,
      max_tenure_days: 729,
      min_deposit: null,
      max_deposit: null,
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      interest_rate: 6.80,
      staging_status: 'DRAFT',
      source_content_hash: 'hash_sbi_run_123',
    };

    const mockDb = createMockSupabase([committedRow]);

    // Scenario A: Worker 2 retries identical candidate under same hash
    // (Simulating uncertain network timeout where Worker 1 succeeded)
    const retryCandidate = {
      bankCode: 'SBI',
      productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customerType: 'REGULAR',
      minTenureDays: 365,
      maxTenureDays: 729,
      minDeposit: null,
      maxDeposit: null,
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      interestRate: 6.80,
    };

    const recA = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_sbi_run_123',
      expectedCandidates: [retryCandidate],
    });

    assert.strictEqual(recA.canProceed, true, 'Retry must succeed idempotently');
    assert.strictEqual(recA.status, 'ALREADY_COMMITTED');
    assert.strictEqual(recA.writeReceipt.length, 1);
    assert.strictEqual(recA.writeReceipt[0].id, 'uuid_committed_row_1');

    // Scenario B: Worker attempts to stage DIFFERENT rate for same identity under same hash -> FAILS CLOSED
    const conflictingCandidate = {
      ...retryCandidate,
      interestRate: 7.00, // Conflict!
    };

    const recB = await coordinator.reconcileStagingState({
      supabaseClient: mockDb,
      bankCode: 'SBI',
      sourceContentHash: 'hash_sbi_run_123',
      expectedCandidates: [conflictingCandidate],
    });

    assert.strictEqual(recB.canProceed, false, 'Rate conflict must fail closed');
    assert.strictEqual(recB.status, 'IDENTITY_MISMATCH');
    assert.match(recB.reason, /Rate change conflict detected/);

    // Scenario C: Direct insert collision simulation
    const insertCollision = await mockDb.from('staged_rate_candidates').insert({
      bank_code: retryCandidate.bankCode,
      product_type: retryCandidate.productType,
      customer_type: retryCandidate.customerType,
      min_tenure_days: retryCandidate.minTenureDays,
      max_tenure_days: retryCandidate.maxTenureDays,
      min_deposit: retryCandidate.minDeposit,
      max_deposit: retryCandidate.maxDeposit,
      is_callable: retryCandidate.isCallable,
      rate_category: retryCandidate.rateCategory,
      scheme_name: retryCandidate.schemeName,
      staging_status: 'DRAFT',
    });

    assert.notStrictEqual(insertCollision.error, null);
    assert.strictEqual(insertCollision.error.code, '23505');
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
