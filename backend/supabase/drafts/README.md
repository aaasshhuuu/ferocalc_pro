# FeroCalc Supabase Migration Drafts (Execution Guard)

This directory contains unapplied, draft database migrations that are undergoing offline design, schema contract verification, and local rehearsal.

## Critical Operational Guardrails

1. **NEVER Execute Automatically:**
   Files in this directory MUST NEVER be executed automatically by CI/CD, deployment scripts, migration runners, or `supabase db push`.

2. **Authorization Prerequisite:**
   A migration draft remains in `backend/supabase/drafts/` until:
   - All human review sign-offs are completed (`REVIEW_REQUIRED` gate cleared).
   - Formal written staging authorization is issued by the system operator.
   - Preflight duplicate checks are executed against the target remote database with 0 duplicates found.

3. **Promotion to Executable Status:**
   Only after all prerequisites are satisfied may an operator copy the authorized `.sql` file into `backend/supabase/migrations/` with its assigned sequence number.

4. **Migration 016 Superseded Status:**
   Migration 016 (`016_add_staged_candidate_active_uniqueness.sql`) is **SUPERSEDED** by Migration 017 (`017_calendar_aware_candidate_staging.sql`). Migration 016 assumes single-domain day tenures and causes false collisions on dual-domain CALENDAR records where day bounds are NULL under `NULLS NOT DISTINCT`. It must remain quarantined as superseded and not be executed.

5. **Migration 017 Recovery & Rollback Safeguards:**
   - **Automatic Transactional Rollback (On Execution Failure):**
     Migration 017 executes inside a single `BEGIN ... COMMIT` block. If Step 2 (duplicate assertion), Step 6 (catalog verification assertion), or any constraint validation fails, PostgreSQL automatically rolls back the entire transaction. No manual database cleanup is required.
   - **Manual Recovery (Post-Commit):**
     - **Prefer Forward Fix:** If an issue arises after Migration 017 has committed, a forward fix or data-preserving path is strongly preferred over rolling back.
     - **Stop Routine Rollback if Calendar Rows Exist:** If any records with `tenure_domain = 'CALENDAR'` exist in `staged_rate_candidates`, routine rollback MUST STOP IMMEDIATELY. Dropping calendar columns permanently destroys calendar tenure data, and restoring `NOT NULL` on legacy day columns will fail on CALENDAR records.
     - **Prohibition on Automated Purges:** Under NO circumstances may an operator or automated script purge, delete, or discard candidate records merely to force a rollback. Any export, archive, delete, or restore requires a specific written recovery decision, a verified database backup, and an authorized DBA/operator.
     - **Prerequisites for Rollback When Calendar Rows are Absent:** If `SELECT count(*) FROM staged_rate_candidates WHERE tenure_domain = 'CALENDAR'` returns 0, rollback still requires:
       1. A verified pre-migration schema snapshot and recent full backup.
       2. Prior index inspection: Recreating `idx_staged_candidates_active_identity` is only permitted if it was verified present before Migration 017 (as recorded by Check 6 of `017_staging_pre_migration_precheck.sql`).
