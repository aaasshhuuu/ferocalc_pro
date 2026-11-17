# FeroCalc — Phase 5.1.0.1: Legal Accuracy, Data Safety & Privacy Corrections Implementation Report

**Milestone:** Phase 5.1.0.1 (Focused Compliance, Legal Accuracy, Data Safety & Platform Security Corrections)
**Target Repository:** `C:\projects\fincalc_pro_staging_prep`
**Active Branch:** `staging/vercel-backend-preview`
**Date:** November 2026
**Status:** Completed & Fully Verified (100% Test Pass Rate Across Flutter & Backend)

---

## Executive Summary

Phase 5.1.0.1 executed a focused, rigorous correction and alignment milestone following the Phase 5.1.0 audit. Rather than redesigning architectures or rewriting functional features, this milestone eliminated factual and legal inaccuracies, resolved misalignments between Google Play Console declarations and technical implementations, established a secure data deletion mechanism for anonymous push notification registrations, enforced file-level Android backup isolation for sensitive financial profiles, and reclassified Google Play regulatory checklists and blocker registers according to official 2026/2027 guidelines.

All 696 Flutter tests and 46 backend test suites passed cleanly with zero regressions.

---

## 1. Mandatory Environment Boundaries Confirmation

In strict accordance with project safety instructions:
- **Workspace Isolation:** All research, file edits, and testing took place exclusively inside `C:\projects\fincalc_pro_staging_prep`.
- **Protected Workspace:** `C:\projects\fincalc_pro` was never accessed, inspected, or modified.
- **Protected Production Database:** Production Supabase instance (`pmaykclwuyspxhgeomee`) was never touched or connected to.
- **Staging Database Reference:** Staging Supabase reference `cqrslxngpwbtkjejlwty` was respected.
- **Git State Preservation:** All existing tracked, modified, and untracked files from previous milestones were strictly preserved. No destructive Git operations (`git reset --hard`, `git clean`, `git checkout .`, etc.) were performed.
- **No Deployments or Production Migrations:** Zero Git commits, pushes, remote branch modifications, Vercel preview deployments, or production migrations were executed.
- **Operational Restraint:** Ingestion schedules remained disabled, live Home Screen rates were not promoted, and bank candidate promotions were not automated.

---

## 2. Indian Tax Law Statutory References (Section 2 & 8)

### Outdated Statements Identified
Previous documentation and educational content contained outdated statutory references:
1. Universal citations to Section 194A of the Income-tax Act, 1961 as governing ongoing bank deposit TDS.
2. Outdated statutory annual withholding thresholds: ₹40,000 for regular individuals and ₹50,000 for senior citizens.
3. Imprecise phrasing in educational cards and screens that could be misinterpreted as implying that TDS thresholds represent tax exemption limits.

### Statutory Corrections Implemented
1. **Income-tax Act, 2025 Statutory Reference:**
   - Explicitly cited **Section 393(1), Table Sl. No. 5(ii) of the Income-tax Act, 2025** for interest paid or credited on or after **1 April 2026**.
   - Updated the statutory annual bank withholding thresholds:
     * **Resident Senior Citizens (60 years or older):** ₹1,00,000 per banking institution.
     * **Other Individuals:** ₹50,000 per banking institution.
2. **Historical Preservation (Income-tax Act, 1961):**
   - Preserved Section 194A statutory thresholds (₹50,000 senior / ₹40,000 regular) strictly for periods and transactions occurring up to **31 March 2026**.
3. **Withholding vs. Exemption Clarification:**
   - Explicitly clarified across legal documents, financial disclaimers, and educational content that **TDS is strictly an advance withholding mechanism and does NOT constitute an income tax exemption**.
   - Noted that all bank interest earned is taxable under "Income from Other Sources" at the depositor's personal marginal income tax slab rate. Depositors must pay differential tax if their marginal rate exceeds the withholding rate.
4. **PAN & Form 15G / 15H Requirements:**
   - Clarified that providing a valid PAN ensures standard statutory withholding, while failure to furnish a valid PAN subjects the depositor to higher statutory withholding rates.
   - Described eligibility and conditions for submitting Form 15G (individuals under 60) and Form 15H (senior citizens) when estimated total taxable income is below the basic exemption limit.
5. **Removal of Unverified Rate Claims:**
   - Removed unverified flat percentage claims (such as generic "10% TDS" or "20% without PAN" statements) from user-facing screens and disclaimers where statutory provisions depend on specific PAN compliance rules and applicable Finance Act schedules.

### Files Updated
- `docs/legal/financial_disclaimer.md` (Section 6: Taxation and TDS Disclosures)
- `lib/features/profile/presentation/screens/financial_disclaimer_screen.dart` (Section 6)
- `lib/core/data/financial_management_data.dart` (Tax Rules & FD Strategy educational modules)
- `lib/core/data/translations/financial_literacy_hi.dart` (Hindi localized statutory tax disclosures)
- `lib/core/data/translations/financial_literacy_gu.dart` (Gujarati localized statutory tax disclosures)

---

## 3. Google Mobile Ads SDK (AdMob) Data Safety Declarations (Section 3)

### Exact Native Dependency Resolution
Inspection of the resolved Gradle build graph revealed:
- Flutter package: `google_mobile_ads: ^9.1.0`
- **Exact Resolved Native SDK:** `com.google.android.gms:play-services-ads:25.4.0` (via Google Play Services Ads client).

### Google Play Data Safety Mapping
Based on Google's official Data Safety disclosure for `play-services-ads:25.4.0`, four distinct data categories are evaluated and declared:

| Data Type Category | Collected? | Shared? | Processing / Purpose | Encryption & Retention |
| :--- | :--- | :--- | :--- | :--- |
| **Approximate Location** | Yes | Yes (Google) | IP-based general/coarse location estimation for localized ads, frequency capping, and fraud prevention. *(Zero fine/coarse GPS permissions declared in manifest).* | Encrypted in transit via TLS |
| **User Product Interactions** | Yes | Yes (Google) | App launches, screen views, ad views/impressions, taps, video interactions, and audio interaction metrics for advertising attribution, analytics, and fraud prevention. | Encrypted in transit via TLS |
| **Diagnostics & Performance** | Yes | Yes (Google) | SDK startup latency, battery level, device volume, connection type, crash logs, and Application Not Responding (ANR) events for service reliability and fraud prevention. | Encrypted in transit via TLS |
| **Device or Other Identifiers** | Yes | Yes (Google) | Google Advertising ID (GAID), App Set ID, and hardware identifiers for personalized advertising (where permitted), frequency capping, and anti-fraud telemetry. | Encrypted in transit via TLS |

### Technical Safeguards Maintained
- `android:usesCleartextTraffic="false"` strictly enforced in `android/app/src/main/AndroidManifest.xml`.
- No optional mediation adapters, auxiliary ad SDKs, or invasive hardware permissions are added.
- In-app visual separation: All AdMob banner placements feature an explicit, permanent `ADVERTISEMENT` pill badge and container frame to guarantee editorial independence.

### Files Updated
- `docs/release/google_play_data_safety_draft.md`
- `docs/legal/privacy_policy.md` (Section 3: Advertising & Third-Party SDK Disclosures)
- `lib/features/profile/presentation/screens/privacy_policy_screen.dart`
- `lib/features/profile/presentation/screens/ad_disclosure_screen.dart`

---

## 4. Separation of Account Deletion from Data Deletion Requests (Section 4)

### Play Console Conceptual Distinction
1. **Account Deletion (Google Play Policy):**
   - **Answer: NO.**
   - FeroCalc does not offer consumer accounts, logins, passwords, cloud user profiles, or social sign-in. Creating a fictitious consumer account deletion UI would be fraudulent and confusing to users.
2. **Data Deletion Request Mechanism:**
   - **Answer: YES.**
   - FeroCalc transmits anonymous device tokens, favorite bank IDs, and notification categories to its backend for verified rate alerts. A legitimate data deletion mechanism is therefore required and has been implemented.

### Remote Notification Registration Deletion Architecture
To satisfy Google Play Data Safety requirements without compromising security:
1. **Cryptographic Authorization Contract:**
   - When an installation registers for notifications, the client generates an anonymous 256-bit random authorization token (`installationAuthToken`).
   - The backend stores a SHA-256 hash of this token (`tokenHash`) alongside the `installationId`.
2. **Protected Deletion Endpoints:**
   - `DELETE /api/notifications/device-token`
   - `POST /api/notifications/delete-device-data`
   - Callers must furnish the matching `x-installation-token` header or request body token. Requests with missing or non-matching tokens fail closed with `403 Forbidden`, preventing arbitrary malicious actors from deleting notifications for known installation IDs.
3. **Scope of Remote Deletion:**
   - **Deleted:** Remote device token, favorite bank associations, and alert preference records in the notification registration repository.
   - **Preserved (Local):** Local calculation history, saved financial goals, and financial insight profiles remain on the user's device unless the user explicitly uses the in-app local data wipe.
   - **Preserved (Global):** Globally published verified rate records, historical rate archives, and reviewer audit logs are retained for statutory transparency and regulatory integrity.
4. **In-App User Entry:**
   - Added a **Data Privacy & Deletion** section in `NotificationSettingsScreen`.
   - Users can view and copy their anonymous Installation ID (for manual audit or email requests) or trigger a one-click remote registration deletion with an explicit confirmation dialog.
5. **Support Email Workflow:**
   - Documented `ferocalc.app@gmail.com` as the official manual request endpoint in the Privacy Policy and Data Safety drafts.

### Files Updated & Added
- `backend/notifications/verified_rate_notification_service.js` (Added SHA-256 token verification, `deleteDeviceToken`, and `tokenHash` validation)
- `backend/routes/notifications.js` (Added `DELETE /api/notifications/device-token` and `POST /api/notifications/delete-device-data`)
- `lib/services/notification_service.dart` (Added `deleteRemoteRegistration` with `activeDio.delete<dynamic>`)
- `lib/features/notifications/presentation/screens/notification_settings_screen.dart` (Added Data Privacy & Deletion UI)
- `docs/legal/privacy_policy.md` & `docs/release/google_play_data_safety_draft.md`

---

## 5. Android Backup Rules & Local Privacy Isolation (Section 5)

### Root Cause Analysis of Phase 5.1.0 Backup Rules
In Phase 5.1.0, an attempt was made to exclude specific SharedPreferences by specifying `flutter.ferocalc_admin_auth.xml` in Android backup XML. However:
- Flutter's native Android implementation of `shared_preferences` aggregates all key-value pairs into a single XML file located at `/data/data/com.ferocalc.app/shared_prefs/FlutterSharedPreferences.xml`.
- Android `backup_rules.xml` and `data_extraction_rules.xml` operate strictly at the file and directory level, not at individual XML key levels.
- Consequently, targeting nonexistent file names left sensitive data (including `ferocalc_financial_profile_v1` and administrative tokens) included in Google Drive cloud backups.

### Hardened File-Level Implementation
To prevent unencrypted cloud backups of financial profile data and anonymous device credentials while maintaining device security:
1. **Updated XML Rules:**
   - Both `android/app/src/main/res/xml/data_extraction_rules.xml` and `android/app/src/main/res/xml/backup_rules.xml` now explicitly exclude the single Flutter preferences file:
     ```xml
     <exclude domain="sharedpref" path="FlutterSharedPreferences.xml"/>
     ```
   - Excluded from both `<cloud-backup>` (Google Drive auto-backup) and `<device-transfer>` (ADB and device-to-device transfers).
2. **Privacy & Migration Trade-Off:**
   - Financial profiles and anonymous notification credentials are guaranteed to remain strictly local to the device hardware.
   - If a user changes devices or reinstalls the app, local financial profiles and calculation history will not be restored automatically from Google Drive.
   - This architectural decision is explicitly disclosed in `docs/legal/privacy_policy.md` and `docs/release/google_play_data_safety_draft.md`.

### Files Updated
- `android/app/src/main/res/xml/data_extraction_rules.xml`
- `android/app/src/main/res/xml/backup_rules.xml`
- `docs/legal/privacy_policy.md` (Section 5: Local Data Storage & Cloud Backup Exclusions)

---

## 6. Server Log Retention Claims (Section 6)

### Identification of Unsupported Claims
The previous Privacy Policy asserted that Vercel server request logs were permanently purged within 72 hours. Verification revealed that Vercel project log retention depends on the organization's account tier (Pro vs. Enterprise) and log drain configuration, rather than a fixed 72-hour hard guarantee.

### Policy Language Correction
- Removed the unsupported 72-hour retention claim from `docs/legal/privacy_policy.md` and `privacy_policy_screen.dart`.
- Accurately described server request metadata: Standard reverse-proxy access logs (IP address, user agent, request path, HTTP status code, and latency) are processed by Vercel for operational health, rate limiting, and DDoS defense in accordance with Vercel's platform data retention policies.
- Clarified that FeroCalc's application layer never logs calculator numeric inputs, savings amounts, or financial profiles to server logs.

---

## 7. Google Play Trader Status & Blocker Register Reclassification (Section 7)

### Regulatory Correction
The previous checklist incorrectly stated that all Google Play developers must declare Trader Status immediately in November 2026. The official Google Play guidance for EU Digital Services Act compliance defines:
- **New Developer Accounts:** Must declare Trader Status upon account creation.
- **Existing Developer Accounts:** Have a formal compliance deadline of **1 February 2027**.

### Classification Guidance
- FeroCalc does not automatically mark the account as "Non-Trader" merely because it primarily targets Indian depositors.
- Under EU DSA guidelines, commercial activity, profit-seeking intent, and ad monetization (Google AdMob) are relevant factors in determining Trader status.
- The declaration is classified as a **mandatory owner-controlled console action**. The account owner must determine whether the publishing entity acts as a trader based on their broader corporate structure and monetization activities.
- The legal implications of declaring Trader status (public display of physical address, phone number, and email on Google Play Store listings in the EU) are explicitly documented.

### Tiered Production Blocker Register
`docs/release/production_blocker_register.md` was reorganized into 4 clear tiers:
- **Tier 1: Production Launch Blockers (Technical & Build Readiness)**
  * BLK-001: Offline production keystore generation (`upload-keystore.jks`).
  * BLK-002: Real Google AdMob Production App ID & Ad Unit IDs.
  * BLK-003: Privacy Policy and Financial Disclaimer public HTTPS hosting.
  * BLK-004: Production Supabase service key configuration on Vercel.
- **Tier 2: Owner-Controlled Console Actions (With Specific Deadlines)**
  * BLK-005: Google Play Trader Status declaration (Deadline: 1 February 2027 for existing accounts).
  * BLK-006: Play Console App Content Declarations (Financial Features, Target Audience, Data Safety).
- **Tier 3: High-Priority Operational Verification (Post-Launch Staging)**
  * BLK-007: Bank rate live parser canary checks.
  * BLK-008: Automated rate change email alert delivery.
- **Tier 4: Optional Future Enhancements**
  * Local encrypted SQLite migration for saved calculations.

---

## 8. Additional Legal & Release Document Corrections (Section 8)

1. **Entity Name & Registered Address Placeholders:**
   - Ensured no fictitious legal entities or physical addresses were invented.
   - Retained standardized placeholders: `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_OFFICE_ADDRESS]`.
2. **Explicit Non-Banking & Non-Lending Disclosures:**
   - Re-affirmed across `terms_of_use.md`, `financial_disclaimer.md`, and in-app screens that FeroCalc is strictly a calculative and educational utility, not a bank, NBFC, or deposit-taking entity.
3. **DICGC Deposit Insurance Accuracy:**
   - Accurately described the ₹5,00,000 statutory deposit insurance limit per depositor per insured bank (principal + interest) in the same right and capacity.
   - Clarified that deposits across multiple branches of the same bank are aggregated, while deposits in separate insured banks are independently covered up to ₹5,00,000 each.
4. **Bank Rate & Eligibility Caveats:**
   - Stated that senior citizen rates and special tenure slabs are subject to individual bank eligibility terms and verification documents, with zero guarantee of universal availability.

---

## 9. Comprehensive Test Suite & Verification Results

### 1. New Compliance & Privacy Test Suite (`test/privacy_security_and_compliance_test.dart`)
A dedicated 12-test comprehensive suite was created and executed:
- **Test 1:** `PrivacyPolicyScreen` renders complete data inventory, AdMob SDK, and data deletion rights. **(PASS)**
- **Test 2:** `TermsScreen` renders comprehensive Terms of Use and utility disclosures. **(PASS)**
- **Test 3:** `FinancialDisclaimerScreen` renders updated statutory tax laws (Income-tax Act, 2025) and DICGC insurance details. **(PASS)**
- **Test 4:** `AdDisclosureScreen` renders AdMob transparency and editorial independence. **(PASS)**
- **Test 5:** `ProfileScreen` renders Legal, Privacy & Disclosures navigation tiles. **(PASS)**
- **Test 6:** `NotificationSettingsScreen` renders Data Privacy & Deletion section. **(PASS)**
- **Test 7:** Data deletion mechanism revokes remote token, prevents unauthorized deletion, and preserves local calculations and goals. **(PASS)**
- **Test 8:** Android manifest specifies safe backup, cleartext blocking, and least permissions. **(PASS)**
- **Test 9:** Android backup rules explicitly exclude `FlutterSharedPreferences.xml` from cloud backup. **(PASS)**
- **Test 10:** Home screen contains explicit `ADVERTISEMENT` badge for Google AdMob attribution. **(PASS)**
- **Test 11:** Data safety draft explicitly documents user product interactions, diagnostics, and deletion requests. **(PASS)**
- **Test 12:** Trader status guidance states 1 February 2027 deadline and commercial evaluation criteria. **(PASS)**

### 2. Backend Notification & Security Suite (`backend/test/verified_rate_notification_test.js`)
- Tested `DELETE /api/notifications/device-token` with valid `installationToken`. **(PASS)**
- Tested rejection of missing or invalid tokens with `403 Forbidden`. **(PASS)**
- Tested preservation of global verified rate events upon device registration deletion. **(PASS)**
- Tested rejection of malformed payloads and oversized installation IDs with `400 Bad Request`. **(PASS)**
- **Total Backend Suites:** 46 test files, 100% PASS (29/29 in notification suite, 0 failures across all parsers, policies, and auth routes).

### 3. Full Repository Regression Test (`flutter test`)
- **Total Tests Executed:** 696 tests.
- **Results:** 696 passed, 0 failed.
- **Duration:** 3m 23s.
- Zero regressions across existing calculator, history, discovery, insights, and trust center test suites.

### 4. Static Code Analysis (`flutter analyze`)
- Analyzed all modified Dart files (`notification_service.dart`, `financial_disclaimer_screen.dart`, `privacy_policy_screen.dart`, etc.).
- Zero errors, zero warnings.

---

## 10. Summary of Changed & Added Files

| File Path | Nature of Change | Purpose / Impact |
| :--- | :--- | :--- |
| `docs/legal/financial_disclaimer.md` | Modified | Updated Section 6 with Income-tax Act, 2025 Section 393(1) and DICGC disclosures. |
| `docs/legal/privacy_policy.md` | Modified | Added AdMob product interactions, diagnostics, backup exclusions, and deletion workflow; removed 72h log claim. |
| `docs/legal/terms_of_use.md` | Modified | Re-affirmed non-banking utility status and publisher entity placeholders. |
| `docs/release/google_play_data_safety_draft.md` | Modified | Mapped AdMob 25.4.0 SDK data categories; answered YES to deletion requests and NO to account creation. |
| `docs/release/google_play_app_content_checklist.md` | Modified | Updated Trader status deadline to 1 Feb 2027 and clarified commercial evaluation factors. |
| `docs/release/production_blocker_register.md` | Modified | Reclassified into 4 actionable tiers with accurate Trader status deadlines. |
| `docs/release/phase_5_1_0_1_compliance_corrections.md` | Created | Comprehensive milestone release documentation. |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | Modified | Excluded `FlutterSharedPreferences.xml` from cloud backup and device transfer. |
| `android/app/src/main/res/xml/backup_rules.xml` | Modified | Excluded `FlutterSharedPreferences.xml` from legacy full backup. |
| `backend/notifications/verified_rate_notification_service.js` | Modified | Implemented SHA-256 token validation and secure device token deletion. |
| `backend/routes/notifications.js` | Modified | Added `DELETE /api/notifications/device-token` and `POST /api/notifications/delete-device-data`. |
| `backend/test/verified_rate_notification_test.js` | Modified | Added automated integration tests 5.8, 5.9, and 5.10 for deletion endpoint security. |
| `lib/services/notification_service.dart` | Modified | Added `deleteRemoteRegistration` client method with `installationAuthToken` authentication. |
| `lib/features/notifications/presentation/screens/notification_settings_screen.dart` | Modified | Added Data Privacy & Deletion section with copyable Installation ID and confirmation dialog. |
| `lib/features/profile/presentation/screens/financial_disclaimer_screen.dart` | Modified | Updated Section 6 tax statutory text and DICGC insurance wording. |
| `lib/features/profile/presentation/screens/privacy_policy_screen.dart` | Modified | Added AdMob data inventory, file-level backup disclosures, and removed 72h log claim. |
| `lib/core/data/financial_management_data.dart` | Modified | Updated educational card tax thresholds to Income-tax Act, 2025 standards. |
| `lib/core/data/translations/financial_literacy_hi.dart` | Modified | Updated Hindi financial literacy tax thresholds. |
| `lib/core/data/translations/financial_literacy_gu.dart` | Modified | Updated Gujarati financial literacy tax thresholds. |
| `test/privacy_security_and_compliance_test.dart` | Created | Added 12 unit and widget tests validating all Phase 5.1.0.1 compliance requirements. |
| `ferocalc_phase5_1_0_1_compliance_corrections_report.md` | Created | Milestone deliverable report. |

---

## 11. Remaining Owner-Controlled Play Console Actions

Before submitting FeroCalc for production review on Google Play:
1. **Public HTTPS Hosting:** Host `privacy_policy.md`, `financial_disclaimer.md`, and `terms_of_use.md` on a public HTTPS domain (e.g., GitHub Pages or Vercel static route) and paste the URLs into the Play Console Store Listing and in-app constants.
2. **Trader Status Declaration:** In Google Play Console under **Developer Account > Trader status**, make the formal declaration prior to **1 February 2027** based on commercial and AdMob monetization intent.
3. **App Content Questionnaire Responses:** Complete the App Content section using the exact answers specified in `docs/release/google_play_data_safety_draft.md` and `docs/release/google_play_app_content_checklist.md`.
4. **Production Keystore & AdMob Credentials:** Replace test AdMob IDs and debug signing configurations with production credentials as outlined in `docs/release/production_blocker_register.md`.
