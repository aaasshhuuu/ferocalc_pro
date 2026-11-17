# Google Play Console — Data Safety Form & Declarations Draft

**Application Name:** FeroCalc — FD, RD, SIP & EMI Calculator
**Package Name:** `com.ferocalc.app`
**Target API:** 36 (Android 16)
**Distribution Scope:** India (`IN`) Only
**Assessment Date:** November 13, 2026
**Document Status:** Production Launch Ready Draft (Evidence-Based & Phase 5.1.0.1 Hardened)

---

## 1. Overview of Data Safety Responses

Google Play Console requires an evidence-backed declaration of user data collection, sharing, and security practices. This document translates actual codebase implementations, native Gradle dependencies (`com.google.android.gms:play-services-ads:25.4.0`), and backend API contracts into exact Play Console responses.

### Summary of Declarations
- **Does your app collect or share any of the required user data types?**
  **YES** (due to Google Mobile Ads SDK / AdMob integration and anonymous device notification registration).
- **Is all of the user data collected by your app encrypted in transit?**
  **YES** (all network traffic is strictly enforced over TLS/HTTPS; Android cleartext traffic is disabled via `android:usesCleartextTraffic="false"`).
- **Do you provide a way for users to request that their data be deleted?**
  **YES** (Users can request deletion of remote notification registration and preferences directly in-app via Notification Settings or via verified support email `ferocalc.app@gmail.com`).
- **Does your app allow users to create an account?**
  **NO** (Consumer accounts do not exist; all calculator functions, bank rate discovery, and financial tools function without registration).

---

## 2. Category-by-Category Data Safety Declarations

### A. Location
| Question | Response | Supporting Code & Justification |
| :--- | :--- | :--- |
| **Approximate Location** | **Collected:** Yes<br>**Shared:** Yes (with Google LLC / AdMob)<br>**Processed Ephemerally:** No<br>**Required or Optional:** Required for ad serving<br>**Purposes:** Advertising or marketing, Fraud prevention / security / compliance | Handled internally by Google Mobile Ads SDK (`play-services-ads:25.4.0`) via IP address geolocation for country/city estimation. FeroCalc declares **zero** location permissions (`ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` are absent from `AndroidManifest.xml`). |
| **Precise Location** | **NOT Collected** | No GPS, cellular triangulation, or fine location permissions declared or accessed. |

---

### B. Personal Information
| Data Type | Response | Supporting Code & Justification |
| :--- | :--- | :--- |
| **Name** | **NOT Collected** | No consumer profile or registration system exists. |
| **Email Address** | **NOT Collected** | Consumers do not log in. (Admin/reviewer authentication is restricted to internal staff via private Supabase endpoint; not a consumer feature). |
| **User IDs** | **NOT Collected** | No persistent consumer identity or user profile ID exists. |
| **Address / Phone** | **NOT Collected** | Never requested or stored. |
| **Government IDs** | **NOT Collected** | No PAN, Aadhaar, or Voter ID requested or processed. |

---

### C. Financial Information
| Data Type | Response | Supporting Code & Justification |
| :--- | :--- | :--- |
| **User Payment Info** | **NOT Collected** | FeroCalc has no in-app purchases, paid features, or payment processing. |
| **Purchase History** | **NOT Collected** | No commerce or financial transactions. |
| **Credit Score / Credit Info** | **NOT Collected** | No credit bureau queries or credit checks. |
| **Financial Accounts / Balances** | **NOT Collected off-device** | Calculator inputs, loan amounts, and Financial Insights metrics (monthly income, savings) are stored **strictly on-device in local SharedPreferences** and are **NEVER** transmitted off the device. Furthermore, `FlutterSharedPreferences.xml` is explicitly excluded from Android Cloud Backup (`data_extraction_rules.xml` and `backup_rules.xml`). Under Google Play Data Safety guidelines, data that never leaves the user's device is not classified as "collected". |

---

### D. App Activity & User Product Interactions
| Data Type | Response | Supporting Code & Justification |
| :--- | :--- | :--- |
| **App Interactions** | **Collected:** Yes<br>**Shared:** Yes (with Google LLC / AdMob)<br>**Processed Ephemerally:** No<br>**Required or Optional:** Required for ad delivery & analytics<br>**Purposes:**<br>1. Advertising or marketing (Google AdMob)<br>2. Analytics<br>3. Fraud prevention, security & compliance | Automatically collected by the Google Mobile Ads SDK (`play-services-ads:25.4.0`) to track user product interactions, including app launches, screen views, ad views/impressions, and ad click/tap events for advertising attribution and fraud prevention. FeroCalc does NOT bundle standalone custom product analytics SDKs. |

---

### E. App Info and Performance / Diagnostics
| Data Type | Response | Supporting Code & Justification |
| :--- | :--- | :--- |
| **Diagnostics & Performance** | **Collected:** Yes<br>**Shared:** Yes (with Google LLC / AdMob)<br>**Processed Ephemerally:** Depends on metric<br>**Required or Optional:** Required for SDK stability<br>**Purposes:**<br>1. Analytics<br>2. App functionality<br>3. Fraud prevention, security & compliance | Collected by the Google Mobile Ads SDK (`play-services-ads:25.4.0`). Evaluates broader diagnostic and performance data, including SDK startup latency, battery level, device volume, screen resolution, connection types, crashes, and ANR telemetry. FeroCalc does NOT bundle standalone Crashlytics or Sentry SDKs. |

---

### F. Device or Other Identifiers
| Data Type | Response | Supporting Code & Justification |
| :--- | :--- | :--- |
| **Device or other IDs** | **Collected:** Yes<br>**Shared:** Yes (AdMob identifiers shared with Google; FeroCalc installation ID NOT shared)<br>**Processed Ephemerally:** No<br>**Required or Optional:**<br>• AdMob GAID / App Set ID: Required for ad delivery.<br>• Notification Installation ID: Optional (only activated if user interacts with notification settings).<br>**Purposes:**<br>1. Advertising or marketing (Google AdMob)<br>2. App functionality (Rate change alerts)<br>3. Analytics<br>4. Fraud prevention, security & compliance | **Code Evidence:**<br>1. Google Mobile Ads SDK collects Android Advertising ID (`GAID`) and App Set ID for ad attribution and frequency capping.<br>2. `NotificationService` generates an anonymous `installationId` (`inst_xxx`) and auth token sent to `POST /api/notifications/device-token` to route verified rate change alerts without consumer identity. This internal ID is never shared with Google or third parties. |

---

## 3. Security Practices

1. **Encryption in Transit:**
   **YES** — All network communications (verified rate queries, anonymous notification tokens, AdMob calls) are strictly enforced over TLS/HTTPS.
   - `AndroidManifest.xml` explicitly enforces `android:usesCleartextTraffic="false"`.
2. **Independent Security Review:**
   Select "No" unless a certified third-party MASA (Mobile Application Security Assessment) has been officially conducted.
3. **Data Deletion Mechanism:**
   - Select: **"Yes, the app provides a mechanism for users to request that their data be deleted."**
   - **How Deletion Is Requested:**
     1. **In-App Self-Service:** Users can navigate to **Notification Settings > Data Privacy & Deletion > Tap "Delete Remote Notification Data"**. This sends a cryptographically authorized request to `DELETE /api/notifications/device-token`, permanently purging their remote device token, alert preferences, and favorite bank associations.
     2. **Assisted Email Request:** Users who have uninstalled the app or prefer email handling can email **`ferocalc.app@gmail.com`** with their anonymous Installation ID.
   - **What Data Is Deleted:** Remote push tokens, favorite bank IDs, and alert category preferences.
   - **What Data Is Retained:** Shared verified bank rate history and security audit logs are retained permanently for statutory auditability and platform integrity (zero personal identity contained). Local calculations and goals remain on-device unless the user clears app storage.

---

## 4. Google Play Account Deletion Policy Compliance

- **Does your app allow users to create an account?**
  **NO**.
- **Explanation for Reviewers:**
  "FeroCalc does not support or provide consumer account creation. All financial calculators, fixed deposit rate discovery features, and notification centers function without user registration or login. The administrative portal (`/admin`) is strictly an internal rate verification interface for authorized staff and does not permit public consumer signups."
- **Account Deletion URL Requirement:** **NOT APPLICABLE** (exempt because consumer accounts cannot be created).
- **Distinction Between Account and Data Deletion:** While consumer accounts do not exist, FeroCalc truthfully declares a data deletion request mechanism in Section 3 for its anonymous notification registration service.

---

## 5. Google Play Financial Services Policy Compliance

FeroCalc falls under the **Financial Utilities / Calculators / Financial Education** classification:

| Financial Policy Area | FeroCalc Status | Reviewer Notes |
| :--- | :--- | :--- |
| **Personal Loans** | **DOES NOT PROVIDE** | FeroCalc does NOT offer, facilitate, or broker personal loans or short-term credit. The EMI and Loan Amount calculators are educational mathematical tools. |
| **Banking / Deposits** | **DOES NOT ACCEPT** | FeroCalc is NOT a bank and does NOT accept customer deposits or hold funds. |
| **Digital Lending Apps (India DLA)** | **NOT A DLA** | FeroCalc does not originate loans or act as a Lending Service Provider (LSP). Does not access contacts, camera, or SMS. |
| **Financial Affiliation** | **INDEPENDENT** | App clearly discloses non-affiliation with RBI or commercial banks in About, Legal, and Disclaimer screens. |

---

## 6. Target Audience, Content Rating & Ads Declaration

- **Target Age Group:** 18 and over (Adults managing household personal finances).
- **Appeal to Children:** Neutral / No child-directed content.
- **Contains Ads:** **YES** (Google AdMob banner ads on Android Home screen).
- **News App:** **NO**.
- **COVID-19 Contact Tracing:** **NO**.
- **Government Services:** **NO** (Utility app; does not claim to represent any government department).

---

## 7. Google Play Trader Status Guidance

Under Google Play's compliance framework for developer accounts:
- **Scope:** The Trader status declaration applies globally to all active developer accounts across Google Play Console, regardless of whether distribution is initially limited to India.
- **Applicable Deadlines:**
  - **New Developer Accounts:** Must complete the Trader status declaration immediately during account creation and identity verification.
  - **Existing Developer Accounts:** The official Google Play deadline to submit the Trader status declaration is **1 February 2027**.
- **Classification Criteria:** Google's guidance considers commercial activity, profit-seeking intent, and ad-monetization (such as serving Google AdMob ads) as key factors indicating trader status. The account owner must determine and select their status based on their entity's actual activities; do NOT automatically declare Non-Trader merely because FeroCalc distributes only in India or offers free calculators.
- **Public Disclosure Implications:** If declared as a Trader, the developer's registered business address, phone number, and support email will be displayed publicly to consumers on Google Play store listings in applicable jurisdictions (including the EEA) under consumer protection rules.
- **Action for Publisher:** The account owner must log into Play Console > **Developer account > About you > Trader status** and complete the declaration prior to 1 February 2027 (or immediately upon account setup if registering a new console account).
