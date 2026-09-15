---
name: make-autonomous
description: Enable autonomous PRD mode for the current project. Installs YOLO skill symlinks and permissions.
category: project-management
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Enable Autonomous PRD Mode

Enable autonomous PRD mode for the current project. This installs YOLO skill variants (with active trigger descriptions) via symlinks, and frictionless permissions.

**There is no automatic resume after `/clear`, and this skill does not install a hook.** It advertised a `SessionStart` hook until 2026-08-18; that hook was removed because it never worked — text injected as an out-of-band command is surfaced to the reader rather than acted on. Whatever made the loop appear to continue was the YOLO skill descriptions' trigger language, not a hook. **After `/clear`, the user runs `/prd-next` again.**

## What This Does

1. **Creates symlinks to YOLO skill variants** in `.claude/skills/` pointing to `SKILL.v1-yolo.md` files in the claude-config repo
2. **Adjusts permissions** to reduce friction for autonomous git and skill operations

**Step 1 does not currently take effect, and step 2 does.** Personal skills in `~/.claude/skills/` take precedence over project skills in `.claude/skills/`, so a project symlink pointing at a `SKILL.v1-yolo.md` is shadowed by the personal copy of the same skill and the YOLO variant never loads. Established by live test during PRD #109's Milestone A4 — see [the installation-scope findings](../../../docs/research/claude-code-skill-installation-scope.md). Nine repos carried these symlinks without them ever having applied.

**So running this skill today loosens permissions and changes no behaviour.** That is the opposite of the safer failure: the guardrails come off while the autonomous hand-offs the looser permissions were meant to serve stay inactive. Say so when reporting what was installed, rather than reporting a mode that is not running.

The descriptions below are accurate about what each YOLO variant instructs — `prd-start` really does auto-invoke `prd-next`, and `prd-next` really does invoke `/prd-update-progress` — but they describe files that are not being loaded. Whether these variants should exist at all is Milestone C1's skill-consolidation decision; do not delete them here.

## PRD Skills Installed

These skills get symlinked (YOLO variants with active trigger descriptions):
- `prd-next` — INVOKE AUTOMATICALLY after `/prd-start`. **Not after `/clear`** — nothing triggers it there
- `prd-done` — **user-invoked**, once `/prd-next` reports every PRD item is checked. Nothing invokes it automatically and no `/clear` loop triggers it. This is the one hand-off YOLO mode deliberately leaves to a human, because the last step it would take unattended is merging, and this project requires a human to examine and approve the CodeRabbit review before a merge
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

### Step 3: Adjust Permissions

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

### Step 4: Verification

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
Permissions loosened for [project-name]. Autonomous hand-offs are NOT active.

Changes made:
  Permissions  — PRD skill and git permissions added (.claude/settings.local.json)
  Skills       — YOLO variant symlinks created in .claude/skills/, but shadowed by
                 the personal copies in ~/.claude/skills/ and never loaded (see above)

This session still runs the ordinary interactive skills. Nothing here makes
/prd-next auto-continue after /clear — run it yourself each time.

To revert the permission changes: run /make-careful
```

## Important Notes

- `.claude/settings.local.json` is auto-gitignored by Claude Code — permission changes are local only
- Symlinks in `.claude/skills/` should be added to `.gitignore` if the project doesn't want them tracked
- This skill only adds — it never removes existing content or settings
- If the project already has PRD skill files (not symlinks) in `.claude/skills/`, warn the user before overwriting
