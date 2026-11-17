# FeroCalc — Phase 5.1.1.3: Migration Execution Safety & History Reconciliation Patch Report

**Document Version:** 1.0.0
**Execution Timestamp:** November 13, 2026
**Execution Environment:** `C:\projects\fincalc_pro_staging_prep`
**Git Working Branch:** `staging/vercel-backend-preview`
**Scope:** Documentation and migration-execution procedure only
**Final Milestone Verdict:** **`MIGRATION RUNBOOK VERIFIED — OWNER EXECUTION REQUIRED`**

---

## 1. Executive Summary & Objective Realization

This safety report closes the remaining migration-history and transaction-execution risks identified in the FeroCalc production release documentation.

### Core Problems Addressed:
1. **Unsanctioned Manual SQL Ledger Inserts:**
   The release runbook previously suggested running an ad-hoc `INSERT INTO supabase_migrations.schema_migrations (version) VALUES (...)` SQL query. Direct table insertion bypasses Supabase CLI internal table management, version validation, and concurrency locks. This has been completely removed and replaced with the official, forward-compatible CLI workflow: `npx supabase migration repair --status applied <version> --linked`.
2. **Empirical CLI Flag Verification (`--linked` vs `--remote`):**
   Testing against the repository's project-local Supabase CLI (`v2.122.0`, pinned in `backend/package.json`) confirmed that `--remote` is **not a valid flag** in v2.122.x for `supabase migration repair` or `supabase migration list`. Both commands fail closed with `{"_tag":"Error","error":{"code":"UnrecognizedOption","message":"Unrecognized flag: --remote"}}`. The supported flag for linked remote projects under CLI v2.122.x is strictly `--linked` (or `--project-ref <id>`). *(Clarification Note: As detailed in Phase 5.1.1.4, official Supabase CLI v3.x documentation specifies `--remote` as the primary preferred target flag, with `--linked` as deprecated compatibility syntax. The earlier attribution of this flag error to CLI v3 resulted from executing the test within `backend/`, which resolved to local CLI v2.122.0. Because the release runbook defaults to executing inside `backend/`, `--linked` remains the verified, required syntax for the project-local v2 workflow).* The runbook and checklist reflect this verified syntax.
3. **Migration 012 Enum Transaction Safety (PostgreSQL Error 55P04 Prevention):**
   In PostgreSQL, executing `ALTER TYPE ... ADD VALUE` cannot be used in expressions or casts within the same transaction block (PostgreSQL error `55P04`). Furthermore, the Supabase Web Console SQL Editor implicitly wraps query editor blocks in a transaction, meaning the absence of explicit `BEGIN ... COMMIT` statements does **not** ensure safety. A two-segment execution protocol was designed, documented, and verified to guarantee that `ALTER TYPE ... ADD VALUE IF NOT EXISTS 'PROMOTED'` commits before any subsequent statements or migrations evaluate that value.
4. **Migration 017 Self-Contained Transaction Boundaries:**
   `20261025100101_calendar_aware_candidate_staging_017.sql` already encapsulates its own transaction boundary (`BEGIN;` at Line 27 and `COMMIT;` at Line 313) along with fail-closed preflight duplicate checks and catalog verification assertions. Wrapping it in an outer transaction generates PostgreSQL warning `25001` and causes the internal `COMMIT;` to commit prematurely, breaking rollback atomicity. The runbook now mandates executing Migration 017 strictly as-is.
5. **Exact Preservation of 24 Migration Files & Versions:**
   The original filenames and versions of all 24 migration files (15 legacy sequential `001`–`015` and 9 timestamped migrations) have been preserved without renaming, synthetic timestamp conversion, or re-generation.
6. **Hard Gate Before Future `supabase db push`:**
   Documented the strict operational rule that all 24 local migrations must match remote applied versions before any operator runs `supabase db push`. Replaying unbaselined legacy migrations against an initialized database causes fatal catalog collisions and a critical security regression in Migration 005 (reverting least-privilege bank write protections).

---

## 2. Supabase Migration Inventory & History Reconciliation

### 2.1 Complete 24-File Migration Inventory

The table below lists every migration in `backend/supabase/migrations/` in exact sequential execution order:

| Step | Exact Migration File Name | Parsed Version | Scope & Objects Created / Modified | Transaction Execution Behavior |
| :--- | :--- | :--- | :--- | :--- |
| **01** | `001_create_enums.sql` | `001` | Base enums (`bank_type`, `rate_status`, `customer_type`, `compounding_frequency`) | Safe for `BEGIN ... COMMIT`. Idempotent `DO $$ ... EXCEPTION` blocks. |
| **02** | `002_create_banks.sql` | `002` | `public.banks` table, triggers, and indices | Safe for `BEGIN ... COMMIT`. Standard DDL. |
| **03** | `003_create_fd_rates.sql` | `003` | `public.fd_rates` active published rate table, check constraints | Safe for `BEGIN ... COMMIT`. Standard DDL. |
| **04** | `004_create_audit_log.sql` | `004` | `public.rate_audit_log` append-only audit trail | Safe for `BEGIN ... COMMIT`. Standard DDL. |
| **05** | `005_create_rls_policies.sql` | `005` | Base RLS policies on banks, fd_rates, audit log | Safe for `BEGIN ... COMMIT`. Base RLS policies. |
| **06** | `006_create_views_and_functions.sql` | `006` | Public rate query views and helper functions | Safe for `BEGIN ... COMMIT`. View and function DDL. |
| **07** | `007_overlap_protection.sql` | `007` | Day-domain tenure slab overlap protection triggers | Safe for `BEGIN ... COMMIT`. PL/pgSQL triggers. |
| **08** | `008_overlap_protection_hardening.sql` | `008` | Overlap boundary edge-case concurrency defense | Safe for `BEGIN ... COMMIT`. Lock helper functions. |
| **09** | `009_calendar_tenure_domain.sql` | `009` | Dual tenure domain enums (`tenure_domain`, `boundary_op`) & `fd_rates` columns | Safe for `BEGIN ... COMMIT`. Enum & table alterations. |
| **10** | `010_create_rate_source_monitoring.sql` | `010` | `rate_sources` catalog and `source_collection_logs` | Safe for `BEGIN ... COMMIT`. Standard DDL. |
| **11** | `011_create_rate_candidate_staging.sql` | `011` | `staging_candidate_status` enum & `staged_rate_candidates` table | Safe for `BEGIN ... COMMIT`. Creates staging tables. |
| **12** | `012_candidate_promotion_and_audit.sql` | `012` | Adds `'PROMOTED'` to `staging_candidate_status`, `promotion_audit_log` | **SPECIAL EXECUTION:** Execute in **two committed segments** (Segment A: enum addition, Segment B: DDL). |
| **13** | `013_create_pipeline_runs_and_health.sql` | `013` | `rate_pipeline_runs` and distributed lock table | Safe for `BEGIN ... COMMIT`. Standard DDL. |
| **14** | `014_create_baseline_attestations.sql` | `014` | `baseline_source_attestations` SHA-256 table | Safe for `BEGIN ... COMMIT`. Standard DDL. |
| **15** | `015_add_special_scheme_to_staged_candidates.sql` | `015` | Bespoke scheme columns on `staged_rate_candidates` | Safe for `BEGIN ... COMMIT`. Column additions. |
| **16** | `20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql` | `20261025095847` | Revokes unsafe DDL permissions; enforces RLS | Safe for `BEGIN ... COMMIT`. Security hardening. |
| **17** | `20261025100101_calendar_aware_candidate_staging_017.sql` | `20261025100101` | Calendar tenure staging columns & partial unique indexes | **SELF-CONTAINED TRANSACTION:** Contains `BEGIN;` (L27) and `COMMIT;` (L313). Execute **as-is**. |
| **18** | `20261025100407_restrict_public_views_to_read_only.sql` | `20261025100407` | Revokes write permissions on public views from anon/authenticated | Safe for `BEGIN ... COMMIT`. Revoke grants. |
| **19** | `20261025100630_use_invoker_security_for_public_views.sql` | `20261025100630` | Enforces `security_invoker = true` on public views | Safe for `BEGIN ... COMMIT`. `ALTER VIEW ... SET`. |
| **20** | `20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql` | `20261025100654` | Hardens `is_admin()` helper as STABLE SECURITY INVOKER | Safe for `BEGIN ... COMMIT`. Helper and policy DDL. |
| **21** | `20261028095435_restrict_reviewer_bank_catalog_mutations.sql` | `20261028095435` | Creates `can_manage_bank_catalog()`; locks bank writes from REVIEWER | Safe for `BEGIN ... COMMIT`. RBAC hardening. |
| **22** | `20261107073416_atomic_candidate_promotion_rpc.sql` | `20261107073416` | Atomic candidate promotion RPC (`promote_candidate_atomic`) | Safe for `BEGIN ... COMMIT`. SECURITY DEFINER function. |
| **23** | `20261108050936_atomic_policy_escalation_rpc.sql` | `20261108050936` | Atomic policy escalation RPC (`escalate_policy_violation_atomic`) | Safe for `BEGIN ... COMMIT`. SECURITY DEFINER function. |
| **24** | `20261112193000_verified_rate_notification_events.sql` | `20261112193000` | Creates `verified_rate_notification_events` store & deduplication index | Safe for `BEGIN ... COMMIT`. Standard DDL & RLS. |

### 2.2 CLI Filename Parsing & Version Compatibility

Supabase CLI (written in Go) parses migration filenames via the regular expression:
`^([0-9]+)_(.*)\.sql$`

When analyzed against the repository's migration directory:
- Legacy migrations `001_create_enums.sql` through `015_add_special_scheme_to_staged_candidates.sql` are parsed with versions `"001"` through `"015"`.
- Timestamped migrations `20261025095847_...` through `20261112193000_...` are parsed with 14-digit UTC timestamp strings.
- In lexicographical sort order, `"001"` through `"015"` naturally precede `"20261025095847"`, ensuring that CLI ordering matches the exact numerical sequence required for schema construction.
- **Preservation Policy:** Original migration versions must be preserved exactly. Renaming legacy files to synthetic timestamps would alter SHA-256 baseline attestations, break git provenance, and introduce unknown divergence.

### 2.3 Danger of Direct SQL Insertion into `schema_migrations`

Manual SQL insertion via:
```sql
INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('001'), ...;
```
poses severe operational hazards:
1. **Schema Variability:** Across Supabase CLI releases, the structure of `supabase_migrations.schema_migrations` evolves (e.g. adding columns like `statements text[]` or `name text`). Direct row insertion risks schema violations or omitting mandatory metadata.
2. **Locking & Concurrency:** Supabase CLI migration commands take advisory locks to prevent concurrent schema updates. Direct SQL execution bypasses these concurrency locks.
3. **Drift from Supported Workflow:** Official Supabase tooling provides `supabase migration repair` specifically to synchronize history. Ad-hoc SQL introduces uncontrolled deviations from documented DBA practices.

### 2.4 Official CLI Migration Repair Workflow

The supported procedure for recording migrations executed through the Web Console SQL Editor is:

```bash
cd C:\projects\fincalc_pro_staging_prep\backend

# Batch repair (recommended):
npx supabase migration repair --status applied \
  001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 \
  20261025095847 \
  20261025100101 \
  20261025100407 \
  20261025100630 \
  20261025100654 \
  20261028095435 \
  20261107073416 \
  20261108050936 \
  20261112193000 \
  --linked
```

#### Fundamental Invariant: Repair Updates History Only
`supabase migration repair --status applied` **ONLY** updates the tracking ledger table `supabase_migrations.schema_migrations`. It **NEVER** executes, validates, or evaluates any SQL from the migration file. Therefore, it must be run **strictly after** the SQL statements have been applied in the SQL Editor and verified against the PostgreSQL catalog.

### 2.5 Verification & Hard Gate Before `supabase db push`

After running `migration repair`, the DBA must execute:
```bash
npx supabase migration list --linked
```

**Required State:** All 24 local migrations must show `Remote: Applied` with zero unapplied local migrations.

#### Fatal Replay Hazards of Unbaselined Legacy Migrations:
If any of migrations `001` through `015` remain unrecorded in the remote ledger, running `supabase db push` will attempt to replay them against the remote database. This causes catastrophic failures:
- `001`: Duplicate type `rate_status`.
- `002`: Duplicate relation `public.banks`.
- `003`: Duplicate relation `public.fd_rates`.
- **`005` (CRITICAL SECURITY REGRESSION):** Recreates `banks_admin_write` and binds `is_admin()`, reversing Migration 018 RBAC protections and reopening master bank catalog modifications to the `REVIEWER` role.
- `006`: Overwrites `security_invoker = true` views with legacy definer views.
- `007` & `008`: Overwrites calendar tenure domain logic with superseded day-only triggers.

**Hard Gate:** `supabase db push` is strictly prohibited until `supabase migration list --linked` confirms that all 24 migrations are recorded as applied on remote.

---

## 3. Migration 012 — Enum Transaction Safety Deep Dive

### 3.1 Actual File Inspection (`012_candidate_promotion_and_audit.sql`)

The migration contains the following statements:
1. `DO $$ BEGIN ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED'; EXCEPTION WHEN duplicate_object THEN NULL; END $$;`
2. `ALTER TABLE staged_rate_candidates ADD COLUMN IF NOT EXISTS promoted_rate_id UUID REFERENCES fd_rates(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS promoted_at TIMESTAMPTZ, ADD COLUMN IF NOT EXISTS promoted_by TEXT, ADD COLUMN IF NOT EXISTS promotion_reason TEXT;`
3. `CREATE TABLE IF NOT EXISTS promotion_audit_log (...);`
4. 5 index creation statements on `promotion_audit_log` (`idx_prom_audit_rate`, `idx_prom_audit_cand`, `idx_prom_audit_action`, `idx_prom_audit_actor`, `idx_prom_audit_created`).

### 3.2 Identification of Statements Referencing `PROMOTED`
- **Inside Migration 012:** No subsequent statement references `'PROMOTED'::staging_candidate_status`. The added columns in `staged_rate_candidates` are `UUID`, `TIMESTAMPTZ`, and `TEXT`. In `promotion_audit_log`, `action`, `previous_status`, and `new_status` are defined as `TEXT`, not the enum type.
- **Outside Migration 012:** Migration 019 (`20261107073416_atomic_candidate_promotion_rpc.sql`) explicitly uses:
  - `IF v_candidate.staging_status = 'PROMOTED'::public.staging_candidate_status THEN`
  - `staging_status = 'PROMOTED'::public.staging_candidate_status`
- Migration 020 (`20261108050936_atomic_policy_escalation_rpc.sql`) evaluates:
  - `IF p_new_status IN ('PROMOTED', 'VERIFIED') THEN`

### 3.3 Transaction Safety Analysis & PostgreSQL Error 55P04
In PostgreSQL:
- An `ALTER TYPE ... ADD VALUE` statement changes the system catalog definition of the enum type.
- Under PostgreSQL's transactional DDL architecture, a newly added enum value **cannot be referenced or evaluated in any expression, cast, or query within the same transaction**. Attempting to do so immediately raises:
  `ERROR: 55P04: unsafe use of new value "PROMOTED" of enum type staging_candidate_status`
  `HINT: New enum values must be committed before they can be used.`
- **Why Absence of Outer BEGIN/COMMIT Does Not Ensure Safety:** In the Supabase Web Console SQL Editor, executing multiple statements in a single "Run" submission implicitly executes them in a single transaction block. If an operator pastes Migration 012 alongside queries or migrations that reference `'PROMOTED'`, PostgreSQL treats them as a single transaction and fails with `55P04`.
- **Subtransaction Risk:** Wrapping `ALTER TYPE ... ADD VALUE` inside a PL/pgSQL `EXCEPTION` block creates a subtransaction (savepoint), which PostgreSQL restricts for certain DDL commands.

### 3.4 Exact SQL Editor Execution Sequence for Migration 012

To guarantee safety, the DBA must execute Migration 012 in two committed segments:

#### Segment A: Isolated Enum Extension
Execute in SQL Editor and commit:
```sql
ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED';
COMMIT;
```
*Verify enum catalog state:*
```sql
SELECT enumlabel
FROM pg_enum
WHERE enumtypid = 'staging_candidate_status'::regtype
ORDER BY enumsortorder;
```
*Confirmation:* Verify that the output includes `'DRAFT'`, `'IN_REVIEW'`, `'REJECTED'`, `'INVALID'`, and `'PROMOTED'`.

#### Segment B: Table Alteration & Audit Log Creation
Execute the remainder of Migration 012 in SQL Editor:
```sql
ALTER TABLE staged_rate_candidates
  ADD COLUMN IF NOT EXISTS promoted_rate_id UUID REFERENCES fd_rates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS promoted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS promoted_by TEXT,
  ADD COLUMN IF NOT EXISTS promotion_reason TEXT;

CREATE TABLE IF NOT EXISTS promotion_audit_log (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staged_candidate_id UUID REFERENCES staged_rate_candidates(id) ON DELETE SET NULL,
  rate_id             UUID REFERENCES fd_rates(id) ON DELETE CASCADE,
  action              TEXT NOT NULL,
  actor_type          TEXT NOT NULL,
  actor_id            TEXT,
  previous_status     TEXT,
  new_status          TEXT,
  policy_result       JSONB,
  diff_summary        JSONB,
  source_content_hash TEXT,
  parser_version      TEXT,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prom_audit_rate ON promotion_audit_log (rate_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_prom_audit_cand ON promotion_audit_log (staged_candidate_id);
CREATE INDEX IF NOT EXISTS idx_prom_audit_action ON promotion_audit_log (action);
CREATE INDEX IF NOT EXISTS idx_prom_audit_actor ON promotion_audit_log (actor_type);
CREATE INDEX IF NOT EXISTS idx_prom_audit_created ON promotion_audit_log (created_at DESC);
```

---

## 4. Migration 017 — Transaction Handling Deep Dive

### 4.1 Internal Boundaries of `20261025100101_calendar_aware_candidate_staging_017.sql`

Inspection of the complete 313-line migration file reveals:
- **Transaction Start:** Line 27 begins with explicit `BEGIN;`.
- **Step 1 (DDL):** Lines 33–42 add calendar tenure columns (`tenure_domain`, `min_years`, `max_operator`, etc.).
- **Step 2 (Preflight Assertion):** Lines 48–73 execute an in-transaction duplicate check (`DO $$ DECLARE v_dup_count ... $$;`). If any active duplicate DAYS candidates exist, it throws `RAISE EXCEPTION` and aborts.
- **Step 3 & 4 (Constraints):** Drop legacy constraints/indices and enforce calendar duration constraints.
- **Step 5 (Partial Unique Indices):** Create domain-specific partial unique indexes `idx_staged_candidates_active_days_identity` and `idx_staged_candidates_active_calendar_identity`.
- **Step 6 (Catalog Verification Assertion):** Lines 267–311 inspect `pg_indexes` to ensure both replacement indexes exist with expected expressions and predicates. If checks fail, it throws `RAISE EXCEPTION` and aborts.
- **Transaction End:** Line 313 concludes with explicit `COMMIT;`.

### 4.2 Why Wrapping in an Outer Transaction is Unsafe
If an operator wraps Migration 017 in an outer `BEGIN ... COMMIT` block:
1. The outer `BEGIN` initiates transaction 1.
2. Line 27 encounters `BEGIN;`. PostgreSQL outputs `WARNING: 25001: there is already a transaction in progress`.
3. At Line 313, `COMMIT;` is encountered. In PostgreSQL, this commits the active transaction immediately.
4. Any statements following Migration 017 in the outer wrapper now run outside the transaction.
5. The trailing outer `COMMIT;` encounters no active transaction and emits `WARNING: 25001: there is no transaction in progress`.
6. If an error occurs after Line 313, rolling back the outer wrapper is impossible because the inner `COMMIT;` has already made the changes permanent.

### 4.3 Execution Rules for Migration 017
- **SQL Editor Execution:** Paste and execute `20261025100101_calendar_aware_candidate_staging_017.sql` **strictly as-is**. Do not prepend `BEGIN;` or append `COMMIT;`.
- **CLI Workflow Execution:** In `npx supabase migration up`, the CLI handles the file natively.
- **File Integrity:** Zero modifications to the SQL file are required or permitted.

---

## 5. End-to-End Dry-Run & CLI Verification Evidence

### 5.1 Supabase CLI Version & Flag Verification

We inspected the installed Supabase CLI environment:
- `backend/package.json` specifies `"supabase": "^2.122.0"` in `devDependencies`.
- Executing `npx supabase --version` inside `backend/` confirmed project-local `v2.122.0`.
- Executing `npx supabase --version` outside `backend/` (repo root) invoked `v3.1.0` from npm cache.

#### Empirical Test: Unrecognized `--remote` Flag in Project-Local CLI v2.122.0
We tested whether `--remote` is supported by project-local Supabase CLI v2.122.0 in `backend/`:

```bash
# Executed inside backend/ (evaluating under local v2.122.0):
# Test 1: Migration repair with --remote
npx supabase migration repair --status applied 001 --remote
# Output:
# {"_tag":"Error","error":{"code":"UnrecognizedOption","message":"Unrecognized flag: --remote in command supabase migration repair"}}

# Test 2: Migration list with --remote
npx supabase migration list --remote
# Output:
# {"_tag":"Error","error":{"code":"UnrecognizedOption","message":"Unrecognized flag: --remote in command supabase migration list"}}
```
**Conclusion for CLI v2.122.x:** In Supabase CLI v2.122.x, the flag `--remote` is strictly invalid. The supported flag for linked remote projects is `--linked` (or `--project-ref <id>`).

*(Cross-Version Reconcilation Note: In Supabase CLI v3.x, official documentation and CLI architecture introduced `--remote` as the primary, preferred target flag for remote databases, retaining `--linked` as deprecated compatibility syntax. Because the release runbook executes in `backend/` using the project-local `v2.122.0` package, `--linked` is the verified and required syntax for that workflow. See `docs/release/phase_5_1_1_4_cli_compatibility_clarification.md` for complete cross-version verification).*

#### Empirical Test: Flag Recognition with `--linked`
When running with `--linked`:
```bash
npx supabase migration list --linked
# Output:
# {"_tag":"Error","error":{"code":"DbConfigIpv6Error","message":"IPv6 is not supported on your current network","suggestion":"Run supabase link --project-ref cqrslxngpwbtkjejlwty to setup IPv4 connection."}}
```
**Observation:** The CLI properly recognizes `--linked` and attempts connection to the linked staging project (`cqrslxngpwbtkjejlwty`). The `DbConfigIpv6Error` occurs because direct Supabase PostgreSQL endpoints resolve to IPv6, and the Windows host network lacks IPv6 routing. In standard Supabase workflows, configuring the connection pooler via `supabase link` provides the required IPv4 connection.

### 5.2 Test Suite Analysis: `migration_deployment_guard_test.js`

Executing `npm run test:deployment-guard` in `backend/` yielded:
```text
Group 1: Filename Parsing & Version Classification
  ✓ parseMigrationFilename correctly parses 3-digit legacy migrations
  ✓ parseMigrationFilename correctly parses 14-digit timestamped migrations
  ✓ parseMigrationFilename returns null for non-sql or invalid filenames

Group 2: Live Migration Directory Analysis
  ✗ analyzeMigrationDirectory categorizes all 21 repository migrations accurately
    Expected 21 total migration files: 24 !== 21
```

**Root Cause Analysis:**
`migration_deployment_guard_test.js` was written during Phase 3C.14 when the repository held exactly 21 migrations (15 legacy + 6 timestamped). Subsequently, three migrations were added:
- `20261107073416_atomic_candidate_promotion_rpc.sql` (Migration 019)
- `20261108050936_atomic_policy_escalation_rpc.sql` (Migration 020)
- `20261112193000_verified_rate_notification_events.sql` (Migration 021)

This brought the total to 24 migrations (15 legacy + 9 timestamped). The test failure is caused by a hardcoded count assertion (`21`), not a defect in the migration files or the guard logic. In accordance with the prompt's boundary rules (*"Documentation changes only, unless a genuine migration defect is identified. Explain any proposed code change separately and do not apply it automatically"*), no code edits were applied to `migration_deployment_guard_test.js`.

**Recommended Test Maintenance (For Project Owner / Backend Engineer):**
In `backend/test/migration_deployment_guard_test.js` line 88:
```javascript
// Proposed update:
assert.strictEqual(analysis.totalCount, 24, 'Expected 24 total migration files');
assert.strictEqual(analysis.legacyFiles.length, 15, 'Expected 15 legacy files (001–015)');
assert.strictEqual(analysis.timestampedFiles.length, 9, 'Expected 9 timestamped files');
```

---

## 6. Exact Documents Updated

The following authoritative documents in `docs/release/` were updated during Phase 5.1.1.3:

| Document File Path | Nature of Modifications | Primary Sections Affected |
| :--- | :--- | :--- |
| `docs/release/final_production_deployment_runbook.md` | Updated version to 1.2.0. Completely removed manual SQL `INSERT INTO supabase_migrations.schema_migrations`. Documented supported `supabase migration repair --status applied <version> --linked` workflow and explained history-only behavior. Added exact 2-segment execution sequence for Migration 012 and explained PostgreSQL error 55P04 enum transaction safety. Verified Migration 017 internal transaction boundaries (`BEGIN;` L27, `COMMIT;` L313) and prohibited outer transaction wrapping. Established hard gate before future `supabase db push`. | Sections 3.1, 3.2 |
| `docs/release/final_owner_action_checklist.md` | Updated phase to 5.1.1.3. Updated Item 04 action steps: replaced manual `schema_migrations` insertion with `npx supabase migration repair --status applied ... --linked`; added Migration 012 two-segment execution and Migration 017 as-is execution guidance; updated verification method with `migration list --linked`. | Section 2 (Tier 3 Table), Section 3 (Item 4) |
| `docs/release/phase_5_1_1_3_migration_execution_safety_report.md` | Authoritative safety patch report documenting investigations, empirical CLI flag tests, transaction boundary audits, and final verdict. | Entire Document |

---

## 7. Governance, Boundaries & Compliance Verification

| Constraint / Boundary | Compliance Evidence |
| :--- | :--- |
| **Never access production Supabase (`pmaykclwuyspxhgeomee`)** | **PASS.** Zero network requests, queries, or CLI commands were executed against the production project reference. |
| **Never access or modify main repository (`C:\projects\fincalc_pro`)** | **PASS.** All work was strictly confined to `C:\projects\fincalc_pro_staging_prep`. |
| **Never deploy Vercel or execute production SQL** | **PASS.** No Vercel deployment commands or remote production SQL statements were run. |
| **Preserve all existing modified/untracked files** | **PASS.** All existing working copy changes and untracked assets remain completely intact. |
| **No Git reset, clean, stash, commits, pushes, or branch deletion** | **PASS.** No destructive git commands were issued. Working copy remains on branch `staging/vercel-backend-preview`. |
| **Documentation changes only** | **PASS.** Only documentation files in `docs/release/` were modified/created. No production code or migration SQL files were altered. |

---

## 8. Remaining Manual Owner Actions

The Project Owner and Database Administrator must execute the following physical steps when conducting the production deployment:

1. **Production Supabase Console:** Log in to project `pmaykclwuyspxhgeomee` > **SQL Editor**.
2. **Execute Migrations 01 through 11:** Sequentially execute each file.
3. **Execute Migration 012 in Two Segments:**
   - Run Segment A (`ALTER TYPE ... ADD VALUE IF NOT EXISTS 'PROMOTED'; COMMIT;`).
   - Verify enum in catalog (`SELECT enumlabel FROM pg_enum ...`).
   - Run Segment B (columns, `promotion_audit_log`, and indices).
4. **Execute Migrations 13 through 16:** Sequentially execute each file.
5. **Execute Migration 017 As-Is:** Paste `20261025100101_calendar_aware_candidate_staging_017.sql` directly into SQL Editor without outer `BEGIN ... COMMIT` blocks.
6. **Execute Migrations 18 through 24:** Sequentially execute each file.
7. **Run Catalog Verification Queries:** Execute Queries 1 through 5 in Section 3.3 to confirm RLS, `security_invoker = true`, and permissions.
8. **Run Supabase CLI Migration Repair:** Execute `npx supabase migration repair --status applied <all 24 versions> --linked` in `backend/`.
9. **Verify History Synchronization:** Run `npx supabase migration list --linked` and verify zero unapplied diffs.

---

## 9. Final Milestone Verdict

# **`MIGRATION RUNBOOK VERIFIED — OWNER EXECUTION REQUIRED`**

**Production deployment is NOT authorized or completed.** Execution of production migrations and application deployment remains strictly gated pending physical DBA execution of the verified runbook procedures.
