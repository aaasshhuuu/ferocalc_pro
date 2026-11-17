# Quarantined Migration Statements (Recovered from Staging)

> **CRITICAL GUARDRAIL — REVIEW AND PROVENANCE ONLY**
> **DO NOT EXECUTE, DO NOT REPLAY, AND DO NOT PROMOTE TO EXECUTABLE MIGRATIONS.**

---

## 1. Provenance and Status

The SQL migration files in this directory (`backend/supabase/drafts/recovered_from_staging/`) were recovered from the live Supabase staging database (`cqrslxngpwbtkjejlwty`) migration-history records via the operator export report `ferocalc_phase_3c_7_1_remote_sql_export_review_only.txt`.

- **Source:** Remote Supabase staging migration history (`supabase_migrations.schema_migrations` statements).
- **Execution Status in Staging:** **ALREADY RECORDED AS APPLIED IN STAGING.**
- **Execution Approval:** **NOT APPROVED FOR EXECUTION.**
- **Authorization Status:** **NOT VERIFIED** (No signed DBA packet, change ticket, or approved execution window exists in repository source).
- **Backup Verification Status:** **NOT VERIFIED** (No pre-execution snapshot reference is cataloged).

---

## 2. Mandatory Quarantine Rules

1. **Never Apply Automatically:**
   Files in this directory must **never** be executed or applied automatically by CI/CD pipelines, automated deployment scripts, migration runners, or `supabase db push`.
2. **Do Not Replay:**
   Because the staging database already records these migration versions (`20261025095847`, `20261025100407`, `20261025100630`, `20261025100654`), these statements must **never** be replayed against staging merely to recreate migration history or synchronize schemas.
3. **Quarantine Isolation:**
   These files must **not** be moved or copied into the executable migrations directory (`backend/supabase/migrations/`) until a formal, separately reviewed migration-history reconciliation plan is drafted, audited, and approved by an authorized DBA and product owner.
4. **Strict Production Isolation:**
   These statements must **never** be run against production project `pmaykclwuyspxhgeomee`.

---

## 3. Catalog of Recovered Statements

| Version | Quarantined SQL Filename | Stored Chars / Bytes | SHA-256 Digest | Match Status |
|:---|:---|:---:|:---|:---:|
| `20261025095847` | [`20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql`](file:///C:/projects/fincalc_pro/backend/supabase/drafts/recovered_from_staging/20261025095847_restore_core_rls_policies_and_revoke_unsafe_ddl_privileges.sql) | 1,825 | `2d91b3aebdcbc45e8dbeee4268a88bbf13db24511ee4870dfd70d5918c982cfa` | **EXACT MATCH** |
| `20261025100101` | [`017_calendar_aware_candidate_staging.sql`](file:///C:/projects/fincalc_pro/backend/supabase/drafts/017_calendar_aware_candidate_staging.sql) *(in `drafts/` root; not duplicated here)* | 12,008 | `c7f32eb2df125be51072af3d2520953a2532a463252eac6d5668cbb38dd54fba` | **EXACT MATCH** |
| `20261025100407` | [`20261025100407_restrict_public_views_to_read_only.sql`](file:///C:/projects/fincalc_pro/backend/supabase/drafts/recovered_from_staging/20261025100407_restrict_public_views_to_read_only.sql) | 152 | `89aad7b5a3f7b8b339dec5101930773b4500e4f3f4399741edc90db9604f71fd` | **EXACT MATCH** |
| `20261025100630` | [`20261025100630_use_invoker_security_for_public_views.sql`](file:///C:/projects/fincalc_pro/backend/supabase/drafts/recovered_from_staging/20261025100630_use_invoker_security_for_public_views.sql) | 135 | `01255614edb567107299abedb8aba1b302b6014a452ff7df1cb2c61ce2ee6d4f` | **EXACT MATCH** |
| `20261025100654` | [`20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql`](file:///C:/projects/fincalc_pro/backend/supabase/drafts/recovered_from_staging/20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql) | 741 | `b63a07b5935463c3a750e206703481b6fcdfb46e3f6b97a443cd54ab85be19f2` | **EXACT MATCH** |

*Note: Per Phase 3C.7.2 directives, Migration 017 (`20261025100101`) was verified to match `backend/supabase/drafts/017_calendar_aware_candidate_staging.sql` exactly and is retained in `drafts/` without creating a duplicate file.*

---

## 4. Outstanding Security Review Flag (Task 6)

> [!WARNING]
> **Privilege Escalation Review Required: `public.is_admin()` Permissions**
> In migration `20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql`, the definition of helper function `public.is_admin()` evaluates:
> ```sql
> RETURN COALESCE(
>   auth.jwt() ->> 'role' = 'service_role'
>   OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN'
>   OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'REVIEWER',
>   false
> );
> ```
> This function treats users with the `REVIEWER` role in `app_metadata` identically to `ADMIN`.
> Because the `banks` table write policies (`banks_admin_insert`, `banks_admin_update`, `banks_admin_delete`) call `public.is_admin()`, users with `REVIEWER` credentials currently inherit write permissions (`INSERT`, `UPDATE`, `DELETE`) on the `banks` table.
>
> **Action Required:** Product and security owners must review whether reviewers should have write access to bank metadata, or whether `banks` write operations must be restricted strictly to `ADMIN` and `service_role`. No behavioral changes are made in this preservation task.
