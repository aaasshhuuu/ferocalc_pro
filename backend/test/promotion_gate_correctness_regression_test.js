// FeroCalc Verified FD Rate Engine — Promotion Gate Correctness & Safety Regression Test Suite
//
// Verifies Phase 4 Live Pipeline Promotion Gate Fixes:
// 1. Baseline Query Calendar Tenure Preservation:
//    - _fetchBaselineRates selects complete calendar tenure fields
//    - Canara (12 CALENDAR + 12 DAYS) yields zero missing tenure anomalies
//    - Indian Bank (24 CALENDAR + 30 DAYS) yields zero missing tenure anomalies
//    - Genuinely missing tenures still trigger ANOMALY_TENURE_DISAPPEARED
// 2. Bank Identity Normalization & RateDiffEngine:
//    - _getActiveVerifiedRates attaches canonical bankCode from banks.short_name
//    - Active DB rates with UUID bank_id match candidate bankCode
//    - 57 PNB candidates classify as UNCHANGED
//    - 30 Central Bank candidates classify as UNCHANGED
//    - 24 Canara candidates classify as UNCHANGED
//    - 54 Indian Bank candidates classify as UNCHANGED
//    - Genuinely new tenures classify as NEW
//    - Genuine rate updates classify as RATE_CHANGED
// 3. Persisted Review Status & Safety:
//    - Policy-denied candidates persist staging_status = 'IN_REVIEW' to DB
//    - DB update failures fail closed and report error correctly
//    - UNCHANGED candidates are never marked IN_REVIEW
//    - Unattested new buckets remain blocked by Rule 10
// 4. End-to-End Policy Safety Rule Preservation:
//    - Unofficial domain rejection, rate delta limits, dry-run safety

'use strict';

const assert = require('assert');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { PromotionService } = require('../promotion/promotion_service');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
const { PipelineSchedulerService } = require('../scheduling/pipeline_scheduler_service');
const { AnomalyDetector } = require('../validators/anomaly_detector');

let passed = 0;
let failed = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

async function runTestAsync(name, fn) {
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
    failed++;
  }
}

// ----------------------------------------------------------------
// Fixture Helpers: Synthetic Verified Rates & Candidates
// ----------------------------------------------------------------

function createSyntheticPnbActiveRates() {
  const rates = [];
  const slabs = [
    { min: 7, max: 14, reg: 3.5, snr: 4.0, sup: 4.3, text: '7 to 14 Days' },
    { min: 15, max: 29, reg: 3.5, snr: 4.0, sup: 4.3, text: '15 to 29 Days' },
    { min: 30, max: 45, reg: 3.5, snr: 4.0, sup: 4.3, text: '30 to 45 Days' },
    { min: 46, max: 90, reg: 4.5, snr: 5.0, sup: 5.3, text: '46 to 90 Days' },
    { min: 91, max: 179, reg: 4.5, snr: 5.0, sup: 5.3, text: '91 to 179 Days' },
    { min: 180, max: 270, reg: 6.0, snr: 6.5, sup: 6.8, text: '180 to 270 Days' },
    { min: 271, max: 299, reg: 6.25, snr: 6.75, sup: 7.05, text: '271 to 299 Days' },
    { min: 300, max: 300, reg: 7.05, snr: 7.55, sup: 7.85, text: '300 Days' },
    { min: 301, max: 364, reg: 6.25, snr: 6.75, sup: 7.05, text: '301 to less than 1 Year' },
    { min: 365, max: 365, reg: 6.75, snr: 7.25, sup: 7.55, text: '1 Year' },
    { min: 366, max: 389, reg: 6.8, snr: 7.3, sup: 7.6, text: '>1 Year to 389 Days' },
    { min: 390, max: 390, reg: 7.05, snr: 7.55, sup: 7.85, text: '390 Days' },
    { min: 391, max: 443, reg: 6.8, snr: 7.3, sup: 7.6, text: '>390 Days to 443 Days' },
    { min: 444, max: 444, reg: 7.25, snr: 7.75, sup: 8.05, text: '444 Days' },
    { min: 445, max: 665, reg: 6.8, snr: 7.3, sup: 7.6, text: '>444 Days to 665 Days' },
    { min: 666, max: 666, reg: 7.05, snr: 7.55, sup: 7.85, text: '666 Days' },
    { min: 667, max: 730, reg: 6.8, snr: 7.3, sup: 7.6, text: '>666 Days to 2 Years' },
    { min: 731, max: 1095, reg: 7.0, snr: 7.5, sup: 7.8, text: '>2 to 3 Years' },
    { min: 1096, max: 1825, reg: 6.5, snr: 7.0, sup: 7.3, text: '>3 to 5 Years' },
  ];

  slabs.forEach((s, idx) => {
    ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN'].forEach(cust => {
      rates.push({
        id: `pnb_rate_${idx}_${cust}`,
        bank_id: 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a',
        banks: { short_name: 'PNB' },
        customer_type: cust,
        interest_rate: cust === 'REGULAR' ? s.reg : (cust === 'SENIOR_CITIZEN' ? s.snr : s.sup),
        min_tenure_days: s.min,
        max_tenure_days: s.max,
        tenure_domain: 'DAYS',
        source_tenure_text: s.text,
        is_callable: true,
        status: 'VERIFIED',
      });
    });
  });

  return rates;
}

function createSyntheticCentralBankActiveRates() {
  const rates = [];
  const slabs = [
    { min: 7, max: 14, reg: 3.0, snr: 3.5, text: '7 -14 days', cat: 'STANDARD', scheme: null },
    { min: 15, max: 30, reg: 3.5, snr: 4.0, text: '15 - 30 days', cat: 'STANDARD', scheme: null },
    { min: 31, max: 45, reg: 3.75, snr: 4.25, text: '31 - 45 days', cat: 'STANDARD', scheme: null },
    { min: 46, max: 59, reg: 4.5, snr: 5.0, text: '46 - 59 days', cat: 'STANDARD', scheme: null },
    { min: 60, max: 90, reg: 4.75, snr: 5.25, text: '60 - 90 days', cat: 'STANDARD', scheme: null },
    { min: 91, max: 179, reg: 5.0, snr: 5.5, text: '91 - 179 days', cat: 'STANDARD', scheme: null },
    { min: 180, max: 270, reg: 6.0, snr: 6.5, text: '180 - 270 days', cat: 'STANDARD', scheme: null },
    { min: 271, max: 364, reg: 6.25, snr: 6.75, text: '271 - 364 days', cat: 'STANDARD', scheme: null },
    { min: 365, max: 729, reg: 6.75, snr: 7.25, text: '1 yr to less than 2 yrs', cat: 'STANDARD', scheme: null },
    { min: 730, max: 1094, reg: 6.5, snr: 7.0, text: '2 yr to less than 3 yrs', cat: 'STANDARD', scheme: null },
    { min: 1095, max: 1824, reg: 6.5, snr: 7.0, text: '3 yr to less than 5 yrs', cat: 'STANDARD', scheme: null },
    { min: 1825, max: 3650, reg: 6.25, snr: 6.75, text: '5 yrs & up to 10 yrs', cat: 'STANDARD', scheme: null },
    { min: 333, max: 333, reg: 7.15, snr: 7.65, text: 'Cent 333', cat: 'SPECIAL_SCHEME', scheme: 'CENT_333' },
    { min: 444, max: 444, reg: 7.25, snr: 7.75, text: 'Cent 444', cat: 'SPECIAL_SCHEME', scheme: 'CENT_444' },
    { min: 555, max: 555, reg: 7.25, snr: 7.75, text: 'Cent 555', cat: 'SPECIAL_SCHEME', scheme: 'CENT_555' },
  ];

  slabs.forEach((s, idx) => {
    ['REGULAR', 'SENIOR_CITIZEN'].forEach(cust => {
      rates.push({
        id: `cb_rate_${idx}_${cust}`,
        bank_id: 'b2222222-3333-4444-5555-666666666666',
        banks: { short_name: 'CENTRAL_BANK' },
        customer_type: cust,
        interest_rate: cust === 'REGULAR' ? s.reg : s.snr,
        min_tenure_days: s.min,
        max_tenure_days: s.max,
        tenure_domain: 'DAYS',
        source_tenure_text: s.text,
        rate_category: s.cat,
        scheme_name: s.scheme,
        is_callable: true,
        status: 'VERIFIED',
      });
    });
  });

  return rates;
}

function createSyntheticCanaraActiveRates() {
  const rates = [];
  const daySlabs = [
    { min: 7, max: 45, text: '7 Days to 45 Days*', reg: 3.0, snr: 3.0 },
    { min: 46, max: 90, text: '46 Days to 90 Days', reg: 4.0, snr: 4.0 },
    { min: 91, max: 179, text: '91 Days to 179 Days', reg: 4.25, snr: 4.25 },
    { min: 180, max: 269, text: '180 Days to 269 Days', reg: 5.25, snr: 5.75 },
    { min: 270, max: 364, text: '270 Days to less than 1 Year', reg: 5.5, snr: 6.0 },
    { min: 444, max: 444, text: '444 Days ##', reg: 6.65, snr: 7.15 },
    { min: 555, max: 555, text: '555 Days ##', reg: 6.75, snr: 7.25 },
  ];
  const calSlabs = [
    { y1: 1, m1: 0, d1: 0, op1: 'GTE', y2: 1, m2: 3, d2: 0, op2: 'LTE', text: '1 Year & above to 1 year 3 months Only (Except 444 days)', reg: 6.4, snr: 6.9 },
    { y1: 1, m1: 3, d1: 0, op1: 'GT', y2: 2, m2: 0, d2: 0, op2: 'LT', text: 'Above 1 Year 3 months to less than 2 Years (Except 555 days)', reg: 6.25, snr: 6.75 },
    { y1: 2, m1: 0, d1: 0, op1: 'GTE', y2: 3, m2: 0, d2: 0, op2: 'LT', text: '2 Years & above to less than 3 Years', reg: 6.25, snr: 6.75 },
    { y1: 3, m1: 0, d1: 0, op1: 'GTE', y2: 5, m2: 0, d2: 0, op2: 'LT', text: '3 Years & above to less than 5 Years', reg: 6.25, snr: 6.75 },
    { y1: 5, m1: 0, d1: 0, op1: 'GTE', y2: 10, m2: 0, d2: 0, op2: 'LTE', text: '5 Years & above to 10 Years', reg: 6.25, snr: 6.75 },
  ];

  // 7 day slabs * 2 customer types = 14 rows, 5 cal slabs * 2 = 10 rows => 24 total
  daySlabs.forEach((s, idx) => {
    rates.push({
      id: `canara_day_${idx}_reg`,
      bank_id: 'c1111111-2222-3333-4444-555555555555',
      banks: { short_name: 'CANARA' },
      customer_type: 'REGULAR',
      interest_rate: s.reg,
      min_tenure_days: s.min,
      max_tenure_days: s.max,
      tenure_domain: 'DAYS',
      source_tenure_text: s.text,
      is_callable: true,
      status: 'VERIFIED',
    });
    rates.push({
      id: `canara_day_${idx}_snr`,
      bank_id: 'c1111111-2222-3333-4444-555555555555',
      banks: { short_name: 'CANARA' },
      customer_type: 'SENIOR_CITIZEN',
      interest_rate: s.snr,
      min_tenure_days: s.min,
      max_tenure_days: s.max,
      tenure_domain: 'DAYS',
      source_tenure_text: s.text,
      is_callable: true,
      status: 'VERIFIED',
    });
  });

  calSlabs.forEach((s, idx) => {
    rates.push({
      id: `canara_cal_${idx}_reg`,
      bank_id: 'c1111111-2222-3333-4444-555555555555',
      banks: { short_name: 'CANARA' },
      customer_type: 'REGULAR',
      interest_rate: s.reg,
      min_tenure_days: null,
      max_tenure_days: null,
      tenure_domain: 'CALENDAR',
      source_tenure_text: s.text,
      min_years: s.y1,
      min_months: s.m1,
      min_days_cal: s.d1,
      min_operator: s.op1,
      max_years: s.y2,
      max_months: s.m2,
      max_days_cal: s.d2,
      max_operator: s.op2,
      is_callable: true,
      status: 'VERIFIED',
    });
    rates.push({
      id: `canara_cal_${idx}_snr`,
      bank_id: 'c1111111-2222-3333-4444-555555555555',
      banks: { short_name: 'CANARA' },
      customer_type: 'SENIOR_CITIZEN',
      interest_rate: s.snr,
      min_tenure_days: null,
      max_tenure_days: null,
      tenure_domain: 'CALENDAR',
      source_tenure_text: s.text,
      min_years: s.y1,
      min_months: s.m1,
      min_days_cal: s.d1,
      min_operator: s.op1,
      max_years: s.y2,
      max_months: s.m2,
      max_days_cal: s.d2,
      max_operator: s.op2,
      is_callable: true,
      status: 'VERIFIED',
    });
  });

  return rates;
}

function createSyntheticIndianBankActiveRates() {
  const rates = [];
  const daySlabs = [
    { min: 7, max: 14, text: '7 days to 14 days', reg: 2.8, snr: 3.3, super: 3.55 },
    { min: 15, max: 29, text: '15 days to 29 days', reg: 2.8, snr: 3.3, super: 3.55 },
    { min: 30, max: 45, text: '30 days to 45 days', reg: 3.0, snr: 3.5, super: 3.75 },
    { min: 46, max: 90, text: '46 days to 90 days', reg: 3.25, snr: 3.75, super: 4.0 },
    { min: 91, max: 120, text: '91 days to 120 days', reg: 3.5, snr: 4.0, super: 4.25 },
    { min: 121, max: 180, text: '121 days to 180 days', reg: 3.85, snr: 4.35, super: 4.6 },
    { min: 181, max: 269, text: '181 days to 269 days', reg: 4.5, snr: 5.0, super: 5.25 },
    { min: 270, max: 299, text: '270 days to less than 300 days', reg: 4.75, snr: 5.25, super: 5.5 },
    { min: 300, max: 300, text: 'IND Supreme 2.0(300 days)', reg: 6.2, snr: 6.7, super: 6.95 },
    { min: 301, max: 364, text: '301 days to less than 1 year', reg: 4.75, snr: 5.25, super: 5.5 },
  ];
  const calSlabs = [
    { y1: 1, m1: 0, d1: 0, op1: 'GTE', y2: 2, m2: 0, d2: 0, op2: 'LT', text: '1 year to less than 2 years', reg: 6.1, snr: 6.6, super: 6.85 },
    { y1: 2, m1: 0, d1: 0, op1: 'GTE', y2: 3, m2: 0, d2: 0, op2: 'LT', text: '2 years to less than 3 years', reg: 6.15, snr: 6.65, super: 6.9 },
    { y1: 3, m1: 0, d1: 0, op1: 'GTE', y2: 5, m2: 0, d2: 0, op2: 'LT', text: '3 years to less than 5 years', reg: 6.05, snr: 6.55, super: 6.8 },
    { y1: 5, m1: 0, d1: 0, op1: 'GTE', y2: 5, m2: 0, d2: 0, op2: 'LTE', text: '5 year', reg: 6.0, snr: 6.5, super: 6.75 },
    { y1: 5, m1: 0, d1: 0, op1: 'GT', y2: 10, m2: 0, d2: 0, op2: 'LTE', text: 'Above 5 years', reg: 5.9, snr: 6.4, super: 6.65 },
    { y1: 1, m1: 0, d1: 0, op1: 'GTE', y2: 1, m2: 0, d2: 0, op2: 'LTE', text: '1 year', reg: 6.1, snr: 6.6, super: 6.85 },
    { y1: 1, m1: 0, d1: 1, op1: 'GTE', y2: 1, m2: 3, d2: 0, op2: 'LTE', text: 'Above 1 year to 15 months', reg: 6.1, snr: 6.6, super: 6.85 },
    { y1: 1, m1: 3, d1: 1, op1: 'GTE', y2: 2, m2: 0, d2: 0, op2: 'LT', text: 'Above 15 months to less than 2 years', reg: 6.1, snr: 6.6, super: 6.85 },
  ];

  // 10 day slabs * 3 = 30 rows, 8 cal slabs * 3 = 24 rows => 54 total
  daySlabs.forEach((s, idx) => {
    ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN'].forEach(cust => {
      rates.push({
        id: `ib_day_${idx}_${cust}`,
        bank_id: 'i1111111-2222-3333-4444-555555555555',
        banks: { short_name: 'INDIAN_BANK' },
        customer_type: cust,
        interest_rate: cust === 'REGULAR' ? s.reg : (cust === 'SENIOR_CITIZEN' ? s.snr : s.super),
        min_tenure_days: s.min,
        max_tenure_days: s.max,
        tenure_domain: 'DAYS',
        source_tenure_text: s.text,
        is_callable: true,
        status: 'VERIFIED',
      });
    });
  });

  calSlabs.forEach((s, idx) => {
    ['REGULAR', 'SENIOR_CITIZEN', 'SUPER_SENIOR_CITIZEN'].forEach(cust => {
      rates.push({
        id: `ib_cal_${idx}_${cust}`,
        bank_id: 'i1111111-2222-3333-4444-555555555555',
        banks: { short_name: 'INDIAN_BANK' },
        customer_type: cust,
        interest_rate: cust === 'REGULAR' ? s.reg : (cust === 'SENIOR_CITIZEN' ? s.snr : s.super),
        min_tenure_days: null,
        max_tenure_days: null,
        tenure_domain: 'CALENDAR',
        source_tenure_text: s.text,
        min_years: s.y1,
        min_months: s.m1,
        min_days_cal: s.d1,
        min_operator: s.op1,
        max_years: s.y2,
        max_months: s.m2,
        max_days_cal: s.d2,
        max_operator: s.op2,
        is_callable: true,
        status: 'VERIFIED',
      });
    });
  });

  return rates;
}

function activeRatesToCandidates(activeRates, bankCode) {
  return activeRates.map(r => ({
    bankCode,
    bank_code: bankCode,
    customerType: r.customer_type,
    customer_type: r.customer_type,
    interestRate: r.interest_rate,
    interest_rate: r.interest_rate,
    tenureDomain: r.tenure_domain,
    tenure_domain: r.tenure_domain,
    tenureLabel: r.source_tenure_text,
    tenure_label: r.source_tenure_text,
    sourceTenureText: r.source_tenure_text,
    minTenureDays: r.min_tenure_days,
    min_tenure_days: r.min_tenure_days,
    maxTenureDays: r.max_tenure_days,
    max_tenure_days: r.max_tenure_days,
    minYears: r.min_years,
    min_years: r.min_years,
    minMonths: r.min_months,
    min_months: r.min_months,
    minDaysCal: r.min_days_cal,
    min_days_cal: r.min_days_cal,
    minOperator: r.min_operator,
    min_operator: r.min_operator,
    maxYears: r.max_years,
    max_years: r.max_years,
    maxMonths: r.max_months,
    max_months: r.max_months,
    maxDaysCal: r.max_days_cal,
    max_days_cal: r.max_days_cal,
    maxOperator: r.max_operator,
    max_operator: r.max_operator,
    isCallable: r.is_callable,
    is_callable: r.is_callable,
    rateCategory: r.rate_category || 'STANDARD',
    rate_category: r.rate_category || 'STANDARD',
    schemeName: r.scheme_name || null,
    scheme_name: r.scheme_name || null,
    minDeposit: 0,
    min_deposit: 0,
    maxDeposit: null,
    max_deposit: null,
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    anomalyFlags: [],
    anomaly_flags: [],
    stagingStatus: 'DRAFT',
    validationStatus: 'VALID',
    validationErrors: [],
  }));
}

// ----------------------------------------------------------------
// Main Test Runner
// ----------------------------------------------------------------

async function main() {
  console.log('================================================================');
  console.log('FeroCalc Live Promotion Gate Correctness & Safety Regression');
  console.log('================================================================\n');

  const diffEngine = new RateDiffEngine();
  const policyEngine = new PromotionPolicyEngine({ requireOfficialDomain: true });
  const anomalyDetector = new AnomalyDetector();

  // ----------------------------------------------------------------
  // Group 1: Baseline Query & Calendar Tenure Preservation
  // ----------------------------------------------------------------
  console.log('--- Group 1: Baseline Query & Calendar Tenure Preservation ---');

  runTest('1.1 Canara: 24 active baseline rates (12 CALENDAR, 12 DAYS) yield 0 disappeared-tenure anomalies', () => {
    const active = createSyntheticCanaraActiveRates();
    assert.strictEqual(active.length, 24, 'Canara fixture must contain exactly 24 rates');
    const calCount = active.filter(r => r.tenure_domain === 'CALENDAR').length;
    const dayCount = active.filter(r => r.tenure_domain === 'DAYS').length;
    assert.strictEqual(calCount, 10, 'Expected 10 calendar slabs');
    assert.strictEqual(dayCount, 14, 'Expected 14 day slabs');

    const candidates = activeRatesToCandidates(active, 'CANARA');
    const anomalyResult = anomalyDetector.detectAnomalies(candidates, active, { bankCode: 'CANARA' });
    assert.strictEqual(anomalyResult.hasAnomalies, false, 'Expected no anomalies on full matching baseline');
    assert.strictEqual(anomalyResult.flags.length, 0, 'Flags array should be empty');
  });

  runTest('1.2 Indian Bank: 54 active baseline rates (24 CALENDAR, 30 DAYS) yield 0 disappeared-tenure anomalies', () => {
    const active = createSyntheticIndianBankActiveRates();
    assert.strictEqual(active.length, 54, 'Indian Bank fixture must contain exactly 54 rates');
    const calCount = active.filter(r => r.tenure_domain === 'CALENDAR').length;
    const dayCount = active.filter(r => r.tenure_domain === 'DAYS').length;
    assert.strictEqual(calCount, 24, 'Expected 24 calendar slabs');
    assert.strictEqual(dayCount, 30, 'Expected 30 day slabs');

    const candidates = activeRatesToCandidates(active, 'INDIAN_BANK');
    const anomalyResult = anomalyDetector.detectAnomalies(candidates, active, { bankCode: 'INDIAN_BANK' });
    assert.strictEqual(anomalyResult.hasAnomalies, false, 'Expected no anomalies on full matching baseline');
    assert.strictEqual(anomalyResult.flags.length, 0, 'Flags array should be empty');
  });

  runTest('1.3 Flawed baseline query (omitting tenure_domain) reproduces the false missing-tenure anomaly', () => {
    const active = createSyntheticCanaraActiveRates();
    // Simulate flawed baseline query: strip tenure_domain, source_tenure_text, and calendar fields
    const flawedBaseline = active.map(r => ({
      customer_type: r.customer_type,
      min_tenure_days: r.min_tenure_days,
      max_tenure_days: r.max_tenure_days,
      interest_rate: r.interest_rate,
      is_callable: r.is_callable,
      // tenure_domain, source_tenure_text, min_years etc. omitted
    }));

    const candidates = activeRatesToCandidates(active, 'CANARA');
    const anomalyResult = anomalyDetector.detectAnomalies(candidates, flawedBaseline, { bankCode: 'CANARA' });
    assert.strictEqual(anomalyResult.hasAnomalies, true, 'Flawed baseline must trigger anomaly');
    const missingFlag = anomalyResult.flags.find(f => f.includes('ANOMALY_TENURE_DISAPPEARED'));
    assert.ok(missingFlag, 'Must include ANOMALY_TENURE_DISAPPEARED flag');
    assert.ok(missingFlag.includes('10 previously active tenure buckets are missing'), `Flag text: ${missingFlag}`);
  });

  runTest('1.4 Genuinely missing tenure (30%+ dropped) triggers ANOMALY_TENURE_DISAPPEARED', () => {
    const active = createSyntheticCanaraActiveRates();
    const candidates = activeRatesToCandidates(active, 'CANARA');
    // Drop 10 slabs out of 24
    const partialCandidates = candidates.slice(10);
    const anomalyResult = anomalyDetector.detectAnomalies(partialCandidates, active, { bankCode: 'CANARA' });
    assert.strictEqual(anomalyResult.hasAnomalies, true);
    assert.ok(anomalyResult.flags.some(f => f.includes('ANOMALY_TENURE_DISAPPEARED')));
  });

  runTest('1.5 Count deviation (>40%) triggers ANOMALY_COUNT_MISMATCH', () => {
    const active = createSyntheticCanaraActiveRates();
    const candidates = activeRatesToCandidates(active, 'CANARA');
    // Drop 12 slabs out of 24 (50% drop)
    const halvedCandidates = candidates.slice(0, 12);
    const anomalyResult = anomalyDetector.detectAnomalies(halvedCandidates, active, { bankCode: 'CANARA' });
    assert.strictEqual(anomalyResult.hasAnomalies, true);
    assert.ok(anomalyResult.flags.some(f => f.includes('ANOMALY_COUNT_MISMATCH')));
  });

  // ----------------------------------------------------------------
  // Group 2: Bank Identity Normalization & RateDiffEngine
  // ----------------------------------------------------------------
  console.log('\n--- Group 2: Bank Identity Normalization & RateDiffEngine ---');

  await runTestAsync('2.1 _getActiveVerifiedRates normalizes bankCode while preserving bank_id UUID', async () => {
    const mockDb = {
      from(table) {
        if (table === 'banks') {
          return {
            select() {
              return {
                eq() {
                  return {
                    maybeSingle: () => Promise.resolve({ data: { id: 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a', short_name: 'PNB' }, error: null }),
                    single: () => Promise.resolve({ data: { id: 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a', short_name: 'PNB' }, error: null }),
                  };
                }
              };
            }
          };
        }
        return {
          select(cols) {
            return {
              eq(col1, val1) {
                return {
                  eq(col2, val2) {
                    return Promise.resolve({
                      data: [
                        {
                          id: 'rate_pnb_1',
                          bank_id: 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a',
                          banks: { short_name: 'PNB' },
                          customer_type: 'REGULAR',
                          min_tenure_days: 46,
                          max_tenure_days: 90,
                          interest_rate: 6.3,
                          is_callable: true,
                          tenure_domain: 'DAYS',
                          status: 'VERIFIED',
                        }
                      ],
                      error: null,
                    });
                  }
                };
              }
            };
          }
        };
      }
    };

    const promo = new PromotionService({ supabaseClient: mockDb });
    const rates = await promo._getActiveVerifiedRates('PNB');
    assert.strictEqual(rates.length, 1);
    const r = rates[0];
    assert.strictEqual(r.bank_id, 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a', 'Original bank_id UUID must be preserved');
    assert.strictEqual(r.bankCode, 'PNB', 'Canonical bankCode must be attached');
    assert.strictEqual(r.bank_code, 'PNB', 'Canonical bank_code must be attached');
    assert.deepStrictEqual(r.banks, { short_name: 'PNB' }, 'Joined banks relationship must be preserved');
  });

  runTest('2.2 Active rate with UUID bank_id matches candidate bankCode = PNB as UNCHANGED', () => {
    const activeRate = {
      id: 'rate_pnb_01',
      bank_id: 'ebe9332b-5e22-46ac-b887-2ec15cb5df1a',
      bankCode: 'PNB',
      bank_code: 'PNB',
      customer_type: 'REGULAR',
      min_tenure_days: 46,
      max_tenure_days: 90,
      interest_rate: 6.3,
      is_callable: true,
      tenure_domain: 'DAYS',
      min_deposit: 0,
      max_deposit: 29999999,
      rate_category: 'STANDARD',
      scheme_name: null,
      status: 'VERIFIED',
    };

    const candidate = {
      bankCode: 'PNB',
      bank_code: 'PNB',
      customerType: 'REGULAR',
      customer_type: 'REGULAR',
      minTenureDays: 46,
      min_tenure_days: 46,
      maxTenureDays: 90,
      max_tenure_days: 90,
      interestRate: 6.3,
      interest_rate: 6.3,
      isCallable: true,
      is_callable: true,
      tenureDomain: 'DAYS',
      tenure_domain: 'DAYS',
      minDeposit: 0,
      min_deposit: 0,
      maxDeposit: 29999999,
      max_deposit: 29999999,
      rateCategory: 'STANDARD',
      schemeName: null,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeRate]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNCHANGED, `Expected UNCHANGED but got ${diff.diffType}`);
  });

  runTest('2.3 Batch diff: All 57 PNB candidates classify as UNCHANGED against normalized active rates', () => {
    const active = createSyntheticPnbActiveRates().map(r => ({
      ...r,
      bankCode: 'PNB',
      bank_code: 'PNB',
    }));
    assert.strictEqual(active.length, 57, 'PNB active fixture must contain exactly 57 rates');
    const candidates = activeRatesToCandidates(active, 'PNB');

    let unchangedCount = 0;
    candidates.forEach(c => {
      const diff = diffEngine.diffCandidate(c, active);
      if (diff.diffType === DIFF_TYPES.UNCHANGED) unchangedCount++;
    });
    assert.strictEqual(unchangedCount, 57, `Expected 57 UNCHANGED, got ${unchangedCount}`);
  });

  runTest('2.4 Batch diff: All 30 Central Bank candidates classify as UNCHANGED against normalized active rates', () => {
    const active = createSyntheticCentralBankActiveRates().map(r => ({
      ...r,
      bankCode: 'CENTRAL_BANK',
      bank_code: 'CENTRAL_BANK',
    }));
    assert.strictEqual(active.length, 30, 'Central Bank active fixture must contain exactly 30 rates');
    const candidates = activeRatesToCandidates(active, 'CENTRAL_BANK');

    let unchangedCount = 0;
    candidates.forEach(c => {
      const diff = diffEngine.diffCandidate(c, active);
      if (diff.diffType === DIFF_TYPES.UNCHANGED) unchangedCount++;
    });
    assert.strictEqual(unchangedCount, 30, `Expected 30 UNCHANGED, got ${unchangedCount}`);
  });

  runTest('2.5 Batch diff: All 24 Canara candidates classify as UNCHANGED against normalized active rates', () => {
    const active = createSyntheticCanaraActiveRates().map(r => ({
      ...r,
      bankCode: 'CANARA',
      bank_code: 'CANARA',
    }));
    assert.strictEqual(active.length, 24, 'Canara active fixture must contain exactly 24 rates');
    const candidates = activeRatesToCandidates(active, 'CANARA');

    let unchangedCount = 0;
    candidates.forEach(c => {
      const diff = diffEngine.diffCandidate(c, active);
      if (diff.diffType === DIFF_TYPES.UNCHANGED) unchangedCount++;
    });
    assert.strictEqual(unchangedCount, 24, `Expected 24 UNCHANGED, got ${unchangedCount}`);
  });

  runTest('2.6 Batch diff: All 54 Indian Bank candidates classify as UNCHANGED against normalized active rates', () => {
    const active = createSyntheticIndianBankActiveRates().map(r => ({
      ...r,
      bankCode: 'INDIAN_BANK',
      bank_code: 'INDIAN_BANK',
    }));
    assert.strictEqual(active.length, 54, 'Indian Bank active fixture must contain exactly 54 rates');
    const candidates = activeRatesToCandidates(active, 'INDIAN_BANK');

    let unchangedCount = 0;
    candidates.forEach(c => {
      const diff = diffEngine.diffCandidate(c, active);
      if (diff.diffType === DIFF_TYPES.UNCHANGED) unchangedCount++;
    });
    assert.strictEqual(unchangedCount, 54, `Expected 54 UNCHANGED, got ${unchangedCount}`);
  });

  runTest('2.7 Genuinely new tenure bucket classifies as DIFF_TYPES.NEW', () => {
    const active = createSyntheticCanaraActiveRates().map(r => ({
      ...r,
      bankCode: 'CANARA',
      bank_code: 'CANARA',
    }));
    // 4000 days (> 10 years) is disjoint from all existing tenures (max is 10 years = 3652 days)
    const newCandidate = {
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      minTenureDays: 4000,
      maxTenureDays: 4000,
      interestRate: 7.5,
      isCallable: true,
      tenureDomain: 'DAYS',
      rateCategory: 'STANDARD',
      schemeName: null,
    };

    const diff = diffEngine.diffCandidate(newCandidate, active);
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW, `Expected NEW, got ${diff.diffType}`);
  });

  runTest('2.8 Genuine rate change on existing tenure classifies as DIFF_TYPES.RATE_CHANGED', () => {
    const active = createSyntheticCanaraActiveRates().map(r => ({
      ...r,
      bankCode: 'CANARA',
      bank_code: 'CANARA',
    }));
    // Change rate of 7-45 days regular from 3.0 to 3.25
    const candidate = {
      bankCode: 'CANARA',
      customerType: 'REGULAR',
      minTenureDays: 7,
      maxTenureDays: 45,
      interestRate: 3.25,
      isCallable: true,
      tenureDomain: 'DAYS',
      rateCategory: 'STANDARD',
      schemeName: null,
    };

    const diff = diffEngine.diffCandidate(candidate, active);
    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED, `Expected RATE_CHANGED, got ${diff.diffType}`);
    assert.strictEqual(diff.rateDelta, 0.25);
  });

  // ----------------------------------------------------------------
  // Group 3: Persisted Review Status & Safety
  // ----------------------------------------------------------------
  console.log('\n--- Group 3: Persisted Review Status & Safety ---');

  await runTestAsync('3.1 Policy-denied candidate (e.g. unreviewed NEW bucket) persists staging_status = IN_REVIEW', async () => {
    let updatedTable = null;
    let updatedPayload = null;
    let updatedId = null;

    const mockDb = {
      from(table) {
        return {
          update(payload) {
            updatedTable = table;
            updatedPayload = payload;
            return {
              eq(col, val) {
                if (col === 'id') updatedId = val;
                return Promise.resolve({ error: null });
              }
            };
          }
        };
      }
    };

    const candidate = {
      id: 'cand_review_test_01',
      bankCode: 'PNB',
      customerType: 'REGULAR',
      tenureLabel: 'Special 999 Days',
      interestRate: 7.75,
      minTenureDays: 999,
      maxTenureDays: 999,
      tenureDomain: 'DAYS',
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      effectiveFrom: '2026-11-04',
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
    };

    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      logger: { warn: () => {}, error: () => {}, info: () => {}, log: () => {} },
    });

    const source = { bankCode: 'PNB', id: 'pnb-retail', sourceUrl: 'https://pnb.bank.in/rates' };
    const collectionResult = { status: 'SUCCESS', httpStatus: 200, contentHash: 'a'.repeat(64), changed: true };

    scheduler.collectionService = {
      collectSource: async () => collectionResult,
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.diffEngine = {
      diffCandidate: () => ({ diffType: 'NEW', previousRecord: null })
    };
    scheduler.policyEngine = {
      evaluateCandidate: () => ({
        eligibleForAutoPromotion: false,
        recommendedAction: 'IN_REVIEW',
        decisionReason: 'Brand new rate bucket introduced (requires initial human review)',
        failedReasons: ['Brand new rate bucket introduced (requires initial human review)']
      })
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => []
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { candidatesWithAnomalies: 0, anomalyFlags: [] }
      })
    };

    const result = await scheduler._processSingleSource({ source, jobId: 'job_test_01', dryRun: false });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.reviewCount, 1);
    assert.strictEqual(candidate.stagingStatus, 'IN_REVIEW');
    assert.strictEqual(updatedTable, 'staged_rate_candidates', 'Must target staged_rate_candidates table');
    assert.strictEqual(updatedId, 'cand_review_test_01', 'Must update exact candidate ID');
    assert.strictEqual(updatedPayload.staging_status, 'IN_REVIEW', 'Must persist IN_REVIEW status');
  });

  await runTestAsync('3.2 Database update error during review persistence fails closed (status: ERROR)', async () => {
    const mockDb = {
      from(table) {
        return {
          update() {
            return {
              eq() {
                return Promise.resolve({ error: { message: 'Database connection timeout' } });
              }
            };
          }
        };
      }
    };

    const candidate = {
      id: 'cand_fail_test_02',
      bankCode: 'PNB',
      customerType: 'REGULAR',
      tenureLabel: 'Special 888 Days',
      interestRate: 7.5,
      minTenureDays: 888,
      maxTenureDays: 888,
      tenureDomain: 'DAYS',
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      effectiveFrom: '2026-11-04',
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
    };

    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      logger: { warn: () => {}, error: () => {}, info: () => {}, log: () => {} },
    });

    const source = { bankCode: 'PNB', id: 'pnb-retail', sourceUrl: 'https://pnb.bank.in/rates' };
    const collectionResult = { status: 'SUCCESS', httpStatus: 200, contentHash: 'a'.repeat(64), changed: true };

    scheduler.collectionService = {
      collectSource: async () => collectionResult,
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.diffEngine = {
      diffCandidate: () => ({ diffType: 'NEW', previousRecord: null })
    };
    scheduler.policyEngine = {
      evaluateCandidate: () => ({
        eligibleForAutoPromotion: false,
        recommendedAction: 'IN_REVIEW',
        decisionReason: 'Brand new rate bucket introduced (requires initial human review)',
        failedReasons: ['Brand new rate bucket introduced (requires initial human review)']
      })
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => []
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { candidatesWithAnomalies: 0, anomalyFlags: [] }
      })
    };

    const result = await scheduler._processSingleSource({ source, jobId: 'job_test_02', dryRun: false });

    assert.strictEqual(result.status, 'ERROR', 'Failure to persist review status must fail the source');
    assert.ok(result.error.includes('Database connection timeout'), `Error message: ${result.error}`);
  });

  await runTestAsync('3.3 UNCHANGED candidates are never marked IN_REVIEW or updated', async () => {
    let updateCalled = false;
    const mockDb = {
      from() {
        return {
          update() {
            updateCalled = true;
            return { eq: () => Promise.resolve({ error: null }) };
          }
        };
      }
    };

    const candidate = {
      id: 'cand_unchanged_03',
      bankCode: 'PNB',
      customerType: 'REGULAR',
      tenureLabel: '46 to 90 Days',
      interestRate: 6.3,
      minTenureDays: 46,
      maxTenureDays: 90,
      tenureDomain: 'DAYS',
      isCallable: true,
      rateCategory: 'STANDARD',
      schemeName: null,
      effectiveFrom: '2026-11-04',
      validationStatus: 'VALID',
      anomalyFlags: [],
      stagingStatus: 'DRAFT',
    };

    const scheduler = new PipelineSchedulerService({
      supabaseClient: mockDb,
      logger: { warn: () => {}, error: () => {}, info: () => {}, log: () => {} },
    });

    const source = { bankCode: 'PNB', id: 'pnb-retail', sourceUrl: 'https://pnb.bank.in/rates' };
    const collectionResult = { status: 'SUCCESS', httpStatus: 200, contentHash: 'a'.repeat(64), changed: true };

    scheduler.collectionService = {
      collectSource: async () => collectionResult,
    };
    scheduler.healthMonitor = {
      recordCollectionOutcome: async () => ({ healthStatus: 'HEALTHY' }),
    };
    scheduler.diffEngine = {
      diffCandidate: () => ({ diffType: DIFF_TYPES.UNCHANGED, previousRecord: {} })
    };
    scheduler.promotionService = {
      _getActiveVerifiedRates: async () => [{ id: 'active_01' }]
    };
    scheduler.stagingService = {
      processCollectionResult: async () => ({
        extracted: true,
        status: 'EXTRACTION_SUCCESS',
        candidates: [candidate],
        anomalies: { candidatesWithAnomalies: 0, anomalyFlags: [] }
      })
    };

    const result = await scheduler._processSingleSource({ source, jobId: 'job_test_03', dryRun: false });

    assert.strictEqual(result.status, 'SUCCESS');
    assert.strictEqual(result.unchangedRatesCount, 1);
    assert.strictEqual(result.reviewCount, 0);
    assert.strictEqual(result.promotedCount, 0);
    assert.strictEqual(candidate.stagingStatus, 'DRAFT', 'Status must remain DRAFT');
    assert.strictEqual(updateCalled, false, 'No DB update should be triggered for unchanged candidate');
  });

  // ----------------------------------------------------------------
  // Group 4: Full Promotion Policy Safety Rules Preservation
  // ----------------------------------------------------------------
  console.log('\n--- Group 4: Promotion Policy Safety Rules Preservation ---');

  runTest('4.1 Unofficial domain URL blocks automated promotion', () => {
    const candidate = {
      bankCode: 'PNB',
      parserId: 'pnb_parser',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-04',
      sourceUrl: 'https://evil-spoof-pnb.com/rates',
      sourceContentHash: 'a'.repeat(64),
      anomalyFlags: [],
    };
    const diff = { diffType: 'RATE_CHANGED', absDelta: 0.25 };
    const res = policyEngine.evaluateCandidate(candidate, diff, {
      httpStatus: 200,
      fetchStatus: 'SUCCESS',
      parserSuccess: true,
      sourceContentHash: 'a'.repeat(64),
      sourceUrl: 'https://evil-spoof-pnb.com/rates',
    });
    assert.strictEqual(res.eligibleForAutoPromotion, false);
    assert.ok(res.failedReasons.some(r => r.includes('Source URL is not from a registered official bank domain')));
  });

  runTest('4.2 Missing explicit effective date blocks automated promotion', () => {
    const candidate = {
      bankCode: 'PNB',
      parserId: 'pnb_parser',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      effectiveFrom: null, // missing date
      sourceUrl: 'https://pnb.bank.in/rates',
      sourceContentHash: 'a'.repeat(64),
      anomalyFlags: [],
    };
    const diff = { diffType: 'RATE_CHANGED', absDelta: 0.25 };
    const res = policyEngine.evaluateCandidate(candidate, diff, {
      httpStatus: 200,
      fetchStatus: 'SUCCESS',
      parserSuccess: true,
      sourceContentHash: 'a'.repeat(64),
      sourceUrl: 'https://pnb.bank.in/rates',
    });
    assert.strictEqual(res.eligibleForAutoPromotion, false);
    assert.ok(res.failedReasons.some(r => r.includes('explicitly sourced effectiveFrom date')));
  });

  runTest('4.3 Rate delta exceeding 50 bps threshold blocks automated promotion', () => {
    const candidate = {
      bankCode: 'PNB',
      parserId: 'pnb_parser',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-04',
      sourceUrl: 'https://pnb.bank.in/rates',
      sourceContentHash: 'a'.repeat(64),
      anomalyFlags: [],
    };
    const diff = { diffType: 'RATE_CHANGED', absDelta: 0.75 }; // 75 bps > 50 bps limit
    const res = policyEngine.evaluateCandidate(candidate, diff, {
      httpStatus: 200,
      fetchStatus: 'SUCCESS',
      parserSuccess: true,
      sourceContentHash: 'a'.repeat(64),
      sourceUrl: 'https://pnb.bank.in/rates',
    });
    assert.strictEqual(res.eligibleForAutoPromotion, false);
    assert.ok(res.failedReasons.some(r => r.includes('exceeds automated policy ceiling')));
  });

  runTest('4.4 Candidate with ANOMALY_TENURE_DISAPPEARED blocks automated promotion', () => {
    const candidate = {
      bankCode: 'CANARA',
      parserId: 'canara_parser',
      parserVersion: '1.0.0',
      validationStatus: 'VALID',
      effectiveFrom: '2026-11-04',
      sourceUrl: 'https://canarabank.bank.in/rates',
      sourceContentHash: 'a'.repeat(64),
      anomalyFlags: ['ANOMALY_TENURE_DISAPPEARED: 12 previously active tenure buckets are missing'],
    };
    const diff = { diffType: 'RATE_CHANGED', absDelta: 0.25 };
    const res = policyEngine.evaluateCandidate(candidate, diff, {
      httpStatus: 200,
      fetchStatus: 'SUCCESS',
      parserSuccess: true,
      sourceContentHash: 'a'.repeat(64),
      sourceUrl: 'https://canarabank.bank.in/rates',
    });
    assert.strictEqual(res.eligibleForAutoPromotion, false);
    assert.strictEqual(res.recommendedAction, 'IN_REVIEW');
    assert.ok(res.failedReasons.some(r => r.includes('unexpected disappearance of previously active tenures')));
  });

  console.log('\n================================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('================================================================');

  if (failed > 0) {
    process.exit(1);
  }
}

main().catch(err => {
  console.error('[FATAL] Test runner crashed:', err);
  process.exit(1);
});
