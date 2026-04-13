# Setting Up a New Machine

Three companion scripts restore a full Claude development environment when switching to a new laptop. Run them in order: one on the **old machine** to push private files to `claude-personal`, then two on the **new machine** to clone repos and restore everything.

| Script | Runs on | Purpose |
|--------|---------|---------|
| `scripts/backup-private-files.sh` | Old machine | Pushes gitignored private files into `claude-personal` |
| `scripts/sync-repos.sh` | New machine | Clones missing repos, pulls existing ones |
| `scripts/bootstrap.sh` | New machine | Restores settings, memory files, hooks, and private files |

---

## Prerequisites

Before running any script, you need two repos cloned on **both** machines:

```bash
git clone git@github.com:wiggitywhitney/claude-config.git ~/Documents/Repositories/claude-config
git clone git@github.com:wiggitywhitney/claude-personal.git ~/Documents/Repositories/claude-personal
```

You also need the following installed and authenticated on the new machine:

- [GitHub CLI](https://cli.github.com/) (`gh`) — `sync-repos.sh` uses it to list and clone your repos
- [GNU coreutils](https://formulae.brew.sh/formula/coreutils) (`brew install coreutils`) — `sync-repos.sh` uses GNU `date` for date arithmetic, which is not available in macOS's built-in BSD `date`

---

## Step 0: Back up private files (old machine)

Before you switch, run this on the **old machine** to push gitignored private files into `claude-personal`:

```bash
scripts/backup-private-files.sh
```

What gets backed up by default:

- `journal/` — gitignored journal directories found in any repo under `~/Documents/Repositories`
- `.claude/design-decisions.md` — gitignored design decision logs

Each repo can opt in additional paths by listing them in a `.private-sync` file at the repo root (one relative path per line).

**Sample output:**

```text
[SKIPPED] another-project/journal — not found
[SKIPPED] another-project/.claude/design-decisions.md — not found
[OK] backed up my-project/journal
[OK] backed up my-project/.claude/design-decisions.md
[OK] backed up my-project/notes/scratch.md
[master (root-commit) 5ea6b8f] chore: back up private files from local repos
 3 files changed, 3 insertions(+)
```

`[SKIPPED]` lines are normal — they appear for repos that don't have the default private paths. The script commits any changed files to `claude-personal` automatically. Running again when nothing has changed produces no output and no commit.

**Dry run** — verify what would be backed up without copying any files:

```bash
scripts/backup-private-files.sh --dry-run
```

```text
[DRY RUN] Would back up my-project/journal
[SKIPPED] my-project/.claude/design-decisions.md — not found
```

---

## Step 1: Sync repos (new machine)

On the new machine, run this to clone missing repos and pull existing ones:

```bash
scripts/sync-repos.sh
```

The script uses `gh repo list` to find all your repos active within the last 6 months, then clones those not on disk and fast-forward pulls those already present.

**Sample output:**

```text
[OK] pulled my-project (2 commits)
[OK] cloned new-repo
[SKIPPED] archived-repo — not active in last 6 months
```

**When a pull can't fast-forward** (the repo has local-only commits or has diverged):

```text
[SKIPPED] my-project — local changes, run git pull manually
```

This is a warning, not a failure. The script continues with all other repos and exits 0.

**Dry run** — see what would be cloned or pulled without making any changes:

```bash
scripts/sync-repos.sh --dry-run
```

```text
[DRY RUN] Would pull my-project
[DRY RUN] Would clone new-repo
[SKIPPED] archived-repo — not active in last 6 months
```

---

## Step 2: Bootstrap (new machine)

After syncing repos, run bootstrap to restore your Claude environment:

```bash
scripts/bootstrap.sh
```

Bootstrap runs five steps in order:

1. Creates the `~/.claude/settings.json` symlink pointing to `claude-config/config/settings.json`
2. Restores memory files from `claude-personal` into `~/.claude/projects/`
3. Installs git hooks in all repos under `~/Documents/Repositories/`
4. Restores `settings.local.json` files into each repo's `.claude/` directory
5. Restores private files (journal entries, design decisions, and `.private-sync` additions) into each repo

**Sample output on a fresh machine:**

```text
[OK] settings.json symlink created → /Users/whitney.lee/Documents/Repositories/claude-config/config/settings.json
[OK] Restored memory: my-project/notes.md
[OK] git hooks installed: my-project
[OK] Restored settings.local.json: my-project
[SKIPPED] settings.local.json: other-project — repo not cloned yet
[OK] private file: my-project/journal/entries/2026-04-13.md
[OK] private file: my-project/.claude/design-decisions.md
[SKIPPED] private files: other-project — repo not cloned yet

Re-run bootstrap after cloning the above repos to restore their files and settings.
```

`[SKIPPED]` lines for repos not yet cloned are expected on a fresh machine — bootstrap restores what it can and tells you what to come back to.

**Re-running is safe.** On an already-configured machine, bootstrap skips steps that are already correct rather than overwriting them:

```text
[SKIPPED] settings.json symlink already correct
[SKIPPED] memory: my-project/notes.md (identical)
```

**Dry run** — see what would happen without making any changes:

```bash
scripts/bootstrap.sh --dry-run
```

```text
[SKIPPED] settings.json symlink already correct
[DRY RUN] Would restore memory: my-project/notes.md
[DRY RUN] Would install git hooks in my-project
[DRY RUN] Would restore settings.local.json: my-project
```

---

## Re-running after cloning more repos

Bootstrap skips repos not yet on disk and prints a reminder at the end. After you clone a previously-skipped repo, run bootstrap again to fill in the gap:

```bash
# Clone a repo that was skipped earlier
gh repo clone owner/other-project ~/Documents/Repositories/other-project

# Re-run — only the new repo needs restoring, everything else is skipped as identical
scripts/bootstrap.sh
```

Each re-run is safe and fast: steps already completed are skipped immediately, and only new or changed items are restored.

---

## Flags reference

| Flag | Script(s) | Default | Purpose |
|------|-----------|---------|---------|
| `--dry-run` | all three | off | Print what would happen without making any changes or commits |
| `--months N` | `sync-repos.sh` | `6` | Only sync repos active within the last N months |
| `--repos-dir <path>` | all three | `~/Documents/Repositories` | Use a different directory to scan for repos |
| `--claude-personal-dir <path>` | `backup-private-files.sh`, `bootstrap.sh` | `~/Documents/Repositories/claude-personal` | Use a different `claude-personal` clone |
