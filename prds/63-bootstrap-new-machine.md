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

Three companion scripts that together restore a full Claude development environment when switching to a new machine:

1. **`scripts/backup-private-files.sh`** — run on the *current* machine before switching; pushes per-repo gitignored files (`journal/`, `.claude/design-decisions.md`, and any repo-specific additions via `.private-sync`) into claude-personal
2. **`scripts/sync-repos.sh`** — run on the *new* machine first; clones missing repos and pulls existing ones using `gh repo list`
3. **`scripts/bootstrap.sh`** — run on the *new* machine after sync; restores the settings.json symlink, memory files, `settings.local.json`, private files, and git hooks across all discovered repos

All three scripts are idempotent — running them on an already-configured machine produces no errors and no unintended changes.

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
5. Restore private files from `private-files/` in claude-personal (requires repos already cloned — see M7)
6. Install git hooks (requires repos already cloned)

Steps 4 and 5 may partially succeed on a fresh machine where not all repos are cloned yet. The script should complete the steps it can and print a clear summary of what was skipped, so the user can re-run after cloning the remaining repos.

## Success Criteria

- Running `scripts/backup-private-files.sh` on the current machine pushes all per-repo private files (journal entries, design decisions, and any `.private-sync` additions) into claude-personal
- Running `scripts/sync-repos.sh` then `scripts/bootstrap.sh` on a fresh machine with claude-config and claude-personal cloned restores: the settings.json symlink, all memory files, all `settings.local.json` files, all private files, and git hooks in all discovered repos
- Running any script on an already-configured machine produces no errors and no unintended changes
- Skipped steps (repos not yet cloned) produce clear, actionable output and a re-run reminder
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

### Milestone 4: settings.local.json Restore (Design Decision B) ✅
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

### Milestone 5: Repo Sync Script ✅

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

**Updated per Decision 5: deferred until M7 is complete.** End-to-end tests and documentation must cover the full feature set — including `backup-private-files.sh` and the private-file restore step — so they are written once over everything rather than twice.

Validate the full new-machine setup flow and document all three scripts. (Updated per Decision 4: docs must cover `sync-repos.sh` and `bootstrap.sh` as a two-step flow, not bootstrap alone. Updated per Decision 5: docs must also cover `backup-private-files.sh` as a prerequisite step run on the old machine.)

**To implement:**
- Write an end-to-end bats test for `bootstrap.sh` that: creates a temp `~/.claude/`-like directory, a temp repos directory with two fake git repos, a temp claude-personal with sample memory, settings files, and private-files backup, runs `bootstrap.sh`, and asserts all outputs are in place (including restored private files)
- Write an end-to-end bats test for `sync-repos.sh` that: mocks `gh repo list` output, sets up a temp repos directory with one existing repo and one absent, runs `sync-repos.sh`, and asserts the correct clone/pull/skip behavior
- Write an end-to-end bats test for `backup-private-files.sh` that: sets up a temp repos directory with sample `journal/` and `.claude/design-decisions.md` files (and one repo with a `.private-sync` listing an extra path), runs the script, and asserts all expected files land in claude-personal
- Run `/write-docs` to produce a `docs/new-machine-setup.md` guide covering: prerequisites (clone claude-config and claude-personal), step 0 (`backup-private-files.sh` — run on old machine to push private files to claude-personal), step 1 (`sync-repos.sh` — clone/pull active repos on new machine), step 2 (`bootstrap.sh` — symlink, memory, hooks, private files), re-running after cloning more repos, and all flags: `--dry-run` (all three scripts), `--months N` (sync-repos.sh), `--repos-dir` (all three scripts), `--claude-personal-dir` (backup-private-files.sh and bootstrap.sh)
- Update the existing README.md "Setup: Install on a New Machine" section to describe the full flow and link to `docs/new-machine-setup.md`

**Success criteria:**
- All three end-to-end tests pass
- `docs/new-machine-setup.md` answers: "I just got a new laptop. How do I restore everything?"
- README documents the three-script sequence and key flags
- No manual steps required beyond cloning claude-config and claude-personal and running three commands

### Milestone 7: Private File Backup and Restore ✅
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

**Context:** Research confirmed that `prds/` directories are committed (not gitignored) in all active repos — they travel with the repo on clone and need no special handling. The gitignored items worth syncing are `journal/` (gitignored in 10+ repos) and `.claude/design-decisions.md` (gitignored in 5+ repos). See Decision 6, 7, 8.

**Implement two components in this order:**

**`scripts/backup-private-files.sh`** (run on current machine; pushes private files to claude-personal):
- Accepts `--dry-run`, `--repos-dir <path>` (defaults to `~/Documents/Repositories`), and `--claude-personal-dir <path>` (defaults to `~/Documents/Repositories/claude-personal`)
- For each repo under repos-dir:
  - Build sync list: hardcoded defaults (`journal/`, `.claude/design-decisions.md`) plus any paths listed in `.private-sync` at the repo root (one path per line; paths are relative to the repo root)
  - For each path in the sync list that exists in the repo:
    - If it is a directory: use `cp -r` to copy into claude-personal under `private-files/<repo-name>/<path>`, creating intermediate directories as needed
    - If it is a file: use `cp` to copy, creating intermediate directories as needed
  - Skip paths that do not exist in the repo with `[SKIPPED] <repo>/<path> — not found`
- If any files were copied: commit changes to claude-personal with message `chore: back up private files from <repo>`
- If nothing changed: exit silently (no commit, no output)
- Output format: `[OK] backed up <repo>/<path>`, `[SKIPPED] <repo>/<path> — not found`, `[DRY RUN] Would back up <repo>/<path>`
- Write bats tests: backs up `journal/` from repo, backs up `.claude/design-decisions.md`, reads additional paths from `.private-sync` (including a path that does not exist in the repo, which should be skipped), dry-run makes no changes, no-op when nothing to back up produces no output and no commit

**New restore step in `scripts/bootstrap.sh`** (run on new machine; pulls from claude-personal; this is step 5 in the order of operations from Decision C):
- For each repo directory under `<claude-personal-dir>/private-files/`:
  - If the repo is not cloned locally: print `[SKIPPED] <repo> — not cloned yet` and continue
  - If cloned: for each item (file or directory) in the backup:
    - If a directory: compare file-by-file; skip files that are byte-for-byte identical, restore files that are missing or different
    - If a file: skip if byte-for-byte identical; restore if missing or different
    - Print `[OK] restored <repo>/<path>` for new items, `[UPDATED] <repo>/<path>` for overwrites, `[SKIPPED] <repo>/<path> — identical` for unchanged
- At end of script, if any repos were skipped, print: "Re-run bootstrap after cloning the above repos to restore their private files."
- Write bats tests: restores `journal/` directory tree to cloned repo, restores `.claude/design-decisions.md` file to cloned repo, skips uncloned repo with message, idempotent when content matches, overwrites when content differs, prints re-run reminder when repos skipped, dry-run shows would-restore without writing

**Success criteria:**
- Running `backup-private-files.sh` on current machine captures all private files to claude-personal
- Running `bootstrap.sh` on a new machine restores them to the correct repos
- `.private-sync` additions are picked up in both backup and restore
- Tests pass

## Decision Log

| # | Decision | Rationale | Impact |
|---|---|---|---|
| 1 | `sync-repos.sh` uses `gh repo list` filtered to repos active within last N months | Auto-discovery avoids maintaining a repo list; N-month window skips forks and archived projects | Determines which repos are cloned/pulled; window size is user-configurable via `--months` |
| 2 | `git pull --ff-only` for repos already present on disk; warn and skip on failure | Fast-forward-only prevents silent merge commits; skipping with a warning is safe when local work exists | Repos with local changes or diverged history are surfaced as warnings, not errors |
| 3 | `--months N` flag (default 6) rather than interactive prompt or hardcoded constant | Consistent with `bootstrap.sh`'s flag style; scriptable/automatable; default covers active projects without requiring configuration | `sync-repos.sh` is non-interactive and can run in pipelines; `--dry-run` and `--repos-dir` follow the same pattern |
| 4 | `sync-repos.sh` is M5 of PRD #63, not a separate issue | Scope fits the "bootstrap a new machine" problem; script is a prerequisite to `bootstrap.sh` and belongs in the same delivery | M6 (formerly M5) docs milestone must cover both scripts; README "Getting Started" section documents the two-step flow |
| 5 | Defer M6 (end-to-end tests + docs) until M7 is complete | Writing tests and docs twice — once after M5, once after M7 — wastes effort; better to verify and document the complete feature set in one pass | M6 expanded to cover `backup-private-files.sh` end-to-end test and a three-script flow in docs |
| 6 | Default private sync targets: `journal/` and `.claude/design-decisions.md` | Research across all active repos confirmed `journal/` is gitignored in 10+ repos and `.claude/design-decisions.md` in 5+ repos; `prds/` is NOT gitignored anywhere — it is committed and travels with the repo on clone | Determines what M7 backs up and restores by default with zero per-repo config |
| 7 | Hardcoded defaults + per-repo `.private-sync` opt-in for additional paths | Hardcoded list covers the common case with no per-repo config; `.private-sync` handles exceptions without changing core logic | M7 backup and restore both read `.private-sync` (one path per line at repo root) to extend the default list |
| 8 | `backup-private-files.sh` is a standalone script | Runs on the current (old) machine as an outbound operation; `sync-repos.sh` and `bootstrap.sh` run on the new machine as inbound operations — different phases of a handoff; standalone makes periodic backup easy without triggering the full bootstrap flow | Adds a third companion script; M6 docs describe a three-step workflow: backup on old machine, then sync-repos + bootstrap on new machine |

## References

- [PRD #62: claude-personal backup repo](62-claude-personal-backup.md) — provides memory files and `settings.local.json` that bootstrap restores
- [scripts/install-git-hooks.sh](../scripts/install-git-hooks.sh) — hook installer called by M3
- [config/settings.json](../config/settings.json) — settings file that M1 symlinks into `~/.claude/`
