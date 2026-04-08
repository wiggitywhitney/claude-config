# PRD #62: claude-personal Backup Repo

## Problem

Claude memory files and personal config live only in `~/.claude/` with no version control. A laptop failure or migration would lose months of accumulated per-project memories (94 files across 16 projects) and Claude Code configuration. `~/.claude/settings.json` is now symlinked from claude-config, but the memory files have no home.

## Solution

Create a private GitHub repo (`claude-personal`) that versions:
- Per-project memory files from `~/.claude/projects/*/memory/`
- Possibly `~/.claude/settings.json` (already symlinked from claude-config — evaluate whether to duplicate here or just reference)

With idempotent sync scripts covering both directions:
- **push**: local `~/.claude/` → repo (run regularly to keep backup current)
- **restore**: repo → local `~/.claude/` (run once on a new machine)

Chat history (`~/.claude/history.jsonl`) is **explicitly excluded** — 7.7MB today, grows unboundedly, and is not structured for git diffs.

## Scope

**In scope:**
- Memory files (`~/.claude/projects/*/memory/` — all `*.md` files)
- Per-project `settings.local.json` files (`<repo>/.claude/settings.local.json` — 18 files today, gitignored by design, contain accumulated per-project tool permissions)
- Push script (local → repo)
- Restore script (repo → local)

**Out of scope:**
- `~/.claude/settings.json` — global settings, already versioned in claude-config repo via symlink; no need to duplicate here
- `~/.claude/history.jsonl` (unbounded growth, not useful as git history)
- Journal entries (tracked separately in the Journal repo)
- `.vals.yaml` files (contain secrets, never committed)
- Project-level `CLAUDE.md` files (already in each project's own repo)

## Key Design Decision (Discuss at M1)

**Memory directory naming**: Memory files currently live in directories named after absolute paths, e.g.:

```text
~/.claude/projects/-Users-whitney-lee-Documents-Repositories-commit-story-v2-eval/memory/
```

Two approaches to storing these in the repo:

**Option A: Preserve path structure** — rsync as-is, keep the `-Users-whitney-lee-...` directory names in the repo. Simple to implement; ugly to browse; works on restore only if the new machine has the same username and directory layout.

**Option B: Map to logical project names** — `memory/commit-story-v2-eval/`, `memory/claude-config/`, etc. Cleaner to browse; requires a manifest or naming convention to map back to absolute paths on restore; handles username/path changes gracefully.

This decision gates the sync script design. **Discuss at M1 before writing any code.**

## Success Criteria

- All memory files are committed to the private repo
- `push` script is idempotent — safe to run repeatedly, commits only when there are changes
- `restore` script places files in the correct `~/.claude/projects/` locations on a fresh machine
- Running push + restore round-trip produces identical memory files locally
- Chat history is never committed

## Milestones

### Milestone 1: Design Decision — Memory Directory Structure

Before writing any code, decide how memory directories are named in the repo (Option A: preserve absolute path names vs Option B: map to logical names). This decision shapes every other milestone.

**To implement:**
- Review the two options above and their trade-offs (portability, readability, sync complexity)
- Make the call and record it as a Decision in this PRD
- Draft the directory layout the repo will use

**Success criteria:**
- Decision recorded in this PRD with rationale
- Repo directory layout defined (even if the repo doesn't exist yet)

### Milestone 2: Create Private Repo and Initial Memory Snapshot

Create the `claude-personal` private GitHub repo and commit the current state of all memory files using the structure decided in M1.

**To implement:**
- Create private repo at `github.com/wiggitywhitney/claude-personal`
- Organize memory files per the M1 decision
- Initial commit with all 94 current memory files
- Add `.gitignore` that blocks `*.jsonl`, `*.env`, `.vals.yaml`, and any file matching common secret patterns

**Success criteria:**
- Repo exists and is private
- All current memory files are committed
- `.gitignore` prevents accidental secret commits
- Repo is cloneable to `~/Documents/Repositories/claude-personal`

### Milestone 3: Push Script (local → repo)

Write `scripts/sync-push.sh` that syncs local memory files to the repo and commits if anything changed.

**To implement:**
- Script reads from `~/.claude/projects/*/memory/` and copies to the repo (applying the M1 naming convention)
- Idempotent: if nothing changed, exits 0 without committing
- If changes exist: stages, commits with a timestamp message, and pushes
- Dry-run flag (`--dry-run`) shows what would change without committing
- Write bats tests covering: no changes (no commit), new file added, file modified, dry-run output

**Success criteria:**
- Running twice with no local changes produces zero commits
- New memory file shows up in repo after push
- Tests pass

### Milestone 4: Restore Script (repo → local)

Write `scripts/sync-restore.sh` that restores memory files from the repo to `~/.claude/projects/*/memory/` on a new machine.

**To implement:**
- Script reads the repo's memory files and writes them to the correct `~/.claude/projects/` paths (reversing the M1 naming convention)
- Idempotent: safe to run on a machine that already has the files (overwrites with repo version)
- Prints what it restored vs what it skipped (already identical)
- Write bats tests covering: fresh restore (creates dirs and files), re-restore (idempotent), directory creation for missing project paths

**Success criteria:**
- Fresh machine gets all memory files in the correct locations
- Re-running on a machine with identical files produces no errors
- Tests pass
- Round-trip (push then restore) produces byte-identical files

### Milestone 5: Documentation and Cron Suggestion

Document how to use the repo and recommend a backup cadence.

**To implement (run `/write-docs`):**
- README covering: what the repo is, what it backs up, what it doesn't, how to push, how to restore on a new machine
- Note the recommended manual cadence (e.g., run push before laptop travels)
- Add a comment in push script pointing to how to schedule it (cron or launchd) without prescribing one

**Success criteria:**
- README answers: "I just got a new laptop — how do I restore everything?"
- New-machine restore steps are clear and complete
- No secrets or absolute-path assumptions in the docs

## Decision Log

_(Decisions recorded here as they are made during implementation)_
