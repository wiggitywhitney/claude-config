# claude-config

Shared Claude Code testing infrastructure, safety config, and developer tooling. Apply to any project developed with Claude Code to get standardized verification, testing guidance, and safety guardrails.

## What's Included

| Deliverable | Path | Purpose |
|---|---|---|
| Testing Decision Guide | [`guides/testing-decision-guide.md`](guides/testing-decision-guide.md) | Maps project types to testing strategies |
| `/verify` Skill | [`.claude/skills/verify/`](.claude/skills/verify/) | Pre-PR verification loop (build, typecheck, lint, security, tests) |
| Tiered Verification Hooks | [`.claude/skills/verify/scripts/`](.claude/skills/verify/scripts/) | Automatic gates on commit, push, and PR creation |
| CLAUDE.md Templates | [`templates/`](templates/) | Starter templates for new projects |
| CLAUDE.md Authoring Guide | [`guides/claude-md-guide.md`](guides/claude-md-guide.md) | How to write effective CLAUDE.md files |
| Testing Rules | [`rules/testing-rules.md`](rules/testing-rules.md) | Always/Never testing patterns |
| Permission Profiles | [`guides/permission-profiles.md`](guides/permission-profiles.md) | Three trust levels for `settings.json` |
| Per-Language Rules | [`rules/languages/`](rules/languages/) | Path-scoped rules for TypeScript, Shell, Python, Go, JS |

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

## Tiered Verification Hooks

Hooks run automatically as PreToolUse gates — no manual invocation needed. Each hook fires on the relevant git event and blocks if verification fails.

| Git Event | Hook | Verification Level | What It Checks |
|---|---|---|---|
| `git commit` | `pre-commit-hook.sh` | quick + lint | Build, Type Check, Lint (staged files only) |
| `git push` | `pre-push-hook.sh` | full | Build, Type Check, Lint, Security, Tests |
| `gh pr create` | `pre-pr-hook.sh` | pre-pr | Build, Type Check, Lint, Security (expanded), Tests |

### Additional enforcement hooks

| Hook | Trigger | Behavior |
|---|---|---|
| `check-commit-message.sh` | `git commit` | Blocks commits with AI/Claude/Anthropic attribution |
| `check-branch-protection.sh` | `git commit` | Blocks direct commits to main/master |
| `check-coderabbit-required.sh` | `gh pr merge` | Blocks PR merge without CodeRabbit review |
| `check-test-tiers.sh` | `git push`, `gh pr create` | Warns when unit/integration/e2e tests are missing |
| `post-write-codeblock-check.sh` | Write/Edit | Warns about Markdown code blocks missing language specifiers |

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

Replace `/path/to/claude-config` with the absolute path to your clone of this repo.

## Repo Structure

```text
claude-config/
  .claude/
    CLAUDE.md                          # Project-level instructions
    skills/
      verify/
        SKILL.md                       # /verify skill definition
        scripts/                       # All hook and verification scripts
        tests/                         # Hook tests
  guides/
    claude-md-guide.md                 # How to write CLAUDE.md files
    permission-profiles.md             # Three permission tiers
    testing-decision-guide.md          # Project type → testing strategy
  rules/
    testing-rules.md                   # Always/Never testing patterns
    languages/                         # Per-language rules with paths: activation
      typescript.md
      shell.md
      javascript.md
      python.md                        # Placeholder
      go.md                            # Placeholder
  templates/
    claude-md-general.md               # General CLAUDE.md template
    claude-md-nodejs.md                # Node.js/TypeScript template
```
