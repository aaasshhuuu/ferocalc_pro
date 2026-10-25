-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 016 Staging Precheck Suite (Read-Only)
--
-- STATUS: READ-ONLY PRECHECK / NOT EXECUTED
-- TARGET PROJECT: cqrslxngpwbtkjejlwty (STAGING ONLY)
-- PRODUCTION PROJECT (STRICTLY PROHIBITED): pmaykclwuyspxhgeomee
--
-- Instructions:
-- Execute these queries in the Supabase SQL Editor for staging project:
-- https://supabase.com/dashboard/project/cqrslxngpwbtkjejlwty/sql
--
-- Safety Guarantee:
-- Contains STRICTLY SELECT-only statements.
-- Zero INSERT, UPDATE, DELETE, UPSERT, DDL, or state-mutating calls.
-- ============================================================

-- ------------------------------------------------------------
-- Check 0: Verify Target Database & User Environment
-- Expected: PostgreSQL on Supabase staging project
-- ------------------------------------------------------------
SELECT
  current_database() AS db_name,
  current_user AS user_name,
  version() AS pg_version;

-- ------------------------------------------------------------
-- Check 1: Verify Migration 015 Check Constraints
-- Expected: Both constraints present on staged_rate_candidates
--   1. staged_rates_scheme_name_required
--   2. staged_rates_scheme_name_standard_null
-- ------------------------------------------------------------
SELECT 
  conname AS constraint_name, 
  pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE c.conrelid = 'staged_rate_candidates'::regclass
  AND conname IN (
    'staged_rates_scheme_name_required',
    'staged_rates_scheme_name_standard_null'
  )
ORDER BY conname;

-- ------------------------------------------------------------
-- Check 2: Verify Migration 015 Index Exists
-- Expected: 1 row returned for idx_staged_rates_category
-- ------------------------------------------------------------
SELECT 
  indexname, 
  indexdef
FROM pg_indexes
WHERE tablename = 'staged_rate_candidates'
  AND indexname = 'idx_staged_rates_category';

-- ------------------------------------------------------------
-- Check 3: Verify Exact Staging Table Columns & Types for Proposed Index
-- Expected: Exactly 11 rows returned with matching data types
-- ------------------------------------------------------------
SELECT 
  column_name, 
  data_type, 
  udt_name, 
  is_nullable, 
  column_default
FROM information_schema.columns
WHERE table_name = 'staged_rate_candidates'
  AND column_name IN (
    'bank_code',
    'product_type',
    'customer_type',
    'min_tenure_days',
    'max_tenure_days',
    'min_deposit',
    'max_deposit',
    'is_callable',
    'rate_category',
    'scheme_name',
    'staging_status'
  )
ORDER BY column_name;

-- ------------------------------------------------------------
-- Check 4: Duplicate Active Identity Detection
-- (Exact expressions, NULLS NOT DISTINCT semantics, and predicate proposed in Migration 016)
-- Expected: 0 rows returned (Zero duplicate active identities)
-- Fail-Closed: If count > 0, STOP IMMEDIATELY. Migration 016 cannot proceed.
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
FROM staged_rate_candidates
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
-- Check 5: Baseline Table & View Counts Verification
-- Expected:
--   baseline_source_attestations: 0
--   fd_rates: 1 (draft seed row)
--   rate_sources: 5 (3 enabled, 2 disabled)
--   staged_rate_candidates: 0 (or historical clean state)
--   verified_fd_rates (view): 0 (zero public verified rates)
-- ------------------------------------------------------------
SELECT 'staged_rate_candidates' AS entity_name, count(*) AS observed_count FROM staged_rate_candidates
UNION ALL
SELECT 'baseline_source_attestations' AS entity_name, count(*) AS observed_count FROM baseline_source_attestations
UNION ALL
SELECT 'rate_sources' AS entity_name, count(*) AS observed_count FROM rate_sources
UNION ALL
SELECT 'fd_rates' AS entity_name, count(*) AS observed_count FROM fd_rates
UNION ALL
SELECT 'verified_fd_rates (view)' AS entity_name, count(*) AS observed_count FROM verified_fd_rates
ORDER BY entity_name;

-- ------------------------------------------------------------
-- Check 6: Verify Existing Staging Draft Row in fd_rates
-- Expected: Exactly 1 row with id = 'b8a85f4e-f324-44a6-a6a8-8ef5e6419297'
-- ------------------------------------------------------------
SELECT 
  id,
  bank_id,
  customer_type,
  min_tenure_days,
  max_tenure_days,
  interest_rate,
  is_callable,
  status,
  rate_category,
  scheme_name,
  review_notes
FROM fd_rates
WHERE id = 'b8a85f4e-f324-44a6-a6a8-8ef5e6419297';

-- ------------------------------------------------------------
-- Check 7: Verify Proposed Index Name Availability Across Target Schema
-- (Detects any relation/index in schema 'public' with the proposed name,
-- preventing hidden collisions that 'CREATE ... IF NOT EXISTS' would bypass)
-- Expected: 0 rows returned (Zero name collisions across the target schema)
-- Fail-Closed: If any row is returned, STOP IMMEDIATELY.
--   A collision requires human investigation and separate authorization;
--   never automatically DROP a conflicting relation.
-- ------------------------------------------------------------
SELECT 
  n.nspname AS schema_name,
  c.relname AS relation_name,
  c.relkind AS relation_kind,
  CASE c.relkind
    WHEN 'r' THEN 'table'
    WHEN 'i' THEN 'index'
    WHEN 'S' THEN 'sequence'
    WHEN 't' THEN 'toast_table'
    WHEN 'v' THEN 'view'
    WHEN 'm' THEN 'materialized_view'
    WHEN 'c' THEN 'composite_type'
    WHEN 'f' THEN 'foreign_table'
    WHEN 'p' THEN 'partitioned_table'
    WHEN 'I' THEN 'partitioned_index'
    ELSE c.relkind::text
  END AS relation_kind_desc,
  COALESCE(t.relname, '') AS parent_table,
  COALESCE(pg_get_indexdef(c.oid), '') AS index_definition
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_index i ON i.indexrelid = c.oid
LEFT JOIN pg_class t ON t.oid = i.indrelid
WHERE n.nspname = 'public'
  AND c.relname = 'idx_staged_candidates_active_identity';
