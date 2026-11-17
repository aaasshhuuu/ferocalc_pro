# Google Play Console — App Content & Policy Compliance Checklist

**Application Name:** FeroCalc — FD, RD, SIP & EMI Calculator
**Package Identifier:** `com.ferocalc.app`
**Distribution Region:** India (`IN`) Only
**Target Android Version:** Android 16 (API 36)
**Document Purpose:** Complete operational checklist for submission in Google Play Console.

---

## 1. App Content Declarations (Play Console > Policy > App content)

| Console Section | Required Selection / Input | Implementation Status & Reviewer Guidance | Action Status |
| :--- | :--- | :--- | :--- |
| **Privacy Policy** | Public HTTPS URL pointing to Privacy Policy | `[PRIVACY_POLICY_PUBLIC_URL]` *(Blocker: Developer must host `docs/legal/privacy_policy.md` on a verified public domain, e.g., GitHub Pages or public web endpoint).* | **MANUAL BLOCKER** |
| **Ads Declaration** | **"Yes, my app contains ads"** | Banner ad powered by Google AdMob on Home screen. AdMob test mode used in debug; official ad units configured in release. | Ready for declaration |
| **App Access** | **"All functionality is available without special access"** | All consumer features (Calculators, Hub, FD Discovery, Compare, Financial Insights, Notifications) require no login. Note for reviewers: `The /admin route is an internal staff console for verifying public bank circulars; no consumer account login exists.` | Ready for declaration |
| **Content Ratings** | Complete IARC Questionnaire | Financial utility app with ads. Expected rating: **PEGI 3 / Everyone (All ages)**. No violence, sexual content, profanity, controlled substances, or gambling. | Ready to fill |
| **Target Audience** | **18 and over** | Target demographic: Working adults and seniors managing savings in India. Form asks: *"Could your app appeal to children?"* Select: **"No"**. | Ready for declaration |
| **News App** | **"No"** | FeroCalc is a financial calculation utility, not a news organization. | Ready for declaration |
| **COVID-19 Contact Tracing** | **"My app is not a publicly available COVID-19 contact tracing or status app"** | Standard declaration. | Ready for declaration |
| **Data Safety** | Submit responses from `docs/release/google_play_data_safety_draft.md` | Declares AdMob GAID, App Set ID, approximate location (IP), user product interactions (launches, taps, impressions), diagnostics/performance telemetry, anonymous notification installation ID, data deletion request mechanism, zero off-device financial data transmission, full TLS encryption. | Ready for declaration |
| **Government Apps** | **"No"** | Does not represent a government entity or RBI. Disclaimers clearly state independent status. | Ready for declaration |
| **Financial Features** | Select: **"Financial planning and management" / "Financial calculators"** | Under the Google Play Financial Services Policy: Declare that the app does NOT provide personal loans, does NOT provide credit, does NOT accept deposits, and is NOT a Digital Lending App (DLA). | Ready for declaration |
| **Advertising ID** | **"Yes, my app uses the Advertising ID"** | Select purposes: **"Advertising or marketing"** (Google AdMob), **"Analytics"**, and **"Fraud prevention / security / compliance"**. | Ready for declaration |
| **Trader Status Declaration** | Declare **"Trader"** or **"Non-Trader"** | Global requirement for developer accounts. Official deadline for existing developer accounts is **1 February 2027** (declared upon account creation for new accounts). Account owner must make an accurate determination based on commercial activity and ad monetization (AdMob). | **OWNER ACTION (Deadline: 1 Feb 2027)** |

---

## 2. Store Presence & Country Availability Setup

### Country / Region Availability
1. In Google Play Console, navigate to: **Release > Production (or Testing) > Countries/regions**.
2. Click **Add countries/regions**.
3. Select **India (`IN`)** ONLY.
4. Confirm selection.
> [!IMPORTANT]
> Country availability cannot be configured in Gradle or AndroidManifest code. It must be selected directly in the Play Console UI before creating a production release.

---

## 3. Store Listing Prerequisites

| Asset | Technical Requirement | Status in Repository | Manual Action Needed |
| :--- | :--- | :--- | :--- |
| **App Title** | Up to 30 characters: `FeroCalc: FD & EMI Calculator` | Defined in `pubspec.yaml` / `AndroidManifest.xml` | Confirm title in Play Console |
| **Short Description** | Up to 80 characters: `Smart FD rates, SIP, EMI, PPF & compound interest calculators for India.` | Drafted | Paste into Store Listing |
| **Full Description** | Up to 4000 characters: Educational description detailing FD discovery, calculators, privacy-first local storage, and bank rate transparency. | Drafted | Paste into Store Listing |
| **App Icon** | 512 x 512 px, 32-bit PNG, up to 1024 KB | Generated in `assets/images/ferocalc_icon.png` | Upload 512x512 PNG |
| **Feature Graphic** | 1024 x 500 px, JPEG or 24-bit PNG | Must be exported | Export and upload |
| **Phone Screenshots** | Minimum 2, maximum 8 screenshots (16:9 or 9:16 aspect ratio) | Screens tested in test suite | Capture high-res screenshots on device/emulator |

---

## 4. Release Signing & Production Artifact Prerequisites

1. **Production Keystore (`upload-keystore.jks`):**
   - The developer must generate or provision a secure upload keystore.
   - Configure `android/key.properties` with real alias and passwords.
   - Fail-closed Gradle configuration (`android/app/build.gradle.kts`) guarantees that release builds fail safely if credentials are absent.
2. **App Bundle (`.aab`):**
   - Generated via `flutter build appbundle --release`.
   - Never commit `key.properties` or `.jks` files to Git.
