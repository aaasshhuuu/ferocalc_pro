// FeroCalc Verified FD Rate Engine — Security Hardening Test Suite
const BASE_URL = process.env.TEST_BASE_URL || 'https://backend-ten-livid-14.vercel.app';

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, message) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log('  PASS: ' + message);
  } else {
    failedTests++;
    console.error('  FAIL: ' + message);
  }
}

async function run() {
  console.log('\n======================================================');
  console.log('FeroCalc Security Hardening Tests against: ' + BASE_URL);
  console.log('======================================================\n');

  console.log('Group 1: Verifying Retirement of Pilot-Only Endpoints...');
  const r1 = await fetch(BASE_URL + '/api/admin/create-pilot-draft', { method: 'POST' });
  assert(r1.status === 404, 'POST /api/admin/create-pilot-draft returns 404 Not Found (got ' + r1.status + ')');

  const r2 = await fetch(BASE_URL + '/api/admin/pilot-draft');
  assert(r2.status === 404, 'GET /api/admin/pilot-draft returns 404 Not Found (got ' + r2.status + ')');

  const r3 = await fetch(BASE_URL + '/api/admin/verify-pilot-rate', { method: 'POST' });
  assert(r3.status === 404, 'POST /api/admin/verify-pilot-rate returns 404 Not Found (got ' + r3.status + ')');

  const r4 = await fetch(BASE_URL + '/api/admin/pilot-verified');
  assert(r4.status === 404, 'GET /api/admin/pilot-verified returns 404 Not Found (got ' + r4.status + ')');

  console.log('\nGroup 2: Verifying Admin Authentication Enforcement...');
  const r5 = await fetch(BASE_URL + '/api/admin/rates');
  assert(r5.status === 401, 'GET /api/admin/rates without token returns 401 (got ' + r5.status + ')');

  const r6 = await fetch(BASE_URL + '/api/admin/rates/draft', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ bank_id: 'fake' }),
  });
  assert(r6.status === 401, 'POST /api/admin/rates/draft without token returns 401 (got ' + r6.status + ')');

  const r7 = await fetch(BASE_URL + '/api/admin/rates/b8a85f4e-f324-44a6-a6a8-8ef5e6419297', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ interest_rate: 7.0 }),
  });
  assert(r7.status === 401, 'PATCH /api/admin/rates/:id without token returns 401 (got ' + r7.status + ')');

  const r8 = await fetch(BASE_URL + '/api/admin/rates/b8a85f4e-f324-44a6-a6a8-8ef5e6419297/transition', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ new_status: 'ARCHIVED' }),
  });
  assert(r8.status === 401, 'PATCH /api/admin/rates/:id/transition without token returns 401 (got ' + r8.status + ')');

  const r9 = await fetch(BASE_URL + '/api/admin/rates/b8a85f4e-f324-44a6-a6a8-8ef5e6419297/audit');
  assert(r9.status === 401, 'GET /api/admin/rates/:id/audit without token returns 401 (got ' + r9.status + ')');

  const r10 = await fetch(BASE_URL + '/api/admin/rates', {
    headers: { 'Authorization': 'Bearer invalid-token-123' },
  });
  assert(r10.status === 401, 'GET /api/admin/rates with invalid token returns 401 (got ' + r10.status + ')');

  console.log('\nGroup 3: Verifying Public Verified-Rate API Endpoints...');
  const r11 = await fetch(BASE_URL + '/api/verified-rates');
  assert(r11.status === 200, 'GET /api/verified-rates returns 200 OK (got ' + r11.status + ')');
  const body11 = await r11.json();
  assert(body11.status === 'ok', 'Response envelope status is ok');
  assert(Array.isArray(body11.data), 'Response data is an array');
  assert(body11.data.length >= 1, 'At least 1 verified rate is returned (count: ' + body11.data.length + ')');

  const sbiRate = body11.data.find(r => r.id === 'b8a85f4e-f324-44a6-a6a8-8ef5e6419297');
  assert(!!sbiRate, 'SBI verified rate b8a85f4e-f324-44a6-a6a8-8ef5e6419297 is present');
  if (sbiRate) {
    assert(sbiRate.bank_short_name === 'SBI', 'Bank is SBI');
    assert(sbiRate.interest_rate === 6.25, 'Interest rate is 6.25%');
    assert(sbiRate.customer_type === 'REGULAR', 'Customer type is REGULAR');
    assert(sbiRate.min_tenure_days === 365 && sbiRate.max_tenure_days === 729, 'Tenure is 365-729 days');
    assert(sbiRate.is_callable === true, 'is_callable is true');
    assert(sbiRate.compounding_frequency === 'QUARTERLY', 'compounding_frequency is QUARTERLY');
    assert(sbiRate.effective_from.startsWith('2025-12-15'), 'effective_from is 2025-12-15');
    assert(sbiRate.effective_until === null, 'effective_until is null (active)');
    assert(sbiRate.verified_at != null, 'verified_at timestamp exists');
    assert(sbiRate.source_url === 'https://sbi.co.in/web/interest-rates/deposit-rates/retail-domestic-term-deposits', 'source_url is official SBI URL');
  }

  const r12 = await fetch(BASE_URL + '/api/verified-rates/top');
  assert(r12.status === 200, 'GET /api/verified-rates/top returns 200 OK (got ' + r12.status + ')');
  const body12 = await r12.json();
  assert(body12.data.some(r => r.id === 'b8a85f4e-f324-44a6-a6a8-8ef5e6419297'), 'Top rates includes verified SBI rate');

  const r13 = await fetch(BASE_URL + '/api/verified-rates/bank/43b748bd-2155-4a3f-8dd0-5249ede00cac');
  assert(r13.status === 200, 'GET /api/verified-rates/bank/:sbi_id returns 200 OK (got ' + r13.status + ')');
  const body13 = await r13.json();
  assert(body13.data.some(r => r.id === 'b8a85f4e-f324-44a6-a6a8-8ef5e6419297'), 'Bank rates query returns SBI rate');

  const r14 = await fetch(BASE_URL + '/api/verified-rates/banks');
  assert(r14.status === 200, 'GET /api/verified-rates/banks returns 200 OK (got ' + r14.status + ')');
  const body14 = await r14.json();
  assert(body14.data.length === 5, 'Banks registry returns 5 pilot banks (got ' + body14.data.length + ')');

  console.log('\nGroup 4: Verifying Non-VERIFIED Data Cannot Leak...');
  for (const r of body11.data) {
    assert(r.effective_until === null || new Date(r.effective_until) > new Date(), 'Rate ' + r.id + ' is non-expired');
  }

  console.log('\nGroup 5: Verifying Health & Legacy Isolation...');
  const r15 = await fetch(BASE_URL + '/api/health');
  assert(r15.status === 200, 'GET /api/health returns 200 OK');

  const r16 = await fetch(BASE_URL + '/api/rates');
  assert(r16.status === 200, 'GET /api/rates returns 200 OK');
  const body16 = await r16.json();
  assert(Array.isArray(body16.data && body16.data.banks), 'Legacy endpoint returns banks array');

  console.log('\n======================================================');
  console.log('Test Results: ' + passedTests + ' passed, ' + failedTests + ' failed, ' + totalTests + ' total');
  console.log('======================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

run().catch(err => {
  console.error('Test run error:', err);
  process.exit(1);
});
