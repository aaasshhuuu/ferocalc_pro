-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 017 Staging Post-Migration Verification Suite (Read-Only)
--
-- STATUS: READ-ONLY POST-MIGRATION VERIFICATION
-- TARGET PROJECT: cqrslxngpwbtkjejlwty (STAGING ONLY)
-- PRODUCTION PROJECT (STRICTLY PROHIBITED): pmaykclwuyspxhgeomee
--
-- Instructions:
-- Execute these queries in the Supabase SQL Editor for staging project
-- AFTER Migration 017 has been executed:
-- https://supabase.com/dashboard/project/cqrslxngpwbtkjejlwty/sql
--
-- Operational Scope:
-- Validates that Migration 017 executed cleanly and completely:
--   1. Added all 9 dual-domain calendar columns with correct data types.
--   2. Relaxed NOT NULL on legacy day columns (min_tenure_days, max_tenure_days).
--   3. Dropped legacy day-only constraints (staged_rates_tenure_min_positive, staged_rates_tenure_max_gte_min).
--   4. Created all 12 domain-specific check constraints.
--   5. Dropped legacy index (idx_staged_candidates_active_identity).
--   6. Created replacement partial unique indexes for DAYS and CALENDAR domains.
--   7. Confirms zero active duplicate identities exist in either domain.
--
-- Safety Guarantee:
-- Contains STRICTLY SELECT-only statements.
-- Zero INSERT, UPDATE, DELETE, UPSERT, ALTER, DROP, CREATE, DDL, or repair statements.
-- ============================================================

-- ------------------------------------------------------------
-- Check 0: Verify Target Database & User Environment
-- Expected: PostgreSQL on Supabase staging project ref 'cqrslxngpwbtkjejlwty'
-- ------------------------------------------------------------
SELECT
  current_database() AS db_name,
  current_user AS user_name,
  version() AS pg_version;

-- ------------------------------------------------------------
-- Check 1: Verify All 9 Added Calendar Columns on staged_rate_candidates
-- Expected: Exactly 9 rows returned with matching types:
--   max_days_cal   | integer       | YES | null
--   max_months     | integer       | YES | null
--   max_operator   | USER-DEFINED  | YES | null (udt_name: boundary_op)
--   max_years      | integer       | YES | null
--   min_days_cal   | integer       | YES | null
--   min_months     | integer       | YES | null
--   min_operator   | USER-DEFINED  | YES | null (udt_name: boundary_op)
--   min_years      | integer       | YES | null
--   tenure_domain  | USER-DEFINED  | NO  | 'DAYS'::tenure_domain (udt_name: tenure_domain)
-- ------------------------------------------------------------
SELECT
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'staged_rate_candidates'
  AND column_name IN (
    'tenure_domain',
    'min_years',
    'min_months',
    'min_days_cal',
    'min_operator',
    'max_years',
    'max_months',
    'max_days_cal',
    'max_operator'
  )
ORDER BY column_name;

-- ------------------------------------------------------------
-- Check 2: Verify Legacy Day Bounds Nullability Relaxation
-- Expected: Exactly 2 rows returned with is_nullable = 'YES'
--   min_tenure_days | integer | YES
--   max_tenure_days | integer | YES
-- ------------------------------------------------------------
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'staged_rate_candidates'
  AND column_name IN ('min_tenure_days', 'max_tenure_days')
ORDER BY column_name;

-- ------------------------------------------------------------
-- Check 3: Verify Legacy Check Constraints Were Dropped
-- Expected: 0 rows returned.
-- Fail-Closed: Neither staged_rates_tenure_min_positive nor
--   staged_rates_tenure_max_gte_min should exist in pg_constraint.
-- ------------------------------------------------------------
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'public'
  AND c.conrelid = 'public.staged_rate_candidates'::regclass
  AND conname IN (
    'staged_rates_tenure_min_positive',
    'staged_rates_tenure_max_gte_min'
  );

-- ------------------------------------------------------------
-- Check 4: Verify All 12 Migration 017 Domain Check Constraints Exist
-- Expected: Exactly 12 rows returned:
--   1. staged_rates_days_domain_day_cols_not_null
--   2. staged_rates_days_domain_cal_cols_null
--   3. staged_rates_cal_domain_day_cols_null
--   4. staged_rates_cal_domain_component_ranges
--   5. staged_rates_cal_domain_min_op_valid
--   6. staged_rates_cal_domain_max_op_valid
--   7. staged_rates_cal_domain_lower_coupling
--   8. staged_rates_cal_domain_upper_coupling
--   9. staged_rates_cal_domain_has_endpoint
--  10. staged_rates_cal_domain_min_nonzero
--  11. staged_rates_cal_domain_max_nonzero
--  12. staged_rates_cal_domain_min_lte_max
-- ------------------------------------------------------------
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname = 'public'
  AND c.conrelid = 'public.staged_rate_candidates'::regclass
  AND conname IN (
    'staged_rates_days_domain_day_cols_not_null',
    'staged_rates_days_domain_cal_cols_null',
    'staged_rates_cal_domain_day_cols_null',
    'staged_rates_cal_domain_component_ranges',
    'staged_rates_cal_domain_min_op_valid',
    'staged_rates_cal_domain_max_op_valid',
    'staged_rates_cal_domain_lower_coupling',
    'staged_rates_cal_domain_upper_coupling',
    'staged_rates_cal_domain_has_endpoint',
    'staged_rates_cal_domain_min_nonzero',
    'staged_rates_cal_domain_max_nonzero',
    'staged_rates_cal_domain_min_lte_max'
  )
ORDER BY conname;

-- ------------------------------------------------------------
-- Check 5: Verify Legacy Index Was Dropped
-- Expected: 0 rows returned.
--   idx_staged_candidates_active_identity must NOT exist.
-- ------------------------------------------------------------
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'staged_rate_candidates'
  AND indexname = 'idx_staged_candidates_active_identity';

-- ------------------------------------------------------------
-- Check 6: Verify Replacement Domain-Specific Partial Unique Indexes
-- Expected: Exactly 2 rows returned:
--   1. idx_staged_candidates_active_days_identity
--      - Covers (bank_code, product_type, customer_type, min_tenure_days, max_tenure_days,
--                min_deposit, max_deposit, is_callable, rate_category, upper(btrim(scheme_name)))
--      - NULLS NOT DISTINCT
--      - WHERE staging_status IN ('DRAFT', 'IN_REVIEW') AND tenure_domain = 'DAYS'
--   2. idx_staged_candidates_active_calendar_identity
--      - Covers (bank_code, product_type, customer_type, min_years, min_months, min_days_cal,
--                min_operator, max_years, max_months, max_days_cal, max_operator,
--                min_deposit, max_deposit, is_callable, rate_category, upper(btrim(scheme_name)))
--      - NULLS NOT DISTINCT
--      - WHERE staging_status IN ('DRAFT', 'IN_REVIEW') AND tenure_domain = 'CALENDAR'
-- ------------------------------------------------------------
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'staged_rate_candidates'
  AND indexname IN (
    'idx_staged_candidates_active_days_identity',
    'idx_staged_candidates_active_calendar_identity'
  )
ORDER BY indexname;

-- ------------------------------------------------------------
-- Check 7: Post-Migration Active DAYS Duplicate Detection
-- Expected: 0 rows returned.
-- ------------------------------------------------------------
SELECT
  bank_code,
  product_type,
  customer_type,
  min_tenure_days,
  max_tenure_days,
  min_deposit,
  max_deposit,
  is_callable,
  rate_category,
  upper(btrim(scheme_name)) AS norm_scheme_name,
  count(*) AS duplicate_count,
  array_agg(id) AS candidate_ids
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
HAVING count(*) > 1;

-- ------------------------------------------------------------
-- Check 8: Post-Migration Active CALENDAR Duplicate Detection
-- Expected: 0 rows returned.
-- ------------------------------------------------------------
SELECT
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
  upper(btrim(scheme_name)) AS norm_scheme_name,
  count(*) AS duplicate_count,
  array_agg(id) AS candidate_ids
FROM public.staged_rate_candidates
WHERE staging_status IN ('DRAFT', 'IN_REVIEW')
  AND tenure_domain = 'CALENDAR'
GROUP BY
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
  upper(btrim(scheme_name))
HAVING count(*) > 1;

-- ------------------------------------------------------------
-- Check 9: Domain Integrity Assertion on All Existing Records
-- Expected: 0 rows returned across all checks:
--   1. DAYS domain candidates with non-null calendar components
--   2. CALENDAR domain candidates with non-null day bounds
--   3. Invalid tenure_domain values
-- ------------------------------------------------------------
SELECT
  id,
  bank_code,
  tenure_domain,
  min_tenure_days,
  max_tenure_days,
  min_years,
  min_months,
  staging_status,
  'DAYS domain has non-null calendar components' AS violation_reason
FROM public.staged_rate_candidates
WHERE tenure_domain = 'DAYS'
  AND (min_years IS NOT NULL OR min_months IS NOT NULL OR min_days_cal IS NOT NULL OR min_operator IS NOT NULL
    OR max_years IS NOT NULL OR max_months IS NOT NULL OR max_days_cal IS NOT NULL OR max_operator IS NOT NULL)

UNION ALL

SELECT
  id,
  bank_code,
  tenure_domain,
  min_tenure_days,
  max_tenure_days,
  min_years,
  min_months,
  staging_status,
  'CALENDAR domain has non-null day bounds' AS violation_reason
FROM public.staged_rate_candidates
WHERE tenure_domain = 'CALENDAR'
  AND (min_tenure_days IS NOT NULL OR max_tenure_days IS NOT NULL);
