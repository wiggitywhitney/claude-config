# PRD #65: Code Review Plugin Evaluation

## Problem

CodeRabbit rate limits block the review cycle. When limits are hit, there is no fallback — work stalls waiting for the limit to reset. A supplemental code review capability is needed.

Beyond the rate-limit gap: research (Decision 2) showed that CodeRabbit and the `code-review` plugin find *different* issue classes. On a real PR, CodeRabbit caught security and correctness issues; the plugin caught forward-compatibility gaps, convention inconsistencies, and historical context issues that CodeRabbit missed. Running both provides genuinely complementary coverage, not redundancy.

## Solution

~~Run a research spike to evaluate the Code Review plugin. Based on findings, either:~~
~~- **Use the plugin as-is** — install it and wire it into the workflow~~
~~- **Build a custom `/review-pr` skill** — drawing on the plugin's patterns where useful~~

Research spike complete (Milestone 1). Decision: integrate the `code-review` plugin as a permanent part of the PR review workflow — running on every PR alongside CodeRabbit, not just as a rate-limit fallback. No custom skill needed.

## Success Criteria (Global)

- ~~A clear decision is made: plugin vs. custom skill~~ ✓ (Decision 2: plugin as-is)
- `/code-review` is wired into the standard PR workflow and runs on every PR
- When CodeRabbit is rate-limited, `/code-review` provides full review coverage with no workflow stall
- Both `rules/git-workflow.md` and `rules/hooks-reference.md` document the updated workflow
- `/prd-done` SKILL.md and SKILL.v1-yolo.md each include a step to run `/code-review` immediately after PR creation

## Milestones

### Milestone 1: Research Spike — Evaluate the Code Review Plugin

**Do NOT write any skill code during this milestone.** Research only.

**Process:**
1. Locate the Code Review plugin source — check `~/.claude/plugins/` and search the Claude plugin registry
2. Read the plugin's SKILL.md or README: what does it do, how is it invoked, what output does it produce?
3. Test the plugin against a real PR diff in this repo to see actual output
4. Assess fit: does it produce findings at a useful granularity? Does it work without a CodeRabbit subscription? Does invocation fit naturally into the existing git workflow?
5. Write `research/code-review-plugin-evaluation.md` with these sections:
   - **What the plugin does** — invocation, input, output format
   - **Comparison to CodeRabbit** — what it covers, what it misses, output format differences
   - **Fit assessment** — answers to the three questions in step 4
   - **Recommendation** — one of: "use plugin as-is" or "build custom skill"; include the key tradeoff that drove the decision
6. Route based on recommendation: plugin as-is → Milestone 2a; build custom → Milestone 2b

**Success Criteria:**
- `research/code-review-plugin-evaluation.md` exists with all four sections complete ✓
- Recommendation names the tradeoff, not just the conclusion ✓

### Milestone 2a: Integrate Plugin Into Standard PR Workflow

Install and document `/code-review` as a permanent step in the PR review workflow — running on every PR, not just as a rate-limit fallback. (Decision 4)

**Process:**
1. ~~Install the plugin~~ — **already done** (`claude plugin install code-review`, 2026-04-13) (Decision 2). Note: user-scoped plugin installs are NOT globally accessible across all repos — the skill must also be created in claude-config and symlinked globally (Decision 7).
2. Create `.claude/skills/code-review/SKILL.md` in claude-config. Copy the content from `~/.claude/plugins/cache/claude-plugins-official/code-review/unknown/commands/code-review.md` verbatim (including the frontmatter). Then add `~/.claude/skills/code-review` as a symlink pointing to `claude-config/.claude/skills/code-review`, following the same pattern as anki, research, write-docs, etc. (Decision 7)
3. ~~Verify it works against a real PR diff~~ — **already done** during Milestone 1; PR #79 diff, 3 real findings (Decision 2)
4. Update `rules/git-workflow.md` — insert a new bullet immediately before the existing "After creating a PR, start a background sleep timer (7 minutes)..." line. The new bullet should say: after creating a PR, immediately run `/code-review` in the session. Note that `/code-review` and CodeRabbit find different issue classes (CLAUDE.md compliance / bugs / historical context vs. security / correctness) — address both finding sets before merging. If CodeRabbit is rate-limited and never posts, `/code-review` provides full coverage; do not block the merge indefinitely waiting for CodeRabbit. (Decision 4)
5. Add a `## Supplemental Code Review` section at the end of `rules/hooks-reference.md` (after the existing `## PostToolUse hooks` section). Frame it as an instruction to the implementing AI, not passive documentation: "Immediately after creating a PR, run `/code-review` in the session." Include: the plugin name and install status (available in all sessions via skill symlink), when it runs (every PR, immediately after creation — not pre-push, which requires an open PR), what to expect in the output (confidence-scored findings ≥80 threshold, grouped by: CLAUDE.md compliance, bugs, historical context, code comments; GitHub permalink with full SHA per finding), and rate-limit behavior (if CodeRabbit is rate-limited, `/code-review` provides full coverage — do not block indefinitely on CodeRabbit). (Decisions 4, 6)
6. Update `.claude/skills/prd-done/SKILL.md` — locate the section where `gh pr create` is run and add a new step immediately after it: run `/code-review` using the Skill tool; review the findings and address any at or above the 80-confidence threshold before continuing; then start the 7-minute CodeRabbit timer as usual. Use the same phrasing and framing as the bullet added to `rules/git-workflow.md` in step 4. (Decision 5)
7. Apply the identical addition from step 6 to `.claude/skills/prd-done/SKILL.v1-yolo.md`. (Decision 5)

**Do NOT edit existing sections of either rules file** — add only.

**Note on `pr-review-toolkit`:** A second plugin runs 6 agents in-conversation for local pre-PR review (no GitHub posting). Not in scope for this milestone — `/code-review` only. (Decision 3)

**Note on pre-push hook:** The plugin requires an open PR and cannot run pre-push. The pre-push CodeRabbit CLI step is unchanged.

**Success Criteria:**
- Plugin is installed and produces output against a real PR ✓ (completed in Milestone 1)
- `.claude/skills/code-review/SKILL.md` exists in claude-config and `~/.claude/skills/code-review` is symlinked to it (Decision 7)
- `rules/git-workflow.md` includes "run `/code-review` immediately after PR creation" in the standard PR workflow
- `rules/hooks-reference.md` has a "Supplemental Code Review" section documenting invocation, output format, and rate-limit behavior

### Milestone 2b: ~~Build a Custom `/review-pr` Skill~~ — ELIMINATED

> **NOT THE CHOSEN PATH** — Eliminated by Decision 2 (plugin as-is) and Decision 4 (always-run-both). Do not implement.

## Decision Log

### Decision 1: Research Spike Before Implementation (2026-04-09)
The Code Review plugin already exists — evaluating it before building anything avoids duplicating work. The research spike is a hard gate: no code is written until the spike produces a written recommendation. This prevents premature commitment to either path.

### Decision 2: Use Plugin As-Is → Milestone 2a (2026-04-13)
Milestone 1 research spike complete. Recommendation: use the `code-review` plugin as-is rather than building a custom skill. The plugin was tested against PR #79 diff and found 3 real issues above the 80-confidence threshold — findings that were different from (not duplicates of) CodeRabbit's findings on the same PR. Key tradeoff: manual invocation via `/code-review` vs. CodeRabbit's automatic pre-push triggering, but manual invocation is acceptable for a fallback tool. The plugin is already installed (`claude plugin install code-review`, 2026-04-13). Full findings in `research/code-review-plugin-evaluation.md`.

### Decision 3: `pr-review-toolkit` Is Complementary, Not a Substitute (2026-04-13)
A second plugin discovered during research, `pr-review-toolkit`, runs 6 specialized agents in-conversation for local pre-PR review. It does not post GitHub comments. It is a different tool for a different use case (local pre-commit review vs. post-push PR supplement) and is not part of this PRD's scope. The `hooks-reference.md` documentation should focus on `/code-review`; `pr-review-toolkit` may be mentioned as a footnote if useful context.

### Decision 4: Run `/code-review` on Every PR, Always — Not Just as Fallback (2026-04-13)
The original framing treated `/code-review` as a rate-limit fallback. Research showed CodeRabbit and the plugin find different issue classes (CodeRabbit: security/correctness; plugin: forward-compatibility, convention consistency, historical context) — making them genuinely complementary, not redundant. The updated workflow: after creating a PR, immediately run `/code-review` in the session, then start the 7-minute CodeRabbit timer as before. Both sets of findings are addressed before merge. If CodeRabbit is rate-limited, `/code-review` provides full coverage and work does not stall. The pre-push CodeRabbit CLI step is unchanged (plugin requires an open PR and cannot run pre-push). Milestone 2b (custom skill) is eliminated — it was only needed if the plugin was rejected, which it was not.

### Decision 5: `/prd-done` Skill Must Include a Run `/code-review` Step (2026-04-13)
Skills are where the implementing AI receives procedural step-by-step instructions. Rules files are passive context that Claude reads but does not act on procedurally. Updating only `rules/git-workflow.md` would inform Claude that `/code-review` should run but would not reliably trigger it during the `/prd-done` workflow. The fix: add an explicit step in both `SKILL.md` and `SKILL.v1-yolo.md` immediately after `gh pr create`, instructing Claude to run `/code-review` before starting the CodeRabbit timer.

### Decision 6: `hooks-reference.md` Addition Must Be Instructional, Not Documentary (2026-04-13)
The original plan framed the `hooks-reference.md` section as passive documentation (what the plugin is, what it outputs). Passive framing does not produce the behavior — the implementing AI reads it as reference and may not act. The section must be written as an imperative instruction: "Immediately after creating a PR, run `/code-review` in the session." Documentation detail (output format, rate-limit behavior) follows as supporting context, not the primary frame.

### Decision 7: User-Scoped Plugin Installs Are Not Globally Accessible — Use Skill Symlink Pattern (2026-04-13)
Confirmed via live test: `/code-review` fails with "Unknown Skill: code-review" in repos other than claude-config (observed in spinybacked-orbweaver). The PRD's assumption in Decision 2 that user-scoped = globally available was incorrect. Fix: create `.claude/skills/code-review/SKILL.md` in claude-config with the plugin command content verbatim, then add `~/.claude/skills/code-review` as a symlink pointing to it. This follows the identical pattern used for anki, research, write-docs, and other globally available skills. The plugin install (`claude plugin install code-review`) is retained as-is; the skill file is the access mechanism.
