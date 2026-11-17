# FeroCalc — Phase 5.1.0.1 Compliance, Legal Accuracy & Privacy Corrections Report

**Document Version:** 1.0.0
**Date:** November 13, 2026
**Status:** Verification & Audit Complete
**Scope:** Staging Environment (`staging/vercel-backend-preview` at `C:\projects\fincalc_pro_staging_prep`)

---

## 1. Executive Summary

Phase 5.1.0.1 implements a surgical, evidence-based correction milestone addressing factual inaccuracies, legal terminology, Google Play Console compliance declarations, data deletion mechanics, and Android backup privacy rules identified in the Phase 5.1.0 readiness audit.

Every correction strictly preserves existing application features, avoids destructive Git actions, respects environment isolation boundaries (staging Supabase `cqrslxngpwbtkjejlwty`, zero production mutations), and establishes rigorous test coverage across both Flutter and Node test suites.

---

## 2. Key Corrections Implemented

### A. Indian Tax Law References & TDS Thresholds
- **Outdated Claim Found:** Documents and in-app screens previously stated that bank FD/RD interest TDS under Section 194A is deducted at ₹40,000 for regular individuals and ₹50,000 for senior citizens, without distinguishing the statutory transition.
- **Corrected Statutory Framework:**
  - **Income-tax Act, 2025 (Effective 1 April 2026):** For interest (other than interest on securities) paid or credited by a banking company, qualifying co-operative bank, or applicable post-office scheme, Tax Deducted at Source is governed by **Section 393(1), Table Serial No. 5(ii)**:
    - **Resident Senior Citizens (aged 60 and above):** ₹1,00,000 per financial year.
    - **Other Individuals (regular depositors):** ₹50,000 per financial year.
  - **Earlier Statutory Regime (up to 31 March 2026):** For payments governed by Section 194A of the earlier Income-tax Act, 1961, statutory withholding thresholds were ₹50,000 for senior citizens and ₹40,000 for regular depositors.
- **Withholding vs. Tax Liability:** Explicitly clarified in legal disclaimers and educational content that TDS is merely an advance withholding mechanism for tax collection. Earning interest below the TDS threshold does **not** exempt that interest from income tax; interest remains fully taxable under the depositor's applicable income tax slab / marginal rate.
- **PAN & Self-Declarations:** Clarified that standard withholding applies when a valid PAN is provided, and higher statutory withholding rates apply when a valid PAN is not furnished. Form 15G (under 60) and Form 15H (senior citizens) self-declarations apply only when estimated total annual income is below the basic tax exemption limit.
- **Files Corrected:**
  - `docs/legal/financial_disclaimer.md`
  - `lib/features/profile/presentation/screens/financial_disclaimer_screen.dart`
  - `lib/core/data/financial_management_data.dart`
  - `lib/core/data/translations/financial_literacy_hi.dart`
  - `lib/core/data/translations/financial_literacy_gu.dart`

---

### B. AdMob Google Play Data Safety Declarations
- **Exact SDK Dependency Resolved:**
  - Flutter plugin: `google_mobile_ads: ^9.1.0` (resolved `9.1.0` in `pubspec.lock`).
  - Native Android SDK resolved by Gradle: `com.google.android.gms:play-services-ads:25.4.0` (with `com.google.android.ump:user-messaging-platform:4.0.0`).
  - Flag `USE_NEXT_GEN_SDK` is not active.
  - Zero mediation adapters or third-party ad networks bundled.
- **Corrected Data Safety Categories:**
  - **Location:** Approximate location derived from IP address for general geographic estimation (country/city). No GPS or fine location permissions declared in `AndroidManifest.xml`. (Purposes: Advertising or marketing, Fraud prevention).
  - **App Activity / User Product Interactions:** Explicitly declared user product interactions (app launch, screen views, ad views/impressions, ad click/tap events). (Purposes: Advertising or marketing, Analytics, Fraud prevention).
  - **App Info & Performance / Diagnostics:** Broader diagnostic telemetry declared (SDK startup latency, battery level, device volume, connection types, crashes, ANRs). Not restricted solely to "crash logs". (Purposes: Analytics, App functionality, Fraud prevention).
  - **Device or Other Identifiers:** Google Advertising ID (`GAID`) and App Set ID collected by AdMob SDK for ad attribution. FeroCalc internal anonymous `installationId` declared separately (never shared with Google or third parties).
  - **Security:** Enforces TLS encryption for all network traffic (`android:usesCleartextTraffic="false"`).
- **Files Corrected:**
  - `docs/release/google_play_data_safety_draft.md`
  - `docs/legal/privacy_policy.md`
  - `lib/features/profile/presentation/screens/privacy_policy_screen.dart`

---

### C. Separation of Account Deletion from Data Deletion Requests
- **Account Deletion Response:** Answered **NO** to consumer account creation, because FeroCalc has no consumer account registration, logins, or server-side profiles.
- **Data Deletion Request Mechanism:** Answered **YES**, evaluating anonymous notification registration data separately:
  - FeroCalc transmits anonymous installation IDs (`inst_xxx`), device push tokens, and alert preferences to its notification service.
- **Safe, Practical Deletion Workflow Implemented:**
  1. **Self-Service Protected Contract:** Added `DELETE /api/notifications/device-token` (and `POST /api/notifications/delete-device-data`) in `backend/routes/notifications.js` and `verified_rate_notification_service.js`.
  2. **Anti-Tampering Ownership Protection:** Device registrations store a cryptographic SHA-256 hash of an installation authentication token (`installationAuthToken`). Callers must supply the token in header `x-installation-token` or payload `installationToken` to delete a record. An arbitrary caller guessing an `installationId` receives `403 Forbidden`.
  3. **Complete Remote Revocation:** Deletion revokes the device token, purges favorite bank associations, and clears remote alert preferences.
  4. **Data Isolation:** Deletion does **NOT** touch the user's local saved calculations, goals, or financial profile.
  5. **Shared Rate Integrity Retained:** Globally shared verified rate history and system security audit records are retained permanently for statutory auditability.
  6. **In-App Entry:** Added a **Data Privacy & Deletion** card in `NotificationSettingsScreen` with one-tap copy of the anonymous Installation ID and a protected deletion trigger with explicit confirmation dialog.
  7. **Assisted Email Route:** Documented support email `ferocalc.app@gmail.com` for manual deletion requests by users who uninstalled the app.
- **Files Corrected:**
  - `backend/routes/notifications.js`
  - `backend/notifications/verified_rate_notification_service.js`
  - `lib/services/notification_service.dart`
  - `lib/features/notifications/presentation/screens/notification_settings_screen.dart`
  - `lib/features/profile/presentation/screens/privacy_policy_screen.dart`
  - `docs/legal/privacy_policy.md`
  - `docs/release/google_play_data_safety_draft.md`

---

### D. Android Backup & Local Storage Privacy Verification
- **Vulnerability Found in Previous Draft:** Android backup XML rules (`<exclude domain="sharedpref" path="..."/>`) operate on whole files, not individual SharedPreferences keys. Because Flutter stores all preferences in `FlutterSharedPreferences.xml`, previous attempts to exclude individual keys (`flutter.ferocalc_admin_auth.xml`) were non-functional. Consequently, `ferocalc_financial_profile_v1` and administrative session tokens would have been uploaded to Google Cloud Backup under `<include domain="sharedpref" path="."/>`.
- **Privacy-Safe Implementation:**
  - `FlutterSharedPreferences.xml` is explicitly excluded from `<cloud-backup>` and `<device-transfer>` in `android/app/src/main/res/xml/data_extraction_rules.xml` and `android/app/src/main/res/xml/backup_rules.xml`.
  - Guarantees that sensitive personal financial metrics, anonymous installation tokens, and administrative credentials are never uploaded to Google Cloud Backup or transferred across devices unencrypted.
  - **Documented Trade-Off:** Because SharedPreferences is excluded from cloud backup to protect user privacy, saved calculations and goals will not be restored from Google Drive cloud backups upon device migration; users configure preferences fresh on a new device.
- **Files Corrected:**
  - `android/app/src/main/res/xml/data_extraction_rules.xml`
  - `android/app/src/main/res/xml/backup_rules.xml`
  - `docs/legal/privacy_policy.md`
  - `lib/features/profile/presentation/screens/privacy_policy_screen.dart`

---

### E. Server Log Retention Claims
- **Outdated Claim Found:** `privacy_policy.md` previously claimed that server request logs are purged within 72 hours.
- **Correction:** Removed the unsupported "72h" duration claim. Accurately described that hosting provider request metadata (IP address, HTTP method, path, status code) is processed transiently by Vercel for routing and DDoS mitigation in accordance with standard hosting operational policies, without unverified duration promises.
- **Files Corrected:**
  - `docs/legal/privacy_policy.md`
  - `lib/features/profile/presentation/screens/privacy_policy_screen.dart`

---

### F. Google Play Trader Status Guidance & Blocker Register Reclassification
- **Outdated Claim Found:** Previously marked as an immediate November 2026 release blocker for all developer accounts, with language suggesting automatic Non-Trader status due to India distribution.
- **Corrected Guidance:**
  - **New Developer Accounts:** Must declare Trader status upon account creation.
  - **Existing Developer Accounts:** Google Play deadline is **1 February 2027**.
  - **Scope:** Global requirement across active Google Play Console accounts.
  - **Classification Criteria:** Google considers commercial activity, profit-seeking intent, and ad monetization (AdMob) as key factors. The account owner must determine status based on actual entity activities; do not automatically default to Non-Trader.
  - **Blocker Register Tiering:** Reclassified in `production_blocker_register.md` as an **Owner-Controlled Action (Deadline: 1 Feb 2027)**, distinct from genuine production blockers.
- **Files Corrected:**
  - `docs/release/google_play_app_content_checklist.md`
  - `docs/release/production_blocker_register.md`
  - `docs/release/google_play_data_safety_draft.md`

---

### G. Additional Legal & Regulatory Corrections
- Preserved explicit non-banking, non-lending, non-deposit-taking status.
- Avoided implying universal bank eligibility for senior citizen rates; clarified that eligibility is governed strictly by each bank's terms.
- Avoided overbroad DICGC claims; stated the ₹5 lakh maximum limit per depositor per insured bank in the same right and capacity, distinguishing independent coverage across separate banking entities from aggregation across branches of the same bank.
- Kept calculator outputs and Financial Insights described strictly as mathematical estimates.
- Maintained zero secret leakage and untouched production credentials.
- **Files Corrected:**
  - `docs/legal/financial_disclaimer.md`
  - `lib/features/profile/presentation/screens/financial_disclaimer_screen.dart`
  - `docs/legal/terms_of_use.md`
  - `docs/legal/privacy_policy.md`

---

## 3. Verification & Compliance Matrix

| Milestone Area | Status | Verification Evidence |
| :--- | :--- | :--- |
| **Tax Law References** | **VERIFIED** | Correct Income-tax Act, 2025 Section 393(1) Table Sl. No. 5(ii) (₹1,00,000 senior / ₹50,000 other) and Section 194A up to 31 March 2026 verified across legal docs, in-app screens, and educational topics. |
| **AdMob Data Safety** | **VERIFIED** | Gradle dependency `play-services-ads:25.4.0` verified. App interactions, broader diagnostics, GAID, and IP coarse location mapped to Play Console categories. |
| **Data Deletion Mechanism** | **VERIFIED** | Protected `DELETE /api/notifications/device-token` contract with SHA-256 tokenAuth implemented. In-app deletion UI with local data preservation tested. |
| **Android Backup Isolation** | **VERIFIED** | `FlutterSharedPreferences.xml` excluded from `<cloud-backup>` and `<device-transfer>` in `data_extraction_rules.xml` and `backup_rules.xml`. |
| **Server Log Retention** | **VERIFIED** | Unsupported 72h claim replaced with honest hosting infrastructure operational policy description. |
| **Trader Status Deadline** | **VERIFIED** | Corrected to 1 February 2027 deadline for existing accounts; commercial/ad factors documented; moved to owner action tier. |
| **Blocker Register Tiering**| **VERIFIED** | Tier 1 (Production Blockers), Tier 2 (Owner Actions with Deadlines), Tier 3 (High-Priority Operational Verification), Tier 4 (Optional Future Items). |
| **Environment Isolation**  | **VERIFIED** | 100% confined to `C:\projects\fincalc_pro_staging_prep`. Staging Supabase `cqrslxngpwbtkjejlwty` active. Zero production touches. |
