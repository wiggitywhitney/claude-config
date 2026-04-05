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

### Decision 3 — `/skill-creator eval` excluded from suggest-write-prompt hook (2026-04-05)
**Decision:** The `suggest-write-prompt.sh` hook only recommends `/write-prompt`. It does NOT recommend `/skill-creator eval`.
**Rationale:** The hook fires on every Write|Edit to a SKILL.md or CLAUDE.md — including typo fixes, wording tweaks, and code block label additions. Recommending eval on every edit would (1) create noise that trains the implementing agent to ignore the recommendation, (2) incur real cost for trivial changes, and (3) dilute the value of the `/write-prompt` reminder. Eval is appropriate for significant behavioral changes, attached to milestone completion events — not every file save.
**Impact:** M3 implemented without eval recommendation. Future work: add `/skill-creator eval` advisory to `/prd-done` and/or `/prd-update-progress` skills, triggered after milestone completion rather than individual file edits. This is a separate PRD or enhancement, not in scope for PRD #52.

### Decision 4 — Research-explicit milestone characteristic added to both skill files (2026-04-05)
**Decision:** Both `SKILL.md` and `SKILL.v1-yolo.md` received an additional milestone characteristic: "Research-explicit: when a milestone requires researching a technology or API before implementing, direct the implementing AI to run `/research <topic>` explicitly — do not leave it as 'investigate X' or 'look into Y'."
**Rationale:** User requested this during implementation. Vague "investigate" instructions are the exact failure mode the PRD exists to prevent. Naming `/research` explicitly gives the implementing AI a concrete action instead of an open-ended directive.
**Impact:** M1 and M2 scope expanded during implementation to include this characteristic in the Milestone Characteristics section. Both milestones delivered with this addition.

## Milestones

### Milestone 1: Update `SKILL.md` (CLI version) ✅ Complete

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

### Milestone 2: Update `SKILL.v1-yolo.md` (YOLO version) ✅ Complete

**Location:** `.claude/skills/prd-create/SKILL.v1-yolo.md`

Apply the identical changes as Milestone 1:
- Same callout near the milestone guidance section
- Same step 6 in the Workflow section
- Same renumbering of subsequent steps

**Success Criteria:**
- Both files contain identical callout and workflow step additions
- Run `/write-prompt` on the modified SKILL.v1-yolo.md after all changes are complete

### Milestone 3: PostToolUse hook — suggest /write-prompt on SKILL.md and CLAUDE.md edits ✅ Complete

**Research first:** Run `/research` to verify the PostToolUse hook input format and `additionalContext` output schema before implementing. The existing `post-write-codeblock-check.sh` hook demonstrates the stdin JSON pattern; verify that advisory (non-blocking) PostToolUse output uses `hookSpecificOutput.additionalContext` and exits 0.

**Implementation:**
- Create `~/.claude/skills/verify/scripts/suggest-write-prompt.sh` — a PostToolUse hook on Write|Edit
- Read file path from `tool_input.file_path` in stdin JSON
- If path matches `*/SKILL.md`, `*/SKILL.v1-yolo.md`, or `*CLAUDE.md`: emit advisory via `additionalContext` suggesting `/write-prompt` on the changed file
- Always exit 0 — advisory only, never blocking
- Register in `~/.claude/settings.json` as a PostToolUse hook on `Write|Edit` alongside the existing codeblock check

**TDD — write failing tests before implementing:**
- Write tests in `~/.claude/skills/verify/tests/` (or equivalent test location)
- Test cases:
  - SKILL.md path → advisory emitted
  - SKILL.v1-yolo.md path → advisory emitted
  - CLAUDE.md path → advisory emitted
  - Non-matching path (e.g., `main.ts`) → no output, exit 0
  - Empty file path → no output, exit 0
- Run tests and confirm they fail before writing the hook
- Implement hook, run tests, confirm they pass

**Success Criteria:**
- Tests written and passing before milestone is marked complete
- Hook fires advisory (not blocking) for SKILL.md, SKILL.v1-yolo.md, and CLAUDE.md edits
- Hook is silent for all other file types
- Registered correctly in `~/.claude/settings.json`
- Run `/write-prompt` on the hook script after implementation

## Implementation Notes

- Milestones 1 and 2 touch the same skill from different entry points (CLI vs YOLO). Implement in one session.
- After editing both files, run `/write-prompt` on the edits themselves (the workflow additions are skill instructions and should meet the same quality bar).
- Milestone 3 is independent of 1 and 2 — can be implemented in a separate session on the same branch.
- Commit on a feature branch — not directly to main.
