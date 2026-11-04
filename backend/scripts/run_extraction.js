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

async function runLiveExtraction(dependencies = {}) {
  const logger = dependencies.logger || console;

  logger.log('====================================================');
  logger.log(' FeroCalc FD Rate Extraction & Validation (Phase 2) ');
  logger.log('====================================================');
  logger.log('Mode: READ ONLY Candidate Staging (DRAFT / IN_REVIEW)');
  logger.log('Auto-Publish: STRICTLY DISABLED (Zero VERIFIED rates)\n');

  const collectionService = dependencies.collectionService || new RateCollectionService();
  const stagingService = dependencies.stagingService || new CandidateStagingService();
  const sources = dependencies.sources || (dependencies.registry || defaultRegistry).getEnabledSources();

  const results = [];

  for (const src of sources) {
    logger.log(`\n--- Collecting & Extracting ${src.bankCode} (${src.id}) ---`);
    logger.log(`URL: ${src.sourceUrl}`);

    try {
      // 1. Collect
      const collectionResult = await collectionService.collectSource(src, {
        timeoutMs: 15000,
        maxRetries: 2,
        readOnly: true,
      });

      logger.log(`HTTP Status: ${collectionResult.httpStatus}`);
      logger.log(`Source Hash: ${collectionResult.contentHash ? collectionResult.contentHash.substring(0, 16) + '...' : 'null'}`);
      logger.log(`Collection Status: ${collectionResult.status}`);

      // 2. Extract & Validate
      const stageResult = await stagingService.processCollectionResult(collectionResult, {
        forceReExtract: true, // For live validation reporting
        skipDbAccess: true,   // Read-only safety: prevent querying verified/staged baselines
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

      logger.log(`Parser Selected: ${stageResult.parserId || 'None'}`);
      logger.log(`Parsing Successful: ${stageResult.extracted}`);
      logger.log(`Candidates Extracted: ${stageResult.totalCandidates || 0}`);
      logger.log(`Valid: ${stageResult.validCount || 0} | Invalid: ${stageResult.invalidCount || 0} | Anomalous: ${stageResult.anomalousCount || 0}`);
      if (stageResult.effectiveFrom) {
        logger.log(`Effective Date: ${stageResult.effectiveFrom}`);
      }

    } catch (err) {
      logger.error(`Extraction failed for ${src.bankCode}:`, err.message);
      results.push({
        bankCode: src.bankCode,
        sourceId: src.id,
        httpStatus: 0,
        parsingSuccessful: false,
        error: err.message,
      });
    }
  }

  logger.log('\n====================================================');
  logger.log('              LIVE EXTRACTION SUMMARY               ');
  logger.log('====================================================');

  for (const r of results) {
    logger.log(`\nBank: ${r.bankCode} (${r.sourceId})`);
    logger.log(`  HTTP Status:       ${r.httpStatus}`);
    logger.log(`  Source Hash:       ${r.contentHash ? r.contentHash.substring(0, 24) + '...' : 'N/A'}`);
    logger.log(`  Parser:            ${r.parserSelected} (v${r.parserVersion})`);
    logger.log(`  Parsing Status:    ${r.parsingSuccessful ? 'SUCCESS' : 'FAILED'}`);
    logger.log(`  Candidates Total:  ${r.totalCandidates}`);
    logger.log(`  Valid:             ${r.validCount}`);
    logger.log(`  Invalid:           ${r.invalidCount}`);
    logger.log(`  Anomalous:         ${r.anomalousCount}`);
    if (r.sampleCandidate) {
      logger.log(`  Sample Candidate:  ${r.sampleCandidate.customerType} | ${r.sampleCandidate.tenureLabel} | ${r.sampleCandidate.interestRate}% (Senior: ${r.sampleCandidate.seniorCitizenRate}%) | Callable: ${r.sampleCandidate.isCallable} | Staging: ${r.sampleCandidate.stagingStatus}`);
    }
  }

  logger.log('\n----------------------------------------------------');
  logger.log('Safety Notice: 0 rates published to production.');
  logger.log('All candidates retained strictly in DRAFT/IN_REVIEW state.');
  logger.log('----------------------------------------------------');

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
