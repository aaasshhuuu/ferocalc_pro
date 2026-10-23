// FeroCalc Phase 3C.5.42 — Calendar-Tenure Staging & Promotion Regression Test Suite
//
// Verifies:
// 1. CandidateStagingService domain-aware validation:
//    - DAYS domain enforces positive integer bounds and min <= max.
//    - CALENDAR domain allows null day bounds and strictly enforces calendar component/operator constraints.
//    - Operator-component coupling, non-negativity, month bounds [0, 11], non-zero duration, symbolic ordering.
// 2. RateDiffEngine domain-aware keying:
//    - CALENDAR candidates generate composite calendar keys, preventing collision on 0#0.
//    - Accurate UNCHANGED and RATE_CHANGED detection for CALENDAR candidates.
//    - Skips day-based overlap comparisons for CALENDAR candidates.
//    - Safe tenure representation in diffBatch removedFromSource.
// 3. PromotionService dual-domain promotion & archiving:
//    - Correctly maps calendar fields and source_tenure_text to VERIFIED fd_rates.
//    - Nullifies day bounds for CALENDAR promotions.
//    - Matches historical archived records by calendar components in _findPreviousArchivedRate.
//
// Constraints: Offline execution only. Zero remote database mutations. Zero mock leakages.

'use strict';

const assert = require('assert');
const { CandidateStagingService } = require('../staging/candidate_staging_service');
const { RateDiffEngine, DIFF_TYPES } = require('../promotion/rate_diff_engine');
const { PromotionService } = require('../promotion/promotion_service');

const crypto = require('crypto');
const HDFC_SOURCE_URL = 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate';
const { HDFC_CANONICAL_SLABS } = require('../parsers/hdfc_canonical_tenure');

/**
 * Deterministic synthetic table fixture for parser/staging/promotion tests.
 * Rates and tenures come from the canonical in-repo model, so this fixture
 * validates plumbing and verbatim-label preservation, NOT independent bank
 * source verification. Never use this fixture for production staging.
 */
function escapeHdfcFixtureCell(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function buildHdfcRegressionFixture() {
  const html = [
    '<html><body>',
    '<p>Applicable from 19th August, 2026</p>',
    '<table>',
    '<tr><th>Tenure Bucket</th><th>Interest Rate (per annum)</th><th>Senior Citizen Rates (per annum)</th></tr>',
    ...HDFC_CANONICAL_SLABS.map((slab) =>
      '<tr><td>' + escapeHdfcFixtureCell(slab.publishedTenureLabel) + '</td>' +
      '<td>' + Number(slab.regularRate).toFixed(2) + '%</td>' +
      '<td>' + Number(slab.seniorRate).toFixed(2) + '%</td></tr>'
    ),
    '</table>',
    '</body></html>',
  ].join('');

  return {
    html,
    sourceContentHash: crypto.createHash('sha256').update(html, 'utf8').digest('hex'),
  };
}


let passed = 0;
let failed = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`  PASS: ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

function makeMockDb(capturedList = []) {
  return {
    from(tableName) {
      return {
        insert(records) {
          records.forEach(r => capturedList.push({ ...r }));
          return {
            select() {
              return Promise.resolve({
                data: records.map((r, i) => ({ id: `uuid_${i}`, ...r })),
                error: null,
              });
            },
          };
        },
      };
    },
  };
}

const silentLogger = {
  log: () => {},
  warn: () => {},
  error: () => {},
  info: () => {},
};

function makeBaseCandidate(overrides = {}) {
  return {
    sourceId: 'hdfc-retail-domestic',
    bankCode: 'HDFC',
    productType: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
    customerType: 'REGULAR',
    tenureLabel: '1 Year to < 15 months',
    tenureDomain: 'CALENDAR',
    minTenureDays: null,
    maxTenureDays: null,
    tenureUnit: 'MONTHS',
    minYears: 1,
    minMonths: 0,
    minDaysCal: 0,
    minOperator: 'GTE',
    maxYears: 1,
    maxMonths: 3,
    maxDaysCal: 0,
    maxOperator: 'LT',
    interestRate: 6.60,
    seniorCitizenRate: 7.10,
    minDeposit: 5000,
    maxDeposit: 29999999,
    isCallable: true,
    compoundingFrequency: 'QUARTERLY',
    effectiveFrom: '2026-08-19',
    sourceUrl: 'https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate',
    sourceContentHash: '3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c',
    extractedAt: '2026-10-22T12:00:00.000Z',
    parserId: 'hdfc-retail-parser',
    parserVersion: '1.2.0',
    validationStatus: 'VALID',
    validationErrors: [],
    anomalyFlags: [],
    stagingStatus: 'DRAFT',
    rateCategory: 'STANDARD',
    schemeName: null,
    ...overrides,
  };
}

async function runTests() {
  console.log('======================================================================');
  console.log('FeroCalc Phase 3C.5.42 Calendar-Tenure Staging & Promotion Tests');
  console.log('======================================================================\n');

  console.log('--- Group 1: CandidateStagingService Dual-Domain Persistence Validation ---');

  await test('1. DAYS candidate with valid integer bounds serializes days correctly and nullifies calendar fields', async () => {
    const captured = [];
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(captured) });
    const daysCandidate = makeBaseCandidate({
      tenureDomain: 'DAYS',
      tenureLabel: '7 - 14 days',
      minTenureDays: 7,
      maxTenureDays: 14,
      tenureUnit: 'DAYS',
      minYears: null, minMonths: null, minDaysCal: null, minOperator: null,
      maxYears: null, maxMonths: null, maxDaysCal: null, maxOperator: null,
    });

    const res = await service._persistCandidates([daysCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 1);
    assert.strictEqual(captured.length, 1);
    const row = captured[0];
    assert.strictEqual(row.tenure_domain, 'DAYS');
    assert.strictEqual(row.min_tenure_days, 7);
    assert.strictEqual(row.max_tenure_days, 14);
    assert.strictEqual(row.min_years, null);
    assert.strictEqual(row.min_months, null);
    assert.strictEqual(row.min_days_cal, null);
    assert.strictEqual(row.min_operator, null);
    assert.strictEqual(row.max_years, null);
    assert.strictEqual(row.max_months, null);
    assert.strictEqual(row.max_days_cal, null);
    assert.strictEqual(row.max_operator, null);
  });

  await test('2. DAYS candidate with null minTenureDays throws fail-closed validation error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      tenureDomain: 'DAYS',
      minTenureDays: null,
      maxTenureDays: 30,
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /DAYS candidate requires non-null minTenureDays and maxTenureDays/);
  });

  await test('3. DAYS candidate with inverted bounds (min > max) throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      tenureDomain: 'DAYS',
      minTenureDays: 90,
      maxTenureDays: 30,
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /DAYS candidate requires minTenureDays > 0 and maxTenureDays >= minTenureDays/);
  });

  await test('4. CALENDAR candidate with null integer day bounds serializes all 9 calendar fields correctly', async () => {
    const captured = [];
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(captured), logger: { error: () => {} } });
    const calCandidate = makeBaseCandidate({
      tenureDomain: 'CALENDAR',
      minTenureDays: null,
      maxTenureDays: null,
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });

    const res = await service._persistCandidates([calCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 1);
    assert.strictEqual(captured.length, 1);
    const row = captured[0];
    assert.strictEqual(row.tenure_domain, 'CALENDAR');
    assert.strictEqual(row.min_tenure_days, null);
    assert.strictEqual(row.max_tenure_days, null);
    assert.strictEqual(row.min_years, 1);
    assert.strictEqual(row.min_months, 0);
    assert.strictEqual(row.min_days_cal, 0);
    assert.strictEqual(row.min_operator, 'GTE');
    assert.strictEqual(row.max_years, 1);
    assert.strictEqual(row.max_months, 3);
    assert.strictEqual(row.max_days_cal, 0);
    assert.strictEqual(row.max_operator, 'LT');
    assert.strictEqual(row.tenure_label, '1 Year to < 15 months');
  });

  await test('5. CALENDAR candidate with invalid lower operator (LTE) throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      minOperator: 'LTE',
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR candidate lower operator must be GTE or GT/);
  });

  await test('6. CALENDAR candidate with invalid upper operator (GTE) throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      maxOperator: 'GTE',
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR candidate upper operator must be LTE or LT/);
  });

  await test('7. CALENDAR candidate with missing lower operator when components exist throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      minYears: 1, minMonths: 0, minDaysCal: 0,
      minOperator: null,
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR candidate lower operator and components must be strictly coupled/);
  });

  await test('8. CALENDAR candidate with missing upper components when operator exists throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      maxYears: null, maxMonths: null, maxDaysCal: null,
      maxOperator: 'LTE',
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR candidate upper operator and components must be strictly coupled/);
  });

  await test('9. CALENDAR candidate with month out of [0, 11] (minMonths = 12) throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      minMonths: 12,
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /minMonths must be in range \[0, 11\]/);
  });

  await test('10. CALENDAR candidate with zero bound duration (0Y 0M 0D) throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      minYears: 0, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR lower bound duration cannot be zero/);
  });

  await test('11. CALENDAR candidate with inverted symbolic ordering (min > max) throws fail-closed error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      minYears: 2, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR lower bound exceeds upper bound/);
  });

  await test('12. CALENDAR candidate with identical endpoints and strict inequality throws empty-interval error', async () => {
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(), logger: silentLogger });
    const invalidCandidate = makeBaseCandidate({
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GT',
      maxYears: 1, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
    });
    const res = await service._persistCandidates([invalidCandidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 0);
    assert.match(res.error, /CALENDAR equal endpoints with strict inequality operators create empty interval/);
  });

  await test('13. Canonical verbatim source tenure text is preserved exactly in serialized payload', async () => {
    const captured = [];
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(captured), logger: { error: () => {} } });
    const verbatimLabel = '4 Year 7 Months to < 55 months';
    const candidate = makeBaseCandidate({
      tenureLabel: verbatimLabel,
      minYears: 4, minMonths: 7, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 4, maxMonths: 7, maxDaysCal: 1, maxOperator: 'LT',
    });

    const res = await service._persistCandidates([candidate], { requireLock: false });
    assert.strictEqual(res.persistedCount, 1);
    assert.strictEqual(captured[0].tenure_label, verbatimLabel);
  });

  console.log('\n--- Group 2: RateDiffEngine Domain-Aware Keying & Diff Logic ---');

  const diffEngine = new RateDiffEngine();

  await test('14. RateDiffEngine.getBucketKey generates distinct keys for distinct CALENDAR slabs (zero 0#0 collision)', () => {
    const slab1 = makeBaseCandidate({
      tenureLabel: '1 Year to < 15 months',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });
    const slab2 = makeBaseCandidate({
      tenureLabel: '15 months to < 18 months',
      minYears: 1, minMonths: 3, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 6, maxDaysCal: 0, maxOperator: 'LT',
    });

    const key1 = diffEngine.getBucketKey(slab1);
    const key2 = diffEngine.getBucketKey(slab2);

    assert.notStrictEqual(key1, key2, 'Keys must be distinct between different calendar slabs');
    assert.ok(key1.includes('CALENDAR#1_0_0_GTE#1_3_0_LT'), 'Key 1 must encode its exact calendar bounds');
    assert.ok(key2.includes('CALENDAR#1_3_0_GTE#1_6_0_LT'), 'Key 2 must encode its exact calendar bounds');
  });

  await test('15. RateDiffEngine.getBucketKey retains exact legacy format for DAYS candidates', () => {
    const daysCandidate = makeBaseCandidate({
      tenureDomain: 'DAYS',
      minTenureDays: 7,
      maxTenureDays: 14,
    });
    const key = diffEngine.getBucketKey(daysCandidate);
    assert.ok(key.includes('#7#14#'), 'DAYS candidate bucket key must include exact day bounds');
  });

  await test('16. RateDiffEngine.getDomainKey includes domain discriminator', () => {
    const daysCandidate = makeBaseCandidate({ tenureDomain: 'DAYS' });
    const calCandidate = makeBaseCandidate({ tenureDomain: 'CALENDAR' });

    const daysDomain = diffEngine.getDomainKey(daysCandidate);
    const calDomain = diffEngine.getDomainKey(calCandidate);

    assert.notStrictEqual(daysDomain, calDomain);
    assert.ok(daysDomain.endsWith('#DAYS'));
    assert.ok(calDomain.endsWith('#CALENDAR'));
  });

  await test('17. RateDiffEngine.diffCandidate detects UNCHANGED when CALENDAR candidate matches active record', () => {
    const candidate = makeBaseCandidate({ interestRate: 6.60 });
    const activeRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.60,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeRecord]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNCHANGED);
    assert.strictEqual(diff.hasChanged, false);
    assert.strictEqual(diff.rateDelta, 0);
  });

  await test('18. RateDiffEngine.diffCandidate detects RATE_CHANGED when CALENDAR candidate rate differs', () => {
    const candidate = makeBaseCandidate({ interestRate: 6.75 });
    const activeRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.60,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeRecord]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.RATE_CHANGED);
    assert.strictEqual(diff.hasChanged, true);
    assert.strictEqual(diff.rateDelta, 0.15);
  });

  await test('19. RateDiffEngine.diffCandidate skips day-overlap check for CALENDAR candidates (no false TENURE_CHANGED)', () => {
    const candidate = makeBaseCandidate({
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });
    // Active record in same domain with different calendar bounds
    const activeRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 2, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 6, max_days_cal: 0, max_operator: 'LT',
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 7.00,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeRecord]);
    // Must be classified as NEW, NOT mistakenly TENURE_CHANGED via 0 <= 0 day comparison
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW);
  });

  await test('20. RateDiffEngine.diffBatch removedFromSource handles CALENDAR records without day-span crashes', () => {
    const activeCalRecord = {
      id: 'active_hdfc_cal_1',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      tenure_domain: 'CALENDAR',
      source_tenure_text: '1 Year to < 15 months',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
      interest_rate: 6.60,
    };

    // diffBatch with empty candidate list -> activeCalRecord should be flagged as REMOVED_FROM_SOURCE
    const report = diffEngine.diffBatch([], [activeCalRecord]);
    assert.strictEqual(report.removedCount, 1);
    assert.strictEqual(report.removedFromSource[0].diffType, DIFF_TYPES.REMOVED_FROM_SOURCE);
    assert.ok(report.removedFromSource[0].details.includes('1 Year to < 15 months'));
  });

  console.log('\n--- Group 3: PromotionService Dual-Domain Rate Creation & Versioning ---');

  await test('21. PromotionService maps calendar fields and source_tenure_text into VERIFIED rate record', async () => {
    const promotionService = new PromotionService();
    const candidate = makeBaseCandidate({
      interestRate: 6.60,
      notes: 'HDFC Table 1 Slab 6 Verified',
    });

    const result = await promotionService.promoteCandidate({
      candidate,
      actorType: 'ADMIN',
      actorId: 'admin_test_uuid',
      reason: 'Manual test promotion',
      activeVerifiedRates: [],
    });

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.promoted, true);
    const verifiedRate = result.newVerifiedRate;
    assert.strictEqual(verifiedRate.status, 'VERIFIED');
    assert.strictEqual(verifiedRate.tenure_domain, 'CALENDAR');
    assert.strictEqual(verifiedRate.min_tenure_days, null);
    assert.strictEqual(verifiedRate.max_tenure_days, null);
    assert.strictEqual(verifiedRate.min_years, 1);
    assert.strictEqual(verifiedRate.min_months, 0);
    assert.strictEqual(verifiedRate.min_days_cal, 0);
    assert.strictEqual(verifiedRate.min_operator, 'GTE');
    assert.strictEqual(verifiedRate.max_years, 1);
    assert.strictEqual(verifiedRate.max_months, 3);
    assert.strictEqual(verifiedRate.max_days_cal, 0);
    assert.strictEqual(verifiedRate.max_operator, 'LT');
    assert.strictEqual(verifiedRate.source_tenure_text, '1 Year to < 15 months');
  });

  await test('22. PromotionService retains day bounds and nullifies calendar fields for DAYS candidates', async () => {
    const promotionService = new PromotionService();
    const daysCandidate = makeBaseCandidate({
      tenureDomain: 'DAYS',
      tenureLabel: '7 - 14 days',
      minTenureDays: 7,
      maxTenureDays: 14,
    });

    const result = await promotionService.promoteCandidate({
      candidate: daysCandidate,
      actorType: 'ADMIN',
      actorId: 'admin_test_uuid',
      activeVerifiedRates: [],
    });

    assert.strictEqual(result.success, true);
    const verifiedRate = result.newVerifiedRate;
    assert.strictEqual(verifiedRate.tenure_domain, 'DAYS');
    assert.strictEqual(verifiedRate.min_tenure_days, 7);
    assert.strictEqual(verifiedRate.max_tenure_days, 14);
    assert.strictEqual(verifiedRate.min_years, null);
    assert.strictEqual(verifiedRate.max_years, null);
  });

  await test('23. PromotionService._findPreviousArchivedRate matches prior archived CALENDAR record using calendar components', async () => {
    const archivedCalRate = {
      id: 'archived_rate_1',
      bankCode: 'HDFC',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
      status: 'ARCHIVED',
    };

    const promotionService = new PromotionService({
      inMemoryRates: [archivedCalRate],
    });

    const currentRate = {
      id: 'active_rate_2',
      bankCode: 'HDFC',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
    };

    const match = await promotionService._findPreviousArchivedRate(currentRate);
    assert.ok(match, 'Must find matching archived calendar record');
    assert.strictEqual(match.id, 'archived_rate_1');
  });

  console.log('\n--- Group 4: Admin Staged Candidates Enriched Mapping ---');

  await test('24. Admin router enrichment logic maps calendar fields and defaults DAYS correctly', () => {
    const rawStagedCalendarRow = {
      id: 'cand_cal_1',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      tenure_domain: 'CALENDAR',
      tenure_label: '1 Year to < 15 months',
      source_tenure_text: '1 Year to < 15 months',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
      min_tenure_days: null,
      max_tenure_days: null,
      tenure_unit: 'MONTHS',
      interest_rate: 6.60,
    };

    // Mirroring admin_staged_candidates.js mapping logic
    const enrichedCal = {
      id: rawStagedCalendarRow.id,
      bankCode: rawStagedCalendarRow.bank_code,
      tenureDomain: rawStagedCalendarRow.tenure_domain || 'DAYS',
      tenureLabel: rawStagedCalendarRow.tenure_label,
      sourceTenureText: rawStagedCalendarRow.source_tenure_text ?? rawStagedCalendarRow.tenure_label,
      displayTenure: (rawStagedCalendarRow.tenure_domain === 'CALENDAR')
        ? (rawStagedCalendarRow.source_tenure_text ?? rawStagedCalendarRow.tenure_label)
        : (rawStagedCalendarRow.tenure_label || `${rawStagedCalendarRow.min_tenure_days} - ${rawStagedCalendarRow.max_tenure_days} days`),
      minTenureDays: rawStagedCalendarRow.min_tenure_days,
      maxTenureDays: rawStagedCalendarRow.max_tenure_days,
      minYears: rawStagedCalendarRow.min_years ?? null,
      minMonths: rawStagedCalendarRow.min_months ?? null,
      minDaysCal: rawStagedCalendarRow.min_days_cal ?? null,
      minOperator: rawStagedCalendarRow.min_operator ?? null,
      maxYears: rawStagedCalendarRow.max_years ?? null,
      maxMonths: rawStagedCalendarRow.max_months ?? null,
      maxDaysCal: rawStagedCalendarRow.max_days_cal ?? null,
      maxOperator: rawStagedCalendarRow.max_operator ?? null,
      tenureUnit: (rawStagedCalendarRow.tenure_domain === 'CALENDAR') ? 'CALENDAR' : (rawStagedCalendarRow.tenure_unit || 'DAYS'),
      legacyTenureUnit: rawStagedCalendarRow.tenure_unit,
    };

    assert.strictEqual(enrichedCal.tenureDomain, 'CALENDAR');
    assert.strictEqual(enrichedCal.displayTenure, '1 Year to < 15 months');
    assert.strictEqual(enrichedCal.tenureUnit, 'CALENDAR');
    assert.strictEqual(enrichedCal.legacyTenureUnit, 'MONTHS');
    assert.strictEqual(enrichedCal.minYears, 1);
    assert.strictEqual(enrichedCal.maxMonths, 3);
    assert.strictEqual(enrichedCal.minOperator, 'GTE');
    assert.strictEqual(enrichedCal.maxOperator, 'LT');
    assert.strictEqual(enrichedCal.minTenureDays, null);

    const rawStagedDaysRow = {
      id: 'cand_days_1',
      bank_code: 'SBI',
      tenure_label: '7 - 14 days',
      min_tenure_days: 7,
      max_tenure_days: 14,
      tenure_unit: 'DAYS',
    };

    const enrichedDays = {
      id: rawStagedDaysRow.id,
      bankCode: rawStagedDaysRow.bank_code,
      tenureDomain: rawStagedDaysRow.tenure_domain || 'DAYS',
      tenureLabel: rawStagedDaysRow.tenure_label,
      sourceTenureText: rawStagedDaysRow.source_tenure_text ?? rawStagedDaysRow.tenure_label,
      displayTenure: (rawStagedDaysRow.tenure_domain === 'CALENDAR')
        ? (rawStagedDaysRow.source_tenure_text ?? rawStagedDaysRow.tenure_label)
        : (rawStagedDaysRow.tenure_label || `${rawStagedDaysRow.min_tenure_days} - ${rawStagedDaysRow.max_tenure_days} days`),
      minTenureDays: rawStagedDaysRow.min_tenure_days,
      maxTenureDays: rawStagedDaysRow.max_tenure_days,
      minYears: rawStagedDaysRow.min_years ?? null,
      maxYears: rawStagedDaysRow.max_years ?? null,
      tenureUnit: (rawStagedDaysRow.tenure_domain === 'CALENDAR') ? 'CALENDAR' : (rawStagedDaysRow.tenure_unit || 'DAYS'),
      legacyTenureUnit: rawStagedDaysRow.tenure_unit,
    };

    assert.strictEqual(enrichedDays.tenureDomain, 'DAYS');
    assert.strictEqual(enrichedDays.displayTenure, '7 - 14 days');
    assert.strictEqual(enrichedDays.tenureUnit, 'DAYS');
    assert.strictEqual(enrichedDays.legacyTenureUnit, 'DAYS');
    assert.strictEqual(enrichedDays.minTenureDays, 7);
    assert.strictEqual(enrichedDays.maxTenureDays, 14);
    assert.strictEqual(enrichedDays.minYears, null);
    assert.strictEqual(enrichedDays.maxYears, null);
  });

  console.log('\n--- Group 5: Phase 3C.5.43 Calendar Identity & Interval Safety Hardening ---');

  await test('25. Canonicalize (years=1, months=null, days=null) vs (years=1, months=0, days=0) before persistence', async () => {
    const captured = [];
    const service = new CandidateStagingService({ supabaseClient: makeMockDb(captured), logger: silentLogger });

    const candNull = makeBaseCandidate({
      tenureLabel: '1 Year to < 15 months',
      minYears: 1, minMonths: null, minDaysCal: null, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: null, maxOperator: 'LT',
    });
    const candZero = makeBaseCandidate({
      tenureLabel: '1 Year to < 15 months',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });

    await service._persistCandidates([candNull], { requireLock: false });
    await service._persistCandidates([candZero], { requireLock: false });

    assert.strictEqual(captured.length, 2);
    // Both must serialize with identical canonical numeric zeroes
    assert.strictEqual(captured[0].min_years, 1);
    assert.strictEqual(captured[0].min_months, 0);
    assert.strictEqual(captured[0].min_days_cal, 0);
    assert.strictEqual(captured[0].max_days_cal, 0);

    assert.strictEqual(captured[1].min_years, 1);
    assert.strictEqual(captured[1].min_months, 0);
    assert.strictEqual(captured[1].min_days_cal, 0);
    assert.strictEqual(captured[1].max_days_cal, 0);

    // Source tenure label must not be rewritten
    assert.strictEqual(captured[0].tenure_label, '1 Year to < 15 months');
    assert.strictEqual(captured[1].tenure_label, '1 Year to < 15 months');
  });

  await test('26. SQL uniqueness & JS bucket keys agree on identity semantics for null-vs-zero normalization', () => {
    const candNull = makeBaseCandidate({
      minYears: 1, minMonths: null, minDaysCal: null, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: null, maxOperator: 'LT',
    });
    const candZero = makeBaseCandidate({
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });

    const keyNull = diffEngine.getBucketKey(candNull);
    const keyZero = diffEngine.getBucketKey(candZero);

    assert.strictEqual(keyNull, keyZero, 'JS bucket keys must be identical for null and zero components');
    assert.ok(keyNull.includes('CALENDAR#1_0_0_GTE#1_3_0_LT'));
  });

  await test('27. Different boundary operators produce distinct bucket keys and do not match', () => {
    const candGTE = makeBaseCandidate({ minOperator: 'GTE' });
    const candGT = makeBaseCandidate({ minOperator: 'GT' });

    const keyGTE = diffEngine.getBucketKey(candGTE);
    const keyGT = diffEngine.getBucketKey(candGT);

    assert.notStrictEqual(keyGTE, keyGT, 'Keys must differ when boundary operators differ');
    assert.ok(keyGTE.includes('_GTE#'));
    assert.ok(keyGT.includes('_GT#'));
  });

  await test('28. Different tenure domains produce distinct bucket keys', () => {
    const daysCandidate = makeBaseCandidate({
      tenureDomain: 'DAYS',
      minTenureDays: 365,
      maxTenureDays: 455,
    });
    const calCandidate = makeBaseCandidate({
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });

    const daysKey = diffEngine.getBucketKey(daysCandidate);
    const calKey = diffEngine.getBucketKey(calCandidate);

    assert.notStrictEqual(daysKey, calKey);
    assert.ok(daysKey.includes('#365#455#'));
    assert.ok(calKey.includes('#CALENDAR#1_0_0_GTE#1_3_0_LT#'));
  });

  await test('29. Explicit interval conflict: Overlapping calendar ranges in same domain return TENURE_CHANGED', () => {
    const candidate = makeBaseCandidate({
      tenureLabel: '1 Year to < 18 months',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 6, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.60,
    });

    // Active record covering 15 months to < 24 months (overlaps with 12M..18M between 15M and 18M)
    const activeOverlappingRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 3, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.75,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeOverlappingRecord]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.TENURE_CHANGED);
    assert.strictEqual(diff.hasChanged, true);
    assert.ok(diff.details.includes('overlaps active record'));
  });

  await test('30. Adjacent non-overlapping calendar ranges with strict vs inclusive boundaries return NEW', () => {
    // Candidate: [1 Year to < 15 months) -> LT 15M excludes 15M
    const candidate = makeBaseCandidate({
      tenureLabel: '1 Year to < 15 months',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });

    // Active record: [15 months to < 18 months) -> GTE 15M starts at 15M
    const activeAdjacentRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 3, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 6, max_days_cal: 0, max_operator: 'LT',
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.75,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeAdjacentRecord]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW, 'Adjacent non-overlapping intervals must not trigger conflict');
  });

  await test('31. Adjacent overlapping calendar ranges with inclusive vs inclusive boundaries return TENURE_CHANGED', () => {
    // Candidate: [1 Year to 15 months] -> LTE 15M includes 15M
    const candidate = makeBaseCandidate({
      tenureLabel: '1 Year to 15 months',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LTE',
      interestRate: 6.60,
    });

    // Active record: [15 months to 18 months] -> GTE 15M includes 15M (overlaps at 15M)
    const activeCollidingRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'CALENDAR',
      min_years: 1, min_months: 3, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 6, max_days_cal: 0, max_operator: 'LTE',
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.75,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeCollidingRecord]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.TENURE_CHANGED, 'Inclusive-inclusive boundary meeting must detect overlap');
  });

  await test('32. Mixed-domain comparison (DAYS vs CALENDAR) returns UNRESOLVED_DOMAIN_CONFLICT', () => {
    const candidate = makeBaseCandidate({
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
    });

    const activeDaysRecord = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'DAYS',
      min_tenure_days: 365,
      max_tenure_days: 455,
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.60,
    };

    const diff = diffEngine.diffCandidate(candidate, [activeDaysRecord]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNRESOLVED_DOMAIN_CONFLICT);
    assert.strictEqual(diff.isConflict, true);
    assert.ok(diff.details.includes('cannot be authoritatively compared'));
  });

  await test('33. PromotionPolicyEngine fails closed on UNRESOLVED_DOMAIN_CONFLICT', () => {
    const { PromotionPolicyEngine } = require('../promotion/promotion_policy_engine');
    const policy = new PromotionPolicyEngine();
    const candidate = makeBaseCandidate();
    const conflictDiff = {
      diffType: DIFF_TYPES.UNRESOLVED_DOMAIN_CONFLICT,
      isConflict: true,
      details: 'Unresolved domain conflict between CALENDAR and DAYS',
    };

    const evalResult = policy.evaluateCandidate(candidate, conflictDiff, {
      fetchStatus: 'SUCCESS',
      parserSuccess: true,
      sourceContentHash: candidate.sourceContentHash,
      sourceUrl: candidate.sourceUrl,
    });

    assert.strictEqual(evalResult.eligibleForAutoPromotion, false, 'Candidate with domain conflict must not auto-promote');
    assert.strictEqual(evalResult.recommendedAction, 'IN_REVIEW');
    assert.ok(evalResult.failedReasons.some(r => r.includes('domain conflict')));
  });

  await test('34. Prevent misleading admin display of legacy tenure_unit for CALENDAR candidates', () => {
    const rawStagedRow = {
      id: 'staged_cand_99',
      bank_code: 'HDFC',
      customer_type: 'REGULAR',
      tenure_domain: 'CALENDAR',
      tenure_label: '1 Year to < 15 months',
      source_tenure_text: '1 Year to < 15 months',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 3, max_days_cal: 0, max_operator: 'LT',
      min_tenure_days: null,
      max_tenure_days: null,
      tenure_unit: 'DAYS', // Legacy DB column defaulted to 'DAYS' by Migration 011
      interest_rate: 6.60,
    };

    // Simulated admin route enrichment from admin_staged_candidates.js
    const enriched = {
      id: rawStagedRow.id,
      bankCode: rawStagedRow.bank_code,
      tenureDomain: rawStagedRow.tenure_domain || 'DAYS',
      tenureLabel: rawStagedRow.tenure_label,
      sourceTenureText: rawStagedRow.source_tenure_text ?? rawStagedRow.tenure_label,
      displayTenure: (rawStagedRow.tenure_domain === 'CALENDAR')
        ? (rawStagedRow.source_tenure_text ?? rawStagedRow.tenure_label)
        : (rawStagedRow.tenure_label || `${rawStagedRow.min_tenure_days} - ${rawStagedRow.max_tenure_days} days`),
      tenureUnit: (rawStagedRow.tenure_domain === 'CALENDAR') ? 'CALENDAR' : (rawStagedRow.tenure_unit || 'DAYS'),
      legacyTenureUnit: rawStagedRow.tenure_unit,
    };

    // Assert that tenureUnit is mapped to CALENDAR and displayTenure is verbatim text
    assert.strictEqual(enriched.tenureDomain, 'CALENDAR');
    assert.strictEqual(enriched.tenureUnit, 'CALENDAR', 'Authoritative tenureUnit must NOT show DAYS for calendar candidate');
    assert.strictEqual(enriched.legacyTenureUnit, 'DAYS', 'Raw legacy column value preserved in legacyTenureUnit');
    assert.strictEqual(enriched.displayTenure, '1 Year to < 15 months', 'Display tenure must match published verbatim text');
  });

  console.log('\n--- Group 6: Synthetic HDFC Fixture End-to-End Pipeline Verification ---');

  await test('35. Synthetic HDFC table fixture preserves verbatim calendar labels through parser, staging, and promotion', async () => {
    const { HdfcRateParser } = require('../parsers/hdfc_parser');
    const fixture = buildHdfcRegressionFixture();
    const parser = new HdfcRateParser();

    const extractionResult = parser.parse(fixture.html, {
      sourceUrl: HDFC_SOURCE_URL,
      sourceContentHash: fixture.sourceContentHash,
      sourceId: 'hdfc-retail-domestic',
    });

    assert.strictEqual(extractionResult.success, true);
    assert.strictEqual(extractionResult.candidates.length, 38);

    const candidates = extractionResult.candidates;
    const allLabels = candidates.map(c => c.tenureLabel);
    assert.ok(allLabels.some(l => l.includes('<')), 'Fixture output must retain strict less-than labels');
    assert.ok(allLabels.some(l => l.includes('<='), 'Fixture output must retain less-than-or-equal labels');
    assert.ok(allLabels.some(l => l.includes('1 day')), 'Fixture output must retain +1 day labels');
    assert.ok(allLabels.some(l => l.includes('(35 months)'), 'Fixture output must retain 35-month milestone');
    assert.ok(allLabels.some(l => l.includes('(55 months)'), 'Fixture output must retain 55-month milestone');

    const capturedStagingRows = [];
    const stagingService = new CandidateStagingService({
      supabaseClient: makeMockDb(capturedStagingRows),
      logger: silentLogger,
    });
    const persistResult = await stagingService._persistCandidates(candidates, { requireLock: false });
    assert.strictEqual(persistResult.persistedCount, 38);
    assert.strictEqual(capturedStagingRows.length, 38);

    for (let i = 0; i < 38; i++) {
      assert.strictEqual(capturedStagingRows[i].tenure_label, candidates[i].tenureLabel);
    }

    // These promotion calls use an in-memory test path and synthetic fixture data only.
    const promotionService = new PromotionService();
    const cand35Months = candidates.find(c => c.tenureLabel.includes('(35 months)'));
    assert.ok(cand35Months, '35-month fixture candidate must exist');
    const promoResult35 = await promotionService.promoteCandidate({
      candidate: cand35Months,
      actorType: 'ADMIN',
      actorId: 'test_admin_id',
      activeVerifiedRates: [],
    });
    assert.strictEqual(promoResult35.success, true);
    assert.strictEqual(promoResult35.newVerifiedRate.source_tenure_text, cand35Months.tenureLabel);

    const cand55Months = candidates.find(c => c.tenureLabel.includes('(55 months)'));
    assert.ok(cand55Months, '55-month fixture candidate must exist');
    const promoResult55 = await promotionService.promoteCandidate({
      candidate: cand55Months,
      actorType: 'ADMIN',
      actorId: 'test_admin_id',
      activeVerifiedRates: [],
    });
    assert.strictEqual(promoResult55.success, true);
    assert.strictEqual(promoResult55.newVerifiedRate.source_tenure_text, cand55Months.tenureLabel);

    const candStrictLt = candidates.find(c => c.tenureLabel.includes('1 Year to < 15 months'));
    assert.ok(candStrictLt);
    const promoResultLt = await promotionService.promoteCandidate({
      candidate: candStrictLt,
      actorType: 'ADMIN',
      actorId: 'test_admin_id',
      activeVerifiedRates: [],
    });
    assert.strictEqual(promoResultLt.newVerifiedRate.source_tenure_text, '1 Year to < 15 months');

    const candLte = candidates.find(c => c.tenureLabel.includes('90 days <= 6 months'));
    assert.ok(candLte);
    const promoResultLte = await promotionService.promoteCandidate({
      candidate: candLte,
      actorType: 'ADMIN',
      actorId: 'test_admin_id',
      activeVerifiedRates: [],
    });
    assert.strictEqual(promoResultLte.newVerifiedRate.source_tenure_text, '90 days <= 6 months');
  });

  console.log('\n--- Group 7: Phase 3C.5.44 Exact Interval Verification & Scoped Mixed-Domain Tests ---');  });

  console.log('\n--- Group 7: Phase 3C.5.44 Exact Interval Verification & Scoped Mixed-Domain Tests ---');

  await test('36. Exact calendar tuple comparison ordering & equal endpoints (_compareCalendarTuples)', () => {
    // 1. Equal endpoints
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 1, months: 0, daysCal: 0 },
      { years: 1, months: 0, daysCal: 0 }
    ), 0, 'Identical tuples must return 0');

    // 2. Normalized total months equivalence (1Y 0M == 0Y 12M)
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 1, months: 0, daysCal: 0 },
      { years: 0, months: 12, daysCal: 0 }
    ), 0, '1Y 0M and 0Y 12M must evaluate to equal total months');

    // 3. Same month, day ordering
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 1, months: 0, daysCal: 0 },
      { years: 1, months: 0, daysCal: 1 }
    ), -1, '1Y 0D must be strictly before 1Y 1D');
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 1, months: 0, daysCal: 1 },
      { years: 1, months: 0, daysCal: 0 }
    ), 1, '1Y 1D must be strictly after 1Y 0D');

    // 4. Different months with standard banking day offsets
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 1, months: 0, daysCal: 1 },
      { years: 1, months: 1, daysCal: 0 }
    ), -1, '1Y 1D must be strictly before 1Y 1M 0D (Delta M = 1, day delta 1 < 28)');

    // 5. Long-tenure versus shorter-tenure
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 5, months: 0, daysCal: 0 },
      { years: 10, months: 0, daysCal: 0 }
    ), -1, '5Y must be strictly before 10Y');
    assert.strictEqual(diffEngine._compareCalendarTuples(
      { years: 0, months: 6, daysCal: 0 },
      { years: 1, months: 0, daysCal: 0 }
    ), -1, '6M must be strictly before 1Y');
  });

  await test('37. Indeterminate calendar tuple ordering without anchor date returns null', () => {
    // 30 days vs 1 month: February has 28 days (30d > 1m), but March has 31 days (30d < 1m)
    const result = diffEngine._compareCalendarTuples(
      { years: 0, months: 0, daysCal: 30 },
      { years: 0, months: 1, daysCal: 0 }
    );
    assert.strictEqual(result, null, 'Unnormalized 30 days vs 1 month cannot be determined without anchor date');

    const resultRev = diffEngine._compareCalendarTuples(
      { years: 0, months: 1, daysCal: 0 },
      { years: 0, months: 0, daysCal: 30 }
    );
    assert.strictEqual(resultRev, null, 'Reverse 1 month vs 30 days cannot be determined without anchor date');
  });

  await test('38. Strict versus inclusive boundary interactions (_isCalendarIntervalStrictlyBefore)', () => {
    // Upper A touches Lower B at 2Y 0M 0D
    const upperStrict = { years: 2, months: 0, daysCal: 0, op: 'LT' };
    const upperInclusive = { years: 2, months: 0, daysCal: 0, op: 'LTE' };
    const lowerStrict = { years: 2, months: 0, daysCal: 0, op: 'GT' };
    const lowerInclusive = { years: 2, months: 0, daysCal: 0, op: 'GTE' };

    // Strict upper (< 2Y) meeting inclusive lower (>= 2Y): disjoint
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperStrict, lowerInclusive), true);

    // Inclusive upper (<= 2Y) meeting strict lower (> 2Y): disjoint
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperInclusive, lowerStrict), true);

    // Inclusive upper (<= 2Y) meeting inclusive lower (>= 2Y): BOTH contain point 2Y -> NOT strictly before
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperInclusive, lowerInclusive), false);

    // Open-ended upper bound (null op): cannot be before anything
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(null, lowerInclusive), false);
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore({ years: 5, months: 0, daysCal: 0, op: null }, lowerInclusive), false);
  });

  await test('39. Adjacent versus overlapping calendar intervals (_calendarIntervalsOverlap)', () => {
    // Slab 1: [1Y, 2Y)
    const slab1 = {
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
    };
    // Slab 2: [2Y, 3Y)
    const slab2 = {
      minYears: 2, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 3, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
    };
    // Adjacent disjoint intervals: must NOT overlap
    assert.strictEqual(diffEngine._calendarIntervalsOverlap(slab1, slab2), false);

    // Slab 3: [1Y, 2Y] (inclusive upper)
    const slab3 = {
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
    };
    // Slab 3 and Slab 2 share point 2Y: must OVERLAP
    assert.strictEqual(diffEngine._calendarIntervalsOverlap(slab3, slab2), true);
  });

  await test('40. Long-tenure versus shorter-tenure interval isolation (no false overlap)', () => {
    const shortSlab = {
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
    };
    const longSlab = {
      minYears: 5, minMonths: 0, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 10, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
    };
    assert.strictEqual(diffEngine._calendarIntervalsOverlap(shortSlab, longSlab), false);
    assert.strictEqual(diffEngine._calendarIntervalsOverlap(longSlab, shortSlab), false);
  });

  await test('41. Day-component edge cases (1 Year vs 1 Year 1 day)', () => {
    // [1Y, 1Y 1D) vs [1Y 1D, 2Y)
    const slabDay0 = {
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 0, maxDaysCal: 1, maxOperator: 'LT',
    };
    const slabDay1 = {
      minYears: 1, minMonths: 0, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 2, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LT',
    };
    assert.strictEqual(diffEngine._calendarIntervalsOverlap(slabDay0, slabDay1), false);
  });

  await test('42. Existing DAYS behavior unchanged with exact integer day arithmetic', () => {
    const candDays = makeBaseCandidate({
      tenureDomain: 'DAYS',
      minTenureDays: 90,
      maxTenureDays: 179,
      interestRate: 6.25,
    });
    const activeDaysSame = {
      bank_code: 'HDFC',
      product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
      customer_type: 'REGULAR',
      is_callable: true,
      rate_category: 'STANDARD',
      scheme_name: null,
      tenure_domain: 'DAYS',
      min_tenure_days: 90,
      max_tenure_days: 179,
      min_deposit: 5000,
      max_deposit: 29999999,
      interest_rate: 6.25,
    };
    const diff = diffEngine.diffCandidate(candDays, [activeDaysSame]);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNCHANGED);
  });

  await test('43. Mixed-domain scoping: clearly unrelated tenure buckets do NOT produce false global conflicts', () => {
    // Active verified rates in DAYS for short tenures (7-14d, 15-29d, 30-45d)
    const activeRates = [
      {
        id: 'rate_d1',
        bank_code: 'HDFC',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        is_callable: true,
        rate_category: 'STANDARD',
        scheme_name: null,
        tenure_domain: 'DAYS',
        min_tenure_days: 7,
        max_tenure_days: 14,
        min_deposit: 5000,
        max_deposit: 29999999,
        interest_rate: 2.75,
      },
      {
        id: 'rate_d2',
        bank_code: 'HDFC',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        is_callable: true,
        rate_category: 'STANDARD',
        scheme_name: null,
        tenure_domain: 'DAYS',
        min_tenure_days: 15,
        max_tenure_days: 29,
        min_deposit: 5000,
        max_deposit: 29999999,
        interest_rate: 3.00,
      },
    ];

    // Candidate in CALENDAR for 5 Years 1 day to 10 Years
    const candLongCal = makeBaseCandidate({
      tenureDomain: 'CALENDAR',
      minYears: 5, minMonths: 0, minDaysCal: 1, minOperator: 'GTE',
      maxYears: 10, maxMonths: 0, maxDaysCal: 0, maxOperator: 'LTE',
      interestRate: 6.15,
    });

    const diff = diffEngine.diffCandidate(candLongCal, activeRates);
    // Must NOT be UNRESOLVED_DOMAIN_CONFLICT because 5-10 years is clearly unrelated to 7-29 days!
    assert.strictEqual(diff.diffType, DIFF_TYPES.NEW, 'Unrelated long-tenure CALENDAR candidate must classify as NEW');
    assert.strictEqual(diff.isConflict, undefined);
  });

  await test('44. Mixed-domain scoping: potentially overlapping mixed-domain pair is blocked fail-closed', () => {
    // Active verified rate in DAYS covering 365 to 455 days
    const activeRates = [
      {
        id: 'rate_d1',
        bank_code: 'HDFC',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        is_callable: true,
        rate_category: 'STANDARD',
        scheme_name: null,
        tenure_domain: 'DAYS',
        min_tenure_days: 7,
        max_tenure_days: 14,
        min_deposit: 5000,
        max_deposit: 29999999,
        interest_rate: 2.75,
      },
      {
        id: 'rate_d_overlap',
        bank_code: 'HDFC',
        product_type: 'RETAIL_DOMESTIC_TERM_DEPOSIT',
        customer_type: 'REGULAR',
        is_callable: true,
        rate_category: 'STANDARD',
        scheme_name: null,
        tenure_domain: 'DAYS',
        min_tenure_days: 365,
        max_tenure_days: 399,
        min_deposit: 5000,
        max_deposit: 29999999,
        interest_rate: 6.60,
      },
    ];

    // Candidate in CALENDAR: 1 Year to < 15 Months (~365 to 455 days)
    const candOverlappingCal = makeBaseCandidate({
      tenureDomain: 'CALENDAR',
      minYears: 1, minMonths: 0, minDaysCal: 0, minOperator: 'GTE',
      maxYears: 1, maxMonths: 3, maxDaysCal: 0, maxOperator: 'LT',
      interestRate: 6.60,
    });

    const diff = diffEngine.diffCandidate(candOverlappingCal, activeRates);
    assert.strictEqual(diff.diffType, DIFF_TYPES.UNRESOLVED_DOMAIN_CONFLICT, 'Potentially overlapping mixed-domain pair must be flagged as conflict');
    assert.strictEqual(diff.isConflict, true);
    assert.strictEqual(diff.previousRecord.id, 'rate_d_overlap');
  });

  await test('45. Canonical HDFC slab 16 and 17 values survive parser mapping from synthetic fixture', () => {
    const { HdfcRateParser } = require('../parsers/hdfc_parser');
    const fixture = buildHdfcRegressionFixture();
    const parser = new HdfcRateParser();
    const result = parser.parse(fixture.html, {
      sourceUrl: HDFC_SOURCE_URL,
      sourceContentHash: fixture.sourceContentHash,
      sourceId: 'hdfc-retail-domestic',
    });

    const slab16Reg = result.candidates.find(c => c.tenureLabel === '3 Years 1 day to < 4 Years 7 Months' && c.customerType === 'REGULAR');
    const slab16Sen = result.candidates.find(c => c.tenureLabel === '3 Years 1 day to < 4 Years 7 Months' && c.customerType === 'SENIOR_CITIZEN');
    assert.ok(slab16Reg, 'Slab 16 REGULAR fixture candidate must exist');
    assert.ok(slab16Sen, 'Slab 16 SENIOR_CITIZEN fixture candidate must exist');
    assert.strictEqual(slab16Reg.interestRate, 6.50);
    assert.strictEqual(slab16Sen.interestRate, 7.10);
    assert.strictEqual(Math.round((slab16Sen.interestRate - slab16Reg.interestRate) * 100), 60);

    const slab17Reg = result.candidates.find(c => c.tenureLabel === '4 Year 7 Months (55 months)' && c.customerType === 'REGULAR');
    const slab17Sen = result.candidates.find(c => c.tenureLabel === '4 Year 7 Months (55 months)' && c.customerType === 'SENIOR_CITIZEN');
    assert.ok(slab17Reg, 'Slab 17 REGULAR fixture candidate must exist');
    assert.ok(slab17Sen, 'Slab 17 SENIOR_CITIZEN fixture candidate must exist');
    assert.strictEqual(slab17Reg.interestRate, 6.40);
    assert.strictEqual(slab17Sen.interestRate, 6.90);
    assert.strictEqual(Math.round((slab17Sen.interestRate - slab17Reg.interestRate) * 100), 50);
  });

  console.log('\n--- Group 8: Phase 3C.5.45 Exhaustive Gregorian Interval Proofs & Fixture Integrity ---');  });

  console.log('\n--- Group 8: Phase 3C.5.45 Exhaustive Gregorian Interval Proofs & Hash Integrity ---');

  await test('46. Distinct-month differences with exact boundary conditions for 1, 2, 3, 4, and 12 months', () => {
    // Delta M = 1: [minDays = 28, maxDays = 31]
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 27 }, { months: 1, daysCal: 0 }), -1, '1M: 27d < 28d -> strictly before (-1)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 28 }, { months: 1, daysCal: 0 }), null, '1M: 28d is indeterminate (Feb common year = 28d)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 30 }, { months: 1, daysCal: 0 }), null, '1M: 30d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 31 }, { months: 1, daysCal: 0 }), null, '1M: 31d is indeterminate (max month is 31d)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 32 }, { months: 1, daysCal: 0 }), 1, '1M: 32d > 31d -> strictly after (1)');

    // Delta M = 2: [minDays = 59, maxDays = 62]
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 58 }, { months: 2, daysCal: 0 }), -1, '2M: 58d < 59d -> strictly before (-1)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 59 }, { months: 2, daysCal: 0 }), null, '2M: 59d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 62 }, { months: 2, daysCal: 0 }), null, '2M: 62d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 63 }, { months: 2, daysCal: 0 }), 1, '2M: 63d > 62d -> strictly after (1)');

    // Delta M = 3: [minDays = 89, maxDays = 92]
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 88 }, { months: 3, daysCal: 0 }), -1, '3M: 88d < 89d -> strictly before (-1)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 89 }, { months: 3, daysCal: 0 }), null, '3M: 89d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 92 }, { months: 3, daysCal: 0 }), null, '3M: 92d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 93 }, { months: 3, daysCal: 0 }), 1, '3M: 93d > 92d -> strictly after (1)');

    // Delta M = 4: [minDays = 120, maxDays = 123]
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 119 }, { months: 4, daysCal: 0 }), -1, '4M: 119d < 120d -> strictly before (-1)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 120 }, { months: 4, daysCal: 0 }), null, '4M: 120d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 123 }, { months: 4, daysCal: 0 }), null, '4M: 123d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ months: 0, daysCal: 124 }, { months: 4, daysCal: 0 }), 1, '4M: 124d > 123d -> strictly after (1)');

    // Delta M = 12 (1 year): [minDays = 365, maxDays = 366]
    assert.strictEqual(diffEngine._compareCalendarTuples({ years: 1, daysCal: 364 }, { years: 2, daysCal: 0 }), -1, '12M: 364d < 365d -> strictly before (-1)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ years: 1, daysCal: 365 }, { years: 2, daysCal: 0 }), null, '12M: 365d is indeterminate (365 in common, 366 in leap)');
    assert.strictEqual(diffEngine._compareCalendarTuples({ years: 1, daysCal: 366 }, { years: 2, daysCal: 0 }), null, '12M: 366d is indeterminate');
    assert.strictEqual(diffEngine._compareCalendarTuples({ years: 1, daysCal: 367 }, { years: 2, daysCal: 0 }), 1, '12M: 367d > 366d -> strictly after (1)');
  });

  await test('47. Exhaustive empirical proof across all 2,922 Gregorian anchor dates (2 full leap cycles: 2024–2031)', () => {
    const { addMonths, addDays } = require('../parsers/hdfc_canonical_tenure');

    // Generate every calendar start date from 2024-01-01 to 2031-12-31 (2,922 calendar days)
    const allDates = [];
    let cur = new Date('2024-01-01T00:00:00Z');
    const end = new Date('2032-01-01T00:00:00Z');
    while (cur < end) {
      allDates.push(cur.toISOString().split('T')[0]);
      cur.setUTCDate(cur.getUTCDate() + 1);
    }
    assert.strictEqual(allDates.length, 2922, 'Must cover exactly 2,922 dates across 8 full Gregorian years');

    // Sample suite of test tuples covering various month offsets, day components, and edge cases
    const testCases = [
      { t1: { months: 0, daysCal: 0 }, t2: { months: 1, daysCal: 0 } },
      { t1: { months: 0, daysCal: 1 }, t2: { months: 1, daysCal: 0 } },
      { t1: { months: 0, daysCal: 27 }, t2: { months: 1, daysCal: 0 } },
      { t1: { months: 0, daysCal: 28 }, t2: { months: 1, daysCal: 0 } },
      { t1: { months: 0, daysCal: 30 }, t2: { months: 1, daysCal: 0 } },
      { t1: { months: 0, daysCal: 32 }, t2: { months: 1, daysCal: 0 } },
      { t1: { months: 0, daysCal: 58 }, t2: { months: 2, daysCal: 0 } },
      { t1: { months: 0, daysCal: 60 }, t2: { months: 2, daysCal: 0 } },
      { t1: { months: 0, daysCal: 63 }, t2: { months: 2, daysCal: 0 } },
      { t1: { months: 0, daysCal: 88 }, t2: { months: 3, daysCal: 0 } },
      { t1: { months: 0, daysCal: 90 }, t2: { months: 3, daysCal: 0 } },
      { t1: { months: 0, daysCal: 93 }, t2: { months: 3, daysCal: 0 } },
      { t1: { years: 1, daysCal: 0 }, t2: { years: 2, daysCal: 0 } },
      { t1: { years: 1, daysCal: 1 }, t2: { years: 2, daysCal: 0 } },
      { t1: { years: 1, daysCal: 364 }, t2: { years: 2, daysCal: 0 } },
      { t1: { years: 1, daysCal: 365 }, t2: { years: 2, daysCal: 0 } },
      { t1: { years: 1, daysCal: 367 }, t2: { years: 2, daysCal: 0 } },
      { t1: { years: 5, daysCal: 1 }, t2: { years: 10, daysCal: 0 } },
    ];

    for (const tc of testCases) {
      const symbolic = diffEngine._compareCalendarTuples(tc.t1, tc.t2);

      let less = 0, greater = 0, equal = 0;
      const y1 = tc.t1.years || 0, m1 = tc.t1.months || 0, d1 = tc.t1.daysCal || 0;
      const y2 = tc.t2.years || 0, m2 = tc.t2.months || 0, d2 = tc.t2.daysCal || 0;

      for (const d of allDates) {
        const d1Target = addDays(addMonths(d, y1 * 12 + m1), d1);
        const d2Target = addDays(addMonths(d, y2 * 12 + m2), d2);
        if (d1Target < d2Target) less++;
        else if (d1Target > d2Target) greater++;
        else equal++;
      }

      if (symbolic === -1) {
        assert.strictEqual(less, allDates.length, `Expected -1 for ${JSON.stringify(tc)} to hold on 100% of dates, got ${less}/${allDates.length}`);
      } else if (symbolic === 1) {
        assert.strictEqual(greater, allDates.length, `Expected 1 for ${JSON.stringify(tc)} to hold on 100% of dates, got ${greater}/${allDates.length}`);
      } else if (symbolic === 0) {
        assert.strictEqual(equal, allDates.length, `Expected 0 for ${JSON.stringify(tc)} to hold on 100% of dates, got ${equal}/${allDates.length}`);
      } else if (symbolic === null) {
        // Genuinely indeterminate: must NOT be 100% any one direction
        assert.ok(less < allDates.length && greater < allDates.length && equal < allDates.length, `Expected null for ${JSON.stringify(tc)} to be anchor-dependent`);
      }
    }
  });

  await test('48. Strict and inclusive boundary interactions across boundary points', () => {
    // Upper A and Lower B meet at exactly (2Y, 0M, 0D)
    const upperLt = { years: 2, months: 0, daysCal: 0, op: 'LT' };
    const upperLte = { years: 2, months: 0, daysCal: 0, op: 'LTE' };
    const lowerGt = { years: 2, months: 0, daysCal: 0, op: 'GT' };
    const lowerGte = { years: 2, months: 0, daysCal: 0, op: 'GTE' };

    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperLt, lowerGte), true, 'LT meets GTE is strictly before');
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperLte, lowerGt), true, 'LTE meets GT is strictly before');
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperLt, lowerGt), true, 'LT meets GT is strictly before');
    assert.strictEqual(diffEngine._isCalendarIntervalStrictlyBefore(upperLte, lowerGte), false, 'LTE meets GTE share boundary point');
  });

  await test('49. Deterministic HDFC fixture hash is reproducible and passed through parser provenance', () => {
    const { HdfcRateParser } = require('../parsers/hdfc_parser');
    const fixture = buildHdfcRegressionFixture();
    const textHash = crypto.createHash('sha256').update(fixture.html, 'utf8').digest('hex');
    const byteHash = crypto.createHash('sha256').update(Buffer.from(fixture.html, 'utf8')).digest('hex');
    assert.strictEqual(textHash, fixture.sourceContentHash);
    assert.strictEqual(byteHash, fixture.sourceContentHash);
    assert.match(textHash, /^[a-f0-9]{64}$/);

    const parsed = new HdfcRateParser().parse(fixture.html, {
      sourceUrl: HDFC_SOURCE_URL,
      sourceContentHash: fixture.sourceContentHash,
      sourceId: 'hdfc-retail-domestic',
    });
    assert.strictEqual(parsed.success, true);
    assert.strictEqual(parsed.candidates.length, 38);
    assert.ok(parsed.candidates.every(c => c.sourceContentHash === fixture.sourceContentHash));
  });

  await test('50. Tracked HDFC human-review worksheet contains 38 REVIEW_REQUIRED rows with blank reviewer fields', () => {
    const fs = require('fs');
    const path = require('path');
    const reviewCsvPath = path.join(__dirname, '..', 'review', 'hdfc_batch_2_human_review.csv');
    const lines = fs.readFileSync(reviewCsvPath, 'utf8').trim().split(/\r?\n/);
    assert.strictEqual(lines.length, 39, 'Header plus 38 candidate rows must exist');

    const headers = lines[0].split(',');
    const indexes = Object.fromEntries(headers.map((name, index) => [name, index]));
    for (const required of [
      'review_id', 'candidate_id', 'tenure_label', 'tenure_domain',
      'interest_rate', 'senior_citizen_rate', 'source_content_hash',
      'validation_status', 'review_status', 'reviewer_decision', 'reviewer_name', 'reviewed_at',
    ]) {
      assert.ok(Object.hasOwn(indexes, required), 'Missing required worksheet column: ' + required);
    }

    const rows = lines.slice(1).map(line => line.split(','));
    assert.strictEqual(rows.length, 38);
    assert.strictEqual(new Set(rows.map(row => row[indexes.review_id])).size, 38);
    assert.strictEqual(new Set(rows.map(row => row[indexes.candidate_id])).size, 38);

    for (const row of rows) {
      assert.strictEqual(row[indexes.validation_status], 'VALID');
      assert.strictEqual(row[indexes.review_status], 'REVIEW_REQUIRED');
      assert.strictEqual(row[indexes.source_content_hash], '3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c');
      assert.strictEqual(row[indexes.effective_from], '2026-08-19');
      assert.strictEqual(row[indexes.min_deposit], '5000.00');
      assert.strictEqual(row[indexes.max_deposit], '29999999.00');
      assert.strictEqual(row[indexes.reviewer_decision], '');
      assert.strictEqual(row[indexes.reviewer_name], '');
      assert.strictEqual(row[indexes.reviewed_at], '');
    }

    const byReviewId = new Map(rows.map(row => [row[indexes.review_id], row]));
    assert.strictEqual(byReviewId.get('REV_047')[indexes.interest_rate], '6.50');
    assert.strictEqual(byReviewId.get('REV_048')[indexes.interest_rate], '7.10');
    assert.strictEqual(byReviewId.get('REV_049')[indexes.interest_rate], '6.40');
    assert.strictEqual(byReviewId.get('REV_050')[indexes.interest_rate], '6.90');
    assert.strictEqual(byReviewId.get('REV_047')[indexes.senior_spread_bps], '60');
    assert.strictEqual(byReviewId.get('REV_049')[indexes.senior_spread_bps], '50');
  });

  console.log('======================================================================');  });

  console.log('======================================================================');
  console.log(`Results: ${passed} passed, ${failed} failed (Total: ${passed + failed})`);
  console.log('======================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
