-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 013: Pipeline Execution Audit, Source Health & Job Locking
--
-- Adds:
-- 1. rate_pipeline_runs: Persistent audit table for scheduled and manual pipeline runs.
-- 2. rate_pipeline_locks: Database-backed persistent job locking with lease expiration.
-- 3. Source health tracking columns on rate_sources.
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter tables from migrations 001-012.
--   * Preserves all existing verified rates, staging candidates, and audit records.
--   * Full auditability: Records execution ID, timestamps, counts, and error summaries.
-- ============================================================

-- 1. Pipeline Run Execution Audit Table
CREATE TABLE IF NOT EXISTS rate_pipeline_runs (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id                TEXT NOT NULL UNIQUE,
  started_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at           TIMESTAMPTZ,
  duration_ms           INTEGER,
  status                TEXT NOT NULL DEFAULT 'RUNNING', -- 'RUNNING', 'SUCCESS', 'PARTIAL_SUCCESS', 'FAILED', 'LOCKED'
  trigger_type          TEXT NOT NULL DEFAULT 'MANUAL',  -- 'CRON', 'MANUAL', 'API'
  is_dry_run            BOOLEAN NOT NULL DEFAULT false,
  source_count          INTEGER NOT NULL DEFAULT 0,
  success_count         INTEGER NOT NULL DEFAULT 0,
  failure_count         INTEGER NOT NULL DEFAULT 0,
  changed_count         INTEGER NOT NULL DEFAULT 0,
  extracted_count       INTEGER NOT NULL DEFAULT 0,
  promoted_count        INTEGER NOT NULL DEFAULT 0,
  review_count          INTEGER NOT NULL DEFAULT 0,
  invalid_count         INTEGER NOT NULL DEFAULT 0,
  error_summary         TEXT,
  metadata              JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started ON rate_pipeline_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_status ON rate_pipeline_runs (status);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_trigger ON rate_pipeline_runs (trigger_type);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_job_id ON rate_pipeline_runs (job_id);

-- 2. Persistent Distributed Job Lock Table
CREATE TABLE IF NOT EXISTS rate_pipeline_locks (
  lock_name             TEXT PRIMARY KEY, -- e.g. 'rate_pipeline_global'
  locked_by_job_id      TEXT NOT NULL,
  acquired_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at           TIMESTAMPTZ NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Extend rate_sources with Health and Stale Monitoring State
ALTER TABLE rate_sources
  ADD COLUMN IF NOT EXISTS consecutive_failures INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_failure_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_http_status INTEGER,
  ADD COLUMN IF NOT EXISTS health_status TEXT NOT NULL DEFAULT 'HEALTHY', -- 'HEALTHY', 'DEGRADED', 'FAILING', 'STALE_RISK'
  ADD COLUMN IF NOT EXISTS stale_risk BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS last_stale_warning_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_rate_sources_health ON rate_sources (health_status);
CREATE INDEX IF NOT EXISTS idx_rate_sources_stale ON rate_sources (stale_risk);
