-- ============================================================
-- FeroCalc Verified FD Rate Engine
-- Draft Migration 019: Atomic Candidate Promotion Transaction RPC
--
-- STATUS: APPLIED
-- Applied to staging Supabase (cqrslxngpwbtkjejlwty) via migration interface. Version: 20261107073416.
--
-- Security Hardening (Phase 4.2.6 Audit):
--   * SECURITY DEFINER with SET search_path = '' (empty search path).
--   * Fully qualified references (public.table, auth.table, pg_catalog.func).
--   * Strict RBAC separation:
--       - 'AUTOMATED_POLICY': requires auth.users app_metadata ferocalc_role = 'SYSTEM_BOT'
--         and is_service_account = true. Blocks human admin.
--       - 'ADMIN': requires auth.users app_metadata ferocalc_role = 'ADMIN'.
--         Strictly rejects 'REVIEWER', unprivileged users, and spoofed user_metadata.
--   * Full Promotion Domain Integrity:
--       - Superseded rate must match bank, customer type, callability, rate category,
--         scheme name, tenure domain, and tenure boundary components.
--   * Effective Date Integrity:
--       - Conflicts between explicit p_effective_at and candidate effective_from are rejected.
--       - Automated promotion requires explicit effective_from.
--   * Privileges: Revoked from PUBLIC, anon, authenticated; granted strictly to service_role.
-- ============================================================

CREATE OR REPLACE FUNCTION public.promote_staged_candidate(
  p_staged_candidate_id UUID,
  p_actor_type          TEXT,           -- 'AUTOMATED_POLICY' or 'ADMIN'
  p_actor_id            UUID,           -- Dedicated service bot UUID or authorized admin UUID
  p_supersede_rate_id   UUID DEFAULT NULL, -- Old rate ID if replacing existing verified rate
  p_effective_at        TIMESTAMPTZ DEFAULT NULL, -- Explicit timestamp or derived from candidate
  p_policy_result       JSONB DEFAULT '{}'::pg_catalog.jsonb,
  p_diff_summary        JSONB DEFAULT '{}'::pg_catalog.jsonb,
  p_notes               TEXT DEFAULT NULL
)
RETURNS TABLE (
  new_rate_id        UUID,
  superseded_rate_id UUID,
  candidate_id       UUID,
  promotion_status   TEXT
) AS $$
DECLARE
  v_candidate     public.staged_rate_candidates%ROWTYPE;
  v_bank_id       UUID;
  v_old_rate      public.fd_rates%ROWTYPE;
  v_new_rate      public.fd_rates%ROWTYPE;
  v_domain_str    TEXT;
  v_lock_key      BIGINT;
  v_user_role     TEXT;
  v_is_service    BOOLEAN;
  v_now           TIMESTAMPTZ := pg_catalog.clock_timestamp();
  v_effective_at  TIMESTAMPTZ;
  v_tenure_domain public.tenure_domain;
  c_admin_uuid    CONSTANT UUID := '995b04cd-518b-435d-83a0-d1bdde22cca6'::uuid;
BEGIN
  -- ============================================================
  -- 1. ACTOR SECURITY & SERVICE IDENTITY VALIDATION
  -- ============================================================
  IF p_actor_id IS NULL THEN
    RAISE EXCEPTION 'Actor UUID is required for promotion';
  END IF;

  IF p_actor_type NOT IN ('AUTOMATED_POLICY', 'ADMIN') THEN
    RAISE EXCEPTION 'Unrecognized actor_type: %', p_actor_type
      USING ERRCODE = '42501';
  END IF;

  IF p_actor_type = 'AUTOMATED_POLICY' THEN
    -- Anti-spoofing: Automated policy promotions must NEVER impersonate human admin
    IF p_actor_id = c_admin_uuid THEN
      RAISE EXCEPTION 'Automated promotion cannot use human admin identity (%)', p_actor_id
        USING ERRCODE = '42501';
    END IF;

    -- Verify dedicated service bot role in auth.users app_metadata
    -- (Never use user_metadata; strictly read app_metadata)
    SELECT
      raw_app_meta_data->>'ferocalc_role',
      CASE
        WHEN raw_app_meta_data IS NOT NULL
             AND (raw_app_meta_data ? 'is_service_account')
             AND pg_catalog.jsonb_typeof(raw_app_meta_data->'is_service_account') = 'boolean'
        THEN (raw_app_meta_data->>'is_service_account')::boolean
        ELSE false
      END
    INTO v_user_role, v_is_service
    FROM auth.users
    WHERE id = p_actor_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'System Bot identity verification failed: user % not found in auth', p_actor_id
        USING ERRCODE = '42501';
    END IF;

    IF v_user_role <> 'SYSTEM_BOT' OR v_is_service <> true THEN
      RAISE EXCEPTION 'System Bot identity verification failed: user % is not a dedicated service bot (app_metadata.ferocalc_role="%", is_service_account=%)',
        p_actor_id, v_user_role, v_is_service
        USING ERRCODE = '42501';
    END IF;
  ELSE
    -- Admin path: caller session must possess admin role
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Access denied: Admin privileges required for manual candidate promotion'
        USING ERRCODE = '42501';
    END IF;

    -- Anti-spoofing: Dedicated service bot must not use manual ADMIN mode
    SELECT
      raw_app_meta_data->>'ferocalc_role',
      CASE
        WHEN raw_app_meta_data IS NOT NULL
             AND (raw_app_meta_data ? 'is_service_account')
             AND pg_catalog.jsonb_typeof(raw_app_meta_data->'is_service_account') = 'boolean'
        THEN (raw_app_meta_data->>'is_service_account')::boolean
        ELSE false
      END
    INTO v_user_role, v_is_service
    FROM auth.users
    WHERE id = p_actor_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Admin identity verification failed: user % not found in auth', p_actor_id
        USING ERRCODE = '42501';
    END IF;

    IF v_user_role = 'SYSTEM_BOT' OR v_is_service = true THEN
      RAISE EXCEPTION 'Admin identity verification failed: service bot % cannot promote in ADMIN mode', p_actor_id
        USING ERRCODE = '42501';
    END IF;

    -- Strict RBAC: Must be specifically 'ADMIN'.
    -- REVIEWER role is strictly rejected from manual candidate promotion.
    IF v_user_role IS NULL OR v_user_role <> 'ADMIN' THEN
      RAISE EXCEPTION 'Admin identity verification failed: user % possesses role "%", not ADMIN',
        p_actor_id, COALESCE(v_user_role, 'NONE')
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- ============================================================
  -- 2. LOCK & VALIDATE STAGED RATE CANDIDATE
  -- ============================================================
  -- FROM staged_rate_candidates FOR UPDATE
  SELECT * INTO v_candidate
  FROM public.staged_rate_candidates
  WHERE id = p_staged_candidate_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Staged candidate % not found', p_staged_candidate_id;
  END IF;

  -- Idempotency check: Already promoted candidates cannot be re-promoted
  IF v_candidate.staging_status = 'PROMOTED'::public.staging_candidate_status THEN
    RAISE EXCEPTION 'Staged candidate % is already PROMOTED (promoted_rate_id: %)',
      p_staged_candidate_id, v_candidate.promoted_rate_id;
  END IF;

  IF v_candidate.staging_status NOT IN ('DRAFT'::public.staging_candidate_status, 'IN_REVIEW'::public.staging_candidate_status) THEN
    RAISE EXCEPTION 'Staged candidate % cannot be promoted from status %',
      p_staged_candidate_id, v_candidate.staging_status;
  END IF;

  IF v_candidate.validation_status <> 'VALID' THEN
    RAISE EXCEPTION 'Cannot promote candidate % with validation status %',
      p_staged_candidate_id, v_candidate.validation_status;
  END IF;

  -- In automated mode: fail closed if candidate has unresolved anomaly flags
  IF p_actor_type = 'AUTOMATED_POLICY' AND v_candidate.anomaly_flags IS NOT NULL AND v_candidate.anomaly_flags <> '[]'::pg_catalog.jsonb THEN
    RAISE EXCEPTION 'Cannot auto-promote candidate % with active anomaly flags: %',
      p_staged_candidate_id, v_candidate.anomaly_flags;
  END IF;

  -- In automated mode: explicit effective_from date is strictly required
  IF p_actor_type = 'AUTOMATED_POLICY' AND v_candidate.effective_from IS NULL THEN
    RAISE EXCEPTION 'Cannot auto-promote candidate % without explicit effective_from date',
      p_staged_candidate_id;
  END IF;

  -- ============================================================
  -- 3. RESOLVE BANK ENTITY
  -- ============================================================
  SELECT id INTO v_bank_id
  FROM public.banks
  WHERE short_name = v_candidate.bank_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bank with code % not found in banks catalog', v_candidate.bank_code;
  END IF;

  v_tenure_domain := COALESCE(v_candidate.tenure_domain, 'DAYS'::public.tenure_domain);

  -- ============================================================
  -- 4. CONFLICT-DOMAIN ADVISORY LOCK (Mirroring Migrations 007, 008 & 009)
  -- ============================================================
  -- Includes tenure_domain to guarantee exact collision key parity with Migration 009
  v_domain_str :=
      v_bank_id::pg_catalog.text               || pg_catalog.chr(1) ||
      v_candidate.customer_type::pg_catalog.text || pg_catalog.chr(1) ||
      COALESCE(v_candidate.is_callable, true)::pg_catalog.text || pg_catalog.chr(1) ||
      COALESCE(v_candidate.rate_category, 'STANDARD'::public.rate_category)::pg_catalog.text || pg_catalog.chr(1) ||
      v_tenure_domain::text                    || pg_catalog.chr(1) ||
      CASE
        WHEN v_candidate.rate_category = 'SPECIAL_SCHEME'::public.rate_category
        THEN pg_catalog.upper(pg_catalog.btrim(COALESCE(v_candidate.scheme_name, '')))
        ELSE ''
      END;

  v_lock_key := ('x' || pg_catalog.substr(pg_catalog.md5(v_domain_str), 1, 16))::bit(64)::bigint;
  PERFORM pg_catalog.pg_advisory_xact_lock(v_lock_key);

  -- Effective date determination and validation
  IF p_effective_at IS NOT NULL AND v_candidate.effective_from IS NOT NULL THEN
    IF p_effective_at::pg_catalog.date <> v_candidate.effective_from THEN
      RAISE EXCEPTION 'Explicit effective timestamp % (date: %) conflicts with candidate published effective_from %',
        p_effective_at, p_effective_at::pg_catalog.date, v_candidate.effective_from;
    END IF;
  END IF;

  -- Determine effective date deterministically in UTC (independent of connection TimeZone)
  v_effective_at := COALESCE(
    p_effective_at,
    CASE
      WHEN v_candidate.effective_from IS NOT NULL
      THEN (v_candidate.effective_from::pg_catalog.text || 'T00:00:00Z')::pg_catalog.timestamptz
      ELSE NULL
    END,
    v_now
  );

  -- ============================================================
  -- 5. ARCHIVE PREVIOUS VERIFIED RATE (IF SUPERSEDING)
  -- ============================================================
  -- FROM fd_rates FOR UPDATE
  IF p_supersede_rate_id IS NOT NULL THEN
    SELECT * INTO v_old_rate
    FROM public.fd_rates
    WHERE id = p_supersede_rate_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Previous rate to supersede % not found', p_supersede_rate_id;
    END IF;

    -- Strict Promotion Domain Integrity Matching:
    -- 1. Bank
    IF v_old_rate.bank_id <> v_bank_id THEN
      RAISE EXCEPTION 'Bank ID mismatch between candidate and previous rate: % vs %',
        v_bank_id, v_old_rate.bank_id;
    END IF;

    -- 2. Customer Type
    IF v_old_rate.customer_type <> v_candidate.customer_type THEN
      RAISE EXCEPTION 'Customer type mismatch between candidate and previous rate: % vs %',
        v_candidate.customer_type, v_old_rate.customer_type;
    END IF;

    -- 3. Callability
    IF v_old_rate.is_callable IS DISTINCT FROM COALESCE(v_candidate.is_callable, true) THEN
      RAISE EXCEPTION 'Callability mismatch between candidate (%) and previous rate (%)',
        v_candidate.is_callable, v_old_rate.is_callable;
    END IF;

    -- 4. Rate Category
    IF v_old_rate.rate_category IS DISTINCT FROM COALESCE(v_candidate.rate_category, 'STANDARD'::public.rate_category) THEN
      RAISE EXCEPTION 'Rate category mismatch between candidate (%) and previous rate (%)',
        v_candidate.rate_category, v_old_rate.rate_category;
    END IF;

    -- 5. Special Scheme Name (if applicable)
    IF v_candidate.rate_category = 'SPECIAL_SCHEME'::public.rate_category THEN
      IF pg_catalog.upper(pg_catalog.btrim(COALESCE(v_old_rate.scheme_name, ''))) IS DISTINCT FROM pg_catalog.upper(pg_catalog.btrim(COALESCE(v_candidate.scheme_name, ''))) THEN
        RAISE EXCEPTION 'Special scheme name mismatch between candidate (%) and previous rate (%)',
          v_candidate.scheme_name, v_old_rate.scheme_name;
      END IF;
    ELSE
      IF v_old_rate.scheme_name IS NOT NULL THEN
        RAISE EXCEPTION 'Previous rate has scheme_name % but candidate is STANDARD',
          v_old_rate.scheme_name;
      END IF;
    END IF;

    -- 6. Tenure Domain
    IF v_old_rate.tenure_domain IS DISTINCT FROM v_tenure_domain THEN
      RAISE EXCEPTION 'tenure_domain mismatch between candidate (%) and previous rate (%)',
        v_tenure_domain, v_old_rate.tenure_domain;
    END IF;

    -- 7. Tenure Boundaries
    IF v_tenure_domain = 'DAYS'::public.tenure_domain THEN
      IF v_old_rate.min_tenure_days IS DISTINCT FROM v_candidate.min_tenure_days
         OR v_old_rate.max_tenure_days IS DISTINCT FROM v_candidate.max_tenure_days THEN
        RAISE EXCEPTION 'Day tenure boundaries mismatch: candidate [%, %] vs previous rate [%, %]',
          v_candidate.min_tenure_days, v_candidate.max_tenure_days,
          v_old_rate.min_tenure_days, v_old_rate.max_tenure_days;
      END IF;
    ELSIF v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN
      IF v_old_rate.min_years IS DISTINCT FROM v_candidate.min_years
         OR v_old_rate.min_months IS DISTINCT FROM v_candidate.min_months
         OR v_old_rate.min_days_cal IS DISTINCT FROM v_candidate.min_days_cal
         OR v_old_rate.min_operator IS DISTINCT FROM v_candidate.min_operator
         OR v_old_rate.max_years IS DISTINCT FROM v_candidate.max_years
         OR v_old_rate.max_months IS DISTINCT FROM v_candidate.max_months
         OR v_old_rate.max_days_cal IS DISTINCT FROM v_candidate.max_days_cal
         OR v_old_rate.max_operator IS DISTINCT FROM v_candidate.max_operator THEN
        RAISE EXCEPTION 'Calendar tenure boundaries mismatch between candidate and previous rate %',
          p_supersede_rate_id;
      END IF;
    END IF;

    -- Safety check: Old rate must be in VERIFIED or ARCHIVED status
    IF v_old_rate.status = 'VERIFIED'::public.rate_status THEN
      UPDATE public.fd_rates
      SET
        status          = 'ARCHIVED'::public.rate_status,
        effective_until = CASE
                            -- Equality-boundary fix (<=): If it already expired at or before cutover, preserve original boundary
                            WHEN v_old_rate.effective_until IS NOT NULL AND v_old_rate.effective_until <= v_effective_at
                            THEN v_old_rate.effective_until
                            ELSE v_effective_at
                          END,
        updated_at      = v_now
      WHERE id = p_supersede_rate_id;

      INSERT INTO public.rate_audit_log (rate_id, action, old_value, new_value, performed_by, notes)
      VALUES (
        p_supersede_rate_id,
        'ARCHIVE',
        pg_catalog.jsonb_build_object('status', 'VERIFIED', 'effective_until', v_old_rate.effective_until),
        pg_catalog.jsonb_build_object('status', 'ARCHIVED', 'effective_until',
          CASE
            WHEN v_old_rate.effective_until IS NOT NULL AND v_old_rate.effective_until <= v_effective_at
            THEN v_old_rate.effective_until
            ELSE v_effective_at
          END
        ),
        p_actor_id,
        COALESCE(p_notes, 'Superseded by newly promoted candidate ' || p_staged_candidate_id::pg_catalog.text)
      );
    ELSIF v_old_rate.status = 'ARCHIVED'::public.rate_status THEN
      -- Already archived record (such as expired PNB 3.80% rate)
      -- Confirm it remains ARCHIVED with its explicit historical boundary untouched
      NULL;
    ELSE
      RAISE EXCEPTION 'Previous rate % is in unexpected status % (expected VERIFIED or ARCHIVED)',
        p_supersede_rate_id, v_old_rate.status;
    END IF;
  END IF;

  -- ============================================================
  -- 6. INSERT NEW ACTIVE VERIFIED RATE INTO PUBLIC.FD_RATES
  -- ============================================================
  -- Accommodates dual-domain tenure models (DAYS and CALENDAR) per Migration 009
  INSERT INTO public.fd_rates (
    id,
    bank_id,
    customer_type,
    tenure_domain,
    source_tenure_text,
    min_tenure_days,
    max_tenure_days,
    min_years,
    min_months,
    min_days_cal,
    min_operator,
    max_years,
    max_months,
    max_days_cal,
    max_operator,
    min_deposit,
    max_deposit,
    interest_rate,
    is_callable,
    compounding_frequency,
    effective_from,
    effective_until,
    status,
    source_url,
    created_by,
    verified_by,
    verified_at,
    created_at,
    updated_at,
    review_notes,
    rate_category,
    scheme_name
  )
  VALUES (
    COALESCE(v_candidate.promoted_rate_id, pg_catalog.gen_random_uuid()),
    v_bank_id,
    v_candidate.customer_type,
    v_tenure_domain,
    v_candidate.tenure_label,
    CASE WHEN v_tenure_domain = 'DAYS'::public.tenure_domain THEN v_candidate.min_tenure_days ELSE NULL END,
    CASE WHEN v_tenure_domain = 'DAYS'::public.tenure_domain THEN v_candidate.max_tenure_days ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.min_years ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.min_months ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.min_days_cal ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.min_operator ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.max_years ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.max_months ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.max_days_cal ELSE NULL END,
    CASE WHEN v_tenure_domain = 'CALENDAR'::public.tenure_domain THEN v_candidate.max_operator ELSE NULL END,
    COALESCE(v_candidate.min_deposit, 0),
    v_candidate.max_deposit,
    v_candidate.interest_rate,
    COALESCE(v_candidate.is_callable, true),
    COALESCE(v_candidate.compounding_frequency, 'QUARTERLY'::public.compounding_frequency),
    v_effective_at,
    NULL, -- Currently active
    'VERIFIED'::public.rate_status,
    v_candidate.source_url,
    p_actor_id,
    p_actor_id,
    v_now,
    v_now,
    v_now,
    COALESCE(p_notes, 'Promoted from candidate ' || p_staged_candidate_id::pg_catalog.text),
    COALESCE(v_candidate.rate_category, 'STANDARD'::public.rate_category),
    v_candidate.scheme_name
  )
  RETURNING * INTO v_new_rate;

  -- ============================================================
  -- 7. UPDATE STAGED CANDIDATE TO 'PROMOTED'
  -- ============================================================
  UPDATE public.staged_rate_candidates
  SET
    staging_status   = 'PROMOTED'::public.staging_candidate_status,
    promoted_rate_id = v_new_rate.id,
    promoted_at      = v_now,
    promoted_by      = p_actor_type,
    promotion_reason = COALESCE(p_notes, 'Promoted by ' || p_actor_type)
  WHERE id = p_staged_candidate_id;

  -- ============================================================
  -- 8. APPEND IMMUTABLE PROMOTION AUDIT LOG ENTRY (INSERT INTO promotion_audit_log)
  -- ============================================================
  INSERT INTO public.promotion_audit_log (
    staged_candidate_id,
    rate_id,
    action,
    actor_type,
    actor_id,
    previous_status,
    new_status,
    policy_result,
    diff_summary,
    source_content_hash,
    parser_version,
    notes,
    created_at
  )
  VALUES (
    p_staged_candidate_id,
    v_new_rate.id,
    'PROMOTE',
    p_actor_type,
    p_actor_id::pg_catalog.text,
    v_candidate.staging_status::pg_catalog.text,
    'VERIFIED',
    p_policy_result,
    p_diff_summary,
    v_candidate.source_content_hash,
    v_candidate.parser_version,
    COALESCE(p_notes, 'Atomic candidate promotion'),
    v_now
  );

  -- Return successfully committed result
  RETURN QUERY SELECT v_new_rate.id, p_supersede_rate_id, p_staged_candidate_id, 'PROMOTED'::pg_catalog.text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Lock down execution privileges: service_role only
REVOKE ALL ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) FROM anon;
GRANT  EXECUTE ON FUNCTION public.promote_staged_candidate(UUID, TEXT, UUID, UUID, TIMESTAMPTZ, JSONB, JSONB, TEXT) TO service_role;
