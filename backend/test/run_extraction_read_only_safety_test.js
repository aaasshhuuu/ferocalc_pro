'use strict';

const assert = require('assert');
const { runLiveExtraction } = require('../scripts/run_extraction');
const { RateCollectionService } = require('../collectors/collection_service');
const { CandidateStagingService } = require('../staging/candidate_staging_service');

const noopLogger = {
  log() {},
  warn() {},
  error() {},
};

let totalTests = 0;
let passedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    passedTests++;
    console.log(`  ✓ ${name}`);
  } catch (err) {
    console.error(`  ✗ ${name}`);
    throw err;
  }
}

async function runTestAsync(name, fn) {
  totalTests++;
  try {
    await fn();
    passedTests++;
    console.log(`  ✓ ${name}`);
  } catch (err) {
    console.error(`  ✗ ${name}`);
    throw err;
  }
}

async function runAllTests() {
  console.log('\n======================================================');
  console.log('FeroCalc Run Extraction Read-Only Safety Regression');
  console.log('======================================================\n');

  // Test 1: Verify runner passes readOnly: true, skipDbAccess: true, skipDbPersist: true, forceReExtract: true
  await runTestAsync('1. Runner passes readOnly: true to collectionService and skipDbAccess, skipDbPersist, forceReExtract to candidateStagingService', async () => {
    const collectedOptions = [];
    const stagingOptions = [];

    const mockSources = [
      { id: 'mock-sbi', bankCode: 'SBI', sourceUrl: 'https://sbi.co.in/rates' },
      { id: 'mock-hdfc', bankCode: 'HDFC', sourceUrl: 'https://hdfcbank.com/rates' },
    ];

    const mockCollectionService = {
      async collectSource(src, options) {
        collectedOptions.push({ src, options });
        return {
          sourceId: src.id,
          bankCode: src.bankCode,
          sourceUrl: src.sourceUrl,
          httpStatus: 200,
          status: 'CHANGED',
          contentHash: 'a'.repeat(64),
          bodyBuffer: Buffer.from('mock body'),
        };
      },
    };

    const mockStagingService = {
      async processCollectionResult(collectionResult, options) {
        stagingOptions.push({ collectionResult, options });
        return {
          sourceId: collectionResult.sourceId,
          extracted: true,
          status: 'EXTRACTION_SUCCESS',
          totalCandidates: 5,
          validCount: 5,
          invalidCount: 0,
          anomalousCount: 0,
          effectiveFrom: '2026-10-27',
          candidates: [{ customerType: 'REGULAR', tenureLabel: '1 Year', interestRate: 7.0, isCallable: true, stagingStatus: 'IN_REVIEW' }],
          validation: { errors: [] },
        };
      },
    };

    const results = await runLiveExtraction({
      sources: mockSources,
      collectionService: mockCollectionService,
      stagingService: mockStagingService,
      logger: noopLogger,
      skipEnvLoad: true,
    });

    assert.strictEqual(results.length, 2, 'Both sources processed');
    assert.strictEqual(collectedOptions.length, 2, 'collectSource called twice');
    assert.strictEqual(stagingOptions.length, 2, 'processCollectionResult called twice');

    for (let i = 0; i < 2; i++) {
      // Collection options assertions
      assert.strictEqual(collectedOptions[i].options.readOnly, true, 'readOnly must be explicitly true for collectionService');
      assert.strictEqual(collectedOptions[i].options.timeoutMs, 15000, 'timeoutMs should be 15000');
      assert.strictEqual(collectedOptions[i].options.maxRetries, 2, 'maxRetries should be 2');

      // Staging options assertions
      assert.strictEqual(stagingOptions[i].options.skipDbAccess, true, 'skipDbAccess must be explicitly true for stagingService');
      assert.strictEqual(stagingOptions[i].options.skipDbPersist, true, 'skipDbPersist must be explicitly true for stagingService');
      assert.strictEqual(stagingOptions[i].options.forceReExtract, true, 'forceReExtract must be preserved as true');
    }
  });

  // Test 2: Source collection failure isolation (does not stop remaining sources)
  await runTestAsync('2. Single source collection failure does not abort remaining sources', async () => {
    const mockSources = [
      { id: 'src-1', bankCode: 'SBI', sourceUrl: 'https://sbi.co.in' },
      { id: 'src-failed', bankCode: 'FAIL', sourceUrl: 'https://badurl.test' },
      { id: 'src-3', bankCode: 'ICICI', sourceUrl: 'https://icicibank.com' },
    ];

    const mockCollectionService = {
      async collectSource(src, options) {
        if (src.bankCode === 'FAIL') {
          throw new Error('Connection timed out');
        }
        return {
          sourceId: src.id,
          bankCode: src.bankCode,
          sourceUrl: src.sourceUrl,
          httpStatus: 200,
          status: 'UNCHANGED',
          contentHash: 'b'.repeat(64),
          bodyBuffer: Buffer.from('mock body'),
        };
      },
    };

    const processedStaging = [];
    const mockStagingService = {
      async processCollectionResult(collectionResult) {
        processedStaging.push(collectionResult.bankCode);
        return {
          sourceId: collectionResult.sourceId,
          extracted: true,
          status: 'EXTRACTION_SUCCESS',
          totalCandidates: 2,
          validCount: 2,
          invalidCount: 0,
          anomalousCount: 0,
        };
      },
    };

    const results = await runLiveExtraction({
      sources: mockSources,
      collectionService: mockCollectionService,
      stagingService: mockStagingService,
      logger: noopLogger,
      skipEnvLoad: true,
    });

    assert.strictEqual(results.length, 3, 'All 3 sources returned a result record');
    assert.strictEqual(results[0].bankCode, 'SBI');
    assert.strictEqual(results[0].parsingSuccessful, true);

    assert.strictEqual(results[1].bankCode, 'FAIL');
    assert.strictEqual(results[1].parsingSuccessful, false);
    assert.strictEqual(results[1].error, 'Connection timed out');

    assert.strictEqual(results[2].bankCode, 'ICICI');
    assert.strictEqual(results[2].parsingSuccessful, true);

    assert.deepStrictEqual(processedStaging, ['SBI', 'ICICI'], 'Staging only called for successful collections');
  });

  // Test 3: Staging processing failure isolation (does not abort remaining sources)
  await runTestAsync('3. Single source staging processing failure does not abort remaining sources', async () => {
    const mockSources = [
      { id: 'src-stage-err', bankCode: 'ERR_STAGE', sourceUrl: 'https://bank1.test' },
      { id: 'src-stage-ok', bankCode: 'OK_STAGE', sourceUrl: 'https://bank2.test' },
    ];

    const mockCollectionService = {
      async collectSource(src) {
        return {
          sourceId: src.id,
          bankCode: src.bankCode,
          sourceUrl: src.sourceUrl,
          httpStatus: 200,
          status: 'CHANGED',
          contentHash: 'c'.repeat(64),
          bodyBuffer: Buffer.from('mock body'),
        };
      },
    };

    const mockStagingService = {
      async processCollectionResult(collectionResult) {
        if (collectionResult.bankCode === 'ERR_STAGE') {
          throw new Error('Malformed DOM in parser');
        }
        return {
          sourceId: collectionResult.sourceId,
          extracted: true,
          status: 'EXTRACTION_SUCCESS',
          totalCandidates: 3,
          validCount: 3,
          invalidCount: 0,
          anomalousCount: 0,
        };
      },
    };

    const results = await runLiveExtraction({
      sources: mockSources,
      collectionService: mockCollectionService,
      stagingService: mockStagingService,
      logger: noopLogger,
      skipEnvLoad: true,
    });

    assert.strictEqual(results.length, 2);
    assert.strictEqual(results[0].bankCode, 'ERR_STAGE');
    assert.strictEqual(results[0].parsingSuccessful, false);
    assert.strictEqual(results[0].error, 'Malformed DOM in parser');

    assert.strictEqual(results[1].bankCode, 'OK_STAGE');
    assert.strictEqual(results[1].parsingSuccessful, true);
  });

  // Test 4: RateCollectionService with readOnly: true guarantees 0 DB reads/writes and 0 snapshot saves
  await runTestAsync('4. Underlying RateCollectionService with readOnly: true suppresses previous-hash DB lookup, snapshot storage, and result persistence', async () => {
    let dbQueryAttempted = false;
    let snapshotSaveAttempted = false;
    let persistResultAttempted = false;

    const mockStorage = {
      async saveSnapshot() {
        snapshotSaveAttempted = true;
        throw new Error('saveSnapshot must NOT be called in readOnly mode');
      },
      async getSnapshotMetadata() { return null; },
    };

    const service = new RateCollectionService({
      storage: mockStorage,
      logger: noopLogger,
    });

    service._getPreviousHash = async () => {
      dbQueryAttempted = true;
      throw new Error('_getPreviousHash must NOT be called in readOnly mode');
    };

    service._persistResult = async () => {
      persistResultAttempted = true;
      throw new Error('_persistResult must NOT be called in readOnly mode');
    };

    const mockSource = {
      id: 'test-src',
      bankCode: 'TEST',
      sourceUrl: 'https://testbank.com/rates',
    };

    const mockFetch = async () => ({
      statusCode: 200,
      contentType: 'text/html',
      headers: {},
      bodyBuffer: Buffer.from('<html><body><table><tr><td>1 Year</td><td>7.00%</td></tr></table></body></html>'),
      byteLength: 50,
      attemptsMade: 1,
    });

    const result = await service.collectSource(mockSource, {
      readOnly: true,
      fetchFunc: mockFetch,
    });

    assert.strictEqual(result.httpStatus, 200);
    assert.strictEqual(result.status, 'FIRST_SEEN');
    assert.strictEqual(dbQueryAttempted, false, 'No database lookup for previous hash');
    assert.strictEqual(snapshotSaveAttempted, false, 'No snapshot saved to storage');
    assert.strictEqual(persistResultAttempted, false, 'No result persisted to collection log');
  });

  // Test 5: CandidateStagingService with skipDbAccess: true and skipDbPersist: true guarantees 0 DB calls
  await runTestAsync('5. Underlying CandidateStagingService with skipDbAccess: true and skipDbPersist: true suppresses baseline queries and candidate persistence', async () => {
    let baselineQueryAttempted = false;
    let candidatePersistAttempted = false;

    const staging = new CandidateStagingService({ skipDbPersist: true });

    staging._fetchBaselineRates = async () => {
      baselineQueryAttempted = true;
      throw new Error('_fetchBaselineRates must NOT be called when skipDbAccess is true');
    };

    staging._persistCandidates = async () => {
      candidatePersistAttempted = true;
      throw new Error('_persistCandidates must NOT be called when skipDbPersist is true');
    };

    const SBI_HTML = `
      <html><body><table>
        <tr>
          <th>Tenors</th>
          <th>Existing Rates for Public w.e.f. 15/07/2025</th>
          <th>Revised Rates for Public w.e.f. 15/12/2025</th>
          <th>Existing Rates for Senior Citizen w.e.f. 15/07/2025</th>
          <th>Revised Rates for Senior Citizen w.e.f. 15/12/2025</th>
        </tr>
        <tr>
          <td>1 year to less than 2 years</td>
          <td>6.80</td>
          <td>6.80</td>
          <td>7.30</td>
          <td>7.30</td>
        </tr>
      </table></body></html>
    `;

    const collectionResult = {
      sourceId: 'sbi-retail-domestic',
      bankCode: 'SBI',
      status: 'CHANGED',
      contentHash: 'd'.repeat(64),
      sourceUrl: 'https://sbi.co.in',
      bodyBuffer: Buffer.from(SBI_HTML),
    };

    const stageResult = await stagingServiceProcess(staging, collectionResult);

    assert.strictEqual(stageResult.extracted, true);
    assert.strictEqual(stageResult.status, 'EXTRACTION_SUCCESS');
    assert.strictEqual(baselineQueryAttempted, false, 'Baseline database query was skipped');
    assert.strictEqual(candidatePersistAttempted, false, 'Candidate persistence was skipped');
  });

  // Test 6: Default export signature and optional dependency injection
  runTest('6. runLiveExtraction is an async function accepting optional dependencies', () => {
    assert.strictEqual(typeof runLiveExtraction, 'function');
    assert.strictEqual(runLiveExtraction.constructor.name, 'AsyncFunction');
  });

  console.log('\n======================================================');
  console.log(`Results: ${passedTests}/${totalTests} passed, 0 failed (Total: ${totalTests})`);
  console.log('======================================================\n');
}

async function stagingServiceProcess(staging, collectionResult) {
  return await staging.processCollectionResult(collectionResult, {
    forceReExtract: true,
    skipDbAccess: true,
    skipDbPersist: true,
  });
}

runAllTests().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
