'use strict';

const assert = require('assert');
const { main } = require('../scripts/run_baseline_attestation');
const { RateCollectionService } = require('../collectors/collection_service');

const noopLogger = {
  log() {},
  warn() {},
  error() {},
};

async function testLegacyDryRunFailsBeforeAnySideEffect() {
  let loaderCalls = 0;
  let collectionCalls = 0;
  const result = await main({
    args: ['--dry-run'],
    logger: noopLogger,
    loadEnvironment: () => { loaderCalls++; },
    sources: [{ id: 'sbi-retail-domestic', bankCode: 'SBI', sourceUrl: 'https://sbi.co.in' }],
    collectionService: { collectSource: async () => { collectionCalls++; throw new Error('must not fetch'); } },
  });
  assert.strictEqual(result.exitCode, 2);
  assert.strictEqual(loaderCalls, 0, 'invalid mode must fail before environment loading');
  assert.strictEqual(collectionCalls, 0, 'invalid mode must fail before source collection');
}

async function testMissingExplicitReadOnlyFlagFailsClosed() {
  let loaderCalls = 0;
  const result = await main({
    args: [],
    logger: noopLogger,
    loadEnvironment: () => { loaderCalls++; },
  });
  assert.strictEqual(result.exitCode, 2);
  assert.strictEqual(loaderCalls, 0, 'missing mode must fail before loading environment');
}

async function testInspectionDoesNotCreateOrPromoteAttestations() {
  let loaderCalls = 0;
  let collectionCalls = 0;
  let stagingCalls = 0;
  const source = {
    id: 'sbi-retail-domestic',
    bankCode: 'SBI',
    sourceUrl: 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
  };
  const collectionService = {
    async collectSource(_src, options) {
      collectionCalls++;
      assert.strictEqual(options.readOnly, true);
      assert.strictEqual(options.previousHash, null);
      return {
        sourceId: source.id,
        bankCode: source.bankCode,
        sourceUrl: source.sourceUrl,
        status: 'CHANGED',
        httpStatus: 200,
        contentHash: 'a'.repeat(64),
        bodyBuffer: Buffer.from('fixture-html'),
        fetchedAt: '2026-10-27T00:00:00.000Z',
      };
    },
  };
  const stagingService = {
    async processCollectionResult(_collection, options) {
      stagingCalls++;
      assert.strictEqual(options.skipDbPersist, true);
      assert.strictEqual(options.skipDbAccess, true);
      assert.deepStrictEqual(options.baselineRates, []);
      return {
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        parserId: 'sbi_retail_html',
        parserVersion: '1.0.0',
        effectiveFrom: '2025-12-15',
        candidates: [{ validationStatus: 'VALID', anomalyFlags: [] }],
        validation: { validCount: 1, invalidCount: 0, errors: [] },
        anomalies: { candidatesWithAnomalies: 0, anomalyFlags: [] },
      };
    },
  };
  const forbidden = async () => { throw new Error('mutating attestation method must never be called'); };
  const attestationService = {
    generateBatchId: () => 'baseline_sbi_test',
    evaluateAttestationEligibility: () => ({ eligible: true, issues: [] }),
    createBaselineBatch: forbidden,
    getAttestationByBatchId: forbidden,
    attestBaseline: forbidden,
    promoteBaseline: forbidden,
  };

  const result = await main({
    args: ['--inspect-read-only'],
    logger: noopLogger,
    loadEnvironment: () => { loaderCalls++; },
    sources: [source],
    collectionService,
    stagingService,
    attestationService,
    isOfficialBankDomain: () => true,
  });

  assert.strictEqual(loaderCalls, 1);
  assert.strictEqual(collectionCalls, 1);
  assert.strictEqual(stagingCalls, 1);
  assert.strictEqual(result.exitCode, 0);
  assert.strictEqual(result.reports.length, 1);
  assert.strictEqual(result.reports[0].databaseAccess, 'NONE');
  assert.strictEqual(result.reports[0].attestationWritten, false);
  assert.strictEqual(result.reports[0].promotionPerformed, false);
  assert.strictEqual(result.reports[0].structuralEligibility, true);
}

async function testCollectionServiceReadOnlyDoesNotTouchPersistence() {
  const expectedHash = 'b'.repeat(64);
  const collectionService = new RateCollectionService({
    collectorFactory: () => ({
      id: 'sbi-retail-domestic',
      bankCode: 'SBI',
      sourceUrl: 'https://sbi.co.in',
      async collect(options) {
        assert.strictEqual(options.previousHash, null);
        return {
          sourceId: 'sbi-retail-domestic',
          bankCode: 'SBI',
          sourceUrl: 'https://sbi.co.in',
          status: 'CHANGED',
          contentHash: expectedHash,
          bodyBuffer: Buffer.from('fixture'),
          contentType: 'text/html',
          httpStatus: 200,
          fetchedAt: '2026-10-27T00:00:00.000Z',
          fetchDurationMs: 1,
          byteLength: 7,
        };
      },
    }),
    storage: {
      async saveSnapshot() {
        throw new Error('snapshot persistence must not run in read-only mode');
      },
    },
    logger: noopLogger,
  });
  collectionService._getPreviousHash = async () => {
    throw new Error('prior-hash database read must not run in read-only mode');
  };
  collectionService._persistResult = async () => {
    throw new Error('telemetry persistence must not run in read-only mode');
  };

  const result = await collectionService.collectSource(
    { id: 'sbi-retail-domestic', bankCode: 'SBI', sourceUrl: 'https://sbi.co.in' },
    { readOnly: true, previousHash: null },
  );
  assert.strictEqual(result.contentHash, expectedHash);
}

async function run() {
  const tests = [
    ['legacy --dry-run refuses before environment loading/source fetch', testLegacyDryRunFailsBeforeAnySideEffect],
    ['missing explicit read-only flag fails closed', testMissingExplicitReadOnlyFlagFailsClosed],
    ['inspection avoids attestation creation and promotion', testInspectionDoesNotCreateOrPromoteAttestations],
    ['collection read-only mode skips database and snapshot persistence', testCollectionServiceReadOnlyDoesNotTouchPersistence],
  ];
  let failed = 0;
  for (const [name, fn] of tests) {
    try {
      await fn();
      console.log('PASS: ' + name);
    } catch (error) {
      failed++;
      console.error('FAIL: ' + name + ': ' + error.stack);
    }
  }
  console.log('\nBaseline CLI read-only safety: ' + (tests.length - failed) + '/' + tests.length + ' passed');
  if (failed) process.exitCode = 1;
}

run().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
