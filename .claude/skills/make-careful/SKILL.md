---
name: make-careful
description: Disable autonomous PRD mode — swap YOLO skill symlinks to careful variants, remove hooks and permissions
category: project-management
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Disable Autonomous PRD Mode

Swap a project from autonomous (YOLO) PRD mode to careful mode. This replaces YOLO skill symlinks with careful variants, removes the `/clear` → auto-resume SessionStart hook, and removes autonomous permissions.

## What This Does

1. **Swaps symlinks to careful skill variants** in `.claude/skills/` pointing to `SKILL.md` files in the claude-config repo
2. **Removes SessionStart hook** that enables the `/clear` → auto-resume loop
3. **Removes autonomous permissions** added by `/make-autonomous`

## PRD Skills After Swap

These skills get symlinked to careful variants (passive descriptions, user-driven invocation):
- `prd-next` — Analyze existing PRD to identify and recommend the single highest-priority task
- `prd-done` — Complete PRD implementation workflow - create branch, push changes, create PR
- `prd-update-progress` — Update PRD progress based on git commits and code changes
- `prd-start` — Start working on a PRD implementation
- `prd-create` — Create documentation-first PRDs
- `prd-update-decisions` — Capture design decisions in PRD decision log
- `prd-close` — Close a completed or abandoned PRD
- `prds-get` — Fetch open GitHub issues with PRD label

## Process

### Step 1: Pre-Flight Checks

1. Verify the current directory is a git repository (run `git rev-parse --git-dir`)
2. Check if `.claude/skills/` exists with PRD skill symlinks
3. Check current mode:
   - If `.claude/skills/prd-next/SKILL.md` is a symlink pointing to a `SKILL.v1-yolo.md` file: autonomous mode, proceed with swap
   - If `.claude/skills/prd-next/SKILL.md` is a symlink pointing to a `SKILL.md` file (not yolo): already in careful mode, inform user and exit
   - If `.claude/skills/prd-next/SKILL.md` does not exist: no PRD skills installed, inform user and exit
4. Locate the claude-config repo:
   - Check `$CLAUDE_CONFIG_DIR` environment variable
   - Fallback: check `~/Documents/Repositories/claude-config`
   - Verify the path exists and contains `.claude/skills/prd-next/SKILL.md` (careful variant)
   - If not found: error and exit — claude-config repo is required

### Step 2: Swap Symlinks to Careful Skill Variants

For each PRD skill, replace the YOLO symlink with one pointing to the careful variant. Use the Bash tool:

```bash
CLAUDE_CONFIG="$CLAUDE_CONFIG_DIR"  # or ~/Documents/Repositories/claude-config
SKILLS_DIR=".claude/skills"

# PRD skills to swap (all have careful variants as SKILL.md in claude-config)
for skill in prd-next prd-done prd-start prd-update-progress prd-update-decisions prd-create prd-close prds-get; do
    # Only swap if the skill directory exists in the project
    if [[ -d "$SKILLS_DIR/$skill" ]]; then
        # Remove existing symlink
        rm -f "$SKILLS_DIR/$skill/SKILL.md"

        # Create symlink to careful variant (SKILL.md in claude-config)
        ln -s "$CLAUDE_CONFIG/.claude/skills/$skill/SKILL.md" "$SKILLS_DIR/$skill/SKILL.md"
    fi
done
```

**Important**: Use absolute paths for symlink targets so they work regardless of working directory.

### Step 3: Remove SessionStart Hook

Read `.claude/settings.local.json`. Remove the `prd-loop-continue.sh` SessionStart hook entry:

**What to remove:**
- Find the `hooks.SessionStart` array
- Remove the entry where `matcher` is `"clear"` and the command references `prd-loop-continue.sh`
- If `SessionStart` becomes empty after removal, remove the `SessionStart` key
- If `hooks` becomes empty after removal, remove the `hooks` key
- Never touch other hook types (PreToolUse, PostToolUse, etc.)

### Step 4: Remove Autonomous Permissions

Remove the permission entries that `/make-autonomous` added from `.claude/settings.local.json` under `permissions.allow`.

**Entries to remove** (these are the entries installed by `/make-autonomous`):

```json
[
  "Bash(git status*)",
  "Bash(git log *)",
  "Bash(git log)",
  "Bash(git diff*)",
  "Bash(git branch*)",
  "Bash(git add *)",
  "Bash(git add .)",
  "Bash(git commit *)",
  "Bash(git checkout *)",
  "Bash(git switch *)",
  "Bash(git push*)",
  "Bash(git pull*)",
  "Bash(git stash*)",
  "Bash(git remote *)",
  "Bash(git rev-parse *)",
  "Bash(git show *)",
  "Bash(gh *)",
  "Bash(ls *)",
  "Bash(ls)",
  "Bash(pwd)",
  "Skill(prd-next)",
  "Skill(prd-done)",
  "Skill(prd-start)",
  "Skill(prd-update-progress)",
  "Skill(prd-update-decisions)",
  "Skill(prd-create)",
  "Skill(prd-close)",
  "Skill(anki-yolo)",
  "WebFetch",
  "WebSearch"
]
```

**Removal rules:**
- Only remove entries that exactly match the list above
- Preserve all other permission entries (user-added, project-specific)
- If `permissions.allow` becomes empty after removal, remove the `allow` key
- If `permissions` becomes empty after removal, remove the `permissions` key
- Use a script to filter — do not manually edit the JSON

### Step 5: Verification

After all changes, verify the symlinks are correct:

```bash
# Verify each symlink points to the careful variant
for skill in prd-next prd-done prd-start prd-update-progress prd-update-decisions prd-create prd-close prds-get; do
    if [[ -L ".claude/skills/$skill/SKILL.md" ]]; then
        target=$(readlink ".claude/skills/$skill/SKILL.md")
        if [[ "$target" == *"v1-yolo"* ]]; then
            echo "WARNING: $skill still points to YOLO variant: $target"
        else
            echo "$skill -> $target (careful)"
        fi
    elif [[ -f ".claude/skills/$skill/SKILL.md" ]]; then
        echo "$skill -> regular file (not symlink)"
    else
        echo "$skill -> not installed"
    fi
done
```

Then display a summary:

```text
Careful PRD mode enabled for [project-name].

Changes made:
  Skills       — Careful variant symlinks installed in .claude/skills/
  Hooks        — SessionStart hook removed (.claude/settings.local.json)
  Permissions  — Autonomous permissions removed (.claude/settings.local.json)

Restart Claude Code to pick up the new skill definitions.
    The symlinks are in place, but the current session has the old skills loaded in memory.

To re-enable autonomous mode: run /make-autonomous
```

## Important Notes

- `.claude/settings.local.json` is auto-gitignored by Claude Code — changes are local only
- This skill only removes what `/make-autonomous` added — it never removes user-added content
- If some PRD skills were not installed by `/make-autonomous`, they are left untouched
- The skill is idempotent — running it when already in careful mode is a no-op
