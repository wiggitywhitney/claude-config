# PRD #5: CodeRabbit CLI Integration & Code Review Tool Evaluation

**Status**: Not Started
**Priority**: Medium
**Created**: 2026-02-18
**GitHub Issue**: [#5](https://github.com/wiggitywhitney/claude-config/issues/5)
**Context**: PR merge cycles currently include ~5 minute idle waits for CodeRabbit's GitHub-based review after PR creation. The CodeRabbit MCP server works but adds token overhead to every session. CodeRabbit recently launched a CLI tool that runs reviews locally. OpenAI's Codex is an alternative worth evaluating.

---

## Problem

The current code review workflow has two pain points:

1. **Merge cycle latency**: After creating a PR, there's a ~5 minute wait for CodeRabbit's GitHub-based review before the PR can be merged. During YOLO mode, this creates idle cycles where Claude Code is waiting instead of working.

2. **MCP server overhead**: The CodeRabbit MCP server loads tool schemas into Claude's context on every session, consuming tokens even when code review isn't needed. A CLI-based approach (like the dot-ai pattern) could reduce this overhead.

Additionally, no evaluation has been done of whether CodeRabbit is still the best tool for AI-powered code review, or whether alternatives like OpenAI Codex offer better capabilities for this workflow.

## Solution

Research-first approach: evaluate CodeRabbit CLI and alternatives (Codex), then integrate the best option into the existing hook-based workflow. The goal is faster review feedback with less token overhead — ideally catching issues locally before a PR is even created.

## Current Workflow

```text
implement → commit (hook: quick+lint) → push (hook: full verify) → create PR (hook: pre-pr verify)
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

- [ ] CodeRabbit CLI capabilities fully documented with hands-on testing
- [ ] Codex code review capabilities evaluated and documented
- [ ] Clear recommendation made with rationale
- [ ] Chosen tool integrated into workflow, reducing merge cycle latency
- [ ] Token overhead reduced compared to current MCP server approach
- [ ] Review quality maintained or improved

## Milestones

### Milestone 1: Research — CodeRabbit CLI
Hands-on evaluation of CodeRabbit CLI. Install it, run it against real code, document what it can and can't do.

- [ ] Install CodeRabbit CLI and run against a real project
- [ ] Document capabilities: what it reviews, output format, configuration options
- [ ] Test as pre-PR local check: can it catch the same issues the GitHub review catches?
- [ ] Evaluate token/cost implications vs MCP server approach
- [ ] Document limitations and gaps compared to GitHub-based review

### Milestone 2: Research — Codex & Alternatives
Evaluate Codex and any other notable code review tools as alternatives.

- [ ] Research Codex code review capabilities (features, accuracy, integration options)
- [ ] Hands-on test if possible — run against same code as CodeRabbit CLI for comparison
- [ ] Evaluate cost, token usage, and integration complexity
- [ ] Document findings in `research/code-review-tool-evaluation.md`

### Milestone 3: Recommendation & Decision
Compare tools and make a clear recommendation.

- [ ] Create comparison matrix (features, accuracy, speed, cost, integration effort)
- [ ] Make recommendation with rationale
- [ ] Record decision in this PRD's Decision Log

### Milestone 4: Integration
Integrate the chosen tool into the existing workflow.

- [ ] Determine integration point: hook (pre-push? pre-PR?), skill, or standalone CLI step
- [ ] Implement integration (hook script, CLAUDE.md updates, settings changes)
- [ ] Update or replace CodeRabbit MCP server configuration if applicable
- [ ] Update YOLO mode workflow if merge cycle changes
- [ ] Test end-to-end in at least one real project

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
