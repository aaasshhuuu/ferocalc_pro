'use strict';

const { loadEnv } = require('../env_loader');
loadEnv({ environment: 'staging' });

const { supabaseAdmin } = require('../supabase/supabase_client');
const { BaselineAttestationService } = require('../attestation/baseline_attestation_service');
const { PromotionService } = require('../promotion/promotion_service');
const { defaultRegistry } = require('../collectors/source_registry');

const STAGING_URL = 'https://cqrslxngpwbtkjejlwty.supabase.co';
const ADMIN_USER_ID = '995b04cd-518b-435d-83a0-d1bdde22cca6';

const REMAINING_BANKS = [
  {
    code: 'CENTRAL_BANK',
    sourceId: 'central-bank-retail-domestic',
    effectiveFrom: '2026-08-10',
    expectedCandidates: 30,
    description: 'Central Bank of India retail domestic callable deposit rates',
  },
  {
    code: 'INDIAN_BANK',
    sourceId: 'indian-bank-retail-domestic',
    effectiveFrom: '2026-10-23',
    expectedCandidates: 54,
    description: 'Indian Bank retail domestic callable deposit rates',
  },
  {
    code: 'AU_SMALL_FINANCE',
    sourceId: 'au-small-finance-retail-domestic',
    effectiveFrom: '2026-09-01',
    expectedCandidates: 24,
    description: 'AU Small Finance Bank retail domestic callable deposit rates',
  },
  {
    code: 'PNB',
    sourceId: 'pnb-retail-domestic',
    effectiveFrom: '2026-11-01',
    expectedCandidates: 57,
    description: 'Punjab National Bank retail domestic callable deposit rates w.e.f. 01.11.2026',
  },
  {
    code: 'UCO',
    sourceId: 'uco-retail-domestic',
    effectiveFrom: '2026-05-21',
    expectedCandidates: 48,
    description: 'UCO Bank retail domestic callable deposit rates (active non-expired slabs)',
  },
  {
    code: 'CANARA',
    sourceId: 'canara-retail-domestic',
    effectiveFrom: '2026-11-02',
    expectedCandidates: 24,
    description: 'Canara Bank retail domestic callable deposit rates w.e.f. 02.11.2026',
  },
  {
    code: 'INDUSIND',
    sourceId: 'indusind-retail-domestic',
    effectiveFrom: '2026-10-30',
    expectedCandidates: 34,
    description: 'IndusInd Bank retail domestic callable deposit rates w.e.f. 30.10.2026',
  },
  {
    code: 'AXIS',
    sourceId: 'axis-retail-domestic',
    effectiveFrom: '2026-10-29',
    expectedCandidates: 36,
    description: 'Axis Bank retail domestic callable deposit rates w.e.f. 29.10.2026',
  },
];

async function promoteBank(bankConfig, attestationService, promoService) {
  console.log(`\n================================================================`);
  console.log(` Promoting ${bankConfig.code} (${bankConfig.sourceId}) `);
  console.log(`================================================================`);

  // 1. Fetch bank from banks table
  const { data: bankRow, error: bankErr } = await supabaseAdmin
    .from('banks')
    .select('id, short_name')
    .eq('short_name', bankConfig.code)
    .single();

  if (bankErr || !bankRow) {
    throw new Error(`Bank not found in banks table: ${bankConfig.code} (${bankErr?.message})`);
  }

  // 2. Fetch staged DRAFT candidates
  const { data: candidates, error: candErr } = await supabaseAdmin
    .from('staged_rate_candidates')
    .select('*')
    .eq('bank_code', bankConfig.code)
    .eq('staging_status', 'DRAFT')
    .eq('validation_status', 'VALID');

  if (candErr) throw candErr;

  console.log(`[1] Found ${candidates.length} valid DRAFT candidates (expected ${bankConfig.expectedCandidates})`);
  if (candidates.length !== bankConfig.expectedCandidates) {
    throw new Error(`Candidate count mismatch for ${bankConfig.code}: expected ${bankConfig.expectedCandidates}, got ${candidates.length}`);
  }

  const firstCandidate = candidates[0];
  const sourceContentHash = firstCandidate.source_content_hash;
  const sourceUrl = firstCandidate.source_url;
  const parserId = firstCandidate.parser_id;
  const parserVersion = firstCandidate.parser_version;

  // 3. Ensure rate_sources entry exists
  const sourceRegistryEntry = defaultRegistry.getSource(bankConfig.sourceId);
  const { error: srcUpsertErr } = await supabaseAdmin.from('rate_sources').upsert({
    id: bankConfig.sourceId,
    bank_id: bankRow.id,
    bank_code: bankConfig.code,
    source_url: sourceRegistryEntry?.sourceUrl || sourceUrl,
    source_type: sourceRegistryEntry?.sourceType || 'HTML',
    parser_id: parserId,
    parser_version: parserVersion,
    is_enabled: true,
  }, { onConflict: 'id' });

  if (srcUpsertErr) throw srcUpsertErr;
  console.log(`[2] Rate source verified in rate_sources table: ${bankConfig.sourceId}`);

  // 4. Create Baseline Batch
  const batchId = attestationService.generateBatchId(bankConfig.code, bankConfig.sourceId, sourceContentHash);
  const pendingBatch = await attestationService.createBaselineBatch({
    batchId,
    bankCode: bankConfig.code,
    sourceId: bankConfig.sourceId,
    sourceUrl,
    effectiveUrl: sourceUrl,
    sourceContentHash,
    parserId,
    parserVersion,
    candidates,
    validationSummary: {
      validCount: candidates.length,
      invalidCount: 0,
      totalCount: candidates.length,
    },
    anomalySummary: {
      candidatesWithAnomalies: 0,
      anomalyFlags: [],
    },
    effectiveFrom: bankConfig.effectiveFrom,
    notes: `${bankConfig.code} official rate schedule baseline: ${bankConfig.description}`,
  });
  console.log(`[3] Created baseline batch: ${pendingBatch.id} (batchId: ${batchId})`);

  // 5. Attest Baseline
  const attestedBatch = await attestationService.attestBaseline({
    attestationId: pendingBatch.id,
    adminUserId: ADMIN_USER_ID,
    notes: `Attested official ${bankConfig.code} baseline effective ${bankConfig.effectiveFrom}`,
  });
  console.log(`[4] Attested baseline: Status=${attestedBatch.attestationStatus}`);

  // 6. Promote Baseline Batch
  const promoResult = await attestationService.promoteBaseline({
    attestationId: attestedBatch.id,
    adminUserId: ADMIN_USER_ID,
    isCallable: true,
    dryRun: false,
  });
  console.log(`[5] Baseline Promotion: Promoted=${promoResult.promotedCount}, Review=${promoResult.reviewCount}, Invalid=${promoResult.invalidCount}`);

  // 7. Ensure zero candidates remain DRAFT
  const { data: remainingDrafts } = await supabaseAdmin
    .from('staged_rate_candidates')
    .select('*')
    .eq('bank_code', bankConfig.code)
    .eq('staging_status', 'DRAFT')
    .eq('validation_status', 'VALID');

  if (remainingDrafts && remainingDrafts.length > 0) {
    console.log(`  -> Promoting ${remainingDrafts.length} remaining valid DRAFT candidates through PromotionService...`);
    for (const c of remainingDrafts) {
      const pRes = await promoService.promoteCandidate({
        candidate: c,
        actorType: 'ADMIN',
        actorId: ADMIN_USER_ID,
        reason: `Baseline attestation promotion for ${bankConfig.code}`,
        context: { isBaselineAttested: true },
      });
      if (!pRes.promoted) {
        throw new Error(`Promotion failed for candidate ${c.id} (${c.tenure_label}): ${pRes.reason}`);
      }
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

  // 8. Verify final bank active rates
  const { data: activeRates } = await supabaseAdmin
    .from('fd_rates')
    .select('id')
    .eq('bank_id', bankRow.id)
    .eq('status', 'VERIFIED');

  console.log(`[6] ${bankConfig.code} active verified rates in staging: ${activeRates?.length || 0}`);
  if (activeRates?.length !== bankConfig.expectedCandidates) {
    throw new Error(`Expected ${bankConfig.expectedCandidates} active verified rates for ${bankConfig.code}, but found ${activeRates?.length}`);
  }

  return activeRates?.length || 0;
}

async function main() {
  if (process.env.SUPABASE_URL !== STAGING_URL) {
    throw new Error(`SAFETY ERROR: Expected staging URL ${STAGING_URL}`);
  }

  console.log('================================================================');
  console.log(' FeroCalc Remaining 8 Banks Attestation & Promotion Runner     ');
  console.log('================================================================');
  console.log(`Target database: ${process.env.SUPABASE_URL}`);

  // 1. Snapshot initial verified rates to ensure zero baseline mutation
  const { data: initialRates } = await supabaseAdmin
    .from('fd_rates')
    .select('id, bank_id, interest_rate, min_tenure_days, max_tenure_days, status')
    .eq('status', 'VERIFIED');

  console.log(`\nInitial verified rates in staging: ${initialRates.length}`);
  if (initialRates.length !== 118) {
    throw new Error(`SAFETY ERROR: Expected exactly 118 initial verified rates, found ${initialRates.length}`);
  }

  const initialRateIds = new Set(initialRates.map(r => r.id));

  const attestationService = new BaselineAttestationService();
  const promoService = new PromotionService();

  const results = {};
  for (const bankConfig of REMAINING_BANKS) {
    try {
      const count = await promoteBank(bankConfig, attestationService, promoService);
      results[bankConfig.code] = count;
    } catch (err) {
      console.error(`FATAL ERROR promoting ${bankConfig.code}:`, err);
      process.exit(1);
    }
  }

  // 2. Post-promotion verification
  const { data: finalRates } = await supabaseAdmin
    .from('fd_rates')
    .select('id, bank_id, interest_rate, min_tenure_days, max_tenure_days, status')
    .eq('status', 'VERIFIED');

  const { data: banks } = await supabaseAdmin.from('banks').select('id, short_name');
  const bankMap = Object.fromEntries(banks.map(b => [b.id, b.short_name]));

  const counts = {};
  for (const r of finalRates) {
    const code = bankMap[r.bank_id] || r.bank_id;
    counts[code] = (counts[code] || 0) + 1;
  }

  console.log('\n================================================================');
  console.log(' POST-PROMOTION VERIFIED RATES AUDIT                            ');
  console.log('================================================================');
  console.log(`Total verified rates in staging: ${finalRates.length} (Expected: ${118 + 307} = 425)`);
  console.log('Counts by bank:');
  console.table(counts);

  // Check preservation of all 118 original rates
  for (const initRate of initialRates) {
    const found = finalRates.find(r => r.id === initRate.id);
    if (!found) {
      throw new Error(`SAFETY VIOLATION: Initial rate ${initRate.id} was deleted!`);
    }
    if (found.interest_rate !== initRate.interest_rate || found.status !== 'VERIFIED') {
      throw new Error(`SAFETY VIOLATION: Initial rate ${initRate.id} was mutated!`);
    }
  }
  console.log('\n✔ All 118 initial verified rates strictly preserved with zero mutations.');

  // Check expected counts
  const expectedTotal = 118 + 307;
  if (finalRates.length !== expectedTotal) {
    throw new Error(`Expected exactly ${expectedTotal} verified rates, found ${finalRates.length}`);
  }

  console.log(`✔ Exactly ${expectedTotal} active verified rates confirmed in staging.`);
  console.log('\nAll 8 remaining banks successfully attested and promoted!');
}

main().catch(err => {
  console.error('PROMOTION RUNNER FAILED:', err);
  process.exit(1);
});
