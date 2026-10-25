// FeroCalc CORS Policy Automated Unit & Regression Tests
// Verifies narrow allowlist logic, production web origins, scoped Vercel preview URLs,
// strict wildcard / arbitrary vercel app rejection, and Express cors callback behavior.

'use strict';

const assert = require('assert');
const {
  NARROW_PREVIEW_PATTERN,
  isOriginAllowed,
  parseAllowedOrigins,
  createCorsOriginValidator,
} = require('../cors_policy');

const PROD_WEB_ORIGIN = 'https://web-psi-kohl-23.vercel.app';
const SCOPED_PREVIEW_ORIGIN = 'https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app';
const CONFIGURED_ORIGINS = [
  PROD_WEB_ORIGIN,
  'http://localhost:3000',
  'http://localhost:8080',
];

const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

// 1. parseAllowedOrigins tests
test('parseAllowedOrigins: defaults to localhost when env var missing or empty', () => {
  const d1 = parseAllowedOrigins();
  assert.deepStrictEqual(d1, ['http://localhost:3000', 'http://localhost:8080']);

  const d2 = parseAllowedOrigins('');
  assert.deepStrictEqual(d2, ['http://localhost:3000', 'http://localhost:8080']);

  const d3 = parseAllowedOrigins(null);
  assert.deepStrictEqual(d3, ['http://localhost:3000', 'http://localhost:8080']);
});

test('parseAllowedOrigins: parses comma-separated string and trims whitespace', () => {
  const parsed = parseAllowedOrigins(' https://web-psi-kohl-23.vercel.app , http://localhost:3000,http://localhost:8080 ');
  assert.deepStrictEqual(parsed, [
    'https://web-psi-kohl-23.vercel.app',
    'http://localhost:3000',
    'http://localhost:8080',
  ]);
});

test('parseAllowedOrigins: ignores empty trailing or repeated commas', () => {
  const parsed = parseAllowedOrigins('https://example.com,, https://foo.com, ');
  assert.deepStrictEqual(parsed, ['https://example.com', 'https://foo.com']);
});

// 2. isOriginAllowed: Configured production and dev origins
test('isOriginAllowed: allows production web origin', () => {
  assert.strictEqual(isOriginAllowed(PROD_WEB_ORIGIN, CONFIGURED_ORIGINS), true);
});

test('isOriginAllowed: allows local development origins', () => {
  assert.strictEqual(isOriginAllowed('http://localhost:3000', CONFIGURED_ORIGINS), true);
  assert.strictEqual(isOriginAllowed('http://localhost:8080', CONFIGURED_ORIGINS), true);
});

test('isOriginAllowed: rejects unconfigured origins', () => {
  assert.strictEqual(isOriginAllowed('https://evil-attacker.com', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('https://google.com', CONFIGURED_ORIGINS), false);
});

// 3. isOriginAllowed: Scoped Vercel preview origins
test('isOriginAllowed: allows exact match scoped Vercel preview origins', () => {
  assert.strictEqual(isOriginAllowed(SCOPED_PREVIEW_ORIGIN, CONFIGURED_ORIGINS), true);
  assert.strictEqual(isOriginAllowed('https://web-abc123xyz-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), true);
  assert.strictEqual(isOriginAllowed('https://web-1-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), true);
});

test('isOriginAllowed: rejects insecure HTTP preview origin', () => {
  assert.strictEqual(isOriginAllowed('http://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects different project name in same team scope', () => {
  assert.strictEqual(isOriginAllowed('https://backend-gvc763jzd-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('https://api-gvc763jzd-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects different team scope in vercel.app', () => {
  assert.strictEqual(isOriginAllowed('https://web-gvc763jzd-otherteam.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects generic or arbitrary Vercel URLs', () => {
  assert.strictEqual(isOriginAllowed('https://my-unrelated-app.vercel.app', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('https://web-gvc763jzd.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects wildcard or blanket strings', () => {
  assert.strictEqual(isOriginAllowed('*', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('*.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects domain suffix / spoofing attempts', () => {
  assert.strictEqual(isOriginAllowed('https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app.attacker.com', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('https://attacker-web-gvc763jzd-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects origins with ports, paths, or uppercase letters', () => {
  assert.strictEqual(isOriginAllowed('https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app:8080', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app/path', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed('https://WEB-GVC763JZD-kuldip12490-8771s-projects.vercel.app', CONFIGURED_ORIGINS), false);
});

test('isOriginAllowed: rejects null, empty, non-string inputs', () => {
  assert.strictEqual(isOriginAllowed('', CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed(null, CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed(undefined, CONFIGURED_ORIGINS), false);
  assert.strictEqual(isOriginAllowed(12345, CONFIGURED_ORIGINS), false);
});

// 4. createCorsOriginValidator Express delegate tests
test('createCorsOriginValidator: allows non-browser requests with no origin header', (done) => {
  const validator = createCorsOriginValidator(CONFIGURED_ORIGINS);
  validator(undefined, (err, allow) => {
    assert.strictEqual(err, null);
    assert.strictEqual(allow, true);
    validator(null, (err2, allow2) => {
      assert.strictEqual(err2, null);
      assert.strictEqual(allow2, true);
      done();
    });
  });
});

test('createCorsOriginValidator: allows configured production origin', (done) => {
  const validator = createCorsOriginValidator(CONFIGURED_ORIGINS);
  validator(PROD_WEB_ORIGIN, (err, allow) => {
    assert.strictEqual(err, null);
    assert.strictEqual(allow, true);
    done();
  });
});

test('createCorsOriginValidator: allows scoped preview origin', (done) => {
  const validator = createCorsOriginValidator(CONFIGURED_ORIGINS);
  validator(SCOPED_PREVIEW_ORIGIN, (err, allow) => {
    assert.strictEqual(err, null);
    assert.strictEqual(allow, true);
    done();
  });
});

test('createCorsOriginValidator: rejects unauthorized browser origin without throwing', (done) => {
  const validator = createCorsOriginValidator(CONFIGURED_ORIGINS);
  validator('https://unauthorized-domain.com', (err, allow) => {
    assert.strictEqual(err, null);
    assert.strictEqual(allow, false);
    done();
  });
});

// Runner
let passed = 0;
let failed = 0;

console.log('Running FeroCalc CORS policy tests...');
for (const t of tests) {
  try {
    if (t.fn.length > 0) {
      // Async / callback style
      let cbCalled = false;
      t.fn(() => { cbCalled = true; });
      assert.strictEqual(cbCalled, true, `Test "${t.name}" did not invoke done callback synchronously`);
    } else {
      t.fn();
    }
    console.log(`  PASS: ${t.name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL: ${t.name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

console.log(`\nCORS Policy test summary: ${passed} passed, ${failed} failed.`);
if (failed > 0) {
  process.exit(1);
}
