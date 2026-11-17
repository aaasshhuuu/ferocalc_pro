-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 018: Least-Privilege Bank Catalog Mutation Restriction
--
-- STATUS: DRAFT / NOT EXECUTED / QUARANTINED
-- QUARANTINED under backend/supabase/drafts/
-- DO NOT MOVE TO backend/supabase/migrations/ WITHOUT EXPLICIT OPERATOR AUTHORIZATION.
-- DO NOT EXECUTE AGAINST STAGING OR PRODUCTION WITHOUT EXPLICIT DBA AND SECURITY OWNER SIGN-OFF.
--
-- Target Staging Reference: cqrslxngpwbtkjejlwty (ferocalc-staging)
-- Strictly Forbidden Production: pmaykclwuyspxhgeomee (ferocalc-production)
--
-- Context & Problem Statement:
-- In staging migration 20261025100654_harden_admin_rls_helper_and_bank_write_policies.sql,
-- public.is_admin() was defined as:
--   RETURN COALESCE(
--     auth.jwt() ->> 'role' = 'service_role'
--     OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN'
--     OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'REVIEWER',
--     false
--   );
-- And public.banks DML write policies (banks_admin_insert, banks_admin_update, banks_admin_delete)
-- were previously configured to evaluate public.is_admin().
--
-- This configuration violates the Principle of Least Privilege: users with ferocalc_role = 'REVIEWER'
-- inherit full write privileges (INSERT, UPDATE, DELETE) on the master public.banks catalog
-- via direct PostgREST calls.
--
-- Architectural Remediation Decision:
-- DO NOT modify public.is_admin() globally.
-- Modifying public.is_admin() to exclude REVIEWER would break:
--   1. fd_rates_public_read_verified_only (REVIEWER needs to read unverified drafts & candidates)
--   2. audit_log_admin_read (REVIEWER needs read access to rate audit history)
--   3. transition_rate_status / supersede_active_rate stored functions (which check is_admin())
--
-- Instead, introduce a dedicated, narrow least-privilege predicate:
--   public.can_manage_bank_catalog()
-- which permits only 'service_role' and ferocalc_role = 'ADMIN'.
-- The bank catalog write policies are updated to use this narrow predicate,
-- cleanly isolating master bank catalog administration from rate-candidate review.
--
-- Rollback / Backout Strategy & Safeguards:
--
-- 1. Pre-COMMIT Abort (Automatic Transactional Rollback):
--    Migration 018 executes entirely inside a single BEGIN ... COMMIT block.
--    If any error occurs during execution, or if any of the Step 3 catalog assertions fail,
--    PostgreSQL automatically rolls back the entire transaction. No partial schema
--    mutations occur, and no manual cleanup is required.
--
-- 2. Post-COMMIT Backout Policy:
--    PROHIBITION ON BLIND ROLLBACK TO VULNERABLE PRIOR STATE:
--    Under NO circumstances should an operator execute a rollback script that restores
--    mutation policies using public.is_admin() or recreates banks_admin_write.
--    Because public.is_admin() includes ferocalc_role = 'REVIEWER', restoring those
--    policies reintroduces the very write-access vulnerability this migration eliminates.
--
--    FORWARD-FIX REQUIREMENT:
--    If an issue arises after Migration 018 has committed, a forward fix preserving
--    least privilege must be authored, reviewed, and approved by the DBA and Security Owner.
--
--    EMERGENCY FAIL-CLOSED MUTATION LOCKOUT (If Forward Fix is Pending):
--    If bank catalog writes must be immediately halted post-commit while preserving public
--    read access, the fail-closed emergency remediation MUST use RESTRICTIVE policies.
--    In PostgreSQL RLS, permissive policies combine with boolean OR (so a permissive policy
--    returning false does NOT override another permissive policy returning true).
--    Using AS RESTRICTIVE forces boolean AND evaluation ((permissive) AND false = false),
--    guaranteeing that NO permissive policy can bypass the lockout:
--      BEGIN;
--      DROP POLICY IF EXISTS "banks_admin_write" ON public.banks;
--      DROP POLICY IF EXISTS "banks_admin_insert" ON public.banks;
--      DROP POLICY IF EXISTS "banks_admin_update" ON public.banks;
--      DROP POLICY IF EXISTS "banks_admin_delete" ON public.banks;
--      CREATE POLICY "banks_emergency_lockout_insert" ON public.banks AS RESTRICTIVE FOR INSERT WITH CHECK (false);
--      CREATE POLICY "banks_emergency_lockout_update" ON public.banks AS RESTRICTIVE FOR UPDATE USING (false) WITH CHECK (false);
--      CREATE POLICY "banks_emergency_lockout_delete" ON public.banks AS RESTRICTIVE FOR DELETE USING (false);
--      COMMIT;
--    This locks out all bank catalog writes completely and unconditionally without restoring insecure policies.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- STEP 1: DEFINE NARROW BANK CATALOG MANAGEMENT PREDICATE
-- ------------------------------------------------------------
-- Evaluates TRUE only for service_role or users with ferocalc_role = 'ADMIN'.
-- Strictly denies ferocalc_role = 'REVIEWER', anonymous callers, and standard users.
-- Uses SECURITY INVOKER and explicit search_path to prevent search_path poisoning.
CREATE OR REPLACE FUNCTION public.can_manage_bank_catalog()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN COALESCE(
    auth.jwt() ->> 'role' = 'service_role'
    OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN',
    false
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = public, auth;

COMMENT ON FUNCTION public.can_manage_bank_catalog() IS
  'Evaluates true strictly for service_role or users with ferocalc_role = ADMIN. Excludes REVIEWER role to protect master bank catalog integrity.';

-- Revoke default public execution and grant explicitly to client roles for clean RLS evaluation
REVOKE EXECUTE ON FUNCTION public.can_manage_bank_catalog() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_bank_catalog() TO anon, authenticated, service_role;

-- ------------------------------------------------------------
-- STEP 2: DROP OBSOLETE & BYPASS-PRONE POLICIES AND RECREATE TARGET POLICIES
-- ------------------------------------------------------------
-- Explicitly drop legacy ALL policy banks_admin_write if present
-- (ensures no permissive OR-bypass persists across migration drift states)
DROP POLICY IF EXISTS "banks_admin_write" ON public.banks;

-- Replace banks_admin_insert with narrow predicate
DROP POLICY IF EXISTS "banks_admin_insert" ON public.banks;
CREATE POLICY "banks_admin_insert" ON public.banks
  FOR INSERT WITH CHECK (public.can_manage_bank_catalog());

-- Replace banks_admin_update with narrow predicate
DROP POLICY IF EXISTS "banks_admin_update" ON public.banks;
CREATE POLICY "banks_admin_update" ON public.banks
  FOR UPDATE USING (public.can_manage_bank_catalog()) WITH CHECK (public.can_manage_bank_catalog());

-- Replace banks_admin_delete with narrow predicate
DROP POLICY IF EXISTS "banks_admin_delete" ON public.banks;
CREATE POLICY "banks_admin_delete" ON public.banks
  FOR DELETE USING (public.can_manage_bank_catalog());

-- ------------------------------------------------------------
-- STEP 3: PRESERVE READ POLICY & RUN COMPREHENSIVE CATALOG ASSERTIONS
-- ------------------------------------------------------------
-- Note: banks_public_read (FOR SELECT USING (true)) remains untouched.
-- Verify catalog state fail-closed: aborts entire transaction if any assertion fails.
DO $$
DECLARE
  v_policy_count        integer;
  v_permissive_count    integer;
  v_roles_public_count  integer;
  v_all_cmd_count       integer;
  v_is_admin_ref_count  integer;
  v_insert_check        text;
  v_update_using        text;
  v_update_check        text;
  v_delete_using        text;
  v_read_using          text;
  v_func_nargs          integer;
  v_func_rettype        regtype;
  v_func_secdef         boolean;
  v_func_volatile       char;
  v_func_src            text;
BEGIN
  -- Assertion 1: Total policy count on public.banks must be EXACTLY 4
  -- (1 SELECT, 1 INSERT, 1 UPDATE, 1 DELETE).
  -- Any lingering, duplicate, or unexpected permissive policy will fail closed!
  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks';

  IF v_policy_count != 4 THEN
    RAISE EXCEPTION 'Catalog verification failed: expected exactly 4 policies on public.banks, found %', v_policy_count;
  END IF;

  -- Assertion 2: All 4 policies must be PERMISSIVE
  SELECT count(*) INTO v_permissive_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND permissive = 'PERMISSIVE';

  IF v_permissive_count != 4 THEN
    RAISE EXCEPTION 'Catalog verification failed: expected all 4 policies on public.banks to be PERMISSIVE, found %', v_permissive_count;
  END IF;

  -- Assertion 2B: All 4 policies must have role scope '{public}' (default for all roles)
  SELECT count(*) INTO v_roles_public_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND roles = '{public}';

  IF v_roles_public_count != 4 THEN
    RAISE EXCEPTION 'Catalog verification failed: expected all 4 policies on public.banks to have roles = {public}, found %', v_roles_public_count;
  END IF;

  -- Assertion 3: No policy with cmd = 'ALL' may exist on public.banks
  SELECT count(*) INTO v_all_cmd_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND cmd = 'ALL';

  IF v_all_cmd_count > 0 THEN
    RAISE EXCEPTION 'Catalog verification failed: permissive ALL policy found on public.banks';
  END IF;

  -- Assertion 4: No policy on public.banks may reference public.is_admin()
  SELECT count(*) INTO v_is_admin_ref_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND (coalesce(qual, '') LIKE '%is_admin%' OR coalesce(with_check, '') LIKE '%is_admin%');

  IF v_is_admin_ref_count > 0 THEN
    RAISE EXCEPTION 'Catalog verification failed: public.banks still contains policies referencing is_admin()';
  END IF;

  -- Assertion 5: Verify exact commands and predicates for all 4 expected policies
  SELECT with_check INTO v_insert_check
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND policyname = 'banks_admin_insert' AND cmd = 'INSERT';

  IF v_insert_check IS NULL OR v_insert_check NOT LIKE '%can_manage_bank_catalog%' THEN
    RAISE EXCEPTION 'Catalog verification failed: banks_admin_insert is missing or does not invoke can_manage_bank_catalog()';
  END IF;

  SELECT qual, with_check INTO v_update_using, v_update_check
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND policyname = 'banks_admin_update' AND cmd = 'UPDATE';

  IF v_update_using IS NULL OR v_update_check IS NULL
     OR v_update_using NOT LIKE '%can_manage_bank_catalog%'
     OR v_update_check NOT LIKE '%can_manage_bank_catalog%' THEN
    RAISE EXCEPTION 'Catalog verification failed: banks_admin_update is missing or does not invoke can_manage_bank_catalog() in USING and WITH CHECK';
  END IF;

  SELECT qual INTO v_delete_using
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND policyname = 'banks_admin_delete' AND cmd = 'DELETE';

  IF v_delete_using IS NULL OR v_delete_using NOT LIKE '%can_manage_bank_catalog%' THEN
    RAISE EXCEPTION 'Catalog verification failed: banks_admin_delete is missing or does not invoke can_manage_bank_catalog()';
  END IF;

  SELECT qual INTO v_read_using
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND policyname = 'banks_public_read' AND cmd = 'SELECT';

  IF v_read_using IS NULL OR v_read_using NOT LIKE '%true%' THEN
    RAISE EXCEPTION 'Catalog verification failed: banks_public_read is missing or does not allow public SELECT';
  END IF;

  -- Assertion 6: Verify function public.can_manage_bank_catalog() signature, zero arguments, security invoker, and body
  SELECT pronargs, prorettype, prosecdef, provolatile, prosrc
  INTO v_func_nargs, v_func_rettype, v_func_secdef, v_func_volatile, v_func_src
  FROM pg_proc
  WHERE proname = 'can_manage_bank_catalog'
    AND pronamespace = 'public'::regnamespace
    AND pronargs = 0;

  IF v_func_rettype IS NULL THEN
    RAISE EXCEPTION 'Catalog verification failed: function public.can_manage_bank_catalog() not found in pg_proc';
  END IF;

  IF v_func_nargs != 0 THEN
    RAISE EXCEPTION 'Catalog verification failed: function must have exactly 0 arguments (pronargs=0)';
  END IF;

  IF v_func_rettype != 'boolean'::regtype THEN
    RAISE EXCEPTION 'Catalog verification failed: function return type is not boolean';
  END IF;

  IF v_func_secdef IS NOT FALSE THEN
    RAISE EXCEPTION 'Catalog verification failed: function must be SECURITY INVOKER (prosecdef=false)';
  END IF;

  IF v_func_volatile != 's' THEN
    RAISE EXCEPTION 'Catalog verification failed: function volatility must be STABLE (provolatile=''s'')';
  END IF;

  IF v_func_src NOT LIKE '%ADMIN%' OR v_func_src LIKE '%REVIEWER%' THEN
    RAISE EXCEPTION 'Catalog verification failed: function body in pg_proc must include ADMIN and exclude REVIEWER';
  END IF;
END $$;

COMMIT;
