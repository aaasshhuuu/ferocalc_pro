# FeroCalc — Phase 5.1.1: Final Production Release Candidate Assembly & Google Play Submission Preparation Report

**Document Version:** 1.0.0 (Release Candidate Final)
**Execution Timestamp:** November 13, 2026
**Target Platform:** Android 16 (API 36) / Minimum Android API 21 (Android 5.0 Lollipop)
**Package Identifier:** `com.ferocalc.app`
**Distribution Region:** India (`IN`) Only
**Git Working Branch:** `staging/vercel-backend-preview`
**Working Repository Directory:** `C:\projects\fincalc_pro_staging_prep`
**Final Pre-Production Verdict:** **`READY FOR FINAL OWNER INPUTS (BLOCKED — SPECIFIED ITEMS REMAIN)`**

---

## 1. Executive Summary & Objective Realization

Phase 5.1.1 represents the final pre-production preparation milestone for FeroCalc. All architectural implementations, financial algorithms, rate discovery pipelines, privacy protections, and automated regression test suites have been assembled, hardened, and verified under strict release protocols.

### Key Milestone Achievements:
1. **100% Automated Test Pass Rate:**
   - **Flutter Test Suite:** All 45 test files and **696 individual tests passed with zero failures** (`flutter test`).
   - **Flutter Static Analysis:** Clean analysis with **0 errors and 0 warnings** (90 informational hints) (`flutter analyze --no-fatal-infos`).
   - **Backend API Suite:** All **46 backend test suites passed with zero failures** (`npm test` in `backend/`).
2. **Android Production Candidate Verified:**
   - Target SDK set to **Android 16 (API 36)** with backward compatibility to API 21.
   - Application label: `FeroCalc`, package: `com.ferocalc.app`, version: `1.0.1+7`.
   - Single release manifest permission: `android.permission.INTERNET`. Zero SMS, contacts, camera, or fine location permissions.
   - Strict network security: `android:usesCleartextTraffic="false"` (HTTPS-only).
   - Cloud backup privacy isolation: `FlutterSharedPreferences.xml` explicitly excluded in `data_extraction_rules.xml` and `backup_rules.xml`, guaranteeing that personal financial figures and anonymous installation tokens never leave the local device.
3. **Fail-Closed Release Signing Safeguard Confirmed:**
   - Gradle `signingReport` confirmed `Store: null` and `Alias: null` when production keys are absent.
   - Attempting `flutter build appbundle --release` without production signing keys failed closed as designed (`Execution failed for task ':app:signReleaseBundle'`), preventing unauthenticated or debug-signed bundles from ever being published.
   - Explicit authorized staging QA path (`FEROCALC_STAGING_DEBUG_SIGNING=true`) successfully generated a verified **69.2 MB staging QA APK** (`build/app/outputs/flutter-apk/app-release.apk`) for pre-launch preview on test devices.
4. **Complete Store Listing Package Prepared:**
   - Complete Google Play store listing package compiled in `docs/release/final_store_listing_package.md`.
   - Title, short description (73 chars), full description, search keywords, graphics inventory, feature graphic blueprint (1024 × 500 px), and genuine screenshot inventory (7 real app screens).
   - High-resolution icon verified: `assets/images/ferocalc_icon.png` is exactly 512 × 512 px (91.4 KB).
5. **Legal & Regulatory Documents Finalized:**
   - Synchronized consistency across `docs/legal/privacy_policy.md`, `terms_of_use.md`, `financial_disclaimer.md`, in-app screens, and Google Play Data Safety draft.
   - Explicit statutory references for TDS: Section 194A (Income-tax Act, 1961) for pre-April 2026 interest and Section 393(1), Table Serial No. 5(ii) (Income-tax Act, 2025) for interest paid on or after 1 April 2026.
   - DICGC deposit insurance limit of ₹5 Lakh per depositor per bank explicitly stated.
   - Honest representation: Consumer accounts do not exist; anonymous device notification registration data deletion is provided both in-app and via email.
6. **Production Infrastructure Runbook & Consolidated Owner Action Package:**
   - Step-by-step production runbook generated in `docs/release/final_production_deployment_runbook.md` detailing Supabase migrations (001 through 015 + post-Phase 4 migrations) and Vercel production deployment.
   - All outstanding human prerequisites consolidated into ONE single action checklist in `docs/release/final_owner_action_checklist.md`.

---

## 2. Environment Safety & Isolation Compliance Audit

Strict adherence to environment safety protocols was maintained throughout this phase:

| Safety Protocol Requirement | Compliance State | Verification Evidence |
| :--- | :--- | :--- |
| **Work strictly in staging worktree** | **COMPLIANT** | All operations executed exclusively within `C:\projects\fincalc_pro_staging_prep`. |
| **Branch verification** | **COMPLIANT** | Branch confirmed as `staging/vercel-backend-preview`. |
| **Never access `fincalc_pro`** | **COMPLIANT** | Main development worktree `C:\projects\fincalc_pro` was never accessed or modified. |
| **Never access production Supabase** | **COMPLIANT** | Production Supabase database `pmaykclwuyspxhgeomee` was untouched during this phase. |
| **Preserve all existing work** | **COMPLIANT** | Zero destructive git operations (no resets, cleanups, or branch deletions). |
| **No unauthorized Git actions** | **COMPLIANT** | Zero commits, zero pushes, and zero remote deployments were executed. |
| **No fake credentials** | **COMPLIANT** | No fake production keystore, dummy certificates, or fake publisher names were generated. |
| **No live rate / ingestion activation** | **COMPLIANT** | Automated live scrapers and ingestion crons remained disabled. Offline test fixtures utilized. |

---

## 3. Application Integration Verification (Phases 4.3.x through 5.1.0.1)

All features implemented across preceding development phases were inspected and verified as fully integrated without duplicate code or feature conflicts:

| Subsystem / Feature Module | Implemented Scope & Capabilities | Verification Method | Status |
| :--- | :--- | :--- | :--- |
| **18+ Financial Calculators** | FD, RD, SIP, EMI, PPF, SSY, Inflation, Compound Interest, CAGR, Dividend Yield, Credit Card EMI, Home Loan Eligibility, Gratuity, NPS, SWP, Lumpsum, EPF, Income Tax. | Calculator unit tests, mathematical audit | **VERIFIED INTEGRATED** |
| **Official Verified FD Rates** | Multi-source bank rate catalog (SBI, HDFC, ICICI, Kotak, PNB, BOB, Axis, IndusInd, AU SFB, Unity SFB, etc.). | Collector & parser test suites, source provenance linkage | **VERIFIED INTEGRATED** |
| **Smart FD Discovery** | Filter by tenure, min deposit, bank type; sort by yield; toggle Senior Citizen rates. | `smart_fd_discovery_engine_test.dart`, widget tests | **VERIFIED INTEGRATED** |
| **Advanced FD Comparison** | Side-by-side comparison between any two banks, interest yield delta, broken-period notes. | `two_bank_comparison_test.dart`, `compare_screen_layout_test.dart` | **VERIFIED INTEGRATED** |
| **Calculator Hub** | Categorized view (Deposits, Investments, Loans, Taxes, Retirement), instant search, favorite pinning. | `calculators_hub_test.dart` | **VERIFIED INTEGRATED** |
| **Saved Calculations** | Local calculation persistence, deduplication, rapid tap defense, individual & bulk deletion. | `calculation_history_test.dart`, `saved_calculations_and_goal_planner_test.dart` | **VERIFIED INTEGRATED** |
| **Financial Goal Planner** | Goal creation, monthly savings target computation, progress tracking, local storage. | `goal_planner_screen_test.dart` | **VERIFIED INTEGRATED** |
| **Favorite Banks** | Save preferred banks, quick access filtering, notification preference linkage. | `favorite_banks_screen.dart`, unit tests | **VERIFIED INTEGRATED** |
| **Notifications & Preferences** | Verified rate change alert preferences, bank selection, in-app notification center. | `notifications_and_personalization_test.dart` | **VERIFIED INTEGRATED** |
| **Data Trust Center** | Complete data storage transparency, on-device financial privacy guarantees, local cache clearing. | `data_trust_center_test.dart` | **VERIFIED INTEGRATED** |
| **Financial Insights** | Private on-device financial health score, emergency fund coverage, debt-to-income ratio. | `financial_insights_dashboard_test.dart` | **VERIFIED INTEGRATED** |
| **Admin Dashboard** | Staff console for reviewing staged rate candidates, diff inspection, atomic promotion RPC. | `admin_dashboard_widget_test.dart`, `admin_models_and_services_test.dart` | **VERIFIED INTEGRATED** |
| **Legal & Disclaimers** | Privacy Policy, Terms of Use, Financial Disclaimers, AdMob disclosures, DICGC & TDS notes. | `privacy_security_and_compliance_test.dart` | **VERIFIED INTEGRATED** |

---

## 4. Complete Regression Verification Results

### 1. Flutter Test Suite (`flutter test`)
- **Total Test Files:** 45 files
- **Total Tests Run:** 696 tests
- **Tests Passed:** **696 (100%)**
- **Tests Failed:** **0**
- **Duration:** 2 minutes 52 seconds

### 2. Flutter Code Analysis (`flutter analyze --no-fatal-infos`)
- **Errors:** **0**
- **Warnings:** **0**
- **Informational Hints:** 90 (minor deprecation suggestions, e.g. `.withValues()` and trailing commas)
- **Status:** **CLEAN** (Exited with code 0)

### 3. Backend Test Suite (`npm test` in `backend/`)
- **Test Suites Executed:** 46 suites
- **Total Test Assertions:** > 300 assertions
- **Test Suites Passed:** **46 (100%)**
- **Test Suites Failed:** **0**
- **Key Suites Verified:**
  - `env_loader_test.js`: Deterministic path resolution and fail-closed secret safety.
  - `collector_test.js`: Deterministic SHA-256 source hashing across bank portals.
  - `rbac_least_privilege_test.js`: Reviewer role restricted from modifying bank catalog.
  - `verified_rate_notification_test.js`: Verified-only alert dispatching, deterministic event hashing, anonymous device token registration, and cryptographic deletion (`DELETE /api/notifications/device-token`).
  - `exact_numeric_identity_test.js`: Exact decimal precision boundaries (`NUMERIC(18,2)`).

---

## 5. Android Production Candidate Technical Audit

| Property / Component | Configured Value | Verification Source | Compliance Status |
| :--- | :--- | :--- | :--- |
| **Package Name** | `com.ferocalc.app` | `android/app/build.gradle.kts` | **VERIFIED** |
| **Version Name** | `1.0.1` | `pubspec.yaml` (line 4) | **VERIFIED** |
| **Version Code** | `7` | `pubspec.yaml` (line 4: `1.0.1+7`) | **VERIFIED** |
| **Compile SDK Version** | `36` (Android 16) | `android/app/build.gradle.kts` (line 42) | **VERIFIED** |
| **Target SDK Version** | `36` (Android 16) | `android/app/build.gradle.kts` (line 56) | **VERIFIED** |
| **Min SDK Version** | `21` (Android 5.0) | `android/app/build.gradle.kts` (line 55) | **VERIFIED** |
| **Application Label** | `FeroCalc` | `AndroidManifest.xml` (line 5) | **VERIFIED** |
| **App Icon** | `@mipmap/ic_launcher` | `AndroidManifest.xml` (lines 7, 8) | **VERIFIED** |
| **Declared Permissions**| `android.permission.INTERNET` ONLY | `AndroidManifest.xml` (line 2) | **VERIFIED (Zero Sensitive Permissions)** |
| **Network Security** | `android:usesCleartextTraffic="false"` | `AndroidManifest.xml` (line 12) | **VERIFIED (HTTPS Enforced)** |
| **Cloud Backup Exclusions**| Excludes `FlutterSharedPreferences.xml` | `data_extraction_rules.xml` & `backup_rules.xml` | **VERIFIED (Privacy Protected)** |
| **AdMob App ID (Release)**| `ca-app-pub-6265679606207808~8961400103` | `AndroidManifest.xml` (line 40) | **VERIFIED** |
| **Minification / R8** | `isMinifyEnabled = false` | `android/app/build.gradle.kts` (line 102) | **VERIFIED** |
| **Resource Shrinking** | `isShrinkResources = false` | `android/app/build.gradle.kts` (line 103) | **VERIFIED** |
| **Fail-Closed Release Signing**| `Store: null` without `key.properties` | `android/app/build.gradle.kts` (lines 73-83) | **VERIFIED (Fails closed on bundleRelease)** |
| **Staging QA APK Output** | `app-release.apk` (69.2 MB) | `build/app/outputs/flutter-apk/` | **VERIFIED (Built via authorized staging path)** |

---

## 6. Store Listing Package & Graphics Inventory Summary

The complete Google Play store listing package has been assembled in `docs/release/final_store_listing_package.md`:
- **Final App Title:** `FeroCalc — FD & EMI Calculator` (30 characters).
- **Alternative Title:** `FeroCalc: FD, RD, SIP & EMI` (27 characters).
- **Short Description:** `Smart FD rates, SIP, EMI, PPF & compound interest calculators for India.` (73 characters).
- **Full Description:** Comprehensive, structured description covering offline-ready local storage, verified bank rate directory, 18+ financial calculators, DICGC insurance notices, and TDS tax disclosures.
- **Search Keywords:** High-intent search terms targeting Indian savers and investors.
- **Graphics Inventory:**
  - **High-Res Icon:** `assets/images/ferocalc_icon.png` (512 × 512 px, 32-bit PNG, 91.4 KB) — **READY in repository**.
  - **Adaptive Foreground Icon:** `assets/images/ferocalc_foreground.png` (432 × 432 px, 48.2 KB) — **READY in repository**.
  - **Feature Graphic Blueprint:** 1024 × 500 px specification, design safe zone (800 × 400 px), and color scheme (`#000B1B`, `#00D26A`, `#0A192F`).
  - **Screenshot Inventory:** 7 genuine screen captures mapped to actual UI flows (Home, FD Discovery, Compare, EMI & Amortization, Financial Insights, Goal Planner, and Data Trust Center).

---

## 7. Legal Document Finalization & Statutory Consistency

Consistency across `docs/legal/privacy_policy.md`, `terms_of_use.md`, `financial_disclaimer.md`, in-app screens, and Google Play Data Safety draft was verified:

1. **Publisher Identity Placeholders:**
   - Placeholders `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_ADDRESS]` are established and ready for owner input.
   - Support and privacy contact consistently set to `ferocalc.app@gmail.com`.
2. **Taxation & TDS Statutory Framework:**
   - **Pre-April 2026 Payments:** Governed by Section 194A of the Income-tax Act, 1961 (withholding threshold: ₹50,000 for senior citizens, ₹40,000 for regular depositors).
   - **Post-April 2026 Payments:** Governed by Section 393(1), Table Serial No. 5(ii) of the Income-tax Act, 2025 (withholding threshold: ₹1,00,000 for senior citizens, ₹50,000 for regular depositors).
   - Clarified that TDS is advance tax withholding and does not exempt interest from total taxable income. Form 15G / 15H self-declarations accurately described.
3. **DICGC Deposit Insurance:**
   - Explicitly cites the statutory ₹5,00,000 limit per depositor per insured bank across all branches in the same right and capacity.
4. **Data Safety & Deletion Accuracy:**
   - Accurately states that consumer accounts do not exist.
   - Truthfully describes the anonymous notification data deletion mechanism (`DELETE /api/notifications/device-token`) and in-app self-service button.
   - Confirms that local financial data is user-controlled and never transmitted to remote servers.
   - Excludes SharedPreferences from cloud backups to prevent off-device leakage.

---

## 8. Play Console Submission Preparation

Evidence-backed answers for all Google Play Console questionnaires are detailed in `docs/release/google_play_app_content_checklist.md` and `docs/release/google_play_data_safety_draft.md`:

- **Data Safety:** Declares AdMob GAID, App Set ID, approximate location (via IP), user interactions (launches, taps, impressions), SDK diagnostics, and anonymous device notification ID. Declares TLS encryption in transit and data deletion mechanism.
- **Financial Features:** Declares category **"Financial planning and management" / "Financial calculators"**. Explicitly confirms app does NOT provide personal loans, does NOT provide credit, does NOT accept deposits, and is NOT a Digital Lending App (DLA).
- **Trader Status Declaration:** Full regulatory guidance provided under EU Digital Services Act / consumer protection rules (deadline for existing accounts: 1 February 2027; required immediately for new accounts). Guidance highlights commercial activity and AdMob monetization as key factors for Trader classification.
- **Target Audience:** Age 18 and over; appeal to children: "No".
- **Content Rating:** IARC questionnaire answers prepared (PEGI 3 / Everyone).
- **App Access:** "All functionality is available without special access" (with reviewer guidance note that `/admin` is an internal rate verification interface, not a consumer login).
- **Country Availability:** India (`IN`) ONLY.

---

## 9. Production Infrastructure Preparation Summary

A complete, transaction-safe production deployment runbook is compiled in `docs/release/final_production_deployment_runbook.md`:
- **Supabase Production Migrations (`pmaykclwuyspxhgeomee`):**
  - Full inventory of 24 migration files (001 through 015 + post-Phase 4 migrations).
  - Sequence and dependency mapping.
  - Transaction safety protocol (`BEGIN; ... COMMIT;`).
  - RLS policy verification and invoker security enforcement on public views.
  - Post-migration SQL verification queries.
- **Vercel Production Deployment:**
  - Production project configuration inventory.
  - Required environment variables: `NODE_ENV`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `ADMIN_JWT_SECRET`, `CORS_ORIGINS`, `RATE_LIMIT_MAX_REQUESTS`.
  - Health check verification commands.
- **Rollback & Incident Response:**
  - Mobile app rollout halt procedure.
  - Vercel instant rollback.
  - Supabase Point-in-Time Recovery (PITR).

---

## 10. Consolidated Final Deliverables Inventory

The following authoritative deliverables have been generated in this phase:

1. `ferocalc_phase5_1_1_final_release_candidate_report.md` (This master milestone report).
2. `docs/release/final_store_listing_package.md` (Complete Google Play store listing package, descriptions, keywords, graphics inventory).
3. `docs/release/final_production_deployment_runbook.md` (Comprehensive deployment runbook for Supabase migrations, Vercel backend, and Android release assembly).
4. `docs/release/final_owner_action_checklist.md` (Consolidated 9-item owner action checklist covering all outstanding manual requirements).
5. `docs/release/final_release_test_matrix.md` (Detailed regression test matrix covering 696 Flutter tests, 46 backend suites, and Android security audits).

---

## 11. Explicit Final Milestone Verdict

### **VERDICT: READY FOR FINAL OWNER INPUTS (BLOCKED — SPECIFIED ITEMS REMAIN)**

### Justification & Traceability:
- **What is Complete:** All code implementation, architectural integration, financial mathematics verification, accessibility compliance, fail-closed build security, test automation (100% pass), staging QA build generation (69.2 MB APK), store listing packaging, and deployment runbooks are **100% complete and verified**.
- **What Remains (Specified Blocking Items for Project Owner):**
  1. **BLK-01:** Production Keystore & `key.properties` provisioning (blocks production `.aab` generation).
  2. **BLK-02:** Public HTTPS hosting of `docs/legal/privacy_policy.md` (blocks Play Console submission).
  3. **BLK-03:** Specifying publisher legal entity name and registered address (blocks Play Console submission).
  4. **BLK-04:** Selecting India-only country availability in Play Console (blocks Play Console release).
  5. **BLK-05:** Applying reviewed database migrations to production Supabase `pmaykclwuyspxhgeomee` (blocks live launch).
  6. **BLK-06:** Setting production environment variables on Vercel (blocks live launch).
  7. **ACT-01 / ACT-02:** Completing Play Console App Content questionnaires and Trader Status declaration.
  8. **HIGH-01 / HIGH-02:** AdMob production account verification and uploading final store visual assets.

Every safe local implementation, integration fix, validation, and release-preparation task in this phase has been completed without modifying production infrastructure or breaking safety boundaries.
