# PRD #52: Add /write-prompt Review Step to prd-create Skills

**Status**: Active
**Priority**: Medium
**Created**: 2026-04-05
**GitHub Issue**: [#52](https://github.com/wiggitywhitney/claude-config/issues/52)

## Problem

PRD milestones are de-facto prompts for future AI implementors. A future Claude reads each milestone as an instruction and executes it. If the milestone contains contradictory instructions, vague directives like "investigate X," or missing specifics about what to do and why, the implementing AI will make wrong choices — and the errors won't surface until implementation is underway.

The `prd-create` skill has no step that treats milestones as AI agent instructions and applies prompt-quality standards to them before the PRD is committed.

## Solution

Add a mandatory `/write-prompt` review step to both `prd-create` skill files (CLI and YOLO variants), placed after milestone definition and before the commit step. Also add a callout near the milestone guidance section so the author writes with the upcoming review in mind.

## Design Decisions

### Decision 1 — Unconditional, not optional (2026-04-05)
**Decision:** The `/write-prompt` step is added unconditionally — it runs on every PRD creation, not only when milestones seem complex.
**Rationale:** If the step is conditional, it gets skipped. Prompt quality review is fast and cheap relative to the cost of implementing against bad milestone instructions.
**Impact:** Both skill files add the step without any "if milestones are complex" qualifier.

### Decision 2 — Review milestones as AI agent instructions, not as project management text (2026-04-05)
**Decision:** The `/write-prompt` invocation explicitly frames the milestone text as AI agent instructions.
**Rationale:** The skill already says PRD milestones guide implementation. But without explicitly framing them as prompts, the write-prompt review might treat them as human-readable documentation and miss prompt-specific failure modes (missing specifics, vague directives, missing operationalization plan).
**Impact:** The workflow step says "Run `/write-prompt` on the milestones section as AI agent instructions."

## Milestones

### Milestone 1: Update `SKILL.md` (CLI version) ⬜

**Location:** `.claude/skills/prd-create/SKILL.md`

**Change 1 — Add callout near milestone guidance:**

Near the text "Focus on 5-10 major milestones rather than exhaustive task lists," add:

```markdown
> **Milestone Quality:** After finalizing milestones, you will run `/write-prompt` to review them as AI agent instructions. Write milestones with this review in mind: be specific about what to do, give the implementing AI the "why" behind each decision, and avoid open-ended instructions like "investigate X."
```

**Change 2 — Add step to ## Workflow section:**

In the `## Workflow` section, after the "Milestone Definition" step and before the commit/push step, insert:

```markdown
6. **Prompt Quality Review**: Run `/write-prompt` on the milestones section as AI agent instructions — milestone text is executed by a future AI implementor, making it a de-facto prompt. Apply all suggested improvements before committing. Do not skip this step.
```

Renumber all subsequent workflow steps accordingly.

**Success Criteria:**
- Callout appears adjacent to the "5-10 major milestones" guidance
- Step 6 appears between Milestone Definition and commit/push
- Subsequent steps are renumbered correctly
- Run `/write-prompt` on the modified SKILL.md after all changes are complete

### Milestone 2: Update `SKILL.v1-yolo.md` (YOLO version) ⬜

**Location:** `.claude/skills/prd-create/SKILL.v1-yolo.md`

Apply the identical changes as Milestone 1:
- Same callout near the milestone guidance section
- Same step 6 in the Workflow section
- Same renumbering of subsequent steps

**Success Criteria:**
- Both files contain identical callout and workflow step additions
- Run `/write-prompt` on the modified SKILL.v1-yolo.md after all changes are complete

## Implementation Notes

- Both milestones touch the same skill from different entry points (CLI vs YOLO). Implement in one session.
- After editing both files, run `/write-prompt` on the edits themselves (the workflow additions are skill instructions and should meet the same quality bar).
- Commit on a feature branch — not directly to main.
