-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 014: Official Source Baseline Attestations
--
-- Enables source-level trust attestation and safe baseline seeding
-- for initial bank rate datasets.
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter tables from migrations 001-013.
--   * Preserves all existing verified rates, staged candidates, and audit records.
--   * Full auditability: Records batch ID, source hash, admin attestor, and timestamps.
-- ============================================================

-- 1. Baseline Source Attestation Registry
CREATE TABLE IF NOT EXISTS baseline_source_attestations (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id                  TEXT NOT NULL UNIQUE, -- e.g. 'baseline_sbi_retail_domestic_9eaa989f6db1'
  bank_code                 TEXT NOT NULL,
  source_id                 TEXT NOT NULL REFERENCES rate_sources(id) ON DELETE CASCADE,
  source_url                TEXT NOT NULL,
  source_type               TEXT NOT NULL DEFAULT 'HTML',
  source_content_hash       TEXT NOT NULL,
  fetched_at                TIMESTAMPTZ NOT NULL,
  parser_id                 TEXT NOT NULL,
  parser_version            TEXT NOT NULL,
  candidate_count           INTEGER NOT NULL DEFAULT 0,
  valid_candidate_count     INTEGER NOT NULL DEFAULT 0,
  invalid_candidate_count   INTEGER NOT NULL DEFAULT 0,
  anomalous_candidate_count INTEGER NOT NULL DEFAULT 0,
  effective_from            DATE,
  attestation_status        TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'ATTESTED', 'REJECTED', 'SUPERSEDED'
  attested_at               TIMESTAMPTZ,
  attested_by               TEXT,
  rejection_reason          TEXT,
  promotion_status          TEXT NOT NULL DEFAULT 'UNPROMOTED', -- 'UNPROMOTED', 'PROMOTED', 'PARTIALLY_PROMOTED'
  promoted_at               TIMESTAMPTZ,
  promoted_by               TEXT,
  promoted_count            INTEGER NOT NULL DEFAULT 0,
  notes                     TEXT,
  metadata                  JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_baseline_attest_source ON baseline_source_attestations (source_id, source_content_hash);
CREATE INDEX IF NOT EXISTS idx_baseline_attest_status ON baseline_source_attestations (attestation_status);
CREATE INDEX IF NOT EXISTS idx_baseline_attest_bank ON baseline_source_attestations (bank_code);
CREATE INDEX IF NOT EXISTS idx_baseline_attest_created ON baseline_source_attestations (created_at DESC);
