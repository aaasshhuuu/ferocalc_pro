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
    this.supabaseClient = options.supabaseClient || null;
    this.promotionService = options.promotionService || new PromotionService({
      diffEngine: this.diffEngine,
      policyEngine: this.policyEngine,
      logger: this.logger,
      supabaseClient: this.supabaseClient,
      inMemoryRates: options.inMemoryRates,
      inMemoryAuditLogs: options.inMemoryAuditLogs,
    });
    this.stagingService = options.stagingService || new CandidateStagingService({
      logger: this.logger,
      supabaseClient: this.supabaseClient,
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
    let sourcesToProcess = params.sources;
    if (!sourcesToProcess) {
      if (isSupabaseAvailable() && supabaseAdmin) {
        try {
          const { data: dbSources, error: dbErr } = await supabaseAdmin
            .from('rate_sources')
            .select('id, is_enabled')
            .eq('is_enabled', true);
          if (!dbErr && Array.isArray(dbSources) && dbSources.length > 0) {
            const enabledSet = new Set(dbSources.map(d => d.id));
            sourcesToProcess = defaultRegistry.getAllSources()
              .filter(s => enabledSet.has(s.id))
              .map(s => ({ ...s, enabled: true }));
          }
        } catch (fetchErr) {
          this.logger.warn(`[RatePipeline] Failed to load enabled sources from database, falling back to defaultRegistry: ${fetchErr.message}`);
        }
      }
      if (!sourcesToProcess || sourcesToProcess.length === 0) {
        sourcesToProcess = defaultRegistry.getEnabledSources();
      }
    } else {
      sourcesToProcess = sourcesToProcess.filter(s => s.enabled === true || s.isEnabled === true);
    }

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
      reconciledStaleReviewCount: 0,
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
        runSummary.reconciledStaleReviewCount += sourceResult.reconciledStaleReviewCount || 0;
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
      reconciledStaleReviewCount: 0,
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

          // Safe Stale Tenure-Anomaly Reconciliation (Phase 4.1)
          const reconcileRes = await this._reconcileCandidateReviewStatus({
            candidate,
            diff,
            stageResult,
            dryRun,
          });

          if (reconcileRes.error) {
            result.status = 'ERROR';
            result.error = reconcileRes.error;
            return result;
          }

          if (reconcileRes.reconciled) {
            result.reconciledStaleReviewCount++;
          }
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
          candidate.staging_status = 'IN_REVIEW';

          // Persist staging_status = 'IN_REVIEW' to staged_rate_candidates if database client is available
          const candId = candidate.id || candidate.stagedCandidateId || candidate._candidate_id;
          const db = this.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);
          if (candId && db) {
            try {
              const { error: updateErr } = await db
                .from('staged_rate_candidates')
                .update({ staging_status: 'IN_REVIEW' })
                .eq('id', candId);

              if (updateErr) {
                this.logger.error(`[PipelineSchedulerService] Failed to persist IN_REVIEW status for candidate ${candId}: ${updateErr.message}`);
                result.status = 'ERROR';
                result.error = `Failed to persist candidate IN_REVIEW status: ${updateErr.message}`;
                return result;
              }
            } catch (dbErr) {
              this.logger.error(`[PipelineSchedulerService] Exception persisting IN_REVIEW status for candidate ${candId}: ${dbErr.message}`);
              result.status = 'ERROR';
              result.error = `Exception persisting candidate IN_REVIEW status: ${dbErr.message}`;
              return result;
            }
          }

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
  /**
   * Safe reconciliation of obsolete ANOMALY_TENURE_DISAPPEARED review flags (Phase 4.1).
   *
   * Rules:
   * 1. Reconcile only an existing candidate confirmed UNCHANGED against active verified baseline.
   * 2. Clear only obsolete ANOMALY_TENURE_DISAPPEARED when fresh extraction proves tenure buckets present.
   * 3. Change IN_REVIEW to DRAFT only when:
   *    - validation_status is VALID;
   *    - the only anomaly is the specifically reconciled tenure-disappeared flag;
   *    - candidate is unchanged;
   *    - no other manual or policy review reason exists.
   * 4. Preserve all unrelated anomaly flags and review statuses.
   * 5. Zero database writes during dry-run.
   * 6. Fails closed on database errors.
   * 7. Idempotent on repeated runs.
   *
   * @param {Object} params
   * @param {Object} params.candidate - Freshly extracted candidate
   * @param {Object} params.diff - RateDiffEngine result
   * @param {Object} params.stageResult - Extraction and anomaly summary for the batch
   * @param {boolean} params.dryRun - Whether pipeline is running in dry-run mode
   * @returns {Promise<{ reconciled: boolean, error?: string }>}
   */
  async _reconcileCandidateReviewStatus(params = {}) {
    const { candidate, diff, stageResult, dryRun } = params;
    if (!candidate || diff?.diffType !== DIFF_TYPES.UNCHANGED) {
      return { reconciled: false };
    }

    const candId = candidate.id || candidate.stagedCandidateId || candidate._candidate_id;
    const db = this.supabaseClient || (isSupabaseAvailable() ? supabaseAdmin : null);

    // Inspect existing persisted candidate record
    let existingRow = candidate._matchedRow || null;
    if (!existingRow && candId && db && typeof db.from === 'function') {
      try {
        const query = db.from('staged_rate_candidates');
        if (query && typeof query.select === 'function') {
          const { data, error: fetchErr } = await query
            .select('id, bank_code, staging_status, validation_status, anomaly_flags, notes')
            .eq('id', candId)
            .maybeSingle();

          if (fetchErr) {
            this.logger.error(`[PipelineSchedulerService] Failed to query candidate ${candId} for reconciliation: ${fetchErr.message}`);
            return { reconciled: false, error: `Failed to query candidate for reconciliation: ${fetchErr.message}` };
          }
          if (data) {
            existingRow = data;
            candidate._matchedRow = data;
          }
        }
      } catch (err) {
        this.logger.error(`[PipelineSchedulerService] Exception querying candidate ${candId} for reconciliation: ${err.message}`);
        return { reconciled: false, error: `Exception querying candidate for reconciliation: ${err.message}` };
      }
    }

    // Determine original status and validation status safely
    const originalStatus = (existingRow && existingRow.staging_status)
      || candidate.stagingStatus
      || candidate.staging_status
      || 'DRAFT';

    const validationStatus = (existingRow && existingRow.validation_status)
      || candidate.validationStatus
      || candidate.validation_status
      || 'VALID';

    // Requirement 5: Invalid candidates must not transition to DRAFT
    if (validationStatus !== 'VALID') {
      candidate.stagingStatus = 'INVALID';
      candidate.staging_status = 'INVALID';
      return { reconciled: false, status: 'INVALID' };
    }

    // Requirement 6: Dry-run must preserve every original status and perform zero database writes
    if (dryRun) {
      candidate.stagingStatus = originalStatus;
      candidate.staging_status = originalStatus;
      return { reconciled: false, status: originalStatus };
    }

    if (!candId || !db) {
      candidate.stagingStatus = originalStatus;
      candidate.staging_status = originalStatus;
      return { reconciled: false, status: originalStatus };
    }

    if (!existingRow) {
      candidate.stagingStatus = originalStatus;
      candidate.staging_status = originalStatus;
      return { reconciled: false, status: originalStatus };
    }

    // Idempotent: If not IN_REVIEW, preserve status and no action needed
    if (existingRow.staging_status !== 'IN_REVIEW') {
      candidate.stagingStatus = existingRow.staging_status;
      candidate.staging_status = existingRow.staging_status;
      return { reconciled: false, status: existingRow.staging_status };
    }

    // Requirement 3: Manual MANUAL_REVIEW holds must remain IN_REVIEW
    const notesStr = (existingRow.notes && typeof existingRow.notes === 'string')
      ? existingRow.notes
      : (candidate.notes && typeof candidate.notes === 'string' ? candidate.notes : '');
    if (notesStr.includes('MANUAL_REVIEW')) {
      candidate.stagingStatus = 'IN_REVIEW';
      candidate.staging_status = 'IN_REVIEW';
      return { reconciled: false, status: 'IN_REVIEW' };
    }

    // Rule 3: Current extraction must prove tenure buckets are present (clean batch)
    const currentBatchFlags = stageResult?.anomalies?.flags || [];
    const candidateFlags = candidate.anomalyFlags || [];
    const currentHasTenureDisappeared =
      currentBatchFlags.some(f => typeof f === 'string' && f.includes('ANOMALY_TENURE_DISAPPEARED')) ||
      candidateFlags.some(f => typeof f === 'string' && f.includes('ANOMALY_TENURE_DISAPPEARED'));

    if (currentHasTenureDisappeared) {
      candidate.stagingStatus = 'IN_REVIEW';
      candidate.staging_status = 'IN_REVIEW';
      return { reconciled: false, status: 'IN_REVIEW' };
    }

    const existingFlags = Array.isArray(existingRow.anomaly_flags) ? existingRow.anomaly_flags : [];
    const hasStaleTenureAnomaly = existingFlags.some(f => typeof f === 'string' && f.includes('ANOMALY_TENURE_DISAPPEARED'));

    if (!hasStaleTenureAnomaly) {
      candidate.stagingStatus = 'IN_REVIEW';
      candidate.staging_status = 'IN_REVIEW';
      return { reconciled: false, status: 'IN_REVIEW' };
    }

    // Rule 3: Clear only the obsolete ANOMALY_TENURE_DISAPPEARED flag
    const remainingFlags = existingFlags.filter(f => !(typeof f === 'string' && f.includes('ANOMALY_TENURE_DISAPPEARED')));

    // Requirement 4: If there are additional anomalies, preserve IN_REVIEW and only clear the obsolete tenure flag
    if (remainingFlags.length > 0) {
      try {
        const { error: updateErr } = await db
          .from('staged_rate_candidates')
          .update({
            anomaly_flags: remainingFlags,
            updated_at: new Date().toISOString(),
          })
          .eq('id', candId);

        if (updateErr) {
          this.logger.error(`[PipelineSchedulerService] Failed to update anomaly flags for candidate ${candId}: ${updateErr.message}`);
          return { reconciled: false, error: `Failed to update anomaly flags: ${updateErr.message}` };
        }

        existingRow.anomaly_flags = remainingFlags;
        candidate.anomalyFlags = remainingFlags;
        candidate.anomaly_flags = remainingFlags;
        candidate.stagingStatus = 'IN_REVIEW';
        candidate.staging_status = 'IN_REVIEW';
        return { reconciled: false, status: 'IN_REVIEW' };
      } catch (err) {
        this.logger.error(`[PipelineSchedulerService] Exception updating anomaly flags for candidate ${candId}: ${err.message}`);
        return { reconciled: false, error: `Exception updating anomaly flags: ${err.message}` };
      }
    }

    // Requirement 1: All criteria satisfied - change IN_REVIEW to DRAFT and clear anomaly_flags
    try {
      const { error: updateErr } = await db
        .from('staged_rate_candidates')
        .update({
          staging_status: 'DRAFT',
          anomaly_flags: [],
          updated_at: new Date().toISOString(),
        })
        .eq('id', candId);

      if (updateErr) {
        this.logger.error(`[PipelineSchedulerService] Failed to reconcile candidate ${candId} to DRAFT: ${updateErr.message}`);
        return { reconciled: false, error: `Failed to reconcile candidate: ${updateErr.message}` };
      }

      existingRow.staging_status = 'DRAFT';
      existingRow.anomaly_flags = [];
      candidate.stagingStatus = 'DRAFT';
      candidate.staging_status = 'DRAFT';
      candidate.anomalyFlags = [];
      candidate.anomaly_flags = [];

      return { reconciled: true, status: 'DRAFT' };
    } catch (err) {
      this.logger.error(`[PipelineSchedulerService] Exception reconciling candidate ${candId}: ${err.message}`);
      return { reconciled: false, error: `Exception reconciling candidate: ${err.message}` };
    }
  }

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
            metadata: { sourceResults: summary.sourceResults, reconciledStaleReviewCount: summary.reconciledStaleReviewCount || 0 },
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
