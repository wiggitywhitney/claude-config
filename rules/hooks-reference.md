---
paths: ["**/.claude/**", "**/hooks/**", "**/*.sh"]
description: Reference for all PreToolUse and PostToolUse hooks and what they enforce
---

# Hooks Reference

## PreToolUse hooks (fire before tool execution)

- **google-mcp-safety-hook.py** (PreToolUse: `mcp__.*calendar|youtube|drive|sheet|spreadsheet.*`) — defense-in-depth safety for Google API MCP servers
- **check-commit-message.sh** (PreToolUse: Bash) — blocks git commits with AI/Claude/Anthropic/Co-Authored-By references in commit messages
- **check-branch-protection.sh** (PreToolUse: Bash) — blocks commits to main/master; opt out with `.skip-branching`; docs-only exemption per @rules/branch-protection.md
- **check-coderabbit-required.sh** (PreToolUse: Bash) — blocks PR merge without CodeRabbit review; opt out with `.skip-coderabbit`
- **pre-commit-hook.sh** (PreToolUse: Bash) — gates git commit on quick+lint verification (build, typecheck, lint)
- **pre-push-hook.sh** (PreToolUse: Bash) — gates git push on security verification; escalates to expanded security + tests when an open PR is detected for the branch (uses `gh pr list`); falls back to standard security when gh is unavailable; runs advisory CodeRabbit CLI review after blocking checks pass (findings in additionalContext; skip with `.skip-coderabbit`)
- **pre-pr-hook.sh** (PreToolUse: Bash) — gates PR creation on security+tests verification (expanded security, tests; build/typecheck/lint already passed at commit); also runs advisory acceptance gate tests when `.claude/verify.json` has an `"acceptance_test"` command; results require human approval before PR creation continues
- **check-test-tiers.sh** (PreToolUse: Bash) — warns (not blocks) on git push/PR create when unit/integration/e2e test tiers are missing; opt out with `.skip-integration`, `.skip-e2e`
- **check-progress-md.sh** (PreToolUse: Bash) — blocks git commit when PRD checkboxes are marked done but PROGRESS.md is not staged; only fires when PROGRESS.md exists in repo
- **check-aboutme.sh** (PreToolUse: Write|Edit) — blocks code files missing ABOUTME headers; fix-and-retry adds headers organically; skips config, markdown, generated files

## PostToolUse hooks (fire after tool execution)

- **post-write-codeblock-check.sh** (PostToolUse: Write|Edit) — checks markdown files for bare code blocks missing language specifiers
