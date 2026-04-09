# PRD #65: Code Review Plugin Evaluation

## Problem

CodeRabbit rate limits block the review cycle. When limits are hit, there is no fallback — work stalls waiting for the limit to reset. A supplemental code review capability is needed for these gaps.

A Code Review plugin already exists in the Claude Code plugin ecosystem. The right first step is to evaluate whether it covers the use case as-is, before building anything new.

## Solution

Run a research spike to evaluate the Code Review plugin. Based on findings, either:
- **Use the plugin as-is** — install it and wire it into the workflow
- **Build a custom `/review-pr` skill** — drawing on the plugin's patterns where useful

The research spike decides. Implementation follows the decision.

## Success Criteria (Global)

- A clear decision is made: plugin vs. custom skill
- Whichever path is chosen is implemented and usable when CodeRabbit is rate-limited
- The workflow for invoking the supplement is documented

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
- `research/code-review-plugin-evaluation.md` exists with all four sections complete
- Recommendation names the tradeoff, not just the conclusion

### Milestone 2a: Wire Up the Plugin (if research recommends as-is)

Install and integrate the Code Review plugin into the workflow.

**Process:**
1. Install the plugin following its documented installation process
2. Verify it works against a real PR diff in this repo
3. Add a "Supplemental Review" section to `rules/hooks-reference.md` documenting: when to invoke it, the invocation command, and what to expect in the output

**Do NOT edit existing sections of hooks-reference.md** — add only.

**Success Criteria:**
- Plugin is installed and produces output against a real PR
- "Supplemental Review" section added to hooks-reference.md

### Milestone 2b: Build a Custom `/review-pr` Skill (if research recommends custom)

Build a custom skill using patterns learned from the plugin study.

**Process:**
1. Read existing skills in `.claude/skills/` to understand the SKILL.md authoring conventions used in this repo before writing anything
2. Design the skill around the patterns from the Code Review plugin that are worth reusing — do not start from scratch
3. Write `SKILL.md` with: input (branch or PR number), process (read diff, produce findings), output format (file-grouped findings with severity: high/medium/low)
4. Run `/write-prompt` on the SKILL.md before finalizing
5. Test against a real PR diff in this repo
6. Document invocation in `rules/hooks-reference.md`

**Do NOT build a full CodeRabbit replacement.** Scope is: supplement when rate-limited, not parity.

**Success Criteria:**
- `/review-pr` skill exists and has passed `/write-prompt` review
- Produces findings with file grouping and severity levels against a real PR
- Invocation documented in hooks-reference.md

## Decision Log

### Decision 1: Research Spike Before Implementation (2026-04-09)
The Code Review plugin already exists — evaluating it before building anything avoids duplicating work. The research spike is a hard gate: no code is written until the spike produces a written recommendation. This prevents premature commitment to either path.
