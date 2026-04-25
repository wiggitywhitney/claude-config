# Global Development Standards

## Dates and Times

Before discussing any date, time, day of the week, or scheduling topic with the user, run `date` first to get the current date, time, and day of the week. Do not rely on context injections or training data — use the deterministic output. This applies to any conversation involving deadlines, "today", "tomorrow", days of the week, or relative time references. Do NOT compute a specific future date's day of the week from memory or mental arithmetic — always verify with a deterministic method: `python3 -c "from datetime import date; print(date(YYYY,MM,DD).strftime('%A'))"`.

## Writing Style

When drafting emails or written communication:
- Use complete sentences. Never drop subjects.
- **Do**: "I am happy to answer any questions." / "I am just bubbling this back up."
- **Don't**: "Happy to answer any questions." / "Just bubbling this back up."
- Kind but direct, with full sentences.

## Shell Commands

- Always provide shell commands as a single line. Never use backslash line continuation — it breaks when pasted into a terminal.

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
- When creating or modifying any SKILL.md file, system prompt, AI agent instruction, or PRD, use `/write-prompt` to review the result before committing. PRDs are prompts — future agents read and act on them.
- **ALWAYS add progress indicators** for any operation that might cause the user to wait. This includes downloading files, processing large datasets, network requests, and any computation that takes more than 1-2 seconds.
- **MANDATORY**: When writing user-facing documentation (README, guides, PRD milestones), invoke `/write-docs`. Do not skip this step. Excludes CLAUDE.md and rule files.

## Getting Help

- ALWAYS ask for clarification rather than making assumptions.
- Ask for help when encountering difficulties.

## Asking Multiple Questions

When you have multiple questions or decisions for the user, present them **one at a time**. Ask the first question, discuss it until resolved, then move to the next. Never dump a numbered list of 2+ questions in a single message. This applies to design decisions, clarifications, and any situation where the user's answer to one question might inform the next.

## Adopting New Technologies

- **MANDATORY**: Before writing code with any technology new to the project, invoke `/research <technology>`. Do not skip this step.
- Full process: @~/.claude/rules/adopting-new-technologies.md
- Kyverno (version numbering, GKE firewall, subjects matching): @~/.claude/rules/kyverno-gotchas.md
- yt-dlp (format selectors, ffmpeg-absent behavior, mweb stability, Node v20+): @~/.claude/rules/yt-dlp-gotchas.md
- Weaver (v0.22.1 auto-escaping defaults, definition schema format): @~/.claude/rules/weaver-gotchas.md
- Micro.blog API (dual auth tokens, editPage param order, feed-based cross-posting): @~/.claude/rules/microblog-api-gotchas.md
- OTel JS semantic conventions (stable vs incubating entry-points, DB/HTTP attribute renames, deprecated SEMATTRS_*): @~/.claude/rules/otel-semconv-gotchas.md
- mmdc/mermaid-cli (Puppeteer peer dep, Apple Silicon Chrome path, npx -p flag, PNG scaling): @~/.claude/rules/mmdc-gotchas.md
- Social platform video upload (Bluesky separate service token, Mastodon async 202 poll, LinkedIn 4-step init/upload/finalize/poll + ETag stripping): @~/.claude/rules/social-video-upload-gotchas.md

## Testing

- Tests MUST cover implemented functionality. No tests, not done. TDD: write failing test → implement → verify.
- Use real implementations when feasible; mock only at system boundaries. Separate deterministic from non-deterministic.
- **Bash scripts**: Use **bats-core** (`brew install bats-core`) for all bash test suites. Place tests in `tests/<script-name>.bats`. Do NOT use plain-bash ad hoc test scripts.
- Full testing rules: @~/.claude/rules/testing-rules.md
- Bats gotchas and patterns: @~/.claude/rules/bats-bash-testing.md
- Project-type strategies: @~/Documents/Repositories/claude-config/guides/testing-decision-guide.md

## Development Workflow

- Discover → write test → run test → implement → verify via test → fix if broken → commit.
- Never reference task management systems or items in code files or documentation.

## Git Workflow

- Feature branches only. PRs require CodeRabbit review approved by human before merge.
- After merging a PR, delete the feature branch locally and from the remote.
- Full workflow, CodeRabbit process, and triage rubric: @~/.claude/rules/git-workflow.md
- GitHub CLI fork gotchas (gh pr create targets upstream by default): @~/.claude/rules/gh-fork-gotchas.md

## GitHub Issues

When creating a GitHub issue: draft the body, then use the Skill tool to invoke `/write-prompt` passing the draft as input — ask it to organize the unstructured content into a clear, polished version without adding, removing, or changing meaning. Use the polished result when calling `gh issue create`.

Every GitHub issue body must end with a checklist item that updates the project's `PROGRESS.md` (style rules below). Without this, non-PRD work accumulates without a durable record.

## PROGRESS.md

When a repo has a `PROGRESS.md` at its root, write entries in this style:

- **Format**: `- (YYYY-MM-DD) [Prose description of what changed and why].` under the appropriate section heading (Added, Changed, Deprecated, Removed, Fixed, Security).
- **Convention**: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are for external readers of the repo, not internal workflow tracking.
- **Include**: what changed, why, and the reasoning behind the decision. User-facing identifiers (rule IDs, API names, paths like `docs/rules-reference.md`) are fine — but **briefly explain each on first use**, e.g., "CDQ-007 (PII attribute names, filesystem paths, nullable access)" rather than bare "CDQ-007".
- **Omit**: GitHub issue numbers, PRD numbers, milestone IDs ("M1", "B3"), test counts, internal file paths, commit SHAs. The closing commit handles ticket linkage.

Narrative issue references in prose ("Closed issue #493 as working as intended") are fine — that's context, not metadata. Avoid trailing `Closes #NNN.` lines; those belong in commit messages.

## ROADMAP.md

When a repo has a `docs/ROADMAP.md`, update it on PRD lifecycle events:

- **On PRD creation**: add an entry to the appropriate timeframe tier (Short-term / Medium-term / Long-term by PRD priority): `- [Brief description] ([PRD #NNN](issue-url)) — [1-line rationale or blocked-by]`. If a placeholder exists ("new PRD, to be created"), update in place — don't duplicate.
- **On PRD closure**: remove the entry. ROADMAP is forward-looking; completed work lives in `PROGRESS.md`.

Link to the GitHub issue, not the PRD file path — issues are stable across renames.

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

## macOS Image Processing

- `sips` silently skips files with spaces in their paths (exit 0, no output). Always use a temp-file workaround.
- macOS screenshots contain a narrow no-break space (U+202F) before "AM"/"PM" — never hardcode screenshot names; use glob iteration.
- Full rules and resize helpers: @~/.claude/rules/macos-image-processing.md

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
- Cross-PRD dependencies block clean merges. Design PRDs so every milestone is completable from main alone. Recovery when one is discovered mid-implementation: @~/.claude/rules/prd-dependency-management.md
- **Decision cascade**: When a row is added to a PRD's `## Decision Log`, evaluate each remaining milestone in that PRD: does the new decision change its prerequisites, approach, or success criteria? Update any milestone whose plan is affected. Then scan other open PRDs in `prds/` — if the decision is relevant to their scope, open those PRDs and update their affected milestones too.

## Eval Run Setup (spinybacked-orbweaver-eval)

When setting up a new spiny-orb evaluation target or running `spiny-orb instrument`:
- GitHub PAT setup, dry-run verification, and failure modes: @~/.claude/rules/eval-github-pat.md

## Conflict Resolution

- Project CLAUDE.md overrides global. When rules conflict, ask the user.

## Current Life Context

Whitney's current context (location, schedule, active projects, upcoming deadlines, recent git activity) is pre-loaded from a nightly-generated file:

@~/Documents/Journal/CURRENT-CONTEXT.md

Check the freshness timestamp in that file. If it is more than 48 hours old, treat it as background only and rely on Whitney's direct answers for current state.

## Hooks Reference

- Hook details: @~/.claude/rules/hooks-reference.md
