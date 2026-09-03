-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 006: Verified rates view + workflow functions
-- Server-side business logic for workflow transitions
-- ============================================================

-- ============================================================
-- Public verified rates view
-- This is what the public API queries. Enforces VERIFIED-only.
-- ============================================================

CREATE OR REPLACE VIEW verified_fd_rates AS
  SELECT
    r.id,
    r.bank_id,
    b.name            AS bank_name,
    b.short_name      AS bank_short_name,
    b.official_website AS bank_source_domain,
    r.customer_type,
    r.min_tenure_days,
    r.max_tenure_days,
    r.min_deposit,
    r.max_deposit,
    r.interest_rate,
    r.is_callable,
    r.compounding_frequency,
    r.effective_from,
    r.effective_until,
    r.source_url,
    r.verified_at,
    r.review_notes
  FROM fd_rates r
  JOIN banks b ON b.id = r.bank_id
  WHERE
    r.status = 'VERIFIED'
    AND b.status = 'ACTIVE'
    AND (r.effective_until IS NULL OR r.effective_until > now());

-- ============================================================
-- Function: transition_rate_status
-- Safe status machine enforcer.
-- Called by the Node.js admin API with the service-role key.
-- ============================================================

CREATE OR REPLACE FUNCTION transition_rate_status(
  p_rate_id       UUID,
  p_new_status    rate_status,
  p_performed_by  UUID,
  p_notes         TEXT DEFAULT NULL
)
RETURNS fd_rates AS $$
DECLARE
  v_rate        fd_rates;
  v_old_status  rate_status;
  v_old_json    JSONB;
  v_new_json    JSONB;
  v_action      audit_action;
BEGIN
  -- ============================================================
  -- SECURITY: Reject callers who are not authorised admins.
  -- This check fires even when called directly via PostgREST RPC,
  -- bypassing the Node.js backend entirely.
  -- service_role (used by the Node backend) always passes.
  -- anon / authenticated / any other role is denied.
  -- ============================================================
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  -- Lock the row
  SELECT * INTO v_rate FROM fd_rates WHERE id = p_rate_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rate % not found', p_rate_id;
  END IF;

  v_old_status := v_rate.status;

  -- ============================================================
  -- Enforce legal state transitions only:
  --
  -- DRAFT       → IN_REVIEW, REJECTED
  -- IN_REVIEW   → VERIFIED, REJECTED, DRAFT (send back)
  -- VERIFIED    → ARCHIVED
  -- REJECTED    → DRAFT (allow re-entry after correction)
  -- ARCHIVED    → (terminal — no transitions)
  -- ============================================================

  IF NOT (
    (v_old_status = 'DRAFT'     AND p_new_status IN ('IN_REVIEW', 'REJECTED'))
    OR (v_old_status = 'IN_REVIEW' AND p_new_status IN ('VERIFIED', 'REJECTED', 'DRAFT'))
    OR (v_old_status = 'VERIFIED'  AND p_new_status = 'ARCHIVED')
    OR (v_old_status = 'REJECTED'  AND p_new_status = 'DRAFT')
  ) THEN
    RAISE EXCEPTION 'Illegal status transition: % → %', v_old_status, p_new_status;
  END IF;

  -- Determine audit action label
  CASE p_new_status
    WHEN 'IN_REVIEW' THEN v_action := 'SUBMIT_FOR_REVIEW';
    WHEN 'VERIFIED'  THEN v_action := 'VERIFY';
    WHEN 'REJECTED'  THEN v_action := 'REJECT';
    WHEN 'ARCHIVED'  THEN v_action := 'ARCHIVE';
    WHEN 'DRAFT'     THEN v_action := 'EDIT'; -- returned to draft
    ELSE v_action := 'EDIT';
  END CASE;

  -- Prepare diff snapshots
  v_old_json := jsonb_build_object('status', v_old_status::text);
  v_new_json := jsonb_build_object('status', p_new_status::text);

  -- Apply the transition
  UPDATE fd_rates
  SET
    status       = p_new_status,
    verified_by  = CASE WHEN p_new_status = 'VERIFIED' THEN p_performed_by ELSE verified_by END,
    verified_at  = CASE WHEN p_new_status = 'VERIFIED' THEN now() ELSE verified_at END,
    review_notes = COALESCE(p_notes, review_notes),
    updated_at   = now()
  WHERE id = p_rate_id
  RETURNING * INTO v_rate;

  -- Write audit log entry
  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (p_rate_id, v_action, v_old_json, v_new_json, p_performed_by, p_notes);

  RETURN v_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ============================================================
-- Function: archive_and_supersede
-- When a new VERIFIED rate replaces an older one:
--   1. Archive the old rate (set effective_until)
--   2. Verify the new rate (set effective_from)
-- History is always preserved.
-- ============================================================

CREATE OR REPLACE FUNCTION archive_and_supersede(
  p_old_rate_id   UUID,
  p_new_rate_id   UUID,
  p_performed_by  UUID,
  p_effective_at  TIMESTAMPTZ DEFAULT now(),
  p_notes         TEXT DEFAULT NULL
)
RETURNS TABLE (old_rate fd_rates, new_rate fd_rates) AS $$
DECLARE
  v_old fd_rates;
  v_new fd_rates;
BEGIN
  -- ============================================================
  -- SECURITY: Reject callers who are not authorised admins.
  -- Mirrors the check in transition_rate_status for defense-in-depth.
  -- service_role (used by the Node backend) always passes.
  -- ============================================================
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  -- Archive the old rate
  UPDATE fd_rates
  SET
    status          = 'ARCHIVED',
    effective_until = p_effective_at,
    updated_at      = now()
  WHERE id = p_old_rate_id
    AND status = 'VERIFIED'
  RETURNING * INTO v_old;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Old rate % is not VERIFIED — cannot supersede', p_old_rate_id;
  END IF;

  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (
    p_old_rate_id,
    'ARCHIVE',
    jsonb_build_object('status', 'VERIFIED'),
    jsonb_build_object('status', 'ARCHIVED', 'effective_until', p_effective_at),
    p_performed_by,
    COALESCE(p_notes, 'Superseded by rate ' || p_new_rate_id)
  );

  -- Verify the new rate (must be IN_REVIEW).
  -- transition_rate_status also calls is_admin(); since we are inside a
  -- SECURITY DEFINER function the session JWT is preserved and the
  -- service_role context flows through correctly.
  SELECT * INTO v_new FROM transition_rate_status(
    p_new_rate_id,
    'VERIFIED',
    p_performed_by,
    COALESCE(p_notes, 'Supersedes archived rate ' || p_old_rate_id)
  );

  RETURN QUERY SELECT v_old, v_new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ============================================================
-- PRIVILEGE HARDENING
-- Revoke direct-call access from all roles except service_role.
-- The Node.js backend uses the service-role key for all admin writes,
-- so service_role must retain EXECUTE.
--
-- Arguments must be fully typed — PostgreSQL uses the full signature
-- for REVOKE/GRANT to disambiguate overloaded functions.
-- ============================================================

REVOKE EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  TO service_role;

REVOKE EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  TO service_role;

