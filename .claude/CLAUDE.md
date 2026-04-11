# Claude Config

Shared Claude Code testing infrastructure, safety config, and developer tooling across all of Whitney's repos.

## YOLO Workflow Mode

Proceed without trivial confirmations. Never ask "Shall I continue?", "Do you want to proceed?", or "Ready to start?" — just do the work. The user will interrupt if needed.

**Do ask** when something is ambiguous, when a decision has major implications, or when you need to deviate from what the PRD explicitly defines. This follows the same principle as Getting Help: ask for clarification rather than making assumptions.

**CodeRabbit reviews are REQUIRED before merging any PR.** Create the PR, wait for CodeRabbit to complete its review, then process ALL CodeRabbit feedback with the user before merging. This is non-negotiable.

## CodeRabbit Reviews (MANDATORY)

Every PR must go through CodeRabbit review before merge. This is a hard requirement, not optional.

### Pre-Push CLI Review (Advisory)

The pre-push hook runs CodeRabbit CLI review automatically on every `git push`. This is **advisory** — it never blocks the push, but findings appear in hook output. When the CLI review surfaces issues:
1. Read the findings in the hook's `additionalContext`
2. Fix the issues before creating a PR
3. Push again (the CLI review runs again to confirm the fix)

This catches problems in ~30s locally, reducing review round-trips after PR creation.

### PR Review (Blocking)

**Timing:** After creating a PR, start a 7-minute timer before checking for the review. Do NOT poll every 30 seconds.

**Process:**
1. Create the PR and push to remote
2. Wait 7 minutes, then fetch all CodeRabbit findings using three `gh api` calls — CodeRabbit posts to all three channels and missing any one means missing findings:
   ```bash
   gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews --jq '[.[] | {user: .user.login, state, body}]'
   gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '[.[] | {user: .user.login, path, line, body}]'
   gh api repos/OWNER/REPO/issues/PR_NUMBER/comments --jq '[.[] | {user: .user.login, body}]'
   ```
3. If no review yet, wait another 2-3 minutes before checking again
4. For each CodeRabbit comment: explain the issue, give a recommendation, then **follow your own recommendation** (YOLO mode)
5. Only stop for user input if something is truly ambiguous or has major architectural implications
6. After pushing fixes, wait 7 minutes, then re-run the three `gh api` calls from step 2 to check for new findings
7. If new comments appear, address them and repeat step 6
8. After re-review is clear and human has approved, merge the PR

### Triage: When to Defer vs. Fix Now

**Default: fix it now.** See [Deferring Known Issues](#deferring-known-issues) below for the narrow set of legitimate reasons to defer and the required process when deferring.

## Deferring Known Issues

**Default: fix it now.** Future instances have no memory of deferred intent — silent deferrals disappear.

Deferral is only appropriate when the fix is:
- In a **different repo** (out of scope for the current branch)
- **PRD-scoped** — needs its own milestone and planning
- Likely to cause **merge conflicts** with current branch work
- Blocked on **significant investigation** that can't be done in this session

When any of these apply, **stop and surface it explicitly** before continuing:

> "I want to defer [X] because [reason]. What would you like to do?
> A. Fix it now
> B. Create a GitHub issue (tracked, you'll see it)
> C. Let it go — knowing it may not come back up"

Wait for the user's answer. Never choose a default silently.

## Git Conventions

- Don't squash git commits
- Make a new branch for each new feature
- Never reference task management systems in code files or documentation
- Create a new PR to merge to main anytime there are codebase additions
- Make sure CodeRabbit review has been examined and is approved by human before merging PR

## Hook & Rule Authoring Conventions

**Hook severity:** Use exit 2 (blocking deny) only for zero-tolerance rules that must never be violated (e.g., commit message policy, verification failures). Use exit 0 with advisory `additionalContext` for style and quality guidance where violations are informational, not blocking.

**Rule file frontmatter:** All rule files in `rules/` must include `paths:` frontmatter so Claude Code only loads them in relevant file contexts. Example: `paths: ["**/*.ts", "**/*.tsx"]` for TypeScript rules. This reduces token cost by avoiding irrelevant rules in every conversation.

**Placeholder rule files:** When creating a new rule file for a domain that doesn't have established patterns yet, create a stub with correct `paths:` frontmatter and a single line: "Add rules as patterns emerge from real usage." Do not fill rule files with speculative rules — let real usage drive content.

## Native Git Hook System

Git enforcement (branch protection, commit message, build verification, push security) runs as native git hooks, not Claude Code hooks. Source of truth: `hooks/git/`. When setting up a new repo or confirming hooks are in place, install with:

```bash
bash scripts/install-git-hooks.sh [repo-path]
```

Idempotent — safe to re-run. Never touches `post-commit` (reserved for commit-story). Full reference: @~/.claude/rules/hooks-reference.md

## Testing

- All bash hook and script files MUST have bats test coverage. Place tests in `tests/<script-name>.bats`.
- Bats gotchas and patterns: @~/.claude/rules/bats-bash-testing.md

## Secrets Management (vals)

This project uses [vals](https://github.com/helmfile/vals) for secrets management, pulling from GCP Secrets Manager.

**Exporting secrets to shell (for MCP servers):**
```bash
eval $(vals eval -f .vals.yaml --output shell)
```

Secrets are configured in `.vals.yaml` (gitignored).
