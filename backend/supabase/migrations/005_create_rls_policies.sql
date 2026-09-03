-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 005: Row Level Security (RLS) Policies
-- Supabase Auth integration
-- ============================================================

-- ============================================================
-- Enable RLS on all tables
-- ============================================================

ALTER TABLE banks          ENABLE ROW LEVEL SECURITY;
ALTER TABLE fd_rates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_audit_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Helper: admin check
-- Admin is identified by the 'role' key in the JWT's app_metadata.
-- Set this via Supabase Dashboard → Authentication → Users → Edit user
-- OR via the service-role key admin API.
-- ============================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  -- COALESCE guarantees FALSE (never NULL) when auth.jwt() is null
  -- (i.e. unauthenticated callers, malformed tokens, or anon requests).
  -- SET search_path prevents search_path injection attacks on this
  -- SECURITY DEFINER function.
  RETURN COALESCE(
    auth.jwt() ->> 'role' = 'service_role'
    OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'ADMIN'
    OR (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') = 'REVIEWER',
    false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ============================================================
-- banks table policies
-- ============================================================

-- Anyone (including anon Flutter app) can READ banks
CREATE POLICY "banks_public_read" ON banks
  FOR SELECT
  USING (true);

-- Only admins can INSERT/UPDATE/DELETE banks
CREATE POLICY "banks_admin_write" ON banks
  FOR ALL
  USING (is_admin());

-- ============================================================
-- fd_rates table policies
-- ============================================================

-- Public (anon key) can ONLY read VERIFIED rates
-- This is the critical security rule: never expose DRAFTs publicly
CREATE POLICY "fd_rates_public_read_verified_only" ON fd_rates
  FOR SELECT
  USING (
    -- Public (non-admin) callers see only VERIFIED
    is_admin()
    OR status = 'VERIFIED'
  );

-- Only admins can insert new draft rates
CREATE POLICY "fd_rates_admin_insert" ON fd_rates
  FOR INSERT
  WITH CHECK (is_admin());

-- Only admins can update rates (workflow transitions)
CREATE POLICY "fd_rates_admin_update" ON fd_rates
  FOR UPDATE
  USING (is_admin());

-- Nobody can DELETE a rate — ARCHIVE instead
-- (No DELETE policy = DELETE is denied for everyone)

-- ============================================================
-- rate_audit_log policies
-- ============================================================

-- Admins can read all audit logs
CREATE POLICY "audit_log_admin_read" ON rate_audit_log
  FOR SELECT
  USING (is_admin());

-- Admins can insert audit entries (the service layer writes these)
CREATE POLICY "audit_log_admin_insert" ON rate_audit_log
  FOR INSERT
  WITH CHECK (is_admin());

-- NOBODY can UPDATE or DELETE audit log entries (append-only)
-- Enforced by absence of UPDATE/DELETE policies.

-- ============================================================
-- user_roles view (for admin dashboard display)
-- ============================================================

-- Returns the current user's FeroCalc role (safe to expose to admin dashboard)
-- NOTE: auth.email() does not exist in Supabase PostgreSQL.
-- Use auth.jwt() ->> 'email' to read the email claim from the JWT instead.
CREATE OR REPLACE VIEW current_user_role AS
  SELECT
    auth.uid() AS user_id,
    (auth.jwt() ->> 'email') AS email,
    (auth.jwt() -> 'app_metadata' ->> 'ferocalc_role') AS ferocalc_role;
