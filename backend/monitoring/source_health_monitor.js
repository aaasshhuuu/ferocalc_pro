// FeroCalc Verified FD Rate Engine — Source Health & Stale Monitor
//
// Evaluates rate source operational health, consecutive failures, and staleness.
//
// Safety Guarantees:
// 1. One transient failure never marks a source FAILING or DEGRADED.
// 2. Stale sources NEVER delete or remove active verified rates.
// 3. Successful heartbeats cleanly reset consecutive failures and stale risk.
// 4. Configurable stale thresholds (24h WARNING, 48h STALE_RISK, 7d STALE).

'use strict';

const { supabaseAdmin, isSupabaseAvailable } = require('../supabase/supabase_client');
const { SEVERITY_LEVELS, ALERT_TYPES } = require('./alert_notifier');

const HEALTH_STATES = {
  HEALTHY: 'HEALTHY',
  DEGRADED: 'DEGRADED',
  FAILING: 'FAILING',
  STALE_RISK: 'STALE_RISK',
};

const DEFAULT_THRESHOLDS = {
  warningHours: 24,       // 24h without success -> Warning alert
  staleRiskHours: 48,     // 48h without success -> DEGRADED / STALE_RISK
  staleDays: 7,           // 7 days without success -> STALE (CRITICAL)
  failureThresholdDegraded: 2, // 2 consecutive failures -> DEGRADED
  failureThresholdFailing: 4,  // 4 consecutive failures -> FAILING
};

class SourceHealthMonitor {
  constructor(options = {}) {
    this.thresholds = { ...DEFAULT_THRESHOLDS, ...options.thresholds };
    this.notifier = options.notifier || null;
    this.logger = options.logger || console;

    // In-memory registry for testing or offline environments
    this._inMemoryHealth = new Map();
  }

  /**
   * Evaluates and updates the health status of a source after a collection attempt.
   *
   * @param {Object} source - Source definition
   * @param {Object} collectionResult - Outcome from RateCollector.collect()
   * @param {string} jobId - Pipeline job ID
   * @returns {Promise<Object>} Updated health state
   */
  async recordCollectionOutcome(source, collectionResult, jobId = 'N/A') {
    const sourceId = source.id;
    const now = new Date();
    const currentState = await this.getSourceHealth(sourceId);

    const isSuccess = collectionResult.status === 'UNCHANGED' ||
                      collectionResult.status === 'CHANGED' ||
                      collectionResult.status === 'FIRST_SEEN';

    let consecutiveFailures = isSuccess ? 0 : (currentState.consecutiveFailures + 1);
    let lastSuccessAt = isSuccess ? now.toISOString() : currentState.lastSuccessAt;
    let lastFailureAt = isSuccess ? currentState.lastFailureAt : now.toISOString();
    let lastCheckedAt = now.toISOString();
    let lastHTTPStatus = collectionResult.httpStatus || currentState.lastHTTPStatus;
    let lastError = isSuccess ? null : (collectionResult.error || 'Fetch failed');

    // Determine current health based on consecutive failures and staleness
    const { healthStatus, staleRisk, warnings } = this._computeHealth({
      consecutiveFailures,
      lastSuccessAt,
      now,
    });

    const updatedState = {
      sourceId,
      bankCode: source.bankCode,
      consecutiveFailures,
      lastSuccessAt,
      lastFailureAt,
      lastCheckedAt,
      lastHTTPStatus,
      lastError,
      healthStatus,
      staleRisk,
      warnings,
    };

    // Save to memory
    this._inMemoryHealth.set(sourceId, updatedState);

    // Save to Supabase if available
    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        await supabaseAdmin
          .from('rate_sources')
          .update({
            last_checked_at: lastCheckedAt,
            last_success_at: lastSuccessAt,
            last_failure_at: lastFailureAt,
            last_http_status: lastHTTPStatus,
            last_error: lastError,
            consecutive_failures: consecutiveFailures,
            health_status: healthStatus,
            stale_risk: staleRisk,
            updated_at: now.toISOString(),
          })
          .eq('id', sourceId);
      } catch (err) {
        this.logger.warn(`Failed to persist health state for source ${sourceId}: ${err.message}`);
      }
    }

    // Trigger alerts if health transitioned to abnormal
    if (this.notifier) {
      if (consecutiveFailures >= this.thresholds.failureThresholdFailing) {
        await this.notifier.notify({
          severity: SEVERITY_LEVELS.ERROR,
          bank: source.bankCode,
          sourceId,
          jobId,
          failureType: ALERT_TYPES.CONSECUTIVE_FAILURES,
          recommendedAction: `Inspect official bank endpoint for ${source.bankCode}. Source has failed ${consecutiveFailures} consecutive times.`,
          message: `Source failing: ${lastError}`,
          details: { consecutiveFailures, lastHTTPStatus },
        });
      } else if (consecutiveFailures === this.thresholds.failureThresholdDegraded) {
        await this.notifier.notify({
          severity: SEVERITY_LEVELS.WARNING,
          bank: source.bankCode,
          sourceId,
          jobId,
          failureType: ALERT_TYPES.CONSECUTIVE_FAILURES,
          recommendedAction: `Check network status for ${source.bankCode}. Source degraded after ${consecutiveFailures} failures.`,
          message: `Source degraded: ${lastError}`,
          details: { consecutiveFailures, lastHTTPStatus },
        });
      }

      for (const w of warnings) {
        await this.notifier.notify({
          severity: w.severity,
          bank: source.bankCode,
          sourceId,
          jobId,
          failureType: w.type,
          recommendedAction: w.recommendedAction,
          message: w.message,
          details: w.details,
        });
      }
    }

    return updatedState;
  }

  /**
   * Evaluates staleness across all registered sources.
   */
  async evaluateAllSources(sources, jobId = 'N/A') {
    const reports = [];
    for (const src of sources) {
      const state = await this.getSourceHealth(src.id);
      const now = new Date();
      const evalResult = this._computeHealth({
        consecutiveFailures: state.consecutiveFailures,
        lastSuccessAt: state.lastSuccessAt,
        now,
      });

      reports.push({
        sourceId: src.id,
        bankCode: src.bankCode,
        healthStatus: evalResult.healthStatus,
        staleRisk: evalResult.staleRisk,
        consecutiveFailures: state.consecutiveFailures,
        lastSuccessAt: state.lastSuccessAt,
        warnings: evalResult.warnings,
      });
    }
    return reports;
  }

  /**
   * Retrieves the current health state for a source.
   */
  async getSourceHealth(sourceId) {
    if (this._inMemoryHealth.has(sourceId)) {
      return this._inMemoryHealth.get(sourceId);
    }

    if (isSupabaseAvailable() && supabaseAdmin) {
      try {
        const { data } = await supabaseAdmin
          .from('rate_sources')
          .select('consecutive_failures, last_success_at, last_failure_at, last_checked_at, last_http_status, last_error, health_status, stale_risk')
          .eq('id', sourceId)
          .maybeSingle();

        if (data) {
          const loaded = {
            sourceId,
            consecutiveFailures: data.consecutive_failures || 0,
            lastSuccessAt: data.last_success_at,
            lastFailureAt: data.last_failure_at,
            lastCheckedAt: data.last_checked_at,
            lastHTTPStatus: data.last_http_status,
            lastError: data.last_error,
            healthStatus: data.health_status || HEALTH_STATES.HEALTHY,
            staleRisk: Boolean(data.stale_risk),
          };
          this._inMemoryHealth.set(sourceId, loaded);
          return loaded;
        }
      } catch {
        // Fall back to default
      }
    }

    // Default clean state
    const clean = {
      sourceId,
      consecutiveFailures: 0,
      lastSuccessAt: null,
      lastFailureAt: null,
      lastCheckedAt: null,
      lastHTTPStatus: null,
      lastError: null,
      healthStatus: HEALTH_STATES.HEALTHY,
      staleRisk: false,
    };
    this._inMemoryHealth.set(sourceId, clean);
    return clean;
  }

  // ----------------------------------------------------------------
  // Internal Computation
  // ----------------------------------------------------------------

  _computeHealth({ consecutiveFailures, lastSuccessAt, now }) {
    const warnings = [];
    let healthStatus = HEALTH_STATES.HEALTHY;
    let staleRisk = false;

    // 1. Failure-based health
    if (consecutiveFailures >= this.thresholds.failureThresholdFailing) {
      healthStatus = HEALTH_STATES.FAILING;
    } else if (consecutiveFailures >= this.thresholds.failureThresholdDegraded) {
      healthStatus = HEALTH_STATES.DEGRADED;
    }

    // 2. Staleness-based health
    if (lastSuccessAt) {
      const elapsedMs = now.getTime() - new Date(lastSuccessAt).getTime();
      const elapsedHours = elapsedMs / (1000 * 60 * 60);
      const elapsedDays = elapsedHours / 24;

      if (elapsedDays >= this.thresholds.staleDays) {
        healthStatus = HEALTH_STATES.FAILING;
        staleRisk = true;
        warnings.push({
          type: ALERT_TYPES.STALE_SOURCE_CRITICAL,
          severity: SEVERITY_LEVELS.CRITICAL,
          message: `Source has not successfully updated in ${elapsedDays.toFixed(1)} days (threshold: ${this.thresholds.staleDays}d)`,
          recommendedAction: 'Verify bank website availability; rates may be significantly stale.',
          details: { elapsedDays, lastSuccessAt },
        });
      } else if (elapsedHours >= this.thresholds.staleRiskHours) {
        if (healthStatus === HEALTH_STATES.HEALTHY) {
          healthStatus = HEALTH_STATES.STALE_RISK;
        }
        staleRisk = true;
        warnings.push({
          type: ALERT_TYPES.STALE_SOURCE_WARNING,
          severity: SEVERITY_LEVELS.WARNING,
          message: `Source has not successfully updated in ${elapsedHours.toFixed(1)} hours (threshold: ${this.thresholds.staleRiskHours}h)`,
          recommendedAction: 'Monitor source connectivity; review if manual check is required.',
          details: { elapsedHours, lastSuccessAt },
        });
      } else if (elapsedHours >= this.thresholds.warningHours) {
        warnings.push({
          type: ALERT_TYPES.STALE_SOURCE_WARNING,
          severity: SEVERITY_LEVELS.WARNING,
          message: `Source has not had a successful collection in ${elapsedHours.toFixed(1)} hours (threshold: ${this.thresholds.warningHours}h)`,
          recommendedAction: 'Review source polling status.',
          details: { elapsedHours, lastSuccessAt },
        });
      }
    }

    return { healthStatus, staleRisk, warnings };
  }

  // Testing helper
  _setSourceHealth(sourceId, state) {
    this._inMemoryHealth.set(sourceId, state);
  }
}

module.exports = {
  SourceHealthMonitor,
  HEALTH_STATES,
  DEFAULT_THRESHOLDS,
};
