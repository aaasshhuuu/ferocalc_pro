-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 018: Least-Privilege Bank Catalog Mutation Restriction
-- REHEARSAL-ONLY TRANSACTION-SAFE ARTIFACT (ROLLBACK ON COMPLETION)
--
-- STATUS: REHEARSAL ONLY / NOT A PRODUCTION MIGRATION / QUARANTINED
-- QUARANTINED under backend/supabase/drafts/
--
-- CRITICAL OPERATIONAL WARNINGS:
-- 1. CONTROLLED DBA REHEARSAL ONLY:
--    This script is strictly intended for controlled, manual DBA dry-run rehearsal
--    against a staging database.
-- 2. NOT EXECUTABLE IN CI/CD OR AUTOMATION:
--    This file MUST NEVER be executed by automated deployment pipelines, CI/CD runners,
--    or "supabase db push".
-- 3. PROHIBITION ON PRODUCTION PROMOTION:
--    This file MUST NEVER be promoted to backend/supabase/migrations/ or executed
--    against production.
-- 4. NON-MUTATING ROLLBACK GUARANTEE:
--    This script executes the exact Migration 018 DDL statements and runtime catalog
--    assertions inside an outer transaction ending with an unconditional ROLLBACK;.
--    PostgreSQL rolls back all schema modifications at the conclusion of the rehearsal.
--    Zero rows or schema changes persist.
-- 5. SINGLE OUTER TRANSACTION (NO NESTED TRANSACTIONS):
--    The top-level BEGIN; and COMMIT; from the original migration draft have been
--    replaced by this outer BEGIN; ... ROLLBACK; block to avoid nested transaction
--    warnings or unintended intermediate commits in PostgreSQL.
--
-- Target Staging Reference: cqrslxngpwbtkjejlwty (ferocalc-staging)
-- Strictly Forbidden Production: pmaykclwuyspxhgeomee (ferocalc-production)
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

ROLLBACK;
