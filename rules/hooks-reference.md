---
paths: ["**/.claude/**", "**/hooks/**", "**/*.sh"]
description: Reference for all PreToolUse and PostToolUse hooks and what they enforce
---

# Hooks Reference

## Native git hooks (installed via `scripts/install-git-hooks.sh`)

These run inside the git process itself, providing stronger enforcement than Claude Code hooks because they intercept git operations directly. However, users can bypass them with `--no-verify` (e.g., `git commit --no-verify`, `git push --no-verify`), so they provide strong local enforcement but are not absolute.

Install with `bash scripts/install-git-hooks.sh [repo-path]`. The installer is idempotent, backs up existing hooks, and never touches `post-commit` (reserved for commit-story). Source of truth: `hooks/git/`.

**pre-commit dispatcher** (`hooks/git/pre-commit`) runs:
- **branch-protection.sh** — blocks commits to main/master; opt out with `.skip-branching`; docs-only exemption per @rules/branch-protection.md
- **progress-md.sh** — blocks commits when PRD checkboxes are marked done but PROGRESS.md is not staged
- **pre-commit-verify.sh** — gates commit on build/typecheck/lint verification; docs-only early exit

**commit-msg dispatcher** (`hooks/git/commit-msg`) runs:
- **commit-message.sh** — blocks commits with AI/Claude/Anthropic/Co-Authored-By references

**pre-push dispatcher** (`hooks/git/pre-push`) runs:
- **test-tiers.sh** — warns (does not block) when unit/integration/e2e test tiers are missing; opt out with `.skip-integration`, `.skip-e2e`
- **pre-push-verify.sh** — gates push on security verification (docs-only early exit)
  - Escalates to expanded security + tests when an open PR exists
  - Runs advisory CodeRabbit CLI review after blocking checks pass

## PreToolUse hooks (fire before tool execution)

- **google-mcp-safety-hook.py** (PreToolUse: `mcp__.*(youtube).*`) — blocks destructive YouTube MCP operations (delete, upload)
- **gogcli-safety-hook.py** (PreToolUse: Bash) — blocks destructive or people-affecting gog CLI commands: data deletion, outreach, calendar with attendees, sharing, non-allowlisted sheet writes, account safety changes
- **check-coderabbit-required.sh** (PreToolUse: Bash) — blocks PR merge without CodeRabbit review; opt out with `.skip-coderabbit`
- **pre-pr-hook.sh** (PreToolUse: Bash) — gates PR creation on security+tests verification (expanded security, tests; build/typecheck/lint already passed at commit); also runs advisory acceptance gate tests when `.claude/verify.json` has an `"acceptance_test"` command; results require human approval before PR creation continues
- **check-aboutme.sh** (PreToolUse: Write|Edit) — blocks code files missing ABOUTME headers; fix-and-retry adds headers organically; skips config, markdown, generated files

## PostToolUse hooks (fire after tool execution)

- **post-write-codeblock-check.sh** (PostToolUse: Write|Edit) — checks markdown files for bare code blocks missing language specifiers
- **suggest-write-prompt.sh** (PostToolUse: Write|Edit, Bash) — advisory reminder to run `/write-prompt` when SKILL.md or CLAUDE.md files are edited, or when `gh issue create` succeeds; explains that any AI-consumed document is a prompt
- **cascade-decision-check.sh** (PostToolUse: Write|Edit) — advisory reminder to cascade-evaluate downstream milestones when a PRD file in `prds/` is edited; prompts Claude to check for new Decision Log rows and update affected milestones in the current and other open PRDs

## Supplemental Code Review

Immediately after creating a PR, run `/code-review` in the session using the Skill tool — **except** for docs-only PRs (markdown, SKILL.md, CLAUDE.md, rules files) or small/obvious code changes, where CodeRabbit coverage is sufficient.

**Plugin**: `code-review` — available in all sessions via `~/.claude/skills/code-review` symlink (no per-repo install needed).

**When it runs**: Every non-trivial PR, immediately after `gh pr create` — not pre-push. The plugin requires an open PR and cannot run before one exists. The pre-push CodeRabbit CLI step is unchanged.

**What to expect**: Five parallel Sonnet agents independently review the diff, then parallel Haiku agents score each finding (0–100 confidence). Findings below 50 are filtered out. Findings are grouped into two tiers — High confidence (≥ 80) and Medium confidence (50–79) — and posted as a two-tier markdown table in the PR comment. Each finding includes a score, a Fix or Skip disposition, and a GitHub permalink with the full commit SHA.

**Rate-limit behavior**: If CodeRabbit is rate-limited and never posts a review, `/code-review` provides full coverage. Do not block the merge indefinitely waiting for CodeRabbit — once `/code-review` findings are addressed and human has reviewed, merging is unblocked.
