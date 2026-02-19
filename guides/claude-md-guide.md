# CLAUDE.md Authoring Guide

How to write an effective project-level `.claude/CLAUDE.md` file. Use with the skeleton templates in `templates/`.

## Core Principle: Lean and Project-Specific

The global `~/.claude/CLAUDE.md` already handles coding standards, testing defaults, TDD workflow, git workflow, and hook documentation. Your project-level CLAUDE.md should contain **only what's unique to this project**. If it's true of every project, it belongs in the global file, not here.

Target: under 150 lines. If your file is growing past that, factor domain-specific rules into `rules/` files with `paths:` frontmatter activation (see [Rule Files](#rule-files) below).

**Why lean matters:** Claude Code wraps CLAUDE.md content with a dismissal notice ("this context may or may not be relevant to your tasks"). The more irrelevant content in your file, the more likely Claude ignores even the important parts. Frontier LLMs can follow ~150 instructions with reasonable consistency; Claude Code's system prompt consumes ~50 of those, leaving ~100 for your CLAUDE.md and rules combined.

**The test for every line:** "Would removing this cause Claude to make mistakes?" If not, cut it.

## CLAUDE.md Hierarchy

Claude Code loads instructions from multiple locations. More specific files take precedence over broader ones.

| File | Scope | Shared via git? |
|---|---|---|
| `~/.claude/CLAUDE.md` | All projects (personal) | No |
| `.claude/CLAUDE.md` | This project (team) | Yes |
| `.claude/rules/*.md` | This project, path-scoped | Yes |
| `CLAUDE.local.md` | This project (personal, auto-gitignored) | No |

**`CLAUDE.local.md`** is useful for personal overrides that shouldn't be committed: local sandbox URLs, preferred test data, port configurations, environment-specific settings.

**Child directory CLAUDE.md files** load on demand when Claude reads files in those directories — useful for monorepos with distinct subsystems.

## Section Reference

### Project Name + Description

The heading and first line. Tell Claude what this project is and why it exists in one sentence.

**Real example** (commit-story-v2):
```markdown
# Commit Story v2

A complete rebuild of commit-story using modern tooling (LangGraph) with zero telemetry.
```

**Real example** (content-manager):
```markdown
# Content Manager

Content manager for Whitney Lee's content publishing workflow. Syncs content from a Google Sheet to Micro.blog, which then cross-posts to Bluesky and other platforms.
```

### Project Constraints

Non-obvious constraints that change how Claude should write code. These are the rules that are easy to violate if you don't know about them.

**Real example** (commit-story-v2):
```markdown
## Project Constraints

- The app ships with NO instrumentation. Do not add telemetry — an AI instrumentation agent will add it in Phase 3.
- **Build order**: Phase 1 (LangGraph rebuild, this repo) → Phase 2 (OTel Weaver schema) → Phase 3 (Telemetry Agent)
```

**Real example** (cluster-whisperer):
```markdown
## Terminology Corrections

**Correct the user if they confuse LangChain and LangGraph** - even if you understand from context. This is for a KubeCon presentation; precise terminology matters.

## Code Style

This is a learning-focused repository. All code and documentation should:
- Include doc strings explaining what the code does and why
- Use plain language that someone with no prior knowledge can understand
- Be succinct - explain concepts clearly without unnecessary verbosity
- Prioritize teaching over production optimization
```

Good constraints are things Claude would get wrong without being told: build ordering, forbidden dependencies, terminology precision, audience-specific writing style.

### Tech Stack

List the core technologies so Claude makes consistent choices and doesn't introduce unwanted dependencies.

**Real example** (commit-story-v2):
```markdown
## Tech Stack

- **LangGraph** (`@langchain/langgraph` v1.1.0) for AI orchestration
- **LangChain** for model integrations
- **Node.js** with ES modules
- **No telemetry** - this will be added by an instrumentation agent later
```

Include version pins if they matter. Call out what's intentionally absent ("No telemetry", "No runtime dependencies").

### Development Setup

How to install, build, test, and run the project. Concrete commands that someone can copy-paste.

**Real example** (content-manager) — a `## Development Setup` section with the command to get credentials:

```bash
gcloud secrets versions access latest --secret=content_manager_service_account --project=demoo-ooclock
```

Keep this to the minimum needed to get running. If setup is complex, use an `@import` to reference a separate doc rather than bloating CLAUDE.md (see [Imports](#imports) below).

### Testing

Project-specific testing details only. The global CLAUDE.md already handles: TDD workflow, run tests before committing, real implementations over mocks, and references to `rules/testing-rules.md`.

Add here: the test command, coverage thresholds, where test files live, which test tiers apply (and which are opted out via `.skip-e2e`, `.skip-integration`).

### Completion Checklist

What Claude checks before marking any task complete. Make these specific to the project — not generic "tests pass" but the actual commands.

**Example** for a Node.js project:
```markdown
## Completion Checklist

- [ ] Tests written for new functionality
- [ ] All tests pass (`npm test`)
- [ ] Build succeeds (`npm run build`)
- [ ] Type check passes (`npx tsc --noEmit`)
```

### Optional Sections

Include only when relevant. Each is a full section in the template, commented out until needed.

**Workflow Mode** — For projects that use YOLO/autonomous mode. Defines how much Claude should do without asking.

**Secrets Management** — For projects using vals or other secrets tooling. Document how to load secrets locally.

**Package Distribution** — For published packages. Registry, package name, entry points, dependency audit commands.

**Rules Enforced by Hooks** — HTML comments documenting what hooks enforce. These don't consume Claude's attention on rules already handled deterministically.

**Real example** (cluster-whisperer):
```markdown
<!-- Git workflow, CodeRabbit reviews enforced globally via ~/.claude/CLAUDE.md -->
```

## Imports

CLAUDE.md files support `@path/to/file` syntax for referencing external files without inlining their content:

```markdown
See @README.md for project overview and @package.json for available npm commands.
Git workflow: @docs/git-instructions.md
```

- Relative paths resolve relative to the file containing the import, not the working directory.
- Absolute paths and `~` home paths are supported.
- Recursive imports work up to 5 levels deep.
- Imports inside code spans and code blocks are not evaluated.
- First-time imports require an approval dialog from the user.

Use imports for content that's already well-documented elsewhere (README, docs/) rather than duplicating it into CLAUDE.md.

## Rule Files

When a project has domain-specific rules (language conventions, API patterns, architecture constraints), factor them into `.claude/rules/` files rather than growing CLAUDE.md.

Rule files are loaded with the **same priority as CLAUDE.md** but offer modular organization. Rules without a `paths:` field load unconditionally. Rules with `paths:` activate only when Claude works on matching files.

```markdown
---
paths: ["**/*.ts", "**/*.tsx"]
---

# TypeScript Rules

- Prefer `interface` over `type` for object shapes
- Use `unknown` over `any`
```

For new domains without established patterns, create a placeholder:

```markdown
---
paths: ["**/*.py"]
---

# Python Rules

Add rules as patterns emerge from real usage.
```

**Organizing rules:**

```text
.claude/rules/
  frontend/
    react.md
    styles.md
  backend/
    api.md
    database.md
  general.md
```

**Symlinks** are supported, enabling shared rules across projects:

```bash
ln -s ~/Documents/Repositories/claude-config/rules/testing-rules.md .claude/rules/testing.md
```

This keeps each file focused and avoids loading irrelevant rules. See `rules/testing-rules.md` for a real example.

## What to Include vs Exclude

From [Anthropic's official best practices](https://code.claude.com/docs/en/best-practices):

**Include:**
- Bash commands Claude cannot guess (build, test, deploy)
- Code style rules that differ from language defaults
- Testing instructions and preferred test runners
- Repository etiquette (branch naming, PR conventions)
- Architectural decisions specific to your project
- Developer environment quirks (required env vars)
- Common gotchas or non-obvious behaviors

**Exclude:**
- Anything Claude can figure out by reading code
- Standard language conventions Claude already knows
- Detailed API documentation (use `@imports` to link instead)
- Information that changes frequently
- Long explanations or tutorials
- File-by-file descriptions of the codebase
- Self-evident practices like "write clean code"

## When to Use CLAUDE.md vs Other Features

| Need | Use |
|---|---|
| Universal project context loaded every session | `.claude/CLAUDE.md` |
| Modular, path-scoped instructions | `.claude/rules/*.md` |
| Domain knowledge loaded on demand | Skills (`.claude/skills/`) |
| Actions that must happen every time with zero exceptions | Hooks |
| Personal project-specific overrides | `CLAUDE.local.md` |

CLAUDE.md instructions are **advisory** — Claude may choose to ignore them. Hooks are **deterministic** and guarantee execution. If something must always happen (run linter after edit, block writes to a directory), use a hook.

## Anti-Patterns

- **Duplicating global rules.** If it's in `~/.claude/CLAUDE.md`, don't repeat it.
- **Speculative rules.** Don't add rules for problems you haven't hit. Let real usage drive content.
- **Long CLAUDE.md files.** Past ~150 lines, factor content into `rules/` or separate docs. Every line costs context tokens on every conversation.
- **Uncommented examples.** Template examples that aren't deleted after customization become confusing instructions that Claude might follow literally.
- **Generic completion checklists.** "Tests pass" is less useful than "`npm test` passes." Be specific.
- **Using CLAUDE.md as a linter.** Style enforcement belongs in deterministic tools (formatters, linters, hooks), not CLAUDE.md instructions.
- **Hotfix rules.** Don't add a rule because Claude made one mistake. Evaluate whether the rule is genuinely universally applicable.
- **Temporal references.** Avoid "we recently changed X" or "the new API." Use evergreen language.

## Sources

- [Manage Claude's memory](https://code.claude.com/docs/en/memory) — canonical reference for CLAUDE.md hierarchy and behavior
- [Best Practices for Claude Code](https://code.claude.com/docs/en/best-practices) — official include/exclude guidance
- [Using CLAUDE.md files](https://claude.com/blog/using-claude-md-files) — Anthropic blog post on the WHAT/WHY/HOW framework
