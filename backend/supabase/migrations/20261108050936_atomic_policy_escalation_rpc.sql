-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 020: Atomic Policy Escalation RPC
--
-- STATUS: APPLIED
-- Applied to staging Supabase (cqrslxngpwbtkjejlwty) via SQL Editor.
-- Recorded migration version: 20261108050936
-- Migration name: 20261107134500_atomic_policy_escalation_rpc
--
-- Purpose:
--   Provides an atomic PostgreSQL RPC to persist policy-escalation
--   status transitions (DRAFT/IN_REVIEW → IN_REVIEW/INVALID) when
--   PromotionPolicyEngine blocks automated promotion.
--
--   Companion to Migration 019 (promote_staged_candidate). This RPC
--   handles the BLOCKED path; Migration 019 handles the PROMOTED path.
--
-- Security Hardening (consistent with Migration 019):
--   * SECURITY DEFINER with SET search_path = '' (empty search path).
--   * Fully qualified references (public.table, pg_catalog.func).
--   * Actor validation: 'AUTOMATED_POLICY' requires auth.users
--     app_metadata ferocalc_role='SYSTEM_BOT' and is_service_account=true.
--   * Optimistic concurrency: p_expected_previous_status must match the
--     live row; mismatches raise an exception before any write.
--   * Rejects transitions to 'PROMOTED' or 'VERIFIED' — this RPC
--     NEVER creates or modifies verified_fd_rates rows.
--   * Rejects unexpected actor types.
--   * Rejects NULL p_new_status (SQLSTATE 22023).
--   * Rejects NULL or disallowed p_expected_previous_status values
--     (only 'DRAFT' and 'IN_REVIEW' are accepted; SQLSTATE 22023).
--   * INVALID is a terminal state: INVALID → IN_REVIEW is rejected
--     (SQLSTATE 42501). Only idempotent INVALID → INVALID is permitted.
--   * Privileges: Revoked from PUBLIC, anon, authenticated;
--     granted strictly to service_role.
-- ============================================================

CREATE OR REPLACE FUNCTION public.escalate_staged_candidate(
  p_staged_candidate_id      UUID,
  p_actor_type               TEXT,           -- Must be 'AUTOMATED_POLICY'
  p_actor_id                 UUID,           -- Dedicated service bot UUID
  p_expected_previous_status TEXT,           -- Optimistic concurrency check; must be 'DRAFT' or 'IN_REVIEW'
  p_new_status               TEXT,           -- 'IN_REVIEW' or 'INVALID'
  p_policy_result            JSONB DEFAULT '{}'::pg_catalog.jsonb,
  p_diff_summary             JSONB DEFAULT '{}'::pg_catalog.jsonb,
  p_notes                    TEXT DEFAULT NULL,
  p_source_content_hash      TEXT DEFAULT NULL,
  p_parser_version           TEXT DEFAULT NULL
)
RETURNS TABLE (
  candidate_id  UUID,
  previous_status TEXT,
  new_status    TEXT,
  escalation_status TEXT
) AS $$
DECLARE
  v_candidate     public.staged_rate_candidates%ROWTYPE;
  v_user_role     TEXT;
  v_is_service    BOOLEAN;
  v_now           TIMESTAMPTZ := pg_catalog.clock_timestamp();
  c_admin_uuid    CONSTANT UUID := '995b04cd-518b-435d-83a0-d1bdde22cca6'::uuid;
  v_action        TEXT;
BEGIN
  -- ============================================================
  -- 1. ACTOR SECURITY & SERVICE IDENTITY VALIDATION
  -- ============================================================
  IF p_actor_id IS NULL THEN
    RAISE EXCEPTION 'Actor UUID is required for escalation'
      USING ERRCODE = '42501';
  END IF;

  -- Only AUTOMATED_POLICY is permitted to call this RPC.
  -- ADMIN-driven escalations go through a different administrative path.
  IF p_actor_type IS NULL OR p_actor_type <> 'AUTOMATED_POLICY' THEN
    RAISE EXCEPTION 'escalate_staged_candidate: only AUTOMATED_POLICY actor_type is accepted, got: %', p_actor_type
      USING ERRCODE = '42501';
  END IF;

  -- Anti-spoofing: must not use the human admin identity
  IF p_actor_id = c_admin_uuid THEN
    RAISE EXCEPTION 'Escalation cannot use human admin identity (%)', p_actor_id
      USING ERRCODE = '42501';
  END IF;

  -- Verify dedicated service bot role in auth.users app_metadata
  SELECT
    raw_app_meta_data->>'ferocalc_role',
    CASE
      WHEN raw_app_meta_data IS NOT NULL
           AND (raw_app_meta_data ? 'is_service_account')
           AND (raw_app_meta_data->>'is_service_account')::pg_catalog.bool IS TRUE
      THEN TRUE
      ELSE FALSE
    END
  INTO v_user_role, v_is_service
  FROM auth.users
  WHERE id = p_actor_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Escalation actor % not found in auth.users', p_actor_id
      USING ERRCODE = '42501';
  END IF;

  IF v_user_role IS DISTINCT FROM 'SYSTEM_BOT' THEN
    RAISE EXCEPTION 'Escalation actor % does not have ferocalc_role=SYSTEM_BOT (got: %)', p_actor_id, v_user_role
      USING ERRCODE = '42501';
  END IF;

  IF v_is_service IS NOT TRUE THEN
    RAISE EXCEPTION 'Escalation actor % does not have is_service_account=true', p_actor_id
      USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- 2. INPUT VALIDATION: p_new_status
  --    NULL is rejected explicitly before the allowed-value check
  --    so callers receive a clear diagnostic rather than a cast error.
  -- ============================================================
  IF p_new_status IS NULL THEN
    RAISE EXCEPTION 'Escalation target status is required'
      USING ERRCODE = '22023';
  END IF;

  -- Safety guard: reject transitions to PROMOTED/VERIFIED.
  -- This RPC MUST NEVER touch verified_fd_rates.
  IF p_new_status IN ('PROMOTED', 'VERIFIED') THEN
    RAISE EXCEPTION 'escalate_staged_candidate cannot transition to %; use promote_staged_candidate instead', p_new_status
      USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('IN_REVIEW', 'INVALID') THEN
    RAISE EXCEPTION 'Unexpected escalation target status: %. Must be IN_REVIEW or INVALID', p_new_status
      USING ERRCODE = '22023';
  END IF;

  -- ============================================================
  -- 3. INPUT VALIDATION: p_expected_previous_status
  --    Only 'DRAFT' and 'IN_REVIEW' are valid source states for
  --    automated escalation. NULL, 'INVALID', 'PROMOTED', and any
  --    other value are rejected with SQLSTATE 22023.
  --    'INVALID' is a terminal state; INVALID → IN_REVIEW is separately
  --    enforced below (SQLSTATE 42501) for a more specific error message.
  -- ============================================================
  IF p_expected_previous_status NOT IN ('DRAFT', 'IN_REVIEW') THEN
    RAISE EXCEPTION 'Unexpected escalation source status: %', p_expected_previous_status
      USING ERRCODE = '22023';
  END IF;

  -- Terminal-state guard: INVALID candidates cannot be re-escalated to IN_REVIEW.
  -- Idempotent INVALID → INVALID is handled further below.
  IF p_expected_previous_status = 'INVALID' AND p_new_status = 'IN_REVIEW' THEN
    RAISE EXCEPTION 'INVALID candidates cannot transition to IN_REVIEW via automated escalation'
      USING ERRCODE = '42501';
  END IF;

  -- ============================================================
  -- 4. FETCH CANDIDATE & OPTIMISTIC CONCURRENCY CHECK
  -- ============================================================
  SELECT * INTO v_candidate
  FROM public.staged_rate_candidates
  WHERE id = p_staged_candidate_id
  FOR UPDATE;  -- Row-level lock prevents concurrent escalation

  IF NOT FOUND THEN
    RAISE EXCEPTION 'staged_rate_candidates row not found: %', p_staged_candidate_id
      USING ERRCODE = 'P0002';
  END IF;

  IF v_candidate.staging_status::pg_catalog.text IS DISTINCT FROM p_expected_previous_status THEN
    RAISE EXCEPTION 'Optimistic concurrency conflict: expected staging_status=%, got=%',
      p_expected_previous_status, v_candidate.staging_status
      USING ERRCODE = '40001';
  END IF;

  -- Guard: candidate already in the target state — idempotent success
  IF v_candidate.staging_status::pg_catalog.text = p_new_status THEN
    RETURN QUERY SELECT
      p_staged_candidate_id,
      p_new_status,
      p_new_status,
      'IDEMPOTENT'::pg_catalog.text;
    RETURN;
  END IF;

  -- ============================================================
  -- 5. ATOMIC STATUS UPDATE — no verified_fd_rates touched
  -- ============================================================
  UPDATE public.staged_rate_candidates
  SET
    staging_status = p_new_status::public.staging_candidate_status,
    updated_at     = v_now,
    notes          = COALESCE(p_notes, notes)
  WHERE id = p_staged_candidate_id;

  -- ============================================================
  -- 6. APPEND IMMUTABLE AUDIT ENTRY
  -- ============================================================
  v_action := CASE p_new_status
    WHEN 'INVALID'   THEN 'MARK_INVALID'
    ELSE                   'ESCALATE_TO_IN_REVIEW'
  END;

  INSERT INTO public.promotion_audit_log (
    staged_candidate_id,
    rate_id,
    action,
    actor_type,
    actor_id,
    previous_status,
    new_status,
    policy_result,
    diff_summary,
    source_content_hash,
    parser_version,
    notes,
    created_at
  ) VALUES (
    p_staged_candidate_id,
    NULL,                            -- No rate touched
    v_action,
    p_actor_type,
    p_actor_id::pg_catalog.text,
    p_expected_previous_status,
    p_new_status,
    p_policy_result,
    p_diff_summary,
    p_source_content_hash,
    p_parser_version,
    COALESCE(p_notes, 'Atomic policy escalation'),
    v_now
  );

  -- ============================================================
  -- 7. RETURN RESULT
  -- ============================================================
  RETURN QUERY SELECT
    p_staged_candidate_id,
    p_expected_previous_status,
    p_new_status,
    'ESCALATED'::pg_catalog.text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Lock down execution privileges: service_role only
REVOKE ALL ON FUNCTION public.escalate_staged_candidate(UUID, TEXT, UUID, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.escalate_staged_candidate(UUID, TEXT, UUID, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION public.escalate_staged_candidate(UUID, TEXT, UUID, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TEXT) FROM anon;
GRANT  EXECUTE ON FUNCTION public.escalate_staged_candidate(UUID, TEXT, UUID, TEXT, TEXT, JSONB, JSONB, TEXT, TEXT, TEXT) TO service_role;
