// FeroCalc Verified FD Rate Engine — Source Provenance Linkage & Deduplication Tests
//
// Verifies:
// 1. BaseCollector and collectors expose parserId consistently on collection results.
// 2. CollectionService persists real parserId and propagates persistence errors.
// 3. CandidateStagingService refuses staging when source_collection_logs record is missing.
// 4. CandidateStagingService deduplicates candidates on identical content hash and bank code.

'use strict';

const assert = require('assert');
const { BaseCollector } = require('../collectors/base_collector');
const { HdfcCollector } = require('../collectors/pilot_collectors');
const { RateCollectionService } = require('../collectors/collection_service');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { BaselineAttestationService } = require('../attestation/baseline_attestation_service');

let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

async function runTestSuite() {
  console.log('================================================================');
  console.log('FeroCalc Source Provenance Linkage & Deduplication Test Suite   ');
  console.log('================================================================\n');

  console.log('Group 1: Collector Parser ID Consistency...');

  await test('1. BaseCollector exposes parserId getter from config', async () => {
    const collector = new BaseCollector({
      id: 'test-src',
      bankCode: 'TEST',
      sourceUrl: 'https://test.bank.in',
      parserId: 'test_parser_v1',
    });
    assert.strictEqual(collector.parserId, 'test_parser_v1');
  });

  await test('2. Collector collect() includes parserId in success and error payloads', async () => {
    const collector = new BaseCollector({
      id: 'test-src',
      bankCode: 'TEST',
      sourceUrl: 'https://test.bank.in',
      parserId: 'test_parser_v1',
    });

    // Success payload
    const successResult = await collector.collect({
      fetchFunc: async () => ({
        url: 'https://test.bank.in',
        statusCode: 200,
        contentType: 'text/html',
        bodyBuffer: Buffer.from('hello'),
        byteLength: 5,
      }),
    });
    assert.strictEqual(successResult.parserId, 'test_parser_v1');

    // Error payload
    const errorResult = await collector.collect({
      fetchFunc: async () => {
        throw new Error('Network timeout');
      },
    });
    assert.strictEqual(errorResult.parserId, 'test_parser_v1');
    assert.strictEqual(errorResult.status, 'FETCH_FAILED');
  });

  await test('3. HdfcCollector exposes parserId hdfc_retail_html', async () => {
    const hdfc = new HdfcCollector();
    assert.strictEqual(hdfc.parserId, 'hdfc_retail_html');
  });

  console.log('\nGroup 2: Collection Service Persistence & Error Propagation...');

  await test('4. RateCollectionService._persistResult throws if rate_sources upsert fails', async () => {
    const mockDb = {
      from(table) {
        if (table === 'rate_sources') {
          return {
            upsert: async () => ({ error: { message: 'Database connection refused' } }),
          };
        }
        return {};
      },
    };

    const service = new RateCollectionService({
      storage: { saveSnapshot: async () => {} },
      logger: { log: () => {}, error: () => {} },
      supabaseAdmin: mockDb,
    });

    const fakeResult = {
      sourceId: 'hdfc-retail-domestic',
      bankCode: 'HDFC',
      sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
      sourceType: 'HTML',
      parserId: 'hdfc_retail_html',
      parserVersion: '1.0.0',
      fetchedAt: new Date().toISOString(),
      httpStatus: 200,
      contentType: 'text/html',
      contentHash: 'a'.repeat(64),
      status: 'CHANGED',
      changed: true,
      fetchDurationMs: 120,
      byteLength: 1000,
      error: null,
    };

    let threw = false;
    try {
      await service._persistResult(fakeResult);
    } catch (err) {
      threw = true;
      assert(err.message.includes('Failed to persist rate_source'));
    }
    assert(threw, 'Expected _persistResult to throw on database failure');
  });

  console.log('\nGroup 3: Candidate Provenance Linkage & Fail-Closed Protection...');

  await test('5. CandidateStagingService refuses staging if source_collection_logs has no matching hash', async () => {
    const mockDb = {
      from(table) {
        if (table === 'source_collection_logs') {
          return {
            select() {
              return {
                eq() {
                  return {
                    eq() {
                      return {
                        limit: async () => ({ data: [], error: null }), // Empty: no log found
                      };
                    },
                  };
                },
              };
            },
          };
        }
        return {
          select: () => ({ eq: () => ({ eq: () => ({ limit: async () => ({ data: [] }) }) }) }),
        };
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { error: () => {}, warn: () => {}, info: () => {} },
      parserFactory: () => ({
        id: 'mock_parser',
        version: '1.0.0',
        parse: () => ({
          success: true,
          candidates: [
            {
              bankId: 'HDFC',
              bankCode: 'HDFC',
              sourceId: 'hdfc-retail-domestic',
              productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
              customerType: 'REGULAR',
              tenureUnit: 'DAYS',
              minTenureDays: 7,
              maxTenureDays: 14,
              tenureLabel: '7 - 14 days',
              interestRate: 2.75,
              seniorCitizenRate: 3.25,
              isCallable: true,
              effectiveFrom: '2026-08-19',
              sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
              sourceContentHash: 'f'.repeat(64),
              extractedAt: new Date().toISOString(),
              parserId: 'mock_parser',
              parserVersion: '1.0.0',
              validationErrors: [],
              anomalyFlags: [],
              validationStatus: 'VALID',
              stagingStatus: 'DRAFT',
              tenureDomain: 'DAYS',
            },
          ],
        }),
      }),
    });

    let threw = false;
    try {
      await service.processCollectionResult({
        sourceId: 'hdfc-retail-domestic',
        bankCode: 'HDFC',
        status: 'CHANGED',
        contentHash: 'f'.repeat(64),
        sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
        bodyBuffer: Buffer.from('mock'),
      });
    } catch (err) {
      threw = true;
      assert(err.message.includes('Provenance assertion failed'), `Unexpected error message: ${err.message}`);
    }
    assert(threw, 'Expected processCollectionResult to fail closed without provenance log');
  });

  console.log('\nGroup 4: Candidate Deduplication on Re-Extraction...');

  await test('6. _persistCandidates reuses existing rows when (source_content_hash, bank_code) match', async () => {
    const existingStagedRows = [
      {
        id: 'existing-uuid-1',
        bank_code: 'HDFC',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: 2.75,
        is_callable: true,
        source_content_hash: 'hash-abc',
        staging_status: 'DRAFT',
        tenure_label: '7 - 14 days',
        tenure_domain: 'DAYS',
        rate_category: 'STANDARD',
        scheme_name: null,
      },
      {
        id: 'existing-uuid-2',
        bank_code: 'HDFC',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'SENIOR_CITIZEN',
        min_tenure_days: 7,
        max_tenure_days: 14,
        interest_rate: 3.25,
        is_callable: true,
        source_content_hash: 'hash-abc',
        staging_status: 'DRAFT',
        tenure_label: '7 - 14 days',
        tenure_domain: 'DAYS',
        rate_category: 'STANDARD',
        scheme_name: null,
      },
    ];

    let insertedRecords = [];

    const mockDb = {
      from(table) {
        if (table === 'staged_rate_candidates') {
          return {
            select() {
              return {
                in() {
                  return {
                    in: async () => ({ data: existingStagedRows, error: null }),
                  };
                },
              };
            },
            insert(recs) {
              insertedRecords.push(...recs);
              return {
                select: async () => ({
                  data: recs.map((r, i) => ({ id: `new-uuid-${i}`, ...r })),
                  error: null,
                }),
              };
            },
          };
        }
        return {};
      },
    };

    const service = new CandidateStagingService({
      supabaseClient: mockDb,
      logger: { error: () => {}, warn: () => {}, info: () => {} },
    });

    const candidates = [
      {
        sourceId: 'hdfc-retail-domestic',
        bankCode: 'HDFC',
        customerType: 'REGULAR',
        tenureLabel: '7 - 14 days',
        tenureDomain: 'DAYS',
        minTenureDays: 7,
        maxTenureDays: 14,
        interestRate: 2.75,
        sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
        sourceContentHash: 'hash-abc',
        extractedAt: new Date().toISOString(),
        parserId: 'hdfc_retail_html',
        parserVersion: '1.0.0',
      },
      {
        sourceId: 'hdfc-retail-domestic',
        bankCode: 'HDFC',
        customerType: 'SENIOR_CITIZEN',
        tenureLabel: '7 - 14 days',
        tenureDomain: 'DAYS',
        minTenureDays: 7,
        maxTenureDays: 14,
        interestRate: 3.25,
        sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
        sourceContentHash: 'hash-abc',
        extractedAt: new Date().toISOString(),
        parserId: 'hdfc_retail_html',
        parserVersion: '1.0.0',
      },
    ];

    const result = await service._persistCandidates(candidates, { requireLock: false });

    // Assert that zero new rows were inserted to DB
    assert.strictEqual(insertedRecords.length, 0, 'No rows should be inserted for existing candidates');
    assert.strictEqual(result.reusedCount, 2, 'Both rows should be identified as reused');
    assert.strictEqual(result.persistedCount, 2, 'Total active persisted rows returned should be 2');

    // Assert that candidates in-memory received the existing DB IDs
    assert.strictEqual(candidates[0].id, 'existing-uuid-1');
    assert.strictEqual(candidates[1].id, 'existing-uuid-2');
  });

  console.log('\nGroup 5: Baseline Attestation Provenance Linkage Verification...');

  await test('7. BaselineAttestationService.attestBaseline fails closed if source_collection_logs has no matching hash', async () => {
    const mockAttestation = {
      id: 'attestation-uuid-1',
      batchId: 'baseline_hdfc_test_123',
      bankCode: 'HDFC',
      sourceId: 'hdfc-retail-domestic',
      sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
      sourceContentHash: 'a'.repeat(64),
      parserId: 'hdfc_retail_html',
      parserVersion: '1.0.0',
      candidateCount: 1,
      validCandidateCount: 1,
      invalidCandidateCount: 0,
      anomalousCandidateCount: 0,
      attestationStatus: 'PENDING',
    };

    const mockDb = {
      from(table) {
        if (table === 'source_collection_logs') {
          return {
            select() {
              return {
                eq() {
                  return {
                    eq() {
                      return {
                        limit: async () => ({ data: [], error: null }), // Empty: no matching log found
                      };
                    },
                  };
                },
              };
            },
          };
        }
        return {};
      },
    };

    const service = new BaselineAttestationService({
      supabaseAdmin: mockDb,
      skipDbPersist: false,
    });
    service._inMemoryAttestations.set('attestation-uuid-1', mockAttestation);

    let threw = false;
    try {
      await service.attestBaseline({
        attestationId: 'attestation-uuid-1',
        adminUserId: '550e8400-e29b-41d4-a716-446655440000',
        notes: 'Test attestation',
      });
    } catch (err) {
      threw = true;
      assert(err.message.includes('Provenance assertion failed'), `Unexpected error message: ${err.message}`);
    }
    assert(threw, 'Expected attestBaseline to fail closed when source_collection_logs record is missing');
  });

  await test('8. BaselineAttestationService.attestBaseline succeeds when source_collection_logs has matching hash', async () => {
    const mockAttestation = {
      id: 'attestation-uuid-2',
      batchId: 'baseline_hdfc_test_456',
      bankCode: 'HDFC',
      sourceId: 'hdfc-retail-domestic',
      sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
      sourceContentHash: 'b'.repeat(64),
      parserId: 'hdfc_retail_html',
      parserVersion: '1.0.0',
      candidateCount: 1,
      validCandidateCount: 1,
      invalidCandidateCount: 0,
      anomalousCandidateCount: 0,
      attestationStatus: 'PENDING',
    };

    let updatedDbRecord = null;
    const mockDb = {
      from(table) {
        if (table === 'source_collection_logs') {
          return {
            select() {
              return {
                eq() {
                  return {
                    eq() {
                      return {
                        limit: async () => ({ data: [{ id: 'log-uuid-valid' }], error: null }),
                      };
                    },
                  };
                },
              };
            },
          };
        }
        if (table === 'baseline_source_attestations') {
          return {
            update(payload) {
              updatedDbRecord = payload;
              return {
                eq: async () => ({ data: [payload], error: null }),
              };
            },
          };
        }
        return {};
      },
    };

    const service = new BaselineAttestationService({
      supabaseAdmin: mockDb,
      skipDbPersist: false,
    });
    service._inMemoryAttestations.set('attestation-uuid-2', mockAttestation);

    const result = await service.attestBaseline({
      attestationId: 'attestation-uuid-2',
      adminUserId: '550e8400-e29b-41d4-a716-446655440000',
      notes: 'Test attestation valid',
    });

    assert.strictEqual(result.attestationStatus, 'ATTESTED');
    assert.strictEqual(result.attestedBy, '550e8400-e29b-41d4-a716-446655440000');
    assert.ok(updatedDbRecord, 'DB record should be updated');
    assert.strictEqual(updatedDbRecord.attestation_status, 'ATTESTED');
  });

  console.log('\n================================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTestSuite().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
