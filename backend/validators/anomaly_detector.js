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

      // Helper to generate canonical bucket key
      const getBucketKey = (item) => {
        const cust = item.customer_type || item.customerType;
        const call = item.is_callable !== false && item.isCallable !== false;
        const domain = String(item.tenure_domain || item.tenureDomain || 'DAYS').toUpperCase().trim();
        if (domain === 'CALENDAR') {
          const minY = item.min_years != null ? Number(item.min_years) : (item.minYears != null ? Number(item.minYears) : 0);
          const minM = item.min_months != null ? Number(item.min_months) : (item.minMonths != null ? Number(item.minMonths) : 0);
          const minD = item.min_days_cal != null ? Number(item.min_days_cal) : (item.minDaysCal != null ? Number(item.minDaysCal) : 0);
          const minOp = String(item.min_operator || item.minOperator || '').toUpperCase().trim();
          const maxY = item.max_years != null ? Number(item.max_years) : (item.maxYears != null ? Number(item.maxYears) : 0);
          const maxM = item.max_months != null ? Number(item.max_months) : (item.maxMonths != null ? Number(item.maxMonths) : 0);
          const maxD = item.max_days_cal != null ? Number(item.max_days_cal) : (item.maxDaysCal != null ? Number(item.maxDaysCal) : 0);
          const maxOp = String(item.max_operator || item.maxOperator || '').toUpperCase().trim();
          return `${cust}|${call}|CALENDAR|${minY}_${minM}_${minD}_${minOp}|${maxY}_${maxM}_${maxD}_${maxOp}`;
        }
        const minDays = item.min_tenure_days != null ? item.min_tenure_days : (item.minTenureDays != null ? item.minTenureDays : null);
        const maxDays = item.max_tenure_days != null ? item.max_tenure_days : (item.maxTenureDays != null ? item.maxTenureDays : null);
        return `${cust}|${call}|DAYS|${minDays}|${maxDays}`;
      };

      const getLabelKey = (item) => {
        const cust = item.customer_type || item.customerType;
        const call = item.is_callable !== false && item.isCallable !== false;
        const label = String(item.tenure_label || item.tenureLabel || item.source_tenure_text || item.sourceTenureText || '').toLowerCase().trim();
        return label ? `${cust}|${call}|LABEL|${label}` : null;
      };

      // 2. Check Rate Delta per Tenure Bucket
      // Index previous rates by bucket key and label key
      const prevMap = new Map();
      const prevLabelMap = new Map();
      const prevRatesByKey = [];

      for (const p of previousRates) {
        const pRate = p.interest_rate !== undefined && p.interest_rate !== null ? p.interest_rate : p.interestRate;
        const bKey = getBucketKey(p);
        const lKey = getLabelKey(p);
        if (pRate !== undefined && pRate !== null) {
          prevMap.set(bKey, parseFloat(pRate));
          if (lKey) prevLabelMap.set(lKey, parseFloat(pRate));
        }
        prevRatesByKey.push({ bKey, lKey, p });
      }

      for (const c of candidates) {
        const bKey = getBucketKey(c);
        const lKey = getLabelKey(c);
        const prevRate = prevMap.has(bKey) ? prevMap.get(bKey) : (lKey && prevLabelMap.has(lKey) ? prevLabelMap.get(lKey) : null);

        if (prevRate !== null && prevRate !== undefined) {
          const delta = Math.abs(c.interestRate - prevRate);
          if (delta > this.config.maxRateDeltaPct) {
            const tenureDesc = (c.tenureDomain || 'DAYS') === 'CALENDAR' ? c.tenureLabel : `[${c.minTenureDays}..${c.maxTenureDays}d]`;
            const flag = `ANOMALY_LARGE_RATE_DELTA: Rate for ${c.customerType} ${tenureDesc} changed by ${delta.toFixed(2)}% (from ${prevRate}% to ${c.interestRate}%, threshold ${this.config.maxRateDeltaPct}%)`;
            c.anomalyFlags.push(flag);
            c.stagingStatus = 'IN_REVIEW';
            anomalies.flags.push(flag);
            anomalies.hasAnomalies = true;
            anomalies.anomalyCount++;
          }
        }
      }

      // 3. Check for Disappeared Tenures
      // A previous rate is missing if neither its bucket key nor its label key is present in new candidates
      const currBucketKeys = new Set(candidates.map(c => getBucketKey(c)));
      const currLabelKeys = new Set(candidates.map(c => getLabelKey(c)).filter(Boolean));

      let missingCount = 0;
      for (const { bKey, lKey } of prevRatesByKey) {
        const isMatched = currBucketKeys.has(bKey) || (lKey && currLabelKeys.has(lKey));
        if (!isMatched) {
          missingCount++;
        }
      }

      if (missingCount > 0 && missingCount >= prevRatesByKey.length * 0.3) {
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
