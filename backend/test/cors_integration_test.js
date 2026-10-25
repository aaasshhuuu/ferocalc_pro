// FeroCalc Verified FD Rate Engine — End-to-End CORS HTTP Integration Test Suite
// Instantiates the production Express app via server.js with process.env.VERCEL = '1'
// and exercises real HTTP OPTIONS (preflight) and GET requests across:
// - Exact allowlisted production origin
// - Documented scoped preview origin
// - Second valid scoped preview origin
// - Unrelated Vercel hosts
// - Spoofed suffix (.attacker.com)
// - Insecure HTTP protocol
// - Unexpected port
// - Missing Origin header (native mobile Dio / server-to-server)
// - Wildcards and spoofing variations

'use strict';

// Set VERCEL='1' so server.js exports app without binding to default PORT
process.env.VERCEL = '1';
process.env.ALLOWED_ORIGINS = 'https://web-psi-kohl-23.vercel.app,http://localhost:3000,http://localhost:8080';

const assert = require('assert');
const app = require('../server');

const PROD_ORIGIN = 'https://web-psi-kohl-23.vercel.app';
const SCOPED_PREVIEW_ORIGIN_1 = 'https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app';
const SCOPED_PREVIEW_ORIGIN_2 = 'https://web-0a1b2c3d4e-kuldip12490-8771s-projects.vercel.app';
const SCOPED_BRANCH_PREVIEW_ORIGIN = 'https://web-git-sync-latest-local-cha-cf40a2-kuldip12490-8771s-projects.vercel.app';
const UNRELATED_VERCEL_APP = 'https://unrelated-project.vercel.app';
const UNRELATED_TEAM_SCOPE = 'https://web-gvc763jzd-otherteam.vercel.app';
const SPOOFED_SUFFIX = 'https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app.attacker.com';
const SPOOFED_PREFIX = 'https://attacker-web-gvc763jzd-kuldip12490-8771s-projects.vercel.app';
const INSECURE_HTTP = 'http://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app';
const UNEXPECTED_PORT = 'https://web-gvc763jzd-kuldip12490-8771s-projects.vercel.app:8443';

async function main() {
  console.log('======================================================');
  console.log('FeroCalc End-to-End CORS HTTP Integration Tests');
  console.log('======================================================\n');

  // Bind server on ephemeral port (0)
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;

  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      passed++;
      console.log(`  PASS: ${name}`);
    } catch (err) {
      failed++;
      console.error(`  FAIL: ${name}`);
      console.error(`    ${err.message}`);
    }
  }

  try {
    // 1. Production Web Origin
    await test('1.1 OPTIONS preflight allows exact production origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': PROD_ORIGIN,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.status, 204);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), PROD_ORIGIN);
    });

    await test('1.2 GET allows exact production origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': PROD_ORIGIN },
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), PROD_ORIGIN);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
    });

    // 2. Documented Scoped Preview Origin
    await test('2.1 OPTIONS preflight allows documented preview origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': SCOPED_PREVIEW_ORIGIN_1,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.status, 204);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), SCOPED_PREVIEW_ORIGIN_1);
    });

    await test('2.2 GET allows documented preview origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': SCOPED_PREVIEW_ORIGIN_1 },
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), SCOPED_PREVIEW_ORIGIN_1);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
    });

    // 3. Second Valid Scoped Preview Hostname
    await test('3.1 OPTIONS preflight allows second valid scoped preview origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': SCOPED_PREVIEW_ORIGIN_2,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.status, 204);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), SCOPED_PREVIEW_ORIGIN_2);
    });

    await test('3.2 GET allows second valid scoped preview origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': SCOPED_PREVIEW_ORIGIN_2 },
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), SCOPED_PREVIEW_ORIGIN_2);
    });

    // 3B. Scoped Branch-Slug Preview Alias (e.g. web-git-sync-latest-local-cha-cf40a2-kuldip12490-8771s-projects.vercel.app)
    await test('3.3 OPTIONS preflight allows scoped branch-slug preview alias', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': SCOPED_BRANCH_PREVIEW_ORIGIN,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.status, 204);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), SCOPED_BRANCH_PREVIEW_ORIGIN);
    });

    await test('3.4 GET allows scoped branch-slug preview alias', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': SCOPED_BRANCH_PREVIEW_ORIGIN },
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), SCOPED_BRANCH_PREVIEW_ORIGIN);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
    });

    // 4. Unrelated Vercel Hostname Rejection
    await test('4.1 OPTIONS rejects unrelated Vercel app', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': UNRELATED_VERCEL_APP,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    await test('4.2 GET rejects unrelated Vercel app', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': UNRELATED_VERCEL_APP },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    await test('4.3 GET rejects different team scope in vercel.app', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': UNRELATED_TEAM_SCOPE },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    // 5. Spoofed Suffix Attack (.attacker.com)
    await test('5.1 OPTIONS rejects spoofed domain suffix (.attacker.com)', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': SPOOFED_SUFFIX,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    await test('5.2 GET rejects spoofed domain suffix (.attacker.com)', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': SPOOFED_SUFFIX },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    await test('5.3 GET rejects spoofed domain prefix', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': SPOOFED_PREFIX },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    // 6. Insecure HTTP Rejection
    await test('6.1 OPTIONS rejects insecure HTTP preview URL', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': INSECURE_HTTP,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    await test('6.2 GET rejects insecure HTTP preview URL', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': INSECURE_HTTP },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    // 7. Unexpected Port Rejection
    await test('7.1 OPTIONS rejects unexpected port on preview URL', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        method: 'OPTIONS',
        headers: {
          'Origin': UNEXPECTED_PORT,
          'Access-Control-Request-Method': 'GET',
        },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    await test('7.2 GET rejects unexpected port on preview URL', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': UNEXPECTED_PORT },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    // 8. Missing Origin Header (Mobile / Server-to-Server)
    await test('8.1 GET succeeds without Origin header (mobile Dio / curl)', async () => {
      const res = await fetch(`${baseUrl}/api/health`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
      const json = await res.json();
      assert.strictEqual(json.status, 'ok');
    });

    // 9. Wildcard Origin Rejection
    await test('9.1 GET rejects wildcard "*" Origin header', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': '*' },
      });
      assert.strictEqual(res.headers.get('access-control-allow-origin'), null);
    });

    // 10. Localhost Dev Origins
    await test('10.1 GET allows localhost:3000 configured development origin', async () => {
      const res = await fetch(`${baseUrl}/api/health`, {
        headers: { 'Origin': 'http://localhost:3000' },
      });
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('access-control-allow-origin'), 'http://localhost:3000');
    });

  } finally {
    server.close();
  }

  console.log(`\nCORS Integration test summary: ${passed} passed, ${failed} failed.`);
  if (failed > 0) {
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
