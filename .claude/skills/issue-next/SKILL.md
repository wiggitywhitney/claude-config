---
name: issue-next
description: Fresh session pickup using the most recent checkpoint comment and git log — reconstructs working context for active issue work
category: project-management
---

# Issue Next Slash Command

## Process Overview

1. **Identify Context** - Extract issue numbers from the current branch name
2. **Fetch Checkpoint** - Find the most recent checkpoint comment on the active issue(s)
3. **Read Git Log** - Capture recent commits for code context
4. **Synthesize Brief** - Present a structured context summary
5. **Transition** - Ask whether to continue or adjust the plan

## Step 1: Identify Context

```bash
git branch --show-current
```

Extract issue numbers from the branch name. Branch format: `feature/<numbers>-<description>` where `<numbers>` is a hyphen-separated list of issue numbers (e.g., `feature/98-101-autonomous-issue-execution` → issues 98 and 101, `feature/42-fix-auth-token-handling` → issue 42).

For each issue number, fetch the title:

```bash
gh issue view <number> --json title,state
```

If the current branch does not match the `feature/<numbers>-<description>` format, tell the user: "This branch doesn't follow the issue branch naming convention. Please run `/issue-start` to create a correctly-named branch, or specify the issue number manually."

## Step 2: Fetch Checkpoint

For each issue number extracted from the branch name, fetch all comments:

```bash
gh issue view <number> --comments --json comments
```

Find the most recent comment whose body begins with the exact string `## Progress Checkpoint`. Use the issue with the most recent such comment as the context source for the brief.

If no checkpoint comment exists on any issue in the working set, note this: "No checkpoint comment found on this issue. Using git log only for context." Then proceed with Step 3.

**Checkpoint comment format** (the sentinel is `## Progress Checkpoint` — match on this exact string, nothing else):

```markdown
## Progress Checkpoint

**Branch**: `feature/<numbers>-<description>`
**Done**:
- [bullet per completed item since last checkpoint]

**Next step**: [one concrete next action]

**Open questions** (optional):
- [question if any]
```

## Step 3: Read Git Log

```bash
git log --oneline -10
```

Use recent commits as supplemental context — they show what code landed after the checkpoint was posted.

## Step 4: Synthesize Brief

Present a structured context summary in this format:

```markdown
## Active Issue(s)

- #<number>: <title>
[repeat for each issue in working set]

## What Was Done

[Bullets from the checkpoint's Done section, or derived from git log if no checkpoint]

## Next Step

[The concrete next action from the checkpoint's "Next step" field, or the most recent commit context if no checkpoint]

## Open Questions

[Bullets from the checkpoint's Open questions section, or "None recorded" if absent]

## Recent Commits

[The git log --oneline -10 output]
```

If the checkpoint was posted from a different session, note this: "Last checkpoint was posted [relative time if available from comment timestamp]. Recent commits since then: [list any commits after the checkpoint was posted]."

## Step 5: Transition

Ask a single question:

"Ready to continue with the next step, or do you want to adjust the plan first?"

Wait for the user's response before taking any further action.

## Success Criteria

- ✅ Correctly identifies issue numbers from the current branch name
- ✅ Finds the most recent checkpoint comment using the exact sentinel `## Progress Checkpoint`
- ✅ Falls back gracefully to git log when no checkpoint comment exists
- ✅ Presents a complete brief without requiring the user to re-explain context
- ✅ Transitions to the next step with a single question

## After Completing a Work Session

When the user completes a task or reaches a natural stopping point, prompt them:

---

**Session complete.**

To save progress and prepare for the next session, run `/issue-update-progress`.

---
