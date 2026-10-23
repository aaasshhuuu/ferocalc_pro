-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 010: Rate Source Monitoring & Collection Registry
--
-- Tracks official bank sources, polling intervals, content hashes,
-- and collection logs for automated change detection.
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter tables from migrations 001-009.
--   * NO AUTO-PUBLISH: Collections NEVER write directly to fd_rates.status = 'VERIFIED'.
--   * Full auditability: Every collection run records status, hash, and duration.
-- ============================================================

-- 1. ENUMs for source type and collection status
DO $$ BEGIN
  CREATE TYPE rate_source_type AS ENUM ('HTML', 'PDF', 'JSON');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE source_collection_status AS ENUM (
    'FIRST_SEEN',
    'UNCHANGED',
    'CHANGED',
    'FETCH_FAILED',
    'PARSER_UNAVAILABLE'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Registered rate sources
CREATE TABLE IF NOT EXISTS rate_sources (
  id                  TEXT PRIMARY KEY, -- e.g. 'sbi-domestic-retail', 'hdfc-retail-below-3cr'
  bank_id             UUID REFERENCES banks(id) ON DELETE RESTRICT,
  bank_code           TEXT NOT NULL,    -- Human-readable bank code e.g. 'SBI', 'HDFC'
  source_url          TEXT NOT NULL,
  source_type         rate_source_type NOT NULL DEFAULT 'HTML',
  parser_id           TEXT NOT NULL,    -- e.g. 'sbi_html_table_v1'
  parser_version      TEXT NOT NULL DEFAULT '1.0.0',
  is_enabled          BOOLEAN NOT NULL DEFAULT true,
  polling_interval_h  INTEGER NOT NULL DEFAULT 24,

  -- Observability & Change Detection State
  last_checked_at     TIMESTAMPTZ,
  last_success_at     TIMESTAMPTZ,
  last_content_hash   TEXT,             -- SHA-256 in hex
  last_status         source_collection_status,
  last_error          TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT rate_sources_url_format CHECK (source_url ~* '^https?://'),
  CONSTRAINT rate_sources_polling_positive CHECK (polling_interval_h > 0)
);

CREATE INDEX IF NOT EXISTS idx_rate_sources_bank ON rate_sources (bank_code);
CREATE INDEX IF NOT EXISTS idx_rate_sources_enabled ON rate_sources (is_enabled);

-- 3. Immutable collection log table (for audit trail & history)
CREATE TABLE IF NOT EXISTS source_collection_logs (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id           TEXT NOT NULL REFERENCES rate_sources(id) ON DELETE CASCADE,
  bank_code           TEXT NOT NULL,
  source_url          TEXT NOT NULL,
  fetched_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  http_status         INTEGER,
  content_type        TEXT,
  content_hash        TEXT,             -- SHA-256
  status              source_collection_status NOT NULL,
  changed             BOOLEAN NOT NULL DEFAULT false,
  fetch_duration_ms   INTEGER,
  byte_size           INTEGER,
  error_message       TEXT,
  parser_version      TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_collection_logs_source ON source_collection_logs (source_id, fetched_at DESC);
CREATE INDEX IF NOT EXISTS idx_collection_logs_status ON source_collection_logs (status);
CREATE INDEX IF NOT EXISTS idx_collection_logs_fetched ON source_collection_logs (fetched_at DESC);
