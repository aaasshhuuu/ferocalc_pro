// FeroCalc Verified FD Rate Engine — Phase 3C.3 Verified Rates API Test Suite
//
// Tests product-dimension filtering on public verified-rate endpoints:
// - GET /api/verified-rates
// - GET /api/verified-rates/top
// - GET /api/verified-rates/bank/:id
//
// Invariants tested:
// - Test A: Omitted isCallable defaults to true (callable-only safe default).
// - Test B: isCallable=true returns callable only.
// - Test C: isCallable=false returns non-callable only.
// - Test D: isCallable=all returns both callable and non-callable.
// - Test E: Snake_case is_callable works identically.
// - Test F: /top default never ranks non-callable rates.
// - Test G: /bank/:id respects isCallable (callable by default, supports false & all).
// - Test H: Invalid isCallable values return HTTP 400 Bad Request with explicit message.

'use strict';

const assert = require('assert');
const express = require('express');

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function runTest(name, fn) {
  totalTests++;
  try {
    fn();
    passedTests++;
    console.log(`  PASS: ${name}`);
  } catch (err) {
    failedTests++;
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
  }
}

async function runTestAsync(name, fn) {
  totalTests++;
  try {
    await fn();
    passedTests++;
    console.log(`  PASS: ${name}`);
  } catch (err) {
    failedTests++;
    console.error(`  FAIL: ${name}`);
    console.error(`        ${err.message}`);
  }
}

// ---------------------------------------------------------------------------
// Mock Supabase Query Engine & Setup
// ---------------------------------------------------------------------------

const ICICI_BANK_ID = '43b748bd-2155-4a3f-8dd0-5249ede00cac';
const SBI_BANK_ID   = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';

// Sample dataset containing both callable and non-callable rates
const MOCK_DATASET = [
  {
    id: 'sbi-rate-1',
    bank_id: SBI_BANK_ID,
    bank_name: 'State Bank of India',
    customer_type: 'REGULAR',
    tenure_domain: 'DAYS',
    min_tenure_days: 365,
    max_tenure_days: 389,
    interest_rate: 6.80,
    is_callable: true,
  },
  {
    id: 'icici-callable-1',
    bank_id: ICICI_BANK_ID,
    bank_name: 'ICICI Bank',
    customer_type: 'REGULAR',
    tenure_domain: 'DAYS',
    min_tenure_days: 365,
    max_tenure_days: 389,
    interest_rate: 6.25,
    is_callable: true,
  },
  {
    id: 'icici-noncallable-1',
    bank_id: ICICI_BANK_ID,
    bank_name: 'ICICI Bank',
    customer_type: 'REGULAR',
    tenure_domain: 'DAYS',
    min_tenure_days: 365,
    max_tenure_days: 389,
    interest_rate: 6.50,
    is_callable: false,
  },
  {
    id: 'icici-callable-senior',
    bank_id: ICICI_BANK_ID,
    bank_name: 'ICICI Bank',
    customer_type: 'SENIOR_CITIZEN',
    tenure_domain: 'DAYS',
    min_tenure_days: 365,
    max_tenure_days: 389,
    interest_rate: 6.75,
    is_callable: true,
  },
  {
    id: 'icici-noncallable-senior',
    bank_id: ICICI_BANK_ID,
    bank_name: 'ICICI Bank',
    customer_type: 'SENIOR_CITIZEN',
    tenure_domain: 'DAYS',
    min_tenure_days: 365,
    max_tenure_days: 389,
    interest_rate: 7.00,
    is_callable: false,
  },
];

let lastQueryOps = [];

let currentDataset = MOCK_DATASET;

class MockQueryBuilder {
  constructor(dataset) {
    this.dataset = [...dataset];
    this.ops = [];
    lastQueryOps = this.ops;
  }
  select(fields) {
    this.ops.push({ op: 'select', fields });
    return this;
  }
  order(field, opts) {
    this.ops.push({ op: 'order', field, opts });
    const ascending = opts?.ascending ?? true;
    this.dataset.sort((a, b) => {
      if (a[field] < b[field]) return ascending ? -1 : 1;
      if (a[field] > b[field]) return ascending ? 1 : -1;
      return 0;
    });
    return this;
  }
  limit(n) {
    this.ops.push({ op: 'limit', n });
    this.dataset = this.dataset.slice(0, n);
    return this;
  }
  eq(field, val) {
    this.ops.push({ op: 'eq', field, val });
    this.dataset = this.dataset.filter(r => r[field] === val);
    return this;
  }
  lte(field, val) {
    this.ops.push({ op: 'lte', field, val });
    this.dataset = this.dataset.filter(r => r[field] != null && r[field] <= val);
    return this;
  }
  gte(field, val) {
    this.ops.push({ op: 'gte', field, val });
    this.dataset = this.dataset.filter(r => r[field] != null && r[field] >= val);
    return this;
  }
  or(clause) {
    this.ops.push({ op: 'or', clause });
    return this;
  }
  then(resolve, reject) {
    return Promise.resolve({ data: this.dataset, error: null }).then(resolve, reject);
  }
}

const mockSupabasePublic = {
  from: (table) => {
    return new MockQueryBuilder(currentDataset);
  },
};

// Install mock into require.cache before requiring routes/verified_rates
const clientPath = require.resolve('../supabase/supabase_client');
require.cache[clientPath] = {
  id: clientPath,
  filename: clientPath,
  loaded: true,
  exports: {
    supabasePublic: mockSupabasePublic,
    supabaseAdmin: mockSupabasePublic,
    isSupabaseAvailable: () => true,
    verifySupabaseUser: async () => ({ id: 'mock-user' }),
  },
};

const verifiedRatesRouter = require('../routes/verified_rates');
const { parseIsCallableFilter } = verifiedRatesRouter;

async function run() {
  console.log('\n======================================================');
  console.log('FeroCalc Phase 3C.3 Verified Rates API Test Suite');
  console.log('======================================================\n');

  // -------------------------------------------------------------------------
  console.log('Group 1: Helper parseIsCallableFilter Unit Tests...');
  // -------------------------------------------------------------------------

  runTest('1. Omitted / empty query defaults to filterValue: true', () => {
    const res1 = parseIsCallableFilter({});
    assert.strictEqual(res1.filterValue, true);
    assert.strictEqual(res1.hasError, false);

    const res2 = parseIsCallableFilter({ isCallable: '' });
    assert.strictEqual(res2.filterValue, true);
    assert.strictEqual(res2.hasError, false);

    const res3 = parseIsCallableFilter({ is_callable: '   ' });
    assert.strictEqual(res3.filterValue, true);
    assert.strictEqual(res3.hasError, false);
  });

  runTest('2. isCallable=true and isCallable=1 parse to filterValue: true', () => {
    const res1 = parseIsCallableFilter({ isCallable: 'true' });
    assert.strictEqual(res1.filterValue, true);
    assert.strictEqual(res1.hasError, false);

    const res2 = parseIsCallableFilter({ isCallable: '1' });
    assert.strictEqual(res2.filterValue, true);
    assert.strictEqual(res2.hasError, false);

    const res3 = parseIsCallableFilter({ isCallable: 'TRUE' });
    assert.strictEqual(res3.filterValue, true);
    assert.strictEqual(res3.hasError, false);
  });

  runTest('3. isCallable=false and isCallable=0 parse to filterValue: false', () => {
    const res1 = parseIsCallableFilter({ isCallable: 'false' });
    assert.strictEqual(res1.filterValue, false);
    assert.strictEqual(res1.hasError, false);

    const res2 = parseIsCallableFilter({ isCallable: '0' });
    assert.strictEqual(res2.filterValue, false);
    assert.strictEqual(res2.hasError, false);

    const res3 = parseIsCallableFilter({ isCallable: 'FALSE' });
    assert.strictEqual(res3.filterValue, false);
    assert.strictEqual(res3.hasError, false);
  });

  runTest('4. isCallable=all parses to filterValue: null (no filter)', () => {
    const res1 = parseIsCallableFilter({ isCallable: 'all' });
    assert.strictEqual(res1.filterValue, null);
    assert.strictEqual(res1.hasError, false);

    const res2 = parseIsCallableFilter({ isCallable: 'ALL' });
    assert.strictEqual(res2.filterValue, null);
    assert.strictEqual(res2.hasError, false);
  });

  runTest('5. Snake case is_callable parses identically', () => {
    assert.strictEqual(parseIsCallableFilter({ is_callable: 'true' }).filterValue, true);
    assert.strictEqual(parseIsCallableFilter({ is_callable: 'false' }).filterValue, false);
    assert.strictEqual(parseIsCallableFilter({ is_callable: 'all' }).filterValue, null);
  });

  runTest('6. Invalid isCallable values return hasError: true with explicit message', () => {
    const invalidVals = ['maybe', 'invalid', '2', 'none', 'yes', 'no'];
    for (const val of invalidVals) {
      const res = parseIsCallableFilter({ isCallable: val });
      assert.strictEqual(res.hasError, true, `Should flag ${val} as error`);
      assert.strictEqual(res.filterValue, null);
      assert.ok(res.errorMessage.includes('Must be one of: true, false, all'));
      assert.ok(res.errorMessage.includes(val));
    }
  });

  // -------------------------------------------------------------------------
  console.log('\nGroup 2: HTTP Integration Tests via Local Express...');
  // -------------------------------------------------------------------------

  const app = express();
  app.use('/api/verified-rates', verifiedRatesRouter);

  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}/api/verified-rates`;

  try {
    await runTestAsync('7. [Test A] GET /api/verified-rates defaults to callable-only (is_callable=true)', async () => {
      const res = await fetch(baseUrl);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.ok(json.data.length > 0);

      // Verify DB query applied .eq('is_callable', true)
      const callableOp = lastQueryOps.find(op => op.op === 'eq' && op.field === 'is_callable');
      assert.ok(callableOp, 'Expected eq("is_callable", true) in query');
      assert.strictEqual(callableOp.val, true);

      // Verify all returned records have is_callable === true
      assert.ok(json.data.every(r => r.is_callable === true));
      assert.ok(!json.data.some(r => r.is_callable === false));
    });

    await runTestAsync('8. [Test B] GET /api/verified-rates?isCallable=true returns callable only', async () => {
      const res = await fetch(`${baseUrl}?isCallable=true`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');

      const callableOp = lastQueryOps.find(op => op.op === 'eq' && op.field === 'is_callable');
      assert.ok(callableOp);
      assert.strictEqual(callableOp.val, true);
      assert.ok(json.data.every(r => r.is_callable === true));
    });

    await runTestAsync('9. [Test C] GET /api/verified-rates?isCallable=false returns non-callable only', async () => {
      const res = await fetch(`${baseUrl}?isCallable=false`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.ok(json.data.length > 0);

      const callableOp = lastQueryOps.find(op => op.op === 'eq' && op.field === 'is_callable');
      assert.ok(callableOp);
      assert.strictEqual(callableOp.val, false);
      assert.ok(json.data.every(r => r.is_callable === false));
      assert.ok(!json.data.some(r => r.is_callable === true));
    });

    await runTestAsync('10. [Test D] GET /api/verified-rates?isCallable=all returns both callable and non-callable', async () => {
      const res = await fetch(`${baseUrl}?isCallable=all`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');

      // Verify DB query did NOT apply any filter on is_callable
      const callableOp = lastQueryOps.find(op => op.op === 'eq' && op.field === 'is_callable');
      assert.strictEqual(callableOp, undefined, 'Should not filter by is_callable when isCallable=all');

      assert.ok(json.data.some(r => r.is_callable === true), 'Should contain callable');
      assert.ok(json.data.some(r => r.is_callable === false), 'Should contain non-callable');
    });

    await runTestAsync('11. [Test E] Snake_case query parameters work identically', async () => {
      const resFalse = await fetch(`${baseUrl}?is_callable=false`);
      assert.strictEqual(resFalse.status, 200);
      const jsonFalse = await resFalse.json();
      assert.ok(jsonFalse.data.every(r => r.is_callable === false));

      const resAll = await fetch(`${baseUrl}?is_callable=all`);
      assert.strictEqual(resAll.status, 200);
      const jsonAll = await resAll.json();
      assert.ok(jsonAll.data.some(r => r.is_callable === true));
      assert.ok(jsonAll.data.some(r => r.is_callable === false));
    });

    await runTestAsync('12. [Test F] GET /api/verified-rates/top defaults to callable-only', async () => {
      const res = await fetch(`${baseUrl}/top`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');

      const callableOp = lastQueryOps.find(op => op.op === 'eq' && op.field === 'is_callable');
      assert.ok(callableOp, 'Expected eq("is_callable", true) in /top');
      assert.strictEqual(callableOp.val, true);
      assert.ok(json.data.every(r => r.is_callable === true));
      assert.ok(!json.data.some(r => r.is_callable === false));
    });

    await runTestAsync('13. [Test F] GET /api/verified-rates/top?isCallable=false ranks non-callable only', async () => {
      const res = await fetch(`${baseUrl}/top?isCallable=false`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.ok(json.data.every(r => r.is_callable === false));
    });

    await runTestAsync('14. [Test G] GET /api/verified-rates/bank/:id defaults to callable-only', async () => {
      const res = await fetch(`${baseUrl}/bank/${ICICI_BANK_ID}`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');

      const callableOp = lastQueryOps.find(op => op.op === 'eq' && op.field === 'is_callable');
      assert.ok(callableOp);
      assert.strictEqual(callableOp.val, true);
      assert.ok(json.data.every(r => r.is_callable === true));
      assert.ok(!json.data.some(r => r.is_callable === false));
    });

    await runTestAsync('15. [Test G] GET /api/verified-rates/bank/:id?isCallable=all returns both', async () => {
      const res = await fetch(`${baseUrl}/bank/${ICICI_BANK_ID}?isCallable=all`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.ok(json.data.some(r => r.is_callable === true));
      assert.ok(json.data.some(r => r.is_callable === false));
    });

    await runTestAsync('16. [Test H] Invalid isCallable value returns 400 Bad Request on GET /', async () => {
      const res = await fetch(`${baseUrl}?isCallable=invalid_choice`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('Must be one of: true, false, all'));
      assert.ok(json.message.includes('invalid_choice'));
    });

    await runTestAsync('17. [Test H] Invalid isCallable value returns 400 Bad Request on GET /top', async () => {
      const res = await fetch(`${baseUrl}/top?isCallable=maybe`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('Must be one of: true, false, all'));
      assert.ok(json.message.includes('maybe'));
    });

    await runTestAsync('18. [Test H] Invalid isCallable value returns 400 Bad Request on GET /bank/:id', async () => {
      const res = await fetch(`${baseUrl}/bank/${ICICI_BANK_ID}?isCallable=foo`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('Must be one of: true, false, all'));
      assert.ok(json.message.includes('foo'));
    });

    await runTestAsync('19. [Test H] Invalid is_callable returns 400 Bad Request', async () => {
      const res = await fetch(`${baseUrl}?is_callable=bogus`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('Must be one of: true, false, all'));
    });

    console.log('\n--- Group 3: Phase 3C.5.46 Calendar Tenure Query & Parameter Validation Tests ---');

    runTest('20. parseTenureQueryParams parses valid DAYS tenureDays', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ tenureDays: '365' });
      assert.strictEqual(parsed.hasError, false);
      assert.strictEqual(parsed.domain, 'DAYS');
      assert.strictEqual(parsed.tenureDays, 365);
    });

    runTest('21. parseTenureQueryParams parses valid CALENDAR components', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ years: '2', months: '6', daysCal: '15' });
      assert.strictEqual(parsed.hasError, false);
      assert.strictEqual(parsed.domain, 'CALENDAR');
      assert.strictEqual(parsed.years, 2);
      assert.strictEqual(parsed.months, 6);
      assert.strictEqual(parsed.daysCal, 15);
    });

    runTest('22. parseTenureQueryParams enforces mutual exclusion between tenureDays and calendar components', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ tenureDays: '365', years: '1' });
      assert.strictEqual(parsed.hasError, true);
      assert.ok(parsed.errorMessage.includes('Mutually exclusive parameters'));
    });

    runTest('23. parseTenureQueryParams rejects negative tenureDays', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ tenureDays: '-10' });
      assert.strictEqual(parsed.hasError, true);
      assert.ok(parsed.errorMessage.includes('non-negative integer'));
    });

    runTest('24. parseTenureQueryParams rejects negative years', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ years: '-1' });
      assert.strictEqual(parsed.hasError, true);
      assert.ok(parsed.errorMessage.includes('years must be a non-negative integer'));
    });

    runTest('25. parseTenureQueryParams rejects months out of range (months > 11)', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ months: '12' });
      assert.strictEqual(parsed.hasError, true);
      assert.ok(parsed.errorMessage.includes('months must be an integer between 0 and 11'));
    });

    runTest('26. parseTenureQueryParams rejects all-zero calendar components', () => {
      const parsed = verifiedRatesRouter.parseTenureQueryParams({ years: '0', months: '0', daysCal: '0' });
      assert.strictEqual(parsed.hasError, true);
      assert.ok(parsed.errorMessage.includes('greater than zero'));
    });

    await runTestAsync('27. GET /api/verified-rates rejects conflicting tenureDays and calendar parameters (400 Bad Request)', async () => {
      const res = await fetch(`${baseUrl}?tenureDays=365&years=1`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('Mutually exclusive parameters'));
    });

    await runTestAsync('28. GET /api/verified-rates rejects invalid months > 11 (400 Bad Request)', async () => {
      const res = await fetch(`${baseUrl}?months=15`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('months must be an integer between 0 and 11'));
    });

    await runTestAsync('29. GET /api/verified-rates rejects all-zero calendar components (400 Bad Request)', async () => {
      const res = await fetch(`${baseUrl}?years=0&months=0&daysCal=0`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('greater than zero'));
    });

    await runTestAsync('30. GET /api/verified-rates/top rejects conflicting tenureDays and months (400 Bad Request)', async () => {
      const res = await fetch(`${baseUrl}/top?tenureDays=365&months=6`);
      assert.strictEqual(res.status, 400);
      const json = await res.json();
      assert.strictEqual(json.status, 'error');
      assert.ok(json.message.includes('Mutually exclusive parameters'));
    });

    await runTestAsync('31. GET /api/verified-rates with calendar tenure returns empty array gracefully (empty-safe)', async () => {
      const res = await fetch(`${baseUrl}?years=1&months=0&daysCal=0`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.strictEqual(json.data.length, 0); // No CALENDAR records in DB view
      assert.strictEqual(json.meta.count, 0);
    });

    await runTestAsync('32. GET /api/verified-rates/top with calendar tenure returns empty array gracefully', async () => {
      const res = await fetch(`${baseUrl}/top?years=2`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.strictEqual(json.data.length, 0);
    });

    console.log('\n--- Group 4: Phase 3C.5.47 Calendar Fallback Isolation & Verified API Safety Tests ---');

    const HDFC_BANK_ID = 'b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e';

    const MOCK_CALENDAR_DATASET = [
      // DAYS rate (SBI)
      {
        id: 'sbi-rate-days',
        bank_id: SBI_BANK_ID,
        bank_name: 'State Bank of India',
        customer_type: 'REGULAR',
        tenure_domain: 'DAYS',
        min_tenure_days: 365,
        max_tenure_days: 389,
        interest_rate: 6.80,
        is_callable: true,
      },
      // CALENDAR slab 1: [1 Year, 2 Years) -> 7.10%
      {
        id: 'hdfc-cal-1y-2y',
        bank_id: HDFC_BANK_ID,
        bank_name: 'HDFC Bank',
        customer_type: 'REGULAR',
        tenure_domain: 'CALENDAR',
        source_tenure_text: '1 Year to < 2 Years',
        min_years: 1,
        min_months: 0,
        min_days_cal: 0,
        min_operator: 'GTE',
        max_years: 2,
        max_months: 0,
        max_days_cal: 0,
        max_operator: 'LT',
        interest_rate: 7.10,
        is_callable: true,
      },
      // CALENDAR slab 2: [2 Years, 3 Years) -> 7.00%
      {
        id: 'hdfc-cal-2y-3y',
        bank_id: HDFC_BANK_ID,
        bank_name: 'HDFC Bank',
        customer_type: 'REGULAR',
        tenure_domain: 'CALENDAR',
        source_tenure_text: '2 Years to < 3 Years',
        min_years: 2,
        min_months: 0,
        min_days_cal: 0,
        min_operator: 'GTE',
        max_years: 3,
        max_months: 0,
        max_days_cal: 0,
        max_operator: 'LT',
        interest_rate: 7.00,
        is_callable: true,
      },
      // CALENDAR slab 3: (> 1 Year, 2 Years] -> 7.25% (strict GT lower bound)
      {
        id: 'hdfc-cal-gt-1y-2y',
        bank_id: HDFC_BANK_ID,
        bank_name: 'HDFC Bank',
        customer_type: 'REGULAR',
        tenure_domain: 'CALENDAR',
        source_tenure_text: '> 1 Year to 2 Years',
        min_years: 1,
        min_months: 0,
        min_days_cal: 0,
        min_operator: 'GT',
        max_years: 2,
        max_months: 0,
        max_days_cal: 0,
        max_operator: 'LTE',
        interest_rate: 7.25,
        is_callable: true,
      },
      // CALENDAR slab 4: [1 Month, 2 Months) -> 5.50% (variable month length, indeterminate for 30d without anchor)
      {
        id: 'hdfc-cal-1m-2m',
        bank_id: HDFC_BANK_ID,
        bank_name: 'HDFC Bank',
        customer_type: 'REGULAR',
        tenure_domain: 'CALENDAR',
        source_tenure_text: '1 Month to < 2 Months',
        min_years: 0,
        min_months: 1,
        min_days_cal: 0,
        min_operator: 'GTE',
        max_years: 0,
        max_months: 2,
        max_days_cal: 0,
        max_operator: 'LT',
        interest_rate: 5.50,
        is_callable: true,
      },
    ];

    // Switch mock database to calendar dataset
    currentDataset = MOCK_CALENDAR_DATASET;

    // 33. Helper unit test: coversCalendarTenure matches valid calendar record
    runTest('33. coversCalendarTenure matches valid CALENDAR record in range', () => {
      const rate = MOCK_CALENDAR_DATASET[1]; // 1Y to < 2Y
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(rate, { years: 1, months: 6, daysCal: 0 }), true);
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(rate, { years: 1, months: 0, daysCal: 0 }), true);
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(rate, { years: 2, months: 0, daysCal: 0 }), false);
    });

    // 34. Helper unit test: coversCalendarTenure strictly rejects DAYS records
    runTest('34. coversCalendarTenure strictly rejects DAYS records', () => {
      const daysRate = MOCK_CALENDAR_DATASET[0]; // DAYS record
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(daysRate, { years: 1, months: 0, daysCal: 0 }), false);
    });

    // 35. Helper unit test: coversCalendarTenure respects strict GT lower bound
    runTest('35. coversCalendarTenure respects strict GT lower bound', () => {
      const gtRate = MOCK_CALENDAR_DATASET[3]; // > 1Y to 2Y
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(gtRate, { years: 1, months: 0, daysCal: 0 }), false);
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(gtRate, { years: 1, months: 0, daysCal: 1 }), true);
    });

    // 36. Helper unit test: coversCalendarTenure returns null for indeterminate Gregorian boundary without anchor
    runTest('36. coversCalendarTenure returns null for indeterminate Gregorian boundary without anchor', () => {
      const mRate = MOCK_CALENDAR_DATASET[4]; // 1M to < 2M
      // 30 days vs 1 Month: 28 <= 30 <= 31 -> indeterminate
      assert.strictEqual(verifiedRatesRouter.coversCalendarTenure(mRate, { years: 0, months: 0, daysCal: 30 }), null);
    });

    // 37. HTTP Test: Matching verified CALENDAR rate returned for requested tenure
    await runTestAsync('37. GET /api/verified-rates returns matching verified CALENDAR rate for requested tenure', async () => {
      const res = await fetch(`${baseUrl}?years=1&months=6&daysCal=0`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      const ids = json.data.map(r => r.id);
      assert.ok(ids.includes('hdfc-cal-1y-2y'));
      assert.ok(ids.includes('hdfc-cal-gt-1y-2y'));
    });

    // 38. HTTP Test: Verified CALENDAR rate outside requested tenure is excluded
    await runTestAsync('38. GET /api/verified-rates excludes CALENDAR rates outside requested tenure', async () => {
      const res = await fetch(`${baseUrl}?years=2&months=6&daysCal=0`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      const ids = json.data.map(r => r.id);
      assert.ok(ids.includes('hdfc-cal-2y-3y'));
      assert.ok(!ids.includes('hdfc-cal-1y-2y'), '1Y to < 2Y must be excluded from 2Y 6M');
      assert.ok(!ids.includes('hdfc-cal-gt-1y-2y'), '>1Y to 2Y must be excluded from 2Y 6M');
    });

    // 39. HTTP Test: Matching DAYS rate excluded from a CALENDAR request
    await runTestAsync('39. GET /api/verified-rates strictly excludes DAYS rates from CALENDAR query', async () => {
      const res = await fetch(`${baseUrl}?years=1&months=0&daysCal=0`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      const ids = json.data.map(r => r.id);
      assert.ok(!ids.includes('sbi-rate-days'), 'DAYS rate (SBI 365d) must never match a CALENDAR 1Y query');
      assert.ok(json.data.every(r => r.tenure_domain === 'CALENDAR'));
    });

    // 40. HTTP Test: Empty results returned safely when no verified CALENDAR rate matches
    await runTestAsync('40. GET /api/verified-rates returns empty array safely when no CALENDAR rate matches', async () => {
      const res = await fetch(`${baseUrl}?years=10&months=0&daysCal=0`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.strictEqual(json.data.length, 0);
      assert.strictEqual(json.meta.count, 0);
    });

    // 41. HTTP Test: Existing DAYS query behavior preserved
    await runTestAsync('41. GET /api/verified-rates preserves existing DAYS query behavior', async () => {
      const res = await fetch(`${baseUrl}?tenureDays=365`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      const ids = json.data.map(r => r.id);
      assert.ok(ids.includes('sbi-rate-days'));
      assert.ok(json.data.every(r => r.tenure_domain === 'DAYS'));
    });

    // 42. HTTP Test: Unresolved calendar coverage never presented as confirmed best rate on GET /top
    await runTestAsync('42. GET /api/verified-rates/top never presents unresolved coverage as confirmed best rate', async () => {
      const res = await fetch(`${baseUrl}/top?months=0&daysCal=30`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.strictEqual(json.data.length, 0);
    });

    // 43. HTTP Test: GET /top correctly ranks verified CALENDAR rates descending by interest rate
    await runTestAsync('43. GET /api/verified-rates/top correctly ranks matching CALENDAR rates by rate descending', async () => {
      const res = await fetch(`${baseUrl}/top?years=1&months=6&daysCal=0&limit=2`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      assert.strictEqual(json.data.length, 2);
      assert.strictEqual(json.data[0].id, 'hdfc-cal-gt-1y-2y');
      assert.strictEqual(json.data[0].interest_rate, 7.25);
      assert.strictEqual(json.data[1].id, 'hdfc-cal-1y-2y');
      assert.strictEqual(json.data[1].interest_rate, 7.10);
    });

    // 44. HTTP Test: Strict GT boundary exclusion on GET /api/verified-rates
    await runTestAsync('44. GET /api/verified-rates respects strict GT boundary for exact boundary query', async () => {
      const res = await fetch(`${baseUrl}?years=1&months=0&daysCal=0`);
      assert.strictEqual(res.status, 200);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
      const ids = json.data.map(r => r.id);
      assert.ok(ids.includes('hdfc-cal-1y-2y'));
      assert.ok(!ids.includes('hdfc-cal-gt-1y-2y'), 'GT boundary must reject exact lower bound');
    });

  } finally {
    server.close();
  }

  console.log('\n======================================================');
  console.log(`Results: ${passedTests} passed, ${failedTests} failed (Total: ${totalTests})`);
  console.log('======================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

run().catch(err => {
  console.error('Test suite failed with uncaught error:', err);
  process.exit(1);
});
