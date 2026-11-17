# FeroCalc — Phase 5.0.8: Remaining Bank Coverage & Official Rate Source Integration Report

**Milestone:** Phase 5.0.8 — Product & Data Pipeline Implementation
**Workspace:** `C:\projects\fincalc_pro_staging_prep`
**Git Branch:** `staging/vercel-backend-preview`
**Date:** November 12, 2026
**Status:** COMPLETE (All Backend & Flutter Test Suites Passing Cleanly)

---

## 1. Executive Summary

Phase 5.0.8 completes the remaining Indian banking institution coverage improvements in FeroCalc's Verified Rate Engine, focusing on:
1. **Unity Small Finance Bank (`UNITY_SFB`)**: Official source integration implementing a dedicated parser, source registry entry, collector implementation, and comprehensive test suite for retail callable deposits (< Rs. 3 Crore).
2. **Axis Bank (`AXIS`)**: Root cause investigation and resolution of the "retrying / 404" status by identifying Axis Bank's dynamic monthly PDF URL rotation, updating the source registry with the live official PDF (effective 09-Nov-2026), and engineering dynamic landing-page recovery with bounded exponential backoff.
3. **Kotak Mahindra Bank (`KOTAK`)**: Verified review-readiness of the official structured mailer endpoint, validating domestic retail callable bounds (< Rs. 3 Crore), senior citizen rate spreads (+0.50%), candidate deduplication, and strictly preserving review-gate status (`IN_REVIEW`) without automatic promotion.
4. **Cross-Bank Data Quality & Safety**: Enhanced decimal rate normalization, eliminated cross-section effective-date leakage, and validated candidate deduplication and anomaly detection defenses across all supported institutions.

All 46 backend test suites in `npm test` and 131 Flutter tests passed with zero failures. In accordance with mandatory safety boundaries, all ingestion schedules remain disabled (`enabled: false`), candidates remain staged in review, and no commits, pushes, or deployments were performed.

---

## 2. Mandatory Safety & Isolation Conformance

| Boundary Requirement | Enforced State | Evidence |
|---|---|---|
| Working Directory | `C:\projects\fincalc_pro_staging_prep` | Verified via Git branch and file paths |
| Target Branch | `staging/vercel-backend-preview` | Verified via `git status` |
| Production Workspace Isolation | `C:\projects\fincalc_pro` NEVER accessed | No reads, writes, or commands outside staging |
| Supabase Environment | Staging ref `cqrslxngpwbtkjejlwty` | Production ref `pmaykclwuyspxhgeomee` NEVER touched |
| Ingestion Schedules | `enabled: false` | All collectors in `source_registry.js` set to `enabled: false` |
| Home Screen Live Rates | DISABLED | Maintained launch-safe static/reference boundary |
| Candidate Promotion Gate | Zero auto-promotion | Candidates staged in `DRAFT`/`IN_REVIEW`; reviewer approval strictly required |
| Git Operations | Zero commits, pushes, or deployments | All changes preserved in working directory |

---

## 3. Initial State Verification & Catalog Assessment

Prior to implementation, the staging bank catalog and collector registry were inspected:

| Bank Entity | Initial Status | Verified Baseline / Live Condition | Action Taken in Phase 5.0.8 |
|---|---|---|---|
| **Unity Small Finance Bank** (`UNITY_SFB`) | Catalog-only | Official PDF disclosures available on `unity.bank.in` (< Rs. 3 Cr) | Implemented full parser, collector, registry, and 14 unit/integration tests |
| **Axis Bank** (`AXIS`) | Retrying / Error | Official PDF URL path rotated on 09-Nov-2026; old URL returned HTTP 404 | Updated active PDF URL; implemented dynamic landing-page discovery fallback |
| **Kotak Mahindra Bank** (`KOTAK`) | Review-pending | Structured mailer endpoint working; candidates staged in `IN_REVIEW` | Verified 18 slabs (36 candidates); validated bounds and review-readiness |
| **State Bank of India** (`SBI`) | Active / Verified | 18 domestic retail slabs verified (w.e.f. 2026-07-01) | Maintained regression coverage; 0 changes |
| **HDFC Bank** (`HDFC`) | Active / Verified | 16 domestic retail slabs verified (w.e.f. 2026-07-24) | Maintained regression coverage; 0 changes |
| **ICICI Bank** (`ICICI`) | Active / Verified | Retail callable slabs verified | Maintained regression coverage; 0 changes |
| **Bank of Baroda** (`BOB`) | Active / Verified | Retail callable slabs verified | Maintained regression coverage; 0 changes |
| **IDFC FIRST Bank** (`IDFC_FIRST`) | Active / Verified | 20 retail callable slabs verified (w.e.f. 2026-08-01) | Maintained regression coverage; 0 changes |
| **Union Bank of India** (`UNION_BANK`) | Active / Verified | 17 retail callable slabs verified (w.e.f. 2026-08-02) | Maintained regression coverage; 0 changes |
| **Punjab National Bank** (`PNB`) | Active / Verified | 16 retail callable slabs verified (w.e.f. 2026-08-01) | Maintained regression coverage; 0 changes |
| **IndusInd Bank** (`INDUSIND`) | Active / Verified | 17 retail callable slabs verified (w.e.f. 2026-08-05) | Maintained regression coverage; 0 changes |
| **UCO Bank** (`UCO`) | Active / Verified | 15 retail callable slabs verified (w.e.f. 2026-08-12) | Maintained regression coverage; 0 changes |
| **AU Small Finance Bank** (`AU_SFB`) | Active / Verified | 16 retail callable slabs verified (w.e.f. 2026-08-15) | Maintained regression coverage; 0 changes |
| **Canara Bank** (`CANARA`) | Active / Verified | 12 retail callable slabs verified (w.e.f. 2026-03-17) | Maintained regression coverage; 0 changes |
| **Central Bank of India** (`CENTRAL_BANK`) | Active / Verified | 14 retail callable slabs verified (w.e.f. 2026-08-10) | Maintained regression coverage; 0 changes |
| **Indian Bank** (`INDIAN_BANK`) | Active / Verified | 15 retail callable slabs verified (w.e.f. 2026-08-03) | Maintained regression coverage; 0 changes |

---

## 4. Unity Small Finance Bank (`UNITY_SFB`) — Official Source Integration

### 4.1 Official Source Attribution & Discovery
- **Official Bank Portal:** `https://theunitybank.com` redirects to `https://unity.bank.in`
- **Landing Page:** `https://unity.bank.in/personal-banking/deposits/fixed-deposit`
- **Official Rate Card Document:** `https://unity.bank.in/docs/policies/website-disclosure-effective-02-july-2026.pdf`
- **Target Section:** Section A: `A. FIXED DEPOSIT RATE : Retail Investors (< Rs 3 crs)`
- **Published Effective Date:** `11th June, 2026` (`2026-06-11`)
- **Exclusions Strictly Enforced:**
  - Section B (Savings Deposit Rates w.e.f. 19-Aug-2025)
  - Section C (Callable Bulk Deposit Rates $\ge 3$ Cr)
  - Section D (Non-Callable Bulk Deposit Rates $\ge 3$ Cr)

### 4.2 Slabs Extracted (20 Rows, 40 Candidates)
| Tenure Label | Tenure Domain | Canonical Identifier | Regular Rate | Senior Citizen Rate | Spread | Category |
|---|---|---|---|---|---|---|
| `7 - 14 Days` | DAYS | `7D_14D` | 4.00% | 4.00% | +0.00% | STANDARD |
| `15 - 45 Days` | DAYS | `15D_45D` | 4.00% | 4.00% | +0.00% | STANDARD |
| `46 - 60 Days` | DAYS | `46D_60D` | 4.75% | 5.25% | +0.50% | STANDARD |
| `61 - 90 Days` | DAYS | `61D_90D` | 5.00% | 5.50% | +0.50% | STANDARD |
| `91 - 164 Days` | DAYS | `91D_164D` | 5.00% | 5.50% | +0.50% | STANDARD |
| `165 Days - 6 Months` | CALENDAR | `165D_6M` | 5.50% | 6.00% | +0.50% | STANDARD |
| `> 6 Months - 201 Days` | DAYS | `6M1D_201D` | 6.25% | 6.75% | +0.50% | STANDARD |
| `202 Days - 364 Days` | DAYS | `202D_364D` | 6.25% | 6.75% | +0.50% | STANDARD |
| `12 Months` | CALENDAR | `1Y_1Y` | 7.50% | 8.00% | +0.50% | STANDARD |
| `12 Months 1 Day` | CALENDAR | `1Y1D_1Y1D` | 6.50% | 7.00% | +0.50% | STANDARD |
| `>12 Months 1 Day - 500 Days` | CALENDAR | `1Y2D_500D` | 6.50% | 7.00% | +0.50% | STANDARD |
| `501 Days` | DAYS | `501D_501D` | **7.80%** | **8.30%** | +0.50% | SPECIAL_SCHEME (`UNITY_501`) |
| `502 Days - 18 Months` | CALENDAR | `502D_1Y6M` | 6.75% | 7.25% | +0.50% | STANDARD |
| `> 18 Months - 700 Days` | CALENDAR | `1Y6M1D_700D` | 6.75% | 7.25% | +0.50% | STANDARD |
| `701 Days` | DAYS | `701D_701D` | 6.75% | 7.25% | +0.50% | SPECIAL_SCHEME (`UNITY_701`) |
| `702 Days to 998 Days` | DAYS | `702D_998D` | 6.75% | 7.25% | +0.50% | STANDARD |
| `999 Days to 34 Months` | CALENDAR | `999D_2Y10M` | 6.75% | 7.25% | +0.50% | STANDARD |
| `>34 Months - 36 Months` | CALENDAR | `2Y10M1D_3Y` | 6.75% | 7.25% | +0.50% | STANDARD |
| `>36 Months - 60 Months` | CALENDAR | `3Y1D_5Y` | 6.75% | 7.25% | +0.50% | STANDARD |
| `>60 Months - 120 Months` | CALENDAR | `5Y1D_10Y` | 6.00% | 6.50% | +0.50% | STANDARD |

### 4.3 Architecture & Implementation Details
1. **Parser:** `backend/parsers/unity_parser.js` (`UnityRateParser`).
   - Normalizes fragmented PDF tokens (`"202 6"` $\rightarrow$ `"2026"`, `"11 th"` $\rightarrow$ `"11th"`, `"4 . 00 %"` $\rightarrow$ `"4.00%"`).
   - Constrains effective date extraction strictly to Section A header (before column headers) to eliminate leakage from Section B or C dates.
   - Enforces SHA-256 calculation for candidate attribution.
2. **Factory:** Registered `UNITY_SFB` and `THE_UNITY_BANK` in `backend/parsers/parser_factory.js`.
3. **Registry:** Registered `unity-retail-domestic` in `backend/collectors/source_registry.js` with `enabled: false`.
4. **Collector:** Implemented `UnityCollector` in `backend/collectors/pilot_collectors.js` with custom User-Agent, domain validation, and fail-closed error handling.
5. **Domain Allowlist:** Added `unity.bank.in` and `theunitybank.com` to `BaselineAttestationService`, `PromotionPolicyEngine`, and `admin_rates.js`.
6. **Test Suite:** Created `backend/test/unity_parser_test.js` with 14 deterministic tests covering normalizations, special schemes, fail-closed handling, duplicate prevention, and anomaly rejection.

---

## 5. Axis Bank (`AXIS`) — Source Retry Resolution

### 5.1 Root Cause Analysis
- **Failure Signature:** `FETCH_FAILED` with HTTP 404 Not Found on the configured source URL.
- **Root Cause:** Axis Bank rotates its public PDF rate card URL on every rate revision by embedding dates into the filename path:
  - Previous URL: `.../interest-rates/domestic-fixed-deposit-interest-rates-less-than-3-crores-29-october-2026.pdf?sfvrsn=c1f0331d_1` (defunct, returns 404).
  - Active URL: `.../interest-rates/domestic-fixed-deposit-interest-rates-less-than-3-crores-09-november-26.pdf?sfvrsn=8b6dfa7d_1` (effective 2026-11-09).
- Hardcoding static dated URLs caused automated collectors to enter a perpetual retrying state once a new PDF was published.

### 5.2 Resolution & Dynamic Recovery Engine
1. **Source Registry Update:** Configured active live PDF `...09-november-26.pdf` in `backend/collectors/source_registry.js` and `backend/parsers/axis_parser.js`.
2. **Dynamic Landing-Page Recovery:** In `AxisCollector` (`backend/collectors/pilot_collectors.js`):
   - When the direct PDF fetch returns HTTP 404, the collector catches the error and queries the landing page `https://www.axis.bank.in/deposits/fixed-deposits/fd-interest-rates`.
   - Parses the HTML to discover the latest PDF link matching `/domestic-fixed-deposit-interest-rates-less-than-3-crores-.*\.pdf/i`.
   - Validates that the discovered link resolves within the strict domain allowlist (`axis.bank.in` or `axisbank.com`).
   - Downloads the new PDF stream dynamically.
3. **Bounded Retries with Backoff:** Configured 3 maximum retry attempts with exponential backoff (1s, 2s, 4s) and classified error codes (`HTTP_404_PATH_ROTATED`, `NETWORK_TIMEOUT`, `INVALID_STRUCTURE`).
4. **Verified Rate Preservation:** When all retries fail, existing verified rates in Supabase remain untouched and active; no stale or broken candidate records are created.
5. **Live Verification Findings:**
   - Ran `verify_axis_live_source.js`: Successfully fetched and parsed the 09-Nov-2026 PDF (18 rows, 36 candidates).
   - Detected +10 bps rate adjustments on longer tenures (2Y–10Y: Regular increased from 6.50% to 6.60%, Senior from 7.00%/7.25% to 7.10%/7.35%).
   - Rates were correctly staged in `DRAFT`/`IN_REVIEW` without automatic promotion, preserving reviewer governance.

---

## 6. Kotak Mahindra Bank (`KOTAK`) — Review Readiness

### 6.1 Status & Verification
- **Official Endpoint:** `https://www.kotak.bank.in/bank/mailers/intrates/get_all_variable_data_latest.php?section=NRO_Term_Deposit`
- **Format:** JavaScript `document.write("<table>...")` containing structured HTML tables.
- **Candidate Count:** Exactly 18 callable retail rows generating 36 candidates (18 regular, 18 senior citizen).
- **Deposit Limits:** Domestic retail deposit bounds strictly verified: min deposit Rs. 5,000, max deposit < Rs. 3 Crore. Columns 2 and 4 (bulk deposits $\ge 3$ Cr) are strictly excluded.
- **Tenure Domains:** 11 DAYS domain slabs (7-14d, 15-30d, 31-45d, 46-90d, 91d, 92-179d, 180d, 181-269d, 270d, 271-363d, 364d) and 7 CALENDAR domain slabs (365d-<15m, 15m-<18m, 18m-<2y, 2y-<3y, 3y-<4y, 4y-<5y, 5y-10y).
- **Senior Citizen Spread:** +0.50% additional interest rate strictly validated across all tenures.
- **Review Readiness:** Candidates remain in `IN_REVIEW`. No automatic promotion occurred; no reviewer approvals were fabricated.

---

## 7. Cross-Bank Data Quality & Defense Enhancements

1. **Decimal Rate Preservation:** Fixed decimal regex normalization (`replace(/(\d+)\s*%/g, ...)`) to ensure existing decimals (`4.00%`) are preserved without double-appending `.00%`.
2. **Section Isolation:** Restricted effective-date extraction in multi-table documents (e.g. Unity SFB) strictly to the Section A header, preventing leakage from savings or bulk deposit tables.
3. **Deterministic Duplicate Prevention:** `CandidateValidator.validateBatch` groups by composite key `(bankCode, productType, customerType, isCallable, rateCategory, schemeName, tenureKey, minDeposit, maxDeposit)` and fails closed on any collision.
4. **Anomaly Detection:** Configured `AnomalyDetector` to intercept any rate movements $> 0.50\%$ (50 bps) or candidate count deviations $> 40\%$, instantly flagging candidates and forcing `IN_REVIEW` status.
5. **Verified-Rate Preservation:** Collectors fail closed upon network or structure errors, ensuring that active published rates in the consumer application are never overwritten by failed ingestion runs.

---

## 8. Trust Center & Consumer UI Integration

In the FeroCalc Flutter application:
- **Verified Official Rates Display:** Shows verified rates for 13 fully attested institutions (SBI, HDFC, ICICI, BOB, IDFC FIRST, Union Bank, PNB, IndusInd, UCO, AU SFB, Canara, Central Bank, Indian Bank).
- **Awaiting Review Status:** Axis Bank, Kotak Mahindra Bank, and Unity SFB candidates are clearly segregated in the Data Trust Center as awaiting review, never displayed as verified live rates.
- **Catalog-Only / Reference:** Banks without active official collector integration display transparent reference status without misleading verified badges.
- **Smart FD Discovery:** Filtering and comparison engines only pull verified rates with active attestation, completely ignoring draft or in-review candidates.

---

## 9. Test Execution & Verification Results

### 9.1 Backend Test Suites (`npm test`)
Command: `npm test` inside `backend/`
Total Test Suites: **46 suites**
Result: **46 passed, 0 failed (100% pass)**

```
======================================================
Backend Test Execution Summary (46 Suites)
======================================================
- env_loader_test: PASS (8/8)
- collector_test: PASS (19/19)
- extraction_test: PASS (14/14)
- promotion_test: PASS (12/12)
- scheduler_test: PASS (10/10)
- baseline_attestation_test: PASS (15/15)
- verified_rates_api_test: PASS (16/16)
- sbi_wecare_remediation_test: PASS (12/12)
- lock_and_evidence_safety_test: PASS (8/8)
- write_path_safety_design_test: PASS (10/10)
- native_null_identity_test: PASS (9/9)
- exact_numeric_identity_test: PASS (11/11)
- sbi_qualified_senior_rate_regression_test: PASS (14/14)
- cross_bank_qualified_rate_regression_test: PASS (16/16)
- hdfc_r3_calendar_tenure_regression_test: PASS (15/15)
- calendar_staging_and_diff_regression_test: PASS (13/13)
- idfc_first_parser_test: PASS (14/14)
- union_bank_parser_test: PASS (14/14)
- pnb_parser_test: PASS (14/14)
- indusind_parser_test: PASS (14/14)
- uco_parser_test: PASS (14/14)
- au_small_finance_parser_test: PASS (14/14)
- canara_parser_test: PASS (15/15)
- central_bank_parser_test: PASS (14/14)
- axis_parser_test: PASS (15/15)
- indian_bank_parser_test: PASS (14/14)
- hdfc_live_verifier_test: PASS (12/12)
- curl_transport_hardening_test: PASS (10/10)
- cors_origin_policy_test: PASS (19/19)
- cors_integration_test: PASS (8/8)
- baseline_cli_read_only_safety_test: PASS (8/8)
- end_to_end_rate_refresh_test: PASS (10/10)
- rbac_least_privilege_test: PASS (12/12)
- run_extraction_read_only_safety_test: PASS (8/8)
- candidate_promotion_pipeline_defect_test: PASS (11/11)
- source_provenance_linkage_test: PASS (8/8)
- sbi_tenure_domain_normalization_test: PASS (12/12)
- promotion_gate_correctness_regression_test: PASS (14/14)
- stale_review_reconciliation_regression_test: PASS (10/10)
- clean_review_recovery_regression_test: PASS (10/10)
- policy_escalation_persistence_test: PASS (11/11)
- verified_rates_history_api_test: PASS (15/15)
- bob_parser_test: PASS (14/14)
- kotak_parser_test: PASS (14/14)
- verified_rate_notification_test: PASS (23/23)
- unity_parser_test: PASS (14/14)
======================================================
TOTAL SUITES: 46 | PASSED: 46 | FAILED: 0
======================================================
```

### 9.2 Key Focus Test Suites
- **Unity Small Finance Bank:** `npm run test:unity` $\rightarrow$ 14 passed, 0 failed.
- **Axis Bank:** `npm run test:axis` $\rightarrow$ 15 passed, 0 failed.
- **Kotak Mahindra Bank:** `npm run test:kotak` $\rightarrow$ 14 passed, 0 failed.

### 9.3 Flutter Test Suites
Command: `flutter test test/data_trust_center_test.dart test/smart_fd_discovery_engine_test.dart test/smart_fd_discovery_widget_test.dart test/verified_fd_rate_engine_test.dart test/verified_rate_integration_test.dart test/verified_rate_service_test.dart`
Total Tests: **131 tests**
Result: **131 passed, 0 failed (100% pass)**

---

## 10. Files Modified & Created

### Modified Files:
1. `backend/package.json` — Registered `test:unity` script and appended to master `test` pipeline.
2. `backend/collectors/source_registry.js` — Registered `unity-retail-domestic` (`enabled: false`) and updated `axis-retail-domestic` active live PDF URL and landing page.
3. `backend/collectors/pilot_collectors.js` — Implemented `UnityCollector` and enhanced `AxisCollector` with dynamic landing-page recovery.
4. `backend/parsers/axis_parser.js` — Updated active live PDF URL and maintained normalization parity.
5. `backend/parsers/parser_factory.js` — Registered `UnityRateParser` for `UNITY_SFB` and `THE_UNITY_BANK`.
6. `backend/attestation/baseline_attestation_service.js` — Added `unity.bank.in` and `theunitybank.com` to official domain allowlist.
7. `backend/promotion/promotion_policy_engine.js` — Added `unity.bank.in` and `theunitybank.com` to promotion domain allowlist.
8. `backend/routes/admin_rates.js` — Added `unity.bank.in` and `theunitybank.com` to admin rates allowlist.
9. `backend/scripts/verify_axis_live_source.js` — Updated live verification script to read from registry and handle fallback.

### Created Untracked Files:
1. `backend/parsers/unity_parser.js` — Dedicated Unity Small Finance Bank PDF rate card parser (`UnityRateParser`, `parseUnityTenure`).
2. `backend/test/unity_parser_test.js` — Comprehensive 14-test unit and reliability suite for Unity SFB.
3. `ferocalc_phase5_0_8_bank_coverage_source_integration_report.md` — This milestone report.

---

## 11. Remaining Institutional Coverage & Technical Limitations

1. **Scheduled Ingestion Remains Disabled:** In compliance with milestone restrictions, all collectors in `source_registry.js` remain set to `enabled: false`. Background cron schedules remain inactive.
2. **Reviewer Approvals Required:**
   - Unity SFB candidates (40 candidates w.e.f. 2026-06-11) require human reviewer attestation prior to production promotion.
   - Axis Bank updated candidates (36 candidates w.e.f. 2026-11-09) require reviewer sign-off to update existing baseline slabs.
   - Kotak Mahindra Bank candidates (36 candidates) require authorized review workflow sign-off.
3. **Institutions with Future Official Automation Roadmap:**
   - Federal Bank, RBL Bank, Yes Bank, and other scheduled commercial banks remain catalog-only until dedicated official parsers and attestation baselines are constructed.
4. **No Destructive Actions Performed:** No commits, pushes, or deployments have been executed. All work is preserved cleanly in `staging/vercel-backend-preview`.
