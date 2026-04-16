---
name: post-compact
description: Re-anchor context after a compaction event. Reads CLAUDE.md, the active PRD, and git state, then reports orientation. Use immediately after /compact to recover lost context.
triggers:
  - "/post-compact"
  - "re-anchor context"
---

# Post-Compaction Context Re-Anchoring

After a `/compact` event, critical context (project identity, branch state, active rules, user preferences) may be stripped. This skill re-reads essential sources and confirms orientation before continuing work.

This is lighter than `/continue` — designed for mid-session use, not session start. It does NOT re-assess all project state, only re-anchors what compaction typically strips.

## Steps

1. **Read CLAUDE.md** — look at `CLAUDE.md` then `.claude/CLAUDE.md` in the repo root. Read whichever exists. Note any constraints or conventions that affect current work.

2. **Find the active PRD** — scan `prds/` for any `.md` file whose content matches `Status.*In Progress`. If found, read it. Note the last completed `[x]` milestone and the first unchecked `[ ]` item.

3. **Check git state** by running all three commands:
   ```bash
   git branch --show-current
   git log --oneline -5
   git status --short
   ```

4. **Check for active execution state** — if `_execution-state.md` exists in the repo root, read it and note the current task before reporting.

5. **Report orientation** using this format exactly:
   ```text
   --- CONTEXT RE-ANCHORED ---
   Repo: <name> | Branch: <branch>
   Last 3 commits: <oneline log>
   Working tree: <clean | dirty files listed>
   Active PRD: <filename> | Next: <first unchecked milestone>  (or "none" if absent)
   <_execution-state.md summary if present>
   Ready to continue.
   ---
   ```

6. **Flag anything unexpected** before continuing — wrong branch, unexpected dirty state, PRD milestone marked done but no corresponding commit. Do not proceed silently if something looks wrong.

## Constraints

- Do NOT start implementing work during this skill. Orientation only.
- Do NOT modify any files.
- Do NOT ask clarifying questions. Read the sources and report.
- If `prds/` does not exist or no PRD is in-progress, report "Active PRD: none" and continue.

## Exit Condition

Done when the orientation report is printed and confirmed. If anything flagged in Step 6, wait for user response before continuing.
