# PRD #48: Upgrade Existing Skills with Plugin Architecture Patterns

**Status**: Complete
**Completed**: 2026-04-05
**GitHub Issue**: [#48](https://github.com/wiggitywhitney/claude-config/issues/48)

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
**Decision:** When a new concept is detected during card-making, prompt Whitney: "New concept: [X]. Do you want to add an image?" She provides the image (logo, art, etc.). The concept→image mapping persists so the same concept always gets the same image. Images with text or logos are allowed when they do not reveal the card answer on the Front; if they would, place them on the Back instead (see Decision 11). Visually pleasing art without semantic connection to the concept is acceptable — Whitney is visually motivated and art on a card improves engagement even without semantic relevance.
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

### Decision 7 — Image dimensions: 800px wide, PNG format (2026-04-04)
**Decision:** Target image size for the image bank is 800px on the longest side, PNG format. No official Anki pixel spec exists; 800px is the community-tested sweet spot. PNG is preferred over JPG for art/logos (lossless, supports transparent backgrounds). WebP is not reliably supported across Mac/iOS Anki clients.
**Rationale:** Research found no official spec. 800px on the longest side is large enough to be visually engaging without dominating the card or slowing sync. PNG lossless format matches the type of art/logos Whitney wants.
**Impact:** M8 SKILL.md must document 800px on the longest side, PNG as the target. Image resizing in Phase A uses this target.

### Decision 8 — Images must be inside the Obsidian vault; `~/Documents/Journal/anki/images/bank/` is confirmed valid (2026-04-04)
**Decision:** ObsidianToAnki resolves `![[filename.png]]` via Obsidian's vault index (`metadataCache.getFirstLinkpathDest`). Images outside the vault fail silently with no error shown. `~/Documents/Journal/anki/images/bank/` is inside Whitney's vault — confirmed because the parent directory (`images/`) already works. Images are resolved by filename anywhere in the vault, so `![[filename.png]]` needs no path prefix.
**Rationale:** Research traced ObsidianToAnki source code. Whitney confirmed images currently appear in Anki, proving the vault path is correct.
**Impact:** M8 image bank must live at `~/Documents/Journal/anki/images/bank/`. No path prefix in embed syntax — `![[filename.png]]` is sufficient. Removes the "confirm embed syntax" research task from M8 (already confirmed).

### Decision 9 — Image bank filenames must be globally unique within the vault (2026-04-04)
**Decision:** Obsidian resolves `![[filename.png]]` by nearest filename match across the vault. If two vault files share a name, Obsidian picks the closest one — non-deterministic for image bank use. Use a naming convention: `concept-name-bank.png` to prevent collisions with screenshots or other vault images.
**Rationale:** Generic names like `logo.png` or `kubernetes.png` risk colliding with other vault files. The `-bank` suffix namespaces image bank files distinctly.
**Impact:** M8 SKILL.md must specify the `-bank.png` naming convention. The skill enforces this when saving images.

### Decision 10 — Platform: macOS + AnkiMobile (iOS) only; no CSS workarounds needed (2026-04-04)
**Decision:** Whitney uses Anki desktop (macOS) and AnkiMobile (iOS). No Android/AnkiDroid. The `max-width: 100% !important` CSS workaround found in research is AnkiDroid-specific and irrelevant. Standard CSS works on macOS and AnkiMobile without any special overrides.
**Rationale:** Whitney confirmed: MacBook Pro + iPhone. The `!important` bug is specific to AnkiDroid's JavaScript-based image rescaling. Not applicable here.
**Impact:** M8 does not require card template CSS changes. CSS caveats from research do not belong in SKILL.md.

### Decision 11 — Images with text are allowed; rule is answer-reveal on the Front (2026-04-05)
**Decision:** Images with visible text (logos, branding, product screenshots) are acceptable. The rule is: don't place an image on the Front if its text or logo reveals the card answer before the user flips. Logos and branded images are welcome — put them on the Back when they'd give it away, or on the Front when they don't.
**Rationale:** Whitney said she would provide images with visible text (logos, screenshots from product websites). The PRD's original "images with text are forbidden" was overly broad. The actual concern is spoiling the answer, not text per se.
**Impact:** Updated answer-reveal rule in both SKILL.md files. Updated Quality Checklist items. Removed "logos with embedded text are forbidden" language.

### Decision 12 — Two-tier image bank: concept-specific and art pool; oldest-unassigned selection (2026-04-05)
**Decision:** The bank contains two kinds of images: (1) concept-specific images (logos, product screenshots) saved when Whitney provides one — named `concept-name-bank.png`; (2) art pool images (decorative general art) that keep their original filenames and are assigned to new concepts when Whitney says "no, pull from bank." Art images are assigned in order (oldest first, determined by Glob result order). Concept qualification for image assignment mirrors glossary term criteria (technologies, frameworks, APIs, coined terms) — not every card topic.
**Rationale:** Whitney clarified the image bank is a pool of art images for reuse when no specific logo exists. Each concept gets one image persistently tracked in the concept map. The oldest-first policy is deterministic and avoids random assignment.
**Impact:** Image Bank section in both SKILL.md files documents the two-tier design, art pool selection logic (Glob + concept-map cross-reference, first result), and concept qualification criteria. Added Glob to `/anki` allowed-tools so the skill can scan the bank directory.

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

### Milestone 8: `/anki` — Image Bank for Visual Motivation ✅ Complete

**Best done in the same work session as M7** — both touch the core anki/anki-yolo SKILL.md and the card-making workflow.

**Problem:** Cards are purely text. Whitney is visually motivated — art on a card improves engagement and review completion even without a semantic connection to the concept. There's no mechanism to associate images with concepts or persist those associations across card-making sessions.

**Research complete** — see Decisions 7–10. No further research phase needed before implementation.

**Confirmed technical facts (from research):**
- Target dimensions: **800px wide, PNG format** (Decision 7)
- Embed syntax `![[filename.png]]` is correct and confirmed working in Whitney's setup (Decision 8)
- Images must be inside the Obsidian vault — `~/Documents/Journal/anki/images/bank/` is within vault and valid (Decision 8)
- Filenames must be globally unique within the vault — use `concept-name-bank.png` convention (Decision 9)
- Platform: macOS + AnkiMobile (iOS) only — no CSS template changes needed (Decision 10)

**Upgrade — Phase A: Infrastructure**
- Create image bank directory: `~/Documents/Journal/anki/images/bank/`
- Create concept→image mapping file: `~/Documents/Journal/anki/images/concept-map.md` — a simple table mapping concept names to image filenames
- The mapping file must be human-readable and easy to edit manually

**Upgrade — Phase B: Skill Integration**
- During card-making, when a new concept is identified that doesn't have an entry in the concept map: prompt Whitney: "New concept: [X]. Do you want to add an image? (provide the file or skip)"
- If Whitney provides an image: resize to 800px wide, save as PNG to `images/bank/` with a `concept-name-bank.png` filename, add the mapping entry (Decision 7, 9)
- If a concept already has a mapping entry: embed the mapped image automatically on the card front using `![[filename.png]]` syntax — no path prefix needed, Obsidian resolves by filename (Decision 8)
- Cards with multiple concepts → embed all mapped images for those concepts

**Image rules:**
- **Answer-reveal rule** (Decision 11): don't place an image on the Front if its text or logo reveals the card answer before flipping. Logos, product art, and branded images are welcome — put them on the Back if they'd give it away, or on the Front if they don't.
- Visually pleasing art without semantic connection is acceptable (Decision 2: Whitney's visual motivation justifies even decorative images)

**Upgrade — Phase C: Instruction Quality**
- Update SKILL.md with: image bank path, concept-map path, prompt template for new concepts, answer-reveal rule (Decision 11), 800px PNG target, `concept-name-bank.png` naming convention, vault requirement, `![[filename.png]]` embed syntax (Decisions 7–11)

**Success Criteria:**
- Image bank directory and concept-map file exist at specified paths (both within Obsidian vault)
- When a new concept is detected with no mapping, the skill prompts Whitney for an optional image
- When a concept has a mapping, the image is embedded automatically using `![[filename.png]]` syntax
- Images are resized to 800px wide and saved as PNG before going into the bank (Decision 7)
- Image filenames follow `concept-name-bank.png` convention to prevent vault collisions (Decision 9)
- Images that would reveal the answer on the Front are flagged and moved to the Back
- SKILL.md documents all confirmed technical facts from research (Decisions 7–10) so future invocations need no external context
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete — not partway through (Decision 4)
- Note: full anki/anki-yolo consistency check is done in M9, not M8

### Milestone 9: `/anki` vs `/anki-yolo` — Final Consistency Check ✅ Complete

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

- Each milestone is independent — they can be done in any order, though the listed order builds momentum from quick wins to larger changes. M7 depends on M4 being complete (the scoring section should exist before the glossary section references it). M8 depends on M7 (both touch the same SKILL.md; best done in one session). M8 research is complete (Decisions 7–10) — implementation can proceed directly. M9 depends on M8 (final consistency check after all anki changes are made).
- Every milestone must preserve existing skill behavior (no regressions)
- Every milestone must end with a `/write-prompt` review of the updated SKILL.md — run it last, after all other changes are complete (Decision 4)
- The Skill Creator plugin's eval framework could be used to benchmark before/after for any skill, but this is optional — manual validation is sufficient for this PRD
