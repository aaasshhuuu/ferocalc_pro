-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 003: fd_rates table
-- Core financial data with strict integrity constraints
-- ============================================================

CREATE TABLE IF NOT EXISTS fd_rates (
  -- Identity
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Bank reference (cascades on bank delete to preserve history)
  bank_id               UUID NOT NULL REFERENCES banks(id) ON DELETE RESTRICT,

  -- Rate dimensions (the "bucket" this rate applies to)
  customer_type         customer_type NOT NULL DEFAULT 'REGULAR',
  min_tenure_days       INTEGER NOT NULL,
  max_tenure_days       INTEGER NOT NULL,

  -- Deposit range (NULL means no floor/ceiling for that side)
  min_deposit           NUMERIC(18, 2) NOT NULL DEFAULT 0,
  max_deposit           NUMERIC(18, 2),

  -- The rate itself — stored as annual percentage (e.g. 7.25 = 7.25% p.a.)
  interest_rate         NUMERIC(5, 2) NOT NULL,

  -- Product characteristics (CRITICAL for accurate maturity calculation)
  is_callable           BOOLEAN NOT NULL DEFAULT true,
  compounding_frequency compounding_frequency NOT NULL DEFAULT 'QUARTERLY',

  -- Time validity
  effective_from        TIMESTAMPTZ NOT NULL,
  effective_until       TIMESTAMPTZ,   -- NULL = currently active

  -- Workflow state
  status                rate_status NOT NULL DEFAULT 'DRAFT',

  -- Source traceability (the URL admin verified against)
  source_url            TEXT,

  -- Audit: who touched this record
  created_by            UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_by           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Human notes for review process
  review_notes          TEXT,

  -- ============================================================
  -- INTEGRITY CONSTRAINTS — Financial Safety
  -- ============================================================

  -- Tenure must form a valid range
  CONSTRAINT fd_rates_tenure_min_gte_zero
    CHECK (min_tenure_days >= 0),

  CONSTRAINT fd_rates_tenure_max_gte_min
    CHECK (max_tenure_days >= min_tenure_days),

  -- Deposit range must be valid
  CONSTRAINT fd_rates_deposit_min_gte_zero
    CHECK (min_deposit >= 0),

  CONSTRAINT fd_rates_deposit_max_gte_min
    CHECK (max_deposit IS NULL OR max_deposit >= min_deposit),

  -- Interest rate must be non-negative (zero is valid for some products)
  CONSTRAINT fd_rates_rate_non_negative
    CHECK (interest_rate >= 0),

  -- effective_from is always required
  CONSTRAINT fd_rates_effective_from_required
    CHECK (effective_from IS NOT NULL),

  -- effective_until must be after effective_from when set
  CONSTRAINT fd_rates_validity_window
    CHECK (effective_until IS NULL OR effective_until > effective_from),

  -- Verification metadata only present when VERIFIED or ARCHIVED
  CONSTRAINT fd_rates_verify_fields_consistent
    CHECK (
      (status NOT IN ('VERIFIED', 'ARCHIVED'))
      OR (verified_by IS NOT NULL AND verified_at IS NOT NULL)
    ),

  -- Source URL required for VERIFIED records
  CONSTRAINT fd_rates_verified_requires_source
    CHECK (
      status <> 'VERIFIED' OR (source_url IS NOT NULL AND source_url <> '')
    ),

  -- Source URL must be an http(s) URL when present
  CONSTRAINT fd_rates_source_url_format
    CHECK (
      source_url IS NULL
      OR source_url ~* '^https?://'
    )
);

-- Auto-update updated_at
CREATE TRIGGER fd_rates_updated_at
  BEFORE UPDATE ON fd_rates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- INDEXES for query performance
-- ============================================================

-- Primary lookup: find verified rates for a bank
CREATE INDEX IF NOT EXISTS idx_fd_rates_bank_status
  ON fd_rates (bank_id, status);

-- Verified public query (the hot path)
CREATE INDEX IF NOT EXISTS idx_fd_rates_verified
  ON fd_rates (status, bank_id, customer_type)
  WHERE status = 'VERIFIED';

-- Tenure range lookup
CREATE INDEX IF NOT EXISTS idx_fd_rates_tenure
  ON fd_rates (min_tenure_days, max_tenure_days);

-- Effective date window queries
CREATE INDEX IF NOT EXISTS idx_fd_rates_effective
  ON fd_rates (effective_from, effective_until);

-- Admin workflow: find drafts
CREATE INDEX IF NOT EXISTS idx_fd_rates_draft_created
  ON fd_rates (status, created_at)
  WHERE status IN ('DRAFT', 'IN_REVIEW');

-- ============================================================
-- ACTIVE VERIFIED RATE UNIQUENESS
--
-- Prevent two simultaneously active VERIFIED records for the same
-- logical rate bucket.  "Active" means effective_until IS NULL.
-- Archived / expired records (effective_until IS NOT NULL) are
-- excluded so the full history is preserved.
--
-- Bucket dimensions:
--   bank + customer_type + tenure range + deposit range + callable
--
-- max_deposit handling:
--   NULL max_deposit (open ceiling) is folded to -1 via COALESCE.
--   -1 is safe as a sentinel because min_deposit >= 0 is enforced by
--   constraint, so a real max_deposit of -1 can never exist.
--
-- Drop the old index first in case migrations are re-run after edits.
-- ============================================================
DROP INDEX IF EXISTS idx_fd_rates_no_duplicate_verified;

CREATE UNIQUE INDEX IF NOT EXISTS idx_fd_rates_single_active_verified
  ON fd_rates (
    bank_id,
    customer_type,
    min_tenure_days,
    max_tenure_days,
    min_deposit,
    (COALESCE(max_deposit, -1::NUMERIC)),
    is_callable
  )
  WHERE status = 'VERIFIED' AND effective_until IS NULL;

