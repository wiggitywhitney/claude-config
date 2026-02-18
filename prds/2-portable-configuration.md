# PRD #2: Portable Claude Code Configuration Across Machines

**Status**: Not Started
**Priority**: High
**Created**: 2026-02-18
**GitHub Issue**: [#2](https://github.com/wiggitywhitney/claude-config/issues/2)
**Context**: Configuration in `~/.claude/` requires significant investment but is machine-specific. This PRD makes it portable via the claude-config repo.
**Depends On**: PRD #1 (shared testing infrastructure provides the scripts and skills being made portable)

---

## Problem

Claude Code configuration — permissions, hooks, global instructions, skills, and safety scripts — takes significant time to build and refine. But it's trapped on a single machine:

- `~/.claude/settings.json` contains absolute paths (`/Users/whitney.lee/...`) that break on another machine
- `~/.claude/CLAUDE.md` (global instructions) isn't tracked anywhere
- `~/.claude/rules/` (user-level modular rules) isn't tracked anywhere
- Skills symlinks must be manually recreated
- Hook script paths in settings.json are hardcoded to one machine's directory structure
- Setting up a new machine means redoing everything from scratch or manually copying and editing paths

## Solution

Build an install/setup mechanism in the claude-config repo that:

1. **Tracks portable configuration** — Global CLAUDE.md, settings templates, and setup scripts live in the repo
2. **Generates machine-specific config** — An install script resolves absolute paths for the current machine
3. **Merges safely** — Never overwrites existing settings.json; merges hook/permission config into what's already there
4. **Handles all configuration levels** — Accounts for the full scope hierarchy of settings, memory, and rules

## Configuration Levels

Claude Code has a parallel scope hierarchy across settings, memory (CLAUDE.md), and rules. Understanding which levels need portability work and which are already handled is key.

### settings.json (four scopes)

| Scope | Path | Portability | Strategy |
|---|---|---|---|
| **Managed** | `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS) | Org-deployed, not user-managed | Out of scope |
| **Global** | `~/.claude/settings.json` | Machine-specific (absolute paths in hooks) | Template in repo + install script resolves paths |
| **Project** | `<project>/.claude/settings.json` | Already portable (committed to repo) | No action needed |
| **Project Local** | `<project>/.claude/settings.local.json` | Intentionally machine-specific (auto-gitignored) | Document what goes here; optionally provide templates |

### CLAUDE.md (four scopes + subdirectory)

| Scope | Path | Portability | Strategy |
|---|---|---|---|
| **Managed** | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS) | Org-deployed, not user-managed | Out of scope |
| **Global** | `~/.claude/CLAUDE.md` | Not tracked anywhere | Track in repo, symlink or copy during install |
| **Project** | `<project>/CLAUDE.md` or `<project>/.claude/CLAUDE.md` | Already portable (committed to repo) | No action needed |
| **Project Local** | `<project>/CLAUDE.local.md` | Personal per-project prefs (auto-gitignored) | Document what goes here; optionally provide templates |
| **Subdirectory** | `<project>/path/to/CLAUDE.md` | Already portable (committed to repo) | No action needed (loaded on-demand) |

Note: Subdirectory CLAUDE.md files are a fifth scope unique to memory — settings.json has no equivalent. They load on-demand when Claude reads files in those directories.

### Modular Rules (two scopes)

| Scope | Path | Portability | Strategy |
|---|---|---|---|
| **User** | `~/.claude/rules/*.md` | Not tracked anywhere | Track in repo, symlink or copy during install |
| **Project** | `<project>/.claude/rules/*.md` | Already portable (committed to repo) | No action needed |

Project rules support optional path-scoped frontmatter (`paths: ["src/**/*.ts"]`) for conditional loading. User rules apply to all projects.

### MCP Servers

| Scope | Path | Portability | Strategy |
|---|---|---|---|
| **User** | `~/.claude.json` | Machine-specific (may reference local paths) | Document; optionally template |
| **Project** | `<project>/.mcp.json` | Already portable (committed to repo) | No action needed |
| **Managed** | `/Library/Application Support/ClaudeCode/managed-mcp.json` (macOS) | Org-deployed | Out of scope |

## Deliverables

### 1. Global CLAUDE.md + User Rules (Tracked in Repo)
Move `~/.claude/CLAUDE.md` content and `~/.claude/rules/*.md` files into the repo so they're version-controlled. The install script symlinks or copies them into place.

### 2. Settings Template
A `settings.template.json` in the repo that contains the full settings structure with a placeholder (e.g., `$CLAUDE_CONFIG_DIR`) instead of absolute paths. The install script substitutes the actual repo path on the current machine.

Template handles:
- Hook command paths (pre-commit, pre-push, pre-pr, post-write hooks)
- Permission allow/deny/ask lists (these are path-independent and transfer directly)
- Model preferences
- Any other global settings

### 3. Install Script
A `setup.sh` (or similar) that:
- Detects the repo's absolute path on the current machine
- Generates `~/.claude/settings.json` from the template with resolved paths
- **Merges** into existing settings.json if one exists (preserves existing permissions, adds hooks)
- Creates the `~/.claude/skills/verify` symlink pointing to the repo
- Symlinks global CLAUDE.md (`~/.claude/CLAUDE.md`)
- Symlinks user rules directory (`~/.claude/rules/`)
- Copies or symlinks any standalone scripts (e.g., Google MCP safety hook)
- Is idempotent — safe to run multiple times

### 4. Merge Strategy for settings.json
The install script must not overwrite existing settings. Specifically:
- **Hooks**: Add/update hook entries from the template; preserve any hooks not in the template
- **Permissions (allow/deny/ask)**: Merge lists — add entries from template that don't already exist; preserve existing entries
- **Other settings** (model, etc.): Only set if not already present, or prompt

### 5. Uninstall/Reset Option
A way to cleanly remove installed configuration:
- Remove symlinks created by the installer
- Optionally restore settings.json to pre-install state (requires backup during install)

### 6. Documentation
Clear instructions in the repo README covering:
- What gets installed and where
- How to run setup on a new machine
- How the merge strategy works
- How to customize (what to put in project-local vs global)
- How to update configuration (re-run install after pulling latest)

## Success Criteria

- [ ] Running `setup.sh` on a fresh machine with a clone of claude-config produces a fully working Claude Code environment
- [ ] Running `setup.sh` on a machine with existing settings.json preserves all existing configuration while adding new hooks/permissions
- [ ] Global CLAUDE.md and user rules are version-controlled and applied during setup
- [ ] All hook script paths resolve correctly on the new machine
- [ ] Skills and rules symlinks are created and functional
- [ ] Running setup.sh multiple times is safe (idempotent)

## Milestones

### Milestone 1: Settings Template + Path Resolution
Create the settings template with placeholder paths and a script that resolves them to the current machine's repo location.

- [ ] `settings.template.json` created with `$CLAUDE_CONFIG_DIR` placeholders
- [ ] Script resolves placeholders to actual paths and generates valid settings.json
- [ ] Generated settings.json passes validation (valid JSON, paths exist)

### Milestone 2: Safe Merge Into Existing Settings
Implement the merge strategy so setup never overwrites existing configuration.

- [ ] Merge logic for hooks (add new, preserve existing)
- [ ] Merge logic for permissions (union of allow/deny/ask lists)
- [ ] Backup of existing settings.json before any modification
- [ ] Tested: running setup with existing settings preserves all prior config

### Milestone 3: Global CLAUDE.md + User Rules + Skills + Scripts
Track global CLAUDE.md and user rules in the repo, handle symlinks for all global-scope files.

- [ ] Global CLAUDE.md content moved into repo
- [ ] User rules (`~/.claude/rules/`) tracked in repo
- [ ] Install script creates `~/.claude/skills/verify` symlink
- [ ] Install script symlinks `~/.claude/CLAUDE.md` and `~/.claude/rules/`
- [ ] Install script handles standalone scripts (Google MCP safety hook, etc.)
- [ ] All symlinks are idempotent (safe to re-run)

### Milestone 4: Full Install Script + Documentation
Combine all pieces into a single `setup.sh` with documentation.

- [ ] Single `setup.sh` handles full installation
- [ ] Uninstall option removes installed configuration
- [ ] README documents setup process, merge strategy, and customization
- [ ] Tested end-to-end on a clean environment

## Out of Scope

- Automatic syncing between machines (this is clone-and-run, not a sync service)
- Managing project-level `.claude/settings.json` (already portable via git)
- Managing project-level CLAUDE.md files (already portable via git)
- Managing project-level `.claude/rules/*.md` (already portable via git)
- Managed-scope configs (`managed-settings.json`, managed CLAUDE.md, `managed-mcp.json`) — these are org-deployed by admins, not user-managed
- MCP server configuration (`~/.claude.json`) — may contain secrets/tokens; document but don't template
- Cross-platform support beyond macOS (can be added later)
- Secret management (handled separately by vals)

## Decision Log

### Decision 1: Merge, Don't Overwrite
- **Date**: 2026-02-18
- **Decision**: The install script merges configuration into existing settings.json rather than replacing it
- **Rationale**: Users accumulate machine-specific permission approvals over time. Overwriting would force re-approving every permission. Merging preserves existing state while adding the toolkit's hooks and permissions.
- **Impact**: Requires a merge strategy (more complex than simple copy, but much safer)

### Decision 2: Template with Path Placeholders
- **Date**: 2026-02-18
- **Decision**: Use a settings template with `$CLAUDE_CONFIG_DIR` placeholders resolved at install time, rather than relative paths or runtime resolution
- **Rationale**: Claude Code settings.json requires absolute paths for hook commands. A template with placeholders is simple, transparent, and produces a standard settings.json that Claude Code reads natively. No runtime indirection needed.
- **Impact**: Install script does string substitution; the generated file is a normal settings.json

### Decision 3: Separate PRD from PRD #1
- **Date**: 2026-02-18
- **Decision**: Configuration portability is a separate PRD (#2) rather than part of PRD #1 (shared testing infrastructure)
- **Rationale**: PRD #1 builds the toolkit (verify skill, testing rules, permission profiles). This PRD makes all configuration portable across machines. They're complementary but distinct problem spaces. This PRD depends on PRD #1's deliverables existing but solves a different problem.
- **Impact**: PRD #2 can begin after PRD #1's Milestone 1 is complete (hooks and scripts exist to be made portable)
