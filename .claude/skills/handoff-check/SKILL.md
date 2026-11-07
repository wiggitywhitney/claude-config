---
name: handoff-check
description: Make sure a brand-new session could pick up exactly where this one left off. Writes down this session's decisions (with what was rejected and why), open questions, gotchas, and the next-session checklist in the project's own handoff files, then commits them. Use when the user asks for a handoff check, wants to log progress, or is about to pause, clear, or end a session that isn't PRD or issue work.
category: project-management
---

# Handoff Check

Follow the steps below in order: find the project's handoff files, check for edits made under you, list everything this session produced, write what's missing, update the next-session checklist, commit, and report.

The next session starts cold, with no memory of this conversation, only the files in the repo. The check is done when every missing item has been written and committed, not when you've decided what's missing.

## When another skill fits better

- **PRD work is active** (a `prds/` file is being implemented this session): use `/prd-update-progress`, which handles the PRD, the journal, and the commit together. Stop here.
- **Issue work is active** (the branch is `feature/<numbers>-...`): use `/issue-update-progress`, which posts the checkpoint `/issue-next` reads. Stop here.

Use this skill for everything else: walkthroughs, reviews, research, planning, and long working sessions that keep their state in a document.

## Step 1: Find the project's handoff files

Look for where this project already keeps its "what's next" state. Check, in order:

1. Files the conversation has been treating as the source of truth or working log this session. These are usually the answer.
2. The project's `CLAUDE.md`, which may name a handoff doc or a session log.
3. Any markdown file with a next-session section:

   ```bash
   grep -rl --include='*.md' -i -E '^#+ *(next session|next steps|handoff|where we left off)' . 2>/dev/null | grep -v node_modules | head -20
   ```

4. A dated session log for today (for example `*-log-YYYY-MM-DD.md`) next to the handoff doc.

Use what exists and match its sections and format. Don't invent a new tracking file or structure. If you find nothing, ask the user where the handoff should live, and wait for the answer.

## Step 2: Check what has changed under you

Before editing, look at the working tree:

```bash
git status --short
git diff -- <each handoff file>
```

The user, or another session, may be editing the same files right now. Read any uncommitted edits in the handoff files and keep them. They are the user's words. If you edit with a script, re-read the file first, so a find-and-replace doesn't fail on (or overwrite) text the user just changed.

## Step 3: Scan the conversation

Go through this session from the start and make an explicit list of each of these before you write anything. Keep the list in your reasoning, not in a new file.

- **Decisions.** Every choice that shaped the work: what was decided, who decided it, the date, and **what was rejected and why**. The rejected alternatives matter most, because they stop a later session from reopening a settled question. When the user said it in their own words, quote them exactly.
- **State changes.** What got built, filed, merged, closed, sent, or published this session, with its identifier (issue number, commit, URL). Also what was expected to move and didn't.
- **Open questions.** Anything asked and not answered, anything flagged as "the user's call", and anything deferred. Note who owns each one.
- **Gotchas.** Tool quirks, failed approaches, surprising behavior, and anything that cost time to figure out. Write the symptom, the cause, and what to do instead.
- **Where the session paused.** The exact next step, and anything that has to happen before it (a sync to run, a status to check, a person to hear back from).
- **Preferences that reach beyond this project.** A correction or standing rule from the user that applies to other work too. These go to memory or the user's rule files, following their global `CLAUDE.md`, not just to the project's handoff doc.

## Step 4: Write what's missing

For each item on your list, check whether it's already in the handoff files. If it isn't, write it now, in the section where the next session will look:

- Decisions go in the doc's decisions section, under today's date (absolute, YYYY-MM-DD). If the doc has dated decision sections, add a new one for today above the older ones.
- Open questions go in its open-questions section. Mark questions resolved this session as resolved, or remove them, so the list stays current.
- Gotchas go in the session log or gotchas section the project already uses.
- State changes go in the status or progress section the next session reads first.
- Cross-project preferences go to memory or the global rules, as the user's `CLAUDE.md` describes.

Write in plain sentences a stranger could follow. Use the terms the project already uses, not shorthand coined in this conversation.

Rules for this step:

- Do NOT put words in quotation marks that the user didn't say verbatim.
- Do NOT rewrite earlier sessions' logs, journal entries, or dated decision sections to match what's true now. They record what was believed at the time. Add a new dated entry that supersedes them instead.
- Do NOT delete an open question because nobody answered it. Remove it only when it was resolved, and say how.
- Do NOT summarize away the reason for a decision. "Rejected X" without "because Y" lets the next session reopen it.

## Step 5: Update the next-session checklist

Rewrite the next-session section so it says:

1. **What to check first,** and how (the exact commands or scripts), before any new work.
2. **Where the session paused,** and the exact place to resume.
3. **What's still open,** linked to where each item is tracked.

Remove checklist items that are done. Then run the cold-start test: if a new session read only the handoff files and the repo, could it start the next step correctly? If the next step depends on something only this conversation knows (an approach to avoid, a file to read first, a quirk), add it now.

## Step 6: Commit

Follow the repo's own workflow: its branch rules, and a `PROGRESS.md` entry if the repo requires one with every commit.

- Stage **only the handoff files you checked or edited.** Never `git add -A` or `git commit -a`.
- Leave other uncommitted files alone. They may belong to the user or to another session. List them in your report instead.
- If a hook rejects the commit, read its message, fix the cause, and commit again.

## Step 7: Check, then report

Before reporting, confirm each of these. Fix any that fail.

- [ ] Every decision from Step 3 is in a decisions section, with its date and its rejected alternatives.
- [ ] Every open question is written down with its owner, and resolved ones are marked or removed.
- [ ] Every gotcha is written down with its symptom and what to do instead.
- [ ] The next-session checklist names what to check first, where the session paused, and where to resume.
- [ ] The cold-start test from Step 5 passes.
- [ ] The commit contains only handoff files, and `git status` shows no handoff file left uncommitted.

Then report in this shape, and keep it short. The detail lives in the files.

```markdown
**Handoff check done.** Committed as `<sha>`.

- **Written:** <what> → `<file>`, <section> (one line each)
- **Still open for you:** <question> (one line each, or "nothing")
- **Left uncommitted, not mine:** <file> (one line each, or "nothing")
- **Next session starts at:** <one line>
```
