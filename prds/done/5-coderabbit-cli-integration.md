# PRD #5: CodeRabbit CLI Integration & Code Review Tool Evaluation

**Status**: Complete
**Priority**: Medium
**Created**: 2026-02-18
**GitHub Issue**: [#5](https://github.com/wiggitywhitney/claude-config/issues/5)
**Context**: PR merge cycles currently include ~5-minute idle waits for CodeRabbit's GitHub-based review after PR creation. The CodeRabbit MCP server works but adds token overhead to every session. CodeRabbit recently launched a CLI tool that runs reviews locally. OpenAI's Codex is an alternative worth evaluating.

---

## Problem

The current code review workflow has two pain points:

1. **Merge cycle latency**: After creating a PR, there's a ~5-minute wait for CodeRabbit's GitHub-based review before the PR can be merged. During YOLO mode, this creates idle cycles where Claude Code is waiting instead of working.

2. **MCP server overhead**: The CodeRabbit MCP server loads tool schemas into Claude's context on every session, consuming tokens even when code review isn't needed. A CLI-based approach (like the dot-ai pattern) could reduce this overhead.

Additionally, no evaluation has been done of whether CodeRabbit is still the best tool for AI-powered code review, or whether alternatives like OpenAI Codex offer better capabilities for this workflow.

## Solution

Research-first approach: evaluate CodeRabbit CLI and alternatives (Codex), then integrate the best option into the existing hook-based workflow. The goal is faster review feedback with less token overhead — ideally catching issues locally before a PR is even created.

## Current Workflow

```text
implement → commit (hook: quick+lint) → push (hook: security + CodeRabbit CLI review) → create PR (hook: pre-pr verify)
→ wait ~5 min for CodeRabbit GitHub review → address comments → merge
```

### Current CodeRabbit Integration Points
- **MCP Server**: `mcp__coderabbitai__get_coderabbit_reviews`, `mcp__coderabbitai__get_review_comments`, `mcp__coderabbitai__resolve_comment`, etc.
- **CLAUDE.md rules**: "PRs require CodeRabbit review examined and approved by human before merge"
- **YOLO mode**: Wait 5 min, check review, address comments, merge
- **`.skip-coderabbit` dotfile**: Per-repo opt-out (Decision 16, PRD #1)

## Deliverables

### 1. Research: CodeRabbit CLI Capabilities
Understand what the CLI can do, how it compares to the GitHub-based review, and whether it can run as a pre-PR local check.

### 2. Research: Codex as Code Review Alternative
Evaluate OpenAI Codex for code review capabilities, comparing features, accuracy, integration options, and cost against CodeRabbit.

### 3. Tool Comparison & Recommendation
Side-by-side evaluation with a clear recommendation on which tool (or combination) to adopt.

### 4. Integration Implementation
Integrate the chosen tool into the existing workflow — hooks, CLAUDE.md rules, and/or CLI-based pre-PR checks.

## Success Criteria

- [x] CodeRabbit CLI capabilities fully documented with hands-on testing
- [x] Codex code review capabilities evaluated and documented
- [x] Clear recommendation made with rationale
- [x] Chosen tool integrated into workflow, reducing merge cycle latency
- [~] Token overhead reduced compared to current MCP server approach *(Decision 3: MCP overhead is negligible ~$0.10/mo; not worth removing)*
- [x] Review quality maintained or improved

## Milestones

### Milestone 1: Research — CodeRabbit CLI
Hands-on evaluation of CodeRabbit CLI. Install it, run it against real code, document what it can and can't do.

- [x] Install CodeRabbit CLI and run against a real project
- [x] Document capabilities: what it reviews, output format, configuration options
- [x] Test as pre-PR local check: can it catch the same issues the GitHub review catches?
- [x] Evaluate token/cost implications vs MCP server approach
- [x] Document limitations and gaps compared to GitHub-based review

### Milestone 2: Research — Codex & Alternatives
Evaluate Codex and any other notable code review tools as alternatives.

- [x] Research Codex code review capabilities (features, accuracy, integration options)
- [~] Hands-on test if possible — run against same code as CodeRabbit CLI for comparison *(skipped — Decision 2: research sufficient)*
- [x] Evaluate cost, token usage, and integration complexity
- [x] Document findings in `research/code-review-tool-evaluation.md`

### Milestone 3: Recommendation & Decision
Compare tools and make a clear recommendation.

- [x] Create comparison matrix (features, accuracy, speed, cost, integration effort)
- [x] Make recommendation with rationale
- [x] Record decision in this PRD's Decision Log

### Milestone 4: Integration
Integrate the chosen tool into the existing workflow.

- [x] Determine integration point: hook (pre-push? pre-PR?), skill, or standalone CLI step *(Decision 3: pre-push hook)*
- [x] Implement integration (hook script, CLAUDE.md updates, settings changes)
- [x] Update or replace CodeRabbit MCP server configuration if applicable *(Decision 3: keep as-is, no changes needed)*
- [x] Update YOLO mode workflow if merge cycle changes
- [x] Test end-to-end in at least one real project

## Out of Scope

- Building a custom code review tool
- Evaluating more than 2-3 tools (focused comparison, not exhaustive survey)
- Changing the fundamental PR-based workflow (PRs are still the merge mechanism)

## Decision Log

### Decision 1: Research-First, Two-Tool Evaluation
- **Date**: 2026-02-18
- **Decision**: Start with hands-on research of both CodeRabbit CLI and Codex before committing to an integration approach. Evaluate both tools against real code in Whitney's repos.
- **Rationale**: The CodeRabbit CLI is new (launched ~September 2025) and its capabilities relative to the GitHub-based review aren't well understood. Codex is a viable alternative that hasn't been evaluated. Making an integration decision without hands-on testing would be premature.
- **Impact**: Milestones 1-2 are research-focused. Integration work (Milestone 4) depends on the recommendation from Milestone 3.

### Decision 2: Codex Is Complementary, Not a Replacement
- **Date**: 2026-02-25
- **Decision**: Codex is not a viable replacement for CodeRabbit. It's a general-purpose coding agent whose `/review` is a secondary feature, not the product. Weekly review caps (10-25/week on $20/mo ChatGPT Plus) are insufficient for active development. CodeRabbit and Codex are officially documented as complementary tools. Skip hands-on Codex testing; move to recommendation.
- **Rationale**: Research showed Codex's review caps, clunky headless output (requires jq post-processing), and lack of Claude Code integration make it impractical for the hook-based workflow. CodeRabbit CLI is purpose-built for exactly this use case.
- **Impact**: Milestone 2 completed early (research sufficient, hands-on testing unnecessary). Recommendation scope narrowed to CodeRabbit integration approach rather than tool selection.

### Decision 3: Hybrid — CLI Pre-Push + PR Review, Keep MCP
- **Date**: 2026-02-25
- **Decision**: Add CodeRabbit CLI review as a pre-push hook step. Keep GitHub PR reviews as the merge gate. Keep the MCP server as-is.
- **Rationale**: CLI and PR reviews catch different things — the PR review has full PR context, cross-file analysis, conversation threading, and incremental re-review that the CLI cannot provide. The CLI catches issues in ~30s before a PR exists, potentially eliminating a full review round-trip (fix → push → wait 5 more minutes for re-review). MCP server token overhead (~2000-3000 tokens/session) is negligible in cost and context window impact, and the MCP tools provide real value for checking review status and resolving comments programmatically.
- **Impact**: Milestone 4 integration scope: add CLI review to pre-push hook. No changes to MCP server, PR review workflow, or merge gate requirements.
