# claude-config

Shared Claude Code testing infrastructure, safety config, and developer tooling. Apply to any project developed with Claude Code to get standardized verification, testing guidance, and safety guardrails.

## What's Included

| Deliverable | Path | Purpose |
|---|---|---|
| Install Script | [`setup.sh`](setup.sh) | Portable setup: settings, symlinks, merge |
| Settings Template | [`settings.template.json`](settings.template.json) | Global settings with path placeholders |
| Global CLAUDE.md | [`global/CLAUDE.md`](global/CLAUDE.md) | Global development standards |
| Testing Decision Guide | [`guides/testing-decision-guide.md`](guides/testing-decision-guide.md) | Maps project types to testing strategies |
| `/verify` Skill | [`.claude/skills/verify/`](.claude/skills/verify/) | Pre-PR verification loop (build, typecheck, lint, security, tests) |
| Tiered Verification Hooks | [`.claude/skills/verify/scripts/`](.claude/skills/verify/scripts/) | Automatic gates on commit, push, and PR creation |
| Safety Hooks | [`scripts/`](scripts/) | Google MCP and gogcli safety hooks |
| `/research` Skill | [`.claude/skills/research/`](.claude/skills/research/) | Structured technical research with cited sources |
| `/write-prompt` Skill | [`.claude/skills/write-prompt/`](.claude/skills/write-prompt/) | Guided prompt engineering for system prompts and skills |
| `/write-docs` Skill | [`.claude/skills/write-docs/`](.claude/skills/write-docs/) | Validated documentation with real command output |
| `/anki` Skill | [`.claude/skills/anki/`](.claude/skills/anki/) | Create Anki cards from conversation context |
| `/anki-yolo` Skill | [`.claude/skills/anki-yolo/`](.claude/skills/anki-yolo/) | Create and save Anki cards autonomously |
| PRD Skills | [`.claude/skills/`](.claude/skills/) | Full PRD lifecycle: create, start, next, update, close, done |
| `/prds-get` Skill | [`.claude/skills/prds-get/`](.claude/skills/prds-get/) | Fetch all open PRD issues from GitHub |
| `/make-autonomous` Skill | [`.claude/skills/make-autonomous/`](.claude/skills/make-autonomous/) | Enable autonomous PRD mode per-project |
| `/make-careful` Skill | [`.claude/skills/make-careful/`](.claude/skills/make-careful/) | Disable autonomous PRD mode per-project |
| ABOUTME Hook | [`.claude/skills/verify/scripts/check-aboutme.sh`](.claude/skills/verify/scripts/check-aboutme.sh) | Enforces ABOUTME file headers in code files |
| CodeRabbit CLI Hook | [`.claude/skills/verify/scripts/coderabbit-review.sh`](.claude/skills/verify/scripts/coderabbit-review.sh) | Advisory CodeRabbit CLI review on push |
| PRD Loop Hook | [`scripts/prd-loop-continue.sh`](scripts/prd-loop-continue.sh) | SessionStart hook for PRD work continuation after `/clear` |
| Branch Protection Rule | [`rules/branch-protection.md`](rules/branch-protection.md) | Docs-only exemption for main branch commits |
| CLAUDE.md Templates | [`templates/`](templates/) | Starter templates for new projects |
| CLAUDE.md Authoring Guide | [`guides/claude-md-guide.md`](guides/claude-md-guide.md) | How to write effective CLAUDE.md files |
| Testing Rules | [`rules/testing-rules.md`](rules/testing-rules.md) | Always/Never testing patterns |
| Permission Profiles | [`guides/permission-profiles.md`](guides/permission-profiles.md) | Three trust levels for `settings.json` |
| Per-Language Rules | [`rules/languages/`](rules/languages/) | Path-scoped rules for TypeScript, Shell, Python, Go, JS |

## Setup: Install on a New Machine

Clone this repo and run the install script to set up your Claude Code environment:

```bash
git clone git@github.com:wiggitywhitney/claude-config.git ~/Documents/Repositories/claude-config
cd ~/Documents/Repositories/claude-config
./setup.sh --install
```

This single command:
- Generates `~/.claude/settings.json` from the template with resolved absolute paths (or merges into your existing settings.json)
- Creates symlinks for global CLAUDE.md, rules, and skills
- Backs up your existing settings.json before making changes

### What Gets Installed

| Target | Source | Method |
|---|---|---|
| `~/.claude/settings.json` | `settings.template.json` | Generated (merge if exists) |
| `~/.claude/CLAUDE.md` | `global/CLAUDE.md` | Symlink |
| `~/.claude/rules/` | `rules/` | Symlink |
| `~/.claude/skills/verify/` | `.claude/skills/verify/` | Symlink |
| `~/.claude/skills/research/` | `.claude/skills/research/` | Symlink |
| `~/.claude/skills/write-prompt/` | `.claude/skills/write-prompt/` | Symlink |
| `~/.claude/skills/write-docs/` | `.claude/skills/write-docs/` | Symlink |
| `~/.claude/skills/anki/` | `.claude/skills/anki/` | Symlink |
| `~/.claude/skills/anki-yolo/` | `.claude/skills/anki-yolo/` | Symlink |
| `~/.claude/skills/make-autonomous/` | `.claude/skills/make-autonomous/` | Symlink |
| `~/.claude/skills/make-careful/` | `.claude/skills/make-careful/` | Symlink |

### Merge Strategy

When `~/.claude/settings.json` already exists, setup.sh merges rather than overwrites:

- **Hooks**: Adds new hook matchers from the template. For existing matchers, adds new hook commands without duplicating existing ones.
- **Permissions** (allow/deny/ask): Unions the lists — adds entries from the template that don't already exist, preserves all existing entries.
- **Other keys** (model, etc.): Only sets keys that aren't already present. Your existing preferences are never overwritten.

A timestamped backup (`settings.json.backup.YYYYMMDD-HHMMSS`) is created before any modification.

### Updating Configuration

After pulling the latest changes:

```bash
cd ~/Documents/Repositories/claude-config
git pull
./setup.sh --install
```

Since symlinks point into the repo, changes to CLAUDE.md, rules, and skills take effect immediately after `git pull`. Re-running `--install` is only needed when `settings.template.json` changes (new hooks, permissions, or settings).

### Customization

- **Machine-specific project prefs**: Use `<project>/CLAUDE.local.md` (auto-gitignored by Claude Code)
- **Machine-specific project settings**: Use `<project>/.claude/settings.local.json` (auto-gitignored)
- **Personal permissions accumulated over time**: These live in `~/.claude/settings.json` and are preserved by the merge strategy
- **MCP server configuration**: Lives in `~/.claude.json` — not managed by setup.sh since it may contain secrets/tokens

### Uninstalling

To remove the installed configuration:

```bash
./setup.sh --uninstall
```

This removes symlinks created by the installer and reports available backup files. Settings.json is preserved — restore a backup manually if needed:

```bash
cp ~/.claude/settings.json.backup.YYYYMMDD-HHMMSS ~/.claude/settings.json
```

### Advanced Usage

Individual setup steps can be run independently:

```bash
./setup.sh                        # Print resolved settings to stdout
./setup.sh --validate             # Validate template and hook paths
./setup.sh --output FILE          # Write resolved settings to a file
./setup.sh --merge FILE           # Merge resolved settings into existing file
./setup.sh --symlinks             # Create symlinks only (no settings)
./setup.sh --template FILE        # Use a custom template
./setup.sh --claude-dir DIR       # Target a different directory (for testing)
```

## Quick Start: Apply to a New Project

### 1. Copy a CLAUDE.md template

Choose a template based on your project type:

```bash
# General purpose
cp templates/claude-md-general.md /path/to/your-project/.claude/CLAUDE.md

# Node.js / TypeScript
cp templates/claude-md-nodejs.md /path/to/your-project/.claude/CLAUDE.md
```

Then fill in the project-specific sections. See the [CLAUDE.md Authoring Guide](guides/claude-md-guide.md) for detailed guidance on what to include and what to leave out.

### 2. Copy relevant language rules

Copy per-language rule files into your project's `.claude/rules/` directory:

```bash
mkdir -p /path/to/your-project/.claude/rules
cp rules/languages/typescript.md /path/to/your-project/.claude/rules/typescript.md
cp rules/languages/shell.md /path/to/your-project/.claude/rules/shell.md
```

Rules use `paths:` frontmatter so they only activate when Claude works on matching files — no wasted context tokens.

### 3. Symlink testing rules (optional)

If you want the Always/Never testing patterns available in your project:

```bash
ln -s /path/to/claude-config/rules/testing-rules.md /path/to/your-project/.claude/rules/testing.md
```

### 4. Reference the testing decision guide

The [Testing Decision Guide](guides/testing-decision-guide.md) maps five project types to concrete testing strategies:

| Project Type | Primary Strategy | Key Challenge |
|---|---|---|
| LLM-Calling Code | Unit + contract tests + fixtures | Non-determinism |
| Agent Frameworks | State machine + workflow tests | Complex state transitions |
| K8s/Infrastructure | Integration tests against real clusters | Heavy setup, slow feedback |
| Script-Orchestrated Tools | Input/output + CLI validation tests | Deterministic behavior |
| Pure Utilities | Standard unit + property-based tests | Straightforward |

Read the guide to choose your strategy, then apply its coverage targets and recommended tools.

### 5. Configure permission profile

Review the [Permission Profiles Guide](guides/permission-profiles.md) and configure your `~/.claude/settings.json` to match your trust level:

- **Conservative** — Claude asks before most actions. Best for learning or sensitive repos.
- **Balanced** — Claude handles routine operations. Best for daily development.
- **Autonomous** — Claude works independently. Best for trusted automation and YOLO mode.

## The /verify Skill

An interactive verification loop you run before creating pull requests. Invoke it with:

```text
/verify           # full mode (default): build, typecheck, lint, security, tests
/verify quick     # quick mode: build + typecheck only
/verify pre-pr    # pre-pr mode: full + expanded security checks
```

The skill auto-detects your project type by reading config files (package.json, tsconfig.json, etc.) and runs the appropriate commands. If a phase fails, it stops, explains the error, suggests a fix, and restarts from phase 1 after the fix is applied.

### Installing the skill globally

The skill lives at `.claude/skills/verify/` in this repo. To make it available in all projects, ensure this repo is cloned and Claude Code's settings reference the scripts. The skill is already installed if you're using this repo's `settings.json` as your base.

## PRD Workflow Skills

A suite of skills for managing feature work through Product Requirements Documents. PRD skills are **not installed globally** — they are installed per-project via `/make-autonomous` or `/make-careful`.

| Skill | Purpose |
|---|---|
| `/prd-create` | Create structured PRDs with milestones, requirements, and decision logs |
| `/prd-start` | Set up implementation context (validate PRD, create branch, chain to `/prd-next`) |
| `/prd-next` | Identify next task, implement with TDD, update progress, repeat |
| `/prd-update-progress` | Commit work and update PRD checkboxes with evidence |
| `/prd-update-decisions` | Capture design decisions and scope changes in the PRD decision log |
| `/prd-done` | Finalize a completed PRD: create PR, process CodeRabbit review, merge, close issue |
| `/prd-close` | Close a PRD that is already implemented or no longer needed |
| `/prds-get` | List all open PRD issues from GitHub |

### Installing PRD skills in a project

PRD skills require per-project installation. Choose a mode:

```bash
# In your project directory:
/make-autonomous    # YOLO mode — auto-chaining, minimal pauses
/make-careful       # Careful mode — confirmation gates, user approval
```

Both commands create symlinks in your project's `.claude/skills/` directory pointing to the canonical skill definitions in the claude-config repo. See [Autonomous PRD Mode](#autonomous-prd-mode) for details on how the modes differ.

## Autonomous PRD Mode

PRD skills operate in one of two modes, controlled per-project:

| | Careful (default) | Autonomous |
|---|---|---|
| **Invocation** | User-driven — you run each skill manually | Auto-chaining — skills invoke each other |
| **Confirmations** | Pauses for approval at each step | Proceeds without trivial confirmations |
| **Loop behavior** | No auto-resume after `/clear` | User runs `/clear` then `/prd-next` or `/prd-done` (auto-resume planned) |
| **Best for** | Unfamiliar projects, sensitive repos, learning | Trusted projects with well-defined PRDs |

### Enabling autonomous mode

Run `/make-autonomous` in your project directory. This:

1. **Creates symlinks to YOLO skill variants** — skill descriptions include active trigger language (e.g., "INVOKE AUTOMATICALLY after completing a PRD task") that drives Claude to invoke skills proactively
2. **Installs a SessionStart hook** — enables the `/clear` → auto-resume loop via `prd-loop-continue.sh` in `.claude/settings.local.json`
3. **Adds frictionless permissions** — auto-allows git operations, skill invocations, and web tools in `.claude/settings.local.json`

All changes are local (`.claude/settings.local.json` is auto-gitignored by Claude Code).

### The autonomous loop

When autonomous mode is enabled, PRD work flows continuously:

```text
/prd-start
    → /prd-next (identifies highest-priority task)
        → implement with TDD (hooks enforce quality)
            → /prd-update-progress (commits, updates PRD)
                → /clear (resets context)
                    → SessionStart hook detects PRD branch
                        → /prd-next (picks up next task)
                            → ... (repeats until all tasks done)
                                → /prd-done (creates PR, CodeRabbit review, merge)
```

The `/clear` step is intentional — it resets the context window so each task starts fresh, preventing context bloat from accumulating implementation details across tasks.

**Current limitation**: `/prd-update-progress` ends the autonomous loop. The user must manually run `/clear`, then `/prd-next` (or `/prd-done` when the PRD is complete). Fully automated cross-session looping is not yet possible — `/clear` cannot be invoked programmatically, and the SessionStart hook may not reliably trigger the next skill.

### Reverting to careful mode

Run `/make-careful` in your project directory. This swaps symlinks to careful skill variants, removes the SessionStart hook, and removes autonomous permissions. The project retains PRD skills but they require manual invocation.

### How it works: symlink-based mode switching

Each PRD skill has two variants in the claude-config repo:

| File | Mode | Description style |
|---|---|---|
| `SKILL.md` | Careful | Passive — "Analyze PRD to identify next task" |
| `SKILL.v1-yolo.md` | Autonomous | Active — "INVOKE AUTOMATICALLY after /clear on PRD branch" |

`/make-autonomous` creates symlinks pointing to `SKILL.v1-yolo.md`; `/make-careful` swaps them to point at `SKILL.md`. The `description` field in skill frontmatter appears in the system prompt's skill list — active trigger language in YOLO descriptions drives Claude to invoke skills proactively without being asked.

## Tiered Verification Hooks

Hooks run automatically as PreToolUse gates — no manual invocation needed. Each hook fires on the relevant git event and blocks if verification fails.

| Git Event | Hook | Verification Level | What It Checks |
|---|---|---|---|
| `git commit` | `pre-commit-hook.sh` | quick + lint | Build, Type Check, Lint (staged files only) |
| `git push` | `pre-push-hook.sh` | full (escalates to PR-tier when open PR detected) | Build, Type Check, Lint, Security, Tests |
| `gh pr create` | `pre-pr-hook.sh` | pre-pr | Build, Type Check, Lint, Security (expanded), Tests |

### Additional enforcement hooks

| Hook | Trigger | Behavior |
|---|---|---|
| `check-commit-message.sh` | `git commit` | Blocks commits with AI/Claude/Anthropic attribution |
| `check-branch-protection.sh` | `git commit` | Blocks direct commits to main/master |
| `check-coderabbit-required.sh` | `gh pr merge` | Blocks PR merge without CodeRabbit review |
| `check-test-tiers.sh` | `git push`, `gh pr create` | Warns when unit/integration/e2e tests are missing |
| `check-aboutme.sh` | Write/Edit | Blocks code files missing ABOUTME headers (PreToolUse) |
| `coderabbit-review.sh` | `git push` | Advisory CodeRabbit CLI review (runs after blocking checks) |
| `post-write-codeblock-check.sh` | Write/Edit | Warns about Markdown code blocks missing language specifiers (PostToolUse) |
| `prd-loop-continue.sh` | `/clear` | SessionStart hook that resumes PRD work (installed per-project by `/make-autonomous`) |

### Dotfile opt-outs

Repos can opt out of specific enforcement by placing dotfiles at the project root:

| Dotfile | Effect |
|---|---|
| `.skip-branching` | Skips branch protection (allows commits to main) |
| `.skip-coderabbit` | Skips CodeRabbit review requirement on PR merge |
| `.skip-integration` | Skips integration test tier warning |
| `.skip-e2e` | Skips e2e test tier warning |
| `.verify-skip` | Lists paths excluded from security checks (one per line) |

### Installing hooks in settings.json

Hooks are registered in `~/.claude/settings.json` under the `hooks` key. Each hook script is a PreToolUse or PostToolUse command that fires on a matcher pattern. Here is the structure:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/claude-config/.claude/skills/verify/scripts/pre-commit-hook.sh"
          }
        ]
      }
    ]
  }
}
```

See the [reference settings.json](#reference-configuration) section for the full hook configuration.

## Per-Language Rule Files

Rule files in `rules/languages/` use `paths:` frontmatter so Claude Code only loads them when working on matching files:

```markdown
---
paths: ["**/*.ts", "**/*.tsx", "**/tsconfig.json"]
---

# TypeScript Rules

- Prefer `interface` over `type` for object shapes
- Use `unknown` over `any`
...
```

Available languages:

| File | Activates On | Status |
|---|---|---|
| `typescript.md` | `**/*.ts`, `**/*.tsx` | Rules from real usage |
| `shell.md` | `**/*.sh` | Rules from real usage |
| `javascript.md` | `**/*.js`, `**/*.jsx` | Rules from real usage |
| `python.md` | `**/*.py` | Placeholder — add as patterns emerge |
| `go.md` | `**/*.go` | Placeholder — add as patterns emerge |

## Project Detection

The verification scripts auto-detect project type and available commands. Running `detect-project.sh` against a real project:

```text
$ bash .claude/skills/verify/scripts/detect-project.sh /path/to/project
{
  "project_dir": "/path/to/project",
  "project_type": "node-javascript",
  "config_files": {
    "package_json": true,
    "tsconfig": false,
    "pyproject": false,
    "go_mod": false,
    "cargo": false
  },
  "commands": {
    "build": "npm run build",
    "typecheck": null,
    "lint": "npm run lint",
    "test": "npm run test"
  },
  "package_manager": "npm"
}
```

The test tier detection script identifies which test tiers exist:

```text
$ bash .claude/skills/verify/scripts/detect-test-tiers.sh /path/to/project
{
  "project_dir": "/path/to/project",
  "project_type": "node-javascript",
  "test_tiers": {
    "unit": true,
    "integration": false,
    "e2e": false
  }
}
```

## Reference Configuration

The full `~/.claude/settings.json` hook configuration used in production:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/check-aboutme.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/check-commit-message.sh" },
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/check-branch-protection.sh" },
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/check-coderabbit-required.sh" },
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/pre-commit-hook.sh" },
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/pre-push-hook.sh" },
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/pre-pr-hook.sh" },
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/check-test-tiers.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "/path/to/claude-config/.claude/skills/verify/scripts/post-write-codeblock-check.sh" }
        ]
      }
    ]
  }
}
```

The `prd-loop-continue.sh` SessionStart hook is **not** included in global settings — it is installed per-project by `/make-autonomous` into `.claude/settings.local.json`.

Replace `/path/to/claude-config` with the absolute path to your clone of this repo.

## Repo Structure

```text
claude-config/
  setup.sh                             # Install script (--install, --uninstall)
  settings.template.json               # Settings template with $CLAUDE_CONFIG_DIR
  .claude/
    CLAUDE.md                          # Project-level instructions
    skills/
      verify/
        SKILL.md                       # /verify skill definition
        scripts/                       # All hook and verification scripts
        tests/                         # Hook tests (316 tests across 11 modules)
      research/
        SKILL.md                       # /research skill definition
      write-prompt/
        SKILL.md                       # /write-prompt skill definition
      write-docs/
        SKILL.md                       # /write-docs skill definition
      anki/
        SKILL.md                       # /anki skill definition
      anki-yolo/
        SKILL.md                       # /anki-yolo skill definition (autonomous)
      make-autonomous/
        SKILL.md                       # /make-autonomous — enable YOLO PRD mode
      make-careful/
        SKILL.md                       # /make-careful — disable YOLO PRD mode
      prd-create/
        SKILL.md                       # /prd-create (careful mode — default)
        SKILL.v1-yolo.md              # YOLO variant (active trigger descriptions)
      prd-start/
        SKILL.md                       # /prd-start (careful)
        SKILL.v1-yolo.md
      prd-next/
        SKILL.md                       # /prd-next (careful)
        SKILL.v1-yolo.md
      prd-update-progress/
        SKILL.md                       # /prd-update-progress (careful)
        SKILL.v1-yolo.md
      prd-update-decisions/
        SKILL.md                       # /prd-update-decisions (careful)
        SKILL.v1-yolo.md
      prd-done/
        SKILL.md                       # /prd-done (careful)
        SKILL.v1-yolo.md
      prd-close/
        SKILL.md                       # /prd-close (careful)
        SKILL.v1-yolo.md
      prds-get/
        SKILL.md                       # /prds-get (list open PRDs)
  global/
    CLAUDE.md                          # Global development standards (→ ~/.claude/CLAUDE.md)
  guides/
    claude-md-guide.md                 # How to write CLAUDE.md files
    permission-profiles.md             # Three permission tiers
    testing-decision-guide.md          # Project type → testing strategy
  prds/                                # Active PRDs
    done/                              # Archived completed PRDs
  rules/                               # User-level rules (→ ~/.claude/rules/)
    testing-rules.md                   # Always/Never testing patterns
    branch-protection.md               # Docs-only exemption for main branch
    languages/                         # Per-language rules with paths: activation
      typescript.md
      shell.md
      javascript.md
      python.md                        # Placeholder
      go.md                            # Placeholder
  scripts/                             # Standalone hooks and utilities
    google-mcp-safety-hook.py          # Google API MCP safety hook
    gogcli-safety-hook.py              # gogcli MCP safety hook
    prd-loop-continue.sh               # SessionStart hook for PRD work continuation
  templates/
    claude-md-general.md               # General CLAUDE.md template
    claude-md-nodejs.md                # Node.js/TypeScript template
  tests/
    test_setup.py                      # Setup script tests (155 tests)
    test_prd_loop_continue.py          # PRD loop continuation hook tests (31 tests)
```
