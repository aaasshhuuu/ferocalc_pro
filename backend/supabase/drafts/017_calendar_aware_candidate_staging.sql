-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 017: Calendar-Aware Candidate Staging & Uniqueness
--
-- STATUS: DRAFT / NOT EXECUTED
-- DO NOT APPLY WITHOUT EXPLICIT OPERATOR AUTHORIZATION.
--
-- Objectives:
-- 1. Add dual-domain tenure support (DAYS and CALENDAR) to staged_rate_candidates,
--    mirroring public.fd_rates (Migration 009).
-- 2. Relax NOT NULL constraint on min_tenure_days and max_tenure_days to allow
--    NULL for CALENDAR candidates (prohibiting synthetic day projections).
-- 3. Replace legacy active uniqueness index (Migration 016) with domain-specific
--    partial unique indexes:
--      a) idx_staged_candidates_active_days_identity (tenure_domain = 'DAYS')
--      b) idx_staged_candidates_active_calendar_identity (tenure_domain = 'CALENDAR')
-- 4. Enforce strict calendar endpoint constraints:
--      - Component bounds non-negativity and month range [0, 11]
--      - Operator-component coupling (operator cannot exist without components and vice-versa)
--      - At least one bound required
--      - Non-zero duration for specified bounds
--      - Symbolic endpoint ordering (lower <= upper, strict operators rejected if equal)
-- 5. In-transaction fail-closed preflight assertion (aborts if active DAYS duplicates exist).
-- 6. In-transaction catalog verification assertion (fails closed if replacement indexes diverge).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- STEP 1: ADD CALENDAR TENURE COLUMNS TO staged_rate_candidates
-- (tenure_domain and boundary_op enums already exist from Migration 009)
-- ------------------------------------------------------------
ALTER TABLE public.staged_rate_candidates
  ADD COLUMN IF NOT EXISTS tenure_domain tenure_domain NOT NULL DEFAULT 'DAYS',
  ADD COLUMN IF NOT EXISTS min_years INTEGER,
  ADD COLUMN IF NOT EXISTS min_months INTEGER,
  ADD COLUMN IF NOT EXISTS min_days_cal INTEGER,
  ADD COLUMN IF NOT EXISTS min_operator boundary_op,
  ADD COLUMN IF NOT EXISTS max_years INTEGER,
  ADD COLUMN IF NOT EXISTS max_months INTEGER,
  ADD COLUMN IF NOT EXISTS max_days_cal INTEGER,
  ADD COLUMN IF NOT EXISTS max_operator boundary_op;

-- ------------------------------------------------------------
-- STEP 2: IN-TRANSACTION FAIL-CLOSED DUPLICATE ASSERTION
-- (Guarantees zero active DAYS duplicate groups exist before indexing)
-- ------------------------------------------------------------
DO $$
DECLARE
  v_dup_count INTEGER;
BEGIN
  SELECT count(*) INTO v_dup_count
  FROM (
    SELECT 1
    FROM public.staged_rate_candidates
    WHERE staging_status IN ('DRAFT', 'IN_REVIEW')
      AND tenure_domain = 'DAYS'
    GROUP BY
      bank_code,
      product_type,
      customer_type,
      min_tenure_days,
      max_tenure_days,
      min_deposit,
      max_deposit,
      is_callable,
      rate_category,
      upper(btrim(scheme_name))
    HAVING count(*) > 1
  ) t;

  IF v_dup_count > 0 THEN
    RAISE EXCEPTION 'Migration 017 Aborted: Found % duplicate group(s) in active DAYS candidates. Transaction rolled back atomically.', v_dup_count
      USING ERRCODE = 'check_violation';
  END IF;
END $$;

-- ------------------------------------------------------------
-- STEP 3: RELAX NOT NULL ON LEGACY DAY BOUND COLUMNS
-- ------------------------------------------------------------
ALTER TABLE public.staged_rate_candidates
  ALTER COLUMN min_tenure_days DROP NOT NULL,
  ALTER COLUMN max_tenure_days DROP NOT NULL;

-- ------------------------------------------------------------
-- STEP 4: UPDATE TENURE DOMAIN & ENDPOINT CHECK CONSTRAINTS
-- ------------------------------------------------------------
-- Drop legacy day-only constraints from Migration 011
ALTER TABLE public.staged_rate_candidates
  DROP CONSTRAINT IF EXISTS staged_rates_tenure_min_positive,
  DROP CONSTRAINT IF EXISTS staged_rates_tenure_max_gte_min;

-- 4.1 DAYS domain: day columns must be NOT NULL and positive
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_days_domain_day_cols_not_null
    CHECK (
      tenure_domain <> 'DAYS'
      OR (
        min_tenure_days IS NOT NULL
        AND max_tenure_days IS NOT NULL
        AND min_tenure_days > 0
        AND max_tenure_days >= min_tenure_days
      )
    ),
  ADD CONSTRAINT staged_rates_days_domain_cal_cols_null
    CHECK (
      tenure_domain <> 'DAYS'
      OR (
        min_years IS NULL AND min_months IS NULL AND min_days_cal IS NULL AND min_operator IS NULL
        AND max_years IS NULL AND max_months IS NULL AND max_days_cal IS NULL AND max_operator IS NULL
      )
    );

-- 4.2 CALENDAR domain: day columns must be NULL (no synthetic day equivalents)
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_day_cols_null
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (min_tenure_days IS NULL AND max_tenure_days IS NULL)
    );

-- 4.3 CALENDAR domain: non-negative components and month range [0, 11]
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_component_ranges
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (
        (min_years IS NULL OR min_years >= 0)
        AND (min_months IS NULL OR (min_months >= 0 AND min_months <= 11))
        AND (min_days_cal IS NULL OR min_days_cal >= 0)
        AND (max_years IS NULL OR max_years >= 0)
        AND (max_months IS NULL OR (max_months >= 0 AND max_months <= 11))
        AND (max_days_cal IS NULL OR max_days_cal >= 0)
      )
    );

-- 4.4 CALENDAR domain: operator rules (lower = GTE/GT, upper = LTE/LT)
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_min_op_valid
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR min_operator IS NULL
      OR min_operator IN ('GTE', 'GT')
    ),
  ADD CONSTRAINT staged_rates_cal_domain_max_op_valid
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR max_operator IS NULL
      OR max_operator IN ('LTE', 'LT')
    );

-- 4.5 CALENDAR domain: operator-component strict coupling
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_lower_coupling
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (
        (min_operator IS NULL AND min_years IS NULL AND min_months IS NULL AND min_days_cal IS NULL)
        OR (min_operator IS NOT NULL AND (min_years IS NOT NULL OR min_months IS NOT NULL OR min_days_cal IS NOT NULL))
      )
    ),
  ADD CONSTRAINT staged_rates_cal_domain_upper_coupling
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR (
        (max_operator IS NULL AND max_years IS NULL AND max_months IS NULL AND max_days_cal IS NULL)
        OR (max_operator IS NOT NULL AND (max_years IS NOT NULL OR max_months IS NOT NULL OR max_days_cal IS NOT NULL))
      )
    );

-- 4.6 CALENDAR domain: at least one bound required
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_has_endpoint
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR min_operator IS NOT NULL
      OR max_operator IS NOT NULL
    );

-- 4.7 CALENDAR domain: non-zero bound durations
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_min_nonzero
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR min_operator IS NULL
      OR (COALESCE(min_years, 0) + COALESCE(min_months, 0) + COALESCE(min_days_cal, 0) > 0)
    ),
  ADD CONSTRAINT staged_rates_cal_domain_max_nonzero
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR max_operator IS NULL
      OR (COALESCE(max_years, 0) + COALESCE(max_months, 0) + COALESCE(max_days_cal, 0) > 0)
    );

-- 4.8 CALENDAR domain: endpoint ordering (min <= max) and non-contradictory operators
ALTER TABLE public.staged_rate_candidates
  ADD CONSTRAINT staged_rates_cal_domain_min_lte_max
    CHECK (
      tenure_domain <> 'CALENDAR'
      OR min_operator IS NULL
      OR max_operator IS NULL
      OR (
        (COALESCE(min_years, 0) * 12 + COALESCE(min_months, 0) < COALESCE(max_years, 0) * 12 + COALESCE(max_months, 0))
        OR (
          (COALESCE(min_years, 0) * 12 + COALESCE(min_months, 0) = COALESCE(max_years, 0) * 12 + COALESCE(max_months, 0))
          AND (COALESCE(min_days_cal, 0) < COALESCE(max_days_cal, 0))
        )
        OR (
          (COALESCE(min_years, 0) * 12 + COALESCE(min_months, 0) = COALESCE(max_years, 0) * 12 + COALESCE(max_months, 0))
          AND (COALESCE(min_days_cal, 0) = COALESCE(max_days_cal, 0))
          AND min_operator = 'GTE' AND max_operator = 'LTE'
        )
      )
    );

-- ------------------------------------------------------------
-- STEP 5: REPLACE MIGRATION 016 UNIQUE INDEX WITH DUAL PARTIAL INDEXES
-- ------------------------------------------------------------
-- Drop old Migration 016 index that collides on (NULL, NULL) for calendar records
DROP INDEX IF EXISTS public.idx_staged_candidates_active_identity;

-- Index 1: DAYS Domain Active Identity (Fail-closed creation without IF NOT EXISTS)
CREATE UNIQUE INDEX idx_staged_candidates_active_days_identity
  ON public.staged_rate_candidates (
    bank_code,
    product_type,
    customer_type,
    min_tenure_days,
    max_tenure_days,
    min_deposit,
    max_deposit,
    is_callable,
    rate_category,
    (upper(btrim(scheme_name)))
  )
  NULLS NOT DISTINCT
  WHERE staging_status IN ('DRAFT', 'IN_REVIEW')
    AND tenure_domain = 'DAYS';

-- Index 2: CALENDAR Domain Active Identity (Fail-closed creation without IF NOT EXISTS)
CREATE UNIQUE INDEX idx_staged_candidates_active_calendar_identity
  ON public.staged_rate_candidates (
    bank_code,
    product_type,
    customer_type,
    min_years,
    min_months,
    min_days_cal,
    min_operator,
    max_years,
    max_months,
    max_days_cal,
    max_operator,
    min_deposit,
    max_deposit,
    is_callable,
    rate_category,
    (upper(btrim(scheme_name)))
  )
  NULLS NOT DISTINCT
  WHERE staging_status IN ('DRAFT', 'IN_REVIEW')
    AND tenure_domain = 'CALENDAR';

-- ------------------------------------------------------------
-- STEP 6: IN-TRANSACTION CATALOG VERIFICATION ASSERTION
-- ------------------------------------------------------------
DO $$
DECLARE
  v_days_def TEXT;
  v_cal_def  TEXT;
BEGIN
  -- 1. Verify DAYS active uniqueness index definition
  SELECT indexdef INTO v_days_def
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename = 'staged_rate_candidates'
    AND indexname = 'idx_staged_candidates_active_days_identity';

  IF v_days_def IS NULL THEN
    RAISE EXCEPTION 'Migration 017 Aborted: public.idx_staged_candidates_active_days_identity does not exist in catalog.'
      USING ERRCODE = 'undefined_object';
  END IF;

  IF v_days_def NOT LIKE '%UNIQUE INDEX%'
     OR v_days_def NOT LIKE '%NULLS NOT DISTINCT%'
     OR v_days_def NOT LIKE '%min_tenure_days%'
     OR v_days_def NOT LIKE '%tenure_domain = ''DAYS''%' THEN
    RAISE EXCEPTION 'Migration 017 Aborted: public.idx_staged_candidates_active_days_identity definition failed catalog check. Def: %', v_days_def
      USING ERRCODE = 'check_violation';
  END IF;

  -- 2. Verify CALENDAR active uniqueness index definition
  SELECT indexdef INTO v_cal_def
  FROM pg_indexes
  WHERE schemaname = 'public'
    AND tablename = 'staged_rate_candidates'
    AND indexname = 'idx_staged_candidates_active_calendar_identity';

  IF v_cal_def IS NULL THEN
    RAISE EXCEPTION 'Migration 017 Aborted: public.idx_staged_candidates_active_calendar_identity does not exist in catalog.'
      USING ERRCODE = 'undefined_object';
  END IF;

  IF v_cal_def NOT LIKE '%UNIQUE INDEX%'
     OR v_cal_def NOT LIKE '%NULLS NOT DISTINCT%'
     OR v_cal_def NOT LIKE '%min_years%'
     OR v_cal_def NOT LIKE '%tenure_domain = ''CALENDAR''%' THEN
    RAISE EXCEPTION 'Migration 017 Aborted: public.idx_staged_candidates_active_calendar_identity definition failed catalog check. Def: %', v_cal_def
      USING ERRCODE = 'check_violation';
  END IF;
END $$;

COMMIT;
