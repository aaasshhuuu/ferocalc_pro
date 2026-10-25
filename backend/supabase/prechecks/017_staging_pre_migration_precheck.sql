-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 017 Staging Pre-Migration Precheck Suite (Read-Only)
--
-- STATUS: READ-ONLY PRECHECK / OFFLINE PREPARATION ONLY
-- TARGET PROJECT: cqrslxngpwbtkjejlwty (STAGING ONLY)
-- PRODUCTION PROJECT (STRICTLY PROHIBITED): pmaykclwuyspxhgeomee
--
-- Instructions:
-- Execute these queries in the Supabase SQL Editor for staging project:
-- https://supabase.com/dashboard/project/cqrslxngpwbtkjejlwty/sql
--
-- Operational Scope:
-- This script evaluates the target database state IMMEDIATELY BEFORE applying
-- Migration 017 (017_calendar_aware_candidate_staging.sql).
--
-- Safety Guarantee:
-- Contains STRICTLY SELECT-only statements.
-- Zero INSERT, UPDATE, DELETE, UPSERT, ALTER, DROP, CREATE, DDL, or state mutations.
--
-- Stop-and-Inspect Rule:
-- If ANY query returns a result diverging from the "Expected" annotation,
-- STOP IMMEDIATELY. Do not proceed with migration execution.
-- ============================================================

-- ------------------------------------------------------------
-- Check 0: Verify Target Database & User Environment
-- Expected: PostgreSQL on Supabase staging project ref 'cqrslxngpwbtkjejlwty'
-- Prohibited: Any connection string or database for 'pmaykclwuyspxhgeomee'
-- ------------------------------------------------------------
SELECT
  current_database() AS db_name,
  current_user AS user_name,
  version() AS pg_version;

-- ------------------------------------------------------------
-- Check 1: Verify Prerequisite Enums from Migrations 001, 009, 011, 012, 015
-- Expected: Exactly 6 rows returned:
--   1. boundary_op (from Migration 009)
--   2. compounding_frequency (from Migration 001)
--   3. customer_type (from Migration 001)
--   4. rate_category (from Migration 001 / 012)
--   5. staging_candidate_status (from Migration 011 / 012)
--   6. tenure_domain (from Migration 009)
-- Fail-Closed: If 'tenure_domain' or 'boundary_op' is missing, STOP.
--   Migration 017 requires these enums to add calendar columns.
-- ------------------------------------------------------------
SELECT
  typname AS enum_name,
  array_agg(enumlabel ORDER BY enumsortorder) AS enum_values
FROM pg_enum e
JOIN pg_type t ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname IN (
    'boundary_op',
    'compounding_frequency',
    'customer_type',
    'rate_category',
    'staging_candidate_status',
    'tenure_domain'
  )
GROUP BY t.typname
ORDER BY t.typname;

-- ------------------------------------------------------------
-- Check 2: Verify Baseline Table Existence
-- Expected: Exactly 1 row for 'staged_rate_candidates' in schema 'public'
-- ------------------------------------------------------------
SELECT
  schemaname,
  tablename,
  tableowner
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'staged_rate_candidates';

-- ------------------------------------------------------------
-- Check 3: Verify Baseline Table Columns (Pre-Migration State)
-- Expected: Exactly 11 baseline candidate columns present:
--   bank_code, customer_type, is_callable, max_deposit, max_tenure_days,
--   min_deposit, min_tenure_days, product_type, rate_category, scheme_name, staging_status
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
    'bank_code',
    'customer_type',
    'is_callable',
    'max_deposit',
    'max_tenure_days',
    'min_deposit',
    'min_tenure_days',
    'product_type',
    'rate_category',
    'scheme_name',
    'staging_status'
  )
ORDER BY column_name;

-- ------------------------------------------------------------
-- Check 4: Confirm Calendar Columns Do NOT Already Exist
-- Expected: 0 rows returned.
-- Fail-Closed: If any of these columns already exist, the schema has been
--   partially migrated or drifted. STOP IMMEDIATELY for investigation.
-- ------------------------------------------------------------
SELECT
  column_name,
  data_type,
  udt_name
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
-- Check 5: Verify Legacy Constraints on staged_rate_candidates
-- Expected:
--   - staged_rates_tenure_min_positive (min_tenure_days > 0)
--   - staged_rates_tenure_max_gte_min (max_tenure_days >= min_tenure_days)
--   - staged_rates_scheme_name_required (Migration 015)
--   - staged_rates_scheme_name_standard_null (Migration 015)
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
    'staged_rates_tenure_max_gte_min',
    'staged_rates_scheme_name_required',
    'staged_rates_scheme_name_standard_null'
  )
ORDER BY conname;

-- ------------------------------------------------------------
-- Check 6: Verify Legacy Index State (idx_staged_candidates_active_identity)
-- Expected:
--   - If Migration 016 was previously applied/rehearsed: 1 row returned.
--     (Migration 017 Step 5 will drop it via DROP INDEX IF EXISTS).
--   - If Migration 016 was never applied: 0 rows returned.
--     (Migration 017 Step 5 DROP INDEX IF EXISTS will be a harmless no-op).
-- Operator Action: Record whether 0 or 1 row is returned in the DBA packet.
-- ------------------------------------------------------------
SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'staged_rate_candidates'
  AND indexname = 'idx_staged_candidates_active_identity';

-- ------------------------------------------------------------
-- Check 7: Verify Proposed New Index Names Are Available (Zero Collisions)
-- (Detects any index or relation in 'public' with either replacement index name)
-- Expected: 0 rows returned.
-- Fail-Closed: If any row is returned, STOP IMMEDIATELY.
--   An existing relation with either name requires manual investigation.
-- ------------------------------------------------------------
SELECT
  n.nspname AS schema_name,
  c.relname AS relation_name,
  c.relkind AS relation_kind,
  CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized_view'
    ELSE c.relkind::text
  END AS relation_kind_desc
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'idx_staged_candidates_active_days_identity',
    'idx_staged_candidates_active_calendar_identity'
  );

-- ------------------------------------------------------------
-- Check 8: Active Candidate Duplicate Detection (Baseline Schema Columns Only)
-- Evaluates the exact duplicate assertion logic executed in Migration 017 Step 2,
-- using ONLY columns present in the baseline schema.
-- Expected: 0 rows returned (Zero duplicate active identities).
-- Fail-Closed: If count > 0, STOP IMMEDIATELY.
--   Migration 017 Step 2 DO block will fail closed and abort transaction if count > 0.
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
  array_agg(id) AS candidate_ids,
  array_agg(staging_status::text) AS statuses
FROM public.staged_rate_candidates
WHERE staging_status IN ('DRAFT', 'IN_REVIEW')
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
-- Check 9: Validate Existing Data Against Proposed Day Constraints
-- Verifies that all existing rows satisfy:
--   min_tenure_days > 0 AND max_tenure_days >= min_tenure_days
-- and neither column is NULL, ensuring the new DAYS constraint will pass.
-- Expected: 0 rows returned.
-- ------------------------------------------------------------
SELECT
  id,
  bank_code,
  product_type,
  customer_type,
  min_tenure_days,
  max_tenure_days,
  staging_status
FROM public.staged_rate_candidates
WHERE min_tenure_days IS NULL
   OR max_tenure_days IS NULL
   OR min_tenure_days <= 0
   OR max_tenure_days < min_tenure_days;

-- ------------------------------------------------------------
-- Check 10: Baseline Entity Row Counts Summary
-- Expected:
--   rate_sources: >= 3
--   fd_rates: >= 1 (seed/active rates)
--   staged_rate_candidates: count recorded by DBA
-- ------------------------------------------------------------
SELECT 'rate_sources' AS entity_name, count(*) AS observed_count FROM public.rate_sources
UNION ALL
SELECT 'fd_rates' AS entity_name, count(*) AS observed_count FROM public.fd_rates
UNION ALL
SELECT 'staged_rate_candidates' AS entity_name, count(*) AS observed_count FROM public.staged_rate_candidates
ORDER BY entity_name;
