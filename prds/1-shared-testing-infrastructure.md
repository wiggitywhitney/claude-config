# PRD #1: Shared Claude Code Testing & Developer Infrastructure

**Status**: In Progress
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

#### Architecture: Skill + Deterministic Scripts

The `/verify` skill uses a **hybrid architecture**: a skill prompt that defines the process and behavioral constraints, underpinned by deterministic bash scripts that do the actual work.

**Why a skill, not just a script?** The skill controls Claude's autonomous behavior — ensuring it follows the defined verification process (phases, ordering, stop-on-failure rules) rather than improvising its own approach. The skill is a behavioral contract, not AI-powered verification.

**Why scripts underneath?** Every verification phase is deterministic — file existence checks, command execution, grep patterns, exit codes. Scripts provide reliable, predictable results with no AI inference overhead.

**Script components:**

| Script | Responsibility |
|---|---|
| `detect-project.sh` | Reads config files (package.json, tsconfig.json, etc.), outputs project type and available commands |
| `verify-phase.sh` | Runs a single verification phase by name, returns exit code |
| `security-check.sh` | Greps for debug code, secrets, .only, staged .env files |

**The skill orchestrates the scripts**: calls each in sequence, interprets results per the defined rules, communicates findings, and suggests fixes when phases fail.

#### Key design decisions:
- **Stop on first failure, fix, restart from step 1** (from Michael Forrester's approach)
- **Auto-detect project type** — reads package.json, tsconfig.json, etc. to determine commands
- **Node.js/TypeScript first**, extensible to Python/Go later
- **Supports arguments**: `quick` (build + types only), `full` (default), `pre-pr` (full + security)
- **Script-first principle** — all verification logic is deterministic; AI handles orchestration and communication only
- Inspired by Michael Forrester's 8-step verify command and Affaan Mustafa's verification-loop skill

#### Pre-PR Security Checks (`pre-pr` mode)
In addition to the standard 5-phase verification, `pre-pr` mode runs:
- `npm audit` for dependency vulnerabilities
- Grep for hardcoded secrets/API keys in the staged diff
- Grep for leftover `console.log` / `debugger` statements
- Check that no `.env` files are staged

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
Create the global `/verify` slash command that runs build → type check → lint → tests → security scan as a pre-PR verification loop. Install to `~/.claude/skills/verify/`. Includes a PreToolUse hook on `git commit` that runs verification as a deterministic, diff-scoped gate — blocks the commit if any phase fails. Test against commit-story-v2 to validate it works on a real project.

- [x] `/verify` skill created with auto-detection and stop-on-failure loop
- [x] PreToolUse hook on `git commit` runs verification and blocks on failure
- [x] Tested successfully in commit-story-v2
- [ ] Refactor hook to scope security checks to staged diff only (fix crash from vendor files with invalid Unicode)
- [ ] Scope lint phase to changed files only in the hook
- [ ] Keep build/typecheck as whole-project in the hook

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
- Full hooks system (future enhancement — the single `/verify` PreToolUse hook is in scope, but a comprehensive hooks framework is not)
- Agent definitions (not needed for this toolkit's scope)
- LangGraph orchestration — the verification process is linear (not a complex state machine), so a skill + scripts approach is sufficient. LangGraph would add infrastructure overhead (Python runtime, API keys, separate system) without meaningful benefit for a sequential 5-phase process.

## Decision Log

### Decision 1: Hybrid Skill + Scripts Architecture
- **Date**: 2026-02-11
- **Decision**: `/verify` will be a Claude Code skill (behavioral prompt) that orchestrates deterministic bash scripts, not a pure skill or pure bash script
- **Rationale**: The skill controls Claude's autonomous behavior (follow this process, in this order, with these rules). The scripts handle all deterministic work (project detection, command execution, pattern matching). This aligns with the script-first principle: use scripts for file operations, validation, and command execution; use AI for process control, interpretation, and communication.
- **Impact**: Milestone 1 deliverable includes both a skill prompt file and supporting bash scripts

### Decision 2: Pre-PR Security Checks Defined
- **Date**: 2026-02-11
- **Decision**: The `pre-pr` mode runs four specific additional checks beyond the standard 5-phase verification
- **Rationale**: Based on research sources (Michael Forrester, Affaan Mustafa), these are the highest-value pre-PR security checks that catch common mistakes before code reaches remote
- **Impact**: `security-check.sh` script scope expanded; `pre-pr` mode is now concretely defined rather than vaguely "extra security"

### Decision 4: PreToolUse Hook on git commit (Enforcement Gate)
- **Date**: 2026-02-11
- **Decision**: Add a global PreToolUse hook on `Bash` that detects `git commit` commands and runs the verification scripts directly as a blocking gate. No state tracking — runs fresh every time.
- **Rationale**: The hook runs the same deterministic scripts (detect-project, verify-phase, security-check) every time a commit is attempted. If any phase fails, the commit is blocked. No timestamp files or state management needed. Commit was chosen over push because it provides earlier feedback and implicitly makes all pushes safe (you can't push unverified commits). Push doesn't need its own hook since every committed change has already been verified.
- **Impact**: Added to Milestone 1; moves hooks from "out of scope" to "targeted single hook in scope"; eliminates need for CLAUDE.md rules about running /verify

### Decision 5: Two-Layer Verification Design (Updated 2026-02-11)
- **Date**: 2026-02-11
- **Decision**: `/verify` exists as two complementary layers: (1) the skill for ad-hoc full-codebase verification, and (2) the hook for enforcement — a deterministic, diff-scoped commit gate
- **Rationale**: The skill runs all 5 phases across the whole codebase for thorough pre-PR sweeps. The hook runs the same phases but scoped to the staged diff — lightweight, fast, and only checks what you're actually committing. Fix-and-retry is emergent from Claude Code's hook system (deny → Claude sees error → Claude fixes → retries commit → hook fires again), so neither layer needs to orchestrate retry loops explicitly.
- **Impact**: The hook is diff-scoped and lightweight; the skill remains full-codebase. The hook does its own inline diff-scoped checks rather than calling the same whole-codebase scripts.

### Decision 6: Replace CLAUDE.md Style Rules with Hooks
- **Date**: 2026-02-11
- **Decision**: Replace the CLAUDE.md rule about markdown code block language specifiers with a PostToolUse hook on `Write|Edit`. The hook runs a stateful parser (tracks opening vs closing fences) and feeds violations back to Claude immediately after writing.
- **Rationale**: CLAUDE.md style rules have two costs: they consume context window space on every conversation, and prompt compliance isn't 100%. A PostToolUse hook is deterministic (zero context, 100% enforcement) and catches issues at the moment of writing — before they reach commit or CodeRabbit review. This principle applies to any behavioral rule that can be checked programmatically.
- **Impact**: Removes code block language specifier rule from CLAUDE.md; adds PostToolUse hook and `check-markdown-codeblocks.py` script to the toolkit

### Decision 7: Hook Scoped to Git Diff
- **Date**: 2026-02-11
- **Decision**: The pre-commit hook scopes all checks to `git diff --cached` (staged files only), not the whole codebase. Security checks (console.log, debugger, .only) grep the staged diff for added lines. Lint runs on changed files only. Build and typecheck remain whole-project (they inherently must be).
- **Rationale**: Scanning the whole codebase on every commit is expensive, noisy, and dangerous. In practice, `git grep` across the whole repo found console.log in third-party vendor files (`.obsidian/plugins/dataview/main.js`) that contained invalid Unicode surrogates, which broke Claude API JSON serialization and caused a crash loop. Scoping to the diff means you only check what you're actually committing — faster, safer, and no false positives from vendor code.
- **Impact**: Refactored `pre-commit-hook.sh` to do diff-scoped security checks inline rather than calling `security-check.sh`. The skill's `security-check.sh` remains unchanged for full-codebase ad-hoc use.

### Decision 8: Fix-and-Retry is Emergent
- **Date**: 2026-02-11
- **Decision**: The fix-and-retry loop does not need to be explicitly orchestrated in the skill or hook. It emerges naturally from Claude Code's hook system.
- **Rationale**: When the pre-commit hook blocks a commit (returns `deny` with an error reason), Claude Code reads the denial reason, fixes the issue, and attempts the commit again — which triggers the hook again. This IS the fix-and-retry loop. It requires zero additional orchestration, zero context cost, and works consistently because it's a property of the hook system, not prompt compliance. The `/verify` skill can stay as-is for ad-hoc use.
- **Impact**: No changes to skill; confirms the hook design is sufficient without AI orchestration.

### Decision 3: LangGraph Not Needed
- **Date**: 2026-02-11
- **Decision**: Use skill + scripts, not LangGraph, for orchestrating the verification process
- **Rationale**: The verification process is linear (phase 1 → 2 → 3 → 4 → 5 with one conditional restart edge). LangGraph adds value for complex state machines with branching, parallel paths, or multi-agent coordination. For a sequential checklist, the overhead of a Python runtime, LangGraph dependency, and separate API calls isn't justified.
- **Impact**: No Python/LangGraph dependency; simpler deployment as markdown + bash
