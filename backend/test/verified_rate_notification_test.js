// FeroCalc Verified FD Rate Engine — Verified Rate Notification Reliability & Idempotency Test Suite (Phase 5.0.6.1)
'use strict';

const assert = require('assert');
const express = require('express');
const http = require('http');
const {
  VerifiedRateNotificationService,
  verifiedRateNotificationService,
  normalizeEffectiveDate,
  deterministicStringify,
} = require('../notifications/verified_rate_notification_service');
const notificationsRouter = require('../routes/notifications');

let passedTests = 0;
let totalTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
    process.exitCode = 1;
  }
}

async function runAsyncTest(name, fn) {
  totalTests++;
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
    process.exitCode = 1;
  }
}

// Persistent test store simulating an atomic database with unique constraint
class PersistentTestStore {
  constructor() {
    this.events = new Map();
  }

  async recordEvent(eventRecord) {
    const { eventId, payload } = eventRecord;
    // Simulate PostgreSQL UNIQUE constraint check (23505)
    if (this.events.has(eventId)) {
      return {
        duplicate: true,
        eventId,
        reason: `Idempotent duplicate: Event ${eventId} was already recorded in durable store.`,
      };
    }
    this.events.set(eventId, { ...payload });
    return { duplicate: false, eventId };
  }

  async getRecent(limit = 20) {
    return Array.from(this.events.values()).reverse().slice(0, limit);
  }

  clear() {
    this.events.clear();
  }
}

async function main() {
  console.log('======================================================');
  console.log('FeroCalc Phase 5.0.6.1 Notification Reliability Suite');
  console.log('======================================================\n');

  console.log('Group 1: Verified-Only Event Filtering & Status Guards (Req 9)...');

  await runAsyncTest('1.1 Strictly rejects DRAFT status from notification dispatch', async () => {
    const service = new VerifiedRateNotificationService();
    const result = await service.dispatchVerifiedRateEvent({
      status: 'DRAFT',
      bankCode: 'SBI',
      bankName: 'State Bank of India',
      newRate: 7.0,
    });

    assert.strictEqual(result.dispatched, false);
    assert.strictEqual(result.rejected, true);
    assert.ok(result.reason.includes('non-verified status "DRAFT"'));
  });

  await runAsyncTest('1.2 Strictly rejects IN_REVIEW status from notification dispatch', async () => {
    const service = new VerifiedRateNotificationService();
    const result = await service.dispatchVerifiedRateEvent({
      status: 'IN_REVIEW',
      bankCode: 'HDFC',
      bankName: 'HDFC Bank',
      newRate: 7.25,
    });

    assert.strictEqual(result.dispatched, false);
    assert.strictEqual(result.rejected, true);
    assert.ok(result.reason.includes('non-verified status "IN_REVIEW"'));
  });

  await runAsyncTest('1.3 Strictly rejects REJECTED status from notification dispatch', async () => {
    const service = new VerifiedRateNotificationService();
    const result = await service.dispatchVerifiedRateEvent({
      status: 'REJECTED',
      bankCode: 'ICICI',
      bankName: 'ICICI Bank',
      newRate: 6.9,
    });

    assert.strictEqual(result.dispatched, false);
    assert.strictEqual(result.rejected, true);
    assert.ok(result.reason.includes('non-verified status "REJECTED"'));
  });

  await runAsyncTest('1.4 Dispatches successfully when status is VERIFIED', async () => {
    const service = new VerifiedRateNotificationService();
    const result = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'SBI',
      bankName: 'State Bank of India',
      bankId: 'sbi-retail',
      newRate: 7.1,
      previousRate: 6.8,
      tenureDescription: '1 Year to 2 Years',
      effectiveDate: '2026-11-01',
    });

    assert.strictEqual(result.dispatched, true);
    assert.ok(result.eventId.startsWith('evt_'));
    assert.strictEqual(result.payload.bankCode, 'SBI');
    assert.strictEqual(result.payload.title, 'State Bank of India Rate Update');
    assert.ok(result.payload.message.includes('rate increased from 6.8% to 7.1% p.a.'));
    assert.strictEqual(result.payload.effectiveDate, '2026-11-01');
    assert.ok(result.payload.verifiedTimestamp);
  });

  await runAsyncTest('1.5 Dispatches successfully when status is PROMOTED', async () => {
    const service = new VerifiedRateNotificationService();
    const result = await service.dispatchVerifiedRateEvent({
      status: 'PROMOTED',
      bankCode: 'BOB',
      bankName: 'Bank of Baroda',
      newRate: 7.15,
      tenureDescription: '399 Days Special Scheme',
    });

    assert.strictEqual(result.dispatched, true);
    assert.ok(result.payload.message.includes('New verified slab published'));
  });

  console.log('\nGroup 2: Deterministic Identity & Stable Event Hashing (Req 1, 4, 5, 6, 7, 8)...');

  await runAsyncTest('2.1 Identical event processed twice with different system timestamps produces one event ID (Req 1)', async () => {
    const service = new VerifiedRateNotificationService();
    const baseParams = {
      status: 'VERIFIED',
      bankCode: 'KOTAK',
      bankName: 'Kotak Mahindra Bank',
      newRate: 7.4,
      effectiveDate: '2026-11-10',
      tenureDescription: '390 Days',
      candidateId: 'cand_kotak_390d',
    };

    const first = await service.dispatchVerifiedRateEvent(baseParams);
    assert.strictEqual(first.dispatched, true);

    // Wait a brief tick so system clock advances
    await new Promise((r) => setTimeout(r, 15));

    const second = await service.dispatchVerifiedRateEvent(baseParams);
    assert.strictEqual(second.dispatched, false);
    assert.strictEqual(second.duplicate, true);
    assert.strictEqual(second.eventId, first.eventId);
    assert.ok(second.reason.includes('Idempotent duplicate'));
  });

  await runAsyncTest('2.2 Materially changed rate payload generates a distinct new event identity (Req 4)', async () => {
    const service = new VerifiedRateNotificationService();
    const paramsA = {
      status: 'VERIFIED',
      bankCode: 'HDFC',
      bankName: 'HDFC Bank',
      newRate: 7.25,
      previousRate: 7.0,
      tenureDescription: '1 Year to < 15 Months',
      effectiveDate: '2026-11-01',
      candidateId: 'cand_hdfc_1y',
    };

    const paramsB = {
      ...paramsA,
      newRate: 7.35, // Rate changed from 7.25 to 7.35
      previousRate: 7.25,
    };

    const resA = await service.dispatchVerifiedRateEvent(paramsA);
    const resB = await service.dispatchVerifiedRateEvent(paramsB);

    assert.strictEqual(resA.dispatched, true);
    assert.strictEqual(resB.dispatched, true);
    assert.notStrictEqual(resA.eventId, resB.eventId);
    assert.ok(resB.payload.message.includes('rate increased from 7.25% to 7.35% p.a.'));
  });

  await runAsyncTest('2.3 Unchanged rate change event (previousRate == newRate) is suppressed without dispatching', async () => {
    const service = new VerifiedRateNotificationService();
    const result = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'AXIS',
      bankName: 'Axis Bank',
      newRate: 7.1,
      previousRate: 7.1, // Unchanged
      tenureDescription: '1 Year',
      type: 'verifiedRateChange',
    });

    assert.strictEqual(result.dispatched, false);
    assert.strictEqual(result.unchanged, true);
    assert.ok(result.reason.includes('has not materially changed'));
  });

  await runAsyncTest('2.4 Changed effective date generates a correct distinct event identity (Req 5)', async () => {
    const service = new VerifiedRateNotificationService();
    const paramsDate1 = {
      status: 'VERIFIED',
      bankCode: 'ICICI',
      bankName: 'ICICI Bank',
      newRate: 7.2,
      effectiveDate: '2026-10-01',
      tenureDescription: '15 Months to 18 Months',
      candidateId: 'cand_icici_15m',
    };

    const paramsDate2 = {
      ...paramsDate1,
      effectiveDate: '2026-11-01', // New effective date
    };

    const res1 = await service.dispatchVerifiedRateEvent(paramsDate1);
    const res2 = await service.dispatchVerifiedRateEvent(paramsDate2);

    assert.strictEqual(res1.dispatched, true);
    assert.strictEqual(res2.dispatched, true);
    assert.notStrictEqual(res1.eventId, res2.eventId);
  });

  await runAsyncTest('2.5 Different banks never collide on identical tenure and rate parameters (Req 6)', async () => {
    const service = new VerifiedRateNotificationService();
    const sbiRes = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'SBI',
      bankName: 'State Bank of India',
      newRate: 6.8,
      tenureDescription: '1 Year',
      effectiveDate: '2026-11-01',
    });

    const pnbRes = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'PNB',
      bankName: 'Punjab National Bank',
      newRate: 6.8,
      tenureDescription: '1 Year',
      effectiveDate: '2026-11-01',
    });

    assert.strictEqual(sbiRes.dispatched, true);
    assert.strictEqual(pnbRes.dispatched, true);
    assert.notStrictEqual(sbiRes.eventId, pnbRes.eventId);
    assert.notStrictEqual(sbiRes.payload.bankId, pnbRes.payload.bankId);
  });

  await runAsyncTest('2.6 Different notification categories never collide incorrectly (Req 7)', async () => {
    const service = new VerifiedRateNotificationService();
    const changeRes = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'BOB',
      newRate: 7.15,
      type: 'verifiedRateChange',
      tenureDescription: '400 Days',
      effectiveDate: '2026-11-01',
      candidateId: 'cand_bob_400',
    });

    const slabRes = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'BOB',
      newRate: 7.15,
      type: 'newPromotedSlab',
      tenureDescription: '400 Days',
      effectiveDate: '2026-11-01',
      candidateId: 'cand_bob_400',
    });

    assert.strictEqual(changeRes.dispatched, true);
    assert.strictEqual(slabRes.dispatched, true);
    assert.notStrictEqual(changeRes.eventId, slabRes.eventId);
  });

  await runAsyncTest('2.7 Missing candidate ID uses a safe and stable alternative identity (Req 8)', async () => {
    const service = new VerifiedRateNotificationService();
    const slabParams = {
      status: 'VERIFIED',
      bankCode: 'CANARA',
      bankName: 'Canara Bank',
      newRate: 7.25,
      tenureDescription: '444 Days',
      effectiveDate: '2026-11-01',
      // candidateId intentionally omitted
      // promotedRateId intentionally omitted
    };

    const res1 = await service.dispatchVerifiedRateEvent(slabParams);
    assert.strictEqual(res1.dispatched, true);
    assert.ok(res1.eventId.startsWith('evt_'));

    // Re-dispatching the exact same event without candidateId must yield identical eventId and deduplicate
    const res2 = await service.dispatchVerifiedRateEvent(slabParams);
    assert.strictEqual(res2.dispatched, false);
    assert.strictEqual(res2.duplicate, true);
    assert.strictEqual(res2.eventId, res1.eventId);

    // Another distinct slab in the same bank without candidateId must NOT collide
    const otherSlab = await service.dispatchVerifiedRateEvent({
      ...slabParams,
      tenureDescription: '555 Days Special Scheme',
      newRate: 7.3,
    });
    assert.strictEqual(otherSlab.dispatched, true);
    assert.notStrictEqual(otherSlab.eventId, res1.eventId);
  });

  console.log('\nGroup 3: Durable Deduplication, Restarts & Concurrency (Req 2, 3)...');

  await runAsyncTest('3.1 Identical event processed after simulated backend restart remains deduplicated (Req 2)', async () => {
    const sharedStore = new PersistentTestStore();

    // Instance 1 boots, processes event
    const instance1 = new VerifiedRateNotificationService({ persistentStore: sharedStore });
    const params = {
      status: 'VERIFIED',
      bankCode: 'INDUSIND',
      bankName: 'IndusInd Bank',
      newRate: 7.75,
      previousRate: 7.5,
      tenureDescription: '1 Year to 2 Years',
      effectiveDate: '2026-11-01',
      candidateId: 'cand_indus_1y',
    };

    const firstRun = await instance1.dispatchVerifiedRateEvent(params);
    assert.strictEqual(firstRun.dispatched, true);
    assert.strictEqual(sharedStore.events.size, 1);

    // Backend restart simulated: instance2 has fresh in-memory state (empty Set)
    const instance2 = new VerifiedRateNotificationService({ persistentStore: sharedStore });
    assert.strictEqual(instance2.processedEventIds.size, 0); // Proves in-memory cache was cold

    const restartRun = await instance2.dispatchVerifiedRateEvent(params);
    assert.strictEqual(restartRun.dispatched, false);
    assert.strictEqual(restartRun.duplicate, true);
    assert.strictEqual(restartRun.eventId, firstRun.eventId);
    assert.strictEqual(sharedStore.events.size, 1); // No duplicate record created in persistent store
  });

  await runAsyncTest('3.2 Identical event processed concurrently across separate instances does not create duplicates (Req 3)', async () => {
    const sharedStore = new PersistentTestStore();
    const instanceA = new VerifiedRateNotificationService({ persistentStore: sharedStore });
    const instanceB = new VerifiedRateNotificationService({ persistentStore: sharedStore });

    const concurrentParams = {
      status: 'VERIFIED',
      bankCode: 'UNION',
      bankName: 'Union Bank of India',
      newRate: 7.3,
      tenureDescription: '333 Days',
      effectiveDate: '2026-11-01',
      candidateId: 'cand_union_333d',
    };

    // Dispatch concurrently
    const [resultA, resultB] = await Promise.all([
      instanceA.dispatchVerifiedRateEvent(concurrentParams),
      instanceB.dispatchVerifiedRateEvent(concurrentParams),
    ]);

    const dispatchedCount = [resultA, resultB].filter((r) => r.dispatched).length;
    const duplicateCount = [resultA, resultB].filter((r) => r.duplicate).length;

    assert.strictEqual(dispatchedCount, 1, 'Exactly one concurrent request must succeed');
    assert.strictEqual(duplicateCount, 1, 'The competing concurrent request must be marked duplicate');
    assert.strictEqual(resultA.eventId, resultB.eventId);
    assert.strictEqual(sharedStore.events.size, 1, 'Persistent store must hold exactly 1 unique event');
  });

  await runAsyncTest('3.3 Event persistence and deduplication happens before downstream delivery', async () => {
    const sharedStore = new PersistentTestStore();
    let downstreamCalled = false;

    const service = new VerifiedRateNotificationService({
      persistentStore: sharedStore,
    });

    // Mock _sendFcmNotification to track invocation
    service.isFirebaseInitialized = true;
    service.firebaseAdmin = {
      messaging: () => ({
        send: async () => {
          downstreamCalled = true;
          // Verify event is ALREADY stored before delivery finishes
          assert.strictEqual(sharedStore.events.size, 1);
          return 'mock_message_id_999';
        },
      }),
    };

    const res = await service.dispatchVerifiedRateEvent({
      status: 'VERIFIED',
      bankCode: 'UCO',
      bankName: 'UCO Bank',
      newRate: 7.05,
      tenureDescription: '1 Year',
      candidateId: 'cand_uco_1y',
    });

    assert.strictEqual(res.dispatched, true);
    assert.strictEqual(downstreamCalled, true);
    assert.strictEqual(res.fcm.delivered, true);
  });

  await runAsyncTest('3.4 Database-backed persistence and deduplication validates actual database unique constraint when configured', async () => {
    const { isSupabaseAvailable, supabaseAdmin } = require('../supabase/supabase_client');
    if (!isSupabaseAvailable() || !supabaseAdmin) {
      console.log('    (Skipping live DB check: Supabase not configured in offline test run)');
      return;
    }

    const testCandId = 'cand_db_test_' + Date.now();
    const service1 = new VerifiedRateNotificationService({ supabaseClient: supabaseAdmin });
    const service2 = new VerifiedRateNotificationService({ supabaseClient: supabaseAdmin });

    const dbParams = {
      status: 'VERIFIED',
      bankCode: 'SBI',
      bankName: 'State Bank of India',
      newRate: 7.15,
      tenureDescription: '400 Days Special',
      effectiveDate: '2026-11-15',
      candidateId: testCandId,
    };

    try {
      const first = await service1.dispatchVerifiedRateEvent(dbParams);
      assert.strictEqual(first.dispatched, true);
      assert.ok(first.eventId);

      // Second instance with fresh in-memory state attempts identical event
      assert.strictEqual(service2.processedEventIds.has(first.eventId), false);
      const second = await service2.dispatchVerifiedRateEvent(dbParams);
      assert.strictEqual(second.dispatched, false);
      assert.strictEqual(second.duplicate, true);
      assert.strictEqual(second.eventId, first.eventId);
    } finally {
      // Clean up test event from database
      const { eventId } = service1.generateEventIdentity(dbParams);
      await supabaseAdmin.from('rate_pipeline_runs').delete().eq('job_id', 'notif_evt_' + eventId);
    }
  });

  console.log('\nGroup 4: Truthful Delivery & Device Token Registration (Req 10)...');

  await runAsyncTest('4.1 Missing Firebase credentials produce truthful CONFIG_READY_AWAITING_FIREBASE_CREDENTIALS state (Req 10)', async () => {
    // Delete env var if present to test unconfigured state
    const oldKey = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
    delete process.env.FIREBASE_SERVICE_ACCOUNT_KEY;

    try {
      const service = new VerifiedRateNotificationService();
      assert.strictEqual(service.isPushConfigured, false);

      const res = await service.dispatchVerifiedRateEvent({
        status: 'VERIFIED',
        bankCode: 'IDFC',
        bankName: 'IDFC FIRST Bank',
        newRate: 7.5,
        tenureDescription: '1 Year',
      });

      assert.strictEqual(res.dispatched, true);
      assert.strictEqual(res.fcm.delivered, false);
      assert.strictEqual(res.fcm.pushConfigured, false);
      assert.strictEqual(res.fcm.status, 'CONFIG_READY_AWAITING_FIREBASE_CREDENTIALS');
    } finally {
      if (oldKey) process.env.FIREBASE_SERVICE_ACCOUNT_KEY = oldKey;
    }
  });

  runTest('4.2 Registers anonymous consumer device with valid installationId', () => {
    const service = new VerifiedRateNotificationService();
    const reg = service.registerDevice('inst_test_987654', {
      token: 'fcm_mock_token_abc123',
      preferences: {
        masterEnabled: true,
        favoriteBankRateChanges: true,
        productAnnouncements: false,
      },
      favoriteBankIds: ['sbi', 'hdfc'],
    });

    assert.strictEqual(reg.success, true);
    assert.strictEqual(reg.installationId, 'inst_test_987654');

    const stored = service.registeredDevices.get('inst_test_987654');
    assert.ok(stored);
    assert.strictEqual(stored.token, 'fcm_mock_token_abc123');
    assert.deepStrictEqual(stored.favoriteBankIds, ['sbi', 'hdfc']);
    assert.strictEqual(stored.preferences.productAnnouncements, false);
  });

  runTest('4.3 Rejects registration when installationId is missing or empty', () => {
    const service = new VerifiedRateNotificationService();
    assert.throws(() => {
      service.registerDevice('', { token: 'abc' });
    }, /Valid installationId is required/);
  });

  console.log('\nGroup 5: HTTP Endpoint Security & Consumer Access Controls (Req 11, 12)...');

  await runAsyncTest('5.1 Public POST /api/notifications/device-token succeeds without auth token', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      const resp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'inst_http_client_1',
          token: 'token_123',
          preferences: { masterEnabled: true },
          favoriteBankIds: ['sbi'],
        }),
      });

      assert.strictEqual(resp.status, 200);
      const data = await resp.json();
      assert.strictEqual(data.status, 'ok');
      assert.strictEqual(data.data.installationId, 'inst_http_client_1');
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.2 Public GET /api/notifications/events returns sanitized verified notifications without auth (Req 12)', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      const resp = await fetch(`http://127.0.0.1:${port}/api/notifications/events`);
      assert.strictEqual(resp.status, 200);
      const data = await resp.json();
      assert.strictEqual(data.status, 'ok');
      assert.ok(Array.isArray(data.data));
      assert.strictEqual(typeof data.meta.pushConfigured, 'boolean');
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.3 Public event feed strictly redacts internal DB keys, candidate staging internals, and reviewer notes (Req 12)', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      const resp = await fetch(`http://127.0.0.1:${port}/api/notifications/events`);
      assert.strictEqual(resp.status, 200);
      const data = await resp.json();

      for (const item of data.data) {
        assert.strictEqual(item.created_by, undefined);
        assert.strictEqual(item.verified_by, undefined);
        assert.strictEqual(item.review_notes, undefined);
        assert.strictEqual(item.staging_status, undefined);
        assert.strictEqual(item.source_content_hash, undefined);
        assert.strictEqual(item.raw_html, undefined);
      }
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.4 POST /api/notifications/admin/test-dispatch strictly rejects unauthorized requests with 401 (Req 11)', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      const resp = await fetch(`http://127.0.0.1:${port}/api/notifications/admin/test-dispatch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          status: 'VERIFIED',
          bankCode: 'SBI',
          newRate: 7.0,
        }),
      });

      assert.strictEqual(resp.status, 401);
      const data = await resp.json();
      assert.strictEqual(data.status, 'error');
      assert.ok(data.message.includes('Missing authorization token'));
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.5 POST /api/notifications/device-token rejects oversized installationId with 400', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      const resp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'a'.repeat(129),
        }),
      });

      assert.strictEqual(resp.status, 400);
      const data = await resp.json();
      assert.strictEqual(data.status, 'error');
      assert.ok(data.message.includes('must not exceed 128 characters'));
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.6 POST /api/notifications/device-token rejects invalid favoriteBankIds array with 400', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      // Test non-array
      const resp1 = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'valid_id_1',
          favoriteBankIds: 'not_an_array',
        }),
      });
      assert.strictEqual(resp1.status, 400);

      // Test oversized array
      const oversized = Array.from({ length: 51 }, (_, i) => `bank_${i}`);
      const resp2 = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'valid_id_2',
          favoriteBankIds: oversized,
        }),
      });
      assert.strictEqual(resp2.status, 400);
      const data2 = await resp2.json();
      assert.ok(data2.message.includes('exceeds maximum length of 50'));
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.7 POST /api/notifications/device-token rejects unrecognized preference keys and non-boolean values with 400', async () => {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);

    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    const port = server.address().port;

    try {
      // Unrecognized key
      const resp1 = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'valid_id_3',
          preferences: { unauthorizedAdminRole: true },
        }),
      });
      assert.strictEqual(resp1.status, 400);
      const data1 = await resp1.json();
      assert.ok(data1.message.includes('Unrecognized preference key'));

      // Non-boolean value
      const resp2 = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'valid_id_4',
          preferences: { masterEnabled: 'yes_please' },
        }),
      });
      assert.strictEqual(resp2.status, 400);
      const data2 = await resp2.json();
      assert.ok(data2.message.includes('must be a boolean'));
    } finally {
      server.close();
    }
  });

  async function createTestHttpServer() {
    const app = express();
    app.use(express.json());
    app.use('/api/notifications', notificationsRouter);
    const server = http.createServer(app);
    await new Promise((res) => server.listen(0, res));
    return { server, port: server.address().port };
  }

  await runAsyncTest('5.8 DELETE /api/notifications/device-token with valid installationToken deletes registration successfully', async () => {
    const { server, port } = await createTestHttpServer();
    try {
      // 1. Register with installationToken
      const regResp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'inst_del_test_1',
          installationToken: 'secret_token_123',
          token: 'fcm_token_xyz',
          favoriteBankIds: ['sbi', 'hdfc'],
        }),
      });
      assert.strictEqual(regResp.status, 200);

      // Verify device is registered
      const deviceBefore = verifiedRateNotificationService.getDevice('inst_del_test_1');
      assert.ok(deviceBefore);
      assert.strictEqual(deviceBefore.hasToken, true);
      assert.strictEqual(deviceBefore.hasTokenAuth, true);

      // 2. Delete with matching installationToken
      const delResp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'x-installation-token': 'secret_token_123',
        },
        body: JSON.stringify({
          installationId: 'inst_del_test_1',
        }),
      });
      assert.strictEqual(delResp.status, 200);
      const delData = await delResp.json();
      assert.strictEqual(delData.status, 'ok');
      assert.strictEqual(delData.data.deleted, true);

      // Verify device record is completely removed
      const deviceAfter = verifiedRateNotificationService.getDevice('inst_del_test_1');
      assert.strictEqual(deviceAfter, null);
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.9 DELETE /api/notifications/device-token rejects invalid or missing token with 403 Forbidden', async () => {
    const { server, port } = await createTestHttpServer();
    try {
      // 1. Register with installationToken
      await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'inst_del_test_2',
          installationToken: 'owner_secret_456',
          token: 'token_abc',
        }),
      });

      // 2. Attempt deletion with wrong token
      const wrongResp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'x-installation-token': 'wrong_secret',
        },
        body: JSON.stringify({
          installationId: 'inst_del_test_2',
        }),
      });
      assert.strictEqual(wrongResp.status, 403);
      const wrongData = await wrongResp.json();
      assert.ok(wrongData.message.includes('Invalid installation authorization token'));

      // 3. Attempt deletion with missing token
      const missingResp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'inst_del_test_2',
        }),
      });
      assert.strictEqual(missingResp.status, 403);

      // Verify device was NOT deleted
      const deviceStillExists = verifiedRateNotificationService.getDevice('inst_del_test_2');
      assert.ok(deviceStillExists);
      assert.strictEqual(deviceStillExists.installationId, 'inst_del_test_2');
    } finally {
      server.close();
    }
  });

  await runAsyncTest('5.10 DELETE /api/notifications/device-token strictly preserves global verified rate events', async () => {
    const { server, port } = await createTestHttpServer();
    try {
      // Dispatch a verified rate event
      await verifiedRateNotificationService.dispatchVerifiedRateEvent({
        status: 'VERIFIED',
        bankCode: 'SBI',
        bankName: 'State Bank of India',
        bankId: 'sbi',
        newRate: 7.10,
        previousRate: 6.80,
        tenureDescription: '1 Year to less than 2 Years',
        effectiveDate: '2026-11-13',
        candidateId: 'cand_preserve_test_1',
      });

      // Register device
      await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          installationId: 'inst_preserve_test',
          installationToken: 'preserve_token',
        }),
      });

      // Verify events exist before deletion
      const eventsBefore = await verifiedRateNotificationService.getRecentEvents(10);
      assert.ok(eventsBefore.length > 0);
      const initialCount = eventsBefore.length;

      // Delete device
      const delResp = await fetch(`http://127.0.0.1:${port}/api/notifications/device-token`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'x-installation-token': 'preserve_token',
        },
        body: JSON.stringify({
          installationId: 'inst_preserve_test',
        }),
      });
      assert.strictEqual(delResp.status, 200);

      // Verify events still exist untouched
      const eventsAfter = await verifiedRateNotificationService.getRecentEvents(10);
      assert.strictEqual(eventsAfter.length, initialCount);
    } finally {
      server.close();
    }
  });

  console.log('\n======================================================');
  console.log(`Results: ${passedTests} passed, ${totalTests - passedTests} failed (Total: ${totalTests})`);
  console.log('======================================================');

  if (passedTests !== totalTests) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Unhandled test failure:', err);
  process.exit(1);
});
