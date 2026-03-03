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

Flip the defaults and create per-project toggle skills:

1. **Make careful the global default**: Rename current `SKILL.v1-careful.md` → `SKILL.md` (global) and current `SKILL.md` → `SKILL.v1-yolo.md` (stored for autonomous use)
2. **`/make-autonomous` skill**: Per-project opt-in that installs YOLO skills, hooks, CLAUDE.md instructions, and permissions
3. **`/make-careful` skill**: Reverts a project to careful mode by removing autonomous overrides
4. **Fix YOLO skill descriptions**: Add proactive trigger conditions so Claude Code invokes them automatically
5. **Remove `prd-loop-continue.sh` from global settings**: It becomes a project-level hook installed only by `/make-autonomous`

## What `/make-autonomous` Does

When invoked in a project directory, this skill:

### 1. Install YOLO skill overrides
Copy autonomous PRD skill variants from claude-config into the project's `.claude/skills/prd-*/SKILL.md`. Project-level skills override global ones, so the YOLO versions take effect for this project only.

### 2. Install SessionStart hooks
Add the `prd-loop-continue.sh` hook to `.claude/settings.local.json` (auto-gitignored by Claude Code). This enables the `/clear` → auto-resume loop that drives continuous PRD work.

### 3. Add YOLO instructions to project CLAUDE.md
Append an autonomous mode section to the project's `.claude/CLAUDE.md` (or `CLAUDE.local.md`) with instructions like:
- Proceed without trivial confirmations
- Auto-invoke PRD skills when context is clear
- Only pause for genuine ambiguity or architectural decisions

### 4. Adjust permissions (optional)
Add or suggest permission entries in `.claude/settings.local.json` that reduce friction for autonomous operation (e.g., auto-allow common git operations).

## What `/make-careful` Does

Reverts a project to careful mode:

1. Remove project-level YOLO skill overrides from `.claude/skills/prd-*/`
2. Remove SessionStart hooks from `.claude/settings.local.json`
3. Remove YOLO instructions from CLAUDE.md / CLAUDE.local.md
4. Revert any permission changes

## YOLO Skill Description Fixes

Current descriptions (passive — describe what the skill does):
```text
prd-next: Analyze existing PRD to identify and recommend the single highest-priority task
prd-done: Complete PRD implementation workflow - create branch, push changes, create PR
```

Fixed descriptions (active — tell Claude when to invoke):
```text
prd-next: Autonomous PRD task loop. INVOKE AUTOMATICALLY after /prd-start completes or after /clear on a PRD feature branch.
prd-done: Finalize completed PRD. INVOKE AUTOMATICALLY when all PRD checkboxes are checked after /clear.
prd-update-progress: Commit and update PRD. INVOKE AUTOMATICALLY after completing a PRD implementation task.
```

The key insight: skill descriptions are the primary mechanism Claude Code uses to decide whether to proactively invoke a skill. Passive descriptions get treated as "available if asked." Active descriptions with trigger conditions get treated as "run this when conditions are met."

## Success Criteria

- [ ] Careful mode is the global default for all PRD skills
- [ ] `/make-autonomous` installs YOLO mode per-project (skills, hooks, CLAUDE.md, permissions)
- [ ] `/make-careful` cleanly reverts a project to careful mode
- [ ] `prd-loop-continue.sh` removed from global `settings.template.json` and `~/.claude/settings.json`
- [ ] YOLO skill descriptions trigger proactive invocation by Claude Code
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
Build the skill that enables YOLO mode per-project.

- [ ] `/make-autonomous` SKILL.md created with clear trigger conditions
- [ ] Skill copies YOLO variants to project `.claude/skills/prd-*/SKILL.md`
- [ ] Skill installs SessionStart hook in `.claude/settings.local.json`
- [ ] Skill adds YOLO instructions to project CLAUDE.md or CLAUDE.local.md
- [ ] Skill adjusts permissions in `.claude/settings.local.json`
- [ ] Tested on a real project

### Milestone 3: Create /make-careful Skill
Build the skill that reverts a project to careful mode.

- [ ] `/make-careful` SKILL.md created
- [ ] Skill removes project-level YOLO skill overrides
- [ ] Skill removes SessionStart hooks from `.claude/settings.local.json`
- [ ] Skill removes YOLO instructions from CLAUDE.md / CLAUDE.local.md
- [ ] Skill reverts permission changes
- [ ] Tested: `/make-autonomous` → `/make-careful` round-trip leaves project clean

### Milestone 4: Fix YOLO Skill Descriptions
Update autonomous skill descriptions to trigger proactive invocation.

- [ ] All YOLO PRD skill descriptions rewritten with active trigger conditions
- [ ] Descriptions tested — Claude Code invokes skills without being asked
- [ ] Autonomous loop verified: `/clear` → hook → auto-invoke `/prd-next` or `/prd-done`

### Milestone 5: Documentation and README
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
- **Impact**: YOLO `SKILL.md` files get rewritten descriptions. Careful variants keep passive descriptions (user-driven invocation is the point).
