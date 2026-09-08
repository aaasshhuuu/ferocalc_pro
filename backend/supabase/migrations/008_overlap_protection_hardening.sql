-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 008: Overlap Protection Hardening
--
-- Migration 007 (007_overlap_protection.sql) is already applied
-- in production. This migration is a FORWARD-ONLY patch.
--
-- Fixes applied (per invariant audit 2026-09-07):
--
-- FIX 2: transition_rate_status() — domain-change guard
--   After acquiring the target row with FOR UPDATE, compare its
--   conflict-domain fields against the values used to compute the
--   advisory-lock key. If they differ, abort with a retryable
--   exception. This closes the TOCTOU window between the plain
--   domain read and the row lock.
--
-- FIX 3: archive_and_supersede() — DB-level domain compatibility
--   After archiving the old rate, enforce at the database level:
--     old.bank_id       = new.bank_id
--     old.customer_type = new.customer_type
--     old.is_callable   = new.is_callable
--     old.rate_category = new.rate_category
--     For SPECIAL_SCHEME: normalised scheme names must match.
--   Also asserts old.status = VERIFIED and effective_until IS NULL
--   (already checked by the UPDATE … WHERE clause, but the explicit
--   check produces a clearer error message than "0 rows returned").
--   Node.js-level validation is left in place for UX; this is the
--   authoritative, bypass-proof enforcement layer.
--
-- NOTE: FIX 1 (PATCH TOCTOU guard) is implemented in Node.js:
--   backend/routes/admin_rates.js — the final UPDATE adds
--   `.in('status', ['DRAFT', 'REJECTED'])` + `.maybeSingle()`
--   so a concurrent status change causes a deterministic HTTP 409.
--   No DB function change is needed for FIX 1.
--
-- Effective date: 2026-09-07
-- ============================================================

-- ============================================================
-- FIX 2 — transition_rate_status() with domain-change guard
-- ============================================================
-- Full replacement; advisory-lock architecture is UNCHANGED.
-- Only addition: after FOR UPDATE, compare pre-lock domain reads
-- against the now-locked row's domain fields.

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
  -- Pre-lock domain reads (plain SELECT before advisory lock)
  v_bank_id       UUID;
  v_customer_type customer_type;
  v_is_callable   BOOLEAN;
  v_rate_category rate_category;
  v_scheme_name   TEXT;
  -- Normalised scheme-name helpers (FIX 2 domain guard)
  v_pre_scheme    TEXT;
  v_post_scheme   TEXT;
  -- Overlap detection
  v_conflict_id   UUID;
BEGIN
  -- Security guard: only service_role / ADMIN / REVIEWER may call this.
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  -- ── VERIFIED path: advisory lock BEFORE row lock ──────────────────
  IF p_new_status = 'VERIFIED' THEN

    -- Step 1: plain, un-locked read of domain fields.
    -- The rate should be IN_REVIEW at this point; domain fields cannot
    -- legitimately change while IN_REVIEW via the normal API, but we
    -- must still guard against concurrent PATCH bugs or direct DB edits.
    SELECT bank_id, customer_type, is_callable, rate_category, scheme_name
      INTO v_bank_id, v_customer_type, v_is_callable, v_rate_category, v_scheme_name
      FROM fd_rates WHERE id = p_rate_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Rate % not found', p_rate_id;
    END IF;

    -- Step 2: build conflict-domain string.
    -- CHR(1) = ASCII SOH — cannot appear in UUID, enum, or boolean text.
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

    -- Step 3: derive 64-bit advisory-lock key.
    -- md5() → 32 hex chars. First 16 chars = 64 bits.
    -- ::bit(64)::bigint is a pure bit-pattern reinterpretation — no
    -- arithmetic, no overflow risk (unlike abs(hashtext())).
    v_lock_key := ('x' || substr(md5(v_domain_str), 1, 16))::bit(64)::bigint;

    -- Step 4: acquire transaction-level advisory lock.
    -- Blocks until the same domain is free. Released on commit/rollback.
    -- Re-entrant within the same session (archive_and_supersede chain).
    PERFORM pg_advisory_xact_lock(v_lock_key);

  END IF;
  -- ─────────────────────────────────────────────────────────────────

  -- Acquire row lock for the state machine.
  SELECT * INTO v_rate FROM fd_rates WHERE id = p_rate_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rate % not found', p_rate_id;
  END IF;

  -- ── FIX 2: Domain-change guard ──────────────────────────────────
  -- Compare the fields used to derive the advisory-lock key against
  -- the now-locked row's actual values. If anything differs, abort.
  -- A mismatch means a concurrent write changed a conflict-domain
  -- field between our plain read (Step 1) and this row lock.
  --
  -- This guard only executes on the VERIFIED path where we computed
  -- the advisory lock key from v_bank_id, v_customer_type etc.
  -- For SPECIAL_SCHEME, scheme_name is normalised to upper(trim(?))
  -- so we compare the normalised form.
  IF p_new_status = 'VERIFIED' THEN
    v_pre_scheme  := CASE WHEN v_rate_category         = 'SPECIAL_SCHEME'
                          THEN upper(trim(COALESCE(v_scheme_name, '')))
                          ELSE '' END;
    v_post_scheme := CASE WHEN v_rate.rate_category    = 'SPECIAL_SCHEME'
                          THEN upper(trim(COALESCE(v_rate.scheme_name, '')))
                          ELSE '' END;

    IF  v_rate.bank_id         IS DISTINCT FROM v_bank_id
     OR v_rate.customer_type   IS DISTINCT FROM v_customer_type
     OR v_rate.is_callable     IS DISTINCT FROM v_is_callable
     OR v_rate.rate_category   IS DISTINCT FROM v_rate_category
     OR v_post_scheme          IS DISTINCT FROM v_pre_scheme
    THEN
      RAISE EXCEPTION
        'Conflict domain changed concurrently during verification; retry. '
        'Rate % domain fields mutated between advisory-lock read and row lock.',
        p_rate_id;
    END IF;
  END IF;
  -- ─────────────────────────────────────────────────────────────────

  v_old_status := v_rate.status;

  -- State-machine: enforce legal transitions.
  -- DRAFT       → IN_REVIEW, REJECTED
  -- IN_REVIEW   → VERIFIED, REJECTED, DRAFT (send back)
  -- VERIFIED    → ARCHIVED
  -- REJECTED    → DRAFT (re-entry after correction)
  -- ARCHIVED    → (terminal)
  IF NOT (
       (v_old_status = 'DRAFT'     AND p_new_status IN ('IN_REVIEW', 'REJECTED'))
    OR (v_old_status = 'IN_REVIEW' AND p_new_status IN ('VERIFIED', 'REJECTED', 'DRAFT'))
    OR (v_old_status = 'VERIFIED'  AND p_new_status = 'ARCHIVED')
    OR (v_old_status = 'REJECTED'  AND p_new_status = 'DRAFT')
  ) THEN
    RAISE EXCEPTION 'Illegal status transition: % → %', v_old_status, p_new_status;
  END IF;

  -- ── Range-overlap check (VERIFIED transitions only) ────────────
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
       -- Tenure overlap (closed-inclusive).
       -- Adjacent slabs: max_A=729 / min_B=730 → 730 <= 729 is FALSE → no conflict.
       AND c.min_tenure_days  <= v_rate.max_tenure_days
       AND v_rate.min_tenure_days <= c.max_tenure_days
       -- Deposit overlap (NULL = unbounded ceiling, no sentinel constant).
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
  -- ─────────────────────────────────────────────────────────────────

  -- Audit action label
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

  -- Apply transition.
  UPDATE fd_rates
     SET status       = p_new_status,
         verified_by  = CASE WHEN p_new_status = 'VERIFIED' THEN p_performed_by ELSE verified_by END,
         verified_at  = CASE WHEN p_new_status = 'VERIFIED' THEN now() ELSE verified_at END,
         review_notes = COALESCE(p_notes, review_notes),
         updated_at   = now()
   WHERE id = p_rate_id
   RETURNING * INTO v_rate;

  -- Append to audit log.
  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (p_rate_id, v_action, v_old_json, v_new_json, p_performed_by, p_notes);

  RETURN v_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

-- ============================================================
-- FIX 3 — archive_and_supersede() with DB-level domain checks
-- ============================================================
-- Full replacement; advisory-lock architecture is UNCHANGED.
-- New: after archiving the old rate, assert full domain compatibility
-- at the database level — not relying on Node.js validation alone.
--
-- Invariants enforced at DB level (any mismatch raises EXCEPTION):
--   1. old.bank_id       = new.bank_id
--   2. old.customer_type = new.customer_type
--   3. old.is_callable   = new.is_callable
--   4. old.rate_category = new.rate_category
--   5. For SPECIAL_SCHEME: upper(trim(old.scheme_name)) = upper(trim(new.scheme_name))
--   6. old.status = VERIFIED   (enforced implicitly by UPDATE … WHERE … status='VERIFIED';
--                                RETURNING gives null + NOT FOUND check if mismatch)
--   7. old.effective_until IS NULL  (enforced by explicit check below)
--
-- Transaction atomicity: all updates are within the same transaction.
-- If verification fails in transition_rate_status(), PostgreSQL rolls
-- back the entire transaction — old rate is never left ARCHIVED.

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
  -- NEW rate domain (drives the advisory lock)
  v_bank_id       UUID;
  v_customer_type customer_type;
  v_is_callable   BOOLEAN;
  v_rate_category rate_category;
  v_scheme_name   TEXT;
BEGIN
  -- Security guard.
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  -- ── Step 1: plain read of NEW rate domain fields ────────────────
  -- No row lock yet; we need the domain to compute the advisory lock key.
  SELECT bank_id, customer_type, is_callable, rate_category, scheme_name
    INTO v_bank_id, v_customer_type, v_is_callable, v_rate_category, v_scheme_name
    FROM fd_rates WHERE id = p_new_rate_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'New rate % not found', p_new_rate_id;
  END IF;

  -- ── Step 2: conflict-domain string (IDENTICAL to transition_rate_status)
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

  -- ── Step 3: acquire advisory lock BEFORE any row lock ──────────
  -- Concurrent direct verifications in the same domain block here,
  -- then see the newly VERIFIED replacement and raise a conflict.
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- ── Step 4: validate and archive the OLD rate ──────────────────
  -- Explicit effective_until check first (gives a clear error;
  -- the UPDATE WHERE clause below also enforces it).
  PERFORM 1 FROM fd_rates
   WHERE id = p_old_rate_id
     AND status = 'VERIFIED'
     AND effective_until IS NOT NULL;

  IF FOUND THEN
    RAISE EXCEPTION
      'Old rate % has effective_until set — it is already expired and cannot be superseded.',
      p_old_rate_id;
  END IF;

  -- Archive: only succeeds if status = VERIFIED AND effective_until IS NULL.
  UPDATE fd_rates
     SET status          = 'ARCHIVED',
         effective_until = p_effective_at,
         updated_at      = now()
   WHERE id              = p_old_rate_id
     AND status          = 'VERIFIED'
     AND effective_until IS NULL
  RETURNING * INTO v_old;

  IF NOT FOUND THEN
    -- Could be: not found, wrong status, or already-expired.
    -- Distinguish for a precise error message.
    PERFORM 1 FROM fd_rates WHERE id = p_old_rate_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Old rate % not found', p_old_rate_id;
    ELSE
      RAISE EXCEPTION
        'Old rate % is not an active VERIFIED rate (status or effective_until mismatch) '
        '— cannot supersede.',
        p_old_rate_id;
    END IF;
  END IF;

  -- ── FIX 3: DB-level domain-compatibility checks ─────────────────
  -- Assert that old and new rates belong to the same conflict domain.
  -- These checks are authoritative and cannot be bypassed by callers
  -- who call archive_and_supersede() directly via SQL / RPC.

  -- 1. bank_id
  IF v_old.bank_id IS DISTINCT FROM v_bank_id THEN
    RAISE EXCEPTION
      'Bank mismatch: old rate % belongs to bank %, but new rate % belongs to bank %.',
      p_old_rate_id, v_old.bank_id, p_new_rate_id, v_bank_id;
  END IF;

  -- 2. customer_type
  IF v_old.customer_type IS DISTINCT FROM v_customer_type THEN
    RAISE EXCEPTION
      'Customer-type mismatch: old rate % has %, new rate % has %.',
      p_old_rate_id, v_old.customer_type, p_new_rate_id, v_customer_type;
  END IF;

  -- 3. is_callable
  IF v_old.is_callable IS DISTINCT FROM v_is_callable THEN
    RAISE EXCEPTION
      'is_callable mismatch: old rate % is %, new rate % is %.',
      p_old_rate_id, v_old.is_callable, p_new_rate_id, v_is_callable;
  END IF;

  -- 4. rate_category
  IF v_old.rate_category IS DISTINCT FROM v_rate_category THEN
    RAISE EXCEPTION
      'rate_category mismatch: old rate % is %, new rate % is %.',
      p_old_rate_id, v_old.rate_category, p_new_rate_id, v_rate_category;
  END IF;

  -- 5. scheme_name (only relevant for SPECIAL_SCHEME; normalise both sides)
  IF v_rate_category = 'SPECIAL_SCHEME' THEN
    IF upper(trim(COALESCE(v_old.scheme_name, ''))) IS DISTINCT FROM
       upper(trim(COALESCE(v_scheme_name,     ''))) THEN
      RAISE EXCEPTION
        'scheme_name mismatch for SPECIAL_SCHEME: old rate % has scheme_name "%", '
        'new rate % has scheme_name "%".',
        p_old_rate_id, v_old.scheme_name,
        p_new_rate_id, v_scheme_name;
    END IF;
  END IF;
  -- ─────────────────────────────────────────────────────────────────

  -- Audit the archive action.
  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (
    p_old_rate_id, 'ARCHIVE',
    jsonb_build_object('status', 'VERIFIED'),
    jsonb_build_object('status', 'ARCHIVED', 'effective_until', p_effective_at),
    p_performed_by,
    COALESCE(p_notes, 'Superseded by rate ' || p_new_rate_id)
  );

  -- ── Step 5: verify the new rate via the state machine ──────────
  -- transition_rate_status() calls pg_advisory_xact_lock(same key).
  -- Transaction-level advisory locks are re-entrant within the same
  -- session: the nested call returns immediately (no deadlock).
  -- Overlap check sees old rate as ARCHIVED → 0 conflicts.
  --
  -- If transition_rate_status() raises (e.g., bad state, domain guard),
  -- PostgreSQL rolls back the ENTIRE transaction, including the archive
  -- UPDATE above. The old rate is never permanently left ARCHIVED.
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
-- Re-state privilege hardening (idempotent — same as migration 007)
-- ============================================================

REVOKE EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  TO service_role;

REVOKE EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  TO service_role;
