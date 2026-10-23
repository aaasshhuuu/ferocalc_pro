#!/usr/bin/env node
// FeroCalc Verified FD Rate Engine — Manual Collection Runner
//
// Usage:
//   npm run collect:rates
//   node backend/scripts/run_collector.js

'use strict';

const { loadEnv } = require('../env_loader');
loadEnv();
const { RateCollectionService } = require('../collectors/collection_service');

async function main() {
  console.log('====================================================');
  console.log(' FeroCalc FD Rate Source Collector (Phase 1)        ');
  console.log('====================================================');
  console.log('Mode: READ ONLY (Change Detection & Snapshot Hashing)');
  console.log('Auto-Publish: DISABLED (No rates marked VERIFIED)    \n');

  const service = new RateCollectionService();
  const startTime = Date.now();

  const { results, summary } = await service.collectAllEnabledSources();
  const totalDuration = ((Date.now() - startTime) / 1000).toFixed(2);

  console.log('\n--- Collection Results ---');
  for (const r of results) {
    const statusIcon = r.status === 'FETCH_FAILED' ? '❌' : (r.changed ? '🔄' : '✅');
    console.log(`[${statusIcon} ${r.status}] ${r.bankCode} (${r.sourceId})`);
    console.log(`   URL:      ${r.sourceUrl}`);
    console.log(`   HTTP:     ${r.httpStatus || 'N/A'}`);
    console.log(`   Duration: ${r.fetchDurationMs}ms`);
    console.log(`   Hash:     ${r.contentHash ? r.contentHash.slice(0, 16) + '...' : 'NONE'}`);
    if (r.error) {
      console.log(`   Error:    ${r.error}`);
    }
  }

  console.log('\n----------------------------------------------------');
  console.log(`Finished in ${totalDuration}s`);
  console.log(`Summary: Total: ${summary.total} | First-seen: ${summary.firstSeen} | Unchanged: ${summary.unchanged} | Changed: ${summary.changed} | Failed: ${summary.failed}`);
  console.log('----------------------------------------------------\n');
}

main().catch((err) => {
  console.error('Collector runner encountered unexpected error:', err);
  process.exit(1);
});
