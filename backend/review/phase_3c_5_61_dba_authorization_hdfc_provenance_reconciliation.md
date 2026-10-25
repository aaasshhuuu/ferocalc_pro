# FeroCalc Phase 3C.5.61 — DBA Authorization & HDFC Provenance Reconciliation

**Audit timestamp:** 2026-10-25 16:08 IST  
**Target environment:** Supabase staging project `cqrslxngpwbtkjejlwty` only  
**Production ref:** `pmaykclwuyspxhgeomee` — prohibited and not queried  
**Repository branch:** `sync/latest-local-changes-2026-10-23`  
**Mode:** Read-only staging audit plus repository evidence note; no database mutations in this phase

## 1. Executive determination

- **Formal DBA/operator authorization: NOT EVIDENCED / STILL OPEN.** The recorded authorization packet has blank DBA/operator legal name, role, signature, and authorization timestamp. The DBA-observed precheck, backup/rehearsal, and execution-window fields are also blank. No identity or signature is inferred or manufactured in this report.
- **Migration 017 is already reflected in the staging database.** The staging migration ledger contains version `20261025100101` (`calendar_aware_candidate_staging_017`), and both replacement domain-specific indexes are present. This is an observed database state, not proof of a completed DBA sign-off.
- **The audit history is inconsistent.** The migration SQL body recorded in the ledger still contains the header `STATUS: DRAFT / NOT EXECUTED — DO NOT APPLY WITHOUT EXPLICIT OPERATOR AUTHORIZATION`, while the ledger records the migration and the catalog shows its objects. The previously prepared formal packet also has blank operator sign-off. Preserve this as an audit exception; do not rewrite the packet as if prior authorization had been signed.
- **HDFC Batch 2 remains staging-only.** 38 rows exist as `DRAFT`, all 38 `VALID`, 19 REGULAR and 19 SENIOR_CITIZEN, with 10 DAYS and 28 CALENDAR rows, 38 distinct review IDs, zero flagged rows, and all 38 carrying the expected candidate source hash. No promotion to VERIFIED was performed.
- **No production project was queried or changed.** No additional staging write or schema change was performed during this audit.

## 2. Direct staging read-only observations

Checked at `2026-10-25T10:35:32.510648Z` (`2026-10-25 16:05:32 IST`):

| Check | Observed result |
|---|---|
| Database | `postgres` |
| SQL execution role | `postgres` |
| PostgreSQL version | `17.6` |
| Migration 017 ledger entry | Present: `20261025100101` / `calendar_aware_candidate_staging_017` |
| Related security migration ledger entries | Present for `20261025095847`, `20261025100407`, `20261025100630`, `20261025100654` |
| HDFC Batch 2 total rows | 38 |
| DRAFT / VALID rows | 38 / 38 |
| REGULAR / SENIOR_CITIZEN | 19 / 19 |
| DAYS / CALENDAR | 10 / 28 |
| Distinct review IDs | 38 |
| Rows carrying expected `3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c` source hash in notes | 38 |
| Rows with validation errors or anomaly flags | 0 |
| Migration 017 replacement indexes | Both present |
| Global pipeline lock rows after the previous import | 0 |

The HDFC rows were inserted in the previously reported guarded, staging-only transaction. The Node.js `CandidateStagingService` / full scheduler was **not** invoked for that import. These facts should remain visible in the evidence trail; do not describe it as an end-to-end scheduler run.

## 3. DBA authorization status and required handling

The available packet records Owner approval for the *rate review* but leaves the *DBA/operator execution authorization* unsigned. Those are separate controls.

Because Migration 017 is already present on staging, the original **pre-migration** precheck cannot now be represented as having been performed before the migration. The correct next governance step is an independent DBA/operator review of the existing ledger, schema catalog, precheck evidence, backup/rehearsal records, and change history, followed by a truthful exception/authorization record. If the DBA determines that the change lacked required approval at execution time, record it as a change-control exception rather than backdating or fabricating a prior signature.

Do not reapply Migration 017, apply Migration 016, run further migrations, or promote candidates as a way to close this governance gap. No DBA identity, signature, approval timestamp, backup ID, or rehearsal result is supplied by the evidence reviewed here.

## 4. HDFC source-hash lineage reconciliation

The candidate source hash itself is consistent with the source snapshot identifier listed in the prior manifest, but the **baseline digest labels are inconsistent**:

| Evidence location | Recorded value | Meaning / finding |
|---|---|---|
| HDFC candidate worksheet `source_content_hash` | `3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c` | Candidate source hash; same value is identified as the normalized source snapshot digest in the prior evidence manifest |
| Reviewer packet, “Approved Baseline Specification” row | `996f1f8b1393664d4715f530e1cbb372a6a6fa1e17df209b552fae8d47eb6fb6` | Does not match the baseline JSON's internal `sourceReview.rawSnapshotSha256` value |
| Baseline JSON internal `sourceReview.rawSnapshotSha256` | `996f1f875b38cc4cc5b3c5ec8e8731caa579aab9c2017b35ece1acc2f4792bc6` | Different recorded value from the reviewer packet's baseline row |
| Prior manifest's file SHA-256 for `hdfc_official_baseline_2026-08-19.json` | `386beb6d0f2a8a747b7281745fd9d504103a0b7f70258050af423ef520920d59` | Yet another value, labelled as the baseline JSON file digest |
| Live-response artifact path | Packet: `hdfc_live_response_2026-10-24.html`; manifest: `hdfc-live-page.html` | Artifact path naming differs; the referenced artifacts were not retrievable at those paths from the reviewed branch |

These values can represent different hash types only when each is accurately labelled and recomputed from the corresponding bytes. The current records do not establish that reconciliation. Therefore this report **does not silently substitute** one digest for another and does not alter the already staged candidate rows.

### Required closure for source provenance

1. Retrieve the exact source-discovery snapshot, live-response archive, and baseline JSON bytes from the authorized evidence store.
2. Recompute SHA-256 separately for each file and distinguish file digest from an internal raw-source digest.
3. Correct the reviewer packet/manifest labels only after byte-level verification; retain the prior values in the audit history.
4. Re-run an integrity comparison between the verified worksheet and the approved source baseline. Until then, rate content remains staging-only and must not be promoted.

## 5. Decision

**DBA authorization remains open; schema migration 017 is already applied in staging; HDFC Batch 2 remains 38/38 DRAFT and VALID.** The evidence note documents the discrepancy but is not itself DBA authorization and does not retroactively validate the migration's original approval chain.

No production access, promotion, merge, release, or further database mutation was performed in this phase.
