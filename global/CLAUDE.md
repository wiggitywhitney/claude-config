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
- Do not manually run verification before git operations — hooks enforce this automatically (commit: build+typecheck+lint; push: standard security; PR: expanded security+tests).
- Use real implementations when feasible; mock only at system boundaries.
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
- After creating a PR, start a background sleep timer (7 minutes) to poll for the CodeRabbit review. When the timer fires, check the PR for reviews and comments, then present all findings to the user.
- After pushing fixes for CodeRabbit feedback, start another 7-minute timer to check for the re-review before merging.
- NEVER include references to Claude, AI, Anthropic, or Co-Authored-By AI attribution in commit messages. Write commit messages as if authored by a human developer.
- Repos may override rules via dotfiles (`.skip-branching`, `.skip-coderabbit`).

## Infrastructure Safety

- When dealing with infrastructure directly (Kubernetes clusters, databases, cloud resources), always make a backup of any files you edit.
- NEVER render a system unbootable or overwrite any database or datastore without explicit permission.
- List planned infrastructure commands before executing so the user can review scope.
- Only apply Kubernetes resource manifests directly. Do not run host-level setup scripts unless explicitly asked.

## Language & Configuration Defaults

- Primary languages: TypeScript, Markdown, YAML, Shell, JSON.
- When generating code, prefer TypeScript unless context indicates otherwise.
- For configuration, prefer YAML over JSON where the tool supports it.

## Vals Secrets Management

Whitney uses [vals](https://github.com/helmfile/vals) to inject secrets from Google Secret Manager (and other backends). Secrets are never exported to `.zshrc` or committed to repos. Per-repo config lives in `.vals.yaml`.

```bash
# Run a command with secrets injected
vals exec -f .vals.yaml -- command arg1 arg2

# Export secrets into the current shell
eval $(vals eval -f .vals.yaml --output shell)
```

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
<!-- check-branch-protection.sh (PreToolUse: Bash) — blocks commits to main/master; opt out with .skip-branching -->
<!-- check-coderabbit-required.sh (PreToolUse: Bash) — blocks PR merge without CodeRabbit review; opt out with .skip-coderabbit -->
<!-- pre-commit-hook.sh (PreToolUse: Bash) — gates git commit on quick+lint verification (build, typecheck, lint) -->
<!-- pre-push-hook.sh (PreToolUse: Bash) — gates git push on security verification; escalates to expanded security + tests when an open PR is detected for the branch (uses gh pr list); falls back to standard security when gh is unavailable -->
<!-- pre-pr-hook.sh (PreToolUse: Bash) — gates PR creation on security+tests verification (expanded security, tests; build/typecheck/lint already passed at commit) -->
<!-- check-test-tiers.sh (PreToolUse: Bash) — warns (not blocks) on git push/PR create when unit/integration/e2e test tiers are missing; opt out with .skip-integration, .skip-e2e -->

<!-- PostToolUse hooks (fire after tool execution): -->
<!-- post-write-codeblock-check.sh (PostToolUse: Write|Edit) — checks markdown files for bare code blocks missing language specifiers -->
