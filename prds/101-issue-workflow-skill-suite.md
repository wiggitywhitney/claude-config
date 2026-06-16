# PRD #101: Issue Workflow Skill Suite

**Status**: Draft
**Created**: 2026-06-16
**Issue**: https://github.com/wiggitywhitney/claude-config/issues/101

## Problem

The PRD skill suite (/prd-create, /prd-start, /prd-next, /prd-update-progress, /prd-update-decisions, /prd-done) provides a complete interactive workflow for PRD-driven development: create, start, resume with context, save progress, update based on decisions, and close. No equivalent suite exists for GitHub issue work.

The current issue-juggling workflow (`rules/issue-juggling.md`) is fully manual: the user creates each branch, directs implementation, and manages context between sessions without skill-level support. There is no way to save progress mid-issue for a fresh session, no guided juggling pair recommendation, no structured decision cascade, and no skill-driven close-out flow.

## Solution

Six skills that mirror the PRD suite, adapted for GitHub issues:

- `/issue-create` — draft, polish, and create a well-formed GitHub issue
- `/issue-start` — recommend juggling pairs, user decides, create correctly-named branch
- `/issue-update-progress` — post a structured checkpoint comment to the relevant issue + commit
- `/issue-next` — fresh session pickup using the most recent checkpoint comment + git log
- `/issue-update-decisions` — update issue body with a decision, cascade to all open issues and PRDs
- `/issue-done` — close issue(s), clean local and remote branches, update PROGRESS.md

All six skills are globally available via symlinks from `~/.claude/skills/` pointing into `claude-config/.claude/skills/`.

## Milestones

- [x] M1: `/issue-create` skill
- [ ] M2: `/issue-start` skill
- [ ] M3: `/issue-update-progress` skill (defines checkpoint comment format)
- [ ] M4: `/issue-next` skill
- [ ] M5: `/issue-update-decisions` skill
- [ ] M6: `/issue-done` skill
- [ ] M7: Global symlinks — install all six in `~/.claude/skills/`

> **Constraint for all SKILL.md files produced by this PRD**: Each SKILL.md must lead with numbered workflow steps, not a goal statement or purpose summary. Do NOT open any SKILL.md with a description of what the skill does — start directly with the numbered process steps. This is required for all AI-consumed skill documents per CLAUDE.md ("emphasize the process to follow rather than stating the goal upfront").

---

### M1: `/issue-create` skill

**Step 0:** Duplicate `.claude/skills/prd-create/SKILL.md` verbatim as the starting point — copy it to `.claude/skills/issue-create/SKILL.md`, then edit minimally to adapt it for issues (Decision 8). Do not write from scratch. Before removing any section from the duplicated skill, verify it has no equivalent in the issue context — when in doubt, ask (Decision 9). Read the global CLAUDE.md "GitHub Issues" section (run `/write-prompt` before `gh issue create`; every issue body must end with a PROGRESS.md checkbox).

**What:** Create `.claude/skills/issue-create/SKILL.md` — a skill that guides the user through drafting a well-formed GitHub issue, runs `/write-prompt` on the draft, then creates it via `gh issue create`.

**Why:** The global CLAUDE.md already mandates running `/write-prompt` before any `gh issue create` and including a PROGRESS.md checkbox. Today that requires the user to remember these steps manually. `/issue-create` makes the correct process the default: gather the problem and solution from the user, draft the issue body with the required structure, apply `/write-prompt`, then create the issue.

**To implement:**

Write `.claude/skills/issue-create/SKILL.md` with the following workflow steps:

1. **Gather** — Ask the user: what is the problem this issue addresses? (Ask one question at a time per the CLAUDE.md rule on multiple questions.) Follow up: what is the solution approach? Any known acceptance criteria?
2. **Draft** — Produce a well-formed issue body:
   - `## Problem` section (1-3 sentences describing the problem)
   - `## Solution` section (1-3 sentences with key constraints if known)
   - `## Acceptance Criteria` section (checklist if the user provided criteria; omit if not)
   - Final checklist item: `- [ ] Update PROGRESS.md with a changelog entry`
3. **Review** — Invoke `/write-prompt` on the draft before creating the issue. Apply all high-severity findings.
4. **Create** — Run `gh issue create` with the polished body. Add relevant labels if applicable.
5. **Confirm** — Output the issue URL and number.

Run `/write-prompt` on the completed SKILL.md before committing. Apply all high-severity findings.

**Success criteria:**
- `.claude/skills/issue-create/SKILL.md` exists and passes `/write-prompt` review with no high-severity findings
- Running `/issue-create` produces a GitHub issue whose body includes a PROGRESS.md checkbox and has been reviewed by `/write-prompt`
- Manually verified: invoke the skill, walk through a real issue creation, confirm the resulting issue body is well-formed

---

### M2: `/issue-start` skill

**Step 0:** Duplicate `.claude/skills/prd-start/SKILL.md` verbatim as the starting point — copy it to `.claude/skills/issue-start/SKILL.md`, then edit minimally to adapt it for issues (Decision 8). Do not write from scratch. Before removing any section from the duplicated skill, verify it has no equivalent in the issue context — when in doubt, ask (Decision 9). Read `rules/issue-juggling.md` (the workflow this skill initiates). Read Decision 4 and Decision 5 in the Decision Log below (branch naming convention and the two-phase juggling flow).

**What:** Create `.claude/skills/issue-start/SKILL.md` — a skill that analyzes open issues for juggling candidates, presents recommendations, waits for the user to decide the working set, then creates a correctly-named branch.

**Why:** The current juggling workflow requires the user to manually decide which issues to work together and create the branch. `/issue-start` adds two things the manual flow lacks: (1) structured analysis of which issues cluster well (related domain, similar scope, no blocking dependency between them), and (2) correct branch naming that encodes both the issue numbers and a semantic description. Branch naming must come AFTER the juggling decision is made because the branch name includes all issue numbers in the working set.

**To implement:**

Write `.claude/skills/issue-start/SKILL.md` with the following workflow steps:

1. **Read input** — The user provides one or more issue numbers to start with. If only one is provided, proceed to analyze juggling candidates.
2. **Analyze** — Fetch all open issues with `gh issue list --state open --json number,title,body,labels`. Identify issues that cluster well with the provided issue(s) based on: related domain, similar implementation scope, and no blocking dependency between them. Surface 1-3 juggling suggestions with brief rationale for each pairing. If no good candidates exist, state that clearly so the user can proceed solo.
3. **Wait for decision** — Present suggestions and ask: work this issue alone, or with one of the suggested partners? User picks the working set before the branch is created.
4. **Create branch** — Name the branch `feature/<issue-numbers>-<semantic-description>` where `<issue-numbers>` is a hyphen-separated list of all issue numbers in the set and `<semantic-description>` is a short kebab-case summary. Examples: `feature/98-101-autonomous-issue-execution`, `feature/42-fix-auth-token-handling`. For a single issue: `feature/42-fix-auth-token-handling`.
5. **Confirm** — Output the branch name and the full working set. Remind the user to run `/issue-update-progress` at natural stopping points to preserve context for fresh sessions.

Run `/write-prompt` on the completed SKILL.md before committing.

**Success criteria:**
- `.claude/skills/issue-start/SKILL.md` exists and passes `/write-prompt` review
- Branch created by the skill follows the convention: `feature/<numbers>-<description>`
- Skill presents juggling analysis before creating the branch
- Manually verified: invoke on a real open issue, confirm the juggling suggestions are sensible and the branch name is correctly formed

---

### M3: `/issue-update-progress` skill (defines checkpoint comment format)

**Step 0:** Duplicate `.claude/skills/prd-update-progress/SKILL.md` verbatim as the starting point — copy it to `.claude/skills/issue-update-progress/SKILL.md`, then edit minimally to adapt it for issues (Decision 8). Do not write from scratch. Before removing any section from the duplicated skill, verify it has no equivalent in the issue context — when in doubt, ask (Decision 9). Read Decision 2 and Decision 3 in the Decision Log below (why comments over body edits; checkpoint goes to the relevant issue only). Note: the checkpoint comment format defined in this milestone is the contract that M4 (`/issue-next`) reads. Document it clearly in the SKILL.md so M4's implementer has an unambiguous reference.

**What:** Create `.claude/skills/issue-update-progress/SKILL.md` — a skill that posts a structured checkpoint comment to the relevant issue and makes a git commit capturing current code state.

**Why:** Without a structured mid-session save, context is lost when the window fills or the user switches to a fresh session. Storing progress in a GitHub issue comment (not body edits) means it survives local machine loss, is accessible without the repo, and is append-only so it does not trigger GitHub body-edit notifications. The commit message records what changed in code; the checkpoint comment records where work stands and what comes next.

**Checkpoint comment format** (this format is the M4 contract — document it verbatim in the SKILL.md):

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

**To implement:**

Write `.claude/skills/issue-update-progress/SKILL.md` with the following workflow steps:

1. **Identify the working set** — Read `git branch --show-current` to extract issue numbers from the branch name (format: `feature/<numbers>-<description>`).
2. **Identify the relevant issue** — If the branch contains multiple issue numbers, ask the user which issue this checkpoint is most relevant to. (Per Decision 3: post to the relevant issue only, not all issues in the set.)
3. **Gather progress** — Ask the user: what got done since the last checkpoint? What is the next concrete step? Any open questions to preserve?
4. **Post comment** — Format and post the checkpoint comment using the format specified above via `gh issue comment`.
5. **Commit** — Stage all working changes and commit. The commit message describes what changed in code; the checkpoint comment describes work state. Both are needed.
6. **Confirm** — Output the comment URL and commit SHA.

Run `/write-prompt` on the completed SKILL.md before committing.

**Success criteria:**
- `.claude/skills/issue-update-progress/SKILL.md` exists and passes `/write-prompt` review
- The checkpoint comment format is documented verbatim in the SKILL.md (not just described) so M4's implementer can rely on it
- Manually verified: invoke the skill, confirm the comment appears on the correct issue in the expected format, confirm the commit is made

---

### M4: `/issue-next` skill

**Step 0:** Duplicate `.claude/skills/prd-next/SKILL.md` verbatim as the starting point — copy it to `.claude/skills/issue-next/SKILL.md`, then edit minimally to adapt it for issues (Decision 8). Do not write from scratch. Before removing any section from the duplicated skill, verify it has no equivalent in the issue context — when in doubt, ask (Decision 9). Read the checkpoint comment format in M3's completed SKILL.md before starting. The format defined there is the parsing contract for this skill — the sentinel is the literal string `## Progress Checkpoint` at the start of a comment body; do not match partial strings or variations. This milestone gates on M3 being committed.

**What:** Create `.claude/skills/issue-next/SKILL.md` — a skill that reconstructs working context for a fresh session by reading the most recent checkpoint comment on the active issue plus recent git log.

**Why:** When context fills and the user starts a fresh session, they should not have to re-explain where they left off. `/issue-next` does the reconstruction automatically: identifies the active branch, extracts the issue(s) from the branch name, fetches the most recent checkpoint comment, reads the recent git log, and synthesizes a "here is where we are, here is what is next" brief. This is the complement to `/issue-update-progress` — together they make mid-issue session transitions seamless.

**To implement:**

Write `.claude/skills/issue-next/SKILL.md` with the following workflow steps:

1. **Identify context** — Run `git branch --show-current`. Extract issue numbers from the branch name (format: `feature/<numbers>-<description>`). Fetch issue titles with `gh issue view <number> --json title`.
2. **Fetch checkpoint** — Run `gh issue view <number> --comments --json comments` for each issue number extracted from the branch name. Find the most recent comment beginning with `## Progress Checkpoint` across all of them. Use the issue with the most recent such comment as the context source. If no checkpoint comment exists on any issue, note this and proceed with git log only.
3. **Read git log** — Run `git log --oneline -10` to capture recent commits.
4. **Synthesize brief** — Present a structured context summary:
   - Active issue(s): numbers and titles
   - What was done (from the checkpoint's Done section)
   - The next concrete step (from the checkpoint's Next step field)
   - Any open questions preserved from the last session
   - Recent commits for additional code context
5. **Transition** — Ask: ready to continue with the next step, or adjust the plan first?

Run `/write-prompt` on the completed SKILL.md before committing.

**Success criteria:**
- `.claude/skills/issue-next/SKILL.md` exists and passes `/write-prompt` review
- Skill correctly parses the checkpoint comment format defined in M3
- Manually verified: run `/issue-update-progress` to create a checkpoint, open a fresh session, run `/issue-next`, confirm the brief accurately reflects where work left off

---

### M5: `/issue-update-decisions` skill

**Step 0:** Duplicate `.claude/skills/prd-update-decisions/SKILL.md` verbatim as the starting point — copy it to `.claude/skills/issue-update-decisions/SKILL.md`, then edit minimally to adapt it for issues (Decision 8). Do not write from scratch. Before removing any section from the duplicated skill, verify it has no equivalent in the issue context — when in doubt, ask (Decision 9). Read the global CLAUDE.md "Decision cascade" section. Read Decision 6 in the Decision Log below (cascade scope is all open issues and PRDs, same as the PRD equivalent).

**What:** Create `.claude/skills/issue-update-decisions/SKILL.md` — a skill that records a design decision in the active issue's body, then scans all other open issues and PRDs for impact and proposes updates.

**Why:** Design decisions made during issue work often affect other in-flight work. The PRD skill suite handles this via `/prd-update-decisions` which cascades to other PRDs and issues. The issue equivalent works at the same scope: any decision that changes how an issue should be solved might affect another open issue or PRD. Not cascading leaves related work inconsistent and forces rediscovery later.

**To implement:**

Write `.claude/skills/issue-update-decisions/SKILL.md` with the following workflow steps:

1. **Capture the decision** — Ask the user: what was decided? What alternatives were considered? What is the rationale?
2. **Update the active issue** — Append a `## Decision Log` section (or add to an existing one) in the issue body via `gh issue edit`. Format each entry as: `**[YYYY-MM-DD] [Short decision title]**: [description]. **Why**: [rationale]. **Alternatives**: [what was considered and rejected].`
3. **Scan for impact** — Fetch all open issues (`gh issue list --state open --json number,title,body`) and read all PRD files in `prds/*.md`. For each, assess whether the decision affects their stated solution approach, acceptance criteria, or assumptions.
4. **Present findings** — For each affected issue or PRD, describe specifically what needs updating and propose the exact update. Present one at a time (per CLAUDE.md rule on multiple questions).
5. **Apply updates** — With user confirmation for each, apply updates: `gh issue edit` for issues, Edit tool for PRD files.

Cascade scope is all open issues and PRDs, not just the current juggling set. This matches the scope of `/prd-update-decisions`.

Run `/write-prompt` on the completed SKILL.md before committing.

**Success criteria:**
- `.claude/skills/issue-update-decisions/SKILL.md` exists and passes `/write-prompt` review
- Cascade scope confirmed to be all open issues and all PRD files
- Manually verified: record a real decision, run the skill, confirm the cascade analysis surfaces related items and updates are applied correctly

---

### M6: `/issue-done` skill

**Step 0:** Duplicate `.claude/skills/prd-done/SKILL.md` verbatim as the starting point — copy it to `.claude/skills/issue-done/SKILL.md`, then edit minimally to adapt it for issues (Decision 8). Do not write from scratch. Before removing any section from the duplicated skill, verify it has no equivalent in the issue context — when in doubt, ask (Decision 9). Read `rules/git-workflow.md` for the full CodeRabbit + `/code-review` gate that must be honored before merge. Read `rules/issue-juggling.md` for expected end state.

**What:** Create `.claude/skills/issue-done/SKILL.md` — a skill that closes out one or more issues on the current branch: creates a PR if one does not exist, runs the full CodeRabbit + `/code-review` review gate, merges, closes all issues in the working set, deletes local and remote branches, and updates PROGRESS.md.

**Why:** Closing out issue work involves several steps that are easy to miss manually: closing all issues on a multi-issue branch, deleting both local and remote branches, and updating PROGRESS.md. The skill makes the correct end state the default and ensures the CodeRabbit gate is not skipped.

**To implement:**

Write `.claude/skills/issue-done/SKILL.md` with the following workflow steps:

1. **Identify closing set** — Read `git branch --show-current` to extract all issue numbers from the branch name. Fetch each issue's title and confirm they are open.
2. **Check PR status** — If no open PR exists for this branch, create one via `gh pr create` following `rules/git-workflow.md` (use `--label run-acceptance` if `.github/workflows/acceptance-gate.yml` exists).
3. **Review gate** — Follow the full review flow from `rules/git-workflow.md`: start a 7-minute background timer for CodeRabbit, fetch findings from all three channels once the timer fires, address findings, run `/code-review` per the exceptions in git-workflow.md. Do not proceed to merge until the review gate is passed and the human approves.
4. **Merge** — Merge the PR via `gh pr merge`.
5. **Close issues** — For each issue number from the branch name, run `gh issue close <number>`.
6. **Clean branches** — Delete the local branch (`git branch -d <branch>`) and remote branch (`git push origin --delete <branch>`). Switch to main and pull (`git checkout main && git pull`).
7. **Update PROGRESS.md** — Add a changelog entry under the appropriate section describing what changed and why. Follow the PROGRESS.md style rules in global CLAUDE.md.
8. **Update ROADMAP.md** — If the closed issue(s) appear in `docs/ROADMAP.md`, remove those entries (ROADMAP is forward-looking; completed work belongs in PROGRESS.md only).
9. **Confirm** — Output which issues were closed, the PR URL, and confirm branch cleanup.

Multi-issue handling: close all issues whose numbers appear in the branch name. If an issue was added to the branch mid-work but is not in the branch name, the user must specify it explicitly when invoking the skill.

Run `/write-prompt` on the completed SKILL.md before committing.

**Success criteria:**
- `.claude/skills/issue-done/SKILL.md` exists and passes `/write-prompt` review
- Multi-issue branch handling: all issues in the branch name are closed
- CodeRabbit gate is documented as required before merge
- Manually verified: invoke on a real branch with an open PR, confirm all steps execute correctly

---

### M7: Global symlinks — install all six in `~/.claude/skills/`

**Step 0:** Run `ls -la ~/.claude/skills/` to see the current symlinks and confirm the pattern: `~/.claude/skills/<name>` pointing to `<absolute-path>/claude-config/.claude/skills/<name>`. Verify all six skill directories from M1-M6 exist in `claude-config/.claude/skills/` before creating symlinks.

**What:** Create symlinks for all six new issue skills in `~/.claude/skills/` so they are available in any repo, not only when working inside claude-config.

**Why:** The issue skills are used across all repos — that is the entire point of the suite. Skills in `claude-config/.claude/skills/` are only accessible from within the claude-config repo. Global symlinks in `~/.claude/skills/` follow the established pattern for all other globally available skills (anki, code-review, make-autonomous, etc.) and make the skills immediately usable in any project without per-repo setup.

**To implement:**

1. Confirm all six skill directories exist in `claude-config/.claude/skills/` (M1-M6 must be complete).

2. Create symlinks:
   ```bash
   ln -s /Users/whitney.lee/Documents/Repositories/claude-config/.claude/skills/issue-create ~/.claude/skills/issue-create
   ln -s /Users/whitney.lee/Documents/Repositories/claude-config/.claude/skills/issue-start ~/.claude/skills/issue-start
   ln -s /Users/whitney.lee/Documents/Repositories/claude-config/.claude/skills/issue-update-progress ~/.claude/skills/issue-update-progress
   ln -s /Users/whitney.lee/Documents/Repositories/claude-config/.claude/skills/issue-next ~/.claude/skills/issue-next
   ln -s /Users/whitney.lee/Documents/Repositories/claude-config/.claude/skills/issue-update-decisions ~/.claude/skills/issue-update-decisions
   ln -s /Users/whitney.lee/Documents/Repositories/claude-config/.claude/skills/issue-done ~/.claude/skills/issue-done
   ```

3. Verify each symlink resolves correctly: `ls -la ~/.claude/skills/issue-*`

4. Test from a non-claude-config repo: open a Claude Code session in a different repo and confirm the six issue skills appear in the available skills list.

5. Note in PROGRESS.md that the PRD skills (prd-create, prd-start, etc.) are also not globally symlinked — this is a separate gap not fixed by this PRD. Open a standalone issue for it so it is tracked.

**Success criteria:**
- Six symlinks exist in `~/.claude/skills/`, each resolving to the correct skill directory in claude-config
- All six skills accessible from a repo that is not claude-config (manually verified)
- PROGRESS.md updated
- Standalone issue opened for the PRD skills symlink gap

---

## Decision Log

| # | Decision | Alternatives Considered | Rationale |
|---|---|---|---|
| 1 | One PRD covers all six skills | One PRD per skill | Skills share a state model (checkpoint comment format, branch naming convention, juggling set concept) that must be designed cohesively. Separate PRDs would cause later skills to inherit earlier skills' state format decisions without having shaped them. |
| 2 | Progress stored in GitHub issue comments (not body edits) + git commits | Issue body edits; local file (gitignored or committed); git log only | Issue body is the problem statement; appending work logs clutters it and fires GitHub notifications on every body edit. Comments are append-only and do not trigger body notifications. Local files are either lost on machine change (if gitignored) or clutter the repo (if committed). Git log alone requires inference to answer "what is the next step." Comments survive machine loss and are accessible without the local repo. |
| 3 | Checkpoint comment goes to the relevant issue only | Post to all issues in the juggling set | Explicit user decision: "just the primary one, just the relevant one." The skill asks which issue when the working set contains multiple issues. |
| 4 | Branch naming: `feature/<issue-numbers>-<semantic-description>` | Issue numbers only; semantic description only | Both components are needed. Numbers give machine-readable issue identification (used by `/issue-done` to know which issues to close). Semantic description gives human readability. Example: `feature/98-101-autonomous-issue-execution`. |
| 5 | `/issue-start` recommends juggling pairs first, then creates branch | Create branch first, decide juggling later | Branch name encodes issue numbers, so the working set must be decided before the branch is created. Two-phase flow: analyze and recommend, user decides, then create branch. |
| 6 | `/issue-update-decisions` cascades to all open issues and PRDs | Cascade to juggling set only | Same scope as `/prd-update-decisions`. A design decision affecting one issue often affects other in-flight work regardless of whether it is in the current juggling set. Narrower scope would leave related work inconsistent. |
| 7 | Global symlinks in `~/.claude/skills/` from the start | Per-repo symlinks; available only in claude-config repo | Issue skills are used across all repos. PRD skills are not currently globally symlinked; that is a separate gap to track in its own issue, not fixed here. |
| 8 | All issue skill SKILL.md files are written by duplicating the corresponding PRD skill SKILL.md and editing minimally | Writing from scratch; writing "something similar" | The PRD skills are battle-tested and proven. Copying verbatim preserves working patterns, wording, and edge-case handling. Only change what must change to make the skill work for issues — nothing more. |
| 9 | Before removing any section from a duplicated PRD skill, verify it doesn't apply to the issue context — when in doubt, ask | Assuming a section is irrelevant and deleting it without checking | Sections that look PRD-specific may still have issue equivalents (e.g., ROADMAP.md updates). Silent deletions introduce gaps that are hard to detect. The cost of asking is low; the cost of a wrong deletion is a skill that silently skips required steps. |
