# FeroCalc Phase 4.2.11 — Atomic Policy Escalation Persistence Fix
## Final Release Report

**Date:** 2026-11-08
**Branch:** `staging/vercel-backend-preview`
**Release commit:** `d76945e`
**Base commit:** `5652307b09dd0f7fdb2f9d7bcfe7a57274c3ab09`
**Staging Supabase:** `cqrslxngpwbtkjejlwty`
**Vercel Preview:** `ferocalc-staging-backend-ovyehkz8j-kuldip12490-8771s-projects.vercel.app`

---

## 1. Root Cause (Confirmed)

**File:** `backend/promotion/promotion_service.js` (lines 265–297, pre-fix)

When `AUTOMATED_POLICY` blocked automated promotion, the old code path:
1. Updated `candidate.stagingStatus` **in memory only**
2. Called `_logAudit(...)` → successfully INSERT'd to `promotion_audit_log`
3. **Never** executed `UPDATE staged_rate_candidates SET staging_status = ...`

Result: the `staged_rate_candidates` row retained its old status indefinitely. The audit log reflected the intended transition but the actual status column did not.

**Evidence:** Candidate `d7ab06f9-49f2-4d3a-a17f-b5dcb0595070` had an audit entry `ESCALATE_TO_IN_REVIEW` at `2026-11-07T08:33:39Z`, while `updated_at` on `staged_rate_candidates` was `2026-11-04T10:53:17Z` — predating the run.

Upon live DB inspection, `d7ab06f9` is already `IN_REVIEW` (status set during a prior Nov-4 operation). The Phase 4.2.10 report's `DRAFT` observation was based on a stale in-memory read; no repair needed.

---

## 2. Fix Implemented

### 2a. New PostgreSQL RPC — `escalate_staged_candidate`

**Migration:** `20261107134500_atomic_policy_escalation_rpc.sql`
**SHA-256:** `D84F45545FF3F69A4A5AEBC4A9A34367DC08B1ADC60788E40218333E368D71E7`

Signature:
```sql
public.escalate_staged_candidate(
  p_staged_candidate_id      UUID,
  p_actor_type               TEXT,    -- Must be 'AUTOMATED_POLICY'
  p_actor_id                 UUID,    -- Dedicated System Bot UUID
  p_expected_previous_status TEXT,    -- Optimistic concurrency check
  p_new_status               TEXT,    -- 'IN_REVIEW' or 'INVALID'
  p_policy_result            JSONB DEFAULT '{}',
  p_diff_summary             JSONB DEFAULT '{}',
  p_notes                    TEXT DEFAULT NULL,
  p_source_content_hash      TEXT DEFAULT NULL,
  p_parser_version           TEXT DEFAULT NULL
)
RETURNS TABLE(candidate_id UUID, previous_status TEXT, new_status TEXT, escalation_status TEXT)
```

Security model (consistent with Migration 019):
- `SECURITY DEFINER SET search_path = ''` — empty search path, fully-qualified references
- `AUTOMATED_POLICY` only — ADMIN and other actor types are rejected with SQLSTATE `42501`
- Verifies `auth.users.raw_app_meta_data`: `ferocalc_role='SYSTEM_BOT'` and `is_service_account=true`
- Anti-spoofing: rejects human admin UUID `995b04cd-...`
- Safety guard: rejects `p_new_status IN ('PROMOTED', 'VERIFIED')` — this RPC **never** touches `verified_fd_rates`
- Optimistic concurrency: `SELECT ... FOR UPDATE` + status mismatch raises SQLSTATE `40001`
- Idempotent: if `staging_status` already equals `p_new_status`, returns `IDEMPOTENT` without double-writing
- Atomically: `UPDATE staged_rate_candidates` + `INSERT INTO promotion_audit_log` in single transaction
- **Privileges:** `REVOKE ALL FROM PUBLIC, authenticated, anon` → `GRANT EXECUTE TO service_role` only

Returns `escalation_status`: `'ESCALATED'` or `'IDEMPOTENT'`

### 2b. JS Fix — `promotion_service.js`

New behavior when `AUTOMATED_POLICY` blocks promotion:

1. **If `db && typeof db.rpc === 'function'`** (live staging/production runtime):
   - Build `escalationParams` with all 10 RPC arguments
   - Call `db.rpc('escalate_staged_candidate', escalationParams)`
   - If RPC returns error → throw immediately (**fail closed**); in-memory state NOT updated
   - Only after RPC success → update `candidate.stagingStatus` in memory

2. **If `this._isOfflineTestMode`**: use existing `_logAudit` in-memory path (unit tests only)

3. **Otherwise** (live runtime, no DB client): throw and fail closed

Return shape: `{ success: false, promoted: false, escalated: true, atomicRpc: boolean, stagingStatus, previousStatus, policyResult, diffResult, reason }`

---

## 3. Migration Application Status

> **Migration 020 (`20261107134500_atomic_policy_escalation_rpc.sql`) has NOT been applied to staging `cqrslxngpwbtkjejlwty`.**
>
> All programmatic DDL application paths failed — Supabase PAT not available, service-role key rejected by Management API for DDL.
>
> **Operator action required:** Paste the SQL from `backend/supabase/migrations/20261107134500_atomic_policy_escalation_rpc.sql` into the Supabase SQL Editor at `https://supabase.com/dashboard/project/cqrslxngpwbtkjejlwty/sql/new` and execute.
>
> **Verification after applying:**
> ```
> ERROR code=42501  → Applied correctly (function exists; actor_type=null rejected)
> ERROR code=PGRST202 → NOT applied (function not found)
> ```

---

## 4. Test Results

### Phase 4.2.11 Regression Tests (7 / 7)

| # | Test | Status |
|---|------|--------|
| 1 | Successful policy block persists IN_REVIEW via atomic RPC | **PASS** |
| 2 | INVALID recommendation persists via atomic RPC | **PASS** |
| 3 | RPC failure propagates — no false success reported | **PASS** |
| 4 | In-memory state is updated ONLY after RPC success | **PASS** |
| 5 | Concurrent status change causes RPC failure — rejected | **PASS** |
| 6 | Missing DB client in live runtime fails closed before escalation | **PASS** |
| 7 | No verified_fd_rates mutation occurs during policy escalation | **PASS** |

**Test file:** `backend/test/policy_escalation_persistence_test.js`

### Full Backend Test Suite

**Command:** `npm test --prefix backend` **Exit code:** `0` **Result:** 0 failures

All 41 test files passed, including:
- `promotion_test.js` — 59 tests (T1–T7.6 all pass, including T5.12–T5.17 for RPC wiring)
- `hdfc_r3_calendar_tenure_regression_test.js` — 63 tests
- `cors_integration_test.js` — 21 tests
- `hdfc_live_verifier_test.js` — 15 tests
- `policy_escalation_persistence_test.js` — 7 tests (NEW)

---

## 5. Commit & Deployment

| Item | Value |
|------|-------|
| Commit SHA | `d76945e` |
| Commit message | `fix(staging): Phase 4.2.11 — atomic policy escalation persistence via escalate_staged_candidate RPC` |
| Branch | `staging/vercel-backend-preview` |
| Push | `5652307..d76945e` → `origin/staging/vercel-backend-preview` |
| Vercel Preview URL | `ferocalc-staging-backend-ovyehkz8j-kuldip12490-8771s-projects.vercel.app` |
| Vercel status | ● Ready |
| Vercel environment | Preview |

**Files committed (exactly 4):**
- `backend/promotion/promotion_service.js`
- `backend/supabase/migrations/20261107134500_atomic_policy_escalation_rpc.sql`
- `backend/test/policy_escalation_persistence_test.js`
- `backend/package.json`

---

## 6. Live Staging DB State (at report time: 2026-11-08T04:52 UTC)

| Status | Count |
|--------|-------|
| DRAFT | 171 |
| IN_REVIEW | 169 |
| INVALID | 4 |
| PROMOTED | 399 |
| **verified_fd_rates** | **423** (unchanged) |

> Counts differ from Phase 4.2.10 snapshot because automated hourly pipeline runs have continued.

**Candidate `d7ab06f9-49f2-4d3a-a17f-b5dcb0595070`:**
- `staging_status`: `IN_REVIEW` ✅ (already correct — no repair needed)
- `updated_at`: `2026-11-04T10:53:17Z`
- Audit: `ESCALATE_TO_IN_REVIEW` by `AUTOMATED_POLICY` at `2026-11-07T08:33:39Z`

---

## 7. Production Isolation Confirmation

- Production Supabase `pmaykclwuyspxhgeomee` — **never accessed**
- `C:\projects\fincalc_pro` — **never modified**
- `verified_fd_rates` — **never touched** by any escalation path
- No candidate statuses manually updated
- `RATE_PIPELINE_AUTOMATION_ENABLED=true` — untouched
- System Bot UUID `cbea51a6-e753-4d2d-9317-3e8c88af2b92` — no new Auth rows provisioned

---

## 8. Open Gates

| Gate | Status | Action |
|------|--------|--------|
| Migration 020 applied to staging DB | ⏳ **PENDING** | Operator must apply via Supabase SQL Editor |
| PostgREST smoke test (`escalate_staged_candidate`) | ⏳ Pending migration | Expect `42501` not `PGRST202` |
| Candidate `d7ab06f9` repair | ✅ NOT NEEDED | Already `IN_REVIEW` in DB |
| Vercel Preview Ready | ✅ DONE | `ferocalc-staging-backend-ovyehkz8j-...` |
| All 7 regression tests pass | ✅ DONE | 7/7 |
| Full suite passes | ✅ DONE | 0 failures |
| Commit pushed | ✅ DONE | `d76945e` |
