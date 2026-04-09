---
paths: ["**/.claude/**", "**/hooks/**", "**/*.sh"]
description: Reference for all PreToolUse and PostToolUse hooks and what they enforce
---

# Hooks Reference

## Native git hooks (installed via `scripts/install-git-hooks.sh`)

These run inside the git process itself — no alternative code path exists. Install with `bash scripts/install-git-hooks.sh [repo-path]` (idempotent, never touches post-commit). Source of truth: `hooks/git/`.

**pre-commit dispatcher** (`hooks/git/pre-commit`) runs:
- **branch-protection.sh** — blocks commits to main/master; opt out with `.skip-branching`; docs-only exemption per @rules/branch-protection.md
- **progress-md.sh** — blocks commits when PRD checkboxes are marked done but PROGRESS.md is not staged
- **pre-commit-verify.sh** — gates commit on build/typecheck/lint verification; docs-only early exit

**commit-msg dispatcher** (`hooks/git/commit-msg`) runs:
- **commit-message.sh** — blocks commits with AI/Claude/Anthropic/Co-Authored-By references

**pre-push dispatcher** (`hooks/git/pre-push`) runs:
- **test-tiers.sh** — warns (does not block) when unit/integration/e2e test tiers are missing; opt out with `.skip-integration`, `.skip-e2e`
- **pre-push-verify.sh** — gates push on security verification; escalates to expanded security + tests when an open PR exists; runs advisory CodeRabbit CLI review after blocking checks pass; docs-only early exit

## PreToolUse hooks (fire before tool execution)

- **google-mcp-safety-hook.py** (PreToolUse: `mcp__.*(youtube).*`) — blocks destructive YouTube MCP operations (delete, upload)
- **gogcli-safety-hook.py** (PreToolUse: Bash) — blocks destructive or people-affecting gog CLI commands: data deletion, outreach, calendar with attendees, sharing, non-allowlisted sheet writes, account safety changes
- **check-coderabbit-required.sh** (PreToolUse: Bash) — blocks PR merge without CodeRabbit review; opt out with `.skip-coderabbit`
- **pre-pr-hook.sh** (PreToolUse: Bash) — gates PR creation on security+tests verification (expanded security, tests; build/typecheck/lint already passed at commit); also runs advisory acceptance gate tests when `.claude/verify.json` has an `"acceptance_test"` command; results require human approval before PR creation continues
- **check-aboutme.sh** (PreToolUse: Write|Edit) — blocks code files missing ABOUTME headers; fix-and-retry adds headers organically; skips config, markdown, generated files

## PostToolUse hooks (fire after tool execution)

- **post-write-codeblock-check.sh** (PostToolUse: Write|Edit) — checks markdown files for bare code blocks missing language specifiers
- **suggest-write-prompt.sh** (PostToolUse: Write|Edit, Bash) — advisory reminder to run `/write-prompt` when SKILL.md or CLAUDE.md files are edited, or when `gh issue create` succeeds; explains that any AI-consumed document is a prompt
