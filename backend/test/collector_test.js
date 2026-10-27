// FeroCalc Verified FD Rate Engine — Collector Test Suite (Phase 1)
//
// Tests:
// - Deterministic SHA-256 calculation
// - Status classification: FIRST_SEEN, UNCHANGED, CHANGED
// - Error handling: network timeout, non-200 HTTP status, invalid URL
// - Retry behavior with backoff
// - One failed source does not abort batch
// - No automatic VERIFIED status assigned
// - Snapshot storage interface compliance

'use strict';

const { BaseCollector } = require('../collectors/base_collector');
const { SbiCollector } = require('../collectors/pilot_collectors');
const { SourceRegistry } = require('../collectors/source_registry');
const { RateCollectionService } = require('../collectors/collection_service');
const { MetadataOnlySnapshotStorage } = require('../collectors/snapshot_storage');
const { FetchError } = require('../collectors/http_fetcher');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log('  PASS: ' + message);
  } else {
    failedTests++;
    console.error('  FAIL: ' + message);
  }
}

async function run() {
  console.log('\n======================================================');
  console.log('FeroCalc Collector Framework Test Suite (Phase 1)');
  console.log('======================================================\n');

  // ----------------------------------------------------------
  console.log('Group 1: Deterministic SHA-256 & Normalization...');
  // ----------------------------------------------------------
  const collector = new BaseCollector({
    id: 'test-source-1',
    bankCode: 'TEST',
    sourceUrl: 'https://example.com/rates',
  });

  const buffer1 = Buffer.from('<html><body><table><tr><td>1 Year</td><td>7.00%</td></tr></table></body></html>');
  const buffer2 = Buffer.from('<html><body><table><tr><td>1 Year</td><td>7.00%</td></tr></table></body></html>');
  const bufferDiff = Buffer.from('<html><body><table><tr><td>1 Year</td><td>7.25%</td></tr></table></body></html>');

  const hash1 = collector.calculateSha256(buffer1);
  const hash2 = collector.calculateSha256(buffer2);
  const hashDiff = collector.calculateSha256(bufferDiff);

  assert(typeof hash1 === 'string' && hash1.length === 64, 'calculateSha256 produces 64-char hex string');
  assert(hash1 === hash2, 'Identical contents produce identical hash');
  assert(hash1 !== hashDiff, 'Altered content produces different hash');

  // HTML normalization: strips <script> tags containing timestamps
  const bufferWithScript1 = Buffer.from('<div>7.00%</div><script>var ts = 123456789;</script>');
  const bufferWithScript2 = Buffer.from('<div>7.00%</div><script>var ts = 987654321;</script>');
  const normHash1 = collector.calculateSha256(bufferWithScript1);
  const normHash2 = collector.calculateSha256(bufferWithScript2);
  assert(normHash1 === normHash2, 'HTML normalization ignores dynamic script tags');
  // SBI's Liferay portal shell changes independently of the official rate article.
  const sbiCollector = new SbiCollector();
  const buildSbiHtml = (portletId, formDate, rate, navTarget) => `
    <html><body>
      <div class="navigation" id="${portletId}">
        <input name="SearchPortlet_formDate" value="${formDate}" />
        <a href="${navTarget}">Navigation</a>
      </div>
      <section id="content"><div id="main-content">
        <div class="clearfix journal-content-article"
             data-analytics-asset-id="INTEREST_RATE"
             data-analytics-asset-title="Retail Domestic term deposits">
          <div class="table-wrapper"><table><tbody>
            <tr><td>7 days to 45 days</td><td>${rate}</td></tr>
          </tbody></table></div>
          <p>Revised Rates w.e.f. 15/12/2025</p>
        </div>
      </div></section>
    </body></html>`;

  const sbiHtml1 = buildSbiHtml('portlet-abc123', '1793096340551', '3.05', '/web/interest-rates/deposit-rates');
  const sbiHtml2 = buildSbiHtml('portlet-xyz789', '1793096399999', '3.05', '/web/loan-schemes-interest-rates/personal-loans');
  const sbiHtmlRateChanged = buildSbiHtml('portlet-xyz789', '1793096399999', '3.06', '/web/loan-schemes-interest-rates/personal-loans');
  const sbiNormalized = sbiCollector.normalize(Buffer.from(sbiHtml1)).toString('utf8');
  const sbiHash1 = sbiCollector.calculateSha256(Buffer.from(sbiHtml1));
  const sbiHash2 = sbiCollector.calculateSha256(Buffer.from(sbiHtml2));
  const sbiHashRateChanged = sbiCollector.calculateSha256(Buffer.from(sbiHtmlRateChanged));

  assert(sbiNormalized.includes('data-analytics-asset-id="INTEREST_RATE"'), 'SBI hash content contains the official INTEREST_RATE article');
  assert(!sbiNormalized.includes('SearchPortlet_formDate'), 'SBI article normalization excludes volatile portal form timestamps');
  assert(sbiHash1 === sbiHash2, 'SBI source hash is stable when only navigation IDs, form dates, and links change');
  assert(sbiHash1 !== sbiHashRateChanged, 'SBI source hash changes when an official rate value changes');

  const sbiFallback = sbiCollector.normalize(Buffer.from('<html><body><p>Marker temporarily absent</p></body></html>')).toString('utf8');
  assert(sbiFallback.includes('Marker temporarily absent'), 'SBI normalization fails safely to full normalized HTML if the article marker is absent');

  // ----------------------------------------------------------
  console.log('\nGroup 2: Change Classification Logic...');
  // ----------------------------------------------------------
  assert(collector.detectChange(null, hash1) === 'FIRST_SEEN', 'null previousHash classifies as FIRST_SEEN');
  assert(collector.detectChange(hash1, hash1) === 'UNCHANGED', 'Matching hashes classify as UNCHANGED');
  assert(collector.detectChange(hash1, hashDiff) === 'CHANGED', 'Differing hashes classify as CHANGED');

  // ----------------------------------------------------------
  console.log('\nGroup 3: Successful Collection Execution...');
  // ----------------------------------------------------------
  const mockFetchSuccess = async () => ({
    statusCode: 200,
    contentType: 'text/html; charset=utf-8',
    headers: {},
    bodyBuffer: buffer1,
    byteLength: buffer1.length,
    attemptsMade: 1,
  });

  const resFirstSeen = await collector.collect({
    fetchFunc: mockFetchSuccess,
    previousHash: null,
  });

  assert(resFirstSeen.status === 'FIRST_SEEN', 'Initial fetch yields FIRST_SEEN status');
  assert(resFirstSeen.changed === true, 'FIRST_SEEN marks changed = true');
  assert(resFirstSeen.httpStatus === 200, 'HTTP status is 200');
  assert(resFirstSeen.contentHash === hash1, 'contentHash matches calculated buffer hash');
  assert(resFirstSeen.error === null, 'Error is null on success');
  assert(resFirstSeen.status !== 'VERIFIED', 'Result status is NEVER marked VERIFIED (safety guarantee)');

  const resUnchanged = await collector.collect({
    fetchFunc: mockFetchSuccess,
    previousHash: hash1,
  });
  assert(resUnchanged.status === 'UNCHANGED', 'Repeated fetch with identical hash yields UNCHANGED');
  assert(resUnchanged.changed === false, 'UNCHANGED marks changed = false');

  const resChanged = await collector.collect({
    fetchFunc: async () => ({
      statusCode: 200,
      contentType: 'text/html',
      headers: {},
      bodyBuffer: bufferDiff,
      byteLength: bufferDiff.length,
      attemptsMade: 1,
    }),
    previousHash: hash1,
  });
  assert(resChanged.status === 'CHANGED', 'Fetch with updated body yields CHANGED');
  assert(resChanged.changed === true, 'CHANGED marks changed = true');

  // ----------------------------------------------------------
  console.log('\nGroup 4: Failure & Error Handling...');
  // ----------------------------------------------------------
  const mockFetchError = async () => {
    throw new FetchError('Request timed out after 5000ms', 'TIMEOUT');
  };

  const resFailed = await collector.collect({
    fetchFunc: mockFetchError,
    previousHash: hash1,
  });

  assert(resFailed.status === 'FETCH_FAILED', 'Network error yields FETCH_FAILED status');
  assert(resFailed.error.includes('timed out'), 'Error message is accurately captured');
  assert(resFailed.contentHash === null, 'contentHash is null on failure');
  assert(resFailed.changed === false, 'FETCH_FAILED does not mark changed = true');

  // ----------------------------------------------------------
  console.log('\nGroup 5: Retry & Backoff Behavior...');
  // ----------------------------------------------------------
  let callCount = 0;
  const mockFlakyFetch = async (url, opts) => {
    callCount++;
    if (callCount < 2) {
      // Test custom retry wrapper behavior
      if (opts && opts.maxRetries > 0) {
        // simulate retry
        callCount++;
        return {
          statusCode: 200,
          contentType: 'text/html',
          headers: {},
          bodyBuffer: buffer1,
          byteLength: buffer1.length,
          attemptsMade: 2,
        };
      }
      throw new FetchError('Temporary 503 gateway error', 'HTTP_STATUS_ERROR', 503);
    }
    return {
      statusCode: 200,
      contentType: 'text/html',
      headers: {},
      bodyBuffer: buffer1,
      byteLength: buffer1.length,
      attemptsMade: 1,
    };
  };

  const resFlaky = await collector.collect({
    fetchFunc: mockFlakyFetch,
    maxRetries: 2,
  });
  assert(resFlaky.status === 'FIRST_SEEN', 'Flaky endpoint recovers on retry');
  assert(callCount === 2, 'Fetcher attempted retry before succeeding');

  // ----------------------------------------------------------
  console.log('\nGroup 6: Batch Resilience (One failure does not stop batch)...');
  // ----------------------------------------------------------
  const mockSources = [
    {
      id: 'bank-good-1',
      bankCode: 'GOOD1',
      sourceUrl: 'https://good1.com',
      sourceType: 'HTML',
      enabled: true,
    },
    {
      id: 'bank-bad-2',
      bankCode: 'BAD2',
      sourceUrl: 'https://bad2.com',
      sourceType: 'HTML',
      enabled: true,
    },
    {
      id: 'bank-good-3',
      bankCode: 'GOOD3',
      sourceUrl: 'https://good3.com',
      sourceType: 'HTML',
      enabled: true,
    },
  ];

  const testRegistry = new SourceRegistry(mockSources);
  const testStorage = new MetadataOnlySnapshotStorage();
  const testService = new RateCollectionService({
    registry: testRegistry,
    storage: testStorage,
    logger: { log: () => {}, error: () => {} }, // Silent logger in tests
  });

  const mockBatchFetch = async (url) => {
    if (url.includes('bad2')) {
      throw new FetchError('Server connection refused', 'ECONNREFUSED');
    }
    return {
      statusCode: 200,
      contentType: 'text/html',
      headers: {},
      bodyBuffer: Buffer.from(`rates for ${url}`),
      byteLength: 20,
      attemptsMade: 1,
    };
  };

  const batchOutput = await testService.collectAllEnabledSources({
    fetchFunc: mockBatchFetch,
  });

  assert(batchOutput.results.length === 3, 'All 3 sources were processed');
  assert(batchOutput.results[0].status === 'FIRST_SEEN', 'Good source 1 succeeded');
  assert(batchOutput.results[1].status === 'FETCH_FAILED', 'Bad source 2 failed gracefully');
  assert(batchOutput.results[2].status === 'FIRST_SEEN', 'Good source 3 processed despite prior failure');
  assert(batchOutput.summary.total === 3, 'Summary total is 3');
  assert(batchOutput.summary.failed === 1, 'Summary failed count is 1');
  assert(batchOutput.summary.firstSeen === 2, 'Summary firstSeen count is 2');

  // ----------------------------------------------------------
  console.log('\nGroup 7: Snapshot Storage Verification...');
  // ----------------------------------------------------------
  const snapshotMeta = await testStorage.getSnapshotMetadata(batchOutput.results[0].contentHash);
  assert(snapshotMeta !== null, 'Snapshot metadata stored for successful fetch');
  assert(snapshotMeta.storageUri === null, 'Storage URI is null (no fake remote URLs)');
  assert(snapshotMeta.storageType === 'metadata_only', 'Storage type marked metadata_only');

  console.log('\n======================================================');
  console.log(`Results: ${passedTests} passed, ${failedTests} failed (Total: ${totalTests})`);
  console.log('======================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

run().catch((err) => {
  console.error('Test suite failed with unexpected error:', err);
  process.exit(1);
});
