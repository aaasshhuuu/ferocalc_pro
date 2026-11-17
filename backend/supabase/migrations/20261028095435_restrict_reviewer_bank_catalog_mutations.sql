
CREATE OR REPLACE FUNCTION public.can_manage_bank_catalog()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, auth
AS $function$
BEGIN
  RETURN COALESCE(
    auth.jwt() ->> 'role' = 'service_role'
    OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN',
    false
  );
END;
$function$;

COMMENT ON FUNCTION public.can_manage_bank_catalog() IS
  'Evaluates true strictly for service_role or users with ferocalc_role = ADMIN. Excludes REVIEWER role to protect master bank catalog integrity.';

REVOKE EXECUTE ON FUNCTION public.can_manage_bank_catalog() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_manage_bank_catalog() TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "banks_admin_write" ON public.banks;

DROP POLICY IF EXISTS "banks_admin_insert" ON public.banks;
CREATE POLICY "banks_admin_insert" ON public.banks
  FOR INSERT WITH CHECK (public.can_manage_bank_catalog());

DROP POLICY IF EXISTS "banks_admin_update" ON public.banks;
CREATE POLICY "banks_admin_update" ON public.banks
  FOR UPDATE USING (public.can_manage_bank_catalog())
  WITH CHECK (public.can_manage_bank_catalog());

DROP POLICY IF EXISTS "banks_admin_delete" ON public.banks;
CREATE POLICY "banks_admin_delete" ON public.banks
  FOR DELETE USING (public.can_manage_bank_catalog());

DO $assertions$
DECLARE
  v_policy_count integer;
  v_permissive_count integer;
  v_all_cmd_count integer;
  v_is_admin_ref_count integer;
  v_public_role_scope_count integer;
  v_insert_check text;
  v_update_using text;
  v_update_check text;
  v_delete_using text;
  v_read_using text;
  v_func_oid oid;
  v_func_args integer;
  v_func_rettype regtype;
  v_func_secdef boolean;
  v_func_volatile "char";
  v_func_src text;
  v_func_config text[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'banks' AND c.relrowsecurity
  ) THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: RLS is not enabled on public.banks';
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks';
  IF v_policy_count <> 4 THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: expected exactly 4 policies, found %', v_policy_count;
  END IF;

  SELECT count(*) INTO v_permissive_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND permissive = 'PERMISSIVE';
  IF v_permissive_count <> 4 THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: expected 4 permissive policies, found %', v_permissive_count;
  END IF;

  SELECT count(*) INTO v_all_cmd_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks' AND cmd = 'ALL';
  IF v_all_cmd_count <> 0 THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: unexpected ALL policy found';
  END IF;

  SELECT count(*) INTO v_is_admin_ref_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND (COALESCE(qual, '') ILIKE '%is_admin%' OR COALESCE(with_check, '') ILIKE '%is_admin%');
  IF v_is_admin_ref_count <> 0 THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: bank policy still references is_admin()';
  END IF;

  SELECT count(*) INTO v_public_role_scope_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND roles = ARRAY['public']::name[];
  IF v_public_role_scope_count <> 4 THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: expected roles={public} on all four policies, found %', v_public_role_scope_count;
  END IF;

  SELECT with_check INTO v_insert_check
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND policyname = 'banks_admin_insert' AND cmd = 'INSERT';
  IF v_insert_check IS NULL OR v_insert_check NOT LIKE '%can_manage_bank_catalog%' THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: banks_admin_insert predicate mismatch';
  END IF;

  SELECT qual, with_check INTO v_update_using, v_update_check
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND policyname = 'banks_admin_update' AND cmd = 'UPDATE';
  IF v_update_using IS NULL OR v_update_check IS NULL
     OR v_update_using NOT LIKE '%can_manage_bank_catalog%'
     OR v_update_check NOT LIKE '%can_manage_bank_catalog%' THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: banks_admin_update predicate mismatch';
  END IF;

  SELECT qual INTO v_delete_using
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND policyname = 'banks_admin_delete' AND cmd = 'DELETE';
  IF v_delete_using IS NULL OR v_delete_using NOT LIKE '%can_manage_bank_catalog%' THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: banks_admin_delete predicate mismatch';
  END IF;

  SELECT qual INTO v_read_using
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'banks'
    AND policyname = 'banks_public_read' AND cmd = 'SELECT';
  IF v_read_using IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: banks_public_read is not exactly USING (true)';
  END IF;

  SELECT p.oid, p.pronargs, p.prorettype, p.prosecdef, p.provolatile, p.prosrc, p.proconfig
  INTO v_func_oid, v_func_args, v_func_rettype, v_func_secdef, v_func_volatile, v_func_src, v_func_config
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'can_manage_bank_catalog'
    AND p.pronargs = 0
    AND p.proargtypes = ''::oidvector;

  IF v_func_oid IS NULL THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: exact zero-argument function not found';
  END IF;
  IF v_func_rettype <> 'boolean'::regtype THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: helper return type is not boolean';
  END IF;
  IF v_func_secdef IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: helper must be SECURITY INVOKER';
  END IF;
  IF v_func_volatile <> 's' THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: helper must be STABLE';
  END IF;
  IF NOT ('search_path=public, auth' = ANY(COALESCE(v_func_config, ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: helper search_path is not fixed to public, auth';
  END IF;
  IF v_func_src NOT LIKE '%ADMIN%' OR v_func_src LIKE '%REVIEWER%' THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: helper body must allow ADMIN and not contain REVIEWER';
  END IF;
  IF NOT has_function_privilege('anon', v_func_oid, 'EXECUTE')
     OR NOT has_function_privilege('authenticated', v_func_oid, 'EXECUTE')
     OR NOT has_function_privilege('service_role', v_func_oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'Migration 018 assertion failed: helper EXECUTE grants are incomplete';
  END IF;
END;
$assertions$;
