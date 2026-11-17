-- ==============================================================================
-- FeroCalc Phase 3C.5 — Strictly Read-Only Staging RBAC Preflight Audit Script
--
-- STATUS: QUARANTINED READ-ONLY ARTIFACT
-- LOCATION: backend/supabase/drafts/018_read_only_rbac_preflight.sql
-- TARGET STAGING PROJECT REF: cqrslxngpwbtkjejlwty (ferocalc-staging)
-- STRICTLY FORBIDDEN PRODUCTION REF: pmaykclwuyspxhgeomee (ferocalc-production)
--
-- SAFETY INVARIANTS:
-- 1. STRICTLY READ-ONLY: Contains SELECT queries ONLY.
-- 2. ZERO DDL / ZERO DML: No CREATE, ALTER, DROP, GRANT, REVOKE, INSERT, UPDATE,
--    DELETE, TRUNCATE, or migration repair statements.
-- 3. NO TRANSACTION WRAPPERS: Does NOT use BEGIN or COMMIT/ROLLBACK to wrap mutations.
-- 4. NON-MUTATING GUARANTEE: Safe to execute at any time against staging without
--    altering table rows, schema definitions, or migration history.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- CHECK 1: Target Database Identity & Connected Session Metadata
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_1_ENVIRONMENT' AS audit_check,
  current_database() AS current_database,
  current_user AS current_user,
  session_user AS session_user,
  version() AS postgres_version,
  CASE
    WHEN current_database() = 'postgres' THEN 'PASS (Standard Supabase Database Name)'
    ELSE 'UNKNOWN (Unexpected Database Name)'
  END AS status;

-- ------------------------------------------------------------------------------
-- CHECK 2: Supabase Staging Migration History Ledger State
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_2_MIGRATION_LEDGER' AS audit_check,
  version,
  name,
  inserted_at,
  CASE
    WHEN version IN ('20261025095847', '20261025100101', '20261025100407', '20261025100630', '20261025100654')
      THEN 'CONFIRMED_STAGING_MIGRATION'
    ELSE 'UNEXPECTED_OR_DRIFT_MIGRATION'
  END AS ledger_status
FROM supabase_migrations.schema_migrations
ORDER BY version ASC;

-- Summary of migration count:
SELECT
  'CHECK_2B_MIGRATION_COUNT' AS audit_check,
  count(*) AS total_recorded_migrations,
  count(*) FILTER (WHERE version IN ('20261025095847', '20261025100101', '20261025100407', '20261025100630', '20261025100654')) AS expected_staged_count,
  count(*) FILTER (WHERE version ~ '^[0-9]{3}$') AS legacy_unprefixed_count,
  CASE
    WHEN count(*) = 5 AND count(*) FILTER (WHERE version ~ '^[0-9]{3}$') = 0
      THEN 'PASS (Exactly 5 Staging Migrations; Legacy 001-015 Unrecorded)'
    ELSE 'ATTENTION_REQUIRED (Ledger Count Mismatch)'
  END AS status
FROM supabase_migrations.schema_migrations;

-- ------------------------------------------------------------------------------
-- CHECK 3: public.banks Row Level Security (RLS) Enablement & Force Setting
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_3_RLS_STATUS' AS audit_check,
  n.nspname AS schemaname,
  c.relname AS tablename,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS force_rls,
  CASE
    WHEN c.relrowsecurity = true AND c.relforcerowsecurity = false
      THEN 'PASS (RLS Enabled; Standard Supabase Non-Forced Service Role Bypass)'
    WHEN c.relrowsecurity = true AND c.relforcerowsecurity = true
      THEN 'WARNING (FORCE RLS is enabled; service_role will also be evaluated under RLS)'
    ELSE 'FAIL (RLS is disabled on public.banks!)'
  END AS status
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = 'banks';

-- ------------------------------------------------------------------------------
-- CHECK 4: Detailed Inspection of All Policies on public.banks
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_4_BANKS_POLICIES' AS audit_check,
  p.schemaname,
  p.tablename,
  p.policyname,
  p.permissive,
  p.roles,
  p.cmd,
  p.qual,
  p.with_check,
  CASE
    WHEN p.policyname = 'banks_admin_write'
      THEN 'HAZARD (Legacy Permissive ALL Policy Present - Causes REVIEWER OR-Bypass)'
    WHEN p.policyname = 'banks_public_read' AND p.cmd = 'SELECT' AND (p.qual LIKE '%true%' OR p.qual IS NULL)
      THEN 'PASS (Public Read Permissive Policy)'
    WHEN p.policyname IN ('banks_admin_insert', 'banks_admin_update', 'banks_admin_delete')
         AND (coalesce(p.qual, '') LIKE '%can_manage_bank_catalog%' OR coalesce(p.with_check, '') LIKE '%can_manage_bank_catalog%')
      THEN 'POST_MIGRATION_READY (Using Narrow Least-Privilege Predicate)'
    WHEN p.policyname IN ('banks_admin_insert', 'banks_admin_update', 'banks_admin_delete')
         AND (coalesce(p.qual, '') LIKE '%is_admin%' OR coalesce(p.with_check, '') LIKE '%is_admin%')
      THEN 'PRE_MIGRATION_CURRENT (Target for Migration 018 Remediation: Uses Over-Permissive is_admin)'
    ELSE 'UNKNOWN_POLICY_CONFIGURATION'
  END AS policy_assessment
FROM pg_policies p
WHERE p.schemaname = 'public' AND p.tablename = 'banks'
ORDER BY p.cmd, p.policyname;

-- ------------------------------------------------------------------------------
-- CHECK 5: Absence of Permissive ALL Policy (banks_admin_write)
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_5_ALL_POLICY_ABSENCE' AS audit_check,
  count(*) AS all_cmd_policy_count,
  CASE
    WHEN count(*) = 0 THEN 'PASS (No Permissive ALL Policy Found on public.banks)'
    ELSE 'FAIL (Permissive ALL Policy Found! Must Be Dropped by Migration 018)'
  END AS status
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'banks' AND cmd = 'ALL';

-- ------------------------------------------------------------------------------
-- CHECK 6: Function Metadata & Source for public.is_admin()
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_6_IS_ADMIN_METADATA' AS audit_check,
  p.proname,
  p.pronargs AS argument_count,
  pg_get_function_arguments(p.oid) AS argument_signature,
  p.prorettype::regtype AS return_type,
  p.prosecdef AS is_security_definer,
  p.provolatile AS volatility_flag,
  CASE p.provolatile
    WHEN 'i' THEN 'IMMUTABLE'
    WHEN 's' THEN 'STABLE'
    WHEN 'v' THEN 'VOLATILE'
  END AS volatility_description,
  p.proconfig AS runtime_config_settings,
  CASE
    WHEN p.prorettype = 'boolean'::regtype
         AND p.prosecdef = false
         AND p.provolatile = 's'
         AND p.pronargs = 0
         AND p.prosrc LIKE '%ADMIN%'
         AND p.prosrc LIKE '%REVIEWER%'
         AND p.prosrc LIKE '%app_metadata%'
         AND p.prosrc NOT LIKE '%user_metadata%'
      THEN 'PASS (Standard Hardened is_admin: STABLE SECURITY INVOKER, checks app_metadata)'
    ELSE 'ATTENTION (Non-Standard Function Definition for is_admin)'
  END AS function_contract_status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'is_admin';

-- ------------------------------------------------------------------------------
-- CHECK 7: Function Metadata for public.can_manage_bank_catalog()
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_7_CAN_MANAGE_BANK_CATALOG' AS audit_check,
  coalesce(p.proname, 'can_manage_bank_catalog') AS function_name,
  coalesce(p.pronargs, 0) AS argument_count,
  coalesce(p.prorettype::regtype::text, 'N/A') AS return_type,
  p.prosecdef AS is_security_definer,
  p.provolatile AS volatility_flag,
  CASE
    WHEN p.oid IS NULL THEN 'EXPECTED_PRE_MIGRATION (Function does not exist yet; will be created by Migration 018)'
    WHEN p.prorettype = 'boolean'::regtype
         AND p.prosecdef = false
         AND p.provolatile = 's'
         AND p.pronargs = 0
         AND p.prosrc LIKE '%ADMIN%'
         AND p.prosrc NOT LIKE '%REVIEWER%'
         AND p.prosrc LIKE '%app_metadata%'
         AND p.prosrc NOT LIKE '%user_metadata%'
      THEN 'POST_MIGRATION_VALIDATED (Function exists and satisfies least-privilege contract)'
    ELSE 'UNEXPECTED_STATE (Function exists but diverges from target contract)'
  END AS function_contract_status
FROM (SELECT 'can_manage_bank_catalog' AS fname) ref
LEFT JOIN pg_proc p ON p.proname = ref.fname AND p.pronamespace = 'public'::regnamespace;

-- ------------------------------------------------------------------------------
-- CHECK 8: Table-Level Grants on public.banks (Tier 1 Privileges)
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_8_TABLE_GRANTS' AS audit_check,
  grantee,
  privilege_type,
  is_grantable,
  CASE
    WHEN grantee = 'anon' AND privilege_type = 'SELECT' THEN 'EXPECTED (Public Read Allowed at Tier 1)'
    WHEN grantee = 'anon' AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE') THEN 'HAZARD (Anon Should Not Have Write Grants)'
    WHEN grantee = 'authenticated' AND privilege_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE') THEN 'STANDARD_POSTGREST (PostgREST Role Has Tier 1 Grants; RLS Enforces Tier 2 Gate)'
    WHEN grantee = 'service_role' THEN 'EXPECTED (Service Role Has Full Access)'
    ELSE 'OTHER_GRANT'
  END AS grant_assessment
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'banks'
  AND grantee IN ('anon', 'authenticated', 'service_role', 'PUBLIC')
ORDER BY grantee, privilege_type;

-- ------------------------------------------------------------------------------
-- CHECK 9: Routine Execution Privileges (has_function_privilege)
-- ------------------------------------------------------------------------------
SELECT
  'CHECK_9_ROUTINE_EXECUTE_PRIVILEGES' AS audit_check,
  'public.is_admin()' AS function_signature,
  has_function_privilege('anon', 'public.is_admin()', 'EXECUTE') AS anon_can_execute,
  has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE') AS authenticated_can_execute,
  has_function_privilege('service_role', 'public.is_admin()', 'EXECUTE') AS service_role_can_execute,
  CASE
    WHEN has_function_privilege('anon', 'public.is_admin()', 'EXECUTE')
         AND has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE')
         AND has_function_privilege('service_role', 'public.is_admin()', 'EXECUTE')
      THEN 'PASS (All Client Roles Can Evaluate Function In Policies)'
    ELSE 'FAIL (Execution Privilege Missing For One Or More Roles)'
  END AS privilege_status;

-- ------------------------------------------------------------------------------
-- CHECK 10: Consolidated Migration 018 Readiness Gate Summary
-- ------------------------------------------------------------------------------
WITH policy_counts AS (
  SELECT
    count(*) AS total_policies,
    count(*) FILTER (WHERE cmd = 'ALL') AS all_cmd_count,
    count(*) FILTER (WHERE coalesce(qual, '') LIKE '%is_admin%' OR coalesce(with_check, '') LIKE '%is_admin%') AS is_admin_policy_count,
    count(*) FILTER (WHERE coalesce(qual, '') LIKE '%can_manage_bank_catalog%' OR coalesce(with_check, '') LIKE '%can_manage_bank_catalog%') AS narrow_policy_count,
    count(*) FILTER (WHERE policyname = 'banks_public_read') AS public_read_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
),
func_checks AS (
  SELECT
    count(*) FILTER (WHERE proname = 'is_admin') AS is_admin_exists,
    count(*) FILTER (WHERE proname = 'can_manage_bank_catalog') AS narrow_func_exists
  FROM pg_proc
  WHERE pronamespace = 'public'::regnamespace
)
SELECT
  'GATE_SUMMARY' AS audit_check,
  pc.total_policies,
  pc.all_cmd_count,
  pc.is_admin_policy_count,
  pc.narrow_policy_count,
  pc.public_read_count,
  fc.is_admin_exists,
  fc.narrow_func_exists,
  CASE
    WHEN pc.all_cmd_count = 0
         AND pc.is_admin_policy_count > 0
         AND pc.narrow_policy_count = 0
         AND pc.public_read_count = 1
         AND fc.is_admin_exists = 1
         AND fc.narrow_func_exists = 0
      THEN 'STAGING_READY_FOR_REHEARSAL (Current Staging Baseline Confirmed; Migration 018 Not Yet Applied)'
    WHEN pc.all_cmd_count = 0
         AND pc.is_admin_policy_count = 0
         AND pc.narrow_policy_count = 3
         AND pc.public_read_count = 1
         AND fc.is_admin_exists = 1
         AND fc.narrow_func_exists = 1
      THEN 'MIGRATION_018_ALREADY_COMMITTED (Post-Migration Target State Active)'
    WHEN pc.all_cmd_count > 0
      THEN 'DRIFT_DETECTED (banks_admin_write ALL Policy Present - High Bypass Risk)'
    ELSE 'DRIFT_DETECTED (Catalog State Does Not Match Known Pre- or Post-Migration Baseline)'
  END AS readiness_gate_evaluation
FROM policy_counts pc, func_checks fc;
