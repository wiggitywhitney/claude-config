# PRD #48: Upgrade Existing Skills with Plugin Architecture Patterns

## Problem

Whitney's existing skills (`/research`, `/write-prompt`, `/verify`, `/anki`, `/write-docs`) are functional and well-used but don't leverage design patterns discovered in mature Claude Code plugins. Studying Anthropic's Skill Creator, Code Review, and Superpowers plugins revealed patterns — confidence scoring, multi-agent specialization, explicit workflow gates, progressive disclosure — that could make these skills more reliable, less noisy, and better at catching their own mistakes.

## Solution

Systematically upgrade each skill with applicable patterns from the plugin study. Each milestone focuses on one skill, applies the most impactful pattern(s), and validates the result.

## Research Reference

**MANDATORY for every milestone:** Before starting work, read the full research document:
- [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md)

This document contains the specific patterns, examples, and rationale from the plugin study. Read it fresh at the start of each milestone — do not rely on summaries or prior context. The research contains nuances (like the distinction between confidence scoring and binary verdicts, or the specific assertion design principles) that are easy to lose in paraphrase.

## Milestones

### Milestone 1: `/research` — Formalize Phases with Explicit Decision Gates

**Research to read first:** [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md) — focus on "Phased Workflows with Explicit Gates" and the `/research` recommendations.

**Problem:** The `/research` skill has informal phases (Scope, Search, Synthesize, Present, Document). There are no explicit gates — the skill flows from one phase to the next without checking whether the previous phase produced enough to proceed.

**Upgrade:**
- Add explicit decision gates between phases:
  - After Search: "Do I have enough evidence from diverse sources to synthesize?" If no, search more.
  - After Synthesize: "Do my sources corroborate each other? Are there contradictions?" If contradictions exist, add a "Conflicting Findings" section.
- Add an explicit "Contradictions Summary" section template for when sources disagree
- Number the phases explicitly (Phase 1, Phase 2, etc.) with named gates

**Success Criteria:**
- Each phase has a named gate with a clear yes/no question
- The skill stops and searches more when the "enough evidence?" gate fails
- Contradictions between sources are surfaced explicitly rather than silently resolved
- The skill's existing citation and confidence-level features are preserved
- Run `/write-prompt` review on the updated SKILL.md

### Milestone 2: `/write-prompt` — Progressive Disclosure and Severity Scoring

**Research to read first:** [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md) — focus on "Progressive Disclosure (Lazy Loading)" and "Confidence Scoring Over Binary Verdicts" and the `/write-prompt` recommendations.

**Problem:** The `/write-prompt` SKILL.md is large with inline examples. All anti-patterns are flagged equally regardless of severity — a correctness issue gets the same treatment as a style preference.

**Upgrade:**
- Move anti-pattern examples to a `references/` directory (progressive disclosure — loaded only when needed)
- Keep SKILL.md under 500 lines
- Add anti-pattern severity scoring: High (impacts correctness), Medium (impacts efficiency), Low (style preference)
- Only flag High and Medium by default; Low severity findings go in a separate "Style Notes" section

**Success Criteria:**
- SKILL.md is under 500 lines with examples in `references/`
- Anti-patterns are scored by severity and presented in priority order
- Low-severity findings don't clutter the main review output
- Existing anti-pattern detection coverage is preserved (no regressions)
- Run `/write-prompt` review on the updated SKILL.md (meta: use the skill to review itself)

### Milestone 3: `/verify` — Structured Error Transcript Capture

**Research to read first:** [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md) — focus on "Evidence-Based Assertions" and the `/verify` recommendations.

**Problem:** When verification fails, the `/verify` skill reports "Phase N failed" with raw output. There's no structured data capture that would enable pattern detection across failures or help the AI self-correct more efficiently.

**Upgrade:**
- Capture error transcripts as structured data (JSON): phase name, command run, exit code, stderr snippet, timestamp
- Print smart, structured error summaries that include: what failed, the specific error, and a suggested fix
- Store error context so repeated failures on the same phase can reference prior attempts

**Success Criteria:**
- Every verification failure produces structured error data (phase, command, exit code, stderr)
- Error messages include a specific suggested fix, not just "Phase N failed"
- The existing phase structure, restart-on-failure rule, and docs-only skip are preserved
- Integration tests verify structured error output format
- Run `/write-prompt` review on the updated SKILL.md

### Milestone 4: `/anki` — Card-Level Confidence Scoring

**Research to read first:** [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md) — focus on "Confidence Scoring Over Binary Verdicts" and the `/anki` recommendations. Also read the updated `/anki` SKILL.md to understand the "EACH CARD IS AN ISLAND" rule added during this study.

**Problem:** All Anki cards are presented equally regardless of quality. There's no mechanism to score cards on how well they'll work for spaced repetition — a card with a weak memory anchor gets the same treatment as one with a strong personal connection.

**Upgrade:**
- Add card-level confidence scoring on 3 dimensions (each 1-5):
  - **Memory anchor clarity**: Does the card connect to a specific experience, project, or "aha moment"?
  - **Future-self accessibility**: Will this card make sense in 6 months with zero context?
  - **Concept vs. detail balance**: Is this a conference-worthy concept or implementation trivia?
- Calculate an overall score (sum of 3 dimensions, max 15)
- Present cards sorted by score, flag any scoring below 9 for review
- Include scores in the card-ready document (Phase 1) so the user can see quality before cards are made

**Success Criteria:**
- Every card batch includes per-card scores on 3 dimensions
- Cards scoring below 9/15 are flagged with a specific suggestion for improvement
- Scoring doesn't slow down the card-making workflow — it's integrated into the existing two-phase process
- The "EACH CARD IS AN ISLAND" rule, personal anchor requirements, and terminology provenance rules are preserved
- Run `/write-prompt` review on the updated SKILL.md

### Milestone 5: `/write-docs` — Broken Docs Detection Phase

**Research to read first:** [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md) — focus on "Multi-Agent Specialization" and the `/write-docs` recommendations.

**Problem:** The `/write-docs` skill writes new documentation by executing real commands, but it doesn't systematically test *existing* documentation before writing. If the current README has broken instructions, the new docs may build on a broken foundation.

**Upgrade:**
- Add a "Broken Docs Detection" phase before writing new docs:
  - Can you follow the existing README and get a working environment?
  - Do code examples in existing docs execute without error?
  - Do outputs match what existing docs claim?
- Surface broken docs findings before proceeding with new documentation
- Give the user the option to fix existing docs first or proceed with new docs

**Success Criteria:**
- Before writing new docs, existing docs are tested for accuracy
- Broken instructions, non-working code examples, and stale output claims are surfaced
- The user sees broken docs findings and chooses whether to fix them first
- The existing real-command-execution and chunk-by-chunk validation features are preserved
- Run `/write-prompt` review on the updated SKILL.md

### Milestone 6: Review and Cross-Skill Consistency

**Research to read first:** [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md) — read the full document one final time.

**Problem:** After upgrading 5 skills independently, there may be inconsistencies in how patterns were applied (e.g., confidence scoring in `/anki` vs severity scoring in `/write-prompt` using different scales or terminology).

**Upgrade:**
- Review all 5 upgraded skills for consistency in:
  - How phases are numbered and gates are named
  - How severity/confidence scoring is presented
  - How error messages and suggestions are formatted
- Harmonize terminology and patterns where they diverge unnecessarily
- Update the `/anki` skill's SKILL.md to capture any new card-making patterns that emerged during implementation (e.g., if scoring revealed a new card quality dimension)

**Success Criteria:**
- All upgraded skills use consistent terminology for shared patterns
- Phase numbering and gate naming follow the same convention across skills
- Scoring scales are compatible (a "high confidence" finding in one skill means the same thing in another)
- Run `/write-prompt` review on any skills modified in this milestone

## Implementation Notes

- Each milestone is independent — they can be done in any order, though the listed order builds momentum from quick wins to larger changes
- Every milestone must preserve existing skill behavior (no regressions)
- Every milestone must end with a `/write-prompt` review of the updated SKILL.md
- The Skill Creator plugin's eval framework could be used to benchmark before/after for any skill, but this is optional — manual validation is sufficient for this PRD
