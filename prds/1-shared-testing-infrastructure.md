# PRD #1: Shared Claude Code Testing & Developer Infrastructure

**Status**: Draft
**Priority**: High
**Created**: 2026-02-11
**GitHub Issue**: [#1](https://github.com/wiggitywhitney/claude-config/issues/1)
**Context**: Implements Milestone 3 of PRD #25 in commit-story-v2. Layer 0 (global safety net in `~/.claude/settings.json`) is complete. This repo is Layer 1.

---

## Problem

Running Claude Code in skip-permissions mode across multiple repos requires shared testing infrastructure, safety patterns, and verification tooling that doesn't exist yet. Each repo currently has no standardized way to enforce testing, verify work before PRs, or apply consistent development rules. Without shared infrastructure, every new project starts from scratch — no testing guidance, no pre-PR verification, no consistent guardrails.

## Solution

Build this repo (claude-config) as a shared toolkit containing reusable testing infrastructure that can be applied to any project developed with Claude Code. The toolkit includes a testing decision guide, a `/verify` skill, CLAUDE.md templates, testing rules, permission profiles, and a README explaining how to apply everything.

## Research Foundation

Full research at `~/Documents/Repositories/commit-story-v2/docs/research/testing-infrastructure-research.md`. Key sources:

- **Viktor Farcic (dot-ai)**: Integration-first testing, mandatory CLAUDE.md checklist, 10-layer quality gates
- **Michael Forrester (claude-dotfiles)**: 8-step `/verify` command, permission profiles (conservative/balanced/autonomous), TDD enforcement rules
- **Affaan Mustafa (everything-claude-code)**: 8-layer testing redundancy, verification-loop skill, Always/Never rules
- **TACHES (get-shit-done)**: Systemic verification embedded in workflow, pragmatic TDD, script-first deterministic operations

## Deliverables

### 1. Testing Decision Guide
Document that maps project types to testing strategies:

| Project Type | Testing Approach | Key Challenge |
|---|---|---|
| LLM-calling code | Unit tests for logic, contract tests for LLM boundaries, fixture-based regression | Non-determinism in LLM responses |
| Agent frameworks (LangGraph) | Workflow/state machine tests, node-level unit tests, end-to-end scenario tests | Complex state transitions, multi-step flows |
| K8s/infrastructure interaction | Integration tests against real infrastructure (Kind clusters), API contract tests | Heavy infrastructure setup, slow feedback |
| Script-orchestrated tools | Input/output tests, CLI argument validation, file operation verification | Deterministic behavior, filesystem side effects |
| Pure utilities | Standard unit tests, property-based testing, high coverage | Straightforward — just do it |

### 2. /verify Skill
Global slash command installed at `~/.claude/skills/verify/` that runs a verification loop before PRs:

```text
Phase 1: Build        → Compiles cleanly?
Phase 2: Type Check   → Types are sound?
Phase 3: Lint         → Style rules pass?
Phase 4: Tests        → All tests pass?
Phase 5: Security     → No vulnerabilities or leftover debug code?
```

Key design decisions:
- **Stop on first failure, fix, restart from step 1** (from Michael Forrester's approach)
- **Auto-detect project type** — reads package.json, tsconfig.json, etc. to determine commands
- **Node.js/TypeScript first**, extensible to Python/Go later
- **Supports arguments**: `quick` (build + types only), `full` (default), `pre-pr` (full + security)
- Inspired by Michael Forrester's 8-step verify command and Affaan Mustafa's verification-loop skill

### 3. CLAUDE.md Templates
Starter templates with testing rules baked in:

- **Mandatory completion checklist** at the top (inspired by Viktor Farcic):
  - Tests written for new functionality
  - All tests pass
  - No failing tests before marking complete
- **Project-specific sections** to fill in: test command, coverage thresholds, framework, CI pipeline
- **Always/Never testing rules** section
- Template variants: general-purpose, Node.js/TypeScript, Python

### 4. Testing Rules
Always/Never patterns loadable as Claude Code rules:

**Always:**
- Write tests for new functionality before marking a task complete
- Run all tests before committing
- Check for regressions when modifying existing code
- Write integration tests for cross-component interactions
- Use real implementations when feasible; mock only at system boundaries

**Never:**
- Skip tests for "simple" changes
- Commit with failing tests
- Mock when real integration testing is feasible
- Claim work is done without running the test suite
- Hardcode test data that should be generated or parameterized

### 5. Permission Profiles
Reference `settings.json` configurations for three trust levels:

| Profile | Default Mode | Auto-Allow | Ask For | Deny |
|---|---|---|---|---|
| **Conservative** | prompt | Read, Glob, Grep, LS | Everything else | Sensitive files, destructive commands |
| **Balanced** | acceptEdits | + npm/pnpm scripts, git status/log/diff | Write, Edit, git commit/push | Sensitive files, destructive commands |
| **Autonomous** | acceptEdits | + Write, Edit, git add/commit, node, docker compose | git push/merge, rm, docker run | Sensitive files, destructive commands |

All profiles share a universal deny list blocking `.env`, `*.pem`, `~/.ssh`, `sudo`, `rm -rf`, etc.

### 6. README
How to use this repo:
- What this toolkit provides
- How to apply it to a new project (step-by-step)
- How to install the `/verify` skill globally
- How to choose a permission profile
- How to use the testing decision guide
- Links to each deliverable

## Success Criteria

- [ ] All 6 deliverables exist in the repo
- [ ] `/verify` skill has been tested in at least one real project (commit-story-v2)
- [ ] README explains how to apply this toolkit to a new repo
- [ ] Testing decision guide covers all 5 project types listed above
- [ ] Permission profiles are valid `settings.json` configurations

## Milestones

### Milestone 1: /verify Skill (Highest Value)
Create the global `/verify` slash command that runs build → type check → lint → tests → security scan as a pre-PR verification loop. Install to `~/.claude/skills/verify/`. Test against commit-story-v2 to validate it works on a real project.

- [ ] `/verify` skill created with auto-detection and stop-on-failure loop
- [ ] Tested successfully in commit-story-v2

### Milestone 2: Testing Decision Guide + Testing Rules
Create the testing decision guide mapping project types to strategies, and the Always/Never testing rules. These two deliverables are closely related and form the intellectual foundation of the toolkit.

- [ ] Testing decision guide covers all 5 project types with concrete guidance
- [ ] Testing rules documented as Always/Never patterns

### Milestone 3: CLAUDE.md Templates + Permission Profiles
Create the CLAUDE.md starter templates with testing rules baked in, and the three permission profile configurations. These are the "apply to a new project" deliverables.

- [ ] CLAUDE.md templates created (general + Node.js/TypeScript)
- [ ] Permission profiles are valid, tested configurations

### Milestone 4: README + Integration Testing
Write the README explaining how to use the toolkit and apply it to new projects. Do a final integration pass ensuring everything works together.

- [ ] README covers all deliverables with clear instructions
- [ ] End-to-end walkthrough of applying toolkit to a project works

## Out of Scope

- Per-project test suites (those belong in each repo's own PRD)
- CI/CD pipeline templates (future enhancement)
- Python/Go `/verify` support (Node.js/TypeScript first, extensible later)
- Hooks system (future enhancement — may add pre-commit hooks later)
- Agent definitions (not needed for this toolkit's scope)
