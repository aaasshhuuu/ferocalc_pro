// FeroCalc Verified FD Rate Engine — Live Extraction & Validation Runner
// Fetches official sources, parses them into candidate rates, validates,
// detects anomalies, and reports staging metrics.
//
// Safety Guarantee:
// Absolutely NO rates are published or marked VERIFIED.

'use strict';

const { loadEnv } = require('../env_loader');
loadEnv();

const { RateCollectionService } = require('../collectors/collection_service');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { defaultRegistry } = require('../collectors/source_registry');

async function runLiveExtraction() {
  console.log('====================================================');
  console.log(' FeroCalc FD Rate Extraction & Validation (Phase 2) ');
  console.log('====================================================');
  console.log('Mode: READ ONLY Candidate Staging (DRAFT / IN_REVIEW)');
  console.log('Auto-Publish: STRICTLY DISABLED (Zero VERIFIED rates)\n');

  const collectionService = new RateCollectionService();
  const stagingService = new CandidateStagingService();
  const sources = defaultRegistry.getEnabledSources();

  const results = [];

  for (const src of sources) {
    console.log(`\n--- Collecting & Extracting ${src.bankCode} (${src.id}) ---`);
    console.log(`URL: ${src.sourceUrl}`);

    try {
      // 1. Collect
      const collectionResult = await collectionService.collectSource(src, {
        timeoutMs: 15000,
        maxRetries: 2,
      });

      console.log(`HTTP Status: ${collectionResult.httpStatus}`);
      console.log(`Source Hash: ${collectionResult.contentHash ? collectionResult.contentHash.substring(0, 16) + '...' : 'null'}`);
      console.log(`Collection Status: ${collectionResult.status}`);

      // 2. Extract & Validate
      const stageResult = await stagingService.processCollectionResult(collectionResult, {
        forceReExtract: true, // For live validation reporting
        skipDbPersist: true,  // Read-only report mode unless production DB configured
      });

      results.push({
        bankCode: src.bankCode,
        sourceId: src.id,
        sourceUrl: src.sourceUrl,
        httpStatus: collectionResult.httpStatus,
        contentHash: collectionResult.contentHash,
        parserSelected: stageResult.parserId || 'None',
        parserVersion: stageResult.parserVersion || 'None',
        parsingSuccessful: stageResult.extracted && stageResult.status === 'EXTRACTION_SUCCESS',
        totalCandidates: stageResult.totalCandidates || 0,
        validCount: stageResult.validCount || 0,
        invalidCount: stageResult.invalidCount || 0,
        anomalousCount: stageResult.anomalousCount || 0,
        effectiveFrom: stageResult.effectiveFrom,
        sampleCandidate: stageResult.candidates && stageResult.candidates.length > 0 ? stageResult.candidates[0] : null,
        errors: stageResult.validation ? stageResult.validation.errors : [],
      });

      console.log(`Parser Selected: ${stageResult.parserId || 'None'}`);
      console.log(`Parsing Successful: ${stageResult.extracted}`);
      console.log(`Candidates Extracted: ${stageResult.totalCandidates || 0}`);
      console.log(`Valid: ${stageResult.validCount || 0} | Invalid: ${stageResult.invalidCount || 0} | Anomalous: ${stageResult.anomalousCount || 0}`);
      if (stageResult.effectiveFrom) {
        console.log(`Effective Date: ${stageResult.effectiveFrom}`);
      }

    } catch (err) {
      console.error(`Extraction failed for ${src.bankCode}:`, err.message);
      results.push({
        bankCode: src.bankCode,
        sourceId: src.id,
        httpStatus: 0,
        parsingSuccessful: false,
        error: err.message,
      });
    }
  }

  console.log('\n====================================================');
  console.log('              LIVE EXTRACTION SUMMARY               ');
  console.log('====================================================');

  for (const r of results) {
    console.log(`\nBank: ${r.bankCode} (${r.sourceId})`);
    console.log(`  HTTP Status:       ${r.httpStatus}`);
    console.log(`  Source Hash:       ${r.contentHash ? r.contentHash.substring(0, 24) + '...' : 'N/A'}`);
    console.log(`  Parser:            ${r.parserSelected} (v${r.parserVersion})`);
    console.log(`  Parsing Status:    ${r.parsingSuccessful ? 'SUCCESS' : 'FAILED'}`);
    console.log(`  Candidates Total:  ${r.totalCandidates}`);
    console.log(`  Valid:             ${r.validCount}`);
    console.log(`  Invalid:           ${r.invalidCount}`);
    console.log(`  Anomalous:         ${r.anomalousCount}`);
    if (r.sampleCandidate) {
      console.log(`  Sample Candidate:  ${r.sampleCandidate.customerType} | ${r.sampleCandidate.tenureLabel} | ${r.sampleCandidate.interestRate}% (Senior: ${r.sampleCandidate.seniorCitizenRate}%) | Callable: ${r.sampleCandidate.isCallable} | Staging: ${r.sampleCandidate.stagingStatus}`);
    }
  }

  console.log('\n----------------------------------------------------');
  console.log('Safety Notice: 0 rates published to production.');
  console.log('All candidates retained strictly in DRAFT/IN_REVIEW state.');
  console.log('----------------------------------------------------');

  return results;
}

if (require.main === module) {
  runLiveExtraction().catch(err => {
    console.error('Fatal execution error:', err);
    process.exit(1);
  });
}

module.exports = {
  runLiveExtraction,
};
