-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 011: Rate Candidate Staging & Validation Registry
--
-- Stores structured FD-rate candidates extracted from official sources
-- during Phase 2.
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter tables from migrations 001-010.
--   * NO AUTO-PUBLISH: Status is limited to DRAFT, IN_REVIEW, REJECTED, INVALID.
--     Under NO circumstances can an extracted candidate become VERIFIED automatically.
--   * Preserves raw source hash, parser version, validation errors, and anomaly flags.
-- ============================================================

-- 1. Enum for candidate staging lifecycle states (NO 'VERIFIED' status allowed in staging)
DO $$ BEGIN
  CREATE TYPE staging_candidate_status AS ENUM (
    'DRAFT',
    'IN_REVIEW',
    'REJECTED',
    'INVALID'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2. Staged rate candidates table
CREATE TABLE IF NOT EXISTS staged_rate_candidates (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id             TEXT NOT NULL REFERENCES rate_sources(id) ON DELETE CASCADE,
  bank_code             TEXT NOT NULL,
  product_type          TEXT NOT NULL DEFAULT 'RETAIL_DOMESTIC_TERM_DEPOSIT',
  customer_type         customer_type NOT NULL DEFAULT 'REGULAR',
  tenure_label          TEXT NOT NULL,
  min_tenure_days       INTEGER NOT NULL,
  max_tenure_days       INTEGER NOT NULL,
  tenure_unit           TEXT NOT NULL DEFAULT 'DAYS',
  interest_rate         NUMERIC(5, 2) NOT NULL,
  senior_citizen_rate   NUMERIC(5, 2),
  super_senior_rate     NUMERIC(5, 2),
  min_deposit           NUMERIC(18, 2),
  max_deposit           NUMERIC(18, 2),
  is_callable           BOOLEAN DEFAULT true,
  compounding_frequency compounding_frequency DEFAULT 'QUARTERLY',
  effective_from        DATE,
  effective_until       DATE,
  source_url            TEXT NOT NULL,
  source_document_url   TEXT,
  source_content_hash   TEXT NOT NULL,
  extracted_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  parser_id             TEXT NOT NULL,
  parser_version        TEXT NOT NULL,
  validation_status     TEXT NOT NULL DEFAULT 'VALID', -- 'VALID', 'INVALID', 'WARNING'
  validation_errors     JSONB NOT NULL DEFAULT '[]'::jsonb,
  anomaly_flags         JSONB NOT NULL DEFAULT '[]'::jsonb,
  staging_status        staging_candidate_status NOT NULL DEFAULT 'DRAFT',
  notes                 TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT staged_rates_tenure_min_positive CHECK (min_tenure_days > 0),
  CONSTRAINT staged_rates_tenure_max_gte_min CHECK (max_tenure_days >= min_tenure_days),
  CONSTRAINT staged_rates_rate_positive CHECK (interest_rate > 0)
);

CREATE INDEX IF NOT EXISTS idx_staged_rates_source_date ON staged_rate_candidates (source_id, extracted_at DESC);
CREATE INDEX IF NOT EXISTS idx_staged_rates_bank_cust ON staged_rate_candidates (bank_code, customer_type);
CREATE INDEX IF NOT EXISTS idx_staged_rates_status ON staged_rate_candidates (staging_status);
CREATE INDEX IF NOT EXISTS idx_staged_rates_hash ON staged_rate_candidates (source_content_hash);
