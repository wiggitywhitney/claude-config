# PRD #1: Shared Claude Code Testing & Developer Infrastructure

**Status**: Complete
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

Full research at [`wiggitywhitney/commit-story-v2` `docs/research/testing-infrastructure-research.md`](https://github.com/wiggitywhitney/commit-story-v2/blob/main/docs/research/testing-infrastructure-research.md). Key sources:

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
Phase 4: Security     → No vulnerabilities or leftover debug code?
Phase 5: Tests        → All tests pass?
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

- [x] All 6 deliverables exist in the repo
- [x] `/verify` skill has been tested in at least one real project (commit-story-v2)
- [x] README explains how to apply this toolkit to a new repo
- [x] Testing decision guide covers all 5 project types listed above
- [x] Permission profiles documented as guide with tier-down pattern (Decision 20)

## Milestones

### Milestone 1: /verify Skill + Tiered Verification Hooks (Highest Value)
Create the global `/verify` slash command for ad-hoc interactive verification. Create three deterministic PreToolUse hooks that gate git events at increasing verification levels: quick+lint on commit, full on push, pre-pr on PR creation (Decisions 10, 11). All hooks run scripts directly — no skill invocation. Install to `~/.claude/skills/verify/`. Test against commit-story-v2 and Journal repo.

- [x] `/verify` skill created with auto-detection and stop-on-failure loop
- [x] PreToolUse hook on `git commit` runs verification and blocks on failure
- [x] Tested successfully in commit-story-v2
- [x] Tested successfully in Journal repo (second real project, caught vendor file issues)
- [x] Hook handles `git -C <path> commit` pattern used by Claude Code
- [x] Output truncation and Unicode sanitization prevent API crash from vendor files
- [x] `.verify-skip` file excludes vendor paths from all security checks
- [x] Keep build/typecheck as whole-project in the hook (inherently must be)
- [x] Scope security checks to staged diff only in the hook (Decision 7)
- [x] Scope lint phase to changed files only in the hook
- [x] Refactor commit hook from full to quick+lint mode (Decision 10)
- [x] Add PreToolUse hook on `git push` running full verification (Decision 10)
- [x] Add PreToolUse hook on `gh pr create` running pre-pr verification (Decision 10)
- [x] All hooks are purely deterministic — scripts only, no skill invocation (Decision 11)

### Milestone 2: Testing Decision Guide + Testing Rules
Create the testing decision guide mapping project types to strategies, and the Always/Never testing rules. These two deliverables are closely related and form the intellectual foundation of the toolkit.

- [x] Testing decision guide covers all 5 project types with concrete guidance
- [x] Testing rules documented as Always/Never patterns

### Milestone 3: CLAUDE.md Templates + Permission Profiles
Create the CLAUDE.md starter templates with testing rules baked in, and the three permission profile configurations. These are the "apply to a new project" deliverables. Work in three phases: (1) research Forrester's `claude-config/` directory fresh per Decision 14, (2) audit and refactor Whitney's own CLAUDE.md files per Decision 15, (3) generalize into templates. Language-specific rules factored into `rules/languages/` per Decision 13.

- [x] Research `claude-config/` directory of `peopleforrester/llm-coding-workflow` (CLAUDE.md, rules/, hooks/, skills/, settings.json)
- [x] Audit and refactor Whitney's global `~/.claude/CLAUDE.md` — factor out what can move to hooks/rules, apply Forrester's patterns (HTML comments for hook docs, lean file, etc.)
- [x] Audit and refactor project-level CLAUDE.md files using same principles
- [x] CLAUDE.md templates created (general + Node.js/TypeScript), based on refactored real config and Decision 19 patterns (lean ~150 lines, `rules/` with path-based activation, placeholder stubs). Applied to: choose-your-ai-adventure, mcp-hello-world, commit_story, commit-story-v1, spider-rainbows. Authoring guide at `guides/claude-md-guide.md`.
- [x] Per-language rule files created in `rules/languages/` with `paths:` frontmatter activation (Decision 13, Decision 19 pattern 2-3): TypeScript, JavaScript, Shell (real rules); Python, Go (placeholders)
- [x] Permission profiles documented as guide with tier-down pattern from autonomous baseline (Decision 20)
- [x] Create commit message hook that blocks AI/Claude/Co-Authored-By references in commits (Decision 17). Prompt-level rule already exists in global CLAUDE.md; this adds deterministic hook enforcement.
- [x] Add dotfile override checks (`.skip-branching`, `.skip-coderabbit`) to existing hooks (Decision 16). Prompt-level rule already exists in global CLAUDE.md; this adds deterministic hook enforcement.

### Milestone 4: Test Tier Enforcement Hooks with Dotfile Opt-Outs
Enforce that every project has unit, integration, and end-to-end tests — unless the repo explicitly opts out via dotfiles (`.skip-e2e`, `.skip-integration`). Builds on the verification hooks from Milestone 1 and the dotfile override pattern from Decision 16. Natural continuation of the hook work in Milestones 1 and 3 (Decision 21).

- [x] Define what "has tests" means per project type (Node.js/TypeScript: test runner config + test files exist; detect via package.json scripts, test directories)
- [x] Create hook that checks test tier presence on git push or PR creation
- [x] Hook respects `.skip-e2e` and `.skip-integration` dotfiles — skips enforcement for opted-out tiers
- [x] Hook warns (not blocks) when test tiers are missing — gives teams time to add coverage rather than hard-blocking
- [x] Tested across at least two repos with different test configurations

### Milestone 5: README + Integration Testing
Write the README explaining how to use the toolkit and apply it to new projects. Do a final integration pass ensuring everything works together. Documentation follows the execute-then-document principle (Decision 21): every example must come from real execution, not invented output.

- [x] README covers all deliverables with clear instructions
- [x] All README examples are validated by executing them against a real project
- [x] End-to-end walkthrough of applying toolkit to a new project works
- [x] Cross-references between guides, templates, rules, and README are verified

### Milestone 6: Anki Card Review + Creation
Review existing Anki cards for accuracy, then create new cards capturing what was built in this PRD. Cards are both a learning tool and a completeness check — if something can't be turned into a clear card, the concept may not be well enough understood.

**Review existing cards** in `~/Documents/Journal/make Anki cards/finished/`:
- [x] Review "CARDS MADE - Claude Code Skills.md" (18 cards) — verify skill frontmatter fields, safety guardrails, and tool access control are current
- [x] Review "CARDS MADE - Claude Code Plugins and Ralph Loops.md" (30 cards) — verify hooks, verification patterns, and autonomous looping cards reflect tiered hooks (Decisions 10-12)
- [x] Review "CARDS MADE - Claude Code Native Tools.md" (9 cards) — verify tool categories are current
- [x] Update any cards that are stale or inaccurate given the current implementation

**Create new cards** for PRD 1 deliverables:
- [x] Cards for CLAUDE.md authoring patterns (lean files, hierarchy, @imports, what to include/exclude)
- [x] Cards for per-language rule files (paths: frontmatter, placeholder pattern, organization)
- [x] Cards for permission profile tiers (conservative/balanced/autonomous, deny list, tier-down pattern)
- [x] Cards for the verify skill and tiered hooks (commit/push/PR, phase ordering, Decision 12)
- [x] Cards for hook authoring conventions (exit 2 vs exit 0, dotfile opt-outs)

## Out of Scope

- Per-project test suites (those belong in each repo's own PRD)
- CI/CD pipeline templates (future enhancement)
- Python/Go `/verify` support (Node.js/TypeScript first, extensible later)
- General-purpose hooks framework (the three tiered verification hooks are in scope per Decision 10, but a broader hooks system for arbitrary enforcement is not)
- Agent definitions (not needed for this toolkit's scope)
- LangGraph orchestration — the verification process is linear (not a complex state machine), so a skill + scripts approach is sufficient. LangGraph would add infrastructure overhead (Python runtime, API keys, separate system) without meaningful benefit for a sequential 5-phase process.
- `/write-docs` skill — Vfarcic's `dot-ai` repo has a reusable documentation skill that enforces execute-then-document, chunk-by-chunk writing with user confirmation gates. Valuable pattern but out of scope for PRD 1 (testing infrastructure). The execute-then-document principle is adopted for Milestone 5's README. A full write-docs skill is a candidate for a future PRD.

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

### Decision 9: Hook Success Visibility via additionalContext
- **Date**: 2026-02-11
- **Decision**: PreToolUse hooks must use `additionalContext` (not just `permissionDecisionReason`) for Claude to see allow-decision messages. Both fields are needed: `permissionDecisionReason` is shown to the user, `additionalContext` is shown to Claude.
- **Rationale**: Discovered through testing that allow decisions with only `permissionDecisionReason` were invisible to Claude — it silently proceeded. The `additionalContext` field is what Claude Code injects into the AI's context. Using both ensures the success message ("verify: pre-commit check passed") is visible to both human and AI.
- **Impact**: Updated hook JSON output to include both fields. Confirmed working in Journal repo.

### Decision 3: LangGraph Not Needed
- **Date**: 2026-02-11
- **Decision**: Use skill + scripts, not LangGraph, for orchestrating the verification process
- **Rationale**: The verification process is linear (phase 1 → 2 → 3 → 4 → 5 with one conditional restart edge). LangGraph adds value for complex state machines with branching, parallel paths, or multi-agent coordination. For a sequential checklist, the overhead of a Python runtime, LangGraph dependency, and separate API calls isn't justified.
- **Impact**: No Python/LangGraph dependency; simpler deployment as markdown + bash

### Decision 10: Tiered Verification Hooks (Supersedes Decision 4)
- **Date**: 2026-02-14
- **Decision**: Replace the single full-verification commit hook with three tiered hooks, each mapped to a git event and running the appropriate verification mode:

| Git Event | Hook Type | Verification Mode | Phases |
|---|---|---|---|
| `git commit` | PreToolUse | quick + lint | Build, Type Check, Lint |
| `git push` | PreToolUse | full | Build, Type Check, Lint, Security, Tests |
| `gh pr create` | PreToolUse | pre-pr | Build, Type Check, Lint, Security (expanded), Tests |

- **Rationale**: Decision 4 assumed full verification per commit was acceptable. In practice, running the full suite (including tests) on every commit is too heavy and slows iteration. The three verification modes (`quick`, `full`, `pre-pr`) already exist in the `/verify` skill — they just weren't wired to the right git events. Tiered hooks match the natural escalation: commits are frequent and should be fast, pushes are deliberate sharing points worth thorough checks, and PRs are the final gate before review.
- **Impact**: Refactors Milestone 1 from a single commit hook to three hooks. The commit hook becomes lighter (quick + lint). Push and PR hooks are new deliverables. The existing scripts (`detect-project.sh`, `verify-phase.sh`, `security-check.sh`) support all three tiers without modification.

### Decision 11: All Hooks Are Purely Deterministic (No Skill Invocation)
- **Date**: 2026-02-14
- **Decision**: All verification hooks run scripts directly. No hook invokes the `/verify` skill. The `/verify` skill remains exclusively for ad-hoc interactive use when a human explicitly runs `/verify`.
- **Rationale**: The existing commit hook already works this way — it calls `detect-project.sh`, `verify-phase.sh`, and `security-check.sh` directly without involving the skill. This is the right pattern. Hooks are enforcement gates. They should be deterministic, fast, and predictable. Invoking a skill from a hook would add AI inference overhead and non-determinism to what should be a pass/fail gate. The new push and PR hooks follow the same purely-deterministic pattern. This clarifies the relationship between the skill and the hooks established in Decision 5: the skill is for interactive exploration (AI orchestrates scripts, communicates findings, suggests fixes), the hooks are for enforcement (scripts only, no AI, pass/fail).
- **Impact**: Confirms the architecture pattern for all three tiered hooks. No changes to existing scripts. The skill and hooks share the same script library but serve different purposes.

### Decision 12: Security Before Tests (Fail-Fast Ordering)
- **Date**: 2026-02-17
- **Decision**: Swap the order of Security and Tests in all verification modes that include both. The phase order is now: Build → Type Check → Lint → Security → Tests. This applies to the `full` and `pre-pr` modes (push and PR hooks), and to the `/verify` skill's full/pre-pr runs. The `quick` mode (commit hook) is unaffected since it runs neither.
- **Rationale**: Security checks are cheap — grepping the staged diff for console.log, debugger, .only, and .env files takes milliseconds. Tests can take seconds to minutes. Under the stop-on-first-failure rule, a failed phase triggers a fix and restart from phase 1. Running the expensive phase last means you only pay that cost after all cheap checks have passed. If security ran after tests, a trivial issue like a staged `.env` file would waste the entire test run before being caught — and then tests would have to run again after the fix.
- **Impact**: Updates phase ordering in the `/verify` skill description and Decision 10's tiered hook table. The push and PR hooks (not yet built) should implement this order from the start. The existing `pre-commit-hook.sh` will also be updated when it's refactored to quick+lint mode per Decision 10 (tests and security drop out entirely, so the order change is moot for that hook).

### Decision 13: Per-Language Rules Factored Out of CLAUDE.md
- **Date**: 2026-02-18
- **Decision**: Language-specific rules (Python, TypeScript, Go, etc.) should be factored into separate files rather than inlined in CLAUDE.md templates. Templates reference per-language rule files instead of embedding language rules inline.
- **Rationale**: CLAUDE.md context is expensive — every rule consumes tokens on every conversation. Language-specific rules (import ordering, type annotation conventions, linter configuration) are irrelevant when working in a different language. Factoring them into `rules/languages/python.md`, `rules/languages/typescript.md`, etc. means only the relevant language rules are loaded. Pattern observed in Michael Forrester's llm-coding-workflow repo, which uses this exact structure.
- **Impact**: Milestone 3 CLAUDE.md templates will include a `rules/` directory structure with per-language files rather than monolithic templates. Templates will document how to include only relevant language rules.

### Decision 14: Milestone 3 Research Scope — llm-coding-workflow
- **Date**: 2026-02-18
- **Decision**: When implementing Milestone 3, the implementing agent must research the `claude-config/` directory of `https://github.com/peopleforrester/llm-coding-workflow` before writing any deliverables. Research scope: `CLAUDE.md` (137 lines), `rules/` (12 domain-specific files including per-language), `hooks/` (3 Claude Code automation hooks), `skills/` (25+ custom commands), and `settings.json`. Skip `src/`, `tests/`, `assessments/`, and `design-decisions/` — those are CLI implementation, not config patterns. Borrowing verbatim patterns is acceptable where they fit.
- **Rationale**: That repo's `claude-config/` directory is a production reference implementation of a mature Claude Code configuration. The 137-line CLAUDE.md demonstrates how to keep the file lean by factoring deterministic rules into hooks, domain-specific rules into `rules/` files, and using HTML comments to document hook-enforced rules for human readers without burning Claude's context. Understanding the content distribution pattern (what goes where and why) is more valuable than any single file.
- **Impact**: Milestone 3 implementation begins with research of the `claude-config/` directory to understand the content distribution pattern, then applies it.

### Decision 15: Refactor Own CLAUDE.md Before Writing Templates
- **Date**: 2026-02-18
- **Decision**: Milestone 3 should begin with a CLAUDE.md audit and refactor of Whitney's own global (`~/.claude/CLAUDE.md`) and project-level CLAUDE.md files before writing generalized templates. This is a learning exercise that directly informs template design.
- **Rationale**: Practicing on real config and then generalizing produces better templates than designing from theory. The refactor applies Forrester's patterns: lean CLAUDE.md (~150 lines max), deterministic rules moved to hooks, domain-specific rules factored into `rules/` files, HTML comments documenting what hooks enforce. Improvements apply regardless of whether they're testing-related — the goal is a clean, well-factored configuration.
- **Impact**: Milestone 3 gains a new first item: audit and refactor Whitney's CLAUDE.md files. The refactored result becomes the basis for the generalized templates.

### Decision 16: Per-Repo Rule Overrides via Dotfiles
- **Date**: 2026-02-18
- **Decision**: Individual repos can opt out of globally-enforced rules by placing dotfiles at the project root (e.g., `.skip-branching`, `.skip-coderabbit`). Global hooks check for these files and skip enforcement when present.
- **Rationale**: Global CLAUDE.md and hooks enforce strict defaults (feature branches, CodeRabbit reviews, verification). But some repos have legitimate reasons to opt out — private repos don't use CodeRabbit, the Journal repo doesn't need branch protection. Dotfiles are visible to humans (`ls -a`), committed to git (decisions tracked in history), and checked at the hook level (deterministic, zero context cost). This is an extension of the existing `.verify-skip` pattern.
- **Impact**: Hooks gain dotfile checks. Global CLAUDE.md states strict defaults; per-repo dotfiles declare exceptions.

### Decision 17: Professional Commit Messages — No AI Attribution
- **Date**: 2026-02-18
- **Decision**: Commit messages must never reference Claude, AI, Anthropic, or include Co-Authored-By AI attribution. Enforced by a PreToolUse hook on Bash that detects git commit commands and blocks messages containing these patterns.
- **Reference Implementation**: `peopleforrester/llm-coding-workflow` `claude-config/hooks/check-commit-message.sh` — extracts only the commit message (handles heredoc, `-m`, `--message` formats), checks against AI attribution patterns, blocks on match (exit 2). Key technique: extract minimal relevant data before checking to avoid false positives from file paths.
- **Rationale**: Commit messages should describe the technical change, not how it was produced. A hook provides deterministic enforcement (100% compliance, zero context cost) rather than relying on CLAUDE.md prompt compliance.
- **Impact**: New hook added to Milestone 3. Claude Code's default Co-Authored-By behavior is overridden by the hook blocking and forcing a rewrite.

### Decision 18: Test Tier Enforcement as Separate Milestone
- **Date**: 2026-02-18
- **Decision**: Add Milestone 6 to enforce test tier presence (unit, integration, e2e) via hooks, with dotfile opt-outs (`.skip-e2e`, `.skip-integration`). Warn-only, not blocking.
- **Rationale**: The global CLAUDE.md already states the testing default ("Every project MUST have unit, integration, and end-to-end tests") and the dotfile opt-out pattern. But that's prompt compliance only. Hook enforcement makes it deterministic. Warn-only (not block) is appropriate because adding test coverage is gradual — hard-blocking would prevent any commits in repos that don't yet have all three tiers. This builds on Decision 16's dotfile pattern and Milestone 1's verification hooks.
- **Impact**: New Milestone 6 added after Anki review. Does not block Milestones 3-5.

### Decision 19: Template Design Patterns from Forrester Research
- **Date**: 2026-02-18
- **Decision**: Adopt the following patterns from `peopleforrester/llm-coding-workflow`'s `claude-config/` directory (per Decision 14 research scope) as the design basis for CLAUDE.md templates and per-language rule files:
  1. **Lean CLAUDE.md (~100-150 lines)** — Factor domain-specific rules into `rules/` files rather than inlining everything. CLAUDE.md stays behavioral and structural; rules files handle domain specifics.
  2. **Path-based rule activation via frontmatter** — Per-language rule files use `paths:` frontmatter (e.g., `paths: ["**/*.ts", "**/*.tsx"]`) so Claude Code only loads them when working in relevant file contexts. Reduces token cost.
  3. **Placeholder rule files** — Create stubs with correct `paths:` frontmatter and "Add rules as patterns emerge" rather than filling with speculative rules. Let real usage drive rule content.
  4. **Blocking hooks (exit 2) for zero-tolerance rules only** — Reserve hard-blocking denial for rules that must never be violated (e.g., commit message policy). Use warning hooks (exit 0 with advisory output) for style and quality guidance.
  5. **HTML comments documenting hook-enforced rules** — Already adopted in Whitney's global CLAUDE.md. Keeps humans informed about what hooks enforce without consuming Claude's context tokens on rules that are deterministically enforced anyway.
  6. **Permission profiles in settings.json** — Forrester's repo does not configure Claude Code's `permissions` block, but our PRD calls for three profiles (conservative/balanced/autonomous). Whitney's existing `settings.json` is close to the autonomous profile and serves as the starting point.
- **Rationale**: Forrester's `claude-config/` is a production reference implementation with 137-line CLAUDE.md, 12 rule files, 3 hooks, and 25+ skills. The content distribution pattern (what goes where and why) is the most valuable takeaway: CLAUDE.md for behavior, `rules/` for domain specifics with path activation, hooks for deterministic enforcement. This matches the refactoring already done in Decisions 15 and 6.
- **Impact**: Directly informs Milestone 3 template structure. Templates will include a `rules/` directory with per-language stubs using `paths:` frontmatter. Also confirms that Milestone 3's commit message hook (Decision 17) and dotfile overrides (Decision 16) already have prompt-level rules in global CLAUDE.md — the remaining work is purely hook enforcement.

### Decision 20: Permission Profiles as Guide, Not Standalone Files
- **Date**: 2026-02-18
- **Decision**: Replace the three standalone permission profile JSON files (conservative/balanced/autonomous) with a guide document (`guides/permission-profiles.md`) that explains the three tiers, documents the universal deny list, and shows how to tier down from Whitney's existing autonomous config. No standalone profile files are created.
- **Rationale**: The PRD originally referenced Forrester's `claude-dotfiles` repo which implemented three-tier permission profiles. However, Forrester's own newer production repo (`llm-coding-workflow`) has evolved past permission profiles entirely — it uses `skipDangerousModePermissionPrompt: true` and relies on hooks for safety instead. Whitney's existing `settings.json` is a battle-tested autonomous profile. Creating conservative and balanced profile files we never use means shipping untested security configurations — the PRD requires "valid, tested configurations." A guide documenting the pattern and tier-down approach provides the same reference value without the risk of untested artifacts. This follows Decision 19 pattern 3: let real usage drive content.
- **Impact**: Milestone 3 permission profiles item changes from "create three profile files" to "create permission profiles guide." The Milestone 3 checkbox and Success Criteria are updated to reflect the guide deliverable.

### Decision 21: Milestone Reorder and Documentation Principles
- **Date**: 2026-02-18
- **Decision**: Reorder Milestones 4-6 and expand scope:
  - **M4: Test Tier Enforcement Hooks** (was M6) — moved earlier as natural continuation of hook work from M1 and M3.
  - **M5: README + Integration Testing** (was M4) — wraps up the toolkit. Adopts the execute-then-document principle from Vfarcic's `dot-ai` write-docs skill: every example in the README must come from real execution, not invented output. README examples are validated by actually running them against a real project.
  - **M6: Anki Card Review + Creation** (was M5) — expanded from "review existing cards" to also "create new cards for PRD 1 deliverables." Cards are both a learning tool and a completeness check.
  - A full `/write-docs` skill (Vfarcic's pattern) is noted as a future PRD candidate, not in scope for PRD 1.
- **Rationale**: Hook work should stay grouped together while context is fresh. README is a wrap-up activity that benefits from all other deliverables being complete. Anki card creation belongs last because it captures the full picture. The execute-then-document principle prevents stale or hypothetical examples in documentation — a real problem when documentation is written before or separately from implementation.
- **Impact**: Milestones 4-6 renumbered and rescoped. Out of Scope updated with write-docs skill note.
