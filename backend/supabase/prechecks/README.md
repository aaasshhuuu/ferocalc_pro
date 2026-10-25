# FeroCalc Supabase Precheck Suite (Read-Only)

This directory contains standalone, 100% read-only SQL precheck and verification scripts for staging database migrations.

## Strict Safety Guarantees

1. **Read-Only Inspection:**  
   Every query in this directory is strictly a `SELECT` statement. Zero `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, `TRUNCATE`, `GRANT`, `REVOKE`, or state-mutating calls exist.

2. **Target Isolation:**  
   - Authorized Target: **Staging only** (`cqrslxngpwbtkjejlwty`)
   - Strictly Prohibited: **Production** (`pmaykclwuyspxhgeomee`)

3. **Stop-and-Inspect Rule:**  
   If any query returns results diverging from the annotated "Expected" criteria, the operator must **STOP IMMEDIATELY**. Do not proceed with migration execution.

---

## Migration 017 Precheck & Verification Scripts

### 1. Pre-Migration Precheck
- **Script:** `017_staging_pre_migration_precheck.sql`
- **Execution Timing:** Immediately before Migration 017 is applied.
- **Scope:** Evaluates the baseline schema (Migration 015 state). Uses only columns present before Migration 017.
- **Key Verifications:**
  - Database environment & target project.
  - Prerequisite enums (`boundary_op`, `tenure_domain`, `rate_category`, etc.).
  - Absence of calendar columns (detects drift or partial migration).
  - Absence of name collisions for replacement indexes.
  - Active candidate duplicate detection using baseline columns only.
  - Verification that existing rows meet legacy day-bound rules.

### 2. Post-Migration Verification
- **Script:** `017_staging_post_migration_verification.sql`
- **Execution Timing:** Immediately after Migration 017 has committed.
- **Scope:** Verifies that Migration 017 applied cleanly and completely.
- **Key Verifications:**
  - All 9 dual-domain calendar columns exist with correct types and default `tenure_domain = 'DAYS'`.
  - Day columns nullability relaxed (`is_nullable = 'YES'`).
  - Legacy day-only constraints dropped.
  - All 12 domain check constraints present.
  - Legacy index `idx_staged_candidates_active_identity` dropped.
  - Both domain partial unique indexes present (`idx_staged_candidates_active_days_identity` and `idx_staged_candidates_active_calendar_identity`).
  - Zero active duplicates across DAYS and CALENDAR domains independently.
  - Domain integrity assertion across all existing records.

---

## Historical / Superseded Scripts
- `016_staging_precheck.sql`: Legacy precheck for superseded Migration 016. Maintained for historical auditability only.
