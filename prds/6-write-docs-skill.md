# PRD #6: /write-docs Skill for Validated Documentation

**Status**: In Progress
**Priority**: Medium
**Created**: 2026-02-18
**GitHub Issue**: [#6](https://github.com/wiggitywhitney/claude-config/issues/6)
**Context**: Identified during PRD #1 Milestone 5 planning (Decision 21). The execute-then-document principle was adopted for PRD #1's README but a reusable skill was deferred as out of scope.

---

## Problem

Documentation examples across projects are often invented or hypothetical. When docs are written separately from execution, examples go stale, commands don't match actual behavior, and users hit errors following guides. There's no standardized process for writing validated documentation — each project reinvents the approach or skips validation entirely.

## Solution

Create a global `/write-docs` Claude Code skill that enforces validated documentation through a structured process: execute commands, capture real output, write docs from actual results. The skill defines the behavioral contract — how Claude should approach documentation writing — not the domain-specific setup (which varies per project).

## Research Foundation

**Reference implementation**: Vfarcic's `dot-ai` repo — [`.claude/skills/write-docs/SKILL.md`](https://github.com/vfarcic/dot-ai/blob/main/.claude/skills/write-docs/SKILL.md)

Key patterns from the reference:
- **Execute-then-document**: Never write examples without real output
- **Chunk-by-chunk**: Write one section at a time, get confirmation before proceeding
- **User-focused**: Write for users, not developers
- **Validate prerequisites**: Run setup steps from existing docs to verify they work
- **Fix docs when broken**: If existing docs don't work during setup, STOP and discuss updating those docs before proceeding
- **Responsibility split**: Claude runs infrastructure/bash commands; user runs user-facing interactions (MCP client operations in Vfarcic's case)

**What to adapt**: The reference is Kubernetes/Kind-specific (fresh cluster setup, Helm installs, MCP server deployment). Our skill must be project-agnostic while preserving the core validation principles.

## Deliverables

### 1. /write-docs Skill

Global slash command installed at `~/.claude/skills/write-docs/` that guides Claude through a validated documentation workflow.

#### Core Principles (from reference)
1. **Execute-then-document** — Never write examples without real output
2. **Chunk-by-chunk** — Write one section at a time, get confirmation before proceeding
3. **User-focused** — Write for users, not developers
4. **Validate prerequisites** — Run setup steps from existing docs to verify they work
5. **Fix docs when broken** — If existing docs don't work during setup, STOP and discuss before proceeding
6. **Include error cases** — Document what happens when things go wrong, not just the happy path

#### Workflow
1. **Identify documentation target** — Ask what to document (new feature guide, update existing, API reference, setup guide, README)
2. **Environment setup** — Ensure clean starting state for the project type (npm install, build, reset test data, etc.). Follow existing setup docs to validate they still work.
3. **Outline** — Present section structure, get user confirmation before writing
4. **Write chunk-by-chunk** — For each section: propose content, execute commands to capture real output, write the section, get confirmation, proceed to next
5. **Cross-reference check** — Verify internal links, check references to other docs, update index pages
6. **Final review** — Present completed docs for user review

#### Key Design Decisions
- **Project-agnostic**: No assumptions about tech stack. The skill detects project type (same `detect-project.sh` from /verify) and adapts environment setup accordingly.
- **No invented output**: Every command example in documentation must come from actual execution. Claude runs bash commands directly; only asks user for operations that require user-facing tools (browser, MCP client, GUI).
- **Small chunks with gates**: Each section is written and confirmed before moving to the next. Prevents large blocks of content from drifting off-target.
- **Existing docs as validation**: When writing new docs, the setup process follows existing docs first. If existing docs are broken, the process halts to fix them — writing new docs simultaneously validates old docs.

#### File Location Conventions
The skill should respect each project's existing documentation structure. If no convention exists, suggest:
- Feature guides: `docs/guides/`
- Setup guides: `docs/setup/`
- API reference: `docs/api/`
- README: project root

## Success Criteria

- [x] Skill installed globally at `~/.claude/skills/write-docs/`
- [ ] Skill works across at least two different project types (Node.js and shell/config)
- [x] All examples in documentation produced by the skill come from real execution
- [x] Skill validates existing setup docs as part of its workflow
- [x] Chunk-by-chunk confirmation gates work as designed

## Milestones

### Milestone 1: Core Skill Implementation
Create the skill prompt file with the validated documentation workflow. Test against one real project.

- [x] Skill prompt created at `~/.claude/skills/write-docs/SKILL.md` with frontmatter
- [x] Workflow covers all 6 steps (identify, setup, outline, write, cross-reference, review)
- [x] Execute-then-document principle enforced in skill instructions
- [x] Chunk-by-chunk confirmation gates defined
- [x] Tested by writing real documentation for one project

### Milestone 2: Cross-Project Validation
Test the skill across different project types to ensure it's truly project-agnostic.

- [ ] Tested on a Node.js/TypeScript project
- [x] Tested on a shell/config project (e.g., claude-config itself)
- [ ] Skill adapts environment setup to project type
- [ ] File location conventions work across project structures
- [x] Existing docs validation catches real issues

## Out of Scope

- Domain-specific setup procedures (Kind clusters, Helm charts, MCP server deployment) — those belong in each project's own docs
- Automated doc generation from code (JSDoc, TypeDoc) — this skill is for narrative documentation
- Documentation CI/CD (link checking, freshness validation) — future enhancement
- Image/screenshot capture — text-based documentation only for now

## Decision Log

### Decision 1: Project-Agnostic Design
- **Date**: 2026-02-18
- **Decision**: The skill is project-agnostic — no tech stack assumptions baked into the skill itself. Environment setup adapts to the detected project type.
- **Rationale**: Vfarcic's reference is tightly coupled to his Kubernetes/MCP workflow (Kind clusters, Helm, kubeconfig). A reusable skill must work across Whitney's diverse repos (Node.js, Python, shell, React). The existing `detect-project.sh` from the /verify skill can inform environment setup without hardcoding stack-specific procedures.
- **Impact**: The skill is simpler and more portable than the reference, but requires projects to have their own setup docs that the skill follows.

### Decision 2: Skill Scope is Behavioral, Not Technical
- **Date**: 2026-02-18
- **Decision**: The skill defines the documentation process (execute-then-document, chunk-by-chunk, validation gates) but does not include deterministic scripts for environment setup.
- **Rationale**: Unlike /verify which has deterministic phases that benefit from scripts (build, typecheck, lint), documentation writing is inherently interactive and context-dependent. The skill controls Claude's behavior during the process; the actual commands executed vary by project and doc type. Scripts would add complexity without meaningful benefit.
- **Impact**: Skill is a single SKILL.md file with no supporting scripts. Simpler to install and maintain.
