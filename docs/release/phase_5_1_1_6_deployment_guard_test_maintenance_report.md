# FeroCalc — Phase 5.1.1.6: Migration Deployment Guard Test Maintenance Report

**Document Version:** 1.0.0
**Execution Timestamp:** November 13, 2026
**Execution Environment:** `C:\projects\fincalc_pro_staging_prep`
**Git Working Branch:** `staging/vercel-backend-preview`
**Scope:** Test maintenance of migration deployment guard test assertions, inventory synchronization (24 migrations), chronological validation, and full regression verification
**Final Milestone Verdict:** **`DEPLOYMENT GUARD TEST UPDATED — VERIFICATION PASSED`**

---

## 1. Executive Summary & Objective Realization

This maintenance task resolved the stale migration-count assertion in `backend/test/migration_deployment_guard_test.js`.

### 1.1 The Stale Assertion
In Phase 3C.14/3C.15, the migration deployment guard test suite was configured to assert that the migration inventory consisted of 21 files (15 legacy migrations `001`–`015` and 6 timestamped migrations through `20261028095435`).

Subsequent production hardening phases legitimately added 3 timestamped migrations to the active schema directory:
1. `20261107073416_atomic_candidate_promotion_rpc.sql` (Phase 5.0.0 / atomic candidate promotion transaction)
2. `20261108050936_atomic_policy_escalation_rpc.sql` (Phase 5.0.0 / policy escalation audit log transaction)
3. `20261112193000_verified_rate_notification_events.sql` (Phase 5.0.6.1 / verified rate notification event store)

This increased the actual repository migration count to **24** (15 legacy + 9 timestamped). The live guard script (`backend/scripts/migration_deployment_guard.js`) already dynamically parsed all directory contents, but the test in `backend/test/migration_deployment_guard_test.js` was asserting `analysis.totalCount === 21`, resulting in:
```text
AssertionError [ERR_ASSERTION]: Expected 21 total migration files
24 !== 21
```

### 1.2 The Maintenance Resolution
1. **Accurate Inventory Assertions:** Updated Group 2 in `backend/test/migration_deployment_guard_test.js` to assert the verified repository state:
   - **Total Migrations:** Exactly 24
   - **Legacy Migrations:** Exactly 15 (`001` through `015`)
   - **Timestamped Migrations:** Exactly 9 (`20261025095847` through `20261112193000`)
   - **Unparsed Files:** Exactly 0
2. **Sequential Continuity & Chronological Validation:**
   - Enforced strict numerical continuity of legacy versions (`001` to `015`).
   - Enforced exact chronological array matching and strict monotonic ordering (`v[i] > v[i-1]`) for all 9 timestamped migrations.
   - Added validation for all 24 migration objects verifying filename extensions, version length, and non-empty description strings.
3. **Safety Invariants Preserved:**
   - Unconditional production deployment gate (`pmaykclwuyspxhgeomee`).
   - Staging fail-closed lockout on unreconciled legacy replay (`001`–`015`).
   - Specific RBAC regression halt on `005_create_rls_policies.sql`.
   - Target project reference verification (`cqrslxngpwbtkjejlwty`).
4. **Full Test Verification:**
   - `npm run test:deployment-guard`: 17/17 tests PASSED.
   - `npm run test:rbac`: 67/67 tests PASSED.
   - `npm test`: 46/46 test suites PASSED with zero failures.

---

## 2. Complete Migration Inventory (24 Files)

The active migration directory (`backend/supabase/migrations/`) contains exactly 24 SQL files:

| # | Filename | Version | Classification | Description / Scope |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `001_create_enums.sql` | `001` | Legacy | Base ENUMs (bank types, status, customer types) |
| **02** | `002_create_banks.sql` | `002` | Legacy | `banks` table & catalog structure |
| **03** | `003_create_fd_rates.sql` | `003` | Legacy | `fd_rates` active published rate table |
| **04** | `004_create_audit_log.sql` | `004` | Legacy | `rate_audit_log` audit history table |
| **05** | `005_create_rls_policies.sql` | `005` | Legacy | Base Row-Level Security on core tables |
| **06** | `006_create_views_and_functions.sql` | `006` | Legacy | Rate querying views & helper functions |
| **07** | `007_overlap_protection.sql` | `007` | Legacy | Day-domain tenure slab overlap protection |
| **08** | `008_overlap_protection_hardening.sql` | `008` | Legacy | Overlap boundary edge-case defense triggers |
| **09** | `009_calendar_tenure_domain.sql` | `009` | Legacy | Dual tenure domain (DAYS vs CALENDAR) |
| **10** | `010_create_rate_source_monitoring.sql` | `010` | Legacy | Collector source status & telemetry |
| **11** | `011_create_rate_candidate_staging.sql` | `011` | Legacy | `staged_rate_candidates` staging table |
| **12** | `012_candidate_promotion_and_audit.sql` | `012` | Legacy | Staging promotion logging & audit trail |
| **13** | `013_create_pipeline_runs_and_health.sql` | `013` | Legacy | Ingestion pipeline telemetry & distributed locks |
| **14** | `014_create_baseline_attestations.sql` | `014` | Legacy | Rate source SHA-256 baseline hashes |
| **15** | `015_add_special_scheme_to_staged_candidates.sql` | `015` | Legacy | Bespoke schemes (e.g. 400 Days, We-Care) |
| **16** | `20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql` | `20261025095847` | Timestamped | Revoke unsafe DDL privileges & restore RLS |
| **17** | `20261025100101_calendar_aware_candidate_staging_017.sql` | `20261025100101` | Timestamped | Calendar tenure candidate staging DDL |
| **18** | `20261025100407_restrict_public_views_to_read_only.sql` | `20261025100407` | Timestamped | Read-only permissions on public views |
| **19** | `20261025100630_use_invoker_security_for_public_views.sql` | `20261025100630` | Timestamped | `security_invoker = true` on views |
| **20** | `20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql` | `20261025100654` | Timestamped | Least-privilege admin RLS helper |
| **21** | `20261028095435_restrict_reviewer_bank_catalog_mutations.sql` | `20261028095435` | Timestamped | Restrict reviewer role to rate candidates (018) |
| **22** | `20261107073416_atomic_candidate_promotion_rpc.sql` | `20261107073416` | Timestamped | Atomic promotion RPC transaction function |
| **23** | `20261108050936_atomic_policy_escalation_rpc.sql` | `20261108050936` | Timestamped | Atomic policy escalation RPC transaction |
| **24** | `20261112193000_verified_rate_notification_events.sql` | `20261112193000` | Timestamped | Event store for rate change notifications |

---

## 3. Test Suite Implementation Details

In `backend/test/migration_deployment_guard_test.js`, Group 2 was updated with hardened assertions:

```javascript
console.log('\nGroup 2: Live Migration Directory Analysis');

test('analyzeMigrationDirectory categorizes all 24 repository migrations accurately', () => {
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations');
  const analysis = analyzeMigrationDirectory(migrationsDir);

  assert.strictEqual(analysis.totalCount, 24, 'Expected 24 total migration files');
  assert.strictEqual(analysis.legacyFiles.length, 15, 'Expected 15 legacy files (001–015)');
  assert.strictEqual(analysis.timestampedFiles.length, 9, 'Expected 9 timestamped files');
  assert.strictEqual(analysis.unparsedFiles.length, 0, 'All .sql files must be successfully parsed');

  // Verify legacy sequence bounds and continuity (001 through 015)
  const legacyVersions = analysis.legacyFiles.map(f => f.version);
  assert.strictEqual(legacyVersions.length, 15);
  assert.strictEqual(legacyVersions[0], '001');
  assert.strictEqual(legacyVersions[14], '015');
  for (let i = 0; i < 15; i++) {
    const expected = String(i + 1).padStart(3, '0');
    assert.strictEqual(legacyVersions[i], expected, `Legacy migration at index ${i} must be ${expected}`);
  }

  // Verify all 9 timestamped migrations in exact chronological order
  const expectedTimestampedVersions = [
    '20261025095847', // restore_core_rls_policies_and_revoke_unsafe_ddl_privileges
    '20261025100101', // calendar_aware_candidate_staging_017
    '20261025100407', // restrict_public_views_to_read_only
    '20261025100630', // use_invoker_security_for_public_views
    '20261025100654', // harden_admin_rls_helper_and_bank_write_policies
    '20261028095435', // restrict_reviewer_bank_catalog_mutations (Migration 018)
    '20261107073416', // atomic_candidate_promotion_rpc
    '20261108050936', // atomic_policy_escalation_rpc
    '20261112193000'  // verified_rate_notification_events
  ];
  const timestampedVersions = analysis.timestampedFiles.map(f => f.version);
  assert.deepStrictEqual(
    timestampedVersions,
    expectedTimestampedVersions,
    'Timestamped migrations must match expected list in chronological order'
  );

  // Verify strict chronological ordering of timestamped migrations
  for (let i = 1; i < timestampedVersions.length; i++) {
    assert.ok(
      timestampedVersions[i] > timestampedVersions[i - 1],
      `Timestamped migration ${timestampedVersions[i]} must be strictly greater than preceding ${timestampedVersions[i - 1]}`
    );
  }

  // Verify key milestone migrations are present
  assert.ok(timestampedVersions.includes('20261028095435'), 'Must include reconciled Migration 018 (reviewer RBAC)');
  assert.ok(timestampedVersions.includes('20261107073416'), 'Must include atomic promotion RPC migration');
  assert.ok(timestampedVersions.includes('20261108050936'), 'Must include atomic policy escalation RPC migration');
  assert.ok(timestampedVersions.includes('20261112193000'), 'Must include verified rate notification events migration');
});

test('all 24 migrations parse correctly with valid properties and non-empty descriptions', () => {
  const migrationsDir = path.resolve(__dirname, '../supabase/migrations');
  const analysis = analyzeMigrationDirectory(migrationsDir);

  assert.strictEqual(analysis.totalCount, 24);

  // Validate all 15 legacy files
  for (const file of analysis.legacyFiles) {
    assert.strictEqual(file.isLegacy, true, `File ${file.filename} must be flagged as legacy`);
    assert.strictEqual(file.isTimestamped, false, `File ${file.filename} must not be flagged as timestamped`);
    assert.strictEqual(file.version.length, 3, `Legacy version ${file.version} must be 3 digits`);
    assert.ok(file.name && file.name.length > 0, `File ${file.filename} must have a non-empty name`);
    assert.ok(file.filename.endsWith('.sql'), `File ${file.filename} must have .sql extension`);
  }

  // Validate all 9 timestamped files
  for (const file of analysis.timestampedFiles) {
    assert.strictEqual(file.isLegacy, false, `File ${file.filename} must not be flagged as legacy`);
    assert.strictEqual(file.isTimestamped, true, `File ${file.filename} must be flagged as timestamped`);
    assert.strictEqual(file.version.length, 14, `Timestamped version ${file.version} must be 14 digits`);
    assert.ok(file.name && file.name.length > 0, `File ${file.filename} must have a non-empty name`);
    assert.ok(file.filename.endsWith('.sql'), `File ${file.filename} must have .sql extension`);
  }
});
```

---

## 4. Empirical Test Verification Results

### 4.1 Deployment Guard Unit Test Execution (`npm run test:deployment-guard`)
```text
> ferocalc-bank-rates-api@1.0.0 test:deployment-guard
> node test/migration_deployment_guard_test.js

================================================================
FeroCalc Phase 3C.14 / 3C.15 — Migration Deployment Guard Tests
================================================================

Group 1: Filename Parsing & Version Classification
  ✓ parseMigrationFilename correctly parses 3-digit legacy migrations
  ✓ parseMigrationFilename correctly parses 14-digit timestamped migrations
  ✓ parseMigrationFilename returns null for non-sql or invalid filenames

Group 2: Live Migration Directory Analysis
  ✓ analyzeMigrationDirectory categorizes all 24 repository migrations accurately
  ✓ all 24 migrations parse correctly with valid properties and non-empty descriptions

Group 3: Fail-Closed Protection Against Unreconciled Remote Deployment
  ✓ evaluateDeploymentSafety blocks deployment with current repository state
  ✓ assertDeploymentAllowed throws MigrationDeploymentBlockedError on unsafe state
  ✓ production deployment is unconditionally blocked by production gate

Group 4: Safe Workflow Allowances & Permitted Operations
  ✓ evaluateDeploymentSafety allows deployment when all legacy migrations are baselined
  ✓ evaluateDeploymentSafety allows deployment on directory with only timestamped migrations

Group 5: Developer Workflow Non-Interference
  ✓ guard does not affect standard runtime modules or collectors
  ✓ hazard dictionary covers all 15 legacy migrations

Group 6: Phase 3C.15 Target Verification & Environment Gates
  ✓ resolveLinkedProjectRef retrieves the linked staging project ref correctly
  ✓ guard fails closed when target environment is explicitly unknown
  ✓ guard fails closed when project ref differs from staging without explicit override
  ✓ guard does NOT mistake hardcoded staging ledger for proof of arbitrary linked project
  ✓ guard fails closed if target is production project ref even if targetEnv omitted
================================================================
Phase 3C.14 / 3C.15 Test Summary: 17/17 assertions PASSED
================================================================
```
*Result: 17 passed, 0 failed.*

### 4.2 Guard Script Live Audit Verification (`node scripts/migration_deployment_guard.js --audit`)
Executing the deployment guard directly against the repository confirmed that the live guard dynamically inspects all 24 migrations and enforces fail-closed isolation:
```json
{
  "isSafe": false,
  "targetEnv": "staging",
  "targetProjectRef": "cqrslxngpwbtkjejlwty",
  "totalLocalMigrations": 24,
  "legacyCount": 15,
  "timestampedCount": 9,
  "pendingLegacyCount": 15,
  "pendingLegacyFiles": [
    "001_create_enums.sql",
    "002_create_banks.sql",
    "003_create_fd_rates.sql",
    "004_create_audit_log.sql",
    "005_create_rls_policies.sql",
    "006_create_views_and_functions.sql",
    "007_overlap_protection.sql",
    "008_overlap_protection_hardening.sql",
    "009_calendar_tenure_domain.sql",
    "010_create_rate_source_monitoring.sql",
    "011_create_rate_candidate_staging.sql",
    "012_candidate_promotion_and_audit.sql",
    "013_create_pipeline_runs_and_health.sql",
    "014_create_baseline_attestations.sql",
    "015_add_special_scheme_to_staged_candidates.sql"
  ],
  "blockedReasons": [
    "Detected 15 legacy sequential migration(s) (001–015) in active migrations directory that are absent from the remote migration ledger. Supabase CLI would attempt to replay these files against staging, causing catastrophic catalog collisions and RBAC regressions.",
    "CRITICAL SECURITY HALT: 005_create_rls_policies.sql is among the pending legacy files. Replaying 005 would recreate \"banks_admin_write\" and bind is_admin(), reversing Phase 3C.10/3C.11 bank catalog protections and re-exposing master catalog writes to the REVIEWER role."
  ]
}
```

### 4.3 Production Gate Live Audit (`node scripts/migration_deployment_guard.js --production --audit`)
Evaluating under `--production` confirmed that the production deployment gate locks out remote pushes with the primary message:
```text
PRODUCTION DEPLOYMENT GATE: Deploying migrations directly to production project 'pmaykclwuyspxhgeomee' is strictly locked pending formal DBA written authorization and an approved migration baseline.
```

### 4.4 Related RBAC Least-Privilege Test (`npm run test:rbac`)
```text
================================================================
Phase 3C.10 Test Summary: 67/67 assertions PASSED
================================================================
```

### 4.5 Full Backend Regression Suite (`npm test`)
All 46 test suites passed with zero failures:
```text
Total Test Suites Executed: 46
Passed Test Suites:        46
Failed Test Suites:        0
Status:                    100% GREEN
```

---

## 5. Strict Boundaries Verification

- [x] **Test-Maintenance Only:** Changes were strictly confined to `backend/test/migration_deployment_guard_test.js`.
- [x] **No Migration SQL Modified:** All 24 migration files in `backend/supabase/migrations/` remain byte-for-byte identical.
- [x] **Zero Migration Execution:** No migrations or migration repair commands were run against any environment.
- [x] **Zero Database Connections:** No database connections were established to staging (`cqrslxngpwbtkjejlwty`) or production (`pmaykclwuyspxhgeomee`).
- [x] **Zero Vercel Deployment:** No Vercel deployment commands were issued.
- [x] **No Workspace Crossing:** No access to `C:\projects\fincalc_pro`.
- [x] **Git State Preserved:** No Git reset, clean, stash, checkout, commit, or push operations were conducted. All modified and untracked files remain intact.

---

## 6. Final Milestone Verdict & Handover

The stale migration-count assertion has been updated and verified against the complete 24-migration repository inventory. All fail-closed safety invariants, chronological ordering assertions, and environment protections pass with 100% success.

**Final Verdict:**
**`DEPLOYMENT GUARD TEST UPDATED — VERIFICATION PASSED`**

---

## 7. Handover to Project Owner Action Checklist

In accordance with release engineering instructions, no further routine development phases should be initiated. The repository is ready for human account owner execution.

Refer to the authoritative owner documents:
- **Consolidated Action Checklist:** [final_owner_action_checklist.md](file:///C:/projects/fincalc_pro_staging_prep/docs/release/final_owner_action_checklist.md)
- **Production Deployment Runbook:** [final_production_deployment_runbook.md](file:///C:/projects/fincalc_pro_staging_prep/docs/release/final_production_deployment_runbook.md)

### Outstanding Owner Actions:
1. **Item 01:** Business Owner provides legal entity name and registered physical address in `docs/legal/` files.
2. **Item 02:** Web Administrator hosts `docs/legal/privacy_policy.md` at a public HTTPS URL.
3. **Item 03:** Android Release Engineer configures `android/key.properties` and `upload-keystore.jks` to build production AAB (`1.0.1+7`).
4. **Item 04:** DBA executes 24 migrations in Supabase SQL Editor for `pmaykclwuyspxhgeomee`, confirms catalog queries, and reconciles CLI history using `npx supabase migration repair --status applied ... --project-ref pmaykclwuyspxhgeomee`.
5. **Item 05:** DevOps configures production environment variables on Vercel and executes `vercel --prod`.
6. **Item 06:** Monetization Owner confirms AdMob App and Banner Ad unit approval.
7. **Items 07–09:** Play Console Owner completes App Content declarations, selects India-only distribution (`IN`), uploads store listing graphics, and initiates the initial release.
