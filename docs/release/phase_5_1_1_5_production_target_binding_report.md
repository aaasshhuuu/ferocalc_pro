# FeroCalc — Phase 5.1.1.5: Explicit Production Migration Target Binding Report

**Document Version:** 1.0.0
**Execution Timestamp:** November 13, 2026
**Execution Environment:** `C:\projects\fincalc_pro_staging_prep`
**Git Working Branch:** `staging/vercel-backend-preview`
**Scope:** Documentation-only target binding correction, database ambiguity elimination, preflight verification gate definition, and cross-document reconciliation
**Final Milestone Verdict:** **`PRODUCTION MIGRATION TARGET EXPLICITLY VERIFIED — OWNER EXECUTION REQUIRED`**

---

## 1. Executive Summary & Objective Realization

This milestone formally addresses and eliminates target database ambiguity in the Supabase manual SQL Editor + Supabase CLI migration repair workflow (Workflow Option A) for the production release of FeroCalc.

### 1.1 The Identified Target Ambiguity Hazard
In earlier revisions of the production runbook and owner checklist, the post-migration CLI history repair commands relied on the convenience flag:
```bash
npx supabase migration repair --status applied <versions> --linked
npx supabase migration list --linked
```
While convenient in single-environment local workflows, relying on `--linked` in an active multi-environment deployment repository presents a severe operational hazard:
- **Local Link State Inspection:** Inspection of the staging preparation workspace revealed that the local link file at `backend/supabase/.temp/project-ref` currently contains:
  ```text
  cqrslxngpwbtkjejlwty
  ```
  This is the project reference for the **Staging Database (`cqrslxngpwbtkjejlwty`)**.
- **The Staging Pollution Risk:** If a project administrator or DBA had executed the previously documented `--linked` commands without explicitly relinking the workspace, the Supabase CLI would have targeted the **staging** database.
- **Why Staging Must Never Receive Production Repair:** As established in `backend/supabase/drafts/proposed_migration_repair_commands.txt`, staging was deployed early with unversioned legacy migrations (`001` through `015`) that intentionally remain absent from staging's remote `supabase_migrations.schema_migrations` ledger. Marking those 15 legacy versions as applied on staging would alter staging's historical tracking and cause catalog drift. Conversely, production (`pmaykclwuyspxhgeomee`) is a clean, fresh instance where all 24 migrations are executed sequentially in SQL Editor and subsequently recorded in the remote ledger.

### 1.2 The Resolution Implemented
1. **Explicit Production Target Binding:** All production migration repair and list commands have been updated to explicitly target the production project reference:
   ```text
   pmaykclwuyspxhgeomee
   ```
   For the project-local Supabase CLI v2.122.0, the commands strictly use:
   ```bash
   --project-ref pmaykclwuyspxhgeomee
   ```
   This explicit target binding applies to **BOTH**:
   - `supabase migration repair --status applied ... --project-ref pmaykclwuyspxhgeomee`
   - `supabase migration list --project-ref pmaykclwuyspxhgeomee`
2. **Mandatory Preflight Verification Gate:** A mandatory 4-point preflight verification gate has been inserted prior to any repair invocation, enforcing:
   - CLI version resolution (`npx supabase --version`).
   - Project reference confirmation (`pmaykclwuyspxhgeomee` vs `cqrslxngpwbtkjejlwty`).
   - Link state verification (`backend/supabase/.temp/project-ref`).
   - Strict credential masking (zero display or logging of tokens, database passwords, or service-role keys).
3. **CLI v3 Cross-Version Compatibility Retained:** The verified cross-version syntax (`--remote=pmaykclwuyspxhgeomee` for CLI v3.x vs `--project-ref pmaykclwuyspxhgeomee` for CLI v2.122.x) has been fully documented without altering the project's pinned dependency (`supabase@^2.122.0` in `backend/package.json`).
4. **Authoritative Documents Reconciled:** Both `docs/release/final_production_deployment_runbook.md` (v1.3.0) and `docs/release/final_owner_action_checklist.md` (Phase 5.1.1.5) have been updated with complete consistency.

---

## 2. Empirical Investigation & Workspace State Analysis

Prior to modifying runbook directives, empirical checks of the local repository configuration and CLI argument parsers were executed.

### 2.1 Inspection of Local Link Cache (`backend/supabase/.temp/project-ref`)
- **File Path:** `C:\projects\fincalc_pro_staging_prep\backend\supabase\.temp\project-ref`
- **Current Content:**
  ```text
  cqrslxngpwbtkjejlwty
  ```
- **Analysis:**
  The cached reference corresponds to `ferocalc-staging`. If an operator runs `supabase migration repair ... --linked`, the CLI uses this cached value by default. This confirms that relying on `--linked` without explicit relinking would inadvertently target staging instead of production. Explicit target binding (`--project-ref pmaykclwuyspxhgeomee`) overrides any local cached reference, completely eliminating this danger.

### 2.2 Supabase CLI v2.122.0 Help Audit (`backend/`)
Within `backend/`, `npx supabase` resolves to project-local v2.122.0.

#### Command 1: `npx supabase migration repair --help`
```text
FLAGS
  --status choice          Version status to update. (choices: applied, reverted)
  --db-url string          Repairs migrations of the database specified by the connection string (must be percent-encoded).
  --linked                 Repairs the migration history of the linked project.
  --local                  Repairs the migration history of the local database.
  --project-ref string     Project ref of the Supabase project.
  --password, -p string    Password to your remote Postgres database.
```

#### Command 2: `npx supabase migration list --help`
```text
FLAGS
  --db-url string          Lists migrations of the database specified by the connection string (must be percent-encoded).
  --linked                 Lists migrations applied to the linked project.
  --local                  Lists migrations applied to the local database.
  --project-ref string     Project ref of the Supabase project.
  --password, -p string    Password to your remote Postgres database.
```
*Empirical Confirmation:* Both `migration repair` and `migration list` in CLI v2.122.0 officially support `--project-ref <string>`.

### 2.3 Supabase CLI v3.1.0 Help Audit (Root / Global)
At the repository root, `npx supabase` evaluates under v3.1.0.

#### Command 1: `npx supabase migration repair --help`
```text
TARGET
  Local by default. Pass --remote for the linked project, or --remote=<ref|branch|url>.

FLAGS
  --status choice                Version status to update. (choices: applied, reverted)
  --remote[=<ref|branch|url>]    Target a remote database: the linked project, or --remote=<ref|branch|url>.
  --password, -p string          Database password for the project selected with --remote. Not used for the local database or a database URL.
```

#### Command 2: `npx supabase migration list --help`
```text
TARGET
  Local by default. Pass --remote for the linked project, or --remote=<ref|branch|url>.

FLAGS
  --remote[=<ref|branch|url>]    Target a remote database: the linked project, or --remote=<ref|branch|url>.
  --password, -p string          Database password for the project selected with --remote. Not used for the local database or a database URL.
```
*Empirical Confirmation:* Both `migration repair` and `migration list` in CLI v3.x officially support `--remote=<project-ref>` to explicitly bind the remote target.

---

## 3. Mandatory Preflight Protocol Specification

The runbook now establishes a mandatory preflight gate that every operator must execute before running migration repair or listing commands:

```
+-----------------------------------------------------------------------------------+
|                         MANDATORY PREFLIGHT TARGET GATE                           |
+-----------------------------------------------------------------------------------+
                                    |
         +--------------------------+--------------------------+
         |                                                     |
         v                                                     v
+-----------------------------+               +----------------------------------+
|   CLI VERSION IDENTIFICATION|               |   TARGET ISOLATION VERIFICATION  |
|   npx supabase --version    |               |   Explicit Prod: pmaykclwuyspxhgeomee|
|   - In backend/: v2.122.x   |               |   Forbidden:     cqrslxngpwbtkjejlwty|
|   - Global/Root: v3.x       |               |   Check: .temp/project-ref           |
+-----------------------------+               +----------------------------------+
         |                                                     |
         +--------------------------+--------------------------+
                                    |
                                    v
+-----------------------------------------------------------------------------------+
|                        CREDENTIAL MASKING & ISOLATION                             |
|   - Never echo, print, or log SUPABASE_ACCESS_TOKEN, DB passwords, or service keys|
|   - Explicit target binding: --project-ref (v2) or --remote=<ref> (v3)            |
+-----------------------------------------------------------------------------------+
```

### Protocol Steps:
1. **Identify Resolved CLI Version:**
   - Execute: `cd backend && npx supabase --version`.
   - Confirm version output (expected: `2.122.0`).
2. **Confirm Intended Project Reference:**
   - **Production (Explicit Target):** `pmaykclwuyspxhgeomee`
   - **Staging (Strictly Forbidden):** `cqrslxngpwbtkjejlwty`
3. **Verify Local Link State:**
   - Run: `cat backend/supabase/.temp/project-ref` (or `Get-Content backend/supabase/.temp/project-ref`).
   - Note: If `.temp/project-ref` contains `cqrslxngpwbtkjejlwty`, passing `--linked` targets staging!
   - Rule: **Do NOT use `--linked`** unless the workspace has been explicitly relinked via `npx supabase link --project-ref pmaykclwuyspxhgeomee` and `.temp/project-ref` confirmed to read `pmaykclwuyspxhgeomee`.
   - Primary Standard: Always pass `--project-ref pmaykclwuyspxhgeomee` directly.
4. **Credential Masking Standard:**
   - Operators must never output access tokens, database passwords, or service-role keys in terminal sessions, CI logs, or tickets. Use interactive masked inputs or secure environment variables.

---

## 4. Reconciled Production Migration History Repair Commands

### 4.1 Default Runbook Workflow (Project-Local Supabase CLI v2.122.0 in `backend/`)

#### Batch Migration Repair (Recommended):
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

#### Sequential Migration Repair (Alternative):
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

#### Migration History Synchronization Verification:
```bash
cd C:\projects\fincalc_pro_staging_prep\backend
npx supabase migration list --project-ref pmaykclwuyspxhgeomee
```

---

### 4.2 Supabase CLI v3.x Cross-Version Syntax (If Executing with CLI v3)

#### Batch Migration Repair:
```bash
npx supabase migration repair --status applied \
  001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 \
  20261025095847 20261025100101 20261025100407 20261025100630 \
  20261025100654 20261028095435 20261107073416 20261108050936 20261112193000 \
  --remote=pmaykclwuyspxhgeomee
```

#### Migration History Synchronization Verification:
```bash
npx supabase migration list --remote=pmaykclwuyspxhgeomee
```

---

## 5. Comparative Reconciliation Matrix

The table below summarizes the exact modifications across release documentation:

| Document | Section | Previous Text / Directive | Corrected Directive (Phase 5.1.1.5) | Operational Justification |
| :--- | :--- | :--- | :--- | :--- |
| `final_production_deployment_runbook.md` | Document Header | Version 1.2.1 | Version 1.3.0 | Documents explicit target binding milestone. |
| `final_production_deployment_runbook.md` | Section 3.2 (Step A.3) | Immediately presented repair commands using `--linked`. | Inserted **Mandatory Preflight Gate** with CLI version check, reference verification, link state check, and credential masking. | Prevents accidental execution against staging database. |
| `final_production_deployment_runbook.md` | Section 3.2 (Step A.3.1) | `npx supabase migration repair ... --linked` | `npx supabase migration repair ... --project-ref pmaykclwuyspxhgeomee` | Explicitly binds target to production project `pmaykclwuyspxhgeomee`. |
| `final_production_deployment_runbook.md` | Section 3.2 (Step A.3.1) | Indicated `--remote` as general v3 flag. | Documented explicit target syntax: `--remote=pmaykclwuyspxhgeomee`. | Ensures v3 operators also explicitly bind to production. |
| `final_production_deployment_runbook.md` | Section 3.2 (Step A.4) | `npx supabase migration list --linked` | `npx supabase migration list --project-ref pmaykclwuyspxhgeomee` | Guarantees verification checks remote production ledger specifically. |
| `final_production_deployment_runbook.md` | Hard Gate & Option B | Referenced `migration list --linked`. | Updated to reference `migration list --project-ref pmaykclwuyspxhgeomee`. | Ensures consistency throughout all runbook paths. |
| `final_owner_action_checklist.md` | Document Header | Phase 5.1.1.3 | Phase 5.1.1.5 | Aligns checklist with latest safety patch. |
| `final_owner_action_checklist.md` | Tier 3 Matrix (Item 4) | `reconcile CLI history with migration repair --status applied` | `reconcile CLI history targeting explicit production reference: migration repair --status applied ... --project-ref pmaykclwuyspxhgeomee` | Surfaces explicit target binding directly in the top-level checklist matrix. |
| `final_owner_action_checklist.md` | Item 4 Action Steps | Action Step 5 used `--linked`. | Added Preflight step (Step 5); updated repair (Step 6) and list (Step 7) to use `--project-ref pmaykclwuyspxhgeomee`. | Guides DBA through identical preflight and explicit binding steps. |
| `final_owner_action_checklist.md` | Item 4 Verification | `Run npx supabase migration list --linked` | `Run npx supabase migration list --project-ref pmaykclwuyspxhgeomee` | Directs DBA to verify remote production state unambiguously. |

---

## 6. Strict Non-Execution Boundaries Verification

In accordance with strict release engineering protocols:
- [x] **Documentation Changes Only:** Modifications were restricted strictly to markdown documentation files in `docs/release/`.
- [x] **Zero Migration Execution:** No migration repair commands (`npx supabase migration repair`) were executed.
- [x] **Zero Database Access:** Neither staging (`cqrslxngpwbtkjejlwty`) nor production (`pmaykclwuyspxhgeomee`) databases were connected to or queried.
- [x] **Zero Credential Exposure:** No production passwords, personal access tokens, or service-role keys were accessed, stored, displayed, or logged.
- [x] **Code & Migration Preservation:** No migration SQL files (`backend/supabase/migrations/`) or application code were modified.
- [x] **Git State Preserved:** No Git reset, clean, stash, checkout, commit, or push operations were conducted. All modified and untracked files remain intact.

---

## 7. Final Milestone Verdict

The database target binding analysis, empirical CLI validation, preflight safety gate addition, and cross-document reconciliation are complete with zero ambiguities remaining.

**Final Verdict:**
**`PRODUCTION MIGRATION TARGET EXPLICITLY VERIFIED — OWNER EXECUTION REQUIRED`**
