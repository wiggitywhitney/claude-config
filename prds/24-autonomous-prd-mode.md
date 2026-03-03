# PRD #24: Autonomous PRD Mode — /make-autonomous and /make-careful Skills

**Status**: In Progress
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

Flip the defaults and create per-project toggle skills. Mode switching uses **symlink-based skill installation** — each project's `.claude/skills/` contains symlinks pointing to either YOLO or careful skill variants in the claude-config repo (see Decision 6). Global PRD skill symlinks are removed entirely (Decision 8).

1. **Make careful the global default**: Rename current `SKILL.v1-careful.md` → `SKILL.md` and current `SKILL.md` → `SKILL.v1-yolo.md` (with active trigger descriptions per Decision 7)
2. **Remove global PRD skill symlinks**: PRD skills removed from `~/.claude/skills/` — they become project-level only (Decision 8)
3. **`/make-autonomous` skill**: Per-project opt-in that creates symlinks to YOLO skill variants, installs SessionStart hooks, and adjusts permissions
4. **`/make-careful` skill**: Swaps symlinks to careful skill variants, removes hooks and autonomous permissions
5. **Remove `prd-loop-continue.sh` from global settings**: It becomes a project-level hook installed only by `/make-autonomous`

## What `/make-autonomous` Does

When invoked in a project directory, this skill:

### 1. Create symlinks to YOLO skill variants
For each PRD skill, create a project-level symlink in `.claude/skills/<skill-name>/SKILL.md` pointing to the YOLO variant (`SKILL.v1-yolo.md`) in the claude-config repo. YOLO variants have active trigger descriptions (Decision 7) that drive proactive invocation.

### 2. Install SessionStart hooks
Add the `prd-loop-continue.sh` hook to `.claude/settings.local.json` (auto-gitignored by Claude Code). This enables the `/clear` → auto-resume loop that drives continuous PRD work.

### 3. Adjust permissions
Add permission entries in `.claude/settings.local.json` that reduce friction for autonomous operation (e.g., auto-allow git operations, skill invocations).

## What `/make-careful` Does

Swaps a project to careful mode:

1. Swap symlinks to point at careful skill variants (`SKILL.md`) instead of YOLO variants
2. Remove SessionStart hooks from `.claude/settings.local.json`
3. Remove autonomous permission entries

## How Skill Descriptions Change Based on Mode

Careful `SKILL.md` descriptions are passive (user-driven invocation):
```text
prd-next: Analyze existing PRD to identify and recommend the single highest-priority task
prd-done: Complete PRD implementation workflow - create branch, push changes, create PR
prd-update-progress: Update PRD progress based on git commits and code changes
```

YOLO `SKILL.v1-yolo.md` descriptions use active trigger language (Decision 7):
```text
prd-next: INVOKE AUTOMATICALLY after /prd-start or /clear on PRD branch. Identifies next task.
prd-done: INVOKE AUTOMATICALLY when all PRD checkboxes complete. Creates PR, reviews, merges.
prd-update-progress: INVOKE AUTOMATICALLY after completing a PRD task. Commits, updates PRD.
```

The key insight: the `description` field in SKILL.md frontmatter appears in the system prompt's skill list. Active trigger language in descriptions drives Claude to invoke skills proactively without being asked. `/make-autonomous` installs YOLO variants with these active descriptions; `/make-careful` installs careful variants with passive descriptions. No global PRD skills exist to conflict (Decision 8).

## Success Criteria

- [x] Careful mode is the global default for all PRD skills
- [ ] `/make-autonomous` installs YOLO mode per-project (symlinks to YOLO skills, hooks, permissions)
- [ ] `/make-careful` cleanly swaps a project to careful mode
- [x] `prd-loop-continue.sh` removed from global `settings.template.json` and `~/.claude/settings.json`
- [ ] Active YOLO skill descriptions trigger proactive invocation by Claude Code
- [ ] Autonomous loop tested end-to-end: `/prd-start` → implement → `/clear` → auto-resume → complete → `/prd-done`
- [ ] README updated with autonomous mode documentation
- [x] All repos touched in last 2 months have careful PRD skill symlinks installed
- [x] Global PRD skill symlinks removed from `~/.claude/skills/`

## Milestones

### Milestone 1: Flip Global Defaults
Make careful mode the global default. Reorganize skill files.

- [x] Rename current `SKILL.md` → `SKILL.v1-yolo.md` for all PRD skills (preserve autonomous variants)
- [x] Rename current `SKILL.v1-careful.md` → `SKILL.md` for all PRD skills (careful becomes default)
- [x] Remove `prd-loop-continue.sh` SessionStart hook from `settings.template.json`
- [x] Remove `prd-loop-continue.sh` SessionStart hook from live `~/.claude/settings.json`
- [x] Verify careful mode works as global default

### Milestone 2: Create /make-autonomous Skill
Build the skill that enables YOLO mode per-project via symlink-based skill installation (Decision 6).

- [x] Update YOLO `SKILL.v1-yolo.md` descriptions with active trigger language (Decision 7)
- [x] `/make-autonomous` SKILL.md created — creates symlinks to YOLO variants, installs hooks, adjusts permissions
- [x] Skill creates project-level symlinks in `.claude/skills/` pointing to YOLO variants in claude-config
- [x] Skill installs SessionStart hook in `.claude/settings.local.json`
- [x] Skill adjusts permissions in `.claude/settings.local.json`
- [x] Strengthen `prd-loop-continue.sh` hook output language for more directive auto-invocation
- [x] Remove global PRD skill symlinks from `~/.claude/skills/` (Decision 8)
- [ ] Proactive skill triggers tested — Claude Code invokes PRD skills without being asked when YOLO variants installed
- [ ] Autonomous loop verified: `/clear` → hook → auto-invoke `/prd-next` or `/prd-done`
- [ ] Tested on a real project

### Milestone 3: Create /make-careful Skill and Migrate Repos
Build the skill that swaps a project to careful mode. Migrate all active repos.

- [ ] `/make-careful` SKILL.md created
- [ ] Skill swaps symlinks to point at careful variants (not removes — skills stay installed)
- [ ] Skill removes SessionStart hooks from `.claude/settings.local.json`
- [ ] Skill removes autonomous permission entries
- [ ] Tested: `/make-autonomous` → `/make-careful` round-trip leaves project clean
- [x] All repos touched in last 2 months have careful PRD skill symlinks installed

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

### Decision 4: ~~CLAUDE.md-Driven Mode Switching~~ → Superseded by Decision 6
- **Date**: 2026-03-03
- **Decision**: ~~Mode switching driven entirely by CLAUDE.md instructions.~~
- **Rationale**: Claude Code's skill override mechanics are broken ([Issue #20309](https://github.com/anthropics/claude-code/issues/20309)). Project-level skills don't shadow global ones — both appear in the picker.
- **Superseded**: Decision 6 solves the override bug differently — by removing global PRD skills entirely and using project-level symlinks only.

### Decision 5: ~~Proactive Skill Invocation via CLAUDE.md Context~~ → Superseded by Decision 7
- **Date**: 2026-03-03
- **Decision**: ~~Proactive skill trigger conditions embedded in CLAUDE.md section.~~
- **Rationale**: SKILL.md descriptions are static per-file. CLAUDE.md was chosen as the dynamic override mechanism.
- **Superseded**: Decision 7 revives the original approach (active descriptions in SKILL.md frontmatter) now that Decision 6 eliminates the global/project conflict. Each project gets either YOLO or careful skill files via symlinks — no need for CLAUDE.md overrides.

### Decision 6: Symlink-Based Per-Project Skill Installation
- **Date**: 2026-03-03
- **Decision**: `/make-autonomous` creates project-level symlinks in `.claude/skills/` pointing to YOLO skill variants (`SKILL.v1-yolo.md`) in the claude-config repo. `/make-careful` swaps symlinks to careful variants (`SKILL.md`). Global PRD skill symlinks are removed entirely (see Decision 8).
- **Rationale**: The skill override bug (#20309) means project-level skills can't shadow global ones — both appear. The solution is to eliminate the conflict: remove global PRD skills so project-level symlinks are the only source. Symlinks avoid file duplication and ensure all projects reference the canonical skill definitions in claude-config.
- **Impact**: `/make-autonomous` no longer modifies CLAUDE.md. Instead, it creates symlinks for each PRD skill directory. `/make-careful` swaps those symlinks. Milestones 2 and 3 updated to reflect symlink approach.

### Decision 7: Active YOLO Skill Descriptions in Frontmatter
- **Date**: 2026-03-03
- **Decision**: YOLO `SKILL.v1-yolo.md` files get active trigger descriptions in their frontmatter `description` field (e.g., "INVOKE AUTOMATICALLY after /prd-start or /clear on PRD branch"). Careful `SKILL.md` files keep passive descriptions.
- **Rationale**: The `description` field appears in the system prompt's skill list and directly influences whether Claude proactively invokes skills. With global PRD skills removed (Decision 8), there's no conflict — each project sees exactly one set of descriptions (YOLO or careful) based on which symlinks are installed. Revives Decision 3's original approach, now viable because Decision 6 eliminates the global/project conflict.
- **Impact**: YOLO `SKILL.v1-yolo.md` frontmatter descriptions rewritten with active trigger language for prd-next, prd-done, and prd-update-progress. Decision 5 (CLAUDE.md triggers) is superseded.

### Decision 8: Remove Global PRD Skill Symlinks
- **Date**: 2026-03-03
- **Decision**: PRD skills are removed from `~/.claude/skills/` (global). Each project gets PRD skills only via `/make-autonomous` or `/make-careful`, which create project-level symlinks. Projects without either have no PRD skills in their picker.
- **Rationale**: Global PRD skills cause the duplicate-in-picker bug (#20309) when project-level skills also exist. Removing them eliminates the conflict entirely. Only projects that explicitly opt in get PRD skills, which is cleaner — non-PRD projects don't see irrelevant skills.
- **Impact**: Existing repos that use PRD skills need careful symlinks installed (added to Milestone 3 success criteria). Global CLAUDE.md PRD workflow instructions remain as documentation but reference per-project skill installation.
