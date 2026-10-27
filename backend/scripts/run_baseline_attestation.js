'use strict';

// This CLI is intentionally limited to zero-database-access source inspection.
// Any ambiguous or mutating mode (including the historical --dry-run/--inspect
// paths) is refused before environment loading, source fetching, or service creation.

const { loadEnv } = require('../env_loader');

const ALLOWED_FLAGS = new Set(['--inspect-read-only', '--staging']);

function usageError(logger, args) {
  logger.error('REFUSED: this CLI only supports --inspect-read-only (optionally with --staging).');
  logger.error('No source requests, database reads/writes, attestations, or promotions were performed.');
  logger.error('The legacy --inspect and --dry-run modes are disabled because they could trigger side effects.');
  return { exitCode: 2, reports: [], refusedArgs: args };
}

async function main(dependencies = {}) {
  const args = Array.isArray(dependencies.args) ? dependencies.args : process.argv.slice(2);
  const logger = dependencies.logger || console;
  const hasReadOnlyFlag = args.includes('--inspect-read-only');
  const unsupported = args.filter((arg) => !ALLOWED_FLAGS.has(arg));

  // Fail closed before loading .env, constructing Supabase clients, or fetching.
  if (!hasReadOnlyFlag || unsupported.length > 0) {
    return usageError(logger, args);
  }

  if (dependencies.loadEnvironment) {
    dependencies.loadEnvironment({ silent: true });
  } else {
    // Preserve the shared CLI environment-loading contract tested by env_loader_test.
    loadEnv();
  }

  let RateCollectionService;
  let defaultRegistry;
  let CandidateStagingService;
  let BaselineAttestationService;
  let isOfficialBankDomain = () => false;

  if (!dependencies.collectionService) {
    ({ RateCollectionService } = require('../collectors/collection_service'));
  }
  if (!dependencies.sources) {
    ({ defaultRegistry } = require('../collectors/source_registry'));
  }
  if (!dependencies.stagingService) {
    ({ CandidateStagingService } = require('../staging/candidate_staging_service'));
  }
  if (!dependencies.attestationService || !dependencies.isOfficialBankDomain) {
    ({ BaselineAttestationService, isOfficialBankDomain } = require('../attestation/baseline_attestation_service'));
  } else {
    isOfficialBankDomain = dependencies.isOfficialBankDomain;
  }

  const collectionService = dependencies.collectionService || new RateCollectionService();
  const stagingService = dependencies.stagingService || new CandidateStagingService();
  const attestationService = dependencies.attestationService || new BaselineAttestationService();
  const sources = dependencies.sources || defaultRegistry.getEnabledSources();

  logger.log('====================================================');
  logger.log(' FeroCalc Read-Only Source Inspection (Phase 3C)    ');
  logger.log('====================================================');
  logger.log('Mode:       READ-ONLY INSPECTION');
  logger.log('Database:   ZERO READS / ZERO WRITES');
  logger.log('Attestation: DISABLED');
  logger.log('Promotion:   DISABLED');
  logger.log(`Started At: ${new Date().toISOString()}\n`);

  const reports = [];

  for (const src of sources) {
    logger.log(`\n--- Inspecting Official Source: ${src.bankCode} (${src.id}) ---`);
    logger.log(`URL: ${src.sourceUrl}`);

    try {
      const officialDomain = isOfficialBankDomain(src.sourceUrl);
      // readOnly=true suppresses previous-hash queries, snapshot persistence, and
      // telemetry writes inside RateCollectionService.
      const collection = await collectionService.collectSource(src, {
        timeoutMs: 15000,
        maxRetries: 2,
        readOnly: true,
        previousHash: null,
      });

      if (collection.status === 'FETCH_FAILED' || !collection.bodyBuffer || !collection.contentHash) {
        throw new Error('Source fetch failed or returned no body/hash; no attestation evaluation performed.');
      }

      const staged = await stagingService.processCollectionResult(collection, {
        forceReExtract: true,
        skipDbPersist: true,
        skipDbAccess: true,
        baselineRates: [],
      });

      const candidates = staged.candidates || [];
      const validation = staged.validation || { validCount: 0, invalidCount: candidates.length, errors: [] };
      const anomalies = staged.anomalies || { candidatesWithAnomalies: 0, anomalyFlags: [] };
      const candidateCount = candidates.length;
      const invalidCandidateCount = validation.invalidCount !== undefined
        ? validation.invalidCount
        : candidates.filter((candidate) => candidate.validationStatus === 'INVALID').length;
      const anomalousCandidateCount = anomalies.candidatesWithAnomalies !== undefined
        ? anomalies.candidatesWithAnomalies
        : candidates.filter((candidate) => Array.isArray(candidate.anomalyFlags) && candidate.anomalyFlags.length > 0).length;

      // Pure/in-memory evaluation only. Do NOT call createBaselineBatch,
      // getAttestationByBatchId, attestBaseline, or promoteBaseline here.
      const eligibility = attestationService.evaluateAttestationEligibility({
        sourceUrl: src.sourceUrl,
        sourceContentHash: collection.contentHash,
        parserId: staged.parserId,
        parserVersion: staged.parserVersion,
        candidateCount,
        invalidCandidateCount,
        anomalousCandidateCount,
      });
      const eligibilityIssues = [...(eligibility.issues || [])];
      if (!officialDomain) eligibilityIssues.push('Source domain is not on the configured official-bank allowlist.');
      if (!staged.extracted || candidateCount === 0) {
        eligibilityIssues.push(staged.message || 'Parser did not produce a non-empty candidate set.');
      }

      const report = {
        bankCode: src.bankCode,
        sourceId: src.id,
        sourceUrl: src.sourceUrl,
        isOfficialDomain: officialDomain,
        httpStatus: collection.httpStatus,
        sourceContentHash: collection.contentHash,
        effectiveDate: staged.effectiveFrom || 'Not explicitly published by parser',
        candidateCount,
        validCount: validation.validCount || 0,
        invalidCount: invalidCandidateCount,
        anomaliesCount: anomalousCandidateCount,
        anomalyFlags: anomalies.anomalyFlags || [],
        validationStatus: staged.extracted && invalidCandidateCount === 0 ? 'VALID' : 'REVIEW_REQUIRED',
        batchId: attestationService.generateBatchId(src.bankCode, src.id, collection.contentHash),
        structuralEligibility: eligibilityIssues.length === 0,
        eligibilityIssues,
        databaseAccess: 'NONE',
        attestationWritten: false,
        promotionPerformed: false,
        note: 'Structural eligibility is not source approval; candidate values and effective dates still require evidence review.',
      };

      reports.push(report);
      logger.log(`HTTP Status:         ${report.httpStatus}`);
      logger.log(`Source Hash:         ${report.sourceContentHash.substring(0, 24)}...`);
      logger.log(`Candidates:          ${report.candidateCount} (valid ${report.validCount}, invalid ${report.invalidCount})`);
      logger.log(`Anomalous:           ${report.anomaliesCount}`);
      logger.log(`Effective Date:      ${report.effectiveDate}`);
      logger.log(`Structural Eligible: ${report.structuralEligibility ? 'YES' : 'NO'}`);
      if (report.eligibilityIssues.length) {
        logger.log(`Issues:              ${report.eligibilityIssues.join('; ')}`);
      }
    } catch (error) {
      reports.push({
        bankCode: src.bankCode,
        sourceId: src.id,
        sourceUrl: src.sourceUrl,
        error: error.message,
        databaseAccess: 'NONE',
        attestationWritten: false,
        promotionPerformed: false,
      });
      logger.error(`Read-only inspection failed for ${src.bankCode}: ${error.message}`);
    }
  }

  const failed = reports.some((report) =>
    report.error || report.validationStatus === 'REVIEW_REQUIRED' || report.structuralEligibility === false,
  );
  logger.log('\n====================================================');
  logger.log('READ-ONLY inspection complete.');
  logger.log('Database reads:  0');
  logger.log('Database writes: 0');
  logger.log('Attestations:    0');
  logger.log('Promotions:      0');
  logger.log('====================================================');

  return { exitCode: failed ? 1 : 0, reports };
}

if (require.main === module) {
  main()
    .then((result) => {
      if (result.exitCode) process.exitCode = result.exitCode;
    })
    .catch((error) => {
      console.error('Fatal read-only inspection error:', error.message);
      process.exitCode = 1;
    });
}

module.exports = { main, ALLOWED_FLAGS };
