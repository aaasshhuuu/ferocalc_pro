-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 016: Database-Enforced Candidate Uniqueness on Active Staging
--
-- STATUS: DRAFT / NOT EXECUTED
-- DO NOT APPLY WITHOUT EXPLICIT HUMAN AUTHORIZATION.
--
-- Objective:
-- Enforce database-level candidate uniqueness on staged_rate_candidates
-- for active candidates (DRAFT and IN_REVIEW) using business identity fields.
-- Prevents duplicate insertions from uncoordinated runners, concurrent jobs,
-- direct SQL, or expired process leases.
--
-- Candidate Business Identity:
--   bank_code
--   product_type
--   customer_type
--   min_tenure_days
--   max_tenure_days
--   min_deposit
--   max_deposit
--   is_callable
--   rate_category
--   upper(btrim(scheme_name))
--
-- Deduplication Semantics:
--   NULLS NOT DISTINCT (PostgreSQL 15+)
--   Treats matching NULL values in nullable columns (min_deposit, max_deposit,
--   is_callable, scheme_name) as equal for uniqueness, while remaining distinct
--   from explicit values (e.g. min_deposit 0, is_callable true, scheme_name '').
--   Eliminates synthetic numeric and boolean sentinel collisions.
--
-- Active Lifecycle Scope:
--   staging_status IN ('DRAFT', 'IN_REVIEW')
--   (Historical rows with PROMOTED, REJECTED, INVALID are excluded)
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Adds an index only; does not alter table structure or data.
--   * IDEMPOTENT: Uses CREATE UNIQUE INDEX IF NOT EXISTS.
--   * PRE-CHECK REQUIRED: Must run read-only duplicate pre-check query prior to execution.
--   * ROLLBACK SAFE: Dropping the index restores previous behavior with zero data loss.
-- ============================================================

-- ------------------------------------------------------------
-- STEP 0: MANDATORY READ-ONLY DUPLICATE PRE-CHECK QUERY
-- (Run manually before applying this migration. If count > 0, STOP IMMEDIATELY.)
-- ------------------------------------------------------------
/*
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
*/

-- ------------------------------------------------------------
-- STEP 1: CREATE PARTIAL UNIQUE INDEX ON ACTIVE STAGING CANDIDATES
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_staged_candidates_active_identity
  ON staged_rate_candidates (
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
  WHERE staging_status IN ('DRAFT', 'IN_REVIEW');

-- ------------------------------------------------------------
-- STEP 2: VERIFICATION QUERY
-- ------------------------------------------------------------
/*
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'staged_rate_candidates'
  AND indexname = 'idx_staged_candidates_active_identity';
*/

-- ------------------------------------------------------------
-- ROLLBACK PLAN (Index Removal Only — Zero Data Mutation):
-- ------------------------------------------------------------
/*
DROP INDEX IF EXISTS idx_staged_candidates_active_identity;
*/
