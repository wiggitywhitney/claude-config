# Research: Forrester's `claude-config/` Directory

**Source**: `https://github.com/peopleforrester/llm-coding-workflow/tree/main/claude-config`
**Analyzed**: 2026-02-18
**Purpose**: Inform Milestone 3 of PRD #1 (CLAUDE.md templates, permission profiles, per-language rules)

---

## Directory Structure

```text
claude-config/
├── CLAUDE.md              # ~137 lines — universal behavioral rules only
├── settings.json          # Hooks registration, model config, env vars
├── hooks/
│   ├── validate-file.sh       # PostToolUse: Edit|Write — py_compile, ruff, yamllint
│   ├── check-aboutme.sh       # PostToolUse: Edit|Write — ABOUTME header warning
│   └── check-commit-message.sh # PreToolUse: Bash — blocks AI/Claude refs in commits
├── rules/
│   ├── code-style.md          # Universal code style (imports, naming, formatting)
│   ├── languages/
│   │   ├── python.md          # Python conventions + uv preference
│   │   ├── typescript.md      # Detailed TS/Node conventions (~60 lines)
│   │   └── using-uv.md        # uv field manual (~200 lines)
│   ├── frameworks/
│   │   ├── langchain.md       # Placeholder
│   │   └── mcp-servers.md     # Placeholder
│   ├── infra/
│   │   ├── docker.md          # Placeholder
│   │   ├── kubernetes.md      # K8s safety rules
│   │   ├── railway.md         # Deployment workflow
│   │   └── terraform.md       # Placeholder
│   └── tools/
│       ├── argocd.md          # Placeholder
│       └── backstage.md       # Placeholder
└── skills/                    # 25 skill directories, each with SKILL.md
    ├── review-verify/
    ├── plan/
    ├── engineering-journal/
    ├── gh-work-issue/
    └── ... (20+ more)
```

---

## The Content Distribution Pattern

The core architectural insight is a **four-tier content distribution** that minimizes context window cost:

| Tier | Location | Loaded When | Purpose | Context Cost |
|------|----------|-------------|---------|-------------|
| **Always** | `CLAUDE.md` | Every conversation | Universal behavioral rules | ~137 lines |
| **Conditional** | `rules/` | File patterns match | Domain-specific conventions | 0 when irrelevant |
| **Deterministic** | `hooks/` | Tool events fire | Automated enforcement | 0 (runs as scripts) |
| **On-demand** | `skills/` | User invokes | Workflow orchestration | 0 until invoked |

**Decision tree for where a rule should live:**

1. Can it be checked programmatically? → `hooks/` (zero context cost, 100% enforcement)
2. Is it specific to a language, framework, or tool? → `rules/` with path-scoped loading
3. Is it an AI-orchestrated workflow? → `skills/`
4. Is it a universal behavioral rule that applies in every context? → `CLAUDE.md`
5. Is it a hook-enforced rule that humans need to see? → HTML comment in CLAUDE.md

---

## CLAUDE.md Analysis (~137 lines)

### What's IN CLAUDE.md

- **Interaction preferences**: "Address me as Michael"
- **Universal code principles**: Prefer simple solutions, match surrounding style, smallest reasonable changes
- **Permission gates**: Ask before reimplementing, no fallback mechanisms without permission
- **Testing philosophy**: TDD process, no-exceptions test policy, pristine test output
- **Git workflow**: Branch strategy (staging → main), NEVER push to main directly
- **Commit rules**: No AI/Claude references (enforced by hook, documented here)
- **Multi-phase workflow rules**: TaskCreate/TaskUpdate tracking, test after each phase
- **Language defaults**: Python primary, YAML over JSON
- **HTML comments documenting hook-enforced rules** (key pattern)

### What's NOT in CLAUDE.md

- Language-specific syntax/style rules → `rules/languages/`
- Framework-specific patterns → `rules/frameworks/`
- Infrastructure conventions → `rules/infra/`
- Tool-specific configurations → `rules/tools/`
- Verification logic → `hooks/`
- Slash command definitions → `skills/`

### HTML Comments Pattern

```markdown
## Rules Enforced by Hooks and Git Infrastructure

<!-- Claude Code hooks (fire only during Claude sessions): -->
<!-- validate-file.sh (PostToolUse: Edit|Write) - py_compile, ruff style/naming, yamllint -->
<!-- check-aboutme.sh (PostToolUse: Edit|Write) - ABOUTME header warning for .py files -->
<!-- check-commit-message.sh (PreToolUse: Bash) - blocks commits with AI/Claude references -->

<!-- Git hooks (fire for ALL operations - Claude, manual, CI): -->
<!-- pre-commit - lint + type check (fast, every commit) -->
<!-- pre-push - security scan + unit tests (all pushes) + e2e gate (main only) -->
<!-- Deployed via: llm_coding_workflow/scripts/git-hooks/deploy.sh <repo-path> -->
```

**Why this works**: HTML comments are invisible to Claude (no context cost) but visible to humans reading the file. The human knows these hooks exist and what they enforce without burning AI context tokens.

---

## Rules Directory Analysis

### Path-Scoped Loading (Key Mechanism)

Every rule file has YAML frontmatter with `paths:` globs:

```yaml
---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/uv.lock"
---
```

Claude Code only loads the rule into context when the conversation involves files matching those patterns. Python rules don't load when editing TypeScript. Docker rules don't load when writing Python.

### Content Density Varies

| File | Lines | Status |
|------|-------|--------|
| `using-uv.md` | ~200 | Comprehensive field manual |
| `typescript.md` | ~60 | Detailed conventions (type safety, async, testing, naming) |
| `kubernetes.md` | ~15 | Safety rules for cluster operations |
| `railway.md` | ~25 | Deployment workflow |
| `python.md` | ~10 | Brief conventions + uv reference |
| Most others | ~5 | "Add rules as patterns emerge" placeholder |

**Key insight**: The structure is **scaffolded but not forced**. Create the directory and placeholder files for domains you work in. Fill rules in organically as patterns emerge from real work. Don't front-load rules you haven't needed yet.

### Rules Taxonomy

| Category | Purpose | Examples |
|----------|---------|---------|
| `code-style.md` | Universal formatting | Imports ordering, indentation, docstrings, naming |
| `languages/` | Language-specific conventions | Type safety, package management, testing frameworks |
| `frameworks/` | Framework-specific patterns | LangChain, MCP servers |
| `infra/` | Infrastructure conventions | Docker, K8s, Terraform, Railway |
| `tools/` | External tool configurations | ArgoCD, Backstage |

---

## Hooks Analysis

### Architecture Pattern

Each hook is a **standalone bash script** that:
1. Reads JSON from stdin (`INPUT=$(cat)`)
2. Extracts tool name and input with `jq`
3. Applies domain-specific checks
4. Returns exit code: 0 = allow, 2 = block

### Documentation Pattern

Every hook has an extensive header comment block:
- `# ABOUTME:` 2-line summary
- `# HOW THIS HOOK WORKS:` section explaining the stdin JSON format
- `# EXIT CODES:` section
- `# WHAT IT CATCHES:` section
- `# REGISTERED IN:` pointing to settings.json

This is notably thorough — the hook is self-documenting for any human reader.

### Hook Design Choices

| Hook | Type | Matcher | Behavior |
|------|------|---------|----------|
| `validate-file.sh` | PostToolUse | `Edit\|Write` | Runs py_compile + ruff on .py, yamllint on .yaml |
| `check-aboutme.sh` | PostToolUse | `Edit\|Write` | Warns if .py file missing ABOUTME header |
| `check-commit-message.sh` | PreToolUse | `Bash` | Blocks commits with AI/Claude references |

**PostToolUse hooks warn but never block** (exit 0 always). **PreToolUse hooks can block** (exit 2).

### Commit Message Hook — Scoping Technique

The `check-commit-message.sh` hook demonstrates careful scoping:
1. Only processes Bash tool calls (checks `tool_name`)
2. Only checks `git commit` commands (regex match)
3. Extracts **only the commit message** (not file paths or other args)
4. Handles multiple message formats: heredoc, `-m "..."`, `--message="..."`
5. Skips check if message extraction fails (avoids false positives)

This is a pattern worth borrowing: **extract the minimal relevant data, then check only that**.

---

## Settings.json Analysis

```json
{
  "env": { "CLAUDE_CODE_ENABLE_TELEMETRY": "1", "OTEL_METRICS_EXPORTER": "otlp" },
  "model": "opus",
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "..." }] }],
    "PostToolUse": [{ "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "..." }, { "type": "command", "command": "..." }] }]
  },
  "statusLine": { "type": "command", "command": "..." },
  "skipDangerousModePermissionPrompt": true
}
```

**Notable**: No explicit `allow`/`deny` permission lists. Forrester runs in full autonomous mode (`skipDangerousModePermissionPrompt: true`) and relies on hooks + CLAUDE.md rules for safety instead of permission restrictions.

---

## Skills Pattern

Each skill is a directory containing `SKILL.md`. No supporting scripts inside skill directories.

**Skill structure**:
- Description of what the skill does
- "When to Use" section
- "Invocation" section (how user triggers it)
- "Steps" or "Behavior" section (the process)
- "Key Principles" section (behavioral constraints)
- "Tools Used" section

Skills are behavioral/process prompts. They tell Claude **how** to do something, not just **what** to do. Scripts referenced by skills live outside the skills directory (in the main repo's `scripts/` tree).

---

## Patterns Worth Borrowing for Whitney's Config

### High Priority (Direct Applicability)

1. **Four-tier content distribution** — CLAUDE.md for universal rules, `rules/` for conditional, `hooks/` for enforcement, `skills/` for workflows
2. **Path-scoped rule loading** via YAML frontmatter `paths:` field
3. **HTML comments in CLAUDE.md** for documenting hook-enforced rules (zero context cost for AI, visible to humans)
4. **Scaffold-then-fill approach** for rules — create the structure with placeholders, fill as patterns emerge
5. **Self-documenting hooks** with HOW THIS HOOK WORKS blocks

### Medium Priority (Adapt to Whitney's Context)

6. **Lean CLAUDE.md target** (~150 lines) — factor out everything that has a better home
7. **Universal `code-style.md`** at rules root for cross-language conventions
8. **Commit message scoping technique** — extract minimal relevant data before checking

### Contextual Differences (Whitney vs Forrester)

| Aspect | Forrester | Whitney |
|--------|-----------|---------|
| Permission model | Full autonomous (skipDangerousModePermissionPrompt) | Tiered verification hooks |
| Safety philosophy | CLAUDE.md rules + commit message hook | Tiered hooks (commit/push/PR) + settings.json deny lists |
| Branch strategy | staging → main | feature branches → main |
| Primary languages | Python, TypeScript | TypeScript primary |
| Rules density | Many placeholders, few rich | N/A (building from scratch) |

Whitney's approach is more defense-in-depth (layered hooks + permission deny lists). The templates should reflect this rather than Forrester's full-autonomous model.

---

## Key Takeaway

The most valuable pattern is the **content distribution decision tree**:

> "If a rule can be checked programmatically, it belongs in a hook, not CLAUDE.md. If it's language-specific, it belongs in `rules/languages/` with path-scoped loading, not CLAUDE.md. CLAUDE.md is reserved for universal behavioral rules that apply in every conversation."

This principle should drive Whitney's CLAUDE.md audit (next task) and template design.
