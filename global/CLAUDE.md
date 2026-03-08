# Global Development Standards

## Writing Style

When drafting emails or written communication:
- Use complete sentences. Never drop subjects.
- **Do**: "I am happy to answer any questions." / "I am just bubbling this back up."
- **Don't**: "Happy to answer any questions." / "Just bubbling this back up."
- Kind but direct, with full sentences.

## Writing Code

- Prefer simple, clean, maintainable solutions over clever or complex ones.
- Prioritize readability and maintainability.
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
- **ALWAYS add progress indicators** for any operation that might cause the user to wait. This includes downloading files, processing large datasets, network requests, and any computation that takes more than 1-2 seconds.

## Getting Help

- ALWAYS ask for clarification rather than making assumptions.
- Ask for help when encountering difficulties.

## Adopting New Technologies

- Before writing code with a framework, library, or tool that is new to the current project, **stop and research it first**. WebSearch official documentation using the current year. Use `/research <technology>` for thorough investigation.
- Check `~/.claude/rules/` for an existing rule file covering this technology. If one exists, verify its guidance is current rather than researching from scratch.
- When adopting a new framework, API, or tool pattern in a project, check official documentation for current best practices — prioritizing recency and anything that contradicts common assumptions.
- Document surprises (breaking changes, non-obvious gotchas, patterns that differ from conventions) in a path-scoped rule file and reference it from CLAUDE.md using `@path/to/file` import syntax.
- Focus on what the model's training data is most likely to get wrong, not what's already well-known.
- Do not document the obvious. Prioritize the surprising.
- Never trust training data for version numbers, API signatures, or configuration defaults when the technology is new to the project or has had recent major releases. Verify against official docs.
- Skip this process when the technology is already established in the project — existing imports, configuration, and tests indicate prior adoption.

## Testing

- Every project MUST have unit, integration, and end-to-end tests. Explicit human authorization required to skip any test tier.
- Repos may opt out of specific test tiers via dotfiles (`.skip-e2e`, `.skip-integration`).
- Tests MUST cover implemented functionality. No tests, not done.
- NEVER ignore test or system outputs; logs contain critical information.
- Test output MUST be pristine to pass.
- Capture and test logs, including expected errors.
- Do not manually run verification before git operations — hooks enforce this automatically (commit: build+typecheck+lint; push: standard security; PR: expanded security+tests; PR: acceptance gate with live API, advisory).
- **Acceptance gate tests** are for tests that make real API calls (LLM APIs, external services) and cost real money. Repos opt in by adding `"acceptance_test"` to `.claude/verify.json` commands — e.g., `"acceptance_test": "vals exec -f .vals.yaml -- npx vitest run test/**/acceptance-gate.test.ts"`. These run after standard PR verification passes, are advisory (never block PR creation), and require human review of results before proceeding. Use the `spinybacked-orbweaver/.claude/verify.json` command shape as a reference example.
- E2e tests that require network access, external services, or infrastructure (Kind clusters, API keys, databases) MUST have a CI workflow (GitHub Actions).
- Use real implementations when feasible; mock only at system boundaries.
- **Never mock locally installed tools or CLIs.** If a tool is installed on the development machine and runs fast (e.g., linters, compilers, schema validators), test against the real binary. Mocking local tools provides false confidence — the mock can't verify output format assumptions, flag compatibility, or behavioral changes across versions. Reserve mocks for remote APIs, expensive operations, and non-deterministic external services.
- Separate deterministic logic from non-deterministic operations.
- Full testing rules: @~/Documents/Repositories/claude-config/rules/testing-rules.md
- Project-type strategies: @~/Documents/Repositories/claude-config/guides/testing-decision-guide.md

## Test-Driven Development

1. Write a failing test.
2. Run the test to confirm failure.
3. Write minimal code to pass the test.
4. Run the test to confirm success.
5. Refactor code, maintaining test success.

## Development Workflow

- Discover → write test → run test → implement → verify via test → fix if broken → commit.
- Never reference task management systems or items in code files or documentation.

## Git Workflow

- Always work on feature branches. Never commit directly to main.
- Don't squash git commits.
- Create a new PR to merge to main anytime there are codebase additions.
- PRs require CodeRabbit review examined and approved by human before merge.
- The pre-push hook runs CodeRabbit CLI review (advisory). When findings appear, fix issues and push again before creating a PR.
- After creating a PR, start a background sleep timer (7 minutes) to poll for the CodeRabbit review. When the timer fires, check the PR for reviews and comments, then present all findings to the user.
- After pushing fixes for CodeRabbit feedback, start another 7-minute timer to check for the re-review before merging.
- NEVER include references to Claude, AI, Anthropic, or Co-Authored-By AI attribution in commit messages. Write commit messages as if authored by a human developer.
- Repos may override rules via dotfiles (`.skip-branching`, `.skip-coderabbit`).

## Infrastructure Safety

- When dealing with infrastructure directly (Kubernetes clusters, databases, cloud resources), always make a backup of any files you edit.
- NEVER render a system unbootable or overwrite any database or datastore without explicit permission.
- List planned infrastructure commands before executing so the user can review scope.
- Only apply Kubernetes resource manifests directly. Do not run host-level setup scripts unless explicitly asked.

## Cloud Resource Lifecycle

When provisioning cloud infrastructure (GKE clusters, cloud databases, VM instances, etc.):

- **Teardown plan required before creation.** Before provisioning cloud resources, confirm the active PRD includes a teardown step. Add one if missing. Every `setup-*.sh` must have a corresponding `teardown-*.sh`.
- **PRD-level exit criterion.** A PRD cannot close (`/prd-done`) until provisioned resources are torn down or handed off to a named owner.
- **Remind at checkpoints.** When completing tasks with active cloud resources, remind the user what's running and the teardown plan.
- **Cross-session safety.** If a conversation ends with cloud resources running, write a prominent warning in MEMORY.md (resource, project, teardown command).

## ABOUTME File Headers

Every code file (`.py`, `.sh`, `.ts`, `.tsx`, `.js`, `.jsx`) must start with a 1-2 line ABOUTME header using the file's comment syntax (`# ABOUTME: ...` or `// ABOUTME: ...`). Place after shebang lines when present. Exempt: `__init__.py`, config files (JSON/YAML/TOML), markdown, HTML/CSS, generated files, `node_modules`, `.d.ts`, `.min.js`. A PreToolUse hook enforces this. Examples: @~/.claude/rules/aboutme-headers.md

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

Feature work is tracked in PRDs (`prds/` directory). When a project has PRDs, use the PRD skills:
- `/prd-create` — create new PRDs with structured requirements, milestones, and decision logs.
- `/prd-next` — identify the next task from an active PRD.
- `/prd-update-progress` — log completed work with evidence. Clear conversation context afterward before starting the next task.
- `/prd-update-decisions` — capture design decisions and scope changes in the PRD decision log.
- `/prd-done` — finalize a completed PRD (PR, merge, close issue).

Do not invent tasks outside the PRD structure. When a PRD exists, follow it.
- **Do NOT commit manually during PRD work.** `/prd-update-progress` handles commits, PRD updates, and journaling together. Committing manually creates duplicate work and skips the skill's workflow.

## Rules Enforced by Hooks

<!-- PreToolUse hooks (fire before tool execution): -->
<!-- google-mcp-safety-hook.py (PreToolUse: mcp__.*calendar|youtube|drive|sheet|spreadsheet.*) — defense-in-depth safety for Google API MCP servers -->
<!-- check-commit-message.sh (PreToolUse: Bash) — blocks git commits with AI/Claude/Anthropic/Co-Authored-By references in commit messages -->
<!-- check-branch-protection.sh (PreToolUse: Bash) — blocks commits to main/master; opt out with .skip-branching; docs-only exemption per @rules/branch-protection.md -->
<!-- check-coderabbit-required.sh (PreToolUse: Bash) — blocks PR merge without CodeRabbit review; opt out with .skip-coderabbit -->
<!-- pre-commit-hook.sh (PreToolUse: Bash) — gates git commit on quick+lint verification (build, typecheck, lint) -->
<!-- pre-push-hook.sh (PreToolUse: Bash) — gates git push on security verification; escalates to expanded security + tests when an open PR is detected for the branch (uses gh pr list); falls back to standard security when gh is unavailable; runs advisory CodeRabbit CLI review after blocking checks pass (findings in additionalContext; skip with .skip-coderabbit) -->
<!-- pre-pr-hook.sh (PreToolUse: Bash) — gates PR creation on security+tests verification (expanded security, tests; build/typecheck/lint already passed at commit); also runs advisory acceptance gate tests when .claude/verify.json has an "acceptance_test" command; results require human approval before PR creation continues -->
<!-- check-test-tiers.sh (PreToolUse: Bash) — warns (not blocks) on git push/PR create when unit/integration/e2e test tiers are missing; opt out with .skip-integration, .skip-e2e -->
<!-- check-progress-md.sh (PreToolUse: Bash) — blocks git commit when PRD checkboxes are marked done but PROGRESS.md is not staged; only fires when PROGRESS.md exists in repo -->
<!-- check-aboutme.sh (PreToolUse: Write|Edit) — blocks code files missing ABOUTME headers; fix-and-retry adds headers organically; skips config, markdown, generated files -->

<!-- PostToolUse hooks (fire after tool execution): -->
<!-- post-write-codeblock-check.sh (PostToolUse: Write|Edit) — checks markdown files for bare code blocks missing language specifiers -->
