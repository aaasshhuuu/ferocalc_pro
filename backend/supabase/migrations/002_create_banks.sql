-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 002: banks table
-- Pilot registry — 5 banks only for MVP
-- ============================================================

CREATE TABLE IF NOT EXISTS banks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  short_name    TEXT NOT NULL,
  type          bank_type NOT NULL,
  status        bank_status NOT NULL DEFAULT 'ACTIVE',
  official_website TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT banks_name_unique UNIQUE (name),
  CONSTRAINT banks_short_name_unique UNIQUE (short_name),

  -- Official website must be a proper URL when provided
  CONSTRAINT banks_website_format CHECK (
    official_website IS NULL
    OR official_website ~* '^https?://'
  )
);

-- Auto-update updated_at on any row change
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER banks_updated_at
  BEFORE UPDATE ON banks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Seed: 5 Pilot Banks (metadata only — no rates)
-- Source references are official registered domains only.
-- DO NOT invent any rate data in this migration.
-- ============================================================

INSERT INTO banks (name, short_name, type, status, official_website)
VALUES
  (
    'State Bank of India',
    'SBI',
    'PUBLIC',
    'ACTIVE',
    'https://sbi.co.in'
  ),
  (
    'HDFC Bank',
    'HDFC',
    'PRIVATE',
    'ACTIVE',
    'https://hdfcbank.com'
  ),
  (
    'ICICI Bank',
    'ICICI',
    'PRIVATE',
    'ACTIVE',
    'https://icicibank.com'
  ),
  (
    'Axis Bank',
    'AXIS',
    'PRIVATE',
    'ACTIVE',
    'https://axisbank.com'
  ),
  (
    'Unity Small Finance Bank',
    'UNITY_SFB',
    'SMALL_FINANCE',
    'ACTIVE',
    'https://theunitybank.com'
  );
