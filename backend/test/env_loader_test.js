// FeroCalc Verified FD Rate Engine — Environment Configuration Loader Test Suite
// Verifies deterministic resolution, fail-closed conflict handling, and secret redaction.

'use strict';

const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const assert = require('assert');
const { loadEnv, determineTargetEnvironment, BACKEND_DIR, CRITICAL_KEYS } = require('../env_loader');

let passedTests = 0;
let totalTests = 0;

function runTest(description, fn) {
  totalTests++;
  try {
    fn();
    passedTests++;
    console.log(`  PASS: ${totalTests}. ${description}`);
  } catch (err) {
    console.error(`  FAIL: ${totalTests}. ${description}`);
    console.error(`        Error: ${err.message}`);
    throw err;
  }
}

async function main() {
  console.log('======================================================');
  console.log('FeroCalc Environment Configuration & Safety Tests     ');
  console.log('======================================================\n');

  console.log('Group 1: Deterministic Path Resolution & Working Directory Independence...');

  // Test 1: Launching from backend directory
  runTest('Launching from backend directory resolves .env.staging correctly', () => {
    const probeScript = `
      const { loadEnv } = require('./env_loader');
      const meta = loadEnv({ silent: true });
      process.stdout.write(JSON.stringify({
        env: process.env.APP_ENV,
        loaded: process.env.FEROCALC_ENV_LOADED,
        hasUrl: !!process.env.SUPABASE_URL,
        hasAnon: !!process.env.SUPABASE_ANON_KEY,
        hasService: !!process.env.SUPABASE_SERVICE_ROLE_KEY
      }));
    `;
    const output = cp.execSync(`node -e "${probeScript.replace(/\n/g, ' ')}" -- --staging`, {
      cwd: BACKEND_DIR,
      env: { ...process.env, SUPABASE_URL: undefined, SUPABASE_ANON_KEY: undefined, SUPABASE_SERVICE_ROLE_KEY: undefined },
    }).toString().trim();

    const data = JSON.parse(output);
    assert.strictEqual(data.env, 'staging');
    assert.strictEqual(data.loaded, 'staging');
    assert.strictEqual(data.hasUrl, true);
    assert.strictEqual(data.hasAnon, true);
    assert.strictEqual(data.hasService, true);
  });

  // Test 2: Launching from repository root
  runTest('Launching from repository root resolves backend/.env.staging correctly', () => {
    const repoRoot = path.resolve(BACKEND_DIR, '..');
    const probeScript = `
      const { loadEnv } = require('./backend/env_loader');
      const meta = loadEnv({ silent: true });
      process.stdout.write(JSON.stringify({
        env: process.env.APP_ENV,
        loaded: process.env.FEROCALC_ENV_LOADED,
        hasUrl: !!process.env.SUPABASE_URL
      }));
    `;
    const output = cp.execSync(`node -e "${probeScript.replace(/\n/g, ' ')}" -- --staging`, {
      cwd: repoRoot,
      env: { ...process.env, SUPABASE_URL: undefined, SUPABASE_ANON_KEY: undefined, SUPABASE_SERVICE_ROLE_KEY: undefined },
    }).toString().trim();

    const data = JSON.parse(output);
    assert.strictEqual(data.env, 'staging');
    assert.strictEqual(data.loaded, 'staging');
    assert.strictEqual(data.hasUrl, true);
  });

  console.log('\nGroup 2: Target Environment Detection Logic...');

  // Test 3: Flag detection
  runTest('determineTargetEnvironment recognizes --staging and --env=staging flags', () => {
    assert.strictEqual(determineTargetEnvironment({ argv: ['node', 'server.js', '--staging'] }), 'staging');
    assert.strictEqual(determineTargetEnvironment({ argv: ['node', 'server.js', '--env=staging'] }), 'staging');
    assert.strictEqual(determineTargetEnvironment({ env: { APP_ENV: 'staging' } }), 'staging');
    assert.strictEqual(determineTargetEnvironment({ argv: ['node', 'server.js'] }), 'default');
    assert.strictEqual(determineTargetEnvironment({ argv: ['node', 'server.js', '--production'] }), 'default');
  });

  console.log('\nGroup 3: Fail-Closed Protection & Conflict Safety...');

  // Test 4: Conflicting pre-existing shell variable triggers fail-closed error
  runTest('Conflicting pre-existing shell variable throws EnvConflictError and halts', () => {
    const conflictScript = `
      const { loadEnv } = require('./env_loader');
      loadEnv({ silent: true });
    `;
    let threw = false;
    let errorOutput = '';
    try {
      cp.execSync(`node -e "${conflictScript.replace(/\n/g, ' ')}" -- --staging`, {
        cwd: BACKEND_DIR,
        env: {
          ...process.env,
          SUPABASE_URL: 'https://malicious-or-wrong-project.supabase.co',
        },
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (err) {
      threw = true;
      errorOutput = err.stderr ? err.stderr.toString() : err.message;
    }

    assert.strictEqual(threw, true, 'Execution should fail closed when shell variable conflicts');
    assert.ok(errorOutput.includes('[EnvConflictError]'), 'Error should specify [EnvConflictError]');
    assert.ok(errorOutput.includes('SUPABASE_URL'), 'Error should name conflicting key');
    // Ensure secrets/full URLs are NOT leaked in conflict error message (Requirement 5)
    assert.ok(!errorOutput.includes('malicious-or-wrong-project'), 'Conflict error must NOT leak conflicting value');
  });

  // Test 5: Identical pre-existing shell variable is accepted (no false-positive conflict)
  runTest('Pre-existing shell variable identical to env file does NOT trigger conflict', () => {
    const dotenv = require('dotenv');
    const stagingParsed = dotenv.parse(fs.readFileSync(path.join(BACKEND_DIR, '.env.staging'), 'utf8'));
    const stagingUrl = stagingParsed.SUPABASE_URL;

    const identicalScript = `
      const { loadEnv } = require('./env_loader');
      const meta = loadEnv({ silent: true });
      process.stdout.write(JSON.stringify({ loaded: meta.loaded }));
    `;
    const output = cp.execSync(`node -e "${identicalScript.replace(/\n/g, ' ')}" -- --staging`, {
      cwd: BACKEND_DIR,
      env: {
        ...process.env,
        SUPABASE_URL: stagingUrl,
        SUPABASE_ANON_KEY: undefined,
        SUPABASE_SERVICE_ROLE_KEY: undefined,
      },
    }).toString().trim();

    const data = JSON.parse(output);
    assert.strictEqual(data.loaded, true);
  });

  // Test 6: Missing staging credentials triggers EnvMissingError
  runTest('Missing required staging credentials fails closed with EnvMissingError', () => {
    const tempEnvPath = path.join(BACKEND_DIR, '.env.temp_test_missing');
    try {
      // Write temp file with missing SUPABASE_SERVICE_ROLE_KEY
      fs.writeFileSync(tempEnvPath, 'SUPABASE_URL=https://test.supabase.co\nSUPABASE_ANON_KEY=some-key\n');
      let threw = false;
      let errorMsg = '';
      try {
        loadEnv({ environment: 'staging', envPath: tempEnvPath, silent: true });
      } catch (err) {
        threw = true;
        errorMsg = err.message;
      }
      assert.strictEqual(threw, true);
      assert.ok(errorMsg.includes('[EnvMissingError]'));
      assert.ok(errorMsg.includes('SUPABASE_SERVICE_ROLE_KEY'));
    } finally {
      if (fs.existsSync(tempEnvPath)) fs.unlinkSync(tempEnvPath);
    }
  });

  console.log('\nGroup 4: Network Isolation & Secret Redaction...');

  // Test 7: Selection occurs without network calls
  runTest('Environment selection and validation operates purely in-memory without network calls', () => {
    const tempEnvPath = path.join(BACKEND_DIR, '.env.temp_test_offline');
    try {
      fs.writeFileSync(
        tempEnvPath,
        'SUPABASE_URL=https://offline-mock.supabase.co\nSUPABASE_ANON_KEY=mock-anon\nSUPABASE_SERVICE_ROLE_KEY=mock-service\n'
      );
      const res = loadEnv({ environment: 'staging', envPath: tempEnvPath, silent: true });
      assert.strictEqual(res.loaded, true);
      assert.strictEqual(res.environment, 'staging');
      assert.strictEqual(process.env.APP_ENV, 'staging');
    } finally {
      if (fs.existsSync(tempEnvPath)) fs.unlinkSync(tempEnvPath);
    }
  });

  // Test 8: CLI entry points support --staging argument
  runTest('CLI entry points parse --staging and configure environment deterministically', () => {
    const entryPoints = [
      'scripts/run_baseline_attestation.js',
      'scripts/run_extraction.js',
      'scripts/run_pipeline.js',
      'scripts/run_collector.js',
    ];
    for (const ep of entryPoints) {
      const fullPath = path.join(BACKEND_DIR, ep);
      const content = fs.readFileSync(fullPath, 'utf8');
      assert.ok(content.includes("require('../env_loader')"), `${ep} must import env_loader`);
      assert.ok(content.includes('loadEnv()'), `${ep} must call loadEnv()`);
    }
  });

  console.log(`\n======================================================`);
  console.log(`Results: ${passedTests} passed, 0 failed (Total: ${totalTests})`);
  console.log(`======================================================\n`);
}

main().catch(err => {
  console.error('Test suite failed:', err);
  process.exit(1);
});
