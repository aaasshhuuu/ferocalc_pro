'use strict';

const { loadEnv } = require('../env_loader');
loadEnv({ environment: 'staging' });

const { supabaseAdmin } = require('../supabase/supabase_client');
const { PromotionService } = require('../promotion/promotion_service');

const STAGING_URL = 'https://cqrslxngpwbtkjejlwty.supabase.co';
const ADMIN_USER_ID = '995b04cd-518b-435d-83a0-d1bdde22cca6';

async function main() {
  if (process.env.SUPABASE_URL !== STAGING_URL) {
    throw new Error(`SAFETY ERROR: Expected staging URL ${STAGING_URL}`);
  }

  // Update b98ecca3-debc-480c-959e-e444f8c032ff (which was promoted in the test run)
  await supabaseAdmin
    .from('staged_rate_candidates')
    .update({
      staging_status: 'PROMOTED',
      promoted_at: new Date().toISOString(),
      promoted_by: ADMIN_USER_ID,
    })
    .eq('id', 'b98ecca3-debc-480c-959e-e444f8c032ff');

  const { data: drafts, error } = await supabaseAdmin
    .from('staged_rate_candidates')
    .select('*')
    .eq('bank_code', 'BOB')
    .eq('staging_status', 'DRAFT');

  if (error) throw error;
  console.log(`Found ${drafts.length} remaining DRAFT BOB candidates to promote`);

  const promoService = new PromotionService();

  for (const c of drafts) {
    console.log(`Promoting ${c.tenure_label} (${c.customer_type})...`);
    const res = await promoService.promoteCandidate({
      candidate: c,
      actorType: 'ADMIN',
      actorId: ADMIN_USER_ID,
      reason: 'Official Bank of Baroda baseline attestation and promotion',
      context: { isBaselineAttested: true },
    });

    if (!res.promoted) {
      throw new Error(`Promotion failed for ${c.tenure_label}: ${res.reason || JSON.stringify(res.policyResult)}`);
    }

    await supabaseAdmin
      .from('staged_rate_candidates')
      .update({
        staging_status: 'PROMOTED',
        promoted_rate_id: res.newVerifiedRate.id,
        promoted_at: new Date().toISOString(),
        promoted_by: ADMIN_USER_ID,
      })
      .eq('id', c.id);

    console.log(`  -> Promoted! Verified rate ID: ${res.newVerifiedRate.id}`);
  }

  // Post-promotion check
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

  console.log('\n--- Final Verified Rates Summary in Staging ---');
  console.log('Total verified rates:', verifiedRates.length);
  console.log('Counts by bank:', counts);

  if (counts['BOB'] !== 30) throw new Error(`Expected 30 BOB rates, found ${counts['BOB']}`);
  if (counts['ICICI'] !== 26) throw new Error(`Expected 26 ICICI rates, found ${counts['ICICI']}`);
  if (counts['SBI'] !== 16) throw new Error(`Expected 16 SBI rates, found ${counts['SBI']}`);
  if (counts['HDFC'] !== 8) throw new Error(`Expected 8 HDFC rates, found ${counts['HDFC']}`);
  if (verifiedRates.length !== 80) throw new Error(`Expected 80 total verified rates, found ${verifiedRates.length}`);

  console.log('\nSUCCESS: All 30 BOB rates fully verified and promoted in staging!');
}

main().catch(err => {
  console.error('FAILED:', err);
  process.exit(1);
});
