/**
 * FeroCalc Phase 3C.14 / 3C.15 — Migration Deployment Guard Unit & Regression Test Suite
 *
 * Validates that the fail-closed deployment guard:
 * 1. Accurately detects and classifies legacy sequential migrations (001–015) vs. timestamped migrations.
 * 2. Strictly blocks remote deployment when legacy migrations 001–015 are unreconciled on the remote ledger.
 * 3. Explicitly detects and blocks the critical Migration 005 RBAC regression risk.
 * 4. Strictly protects the production environment gate.
 * 5. Permits safe workflows when migrations are fully baselined/reconciled.
 * 6. Does not interfere with ordinary developer operations or runtime services.
 * 7. Fails closed if the target project/environment is unknown (Phase 3C.15 Task 3).
 * 8. Verifies the expected project reference and does NOT mistake the hard-coded staging ledger
 *    for proof of the currently linked remote project (Phase 3C.15 Task 4).
 */

'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const os = require('os');
const {
  MigrationDeploymentBlockedError,
  parseMigrationFilename,
  analyzeMigrationDirectory,
  evaluateDeploymentSafety,
  assertDeploymentAllowed,
  resolveLinkedProjectRef,
  EXPECTED_STAGING_PROJECT_REF,
  FORBIDDEN_PRODUCTION_PROJECT_REF,
  KNOWN_REMOTE_STAGING_LEDGER,
  LEGACY_REPLAY_HAZARDS
} = require('../scripts/migration_deployment_guard');

let totalTests = 0;
let passedTests = 0;

function test(name, fn) {
  totalTests++;
  try {
    fn();
    passedTests++;
    console.log(`  ✓ ${name}`);
  } catch (err) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${err.message}`);
    throw err;
  }
}

console.log('================================================================');
console.log('FeroCalc Phase 3C.14 / 3C.15 — Migration Deployment Guard Tests');
console.log('================================================================');

console.log('\nGroup 1: Filename Parsing & Version Classification');

test('parseMigrationFilename correctly parses 3-digit legacy migrations', () => {
  const parsed = parseMigrationFilename('001_create_enums.sql');
  assert.ok(parsed);
  assert.strictEqual(parsed.version, '001');
  assert.strictEqual(parsed.name, 'create_enums');
  assert.strictEqual(parsed.isLegacy, true);
  assert.strictEqual(parsed.isTimestamped, false);
});

test('parseMigrationFilename correctly parses 14-digit timestamped migrations', () => {
  const parsed = parseMigrationFilename('20261028095435_restrict_reviewer_bank_catalog_mutations.sql');
  assert.ok(parsed);
  assert.strictEqual(parsed.version, '20261028095435');
  assert.strictEqual(parsed.name, 'restrict_reviewer_bank_catalog_mutations');
  assert.strictEqual(parsed.isLegacy, false);
  assert.strictEqual(parsed.isTimestamped, true);
});

test('parseMigrationFilename returns null for non-sql or invalid filenames', () => {
  assert.strictEqual(parseMigrationFilename('README.md'), null);
  assert.strictEqual(parseMigrationFilename('.gitignore'), null);
  assert.strictEqual(parseMigrationFilename('invalid_format.sql'), null);
  assert.strictEqual(parseMigrationFilename(''), null);
});

console.log('\nGroup 2: Live Migration Directory Analysis');

test('analyzeMigrationDirectory categorizes all 21 repository migrations accurately', () => {
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations');
  const analysis = analyzeMigrationDirectory(migrationsDir);

  assert.strictEqual(analysis.totalCount, 21, 'Expected 21 total migration files');
  assert.strictEqual(analysis.legacyFiles.length, 15, 'Expected 15 legacy files (001–015)');
  assert.strictEqual(analysis.timestampedFiles.length, 6, 'Expected 6 timestamped files');

  // Verify legacy sequence bounds
  const legacyVersions = analysis.legacyFiles.map(f => f.version);
  assert.strictEqual(legacyVersions[0], '001');
  assert.strictEqual(legacyVersions[14], '015');

  // Verify timestamped files include reconciled Migration 018
  const timestampedVersions = analysis.timestampedFiles.map(f => f.version);
  assert.ok(timestampedVersions.includes('20261028095435'));
});

console.log('\nGroup 3: Fail-Closed Protection Against Unreconciled Remote Deployment');

test('evaluateDeploymentSafety blocks deployment with current repository state', () => {
  const result = evaluateDeploymentSafety({ targetEnv: 'staging' });

  assert.strictEqual(result.isSafe, false, 'Must be marked UNSAFE');
  assert.strictEqual(result.pendingLegacyCount, 15, 'Must flag 15 pending legacy files');
  assert.ok(result.blockedReasons.length >= 2, 'Must provide multiple blocking reasons');

  // Must detect specific danger of 005 reversing Migration 018
  const rlsRegressionReason = result.blockedReasons.find(r => r.includes('005_create_rls_policies.sql'));
  assert.ok(rlsRegressionReason, 'Must explicitly flag 005 RBAC regression danger');
  assert.ok(rlsRegressionReason.includes('CRITICAL SECURITY HALT'));
});

test('assertDeploymentAllowed throws MigrationDeploymentBlockedError on unsafe state', () => {
  assert.throws(
    () => {
      assertDeploymentAllowed({ targetEnv: 'staging' });
    },
    (err) => {
      assert.strictEqual(err.name, 'MigrationDeploymentBlockedError');
      assert.strictEqual(err.code, 'ERR_MIGRATION_DEPLOYMENT_BLOCKED');
      assert.strictEqual(err.details.pendingLegacyCount, 15);
      return true;
    }
  );
});

test('production deployment is unconditionally blocked by production gate', () => {
  const result = evaluateDeploymentSafety({ targetEnv: 'production' });
  assert.strictEqual(result.isSafe, false);
  const prodReason = result.blockedReasons.find(r => r.includes('PRODUCTION DEPLOYMENT GATE'));
  assert.ok(prodReason, 'Must include production gate error');
});

console.log('\nGroup 4: Safe Workflow Allowances & Permitted Operations');

test('evaluateDeploymentSafety allows deployment when all legacy migrations are baselined', () => {
  // Simulate a future state where DBA has baselined all migrations 001–015 in remote ledger
  const baselinedLedger = [
    ...Array.from({ length: 15 }, (_, i) => String(i + 1).padStart(3, '0')),
    ...KNOWN_REMOTE_STAGING_LEDGER
  ];

  const result = evaluateDeploymentSafety({
    remoteLedgerVersions: baselinedLedger,
    targetEnv: 'staging'
  });

  assert.strictEqual(result.isSafe, true, 'Must be marked SAFE when baselined');
  assert.strictEqual(result.pendingLegacyCount, 0);
  assert.strictEqual(result.blockedReasons.length, 0);

  // assertDeploymentAllowed must not throw
  assert.doesNotThrow(() => {
    assertDeploymentAllowed({
      remoteLedgerVersions: baselinedLedger,
      targetEnv: 'staging'
    });
  });
});

test('evaluateDeploymentSafety allows deployment on directory with only timestamped migrations', () => {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ferocalc-mig-safe-'));
  try {
    // Populate with only timestamped migrations matching remote ledger
    for (const version of KNOWN_REMOTE_STAGING_LEDGER) {
      fs.writeFileSync(path.join(tempDir, `${version}_test_mig.sql`), '-- test migration');
    }

    const result = evaluateDeploymentSafety({
      migrationsDir: tempDir,
      targetEnv: 'staging'
    });

    assert.strictEqual(result.isSafe, true);
    assert.strictEqual(result.legacyCount, 0);
    assert.strictEqual(result.pendingLegacyCount, 0);
    assert.strictEqual(result.timestampedCount, 6);
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
});

console.log('\nGroup 5: Developer Workflow Non-Interference');

test('guard does not affect standard runtime modules or collectors', () => {
  const { isFeroCalcAdmin } = require('../supabase/supabase_client');
  assert.strictEqual(typeof isFeroCalcAdmin, 'function');

  const { BaseCollector } = require('../collectors/base_collector');
  assert.strictEqual(typeof BaseCollector, 'function');
});

test('hazard dictionary covers all 15 legacy migrations', () => {
  for (let i = 1; i <= 15; i++) {
    const version = String(i).padStart(3, '0');
    assert.ok(LEGACY_REPLAY_HAZARDS[version], `Hazard must be defined for legacy version ${version}`);
  }
});

console.log('\nGroup 6: Phase 3C.15 Target Verification & Environment Gates');

test('resolveLinkedProjectRef retrieves the linked staging project ref correctly', () => {
  const linkedRef = resolveLinkedProjectRef();
  assert.strictEqual(linkedRef, EXPECTED_STAGING_PROJECT_REF);
});

test('guard fails closed when target environment is explicitly unknown', () => {
  const result = evaluateDeploymentSafety({
    targetEnv: 'unknown',
    projectRef: 'unknown-project-ref-xyz'
  });
  assert.strictEqual(result.isSafe, false);
  const unknownReason = result.blockedReasons.find(r => r.includes('UNKNOWN TARGET ENVIRONMENT GATE'));
  assert.ok(unknownReason, 'Must include unknown target environment gate');
});

test('guard fails closed when project ref differs from staging without explicit override', () => {
  // Test with an unrecognized foreign project ref
  const result = evaluateDeploymentSafety({
    projectRef: 'foreign-project-12345'
  });
  assert.strictEqual(result.isSafe, false);
  const mismatchReason = result.blockedReasons.find(r => r.includes('PROJECT REFERENCE MISMATCH') || r.includes('UNKNOWN TARGET ENVIRONMENT GATE'));
  assert.ok(mismatchReason, 'Must reject unrecognized project reference');
});

test('guard does NOT mistake hardcoded staging ledger for proof of arbitrary linked project', () => {
  // If linked to another project, the staging ledger must NOT be automatically applied
  const result = evaluateDeploymentSafety({
    projectRef: 'other-project-99999',
    targetEnv: 'custom-env'
  });
  assert.strictEqual(result.isSafe, false);
  const mismatchReason = result.blockedReasons.find(r => r.includes('PROJECT REFERENCE MISMATCH'));
  assert.ok(mismatchReason, 'Must explicitly report project reference mismatch');
});

test('guard fails closed if target is production project ref even if targetEnv omitted', () => {
  const result = evaluateDeploymentSafety({
    projectRef: FORBIDDEN_PRODUCTION_PROJECT_REF
  });
  assert.strictEqual(result.isSafe, false);
  assert.strictEqual(result.targetEnv, 'production');
  const prodReason = result.blockedReasons.find(r => r.includes('PRODUCTION DEPLOYMENT GATE'));
  assert.ok(prodReason, 'Must block forbidden production project ref');
});

console.log('================================================================');
console.log(`Phase 3C.14 / 3C.15 Test Summary: ${passedTests}/${totalTests} assertions PASSED`);
console.log('================================================================\n');
