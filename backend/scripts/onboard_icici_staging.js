'use strict';

const { loadEnv } = require('../env_loader');
loadEnv({ environment: 'staging' });

const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');
const { RateCollectionService } = require('../collectors/collection_service');
const { defaultRegistry } = require('../collectors/source_registry');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { BaselineAttestationService } = require('../attestation/baseline_attestation_service');

const STAGING_URL = 'https://cqrslxngpwbtkjejlwty.supabase.co';
const ADMIN_USER_ID = '995b04cd-518b-435d-83a0-d1bdde22cca6';

async function main() {
  console.log('================================================================');
  console.log(' ICICI Staging Rate Onboarding & Controlled Promotion Pilot     ');
  console.log('================================================================');

  if (process.env.SUPABASE_URL !== STAGING_URL) {
    throw new Error(`SAFETY ERROR: Expected staging URL ${STAGING_URL}, but found ${process.env.SUPABASE_URL}. Failing closed!`);
  }
  console.log(`Verified staging target: ${process.env.SUPABASE_URL}`);

  // Step 1: Collection
  console.log('\n--- Step 1: Collecting official ICICI source ---');
  const collectionService = new RateCollectionService();
  const iciciSourceConfig = defaultRegistry.getSource('icici-retail-domestic');
  if (!iciciSourceConfig) {
    throw new Error('icici-retail-domestic not found in source registry');
  }
  
  const collectionResult = await collectionService.collectSource(iciciSourceConfig);
  console.log(`Collection complete:`);
  console.log(`  HTTP status:      ${collectionResult.httpStatus}`);
  console.log(`  Content hash:     ${collectionResult.contentHash}`);
  console.log(`  Byte size:        ${collectionResult.byteLength}`);
  console.log(`  Duration:         ${collectionResult.fetchDurationMs}ms`);
  console.log(`  Status:           ${collectionResult.status}`);

  if (collectionResult.httpStatus !== 200 || !collectionResult.contentHash) {
    throw new Error(`Failed to collect ICICI source: HTTP ${collectionResult.httpStatus}`);
  }

  // Step 2: Staging Candidates
  console.log('\n--- Step 2: Staging and validating candidates ---');
  const stagingService = new CandidateStagingService();
  const stagingReport = await stagingService.processCollectionResult(collectionResult, {
    forceReExtract: true,
    requireLock: false,
  });

  console.log(`Staging complete:`);
  console.log(`  Candidates count: ${stagingReport.candidates.length}`);
  console.log(`  Valid count:      ${stagingReport.validation?.validCount}`);
  console.log(`  Invalid count:    ${stagingReport.validation?.invalidCount}`);
  console.log(`  Anomalous count:  ${stagingReport.anomalies?.candidatesWithAnomalies}`);

  if (stagingReport.candidates.length === 0 || stagingReport.validation?.invalidCount > 0) {
    throw new Error(`Candidate validation failed: invalidCount=${stagingReport.validation?.invalidCount}`);
  }

  const callableCandidates = stagingReport.candidates.filter(c => c.isCallable === true || c.is_callable === true);
  console.log(`  Callable candidates: ${callableCandidates.length}`);

  // Step 3: Record Pending Baseline Attestation
  console.log('\n--- Step 3: Registering baseline attestation batch ---');
  const attestationService = new BaselineAttestationService();
  const batchId = attestationService.generateBatchId('ICICI', 'icici-retail-domestic', collectionResult.contentHash);
  console.log(`Batch ID: ${batchId}`);

  const pendingBatch = await attestationService.createBaselineBatch({
    batchId,
    bankCode: 'ICICI',
    sourceId: 'icici-retail-domestic',
    sourceUrl: collectionResult.sourceUrl,
    effectiveUrl: collectionResult.sourceUrl,
    sourceContentHash: collectionResult.contentHash,
    parserId: 'icici_retail_html',
    parserVersion: '1.0.0',
    candidates: stagingReport.candidates,
    validationSummary: stagingReport.validation,
    anomalySummary: stagingReport.anomalies,
    effectiveFrom: '2026-11-03',
    notes: 'ICICI Bank official retail domestic deposit rate baseline',
  });
  console.log(`Baseline registered: ID=${pendingBatch.id}, Status=${pendingBatch.attestationStatus}`);

  // Step 4: Administrative Attestation
  console.log('\n--- Step 4: Performing administrative baseline attestation ---');
  const attestedBatch = await attestationService.attestBaseline({
    attestationId: pendingBatch.id,
    adminUserId: ADMIN_USER_ID,
    notes: 'Attested official ICICI deposit rate schedule effective 2026-11-03',
  });
  console.log(`Baseline attested: Status=${attestedBatch.attestationStatus}, AttestedBy=${attestedBatch.attestedBy}`);

  // Step 5: Controlled Promotion (Callable domestic deposits)
  console.log('\n--- Step 5: Promoting verified callable deposit rates ---');
  const promoResult = await attestationService.promoteBaseline({
    attestationId: attestedBatch.id,
    adminUserId: ADMIN_USER_ID,
    isCallable: true,
    dryRun: false,
  });

  console.log(`Promotion result:`);
  console.log(`  Promoted count: ${promoResult.promotedCount}`);
  console.log(`  In Review:      ${promoResult.reviewCount}`);
  console.log(`  Invalid:        ${promoResult.invalidCount}`);

  // Step 6: Verification of Active Rates in Staging
  console.log('\n--- Step 6: Post-promotion database verification ---');
  const { data: verifiedRates, error: vErr } = await supabaseAdmin
    .from('fd_rates')
    .select('id, bank_id, status, customer_type, min_tenure_days, max_tenure_days, min_years, max_years, interest_rate')
    .eq('status', 'VERIFIED');

  if (vErr) throw vErr;

  const { data: banks } = await supabaseAdmin.from('banks').select('id, short_name');
  const bankMap = {};
  for (const b of banks) bankMap[b.id] = b.short_name;

  const counts = {};
  for (const r of verifiedRates) {
    const code = bankMap[r.bank_id] || r.bank_id;
    counts[code] = (counts[code] || 0) + 1;
  }

  console.log(`Total verified rates in staging: ${verifiedRates.length}`);
  console.log(`Verified rates by bank:`, counts);

  if (counts['ICICI'] !== 26) {
    throw new Error(`Expected exactly 26 ICICI rates, but found ${counts['ICICI']}`);
  }
  if (counts['SBI'] !== 16) {
    throw new Error(`SAFETY VIOLATION: Expected exactly 16 SBI rates, but found ${counts['SBI']}`);
  }
  if (counts['HDFC'] !== 8) {
    throw new Error(`SAFETY VIOLATION: Expected exactly 8 HDFC rates, but found ${counts['HDFC']}`);
  }
  if (verifiedRates.length !== 50) {
    throw new Error(`Expected total 50 verified rates (16 SBI + 8 HDFC + 26 ICICI), but found ${verifiedRates.length}`);
  }

  console.log('\nSUCCESS: ICICI baseline attested and promoted cleanly!');
}

main().catch(err => {
  console.error('\nEXECUTION FAILED:', err);
  process.exit(1);
});
