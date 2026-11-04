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

async function main(dependenciesOrArgs = {}, maybeInjected = {}) {
  let isLegacyArrayCall = false;
  let args;
  let logger;
  let loadEnvironment;
  let collectionService;
  let stagingService;
  let attestationService;
  let sources;
  let isOfficialBankDomain;
  let registry;

  if (Array.isArray(dependenciesOrArgs)) {
    isLegacyArrayCall = true;
    args = dependenciesOrArgs;
    const deps = maybeInjected || {};
    logger = deps.logger || console;
    loadEnvironment = deps.loadEnvironment;
    collectionService = deps.collectionService;
    stagingService = deps.stagingService;
    attestationService = deps.attestationService;
    registry = deps.registry;
    sources = deps.sources || (registry ? registry.getEnabledSources() : null);
    isOfficialBankDomain = deps.isOfficialBankDomain;
  } else {
    args = Array.isArray(dependenciesOrArgs.args) ? dependenciesOrArgs.args : process.argv.slice(2);
    logger = dependenciesOrArgs.logger || console;
    loadEnvironment = dependenciesOrArgs.loadEnvironment;
    collectionService = dependenciesOrArgs.collectionService;
    stagingService = dependenciesOrArgs.stagingService;
    attestationService = dependenciesOrArgs.attestationService;
    registry = dependenciesOrArgs.registry;
    sources = dependenciesOrArgs.sources || (registry ? registry.getEnabledSources() : null);
    isOfficialBankDomain = dependenciesOrArgs.isOfficialBankDomain;
  }

  // If called directly via legacy array invocation and --dry-run is supplied, throw error
  if (isLegacyArrayCall && args.includes('--dry-run')) {
    throw new Error('--dry-run mode is disabled for safety. Use --inspect-read-only.');
  }

  const hasReadOnlyFlag = args.includes('--inspect-read-only');
  const unsupported = args.filter((arg) => !ALLOWED_FLAGS.has(arg));

  // Fail closed before loading .env, constructing Supabase clients, or fetching.
  if (!hasReadOnlyFlag || unsupported.length > 0) {
    if (isLegacyArrayCall) {
      throw new Error('--dry-run mode is disabled for safety. Use --inspect-read-only.');
    }
    return usageError(logger, args);
  }

  // Check persistence suppression if services are provided with skipDbPersist = false
  if (collectionService && collectionService.skipDbPersist === false) {
    throw new Error('SAFETY VIOLATION: RateCollectionService must be configured with skipDbPersist: true for read-only inspection');
  }
  if (attestationService && attestationService.skipDbPersist === false) {
    throw new Error('SAFETY VIOLATION: BaselineAttestationService must be configured with skipDbPersist: true for read-only inspection');
  }

  if (loadEnvironment) {
    loadEnvironment({ silent: true });
  } else {
    loadEnv();
  }

  let RateCollectionServiceClass;
  let defaultRegistryModule;
  let CandidateStagingServiceClass;
  let BaselineAttestationServiceClass;
  let defaultIsOfficialBankDomain;

  if (!collectionService) {
    ({ RateCollectionService: RateCollectionServiceClass } = require('../collectors/collection_service'));
    collectionService = new RateCollectionServiceClass({ skipDbPersist: true });
  }
  if (!stagingService) {
    ({ CandidateStagingService: CandidateStagingServiceClass } = require('../staging/candidate_staging_service'));
    stagingService = new CandidateStagingServiceClass();
  }
  if (!attestationService || !isOfficialBankDomain) {
    ({ BaselineAttestationService: BaselineAttestationServiceClass, isOfficialBankDomain: defaultIsOfficialBankDomain } = require('../attestation/baseline_attestation_service'));
    if (!attestationService) {
      attestationService = new BaselineAttestationServiceClass({ skipDbPersist: true });
    }
    if (!isOfficialBankDomain) {
      isOfficialBankDomain = defaultIsOfficialBankDomain;
    }
  }
  if (!sources) {
    if (!registry) {
      ({ defaultRegistry: defaultRegistryModule } = require('../collectors/source_registry'));
      registry = defaultRegistryModule;
    }
    sources = registry.getEnabledSources();
  }

  logger.log('====================================================');
  logger.log(' FeroCalc Read-Only Source Inspection (Phase 3C)    ');
  logger.log('====================================================');
  logger.log('Mode:        READ-ONLY INSPECTION');
  logger.log('Database:    ZERO READS / ZERO WRITES');
  logger.log('Attestation: DISABLED (UNATTESTED)');
  logger.log('Promotion:   DISABLED');
  logger.log(`Started At:  ${new Date().toISOString()}\n`);

  const reports = [];

  for (const src of sources) {
    logger.log(`\n--- Inspecting Official Source: ${src.bankCode} (${src.id}) ---`);
    logger.log(`URL: ${src.sourceUrl}`);

    try {
      const officialDomain = isOfficialBankDomain(src.sourceUrl);

      const collection = await collectionService.collectSource(src, {
        timeoutMs: 15000,
        maxRetries: 2,
        readOnly: true,
        skipDbPersist: true,
        previousHash: null,
      });

      if (collection.status === 'FETCH_FAILED' || (!collection.bodyBuffer && !collection.contentHash)) {
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
        : candidates.filter((c) => c.validationStatus === 'INVALID').length;
      const anomalousCandidateCount = anomalies.candidatesWithAnomalies !== undefined
        ? anomalies.candidatesWithAnomalies
        : candidates.filter((c) => Array.isArray(c.anomalyFlags) && c.anomalyFlags.length > 0).length;

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
      if (candidateCount === 0 || staged.extracted === false) {
        eligibilityIssues.push(staged.message || 'Parser did not produce a non-empty candidate set.');
      }

      const batchId = attestationService.generateBatchId
        ? attestationService.generateBatchId(src.bankCode, src.id, collection.contentHash)
        : `baseline_${src.bankCode.toLowerCase()}_${src.id}_${collection.contentHash.substring(0, 12)}`;

      const report = {
        bankCode: src.bankCode,
        sourceId: src.id,
        sourceUrl: src.sourceUrl,
        isOfficialDomain: officialDomain,
        httpStatus: collection.httpStatus,
        fetchStatus: collection.status,
        sourceContentHash: collection.contentHash,
        effectiveDate: staged.effectiveFrom || 'Not explicitly published by parser',
        candidateCount,
        validCount: validation.validCount || 0,
        invalidCount: invalidCandidateCount,
        anomaliesCount: anomalousCandidateCount,
        validCandidateCount: validation.validCount || 0,
        invalidCandidateCount: invalidCandidateCount,
        anomalousCandidateCount: anomalousCandidateCount,
        anomalyFlags: anomalies.anomalyFlags || [],
        validationStatus: (staged.extracted !== false && invalidCandidateCount === 0 && candidateCount > 0) ? 'VALID' : 'REVIEW_REQUIRED',
        batchId,
        structuralEligibility: eligibilityIssues.length === 0,
        attestationEligibility: eligibilityIssues.length === 0,
        attestationStatus: 'UNATTESTED',
        isAttested: false,
        persisted: false,
        eligibilityIssues,
        attestationIssues: eligibilityIssues,
        databaseAccess: 'NONE',
        attestationWritten: false,
        promotionPerformed: false,
        note: 'Structural eligibility is not source approval; candidate values and effective dates still require evidence review.',
      };

      reports.push(report);
      logger.log(`HTTP Status:         ${report.httpStatus}`);
      logger.log(`Source Hash:         ${report.sourceContentHash ? report.sourceContentHash.substring(0, 24) + '...' : 'null'}`);
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
        attestationStatus: 'ERROR',
        isAttested: false,
        persisted: false,
        structuralEligibility: false,
        attestationEligibility: false,
        eligibilityIssues: [error.message],
        attestationIssues: [error.message],
        databaseAccess: 'NONE',
        attestationWritten: false,
        promotionPerformed: false,
      });
      logger.error(`Read-only inspection failed for ${src.bankCode}: ${error.message}`);
    }
  }

  const failed = reports.some((r) =>
    r.error || r.validationStatus === 'REVIEW_REQUIRED' || r.structuralEligibility === false,
  );
  logger.log('\n====================================================');
  logger.log('READ-ONLY inspection complete.');
  logger.log('Database reads:  0');
  logger.log('Database writes: 0');
  logger.log('Attestations:    0');
  logger.log('Promotions:      0');
  logger.log('====================================================');

  const exitCode = failed ? 1 : 0;
  if (isLegacyArrayCall) {
    return Object.assign(reports, { exitCode, reports });
  }
  return { exitCode, reports };
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
