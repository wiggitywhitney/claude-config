# PRD #48: Upgrade Existing Skills with Plugin Architecture Patterns

## Problem

Whitney's existing skills (`/research`, `/write-prompt`, `/verify`, `/anki`, `/write-docs`) are functional and well-used but don't leverage design patterns discovered in mature Claude Code plugins. Studying Anthropic's Skill Creator, Code Review, and Superpowers plugins revealed patterns — confidence scoring, multi-agent specialization, explicit workflow gates, progressive disclosure — that could make these skills more reliable, less noisy, and better at catching their own mistakes.

## Solution

Systematically upgrade each skill with applicable patterns from the plugin study. Each milestone focuses on one skill, applies the most impactful pattern(s), and validates the result.

## Research Reference

**MANDATORY for every milestone:** Before starting work, read the full research document:
- [`research/plugin-architecture-patterns.md`](../research/plugin-architecture-patterns.md)

This document contains the specific patterns, examples, and rationale from the plugin study. Read it fresh at the start of each milestone — do not rely on summaries or prior context. The research contains nuances (like the distinction between confidence scoring and binary verdicts, or the specific assertion design principles) that are easy to lose in paraphrase.

## Design Decisions

### Decision 1 — Auto-rewrite low-scoring cards, no human in the loop (2026-04-04)
**Decision:** When a card scores below 9/15, automatically rewrite it. Do not pause for user approval. Present the rewritten card alongside the original score so the improvement is visible.
**Rationale:** No human in the loop. The skill should fix the card, not just flag it.
**Impact:** M4 success criteria updated to reflect auto-rewrite behavior.

### Decision 2 — Image bank: human-in-the-loop, art is acceptable without semantic meaning (2026-04-04)
**Decision:** When a new concept is detected during card-making, prompt Whitney: "New concept: [X]. Do you want to add an image?" She provides the image (logo, art, etc.). The concept→image mapping persists so the same concept always gets the same image. Images with text are forbidden (text could reveal the answer). Visually pleasing art without semantic connection to the concept is acceptable — Whitney is visually motivated and art on a card improves engagement even without semantic relevance.
**Rationale:** Full automation (random image from bank) is feasible but semantic automation isn't. Human-in-the-loop at concept introduction time gives Whitney control while keeping the workflow light. Research on decorative images is mixed but Whitney's personal motivation from art is sufficient justification.
**Impact:** Adds M8 (Image Bank). M8 must include a research phase to establish correct Anki image dimensions and confirm the image embed syntax before implementing.

### Decision 3 — Glossary cards tagged `concept::glossary` (2026-04-04)
**Decision:** All Pattern 1 (Glossary/Definition Terms) cards get a `concept::glossary` tag in addition to their other tags. This enables filtered study sessions that prioritize foundational vocabulary before higher-concept cards.
**Rationale:** Glossary cards are the building blocks — knowing what a term means is prerequisite to understanding cards that use the term. Being able to filter to `concept::glossary` lets Whitney front-load vocabulary review.
**Impact:** M7 success criteria updated to require `concept::glossary` tagging. The Pattern 1 template in SKILL.md should include `concept::glossary` in its example tags.

### Decision 5 — Glossary cards are never deferred: always create them in the same session (2026-04-04)
**Decision:** When the Glossary Index Check finds missing terms, those Pattern 1 cards are automatically included in the Phase 2 batch — no prompt to defer. Whitney always wants glossary coverage made immediately.
**Rationale:** The "defer" option adds friction with no benefit. If a term is worth noting as missing, it's worth making the card now.
**Impact:** M7 glossary check step uses no AskUserQuestion for defer; missing terms are queued automatically for Phase 2.

### Decision 6 — Add a final anki consistency milestone (M9) to keep /anki and /anki-yolo in sync (2026-04-04)
**Decision:** Add Milestone 9 as a dedicated consistency pass: compare `/anki` and `/anki-yolo` SKILL.md side by side and ensure they are identical except for the autonomous workflow difference (no approval gate in YOLO).
**Rationale:** M4, M7, and M8 each touch both skill files, but changes are made piecemeal. Without a final comparison pass, features can drift between the two files unnoticed.
**Impact:** Adds M9 after M8. M8 success criteria note that M9 will do the final sync check.

### Decision 4 — Run `/write-prompt` after all changes, not partway through (2026-04-04)
**Decision:** The `/write-prompt` review must run after ALL changes to a SKILL.md are complete — not partway through the milestone. Running it early means subsequent changes (enforcement language, new integrations, wording fixes) go unreviewed.
**Rationale:** During M5, `/write-prompt` ran after the initial Broken Docs Detection phase was written, but before the enforcement language and `/research` integrations were added. A second review at the end caught this gap.
**Impact:** Updated success criteria in M6, M7, and M8 to clarify that `/write-prompt` runs last, after all other skill changes are complete.

## Milestones

### Milestone 1: `/research` — Formalize Phases with Explicit Decision Gates ✅ Complete

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
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)

### Milestone 2: `/write-prompt` — Progressive Disclosure and Severity Scoring ✅ Complete

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
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4) (meta: use the skill to review itself)

### Milestone 3: `/verify` — Structured Error Transcript Capture ✅ Complete

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
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)

### Milestone 4: `/anki` — Card-Level Confidence Scoring ✅ Complete

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
- Cards scoring below 9/15 are automatically rewritten (one attempt) and re-scored; the original score and the improvement made are shown so the change is visible (Decision 1: auto-rewrite, no human in the loop). If the card still scores < 9 after one rewrite, accept it with a note explaining why it couldn't reach the threshold (e.g., "Memory anchor limited: no project experience with this technology yet").
- Scoring doesn't slow down the card-making workflow — it's integrated into the existing two-phase process
- The "EACH CARD IS AN ISLAND" rule, personal anchor requirements, and terminology provenance rules are preserved
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)

### Milestone 5: `/write-docs` — Broken Docs Detection Phase ✅ Complete

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
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)

### Milestone 6: Review and Cross-Skill Consistency ✅ Complete

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
- Run `/write-prompt` review on each modified skill after all changes to that skill are complete — not partway through (Decision 4)

### Milestone 7: `/anki` — Glossary Index Setup and Integration ✅ Complete

**No external research required** — design was decided in conversation on 2026-04-04.

**Problem:** When a new technology, framework, or coined project term appears in a conversation, there's no mechanism to ensure foundational "What is X?" glossary cards get made. Concepts get covered in context-specific cards without ever getting the baseline two-card glossary treatment (Pattern 1 in SKILL.md). After hundreds of card-making sessions, there's no way to know which technologies have glossary coverage and which don't.

**Upgrade — Phase A: Initial Setup (one-time)**
- Create `~/Documents/Journal/anki/glossary-index.md` — a flat list of terms with existing glossary cards, one per line with the date first indexed
- Write a script or manual process to scan `ANKI_FINISHED_DIR` for existing Pattern 1 glossary cards and populate the initial index
- The index must be human-readable and easy to edit manually

**Upgrade — Phase B: Skill Integration**
- In `/anki` Phase 1, after scoring: scan the conversation for newly introduced technologies, APIs, frameworks, and coined project terms
- Cross-reference against the glossary index
- Output a "Missing Glossary Cards" section listing terms without index entries, with a prompt to create them now or defer
- After cards are approved and saved, append newly-glossed terms to the index automatically
- Mirror this behavior in `/anki-yolo`: add missing glossary terms to the final summary with a note

**Upgrade — Phase C: Instruction Quality**
- Update SKILL.md so the glossary index behavior is explained clearly enough for any future invocation to maintain it correctly without re-reading this PRD
- Include the index file path, the format for entries, and the rule for when a term qualifies for a glossary entry

**Success Criteria:**
- Glossary index file exists and is populated from existing finished cards
- `/anki` surfaces missing glossary cards in Phase 1 output and automatically queues them as Pattern 1 cards for Phase 2 (Decision 5: no defer prompt)
- After saving, new glossed terms are appended to the index without user action
- `/anki-yolo` surfaces missing glossary terms in its final summary
- All Pattern 1 glossary cards include `concept::glossary` tag (Decision 3: enables filtered study sessions to front-load vocabulary)
- The Pattern 1 template in SKILL.md is updated to include `concept::glossary` in its example tags
- SKILL.md instructions are self-contained — the index behavior is maintainable without external context
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)

### Milestone 8: `/anki` — Image Bank for Visual Motivation

**Best done in the same work session as M7** — both touch the core anki/anki-yolo SKILL.md and the card-making workflow.

**Problem:** Cards are purely text. Whitney is visually motivated — art on a card improves engagement and review completion even without a semantic connection to the concept. There's no mechanism to associate images with concepts or persist those associations across card-making sessions.

**Research phase required before implementation:**
- Run `/research "Anki image dimensions best practices"` — determine the right pixel dimensions for card images (small enough not to dominate, large enough to be visually engaging)
- Confirm how images are technically added to Anki cards via the Obsidian embed syntax (`![[filename.png]]`) — verify this is the correct approach and document any gotchas
- Do not implement until research is complete and pixel dimensions are decided

**Upgrade — Phase A: Infrastructure**
- Create image bank directory: `~/Documents/Journal/anki/images/bank/`
- Create concept→image mapping file: `~/Documents/Journal/anki/images/concept-map.md` — a simple table mapping concept names to image filenames
- The mapping file must be human-readable and easy to edit manually

**Upgrade — Phase B: Skill Integration**
- During card-making, when a new concept is identified that doesn't have an entry in the concept map: prompt Whitney: "New concept: [X]. Do you want to add an image? (provide the file or skip)"
- If Whitney provides an image: resize to the researched target dimensions, save to `images/bank/`, add the mapping entry
- If a concept already has a mapping entry: embed the mapped image automatically on the card front using Obsidian embed syntax
- Cards with multiple concepts → embed all mapped images for those concepts

**Image rules:**
- **No images with text** — text in an image can reveal the answer on the card front before the user flips
- Logos with text are forbidden for this reason; text-free art or abstract images are preferred
- Visually pleasing art without semantic connection is acceptable (Decision 2: Whitney's visual motivation justifies even decorative images)

**Upgrade — Phase C: Instruction Quality**
- Update SKILL.md with the image bank path, concept-map path, the prompt template for new concepts, and the no-text-in-images rule
- Include the target pixel dimensions (from research) explicitly in the SKILL.md so future invocations don't need to guess

**Success Criteria:**
- Research completed: target pixel dimensions documented in SKILL.md
- Image bank directory and concept-map file exist
- When a new concept is detected with no mapping, the skill prompts Whitney for an optional image
- When a concept has a mapping, the image is embedded automatically without prompting
- Images are resized to the researched target dimensions before saving
- Images with text are flagged and rejected with an explanation
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)
- Note: full anki/anki-yolo consistency check is done in M9, not M8

### Milestone 9: `/anki` vs `/anki-yolo` — Final Consistency Check

**No external research required** — this is a structural comparison pass.

**Problem:** M4, M7, and M8 each touched both skill files piecemeal. Features can silently drift between `/anki` and `/anki-yolo` — one skill gets an improvement that the other doesn't. There's no single moment where both files are compared holistically.

**Upgrade:**
- Read both SKILL.md files in full
- Do a section-by-section comparison: Card Quality Scoring, Card Rules, Glossary Index, Image Bank, Card Patterns, Tag Taxonomy, Quality Checklist
- The only accepted differences between the files:
  - `/anki` has a two-phase workflow with a user approval gate; `/anki-yolo` is a single autonomous flow
  - `/anki` uses AskUserQuestion for decisions; `/anki-yolo` makes autonomous choices
  - `/anki-yolo` has a 10-card default limit; `/anki` does not
- Everything else — card rules, scoring, glossary check, image bank, pattern templates, tag taxonomy — must be identical
- Fix any divergences found

**Success Criteria:**
- Both SKILL.md files read and compared section by section
- All divergences outside the accepted autonomy differences are documented and fixed
- Run `/write-prompt` review on any modified SKILL.md after all changes are complete — not partway through (Decision 4)

## Implementation Notes

- Each milestone is independent — they can be done in any order, though the listed order builds momentum from quick wins to larger changes. M7 depends on M4 being complete (the scoring section should exist before the glossary section references it). M8 depends on M7 (both touch the same SKILL.md; best done in one session). M8 also requires a research phase before implementation — do not skip it. M9 depends on M8 (final consistency check after all anki changes are made).
- Every milestone must preserve existing skill behavior (no regressions)
- Every milestone must end with a `/write-prompt` review of the updated SKILL.md — run it last, after all other changes are complete (Decision 4)
- The Skill Creator plugin's eval framework could be used to benchmark before/after for any skill, but this is optional — manual validation is sufficient for this PRD
