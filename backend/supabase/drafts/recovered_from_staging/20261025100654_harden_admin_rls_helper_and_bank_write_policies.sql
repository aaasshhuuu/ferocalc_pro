
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN COALESCE(
    auth.jwt() ->> 'role' = 'service_role'
    OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN'
    OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'REVIEWER',
    false
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = public, auth;

DROP POLICY IF EXISTS "banks_admin_write" ON public.banks;
CREATE POLICY "banks_admin_insert" ON public.banks
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "banks_admin_update" ON public.banks
  FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());
CREATE POLICY "banks_admin_delete" ON public.banks
  FOR DELETE USING (public.is_admin());
