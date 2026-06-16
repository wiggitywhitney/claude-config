---
name: issue-update-progress
description: Post a structured checkpoint comment to the relevant issue and commit current code state
category: project-management
---

# Issue Update Progress Slash Command

## Instructions

You are helping save progress on active issue work. This command synthesizes what got done and what comes next from conversation context and git history, proposes a structured checkpoint comment for the relevant GitHub issue, and commits the current code state.

## Process Overview

1. **Identify Working Set** - Extract issue numbers from the current branch name
2. **Identify Relevant Issue** - Determine which issue receives the checkpoint comment
3. **Synthesize Progress** - Derive done/next/questions from context and git log; propose for confirmation
4. **Post Checkpoint Comment** - Post the approved comment to the relevant issue
5. **Commit** - Stage all working changes and commit
6. **Confirm** - Output the comment URL and commit SHA
7. **CodeRabbit CLI Review** - Local review to catch issues before they accumulate
8. **Decision Awareness Check** - Capture any design decisions made this session
9. **Handoff Verification** - Ensure a cold AI can pick up where this session left off
10. **Continue to Next Task** - Prompt user to run /issue-next

## Checkpoint Comment Format

The following format is the contract that `/issue-next` reads. Document it exactly — `/issue-next` matches the literal string `## Progress Checkpoint` at the start of a comment body and parses the fields by name.

```markdown
## Progress Checkpoint

**Branch**: `feature/<numbers>-<description>`
**Done**:
- [bullet per completed item since last checkpoint]

**Next step**: [one concrete next action]

**Open questions** (optional):
- [question if any]
```

The comment is posted with `gh issue comment <number> --body "..."`. The most recent comment whose body begins with `## Progress Checkpoint` is what `/issue-next` reads.

## Step 1: Identify Working Set

```bash
git branch --show-current
```

Extract issue numbers from the branch name. Branch format: `feature/<numbers>-<description>` where `<numbers>` is a hyphen-separated list of issue numbers (e.g., `feature/98-101-autonomous-issue-execution` → issues 98 and 101).

## Step 2: Identify Relevant Issue

If the branch contains only one issue number, that is the relevant issue. Proceed to Step 3.

If the branch contains multiple issue numbers, ask the user: "Which issue is this checkpoint most relevant to?" Do NOT post to all issues in the set — post to the relevant issue only.

Wait for the user's answer before proceeding.

## Step 3: Synthesize Progress

**Use conversation context first** — look for recently discussed completions, implemented features, file creation mentions, test completions, and user confirmations ("that works", "done", "ready for next").

**Fall back to git log** if conversation context is insufficient:

```bash
git log --oneline -10
```

From the gathered context, derive:
- **Done**: what got completed since the last checkpoint
- **Next step**: one concrete next action
- **Open questions**: anything deferred, unresolved, or worth preserving across sessions

Compose the full checkpoint comment body using the format from the "Checkpoint Comment Format" section above.

**Propose the complete checkpoint comment body to the user for confirmation.** If the user edits the proposal, apply their edits before posting. Do not post the comment until the user approves the final text.

## Step 4: Post Checkpoint Comment

Post the approved comment to the relevant issue:

```bash
gh issue comment <number> --body "<approved checkpoint comment>"
```

Output the comment URL after posting.

## Step 5: Commit

Before committing, check if `PROGRESS.md` exists in the repository root. If it does, add a feature-level entry under `## [Unreleased]` using the appropriate category (`### Added`, `### Changed`, `### Fixed`). Entry format: `- (YYYY-MM-DD) [description of what changed and why, written for an external reader]`. Stage `PROGRESS.md` with the rest of the commit.

Stage all working changes and commit:

```bash
git add .
git status
git commit -m "feat(<scope>): <brief description of completed work>

- [brief list of key implementation achievements]"
```

The commit message describes what changed in code. The checkpoint comment (Step 4) describes work state. Both are needed.

**Note**: Do NOT push commits unless explicitly requested by the user.

## Step 6: Confirm

Output:
- The comment URL (from Step 4)
- The commit SHA

## Step 7: CodeRabbit CLI Review

After committing, run a local CodeRabbit CLI review to catch issues before they accumulate.

```bash
coderabbit review --plain --type committed --base origin/main
```

If `coderabbit` is not installed, skip this step with a note: "CodeRabbit CLI not installed — skipping local review."

**Handle findings:**
- **If findings exist**: Present findings to the user for triage. Apply the CodeRabbit triage rubric (see CLAUDE.md) — fix or skip each finding with rationale. Commit fixes, then re-run the review to confirm clean.
- **If no findings**: Proceed to next steps.

## Step 8: Decision Awareness Check

Assess whether any design decisions emerged during this session — architecture changes, scope adjustments, technical discoveries, or approach pivots. If any did, run `/issue-update-decisions` to capture them before moving on. This ensures decisions are recorded and propagated to downstream issues and PRDs while context is fresh.

## Step 9: Handoff Verification

The next AI instance reads the issue and git log cold — no memory of this session. Before suggesting `/clear`, complete each of the following. This step is not a self-assessment; it is work.

**Decisions** — Scan this conversation for non-obvious choices: pivots, rejected alternatives, constraints discovered mid-implementation. For each one not yet in the issue body or a code comment, write it there now.

**PROGRESS.md** — Check PROGRESS.md. If today's changes aren't reflected, add the entry now.

**Open questions** — Scan this conversation for anything deferred or unresolved. Each must exist in the issue body, a code TODO, or a GitHub issue before `/clear`. Create it now if it doesn't.

**Next task's entry point** — Read the "Next step" field in the checkpoint comment just posted. Could a cold AI instance start it with only the issue body, the checkpoint comment, and the codebase? If the next step relies on context from this session — an approach to avoid, an API quirk, a file that must be read first — add that context to the issue body now via `gh issue edit`.

**Workarounds and gotchas** — Scan this conversation for tooling quirks, failed approaches, or non-obvious constraints. For each one not yet in a rule file, issue comment, or code comment, write it there now.

Step 9 is done when all five actions are complete, not when they have been assessed.

## Step 10: Next Steps

---

**Progress checkpoint posted and committed.**

To resume this work in a fresh session:
1. Clear/reset the conversation context
2. Run `/issue-next` to reconstruct context from the checkpoint comment and git log

---
