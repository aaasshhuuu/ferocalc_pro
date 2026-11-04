/**
 * FeroCalc Phase 3C.14 / 3C.15 — Fail-Closed Migration Deployment Guard
 *
 * Prevents accidental replay of legacy sequential migrations (001–015)
 * while migration-history reconciliation (BLK-02) remains unresolved.
 *
 * Operating Invariants:
 * 1. The remote staging ledger (supabase_migrations.schema_migrations) contains
 *    strictly six timestamped migration versions (20261025095847 through 20261028095435).
 *    Migrations 001 through 015 are absent from the remote tracking table.
 * 2. Supabase CLI v2.122.0 parses 001–015 as 3-digit versions. Any unconstrained
 *    remote push (e.g. `supabase db push`) treats them as pending unapplied migrations,
 *    causing catalog collisions and reversing Migration 018 RBAC protections.
 * 3. The guard strictly verifies the target project reference (cqrslxngpwbtkjejlwty)
 *    and does NOT mistake the hard-coded staging ledger for proof of the currently
 *    linked remote project.
 * 4. Fails closed if target environment is unknown, target is production (pmaykclwuyspxhgeomee),
 *    project ref is unverified, or legacy migrations 001–015 remain unbaselined.
 */

'use strict';

const fs = require('fs');
const path = require('path');

// Authoritative project references
const EXPECTED_STAGING_PROJECT_REF = 'cqrslxngpwbtkjejlwty';
const FORBIDDEN_PRODUCTION_PROJECT_REF = 'pmaykclwuyspxhgeomee';

// Verified remote migration records present on staging (cqrslxngpwbtkjejlwty)
const KNOWN_REMOTE_STAGING_LEDGER = Object.freeze([
  '20261025095847', // restore_core_rls_policies_and_revoke_unsafe_ddl_privileges
  '20261025100101', // calendar_aware_candidate_staging_017
  '20261025100407', // restrict_public_views_to_read_only
  '20261025100630', // use_invoker_security_for_public_views
  '20261025100654', // harden_admin_rls_helper_and_bank_write_policies
  '20261028095435'  // restrict_reviewer_bank_catalog_mutations (Migration 018)
]);

// Critical safety hazards identified for legacy migrations if replayed
const LEGACY_REPLAY_HAZARDS = Object.freeze({
  '001': 'Type conflict: rate_status ENUM already exists in database catalog.',
  '002': 'Duplicate relation: public.banks table and unique indices already exist.',
  '003': 'Schema conflict: public.fd_rates exists and has been altered by calendar domain migrations.',
  '004': 'Duplicate relation: public.rate_audit_log already exists.',
  '005': 'CRITICAL SECURITY REGRESSION: Recreates banks_admin_write and binds is_admin(), reversing Migration 018.',
  '006': 'Security invoker regression: Replaces hardened view definitions with legacy definer views.',
  '007': 'Domain logic regression: Replaces calendar tenure logic with superseded day-only overlap triggers.',
  '008': 'Hardening conflict: Replaces calendar tenure functions with superseded day-only hardening.',
  '009': 'Catalog conflict: Active calendar tenure domain definitions already present in catalog.',
  '010': 'Duplicate relation: rate_source_monitoring tables already exist.',
  '011': 'Schema conflict: Day-only candidate staging structure conflicts with calendar-aware staging.',
  '012': 'Duplicate relation: candidate_promotion_and_audit tables already exist.',
  '013': 'Duplicate relation: pipeline_runs and distributed lock tables already exist.',
  '014': 'Duplicate relation: baseline_attestations tables already exist.',
  '015': 'Schema conflict: Special scheme columns already exist on staged_rate_candidates.'
});

class MigrationDeploymentBlockedError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = 'MigrationDeploymentBlockedError';
    this.code = 'ERR_MIGRATION_DEPLOYMENT_BLOCKED';
    this.details = details;
  }
}

/**
 * Resolves the currently linked Supabase project ref from local CLI metadata.
 *
 * @param {string} [supabaseDir]
 * @returns {string|null}
 */
function resolveLinkedProjectRef(supabaseDir) {
  const dir = supabaseDir || path.resolve(__dirname, '../supabase');
  const projectRefFile = path.join(dir, '.temp/project-ref');
  if (fs.existsSync(projectRefFile)) {
    try {
      const ref = fs.readFileSync(projectRefFile, 'utf8').trim();
      if (ref) return ref;
    } catch {
      // ignore
    }
  }
  return null;
}

/**
 * Parses a migration SQL filename into its constituent parts.
 *
 * @param {string} filename - e.g. "001_create_enums.sql" or "20261025095847_restore...sql"
 * @returns {object|null}
 */
function parseMigrationFilename(filename) {
  if (!filename || typeof filename !== 'string' || !filename.endsWith('.sql')) {
    return null;
  }

  const match = filename.match(/^([0-9]+)_(.*)\.sql$/);
  if (!match) {
    return null;
  }

  const version = match[1];
  const name = match[2];
  const isTimestamped = version.length === 14;
  const isLegacy = version.length < 14;

  return {
    filename,
    version,
    name,
    isLegacy,
    isTimestamped
  };
}

/**
 * Scans a migration directory and categorizes local migration files.
 *
 * @param {string} migrationsDir
 * @returns {object}
 */
function analyzeMigrationDirectory(migrationsDir) {
  if (!fs.existsSync(migrationsDir)) {
    throw new Error(`Migrations directory does not exist: ${migrationsDir}`);
  }

  const entries = fs.readdirSync(migrationsDir).sort();
  const legacyFiles = [];
  const timestampedFiles = [];
  const unparsedFiles = [];

  for (const entry of entries) {
    const parsed = parseMigrationFilename(entry);
    if (!parsed) {
      if (entry.endsWith('.sql')) {
        unparsedFiles.push(entry);
      }
      continue;
    }

    if (parsed.isLegacy) {
      legacyFiles.push(parsed);
    } else {
      timestampedFiles.push(parsed);
    }
  }

  return {
    migrationsDir,
    totalCount: legacyFiles.length + timestampedFiles.length,
    legacyFiles,
    timestampedFiles,
    unparsedFiles
  };
}

/**
 * Evaluates whether a migration push/deployment can safely proceed.
 *
 * @param {object} options
 * @param {string} [options.migrationsDir] - Defaults to backend/supabase/migrations
 * @param {string} [options.supabaseDir] - Defaults to backend/supabase
 * @param {string} [options.projectRef] - Explicit project ref override
 * @param {string[]} [options.remoteLedgerVersions] - Explicit remote ledger override
 * @param {string} [options.targetEnv] - 'staging' | 'production' | 'local' | 'unknown'
 * @param {boolean} [options.isLocal] - Flag indicating local isolated database operation
 * @param {boolean} [options.allowLegacyReplay] - Explicit bypass flag (must never default to true)
 * @returns {object} Evaluation result with safety boolean and diagnostic details
 */
function evaluateDeploymentSafety(options = {}) {
  const migrationsDir = options.migrationsDir || path.resolve(__dirname, '../supabase/migrations');
  const supabaseDir = options.supabaseDir || path.resolve(__dirname, '../supabase');
  const allowLegacyReplay = Boolean(options.allowLegacyReplay);
  const isLocal = Boolean(options.isLocal);

  // Resolve target project reference from options, env, or .temp/project-ref
  let targetProjectRef = options.projectRef ||
                         process.env.SUPABASE_PROJECT_ID ||
                         process.env.SUPABASE_PROJECT_REF ||
                         resolveLinkedProjectRef(supabaseDir);

  // Resolve target environment
  let targetEnv = options.targetEnv;
  if (!targetEnv) {
    if (isLocal) {
      targetEnv = 'local';
    } else if (targetProjectRef === FORBIDDEN_PRODUCTION_PROJECT_REF) {
      targetEnv = 'production';
    } else if (targetProjectRef === EXPECTED_STAGING_PROJECT_REF) {
      targetEnv = 'staging';
    } else {
      targetEnv = 'unknown';
    }
  }

  const analysis = analyzeMigrationDirectory(migrationsDir);
  const blockedReasons = [];

  // Verification 1: Fail closed if target environment is unknown or unverified
  if (targetEnv === 'unknown' || (!targetProjectRef && !isLocal && !options.remoteLedgerVersions)) {
    blockedReasons.push(
      'UNKNOWN TARGET ENVIRONMENT GATE: Refusing remote deployment because target environment or project reference ' +
      'cannot be verified. Linked project reference is missing or unrecognized. ' +
      `Expected staging project reference: '${EXPECTED_STAGING_PROJECT_REF}'.`
    );
  }

  // Verification 2: Fail closed if target project is production
  if (targetEnv === 'production' || targetProjectRef === FORBIDDEN_PRODUCTION_PROJECT_REF) {
    blockedReasons.push(
      `PRODUCTION DEPLOYMENT GATE: Deploying migrations directly to production project '${FORBIDDEN_PRODUCTION_PROJECT_REF}' ` +
      'is strictly locked pending formal DBA written authorization and an approved migration baseline.'
    );
  }

  // Verification 3: Verify the guard checks the expected project reference and does NOT mistake
  // the hard-coded staging ledger for proof of the currently linked remote project.
  let remoteLedger;
  if (options.remoteLedgerVersions) {
    // Explicitly supplied ledger (e.g. in unit tests or verified dynamic query)
    remoteLedger = new Set(options.remoteLedgerVersions);
  } else if (targetProjectRef === EXPECTED_STAGING_PROJECT_REF && targetEnv === 'staging') {
    // Verified staging project reference matches expected ref
    remoteLedger = new Set(KNOWN_REMOTE_STAGING_LEDGER);
  } else {
    // Linked project is NOT verified as staging; do NOT assume staging ledger records!
    remoteLedger = new Set();
    if (targetEnv !== 'unknown' && targetEnv !== 'production' && !isLocal) {
      blockedReasons.push(
        `PROJECT REFERENCE MISMATCH: Target project reference '${targetProjectRef}' does not match expected staging reference ` +
        `'${EXPECTED_STAGING_PROJECT_REF}'. Staging ledger records cannot be assumed for this project.`
      );
    }
  }

  // Identify legacy migrations missing from the remote tracking ledger
  const pendingLegacyFiles = [];
  const hazards = [];
  for (const file of analysis.legacyFiles) {
    if (!remoteLedger.has(file.version)) {
      pendingLegacyFiles.push(file);
      const hazardDesc = LEGACY_REPLAY_HAZARDS[file.version] || 'Unverified legacy migration replay hazard.';
      hazards.push({
        version: file.version,
        filename: file.filename,
        hazard: hazardDesc
      });
    }
  }

  // Fail-Closed Rule 1: Remote deployment with unbaselined legacy migrations is strictly blocked
  if (pendingLegacyFiles.length > 0 && !allowLegacyReplay) {
    blockedReasons.push(
      `Detected ${pendingLegacyFiles.length} legacy sequential migration(s) (001–015) in active migrations directory ` +
      `that are absent from the remote migration ledger. Supabase CLI would attempt to replay these files against ${targetEnv}, ` +
      `causing catastrophic catalog collisions and RBAC regressions.`
    );
  }

  // Fail-Closed Rule 2: Explicit check for Migration 005 security regression
  const has005 = pendingLegacyFiles.some(f => f.version === '005');
  if (has005 && !allowLegacyReplay) {
    blockedReasons.push(
      'CRITICAL SECURITY HALT: 005_create_rls_policies.sql is among the pending legacy files. ' +
      'Replaying 005 would recreate "banks_admin_write" and bind is_admin(), reversing Phase 3C.10/3C.11 ' +
      'bank catalog protections and re-exposing master catalog writes to the REVIEWER role.'
    );
  }

  const isSafe = blockedReasons.length === 0;

  return {
    isSafe,
    targetEnv,
    targetProjectRef: targetProjectRef || 'UNSET',
    totalLocalMigrations: analysis.totalCount,
    legacyCount: analysis.legacyFiles.length,
    timestampedCount: analysis.timestampedFiles.length,
    pendingLegacyCount: pendingLegacyFiles.length,
    pendingLegacyFiles: pendingLegacyFiles.map(f => f.filename),
    hazards,
    blockedReasons
  };
}

/**
 * Asserts deployment safety, throwing MigrationDeploymentBlockedError if unsafe.
 *
 * @param {object} options
 */
function assertDeploymentAllowed(options = {}) {
  const result = evaluateDeploymentSafety(options);
  if (!result.isSafe) {
    const message = [
      '================================================================================',
      'FAIL-CLOSED MIGRATION DEPLOYMENT GUARD ACTIVATED',
      '================================================================================',
      `Target Environment:         ${result.targetEnv.toUpperCase()}`,
      `Target Project Ref:         ${result.targetProjectRef}`,
      `Total Local Migrations:     ${result.totalLocalMigrations}`,
      `Pending Unbaselined Legacy: ${result.pendingLegacyCount}`,
      '',
      'BLOCKED REASONS:',
      ...result.blockedReasons.map(r => `  - ${r}`),
      '',
      'IDENTIFIED REPLAY HAZARDS:',
      ...result.hazards.map(h => `  * [${h.version}] ${h.filename}: ${h.hazard}`),
      '',
      'RESOLUTION INSTRUCTIONS:',
      '  1. Do NOT run `supabase db push` or `supabase migration repair` manually.',
      '  2. A formal DBA decision (BLK-02) is required to baseline the remote tracking table.',
      '  3. See backend/supabase/drafts/migration_history_reconciliation_manifest.json for guidance.',
      '================================================================================'
    ].join('\n');

    throw new MigrationDeploymentBlockedError(message, result);
  }
  return result;
}

// CLI Execution Entry Point
if (require.main === module) {
  const args = process.argv.slice(2);
  const isAudit = args.includes('--audit') || args.includes('--check-only');

  // Parse --project-ref=<ref> or --project-ref <ref>
  let cliProjectRef = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--project-ref=')) {
      cliProjectRef = args[i].split('=')[1];
    } else if (args[i] === '--project-ref' && i + 1 < args.length) {
      cliProjectRef = args[i + 1];
    }
  }

  // Parse --env=<env> or environment flags
  let cliTargetEnv = null;
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--env=')) {
      cliTargetEnv = args[i].split('=')[1];
    } else if (args[i] === '--production') {
      cliTargetEnv = 'production';
    } else if (args[i] === '--staging') {
      cliTargetEnv = 'staging';
    } else if (args[i] === '--local') {
      cliTargetEnv = 'local';
    }
  }

  const options = {};
  if (cliProjectRef) options.projectRef = cliProjectRef;
  if (cliTargetEnv) options.targetEnv = cliTargetEnv;
  if (args.includes('--local')) options.isLocal = true;

  try {
    const safety = evaluateDeploymentSafety(options);

    if (isAudit) {
      console.log(JSON.stringify(safety, null, 2));
      process.exit(safety.isSafe ? 0 : 1);
    }

    assertDeploymentAllowed(options);
    console.log(`[MigrationGuard] Pre-deployment check PASSED for target environment: ${safety.targetEnv} (${safety.targetProjectRef})`);
    process.exit(0);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}

module.exports = {
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
};
