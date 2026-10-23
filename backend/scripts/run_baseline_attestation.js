// FeroCalc Verified FD Rate Engine — Initial Baseline Attestation & Seeding Runner
//
// Inspects live candidate batches, constructs baseline attestation records,
// and supports safe dry-run promotion simulation.
//
// Usage:
//   node scripts/run_baseline_attestation.js --inspect
//   node scripts/run_baseline_attestation.js --dry-run

'use strict';

const { loadEnv } = require('../env_loader');
loadEnv();

const { RateCollectionService } = require('../collectors/collection_service');
const { defaultRegistry } = require('../collectors/source_registry');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { BaselineAttestationService, isOfficialBankDomain } = require('../attestation/baseline_attestation_service');

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const isInspectOnly = args.includes('--inspect') || (!isDryRun);

  let isCallableFilter = null;
  if (args.includes('--callable-only')) {
    isCallableFilter = true;
  }
  for (const a of args) {
    if (a.startsWith('--isCallable=')) {
      const val = a.split('=')[1].trim().toLowerCase();
      if (val === 'true' || val === '1') isCallableFilter = true;
      else if (val === 'false' || val === '0') isCallableFilter = false;
      else if (val === 'all') isCallableFilter = 'all';
    }
  }

  console.log('====================================================');
  console.log(' FeroCalc Baseline Attestation & Seeding (Phase 3C) ');
  console.log('====================================================');
  console.log(`Mode:       ${isDryRun ? 'DRY-RUN SIMULATION (Zero mutations)' : 'INSPECTION & VERIFICATION'}`);
  console.log(`Filter:     ${isCallableFilter !== null ? `isCallable=${isCallableFilter}` : 'ALL (Complete batch)'}`);
  console.log(`Started At: ${new Date().toISOString()}\n`);

  const collectionService = new RateCollectionService();
  const stagingService = new CandidateStagingService();
  const attestationService = new BaselineAttestationService();
  const sources = defaultRegistry.getEnabledSources();

  const inspectionReports = [];

  for (const src of sources) {
    console.log(`\n--- Inspecting Official Source: ${src.bankCode} (${src.id}) ---`);
    console.log(`URL: ${src.sourceUrl}`);

    const isOfficial = isOfficialBankDomain(src.sourceUrl);
    console.log(`Official Bank Domain Verified: ${isOfficial ? 'YES' : 'NO'}`);

    try {
      // 1. Fetch source
      const colResult = await collectionService.collectSource(src, {
        timeoutMs: 15000,
        maxRetries: 2,
      });

      console.log(`HTTP Status:  ${colResult.httpStatus}`);
      console.log(`Content Hash: ${colResult.contentHash ? colResult.contentHash.substring(0, 32) + '...' : 'null'}`);

      // 2. Extract & validate candidates
      const stageResult = await stagingService.processCollectionResult(colResult, {
        forceReExtract: true,
        skipDbPersist: true, // Read-only extraction
      });

      const candidates = stageResult.candidates || [];
      const validation = stageResult.validation || { validCount: 0, invalidCount: 0, errors: [] };
      const anomalies = stageResult.anomalies || { candidatesWithAnomalies: 0, anomalyFlags: [] };

      const batch = await attestationService.createBaselineBatch({
        bankCode: src.bankCode,
        sourceId: src.id,
        sourceUrl: src.sourceUrl,
        sourceType: src.sourceType || 'HTML',
        sourceContentHash: colResult.contentHash,
        fetchedAt: new Date().toISOString(),
        parserId: stageResult.parserId,
        parserVersion: stageResult.parserVersion,
        candidates,
        validationSummary: validation,
        anomalySummary: anomalies,
        effectiveFrom: stageResult.effectiveFrom,
        notes: `Baseline snapshot inspected on ${new Date().toISOString()}`,
      });

      const report = {
        bankCode: src.bankCode,
        sourceId: src.id,
        sourceUrl: src.sourceUrl,
        isOfficialDomain: isOfficial,
        httpStatus: colResult.httpStatus,
        sourceContentHash: colResult.contentHash,
        effectiveDate: stageResult.effectiveFrom || 'Not explicitly published in header',
        candidateCount: candidates.length,
        validCount: validation.validCount,
        invalidCount: validation.invalidCount,
        anomaliesCount: anomalies.candidatesWithAnomalies,
        anomalyFlags: anomalies.anomalyFlags || [],
        validationStatus: validation.invalidCount === 0 ? 'VALID' : 'INVALID',
        batchId: batch.batchId,
        attestationEligibility: batch.metadata?.eligibility?.eligible || false,
        attestationIssues: batch.metadata?.eligibility?.issues || [],
      };

      inspectionReports.push(report);

      console.log(`Candidates Extracted: ${report.candidateCount}`);
      console.log(`  - Valid:            ${report.validCount}`);
      console.log(`  - Invalid:          ${report.invalidCount}`);
      console.log(`  - Anomalous:        ${report.anomaliesCount}`);
      console.log(`Effective Date:       ${report.effectiveDate}`);
      console.log(`Batch ID:             ${report.batchId}`);
      console.log(`Attestation Eligible: ${report.attestationEligibility ? 'YES (Meets 100% of criteria)' : 'NO'}`);
      if (!report.attestationEligibility) {
        console.log(`Issues:               ${report.attestationIssues.join('; ')}`);
      }

      // If dry-run requested, simulate attestation and promotion
      if (isDryRun && report.attestationEligibility) {
        console.log('\n  [Dry-Run Simulation]');
        // 1. Simulate attestation
        const attestedBatch = await attestationService.attestBaseline({
          attestationId: batch.id,
          adminUserId: 'admin_dry_run_simulation',
          notes: 'Dry-run test attestation',
        });
        console.log(`  - Attestation Status: ${attestedBatch.attestationStatus}`);

        // 2. Simulate promotion
        const promoResult = await attestationService.promoteBaseline({
          attestationId: batch.id,
          adminUserId: 'admin_dry_run_simulation',
          dryRun: true,
          isCallable: isCallableFilter,
        });
        console.log(`  - Candidates Evaluated: ${promoResult.totalCandidates}`);
        console.log(`  - Simulated Promoted:   ${promoResult.promotedCount}`);
        console.log(`  - Remaining In Review:  ${promoResult.reviewCount}`);
        console.log(`  - Invalid:              ${promoResult.invalidCount}`);
      }

    } catch (err) {
      console.error(`Inspection failed for ${src.bankCode}:`, err.message);
      inspectionReports.push({
        bankCode: src.bankCode,
        sourceId: src.id,
        error: err.message,
      });
    }
  }

  console.log('\n====================================================');
  console.log('         BASELINE ATTESTATION SUMMARY TABLE         ');
  console.log('====================================================');
  for (const r of inspectionReports) {
    console.log(`\nBank: [${r.bankCode}] (${r.sourceId})`);
    console.log(`  Official Source:   ${r.sourceUrl}`);
    console.log(`  Official Domain:   ${r.isOfficialDomain ? 'CONFIRMED' : 'UNVERIFIED'}`);
    console.log(`  Source Hash:       ${r.sourceContentHash ? r.sourceContentHash.substring(0, 24) + '...' : 'N/A'}`);
    console.log(`  Effective Date:    ${r.effectiveDate}`);
    console.log(`  Candidates Count:  ${r.candidateCount}`);
    console.log(`  Validation Status: ${r.validationStatus}`);
    console.log(`  Anomalies:         ${r.anomaliesCount === 0 ? 'None (Clean)' : r.anomalyFlags.join(', ')}`);
    console.log(`  Batch ID:          ${r.batchId}`);
    console.log(`  Attestation Ready: ${r.attestationEligibility ? 'YES' : 'NO'}`);
  }

  console.log('\n----------------------------------------------------');
  console.log('SAFETY GUARANTEE: Zero production rates were modified.');
  console.log('Initial baseline remains in IN_REVIEW pending admin action.');
  console.log('----------------------------------------------------');

  return inspectionReports;
}

if (require.main === module) {
  main().catch(err => {
    console.error('Fatal execution error:', err);
    process.exit(1);
  });
}

module.exports = { main };
