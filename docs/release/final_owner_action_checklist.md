# FeroCalc — Consolidated Final Owner Action Checklist

**Phase:** 5.1.1.5 (Explicit Production Migration Target Binding Patched)
**Package Identifier:** `com.ferocalc.app`
**Distribution Region:** India (`IN`) Only
**Assessment Date:** November 13, 2026
**Document Purpose:** Consolidate every outstanding manual requirement, credential, and console action into ONE single authoritative checklist for the project owner. Clearly categorizes blockers by build, submission, launch, and monetization stages.

---

## 1. Executive Summary & Gating Status

All code development, algorithmic audits, accessibility checks, fail-closed signing verifications, and automated test suites (696 Flutter tests, 46 backend suites) have successfully passed with **zero defects**.

The application documentation and pre-production assets are in state: **`READY FOR FINAL OWNER INPUTS (BLOCKED — SPECIFIED ITEMS REMAIN)`**.

Before public release on the Google Play Store, the actions detailed below must be completed by the respective human account owners (Business Owner, Developer Account Owner, Database Administrator, and Marketing/Design Owner). No automated script or agent may fabricate owner credentials, approvals, or legal identities.

---

## 2. Categorized Owner Action Matrix (By Blocking Tier)

### Tier 1: Android Production App Bundle (AAB) Build Blocker
*Must be resolved before `flutter build appbundle --release` can succeed.*

| # | Action Item | Responsible Role | Blocking Impact | Current Repository State | Verification Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **03** | **Production Upload Keystore & Signing Credentials** | Android Release Engineer / Owner | **BLOCKS AAB BUILD** | Fail-closed safeguard active (`Store: null`, `Alias: null`) | Configure `android/key.properties` and `upload-keystore.jks`; run `flutter build appbundle --release`; verify `.aab` output. |

---

### Tier 2: Google Play Console Submission Blockers
*Must be resolved before submitting the release for Google Play review.*

| # | Action Item | Responsible Role | Blocking Impact | Current Repository State | Verification Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | **Publisher Legal Entity & Registered Address** | Business Owner / Legal | **BLOCKS SUBMISSION** | Placeholders `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_ADDRESS]` active | Search repository for placeholders; verify legal docs match Play Console developer profile. |
| **02** | **Public Privacy Policy HTTPS URL** | Web Admin / Project Owner | **BLOCKS SUBMISSION** | Markdown complete in `docs/legal/privacy_policy.md`; requires live HTTPS hosting | Send HTTPS request to URL; verify HTTP 200 OK and readable Privacy Policy text. |
| **07** | **Google Play Console Access & Final Policy Declarations** | Play Console Account Owner | **BLOCKS SUBMISSION** | Questionnaires drafted in `docs/release/` files | Confirm all App Content sections (Data Safety, Financial Features, Trader Status, Ads, Rating) show green checkmarks. |
| **08** | **India-Only Country Availability Selection** | Play Console Account Owner | **BLOCKS SUBMISSION** | Target scope India (`IN`) established | In Play Console > Release > Countries/regions, confirm only India is selected. |
| **09** | **Final Store Listing Visual Assets Upload** | Designer / Marketing Owner | **BLOCKS SUBMISSION** | Icon ready (512x512); Feature graphic & screenshots drafted | Verify visual assets are uploaded and rendering cleanly in Play Console Store Listing preview. |

---

### Tier 3: Production Infrastructure & Live Service Launch Blockers
*Must be resolved before public app launch and live user traffic.*

| # | Action Item | Responsible Role | Blocking Impact | Current Repository State | Verification Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **04** | **Production Supabase DBA Access & Approved Migrations** | Database Administrator / Owner | **BLOCKS LIVE LAUNCH** | Staging DB active; Production DB (`pmaykclwuyspxhgeomee`) unmigrated | Execute 24 reviewed migrations in order; run catalog verification queries; run target preflight; reconcile CLI history targeting explicit production reference: `migration repair --status applied ... --project-ref pmaykclwuyspxhgeomee`. |
| **05** | **Production Vercel Backend Configuration** | DevOps / Project Owner | **BLOCKS LIVE LAUNCH** | Staging preview active; Production Vercel project awaiting env vars | Deploy `vercel --prod` with production env vars; test `curl -I https://[PROD_DOMAIN]/api/health`. |

---

### Tier 4: Monetization & Ad Serving Readiness Blocker
*Must be resolved to avoid ad-serving restrictions or policy penalties upon launch.*

| # | Action Item | Responsible Role | Blocking Impact | Current Repository State | Verification Method |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **06** | **Google AdMob Production App & Ad-Unit Verification** | Monetization Owner / Owner | **BLOCKS LIVE ADS / REVENUE** | Release IDs configured; test mode active in debug | Check Google AdMob Console for active "Ready" app status, approved ad units, and valid `app-ads.txt`. |

---

## 3. Detailed Item-by-Item Action Guidelines

### Item 1: Publisher Legal Entity & Registered Address
- **Why Required:** Mandated under India Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021, the Digital Personal Data Protection Act, 2023, and Google Play Developer Program policies. A legitimate legal entity name and physical business address are required in public developer profiles and legal disclosures.
- **Who Must Provide It:** Business Owner / Legal Representative.
- **Blocking Severity:** **BLOCKS PLAY STORE SUBMISSION**.
- **Action Steps:**
  1. Determine the official registered business entity name (e.g., `Acme Technologies Private Limited` or sole proprietorship trading name) and physical business mailing address.
  2. Replace `[PUBLISHER_LEGAL_ENTITY_NAME]` and `[PUBLISHER_REGISTERED_ADDRESS]` in:
     - `docs/legal/privacy_policy.md`
     - `docs/legal/terms_of_use.md`
     - `docs/legal/financial_disclaimer.md`
     - In-app legal text strings if hardcoded.
  3. Ensure the identical legal name and address are configured in Google Play Console > **Developer account > About you**.
- **How to Verify Completion:** Run:
  `Select-String -Path "docs/legal/*.md" -Pattern "PUBLISHER_LEGAL_ENTITY_NAME"`
  Verify zero matches return.

---

### Item 2: Public Privacy Policy HTTPS URL
- **Why Required:** Google Play policies mandate an active, publicly accessible HTTPS URL linking to a clear privacy policy that covers user data collection, third-party SDKs (AdMob), and data deletion mechanisms.
- **Who Must Provide It:** Web Administrator / Project Owner.
- **Blocking Severity:** **BLOCKS PLAY STORE SUBMISSION**.
- **Action Steps:**
  1. Host `docs/legal/privacy_policy.md` on an authorized public HTTPS domain (e.g., GitHub Pages, Vercel web deployment, or official company website `https://ferocalc.app/privacy`).
  2. Test the URL in a standard web browser to ensure it is publicly accessible without login walls, basic authentication, or geo-blocking.
  3. Enter the public HTTPS URL in Google Play Console > **Policy > App content > Privacy policy**.
- **How to Verify Completion:** Execute:
  `curl -I https://[YOUR_DOMAIN]/privacy`
  Verify HTTP response `200 OK` with valid content-type header.

---

### Item 3: Production Upload Keystore & Signing Credentials
- **Why Required:** Android App Bundles (`.aab`) submitted to Google Play must be cryptographically signed by the developer's private upload key. FeroCalc enforces a fail-closed Gradle configuration that intentionally halts builds when valid signing keys are absent, preventing debug or unsigned binaries from ever being submitted.
- **Who Must Provide It:** Android Release Engineer / Project Owner.
- **Blocking Severity:** **BLOCKS AAB GENERATION**.
- **Action Steps:**
  1. Generate a genuine production keystore using Java `keytool` (if not already existing):
     ```bash
     keytool -genkey -v -keystore upload-keystore.jks -alias ferocalc-upload -keyalg RSA -keysize 2048 -validity 10000
     ```
  2. Store `upload-keystore.jks` in a secure location and copy to `android/upload-keystore.jks` (which is excluded from Git via `.gitignore`).
  3. Create `android/key.properties` (also git-ignored):
     ```properties
     storePassword=[YOUR_KEYSTORE_PASSWORD]
     keyPassword=[YOUR_KEY_PASSWORD]
     keyAlias=ferocalc-upload
     storeFile=../upload-keystore.jks
     ```
  4. Back up the keystore and password credentials in a secure company password manager. (Losing the upload key requires Google Play Support key reset).
- **How to Verify Completion:** Run:
  ```powershell
  $env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
  cd C:\projects\fincalc_pro_staging_prep
  flutter build appbundle --release
  ```
  Verify build succeeds and outputs `build/app/outputs/bundle/release/app-release.aab`.

---

### Item 4: Production Supabase DBA Access & Approved Migrations
- **Why Required:** The production database (`pmaykclwuyspxhgeomee`) must hold identical schema definitions, atomic RPC functions, Row-Level Security policies, and read-only views as validated in staging. Without migrations, rate queries and notification event logging will fail.
- **Who Must Provide It:** Database Administrator / Project Owner.
- **Blocking Severity:** **BLOCKS LIVE LAUNCH**.
- **Action Steps:**
  1. Open the Supabase Management Console for production project `pmaykclwuyspxhgeomee`.
  2. Follow the sequential execution order in `docs/release/final_production_deployment_runbook.md` (Section 3).
  3. Execute each SQL file observing transaction compatibility:
     - **Migration 012:** Execute in **two committed segments** (Segment A: `ALTER TYPE staging_candidate_status ADD VALUE IF NOT EXISTS 'PROMOTED'; COMMIT;`, then Segment B: columns and `promotion_audit_log` DDL).
     - **Migration 017:** Execute strictly **as-is** without outer `BEGIN ... COMMIT` wrapping (self-encapsulated transaction).
  4. Run the catalog verification queries in Section 3.3 to confirm RLS on all 11 tables, `security_invoker = true` on views, and RPC permissions.
  5. **Perform Mandatory Preflight Target & CLI Version Verification:**
     - Identify resolved CLI version: run `npx supabase --version` inside `backend/` (resolves to project-local v2.122.0).
     - Confirm intended database reference is **strictly production (`pmaykclwuyspxhgeomee`)**.
     - Confirm that staging reference `cqrslxngpwbtkjejlwty` must **NEVER** receive production migration-history repair.
     - Note that `backend/supabase/.temp/project-ref` currently holds `cqrslxngpwbtkjejlwty` (staging). **Do NOT use `--linked`** unless you have explicitly relinked to production (`npx supabase link --project-ref pmaykclwuyspxhgeomee`) and verified that `.temp/project-ref` reads `pmaykclwuyspxhgeomee`.
     - Standard: Never print, display, or log access tokens, database passwords, or service-role keys.
  6. Reconcile the Supabase CLI migration tracking ledger using explicit production target binding:
     ```bash
     cd backend
     # Project-Local CLI v2.122.0 (Default):
     npx supabase migration repair --status applied \
       001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 \
       20261025095847 20261025100101 20261025100407 20261025100630 \
       20261025100654 20261028095435 20261107073416 20261108050936 20261112193000 \
       --project-ref pmaykclwuyspxhgeomee
     ```
     *(CLI v3.x alternative syntax: pass `--remote=pmaykclwuyspxhgeomee`).*
     *(Note: NEVER manually insert rows into `supabase_migrations.schema_migrations`; use `supabase migration repair`).*
  7. Verify ledger reconciliation on the production project:
     ```bash
     # Project-Local CLI v2.122.0:
     npx supabase migration list --project-ref pmaykclwuyspxhgeomee

     # CLI v3.x Alternative:
     npx supabase migration list --remote=pmaykclwuyspxhgeomee
     ```
     Confirm all 24 local migrations show as applied on remote with zero pending unapplied files before permitting any future `supabase db push`.
- **How to Verify Completion:** Run catalog verification queries 1 through 5 in the Supabase SQL Editor for `pmaykclwuyspxhgeomee`. Verify all 11 tables have RLS active, views have `security_invoker = true`, and permissions are strictly read-only for public. Run `npx supabase migration list --project-ref pmaykclwuyspxhgeomee` (or `--remote=pmaykclwuyspxhgeomee` on CLI v3) and verify all 24 local migrations show as applied on remote.

---

### Item 5: Production Vercel Configuration
- **Why Required:** The production API backend must serve live rate data and handle anonymous notification token synchronization with isolated production database credentials.
- **Who Must Provide It:** DevOps Engineer / Project Owner.
- **Blocking Severity:** **BLOCKS LIVE LAUNCH**.
- **Action Steps:**
  1. Create or select the production Vercel project.
  2. Configure production environment variables in Vercel:
     - `NODE_ENV=production`
     - `SUPABASE_URL=https://pmaykclwuyspxhgeomee.supabase.co`
     - `SUPABASE_ANON_KEY=[PRODUCTION_ANON_KEY]`
     - `SUPABASE_SERVICE_ROLE_KEY=[PRODUCTION_SERVICE_ROLE_KEY]`
     - `ADMIN_JWT_SECRET=[SECURE_RANDOM_SECRET]`
     - `CORS_ORIGINS=https://ferocalc.app`
     - `RATE_LIMIT_MAX_REQUESTS=100`
  3. Deploy the backend code using `vercel --prod`.
- **How to Verify Completion:** Run:
  `curl -s https://[PRODUCTION_BACKEND_URL]/api/health`
  Verify response returns status `healthy` and database connection `ok`.

---

### Item 6: Google AdMob Production App & Ad-Unit Verification
- **Why Required:** The app displays banner ads to support free service operation. Live release ads require an approved AdMob publisher account, active payment profile, and verified app linking.
- **Who Must Provide It:** Monetization Owner / Project Owner.
- **Blocking Severity:** **BLOCKS LIVE ADS / REVENUE**.
- **Action Steps:**
  1. Log into Google AdMob Console (`apps.admob.com`).
  2. Verify that App ID `ca-app-pub-6265679606207808~8961400103` is in **"Ready"** status.
  3. Verify that Banner Ad Unit `ca-app-pub-6265679606207808/1405598858` is active and approved.
  4. Ensure AdMob `app-ads.txt` is configured on the publisher domain (`https://ferocalc.app/app-ads.txt`) to prevent ad serving restrictions.
- **How to Verify Completion:** Check AdMob dashboard for "No policy violations" and "Ad serving: Enabled".

---

### Item 7: Google Play Console Access & Final Declarations
- **Why Required:** Google Play requires all App Content declarations (Data Safety, Financial Services, Content Ratings, Ads, Target Audience, App Access, and Trader Status) to be submitted accurately before an app can be approved.
- **Who Must Provide It:** Play Console Account Owner.
- **Blocking Severity:** **BLOCKS PLAY STORE SUBMISSION**.
- **Action Steps:**
  1. Log into Google Play Console and select **FeroCalc**.
  2. Fill out **Data Safety** form using exact responses from `docs/release/google_play_data_safety_draft.md`.
  3. Complete **App Content** forms using responses from `docs/release/google_play_app_content_checklist.md`:
     - Ads: **"Yes, my app contains ads"**
     - Financial Features: **"Financial planning and management" / "Financial calculators"** (declare no lending, no deposit-taking).
     - Target Audience: **18 and over** (Appeal to children: "No").
     - App Access: **"All functionality is available without special access"**.
     - Content Rating: Complete IARC questionnaire (expected: PEGI 3 / Everyone).
     - Trader Status: Complete declaration under **Developer account > About you > Trader status** (Deadline: 1 February 2027; determine based on commercial activity and AdMob monetization).
- **How to Verify Completion:** Verify all sections in **Policy > App content** display a green checkmark indicating "Complete".

---

### Item 8: India-Only Country Availability Selection
- **Why Required:** FeroCalc’s calculators, tax references (TDS, Sections 194A / 393(1)), bank circular verification, and DICGC insurance rules are designed exclusively for the Republic of India. Restricting distribution prevents regulatory compliance conflicts in foreign jurisdictions.
- **Who Must Provide It:** Play Console Account Owner.
- **Blocking Severity:** **BLOCKS PLAY STORE SUBMISSION**.
- **Action Steps:**
  1. In Google Play Console, go to **Release > Production (or Testing) > Countries/regions**.
  2. Click **Add countries/regions**.
  3. Select **India (`IN`)** ONLY and deselect all other countries.
  4. Save changes.
- **How to Verify Completion:** Confirm the country count in Play Console displays: **1 country/region: India**.

---

### Item 9: Final Store Listing Visual Assets Upload
- **Why Required:** Google Play requires high-resolution graphic assets to showcase the application on the store listing.
- **Who Must Provide It:** Marketing / UI Designer / Project Owner.
- **Blocking Severity:** **BLOCKS PLAY STORE SUBMISSION**.
- **Action Steps:**
  1. Upload the high-res app icon: `assets/images/ferocalc_icon.png` (512 × 512 px, 32-bit PNG, 91.4 KB).
  2. Export and upload the 1024 × 500 px Feature Graphic following the design blueprint in `docs/release/final_store_listing_package.md`.
  3. Capture and upload genuine phone screenshots (minimum 2, recommended 7) following the screenshot inventory.
  4. Paste the approved Title, Short Description, and Full Description from `docs/release/final_store_listing_package.md`.
- **How to Verify Completion:** Preview store listing in Play Console; verify all graphics and text render without warnings or errors.

---

## 4. Owner Sign-Off Record

| Action Item | Completed By (Name / Signature) | Completion Date | Verification Notes / Ticket Ref |
| :--- | :--- | :--- | :--- |
| **01. Publisher Legal Entity** | ____________________ | ____ / ____ / 2026 | |
| **02. Privacy Policy URL** | ____________________ | ____ / ____ / 2026 | |
| **03. Release Keystore** | ____________________ | ____ / ____ / 2026 | |
| **04. Supabase DB Migrations** | ____________________ | ____ / ____ / 2026 | |
| **05. Vercel Backend Config** | ____________________ | ____ / ____ / 2026 | |
| **06. AdMob Verification** | ____________________ | ____ / ____ / 2026 | |
| **07. Play Console Declarations**| ____________________ | ____ / ____ / 2026 | |
| **08. India-Only Selection** | ____________________ | ____ / ____ / 2026 | |
| **09. Store Listing Assets** | ____________________ | ____ / ____ / 2026 | |
