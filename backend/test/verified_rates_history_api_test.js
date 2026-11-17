// FeroCalc Phase 5.0.1 — Verified Rate History & Freshness Security Test Suite
//
// Tests public rate history endpoint:
// - GET /api/verified-rates/history/:bankId
//
// Invariants tested:
// - Test 1: Invalid UUID bankId returns HTTP 400 Bad Request.
// - Test 2: Non-existent bank returns HTTP 404 Not Found.
// - Test 3: Only VERIFIED and ARCHIVED rates returned; DRAFT, IN_REVIEW, REJECTED are strictly excluded.
// - Test 4: Internal admin fields (review_notes, created_by, verified_by) are strictly redacted.
// - Test 5: Previous rate transitions are correctly linked across versions.
// - Test 6: Bank with no rate changes returns empty list with honest coverage note.
// - Test 7: CustomerType and isCallable filters work correctly.
// - Test 8: Public access requires NO authentication or admin JWT.

'use strict';

const assert = require('assert');
const express = require('express');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    passedTests++;
    console.log(`  PASS: ${name}`);
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
    passedTests++;
    console.log(`  PASS: ${name}`);
  } catch (err) {
    failedTests++;
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
  }
}

const VALID_BANK_ID = '425d8373-c612-4bb6-9218-672d09ea47f1';
const EMPTY_BANK_ID = '99999999-9999-9999-9999-999999999999';

const MOCK_BANKS = [
  {
    id: VALID_BANK_ID,
    name: 'HDFC Bank',
    short_name: 'HDFC',
    status: 'ACTIVE',
    official_website: 'https://www.hdfc.bank.in',
  },
  {
    id: EMPTY_BANK_ID,
    name: 'Empty Bank',
    short_name: 'EB',
    status: 'ACTIVE',
    official_website: 'https://www.emptybank.com',
  },
];

const MOCK_RATES = [
  {
    id: 'rate-archived-1',
    bank_id: VALID_BANK_ID,
    customer_type: 'REGULAR',
    interest_rate: 6.00,
    tenure_domain: 'CALENDAR',
    min_years: 1,
    min_months: 0,
    min_days_cal: 0,
    min_operator: 'GTE',
    max_years: 1,
    max_months: 3,
    max_days_cal: 0,
    max_operator: 'LT',
    is_callable: true,
    effective_from: '2026-01-01T00:00:00Z',
    effective_until: '2026-08-19T00:00:00Z',
    status: 'ARCHIVED',
    source_url: 'https://www.hdfc.bank.in/fd-rates',
    verified_at: '2026-01-02T10:00:00Z',
    created_by: 'admin-uuid-1',
    verified_by: 'reviewer-uuid-1',
    review_notes: 'CONFIDENTIAL REVIEW NOTE — Internal admin observation',
  },
  {
    id: 'rate-verified-current-1',
    bank_id: VALID_BANK_ID,
    customer_type: 'REGULAR',
    interest_rate: 6.25,
    tenure_domain: 'CALENDAR',
    min_years: 1,
    min_months: 0,
    min_days_cal: 0,
    min_operator: 'GTE',
    max_years: 1,
    max_months: 3,
    max_days_cal: 0,
    max_operator: 'LT',
    is_callable: true,
    effective_from: '2026-08-19T00:00:00Z',
    effective_until: null,
    status: 'VERIFIED',
    source_url: 'https://www.hdfc.bank.in/fd-rates',
    verified_at: '2026-08-20T10:00:00Z',
    created_by: 'admin-uuid-2',
    verified_by: 'reviewer-uuid-2',
    review_notes: 'CONFIDENTIAL REVIEW NOTE — Rate increase approved',
  },
  {
    id: 'rate-draft-leak-test',
    bank_id: VALID_BANK_ID,
    customer_type: 'REGULAR',
    interest_rate: 9.99,
    status: 'DRAFT',
    is_callable: true,
    effective_from: '2026-12-01T00:00:00Z',
    review_notes: 'UNVERIFIED CANDIDATE DRAFT',
  },
  {
    id: 'rate-in-review-leak-test',
    bank_id: VALID_BANK_ID,
    customer_type: 'REGULAR',
    interest_rate: 8.88,
    status: 'IN_REVIEW',
    is_callable: true,
    effective_from: '2026-12-01T00:00:00Z',
    review_notes: 'UNVERIFIED IN_REVIEW CANDIDATE',
  },
  {
    id: 'rate-rejected-leak-test',
    bank_id: VALID_BANK_ID,
    customer_type: 'REGULAR',
    interest_rate: 1.00,
    status: 'REJECTED',
    is_callable: true,
    effective_from: '2026-12-01T00:00:00Z',
    review_notes: 'REJECTED DUE TO ERROR',
  },
];

class MockHistoryQueryBuilder {
  constructor(table) {
    this.table = table;
    this.dataset = table === 'banks' ? [...MOCK_BANKS] : [...MOCK_RATES];
  }
  select() { return this; }
  eq(field, val) {
    this.dataset = this.dataset.filter(r => r[field] === val);
    return this;
  }
  in(field, list) {
    this.dataset = this.dataset.filter(r => list.includes(r[field]));
    return this;
  }
  order(field, opts) {
    const asc = opts?.ascending ?? true;
    this.dataset.sort((a, b) => {
      if (a[field] < b[field]) return asc ? -1 : 1;
      if (a[field] > b[field]) return asc ? 1 : -1;
      return 0;
    });
    return this;
  }
  maybeSingle() {
    return Promise.resolve({ data: this.dataset[0] || null, error: null });
  }
  then(resolve, reject) {
    return Promise.resolve({ data: this.dataset, error: null }).then(resolve, reject);
  }
}

const mockClient = {
  from: (table) => new MockHistoryQueryBuilder(table),
};

const clientPath = require.resolve('../supabase/supabase_client');
require.cache[clientPath] = {
  id: clientPath,
  filename: clientPath,
  loaded: true,
  exports: {
    supabasePublic: mockClient,
    supabaseAdmin: mockClient,
    isSupabaseAvailable: () => true,
    verifySupabaseUser: async () => ({ id: 'mock-user' }),
  },
};

const verifiedRatesRouter = require('../routes/verified_rates');

async function testEndpoint(url) {
  const app = express();
  app.use(express.json());
  app.use('/api/verified-rates', verifiedRatesRouter);

  return new Promise((resolve) => {
    const server = app.listen(0, async () => {
      const port = server.address().port;
      try {
        const res = await fetch(`http://127.0.0.1:${port}${url}`);
        const body = await res.json();
        server.close();
        resolve({ status: res.status, body, headers: res.headers });
      } catch (e) {
        server.close();
        resolve({ status: 500, error: e.message });
      }
    });
  });
}

async function run() {
  console.log('\n======================================================');
  console.log('FeroCalc Phase 5.0.1 Verified Rate History Test Suite');
  console.log('======================================================\n');

  // Test 1: Invalid UUID format
  await runTestAsync('1. Invalid UUID format returns HTTP 400', async () => {
    const res = await testEndpoint('/api/verified-rates/history/invalid-uuid-123');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.status, 'error');
    assert.match(res.body.message, /expected UUID/i);
  });

  // Test 2: Non-existent bank
  await runTestAsync('2. Non-existent bank returns HTTP 404', async () => {
    const res = await testEndpoint('/api/verified-rates/history/00000000-0000-0000-0000-000000000000');
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.status, 'error');
    assert.match(res.body.message, /Bank not found/i);
  });

  // Test 3: Only VERIFIED and ARCHIVED returned (never DRAFT, IN_REVIEW, REJECTED)
  await runTestAsync('3. Excludes DRAFT, IN_REVIEW, and REJECTED candidates (Security Guard)', async () => {
    const res = await testEndpoint(`/api/verified-rates/history/${VALID_BANK_ID}`);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
    const items = res.body.data;
    assert.strictEqual(items.length, 2, 'Should only contain the 2 verified/archived records');
    for (const item of items) {
      assert.ok(['VERIFIED', 'ARCHIVED'].includes(item.status), `Unexpected status: ${item.status}`);
      assert.notStrictEqual(item.interestRate, 9.99, 'DRAFT rate leaked!');
      assert.notStrictEqual(item.interestRate, 8.88, 'IN_REVIEW rate leaked!');
      assert.notStrictEqual(item.interestRate, 1.00, 'REJECTED rate leaked!');
    }
  });

  // Test 4: Redaction of internal admin fields
  await runTestAsync('4. Strictly redacts internal admin metadata (review_notes, created_by, verified_by)', async () => {
    const res = await testEndpoint(`/api/verified-rates/history/${VALID_BANK_ID}`);
    const items = res.body.data;
    for (const item of items) {
      assert.strictEqual(item.review_notes, undefined, 'review_notes must not be present');
      assert.strictEqual(item.reviewNotes, undefined, 'reviewNotes must not be present');
      assert.strictEqual(item.created_by, undefined, 'created_by must not be present');
      assert.strictEqual(item.createdBy, undefined, 'createdBy must not be present');
      assert.strictEqual(item.verified_by, undefined, 'verified_by must not be present');
      assert.strictEqual(item.verifiedBy, undefined, 'verifiedBy must not be present');
    }
  });

  // Test 5: Previous rate transitions correctly linked
  await runTestAsync('5. Links previous rate transitions correctly across slab versions', async () => {
    const res = await testEndpoint(`/api/verified-rates/history/${VALID_BANK_ID}`);
    const items = res.body.data;
    const currentRate = items.find(i => i.status === 'VERIFIED');
    const archivedRate = items.find(i => i.status === 'ARCHIVED');

    assert.ok(currentRate, 'Current VERIFIED rate should be present');
    assert.ok(archivedRate, 'ARCHIVED rate should be present');
    assert.strictEqual(currentRate.interestRate, 6.25);
    assert.strictEqual(currentRate.previousRate, 6.00, 'Previous rate should link to the older 6.00% rate');
    assert.strictEqual(archivedRate.interestRate, 6.00);
    assert.strictEqual(archivedRate.previousRate, null, 'Oldest rate has no prior rate');
    assert.strictEqual(res.body.meta.hasHistoricalChanges, true);
  });

  // Test 6: Empty history state
  await runTestAsync('6. Bank with no rates returns empty history list with honest note', async () => {
    const res = await testEndpoint(`/api/verified-rates/history/${EMPTY_BANK_ID}`);
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.length, 0);
    assert.strictEqual(res.body.meta.count, 0);
    assert.strictEqual(res.body.meta.hasHistoricalChanges, false);
    assert.match(res.body.meta.note, /No verified rate history/i);
  });

  // Test 7: CustomerType and isCallable filters
  await runTestAsync('7. Filters by customerType and isCallable correctly', async () => {
    const resCallable = await testEndpoint(`/api/verified-rates/history/${VALID_BANK_ID}?isCallable=true`);
    assert.strictEqual(resCallable.body.data.length, 2);

    const resNonCallable = await testEndpoint(`/api/verified-rates/history/${VALID_BANK_ID}?isCallable=false`);
    assert.strictEqual(resNonCallable.body.data.length, 0);
  });

  // Test 8: Public access works without auth headers
  await runTestAsync('8. Public consumer access works without Authorization header', async () => {
    const res = await testEndpoint(`/api/verified-rates/history/${VALID_BANK_ID}`);
    assert.strictEqual(res.status, 200);
  });

  // Test 9: Freshness endpoint returns allowlisted metadata with cache headers
  await runTestAsync('9. GET /api/verified-rates/freshness returns allowlisted metadata with strict no-cache headers', async () => {
    const res = await testEndpoint('/api/verified-rates/freshness');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
    assert.ok(Array.isArray(res.body.data));
    assert.strictEqual(res.headers.get('cache-control'), 'no-store, no-cache, must-revalidate, max-age=0');
    assert.ok(res.body.meta != null);
    assert.strictEqual(typeof res.body.meta.anyUpdatePending, 'boolean');
    assert.strictEqual(typeof res.body.meta.allFresh, 'boolean');
  });

  // Test 10: Freshness endpoint redacts confidential error traces and credentials
  await runTestAsync('10. Freshness endpoint redacts internal connection strings and raw errors', async () => {
    const res = await testEndpoint('/api/verified-rates/freshness');
    const items = res.body.data;
    for (const item of items) {
      assert.ok(item.sourceId != null);
      assert.ok(item.bankCode != null);
      assert.ok(item.sourceUrl != null);
      assert.strictEqual(item.connectionString, undefined);
      assert.strictEqual(item.password, undefined);
      assert.strictEqual(item.raw_error, undefined);
      assert.strictEqual(item.stack, undefined);
    }
  });

  // Test 11: computeSourceFreshness helper logic
  runTest('11. computeSourceFreshness helper calculates staleness and pending review status', () => {
    const sources = [{ id: 'sbi-test', bankCode: 'SBI', bankName: 'State Bank of India', sourceUrl: 'https://sbi.co.in' }];
    const now = new Date('2026-11-12T12:00:00Z');

    // Fresh check
    const recent = new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString();
    const resultFresh = verifiedRatesRouter.computeSourceFreshness(sources, [{ id: 'sbi-test', last_checked_at: recent, last_success_at: recent, last_status: 'UNCHANGED' }], {}, now);
    assert.strictEqual(resultFresh[0].isStale, false);
    assert.strictEqual(resultFresh[0].hasPendingReview, false);
    assert.strictEqual(resultFresh[0].lastStatus, 'UNCHANGED');

    // Stale check (> 24 hours)
    const old = new Date(now.getTime() - 30 * 60 * 60 * 1000).toISOString();
    const resultStale = verifiedRatesRouter.computeSourceFreshness(sources, [{ id: 'sbi-test', last_checked_at: old, last_success_at: old, last_status: 'UNCHANGED' }], {}, now);
    assert.strictEqual(resultStale[0].isStale, true);

    // Pending review check
    const resultPending = verifiedRatesRouter.computeSourceFreshness(sources, [{ id: 'sbi-test', last_checked_at: recent, last_success_at: recent, last_status: 'CHANGED' }], { SBI: 2 }, now);
    assert.strictEqual(resultPending[0].hasPendingReview, true);
    assert.strictEqual(resultPending[0].pendingReviewCount, 2);
    assert.strictEqual(resultPending[0].updateDetected, true);
  });

  console.log(`\nResults: ${passedTests} passed, ${failedTests} failed (Total: ${totalTests})\n`);
  if (failedTests > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
