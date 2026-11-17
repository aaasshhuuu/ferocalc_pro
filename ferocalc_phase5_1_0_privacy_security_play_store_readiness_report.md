# FeroCalc — Phase 5.1.0 Implementation & Readiness Report
## Privacy, Platform Security, Google Play Compliance & Production Readiness

**Project:** FeroCalc (Flutter Android Client + Node.js Backend)
**Workspace:** `C:\projects\fincalc_pro_staging_prep`
**Git Branch:** `staging/vercel-backend-preview`
**Date:** November 12, 2026
**Target Market:** Republic of India (`IN`)
**Target Operating System / API:** Android 16 (API Level 36)
**Distribution Framework:** Google Play Console & Google AdMob
**Milestone Focus:** Implementation & Release Preparation (Non-Audit-Only)
**Legal Disclaimer:** This report represents engineering, compliance, and platform security verification. It does not constitute formal legal certification or official Google Play approval.

---

## 1. Executive Summary & Mandatory Environment Safety Confirmation

Phase 5.1.0 executed the final major privacy, platform security, Google Play policy compliance, and pre-release hardening for FeroCalc ahead of the consolidated production launch.

### Mandatory Boundary Adherence Confirmation
- **Workspace Isolation:** All work was executed strictly within `C:\projects\fincalc_pro_staging_prep`.
- **Directory Protection:** `C:\projects\fincalc_pro` was never accessed or modified.
- **Git Branch:** Verified on `staging/vercel-backend-preview`. No commits, branch resets, stashes, or pushes were performed.
- **Supabase Isolation:** Production Supabase (`pmaykclwuyspxhgeomee`) was **NEVER** accessed. Staging Supabase reference `cqrslxngpwbtkjejlwty` was strictly maintained.
- **Guardrails Maintained:**
  - Home Screen live-rate display remains disabled (`RateDisplayConfig.enableLiveRateDisplay = false`).
  - Ingestion schedules and automated scrapers remain disabled.
  - Staged bank candidates are never automatically promoted.
  - No production secrets, mock keystores, or dummy credentials were created or embedded.
  - Release-signing fail-closed protections remain active.

---

## 2. Official Google Play Policy Research & Findings

Research was conducted against current official Google Play Developer Program Policies, Android Developer documentation, and recent policy announcements:

### A. Target API Requirements (Android 16 / API 36)
- **Policy Contract:** Google Play requires all new apps and app updates submitted after August 31, 2026 to target Android 16 (API level 36) or higher.
- **Repository Verification:**
  - `android/app/build.gradle.kts`:
    - `compileSdk = 36`
    - `targetSdk = 36`
    - `minSdk = flutter.minSdkVersion` (API 21+)
    - `JavaVersion.VERSION_17` compatibility verified for Android Gradle Plugin and Kotlin.
  - **Compatibility Assessment:** Both AGP (8.x) and Flutter Gradle Plugin compile against API 36 without deprecation errors or manifest merging failures.

### B. October 29, 2026 Policy Announcement & Upcoming Deadlines
- **Local Network Permission Policy:** Google Play policies restrict requesting local network permissions (`NEARBY_WIFI_DEVICES`, `CHANGE_WIFI_MULTICAST_STATE`, or local network discovery) to apps with documented core requirements.
  - *FeroCalc Status:* **Fully Compliant**. FeroCalc does **NOT** declare or use any local network permissions.
- **Manage Contacts Permission Policy:** Effective early 2027, access to `READ_CONTACTS` and `WRITE_CONTACTS` is restricted solely to approved core communications apps.
  - *FeroCalc Status:* **Fully Compliant**. FeroCalc requests **ZERO** contacts permissions.
- **AppFunctions API Restrictions:** Restricts automated app actions and OS agent integrations.
  - *FeroCalc Status:* **Fully Compliant**. FeroCalc does not implement AppFunctions.
- **November 2026 Trader Status Declaration:** Under the EU Digital Services Act (DSA) / Consumer Rights Directive enforcement across developer accounts, all Google Play developers must declare their trader status.
  - *FeroCalc Status:* Documented as a manual blocker for the developer in Play Console (`BLK-04`).

### C. Distribution Scope
- **Geographic Scope:** India (`IN`) only.
- **Play Console Configuration:** Country distribution is not defined in code; it must be selected manually in Google Play Console (Release > Production > Countries/regions > Select India only). Documented in `docs/release/google_play_app_content_checklist.md`.

---

## 3. Comprehensive Application Data Inventory & Privacy Audit

An empirical audit of all client-side storage, backend routes, and third-party SDK dependencies was conducted:

| Data Field / Category | Purpose | Collection Mechanism | Storage Location | Third-Party Sharing | Retention & User Control |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Financial Calculator Inputs** (Principal, tenure, rates) | Calculation processing | In-memory evaluation | RAM only (never disk) | None | Discarded upon navigation. |
| **Calculation History** | Saved calculations for user reference | User taps "Save to History" | Local SharedPreferences | None | User can view and delete anytime; cleared on app reset. |
| **Financial Goals** | Goal tracking and progress | User creates target in Goal Planner | Local SharedPreferences | None | User can edit/delete goals anytime; cleared on app reset. |
| **Financial Insights Profile** (Income, expenses, savings) | Financial health assessment & ratios | User self-enters in Insights Dashboard | Local SharedPreferences | None | Strictly on-device. Never sent to any server. Cleared via Data Trust Center. |
| **Customer Type** (Regular vs Senior) | Tailor displayed FD rates | User toggle in Profile/Home | Local SharedPreferences | None | Stored locally until modified or uninstalled. |
| **Visual Theme** (Dark vs Light) | Display personalization | Theme toggle in Settings | Local SharedPreferences | None | Stored locally until modified or uninstalled. |
| **Anonymous Installation ID** (`inst_xxx`) | Rate alert registration | Generated client-side via SHA-256 | Local SharedPreferences + Server | None | Transmitted anonymously to notification endpoint. Purged upon clear data. |
| **Favorite Banks** (`['sbi', 'hdfc']`) | Rate change notification filtering | User marks bank as favorite | Local SharedPreferences + Server | None | Synchronized anonymously if user enables notifications. Configurable. |
| **Notification Preferences** (Alert category flags) | Alert preference management | User toggles in Notification Settings | Local SharedPreferences + Server | None | Synchronized anonymously with notification backend. Configurable. |
| **In-App Notification Records** | In-app notification feed | Fetched from verified rate change feed | Local SharedPreferences | None | User can mark read, delete individual, or clear entire inbox. |
| **Public Rate Inquiries** | Fetch verified FD rate tables | Anonymous HTTPS GET requests | Server transient memory | None | Transient server logs (IP, method, timestamp; purged per Vercel standard). |
| **Google Advertising ID (GAID)** | Ad attribution & frequency capping | Google Mobile Ads SDK | Handled by Google SDK | Google LLC | User can reset or delete GAID via Android Settings > Google > Ads. |
| **IP Address (via AdMob)** | Coarse geolocation for ad serving | Google Mobile Ads SDK | Handled by Google SDK | Google LLC | Governed under Google's Privacy Policy. |

---

## 4. Privacy Policy, Terms of Use & Legal Implementation

### Documentation Created
- `docs/legal/privacy_policy.md`: Complete, honest privacy policy accurately detailing local-only storage of calculations/financial profiles, anonymous notification registration, AdMob data collection, and publisher placeholders.
- `docs/legal/terms_of_use.md`: Comprehensive terms detailing the educational/utility nature of FeroCalc, non-banking disclaimers, limitation of liability, and Indian governing law.
- `docs/legal/financial_disclaimer.md`: Explicit consumer disclosures covering DICGC deposit insurance (up to ₹5 Lakh), senior citizen KYC requirements, Section 194A TDS rules, and quarterly compounding variations.

### In-App UI & Navigation Experience
1. **Privacy Policy Screen (`PrivacyPolicyScreen`):**
   - Completely rewritten to reflect the modern architecture.
   - Accurately details what is stored locally vs transmitted to backend APIs.
   - Explicitly explains Google AdMob advertising data collection and how users can opt out via Android Settings.
   - Discloses developer contact `ferocalc.app@gmail.com` and publisher placeholders.
2. **Terms of Use Screen (`TermsScreen`):**
   - Replaced basic stub with an extensive, multi-section legal agreement.
   - Explicit non-banking, non-lending, non-deposit-taking clauses.
3. **Financial Disclaimers Screen (`FinancialDisclaimerScreen`):**
   - Dedicated in-app screen accessible from Profile navigation.
   - Detailed consumer protections, DICGC limits, and calculation estimate explanations.
4. **Advertising Disclosures Screen (`AdDisclosureScreen`):**
   - Dedicated in-app screen explaining how AdMob funds the free app.
   - Discloses editorial independence: zero paid rank manipulation for banks.
5. **Restructured Profile Screen:**
   - Unified into a dedicated **"Legal, Privacy & Disclosures"** section with custom icons and semantic accessibility headers:
     - *Privacy Policy* (`/privacy`)
     - *Terms of Use* (`/terms`)
     - *Financial Disclaimers* (`/financial-disclaimer`)
     - *Advertising Disclosures* (`/ad-disclosure`)
     - *Open Source Licenses* (native `showLicensePage`)
     - *App Version*

---

## 5. Google Play Data Safety & App Content Preparation

Created two comprehensive release deliverables:
1. `docs/release/google_play_data_safety_draft.md`:
   - Line-by-line mapping for every Data Safety question in Play Console.
   - Declares AdMob GAID and coarse IP collection.
   - Declares anonymous notification installation ID.
   - Confirms that financial figures are **NOT collected off-device** (local-only storage).
   - Confirms full encryption in transit (HTTPS).
   - Provides clear reviewer justification for the absence of consumer account deletion (no consumer accounts exist).
2. `docs/release/google_play_app_content_checklist.md`:
   - Step-by-step checklist for all Play Console App Content questionnaires.
   - Financial services classification: declares non-DLA, non-lending, non-deposit utility status.
   - Trader status declaration instructions for November 2026.
   - India-only country selection guide.

---

## 6. AdMob Integration & Advertising Compliance

### Audit Findings
- **SDK Dependency:** `google_mobile_ads: ^9.1.0` in `pubspec.yaml`.
- **App ID in Manifest:** `ca-app-pub-6265679606207808~8961400103`.
- **Ad Unit ID in Release:** `ca-app-pub-6265679606207808/1405598858`.
- **Test Ad Unit in Debug/Profile:** `ca-app-pub-3940256099942544/6300978111` (Official Google sample banner).

### Hardened Implementation
- **Visual Demarcation:** In `home_screen.dart`, added an explicit **"ADVERTISEMENT"** attribution badge enclosed within a dedicated themed container with semantic accessibility tags.
- **Accidental Click Protection:** Placed away from calculator sliders, input boxes, and bank rate selection cards.
- **No Intrusive Ads:** Form entry screens and calculation results are completely ad-free. No interstitial or rewarded video blockers are shown during calculation workflows.
- **User Messaging Platform (UMP):** Documented that UMP is not required for India-only distribution, but would be a prerequisite if distribution expands to EEA, UK, or Switzerland (`MED-01`).

---

## 7. Android Permissions & Platform Security Hardening

### Permissions Review
- `android/app/src/main/AndroidManifest.xml`:
  - **Declared Permission:** `<uses-permission android:name="android.permission.INTERNET"/>` ONLY.
  - **Zero Over-Privileged Permissions:** No `READ_CONTACTS`, `WRITE_CONTACTS`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `READ_EXTERNAL_STORAGE`, `RECORD_AUDIO`, `NEARBY_WIFI_DEVICES`, or `POST_NOTIFICATIONS` at the root manifest level.

### Platform Security Enhancements
1. **Cleartext Traffic Blocked:** Added `android:usesCleartextTraffic="false"` to `<application>` in `AndroidManifest.xml`.
2. **Android 12+ (API 31+) Data Extraction Rules:** Created `android/app/src/main/res/xml/data_extraction_rules.xml`:
   - Allows cloud backup and device transfer of normal user preferences and calculation history.
   - Explicitly excludes any administrative authentication tokens (`flutter.ferocalc_admin_auth.xml`, `flutter.admin_token.xml`).
3. **Android 11 & Lower Full Backup Content:** Created `android/app/src/main/res/xml/backup_rules.xml`:
   - Preserves user convenience during device migration while preventing credential leakage.
4. **Exported Components:** Only `MainActivity` is exported (`android:exported="true"`) with singleTop launch mode and main launcher intent filter. Zero background receivers or unprotected services are exported.

---

## 8. Backend Security Hardening & Secret Management

### High-Risk Endpoint Hardening (`backend/routes/notifications.js`)
Hardened `POST /api/notifications/device-token` with strict payload validation:
1. `installationId`: Non-empty string, length constrained between 1 and 128 characters.
2. `token`: If provided, string constrained to maximum 512 characters.
3. `favoriteBankIds`: If provided, must be an array of strings with maximum 50 elements, each string length <= 64 characters.
4. `preferences`: If provided, must be an object containing only allowed boolean keys (`masterEnabled`, `favoriteBankRateChanges`, `newlyPromotedSlabs`, `significantRateChanges`, `productAnnouncements`). Any unrecognized key or non-boolean value immediately triggers HTTP 400.
5. **Memory DoS Defense:** Added an LRU/FIFO capacity cap of 10,000 devices on `registeredDevices` in `VerifiedRateNotificationService` to prevent in-memory exhaustion.

### Secret Exposure Audit
- Git status verified: `.env` and `.env.staging` files are strictly git-ignored (`.gitignore` contains `.env*`).
- Zero production or staging secrets are embedded in client binaries or tracked in Git.
- Admin endpoints strictly require verified Supabase JWTs with `ferocalc_role` verified from server-controlled `app_metadata`.

---

## 9. Release Signing & Fail-Closed Android App Bundle Readiness

- **Configuration:** Inspected `android/app/build.gradle.kts`.
- **Fail-Closed Safeguard:**
  - In release builds, Gradle attempts to load `key.properties`.
  - If `key.properties` is absent and `FEROCALC_STAGING_DEBUG_SIGNING` is NOT set to `true`, Gradle selects an unconfigured release signing config without a storeFile, causing `:app:packageRelease` to fail closed safely.
  - Staging QA builds are allowed only when explicitly opting in via the environment variable `FEROCALC_STAGING_DEBUG_SIGNING=true`.
- **Production Status:** No mock keystores were created. Real release credentials remain an external release blocker (`BLK-01`).

---

## 10. Financial Transparency & Disclosures

Verified that all user-facing financial language strictly distinguishes:
- **Calculator Projections:** Clearly framed as mathematical illustrations based on user-entered assumptions.
- **Bank Rate Information:** Explicitly labeled as official bank-published rates subject to revision.
- **Verification Badges:** Only verified, active rates carry the official verification badge.
- **Pending Review Rates:** Displayed with clear pending status; never promoted prematurely.

---

## 11. Production Blocker & External Readiness Summary

Detailed in `docs/release/production_blocker_register.md`:

### Critical Blockers (Must be resolved before release)
1. **BLK-01 (Release Signing):** Real production keystore (`upload-keystore.jks`) and `android/key.properties` must be provisioned on the release build machine.
2. **BLK-02 (Policy):** Privacy Policy (`docs/legal/privacy_policy.md`) must be hosted on a public HTTPS URL.
3. **BLK-03 (Legal):** Publisher legal entity name and registered address must replace placeholders `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_ADDRESS]`.
4. **BLK-04 (Console):** Trader status declaration must be completed in Google Play Console (November 2026 requirement).
5. **BLK-05 (Console):** Country availability must be set to India (`IN`) only in Google Play Console.
6. **BLK-06 (Database):** Approved migrations must be applied to production Supabase (`pmaykclwuyspxhgeomee`).
7. **BLK-07 (Backend):** Vercel production deployment must be provisioned with isolated production Supabase keys.

### High Severity (Should be completed before Play Store submission)
1. **HIGH-01:** Confirm Google AdMob production account payment profile and app approval.
2. **HIGH-02:** Complete Google Play App Content questionnaires per checklist.
3. **HIGH-03:** Export store listing graphics (512x512 icon, 1024x500 feature graphic, screenshots).

---

## 12. Regression & Validation Results

### 1. Flutter Regression Suite (`flutter test`)
- **Previous Baseline:** 684 passing tests.
- **New Tests Added:** 8 comprehensive tests in `test/privacy_security_and_compliance_test.dart`.
- **Current Result:** **692 passing tests, 0 failures, 0 regressions.**

### 2. Flutter Code Analysis (`flutter analyze --no-fatal-infos`)
- **Current Result:** **0 errors, 0 warnings.** (87 non-fatal style infos consistent with baseline).

### 3. Backend Regression Suite (`npm test` in `backend/`)
- **Previous Baseline:** 46 test suites.
- **New Security Tests Added:** Tests 5.5, 5.6, 5.7 in `backend/test/verified_rate_notification_test.js` validating device token payload sizes, bank ID limits, and preference key sanitization.
- **Current Result:** **All 46 suites passed, 0 failures.**

---

## 13. Deliverables Summary

The following files were created or updated in this phase:

1. **In-App Screens & Client Architecture:**
   - `lib/features/profile/presentation/screens/privacy_policy_screen.dart` (Updated)
   - `lib/features/profile/presentation/screens/terms_screen.dart` (Updated)
   - `lib/features/profile/presentation/screens/financial_disclaimer_screen.dart` (Created)
   - `lib/features/profile/presentation/screens/ad_disclosure_screen.dart` (Created)
   - `lib/features/profile/presentation/screens/profile_screen.dart` (Updated with Legal, Privacy & Disclosures section)
   - `lib/features/home/presentation/screens/home_screen.dart` (Updated with "ADVERTISEMENT" badge)
   - `lib/config/routes/app_router.dart` (Updated with `/terms`, `/financial-disclaimer`, `/ad-disclosure`)
   - `lib/config/routes/route_names.dart` (Updated with route constants)
2. **Android Security & Backup Configuration:**
   - `android/app/src/main/res/xml/data_extraction_rules.xml` (Created)
   - `android/app/src/main/res/xml/backup_rules.xml` (Created)
   - `android/app/src/main/AndroidManifest.xml` (Updated with backup rules and cleartext blocking)
3. **Backend Hardening:**
   - `backend/routes/notifications.js` (Hardened with strict validation)
   - `backend/notifications/verified_rate_notification_service.js` (Hardened with capacity cap)
   - `backend/test/verified_rate_notification_test.js` (Added tests 5.5, 5.6, 5.7)
4. **Documentation & Release Artifacts:**
   - `docs/legal/privacy_policy.md` (Created)
   - `docs/legal/terms_of_use.md` (Created)
   - `docs/legal/financial_disclaimer.md` (Created)
   - `docs/release/google_play_data_safety_draft.md` (Created)
   - `docs/release/google_play_app_content_checklist.md` (Created)
   - `docs/release/production_blocker_register.md` (Created)
   - `test/privacy_security_and_compliance_test.dart` (Created)
   - `ferocalc_phase5_1_0_privacy_security_play_store_readiness_report.md` (Created)

---

## 14. Next Steps

The next milestone will be the consolidated final production release preparation after all critical external blockers (BLK-01 through BLK-07) are resolved by the project owner.
