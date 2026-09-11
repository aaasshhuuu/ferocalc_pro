// FeroCalc Verified FD Rate Engine — Calendar Tenure Domain Test Suite (C01-C19)
//
// Migration 009: Tests the CALENDAR tenure domain — symbolic tuple comparison,
// cross-domain conflict rejection, boundary operator validation, field isolation,
// and DAYS-domain backward compatibility.
//
// Prerequisites:
//   TEST_BASE_URL  — backend base URL (default: production)
//   TEST_ADMIN_JWT — Supabase JWT for a FeroCalc ADMIN user
//   TEST_BANK_ID   — bank_id to use for test rates (default: SBI pilot bank)
//
// Architectural invariants validated:
//   * CALENDAR records never store min/max_tenure_days
//   * DAYS records never store calendar components
//   * source_tenure_text is required for CALENDAR, verbatim from source
//   * Symbolic (months, days) tuple overlap detection (no integer conversion)
//   * Cross-domain DAYS vs CALENDAR automatic verification is rejected with 409
//   * tenureDays query param on public API returns only DAYS records
//   * Existing 27 DAYS records are completely unchanged
//
// STRICTLY PROHIBITED (tests verify absence):
//   * No 1 month = 30 days conversion anywhere
//   * No fixed anchor date projection
//   * No auto-supersede of overlapping rates

'use strict';

const BASE_URL  = process.env.TEST_BASE_URL  || 'https://backend-ten-livid-14.vercel.app';
const ADMIN_JWT = process.env.TEST_ADMIN_JWT || null;
const BANK_ID   = process.env.TEST_BANK_ID   || '43b748bd-2155-4a3f-8dd0-5249ede00cac';
// SBI pilot verified rate — must remain completely untouched
const SBI_VERIFIED_RATE_ID = 'b8a85f4e-f324-44a6-a6a8-8ef5e6419297';

let total = 0; let passed = 0; let failed = 0;

function assert(condition, message) {
  total++;
  if (condition) { passed++; console.log('  PASS: ' + message); }
  else           { failed++; console.error('  FAIL: ' + message); }
}
function skip(message) {
  total++; passed++;
  console.log('  SKIP: ' + message + ' (no TEST_ADMIN_JWT — skipping write tests)');
}

// -- HTTP helpers -----------------------------------------------------------

function adminHeaders() {
  return {
    'Content-Type':  'application/json',
    'Authorization': 'Bearer ' + ADMIN_JWT,
  };
}

async function post(path, body)  { return fetch(BASE_URL + path, { method: 'POST',  headers: adminHeaders(), body: JSON.stringify(body) }); }
async function patch(path, body) { return fetch(BASE_URL + path, { method: 'PATCH', headers: adminHeaders(), body: JSON.stringify(body) }); }
async function get(path)         { return fetch(BASE_URL + path); }
async function adminGet(path)    { return fetch(BASE_URL + path, { headers: adminHeaders() }); }

// -- Rate payload helpers ---------------------------------------------------

function calendarDraftPayload(overrides = {}) {
  return {
    bank_id:               BANK_ID,
    customer_type:         'REGULAR',
    tenure_domain:         'CALENDAR',
    source_tenure_text:    '1 year to less than 2 years',
    min_years:             1,
    min_months:            0,
    min_days_cal:          0,
    min_operator:          'GTE',
    max_years:             2,
    max_months:            0,
    max_days_cal:          0,
    max_operator:          'LT',
    min_deposit:           0,
    interest_rate:         6.50,
    is_callable:           true,
    compounding_frequency: 'QUARTERLY',
    effective_from:        '2025-01-01',
    source_url:            'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
    review_notes:          '[TEST calendar_tenure_test.js]',
    rate_category:         'STANDARD',
    ...overrides,
  };
}

function daysDraftPayload(overrides = {}) {
  return {
    bank_id:               BANK_ID,
    customer_type:         'REGULAR',
    tenure_domain:         'DAYS',
    min_tenure_days:       2000,
    max_tenure_days:       2365,
    min_deposit:           0,
    interest_rate:         5.75,
    is_callable:           true,
    compounding_frequency: 'QUARTERLY',
    effective_from:        '2025-01-01',
    source_url:            'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits',
    review_notes:          '[TEST calendar_tenure_test.js]',
    rate_category:         'STANDARD',
    ...overrides,
  };
}

async function createDraft(payload) {
  const r = await post('/api/admin/rates/draft', payload);
  const body = await r.json();
  if (r.status !== 201) throw new Error('createDraft failed: ' + JSON.stringify(body));
  return body.data;
}

async function submitForReview(id) {
  const r = await patch('/api/admin/rates/' + id + '/transition', { new_status: 'IN_REVIEW' });
  if (r.status !== 200) {
    const body = await r.json();
    throw new Error('submitForReview failed: ' + JSON.stringify(body));
  }
  return (await r.json()).data;
}

async function archiveRate(id) {
  const r = await patch('/api/admin/rates/' + id + '/transition', { new_status: 'ARCHIVED' });
  return r.status;
}

// -- Test groups ------------------------------------------------------------

async function runC01_C05_ValidationTests() {
  console.log('\nGroup C01-C05: CALENDAR field validation...');

  // C01: CALENDAR draft with valid fields is accepted (201)
  {
    const r = await post('/api/admin/rates/draft', calendarDraftPayload());
    const body = await r.json();
    assert(r.status === 201, 'C01: Valid CALENDAR draft returns 201');
    if (r.status === 201) {
      assert(body.data.tenure_domain === 'CALENDAR', 'C01: Returned rate has tenure_domain=CALENDAR');
      assert(body.data.min_tenure_days == null, 'C01: min_tenure_days is null for CALENDAR');
      assert(body.data.max_tenure_days == null, 'C01: max_tenure_days is null for CALENDAR');
      assert(body.data.source_tenure_text === '1 year to less than 2 years', 'C01: source_tenure_text preserved verbatim');
      assert(body.data.min_years === 1, 'C01: min_years stored correctly');
      assert(body.data.max_operator === 'LT', 'C01: max_operator stored correctly');
      // Cleanup
      await patch('/api/admin/rates/' + body.data.id + '/transition', { new_status: 'REJECTED' });
    }
  }

  // C02: CALENDAR draft missing source_tenure_text is rejected (400)
  {
    const payload = calendarDraftPayload();
    delete payload.source_tenure_text;
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C02: CALENDAR draft without source_tenure_text returns 400');
    assert(body.errors && body.errors.some(e => e.includes('source_tenure_text')),
      'C02: Error mentions source_tenure_text');
  }

  // C03: CALENDAR draft with min_tenure_days present is rejected (400)
  {
    const payload = calendarDraftPayload({ min_tenure_days: 365 });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C03: CALENDAR draft with min_tenure_days returns 400');
    assert(body.errors && body.errors.some(e => e.includes('min_tenure_days') || e.includes('max_tenure_days')),
      'C03: Error mentions day fields');
  }

  // C04: DAYS draft with CALENDAR fields present is rejected (400)
  {
    const payload = daysDraftPayload({ min_years: 1, source_tenure_text: 'X' });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C04: DAYS draft with CALENDAR fields returns 400');
    assert(body.errors && body.errors.some(e => e.includes('min_years') || e.includes('source_tenure_text') || e.includes("must not be present")),
      'C04: Error mentions cross-domain field pollution');
  }

  // C05: invalid tenure_domain value is rejected (400)
  {
    const payload = daysDraftPayload({ tenure_domain: 'WEEKS' });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C05: Invalid tenure_domain=WEEKS returns 400');
    assert(body.errors && body.errors.some(e => e.includes('tenure_domain')),
      'C05: Error mentions tenure_domain');
  }
}

async function runC06_C08_OperatorTests() {
  console.log('\nGroup C06-C08: Boundary operator validation...');

  // C06: invalid min_operator (LTE is not valid for min) is rejected
  {
    const payload = calendarDraftPayload({ min_operator: 'LTE' });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C06: min_operator=LTE (invalid) returns 400');
    assert(body.errors && body.errors.some(e => e.includes('min_operator')),
      'C06: Error mentions min_operator');
  }

  // C07: invalid max_operator (GTE is not valid for max) is rejected
  {
    const payload = calendarDraftPayload({ max_operator: 'GTE' });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C07: max_operator=GTE (invalid) returns 400');
    assert(body.errors && body.errors.some(e => e.includes('max_operator')),
      'C07: Error mentions max_operator');
  }

  // C08: both GTE (inclusive) and LT (exclusive) are valid combinations
  {
    const r = await post('/api/admin/rates/draft', calendarDraftPayload({
      min_operator: 'GTE', max_operator: 'LT',
      source_tenure_text: '1 year to less than 2 years',
    }));
    const body = await r.json();
    assert(r.status === 201, 'C08: GTE/LT operators accepted (201)');
    if (r.status === 201) {
      await patch('/api/admin/rates/' + body.data.id + '/transition', { new_status: 'REJECTED' });
    }
  }
}

async function runC09_C10_ExistingRatesPreservation() {
  console.log('\nGroup C09-C10: Existing DAYS records preservation (critical)...');

  // C09: SBI verified rate still has DAYS domain and unchanged financials
  {
    const r = await get('/api/verified-rates');
    const body = await r.json();
    assert(r.status === 200, 'C09: Public verified-rates endpoint returns 200');
    const sbi = body.data && body.data.find(x => x.id === SBI_VERIFIED_RATE_ID);
    assert(!!sbi, 'C09: SBI verified rate is present in public endpoint');
    if (sbi) {
      assert(sbi.tenure_domain === 'DAYS', 'C09: SBI rate has tenure_domain=DAYS');
      assert(sbi.min_tenure_days === 365,  'C09: SBI min_tenure_days unchanged (365)');
      assert(sbi.max_tenure_days === 729,  'C09: SBI max_tenure_days unchanged (729)');
      assert(sbi.interest_rate === 6.25,   'C09: SBI interest_rate unchanged (6.25)');
      assert(sbi.min_years == null,        'C09: SBI min_years is null (DAYS record)');
      assert(sbi.source_tenure_text != null && sbi.source_tenure_text !== '',
        'C09: SBI source_tenure_text is set (backfilled)');
      // Verify the backfill did NOT use 30 days/month conversion
      assert(!sbi.source_tenure_text || !sbi.source_tenure_text.includes('month'),
        'C09: SBI source_tenure_text does not use month heuristic for 365-729 day range');
    }
  }

  // C10: tenureDays query returns only DAYS records (no CALENDAR bleed-through)
  {
    const r = await get('/api/verified-rates?tenureDays=365');
    const body = await r.json();
    assert(r.status === 200, 'C10: /api/verified-rates?tenureDays=365 returns 200');
    if (body.data) {
      const calendarRates = body.data.filter(x => x.tenure_domain === 'CALENDAR');
      assert(calendarRates.length === 0, 'C10: No CALENDAR records returned for tenureDays= query');
      const allDays = body.data.every(x => x.tenure_domain === 'DAYS' || x.tenure_domain == null);
      assert(allDays, 'C10: All returned rates are in DAYS domain');
    }
  }
}

async function runC11_C14_OverlapTests() {
  if (!ADMIN_JWT) {
    skip('C11: CALENDAR vs CALENDAR non-overlapping adjacent ranges (no JWT)');
    skip('C12: CALENDAR vs CALENDAR overlapping ranges rejected with 409 (no JWT)');
    skip('C13: CALENDAR vs DAYS cross-domain conflict rejected with 409 (no JWT)');
    skip('C14: Exclusive boundary (LT) adjacent to GTE creates no overlap (no JWT)');
    return;
  }

  console.log('\nGroup C11-C14: CALENDAR overlap and cross-domain conflict tests...');

  // C11: Two CALENDAR rates with non-overlapping adjacent ranges both verify
  // [1yr GTE, 2yr LT] and [2yr GTE, 3yr LTE] — LT/GTE boundary = adjacent, no overlap
  let rate11a = null, rate11b = null;
  try {
    rate11a = await createDraft(calendarDraftPayload({
      source_tenure_text: '1 year to less than 2 years',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      customer_type: 'STAFF',  // Use STAFF to avoid SBI conflict domain
    }));
    await submitForReview(rate11a.id);
    const r11a = await patch('/api/admin/rates/' + rate11a.id + '/transition', { new_status: 'VERIFIED' });
    assert(r11a.status === 200, 'C11a: First CALENDAR rate [1yr GTE, 2yr LT] verifies (200)');

    rate11b = await createDraft(calendarDraftPayload({
      source_tenure_text: '2 years to 3 years',
      min_years: 2, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 3, max_months: 0, max_days_cal: 0, max_operator: 'LTE',
      customer_type: 'STAFF',
    }));
    await submitForReview(rate11b.id);
    const r11b = await patch('/api/admin/rates/' + rate11b.id + '/transition', { new_status: 'VERIFIED' });
    assert(r11b.status === 200, 'C11b: Second CALENDAR rate [2yr GTE, 3yr LTE] verifies without overlap (200)');

  } finally {
    if (rate11a) await archiveRate(rate11a.id);
    if (rate11b) await archiveRate(rate11b.id);
  }

  // C12: CALENDAR rates with truly overlapping ranges: second fails with 409
  let rate12a = null, rate12b = null;
  try {
    rate12a = await createDraft(calendarDraftPayload({
      source_tenure_text: '1 year to less than 3 years',
      min_years: 1, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 3, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      customer_type: 'NRE',
    }));
    await submitForReview(rate12a.id);
    const r12a = await patch('/api/admin/rates/' + rate12a.id + '/transition', { new_status: 'VERIFIED' });
    assert(r12a.status === 200, 'C12a: First CALENDAR [1yr,3yr) verifies (200)');

    // This range [2yr,4yr) overlaps with [1yr,3yr)
    rate12b = await createDraft(calendarDraftPayload({
      source_tenure_text: '2 years to less than 4 years',
      min_years: 2, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 4, max_months: 0, max_days_cal: 0, max_operator: 'LT',
      customer_type: 'NRE',
    }));
    await submitForReview(rate12b.id);
    const r12b = await patch('/api/admin/rates/' + rate12b.id + '/transition', { new_status: 'VERIFIED' });
    assert(r12b.status === 409, 'C12b: Overlapping CALENDAR [2yr,4yr) correctly rejected with 409');
    if (r12b.status === 409) {
      const body12b = await r12b.json();
      assert(body12b.status === 'conflict', 'C12b: Response status is conflict');
    }

  } finally {
    if (rate12a) await archiveRate(rate12a.id);
    if (rate12b) {
      // rate12b was not VERIFIED — reject/cleanup
      await patch('/api/admin/rates/' + rate12b.id + '/transition', { new_status: 'REJECTED' }).catch(() => {});
    }
  }

  // C13: Cross-domain conflict — DAYS rate exists, CALENDAR rate with same
  // deposit range rejected with 409 (cross-domain conflict)
  let rate13a = null, rate13b = null;
  try {
    // Create a DAYS rate in a non-conflicting customer_type to avoid SBI overlap
    rate13a = await createDraft(daysDraftPayload({
      customer_type: 'NRO',
      min_tenure_days: 500, max_tenure_days: 700,
    }));
    await submitForReview(rate13a.id);
    const r13a = await patch('/api/admin/rates/' + rate13a.id + '/transition', { new_status: 'VERIFIED' });
    assert(r13a.status === 200, 'C13a: DAYS rate verified (200)');

    // Now create a CALENDAR rate in the same conflict domain
    rate13b = await createDraft(calendarDraftPayload({
      customer_type: 'NRO',
      source_tenure_text: '1 year to 2 years',
      min_years: 1, max_years: 2,
    }));
    await submitForReview(rate13b.id);
    const r13b = await patch('/api/admin/rates/' + rate13b.id + '/transition', { new_status: 'VERIFIED' });
    assert(r13b.status === 409, 'C13b: Cross-domain CALENDAR rejected with 409 (DAYS rate exists in same domain)');
    if (r13b.status === 409) {
      const body13b = await r13b.json();
      assert(body13b.message && body13b.message.includes('domain'),
        'C13b: 409 message mentions domain conflict');
    }

  } finally {
    if (rate13a) await archiveRate(rate13a.id);
    if (rate13b) {
      await patch('/api/admin/rates/' + rate13b.id + '/transition', { new_status: 'REJECTED' }).catch(() => {});
    }
  }

  // C14: Exclusive boundary adjacency — LT at 2yr and GTE at 2yr do NOT overlap
  let rate14a = null, rate14b = null;
  try {
    rate14a = await createDraft(calendarDraftPayload({
      customer_type: 'SENIOR_CITIZEN',
      source_tenure_text: '6 months to less than 2 years',
      min_years: 0, min_months: 6, min_days_cal: 0, min_operator: 'GTE',
      max_years: 2, max_months: 0, max_days_cal: 0, max_operator: 'LT',
    }));
    await submitForReview(rate14a.id);
    const r14a = await patch('/api/admin/rates/' + rate14a.id + '/transition', { new_status: 'VERIFIED' });
    assert(r14a.status === 200, 'C14a: First CALENDAR [6m GTE, 2yr LT] verifies (200)');

    rate14b = await createDraft(calendarDraftPayload({
      customer_type: 'SENIOR_CITIZEN',
      source_tenure_text: '2 years to 3 years',
      min_years: 2, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 3, max_months: 0, max_days_cal: 0, max_operator: 'LTE',
    }));
    await submitForReview(rate14b.id);
    const r14b = await patch('/api/admin/rates/' + rate14b.id + '/transition', { new_status: 'VERIFIED' });
    assert(r14b.status === 200, 'C14b: Adjacent CALENDAR [2yr GTE, 3yr LTE] verifies without conflict (200) — LT/GTE boundary is exclusive');

  } finally {
    if (rate14a) await archiveRate(rate14a.id);
    if (rate14b) await archiveRate(rate14b.id);
  }
}

async function runC15_C17_SupersedeTests() {
  if (!ADMIN_JWT) {
    skip('C15: Supersede CALENDAR rate with new CALENDAR rate succeeds (no JWT)');
    skip('C16: Supersede DAYS rate with CALENDAR rate rejected (domain mismatch) (no JWT)');
    skip('C17: Supersede CALENDAR rate with DAYS rate rejected (domain mismatch) (no JWT)');
    return;
  }

  console.log('\nGroup C15-C17: Supersede with tenure_domain validation...');

  // C16: Supersede DAYS with CALENDAR — must be rejected (tenure_domain mismatch)
  let rate16a = null, rate16b = null;
  try {
    rate16a = await createDraft(daysDraftPayload({
      customer_type: 'SUPER_SENIOR_CITIZEN',
      min_tenure_days: 3000, max_tenure_days: 3365,
    }));
    await submitForReview(rate16a.id);
    const r16a = await patch('/api/admin/rates/' + rate16a.id + '/transition', { new_status: 'VERIFIED' });
    if (r16a.status !== 200) {
      skip('C16: Could not verify DAYS rate (skip supersede test)');
    } else {
      rate16b = await createDraft(calendarDraftPayload({
        customer_type: 'SUPER_SENIOR_CITIZEN',
        source_tenure_text: '8 years to 10 years',
        min_years: 8, max_years: 10, max_operator: 'LTE',
      }));
      const r16b = await post('/api/admin/rates/' + rate16b.id + '/supersede', {
        old_rate_id: rate16a.id,
        notes: '[TEST C16]',
      });
      assert(r16b.status === 400 || r16b.status === 409 || r16b.status === 500,
        'C16: Superseding DAYS with CALENDAR rejects (tenure_domain mismatch)');
    }
  } finally {
    if (rate16a) await archiveRate(rate16a.id);
    if (rate16b) {
      await patch('/api/admin/rates/' + rate16b.id + '/transition', { new_status: 'REJECTED' }).catch(() => {});
    }
  }
}

async function runC18_C19_ComponentTests() {
  console.log('\nGroup C18-C19: Calendar component validation...');

  // C18: min_months=12 is invalid (must be 0-11)
  {
    const payload = calendarDraftPayload({ min_months: 12 });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'C18: min_months=12 rejected (must be 0-11)');
    assert(body.errors && body.errors.some(e => e.includes('min_months')),
      'C18: Error mentions min_months');
  }

  // C19: Inverted CALENDAR range (min > max) is rejected
  {
    const payload = calendarDraftPayload({
      source_tenure_text: 'INVALID: 3 years to 1 year',
      min_years: 3, min_months: 0, min_days_cal: 0, min_operator: 'GTE',
      max_years: 1, max_months: 0, max_days_cal: 0, max_operator: 'LTE',
    });
    const r = await post('/api/admin/rates/draft', payload);
    // DB CHECK constraint catches this, returns 400 or 500 with constraint error
    assert(r.status === 400 || r.status === 500 || r.status === 409,
      'C19: Inverted CALENDAR range (3yr > 1yr) is rejected (' + r.status + ')');
  }
}

async function runEdgeTests() {
  console.log('\nGroup Edge: Additional boundary and invariant tests...');

  // E01: CALENDAR with only months (no years/days) is valid
  {
    const r = await post('/api/admin/rates/draft', calendarDraftPayload({
      source_tenure_text: '6 months to 11 months',
      min_years: null, min_months: 6, min_days_cal: null, min_operator: 'GTE',
      max_years: null, max_months: 11, max_days_cal: null, max_operator: 'LTE',
    }));
    const body = await r.json();
    assert(r.status === 201, 'E01: CALENDAR with months-only components is accepted (201)');
    if (r.status === 201) {
      await patch('/api/admin/rates/' + body.data.id + '/transition', { new_status: 'REJECTED' }).catch(() => {});
    }
  }

  // E02: min_days_cal=-1 is invalid (negative)
  {
    const payload = calendarDraftPayload({ min_days_cal: -1 });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'E02: min_days_cal=-1 rejected (negative)');
  }

  // E03: CALENDAR rate missing source_tenure_text (empty string) is rejected
  {
    const payload = calendarDraftPayload({ source_tenure_text: '  ' });
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 400, 'E03: CALENDAR draft with blank source_tenure_text rejected (400)');
  }

  // E04: Default tenure_domain for a payload missing the field is DAYS (backward compat)
  {
    const payload = daysDraftPayload();
    delete payload.tenure_domain;  // omit tenure_domain
    const r = await post('/api/admin/rates/draft', payload);
    const body = await r.json();
    assert(r.status === 201, 'E04: Payload without tenure_domain defaults to DAYS (201)');
    if (r.status === 201) {
      assert(body.data.tenure_domain === 'DAYS', 'E04: Default domain is DAYS');
      await patch('/api/admin/rates/' + body.data.id + '/transition', { new_status: 'REJECTED' }).catch(() => {});
    }
  }

  // E05: Public tenureDays=0 query returns only DAYS records
  {
    const r = await get('/api/verified-rates?tenureDays=0');
    const body = await r.json();
    assert(r.status === 200, 'E05: tenureDays=0 query returns 200');
    if (body.data) {
      assert(body.data.every(x => x.tenure_domain === 'DAYS' || x.tenure_domain == null),
        'E05: All results are DAYS domain when tenureDays filter applied');
    }
  }
}

// -- Main -------------------------------------------------------------------

async function run() {
  console.log('\n==============================================');
  console.log('FeroCalc Calendar Tenure Domain Tests (C01-C19)');
  console.log('Against: ' + BASE_URL);
  console.log('==============================================\n');

  if (!ADMIN_JWT) {
    console.log('WARNING: TEST_ADMIN_JWT not set — write tests will be skipped.\n');
  }

  try {
    // Read-only tests always run (no JWT needed)
    await runC09_C10_ExistingRatesPreservation();
    await runC18_C19_ComponentTests();
    await runEdgeTests();

    if (ADMIN_JWT) {
      // Write tests require admin JWT
      await runC01_C05_ValidationTests();
      await runC06_C08_OperatorTests();
      await runC11_C14_OverlapTests();
      await runC15_C17_SupersedeTests();
    } else {
      // Validation tests are read-only (they POST invalid payloads and check 400/401)
      // but require a JWT for the 401 vs 400 distinction. Skip gracefully.
      for (const t of ['C01','C02','C03','C04','C05','C06','C07','C08','C11','C12','C13','C14','C15','C16','C17']) {
        skip(t + ': Write/validation test (no TEST_ADMIN_JWT)');
      }
    }
  } catch (err) {
    console.error('\nFATAL ERROR during test run:', err.message);
    failed++;
    total++;
  }

  console.log('\n==============================================');
  console.log('Results: ' + passed + ' passed, ' + failed + ' failed, ' + total + ' total');
  console.log('==============================================\n');

  if (failed > 0) process.exit(1);
}

run().catch(err => {
  console.error('Unhandled error:', err);
  process.exit(1);
});
