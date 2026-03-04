---
name: make-autonomous
description: Enable autonomous PRD mode for the current project. Installs YOLO skill symlinks, SessionStart hooks, and permissions.
category: project-management
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Enable Autonomous PRD Mode

Enable autonomous PRD mode for the current project. This installs YOLO skill variants (with active trigger descriptions) via symlinks, the `/clear` → auto-resume SessionStart hook, and frictionless permissions.

## What This Does

1. **Creates symlinks to YOLO skill variants** in `.claude/skills/` pointing to `SKILL.v1-yolo.md` files in the claude-config repo
2. **Installs SessionStart hook** enabling the `/clear` → auto-resume loop via `prd-loop-continue.sh`
3. **Adjusts permissions** to reduce friction for autonomous git and skill operations

## PRD Skills Installed

These skills get symlinked (YOLO variants with active trigger descriptions):
- `prd-next` — INVOKE AUTOMATICALLY after `/prd-start` or `/clear` on PRD branch
- `prd-done` — Triggered by the `/clear` loop when all PRD items are done
- `prd-update-progress` — INVOKE AUTOMATICALLY after completing a PRD task
- `prd-start` — Start working on a PRD implementation
- `prd-create` — Create documentation-first PRDs
- `prd-update-decisions` — Capture design decisions in PRD decision log
- `prd-close` — Close a completed or abandoned PRD
- `prds-get` — Fetch open GitHub issues with PRD label

## Process

### Step 1: Pre-Flight Checks

1. Verify the current directory is a git repository (run `git rev-parse --git-dir`)
2. Check for `.claude/` directory — create it if missing (`mkdir -p .claude`)
3. Check if YOLO skill symlinks already exist:
   - Check if `.claude/skills/prd-next/SKILL.md` is a symlink pointing to a `SKILL.v1-yolo.md` file
   - If yes: inform the user autonomous mode is already enabled and exit
4. Locate the claude-config repo:
   - Check `$CLAUDE_CONFIG_DIR` environment variable
   - Fallback: check `~/Documents/Repositories/claude-config`
   - Verify the path exists and contains `.claude/skills/prd-next/SKILL.v1-yolo.md`
   - If not found: error and exit — claude-config repo is required

### Step 2: Create Symlinks to YOLO Skill Variants

For each PRD skill, create a project-level symlink. Use the Bash tool to run these commands:

```bash
CLAUDE_CONFIG="$CLAUDE_CONFIG_DIR"  # or ~/Documents/Repositories/claude-config
SKILLS_DIR=".claude/skills"

# PRD skills to install (all have YOLO variants)
for skill in prd-next prd-done prd-start prd-update-progress prd-update-decisions prd-create prd-close prds-get; do
    mkdir -p "$SKILLS_DIR/$skill"

    # Remove existing symlink or file if present
    rm -f "$SKILLS_DIR/$skill/SKILL.md"

    # Determine source: use YOLO variant if it exists, otherwise use standard SKILL.md
    if [[ -f "$CLAUDE_CONFIG/.claude/skills/$skill/SKILL.v1-yolo.md" ]]; then
        ln -s "$CLAUDE_CONFIG/.claude/skills/$skill/SKILL.v1-yolo.md" "$SKILLS_DIR/$skill/SKILL.md"
    else
        ln -s "$CLAUDE_CONFIG/.claude/skills/$skill/SKILL.md" "$SKILLS_DIR/$skill/SKILL.md"
    fi
done
```

**Important**: Use absolute paths for symlink targets so they work regardless of working directory.

### Step 3: Install SessionStart Hook

Read `.claude/settings.local.json` (create with `{}` if it doesn't exist). Add a SessionStart hook:

**Target structure to merge into settings.local.json:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "clear",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_CONFIG_DIR/scripts/prd-loop-continue.sh"
          }
        ]
      }
    ]
  }
}
```

**Merge rules:**
- If no `hooks` key exists, add it
- If `hooks` exists but no `SessionStart`, add the `SessionStart` array
- If `SessionStart` already exists, check for a `prd-loop-continue` entry before adding (avoid duplicates)
- Never overwrite existing PreToolUse, PostToolUse, or other hook entries

### Step 4: Adjust Permissions

Add permission entries to `.claude/settings.local.json` under `permissions.allow`. These reduce confirmation prompts during autonomous PRD work:

```json
{
  "permissions": {
    "allow": [
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
      "Skill(prds-get)",
      "Skill(anki-yolo)",
      "WebFetch",
      "WebSearch"
    ]
  }
}
```

**Merge rules:**
- If no `permissions` key exists, add it with the `allow` array
- If `permissions.allow` already exists, add only entries that don't already exist (deduplicate)
- Never remove existing permission entries

### Step 5: Verification

After all changes, verify the symlinks are correct:

```bash
# Verify each symlink points to the right target
for skill in prd-next prd-done prd-start prd-update-progress prd-update-decisions prd-create prd-close prds-get; do
    if [[ -L ".claude/skills/$skill/SKILL.md" ]]; then
        target=$(readlink ".claude/skills/$skill/SKILL.md")
        echo "$skill -> $target"
    else
        echo "WARNING: $skill is not a symlink"
    fi
done
```

Then display a summary:

```text
Autonomous PRD mode enabled for [project-name].

Changes made:
  Skills       — YOLO variant symlinks created in .claude/skills/
  Hooks        — SessionStart hook installed (.claude/settings.local.json)
  Permissions  — PRD skill and git permissions added (.claude/settings.local.json)

⚠️  Restart Claude Code to pick up the new skill definitions.
    The symlinks are in place, but the current session has the old skills loaded in memory.

To revert: run /make-careful

The autonomous loop:
  /prd-start → /prd-next → implement → /prd-update-progress → /clear → auto-resume → repeat
```

## Important Notes

- `.claude/settings.local.json` is auto-gitignored by Claude Code — hook and permission changes are local only
- Symlinks in `.claude/skills/` should be added to `.gitignore` if the project doesn't want them tracked
- This skill only adds — it never removes existing content or settings
- If the project already has PRD skill files (not symlinks) in `.claude/skills/`, warn the user before overwriting
