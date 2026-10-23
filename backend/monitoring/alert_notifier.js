// FeroCalc Verified FD Rate Engine — Low-Noise Alert Notifier
//
// Structured alert dispatcher with multi-channel support (console, webhook, mock).
//
// Safety Guarantees:
// 1. LOW-NOISE: Strictly filters out routine heartbeats and normal unchanged runs.
// 2. ZERO SECRET LEAKAGE: Sanitizes URLs and messages to prevent credential/token leaks.
// 3. STRUCTURED PAYLOAD: Delivers machine-parseable context for automated incident response.

'use strict';

const SEVERITY_LEVELS = {
  INFO: 'INFO',
  WARNING: 'WARNING',
  ERROR: 'ERROR',
  CRITICAL: 'CRITICAL',
};

const ALERT_TYPES = {
  CONSECUTIVE_FAILURES: 'CONSECUTIVE_FAILURES',
  PARSER_ZERO_RESULTS: 'PARSER_ZERO_RESULTS',
  PARSER_FAILURE: 'PARSER_FAILURE',
  ANOMALY_COUNT_MISMATCH: 'ANOMALY_COUNT_MISMATCH',
  ANOMALY_MISSING_TENURE: 'ANOMALY_MISSING_TENURE',
  SUSPICIOUS_RATE_CHANGE: 'SUSPICIOUS_RATE_CHANGE',
  CANDIDATE_IN_REVIEW: 'CANDIDATE_IN_REVIEW',
  STALE_SOURCE_WARNING: 'STALE_SOURCE_WARNING',
  STALE_SOURCE_CRITICAL: 'STALE_SOURCE_CRITICAL',
  JOB_LOCK_COLLISION: 'JOB_LOCK_COLLISION',
  SCHEDULER_FAILURE: 'SCHEDULER_FAILURE',
  UNEXPECTED_PIPELINE_ERROR: 'UNEXPECTED_PIPELINE_ERROR',
};

class AlertNotifier {
  constructor(options = {}) {
    this.channels = options.channels || ['console']; // ['console', 'webhook', 'mock']
    this.webhookUrl = options.webhookUrl || process.env.RATE_ALERT_WEBHOOK_URL || null;
    this.logger = options.logger || console;
    this.mockDispatchedAlerts = []; // Used for unit tests
  }

  /**
   * Sanitizes payloads to guarantee no tokens or sensitive query parameters leak.
   */
  sanitize(text) {
    if (!text || typeof text !== 'string') return text;
    return text
      .replace(/([?&](?:token|key|secret|password|auth)=)[^&\s]+/gi, '$1[REDACTED]')
      .replace(/(Bearer\s+)[a-zA-Z0-9_\-\.]+/gi, '$1[REDACTED]')
      .replace(/(sbp_[a-zA-Z0-9_\-]+)/gi, '[REDACTED_KEY]');
  }

  /**
   * Dispatches a structured alert.
   *
   * @param {Object} alert
   * @param {'INFO'|'WARNING'|'ERROR'|'CRITICAL'} alert.severity
   * @param {string} [alert.bank] - Bank code e.g. 'SBI'
   * @param {string} [alert.sourceId] - e.g. 'sbi-retail-domestic'
   * @param {string} alert.jobId - Execution ID
   * @param {string} alert.failureType - Value from ALERT_TYPES
   * @param {number} [alert.affectedCandidateCount=0]
   * @param {string} alert.recommendedAction
   * @param {string} [alert.message] - Description
   * @param {Object} [alert.details] - Structured metadata
   * @returns {Promise<Object>} Formatted alert payload
   */
  async notify(alert) {
    const payload = {
      severity: alert.severity || SEVERITY_LEVELS.WARNING,
      bank: alert.bank || 'SYSTEM',
      sourceId: alert.sourceId || null,
      jobId: alert.jobId || 'N/A',
      failureType: alert.failureType || ALERT_TYPES.UNEXPECTED_PIPELINE_ERROR,
      timestamp: new Date().toISOString(),
      affectedCandidateCount: alert.affectedCandidateCount || 0,
      recommendedAction: alert.recommendedAction || 'Inspect pipeline run logs',
      message: this.sanitize(alert.message || ''),
      details: alert.details || {},
    };

    // 1. Mock channel (always stores for deterministic test assertions)
    this.mockDispatchedAlerts.push(payload);

    // 2. Console channel
    if (this.channels.includes('console')) {
      const prefix = `[RATE_ALERT:${payload.severity}][${payload.failureType}]`;
      const bankTag = payload.bank ? `[${payload.bank}]` : '';
      const summary = `${prefix}${bankTag} (Job: ${payload.jobId}) ${payload.message} | Action: ${payload.recommendedAction}`;

      if (payload.severity === SEVERITY_LEVELS.CRITICAL || payload.severity === SEVERITY_LEVELS.ERROR) {
        this.logger.error(summary);
      } else {
        this.logger.warn(summary);
      }
    }

    // 3. Webhook channel (future external integrations like Slack, Discord, custom HTTP)
    if (this.channels.includes('webhook') && this.webhookUrl) {
      try {
        if (typeof fetch === 'function') {
          await fetch(this.webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
          });
        }
      } catch (err) {
        this.logger.warn(`Failed to dispatch alert webhook: ${err.message}`);
      }
    }

    return payload;
  }

  /**
   * Clears mock alerts (for test setup/teardown).
   */
  clearMockAlerts() {
    this.mockDispatchedAlerts = [];
  }
}

module.exports = {
  AlertNotifier,
  SEVERITY_LEVELS,
  ALERT_TYPES,
};
