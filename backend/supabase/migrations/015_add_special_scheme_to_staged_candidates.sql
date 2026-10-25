-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 015: Add Special Scheme Fields to Staged Rate Candidates
--
-- Enables staged_rate_candidates to store promotional / special scheme
-- classifications (e.g. 'SBI We-Care') matching fd_rates (Migration 007).
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter tables from migrations 001-014.
--   * Safe for idempotent re-runs.
--   * Preserves existing staged records with DEFAULT 'STANDARD' and NULL scheme_name.
--   * Enforces integrity constraints matching fd_rates.
--   * Maintains RLS policies established in migrations 005 and 011.
-- ============================================================

-- 1. Add rate_category and scheme_name columns
ALTER TABLE staged_rate_candidates
  ADD COLUMN IF NOT EXISTS rate_category rate_category NOT NULL DEFAULT 'STANDARD',
  ADD COLUMN IF NOT EXISTS scheme_name TEXT;

-- 2. Check constraints matching fd_rates (Migration 007)
ALTER TABLE staged_rate_candidates
  DROP CONSTRAINT IF EXISTS staged_rates_scheme_name_required;
ALTER TABLE staged_rate_candidates
  ADD CONSTRAINT staged_rates_scheme_name_required
    CHECK (
      rate_category <> 'SPECIAL_SCHEME'
      OR (scheme_name IS NOT NULL AND btrim(scheme_name) <> '')
    );

ALTER TABLE staged_rate_candidates
  DROP CONSTRAINT IF EXISTS staged_rates_scheme_name_standard_null;
ALTER TABLE staged_rate_candidates
  ADD CONSTRAINT staged_rates_scheme_name_standard_null
    CHECK (rate_category <> 'STANDARD' OR scheme_name IS NULL);

-- 3. Partial and compound indexes for fast special scheme querying
CREATE INDEX IF NOT EXISTS idx_staged_rates_category ON staged_rate_candidates (rate_category, scheme_name);
