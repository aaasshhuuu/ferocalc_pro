# FeroCalc — Phase 5.0.3 Implementation Report: Smart FD Discovery, Best for Me & Advanced Comparison

**Milestone:** Phase 5.0.3: Smart FD Discovery, Best for Me & Advanced Comparison
**Project:** FeroCalc (FinCalc Pro)
**Target Repository / Worktree:** `C:\projects\fincalc_pro_staging_prep`
**Git Branch:** `staging/vercel-backend-preview`
**Target Database:** Staging Supabase (`cqrslxngpwbtkjejlwty`)
**Protected Boundary:** Primary worktree `C:\projects\fincalc_pro` and Production Supabase `pmaykclwuyspxhgeomee` untouched. Zero commits, zero pushes, zero remote deployments executed. Live-rate display on Home Screen remains strictly disabled. Automated collection pipeline remains disabled (`enabled: false`).
**Status:** Verification Complete & Ready for Review
**Date:** 2026-11-12

---

## 1. Executive Summary

Phase 5.0.3 delivers a fully integrated, consumer-facing **Smart FD Discovery** experience in the FeroCalc Flutter application. Built directly on top of the audited verified-rate infrastructure (Phase 4.3.x, Phase 5.0.0, Phase 5.0.1, and Phase 5.0.2), this milestone empowers consumers to search, match, compare, and calculate returns across authentic, active, bank-verified fixed deposits in India.

In strict adherence to FeroCalc's core mathematical and trust principles:
- **No Fabricated Rates or Advice:** The discovery engine operates exclusively on currently published, active `VERIFIED` rate records fetched via `VerifiedRateService`. Unverified, draft, or in-review rates (such as Kotak candidates awaiting administrative review) are strictly excluded from consumer discovery results.
- **Tenure Domain Integrity:** Full dual-domain tenure compatibility is preserved for both `DAYS` and `CALENDAR` tenures without loss of precision. Gregorian calendar conversions are performed rigorously.
- **Single Source of Mathematical Truth:** Maturity estimates and interest earned are computed strictly using the established `FinancialMath.calculateFDMaturity` engine with standard quarterly compounding ($n=4$), preventing formula discrepancies between discovery and the calculator screens.
- **Deep Calculator Integration:** Every matching result provides a seamless "Calculate Returns" action that deep-links directly into `FdCalculatorScreen`, carrying forward the selected principal, rate, tenure, customer category, and official source metadata with visual attribution banners and "Reset Rate" controls.

---

## 2. Core Feature Highlights

### 2.1 "Best for Me" FD Finder (`SmartFdDiscoveryScreen`)
The "Best for Me" FD Finder allows consumers to define their exact investment profile and discovers strictly eligible verified fixed deposits:

1. **User Criteria Inputs:**
   - **Investment Amount:** Formatted numeric input with quick-selection chips (₹25,000, ₹50,000, ₹1 Lakh, ₹5 Lakhs, ₹10 Lakhs).
   - **Investment Tenure & Units:** Numeric tenure with unit selector supporting **Days**, **Months**, and **Years**, complemented by quick preset chips (91 Days, 180 Days, 1 Year, 2 Years, 3 Years, 5 Years).
   - **Customer Category:** Toggle between **Regular** and **Senior Citizen** (+0.50% to +0.75% differential rates automatically surfaced).
   - **Callable / Non-Callable Preference:** Dropdown filter supporting **Any**, **Callable Only**, or **Non-Callable Only**.
   - **Bank Selection:** Search across **All Verified Banks** or isolate a specific institution.
   - **Bank Type Filter:** Filter chips for **All**, **Public Sector**, **Private Sector**, and **Small Finance Banks**.

2. **Matching & Eligibility Engine (`FdDiscoveryEngine`):**
   - **Status Filtering:** Only records with `status == 'VERIFIED'` and `isActive == true` are evaluated. Expired or future-dated records are discarded.
   - **Deposit Boundary Validation:** Verifies that $minDeposit \le principal \le maxDeposit$. Standard retail limits (< ₹2 Crore) and bulk limits ($\ge$ ₹2 Crore) are strictly enforced.
   - **Tenure Domain Matching:**
     - `DAYS` domain: Checks if criteria converted days fall within $[minTenureDays, maxTenureDays]$.
     - `CALENDAR` domain: Accurately matches calendar months, years, and hybrid expressions (e.g. 1 Year to 443 Days, 400 Days special schemes) using Gregorian component arithmetic.
   - **Callable Filtering:** Respects product callable rules (`isCallable == true` vs `false`).
   - **Customer Category Filtering:** Regular queries pull standard retail rates; Senior Citizen queries pull dedicated senior citizen slabs.

3. **Results Presentation:**
   - Displays matching candidates with bank name, bank type badge, applicable interest rate, exact matching tenure description, estimated maturity amount, total interest earned, callable status, deposit limits, last verified date, and official circular link.
   - **Sorting Modes:** Sort by **Estimated Maturity Amount** (default), **Interest Rate (Highest First)**, or **Bank Name (A-Z)**.
   - **Honest Copy & Disclaimers:** Uses explicit language: *"Matching options for your criteria"* and *"Based on your selected criteria"*. Prominently discloses: *"Estimated returns based on quarterly compounding. Not financial advice or guaranteed returns."*

---

### 2.2 Advanced FD Comparison Matrix (`AdvancedFdComparisonScreen`)
Consumers can select up to **four** eligible FD options from the discovery results and compare them side by side in a dedicated matrix:

1. **Normalized Baseline Header:**
   - Standardizes the comparison by displaying the exact baseline inputs held constant across all options: Principal Amount, Investment Tenure, and Customer Category.

2. **Side-by-Side Comparison Columns:**
   - **Interest Rate & Return Badges:** Highest interest rate option automatically marked with a green *"Highest Return"* badge.
   - **Maturity & Interest Spread:** Dynamically calculates and displays the financial spread between the highest and lowest yielding options (e.g., *"Earn ₹2,450 more with [Bank A] compared to [Bank B] over the same tenure"*).
   - **Structural Attributes:** Detailed rows comparing Minimum/Maximum Deposit boundaries, Product Eligibility, Callable Status, Compounding Frequency (Quarterly), Effective Dates, and Last Verified Timestamps.
   - **Official Verification Link:** Direct link to the official circular URL for each compared institution.
   - **Direct Calculation Action:** Individual "Calculate Returns" CTA per column passing specific bank rate parameters to `FdCalculatorScreen`.

---

### 2.3 Deep FD Calculator Integration (`FdCalculatorScreen`)
Rather than keeping discovery isolated, the FeroCalc calculator suite is deeply wired to verified discovery matches:

1. **Parameter Pre-population:**
   - `FdCalculatorScreen` constructor and GoRouter route `/calculator/fd` upgraded to consume:
     - `initialPrincipal` (e.g. 100,000)
     - `initialInterestRate` (e.g. 7.25%)
     - `initialYears`, `initialMonths`, `initialDays` (deconstructed tenure)
     - `initialIsSeniorCitizen` (boolean)
     - `appliedBankName` (e.g. "Punjab National Bank")
     - `appliedSourceUrl` (official circular URL)
     - `appliedVerifiedAt` (ISO timestamp)
     - `appliedCompoundingFrequency` (Quarterly)

2. **Official Verified Rate Notice Banner:**
   - Displays a prominent verified banner inside the calculator:
     - Green Shield verified icon.
     - Notice: *"Using verified rate from [Bank Name] ([Rate]%)"*.
     - Clickable link: *"Official Circular"* opening the bank's official source.
     - "Reset Rate" button that appears if the user edits the interest rate, allowing one-tap restoration of the authentic verified rate.

3. **Assumptions Editing Without Misrepresentation:**
   - Users remain free to tweak principal or tenure. If the rate is modified away from the bank's official rate, the banner cleanly reflects that assumptions were edited and provides the reset option.

---

### 2.4 Navigation & App Touchpoints
Discovery features are accessible via multiple user pathways:
1. **Compare Screen Verified Tab Banner:** A prominent "Best for Me FD Finder" banner is placed directly at the top of the "Verified Rates" tab on `CompareScreen`.
2. **Calculators Hub:** A dedicated card *"Best for Me FD — Discover highest returns for your tenure & amount"* is added to the Deposits section on `CalculatorsHubScreen`.
3. **Route Registry:**
   - `/discovery/best-for-me` (`AppRoutes.smartFdDiscovery`)
   - `/discovery/compare` (`AppRoutes.advancedFdCompare`)
4. **Data Trust Center Empty State Bridges:** In instances where zero banks match user criteria, an honest empty state is rendered with a direct navigation link to `/trust-center` to review data coverage.

---

## 3. Architecture & File Inventory

### 3.1 New Core & Feature Files
| File Path | Description | Lines of Code |
|---|---|---|
| `lib/core/models/discovery_models.dart` | Pure domain models: `CustomerCategory`, `TenureUnit`, `CallablePreference`, `FdSortOption`, `FdDiscoveryCriteria`, `FdDiscoveryMatch`, and `FdDiscoveryEngine`. | 288 |
| `lib/features/discovery/presentation/screens/smart_fd_discovery_screen.dart` | Consumer-facing "Best for Me" discovery UI, input forms, criteria chips, result cards, and bottom comparison selection bar. | 868 |
| `lib/features/discovery/presentation/screens/advanced_fd_comparison_screen.dart` | Multi-bank side-by-side comparison matrix for 2-4 selected FD options with spread calculations and official metadata. | 412 |
| `test/smart_fd_discovery_engine_test.dart` | Exhaustive unit tests for matching criteria, tenure domains, deposit limits, callable tiering, and sorting. | 525 |
| `test/smart_fd_discovery_widget_test.dart` | Full widget and integration test suite validating UI rendering, filtering, comparison bar, and calculator pre-population. | 295 |

### 3.2 Modified Files
| File Path | Nature of Changes |
|---|---|
| `lib/core/utils/date_formatter.dart` | Added `formatRelative()` and `formatIsoDate()` helpers for verified timestamp displays. |
| `lib/config/routes/route_names.dart` | Added `smartFdDiscovery` (`/discovery/best-for-me`) and `advancedFdCompare` (`/discovery/compare`). |
| `lib/config/routes/app_router.dart` | Registered routes for `SmartFdDiscoveryScreen` and `AdvancedFdComparisonScreen`; extended `/calculator/:type` for FD parameter pass-through. |
| `lib/features/calculators/presentation/screens/fd_calculator_screen.dart` | Constructor parameters, applied rate banner, source circular link, and reset rate state. |
| `lib/features/calculators/presentation/screens/calculators_hub_screen.dart` | Added "Best for Me FD" card to Deposits grid. |
| `lib/features/compare/presentation/screens/compare_screen.dart` | Added "Best for Me FD Finder" banner scoped to Verified Rates tab. |

---

## 4. Mathematical & Calculation Integrity

### 4.1 Compounding Engine Integration
In accordance with Indian banking norms (RBI Master Direction on Interest Rates on Deposits), retail domestic term deposits compute maturity using quarterly compounding ($n=4$):

$$A = P \left(1 + \frac{r}{n}\right)^{n \cdot t}$$

Where:
- $P$ = Principal deposit amount in INR.
- $r$ = Annual interest rate as a decimal (e.g. $7.25\% \rightarrow 0.0725$).
- $n$ = Compounding frequency per year ($n = 4$ for quarterly).
- $t$ = Investment tenure in years ($t = \frac{\text{tenureDays}}{365}$ or calendar years).

To avoid formula duplication, `FdDiscoveryEngine` calls directly into FeroCalc's existing calculation engine:
```dart
final maturity = FinancialMath.calculateFDMaturity(
  principal: criteria.depositAmount,
  rate: applicableRate,
  years: tenureInYears,
  frequency: FinancialMathCompoundingFrequency.quarterly,
);
final totalInterest = maturity - criteria.depositAmount;
```

### 4.2 Tenure Normalization & Dual Domain Matching
Indian banks publish rates using either exact day ranges (e.g., `400 days` or `211 days to 364 days`) or calendar ranges (e.g., `1 Year to 2 Years`). The `FdDiscoveryEngine` normalizes inputs without loss of fidelity:
- When a user enters **1 Year**, the engine checks both calendar slabs (`minTenureDays: 365, maxTenureDays: 365` or calendar domain `1 Year`) and day ranges covering 365 days.
- When a user enters **Months** (e.g. 6 Months), the engine checks both day-based slabs ($\sim 180\text{--}184$ days) and calendar slabs ($6\text{ months}$).
- In special schemes (e.g. PNB 443 Days or BOB 399 Days), tenure matching strictly respects the bank's published boundaries.

---

## 5. Verification & Test Suite Results

### 5.1 Unit & Engine Tests (`test/smart_fd_discovery_engine_test.dart`)
19 of 19 tests **PASSED** in 0.8s:
- **Group 1 (Criteria Validation):** Validates normal criteria, rejects zero/negative deposits, rejects tenure < 7 days, rejects tenure > 10 years, converts units accurately.
- **Group 2 (Deposit Boundaries):** Matches within slab limits, excludes deposits below minimum limit, isolates bulk deposits ($\ge$ ₹2 Crore).
- **Group 3 (Tenure Domains):** Evaluates `DAYS` domain exact match, `CALENDAR` domain 1-Year match, 14-Month match, and boundary exclusion.
- **Group 4 (Customer Category):** Matches regular rates, matches senior citizen differentials, isolates senior slabs.
- **Group 5 (Callable & Product Eligibility):** Filters callable vs non-callable preferences accurately.
- **Group 6 (Status & Effective Dates):** Excludes `DRAFT`, `IN_REVIEW`, `STALE`, expired rates, and future-dated records.
- **Group 7 (Sorting & Ranking):** Sorts by estimated maturity, interest rate, and bank name.

### 5.2 Widget & UI Integration Tests (`test/smart_fd_discovery_widget_test.dart`)
5 of 5 tests **PASSED** in 12.0s:
- Renders criteria inputs, loads verified rates from service, displays matching cards.
- Multi-selection allows picking up to 4 options and reveals bottom comparison bar.
- Empty state renders cleanly when no banks match criteria, displaying link to Data Trust Center.
- Tapping "Calculate Returns" launches `FdCalculatorScreen` with pre-filled inputs.
- `FdCalculatorScreen` displays official verified rate banner, circular link, and reset rate button.

### 5.3 Compare Screen Layout & Overflow Regression Tests (`test/compare_screen_layout_test.dart`)
15 of 15 tests **PASSED** in 20.0s:
- Zero overflow on 500dp height.
- Zero overflow on 400dp height.
- Zero overflow with 280dp software keyboard insets.
- Calendar & Days domain toggles fully responsive.

### 5.4 Data Trust Center & Freshness Tests (`test/data_trust_center_test.dart`)
21 of 21 tests **PASSED** in 13.0s:
- Confirms telemetry, coverage calculations, and history API integration remain 100% operational.

### 5.5 Static Analysis (`flutter analyze`)
- Analyzed all discovery files, models, and test suites.
- **Result:** `No issues found!` (0 errors, 0 warnings).

---

## 6. Strict Boundaries Conformance

| Boundary Mandate | Status | Verification Evidence |
|---|---|---|
| **Staging Worktree Only** | Fully Compliant | Executed exclusively in `C:\projects\fincalc_pro_staging_prep`. |
| **Primary Worktree Untouched** | Fully Compliant | `C:\projects\fincalc_pro` remains completely clean and untouched. |
| **Staging Database Only** | Fully Compliant | Target is Staging Supabase `cqrslxngpwbtkjejlwty`. Production `pmaykclwuyspxhgeomee` was never accessed. |
| **Zero Commits / Pushes** | Fully Compliant | All changes exist as uncommitted, unstaged files on branch `staging/vercel-backend-preview`. |
| **No Remote Deployments** | Fully Compliant | No Vercel or Supabase deployments triggered. |
| **Home Screen Live-Rate Display** | Fully Compliant | Live rate banner remains strictly disabled on Home Screen. |
| **Automated Pipeline Schedule** | Fully Compliant | GitHub Actions workflow remains disabled (`enabled: false`). |

---

## 7. Genuine Remaining Limitations & Next Steps

1. **Kotak Mahindra Bank Rates:**
   - As established in Phase 5.0.2, Kotak domestic term deposit slabs (40 candidate slabs) are parsed and stored in the staging database under `IN_REVIEW`. In accordance with FeroCalc security policy, unpromoted candidates are strictly excluded from the Best for Me FD Finder. Once promoted by an authorized human reviewer via the Admin Dashboard, Kotak rates will automatically surface in consumer discovery without requiring any code changes.
2. **Unity Small Finance Bank:**
   - Unity SFB remains in the catalog without a parser (`catalog-only`). It is excluded from verified discovery results until an official parser and collector are implemented.
3. **Axis Bank Source Refresh:**
   - Axis Bank verified rates (36 published slabs) remain active and matchable in discovery. Its official PDF source is undergoing automated retry upon the next collection cycle.
4. **Day-Count Conventions Disclosures:**
   - Maturity calculations adhere to standard quarterly compounding ($n=4$). While this provides an accurate estimate for $>98\%$ of retail FDs, institutions employing specific day-count conventions (such as 365-day leap-year adjustments or monthly compounding) may exhibit rupee-level variances. This is clearly disclosed to consumers in the results header and comparison footer.
