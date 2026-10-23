// FeroCalc Verified FD Rate Engine — Pipeline Orchestrator & Scheduler Service
//
// End-to-end orchestration of scheduled and manual rate updates:
// Lock -> Collect -> Filter Unchanged (Heartbeat) -> Extract -> Validate ->
// Anomaly Detect -> Diff -> Promotion Policy -> Staging/Promotion ->
// Source Health -> Audit Run -> Low-Noise Alerting -> Unlock.
//
// Safety Guarantees:
// 1. Full Idempotency: Duplicate runs with identical data never produce duplicate active verified records.
// 2. Persistent Job Locking: Prevents overlapping executions with lease-based stale recovery.
// 3. Batch Resilience: A failure in one bank never aborts processing of other banks.
// 4. Low-Noise Heartbeat: Unchanged sources produce 0 candidate mutations and 0 alerts.
// 5. Zero Unauthorized Promotion: Dry-run never promotes; automated runs strictly require 100% policy compliance.
// 6. Non-Destructive: Source errors or stale sources NEVER delete active verified rates.

'use strict';

const crypto = require('crypto');
const { RateCollectionService } = require('../collectors/collection_service');
const { defaultRegistry } = require('../collectors/source_registry');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { PromotionService } = require('../promotion/promotion_service');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { JobLockManager } = require('../monitoring/job_lock_manager');
const { SourceHealthMonitor } = require('../monitoring/source_health_monitor');
const { AlertNotifier, SEVERITY_LEVELS, ALERT_TYPES } = require('../monitoring/alert_notifier');
const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');

class PipelineSchedulerService {
  constructor(options = {}) {
    this.logger = options.logger || console;
    this.notifier = options.notifier || new AlertNotifier({ logger: this.logger });
    this.lockManager = options.lockManager || new JobLockManager({
      logger: this.logger,
      allowInMemoryFallback: options.allowInMemoryFallback ?? true,
    });
    this.healthMonitor = options.healthMonitor || new SourceHealthMonitor({
      notifier: this.notifier,
      logger: this.logger,
    });
    this.collectionService = options.collectionService || new RateCollectionService();
    this.diffEngine = options.diffEngine || new RateDiffEngine();
    this.policyEngine = options.policyEngine || new PromotionPolicyEngine();
    this.promotionService = options.promotionService || new PromotionService({
      diffEngine: this.diffEngine,
      policyEngine: this.policyEngine,
      logger: this.logger,
      inMemoryRates: options.inMemoryRates,
      inMemoryAuditLogs: options.inMemoryAuditLogs,
    });
    this.stagingService = options.stagingService || new CandidateStagingService({
      logger: this.logger,
    });

    // In-memory run log for testing/offline environments
    this._inMemoryRuns = options.inMemoryRuns || [];
  }

  /**
   * Generates a unique, deterministic job ID.
   */
  generateJobId(triggerType = 'MANUAL') {
    const timestamp = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
    const entropy = crypto.randomBytes(3).toString('hex');
    return `job_${triggerType.toLowerCase()}_${timestamp}_${entropy}`;
  }

  /**
   * Executes the full rate pipeline.
   *
   * @param {Object} [params]
   * @param {string} [params.jobId]
   * @param {'CRON'|'MANUAL'|'API'} [params.triggerType='MANUAL']
   * @param {boolean} [params.dryRun=false]
   * @param {Array<Object>} [params.sources]
   * @param {boolean} [params.forceReExtract=false]
   * @param {boolean} [params.skipLock=false] - Testing only
   * @returns {Promise<Object>} Execution report
   */
  async executePipeline(params = {}) {
    const triggerType = params.triggerType || 'MANUAL';
    const jobId = params.jobId || this.generateJobId(triggerType);
    const dryRun = Boolean(params.dryRun);
    const forceReExtract = Boolean(params.forceReExtract);
    const sourcesToProcess = params.sources || defaultRegistry.getEnabledSources();

    const startedAt = new Date();
    this.logger.log(`[RatePipeline] Starting execution ${jobId} (Trigger: ${triggerType}, DryRun: ${dryRun}, Sources: ${sourcesToProcess.length})`);

    // 1. Acquire Distributed Job Lock
    if (!params.skipLock) {
      const lockResult = await this.lockManager.acquireLock(jobId);
      if (!lockResult.acquired) {
        this.logger.warn(`[RatePipeline] Lock denied for ${jobId}: ${lockResult.reason}`);
        
        await this.notifier.notify({
          severity: SEVERITY_LEVELS.WARNING,
          jobId,
          failureType: ALERT_TYPES.JOB_LOCK_COLLISION,
          recommendedAction: 'Verify if a previous pipeline run is still active or release stale lock.',
          message: lockResult.reason,
        });

        // Record locked run attempt
        await this._recordRunAudit({
          jobId,
          startedAt: startedAt.toISOString(),
          finishedAt: new Date().toISOString(),
          durationMs: 0,
          status: 'LOCKED',
          triggerType,
          isDryRun: dryRun,
          sourceCount: sourcesToProcess.length,
          successCount: 0,
          failureCount: 0,
          changedCount: 0,
          extractedCount: 0,
          promotedCount: 0,
          reviewCount: 0,
          invalidCount: 0,
          errorSummary: lockResult.reason,
          metadata: { lockResult },
        });

        return {
          success: false,
          status: 'LOCKED',
          jobId,
          reason: lockResult.reason,
        };
      }
    }

    // 2. Initialize Audit Record
    await this._recordRunAudit({
      jobId,
      startedAt: startedAt.toISOString(),
      finishedAt: null,
      status: 'RUNNING',
      triggerType,
      isDryRun: dryRun,
      sourceCount: sourcesToProcess.length,
      successCount: 0,
      failureCount: 0,
      changedCount: 0,
      extractedCount: 0,
      promotedCount: 0,
      reviewCount: 0,
      invalidCount: 0,
      errorSummary: null,
      metadata: {},
    });

    const runSummary = {
      jobId,
      triggerType,
      dryRun,
      startedAt: startedAt.toISOString(),
      sourceCount: sourcesToProcess.length,
      successCount: 0,
      failureCount: 0,
      changedCount: 0,
      extractedCount: 0,
      promotedCount: 0,
      reviewCount: 0,
      invalidCount: 0,
      unchangedCount: 0,
      sourceResults: [],
      errors: [],
    };

    try {
      // 3. Process Each Source (Resilient batch execution)
      for (const source of sourcesToProcess) {
        const sourceResult = await this._processSingleSource({
          source,
          jobId,
          dryRun,
          forceReExtract,
        });

        runSummary.sourceResults.push(sourceResult);

        if (sourceResult.status === 'SUCCESS' || sourceResult.status === 'UNCHANGED') {
          runSummary.successCount++;
        } else {
          runSummary.failureCount++;
          if (sourceResult.error) {
            runSummary.errors.push(`${source.bankCode}: ${sourceResult.error}`);
          }
        }

        if (sourceResult.changed) runSummary.changedCount++;
        if (sourceResult.status === 'UNCHANGED') runSummary.unchangedCount++;
        runSummary.extractedCount += sourceResult.extractedCount || 0;
        runSummary.promotedCount += sourceResult.promotedCount || 0;
        runSummary.reviewCount += sourceResult.reviewCount || 0;
        runSummary.invalidCount += sourceResult.invalidCount || 0;
      }

      // 4. Stale Monitoring Check across all sources
      await this.healthMonitor.evaluateAllSources(sourcesToProcess, jobId);

      // 5. Finalize Status
      const finishedAt = new Date();
      runSummary.finishedAt = finishedAt.toISOString();
      runSummary.durationMs = finishedAt.getTime() - startedAt.getTime();

      let finalStatus = 'SUCCESS';
      if (runSummary.failureCount > 0 && runSummary.successCount > 0) {
        finalStatus = 'PARTIAL_SUCCESS';
      } else if (runSummary.failureCount > 0 && runSummary.successCount === 0) {
        finalStatus = 'FAILED';
      }
      runSummary.status = finalStatus;

      // 6. Update Persistent Audit Record
      await this._updateRunAudit(runSummary);

      this.logger.log(`[RatePipeline] Execution finished ${jobId} -> ${finalStatus} in ${runSummary.durationMs}ms`);
      return runSummary;

    } catch (unexpectedError) {
      this.logger.error(`[RatePipeline] Unexpected fatal pipeline error in ${jobId}: ${unexpectedError.message}`);

      await this.notifier.notify({
        severity: SEVERITY_LEVELS.CRITICAL,
        jobId,
        failureType: ALERT_TYPES.SCHEDULER_FAILURE,
        recommendedAction: 'Investigate uncaught scheduler exception and system health.',
        message: unexpectedError.message,
      });

      const finishedAt = new Date();
      runSummary.finishedAt = finishedAt.toISOString();
      runSummary.durationMs = finishedAt.getTime() - startedAt.getTime();
      runSummary.status = 'FAILED';
      runSummary.errors.push(unexpectedError.message);
      await this._updateRunAudit(runSummary);

      return runSummary;

    } finally {
      // 7. Guaranteed Lock Release
      if (!params.skipLock) {
        await this.lockManager.releaseLock(jobId);
      }
    }
  }

  /**
   * Processes a single source end-to-end.
   */
  async _processSingleSource({ source, jobId, dryRun, forceReExtract }) {
    const result = {
      sourceId: source.id,
      bankCode: source.bankCode,
      sourceUrl: source.sourceUrl,
      status: 'PENDING',
      changed: false,
      extractedCount: 0,
      promotedCount: 0,
      reviewCount: 0,
      invalidCount: 0,
      unchangedRatesCount: 0,
      error: null,
    };

    try {
      // Step A: Fetch & Collect
      const collectionResult = await this.collectionService.collectSource(source, {
        timeoutMs: 15000,
        maxRetries: 2,
      });

      // Update source health
      const healthState = await this.healthMonitor.recordCollectionOutcome(source, collectionResult, jobId);
      result.healthStatus = healthState.healthStatus;
      result.httpStatus = collectionResult.httpStatus;
      result.contentHash = collectionResult.contentHash;

      if (collectionResult.status === 'FETCH_FAILED') {
        result.status = 'FETCH_FAILED';
        result.error = collectionResult.error || 'Source HTTP fetch failed';
        // Guaranteed safety: existing verified rates preserved
        await this.promotionService.handleSourceFailure(source.id, source.bankCode, new Error(result.error));
        return result;
      }

      // Step B: Heartbeat / Unchanged Source Handling
      if (collectionResult.status === 'UNCHANGED' && !forceReExtract) {
        result.status = 'UNCHANGED';
        result.changed = false;
        result.message = 'Source hash unchanged (routine heartbeat)';
        return result;
      }

      // Step C: Changed or First-Seen Source -> Parse & Stage
      result.changed = true;
      const stageResult = await this.stagingService.processCollectionResult(collectionResult, {
        forceReExtract,
        skipDbPersist: dryRun, // Do not persist candidates during dry-run
        lockManager: this.lockManager,
        jobId,
      });

      if (!stageResult.extracted || stageResult.status === 'EXTRACTION_FAILED') {
        result.status = 'EXTRACTION_FAILED';
        result.error = stageResult.message || 'Parser produced 0 candidates';
        
        await this.notifier.notify({
          severity: SEVERITY_LEVELS.ERROR,
          bank: source.bankCode,
          sourceId: source.id,
          jobId,
          failureType: ALERT_TYPES.PARSER_ZERO_RESULTS,
          recommendedAction: `Inspect parser ${stageResult.parserId || source.parserId} for HTML layout changes.`,
          message: result.error,
        });

        return result;
      }

      const candidates = stageResult.candidates || [];
      result.extractedCount = candidates.length;

      // Check anomalies
      if (stageResult.anomalies && stageResult.anomalies.candidatesWithAnomalies > 0) {
        for (const flag of stageResult.anomalies.anomalyFlags || []) {
          const alertType = flag.includes('COUNT')
            ? ALERT_TYPES.ANOMALY_COUNT_MISMATCH
            : ALERT_TYPES.ANOMALY_MISSING_TENURE;

          await this.notifier.notify({
            severity: SEVERITY_LEVELS.WARNING,
            bank: source.bankCode,
            sourceId: source.id,
            jobId,
            failureType: alertType,
            affectedCandidateCount: stageResult.anomalies.candidatesWithAnomalies,
            recommendedAction: 'Verify bank deposit table structure before approving candidates.',
            message: `Batch anomaly detected: ${flag}`,
          });
        }
      }

      // Step D: Evaluate Candidates against Active Verified Rates
      const activeVerifiedRates = await this.promotionService._getActiveVerifiedRates(source.bankCode);

      for (const candidate of candidates) {
        // Compute diff
        const diff = this.diffEngine.diffCandidate(candidate, activeVerifiedRates);

        // Idempotency & Redesign Protection:
        // If the rate is UNCHANGED vs active verified record, DO NOT duplicate promotion!
        if (diff.diffType === DIFF_TYPES.UNCHANGED) {
          result.unchangedRatesCount++;
          candidate.stagingStatus = 'DRAFT';
          continue;
        }

        // Real rate change or new tenure bucket -> Evaluate Promotion Policy
        const policyResult = this.policyEngine.evaluateCandidate(candidate, diff, {
          httpStatus: collectionResult.httpStatus,
          fetchStatus: collectionResult.status,
          parserSuccess: true,
          sourceContentHash: collectionResult.contentHash,
          sourceUrl: source.sourceUrl,
        });

        if (dryRun) {
          // Dry-run mode: Never promote!
          if (policyResult.eligibleForAutoPromotion) {
            result.promotedCount++; // Simulated
          } else if (policyResult.recommendedAction === 'INVALID') {
            result.invalidCount++;
          } else {
            result.reviewCount++;
          }
          continue;
        }

        // Live Execution Mode:
        if (policyResult.eligibleForAutoPromotion) {
          const promoRes = await this.promotionService.promoteCandidate({
            candidate,
            actorType: 'AUTOMATED_POLICY',
            actorId: `SCHEDULER_${jobId}`,
            reason: policyResult.decisionReason,
            activeVerifiedRates,
            context: { jobId },
          });

          if (promoRes.promoted) {
            result.promotedCount++;
            // Update local active rates for subsequent candidates in same batch
            const idx = activeVerifiedRates.findIndex(r => r.id === (diff.previousRecord && diff.previousRecord.id));
            if (idx >= 0) {
              activeVerifiedRates[idx] = promoRes.newVerifiedRate;
            } else {
              activeVerifiedRates.push(promoRes.newVerifiedRate);
            }
          } else {
            result.reviewCount++;
          }
        } else if (policyResult.recommendedAction === 'INVALID') {
          result.invalidCount++;
          candidate.stagingStatus = 'INVALID';
        } else {
          // Escalated to IN_REVIEW
          result.reviewCount++;
          candidate.stagingStatus = 'IN_REVIEW';

          await this.notifier.notify({
            severity: SEVERITY_LEVELS.WARNING,
            bank: source.bankCode,
            sourceId: source.id,
            jobId,
            failureType: ALERT_TYPES.CANDIDATE_IN_REVIEW,
            affectedCandidateCount: 1,
            recommendedAction: 'Log in to Admin Review Queue (/api/admin/staged-candidates) to review or approve.',
            message: `Candidate held in IN_REVIEW: ${policyResult.decisionReason}`,
            details: { candidateId: candidate.id, tenure: candidate.tenureLabel, rate: candidate.interestRate },
          });
        }
      }

      result.status = 'SUCCESS';
      return result;

    } catch (err) {
      result.status = 'ERROR';
      result.error = err.message;
      return result;
    }
  }

  // ----------------------------------------------------------------
  // Audit Helpers
  // ----------------------------------------------------------------

  async _recordRunAudit(runRecord) {
    this._inMemoryRuns.push(runRecord);

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin.from('rate_pipeline_runs').insert([{
          job_id: runRecord.jobId,
          started_at: runRecord.startedAt,
          finished_at: runRecord.finishedAt,
          status: runRecord.status,
          trigger_type: runRecord.triggerType,
          is_dry_run: runRecord.isDryRun,
          source_count: runRecord.sourceCount,
          success_count: runRecord.successCount,
          failure_count: runRecord.failureCount,
          changed_count: runRecord.changedCount,
          extracted_count: runRecord.extractedCount,
          promoted_count: runRecord.promotedCount,
          review_count: runRecord.reviewCount,
          invalid_count: runRecord.invalidCount,
          error_summary: runRecord.errorSummary,
          metadata: runRecord.metadata || {},
        }]);
      } catch (err) {
        this.logger.warn(`Failed to insert pipeline run audit: ${err.message}`);
      }
    }
  }

  async _updateRunAudit(summary) {
    const memoryIndex = this._inMemoryRuns.findIndex(r => r.jobId === summary.jobId);
    if (memoryIndex >= 0) {
      this._inMemoryRuns[memoryIndex] = { ...this._inMemoryRuns[memoryIndex], ...summary };
    }

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin
          .from('rate_pipeline_runs')
          .update({
            finished_at: summary.finishedAt,
            duration_ms: summary.durationMs,
            status: summary.status,
            success_count: summary.successCount,
            failure_count: summary.failureCount,
            changed_count: summary.changedCount,
            extracted_count: summary.extractedCount,
            promoted_count: summary.promotedCount,
            review_count: summary.reviewCount,
            invalid_count: summary.invalidCount,
            error_summary: summary.errors.length > 0 ? summary.errors.join('; ') : null,
            metadata: { sourceResults: summary.sourceResults },
          })
          .eq('job_id', summary.jobId);
      } catch (err) {
        this.logger.warn(`Failed to update pipeline run audit: ${err.message}`);
      }
    }
  }

  /**
   * Helper to retrieve run audit records.
   */
  async getRunAudit(jobId) {
    const inMem = this._inMemoryRuns.find(r => r.jobId === jobId);
    if (inMem) return inMem;

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        const { data } = await supabaseAdmin
          .from('rate_pipeline_runs')
          .select('*')
          .eq('job_id', jobId)
          .maybeSingle();
        return data;
      } catch {
        return null;
      }
    }
    return null;
  }
}

module.exports = {
  PipelineSchedulerService,
};
