# PRD #19: YOLO Mode PRD Skills

**Status**: Planning
**Priority**: High
**Created**: 2026-02-25
**GitHub Issue**: [#19](https://github.com/wiggitywhitney/claude-config/issues/19)
**Context**: The 7 PRD skills (prd-create, prd-start, prd-next, prd-update-progress, prd-update-decisions, prd-done, prd-close) have excessive human-in-the-loop confirmation points that slow down workflow. All global skills are symlinks into this repo, so rewriting the active SKILL.md files updates all projects at once.

---

## Problem

The PRD skills were originally written with a cautious, interactive style — asking for confirmation at nearly every step. In practice, most of these checkpoints add latency without adding value. The user already has YOLO mode instructions in their CLAUDE.md ("Proceed without trivial confirmations"), but the skill prompts themselves override that intent by explicitly instructing Claude to stop and ask.

Key friction points by skill:
- **prd-create**: 10 discussion questions, section-by-section walkthrough, "enter 1 or 2" at the end
- **prd-update-progress**: Presents full progress report and waits for confirmation before applying changes, handles "partial acceptance" scenarios
- **prd-done**: 7 separate "present proposal and ask" moments for PR information, "Ready to create PR?" gate
- **prd-next**: "Do you want to work on this task?" confirmation before proceeding
- **prd-close**: "Proceed with closure?" confirmation

## Solution

Archive the current skill versions as inert reference files (e.g., `SKILL.v1-careful.md`) within each skill directory, then rewrite the active `SKILL.md` files to operate autonomously. The rewritten skills should make their own decisions and only stop for genuinely ambiguous situations or decisions with major implications — consistent with the YOLO mode philosophy already in CLAUDE.md.

Since all global skills are symlinks pointing into this repo's `.claude/skills/` directories, rewriting the files here updates every project automatically.

## Design Principles for YOLO Skills

1. **Act, don't ask** — If the skill has enough context to make a decision, make it. Present what you did, not what you're about to do.
2. **Batch over drip** — Instead of presenting information one piece at a time and waiting, gather everything and present a single summary at the end.
3. **Only stop for ambiguity** — Pause only when there's genuine uncertainty that the user needs to resolve, or when the decision has major/irreversible implications.
4. **Preserve the workflow** — Keep the same logical steps and quality standards. YOLO mode means fewer pauses, not less rigor.
5. **Show your work** — When making autonomous decisions, briefly note what you decided and why, so the user can course-correct if needed.

## Skill-by-Skill Changes

### prd-create
**Current**: Ask user to describe feature → discuss with 10 questions → section-by-section PRD authoring → present options 1 or 2
**YOLO**: If the user provided a feature description (via args or conversation), skip the interview. Draft the full PRD in one pass. Create the issue, write the PRD, update the issue link, and commit — presenting the finished result. Only ask clarifying questions if the feature description is genuinely ambiguous.

### prd-start
**Current**: Already fairly lean. Auto-detects PRD, validates readiness, creates branch, stops with "run /prd-next".
**YOLO**: Remove the readiness checklist display (it's informational noise). After branch setup, automatically invoke `/prd-next` logic instead of telling the user to run it separately.

### prd-next
**Current**: Recommends a task → "Do you want to work on this task?" → waits → design discussion → implementation → "run /prd-update-progress"
**YOLO**: Recommend the task and immediately proceed into design discussion. Skip the confirmation gate. After presenting the implementation approach, begin implementation. When done, automatically invoke `/prd-update-progress` logic instead of telling the user to run it. **Termination**: Only chain to `/prd-update-progress` if unchecked milestone tasks remain; when all tasks are done, present a completion summary and halt.

### prd-update-progress
**Current**: Full progress report → wait for confirmation → apply changes → "run /prd-next"
**YOLO**: Analyze progress, apply updates to PRD checkboxes based on evidence, commit, and present a summary of what was updated. Only pause if there's a genuine divergence between implementation and plan that needs a decision. After committing, automatically invoke `/prd-next` logic only if unchecked milestone tasks remain; otherwise present a completion summary and halt.

### prd-update-decisions
**Current**: "Ask the user which PRD to update" → analyze → update
**YOLO**: Already low friction. Auto-detect PRD (same as other skills). Apply updates and present summary.

### prd-done
**Current**: 7 "propose and ask" moments for PR info → "Ready to create PR?" → wait for CodeRabbit → present findings → merge steps
**YOLO**: Auto-fill all PR information from PRD and git analysis. Create the PR without asking for confirmation on each field. Wait for CodeRabbit, then address all feedback autonomously (following existing CLAUDE.md rules: explain issue, give recommendation, follow recommendation). Only stop for truly ambiguous CodeRabbit feedback or major architectural concerns.

### prd-close
**Current**: "Proceed with closure?" confirmation → various verification steps
**YOLO**: If closure reason is provided, proceed without confirmation. Update PRD, archive, close issue, commit, and present summary.

## Milestones

- [ ] Archive current skill versions as `SKILL.v1-careful.md` in each skill directory (7 files)
- [ ] Rewrite prd-create SKILL.md for YOLO mode
- [ ] Rewrite prd-start SKILL.md for YOLO mode
- [ ] Rewrite prd-next SKILL.md for YOLO mode
- [ ] Rewrite prd-update-progress SKILL.md for YOLO mode
- [ ] Rewrite prd-update-decisions SKILL.md for YOLO mode
- [ ] Rewrite prd-done SKILL.md for YOLO mode
- [ ] Rewrite prd-close SKILL.md for YOLO mode
- [ ] Test YOLO skills end-to-end on a real PRD workflow

## Decision Log

| # | Decision | Date | Rationale |
|---|----------|------|-----------|
| 1 | Archive in-place rather than separate directory | 2026-02-25 | Keeps careful version co-located with its skill for easy reference. `SKILL.v1-careful.md` is ignored by Claude Code which only loads `SKILL.md`. |
| 2 | Rewrite in-place rather than creating separate `-yolo` skills | 2026-02-25 | Avoids skill name collisions (both global and project skills with same name show up as duplicates). Avoids doubling the skill list. All projects benefit automatically via symlinks. |
| 3 | Preserve workflow steps, remove only pause points | 2026-02-25 | YOLO means fewer pauses, not less rigor. Same logical flow, same quality standards, just autonomous execution. |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| YOLO skills make wrong autonomous decisions | Medium | Low | Archived careful versions can be restored. User can interrupt at any time. Skills still explain what they decided. |
| Skills become too terse/miss context | Low | Medium | "Show your work" principle — skills present summaries of autonomous decisions so user stays informed. |
| Some projects need careful mode | Low | Low | Copy `SKILL.v1-careful.md` → project-level `.claude/skills/prd-*-careful/SKILL.md` for opt-in careful mode on specific projects. **Note**: This changes invocation names (e.g., `/prd-create-careful` instead of `/prd-create`). To preserve original names, copy the careful SKILL.md into a directory matching the original skill name at the project level, which overrides the global symlink. |
| prd-next / prd-update-progress loop runs unbounded | Low | Medium | Skills must check for remaining unchecked milestone tasks before chaining; present a completion summary and halt when all tasks are done. |
