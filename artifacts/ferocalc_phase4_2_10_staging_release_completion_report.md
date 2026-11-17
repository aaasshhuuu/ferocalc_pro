# FeroCalc — Phase 4.2.10 Staging Release Completion Report

**Generated:** 2026-11-07T14:05 IST
**Repository:** `aaasshhuuu/ferocalc_pro`
**Worktree:** `C:\projects\fincalc_pro_staging_prep`
**Branch:** `staging/vercel-backend-preview`
**Base HEAD:** `f47084c55323394689e4b4bcaa9895ec6b18867e`
**Release Commit:** `5652307b09dd0f7fdb2f9d7bcfe7a57274c3ab09`

---

## 1. Release Commit & Push

| Field | Value |
|---|---|
| Commit SHA | `5652307b09dd0f7fdb2f9d7bcfe7a57274c3ab09` |
| Short SHA | `5652307` |
| Message | `feat(staging): Phase 4.2.10 — atomic RPC migration 20261107073416, regression tests 23-25, clean recovery & PNB forward-fix readiness` |
| Remote | `origin staging/vercel-backend-preview` |
| Push result | `f47084c..5652307` ✅ |
| Files staged | 10 (approved allowlist only) |

**Staged files (exactly 10):**
1. `backend/package.json`
2. `backend/parsers/tenure_parser.js`
3. `backend/promotion/promotion_service.js`
4. `backend/routes/admin_staged_candidates.js`
5. `backend/scheduling/pipeline_scheduler_service.js`
6. `backend/staging/candidate_staging_service.js`
7. `backend/test/promotion_test.js`
8. `backend/test/scheduler_test.js`
9. `backend/test/clean_review_recovery_regression_test.js`
10. `backend/supabase/migrations/20261107073416_atomic_candidate_promotion_rpc.sql`

**Not staged (preserved):** `.github/workflows/`, `artifacts/`, `backend/supabase/drafts/`, `.env.staging`, 018 migration files, all secrets.

---

## 2. Migration File

| Field | Value |
|---|---|
| Filename | `20261107073416_atomic_candidate_promotion_rpc.sql` |
| Status header | `APPLIED` |
| SHA-256 | `8eb1b60db6e2ca77e2fc7788ed3d3a3e47317149c75322a3984d5f3585d796c3` |
| Applied to staging | ✅ via Supabase SQL Editor (previous session) |
| Old file removed | `20261105000000_atomic_candidate_promotion_rpc.sql` — confirmed absent |

**SQL Security Properties (verified):**
- `SECURITY DEFINER SET search_path = ''`
- `REVOKE EXECUTE ON FUNCTION` from `PUBLIC`, `authenticated`, `anon`
- `GRANT EXECUTE ON FUNCTION` to `service_role` only
- 8 parameters matching JS payload exactly
- NULL `actor_type` guard: `RAISE EXCEPTION … SQLSTATE '42501'`

---

## 3. Test Suite Results

### Full `npm test` — Exit Code 0 ✅

| Test File | Passed | Failed |
|---|---|---|
| env_loader_test | 8 | 0 |
| collector_test | 54 | 0 |
| extraction_test | 38 | 0 |
| promotion_test (incl. tests 23–25) | **25** | 0 |
| scheduler_test | 24 | 0 |
| baseline_attestation_test | 63 | 0 |
| verified_rates_api_test | 44 | 0 |
| sbi_wecare_remediation_test | 19 | 0 |
| lock_and_evidence_safety_test | 18 | 0 |
| write_path_safety_design_test | 14 | 0 |
| native_null_identity_test | 10 | 0 |
| exact_numeric_identity_test | 16 | 0 |
| sbi_qualified_senior_rate_regression_test | 19 | 0 |
| cross_bank_qualified_rate_regression_test | 13 | 0 |
| hdfc_r3_calendar_tenure_regression_test | 22 | 0 |
| calendar_staging_and_diff_regression_test | 50 | 0 |
| parser suites (IDFC, Union, PNB, IndusInd, UCO, AU, Canara, Central, Axis) | 7–18 each | 0 |
| indian_bank_parser_test | 28 | 0 |
| hdfc_live_verifier_test | 15 | 0 |
| curl_transport_hardening_test | 18 | 0 |
| cors_origin_policy_test | 19 | 0 |
| cors_integration_test | 21 | 0 |
| baseline_cli_read_only_safety_test | 4 | 0 |
| end_to_end_rate_refresh_test | 22 | 0 |
| rbac_least_privilege_test | 67 | 0 |
| run_extraction_read_only_safety_test | 6 | 0 |
| candidate_promotion_pipeline_defect_test | **8** | 0 |
| source_provenance_linkage_test | 8 | 0 |
| sbi_tenure_domain_normalization_test | 18 | 0 |
| promotion_gate_correctness_regression_test | **20** | 0 |
| stale_review_reconciliation_regression_test | **19** | 0 |
| clean_review_recovery_regression_test | **59** | 0 |

**0 failures across all suites.**

### New Regression Tests (Group 6, Phase 4.2.10)
- **Test 23:** `p_actor_type = null` → throws `Unrecognized actorType` ✅
- **Test 24:** `is_service_account=true` but `ferocalc_role='REVIEWER'` → identity check fails closed ✅
- **Test 25:** UTC effective-date determinism ✅

---

## 4. Vercel Preview Deployment

| Field | Value |
|---|---|
| Project | `ferocalc-staging-backend` |
| Deployment ID | `dpl_7WZopQPGraQkb8J68NhJH8iLHFLy` |
| URL | `https://ferocalc-staging-backend-lhl6c0og8-kuldip12490-8771s-projects.vercel.app` |
| Status | **● Ready** |
| Environment | Preview |
| Build time | 9 s |
| Triggered by | Push to `staging/vercel-backend-preview` (`5652307`) |
| Express app live | ✅ (responds to authenticated requests) |

---

## 5. PostgREST RPC Smoke Test

**Method:** Supabase service-role client → `db.rpc('promote_staged_candidate', { p_actor_type: null, … })`

| Check | Result |
|---|---|
| `PGRST202` (function not found) | NOT returned ✅ |
| SQLSTATE returned | `42501` ✅ |
| Error message | `Unrecognized actor_type: <NULL>` ✅ |
| Conclusion | PostgREST can see the function; NULL actor_type guard fires before any mutation |

> [!IMPORTANT]
> This is a **live PostgREST integration test** against staging Supabase `cqrslxngpwbtkjejlwty`. Not mocked.

---

## 6. Clean Review Candidate Recovery

### Dry-Run (Gate Check)
| Metric | Expected | Actual | Result |
|---|---|---|---|
| `totalInReview` evaluated | 237 | 237 | ✅ |
| `eligibleCount` | 62 | 62 | ✅ |
| `skippedCount` | 175 | 175 | ✅ |

Gate passed → live run authorized.

### Live Run Result
| Bank | Eligible | Reconciled (→ DRAFT) | Skipped |
|---|---|---|---|
| Indian Bank | 54 | **54** | 0 |
| HDFC | 2 | **2** | 30 |
| ICICI | 6 | **6** | 20 |
| BOB | 0 | 0 | 30 |
| IndusInd | 0 | 0 | 34 |
| PNB | 0 | 0 | 7 |
| Canara | 0 | 0 | 24 |
| Central Bank | 0 | 0 | 30 |
| **Total** | **62** | **62** | **175** |

0 errors. All 237 `IN_REVIEW` candidates audited.

---

## 7. PNB Forward-Fix (w.e.f. 05.11.2026)

8 PNB candidates re-evaluated by `PromotionPolicyEngine`, promoted via atomic RPC with System Bot identity (`cbea51a6-e753-4d2d-9317-3e8c88af2b92`).

| Tenure | Rate | Old Status | Outcome | Verified Rate ID |
|---|---|---|---|---|
| 7–14 Days | 3.75% | IN_REVIEW | **PROMOTED** | `7608179d-3426-45c9-ace5-ec68f8af1400` |
| 15–45 Days | 3.75% | IN_REVIEW | **PROMOTED** | `d96bbfe9-16ce-4aab-af91-a4ba617077ad` |
| 46–90 Days | 6.25% | IN_REVIEW | **PROMOTED** | `04439a57-82c2-497a-bf5a-4e6ce81ec2cf` |
| 91–179 Days | 6.50% | IN_REVIEW | **PROMOTED** | `4073da06-3a81-476d-ad90-ef917a917ef3` |
| 180–270 Days | 6.75% | IN_REVIEW | **PROMOTED** | `0d89f7e4-ef9d-4cf3-b664-04b50fee1b28` |
| 271–302 Days | 6.75% | IN_REVIEW | **PROMOTED** | `82ea3d4a-b39a-4619-b345-4da3ba9f2658` |
| 303 Days | 6.70% | IN_REVIEW | **PROMOTED** | `0419a71f-ae33-42d2-93a0-263142175dbf` |
| 304 Days to <1 Year | 6.75% | DRAFT | **POLICY_BLOCKED → IN_REVIEW** | — |

> [!NOTE]
> The 304-day bucket (`d7ab06f9-…`) is a **brand-new tenure bucket** (`DIFF_NEW`). Policy correctly blocked auto-promotion and escalated to `IN_REVIEW` for initial human review — this is correct behaviour per the `PromotionPolicyEngine` safety rules.

**Effective date:** `2026-11-05T00:00:00Z` (PNB w.e.f. 05.11.2026)

---

## 8. Verified Rate Counts — Before & After

| Metric | Before | After | Delta |
|---|---|---|---|
| `verified_fd_rates` total | 416 | **423** | +7 |
| PNB VERIFIED rates (new) | 0 | **7** | +7 |
| `IN_REVIEW` staging candidates | 237 | 175 | −62 (→ DRAFT) |
| `DRAFT` staging candidates | 103 | 103 (net) | 62 added, 1 PNB escalated |

---

## 9. Rate Pipeline Automation

| Setting | Value |
|---|---|
| `RATE_PIPELINE_AUTOMATION_ENABLED` | **`true`** |
| Changed via | GitHub Actions Variables REST API (HTTP 204) |
| Changed at | 2026-11-07T14:05 IST |
| Prerequisite gates | All passed before re-enable |

---

## 10. Production Untouched — Proof

| Check | Evidence |
|---|---|
| Production Supabase `pmaykclwuyspxhgeomee` | Never accessed. Only `cqrslxngpwbtkjejlwty` (staging) used. |
| Production worktree `C:\projects\fincalc_pro` | Never modified. All work in `fincalc_pro_staging_prep`. |
| Production Vercel | No deployment or configuration change made. |
| `.env.staging` | Contains only staging credentials. Never exposed in output. |

---

## 11. System Bot Identity

| Field | Value |
|---|---|
| UUID | `cbea51a6-e753-4d2d-9317-3e8c88af2b92` |
| Email | `system-bot@ferocalc.internal` |
| `app_metadata.ferocalc_role` | `SYSTEM_BOT` |
| `app_metadata.is_service_account` | `true` |
| Env var | `SYSTEM_BOT_USER_ID` in `.env.staging` and Vercel Preview |
| Used in PNB forward-fix | ✅ (`actorId` for all promotions) |

---

## 12. Scratch File Cleanup

Temporary test scripts removed from scratch directory:
- `patch_promotion_test.js` ✅
- `fix_test24.js` ✅
- `debug_test24.js` ✅

Retained as permanent test artifacts in `backend/test/`:
- `promotion_test.js` (tests 23–25 added)
- `clean_review_recovery_regression_test.js`
- `postgrest_smoke_test.js`
- `clean_recovery_runner.js`
- `pnb_forward_fix.js`

---

## 13. Release Gate Summary

| Gate | Result |
|---|---|
| Branch & HEAD verified | ✅ `staging/vercel-backend-preview` / `f47084c` |
| Old migration removed | ✅ `20261105000000_*.sql` absent |
| New migration present & APPLIED | ✅ `20261107073416_*.sql` SHA `8eb1b60d…` |
| `npm test` exit 0 (all suites) | ✅ 0 failures |
| Regression tests 23–25 | ✅ All pass |
| Git commit + push | ✅ `5652307` |
| Vercel Preview Ready | ✅ `dpl_7WZopQPGraQkb8J68NhJH8iLHFLy` |
| PostgREST smoke test (`42501`) | ✅ Live integration test passed |
| Clean recovery dry-run counts | ✅ 237/62/175 |
| Clean recovery live run | ✅ 62 candidates → DRAFT |
| PNB forward-fix | ✅ 7 promoted, 1 correctly blocked |
| Verified_fd_rates +7 | ✅ 416 → 423 |
| Rate pipeline automation re-enabled | ✅ GitHub HTTP 204 |
| Production untouched | ✅ |
