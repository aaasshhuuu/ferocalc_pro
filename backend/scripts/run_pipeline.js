// FeroCalc Verified FD Rate Engine — Manual Pipeline CLI Runner
//
// Triggers the end-to-end collection, extraction, validation, diff, and safe promotion pipeline.
//
// Usage:
//   npm run rates:run
//   npm run rates:run -- --dry-run
//   npm run rates:run -- --force

'use strict';

const { loadEnv } = require('../env_loader');
loadEnv();

const { PipelineSchedulerService } = require('../scheduling/pipeline_scheduler_service');

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const forceReExtract = args.includes('--force');

  console.log('====================================================');
  console.log(' FeroCalc FD Rate Automation Pipeline (Phase 3B)    ');
  console.log('====================================================');
  console.log(`Mode:            ${isDryRun ? 'DRY-RUN (Zero mutations or promotions)' : 'LIVE EXECUTION'}`);
  console.log(`Force Re-Extract: ${forceReExtract ? 'YES' : 'NO'}`);
  console.log(`Started At:      ${new Date().toISOString()}\n`);

  const scheduler = new PipelineSchedulerService();

  try {
    const summary = await scheduler.executePipeline({
      triggerType: 'MANUAL',
      dryRun: isDryRun,
      forceReExtract,
    });

    console.log('\n====================================================');
    console.log('               PIPELINE RUN SUMMARY                 ');
    console.log('====================================================');
    console.log(`Job ID:              ${summary.jobId}`);
    console.log(`Final Status:        ${summary.status}`);
    console.log(`Trigger:             ${summary.triggerType}`);
    console.log(`Dry Run:             ${summary.dryRun}`);
    console.log(`Duration:            ${summary.durationMs || 0} ms`);
    console.log(`Sources Processed:   ${summary.sourceCount}`);
    console.log(`  - Succeeded:       ${summary.successCount}`);
    console.log(`  - Failed:          ${summary.failureCount}`);
    console.log(`  - Changed:         ${summary.changedCount}`);
    console.log(`  - Unchanged:       ${summary.unchangedCount}`);
    console.log(`Candidates:`);
    console.log(`  - Extracted:       ${summary.extractedCount}`);
    console.log(`  - Promoted:        ${summary.promotedCount}`);
    console.log(`  - In Review:       ${summary.reviewCount}`);
    console.log(`  - Invalid:         ${summary.invalidCount}`);

    console.log('\nPer-Source Breakdown:');
    for (const src of summary.sourceResults || []) {
      console.log(`  [${src.bankCode}] (${src.sourceId}):`);
      console.log(`     Status:         ${src.status}`);
      console.log(`     Health:         ${src.healthStatus || 'N/A'}`);
      console.log(`     HTTP Code:      ${src.httpStatus || 'N/A'}`);
      console.log(`     Changed:        ${src.changed}`);
      console.log(`     Extracted:      ${src.extractedCount}`);
      console.log(`     Promoted:       ${src.promotedCount}`);
      console.log(`     In Review:      ${src.reviewCount}`);
      console.log(`     Unchanged Rates:${src.unchangedRatesCount}`);
      if (src.error) {
        console.log(`     Error:          ${src.error}`);
      }
    }

    if (summary.errors && summary.errors.length > 0) {
      console.log('\nPipeline Errors:');
      summary.errors.forEach(e => console.log(`  ! ${e}`));
    }

    console.log('\n----------------------------------------------------');
    if (isDryRun) {
      console.log('DRY RUN COMPLETE: Zero records written to production.');
    } else {
      console.log('EXECUTION COMPLETE: All actions logged with full audit trail.');
    }
    console.log('----------------------------------------------------');

    return summary;

  } catch (err) {
    console.error('Fatal CLI execution error:', err);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = { main };
