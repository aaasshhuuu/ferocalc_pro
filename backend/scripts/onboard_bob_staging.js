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
  console.log(' Bank of Baroda (BOB) Staging Rate Onboarding & Promotion Pilot ');
  console.log('================================================================');

  if (process.env.SUPABASE_URL !== STAGING_URL) {
    throw new Error(`SAFETY ERROR: Expected staging URL ${STAGING_URL}, but found ${process.env.SUPABASE_URL}. Failing closed!`);
  }
  console.log(`Verified staging target: ${process.env.SUPABASE_URL}`);

  // Step 1: Ensure bob-retail-domestic is in staging rate_sources
  console.log('\n--- Step 1: Ensuring rate_sources registration ---');
  const bobSourceConfig = defaultRegistry.getSource('bob-retail-domestic');
  if (!bobSourceConfig) {
    throw new Error('bob-retail-domestic not found in source registry');
  }

  const { error: srcErr } = await supabaseAdmin.from('rate_sources').upsert({
    id: bobSourceConfig.id,
    bank_id: 'a5db264b-e2ce-4129-b356-2c117ac36041',
    bank_code: bobSourceConfig.bankCode,
    source_url: bobSourceConfig.sourceUrl,
    source_type: bobSourceConfig.sourceType,
    parser_id: bobSourceConfig.parserId,
    parser_version: bobSourceConfig.parserVersion,
    is_enabled: true,
  }, { onConflict: 'id' });

  if (srcErr) {
    throw new Error(`Failed to ensure rate_sources entry for BOB: ${srcErr.message}`);
  }
  console.log(`bob-retail-domestic registered in staging rate_sources`);

  // Step 2: Collection
  console.log('\n--- Step 2: Collecting official Bank of Baroda source ---');
  const collectionService = new RateCollectionService();
  const collectionResult = await collectionService.collectSource(bobSourceConfig);

  console.log(`Collection complete:`);
  console.log(`  HTTP status:      ${collectionResult.httpStatus}`);
  console.log(`  Content hash:     ${collectionResult.contentHash}`);
  console.log(`  Byte size:        ${collectionResult.byteLength}`);
  console.log(`  Duration:         ${collectionResult.fetchDurationMs}ms`);
  console.log(`  Status:           ${collectionResult.status}`);

  if (collectionResult.httpStatus !== 200 || !collectionResult.contentHash) {
    throw new Error(`Failed to collect BOB source: HTTP ${collectionResult.httpStatus}`);
  }

  // Step 3: Staging Candidates
  console.log('\n--- Step 3: Staging and validating candidates ---');
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

  // Step 4: Record Pending Baseline Attestation
  console.log('\n--- Step 4: Registering baseline attestation batch ---');
  const attestationService = new BaselineAttestationService();
  const batchId = attestationService.generateBatchId('BOB', 'bob-retail-domestic', collectionResult.contentHash);
  console.log(`Batch ID: ${batchId}`);

  const pendingBatch = await attestationService.createBaselineBatch({
    batchId,
    bankCode: 'BOB',
    sourceId: 'bob-retail-domestic',
    sourceUrl: collectionResult.sourceUrl,
    effectiveUrl: collectionResult.sourceUrl,
    sourceContentHash: collectionResult.contentHash,
    parserId: 'bob_retail_html',
    parserVersion: '1.0.0',
    candidates: stagingReport.candidates,
    validationSummary: stagingReport.validation,
    anomalySummary: stagingReport.anomalies,
    effectiveFrom: '2026-06-12',
    notes: 'Bank of Baroda official domestic retail deposit rate baseline (< Rs. 3 Crore)',
  });
  console.log(`Baseline registered: ID=${pendingBatch.id}, Status=${pendingBatch.attestationStatus}`);

  // Step 5: Administrative Attestation
  console.log('\n--- Step 5: Performing administrative baseline attestation ---');
  const attestedBatch = await attestationService.attestBaseline({
    attestationId: pendingBatch.id,
    adminUserId: ADMIN_USER_ID,
    notes: 'Attested official Bank of Baroda deposit rate schedule effective 2026-06-12',
  });
  console.log(`Baseline attested: Status=${attestedBatch.attestationStatus}, AttestedBy=${attestedBatch.attestedBy}`);

  // Step 6: Controlled Promotion (all 30 are callable retail term deposits)
  console.log('\n--- Step 6: Promoting verified deposit rates ---');
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

  // Step 7: Post-Promotion Verification in Staging
  console.log('\n--- Step 7: Post-promotion database verification ---');
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

  if (counts['BOB'] !== 30) {
    throw new Error(`Expected exactly 30 BOB rates, but found ${counts['BOB']}`);
  }
  if (counts['ICICI'] !== 26) {
    throw new Error(`SAFETY VIOLATION: Expected exactly 26 ICICI rates, but found ${counts['ICICI']}`);
  }
  if (counts['SBI'] !== 16) {
    throw new Error(`SAFETY VIOLATION: Expected exactly 16 SBI rates, but found ${counts['SBI']}`);
  }
  if (counts['HDFC'] !== 8) {
    throw new Error(`SAFETY VIOLATION: Expected exactly 8 HDFC rates, but found ${counts['HDFC']}`);
  }
  if (verifiedRates.length !== 80) {
    throw new Error(`Expected total 80 verified rates (16 SBI + 8 HDFC + 26 ICICI + 30 BOB), but found ${verifiedRates.length}`);
  }

  console.log('\nSUCCESS: Bank of Baroda baseline attested and promoted cleanly!');
}

main().catch(err => {
  console.error('\nEXECUTION FAILED:', err);
  process.exit(1);
});
