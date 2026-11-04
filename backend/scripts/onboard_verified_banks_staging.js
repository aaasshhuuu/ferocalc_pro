'use strict';

const { loadEnv } = require('../env_loader');
loadEnv({ environment: 'staging' });

const { supabaseAdmin } = require('../supabase/supabase_client');
const { RateCollectionService } = require('../collectors/collection_service');
const { defaultRegistry } = require('../collectors/source_registry');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { BaselineAttestationService } = require('../attestation/baseline_attestation_service');
const { PromotionService } = require('../promotion/promotion_service');

const STAGING_URL = 'https://cqrslxngpwbtkjejlwty.supabase.co';
const ADMIN_USER_ID = '995b04cd-518b-435d-83a0-d1bdde22cca6';

const TARGET_BANKS = [
  {
    code: 'IDFC_FIRST',
    sourceId: 'idfc-first-retail-domestic',
    effectiveFrom: '2026-09-01',
    description: 'IDFC FIRST Bank retail domestic FD rates below Rs. 3 crore',
  },
  {
    code: 'AU_SMALL_FINANCE',
    sourceId: 'au-small-finance-retail-domestic',
    effectiveFrom: '2026-09-01',
    description: 'AU Small Finance Bank retail domestic callable deposit rates',
  },
  {
    code: 'CENTRAL_BANK',
    sourceId: 'central-bank-retail-domestic',
    effectiveFrom: '2026-08-10',
    description: 'Central Bank of India retail domestic callable deposit rates',
  },
  {
    code: 'UNION_BANK',
    sourceId: 'union-bank-retail-callable',
    effectiveFrom: '2026-08-04',
    description: 'Union Bank of India retail domestic callable deposit rates',
  },
  {
    code: 'INDIAN_BANK',
    sourceId: 'indian-bank-retail-domestic',
    effectiveFrom: '2026-10-23',
    description: 'Indian Bank retail domestic callable deposit rates and special schemes',
  },
];

async function onboardBank(target) {
  console.log(`\n================================================================`);
  console.log(` Processing ${target.code} (${target.sourceId}) `);
  console.log(`================================================================`);

  const { data: bankRow } = await supabaseAdmin
    .from('banks')
    .select('id, short_name')
    .eq('short_name', target.code)
    .single();

  if (!bankRow) throw new Error(`Bank not found in banks table: ${target.code}`);

  const sourceConfig = defaultRegistry.getSource(target.sourceId);
  if (!sourceConfig) throw new Error(`Source not found in registry: ${target.sourceId}`);

  // 1. Ensure rate_sources row exists and is enabled
  const { error: srcErr } = await supabaseAdmin.from('rate_sources').upsert({
    id: sourceConfig.id,
    bank_id: bankRow.id,
    bank_code: target.code,
    source_url: sourceConfig.sourceUrl,
    source_type: sourceConfig.sourceType,
    parser_id: sourceConfig.parserId,
    parser_version: sourceConfig.parserVersion,
    is_enabled: true,
  }, { onConflict: 'id' });
  if (srcErr) throw srcErr;
  console.log(`[1] Registered source in rate_sources table: ${target.sourceId}`);

  // 2. Collect official source
  const collectionService = new RateCollectionService();
  const collectionResult = await collectionService.collectSource(sourceConfig);
  console.log(`[2] Collection complete: HTTP ${collectionResult.httpStatus}, Hash: ${collectionResult.contentHash?.slice(0, 16)}..., Bytes: ${collectionResult.byteLength}`);

  if (collectionResult.httpStatus !== 200 || !collectionResult.contentHash) {
    throw new Error(`Failed collection for ${target.code}: HTTP ${collectionResult.httpStatus}`);
  }

  // 3. Stage candidates
  const stagingService = new CandidateStagingService();
  const stagingReport = await stagingService.processCollectionResult(collectionResult, {
    forceReExtract: true,
    requireLock: false,
  });

  console.log(`[3] Staged candidates: Total=${stagingReport.candidates.length}, Valid=${stagingReport.validation?.validCount}, Invalid=${stagingReport.validation?.invalidCount}`);
  if (stagingReport.candidates.length === 0 || stagingReport.validation?.invalidCount > 0) {
    throw new Error(`Candidate validation failed for ${target.code}`);
  }

  // 4. Create Baseline Batch
  const attestationService = new BaselineAttestationService();
  const batchId = attestationService.generateBatchId(target.code, target.sourceId, collectionResult.contentHash);
  const pendingBatch = await attestationService.createBaselineBatch({
    batchId,
    bankCode: target.code,
    sourceId: target.sourceId,
    sourceUrl: collectionResult.sourceUrl,
    effectiveUrl: collectionResult.sourceUrl,
    sourceContentHash: collectionResult.contentHash,
    parserId: sourceConfig.parserId,
    parserVersion: sourceConfig.parserVersion,
    candidates: stagingReport.candidates,
    validationSummary: stagingReport.validation,
    anomalySummary: stagingReport.anomalies,
    effectiveFrom: target.effectiveFrom,
    notes: `${target.code} official rate schedule baseline`,
  });
  console.log(`[4] Created baseline batch: ${pendingBatch.id}`);

  // 5. Attest Baseline
  const attestedBatch = await attestationService.attestBaseline({
    attestationId: pendingBatch.id,
    adminUserId: ADMIN_USER_ID,
    notes: `Attested official ${target.code} baseline effective ${target.effectiveFrom}`,
  });
  console.log(`[5] Attested baseline: Status=${attestedBatch.attestationStatus}`);

  // 6. Promote Eligible Candidates
  const promoResult = await attestationService.promoteBaseline({
    attestationId: attestedBatch.id,
    adminUserId: ADMIN_USER_ID,
    isCallable: true,
    dryRun: false,
  });
  console.log(`[6] Promotion: Promoted=${promoResult.promotedCount}, Review=${promoResult.reviewCount}, Invalid=${promoResult.invalidCount}`);

  // If some candidates remained DRAFT, promote via PromotionService
  const { data: remainingDrafts } = await supabaseAdmin
    .from('staged_rate_candidates')
    .select('*')
    .eq('bank_code', target.code)
    .eq('staging_status', 'DRAFT')
    .eq('validation_status', 'VALID');

  if (remainingDrafts && remainingDrafts.length > 0) {
    console.log(`  -> Promoting ${remainingDrafts.length} remaining validated DRAFT candidates directly...`);
    const promoService = new PromotionService();
    for (const c of remainingDrafts) {
      const pRes = await promoService.promoteCandidate({
        candidate: c,
        actorType: 'ADMIN',
        actorId: ADMIN_USER_ID,
        reason: `Baseline attestation promotion for ${target.code}`,
        context: { isBaselineAttested: true },
      });
      if (pRes.promoted) {
        await supabaseAdmin
          .from('staged_rate_candidates')
          .update({
            staging_status: 'PROMOTED',
            promoted_rate_id: pRes.newVerifiedRate.id,
            promoted_at: new Date().toISOString(),
            promoted_by: ADMIN_USER_ID,
          })
          .eq('id', c.id);
      }
    }
  }

  // Count active verified rates for this bank
  const { data: bankRates } = await supabaseAdmin
    .from('fd_rates')
    .select('id')
    .eq('bank_id', bankRow.id)
    .eq('status', 'VERIFIED');

  console.log(`[Done] ${target.code} active verified rates in staging: ${bankRates?.length || 0}`);
  return bankRates?.length || 0;
}

async function main() {
  if (process.env.SUPABASE_URL !== STAGING_URL) {
    throw new Error(`SAFETY ERROR: Expected staging URL ${STAGING_URL}`);
  }

  console.log('================================================================');
  console.log(' FeroCalc Multi-Bank Staging Onboarding & Promotion Runner      ');
  console.log('================================================================');
  console.log(`Target database: ${process.env.SUPABASE_URL}`);

  for (const target of TARGET_BANKS) {
    try {
      await onboardBank(target);
    } catch (err) {
      console.error(`ERROR onboarding ${target.code}:`, err.message);
    }
  }

  // Overall database summary
  const { data: verifiedRates } = await supabaseAdmin
    .from('fd_rates')
    .select('id, bank_id')
    .eq('status', 'VERIFIED');

  const { data: banks } = await supabaseAdmin.from('banks').select('id, short_name');
  const bankMap = {};
  for (const b of banks) bankMap[b.id] = b.short_name;

  const counts = {};
  for (const r of verifiedRates) {
    const code = bankMap[r.bank_id] || r.bank_id;
    counts[code] = (counts[code] || 0) + 1;
  }

  console.log('\n================================================================');
  console.log(' OVERALL VERIFIED RATES SUMMARY IN STAGING                      ');
  console.log('================================================================');
  console.log(`Total active verified rates: ${verifiedRates.length}`);
  console.log(`Counts by bank:`, counts);
}

main().catch(err => {
  console.error('RUNNER FAILED:', err);
  process.exit(1);
});
