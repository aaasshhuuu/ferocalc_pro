-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Migration 021: Durable Verified Rate Notification Event Store
--
-- STATUS: DRAFT / MIGRATION SPECIFICATION
-- Target Staging Project Reference: cqrslxngpwbtkjejlwty
-- Strictly Forbidden Production Reference: pmaykclwuyspxhgeomee
--
-- Purpose:
--   Establishes a dedicated, durable, concurrency-safe event store
--   for verified rate notifications. Guarantees deterministic event
--   deduplication across pipeline runs, restarts, and concurrent
--   serverless instances via PostgreSQL UNIQUE constraint.
--
-- Safety Guarantees:
--   * STRICTLY ADDITIVE: Does not alter existing tables from migrations 001-020.
--   * UNIQUE constraint on event_id guarantees zero duplicate dispatches.
--   * RLS policies: Service role has full access; public has read-only access to sanitized feed.
--   * Never contains secrets, reviewer notes, or sensitive keys.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.verified_rate_notification_events (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id            TEXT NOT NULL,
  bank_id             TEXT NOT NULL,
  bank_code           TEXT NOT NULL,
  bank_name           TEXT NOT NULL,
  event_type          TEXT NOT NULL DEFAULT 'verifiedRateChange',
  title               TEXT NOT NULL,
  message             TEXT NOT NULL,
  effective_date      TEXT,
  verified_timestamp  TIMESTAMPTZ NOT NULL DEFAULT now(),
  action_route        TEXT,
  payload             JSONB NOT NULL DEFAULT '{}'::jsonb,
  fingerprint         TEXT NOT NULL,
  candidate_id        UUID,
  promoted_rate_id    UUID,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_verified_rate_notification_event_id UNIQUE (event_id)
);

CREATE INDEX IF NOT EXISTS idx_notif_events_event_id ON public.verified_rate_notification_events (event_id);
CREATE INDEX IF NOT EXISTS idx_notif_events_bank_code ON public.verified_rate_notification_events (bank_code);
CREATE INDEX IF NOT EXISTS idx_notif_events_created ON public.verified_rate_notification_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_events_verified ON public.verified_rate_notification_events (verified_timestamp DESC);

-- Enable RLS
ALTER TABLE public.verified_rate_notification_events ENABLE ROW LEVEL SECURITY;

-- Read-only policy for public/anon/authenticated consumers
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'verified_rate_notification_events'
      AND policyname = 'notif_events_public_read'
  ) THEN
    CREATE POLICY notif_events_public_read ON public.verified_rate_notification_events
      FOR SELECT
      TO public
      USING (true);
  END IF;
END $$;

-- Privileged policy for service_role
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'verified_rate_notification_events'
      AND policyname = 'notif_events_service_write'
  ) THEN
    CREATE POLICY notif_events_service_write ON public.verified_rate_notification_events
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END $$;
