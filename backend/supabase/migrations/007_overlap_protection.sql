-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 007: Tenure / Deposit Overlap Protection
--
-- Summary of changes
-- ──────────────────
-- 1. New enum:  rate_category = STANDARD | SPECIAL_SCHEME
-- 2. New cols:  rate_category (NOT NULL DEFAULT STANDARD)
--              scheme_name   (nullable; required for SPECIAL_SCHEME)
-- 3. Check constraints enforce the above invariants.
-- 4. B-tree uniqueness index extended to include rate_category and
--    normalised scheme_name so exact-duplicate detection still works.
-- 5. New partial index on conflict domain for fast overlap queries.
-- 6. transition_rate_status() — for VERIFIED transitions:
--      a. Acquires a 64-bit transaction-level advisory lock keyed on the
--         conflict domain BEFORE locking the target row.
--      b. Runs closed-inclusive tenure AND deposit range-overlap check
--         against all active VERIFIED rates in the same domain.
--      c. Raises a deterministic exception identifying the conflicting rate.
-- 7. archive_and_supersede() — acquires the same advisory lock before
--    archiving the old rate; prevents concurrent verification slipping
--    between the archive and verification steps.
--
-- Advisory-lock key derivation
-- ─────────────────────────────
-- Domain string:
--   bank_id || CHR(1) || customer_type || CHR(1) ||
--   is_callable || CHR(1) || rate_category || CHR(1) ||
--   upper(trim(scheme_name))  [SPECIAL_SCHEME] or ''  [STANDARD]
--
-- Key = ('x' || substr(md5(domain_string), 1, 16))::bit(64)::bigint
--
-- Rationale:
--   md5() returns 32 lowercase hex chars (128 bits).  First 16 chars = 64 bits.
--   Cast: text hex literal -> bit(64) -> bigint is a pure bit-pattern
--   reinterpretation — no signed arithmetic, no overflow risk
--   (unlike abs(hashtext()) which overflows on INT_MIN).
--   Same domain string always produces the same bigint key.
--
-- Effective date: 2026-09-06
-- ============================================================

-- ============================================================
-- Step 1 — rate_category enum (idempotent)
-- ============================================================

DO $$ BEGIN
  CREATE TYPE rate_category AS ENUM ('STANDARD', 'SPECIAL_SCHEME');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- Step 2 — New columns on fd_rates
-- (Column defaults guarantee all existing rows get rate_category = STANDARD,
--  scheme_name = NULL — no explicit UPDATE required.)
-- ============================================================

ALTER TABLE fd_rates
  ADD COLUMN IF NOT EXISTS rate_category  rate_category  NOT NULL DEFAULT 'STANDARD',
  ADD COLUMN IF NOT EXISTS scheme_name    TEXT;

-- ============================================================
-- Step 3 — Check constraints
-- ============================================================

ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_scheme_name_required;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_scheme_name_required
    CHECK (
      rate_category <> 'SPECIAL_SCHEME'
      OR (scheme_name IS NOT NULL AND btrim(scheme_name) <> '')
    );

ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_scheme_name_standard_null;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_scheme_name_standard_null
    CHECK (rate_category <> 'STANDARD' OR scheme_name IS NULL);

-- ============================================================
-- Step 4 — Updated uniqueness index (exact-duplicate guard)
-- ============================================================

DROP INDEX IF EXISTS idx_fd_rates_single_active_verified;

CREATE UNIQUE INDEX idx_fd_rates_single_active_verified
  ON fd_rates (
    bank_id,
    customer_type,
    min_tenure_days,
    max_tenure_days,
    min_deposit,
    COALESCE(max_deposit, -1::NUMERIC),
    is_callable,
    rate_category,
    COALESCE(upper(trim(scheme_name)), '')
  )
  WHERE status = 'VERIFIED' AND effective_until IS NULL;

-- ============================================================
-- Step 5 — Conflict-domain partial index
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_fd_rates_conflict_domain
  ON fd_rates (bank_id, customer_type, is_callable, rate_category, status)
  WHERE status = 'VERIFIED' AND effective_until IS NULL;

-- ============================================================
-- Step 6 — Replace transition_rate_status()
-- ============================================================

CREATE OR REPLACE FUNCTION transition_rate_status(
  p_rate_id       UUID,
  p_new_status    rate_status,
  p_performed_by  UUID,
  p_notes         TEXT DEFAULT NULL
)
RETURNS fd_rates AS $$
DECLARE
  v_rate          fd_rates;
  v_old_status    rate_status;
  v_old_json      JSONB;
  v_new_json      JSONB;
  v_action        audit_action;
  -- Advisory-lock variables (VERIFIED path only)
  v_domain_str    TEXT;
  v_lock_key      BIGINT;
  -- Pre-lock domain reads
  v_bank_id       UUID;
  v_customer_type customer_type;
  v_is_callable   BOOLEAN;
  v_rate_category rate_category;
  v_scheme_name   TEXT;
  -- Overlap detection
  v_conflict_id   UUID;
BEGIN
  -- Security guard
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  -- ── VERIFIED path: advisory lock BEFORE row lock ──────────────────────
  IF p_new_status = 'VERIFIED' THEN

    -- Step 1: plain read for domain computation (rate is IN_REVIEW; domain
    -- fields cannot change in that state, so this read is stable).
    SELECT bank_id, customer_type, is_callable, rate_category, scheme_name
      INTO v_bank_id, v_customer_type, v_is_callable, v_rate_category, v_scheme_name
      FROM fd_rates WHERE id = p_rate_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Rate % not found', p_rate_id;
    END IF;

    -- Step 2: conflict-domain string.
    -- CHR(1) = ASCII SOH; cannot appear in UUIDs, enum names, or booleans.
    v_domain_str :=
        v_bank_id::text        || CHR(1) ||
        v_customer_type::text  || CHR(1) ||
        v_is_callable::text    || CHR(1) ||
        v_rate_category::text  || CHR(1) ||
        CASE
          WHEN v_rate_category = 'SPECIAL_SCHEME'
          THEN upper(trim(COALESCE(v_scheme_name, '')))
          ELSE ''
        END;

    -- Step 3: 64-bit key via MD5 (bit-pattern reinterpretation, no overflow).
    v_lock_key := ('x' || substr(md5(v_domain_str), 1, 16))::bit(64)::bigint;

    -- Step 4: acquire transaction-level advisory lock.
    -- Blocks until domain is free; released on commit/rollback.
    -- Re-entrant: nested call from archive_and_supersede returns immediately.
    PERFORM pg_advisory_xact_lock(v_lock_key);

  END IF;
  -- ─────────────────────────────────────────────────────────────────────

  -- Lock target row for the state machine.
  SELECT * INTO v_rate FROM fd_rates WHERE id = p_rate_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rate % not found', p_rate_id;
  END IF;

  v_old_status := v_rate.status;

  -- State-machine
  IF NOT (
       (v_old_status = 'DRAFT'     AND p_new_status IN ('IN_REVIEW', 'REJECTED'))
    OR (v_old_status = 'IN_REVIEW' AND p_new_status IN ('VERIFIED', 'REJECTED', 'DRAFT'))
    OR (v_old_status = 'VERIFIED'  AND p_new_status = 'ARCHIVED')
    OR (v_old_status = 'REJECTED'  AND p_new_status = 'DRAFT')
  ) THEN
    RAISE EXCEPTION 'Illegal status transition: % → %', v_old_status, p_new_status;
  END IF;

  -- ── Range-overlap check (VERIFIED only) ──────────────────────────────
  IF p_new_status = 'VERIFIED' THEN

    SELECT c.id INTO v_conflict_id
      FROM fd_rates c
     WHERE c.id             <> p_rate_id
       AND c.bank_id         = v_rate.bank_id
       AND c.customer_type   = v_rate.customer_type
       AND c.is_callable     = v_rate.is_callable
       AND c.rate_category   = v_rate.rate_category
       AND (
             v_rate.rate_category <> 'SPECIAL_SCHEME'
             OR upper(trim(c.scheme_name)) = upper(trim(v_rate.scheme_name))
           )
       AND c.status          = 'VERIFIED'
       AND c.effective_until IS NULL
       -- Tenure overlap: closed-inclusive [min, max]
       -- Adjacent (max_A=729, min_B=730): 730 <= 729 is FALSE → no conflict
       AND c.min_tenure_days  <= v_rate.max_tenure_days
       AND v_rate.min_tenure_days <= c.max_tenure_days
       -- Deposit overlap: NULL = unbounded ceiling; no sentinel constant
       AND (c.max_deposit IS NULL OR c.max_deposit >= v_rate.min_deposit)
       AND (v_rate.max_deposit IS NULL OR v_rate.max_deposit >= c.min_deposit)
    LIMIT 1;

    IF FOUND THEN
      RAISE EXCEPTION
        'Overlap conflict: active VERIFIED rate % overlaps this rate in tenure '
        'and/or deposit range. Use POST /api/admin/rates/<id>/supersede with '
        'old_rate_id=% to replace it explicitly.',
        v_conflict_id, v_conflict_id;
    END IF;

  END IF;
  -- ─────────────────────────────────────────────────────────────────────

  CASE p_new_status
    WHEN 'IN_REVIEW' THEN v_action := 'SUBMIT_FOR_REVIEW';
    WHEN 'VERIFIED'  THEN v_action := 'VERIFY';
    WHEN 'REJECTED'  THEN v_action := 'REJECT';
    WHEN 'ARCHIVED'  THEN v_action := 'ARCHIVE';
    WHEN 'DRAFT'     THEN v_action := 'EDIT';
    ELSE                  v_action := 'EDIT';
  END CASE;

  v_old_json := jsonb_build_object('status', v_old_status::text);
  v_new_json := jsonb_build_object('status', p_new_status::text);

  UPDATE fd_rates
     SET status       = p_new_status,
         verified_by  = CASE WHEN p_new_status = 'VERIFIED' THEN p_performed_by ELSE verified_by END,
         verified_at  = CASE WHEN p_new_status = 'VERIFIED' THEN now() ELSE verified_at END,
         review_notes = COALESCE(p_notes, review_notes),
         updated_at   = now()
   WHERE id = p_rate_id
   RETURNING * INTO v_rate;

  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (p_rate_id, v_action, v_old_json, v_new_json, p_performed_by, p_notes);

  RETURN v_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ============================================================
-- Step 7 — Replace archive_and_supersede()
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
  v_old           fd_rates;
  v_new           fd_rates;
  v_domain_str    TEXT;
  v_lock_key      BIGINT;
  v_bank_id       UUID;
  v_customer_type customer_type;
  v_is_callable   BOOLEAN;
  v_rate_category rate_category;
  v_scheme_name   TEXT;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  -- Step 1: read NEW rate domain fields (plain — no row lock yet).
  SELECT bank_id, customer_type, is_callable, rate_category, scheme_name
    INTO v_bank_id, v_customer_type, v_is_callable, v_rate_category, v_scheme_name
    FROM fd_rates WHERE id = p_new_rate_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'New rate % not found', p_new_rate_id;
  END IF;

  -- Step 2: domain string — IDENTICAL derivation to transition_rate_status.
  -- Both functions MUST use the same formula so the same domain maps to
  -- the same lock key.
  v_domain_str :=
      v_bank_id::text        || CHR(1) ||
      v_customer_type::text  || CHR(1) ||
      v_is_callable::text    || CHR(1) ||
      v_rate_category::text  || CHR(1) ||
      CASE
        WHEN v_rate_category = 'SPECIAL_SCHEME'
        THEN upper(trim(COALESCE(v_scheme_name, '')))
        ELSE ''
      END;

  v_lock_key := ('x' || substr(md5(v_domain_str), 1, 16))::bit(64)::bigint;

  -- Step 3: acquire advisory lock BEFORE any row lock.
  -- Concurrent direct verifications in the same domain will block here,
  -- then see the newly VERIFIED replacement rate and raise a conflict.
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- Step 4: archive old rate.
  UPDATE fd_rates
     SET status          = 'ARCHIVED',
         effective_until = p_effective_at,
         updated_at      = now()
   WHERE id     = p_old_rate_id
     AND status = 'VERIFIED'
  RETURNING * INTO v_old;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Old rate % is not VERIFIED — cannot supersede', p_old_rate_id;
  END IF;

  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (
    p_old_rate_id, 'ARCHIVE',
    jsonb_build_object('status', 'VERIFIED'),
    jsonb_build_object('status', 'ARCHIVED', 'effective_until', p_effective_at),
    p_performed_by,
    COALESCE(p_notes, 'Superseded by rate ' || p_new_rate_id)
  );

  -- Step 5: verify new rate via state machine.
  -- transition_rate_status will call pg_advisory_xact_lock(same key).
  -- Transaction-level advisory locks are re-entrant: returns immediately.
  -- Overlap check sees old rate as ARCHIVED → 0 conflicts.
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
-- Step 8 — Re-state privilege hardening (idempotent)
-- ============================================================

REVOKE EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  TO service_role;

REVOKE EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  TO service_role;
