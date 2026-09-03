-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 004: rate_audit_log table
-- Immutable history of every action on every rate record
-- ============================================================

CREATE TABLE IF NOT EXISTS rate_audit_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- The rate this entry refers to
  rate_id         UUID NOT NULL REFERENCES fd_rates(id) ON DELETE CASCADE,

  -- Action performed
  action          audit_action NOT NULL,

  -- Snapshot of changed values (JSON diff, NOT full objects)
  -- old_value: what the field looked like BEFORE the action
  -- new_value: what the field looks like AFTER the action
  old_value       JSONB,
  new_value       JSONB,

  -- Who did this
  performed_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  performed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Optional human annotation (e.g. "Checked against sbi.co.in on 2026-09-02")
  notes           TEXT,

  -- Audit log is append-only: no UPDATE or DELETE permitted
  -- Enforced via RLS policy in migration 005
  CONSTRAINT audit_log_performed_at_not_null
    CHECK (performed_at IS NOT NULL)
);

-- Index for fetching history of a specific rate
CREATE INDEX IF NOT EXISTS idx_audit_log_rate_id
  ON rate_audit_log (rate_id, performed_at DESC);

-- Index for fetching all actions by a specific admin
CREATE INDEX IF NOT EXISTS idx_audit_log_performed_by
  ON rate_audit_log (performed_by, performed_at DESC);

-- Index for time-range queries
CREATE INDEX IF NOT EXISTS idx_audit_log_performed_at
  ON rate_audit_log (performed_at DESC);
