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

### Milestone 1: Design Decision — Memory Directory Structure ✅

Before writing any code, decide how memory directories are named in the repo (Option A: preserve absolute path names vs Option B: map to logical names). This decision shapes every other milestone.

**To implement:**
- Review the two options above and their trade-offs (portability, readability, sync complexity)
- Present your recommendation (Option A or B) with a one-paragraph rationale covering portability, readability, and sync complexity
- **Stop and wait for Whitney to confirm before writing any directory layout or code**
- Once confirmed, record the decision in this PRD's Decision Log with rationale and draft the directory layout the repo will use

**Success criteria:**
- Decision confirmed by Whitney and recorded in the Decision Log with rationale
- Repo directory layout defined (even if the repo doesn't exist yet)

### Milestone 2: Create Private Repo and Initial Memory Snapshot ✅

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

### Milestone 3: Push Script (local → repo) ✅
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Write `scripts/sync-push.sh` in the claude-personal repo that syncs local memory files and `settings.local.json` files to the repo and commits if anything changed.

**To implement:**
- Script reads from `~/.claude/projects/*/memory/` and copies to the repo (applying the M1 naming convention for memory files)
- Script also syncs per-project `settings.local.json` files: reads from `~/Documents/Repositories/<project>/.claude/settings.local.json` and writes to `local-settings/<project-name>/settings.local.json` in the repo. If a project directory exists but has no `settings.local.json`, skip silently.
- Idempotent: if nothing changed across both file sets, exits 0 without committing
- If changes exist: stages, commits with message `"backup: sync memory and settings $(date -u +%Y-%m-%dT%H:%M:%SZ)"`, and pushes
- Dry-run flag (`--dry-run`) shows what would change without committing
- Push is additive-only: files deleted locally are not removed from the repo (accidental local deletions should not destroy the backup)
- Write bats tests covering: no changes (no commit), new memory file added, `settings.local.json` updated, dry-run output, missing `settings.local.json` skipped silently

**Success criteria:**
- Running twice with no local changes produces zero commits
- New memory file and updated `settings.local.json` both appear in repo after push
- Locally-deleted files remain in repo after push
- Tests pass

### Milestone 4: Restore Script (repo → local) ✅
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

Write `scripts/sync-restore.sh` in the claude-personal repo that restores memory files and `settings.local.json` files from the repo to the correct local locations on a new machine.

**To implement:**
- Restore memory files: read from repo (using M1 naming convention), write to `~/.claude/projects/<encoded-path>/memory/` (reversing the M1 mapping). Create parent directories as needed.
- Restore `settings.local.json` files: read from `local-settings/<project-name>/settings.local.json` in the repo, write to `~/Documents/Repositories/<project-name>/.claude/settings.local.json`. Skip if the project directory doesn't exist on disk (repo not yet cloned) — print `[SKIPPED] <project-name> — repo not cloned yet`.
- Skip files that are already identical (byte-for-byte); overwrite if different (repo is authoritative on restore)
- If a local file is newer than the repo version, print a warning before overwriting: `[WARNING] <file> is newer locally than in repo — overwriting with repo version. Run sync-push.sh first if you want to preserve local changes.`
- Prints per-file status: `[RESTORED]`, `[SKIPPED identical]`, `[UPDATED]`, or `[SKIPPED repo not cloned]`
- Write bats tests covering: fresh restore (creates dirs and files), re-restore (idempotent), missing project dir skips with message, directory creation for missing `~/.claude/projects/` paths

**Success criteria:**
- Fresh machine gets all memory files and `settings.local.json` files in the correct locations
- Missing project repos produce skip messages, not errors
- Re-running on a machine with identical files produces no errors
- Tests pass
- Round-trip (push then restore) produces byte-identical files

### Milestone 5: Documentation and Cron Suggestion ✅

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

### M4: Path prefix encoding — derive from HOME, not from `whoami`

**Decision**: Compute the `~/.claude/projects/` path prefix by encoding `$HOME` through `sed 's|[/.]|-|g'`, not by using `$(whoami)`.

**Rationale**: Claude Code encodes the full absolute path to a project directory by replacing every non-alphanumeric character (including dots) with a hyphen. On a machine where the username contains a dot (e.g., `whitney.lee`), `whoami` returns `whitney.lee` but the actual project directory uses `whitney-lee`. Deriving the prefix from `$HOME` with the same encoding rule produces the correct prefix regardless of special characters in the username.

**Correct encoding rule**: `sed 's|[/.]|-|g'` — replaces forward slashes and dots only. Do NOT use `[^a-zA-Z0-9]`, which would also replace hyphens, underscores, and digits in project names (though hyphens → hyphens is a no-op in practice, the rule is imprecise). Evidence: directories like `-Users-...-KubeHound-Demo` show hyphens in project names are preserved.

**Impact**: Both `sync-push.sh` and `sync-restore.sh` use this encoding. The bats test files use the same approach for `TEST_PREFIX`.

### M1: Memory directory naming strategy — Option B (logical project names)

**Decision**: Map memory directories to logical project names rather than preserving absolute path-encoded names.

**Rationale**: Option A (preserving `-Users-whitney-lee-...` directory names) breaks on any machine with a different username or directory layout — exactly the failure mode this backup is designed to survive. Option B survives machine migration, produces a readable repo on GitHub, and the mapping complexity is a one-time implementation cost.

**Mapping rule**: Strip the common prefix encoding (`-Users-<username>-Documents-Repositories-`) from the `~/.claude/projects/` directory name and use the trailing segment as the logical project name. Example: `-Users-whitney-lee-Documents-Repositories-claude-config` → `claude-config`.

**Edge cases**: Projects whose path does not match the `~/Documents/Repositories/<name>` pattern (e.g., paths outside that directory) use the full encoded name as-is as a fallback — this preserves restore correctness for unusual paths without breaking the common case.

**Repo directory layout**:
```text
claude-personal/
├── memory/
│   ├── claude-config/          # ~/.claude/projects/-Users-...-claude-config/memory/
│   ├── commit-story-v2-eval/   # ~/.claude/projects/-Users-...-commit-story-v2-eval/memory/
│   └── ...                     # one directory per project
├── local-settings/
│   ├── claude-config/          # ~/Documents/Repositories/claude-config/.claude/settings.local.json
│   │   └── settings.local.json
│   └── ...                     # one directory per project with a settings.local.json
├── .gitignore
└── README.md
```
