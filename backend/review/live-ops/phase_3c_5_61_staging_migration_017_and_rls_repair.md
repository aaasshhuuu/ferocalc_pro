# Phase 3C.5.61 — Staging Migration 017 & Core RLS Repair Report

**Environment:** STAGING ONLY  
**Supabase project:** `cqrslxngpwbtkjejlwty` (`ferocalc-staging`, PostgreSQL 17.6)  
**Production project:** `pmaykclwuyspxhgeomee` — NOT TOUCHED  
**Repository source commit reviewed:** `1c41601895f00b647b74cae31c3095157c8bbafa`  
**Migration 017 source:** `backend/supabase/drafts/017_calendar_aware_candidate_staging.sql`  
**Migration source SHA-256 from prior verified manifest:** `c7f32eb2df125be51072af3d2520953a2532a463252eac6d5668cbb38dd54fba`

## Outcome

Migration 017 was applied to the staging project using the Supabase migration tool, after the exact committed pre-migration precheck was validated to contain 11 SELECT-only statements and all 11 were executed successfully. The committed post-migration verification file was validated to contain 10 SELECT-only statements and all 10 were executed successfully after application.

No SQL was executed against production. No bank activation, FD rate promotion, PR merge, Vercel deployment, or app release was performed.

## Pre-migration live checks

Target identity was confirmed through the Supabase project API:
- Project name: `ferocalc-staging`
- Project ref: `cqrslxngpwbtkjejlwty`
- Database version: PostgreSQL 17.6

Results of the 11 read-only prechecks:
- Required enums: 6 found.
- Baseline `staged_rate_candidates` table: present.
- Expected 11 baseline columns: present.
- Pre-existing calendar columns: 0.
- Expected legacy constraints: all 4 found.
- Legacy `idx_staged_candidates_active_identity` index: present.
- Replacement index name collisions: 0.
- Active duplicate candidate groups: 0.
- Invalid legacy day-bound rows: 0.
- Baseline counts at precheck: `rate_sources=5`, `fd_rates=1`, `staged_rate_candidates=15`.

## Applied staging changes

The Supabase migration registry now lists these operations:

| Version | Migration name | Result |
|---|---|---|
| `20261025095847` | `restore_core_rls_policies_and_revoke_unsafe_ddl_privileges` | Success |
| `20261025100101` | `calendar_aware_candidate_staging_017` | Success |
| `20261025100407` | `restrict_public_views_to_read_only` | Success |
| `20261025100630` | `use_invoker_security_for_public_views` | Success |
| `20261025100654` | `harden_admin_rls_helper_and_bank_write_policies` | Success |

### RLS and privilege changes

- RLS is enabled on `public.banks`, `public.fd_rates`, and `public.rate_audit_log`; a final catalog query found no public base table with RLS disabled.
- Banks are publicly readable; insert/update/delete require the `is_admin()` policy check.
- Public `fd_rates` reads are restricted by policy to VERIFIED records (admins/reviewers follow the existing claim check); inserts and updates are gated by the admin check. No DELETE policy was added.
- Audit logs are admin-readable and admin-insertable; no UPDATE/DELETE policy was added.
- `is_admin()` was changed to SECURITY INVOKER and retains a fixed `search_path`.
- Public views `verified_fd_rates` and `current_user_role` were changed to `security_invoker=true`.
- `anon` and `authenticated` have only SELECT grants on these two public views.
- `anon` and `authenticated` no longer have TRUNCATE, REFERENCES, or TRIGGER table privileges on the listed public base tables.

### Migration 017 post-verification

All 10 post-migration SELECT checks executed:
- 9 calendar tenure columns present with expected types/defaults.
- `min_tenure_days` and `max_tenure_days` are nullable.
- Legacy day-only constraints absent.
- All 12 domain constraints present.
- Legacy index absent.
- Both replacement unique partial indexes present with expected domain predicates and NULLS NOT DISTINCT semantics.
- DAYS duplicate groups: 0.
- CALENDAR duplicate groups: 0.
- Domain-integrity violations: 0.

Final data-preservation check:
- `staged_rate_candidates`: 15 total rows, all 15 `DAYS`, 0 `CALENDAR`, 0 rows with NULL day bounds.
- `fd_rates`: 1 row, status `DRAFT`.
- `verified_fd_rates`: 0 rows, as no rate is currently VERIFIED.

## Important remaining risks / limitations

1. **Legacy migration history is still incomplete.** Initially, the Supabase migration-history schema/table did not exist and the migration listing was empty. The tool now records the five operations above, but this does not reconstruct the historical application records for repository migrations 001–015. Do not run an automatic `supabase db push` or assume historical migration parity until that ledger is reconciled from evidence. No fake historical entries were inserted.
2. **No full database backup was created or verified by the available tooling during this operation.** The migration’s in-transaction checks passed, and the candidate row count/data domain were verified afterward, but this is not a substitute for a full managed backup.
3. **No application-level anon/authenticated end-to-end request test was run.** Verification covered database catalogs, policies, grants, index definitions and row counts.
4. Supabase security advisors still report informational `RLS enabled, no policy` findings for seven internal tables: `baseline_source_attestations`, `promotion_audit_log`, `rate_pipeline_locks`, `rate_pipeline_runs`, `rate_sources`, `source_collection_logs`, and `staged_rate_candidates`. These remain unavailable through ordinary RLS-protected client access and should be verified against service-role-only backend usage.
5. Remaining security warnings include four functions with mutable search paths (`update_updated_at_column`, `_boundary_op_text`, `_cal_tuple_cmp`, `_calendar_ranges_overlap`) and disabled leaked-password protection in Supabase Auth. They were not altered in this operation.
6. Performance advisors reported unindexed foreign keys and unused indexes; no indexes were deleted.

## Scope statement

This report records actual tool-executed operations against the staging project. It does not claim production readiness, consumer rate availability, all migration-history parity, or an app release. The superseded Migration 016 remains a draft; Migration 017 remains in the repository's draft folder even though its SQL was applied to staging through the migration tool. Repository migration-source/ledger alignment remains a follow-up before automated migration workflows are used.
