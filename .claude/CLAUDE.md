# Claude Config

Shared Claude Code testing infrastructure, safety config, and developer tooling across all of Whitney's repos.

## YOLO Workflow Mode

Proceed without trivial confirmations. Never ask "Shall I continue?", "Do you want to proceed?", or "Ready to start?" — just do the work. The user will interrupt if needed.

**Do ask** when something is ambiguous, when a decision has major implications, or when you need to deviate from what the PRD explicitly defines. This follows the same principle as Getting Help: ask for clarification rather than making assumptions.

**CodeRabbit reviews are REQUIRED before merging any PR.** Create the PR, wait for CodeRabbit to complete its review, then process ALL CodeRabbit feedback with the user before merging. This is non-negotiable.

## CodeRabbit Reviews (MANDATORY)

Every PR must go through CodeRabbit review before merge. This is a hard requirement, not optional.

**Timing:** CodeRabbit reviews take ~5 minutes to complete. After creating a PR, wait at least 5 minutes before checking for the review. Do NOT poll every 30 seconds.

**Process:**
1. Create the PR and push to remote
2. Wait 5 minutes, then check for CodeRabbit review using `mcp__coderabbitai__get_coderabbit_reviews`
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

## Secrets Management (vals)

This project uses [vals](https://github.com/helmfile/vals) for secrets management, pulling from GCP Secrets Manager.

**Exporting secrets to shell (for MCP servers):**
```bash
eval $(vals eval -f .vals.yaml --output shell)
```

Secrets are configured in `.vals.yaml` (gitignored).
