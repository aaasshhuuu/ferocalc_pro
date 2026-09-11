-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 009: Calendar-Aware Tenure Domain
--
-- Adds a dual-domain tenure model:
--
--   DAYS domain (existing SBI + ICICI records)
--     min_tenure_days / max_tenure_days remain authoritative.
--     Calendar fields are NULL.
--
--   CALENDAR domain (future Axis / HDFC / Unity records)
--     min_tenure_days / max_tenure_days MUST be NULL.
--     Calendar components (years, months, days) + boundary
--     operators (GTE/GT/LTE/LT) are stored verbatim from the
--     bank rate card.  No integer-day conversion ever.
--
-- STRICTLY PROHIBITED (enforced by CHECK constraints):
--   * 1 month = 30 days conversion
--   * Fixed anchor date projection
--   * Guessed integer-day equivalents for CALENDAR records
--   * Auto-superseding overlapping VERIFIED rates
--
-- Effective date: 2026-09-11
-- ============================================================


-- ============================================================
-- Step 1 -- New ENUMs (idempotent)
-- ============================================================

DO $$ BEGIN
  CREATE TYPE tenure_domain AS ENUM ('DAYS', 'CALENDAR');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE boundary_op AS ENUM ('GTE', 'GT', 'LTE', 'LT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ============================================================
-- Step 2 -- New columns on fd_rates
-- ============================================================

-- tenure_domain: defaults DAYS for all existing rows.
ALTER TABLE fd_rates
  ADD COLUMN IF NOT EXISTS tenure_domain      tenure_domain NOT NULL DEFAULT 'DAYS';

-- source_tenure_text: verbatim text from the bank rate card.
ALTER TABLE fd_rates
  ADD COLUMN IF NOT EXISTS source_tenure_text TEXT;

-- Calendar endpoint components (lower bound)
ALTER TABLE fd_rates
  ADD COLUMN IF NOT EXISTS min_years    INTEGER,
  ADD COLUMN IF NOT EXISTS min_months   INTEGER,
  ADD COLUMN IF NOT EXISTS min_days_cal INTEGER,
  ADD COLUMN IF NOT EXISTS min_operator boundary_op;

-- Calendar endpoint components (upper bound)
ALTER TABLE fd_rates
  ADD COLUMN IF NOT EXISTS max_years    INTEGER,
  ADD COLUMN IF NOT EXISTS max_months   INTEGER,
  ADD COLUMN IF NOT EXISTS max_days_cal INTEGER,
  ADD COLUMN IF NOT EXISTS max_operator boundary_op;


-- ============================================================
-- Step 3 -- Make day columns nullable
-- ============================================================

ALTER TABLE fd_rates
  ALTER COLUMN min_tenure_days DROP NOT NULL,
  ALTER COLUMN max_tenure_days DROP NOT NULL;


-- ============================================================
-- Step 4 -- Drop old tenure constraints; add domain-specific ones
-- ============================================================

ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_tenure_min_gte_zero,
  DROP CONSTRAINT IF EXISTS fd_rates_tenure_max_gte_min;


-- DAYS: day columns required
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_days_domain_day_cols_required;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_days_domain_day_cols_required
    CHECK (
      tenure_domain <> 'DAYS'
      OR (min_tenure_days IS NOT NULL AND max_tenure_days IS NOT NULL)
    );

-- DAYS: min >= 0
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_days_domain_min_gte_zero;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_days_domain_min_gte_zero
    CHECK (tenure_domain <> 'DAYS' OR min_tenure_days >= 0);

-- DAYS: max >= min
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_days_domain_max_gte_min;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_days_domain_max_gte_min
    CHECK (tenure_domain <> 'DAYS' OR max_tenure_days >= min_tenure_days);

-- DAYS: calendar columns must be NULL
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_days_domain_cal_cols_null;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_days_domain_cal_cols_null
    CHECK (
      tenure_domain <> 'DAYS'
      OR (
        min_years    IS NULL AND min_months   IS NULL AND min_days_cal IS NULL AND min_operator IS NULL
        AND max_years IS NULL AND max_months   IS NULL AND max_days_cal IS NULL AND max_operator IS NULL
      )
    );

-- CALENDAR: day columns must be NULL
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_cal_domain_day_cols_null;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_cal_domain_day_cols_null
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (min_tenure_days IS NULL AND max_tenure_days IS NULL)
    );

-- CALENDAR: all calendar components non-negative and months in [0,11]
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_cal_domain_components_non_negative;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_cal_domain_components_non_negative
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (
        (min_years    IS NULL OR min_years    >= 0) AND
        (min_months   IS NULL OR (min_months  >= 0 AND min_months  <= 11)) AND
        (min_days_cal IS NULL OR min_days_cal >= 0) AND
        (max_years    IS NULL OR max_years    >= 0) AND
        (max_months   IS NULL OR (max_months  >= 0 AND max_months  <= 11)) AND
        (max_days_cal IS NULL OR max_days_cal >= 0)
      )
    );

-- CALENDAR: lower operator must be GTE or GT
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_cal_domain_min_operator_valid;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_cal_domain_min_operator_valid
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR min_operator IS NULL
      OR min_operator IN ('GTE', 'GT')
    );

-- CALENDAR: upper operator must be LTE or LT
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_cal_domain_max_operator_valid;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_cal_domain_max_operator_valid
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR max_operator IS NULL
      OR max_operator IN ('LTE', 'LT')
    );

-- CALENDAR: source_tenure_text required and non-empty
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_cal_domain_source_text_required;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_cal_domain_source_text_required
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (source_tenure_text IS NOT NULL AND btrim(source_tenure_text) <> '')
    );

-- CALENDAR: lower endpoint <= upper endpoint (symbolic tuple comparison)
ALTER TABLE fd_rates
  DROP CONSTRAINT IF EXISTS fd_rates_cal_domain_min_lte_max;
ALTER TABLE fd_rates
  ADD CONSTRAINT fd_rates_cal_domain_min_lte_max
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (min_years IS NULL AND min_months IS NULL AND min_days_cal IS NULL)
      OR (max_years IS NULL AND max_months IS NULL AND max_days_cal IS NULL)
      OR (
        (COALESCE(min_years, 0) * 12 + COALESCE(min_months, 0))
          < (COALESCE(max_years, 0) * 12 + COALESCE(max_months, 0))
        OR (
          (COALESCE(min_years, 0) * 12 + COALESCE(min_months, 0))
            = (COALESCE(max_years, 0) * 12 + COALESCE(max_months, 0))
          AND COALESCE(min_days_cal, 0) <= COALESCE(max_days_cal, 0)
        )
      )
    );


-- ============================================================
-- Step 5 -- Backfill existing DAYS records with source_tenure_text
-- DO NOT change any financial fields.
-- ============================================================

UPDATE fd_rates
SET
  tenure_domain      = 'DAYS',
  source_tenure_text = CASE
    WHEN min_tenure_days = max_tenure_days
      THEN min_tenure_days::text || ' day' || (CASE WHEN min_tenure_days <> 1 THEN 's' ELSE '' END)
    ELSE
      min_tenure_days::text || ' day' ||
      (CASE WHEN min_tenure_days <> 1 THEN 's' ELSE '' END) ||
      ' to ' ||
      max_tenure_days::text || ' day' ||
      (CASE WHEN max_tenure_days <> 1 THEN 's' ELSE '' END)
  END
WHERE
  tenure_domain = 'DAYS'
  AND source_tenure_text IS NULL
  AND min_tenure_days IS NOT NULL;


-- ============================================================
-- Step 6 -- Replace the active-VERIFIED uniqueness indexes
-- ============================================================

DROP INDEX IF EXISTS idx_fd_rates_single_active_verified;

-- DAYS domain uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_fd_rates_active_verified_days
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
  WHERE status = 'VERIFIED'
    AND effective_until IS NULL
    AND tenure_domain = 'DAYS';

-- CALENDAR domain uniqueness
CREATE UNIQUE INDEX IF NOT EXISTS idx_fd_rates_active_verified_calendar
  ON fd_rates (
    bank_id,
    customer_type,
    COALESCE(min_years, -1),
    COALESCE(min_months, -1),
    COALESCE(min_days_cal, -1),
    COALESCE(min_operator::text, ''),
    COALESCE(max_years, -1),
    COALESCE(max_months, -1),
    COALESCE(max_days_cal, -1),
    COALESCE(max_operator::text, ''),
    min_deposit,
    COALESCE(max_deposit, -1::NUMERIC),
    is_callable,
    rate_category,
    COALESCE(upper(trim(scheme_name)), '')
  )
  WHERE status = 'VERIFIED'
    AND effective_until IS NULL
    AND tenure_domain = 'CALENDAR';

-- Updated conflict-domain partial index (includes tenure_domain)
DROP INDEX IF EXISTS idx_fd_rates_conflict_domain;
CREATE INDEX IF NOT EXISTS idx_fd_rates_conflict_domain
  ON fd_rates (bank_id, customer_type, is_callable, rate_category, tenure_domain, status)
  WHERE status = 'VERIFIED' AND effective_until IS NULL;


-- ============================================================
-- Step 7 -- Recreate verified_fd_rates view with new columns
-- Preserves security_invoker=true, VERIFIED-only, ACTIVE banks,
-- effective-date filter, and all existing public columns.
-- ============================================================

DROP VIEW IF EXISTS verified_fd_rates;

CREATE VIEW verified_fd_rates
  WITH (security_invoker = true)
AS
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
    r.review_notes,
    r.rate_category,
    r.scheme_name,
    -- Migration 009 additions
    r.tenure_domain,
    r.source_tenure_text,
    r.min_years,
    r.min_months,
    r.min_days_cal,
    r.min_operator,
    r.max_years,
    r.max_months,
    r.max_days_cal,
    r.max_operator
  FROM fd_rates r
  JOIN banks b ON b.id = r.bank_id
  WHERE
    r.status = 'VERIFIED'
    AND b.status = 'ACTIVE'
    AND (r.effective_until IS NULL OR r.effective_until > now());


-- ============================================================
-- Step 8 -- Calendar overlap helpers
--
-- _cal_tuple_cmp: compare two (months, days) tuples.
-- _calendar_ranges_overlap: symbolic overlap detection.
--
-- No PostgreSQL interval comparison.
-- No daterange.
-- No fixed anchor dates.
-- ============================================================

CREATE OR REPLACE FUNCTION _cal_tuple_cmp(
  a_months  INTEGER,
  a_days    INTEGER,
  b_months  INTEGER,
  b_days    INTEGER
)
RETURNS INTEGER AS $$
BEGIN
  IF    a_months < b_months THEN RETURN -1;
  ELSIF a_months > b_months THEN RETURN  1;
  ELSIF a_days   < b_days   THEN RETURN -1;
  ELSIF a_days   > b_days   THEN RETURN  1;
  ELSE                           RETURN  0;
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;


CREATE OR REPLACE FUNCTION _calendar_ranges_overlap(
  a_min_months  INTEGER,
  a_min_days    INTEGER,
  a_min_op      boundary_op,
  a_max_months  INTEGER,
  a_max_days    INTEGER,
  a_max_op      boundary_op,
  b_min_months  INTEGER,
  b_min_days    INTEGER,
  b_min_op      boundary_op,
  b_max_months  INTEGER,
  b_max_days    INTEGER,
  b_max_op      boundary_op
)
RETURNS BOOLEAN AS $$
DECLARE
  cmp_a_hi_vs_b_lo INTEGER;
  cmp_b_hi_vs_a_lo INTEGER;
BEGIN
  cmp_a_hi_vs_b_lo := _cal_tuple_cmp(a_max_months, a_max_days,
                                      b_min_months, b_min_days);
  IF cmp_a_hi_vs_b_lo < 0 THEN
    RETURN FALSE;
  END IF;
  IF cmp_a_hi_vs_b_lo = 0
     AND (a_max_op = 'LT' OR b_min_op = 'GT') THEN
    RETURN FALSE;
  END IF;

  cmp_b_hi_vs_a_lo := _cal_tuple_cmp(b_max_months, b_max_days,
                                      a_min_months, a_min_days);
  IF cmp_b_hi_vs_a_lo < 0 THEN
    RETURN FALSE;
  END IF;
  IF cmp_b_hi_vs_a_lo = 0
     AND (b_max_op = 'LT' OR a_min_op = 'GT') THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;


-- ============================================================
-- Step 9 -- Replace transition_rate_status()
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
  v_domain_str    TEXT;
  v_lock_key      BIGINT;
  v_bank_id       UUID;
  v_customer_type customer_type;
  v_is_callable   BOOLEAN;
  v_rate_category rate_category;
  v_scheme_name   TEXT;
  v_tenure_domain tenure_domain;
  v_pre_scheme    TEXT;
  v_post_scheme   TEXT;
  v_conflict_id   UUID;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  IF p_new_status = 'VERIFIED' THEN

    SELECT bank_id, customer_type, is_callable, rate_category, scheme_name, tenure_domain
      INTO v_bank_id, v_customer_type, v_is_callable, v_rate_category, v_scheme_name, v_tenure_domain
      FROM fd_rates WHERE id = p_rate_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Rate % not found', p_rate_id;
    END IF;

    v_domain_str :=
        v_bank_id::text        || CHR(1) ||
        v_customer_type::text  || CHR(1) ||
        v_is_callable::text    || CHR(1) ||
        v_rate_category::text  || CHR(1) ||
        v_tenure_domain::text  || CHR(1) ||
        CASE
          WHEN v_rate_category = 'SPECIAL_SCHEME'
          THEN upper(trim(COALESCE(v_scheme_name, '')))
          ELSE ''
        END;

    v_lock_key := ('x' || substr(md5(v_domain_str), 1, 16))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(v_lock_key);

  END IF;

  SELECT * INTO v_rate FROM fd_rates WHERE id = p_rate_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Rate % not found', p_rate_id;
  END IF;

  -- FIX 2: Domain-change guard (includes tenure_domain)
  IF p_new_status = 'VERIFIED' THEN
    v_pre_scheme  := CASE WHEN v_rate_category      = 'SPECIAL_SCHEME'
                          THEN upper(trim(COALESCE(v_scheme_name,      '')))
                          ELSE '' END;
    v_post_scheme := CASE WHEN v_rate.rate_category = 'SPECIAL_SCHEME'
                          THEN upper(trim(COALESCE(v_rate.scheme_name, '')))
                          ELSE '' END;

    IF  v_rate.bank_id         IS DISTINCT FROM v_bank_id
     OR v_rate.customer_type   IS DISTINCT FROM v_customer_type
     OR v_rate.is_callable     IS DISTINCT FROM v_is_callable
     OR v_rate.rate_category   IS DISTINCT FROM v_rate_category
     OR v_rate.tenure_domain   IS DISTINCT FROM v_tenure_domain
     OR v_post_scheme          IS DISTINCT FROM v_pre_scheme
    THEN
      RAISE EXCEPTION
        'Conflict domain changed concurrently during verification; retry. '
        'Rate % domain fields mutated between advisory-lock read and row lock.',
        p_rate_id;
    END IF;
  END IF;

  v_old_status := v_rate.status;

  IF NOT (
       (v_old_status = 'DRAFT'     AND p_new_status IN ('IN_REVIEW', 'REJECTED'))
    OR (v_old_status = 'IN_REVIEW' AND p_new_status IN ('VERIFIED', 'REJECTED', 'DRAFT'))
    OR (v_old_status = 'VERIFIED'  AND p_new_status = 'ARCHIVED')
    OR (v_old_status = 'REJECTED'  AND p_new_status = 'DRAFT')
  ) THEN
    RAISE EXCEPTION 'Illegal status transition: % to %', v_old_status, p_new_status;
  END IF;

  IF p_new_status = 'VERIFIED' THEN

    -- Cross-domain conflict: DAYS vs CALENDAR
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
       AND c.tenure_domain  <> v_rate.tenure_domain
       AND (c.max_deposit IS NULL OR c.max_deposit >= v_rate.min_deposit)
       AND (v_rate.max_deposit IS NULL OR v_rate.max_deposit >= c.min_deposit)
    LIMIT 1;

    IF FOUND THEN
      RAISE EXCEPTION
        'Cross-domain conflict: active VERIFIED rate % uses a different tenure domain '
        'from this rate. Automatic verification across DAYS/CALENDAR domains is prohibited. '
        'Use POST /api/admin/rates/<id>/supersede with old_rate_id=% to replace explicitly.',
        v_conflict_id, v_conflict_id;
    END IF;

    -- DAYS vs DAYS overlap
    IF v_rate.tenure_domain = 'DAYS' THEN
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
         AND c.tenure_domain   = 'DAYS'
         AND c.min_tenure_days  <= v_rate.max_tenure_days
         AND v_rate.min_tenure_days <= c.max_tenure_days
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

    -- CALENDAR vs CALENDAR symbolic overlap
    IF v_rate.tenure_domain = 'CALENDAR' THEN
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
         AND c.tenure_domain   = 'CALENDAR'
         AND _calendar_ranges_overlap(
               COALESCE(v_rate.min_years, 0) * 12 + COALESCE(v_rate.min_months, 0),
               COALESCE(v_rate.min_days_cal, 0),
               COALESCE(v_rate.min_operator, 'GTE'),
               COALESCE(v_rate.max_years, 0) * 12 + COALESCE(v_rate.max_months, 0),
               COALESCE(v_rate.max_days_cal, 0),
               COALESCE(v_rate.max_operator, 'LTE'),
               COALESCE(c.min_years, 0) * 12 + COALESCE(c.min_months, 0),
               COALESCE(c.min_days_cal, 0),
               COALESCE(c.min_operator, 'GTE'),
               COALESCE(c.max_years, 0) * 12 + COALESCE(c.max_months, 0),
               COALESCE(c.max_days_cal, 0),
               COALESCE(c.max_operator, 'LTE')
             )
         AND (c.max_deposit IS NULL OR c.max_deposit >= v_rate.min_deposit)
         AND (v_rate.max_deposit IS NULL OR v_rate.max_deposit >= c.min_deposit)
      LIMIT 1;

      IF FOUND THEN
        RAISE EXCEPTION
          'Overlap conflict: active VERIFIED rate % overlaps this rate in '
          'calendar tenure and/or deposit range. Use POST /api/admin/rates/<id>/supersede with '
          'old_rate_id=% to replace it explicitly.',
          v_conflict_id, v_conflict_id;
      END IF;
    END IF;

  END IF;

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
-- Step 10 -- Replace archive_and_supersede()
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
  v_tenure_domain tenure_domain;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Access denied: Admin or Reviewer privileges required';
  END IF;

  SELECT bank_id, customer_type, is_callable, rate_category, scheme_name, tenure_domain
    INTO v_bank_id, v_customer_type, v_is_callable, v_rate_category, v_scheme_name, v_tenure_domain
    FROM fd_rates WHERE id = p_new_rate_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'New rate % not found', p_new_rate_id;
  END IF;

  v_domain_str :=
      v_bank_id::text        || CHR(1) ||
      v_customer_type::text  || CHR(1) ||
      v_is_callable::text    || CHR(1) ||
      v_rate_category::text  || CHR(1) ||
      v_tenure_domain::text  || CHR(1) ||
      CASE
        WHEN v_rate_category = 'SPECIAL_SCHEME'
        THEN upper(trim(COALESCE(v_scheme_name, '')))
        ELSE ''
      END;

  v_lock_key := ('x' || substr(md5(v_domain_str), 1, 16))::bit(64)::bigint;
  PERFORM pg_advisory_xact_lock(v_lock_key);

  PERFORM 1 FROM fd_rates
   WHERE id = p_old_rate_id
     AND status = 'VERIFIED'
     AND effective_until IS NOT NULL;

  IF FOUND THEN
    RAISE EXCEPTION
      'Old rate % has effective_until set -- it is already expired and cannot be superseded.',
      p_old_rate_id;
  END IF;

  UPDATE fd_rates
     SET status          = 'ARCHIVED',
         effective_until = p_effective_at,
         updated_at      = now()
   WHERE id              = p_old_rate_id
     AND status          = 'VERIFIED'
     AND effective_until IS NULL
  RETURNING * INTO v_old;

  IF NOT FOUND THEN
    PERFORM 1 FROM fd_rates WHERE id = p_old_rate_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Old rate % not found', p_old_rate_id;
    ELSE
      RAISE EXCEPTION
        'Old rate % is not an active VERIFIED rate (status or effective_until mismatch) '
        '-- cannot supersede.',
        p_old_rate_id;
    END IF;
  END IF;

  -- DB-level domain-compatibility checks (FIX 3 + Migration 009)

  IF v_old.bank_id IS DISTINCT FROM v_bank_id THEN
    RAISE EXCEPTION
      'Bank mismatch: old rate % belongs to bank %, but new rate % belongs to bank %.',
      p_old_rate_id, v_old.bank_id, p_new_rate_id, v_bank_id;
  END IF;

  IF v_old.customer_type IS DISTINCT FROM v_customer_type THEN
    RAISE EXCEPTION
      'Customer-type mismatch: old rate % has %, new rate % has %.',
      p_old_rate_id, v_old.customer_type, p_new_rate_id, v_customer_type;
  END IF;

  IF v_old.is_callable IS DISTINCT FROM v_is_callable THEN
    RAISE EXCEPTION
      'is_callable mismatch: old rate % is %, new rate % is %.',
      p_old_rate_id, v_old.is_callable, p_new_rate_id, v_is_callable;
  END IF;

  IF v_old.rate_category IS DISTINCT FROM v_rate_category THEN
    RAISE EXCEPTION
      'rate_category mismatch: old rate % is %, new rate % is %.',
      p_old_rate_id, v_old.rate_category, p_new_rate_id, v_rate_category;
  END IF;

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

  -- Migration 009: tenure_domain must match
  IF v_old.tenure_domain IS DISTINCT FROM v_tenure_domain THEN
    RAISE EXCEPTION
      'tenure_domain mismatch: old rate % is %, new rate % is %. '
      'Cannot supersede across tenure domains.',
      p_old_rate_id, v_old.tenure_domain, p_new_rate_id, v_tenure_domain;
  END IF;

  INSERT INTO rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
  VALUES (
    p_old_rate_id, 'ARCHIVE',
    jsonb_build_object('status', 'VERIFIED'),
    jsonb_build_object('status', 'ARCHIVED', 'effective_until', p_effective_at),
    p_performed_by,
    COALESCE(p_notes, 'Superseded by rate ' || p_new_rate_id)
  );

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
-- Privilege hardening (idempotent)
-- ============================================================

REVOKE EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION transition_rate_status(UUID, rate_status, UUID, TEXT)
  TO service_role;

REVOKE EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION archive_and_supersede(UUID, UUID, UUID, TIMESTAMPTZ, TEXT)
  TO service_role;

REVOKE EXECUTE ON FUNCTION _cal_tuple_cmp(INTEGER, INTEGER, INTEGER, INTEGER)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION _calendar_ranges_overlap(
  INTEGER, INTEGER, boundary_op, INTEGER, INTEGER, boundary_op,
  INTEGER, INTEGER, boundary_op, INTEGER, INTEGER, boundary_op)
  FROM PUBLIC, anon, authenticated;
