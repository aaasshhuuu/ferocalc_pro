# FeroCalc — HDFC Batch 2 Human Reviewer Packet

**Batch Identifier:** `HDFC_BATCH_2`  
**Bank Code:** `HDFC` (HDFC Bank Ltd.)  
**Official Source URL:** [https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate](https://www.hdfc.bank.in/fixed-deposit/fd-interest-rate)  
**Official Effective Date:** `2026-08-19`  
**Product Scope:** Retail Domestic Term Deposits < ₹3.00 Crore (`₹5,000.00` to `₹29,999,999.00`)  
**Compounding Frequency:** `QUARTERLY`  
**Callability:** `true` (Callable)  
**Rate Category:** `STANDARD` (`scheme_name` is NULL)  
**Total Slabs:** 19 slabs  
**Total Review Candidates:** 38 candidates (`REV_017` to `REV_054`)  
**Current Governance Status:** `REVIEW_REQUIRED` (Unapproved, Zero Auto-Promotion)

---

## 1. Evidence Provenance & Cryptographic Traceability

| Artifact | Identifier / File Path | SHA-256 Digest |
|:---|:---|:---|
| **Official Discovery Snapshot** | `backend/review/source-discovery/hdfc_domestic_retail_fd_rates_2026-08-19.html` | `3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c` |
| **Approved Baseline Specification** | `backend/review/hdfc_official_baseline_2026-08-19.json` | `996f1f8b1393664d4715f530e1cbb372a6a6fa1e17df209b552fae8d47eb6fb6` |
| **Live Network Response Archive** | `backend/review/live-evidence/hdfc_live_response_2026-10-24.html` | `e4efbc695bbfaa3eabf77e9e43b2b18f24883574a1e822831c539a9dc9b69039` |
| **Structured Candidate Worksheet** | `backend/review/hdfc_batch_2_human_review.csv` | `0d2da06a86c62c2f9024f2b57b98ec3be6dbeaa64273060fc1887e5b222f778c` |

**Verification Status:**
- All 19 slabs and 38 candidate rate records match the live official HDFC web schedule with **0 mismatches**.
- Effective date confirmed as `2026-08-19` across raw HTML, baseline JSON, and live response headers.

---

## 2. Reviewer Instructions & Regulatory Mandates

> [!IMPORTANT]
> **Human Reviewer Decision Mandate:**  
> This packet provides verified technical and cryptographic evidence. Automated tools are strictly prohibited from populating reviewer decisions. Every candidate in this batch requires independent human examination.
>
> **Permitted Review Actions:**
> - **`APPROVED`**: Rate, tenure boundaries, and eligibility constraints match bank terms. Candidate may be authorized for staging.
> - **`REJECTED`**: Rate or terms do not match official rate card. Candidate discarded.
> - **`HOLD`**: Review deferred pending clarification (e.g., table ambiguity or policy query). Candidate remains locked in `REVIEW_REQUIRED`.

### Mandatory Regulatory & Source Conditions:
1. **Resident Indian Restriction for Senior Citizen Rates:**
   - Bank terms explicitly state: *"The Senior Citizen Rates are only for Resident Indians and do not apply to NRIs."*
   - Senior citizen candidates (`REV_018`, `REV_020`, ..., `REV_054`) are legally restricted to Resident Indian individuals aged 60 and above.
2. **NRE Fixed Deposit Tenure Floor (1 Year Minimum):**
   - Bank terms explicitly state: *"The Minimum tenure for earning the interest on NRE Fixed Deposit is 1 year. No Interest will be paid if the NRE Deposit is prematurely withdrawn before 1 year."*
   - **Sub-One-Year Prohibition:** Slabs 1 through 8 (`7 days` to `< 1 Year`) cannot be offered or booked as NRE deposits.
3. **Card-Rate Senior Spread Architecture:**
   - **Slab 16 (`3 Years 1 day to < 4 Years 7 Months`):** Published rates are Regular **6.50%**, Senior Citizen **7.10%** (+60 bps spread). This is part of standard card rates, not an unannounced special scheme.
   - **Slab 17 (`4 Year 7 Months (55 months)`):** Published rates are Regular **6.40%**, Senior Citizen **6.90%** (+50 bps spread).
   - **Clarification on Discredited 7.20% / 7.80% Values:** These figures do not appear in any published HDFC domestic retail schedule. They originated from early narrative drafting conflating non-retail or third-party reports. The true published rates are 6.40% / 6.90%.
4. **Tenure Domain Definitions:**
   - Slabs 1–5: `DAYS` domain (`[7, 14]`, `[15, 29]`, `[30, 45]`, `[46, 60]`, `[61, 89]`).
   - Slab 6: Bridging slab (`90 days <= 6 months`).
   - Slabs 7–19: `CALENDAR` domain (`6 months 1 day` through `10 Years`). Calendar tuple matching is authoritative.

---

## 3. Candidate Review Table (38 Candidates Across 19 Slabs)

| Review ID | Slab # | Tenure Label | Customer Type | Canonical Boundaries | Published Rate | Senior Spread | Reviewer Decision | Reviewer Initials | Date |
|:---:|:---:|:---|:---:|:---|:---:|:---:|:---:|:---:|:---:|
| `REV_017` | 1 | `7 - 14 days` | `REGULAR` | `[7 days, 14 days]` | `2.75%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |
| `REV_018` | 1 | `7 - 14 days` | `SENIOR_CITIZEN` | `[7 days, 14 days]` | `3.25%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_019` | 2 | `15-29 days` | `REGULAR` | `[15 days, 29 days]` | `2.75%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_020` | 2 | `15-29 days` | `SENIOR_CITIZEN` | `[15 days, 29 days]` | `3.25%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_021` | 3 | `30-45 days` | `REGULAR` | `[30 days, 45 days]` | `3.25%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_022` | 3 | `30-45 days` | `SENIOR_CITIZEN` | `[30 days, 45 days]` | `3.75%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_023` | 4 | `46-60 days` | `REGULAR` | `[46 days, 60 days]` | `4.25%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_024` | 4 | `46-60 days` | `SENIOR_CITIZEN` | `[46 days, 60 days]` | `4.75%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_025` | 5 | `61-89 days` | `REGULAR` | `[61 days, 89 days]` | `4.25%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_026` | 5 | `61-89 days` | `SENIOR_CITIZEN` | `[61 days, 89 days]` | `4.75%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_027` | 6 | `90 days <= 6 months` | `REGULAR` | `[90 days, 6 months]` | `4.25%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_028` | 6 | `90 days <= 6 months` | `SENIOR_CITIZEN` | `[90 days, 6 months]` | `4.75%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_029` | 7 | `6 months 1 day <=9 months` | `REGULAR` | `[6m 1d, 9m]` | `5.50%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_030` | 7 | `6 months 1 day <=9 months` | `SENIOR_CITIZEN` | `[6m 1d, 9m]` | `6.00%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_031` | 8 | `9 months 1 day to < 1 Year` | `REGULAR` | `[9m 1d, 1y)` | `5.75%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_032` | 8 | `9 months 1 day to < 1 Year` | `SENIOR_CITIZEN` | `[9m 1d, 1y)` | `6.25%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_033` | 9 | `1 Year to < 15 months` | `REGULAR` | `[1y, 15m)` | `6.25%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_034` | 9 | `1 Year to < 15 months` | `SENIOR_CITIZEN` | `[1y, 15m)` | `6.75%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_035` | 10 | `15 months to < 18 months` | `REGULAR` | `[15m, 18m)` | `6.35%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_036` | 10 | `15 months to < 18 months` | `SENIOR_CITIZEN` | `[15m, 18m)` | `6.85%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_037` | 11 | `18 months to < 21 months` | `REGULAR` | `[18m, 21m)` | `6.45%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_038` | 11 | `18 months to < 21 months` | `SENIOR_CITIZEN` | `[18m, 21m)` | `6.95%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_039` | 12 | `21 months to 2 years` | `REGULAR` | `[21m, 2y]` | `6.45%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_040` | 12 | `21 months to 2 years` | `SENIOR_CITIZEN` | `[21m, 2y]` | `6.95%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_041` | 13 | `2 Years 1 day to < 2 Year 11 Months` | `REGULAR` | `[2y 1d, 35m)` | `6.45%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_042` | 13 | `2 Years 1 day to < 2 Year 11 Months` | `SENIOR_CITIZEN` | `[2y 1d, 35m)` | `6.95%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_043` | 14 | `2 Years 11 Months (35 months)` | `REGULAR` | `[35m, 35m]` | `6.45%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_044` | 14 | `2 Years 11 Months (35 months)` | `SENIOR_CITIZEN` | `[35m, 35m]` | `6.95%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_045` | 15 | `2 Years 11 Months 1 day <= 3 Year` | `REGULAR` | `[35m 1d, 3y]` | `6.45%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_046` | 15 | `2 Years 11 Months 1 day <= 3 Year` | `SENIOR_CITIZEN` | `[35m 1d, 3y]` | `6.95%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_047` | 16 | `3 Years 1 day to < 4 Years 7 Months` | `REGULAR` | `[3y 1d, 55m)` | `6.50%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_048` | 16 | `3 Years 1 day to < 4 Years 7 Months` | `SENIOR_CITIZEN` | `[3y 1d, 55m)` | `7.10%` | `+60 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_049` | 17 | `4 Year 7 Months (55 months)` | `REGULAR` | `[55m, 55m]` | `6.40%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_050` | 17 | `4 Year 7 Months (55 months)` | `SENIOR_CITIZEN` | `[55m, 55m]` | `6.90%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_051` | 18 | `4 Year 7 Months 1 day <=5 Years` | `REGULAR` | `[55m 1d, 5y]` | `6.40%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_052` | 18 | `4 Year 7 Months 1 day <=5 Years` | `SENIOR_CITIZEN` | `[55m 1d, 5y]` | `6.90%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_053` | 19 | `5 Years 1 day to 10 Years` | `REGULAR` | `[5y 1d, 10y]` | `6.15%` | — | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |
| `REV_054` | 19 | `5 Years 1 day to 10 Years` | `SENIOR_CITIZEN` | `[5y 1d, 10y]` | `6.65%` | `+50 bps` | `[ ] App &nbsp; [ ] Rej &nbsp; [ ] Hold` | | |

---

## 4. Reviewer Execution Sign-Off (To Be Completed by Human Reviewer)

> *Notice: By signing below, the reviewer certifies that every candidate rate above was verified against the official bank rate schedule published at the stated source URL, and that the eligibility constraints (Resident Indian requirement for seniors, 1-year floor for NRE) have been noted.*

- **Reviewer Full Legal Name:** _____________________________________________
- **Reviewer Role / Title:** _____________________________________________
- **Organization / Team:** _____________________________________________
- **Review Date:** ________________________ (YYYY-MM-DD)
- **Batch Final Determination:** `[ ] APPROVED FOR STAGING` &nbsp;&nbsp; `[ ] REJECTED` &nbsp;&nbsp; `[ ] RETURNED FOR REMEDIATION`
- **Reviewer Signature:** _____________________________________________
- **Notes / Observations:**
