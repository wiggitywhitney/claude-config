---
paths: ["**/.claude/**", "**/hooks/**", "**/*.sh"]
description: Reference for all PreToolUse and PostToolUse hooks and what they enforce
---

# Hooks Reference

## How a hook reaches Claude, and how to get it wrong

Two hooks in this repo were written on false assumptions about this and did nothing for months. Confirmed against the official hooks documentation, 2026-08-05.

- **Stderr from a hook that exits 0 goes to the debug log only. Claude never sees it, and neither does the transcript.** A hook that prints its message to stderr and exits 0 is a no-op with no symptom. To surface something to Claude from a `PostToolUse` hook, exit 2 instead.
- **Stdout on exit 0 is parsed for JSON output fields and otherwise written to the debug log**, except for `SessionStart`, `UserPromptSubmit`, and `UserPromptExpansion`, where plain stdout is added as context directly. Relying on that exception works but is a side door; prefer the documented envelope.
- **The documented way to add context is nested, not top-level.** A bare `{"additionalContext": "..."}` is not a recognised field:

  ```json
  {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
  ```

- **`PostCompact` supports no context injection at all** — it is a side-effects-only event, alongside `SessionEnd`, `Notification`, and `CwdChanged`. There is no way to add context after a compaction, so re-anchoring must be invoked deliberately. `PreCompact`, by contrast, can block.
- **Write injected text as factual statements, not as imperative system instructions.** Out-of-band command phrasing can trigger prompt-injection defenses, which surfaces the text to the user instead of treating it as context.

**Before trusting any new hook, exercise it** — pipe a realistic payload to it and read what comes back. Every hook defect found in the 2026-08-05 audit was invisible from reading the script and obvious from running it. When building a test payload, construct the JSON with `python3 -c 'import json...'` rather than `printf`, which expands `\n` into real newlines and produces invalid JSON that hooks silently skip.

## Native git hooks (installed via `scripts/install-git-hooks.sh`)

These run inside the git process itself, providing stronger enforcement than Claude Code hooks because they intercept git operations directly. However, users can bypass them with `--no-verify` (e.g., `git commit --no-verify`, `git push --no-verify`), so they provide strong local enforcement but are not absolute.

Install with `bash scripts/install-git-hooks.sh [repo-path]`. The installer is idempotent, backs up existing hooks, and never touches `post-commit` (reserved for commit-story). Source of truth: `hooks/git/`.

**pre-commit dispatcher** (`hooks/git/pre-commit`) runs:
- **branch-protection.sh** — blocks commits to main/master; opt out with `.skip-branching`; docs-only exemption per @rules/branch-protection.md
- **progress-md.sh** — blocks commits when PRD checkboxes are marked done but PROGRESS.md is not staged
- **pre-commit-verify.sh** — gates commit on build/typecheck/lint verification; docs-only early exit

**commit-msg dispatcher** (`hooks/git/commit-msg`) runs:
- **commit-message.sh** — blocks commits with AI/Claude/Anthropic/Co-Authored-By references. **It matches the bare word anywhere in the message, including when the tool is the legitimate subject of the change.** In repos about Claude Code configuration this fires on ordinary descriptive prose ("how people run Claude unattended") with no attribution involved. Rephrase around the name — "long agent sessions", "the CLI", "the shipped binary" — rather than fighting the hook; the rule it enforces is about attribution, and the rewrite costs nothing.
  - **It matches the substring, not the intent, so the product name trips it too.** A commit message describing work on the tool itself — "adds a Claude Code capability spike", "documents Claude Code hook events" — is rejected with `Commit message contains AI/Claude reference: "Claude Code"`, even though it is naming a product rather than attributing authorship. This bites hardest in this repo, where the subject matter *is* the tool. Rephrase to "the platform", "the CLI", or the specific feature ("hook events", "skill precedence"). Confirmed 2026-08-03.

**pre-push dispatcher** (`hooks/git/pre-push`) runs:
- **test-tiers.sh** — warns (does not block) when unit/integration/e2e test tiers are missing; opt out with `.skip-integration`, `.skip-e2e`
- **progress-md-pr.sh** — blocks push when branch has no PROGRESS.md changes vs the base branch; prompts interactively with an AI-drafted entry (accept/edit/skip); non-interactive environments get an advisory warning and exit 0; only fires in repos that have PROGRESS.md
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
- **suggest-write-prompt.sh** (PostToolUse: Write|Edit, Bash) — advisory reminder to run `/write-prompt` when SKILL.md, CLAUDE.md, PRD files (`prds/`), rules files (`rules/`), or files named `*-prompt.md`/`*-spec.md` are edited, or when `gh issue create` succeeds; explains that any AI-consumed document is a prompt
- **suggest-planning-handoff.sh** (PostToolUse: Write, Bash) — advisory prompt after `gh issue create` succeeds or a new PRD file is written (Write tool only, not Edit); asks three questions: were decisions captured, were open questions captured, could a cold AI act on this document alone; addresses context loss when planning conversations produce issues/PRDs that miss key discussion context
- **suggest-branch-cleanup.sh** (PostToolUse: Bash) — advisory reminder to delete the feature branch locally and from the remote, and confirm the linked GitHub issue is closed, after `gh pr merge` commands
- **cascade-decision-check.sh** (PostToolUse: Write|Edit) — advisory reminder to cascade-evaluate downstream milestones when a PRD file in `prds/` is edited; prompts Claude to check for new Decision Log rows and update affected milestones in the current and other open PRDs

## Supplemental Code Review

Immediately after creating a PR, run `/code-review` in the session using the Skill tool — **except** for: docs-only PRs (markdown, SKILL.md, CLAUDE.md, rules files); standalone issue fixes where ≤2 non-test source files changed, the changes are self-contained (each file independently modified with no complex cross-file interactions), new tests directly cover the changed logic, and CodeRabbit CLI found no blocking findings; or other small/obvious code changes where CodeRabbit coverage is sufficient.

**IMPORTANT**: Never run `/code-review` in the background or in parallel with other skills. It must run as a foreground, blocking Skill tool call so its findings are returned and visible in the conversation. Parallel invocation causes results to be lost.

**Plugin**: `code-review` — available in all sessions via `~/.claude/skills/code-review` symlink (no per-repo install needed).

**When it runs**: Every non-trivial PR, immediately after `gh pr create` — not pre-push. The plugin requires an open PR and cannot run before one exists. The pre-push CodeRabbit CLI step is unchanged. **Never run `/code-review` on GitHub issues** — it is too expensive and only applies to PRs.

**What to expect**: Five parallel Sonnet agents independently review the diff, then parallel Haiku agents score each finding (0–100 confidence). Findings below 50 are filtered out. Findings are grouped into two tiers — High confidence (≥ 80) and Medium confidence (50–79) — and posted as a two-tier markdown table in the PR comment. Each finding includes a score, a Fix or Skip disposition, and a GitHub permalink with the full commit SHA.

**Rate-limit behavior**: If CodeRabbit is rate-limited and never posts a review, `/code-review` provides full coverage. Do not block the merge indefinitely waiting for CodeRabbit — once `/code-review` findings are addressed and human has reviewed, merging is unblocked.
