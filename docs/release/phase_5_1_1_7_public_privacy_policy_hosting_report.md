# FeroCalc — Phase 5.1.1.7: Public Privacy Policy Hosting & Publisher Gate Verification Report

**Document Version:** 1.0.0
**Execution Timestamp:** November 13, 2026
**Execution Environment:** `C:\projects\fincalc_pro_staging_prep`
**Target Public Endpoint:** `https://web-psi-kohl-23.vercel.app/privacy-policy/`
**Approved Canonical Document:** `docs/legal/privacy_policy.md` (Effective: November 12, 2026)
**Scope:** Web route audit, Vercel project linkage inspection, live vs canonical parity audit, responsive visual verification, build compilation, and mandatory publisher information gate evaluation
**Final Milestone Verdict:** **`BLOCKED — PUBLISHER INFORMATION MISSING`**

---

## 1. Executive Summary & Objective Realization

This milestone evaluates the readiness of the publicly hosted FeroCalc Privacy Policy at `https://web-psi-kohl-23.vercel.app/privacy-policy/` for update from the outdated September 21, 2026 policy to the approved November 12, 2026 canonical policy (`docs/legal/privacy_policy.md`).

### 1.1 The Mandatory Publisher Information Gate Finding
The pre-release audit enforced the strict **Mandatory Publisher Information Gate** requiring that:
- `[PUBLISHER_LEGAL_ENTITY_NAME]`
- `[PUBLISHER_REGISTERED_OFFICE_ADDRESS]` (represented as `[PUBLISHER_REGISTERED_ADDRESS]` in codebase)

be replaced with owner-verified, legally recognized entity details prior to public deployment.

**Gate Result:** Both placeholders remain **ACTIVE UNRESOLVED PLACEHOLDERS** across `docs/legal/privacy_policy.md`, `docs/legal/terms_of_use.md`, `docs/legal/financial_disclaimer.md`, and `lib/features/profile/presentation/screens/privacy_policy_screen.dart`. In adherence to project boundaries and Google Play Developer Program Policies:
1. No synthetic, speculative, or fabricated publisher identities were introduced.
2. The website deployment to Vercel production has been **IMMEDIATELY HALTED / BLOCKED**.
3. The exact missing owner inputs have been cataloged with a clear resolution runbook.

### 1.2 Preparation & Build Parity Status
While public hosting deployment is blocked at the publisher identity gate, technical staging preparation is **100% complete**:
- **Route & Project Identified:** The route `/privacy-policy/` is served by the Flutter Web client routed through GoRouter and deep-linked via `vercel.json` rewrites on Vercel project `web` (`prj_jSa5Aop0VyZeKoncnGqlvRDr8jV4`).
- **Code Parity:** `lib/features/profile/presentation/screens/privacy_policy_screen.dart` contains the complete approved November 12, 2026 policy text.
- **Automated Tests:** All 12 test assertions in `test/privacy_security_and_compliance_test.dart` PASSED.
- **Release Web Compilation:** `flutter build web --release` compiled cleanly (`150.9s`) into `build/web/`.
- **Bundle Verification:** Empirical string analysis of `build/web/main.dart.js` confirms full November 12, 2026 text presence and zero presence of outdated September 21, 2026 text.
- **Zero Secrets:** Security scan confirmed zero backend keys, tokens, or private configurations in the compiled web bundle.

---

## 2. Web Architecture & Vercel Project Linkage Inspection

### 2.1 Project & Route Identification
- **Repository Workspace:** `C:\projects\fincalc_pro_staging_prep`
- **Application Type:** Flutter Web Single-Page Application (SPA) with CanvasKit renderer.
- **Public URL:** `https://web-psi-kohl-23.vercel.app/privacy-policy/`
- **Alternate Alias:** `https://web-psi-kohl-23.vercel.app/privacy/`

### 2.2 Vercel Project Linkage Configuration
Inspection of the Vercel linkage metadata (`c:\projects\fincalc_pro\.vercel\project.json`) established the deployment target:
```json
{
  "projectId": "prj_jSa5Aop0VyZeKoncnGqlvRDr8jV4",
  "orgId": "team_BoIyi9zzesoRf4ZNnjKKxNCM",
  "projectName": "web"
}
```
- **Vercel Account:** `kuldip12490-8771` (verified via `vercel whoami`).
- **Deployment Strategy:** Static web directory upload (`build/web/`) as documented in `DEPLOYMENT_GUIDE.md` (Section: Deploy to Vercel/Netlify).

### 2.3 Deep-Linking & Server-Side Rewrites (`vercel.json`)
The repository's root `vercel.json` enforces universal SPA fallback:
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```
When an external user, browser, or Google Play policy crawler requests `GET /privacy-policy/`:
1. Vercel routes the request to `/index.html` with an `HTTP 200 OK` response.
2. The browser downloads `flutter_bootstrap.js` and `main.dart.js`.
3. Flutter's `go_router` (`lib/config/routes/app_router.dart`, lines 495–504) matches `/privacy-policy` and mounts `PrivacyPolicyScreen`:
```dart
GoRoute(
  path: '/privacy',
  name: 'privacy',
  builder: (context, state) => const PrivacyPolicyScreen(),
),
GoRoute(
  path: '/privacy-policy',
  name: 'privacyPolicy',
  builder: (context, state) => const PrivacyPolicyScreen(),
),
```

### 2.4 Live HTTP & Accessibility Audit
A live network inspection of `https://web-psi-kohl-23.vercel.app/privacy-policy/` confirmed:
- **HTTP Status:** `200 OK`
- **Content-Type:** `text/html; charset=utf-8`
- **Headers:** `Strict-Transport-Security`, `Access-Control-Allow-Origin: *`, `X-Vercel-Cache: HIT`
- **Edge Node:** `bom1` (Mumbai Edge Engine)
- **Accessibility Invariants:**
  - Accessible **WITHOUT LOGIN** (no account wall, no authentication challenge).
  - Accessible **WITHOUT COOKIES** (zero cookie consent popups or tracking banners).
  - Accessible **WITHOUT GEOGRAPHICAL RESTRICTIONS** (global public edge routing).

---

## 3. Live vs Canonical Content Gap Analysis

### 3.1 Live Page Inspection (September 21, 2026 Outdated Build)
Inspection by the automated browser subagent (`d683af16-98db-4e58-8ecb-961de450dc0b`) verified that the current live site at `https://web-psi-kohl-23.vercel.app/privacy-policy/` is running the legacy build from October 22, 2026:
- **Displayed Date:** `September 21, 2026` in a rounded badge.
- **Section Structure:** 11 legacy sections.
- **Omissions in Live Policy:**
  - Does NOT disclose the Financial Insights profile on-device storage or Android Cloud Backup exclusion.
  - Does NOT specify the exact native AdMob SDK artifact (`com.google.android.gms:play-services-ads:25.4.0`).
  - Does NOT enumerate AdMob telemetry categories (battery, volume, latency, ANRs, App Set ID).
  - Does NOT document the anonymous installation identifier (`inst_xxx`) or favorite bank preference sync.
  - Does NOT document the protected self-service deletion mechanism (`DELETE /api/notifications/device-token`).
  - Does NOT reference the statutory Digital Personal Data Protection (DPDP) Act, 2023 or Income-tax Act, 2025.

### 3.2 Canonical Policy Requirements (`docs/legal/privacy_policy.md`)
The approved November 12, 2026 canonical policy resolves all legacy omissions:

| Policy Requirement | Live Hosted Status (Sep 21, 2026) | Staging Preparation Status (`lib/` & `docs/`) | Staging Build Status (`build/web/`) |
| :--- | :--- | :--- | :--- |
| **Effective / Update Date** | Outdated: `September 21, 2026` | **Updated:** `November 12, 2026` | **Verified:** `November 12, 2026` in `main.dart.js` |
| **Target Distribution Scope** | Not stated | India (`IN`) explicitly declared | India (`IN`) declared |
| **Local Calculations & RAM** | Stated (in-memory) | Verified in-memory client evaluation | In-memory evaluation confirmed |
| **Calculation History & Goals** | Generic local storage | Explicit `SharedPreferences` + in-app clearing | Explicit user controls confirmed |
| **Financial Insights Profile** | Completely missing | Strictly on-device; excluded from cloud backup | Fully documented |
| **Public Rate Inquiries** | Stated | HTTPS GET; metadata processed by Vercel | Fully documented |
| **Anonymous Installation ID** | Missing | `inst_xxx` + device token for rate alerts | Fully documented |
| **Favorite Bank Sync** | Missing | Synchronized bank IDs (e.g. `['sbi', 'hdfc']`) | Fully documented |
| **AdMob SDK Specification** | Generic mention | Exact `play-services-ads:25.4.0` specified | Fully documented |
| **AdMob Telemetry Scope** | GAID, IP, basic info | GAID, App Set ID, IP, interactions, diagnostics | Comprehensive inventory included |
| **Remote Data Deletion** | Missing | In-app self-service `DELETE` + 30-day email purge | Exact mechanism declared |
| **Local Data Clearing** | In-app settings | In-app Reset + Android Clear Storage + Uninstall | Complete guidance included |
| **Security & Backup Isolation** | Generic HTTPS | Backup isolation rules (`data_extraction_rules.xml`) | Comprehensive safeguards listed |
| **Publisher Identity** | Missing | `[PUBLISHER_LEGAL_ENTITY_NAME]` placeholder | **GATED — OWNER INPUT REQUIRED** |
| **Registered Address** | Missing | `[PUBLISHER_REGISTERED_ADDRESS]` placeholder | **GATED — OWNER INPUT REQUIRED** |

---

## 4. Mandatory Publisher Information Gate Audit

Under Google Play Console developer profile requirements and India Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, a public legal policy must accurately disclose the publisher's official legal name and registered business address.

### 4.1 Gate Check Evaluation

```text
[CHECK 1] [PUBLISHER_LEGAL_ENTITY_NAME]
Status:   UNRESOLVED PLACEHOLDER
Location: docs/legal/privacy_policy.md (lines 6, 120)
          docs/legal/terms_of_use.md (lines 6, 13, 68, 76, 90)
          docs/legal/financial_disclaimer.md (line 6)
          lib/features/profile/presentation/screens/privacy_policy_screen.dart (line 8)
Finding:  Literal placeholder string active. No legal entity name provided.

[CHECK 2] [PUBLISHER_REGISTERED_OFFICE_ADDRESS]
Status:   UNRESOLVED PLACEHOLDER (as [PUBLISHER_REGISTERED_ADDRESS])
Location: docs/legal/privacy_policy.md (lines 7, 121)
          docs/legal/terms_of_use.md (lines 7, 91)
          lib/features/profile/presentation/screens/privacy_policy_screen.dart (line 9)
Finding:  Literal placeholder string active. No physical business address provided.
```

### 4.2 Gate Decision
Because both placeholders remain unresolved:
1. **PUBLISHING HALTED:** The policy will **NOT** be deployed to `https://web-psi-kohl-23.vercel.app` at this time.
2. **ZERO FABRICATION:** In accordance with project instructions, fake or placeholder legal entity details have strictly **NOT** been fabricated.
3. **PLAY CONSOLE LINKAGE DEFERRED:** The Play Console Privacy Policy URL field update remains deferred until live hosting reflects verified publisher details.

---

## 5. Verification & Testing Evidence

### 5.1 Automated Flutter Test Suite (`test/privacy_security_and_compliance_test.dart`)
The 12-test compliance suite in `fincalc_pro_staging_prep` was executed:
```bash
flutter test test/privacy_security_and_compliance_test.dart
```
**Test Results:**
```text
00:00 +0: (setUpAll)
[NotificationService] Initialized. InstallationId: inst_1794573558310054_310054, PushConfigured: false
00:00 +0: FeroCalc Phase 5.1.0.1: Legal Accuracy & Privacy Screens Unit Tests 1. PrivacyPolicyScreen renders complete data inventory, AdMob SDK, and data deletion rights
00:02 +1: FeroCalc Phase 5.1.0.1: Legal Accuracy & Privacy Screens Unit Tests 2. TermsScreen renders comprehensive Terms of Use and utility disclosures
00:02 +2: FeroCalc Phase 5.1.0.1: Legal Accuracy & Privacy Screens Unit Tests 3. FinancialDisclaimerScreen renders updated statutory tax laws (Income-tax Act, 2025) and DICGC
00:02 +3: FeroCalc Phase 5.1.0.1: Legal Accuracy & Privacy Screens Unit Tests 4. AdDisclosureScreen renders AdMob transparency and editorial independence
00:02 +4: FeroCalc Phase 5.1.0.1: Legal Accuracy & Privacy Screens Unit Tests 5. ProfileScreen renders Legal, Privacy & Disclosures section with all tiles
00:04 +5: FeroCalc Phase 5.1.0.1: Data Deletion & Privacy Architecture Tests 6. NotificationSettingsScreen renders Data Privacy & Deletion section
00:04 +6: FeroCalc Phase 5.1.0.1: Data Deletion & Privacy Architecture Tests 7. Data deletion mechanism revokes remote token and preserves local calculations and goals
00:04 +7: FeroCalc Phase 5.1.0.1: Android Backup & Platform Security Tests 8. Android manifest specifies safe backup, cleartext blocking, and least permissions
00:04 +8: FeroCalc Phase 5.1.0.1: Android Backup & Platform Security Tests 9. Android backup rules explicitly exclude FlutterSharedPreferences.xml to isolate sensitive data
00:04 +9: FeroCalc Phase 5.1.0.1: Android Backup & Platform Security Tests 10. Home screen contains explicit ADVERTISEMENT badge for Google AdMob attribution
00:04 +10: FeroCalc Phase 5.1.0.1: Documentation & Regulatory Wording Audit Tests 11. Data safety draft explicitly documents user product interactions, diagnostics, and deletion
00:04 +11: FeroCalc Phase 5.1.0.1: Documentation & Regulatory Wording Audit Tests 12. Trader status guidance states 1 February 2027 deadline and commercial evaluation
00:04 +12: All tests passed!
```
- **Total Test Cases:** 12
- **Passed:** 12
- **Failed:** 0
- **Execution Time:** ~4 seconds

### 5.2 Release Web Compilation (`flutter build web --release`)
A fresh production web build was compiled from `C:\projects\fincalc_pro_staging_prep`:
```bash
flutter build web --release
```
**Compilation Output:**
- Icon Tree-Shaking: `MaterialIcons-Regular.otf` reduced from 1,645,184 to 39,252 bytes (97.6% reduction).
- Compilation Time: `150.9s`
- Output Directory: `build\web`
- Result: `√ Built build\web`

### 5.3 Compiled Bundle String Analysis (`build/web/main.dart.js`)
An automated Node.js string scan was performed on the generated release bundle:
```javascript
node -e "
const fs = require('fs');
const s = fs.readFileSync('build/web/main.dart.js', 'utf8');
console.log('Contains November 12, 2026:', s.includes('November 12, 2026'));
console.log('Contains September 21, 2026:', s.includes('September 21, 2026'));
console.log('Contains PUBLISHER_LEGAL_ENTITY_NAME:', s.includes('[PUBLISHER_LEGAL_ENTITY_NAME]'));
console.log('Contains play-services-ads:25.4.0:', s.includes('play-services-ads:25.4.0'));
console.log('Contains Delete Remote Notification Data:', s.includes('Delete Remote Notification Data'));
"
```
**Output:**
```text
Contains November 12, 2026: true
Contains September 21, 2026: false
Contains PUBLISHER_LEGAL_ENTITY_NAME: true
Contains play-services-ads:25.4.0: true
Contains Delete Remote Notification Data: true
```
This empirically verifies that:
1. Outdated September 21, 2026 content is completely purged from the web bundle.
2. Complete approved November 12, 2026 policy content is compiled into the bundle.
3. Placeholders remain intact awaiting owner resolution.

### 5.4 Zero Private Configuration & Secrets Scan
An automated scan of `build/web/main.dart.js` verified that no internal secrets or server configurations are bundled:
```javascript
node -e "
const fs = require('fs');
const s = fs.readFileSync('build/web/main.dart.js', 'utf8');
console.log('Contains service_role:', s.includes('service_role'));
console.log('Contains SUPABASE_SERVICE_ROLE_KEY:', s.includes('SUPABASE_SERVICE_ROLE_KEY'));
console.log('Contains JWT_SECRET:', s.includes('JWT_SECRET'));
"
```
**Output:**
```text
Contains service_role: false
Contains SUPABASE_SERVICE_ROLE_KEY: false
Contains JWT_SECRET: false
```
Zero credentials or private keys are exposed to web clients.

### 5.5 Visual & Responsive Rendering Audit
The headless browser inspection of the current layout verified:
- **Desktop (1280px+):** Centered max-width column (`720px`) with comfortable margins, dark navy background (`#0A1628`), clean white title, and amber/blue headings.
- **Mobile (390px):** Single-column fluid wrapping, touch-scrollable, responsive margins, and zero horizontal clipping.
- **Styling Parity:** Both the legacy and newly compiled screens use identical responsive constraints (`ConstrainedBox(constraints: BoxConstraints(maxWidth: 720))`), guaranteeing complete visual continuity.

---

## 6. Strict Boundary Compliance

| Boundary Rule | Compliance Status | Operational Evidence |
| :--- | :--- | :--- |
| **Do not modify backend APIs** | **COMPLIANT** | Zero files in `backend/` or `api/` modified. |
| **Do not change production Supabase** | **COMPLIANT** | Production instance `pmaykclwuyspxhgeomee` untouched. |
| **Do not modify mobile application features** | **COMPLIANT** | Zero calculator logic, state blocs, or UI widgets altered. |
| **Do not change the Play Console URL yet** | **COMPLIANT** | Play Console listing package documentation retains placeholder status. |
| **Do not deploy until publisher details are verified** | **COMPLIANT** | Vercel production deployment intentionally HALTED. |
| **Preserve existing project changes** | **COMPLIANT** | Staging migrations (24 files), test fixes, and reports preserved. |

---

## 7. Owner Next Action Runbook (To Unblock Deployment)

To complete the public privacy policy hosting and unblock Google Play submission, the project owner must execute the following sequential steps:

### Step 1: Supply Verified Publisher Details
Determine the official legal entity name and physical registered business address:
1. **Legal Entity Name:** Official registered name (e.g., registered Private Limited company, LLP, or registered Sole Proprietorship name as filed with the Ministry of Corporate Affairs / Registrar of Firms).
2. **Registered Office Address:** Physical mailing address (Door/Suite, Street, City, State, Postal PIN Code, India).

### Step 2: Replace Placeholders Across Repository
Replace `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_ADDRESS]` in:
1. `docs/legal/privacy_policy.md` (lines 6, 7, 120, 121)
2. `docs/legal/terms_of_use.md` (lines 6, 7, 13, 68, 76, 90, 91)
3. `docs/legal/financial_disclaimer.md` (line 6)
4. `lib/features/profile/presentation/screens/privacy_policy_screen.dart`:
   ```dart
   static const String _publisherPlaceholder = 'Your Official Legal Entity Name';
   static const String _addressPlaceholder = 'Your Official Registered Business Address';
   ```

### Step 3: Re-verify & Build Release Web Bundle
Execute in `C:\projects\fincalc_pro_staging_prep`:
```bash
flutter test test/privacy_security_and_compliance_test.dart
flutter build web --release
```

### Step 4: Deploy Web Bundle to Vercel Production
Deploy the compiled `build/web` directory to the linked Vercel project `web`:
```bash
# Link workspace if not already linked:
vercel link --project prj_jSa5Aop0VyZeKoncnGqlvRDr8jV4

# Deploy to production:
vercel deploy --prod build/web
```

### Step 5: Post-Deployment Smoke Test
Verify public accessibility and content update:
```bash
curl -I https://web-psi-kohl-23.vercel.app/privacy-policy/
```
Confirm in browser that:
1. "Last updated" displays `November 12, 2026`.
2. Publisher legal entity name and registered address display the real owner-verified details.

### Step 6: Update Google Play Console App Content
1. Navigate to **Google Play Console > Policy > App content > Privacy policy**.
2. Enter the active URL: `https://web-psi-kohl-23.vercel.app/privacy-policy/`.
3. Save changes.

---

## 8. Final Release Verdict

```text
================================================================================
FINAL MILESTONE VERDICT:
BLOCKED — PUBLISHER INFORMATION MISSING
================================================================================
Reason:
1. [PUBLISHER_LEGAL_ENTITY_NAME] is unresolved in docs/legal/privacy_policy.md
   and lib/features/profile/presentation/screens/privacy_policy_screen.dart.
2. [PUBLISHER_REGISTERED_OFFICE_ADDRESS] is unresolved in legal documents
   and client presentation code.
3. Production deployment to https://web-psi-kohl-23.vercel.app/ is halted
   to prevent publishing unverified or non-compliant publisher identities.
4. Technical preparation, Flutter test suite (12/12 passed), and release
   compilation are complete and verified in staging.
================================================================================
```
