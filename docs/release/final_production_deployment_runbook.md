# FeroCalc — Production Deployment & Release Runbook

**Document Version:** 1.3.0 (Phase 5.1.1.5 Explicit Production Migration Target Binding)
**Package:** `com.ferocalc.app`
**Target Environment:** Production
**Backend Host:** Vercel Production Project
**Database Host:** Supabase Production Project (`pmaykclwuyspxhgeomee`)
**Play Store Scope:** India (`IN`) Only
**Safety Protocol:** Strictly Manual Execution by Project Owner. No automated scripts may run against production without human authorization. Never access production credentials during pre-production verification.

---

## 1. Release Architecture & Dependency Map

```
+-----------------------------------------------------------------------------------+
|                              PROJECT OWNER / DBA                                  |
|   - Production Upload Keystore (.jks)                                             |
|   - Production Supabase Credentials (DBA)                                         |
|   - Production Vercel Environment Variables                                       |
|   - Google Play Console Release Management                                        |
+-----------------------------------------------------------------------------------+
                                   |
         +-------------------------+-------------------------+
         |                                                   |
         v                                                   v
+-----------------------------+             +----------------------------------+
|   SUPABASE PRODUCTION DB    |             |     VERCEL PRODUCTION API        |
|   (pmaykclwuyspxhgeomee)    |             |   (api.ferocalc.app / Vercel)    |
|   - 24 Ordered Migrations   |<----------->|   - Strict Production Env Vars   |
|   - RLS Policies & Roles    |   REST/RPC  |   - Rate Change Notification API |
|   - Views (security_invoker)|             |   - Verified Rate Endpoints      |
|   - Atomic Promotion RPC    |             |   - Health Monitoring            |
+-----------------------------+             +----------------------------------+
                                                             ^
                                                             | HTTPS
                                            +----------------------------------+
                                            |       ANDROID CLIENT (.AAB)      |
                                            |   - Version: 1.0.1 (Code 7)      |
                                            |   - Target SDK: 36 (Android 16)  |
                                            |   - Signed: Production Keystore  |
                                            |   - Play Console: India Only     |
                                            +----------------------------------+
```

---

## 2. Pre-Flight Checklist (Hard Verification Gates)

Before initiating production deployment, verify every item below:

- [ ] **Working Copy Clean:** Repository is in clean state on `staging/vercel-backend-preview` or dedicated release branch.
- [ ] **Flutter Tests Passing:** All 696 tests passed (`flutter test`).
- [ ] **Flutter Analyze Clean:** Zero errors, zero warnings (`flutter analyze --no-fatal-infos`).
- [ ] **Backend Tests Passing:** All 46 test suites passed (`npm test` in `backend/`).
- [ ] **Staging Verification Complete:** Staging QA APK (`build/app/outputs/flutter-apk/app-release.apk`, 69.2 MB) verified on device.
- [ ] **Signing Safeguards Verified:** Fail-closed release signing confirmed via `signingReport` and `bundleRelease` tests.
- [ ] **Legal Placeholders Replaced:** Publisher legal entity and registered address updated in `docs/legal/` files.
- [ ] **Privacy Policy Hosted:** Public HTTPS URL confirmed active and returning valid HTML/Markdown.

---

## 3. Phase A: Supabase Production Database Migration Runbook

> [!CAUTION]
> Production Supabase (`pmaykclwuyspxhgeomee`) must never receive ad-hoc unversioned SQL.
> **DO NOT blindly wrap every migration file in an outer `BEGIN ... COMMIT` block.**
> Inspect the transaction compatibility column below before executing.

### 1. Complete Exact Migration Inventory & Transaction Compatibility Matrix

Every migration must be applied in exact sequential numerical order (1 through 24):

| Step | Exact Migration File Name | Target Scope | Transaction Compatibility & Execution Notes |
| :--- | :--- | :--- | :--- |
| **01** | `001_create_enums.sql` | Base ENUMs (bank types, status, customer types) | **Transaction-safe.** Uses idempotent `DO $$ BEGIN ... EXCEPTION` blocks. Can run in `BEGIN ... COMMIT`. |
| **02** | `002_create_banks.sql` | `banks` table & catalog | **Transaction-safe.** Table DDL, triggers, and timestamps. Can run in `BEGIN ... COMMIT`. |
| **03** | `003_create_fd_rates.sql` | `fd_rates` active published rate table | **Transaction-safe.** Table DDL, check constraints, indexes. Can run in `BEGIN ... COMMIT`. |
| **04** | `004_create_audit_log.sql` | `rate_audit_log` audit records | **Transaction-safe.** Append-only audit table and indexes. Can run in `BEGIN ... COMMIT`. |
| **05** | `005_create_rls_policies.sql` | Base Row-Level Security on core tables | **Transaction-safe.** Base RLS enable statements and policies. Can run in `BEGIN ... COMMIT`. |
| **06** | `006_create_views_and_functions.sql` | Rate querying views & helper functions | **Transaction-safe.** Views and functions. Can run in `BEGIN ... COMMIT`. |
| **07** | `007_overlap_protection.sql` | Day-domain tenure slab overlap protection | **Transaction-safe.** Triggers and exclusion checks. Can run in `BEGIN ... COMMIT`. |
| **08** | `008_overlap_protection_hardening.sql` | Overlap boundary edge-case defense | **Transaction-safe.** Lock helper and hardened triggers. Can run in `BEGIN ... COMMIT`. |
| **09** | `009_calendar_tenure_domain.sql` | Dual tenure domain (DAYS vs CALENDAR) | **Transaction-safe.** Enums, table alterations, helper functions. Can run in `BEGIN ... COMMIT`. |
| **10** | `010_create_rate_source_monitoring.sql` | Collector source status & telemetry | **Transaction-safe.** Enums, `rate_sources`, `source_collection_logs`. Can run in `BEGIN ... COMMIT`. |
| **11** | `011_create_rate_candidate_staging.sql` | `staged_rate_candidates` staging table | **Transaction-safe.** Creates `staging_candidate_status` enum (`'DRAFT'`, `'IN_REVIEW'`, `'REJECTED'`, `'INVALID'`) and staging table. Can run in `BEGIN ... COMMIT`. |
| **12** | `012_candidate_promotion_and_audit.sql` | Staging promotion logging & audit trail | **SPECIAL TRANSACTION NOTE (ENUM TRANSACTION SAFETY):** Contains `ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED';`. In PostgreSQL, a newly added enum value cannot be used in expressions, casts, or functions within the same transaction (fails with `ERROR: 55P04: unsafe use of new value "PROMOTED"`). Executing without an explicit outer `BEGIN/COMMIT` does **not** ensure safety because the Supabase Web SQL Editor evaluates entire query editor submissions in an implicit transaction block. In SQL Editor, execute in **two committed segments**: **Segment A:** `ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED'; COMMIT;` then **Segment B:** table alteration & `promotion_audit_log` DDL. See detailed execution protocol in Section 3.2. |
| **13** | `013_create_pipeline_runs_and_health.sql` | Ingestion pipeline telemetry & locks | **Transaction-safe.** `rate_pipeline_runs` and concurrency lock table. Can run in `BEGIN ... COMMIT`. |
| **14** | `014_create_baseline_attestations.sql` | Rate source SHA-256 baseline hashes | **Transaction-safe.** Baseline attestations table and indexes. Can run in `BEGIN ... COMMIT`. |
| **15** | `015_add_special_scheme_to_staged_candidates.sql` | Bespoke schemes (e.g. 400 Days, We-Care) | **Transaction-safe.** Column additions to staging table. Can run in `BEGIN ... COMMIT`. |
| **16** | `20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql` | Revoke unsafe DDL privileges | **Transaction-safe.** Enables RLS on core tables, revokes TRUNCATE/TRIGGER/REFERENCES. Can run in `BEGIN ... COMMIT`. |
| **17** | `20261025100101_calendar_aware_candidate_staging_017.sql` | Calendar tenure candidate staging | **DO NOT WRAP IN OUTER TRANSACTION.** This script already encapsulates its own transaction boundary with `BEGIN;` (line 27) and `COMMIT;` (line 313), along with in-transaction fail-closed duplicate preflight (line 48) and catalog verification assertions (line 267). Wrapping it in an outer transaction causes nested transaction warnings (`WARNING: 25001`) and causes the internal `COMMIT;` to commit prematurely before outer wrappers finish, breaking rollback atomicity. Execute strictly as-is. |
| **18** | `20261025100407_restrict_public_views_to_read_only.sql` | Read-only permissions on public views | **Transaction-safe.** Revokes INSERT, UPDATE, DELETE from anon/authenticated on views. Can run in `BEGIN ... COMMIT`. |
| **19** | `20261025100630_use_invoker_security_for_public_views.sql` | `security_invoker = true` on views | **Transaction-safe.** Alters `current_user_role` and `verified_fd_rates` to enforce `security_invoker = true`. Can run in `BEGIN ... COMMIT`. |
| **20** | `20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql` | Least-privilege admin RLS helper | **Transaction-safe.** Hardens `is_admin()` as STABLE SECURITY INVOKER; splits bank policies. Can run in `BEGIN ... COMMIT`. |
| **21** | `20261028095435_restrict_reviewer_bank_catalog_mutations.sql` | Restrict reviewer role to rate candidates | **Transaction-safe.** Implements `can_manage_bank_catalog()` and runs schema assertions. Can run in `BEGIN ... COMMIT`. |
| **22** | `20261107073416_atomic_candidate_promotion_rpc.sql`| Atomic promotion RPC transaction | **Transaction-safe.** Implements `promote_candidate_atomic` function. Can run in `BEGIN ... COMMIT`. |
| **23** | `20261108050936_atomic_policy_escalation_rpc.sql` | Atomic policy escalation RPC | **Transaction-safe.** Implements `escalate_policy_violation_atomic` function. Can run in `BEGIN ... COMMIT`. |
| **24** | `20261112193000_verified_rate_notification_events.sql` | `verified_rate_notification_events` table | **Transaction-safe.** Creates event store, unique constraint on `event_id`, and RLS policies. Can run in `BEGIN ... COMMIT`. |

---

### 2. Migration History Reconciliation & Execution Safety Protocol

#### Background & Historical Context:
- **Staging Database (`cqrslxngpwbtkjejlwty`):** Migrations `001` through `015` were applied manually during early development prior to Supabase CLI adoption. Their schema objects exist in the database catalog, but they are **not recorded** in `supabase_migrations.schema_migrations`. Only the timestamped migrations (`20261025095847` through `20261112193000`) exist in the remote tracking ledger.
- **Production Database (`pmaykclwuyspxhgeomee`):** Production Supabase is fresh and unmigrated.
- **Filename Parsing & Version Preservation:** Supabase CLI parses migration filenames using the regex `^([0-9]+)_(.*)\.sql$`. Legacy 3-digit versions (`001` to `015`) and 14-digit timestamped versions (`20261025095847` to `20261112193000`) are valid and distinct version identifiers. **Original migration versions and filenames must be preserved exactly.** Do NOT rename legacy migrations to synthetic timestamps or regenerate them; altering filenames invalidates attestation checksums and git provenance.

#### Strict Rule: Prohibition of Direct SQL Ledger Insertion
> [!CAUTION]
> **NEVER MANUALLY INSERT INTO `supabase_migrations.schema_migrations`:**
> Direct `INSERT INTO supabase_migrations.schema_migrations (version) VALUES (...)` statements bypass Supabase CLI schema tracking, internal version validations, and concurrency locks. Furthermore, the internal schema of `schema_migrations` varies across Supabase CLI engine versions. Ad-hoc SQL inserts risk ledger corruption.
> **Always use the official Supabase CLI command: `supabase migration repair`.**

#### Strict Rule: Migration Repair Does Not Execute SQL
> [!IMPORTANT]
> **`supabase migration repair` updates history only; it does NOT execute SQL:**
> Running `npx supabase migration repair --status applied <version>` informs the Supabase CLI ledger that the migration has already been executed on the target database. It does **not** evaluate, validate, or execute any SQL statements contained in the migration file.
> Consequently, `migration repair` must **ONLY** be invoked **after** the SQL statements have been fully executed and catalog-verified via SQL Editor.

---

#### Workflow Option A: Web Console SQL Editor + CLI Migration Repair (Recommended)

When executing migrations manually through the Supabase Web Console SQL Editor:

##### Step A.1: Execute Migrations Sequentially (1 to 24)
Follow the exact numerical sequence in the inventory table (Steps 01 through 24). For each migration:
1. Open Supabase Dashboard for project `pmaykclwuyspxhgeomee` > **SQL Editor**.
2. Paste the SQL content of the migration file.
3. Observe the specialized execution protocols below for **Migration 012** and **Migration 017**.
4. Click **Run** and verify successful execution (status `Success. No rows returned` or table output).

##### Special Protocol: Migration 012 (`012_candidate_promotion_and_audit.sql`)
In PostgreSQL, executing `ALTER TYPE ... ADD VALUE` cannot be combined with statements that use or evaluate the new enum value within the same transaction. Even though `012` itself only defines columns and does not cast `'PROMOTED'` in DDL, running `012` in a session that evaluates subsequent expressions or queries using `'PROMOTED'` triggers PostgreSQL error `55P04`. Additionally, running `ALTER TYPE ... ADD VALUE` inside a subtransaction (`DO $$ ... EXCEPTION ... $$`) is restricted in PostgreSQL.

To guarantee zero transaction-boundary errors in the SQL Editor, execute Migration 012 in **two committed segments**:

**Segment A: Enum Extension (Execute and commit independently):**
```sql
-- Migration 012: Segment A (Enum Extension)
ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED';
COMMIT;
```
*Run Segment A and verify in catalog:*
```sql
SELECT enumlabel
FROM pg_enum
WHERE enumtypid = 'staging_candidate_status'::regtype
ORDER BY enumsortorder;
-- Expected output must include: DRAFT, IN_REVIEW, REJECTED, INVALID, PROMOTED
```

**Segment B: Staging Columns & Promotion Audit Log Table:**
```sql
-- Migration 012: Segment B (Columns, Tables & Indexes)
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
*Run Segment B and confirm successful execution.*

##### Special Protocol: Migration 017 (`20261025100101_calendar_aware_candidate_staging_017.sql`)
- **Self-Contained Transaction:** Migration 017 explicitly manages its transaction boundary (`BEGIN;` at Line 27 and `COMMIT;` at Line 313).
- **Embedded Assertions:** It contains an in-transaction duplicate preflight check (Line 48) and an in-transaction catalog verification assertion (Line 267). If any check fails, the migration aborts and rolls back automatically.
- **Execution Rule:** Paste and execute the file **strictly as-is**. Do NOT add an outer `BEGIN ... COMMIT` block. Adding an outer transaction causes nested transaction warnings (`25001`) and causes the inner `COMMIT;` to commit prematurely, breaking transaction encapsulation.

##### Step A.2: Execute Catalog Verification Queries
Immediately run the 5 PostgreSQL catalog verification queries documented in Section 3.3 to confirm:
- All 11 core tables exist with `relrowsecurity = true`.
- All public views enforce `security_invoker = true`.
- Public/anon roles possess zero mutation privileges.
- RPC functions have correct security modes (`promote_candidate_atomic` is `SECURITY DEFINER`; `is_admin` is `SECURITY INVOKER`).
- Unique constraints and deduplication keys are active.

##### Step A.3: Reconcile Migration History via Supabase CLI

Once all 24 migrations have executed successfully in the Supabase SQL Editor and catalog assertions pass, use the official Supabase CLI to record all 24 versions in `supabase_migrations.schema_migrations`.

###### Mandatory Preflight Gate: Target Database & CLI Version Verification
Before executing any CLI migration repair or list command, the operator must complete this mandatory preflight verification:

1. **Identify Resolved CLI Version:**
   Execute in the terminal:
   ```bash
   cd C:\projects\fincalc_pro_staging_prep\backend
   npx supabase --version
   ```
   - **Project-Local CLI (v2.122.x — Default Runbook Execution):**
     Inside `backend/`, `npx supabase` resolves to the project-local dependency pinned in `backend/package.json` (`"supabase": "^2.122.0"`). In CLI v2.122.x, the verified flag for targeting a remote database by reference ID is `--project-ref <ref>`. The `--remote` flag does not exist in v2.x and terminates with `Unrecognized flag: --remote`.
   - **Supabase CLI v3.x (Latest / Global Execution):**
     If executed outside `backend/` or using a global CLI installation resolving to v3.x, the unified target flag is `--remote=<ref>`.

2. **Confirm Intended Project Reference:**
   - **Production Database Reference (EXPLICIT TARGET):** `pmaykclwuyspxhgeomee`
   - **Staging Database Reference (STRICTLY FORBIDDEN FOR PRODUCTION REPAIR):** `cqrslxngpwbtkjejlwty`

3. **Verify Local Link State & Absolute Prohibition of Blind `--linked` Usage:**
   - Check the currently cached link reference in the workspace:
     ```bash
     cat backend/supabase/.temp/project-ref
     ```
     *(In PowerShell: `Get-Content backend/supabase/.temp/project-ref`)*
   - > [!CAUTION]
     > **STAGING CORRUPTION HAZARD:** In this workspace, `backend/supabase/.temp/project-ref` points to `cqrslxngpwbtkjejlwty` (the staging database). Running commands with `--linked` without explicit relinking targets the **staging** environment!
     > Staging reference `cqrslxngpwbtkjejlwty` must **NEVER** receive production migration-history repair. Staging possesses its own historical reconciliation rules (where legacy migrations `001` through `015` remain unrecorded to prevent catalog drift).
     > **Do NOT rely on `--linked`** unless you have explicitly relinked to production (`npx supabase link --project-ref pmaykclwuyspxhgeomee`) and confirmed that `backend/supabase/.temp/project-ref` contains exactly `pmaykclwuyspxhgeomee`.
     > To completely eliminate target ambiguity and safeguard staging, all runbook commands **must explicitly bind to `--project-ref pmaykclwuyspxhgeomee`** (CLI v2.122.0) or `--remote=pmaykclwuyspxhgeomee` (CLI v3.x).

4. **Security & Credential Masking Standard:**
   - **NEVER** display, echo, print, or log access tokens (`SUPABASE_ACCESS_TOKEN`), database passwords (`--password`, `PGPASSWORD`), or service-role keys in shell history, terminal transcripts, CI logs, or tickets.
   - When required, enter passwords via interactive masked prompts or inject tokens via secure runtime environment variables.

###### Step A.3.1: Execute History Repair with Explicit Production Target Binding

Execute history repair from the `backend/` directory using explicit target binding to production project `pmaykclwuyspxhgeomee`:

**Project-Local CLI v2.122.0 (Default Runbook Standard):**

*Option 1: Batch repair (all 24 versions in one atomic CLI operation — Recommended)*
```bash
cd C:\projects\fincalc_pro_staging_prep\backend

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
  --project-ref pmaykclwuyspxhgeomee
```

*Option 2: Individual version repairs (if targeting versions sequentially)*
```bash
cd C:\projects\fincalc_pro_staging_prep\backend

npx supabase migration repair --status applied 001 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 002 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 003 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 004 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 005 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 006 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 007 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 008 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 009 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 010 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 011 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 012 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 013 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 014 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 015 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261025095847 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261025100101 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261025100407 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261025100630 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261025100654 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261028095435 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261107073416 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261108050936 --project-ref pmaykclwuyspxhgeomee
npx supabase migration repair --status applied 20261112193000 --project-ref pmaykclwuyspxhgeomee
```

**Supabase CLI v3.x Cross-Version Syntax (Alternative):**
If the operator executes using Supabase CLI v3.x, use `--remote=pmaykclwuyspxhgeomee`:
```bash
npx supabase migration repair --status applied \
  001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 \
  20261025095847 20261025100101 20261025100407 20261025100630 \
  20261025100654 20261028095435 20261107073416 20261108050936 20261112193000 \
  --remote=pmaykclwuyspxhgeomee
```

##### Step A.4: Verify Remote Migration History Synchronization
Verify that all 24 local migrations match remote applied versions on production project `pmaykclwuyspxhgeomee`:

**Project-Local CLI v2.122.0 (Default):**
```bash
cd C:\projects\fincalc_pro_staging_prep\backend
npx supabase migration list --project-ref pmaykclwuyspxhgeomee
```

**Supabase CLI v3.x Alternative:**
```bash
npx supabase migration list --remote=pmaykclwuyspxhgeomee
```

*(Note: Do NOT rely on `--linked` unless the operator has confirmed `cat backend/supabase/.temp/project-ref` returns `pmaykclwuyspxhgeomee`).*

**Expected Verification Output:**
All 24 migration rows must display `Remote: Applied` (or matching timestamped state) with **ZERO** unapplied local migrations.

```
 Local          | Remote         | Time (UTC)
----------------+----------------+----------------------
 001            | Applied        | 2026-11-...
 ...            | Applied        | ...
 015            | Applied        | 2026-11-...
 20261025095847 | Applied        | 2026-11-...
 20261025100101 | Applied        | 2026-11-...
 20261025100407 | Applied        | 2026-11-...
 20261025100630 | Applied        | 2026-11-...
 20261025100654 | Applied        | 2026-11-...
 20261028095435 | Applied        | 2026-11-...
 20261107073416 | Applied        | 2026-11-...
 20261108050936 | Applied        | 2026-11-...
 20261112193000 | Applied        | 2026-11-...
```

##### Hard Gate: Future `supabase db push` Authorization
> [!CAUTION]
> **`supabase db push` IS STRICTLY BLOCKED UNTIL RECONCILIATION IS COMPLETE:**
> If any local migration (especially legacy sequential migrations `001` through `015`) is missing from remote `supabase_migrations.schema_migrations`, running `supabase db push` will attempt to replay that migration file.
> Replaying `001`–`015` against an initialized database triggers fatal catalog collisions and catastrophic security reversals:
> - Replaying `001` fails on duplicate enum type `rate_status`.
> - Replaying `002` fails on duplicate table `public.banks`.
> - **CRITICAL:** Replaying `005` recreates `banks_admin_write` and binds `is_admin()`, completely reversing Phase 3C.10/3C.11 bank catalog protections and re-exposing master catalog mutations to the `REVIEWER` role.
> - Replaying `006` replaces hardened `security_invoker = true` views with legacy definer views.
> - Replaying `007` & `008` replaces calendar tenure logic with superseded day-only triggers.
> Only when `npx supabase migration list --project-ref pmaykclwuyspxhgeomee` (or `--remote=pmaykclwuyspxhgeomee` on CLI v3) confirms that all local files match applied remote entries with zero diffs is future `db push` permitted.

---

#### Workflow Option B: Supabase CLI Workflow (`supabase migration up`)
If using Supabase CLI directly against production from a machine with configured network access:
1. Ensure `SUPABASE_ACCESS_TOKEN` is set: `npx supabase link --project-ref pmaykclwuyspxhgeomee`.
2. Configure IPv4 pooler connection (Supabase direct database endpoints resolve via IPv6; IPv4 requires the connection pooler).
3. Execute: `npx supabase migration up`.
4. Verify with: `npx supabase migration list --project-ref pmaykclwuyspxhgeomee` (CLI v2.122.x) or `npx supabase migration list --remote=pmaykclwuyspxhgeomee` (CLI v3.x).

---

### 3. Corrected Post-Migration Verification Queries (PostgreSQL Catalog-Level)

Execute these queries in the Supabase SQL Editor immediately following migration execution:

```sql
-- ============================================================
-- VERIFICATION QUERY 1: Table Inventory & Row-Level Security
-- Confirms all 11 core tables exist and RLS is enabled.
-- ============================================================
SELECT
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    CASE WHEN c.relrowsecurity THEN 'PASS: RLS ACTIVE' ELSE 'FAIL: RLS INACTIVE' END AS rls_verdict
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
ORDER BY c.relname;
-- EXPECTED: Exactly 11 tables with rls_enabled = true:
-- banks, baseline_source_attestations, fd_rates, promotion_audit_log,
-- rate_audit_log, rate_pipeline_locks, rate_pipeline_runs, rate_sources,
-- source_collection_logs, staged_rate_candidates, verified_rate_notification_events.

-- ============================================================
-- VERIFICATION QUERY 2: Views & security_invoker Catalog Verification
-- CRITICAL: Uses pg_class.reloptions instead of information_schema.
-- ============================================================
SELECT
    c.relname AS view_name,
    c.reloptions AS view_options,
    CASE
        WHEN 'security_invoker=true' = ANY(c.reloptions) THEN 'PASS: security_invoker=true'
        ELSE 'FAIL: missing security_invoker'
    END AS invoker_status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'v'
ORDER BY c.relname;
-- EXPECTED:
-- current_user_role | {security_invoker=true} | PASS: security_invoker=true
-- verified_fd_rates | {security_invoker=true} | PASS: security_invoker=true

-- ============================================================
-- VERIFICATION QUERY 3: Public Grants & Permission Hardening
-- Confirms public/anon cannot execute mutations on tables or views.
-- ============================================================
SELECT
    table_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated')
  AND privilege_type NOT IN ('SELECT')
ORDER BY table_name, grantee, privilege_type;
-- EXPECTED: ZERO ROWS RETURNED. (Anon/authenticated must NEVER have INSERT/UPDATE/DELETE/TRUNCATE).

-- ============================================================
-- VERIFICATION QUERY 4: Custom RPC Functions & Security Modes
-- ============================================================
SELECT
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE WHEN p.prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END AS security_mode
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'is_admin',
    'can_manage_bank_catalog',
    'promote_candidate_atomic',
    'escalate_policy_violation_atomic'
  )
ORDER BY p.proname;
-- EXPECTED:
-- can_manage_bank_catalog        | ()                                  | SECURITY INVOKER
-- escalate_policy_violation_atomic| (...)                              | SECURITY DEFINER
-- is_admin                       | ()                                  | SECURITY INVOKER
-- promote_candidate_atomic       | (uuid, text, text, text)            | SECURITY DEFINER

-- ============================================================
-- VERIFICATION QUERY 5: Notification Events Schema & Deduplication Key
-- ============================================================
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'verified_rate_notification_events';
-- EXPECTED: Primary key on id, and UNIQUE constraint uq_verified_rate_notification_event_id on (event_id).
```

---

## 4. Phase B: Vercel Production Backend Deployment Runbook

### Environment Variables Inventory (Production Project)

Set the following environment variables in the Vercel Production Environment (**Project Settings > Environment Variables**):

| Variable Name | Required Value / Source | Purpose |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | Enforces production runtime optimizations |
| `SUPABASE_URL` | `https://pmaykclwuyspxhgeomee.supabase.co` | Production Supabase database endpoint |
| `SUPABASE_ANON_KEY` | Production Supabase Public Anon Key | Anonymous client queries for rate feeds |
| `SUPABASE_SERVICE_ROLE_KEY` | Production Supabase Service Role Key | Secure backend RPC calls & attestation checks |
| `ADMIN_JWT_SECRET` | 256-bit cryptographically secure random string | Validates internal staff JWT sessions |
| `CORS_ORIGINS` | `https://ferocalc.app` | Restricts cross-origin browser requests |
| `RATE_LIMIT_MAX_REQUESTS` | `100` | Rate limiting protection per IP/minute |

### Deployment Steps:
1. Link Vercel CLI to production project or initiate release via Vercel Web Console:
   ```bash
   vercel --prod
   ```
2. Verify production deployment build completes without errors.
3. Test backend health check endpoints:
   ```bash
   # 1. Health check
   curl -I https://[PROD_BACKEND_DOMAIN]/api/health
   # Expected: HTTP 200 OK

   # 2. Public rate summary (verified feed)
   curl -s https://[PROD_BACKEND_DOMAIN]/api/verified-rates/summary | jq .
   # Expected: Valid JSON rate response

   # 3. Notification device token endpoint (sanitized public endpoint)
   curl -I https://[PROD_BACKEND_DOMAIN]/api/notifications/events
   # Expected: HTTP 200 OK with sanitized public events
   ```

---

## 5. Phase C: Android Production Candidate Assembly (.AAB)

### 1. Release Keystore Configuration
The project owner must create or provide `android/key.properties` (strictly git-ignored):
```properties
storePassword=[YOUR_SECURE_KEYSTORE_PASSWORD]
keyPassword=[YOUR_SECURE_KEY_PASSWORD]
keyAlias=[YOUR_KEY_ALIAS]
storeFile=../upload-keystore.jks
```
Ensure `upload-keystore.jks` is placed in `android/` (or matching relative path).

### 2. Build the Production Android App Bundle (.aab)
Run the build command:
```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
Remove-Item Env:\FEROCALC_STAGING_DEBUG_SIGNING -ErrorAction SilentlyContinue
cd C:\projects\fincalc_pro_staging_prep
flutter build appbundle --release
```

### 3. Verify Generated App Bundle
Verify the output artifact:
- **Location:** `build/app/outputs/bundle/release/app-release.aab`
- **Package Name:** `com.ferocalc.app`
- **Version Name:** `1.0.1`
- **Version Code:** `7`
- **Target SDK:** `36`

---

## 6. Phase D: Google Play Console Release Deployment

1. **Log in to Google Play Console:**
   - Select application: **FeroCalc** (`com.ferocalc.app`).
2. **Configure Country Availability (MANDATORY):**
   - Navigate to: **Release > Production (or Internal testing) > Countries/regions**.
   - Select **India (`IN`)** ONLY.
   - Confirm selection.
3. **Internal Testing Track (Recommended First Step):**
   - Navigate to: **Release > Testing > Internal testing**.
   - Create new release.
   - Upload `build/app/outputs/bundle/release/app-release.aab`.
   - Release name: `1.0.1 (7) - Production Release Candidate`.
   - Release notes:
     ```text
     Initial production release candidate for FeroCalc.
     - 18+ Financial Calculators (FD, RD, SIP, EMI, PPF, SSY, Inflation, CAGR).
     - Official Verified FD Interest Rates across major Indian banks.
     - Smart FD Discovery & Direct Compare tools.
     - On-device private financial calculation architecture, with transparent ad disclosures.
     ```
   - Save and review release.
   - Verify that Google Play pre-launch report generates zero security, crash, or layout errors.
4. **App Content & Data Safety Review:**
   - Confirm all questionnaire sections match `docs/release/google_play_app_content_checklist.md` and `docs/release/google_play_data_safety_draft.md`.
5. **Promotion to Production:**
   - Once Internal Testing and Closed Testing validations pass, promote the release to Production with a staged rollout (e.g., 20% -> 50% -> 100%).

---

## 7. Emergency Rollback & Incident Response Procedures

### 1. Mobile App Rollout Halt
If a critical client defect is discovered during rollout:
1. In Google Play Console, go to **Release > Production**.
2. Click **Halt rollout**. This immediately freezes new user downloads of the faulty version while existing users remain on their current version.
3. Prepare a hotfix release with incremented version code (`1.0.1+8`).

### 2. Backend Instant Rollback (Vercel)
If the backend deployment encounters runtime anomalies:
1. In the Vercel Dashboard, navigate to **Deployments**.
2. Locate the previous stable production deployment.
3. Click the three dots menu (`...`) and select **Instant Rollback**.
4. Traffic routes to the previous deployment within seconds without downtime.

### 3. Database Incident Response (Supabase)
If an unauthorized migration state or schema lock occurs:
1. Point-in-time recovery (PITR) is available via the Supabase Dashboard under **Database > Backups**.
2. Rollback scripts for individual tables are maintained in `backend/supabase/drafts/`.
