# PRD #43: Refactor Global CLAUDE.md

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
