---
paths: ["**/*"]
description: Git workflow rules including branching, CodeRabbit reviews, and commit conventions
---

# Git Workflow

- Always work on feature branches. Never commit directly to main.
- Don't squash git commits.
- Create a new PR to merge to main anytime there are codebase additions.
- PRs require CodeRabbit review examined and approved by human before merge.
- The pre-push hook runs CodeRabbit CLI review (advisory). When findings appear, fix issues and push again before creating a PR.
- **CodeRabbit CLI manual invocation:** When you need to run a CodeRabbit CLI review outside the pre-push hook (e.g., reviewing a PRD or doc-only branch), use:
  ```bash
  coderabbit review --plain --type committed --base origin/main --no-color 2>&1
  ```
  Run in background — reviews take 1-7+ minutes. If CodeRabbit returns a rate-limit error with a wait time (e.g., "please try after 4 minutes and 29 seconds"), set a background sleep timer for that duration and retry automatically. Key gotchas:
  - Always use `--plain` (interactive mode requires a TTY, which Claude Code's Bash tool lacks).
  - Always use `--type committed` for branch-vs-base comparison. The default `--type all` looks for uncommitted changes and will report "No files found" on a clean working tree.
  - Always use `origin/main` (not `main`) as the base ref.
  - The branch must have commits that the base doesn't — if you cherry-pick from main, the CLI sees no diff.
- After creating a PR, start a background sleep timer (7 minutes) to poll for the CodeRabbit review. When the timer fires, fetch all CodeRabbit findings using three `gh api` calls — CodeRabbit posts to all three channels and missing any one means missing findings:
  ```bash
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews --jq '[.[] | {user: .user.login, state, body}]'
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '[.[] | {user: .user.login, path, line, body}]'
  gh api repos/OWNER/REPO/issues/PR_NUMBER/comments --jq '[.[] | {user: .user.login, body}]'
  ```
  - `/pulls/{n}/reviews` — full review bodies including "outside diff range" findings (most content lives here)
  - `/pulls/{n}/comments` — inline comments attached to specific diff lines
  - `/issues/{n}/comments` — conversation-level notices (e.g., "reviews paused")
  Present all findings to the user.
- After pushing fixes for CodeRabbit feedback, start another 7-minute timer to check for the re-review before merging.
- **CodeRabbit triage rubric** for non-critical findings:
  - **Fix** if the finding is real and the only reason not to fix it is effort — effort alone is not a reason to skip.
  - **Defer** if the finding is real and worth addressing, but complexity or scope makes it better suited to a dedicated issue than an inline fix. Create a GitHub issue; run `/write-prompt` on the issue body before creating it.
  - **Skip** if the suggestion misunderstands the code, or if fix complexity genuinely outweighs the benefit and the finding is not worth tracking at all.
- **After merging a PR**, delete the local and remote feature branch immediately. Don't leave stale branches accumulating.
- NEVER include references to Claude, AI, Anthropic, or Co-Authored-By AI attribution in commit messages. Write commit messages as if authored by a human developer.
- Repos may override rules via dotfiles (`.skip-branching`, `.skip-coderabbit`).
- **Acceptance gate labeling:** When creating a PR for a project with acceptance gate tests (`.github/workflows/acceptance-gate.yml` exists or `.claude/verify.json` contains `"acceptance_test"`), add `--label run-acceptance` to the `gh pr create` command. This triggers the acceptance gate CI workflow. The `/prd-done` skill handles this automatically for PRD-driven PRs; apply the same convention for manual PRs.
