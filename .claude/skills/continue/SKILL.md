---
name: continue
description: Resume work from a previous session. Reads PRD state, PROGRESS.md, git state, task list, and layered journal context to summarize where work left off and suggest the next step. Use at the start of a work session. For mid-session context recovery after /compact, use /post-compact instead.
triggers:
  - "/continue"
  - "resume work"
  - "where did we leave off"
  - "pick up where we left off"
---

# Continue

> **Note**: This skill is heavier than `/post-compact` — it reads journal context and PROGRESS.md to reconstruct narrative state, not just structural state. Use it at session start. For mid-session recovery after compaction, use `/post-compact`.

## Step 1: Get Today's Date

Run `date +%Y-%m-%d` to get today's date. Derive yesterday's date with `python3 -c "from datetime import date, timedelta; print(date.today() - timedelta(1))"` — this works on any platform. Alternatives if python3 is unavailable: macOS `date -v-1d +%Y-%m-%d`, GNU/Linux `date -d yesterday +%Y-%m-%d`. You will need both dates for journal file paths.

## Step 2: Read State Sources

Read each source in order. Skip silently if a file or directory is absent — do not error or ask.

1. **Active PRD** — glob `prds/*.md`. Read any file whose content includes `Status: In Progress`. Note the last completed `[x]` milestone and all pending `[ ]` items. If none found, note "no active PRD."

2. **PROGRESS.md** — if it exists at repo root, read it. Focus on the most recent entries under `## [Unreleased]` — these capture the narrative of what was recently accomplished and why.

3. **Git log** — run `git log --oneline -10`.

4. **Git status** — run `git status --short`.

5. **Task list** — run `TaskList` for any pending or in-progress tasks.

6. **Journal context** — only if `journal/` exists in this repo. Read in this order; skip any file that is absent:
   - **Today's raw entries**: `journal/entries/YYYY-MM/YYYY-MM-DD.md` — use today's date for both the month directory and filename.
   - **Yesterday's daily summary**: `journal/summaries/daily/YYYY-MM-DD.md` — use yesterday's date.
   - **Most recent weekly summary**: glob `journal/summaries/weekly/*.md`, take the last file alphabetically.
   - **Most recent monthly summary**: glob `journal/summaries/monthly/*.md`, take the last file alphabetically.

## Step 3: Summarize

Present a concise summary in this format:

```text
--- SESSION RESUME ---
Repo: <name> | Branch: <branch> | Working tree: <clean | N files changed>
Recent commits: <last 5 oneline entries>

Active PRD: <filename | "none">
  Last completed: <most recent [x] milestone | "none">
  Pending: <[ ] milestones, one per line>

Recent progress: <2-4 sentences from PROGRESS.md — what was done last and why>

Pending tasks: <task list items | "none">

Journal context: <key decisions, blockers, or themes from recent journal reading — or "none found">

Anomalies: <unexpected branch, uncommitted work, PRD/commit mismatches, task contradictions — or "none">

Suggested next step: <specific, actionable recommendation based on all of the above>
---
```

If there is no previous state to resume from (no PRD, empty PROGRESS.md, empty git log), say so and ask what the user would like to work on.

## Step 4: Quality Check

Before presenting the summary, verify:
- All sources that exist were read (nothing silently skipped without noting it)
- "Suggested next step" names a specific task, not a vague direction
- Any anomalies found are included in the Anomalies field

## Step 5: Confirm

Ask: "Does this match your understanding? Ready to continue with [suggested next step]?"

Wait for the user's response. Do not begin any work until confirmed.

## Constraints

- Do NOT start implementing work. Assessment and summary only.
- Do NOT modify any files.
- Do NOT ask clarifying questions before summarizing — read sources and report first.
