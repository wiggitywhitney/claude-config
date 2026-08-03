# PRD #43: Refactor Global CLAUDE.md

**Status**: Closed 2026-03-16 (issue #43). Archived 2026-08-03.

> **Superseded in part — do not execute Milestone 3 as written.** This PRD's strategy was to extract verbose sections into rule files and reference them with `@path/to/file` from `CLAUDE.md`. That does not reduce always-loaded context: an `@`-referenced file loads in every session exactly as inline text does, now with file overhead on top. Worse, this PRD also required `paths:` frontmatter on those same files, and a file carrying both mechanisms loads twice. The five rules that ended up double-loaded — `git-workflow`, `issue-juggling`, `infrastructure-safety`, `adopting-new-technologies`, `datadog-environment` — are exactly this PRD's Milestone 2 deliverables, and three of them were scoped `paths: ["**/*"]`, re-injecting on every file read. Issue #108 fixed that in August 2026 and established the rule this PRD predates: every rule file gets **exactly one** loading mechanism, `paths:` for on-demand and `@`-reference only for the few that genuinely apply to every session.
>
> **What shipped:** Milestone 2. All six rule files exist.
>
> **What did not:** the size goal. `global/CLAUDE.md` was 202 lines as of 2026-08-03, against this PRD's target of under 150 — more than the 172 that prompted it. That goal now belongs to PRD #109 M2, measured against the always-loaded byte budget rather than line count, since lines were always a proxy and #108 established the real measurement.
>
> **What is still sound:** Decision 2 below — short domain-specific sections stay inline, because extracting a four-line section costs more in file overhead than it saves. Decision 3 was also correct and correctly implemented: `hooks-reference.md` is path-scoped and loads only when hooks are being edited, which is the model the rest of this PRD should have followed.

## Problem

Global CLAUDE.md is 172 lines, exceeding the 150-line target. Every line is loaded into every conversation across all projects, so bloat has a direct token cost. Several sections duplicate content that already exists in `@`-referenced rule files, and others contain verbose examples and multi-line instructions that could be extracted.

## Solution

Factor verbose sections into `@`-referenced rule files in `rules/` or `guides/`. Keep CLAUDE.md as a concise index where each topic gets 1-2 lines plus an `@path/to/file` reference for details. Target: under 150 lines, ideally ~120.

## Current State Analysis

| Section | Lines | Already has @ref? | Action |
|---|---|---|---|
| Writing Style (7) | 7 | No | Keep inline — already concise |
| Writing Code (17) | 17 | No | Trim; move examples to rule file |
| Getting Help (4) | 4 | No | Keep inline — already concise |
| Adopting New Technologies (10) | 10 | No | Extract to rule file |
| Testing (17) | 17 | Yes (2 refs) | Compress to 3-4 lines + existing refs |
| Test-Driven Development (7) | 7 | No | Merge into Testing section as 1-liner + ref |
| Development Workflow (4) | 4 | No | Keep inline — already concise |
| Git Workflow (16) | 16 | No | Extract details to rule file |
| Issue Juggling (10) | 10 | No | Extract to rule file |
| Infrastructure Safety (7) | 7 | No | Extract to rule file |
| ABOUTME File Headers (3) | 3 | Yes (1 ref) | Keep — already concise |
| Datadog Enterprise Environment (12) | 12 | No | Extract to rule file |
| Language & Configuration Defaults (3) | 3 | No | Keep inline |
| Vals Secrets Management (4) | 4 | Yes (1 ref) | Keep — already concise |
| OpenTelemetry Packaging (6) | 6 | No | Keep inline — domain-specific, few lines |
| PRD Workflow (11) | 11 | No | Compress to 3-4 lines |
| Rules Enforced by Hooks (15) | 15 | No | Extract to reference file |

## Constraints

- CLAUDE.md must remain self-contained enough that a fresh agent understands the rules without reading every referenced file — the index lines must be actionable, not just pointers
- Referenced rule files need correct `paths:` frontmatter so they're only loaded in relevant contexts
- Some rules files already exist (`testing-rules.md`, `vals-secrets.md`, `aboutme-headers.md`) — reuse them, don't duplicate
- The symlink `~/.claude/CLAUDE.md` → `global/CLAUDE.md` must continue to work

## Success Criteria

- [ ] Global CLAUDE.md is under 150 lines
- [ ] No behavioral rules are lost — every rule is either inline or in a referenced file
- [ ] Referenced files have correct `paths:` frontmatter
- [ ] Existing rule file references still work

## Milestones

### Milestone 1: Audit and plan extractions
- [ ] Read every section of current CLAUDE.md and catalog what can be extracted vs what must stay inline
- [ ] Identify which existing rule files can absorb content (e.g., `testing-rules.md` already exists)
- [ ] Identify new rule files needed
- [ ] Produce a line-count budget showing how each section shrinks

### Milestone 2: Create new rule files for extracted content
- [ ] Create `rules/git-workflow.md` — Git workflow details, CodeRabbit process, acceptance gate labeling
- [ ] Create `rules/issue-juggling.md` — Autonomous issue queue workflow
- [ ] Create `rules/infrastructure-safety.md` — Infrastructure safety rules, cloud resource lifecycle
- [ ] Create `rules/adopting-new-technologies.md` — Technology adoption process
- [ ] Create `rules/datadog-environment.md` — Datadog AI Gateway routing and fix
- [ ] Create `rules/hooks-reference.md` — Hook documentation (currently HTML comments)
- [ ] All new files have correct `paths:` frontmatter
- [ ] All new files contain the full detail from the extracted sections

### Milestone 3: Compress CLAUDE.md with @-references
- [ ] Replace verbose sections with 1-2 line summaries + `@path/to/file` references
- [ ] Merge TDD section into Testing as a single line
- [ ] Compress PRD Workflow to 3-4 lines
- [ ] Compress Writing Code to essential rules only (move examples to referenced file if needed)
- [ ] Verify line count is under 150

### Milestone 4: Validate no rules are lost
- [ ] Diff old vs new CLAUDE.md content — every rule accounted for
- [ ] Verify `@` references resolve correctly
- [ ] Test that a fresh Claude Code session loads the rules properly (spot-check a few referenced files)

## Decision Log

| # | Decision | Date | Rationale |
|---|---|---|---|
| 1 | Target 150 lines, ideally ~120 | 2026-03-16 | Every line has token cost across all conversations. Under 150 is the hard constraint; ~120 gives headroom for future additions. |
| 2 | Keep domain-specific short sections inline | 2026-03-16 | OTel Packaging (6 lines), Vals (4 lines), ABOUTME (3 lines) are already concise — extracting them would add file overhead without saving meaningful lines. |
| 3 | Extract hooks reference to a file | 2026-03-16 | 15 lines of HTML comments are useful documentation but don't need to be in every conversation's context. Move to a reference file that's loaded only when editing hooks. |
