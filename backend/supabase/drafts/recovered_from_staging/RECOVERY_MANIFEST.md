# Staging Migration Recovery Manifest

**Manifest Generation Date:** 2026-10-26
**Target Staging Project:** `cqrslxngpwbtkjejlwty` (`ferocalc-staging`)
**Prohibited Production Project:** `pmaykclwuyspxhgeomee`
**Git Checkpoint:** Branch `sync/latest-local-changes-2026-10-23` @ HEAD `1c41601895f00b647b74cae31c3095157c8bbafa`
**Export Reference Report:** `C:\projects\fincalc_pro\ferocalc_phase_3c_7_1_remote_sql_export_review_only.txt`
**Storage Location:** `backend/supabase/drafts/recovered_from_staging/`

---

## 1. Provenance and Integrity Manifest

| Staging Version | Migration Name | Source of Statement | Expected Remote Bytes | Actual Local Bytes | Expected Remote SHA-256 | Actual Local SHA-256 | Match Status | Authorization Status | Backup Evidence Status | Execution Status |
|:---|:---|:---|:---:|:---:|:---|:---|:---:|:---:|:---:|:---|
| `20261025095847` | `restore_core_rls_policies_and_revoke_unsafe_ddl_privileges` | Staging `schema_migrations` export | 1,825 | 1,825 | `2d91b3aebdcbc45e8dbeee4268a88bbf13db24511ee4870dfd70d5918c982cfa` | `2d91b3aebdcbc45e8dbeee4268a88bbf13db24511ee4870dfd70d5918c982cfa` | **EXACT MATCH** | **NOT VERIFIED** | **NOT VERIFIED** | **ALREADY RECORDED IN STAGING — DO NOT REPLAY** |
| `20261025100101` | `calendar_aware_candidate_staging_017` | Staging `schema_migrations` export / local draft `017` | 12,008 | 12,008 | `c7f32eb2df125be51072af3d2520953a2532a463252eac6d5668cbb38dd54fba` | `c7f32eb2df125be51072af3d2520953a2532a463252eac6d5668cbb38dd54fba` | **EXACT MATCH** | **NOT VERIFIED** | **NOT VERIFIED** | **ALREADY RECORDED IN STAGING — DO NOT REPLAY** |
| `20261025100407` | `restrict_public_views_to_read_only` | Staging `schema_migrations` export | 152 | 152 | `89aad7b5a3f7b8b339dec5101930773b4500e4f3f4399741edc90db9604f71fd` | `89aad7b5a3f7b8b339dec5101930773b4500e4f3f4399741edc90db9604f71fd` | **EXACT MATCH** | **NOT VERIFIED** | **NOT VERIFIED** | **ALREADY RECORDED IN STAGING — DO NOT REPLAY** |
| `20261025100630` | `use_invoker_security_for_public_views` | Staging `schema_migrations` export | 135 | 135 | `01255614edb567107299abedb8aba1b302b6014a452ff7df1cb2c61ce2ee6d4f` | `01255614edb567107299abedb8aba1b302b6014a452ff7df1cb2c61ce2ee6d4f` | **EXACT MATCH** | **NOT VERIFIED** | **NOT VERIFIED** | **ALREADY RECORDED IN STAGING — DO NOT REPLAY** |
| `20261025100654` | `harden_admin_rls_helper_and_bank_write_policies` | Staging `schema_migrations` export | 741 | 741 | `b63a07b5935463c3a750e206703481b6fcdfb46e3f6b97a443cd54ab85be19f2` | `b63a07b5935463c3a750e206703481b6fcdfb46e3f6b97a443cd54ab85be19f2` | **EXACT MATCH** | **NOT VERIFIED** | **NOT VERIFIED** | **ALREADY RECORDED IN STAGING — DO NOT REPLAY** |

---

## 2. File Verification & Encoding Standards

- **File Encoding:** UTF-8 without Byte Order Mark (BOM).
- **Line Endings:** POSIX standard LF (`\n`).
- **Statement Integrity:** Exact original leading and trailing newlines from the remote database stored statements were verified and preserved.
- **Migration 017 Handling:** Version `20261025100101` was verified against [`backend/supabase/drafts/017_calendar_aware_candidate_staging.sql`](file:///C:/projects/fincalc_pro/backend/supabase/drafts/017_calendar_aware_candidate_staging.sql). Its SHA-256 (`c7f32eb2df125be51072af3d2520953a2532a463252eac6d5668cbb38dd54fba`) is identical, so no redundant duplicate copy was created.
- **Zero Mismatch Count:** Exactly `0` exact-match failures detected across all five migration definitions.

---

## 3. Outstanding Security Review Flag (Task 6)

- **Subject:** Role evaluation in `public.is_admin()` and write permissions on `public.banks`.
- **Finding:** Migration `20261025100654` sets helper function `public.is_admin()` to return `true` if `(auth.jwt() -> 'app_metadata' ->> 'ferocalc_role')` is either `'ADMIN'` OR `'REVIEWER'`.
- **Downstream Exposure:** The `banks` table policies (`banks_admin_insert`, `banks_admin_update`, `banks_admin_delete`) use `public.is_admin()`. Consequently, users with the `REVIEWER` role in `app_metadata` currently possess table-level insert, update, and delete capabilities on `banks`.
- **Status:** **BLOCKED PENDING PRODUCT / SECURITY OWNER DECISION.** Requires formal confirmation from the product/security owner whether reviewer-level write access to bank entities is intentional or must be restricted exclusively to `ADMIN` and `service_role`.

---

## 4. Operational Guardrails

1. **Quarantine Enforcement:** Under no circumstances should these files be promoted to `backend/supabase/migrations/` or executed via automated runners.
2. **Reconciliation Dependency:** Full schema reconciliation requires:
   - Approved operator / DBA authorization packet.
   - Verified staging backup attestation.
   - Resolution of the `public.is_admin()` role-permission scope.
   - Non-destructive migration repair plan that does not re-execute already-applied statements against staging.
