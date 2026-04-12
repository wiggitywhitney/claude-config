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

### Milestone 1: Script Skeleton and Settings Symlink
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

### Milestone 2: Memory File Restore
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Add the memory file restore step to `scripts/bootstrap.sh`.

**To implement:**
- Read memory files from `<claude-personal-dir>/memory/<project-name>/` (or whatever structure PRD #62 M1 decides)
- Write to `~/.claude/projects/<encoded-path>/memory/` — requires mapping logical project name back to the encoded directory name (this is the inverse of the push direction in PRD #62). **Path encoding rule (PRD #62 M4 decision):** encode `$HOME` via `sed 's|[^a-zA-Z0-9]|-|g'` — do NOT use `$(whoami)`, because macOS usernames can contain dots that Claude Code encodes as hyphens.
- Skip files that already exist and are identical (byte-for-byte); overwrite if different (repo is authoritative on restore)
- Print per-file status: restored / skipped (identical) / updated
- Write bats tests: fresh restore creates files, re-run with identical content skips, re-run with updated content in repo overwrites local; **include a test that uses the HOME-encoding approach and verifies the correct encoded path is produced**

**Success criteria:**
- Memory files land in the correct `~/.claude/projects/*/memory/` locations
- Idempotent — re-running with no repo changes touches nothing
- Tests pass

**Dependency**: PRD #62 M1 must be decided (memory directory naming convention) before implementing this milestone.

### Milestone 3: Git Hook Installation (Design Decision A)
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

### Milestone 5: End-to-End Test and Documentation
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Validate the full bootstrap flow and document the new-machine setup process.

**To implement:**
- Write an end-to-end bats test that: creates a temp `~/.claude/`-like directory, a temp repos directory with two fake git repos, a temp claude-personal with sample memory and settings files, runs `bootstrap.sh`, and asserts all outputs are in place
- Run `/write-docs` to produce a `docs/bootstrap.md` guide covering: prerequisites (clone claude-config and claude-personal), running bootstrap, what each step does, re-running after cloning more repos
- If a `README.md` exists at the repo root, add a "Getting Started on a New Machine" section that links to `docs/bootstrap.md`. If no README exists, the guide is sufficient — do not create a README just for this.

**Success criteria:**
- End-to-end test passes
- `docs/bootstrap.md` answers: "I just got a new laptop. How do I restore everything?"
- No manual steps required beyond cloning the two repos and running one command

## Decision Log

_(Decisions recorded here as they are made during implementation)_

## References

- [PRD #62: claude-personal backup repo](62-claude-personal-backup.md) — provides memory files and `settings.local.json` that bootstrap restores
- [scripts/install-git-hooks.sh](../scripts/install-git-hooks.sh) — hook installer called by M3
- [config/settings.json](../config/settings.json) — settings file that M1 symlinks into `~/.claude/`
