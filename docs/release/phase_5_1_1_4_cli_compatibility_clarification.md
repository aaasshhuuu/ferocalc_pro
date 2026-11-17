# FeroCalc — Phase 5.1.1.4: Supabase CLI Version Compatibility Clarification Report

**Document Version:** 1.0.0
**Execution Timestamp:** November 13, 2026
**Execution Environment:** `C:\projects\fincalc_pro_staging_prep`
**Git Working Branch:** `staging/vercel-backend-preview`
**Scope:** Supabase CLI version compatibility resolution, empirical invocation verification, documentation reconciliation, and release standard definition
**Final Milestone Verdict:** **`CLI VERSION COMPATIBILITY CLARIFIED — OWNER EXECUTION REQUIRED`**

---

## 1. Executive Summary & Objective Realization

This clarification report formally resolves the apparent discrepancy identified between Phase 5.1.1.3's Supabase CLI flag testing and official Supabase CLI v3 documentation.

### The Discrepancy:
In Phase 5.1.1.3, testing indicated that `--remote` was rejected with:
```json
{"_tag":"Error","error":{"code":"UnrecognizedOption","message":"Unrecognized flag: --remote in command supabase migration repair"}}
```
The report previously stated that both Supabase CLI `v2.122.0` and `v3.1.0` rejected `--remote`, mandating `--linked`. However, official Supabase CLI v3 documentation states that `--remote` is the standard target flag for remote projects, while `--linked` is deprecated compatibility syntax.

### The Findings & Resolution:
1. **No Global CLI on PATH:** There is no global `supabase` executable installed on the Windows system PATH (`where.exe supabase` returns not found).
2. **Project-Local CLI v2.122.0 in `backend/`:** `backend/package.json` pins `"supabase": "^2.122.0"`. When `npx supabase` is executed inside `backend/`, `npx` resolves to `backend/node_modules/supabase` (v2.122.0). In Supabase CLI v2.122.x, `--remote` **does not exist**; the valid, verified flag for linked projects is strictly `--linked` (or `--project-ref`).
3. **NPX Cache CLI v3.1.0 at Repository Root:** When `npx supabase` is executed outside `backend/` (such as at the repository root `C:\projects\fincalc_pro_staging_prep`), there is no local `package.json` or `node_modules`. Consequently, `npx` invokes the latest cached version `supabase@3.1.0` from the user's npm cache (`AppData/Local/npm-cache/_npx/...`). In Supabase CLI v3.1.0, `--remote` **is the primary, preferred target flag** (`--remote` for linked project, or `--remote=<ref|branch|url>`), while `--linked` is maintained as deprecated compatibility syntax.
4. **Root Cause of the Phase 5.1.1.3 Statement:** Phase 5.1.1.3 executed its flag test inside `backend/`, which resolved to the local `v2.122.0` binary. The rejection of `--remote` was an authentic output of CLI `v2.122.0`, but was erroneously attributed to CLI `v3.1.0` as well. CLI v3 does **not** reject `--remote`.
5. **Runbook Default Retained:** Because `backend/package.json` pins `supabase@^2.122.0`, any operator executing `npx supabase ...` inside `backend/` invokes CLI v2.122.0. Therefore, the project-local `npx` v2 workflow using `--linked` remains the default runbook standard, while dual-syntax documentation has been added to support operators using CLI v3.x.

---

## 2. Complete Empirical Verification Records

All required checks were executed on November 13, 2026, from both the repository root and the `backend/` directory.

### 2.1 Repository Root (`C:\projects\fincalc_pro_staging_prep`)

#### Check 1: `where.exe supabase`
```powershell
where.exe supabase
# Output:
INFO: Could not find files for the given pattern(s).
```
*Verdict:* No `supabase` binary is present on the Windows system PATH.

#### Check 2: `supabase --version`
```powershell
supabase --version
# Output:
supabase : The term 'supabase' is not recognized as the name of a cmdlet, function, script file, or operable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```
*Verdict:* Direct CLI invocation fails because `supabase` is not globally installed.

#### Check 3: `supabase migration repair --help`
```powershell
supabase migration repair --help
# Output:
supabase : The term 'supabase' is not recognized as the name of a cmdlet, function, script file, or operable program.
```
*Verdict:* Direct command unavailable.

#### Check 4: `npx supabase --version`
```powershell
npx supabase --version
# Output:
3.1.0
```
*Verdict:* Invokes npm-cached latest package `supabase@3.1.0`.

#### Check 5: `npx supabase migration repair --help`
```powershell
npx supabase migration repair --help
# Output:
DESCRIPTION
  Repair the migration history table.

TARGET
  Local by default. Pass --remote for the linked project, or --remote=<ref|branch|url>.

USAGE
  supabase migration repair [flags] [<version...>]

ARGUMENTS
  version... string    Migration version(s) to repair. (optional)

FLAGS
  --status choice                Version status to update. (choices: applied, reverted)
  --remote[=<ref|branch|url>]    Target a remote database: the linked project, or --remote=<ref|branch|url>.
  --password, -p string          Database password for the project selected with --remote. Not used for the local database or a database URL.

GLOBAL FLAGS
  --help, -h                                                          Show help information
  --version, -v                                                       Show version information
  --wizard                                                            Start wizard mode for a command
  --completions <bash|zsh|fish|sh>                                    Print shell completion script (choices: bash, zsh, fish, sh)
  --log-level <all|trace|debug|info|warn|warning|error|fatal|none>    Sets the minimum log level (choices: all, trace, debug, info, warn, warning, error, fatal, none)
  --output-format choice                                              Output format: text (default), json, or stream-json (NDJSON) (choices: text, json, stream-json)
  --output, -o choice                                                 output format of status variables (choices: env, pretty, json, toml, yaml, table, csv)
  --profile string                                                    use a specific profile for connecting to Supabase API
  --debug                                                             output debug logs to stderr
  --workdir string                                                    path to the directory containing your supabase/ folder; used exactly as given, with no ancestor directory search (defaults to searching upward from the current directory)
  --experimental                                                      enable experimental features
  --network-id string                                                 use the specified docker network instead of a generated one
  --yes                                                               answer yes to all prompts; hosted changes only accept this flag or SUPABASE_YES exported in your shell, never supabase/.env or another .env file
  --dns-resolver choice                                               lookup domain names using the specified resolver (choices: native, https)
  --agent choice                                                      Override agent detection: yes, no, or auto (default auto) (choices: auto, yes, no)

PERMISSIONS
  Scoped access token:
    May be required (with --remote, without --password):
      database_write
    May be required (with --remote):
      database_pooling_config_read
      projects_read
    May be required:
      branching_development_read for a preview branch
        or branching_production_read for the main branch
    Optional, with --remote, without --password (command still runs without these):
      database_network_bans_read
      database_network_bans_write
    Optional, with --remote (command still runs without these):
      project_admin_read
```
*Verdict:* Under Supabase CLI v3.1.0, `--remote` is explicitly documented under `TARGET` and `FLAGS` as the official flag to target a remote database.

---

### 2.2 Backend Directory (`C:\projects\fincalc_pro_staging_prep\backend`)

#### Check 1: `where.exe supabase`
```powershell
where.exe supabase
# Output:
INFO: Could not find files for the given pattern(s).
```

#### Check 2: `supabase --version`
```powershell
supabase --version
# Output:
supabase : The term 'supabase' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

#### Check 3: `supabase migration repair --help`
```powershell
supabase migration repair --help
# Output:
supabase : The term 'supabase' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

#### Check 4: `npx supabase --version`
```powershell
npx supabase --version
# Output:
2.122.0
A new version of Supabase CLI is available: v3.1.0 (currently installed v2.122.0)
We recommend updating regularly for new features and bug fixes: https://supabase.com/docs/guides/cli/getting-started#updating-the-supabase-cli
```
*Verdict:* Invokes project-local dependency `supabase@2.122.0` from `backend/node_modules/`.

#### Check 5: `npx supabase migration repair --help`
```powershell
npx supabase migration repair --help
# Output:
DESCRIPTION
  Repair the migration history table.

USAGE
  supabase migration repair [flags] [<version...>]

ARGUMENTS
  version... string    Migration version(s) to repair. (optional)

FLAGS
  --status choice          Version status to update. (choices: applied, reverted)
  --db-url string          Repairs migrations of the database specified by the connection string (must be percent-encoded).
  --linked                 Repairs the migration history of the linked project.
  --local                  Repairs the migration history of the local database.
  --project-ref string     Project ref of the Supabase project.
  --password, -p string    Password to your remote Postgres database.

GLOBAL FLAGS
  --help, -h                                                          Show help information
  --version, -v                                                       Show version information
  --wizard                                                            Start wizard mode for a command
  --completions <bash|zsh|fish|sh>                                    Print shell completion script (choices: bash, zsh, fish, sh)
  --log-level <all|trace|debug|info|warn|warning|error|fatal|none>    Sets the minimum log level (choices: all, trace, debug, info, warn, warning, error, fatal, none)
  --output-format choice                                              Output format: text (default), json, or stream-json (NDJSON) (choices: text, json, stream-json)
  --output, -o choice                                                 output format of status variables (choices: env, pretty, json, toml, yaml, table, csv)
  --profile string                                                    use a specific profile for connecting to Supabase API
  --debug                                                             output debug logs to stderr
  --workdir string                                                    path to the directory containing your supabase/ folder; used exactly as given, with no ancestor directory search (defaults to searching upward from the current directory)
  --experimental                                                      enable experimental features
  --network-id string                                                 use the specified docker network instead of a generated one
  --yes                                                               answer yes to all prompts
  --dns-resolver choice                                               lookup domain names using the specified resolver (choices: native, https)
  --create-ticket                                                     create a support ticket for any CLI error
  --agent choice                                                      Override agent detection: yes, no, or auto (default auto) (choices: auto, yes, no)

PERMISSIONS
  Not needed with --local or --db-url.
  Scoped access token:
    May be required (without --password):
      database_write
    May be required (with --project-ref):
      database_pooling_config_read
    Optional (command still runs without these):
      project_admin_read
    Optional, without --password (command still runs without these):
      database_network_bans_read
      database_network_bans_write
A new version of Supabase CLI is available: v3.1.0 (currently installed v2.122.0)
We recommend updating regularly for new features and bug fixes: https://supabase.com/docs/guides/cli/getting-started#updating-the-supabase-cli
```
*Verdict:* Under Supabase CLI v2.122.0, `--linked` is the official flag to repair the linked project. `--remote` is completely absent from the flag definitions.

---

## 3. Exact Executable & Package Resolution Mapping

The table below maps the exact executables, packages, and resolution paths for each execution context:

| Context | Command | Resolved Package | Package Version | Underlying Binary Executable Path | Resolution Mechanism | Supported Remote Flag |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **System PATH** | `supabase` | None | N/A | None (Not Found) | Windows `%PATH%` environment variable search | None |
| **Repo Root** (`C:\projects\...`) | `npx supabase` | `supabase` + `@supabase/cli-windows-x64` | `3.1.0` | `C:\Users\kuldi\AppData\Local\npm-cache\_npx\aa8e5c70f9d8d161\node_modules\@supabase\cli-windows-x64\bin\supabase.exe` | npx global/user cache fallback (no local `node_modules` in root) | `--remote` (primary)<br>`--linked` (compat) |
| **Backend Dir** (`C:\projects\...\backend`) | `npx supabase` | `supabase` + `@supabase/cli-windows-x64` | `2.122.0` | `C:\projects\fincalc_pro_staging_prep\backend\node_modules\@supabase\cli-windows-x64\bin\supabase.exe` | Local `backend/node_modules/.bin/supabase.cmd` from `backend/package.json` | `--linked` (strictly required)<br>`--remote` (unrecognized) |

---

## 4. Architectural Comparison: Supabase CLI v2 vs v3 Target Flags

### 4.1 Supabase CLI v2 Architecture (`v2.122.x`)
- **Discrete Target Flags:** Commands targeting databases use discrete flags:
  - `--linked`: Targets the project currently linked via `supabase link`.
  - `--local`: Targets the local Docker-based Supabase development stack.
  - `--project-ref <id>`: Targets a remote project by explicit reference ID.
  - `--db-url <connstring>`: Targets a specific Postgres connection string.
- **Flag Evaluation:** Passing `--remote` to any CLI v2 command triggers:
  `{"_tag":"Error","error":{"code":"UnrecognizedOption","message":"Unrecognized flag: --remote"}}`.
- **Active Status in Repo:** This version is pinned in `backend/package.json` (`"supabase": "^2.122.0"`).

### 4.2 Supabase CLI v3 Architecture (`v3.1.x`)
- **Unified Remote Target Flag:** Commands targeting databases use `--remote` as a polymorphic flag:
  - `--remote`: Targets the linked project.
  - `--remote=<ref>`: Targets a specific remote project ref.
  - `--remote=<branch>`: Targets a preview or development branch.
  - `--remote=<url>`: Targets an arbitrary PostgreSQL URL.
  - Default (no flag): Targets the local database.
- **Backward Compatibility:** Flags like `--linked` and `--db-url` are maintained as deprecated compatibility syntax.
- **Official Documentation Alignment:** Official Supabase documentation for CLI v3 prescribes `--remote`.

---

## 5. Release Runbook Standard & Execution Recommendations

### 5.1 Project-Local `npx` v2 Workflow Kept as Runbook Default
The release runbook (`docs/release/final_production_deployment_runbook.md`) and owner checklist (`docs/release/final_owner_action_checklist.md`) mandate executing commands inside `backend/`:

```bash
cd C:\projects\fincalc_pro_staging_prep\backend
```

Because `backend/package.json` pins `supabase@^2.122.0`, running `npx supabase` inside `backend/` always invokes the local `v2.122.0` binary. If the runbook instructed the owner to run `--remote` inside `backend/`, the command would fail with `Unrecognized flag: --remote`.

Therefore:
- **Default Syntax (CLI v2.122.x in `backend/`):**
  ```bash
  npx supabase migration repair --status applied <versions...> --linked
  npx supabase migration list --linked
  ```

### 5.2 Supported CLI v3 Workflow (Optional Upgrade / Global CLI)
If the project owner upgrades `backend/package.json` to Supabase CLI v3 or runs CLI v3 from outside `backend/`, the officially preferred syntax is:

```bash
npx supabase migration repair --status applied <versions...> --remote
npx supabase migration list --remote
```

Both alternatives are now explicitly documented in the runbook.

---

## 6. Documentation Reconciliation Audit

The following authoritative documents in `docs/release/` were reconciled:

| Document | Modification Summary | Sections |
| :--- | :--- | :--- |
| `docs/release/final_production_deployment_runbook.md` | Updated version to 1.2.1. Updated Step A.3 Note to explain the exact distinction between project-local CLI v2.122.x (`--linked`) and CLI v3.x (`--remote`). Annotated `migration list` and hard gate verification steps with CLI v3 equivalents while keeping project-local `--linked` as the default. | Sections 3.1, 3.2 |
| `docs/release/phase_5_1_1_3_migration_execution_safety_report.md` | Reconciled Section 1 (Item 2) and Section 5.1 to clarify that empirical rejection of `--remote` occurred under project-local CLI v2.122.0 in `backend/`, correcting the inadvertent generalization to CLI v3.1.0. Referenced Phase 5.1.1.4 for full cross-version details. | Sections 1, 5.1 |
| `docs/release/phase_5_1_1_4_cli_compatibility_clarification.md` | Created authoritative clarification report documenting all empirical checks, executable resolution paths, architectural flag comparisons, and governance compliance. | Entire Document |

---

## 7. Governance, Strict Boundaries & Compliance Verification

| Constraint / Boundary | Compliance Evidence |
| :--- | :--- |
| **Help/version checks only; do not run migration repair** | **PASS.** Executed only `--version`, `--help`, and `where.exe` checks. Zero migration repairs were initiated. |
| **Do not connect to staging or production databases** | **PASS.** Zero network connections were made to any database. |
| **Absolutely no production access** | **PASS.** Zero access, requests, or queries to production project `pmaykclwuyspxhgeomee`. |
| **Do not modify migration SQL or application code** | **PASS.** No files in `backend/supabase/migrations/` or application code were modified. |
| **Preserve all existing files and changes** | **PASS.** All existing unstaged and untracked changes across the working tree were preserved intact. |
| **No Git commits, pushes, resets or cleanup** | **PASS.** Zero git mutations performed. Working copy branch and status unchanged. |

---

## 8. Final Milestone Verdict

**`CLI VERSION COMPATIBILITY CLARIFIED — OWNER EXECUTION REQUIRED`**

The discrepancy between Phase 5.1.1.3's flag testing and official Supabase CLI v3 documentation is fully explained and resolved:
1. Supabase CLI v2.122.x (installed project-locally in `backend/`) strictly requires `--linked` and rejects `--remote`.
2. Supabase CLI v3.x (evaluated from npm cache at repo root) prefers `--remote` and maintains `--linked` as deprecated compatibility syntax.
3. The release runbook retains the project-local `npx` v2 workflow using `--linked` as its primary tested default, with full documented support for CLI v3's `--remote`.
4. Production migration execution remains gated exclusively on Project Owner manual authorization.
