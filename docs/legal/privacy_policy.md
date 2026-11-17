# FeroCalc — Official Privacy Policy

**Effective Date:** November 12, 2026
**Last Updated:** November 12, 2026
**Target Distribution Scope:** India (`IN`)
**Publisher Legal Entity:** `[PUBLISHER_LEGAL_ENTITY_NAME]` *(Manual Release Blocker: To be specified before Play Console submission)*
**Registered Business Address:** `[PUBLISHER_REGISTERED_ADDRESS]` *(Manual Release Blocker)*
**Developer Support & Privacy Contact:** `ferocalc.app@gmail.com`

---

## 1. Introduction & Mission

FeroCalc ("the Application", "we", "us", or "our") is an independent financial calculation, fixed deposit (FD) rate discovery, and financial literacy utility built for individuals in India. Our core architectural design principle is **privacy-by-default**: calculations and personal financial figures are processed directly on your mobile device without requiring account creation, identity registration, or remote server transmission.

### Important Scope & Regulatory Statement
- FeroCalc is **NOT** a bank, Non-Banking Financial Company (NBFC), credit broker, or deposit-taking institution.
- FeroCalc does **NOT** lend money, issue credit, solicit or accept cash deposits, or operate financial transactions.
- FeroCalc does **NOT** connect to consumer bank accounts, UPI infrastructure, or net banking credentials.
- FeroCalc is independent and is **NOT** affiliated with or endorsed by the Reserve Bank of India (RBI) or any public or private sector bank.

---

## 2. Full Application Data Inventory

We provide a complete, honest inventory distinguishing locally processed information from data transmitted over external networks.

| Data Category | Specific Fields | Processing / Storage Mechanism | Transmitted to Server? | Third-Party Sharing | Retention & User Control |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Financial Calculator Inputs** | Loan principals, interest rates, tenures, compounding frequencies | Processed in-memory in client process | **NO** — Stays in device RAM only | None | Cleared immediately when screen is closed or reset. |
| **Calculation History** | Saved calculation records (principal, maturity, date, type) | Local SharedPreferences on device | **NO** — Strictly on-device | None | User can view and delete individual calculations or clear all history in app. |
| **Financial Goals** | Target amounts, deadlines, monthly savings targets | Local SharedPreferences on device | **NO** — Strictly on-device | None | User can create, edit, or delete goals at any time in app. |
| **Financial Insights Profile** | Self-declared monthly income, expenses, emergency fund, retirement figures | Local SharedPreferences on device (excluded from Cloud Backup) | **NO** — Never transmitted to FeroCalc servers | None | Kept in private device storage. Excluded from cloud backup to prevent off-device upload. Cleared via Android Storage or in-app Reset. |
| **App Preferences** | Selected customer type (Regular vs Senior Citizen), visual theme (Dark/Light) | Local SharedPreferences on device | **NO** — Strictly on-device | None | Persisted until app uninstall or user modification. |
| **Public Rate Inquiries** | Rate filters (tenure duration, bank identifier, callable flag) | Anonymous read-only HTTPS GET requests | **YES** — Fetches verified rate tables | None | Transient hosting provider request metadata (IP, method, path, status) processed by hosting infrastructure (Vercel) to route requests and protect against denial-of-service, retained per hosting operational policies without unverified fixed-time purge guarantees. |
| **Notification Installation ID** | Anonymous unique installation ID (`inst_xxx`, randomly generated) & auth token | Local SharedPreferences + Notification endpoint | **YES** — Sent to register for alerts | None | Used solely to coordinate rate alerts. Deleted upon user in-app deletion request, email request, or app storage reset. |
| **Favorite Banks & Alert Preferences** | Selected bank IDs (e.g. `['sbi', 'hdfc']`), notification category flags | Local SharedPreferences + Notification endpoint | **YES** — Sent during alert preference sync | None | Synchronized to dispatch verified rate changes. Revoked and deleted via in-app deletion or Notification Settings. |
| **Advertising Identifiers & Telemetry** | Google Advertising ID (GAID), App Set ID, IP address (approximate coarse location), user product interactions (launches, taps, impressions), SDK diagnostics & performance (startup latency, battery, screen, crash/ANR telemetry) | Collected independently by Google Mobile Ads SDK (`play-services-ads:25.4.0`) | **YES** — Sent directly to Google AdMob | Google LLC | Governed by Google's Privacy Policy. User can reset/delete GAID via Android Settings. |

---

## 3. Advertising & Google AdMob Integration

FeroCalc is supported by banner advertising powered by Google AdMob (Google Mobile Ads SDK, specifically native Android dependency `com.google.android.gms:play-services-ads:25.4.0` resolved via `google_mobile_ads: ^9.1.0`) displayed on the Android Home screen.

### Ad Quality & Safety Guarantees
1. **Clear Distinction:** All advertisements are visually demarcated with an explicit "ADVERTISEMENT" badge.
2. **Accidental Click Prevention:** Ads are housed in separate containers away from primary calculation buttons, sliders, and navigation controls.
3. **No Intrusive Interstitials:** We do not display intrusive interstitial popups or full-screen video ads during financial form entry or calculation reviews.
4. **Editorial Independence:** Advertisers have no influence over calculator formulas, ranking algorithms, or bank rate display order.
5. **Data Collected by Google:** The Google Mobile Ads SDK automatically collects and processes device identifiers (GAID, App Set ID), IP address (approximate coarse location estimation for ad delivery and fraud prevention), user product interactions (app launch, screen views, ad impressions, ad taps), and diagnostic performance information (battery, volume, latency, crash and ANR telemetry) under [Google's Privacy Policy](https://policies.google.com/privacy).
6. **No Optional Tracking / Mediation:** FeroCalc bundles zero advertising mediation adapters, third-party trackers, or optional location-tracking modules. FeroCalc declares zero GPS or fine location permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`).

### Managing Advertising Preferences
You can opt out of personalized ads or reset your advertising identifier on Android devices at any time:
- Navigate to **Android Settings > Google > Ads**.
- Tap **Reset advertising ID** or **Delete advertising ID**.

---

## 4. Notification & Alert Services

FeroCalc offers verified bank fixed deposit rate change alerts:
- **Contextual Consent:** We never request notification permissions on application startup. Permission is requested contextually only when you enable alerts or interact with the Notification Settings screen.
- **Strict Verification Guardrail:** Notifications are dispatched strictly for rate changes that have completed multi-source verification and human reviewer approval. Unverified rumors, drafts, or internal notes are never broadcast.
- **Opt-Out Controls:** You can disable notifications globally or fine-tune specific bank and slab preferences in **Profile > Notifications & Alerts > Notification Settings**.

---

## 5. User Account Policy & Data Deletion Requests

### Consumer Accounts Policy
FeroCalc does not require, support, or offer consumer account registration. You do not create a username, password, or profile on our servers. Administrative authentication is restricted solely to verified internal rate verification staff.

### Data Deletion Request Mechanism
While consumer accounts do not exist, anonymous notification registration data (anonymous installation IDs, device push tokens, favorite bank identifiers, and notification category preferences) may be transmitted to and stored by FeroCalc's backend when users opt into alerts. Users have clear, accessible mechanisms to request deletion of this data:

1. **Self-Service In-App Deletion:**
   - In **Profile > Notifications & Alerts > Notification Settings**, navigate to the **Data Privacy & Deletion** section.
   - Tap **Delete Remote Notification Data**.
   - FeroCalc securely transmits a protected deletion request to `DELETE /api/notifications/device-token` using a unique cryptographic installation authorization token generated on your device. This prevents unauthorized callers from deleting another device's registration.
   - Upon confirmation, your remote device token, alert preferences, and favorite bank associations are permanently removed from backend storage.
   - **Local Data Preserved:** This action only deletes remote notification registration. Your local saved calculations, goals, and financial profile are stored on your device and are **NOT** deleted.
2. **Assisted Deletion via Support Email:**
   - Users who have uninstalled FeroCalc, changed devices, or prefer assisted deletion may email our verified privacy contact at **`ferocalc.app@gmail.com`** with their anonymous Installation ID (which can be copied from Notification Settings).
   - We will manually purge the matching backend registration record within 30 days of receipt.
3. **Data Retained for Security & Audit:**
   - Globally shared verified bank rate history, public circular provenance records, and system-level security logs are retained permanently for public rate auditability, regulatory transparency, and platform security. These records contain zero consumer personal identities.
4. **Local Data Clearing:**
   - To clear locally stored calculation history, goals, and financial profiles:
     - In-App: Profile > Data & Trust > Clear Local Cache & History.
     - Android Settings: Settings > Apps > FeroCalc > Storage > Clear Storage / Clear Data.
     - App Uninstall: Uninstalling the application completely erases all local files and preferences.

---

## 6. Security Practices

We implement industry-standard technical, operational, and architectural safeguards:
- **HTTPS Everywhere:** All communication with backend endpoints is enforced over TLS/HTTPS.
- **Cleartext Traffic Blocked:** Android network security settings explicitly disallow unencrypted cleartext HTTP traffic (`android:usesCleartextTraffic="false"`).
- **Cloud Backup Privacy Isolation:** To safeguard sensitive personal financial data and administrative credentials, FeroCalc explicitly excludes `FlutterSharedPreferences.xml` from Android Cloud Backup and device transfer in `android/app/src/main/res/xml/data_extraction_rules.xml` and `backup_rules.xml`. This prevents personal financial profiles (`ferocalc_financial_profile_v1`), anonymous installation credentials, and administrative session tokens from being uploaded to Google Cloud Backup or transferred off-device unencrypted.
  - *Data Migration Trade-Off:* Because SharedPreferences is excluded from cloud backup to protect user privacy, saved calculations and goals will not be restored from Google Drive cloud backups upon device migration; users configure preferences fresh on a new device.
- **Fail-Closed Release Signing:** Release builds enforce strict cryptographic keystore signing and reject unauthenticated deployment artifacts.

---

## 7. Children's Privacy

FeroCalc is designed for adult financial decision-makers in India (18 years of age or older). We do not knowingly market to or collect personal information from individuals under 18 years of age (or under 13 where applicable).

---

## 8. Policy Updates & Inquiries

We may update this Privacy Policy to reflect application updates or evolving statutory guidelines (such as the Digital Personal Data Protection Act, 2023). Any updates will be published with a revised "Last Updated" timestamp.

**Contact Details:**
- **Email:** `ferocalc.app@gmail.com`
- **Publisher Entity:** `[PUBLISHER_LEGAL_ENTITY_NAME]`
- **Registered Address:** `[PUBLISHER_REGISTERED_ADDRESS]`
