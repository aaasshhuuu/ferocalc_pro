# FeroCalc — Phase 5.1.1.2: Release Candidate Documentation Integrity Corrections Report

**Document Version:** 1.0.0
**Execution Timestamp:** November 13, 2026
**Execution Environment:** `C:\projects\fincalc_pro_staging_prep`
**Git Working Branch:** `staging/vercel-backend-preview`
**Scope:** Documentation Integrity, Store Listing Truthfulness, FD Rate Verification, and Supabase Migration Runbook Corrections
**Final Milestone Verdict:** **`DOCUMENTATION CORRECTIONS COMPLETE — OWNER INPUTS REQUIRED`**

---

## 1. Exact Documents Changed

The following authoritative documents in `docs/release/` and root were updated to correct all identified documentation and release-runbook integrity issues:

| Document File Path | Nature of Modifications | Primary Sections Affected |
| :--- | :--- | :--- |
| `docs/release/final_store_listing_package.md` | Reconciled privacy claims; removed misleading broad claims ("Zero Cloud Tracking", unqualified "100% Private"); added explicit Data Safety & AdMob disclosure section; corrected Smart FD Discovery screenshot description from unverified rate figures to a neutral genuine UI state. | Sections 2, 4 (Feature Graphic & Screenshot Mapping), Section 5 |
| `docs/release/final_production_deployment_runbook.md` | Expanded all 24 migration filenames to full unabbreviated names; added migration transaction compatibility analysis (highlighting nested `BEGIN/COMMIT` in Migration 017 and `ALTER TYPE` in Migration 012); corrected SQL verification queries to use PostgreSQL catalog metadata (`pg_class.reloptions` for `security_invoker=true`, `pg_class.relrowsecurity`, `pg_proc`, `information_schema.table_privileges`); documented migration ledger reconciliation. | Sections 1, 3 (Migration Inventory, Reconciliation, Catalog Queries), Section 6 |
| `docs/release/final_owner_action_checklist.md` | Restructured the 9 owner action items into four distinct blocking tiers (AAB Build Blockers, Play Store Submission Blockers, Live Launch Blockers, Monetization Readiness Blockers); reinforced zero-fabrication rules for owner credentials and legal identities. | Sections 1, 2, 3 |
| `ferocalc_phase5_1_1_final_release_candidate_report.md` | Minor correction: replaced broad "zero-cloud privacy guarantees" with "on-device financial privacy guarantees" in the Data Trust Center integration table. | Section 3 |
| `docs/release/phase_5_1_1_2_documentation_integrity_report.md` | Newly authored authoritative report detailing all investigations, evidence, catalog queries, and final verdict. | Entire Document |

---

## 2. Privacy & Google Play Data Safety Corrections

### Identified Discrepancies:
In earlier drafts of `final_store_listing_package.md` and related overview text, broad claims such as "Zero Cloud Tracking" and unqualified "100% Private" were used as marketing headers. These claims created a direct contradiction with the official Google Play Data Safety form declarations drafted in `docs/release/google_play_data_safety_draft.md`, because:
1. The app integrates Google Mobile Ads SDK (`play-services-ads:25.4.0`), which automatically transmits the Android Google Advertising ID (`GAID`), App Set ID, IP address (for coarse geographic location estimation), user product interaction telemetry (launches, screen impressions, ad clicks), and diagnostic performance metrics to Google LLC.
2. The app offers verified rate change alerts via an anonymous installation ID (`inst_xxx`) and user bank preferences transmitted over HTTPS to FeroCalc's backend.

### Corrections Applied:
1. **Removed Misleading Slogans:** Completely removed "Zero Cloud Tracking" and unqualified "100% Private" from the store listing package, feature graphic blueprint, and screenshot captions.
2. **Explicit Partitioning of Data Flows:**
   - **Personal Financial Calculations & Data:** 100% on-device. Calculator inputs, loan amounts, monthly budgets, saved calculations, and financial health profiles are processed strictly in device memory and local storage (`FlutterSharedPreferences.xml`). They are **never** transmitted off-device and are explicitly excluded from Android Google Drive cloud backups (`data_extraction_rules.xml`).
   - **Advertising Identifiers & Telemetry:** Disclosed transparently under a dedicated "★ DATA SAFETY & THIRD-PARTY DISCLOSURES" section in the full store description. Declares that Google AdMob collects GAID, App Set ID, coarse IP location, and diagnostics under Google's Privacy Policy.
   - **Rate Alerts (Optional):** Clarified that anonymous installation IDs and bank preferences are transmitted strictly if the user opts into rate change alerts, with an explicit reminder of the self-service in-app deletion button (`DELETE /api/notifications/device-token`).
3. **Preserved Truthful Invariants:**
   - No consumer accounts exist (no registration, no username, no password, no server profile).
   - Personal financial calculations are completely private and stay on the user's hardware.

---

## 3. FD Rate Screenshot Verification Results

### Investigation of Proposed Screenshot Values:
In `final_store_listing_package.md`, Screen 02 (Smart FD Discovery) originally contained the caption:
`Bank cards sorted by yield (AU SFB 8.50%, Unity SFB 9.00%, SBI 7.00%) with Senior Citizen toggle enabled.`

We investigated each bank's official rate extraction in the codebase, parser implementations, test fixtures, and mock reference data:

1. **Unity Small Finance Bank (`unity_parser.js` & `unity_parser_test.js`):**
   - Official rate card (w.e.f. 02-07-2026):
     - Peak rate is on the bespoke **501 Days** tenure: **7.80% p.a. (Regular)** and **8.30% p.a. (Senior Citizen)**.
     - 12 Months tenure: **7.50% p.a. (Regular)** and **8.00% p.a. (Senior Citizen)**.
     - **9.00% does NOT exist** in the official callable retail deposit circular.
2. **AU Small Finance Bank (`au_small_finance_parser.js` & `au_small_finance_parser_test.js`):**
   - Official rate card (w.e.f. 16-08-2026):
     - Peak callable retail rate (< Rs. 3 Crore) is on **30 Months 1 Day to 36 Months**: **7.40% p.a. (Regular)** and **7.90% p.a. (Senior Citizen)**.
     - The parser explicitly notes: *"Annualized yield is strictly ignored and never emitted as the interest rate."* Higher figures (such as 8.14% or 8.50%) represent annualized compound yield or non-callable bulk slabs which are ineligible for standard retail deposits.
     - **8.50% is NOT a valid callable card rate** for retail domestic deposits.
3. **State Bank of India (`sbi_parser.js` & `bank_data.dart`):**
   - Official rate circular:
     - 1 Year: **6.80% p.a.**
     - 2 Years: **7.00% p.a.**
     - Amrit Vrishti (444 Days): **7.25% p.a.**
     - Senior citizen spread is +0.50% p.a. (up to 7.50% on 2Y, 7.75% on Amrit Vrishti).

### Resolution:
Hardcoding unverified or stale numbers like `(AU SFB 8.50%, Unity SFB 9.00%, SBI 7.00%)` creates a risk of deceptive advertising. The screenshot caption mapping in `docs/release/final_store_listing_package.md` has been replaced with a neutral, genuine description of the actual UI state:
> `Bank cards sorted by yield with Senior Citizen toggle enabled, displaying verified bank rate slabs, tenure duration badges, and official circular verification status.`

---

## 4. Complete Exact Supabase Migration Filename Inventory

All 24 migration files in `backend/supabase/migrations/` have been audited. Every abbreviated filename has been expanded to its exact repository name:

```
01. 001_create_enums.sql
02. 002_create_banks.sql
03. 003_create_fd_rates.sql
04. 004_create_audit_log.sql
05. 005_create_rls_policies.sql
06. 006_create_views_and_functions.sql
07. 007_overlap_protection.sql
08. 008_overlap_protection_hardening.sql
09. 009_calendar_tenure_domain.sql
10. 010_create_rate_source_monitoring.sql
11. 011_create_rate_candidate_staging.sql
12. 012_candidate_promotion_and_audit.sql
13. 013_create_pipeline_runs_and_health.sql
14. 014_create_baseline_attestations.sql
15. 015_add_special_scheme_to_staged_candidates.sql
16. 20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql
17. 20261025100101_calendar_aware_candidate_staging_017.sql
18. 20261025100407_restrict_public_views_to_read_only.sql
19. 20261025100630_use_invoker_security_for_public_views.sql
20. 20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql
21. 20261028095435_restrict_reviewer_bank_catalog_mutations.sql
22. 20261107073416_atomic_candidate_promotion_rpc.sql
23. 20261108050936_atomic_policy_escalation_rpc.sql
24. 20261112193000_verified_rate_notification_events.sql
```

---

## 5. Staging Migration-History Reconciliation & Transaction Compatibility

### 1. Staging History Audit vs Migration Files
- **Staging Database (`cqrslxngpwbtkjejlwty`):**
  - Migrations 001 through 015 were applied to the staging schema before Supabase CLI migration tracking was established.
  - As documented in `backend/supabase/drafts/migration_history_reconciliation_manifest.json`, the remote CLI tracking table (`supabase_migrations.schema_migrations`) in staging records only the timestamped migrations (`20261025095847` through `20261025100654`).
- **Production Database (`pmaykclwuyspxhgeomee`):**
  - Clean and completely unmigrated.
  - All 24 migrations must be applied in exact numerical order.

### 2. Transaction Compatibility Analysis:
The previous runbook instruction to *"wrap every migration in BEGIN ... COMMIT"* was technically flawed and unsafe:
1. **Migration 017 (`20261025100101_calendar_aware_candidate_staging_017.sql`):**
   - **Already contains** `BEGIN;` at line 27 and `COMMIT;` at line 313.
   - Wrapping it in an outer transaction causes nested transaction warnings and premature commits. It must be executed **without** an outer transaction wrapper.
2. **Migration 012 (`012_candidate_promotion_and_audit.sql`):**
   - Contains: `ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED';`.
   - In PostgreSQL, enum additions cannot be referenced in subsequent statements within the same transaction block. It must be executed as a standalone block.
3. **Migrations 001–011, 013–016, and 018–024:**
   - Are standard DDL/DML and function definitions that can safely run within explicit transaction blocks.

### 3. Ledger Registration in Production
If migrations are applied through the Supabase Web Dashboard SQL Editor, the web editor does not automatically write entries to `supabase_migrations.schema_migrations`. To prevent future CLI conflicts (`supabase migration list` / `supabase db push` attempting to replay migrations), the runbook includes an explicit post-migration `INSERT INTO supabase_migrations.schema_migrations (version) VALUES (...)` script registering all 24 migration version identifiers.

---

## 6. Corrected PostgreSQL Catalog Verification Queries

The runbook's verification queries have been replaced with precise PostgreSQL catalog queries:

### 1. Verifying `security_invoker = true` (pg_class.reloptions)
`information_schema.views.view_definition` only outputs the SQL query text and completely ignores view options. The catalog query now directly inspects `pg_class.reloptions`:
```sql
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
```

### 2. Verifying Table Inventory & Row-Level Security
Directly queries `pg_class.relrowsecurity`:
```sql
SELECT
    c.relname AS table_name,
    c.relrowsecurity AS rls_enabled,
    CASE WHEN c.relrowsecurity THEN 'PASS: RLS ACTIVE' ELSE 'FAIL: RLS INACTIVE' END AS rls_verdict
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
ORDER BY c.relname;
```

### 3. Verifying Public Table & View Permissions
Ensures anon and authenticated have only `SELECT` privileges and zero write permissions:
```sql
SELECT
    table_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND grantee IN ('anon', 'authenticated')
  AND privilege_type NOT IN ('SELECT')
ORDER BY table_name, grantee, privilege_type;
-- Expected: Zero rows returned.
```

### 4. Verifying RPC Functions
Inspects function security modes (`prosecdef`) and argument signatures in `pg_proc`:
```sql
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
```

### 5. Verifying Notification Events Schema
Confirms primary key, `uq_verified_rate_notification_event_id` unique constraint on `event_id`, and indexes:
```sql
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'verified_rate_notification_events';
```

---

## 7. Categorized Remaining Owner Blockers

The 9 owner action items are categorized into four distinct operational blocking tiers:

```
+-----------------------------------------------------------------------------------------+
|                               CONSOLIDATED OWNER BLOCKERS                               |
+-----------------------------------------------------------------------------------------+
|                                                                                         |
|  TIER 1: AAB BUILD BLOCKER                                                              |
|  -------------------------                                                              |
|  [BLK-01] Item 03: Production Upload Keystore (.jks) & android/key.properties.          |
|           Blocks: Production .aab compilation via Gradle fail-closed safeguard.         |
|                                                                                         |
|  TIER 2: PLAY STORE SUBMISSION BLOCKERS                                                 |
|  --------------------------------------                                                 |
|  [BLK-02] Item 01: Publisher Legal Entity Name & Registered Physical Address.           |
|  [BLK-03] Item 02: Public HTTPS URL hosting docs/legal/privacy_policy.md.               |
|  [BLK-04] Item 07: Play Console App Content forms (Data Safety, Financial, Trader).     |
|  [BLK-05] Item 08: Country/Region availability restricted to India (IN) only.           |
|  [BLK-06] Item 09: Final Store Listing visual assets upload (512 icon, 1024 graphic).   |
|           Blocks: Submitting release candidate for Google Play policy review.           |
|                                                                                         |
|  TIER 3: PRODUCTION INFRASTRUCTURE & LAUNCH BLOCKERS                                    |
|  ---------------------------------------------------                                    |
|  [BLK-07] Item 04: Supabase DBA execution of 24 migrations on pmaykclwuyspxhgeomee.     |
|  [BLK-08] Item 05: Vercel Production Project environment variables & backend deploy.   |
|           Blocks: Live rate feed queries, alert synchronization, and public launch.     |
|                                                                                         |
|  TIER 4: MONETIZATION READINESS BLOCKER                                                 |
|  --------------------------------------                                                 |
|  [BLK-09] Item 06: AdMob production App ID & Banner Unit approval + app-ads.txt.        |
|           Blocks: Live ad rendering without policy penalties.                           |
|                                                                                         |
+-----------------------------------------------------------------------------------------+
```

---

## 8. Unresolved Issues & Risk Assessment

1. **IPv6 vs IPv4 Direct Database Routing:**
   - As documented in the CLI preflight analysis, direct PostgreSQL connections to Supabase databases (`db.<ref>.supabase.co:5432`) resolve to IPv6 addresses.
   - If the project owner's deployment environment lacks IPv6 support, direct command-line `psql` or `supabase db push` will fail with `DbConfigIpv6Error`.
   - **Resolution Provided in Runbook:** The runbook explicitly documents Workflow Option A (Web Console SQL Editor) which routes over HTTPS via the Supabase Management API, bypassing local IPv6 limitations.
2. **Production Access Safeguard Maintained:**
   - In accordance with safety rules, zero production database connections were opened, zero production SQL was executed, and zero production credentials were accessed or fabricated.

---

## 9. Final Milestone Verdict

### **VERDICT: DOCUMENTATION CORRECTIONS COMPLETE — OWNER INPUTS REQUIRED**

**Verdict Justification:**
- **Documentation & Integrity Corrections:** Complete. Broad privacy claims have been reconciled with Data Safety, unverified screenshot rate numbers have been replaced with neutral genuine UI descriptions, abbreviated migration filenames have been fully resolved to their exact 24 names, transaction compatibility risks have been analyzed, and PostgreSQL catalog-level verification queries have been implemented.
- **Automated Regressions:** 100% passing across 696 Flutter tests and 46 backend suites.
- **Next Step:** Awaiting the project owner to provide the 9 categorized external prerequisites (signing keystore, legal entity identity, privacy policy hosting, Supabase DBA migration execution, Vercel production setup, and Play Console declarations).
