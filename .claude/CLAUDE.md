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
2. Wait 7 minutes, then check for CodeRabbit review using `mcp__coderabbitai__get_coderabbit_reviews`
3. If review not ready, wait another 2-3 minutes before checking again
4. For each CodeRabbit comment: explain the issue, give a recommendation, then **follow your own recommendation** (YOLO mode)
5. After addressing each issue, use `mcp__coderabbitai__resolve_comment` to mark resolved
6. Only stop for user input if something is truly ambiguous or has major architectural implications
7. After ALL comments are addressed, merge the PR

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

## Secrets Management (vals)

This project uses [vals](https://github.com/helmfile/vals) for secrets management, pulling from GCP Secrets Manager.

**Exporting secrets to shell (for MCP servers):**
```bash
eval $(vals eval -f .vals.yaml --output shell)
```

Secrets are configured in `.vals.yaml` (gitignored).
