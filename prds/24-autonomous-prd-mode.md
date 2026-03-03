# PRD #24: Autonomous PRD Mode — /make-autonomous and /make-careful Skills

**Status**: Not Started
**Priority**: High
**Created**: 2026-03-03
**GitHub Issue**: [#24](https://github.com/wiggitywhitney/claude-config/issues/24)
**Context**: PRD skills are currently YOLO by default globally, with careful variants set aside. This is backwards — autonomous mode with auto-chaining hooks should require explicit per-project opt-in. This PRD flips the defaults and creates toggle skills.

---

## Problem

The PRD skill suite has two modes — careful (confirmation gates, user approval) and autonomous (YOLO, auto-chaining, minimal pauses). Currently, the autonomous variants are installed globally as the default, with careful variants stored as `SKILL.v1-careful.md` backups. This creates two problems:

1. **Unsafe default**: Every project gets autonomous PRD behavior even when careful mode would be more appropriate. Autonomous mode runs `/clear` loops, auto-chains skills, and proceeds without confirmation — powerful but risky for unfamiliar or sensitive projects.
2. **Broken autonomous loop**: The YOLO skill descriptions don't trigger proactive invocation by Claude Code. For example, after `/prd-update-progress` completes, Claude asks "Want me to run `/prd-done`?" instead of just running it. The descriptions describe *what* the skills do but not *when* to invoke them automatically.

## Solution

Flip the defaults and create per-project toggle skills. Mode switching is driven entirely by CLAUDE.md instructions — not by copying separate skill files — because Claude Code's skill override mechanics are broken (see Decision 4).

1. **Make careful the global default**: Rename current `SKILL.v1-careful.md` → `SKILL.md` (global) and current `SKILL.md` → `SKILL.v1-yolo.md` (archived for reference)
2. **`/make-autonomous` skill**: Per-project opt-in that adds autonomous CLAUDE.md instructions (including proactive skill trigger conditions), installs hooks, and adjusts permissions
3. **`/make-careful` skill**: Reverts a project to careful mode by removing autonomous CLAUDE.md instructions, hooks, and permissions
4. **Remove `prd-loop-continue.sh` from global settings**: It becomes a project-level hook installed only by `/make-autonomous`

## What `/make-autonomous` Does

When invoked in a project directory, this skill:

### 1. Add autonomous CLAUDE.md section
Append an autonomous mode section to the project's `.claude/CLAUDE.md` (or `CLAUDE.local.md`) that includes:
- Proceed without trivial confirmations
- Auto-invoke PRD skills when context is clear
- Only pause for genuine ambiguity or architectural decisions
- **Proactive skill trigger conditions** that override the default passive skill descriptions:
  - `prd-next`: INVOKE AUTOMATICALLY after `/prd-start` completes or after `/clear` on a PRD feature branch
  - `prd-done`: INVOKE AUTOMATICALLY when all PRD checkboxes are checked after `/clear`
  - `prd-update-progress`: INVOKE AUTOMATICALLY after completing a PRD implementation task

This is the primary mode-switching mechanism. CLAUDE.md instructions are loaded alongside skills and influence how Claude interprets them — the passive default skill descriptions become active triggers when the autonomous CLAUDE.md section is present.

### 2. Install SessionStart hooks
Add the `prd-loop-continue.sh` hook to `.claude/settings.local.json` (auto-gitignored by Claude Code). This enables the `/clear` → auto-resume loop that drives continuous PRD work.

### 3. Adjust permissions (optional)
Add or suggest permission entries in `.claude/settings.local.json` that reduce friction for autonomous operation (e.g., auto-allow common git operations).

## What `/make-careful` Does

Reverts a project to careful mode:

1. Remove autonomous CLAUDE.md section (behavioral instructions + proactive trigger conditions)
2. Remove SessionStart hooks from `.claude/settings.local.json`
3. Revert any permission changes

## How Skill Descriptions Change Based on Mode

Default SKILL.md descriptions stay passive (careful mode):
```text
prd-next: Analyze existing PRD to identify and recommend the single highest-priority task
prd-done: Complete PRD implementation workflow - create branch, push changes, create PR
prd-update-progress: Update PRD progress based on git commits and code changes
```

When `/make-autonomous` is run, the CLAUDE.md autonomous section adds proactive trigger overrides:
```text
## Autonomous PRD Mode

Proactively invoke PRD skills when trigger conditions are met:
- prd-next: INVOKE AUTOMATICALLY after /prd-start completes or after /clear on a PRD feature branch
- prd-done: INVOKE AUTOMATICALLY when all PRD checkboxes are checked after /clear
- prd-update-progress: INVOKE AUTOMATICALLY after completing a PRD implementation task
```

The key insight: CLAUDE.md instructions are loaded alongside skills and override how Claude interprets skill descriptions. Passive descriptions become active triggers when the autonomous CLAUDE.md section is present. This avoids depending on skill file overrides (which are broken — see Decision 4).

## Success Criteria

- [ ] Careful mode is the global default for all PRD skills
- [ ] `/make-autonomous` installs YOLO mode per-project (CLAUDE.md instructions, hooks, permissions)
- [ ] `/make-careful` cleanly reverts a project to careful mode
- [ ] `prd-loop-continue.sh` removed from global `settings.template.json` and `~/.claude/settings.json`
- [ ] Autonomous CLAUDE.md section triggers proactive skill invocation by Claude Code
- [ ] Autonomous loop tested end-to-end: `/prd-start` → implement → `/clear` → auto-resume → complete → `/prd-done`
- [ ] README updated with autonomous mode documentation

## Milestones

### Milestone 1: Flip Global Defaults
Make careful mode the global default. Reorganize skill files.

- [ ] Rename current `SKILL.md` → `SKILL.v1-yolo.md` for all PRD skills (preserve autonomous variants)
- [ ] Rename current `SKILL.v1-careful.md` → `SKILL.md` for all PRD skills (careful becomes default)
- [ ] Remove `prd-loop-continue.sh` SessionStart hook from `settings.template.json`
- [ ] Remove `prd-loop-continue.sh` SessionStart hook from live `~/.claude/settings.json`
- [ ] Verify careful mode works as global default

### Milestone 2: Create /make-autonomous Skill
Build the skill that enables YOLO mode per-project via CLAUDE.md instructions (Decision 4).

- [ ] `/make-autonomous` SKILL.md created with clear trigger conditions
- [ ] Skill adds autonomous CLAUDE.md section with behavioral instructions and proactive skill trigger conditions (Decision 5)
- [ ] Skill installs SessionStart hook in `.claude/settings.local.json`
- [ ] Skill adjusts permissions in `.claude/settings.local.json`
- [ ] Proactive skill triggers tested — Claude Code invokes PRD skills without being asked when autonomous section is present
- [ ] Autonomous loop verified: `/clear` → hook → auto-invoke `/prd-next` or `/prd-done`
- [ ] Tested on a real project

### Milestone 3: Create /make-careful Skill
Build the skill that reverts a project to careful mode.

- [ ] `/make-careful` SKILL.md created
- [ ] Skill removes autonomous CLAUDE.md section (behavioral instructions + proactive triggers)
- [ ] Skill removes SessionStart hooks from `.claude/settings.local.json`
- [ ] Skill reverts permission changes
- [ ] Tested: `/make-autonomous` → `/make-careful` round-trip leaves project clean

### Milestone 4: Documentation and README
Document autonomous mode for users.

- [ ] README updated with autonomous mode section: what it is, how to enable, how to revert
- [ ] README explains careful vs autonomous tradeoffs
- [ ] README shows the autonomous loop flow diagram or description

## Out of Scope

- Changing non-PRD skills (research, write-docs, etc.) — this only affects the PRD workflow
- Auto-detecting which mode a project should use — explicit opt-in is the design choice
- Partial autonomous mode (e.g., autonomous for some skills but not others)

## Decision Log

### Decision 1: Careful as Global Default
- **Date**: 2026-03-03
- **Decision**: Careful mode is the global default. Autonomous mode requires per-project opt-in via `/make-autonomous`.
- **Rationale**: Autonomous PRD mode runs `/clear` loops, auto-chains skills, and proceeds without confirmation. This is powerful but should be a deliberate choice per project, not the default behavior imposed on every project.
- **Impact**: All existing projects get careful mode. Projects that want autonomy must explicitly opt in.

### Decision 2: Project-Level Hooks, Not Global
- **Date**: 2026-03-03
- **Decision**: The `prd-loop-continue.sh` SessionStart hook moves from global settings to project-level `.claude/settings.local.json`, installed only by `/make-autonomous`.
- **Rationale**: The hook enables the autonomous `/clear` → resume loop. It should only fire in projects that have opted into autonomous mode. Global installation means it fires everywhere, which is the wrong default.
- **Impact**: `settings.template.json` loses the SessionStart hook entry. `/make-autonomous` installs it per-project.

### Decision 3: Active Skill Descriptions for YOLO Mode
- **Date**: 2026-03-03
- **Decision**: YOLO skill descriptions use active trigger language ("INVOKE AUTOMATICALLY when...") rather than passive descriptions ("Analyzes PRD to...").
- **Rationale**: Claude Code uses skill descriptions to decide when to proactively invoke skills. Passive descriptions result in Claude asking permission. Active descriptions with explicit trigger conditions result in automatic invocation — which is the entire point of autonomous mode.
- **Impact**: ~~YOLO `SKILL.md` files get rewritten descriptions.~~ Superseded by Decision 5 — trigger conditions now live in CLAUDE.md, not skill descriptions. Careful variants keep passive descriptions (user-driven invocation is the point).

### Decision 4: CLAUDE.md-Driven Mode Switching (Not Skill File Overrides)
- **Date**: 2026-03-03
- **Decision**: Mode switching (careful ↔ autonomous) is driven entirely by CLAUDE.md instructions, not by copying separate YOLO skill files to project-level `.claude/skills/` directories.
- **Rationale**: Claude Code's skill override mechanics are broken. Official docs state precedence is enterprise > personal > project (personal wins), and [Issue #20309](https://github.com/anthropics/claude-code/issues/20309) (labeled `bug`, `has repro`, open) confirms project-level skills don't reliably shadow global ones. [Issue #25209](https://github.com/anthropics/claude-code/issues/25209) shows both skills appear in the picker instead of one winning. Agents implement local > global correctly, but skills don't yet. Building on broken infrastructure would create a fragile system.
- **Impact**: `/make-autonomous` no longer copies YOLO skill files. Instead, it adds an autonomous section to project CLAUDE.md with behavioral instructions and proactive trigger conditions. `/make-careful` removes that section. YOLO `SKILL.v1-yolo.md` files are archived for reference only, not installed per-project. Milestone 4 (Fix YOLO Skill Descriptions) is absorbed into Milestone 2 since proactive triggers now live in CLAUDE.md.

### Decision 5: Proactive Skill Invocation via CLAUDE.md Context
- **Date**: 2026-03-03
- **Decision**: Proactive skill trigger conditions are embedded in the autonomous CLAUDE.md section rather than rewriting SKILL.md frontmatter descriptions.
- **Rationale**: SKILL.md `description` fields are static per-file and can't change dynamically per-project. CLAUDE.md instructions are loaded alongside skills and influence how Claude interprets them. Adding trigger conditions like "INVOKE AUTOMATICALLY after `/prd-start`" to the CLAUDE.md autonomous section effectively transforms passive skill descriptions into active triggers — without modifying any skill files. This also means the same skill file works in both modes: passive when autonomous CLAUDE.md section is absent, active when present.
- **Impact**: Default SKILL.md descriptions stay passive (careful behavior). `/make-autonomous` adds a CLAUDE.md section with proactive trigger overrides for each PRD skill. This replaces the original Milestone 4 plan to rewrite YOLO SKILL.md descriptions.
