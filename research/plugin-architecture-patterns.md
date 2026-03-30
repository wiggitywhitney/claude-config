# Research: Claude Code Plugin Architecture Patterns

**Date:** 2026-03-30
**Plugins Studied:** Skill Creator (Anthropic), Code Review (Anthropic), Superpowers (Jesse Vincent)
**Purpose:** Extract design patterns to upgrade Whitney's existing skills

## Cross-Cutting Patterns

### 1. Confidence Scoring Over Binary Verdicts
Anthropic's Code Review plugin for Claude Code uses a 0-100 confidence scale with a threshold of 80. Only high-confidence findings get posted. The rubric: 0 = false positive, 25 = somewhat confident, 50 = moderately confident, 75 = highly confident, 100 = absolutely certain.

**Applicable to:** `/anki` (card quality scoring), `/write-prompt` (anti-pattern severity), `/verify` (pass confidence)

### 2. Multi-Agent Specialization
Anthropic's Code Review plugin for Claude Code launches 5 independent agents in parallel (CLAUDE.md compliance, bug detection, git history, prior PR comments, inline comments). Anthropic's Skill Creator plugin for Claude Code uses 4 agents (executor, grader, comparator, analyzer). Independent agents prevent groupthink.

**Applicable to:** `/research` (parallel source-type agents), `/write-docs` (cross-reference validator)

### 3. Phased Workflows with Explicit Gates
Both Skill Creator and Code Review use numbered phases with clear success criteria. Critical rule from Skill Creator: "After any fix, restart from Phase 1 to ensure earlier fixes don't break later phases."

**Applicable to:** `/research` (formalize existing phases with decision gates)

### 4. Blind Comparison for A/B Decisions
Skill Creator's comparator agent evaluates two outputs WITHOUT knowing which version produced each. Generates rubric, scores 1-5 per criterion, declares winner. Prevents anchoring bias.

**Applicable to:** Future skill evaluation methodology

### 5. Evidence-Based Assertions
Skill Creator's grader returns structured results: `{"text": "...", "passed": true, "evidence": "Found in transcript Step 3: ..."}`. Every claim must cite specific evidence.

**Applicable to:** `/verify` (error transcript capture)

### 6. Progressive Disclosure (Lazy Loading)
Skills load context in 3 levels: YAML frontmatter (always), SKILL.md body (on trigger, max 500 lines), bundled resources in agents/references/scripts/ (loaded as needed).

**Applicable to:** `/write-prompt` (move examples to references/)

## Concrete Upgrade Recommendations by Skill

### `/research` Skill
1. **Formalize phases with explicit decision gates** — Add gates: "enough evidence?" before synthesizing, "sources corroborate?" before presenting. Currently phases are informal.
2. **Launch 3 parallel source-type agents** — Official docs agent, community/blog agent, breaking changes/gotchas agent. Prevents anchoring to first result.
3. **Add explicit "Contradictions Summary" section** — When sources disagree, present both with interpretation of which is more reliable and why.

### `/write-prompt` Skill
1. **Move anti-pattern examples to references/ directory** — Keep SKILL.md under 500 lines via progressive disclosure.
2. **Add anti-pattern severity scoring** — High/medium/low severity before deciding to flag. High = impacts correctness, Medium = impacts efficiency, Low = style preference. Mirrors Code Review's confidence threshold approach.

### `/verify` Skill
1. **Add error transcript capture as structured data** — JSON with phase, command, exit code, stderr, timestamp. Enables pattern detection across failures.

### `/anki` Skill
1. **Add card-level confidence scoring** — Score on 3 dimensions (each 1-5): memory anchor clarity, future-self accessibility, concept vs. detail balance. Total max 15; flag cards below 9 for review. See PRD #48 Milestone 4 for full specification.
2. **Spawn parallel recency-checker agent** — For fast-changing content, launch a background agent that WebSearches for current status and compares with conversation context.

### `/write-docs` Skill
1. **Add "broken docs detection" phase** — Before writing new docs, systematically test existing docs: Can you follow the README? Do code examples execute? Do outputs match claims?
2. **Spawn "cross-reference validator" agent** — Background agent finds other docs that reference this feature, checks if references still work, reports updates needed.

## Key Principles from Plugin Study

- **Output format beats emotional appeals** — "Return complete source file; files with placeholder comments fail validation" works better than "do your best."
- **Principle of Lack of Surprise** — A skill's behavior should not surprise the user if they read the name and description.
- **Generalization over overfitting** — Optimize for millions of future invocations, not 3 test cases.
- **Assertion design** — Good assertions are objectively verifiable, discriminating, and meaningful.
- **Parallel coordination** — Spawn all agents simultaneously, wait for ALL to finish before processing results.

## Source Plugin Locations

- Skill Creator: `/Users/whitney.lee/.claude/plugins/marketplaces/claude-plugins-official/plugins/skill-creator/`
- Code Review: `/Users/whitney.lee/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-review/`
- Superpowers: Not installed locally (marketplace reference only)
