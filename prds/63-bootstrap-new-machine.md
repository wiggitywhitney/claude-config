# PRD #63: Bootstrap a New Machine

## Problem

Setting up a new laptop with a full Claude development environment currently requires remembering and executing a sequence of manual steps across multiple repos and config locations:
- Clone claude-config and claude-personal
- Symlink `~/.claude/settings.json` from claude-config
- Restore memory files and per-project `settings.local.json` from claude-personal
- Run `install-git-hooks.sh` in every active repo
- Clone all active repos (if not already there)

There is no script to do this. Steps get missed, done out of order, or forgotten entirely.

## Solution

An idempotent `scripts/bootstrap.sh` in claude-config that restores a full Claude development environment in a single run. The script coordinates between claude-config (hook logic, settings symlink) and claude-personal (memory files, `settings.local.json` backups). Running it on an already-configured machine is safe — it skips anything already in place.

## Key Design Decisions (Discuss at Implementation)

### Decision A: Repo Discovery for Hook Installation

How does bootstrap know which repos to install git hooks into?

- **Option A1: Hardcoded list** — a `config/repos.txt` file listing repo names. Simple, explicit, requires maintenance.
- **Option A2: Auto-discover `~/Documents/Repositories/`** — scan the directory and install into every git repo found. No maintenance, but installs into repos you may not want hooks in (forks, throwaway projects, etc.).
- **Recommended: Option A2 with opt-out** — auto-discover, but skip repos with a `.skip-git-hooks` dotfile at their root. Combines low-maintenance with explicit control.

**Flag for M3 discussion before implementation.**

### Decision B: settings.local.json Path Mapping on New Machine

`settings.local.json` files live inside project repos. The restore step needs to know where each project repo lives on the new machine. The backup in claude-personal stores these files keyed by project name (or path). On a new machine with the same directory layout, the paths are identical. On a machine with a different username or directory structure, they won't be.

Options:
- **B1: Assume same paths** — restore to hardcoded `~/Documents/Repositories/<name>/.claude/settings.local.json`. Works if the layout is consistent (it is for Whitney's machines). Fails silently if a repo hasn't been cloned yet.
- **B2: Restore only to repos that already exist** — check that `<repo>/.git` exists before restoring; skip and warn for repos not yet cloned. Safe and correct, slightly more complex.
- **Recommended: B2** — skip missing repos with a clear warning so the user knows to clone first.

**Flag for M4 discussion before implementation.**

### Decision C: Order of Operations

Bootstrap must run in this order:
1. Verify claude-personal is cloned and current
2. Create settings.json symlink (no deps)
3. Restore memory files (no deps)
4. Restore `settings.local.json` files (requires repos already cloned — see Decision B)
5. Install git hooks (requires repos already cloned)

Steps 4 and 5 may partially succeed on a fresh machine where not all repos are cloned yet. The script should complete the steps it can and print a clear summary of what was skipped, so the user can re-run after cloning the remaining repos.

## Success Criteria

- Running `scripts/bootstrap.sh` on a fresh machine with claude-config and claude-personal cloned restores all memory files, creates the settings symlink, and installs hooks in all discovered repos
- Running on an already-configured machine produces no errors and no unintended changes
- Skipped steps (repos not cloned yet) produce clear, actionable output
- All bats tests pass

## Milestones

### Milestone 1: Script Skeleton and Settings Symlink ✅
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Create `scripts/bootstrap.sh` with argument parsing, prerequisite checks, and the settings.json symlink step.

**To implement:**
- Script accepts `--dry-run` flag (prints what it would do without doing it) and `--claude-personal-dir <path>` (defaults to `~/Documents/Repositories/claude-personal`)
- The script must determine its own repo root: `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. Use this to construct the symlink target: `$REPO_ROOT/config/settings.json`.
- Prerequisite checks: claude-personal dir exists and is a git repo; `~/.claude/` exists
- Symlink step logic:
  - If `~/.claude/settings.json` is already a symlink pointing to `$REPO_ROOT/config/settings.json` → print `[SKIPPED] settings.json symlink already correct` and move on
  - If `~/.claude/settings.json` is a symlink pointing to any *other* path → back it up with `.pre-bootstrap-backup` suffix and replace it
  - If `~/.claude/settings.json` is a regular file → back it up with `.pre-bootstrap-backup` suffix and replace with symlink
  - If `~/.claude/settings.json` does not exist → create the symlink
- All steps use the same output format: `[OK]`, `[SKIPPED]`, or `[BACKED UP]`
- Write bats tests: dry-run produces no changes, symlink created on fresh setup, idempotent on re-run, non-symlink file is backed up not clobbered, wrong-target symlink is replaced

**Success criteria:**
- `--dry-run` output lists all planned actions without executing any
- Symlink step is idempotent
- Tests pass

### Milestone 2: Memory File Restore ✅
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Add the memory file restore step to `scripts/bootstrap.sh`.

**To implement:**
- Read memory files from `<claude-personal-dir>/memory/<project-name>/` (or whatever structure PRD #62 M1 decides)
- Write to `~/.claude/projects/<encoded-path>/memory/` — requires mapping logical project name back to the encoded directory name (this is the inverse of the push direction in PRD #62). **Path encoding rule (PRD #62 M4 decision):** encode `$HOME` via `sed 's|[/.]|-|g'` (replace slashes and dots only) — do NOT use `$(whoami)`, because macOS usernames with dots (e.g. `whitney.lee`) encode as hyphens in project paths. Do NOT use `[^a-zA-Z0-9]`; that is imprecise and would break project names containing hyphens on a round-trip if encoding were ever applied to names rather than just the home prefix.
- Skip files that already exist and are identical (byte-for-byte); overwrite if different (repo is authoritative on restore)
- Print per-file status: restored / skipped (identical) / updated
- Write bats tests: fresh restore creates files, re-run with identical content skips, re-run with updated content in repo overwrites local; **include a test that uses the HOME-encoding approach and verifies the correct encoded path is produced**

**Success criteria:**
- Memory files land in the correct `~/.claude/projects/*/memory/` locations
- Idempotent — re-running with no repo changes touches nothing
- Tests pass

**Dependency**: PRD #62 M1 must be decided (memory directory naming convention) before implementing this milestone.

### Milestone 3: Git Hook Installation (Design Decision A) ✅
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Add git hook installation to `scripts/bootstrap.sh`. **Read Decision A above, then present your implementation plan (which option you'd implement and why) and wait for Whitney to confirm before writing any code.**

**Decision A recap**: auto-discover repos under `~/Documents/Repositories/` and install hooks in all git repos found, skipping those with a `.skip-git-hooks` dotfile.

**To implement:**
- Find all git repos under `~/Documents/Repositories/` (one level deep — do not recurse into nested repos)
- For each repo: if `.skip-git-hooks` exists, skip with message; otherwise run `scripts/install-git-hooks.sh <repo-path>`
- `install-git-hooks.sh` is already idempotent — calling it again on a repo with hooks installed prints "already installed" and exits 0
- Write bats tests: hooks installed in discovered repo, repo with `.skip-git-hooks` is skipped, already-hooked repo is idempotent

**Success criteria:**
- All active repos get hooks installed in one bootstrap run
- Repos with `.skip-git-hooks` are skipped cleanly
- Tests pass

### Milestone 4: settings.local.json Restore (Design Decision B)
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Add per-project `settings.local.json` restore to `scripts/bootstrap.sh`. **Read Decision B above, then present your implementation plan and wait for Whitney to confirm before writing any code.**

**Decision B recap**: restore only to repos that already exist on disk; skip with a warning for repos not yet cloned.

**To implement:**
- Read `settings.local.json` files from `<claude-personal-dir>/local-settings/<project-name>/settings.local.json` (or equivalent structure from PRD #62)
- For each file: check if `~/Documents/Repositories/<project-name>/.git` exists; if not, print `[SKIPPED] <project-name> — repo not cloned yet`; if yes, write `settings.local.json` (skip if identical, overwrite if different)
- At end of script, if any repos were skipped, print: "Re-run bootstrap after cloning the above repos to restore their settings."
- Write bats tests: file restored when repo exists, skipped with message when repo absent, idempotent when content matches

**Success criteria:**
- `settings.local.json` restored for all present repos
- Missing repos produce clear skip messages, not errors
- Re-running after cloning a previously-missing repo fills in the gap
- Tests pass

**Dependency**: PRD #62 M2 must be complete (files committed to claude-personal) before this can be tested end-to-end.

### Milestone 5: Repo Sync Script

Add `scripts/sync-repos.sh` — a companion script that clones missing repos and pulls existing ones before bootstrap runs.

**Design decisions already made (see Decision Log):**
- Use `gh repo list` filtered by repos pushed within the last N months (Decision 1)
- `git pull --ff-only` for repos already present; warn and skip on failure (Decision 2)
- `--months N` flag (default 6), `--dry-run`, `--repos-dir` env var for testability (Decision 3)

**To implement:**
- Script accepts `--months N` (default 6), `--dry-run`, and `--repos-dir <path>` (defaults to `~/Documents/Repositories`)
- Use `gh repo list --json nameWithOwner,pushedAt --limit 1000` and filter to repos where `pushedAt` is within the last N months
- For each repo not present under `<repos-dir>/`: clone with `gh repo clone <nameWithOwner> <repos-dir>/<name>`
- For each repo already present: run `git -C <path> pull --ff-only`; if it fails (local changes or diverged), print `[SKIPPED] <repo> — local changes, run git pull manually` and continue
- Output format: `[OK] cloned <repo>`, `[OK] pulled <repo> (N commits)`, `[SKIPPED] <repo> — local changes`, `[SKIPPED] <repo> — not active in last N months`
- Write bats tests: clones missing repo, pulls existing repo, skips repo with local changes, skips repo outside N-month window, dry-run makes no changes

**Success criteria:**
- Running `sync-repos.sh` before `bootstrap.sh` on a fresh machine means bootstrap finds all repos already present
- Skipped repos produce clear, actionable messages
- Tests pass

### Milestone 6: End-to-End Test and Documentation
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Validate the full new-machine setup flow and document both scripts. (Updated per Decision 4: docs must cover `sync-repos.sh` and `bootstrap.sh` as a two-step flow, not bootstrap alone.)

**To implement:**
- Write an end-to-end bats test for `bootstrap.sh` that: creates a temp `~/.claude/`-like directory, a temp repos directory with two fake git repos, a temp claude-personal with sample memory and settings files, runs `bootstrap.sh`, and asserts all outputs are in place
- Write an end-to-end bats test for `sync-repos.sh` that: mocks `gh repo list` output, sets up a temp repos directory with one existing repo and one absent, runs `sync-repos.sh`, and asserts the correct clone/pull/skip behavior
- Run `/write-docs` to produce a `docs/new-machine-setup.md` guide covering: prerequisites (clone claude-config and claude-personal), step 1 (`sync-repos.sh` — clone/pull active repos), step 2 (`bootstrap.sh` — symlink, memory, hooks), re-running after cloning more repos, and what each flag does
- Update the existing README.md "Setup: Install on a New Machine" section to describe the two-step flow (`sync-repos.sh` then `bootstrap.sh`) and link to `docs/new-machine-setup.md`

**Success criteria:**
- Both end-to-end tests pass
- `docs/new-machine-setup.md` answers: "I just got a new laptop. How do I restore everything?"
- README documents `--months` flag and the two-step sequence
- No manual steps required beyond cloning claude-config and claude-personal and running two commands

## Decision Log

| # | Decision | Rationale | Impact |
|---|---|---|---|
| 1 | `sync-repos.sh` uses `gh repo list` filtered to repos active within last N months | Auto-discovery avoids maintaining a repo list; N-month window skips forks and archived projects | Determines which repos are cloned/pulled; window size is user-configurable via `--months` |
| 2 | `git pull --ff-only` for repos already present on disk; warn and skip on failure | Fast-forward-only prevents silent merge commits; skipping with a warning is safe when local work exists | Repos with local changes or diverged history are surfaced as warnings, not errors |
| 3 | `--months N` flag (default 6) rather than interactive prompt or hardcoded constant | Consistent with `bootstrap.sh`'s flag style; scriptable/automatable; default covers active projects without requiring configuration | `sync-repos.sh` is non-interactive and can run in pipelines; `--dry-run` and `--repos-dir` follow the same pattern |
| 4 | `sync-repos.sh` is M5 of PRD #63, not a separate issue | Scope fits the "bootstrap a new machine" problem; script is a prerequisite to `bootstrap.sh` and belongs in the same delivery | M6 (formerly M5) docs milestone must cover both scripts; README "Getting Started" section documents the two-step flow |

## References

- [PRD #62: claude-personal backup repo](62-claude-personal-backup.md) — provides memory files and `settings.local.json` that bootstrap restores
- [scripts/install-git-hooks.sh](../scripts/install-git-hooks.sh) — hook installer called by M3
- [config/settings.json](../config/settings.json) — settings file that M1 symlinks into `~/.claude/`
