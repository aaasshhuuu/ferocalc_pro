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
