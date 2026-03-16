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
- After creating a PR, start a background sleep timer (7 minutes) to poll for the CodeRabbit review. When the timer fires, check the PR for reviews and comments, then present all findings to the user.
- After pushing fixes for CodeRabbit feedback, start another 7-minute timer to check for the re-review before merging.
- **CodeRabbit triage rubric** for non-critical findings:
  - **Skip** if the suggestion is genuinely not helpful or misunderstands the code.
  - **Skip** if the complexity or maintenance cost of the fix outweighs its benefit.
  - **Fix** if the only reason to skip is that it takes time to write — effort alone is not a reason to skip.
- NEVER include references to Claude, AI, Anthropic, or Co-Authored-By AI attribution in commit messages. Write commit messages as if authored by a human developer.
- Repos may override rules via dotfiles (`.skip-branching`, `.skip-coderabbit`).
- **Acceptance gate labeling:** When creating a PR for a project with acceptance gate tests (`.github/workflows/acceptance-gate.yml` exists or `.claude/verify.json` contains `"acceptance_test"`), add `--label run-acceptance` to the `gh pr create` command. This triggers the acceptance gate CI workflow. The `/prd-done` skill handles this automatically for PRD-driven PRs; apply the same convention for manual PRs.
