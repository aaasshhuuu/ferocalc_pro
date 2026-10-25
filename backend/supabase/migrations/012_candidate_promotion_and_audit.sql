-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 012: Candidate Promotion & Audit Log
--
-- Adds promotion lifecycle tracking to staged candidates and
-- establishes an immutable audit log for automated policy promotions,
-- manual admin reviews, rejections, and safe rollbacks.
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter tables from migrations 001-011.
--   * Preserves full historical versioning in fd_rates and rate_audit_log.
--   * Records actorType (AUTOMATED_POLICY vs ADMIN), diff, and policy rationale.
-- ============================================================

-- 1. Extend staging status enum to support 'PROMOTED'
DO $$ BEGIN
  ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Add promotion tracking columns to staged_rate_candidates
ALTER TABLE staged_rate_candidates
  ADD COLUMN IF NOT EXISTS promoted_rate_id UUID REFERENCES fd_rates(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS promoted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS promoted_by TEXT,
  ADD COLUMN IF NOT EXISTS promotion_reason TEXT;

-- 3. Dedicated promotion and rollback audit trail
CREATE TABLE IF NOT EXISTS promotion_audit_log (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staged_candidate_id UUID REFERENCES staged_rate_candidates(id) ON DELETE SET NULL,
  rate_id             UUID REFERENCES fd_rates(id) ON DELETE CASCADE,
  action              TEXT NOT NULL, -- 'PROMOTE', 'ROLLBACK', 'REJECT', 'ESCALATE_TO_IN_REVIEW'
  actor_type          TEXT NOT NULL, -- 'AUTOMATED_POLICY', 'ADMIN'
  actor_id            TEXT,          -- 'AUTOMATED_POLICY' or admin user UUID
  previous_status     TEXT,
  new_status          TEXT,
  policy_result       JSONB,
  diff_summary        JSONB,
  source_content_hash TEXT,
  parser_version      TEXT,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prom_audit_rate ON promotion_audit_log (rate_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_prom_audit_cand ON promotion_audit_log (staged_candidate_id);
CREATE INDEX IF NOT EXISTS idx_prom_audit_action ON promotion_audit_log (action);
CREATE INDEX IF NOT EXISTS idx_prom_audit_actor ON promotion_audit_log (actor_type);
CREATE INDEX IF NOT EXISTS idx_prom_audit_created ON promotion_audit_log (created_at DESC);
