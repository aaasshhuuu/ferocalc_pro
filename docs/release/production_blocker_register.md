# FeroCalc — Production Launch Blocker & External Readiness Register

**Phase:** 5.1.0.1 (Legal Accuracy, Data Safety, Privacy Corrections & Production Readiness)
**Date:** November 13, 2026
**Scope:** India-only Distribution (`IN`)
**Status:** Pre-Release Readiness Assessment (Phase 5.1.0.1 Hardened)

---

## 1. Classification Methodology

To provide strict operational clarity for the release owner, items are categorized into distinct priority tiers:

- **GENUINE PRODUCTION BLOCKER (CRITICAL):** Hard gating prerequisite that **MUST** be resolved before building the final production bundle or submitting to Google Play. Failure halts production builds, violates mandatory store policies, or leaves production backend infrastructure unconfigured.
- **OWNER-CONTROLLED PLAY CONSOLE ACTION (DATED DEADLINE):** Mandatory administrative task performed directly by the developer account owner inside Google Play Console with a specific regulatory or platform deadline.
- **HIGH-PRIORITY OPERATIONAL VERIFICATION:** Key pre-launch operational verification step that should be verified prior to public launch to avoid live service degradation or ad serving limits.
- **OPTIONAL / FUTURE ENHANCEMENT:** Post-launch capability or international expansion prerequisite that does not impede initial India-only launch.

---

## 2. Categorized Blocker & Readiness Register

### Tier 1: Genuine Production Blockers (Pre-Submission Mandates)

| ID | Category | Title | Severity | Impact | Required Remediation | Current State |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BLK-01** | Release Signing | **Production Keystore & `key.properties`** | **BLOCKER** | Gradle fails closed on `packageRelease` without valid signing credentials. Debug keys cannot be used on Play Store. | Generate real production `upload-keystore.jks`, configure `android/key.properties` locally (git-ignored). | **FAIL-CLOSED ACTIVE** (Safe) |
| **BLK-02** | Google Play Policy | **Public Privacy Policy URL** | **BLOCKER** | Google Play submission requires an active, publicly accessible HTTPS URL. | Host `docs/legal/privacy_policy.md` on a verified public web domain (e.g. GitHub Pages or production web host) and enter URL in Play Console. | Document updated; requires public hosting. |
| **BLK-03** | Legal / Identity | **Publisher Legal Entity & Registered Address** | **BLOCKER** | Mandatory under India IT rules and Google Play Console developer profile requirements. | Replace placeholders `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_ADDRESS]` with official legal entity name and physical address in legal docs and Play Console. | Placeholders established. |
| **BLK-04** | Google Play Console | **India-Only Distribution Configuration** | **BLOCKER** | Target launch scope is strictly India (`IN`). Must be restricted in Play Console to prevent accidental international distribution. | In Play Console > Release > Countries/regions, select India (`IN`) only. | Awaiting manual console configuration. |
| **BLK-05** | Database / Infra | **Production Supabase Migration Review & Application** | **BLOCKER** | Staging Supabase (`cqrslxngpwbtkjejlwty`) holds verified rate schemas and notification tables. Production Supabase (`pmaykclwuyspxhgeomee`) must receive approved migrations. | Execute reviewed, transaction-safe SQL migrations on production Supabase via official CLI or management portal during final release window. | Staging active; production untouched. |
| **BLK-06** | Backend / Hosting | **Production Vercel Environment Variables** | **BLOCKER** | Production backend must be provisioned with isolated production Supabase URL, anon key, and service role key. | Set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` in Vercel Production environment. Do not use staging credentials. | Staging isolated; production awaiting setup. |

---

### Tier 2: Owner-Controlled Play Console Actions (With Dated Deadlines)

| ID | Action Target | Description & Regulatory Scope | Applicable Deadline | Classification Guidance | Action Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ACT-01** | **Trader Status Declaration** | Mandatory global developer-level declaration across all active Play Console accounts under EU Digital Services Act / consumer protection rules. | **1 February 2027** (Existing Accounts)<br>*Immediate for newly created accounts* | The account owner must make an accurate determination based on commercial activities. Advertising-sponsored apps (AdMob monetization) and commercial intent are significant factors indicating Trader status. Do **NOT** automatically select Non-Trader merely because FeroCalc targets India. | Awaiting owner declaration in Play Console > Developer account > About you > Trader status. |
| **ACT-02** | **App Content Questionnaires** | Complete official Play Console forms: Data Safety, Content Rating (IARC), Financial Features (Financial Utility/No Lending), Ads, Target Audience (18+). | Prior to submitting first release for review | Follow exact answers and evidence drafted in `docs/release/google_play_data_safety_draft.md` and `google_play_app_content_checklist.md`. | All responses drafted and verified against Phase 5.1.0.1 code. |

---

### Tier 3: High-Priority Operational Verification

| ID | Category | Title | Severity | Impact | Required Remediation | Current State |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **HIGH-01** | Advertising | **AdMob Production App ID & Unit Verification** | **HIGH** | App must serve live ads in release mode without ad-serving limitations or policy violations. | Verify that AdMob App ID `ca-app-pub-6265679606207808~8961400103` and Ad Unit `ca-app-pub-6265679606207808/1405598858` are approved and active in Google AdMob Console. | Release IDs configured; test IDs active in debug. |
| **HIGH-02** | Store Presence | **Store Listing Graphics & Screenshots** | **HIGH** | Play Store listing requires high-res icon (512x512), feature graphic (1024x500), and at least 2 phone screenshots. | Export feature graphic and capture phone screenshots of Calculators, Discovery, Compare, and Financial Insights screens. | Assets drafted; awaiting export and upload. |
| **HIGH-03** | Legal / Compliance | **Legal Hosting & In-App Link Parity** | **HIGH** | In-app legal screens and hosted public URLs must match identically before review submission. | Verify hosted Privacy Policy, Terms of Use, and Financial Disclaimers match repository `docs/legal/` files. | Local screens and documents synchronized. |

---

### Tier 4: Optional Future Items & Non-Gating Capabilities

| ID | Category | Title | Severity | Scope & Future Trigger | Action Required |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **MED-01** | Advertising | **EEA/UK/Switzerland Consent (UMP SDK)** | **MEDIUM** | Required ONLY if app distribution expands internationally beyond India to EEA/UK. | Implement Google User Messaging Platform (UMP) SDK prior to expanding distribution beyond India. (Not applicable to India-only launch). |
| **INFO-01**| Notifications | **Firebase Cloud Messaging (FCM) Push Credentials** | **INFORMATIONAL** | Optional for v1.0. App functions fully with verified in-app Notification Center, preference sync, and protected remote deletion. | If background remote push notifications are desired in a future release, bundle `google-services.json` and set backend `FIREBASE_SERVICE_ACCOUNT_KEY`. |

---

## 3. External Credentials & Access Checklist (Zero Secrets Exposed)

The following external accounts and credentials will be required by the project owner during the final production deployment milestone:

1. **Google Play Console Developer Account:**
   - Account Owner or Release Manager access for `com.ferocalc.app`.
   - Ability to complete App Content questionnaires and upload `.aab`.
   - Complete Trader Status declaration (deadline: 1 February 2027).
2. **Production Android Keystore:**
   - Java KeyStore file (`upload-keystore.jks`).
   - Keystore password, key alias, and key password.
3. **Google AdMob Console:**
   - Verified publisher account with active payment profile and approved app status.
4. **Production Supabase Dashboard (`pmaykclwuyspxhgeomee`):**
   - Project Owner or Database Admin access to execute reviewed SQL migrations.
5. **Vercel Project Dashboard:**
   - Production project deployment permissions and environment variable management.
6. **Domain Hosting Portal:**
   - Public HTTPS hosting for Privacy Policy, Terms of Use, and Financial Disclaimers.
