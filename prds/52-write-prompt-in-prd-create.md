# PRD #52: Add /write-prompt Review Step to prd-create Skills

**Status**: Complete
**Completed**: 2026-05-14
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
**Impact:** M3 implemented without eval recommendation. ~~Future work: add `/skill-creator eval` advisory to `/prd-done` and/or `/prd-update-progress` skills.~~ Superseded by Decision 7 — `/skill-creator eval` is never recommended.

### Decision 5 — /skill-creator eval advisory in /prd-done when SKILL.md files were modified (2026-04-05) ⚠️ Superseded by Decision 7
**Decision:** ~~After merging a PRD branch, `/prd-done` should surface an advisory recommending `/skill-creator eval` on changed skills.~~
**Superseded:** Decision 7 (2026-05-14) reverses this — `/skill-creator eval` is never recommended. Milestone 4 was dropped as a result.

### Decision 7 — Never recommend /skill-creator eval (2026-05-14)
**Decision:** Do not recommend `/skill-creator eval` to Whitney, ever. Drop Milestone 4 entirely — the advisory should not be added to `/prd-done`.
**Rationale:** The eval process is too heavyweight — it spawns 6+ parallel agents, consumes hundreds of thousands of tokens, and takes several minutes. Whitney does not want to use it or be reminded it exists.
**Impact:** Milestone 4 is dropped. `/prd-done` will not receive a skill-creator eval advisory step.

### Decision 6 — Skill-creator eval advisory should guide the decision, not make it (2026-05-14)
**Decision:** The advisory in `/prd-done` for SKILL.md changes should help the user decide whether eval is worth running, rather than recommending it unconditionally. Running `/skill-creator eval` is a heavyweight process — it spawns 6+ parallel agents, uses ~300K+ tokens, and takes several minutes of wall time. For minor skill changes (wording tweaks, examples, clarifications), the cost outweighs the benefit. The advisory should surface the changed skill names and provide criteria for when eval is warranted: new skills and significant behavioral changes, yes; minor updates, no.
**Rationale:** Observed during PRD #52 implementation: running eval on `/write-prompt` consumed ~310K tokens and 1–2 minutes per agent run. Recommending this after every SKILL.md modification — including trivial changes — would create a reflexive pattern that is either ignored (noise) or expensive (real cost for no real benefit). Decision 3 already captures this reasoning for the per-file-edit hook; this extends the same logic to the PRD-completion checkpoint.
**Impact:** Milestone 4 advisory text changes from a blanket "Consider running..." to guidance that distinguishes cases where eval is worth it from cases where it is not. Detection logic (scan diff for SKILL.md matches) is unchanged.

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

### Milestone 4: Add /skill-creator eval advisory to /prd-done when SKILL.md files were modified 🚫 Dropped (Decision 7)

**Location:** `.claude/skills/prd-done/SKILL.md` and `.claude/skills/prd-done/SKILL.v1-yolo.md`

**Change — Add eval advisory step after merge (Updated per Decision 6: advisory must guide the decision, not make it unconditionally):**

In the merge/completion section of both `/prd-done` skill files, after the branch is merged, add a step that:
1. Scans the merged branch diff for any files matching `*/SKILL.md` or `*/SKILL.v1-yolo.md`
2. If any were modified: surface an advisory listing the specific changed files and helping the user decide whether eval is warranted — see advisory text below
3. If none were modified: skip silently

**Advisory text (per Decision 6 — cost-aware guidance, not unconditional recommendation):**
> This PRD modified SKILL.md files: [list the specific paths]. Consider running `/skill-creator eval` on the changed skills if: (1) a new skill was created, or (2) the skill's behavior was significantly changed. Skip eval for minor updates such as wording tweaks, adding examples, or clarifying existing steps — the eval process spawns multiple parallel agents and uses substantial tokens.

**Detection approach:** Use `gh pr diff [PR-number] --name-only | grep -E '(SKILL\.md|SKILL\.v1-yolo\.md)$'` to get the list of changed files from the merged PR.

**Success Criteria:**
- Both `/prd-done` SKILL.md and SKILL.v1-yolo.md contain the eval advisory step
- Advisory lists the specific skill files that were changed (not a generic message)
- Advisory includes decision criteria (new skill / behavioral change = run eval; minor updates = skip)
- Advisory fires only when SKILL.md files were in the diff; silent otherwise
- Run `/write-prompt` on both modified skill files after changes are complete

## Implementation Notes

- Milestones 1 and 2 touch the same skill from different entry points (CLI vs YOLO). Implement in one session.
- After editing both files, run `/write-prompt` on the edits themselves (the workflow additions are skill instructions and should meet the same quality bar).
- Milestone 3 is independent of 1 and 2 — can be implemented in a separate session on the same branch.
- Commit on a feature branch — not directly to main.
