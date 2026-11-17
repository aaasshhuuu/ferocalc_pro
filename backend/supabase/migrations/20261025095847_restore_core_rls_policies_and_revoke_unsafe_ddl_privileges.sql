
ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fd_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_audit_log ENABLE ROW LEVEL SECURITY;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

CREATE POLICY "banks_public_read" ON public.banks
  FOR SELECT USING (true);
CREATE POLICY "banks_admin_write" ON public.banks
  FOR ALL USING (public.is_admin());

CREATE POLICY "fd_rates_public_read_verified_only" ON public.fd_rates
  FOR SELECT USING (public.is_admin() OR status = 'VERIFIED');
CREATE POLICY "fd_rates_admin_insert" ON public.fd_rates
  FOR INSERT WITH CHECK (public.is_admin());
CREATE POLICY "fd_rates_admin_update" ON public.fd_rates
  FOR UPDATE USING (public.is_admin());

CREATE POLICY "audit_log_admin_read" ON public.rate_audit_log
  FOR SELECT USING (public.is_admin());
CREATE POLICY "audit_log_admin_insert" ON public.rate_audit_log
  FOR INSERT WITH CHECK (public.is_admin());

CREATE OR REPLACE VIEW public.current_user_role AS
  SELECT
    auth.uid() AS user_id,
    (auth.jwt() ->> 'email') AS email,
    (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') AS ferocalc_role;

REVOKE TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.banks, public.fd_rates, public.rate_audit_log,
            public.rate_sources, public.source_collection_logs,
            public.staged_rate_candidates, public.promotion_audit_log,
            public.rate_pipeline_runs, public.rate_pipeline_locks,
            public.baseline_source_attestations
  FROM anon, authenticated;
