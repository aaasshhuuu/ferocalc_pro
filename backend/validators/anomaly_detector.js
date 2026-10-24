// FeroCalc Verified FD Rate Engine — Anomaly Detector
//
// Identifies unexpected changes between newly extracted candidates and known baseline:
// - Large rate delta (> maxRateDeltaPct, e.g. 1.00%)
// - Dramatic count spike or drop
// - Unexpected disappearance of tenures
//
// Critical Rule:
// Any detected anomaly MUST prevent automatic promotion and force status to IN_REVIEW.

'use strict';

const DEFAULT_ANOMALY_CONFIG = {
  maxRateDeltaPct: 1.00, // 100 bps threshold
  maxCountChangeRatio: 0.40, // 40% change in candidate count
};

class AnomalyDetector {
  constructor(customConfig = {}) {
    this.config = { ...DEFAULT_ANOMALY_CONFIG, ...customConfig };
  }

  /**
   * Compares newly extracted candidates with previous baseline rates.
   *
   * @param {CandidateRate[]} candidates - Newly extracted candidates
   * @param {Array<Object>} previousRates - Known baseline rates (if available)
   * @param {Object} context
   * @returns {Object} Anomaly detection summary
   */
  detectAnomalies(candidates, previousRates = [], context = {}) {
    const anomalies = {
      hasAnomalies: false,
      anomalyCount: 0,
      flags: [],
      candidatesWithAnomalies: 0,
    };

    if (!Array.isArray(candidates) || candidates.length === 0) {
      return anomalies;
    }

    // 1. Check Count Deviation against previous extraction
    if (Array.isArray(previousRates) && previousRates.length > 0) {
      const prevCount = previousRates.length;
      const currCount = candidates.length;
      const countDiff = Math.abs(currCount - prevCount);
      const ratio = countDiff / prevCount;

      if (ratio > this.config.maxCountChangeRatio) {
        const flag = `ANOMALY_COUNT_MISMATCH: Extracted candidate count changed dramatically (was ${prevCount}, now ${currCount}, diff ratio ${(ratio * 100).toFixed(1)}%)`;
        anomalies.flags.push(flag);
        anomalies.hasAnomalies = true;
        anomalies.anomalyCount++;

        // Mark all candidates with count mismatch warning
        for (const c of candidates) {
          c.anomalyFlags.push(flag);
          if (c.stagingStatus === 'DRAFT') {
            c.stagingStatus = 'IN_REVIEW';
          }
        }
      }

      // 2. Check Rate Delta per Tenure Bucket
      // Index previous rates by (customerType, isCallable, minTenureDays, maxTenureDays)
      const prevMap = new Map();
      for (const p of previousRates) {
        const pRate = p.interest_rate || p.interestRate;
        const key = `${p.customer_type || p.customerType}|${p.is_callable !== false}|${p.min_tenure_days || p.minTenureDays}|${p.max_tenure_days || p.maxTenureDays}`;
        if (pRate !== undefined && pRate !== null) {
          prevMap.set(key, parseFloat(pRate));
        }
      }

      for (const c of candidates) {
        const key = `${c.customerType}|${c.isCallable !== false}|${c.minTenureDays}|${c.maxTenureDays}`;
        if (prevMap.has(key)) {
          const prevRate = prevMap.get(key);
          const delta = Math.abs(c.interestRate - prevRate);

          if (delta > this.config.maxRateDeltaPct) {
            const flag = `ANOMALY_LARGE_RATE_DELTA: Rate for ${c.customerType} [${c.minTenureDays}..${c.maxTenureDays}d] changed by ${delta.toFixed(2)}% (from ${prevRate}% to ${c.interestRate}%, threshold ${this.config.maxRateDeltaPct}%)`;
            c.anomalyFlags.push(flag);
            c.stagingStatus = 'IN_REVIEW';
            anomalies.flags.push(flag);
            anomalies.hasAnomalies = true;
            anomalies.anomalyCount++;
          }
        }
      }

      // 3. Check for Disappeared Tenures
      // If a previous tenure bucket is completely absent in the new set
      const currKeys = new Set(candidates.map(c => 
        `${c.customerType}|${c.isCallable !== false}|${c.minTenureDays}|${c.maxTenureDays}`
      ));

      let missingCount = 0;
      for (const key of prevMap.keys()) {
        if (!currKeys.has(key)) {
          missingCount++;
        }
      }

      if (missingCount > 0 && missingCount >= prevMap.size * 0.3) {
        const flag = `ANOMALY_TENURE_DISAPPEARED: ${missingCount} previously active tenure buckets are missing in new extraction`;
        anomalies.flags.push(flag);
        anomalies.hasAnomalies = true;
        anomalies.anomalyCount++;
        for (const c of candidates) {
          c.anomalyFlags.push(flag);
          if (c.stagingStatus === 'DRAFT') {
            c.stagingStatus = 'IN_REVIEW';
          }
        }
      }
    }

    anomalies.candidatesWithAnomalies = candidates.filter(c => c.anomalyFlags.length > 0).length;
    return anomalies;
  }
}

module.exports = {
  AnomalyDetector,
  DEFAULT_ANOMALY_CONFIG,
};
