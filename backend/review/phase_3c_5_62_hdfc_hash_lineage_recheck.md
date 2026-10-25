# FeroCalc Phase 3C.5.62 — HDFC Artifact Hash Recheck & DBA Gate Status

**Date:** 2026-10-25  
**Target environment:** Supabase staging project `cqrslxngpwbtkjejlwty` only  
**Production project:** `pmaykclwuyspxhgeomee` — not accessed  
**Repository ref checked:** `sync/latest-local-changes-2026-10-23`  
**Mode:** Read-only database verification plus repository evidence note. No database mutations in this phase.

## 1. Summary

- The HDFC batch remains **38/38 DRAFT and VALID**, with zero promoted rows and zero validation/anomaly flags.
- The official baseline JSON file digest was recomputed from its current repository bytes and **matches** the prior evidence manifest's file SHA-256: `386beb6d0f2a8a747b7281745fd9d504103a0b7f70258050af423ef520920d59`.
- The reviewer packet contains a different digest for that baseline JSON, and its worksheet digest does not match the current worksheet bytes. The packet must not be treated as a current file-integrity manifest until corrected against the exact files.
- The source-discovery HTML and live-response HTML named in the packet were not retrievable from this repository ref. Their raw bytes were not available for rehashing; their source-level digest chain therefore remains **open**.
- **Formal DBA/operator authorization remains NOT EVIDENCED.** The authorization packet's DBA identity, role, signature, authorization timestamp, observed precheck, backup/rehearsal, and execution-window fields remain blank. Migration 017 and the related security migrations are already present in the staging migration ledger. This must remain an audit/change-control exception—not retroactively represented as pre-authorized.
- No production access, schema mutation, rate promotion, merge, deployment, or release occurred in this phase.

## 2. Recomputed repository file digests

SHA-256 was recalculated over the UTF-8 file contents returned for the named files at the checked repository ref.

| Artifact | Recomputed SHA-256 | Value previously recorded | Finding |
|---|---|---|---|
| `backend/review/hdfc_official_baseline_2026-08-19.json` | `386beb6d0f2a8a747b7281745fd9d504103a0b7f70258050af423ef520920d59` | Prior manifest: `386beb6d0f2a8a747b7281745fd9d504103a0b7f70258050af423ef520920d59` | Match |
| `backend/review/hdfc_official_baseline_2026-08-19.json` | Same file digest above | Reviewer packet's “Approved Baseline Specification” row: `996f1f8b1393664d4715f530e1cbb372a6a6fa1e17df209b552fae8d47eb6fb6` | Does not match the file digest |
| Baseline JSON internal field `sourceReview.rawSnapshotSha256` | `996f1f875b38cc4cc5b3c5ec8e8731caa579aab9c2017b35ece1acc2f4792bc6` | Reviewer packet baseline-row value above | These are separately labelled values; the packet value does not match the internal raw-snapshot value either |
| `backend/review/hdfc_batch_2_human_review.csv` | `e3157f2bb998b0a63f896541d23d9372ed5a5020cccdd3e3f5b8c917331ae57f` | Reviewer packet worksheet row: `ba908e5b310376224ee7ed369700c98f256ee6c94cf2a1b3be31c7257eb9f014` | Does not match the current worksheet file digest |
| `backend/review/hdfc_batch_2_reviewer_packet.md` | `7c126d5f9c9a272e097fc2de1e80596919a6afd37f20601e847020330cea1ea0` | No independent expected value available in the reviewed records | Recorded for traceability |

The candidate worksheet's `source_content_hash` value `3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c` is a source-artifact digest, **not** the worksheet file digest. A different file digest is expected when the digest types are correctly labelled. However, because the named source-discovery and live-response HTML files are absent at the referenced paths on this ref, the bytes needed to verify that source-artifact digest are still unavailable.

Repository paths checked and not retrievable at this ref:
- `backend/review/source-discovery/hdfc_domestic_retail_fd_rates_2026-08-19.html`
- `backend/review/live-evidence/hdfc_live_response_2026-10-24.html`
- Alternate path cited in the prior manifest: `backend/review/live-evidence/hdfc-live-page.html`

Do not silently replace the worksheet's source hash, the baseline JSON internal raw-snapshot hash, or the file digests. Obtain the exact archived files from the authorized evidence store, hash each byte-for-byte, then revise the packet/manifest with an auditable superseding version.

## 3. Current staging verification

Read-only query results from staging:

| Check | Observed result |
|---|---:|
| HDFC staged rows | 38 |
| `DRAFT` + `VALID` | 38 |
| Regular / Senior Citizen | 19 / 19 |
| DAYS / CALENDAR | 10 / 28 |
| Rows with expected `3fa74d2cb4eb9215d904b5209a1f9681bf6b075a1cf37e1eb125bf7cc6f8949c` in `source_content_hash` | 38 |
| Rows carrying that source hash in notes | 38 |
| Validation-error or anomaly-flagged rows | 0 |
| Promoted HDFC rows | 0 |
| Rows in `baseline_source_attestations` | 0 |
| Global pipeline-lock rows after import | 0 |

Migration ledger still lists:
- `20261025095847 restore_core_rls_policies_and_revoke_unsafe_ddl_privileges`
- `20261025100101 calendar_aware_candidate_staging_017`
- `20261025100407 restrict_public_views_to_read_only`
- `20261025100630 use_invoker_security_for_public_views`
- `20261025100654 harden_admin_rls_helper_and_bank_write_policies`

A catalog search did not find a dedicated DBA/operator authorization table or change-ticket table in the database. The match `auth.oauth_authorizations` is an OAuth table, not DBA approval evidence. Absence of a database table is not proof that no external change ticket exists; the reviewed formal authorization packet itself is unsigned.

## 4. DBA authorization and change-control handling

Rate-review approval by the product owner is separate from DBA/operator authorization for database changes. The current evidence does not contain a DBA/operator legal name, role, signature, or timestamp, nor evidence of the required pre-migration sign-off. The Phase 3C.5.61 staging migration report records that the 11 read-only prechecks were executed and succeeded before Migration 017. However, the formal packet's DBA-observed precheck/sign-off fields remain blank: execution of read-only queries is not the same as signed DBA authorization.

Required governance action is an independent DBA/operator review of the existing migration ledger, catalog state, the recorded pre-migration query results, backup/rehearsal records, and change history. Record the actual conclusion and sign-off truthfully, including a change-control exception if authorization was absent at execution time. Do not backdate authorization, fabricate backup evidence, reapply Migration 017, apply Migration 016, or promote this batch to close the gate.

## 5. Decision

**Hash lineage is partially reconciled; source archive verification is still blocked on unavailable source files. DBA authorization remains open. HDFC Batch 2 stays staging-only at 38/38 DRAFT and VALID.**

This report is an evidence update only. It is not DBA authorization and does not retroactively validate the migration's original approval chain.
