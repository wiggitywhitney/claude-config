# Global Development Standards

## Dates and Times

Before discussing any date, time, day of the week, or scheduling topic with the user, run `date` first to get the current date, time, and day of the week. Do not rely on context injections or training data — use the deterministic output. This applies to any conversation involving deadlines, "today", "tomorrow", days of the week, or relative time references.

## Writing Style

When drafting emails or written communication:
- Use complete sentences. Never drop subjects.
- **Do**: "I am happy to answer any questions." / "I am just bubbling this back up."
- **Don't**: "Happy to answer any questions." / "Just bubbling this back up."
- Kind but direct, with full sentences.

## Writing Code

- Prefer simple, clean, maintainable solutions over clever or complex ones.
- Make the smallest reasonable changes necessary.
- Match the style and formatting of surrounding code.
- NEVER make unrelated code changes. Document them in a new issue instead.
- NEVER remove code comments unless actively false. Preserve documentation.
- Write evergreen comments; avoid temporal references.
- Avoid naming code as 'improved', 'new', or 'enhanced'. Use evergreen naming.
- NEVER implement mock modes. Use real data and APIs only.
- NEVER add fallback mechanisms without explicit permission. Code should fail explicitly rather than silently fall back to defaults.
- **You MUST ask permission** before reimplementing features or systems from scratch.
- Prefer deterministic scripts/code over AI for operational tasks. Use AI for content understanding, narrative synthesis, and semantic analysis.
- When creating prompts for AI agents, emphasize the process to follow rather than stating the goal upfront.
- When creating or modifying any SKILL.md file, system prompt, or AI agent instruction, use `/write-prompt` to review the result before committing.
- **ALWAYS add progress indicators** for any operation that might cause the user to wait. This includes downloading files, processing large datasets, network requests, and any computation that takes more than 1-2 seconds.
- **MANDATORY**: When writing user-facing documentation (README, guides, PRD milestones), invoke `/write-docs`. Do not skip this step. Excludes CLAUDE.md and rule files.

## Getting Help

- ALWAYS ask for clarification rather than making assumptions.
- Ask for help when encountering difficulties.

## Adopting New Technologies

- **MANDATORY**: Before writing code with any technology new to the project, invoke `/research <technology>`. Do not skip this step.
- Full process: @~/.claude/rules/adopting-new-technologies.md

## Testing

- Tests MUST cover implemented functionality. No tests, not done. TDD: write failing test → implement → verify.
- Use real implementations when feasible; mock only at system boundaries. Separate deterministic from non-deterministic.
- Full testing rules: @~/.claude/rules/testing-rules.md
- Project-type strategies: @~/Documents/Repositories/claude-config/guides/testing-decision-guide.md

## Development Workflow

- Discover → write test → run test → implement → verify via test → fix if broken → commit.
- Never reference task management systems or items in code files or documentation.

## Git Workflow

- Feature branches only. PRs require CodeRabbit review approved by human before merge.
- Full workflow, CodeRabbit process, and triage rubric: @~/.claude/rules/git-workflow.md

## Issue Juggling

- Autonomous multi-issue workflow: branch per issue, TDD, CodeRabbit review cycle, merge, next.
- Full process: @~/.claude/rules/issue-juggling.md

## Infrastructure Safety

- Backup before editing infra. Never overwrite databases without permission. List commands before executing.
- Full rules: @~/.claude/rules/infrastructure-safety.md

## ABOUTME File Headers

Every code file (`.py`, `.sh`, `.ts`, `.tsx`, `.js`, `.jsx`) must start with a 1-2 line ABOUTME header using the file's comment syntax (`# ABOUTME: ...` or `// ABOUTME: ...`). Place after shebang lines when present. Exempt: `__init__.py`, config files (JSON/YAML/TOML), markdown, HTML/CSS, generated files, `node_modules`, `.d.ts`, `.min.js`. A PreToolUse hook enforces this. Examples: @~/.claude/rules/aboutme-headers.md

## Datadog Enterprise Environment

- Claude Code routes through the Datadog AI Gateway. Subprocesses calling the Anthropic API will fail if gateway headers are wrong.
- Routing details and bypass fix: @~/.claude/rules/datadog-environment.md

## Language & Configuration Defaults

- Primary languages: TypeScript, Markdown, YAML, Shell, JSON. Prefer TypeScript for code, YAML for configuration.

## Vals Secrets Management

- Wrap commands with `vals exec -f .vals.yaml --` to inject secrets. Never extract, store, or inline secret values.
- Details and examples: @~/.claude/rules/vals-secrets.md

## OpenTelemetry Packaging

- Libraries and distributable packages depend on the OTel **API** only — never the SDK, instrumentation packages, or auto-instrumentation bundles.
- The OTel API is a lightweight no-op contract (~50KB in Node, similar in Python/Go). The SDK is the heavyweight implementation that exporters, samplers, and processors live in. Deployers choose the SDK; libraries don't.
- In Node.js specifically, `@opentelemetry/api` must be a `peerDependency` — multiple instances in `node_modules` cause silent trace loss via no-op fallbacks.
- This applies regardless of whether dependencies are added by a human or an AI agent.

## PRD Workflow

Feature work is tracked in PRDs (`prds/` directory). Use the PRD skills: `/prd-create`, `/prd-next`, `/prd-update-progress`, `/prd-update-decisions`, `/prd-done`.
- Do not invent tasks outside the PRD structure. When a PRD exists, follow it.
- **Do NOT commit manually during PRD work.** `/prd-update-progress` handles commits, PRD updates, and journaling together.

## Conflict Resolution

- Project CLAUDE.md overrides global. When rules conflict, ask the user.

## Hooks Reference

- Hook details: @~/.claude/rules/hooks-reference.md
