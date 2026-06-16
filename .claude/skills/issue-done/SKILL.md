---
name: issue-done
description: Close out issue work - ensure PR exists, run the full CodeRabbit + /code-review gate, merge, close all issues in the working set, clean branches, and update PROGRESS.md
category: project-management
---

# Close Issue Work

**Note**: If any `gh` command fails with "command not found", inform the user that GitHub CLI is required and provide the installation link: https://cli.github.com/

## Workflow Steps

### 1. Identify Closing Set
- [ ] **Read current branch**: Run `git branch --show-current`
- [ ] **Extract issue numbers**: Parse the branch name (format: `feature/<numbers>-<description>`) to identify all issue numbers in the working set. If the branch was created with `/issue-start`, all issue numbers in the set appear in the branch name. If the branch name does not follow this format (no leading digits after `feature/`), stop and ask the user to provide the issue number(s) explicitly before continuing.
- [ ] **Fetch issue details**: Run `gh issue view <number> --json number,title,state` for each number. Confirm each is still open.
- [ ] **Surface discrepancies**: If any issue is already closed, or if the user worked on an issue not in the branch name, surface this before continuing. If an issue was added mid-work but is not in the branch name, the user must specify it explicitly.

### 2. Check PR Status
- [ ] **Check for existing PR**: Run `gh pr list --head $(git branch --show-current) --state open --json number,title,url`
- [ ] **If PR exists**: Note the PR number and URL. Proceed to Step 3.
- [ ] **If no PR exists**: Create one:
  - Check for acceptance gate: `ls .github/workflows/acceptance-gate.yml 2>/dev/null`. If found, add `--label run-acceptance`
  - Check for PR template in `.github/PULL_REQUEST_TEMPLATE.md` and related paths; use it if found, otherwise use the default structure below
  - Construct the PR body: include `Closes #<number>` for each issue in the closing set
  - Run `gh pr create --title "..." --body "..."` following `rules/git-workflow.md`

  **Default PR body structure** (when no template exists):
  ```markdown
  ## Description
  [What this PR does and why]

  ## Related Issues
  Closes #[issue-number]

  ## Changes Made
  - [List key changes]

  ## Testing
  - [Testing approach and results]
  ```

### 3. Review Gate
**Do not proceed to merge until this gate is passed and the human approves.**

- [ ] **Start CodeRabbit timer**: Begin a 7-minute background timer after confirming the PR exists.
- [ ] **Run `/code-review`**: Immediately invoke `/code-review` using the Skill tool — **except** for docs-only PRs and the other exceptions listed in `rules/git-workflow.md`. Run it in the foreground; never in the background or in parallel.
- [ ] **Fetch CodeRabbit findings** (when timer fires): Resolve OWNER and REPO with `gh repo view --json owner,name`. Then run all three channels:
  ```bash
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews --jq '[.[] | {user: .user.login, state, body}]'
  gh api repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '[.[] | {user: .user.login, path, line, body}]'
  gh api repos/OWNER/REPO/issues/PR_NUMBER/comments --jq '[.[] | {user: .user.login, body}]'
  ```
- [ ] **Present ALL findings**: Show every CodeRabbit and `/code-review` finding to the user. Do not filter or omit any.
- [ ] **Triage findings** per `rules/git-workflow.md`:
  - **Fix** if the only reason to skip is effort — effort alone is not a reason to skip
  - **Defer** if the fix warrants its own issue — create one and run `/write-prompt` on the body before `gh issue create`
  - **Skip** if the suggestion misunderstands the code, or fix cost genuinely outweighs benefit
- [ ] **Address and push fixes**: Commit and push any changes made in response to findings.
- [ ] **Re-review after pushing fixes**: Start another 7-minute timer. Re-run the three `gh api` calls. Repeat until no new blocking findings remain.
- [ ] **If CodeRabbit rate-limited**: Post `@coderabbitai review` as a comment (`gh pr comment PR_NUMBER --body "@coderabbitai review"`), start another 7-minute timer. If CodeRabbit never posts, `/code-review` provides full coverage — do not block indefinitely.
- [ ] **Human approval**: Wait for explicit human approval before proceeding to merge.

### 4. Update PROGRESS.md
- [ ] **Add changelog entry**: Under `## [Unreleased]` in `PROGRESS.md`, add an entry under the appropriate section heading (`### Added`, `### Fixed`, etc.):
  - Format: `- (YYYY-MM-DD) [What changed and why, including the reasoning behind the decision.]`
  - Include what changed, why, and the reasoning. No GitHub issue numbers, no internal file paths, no PR numbers.
  - Do not create a second section if the target heading already exists — add to the existing one.
- [ ] **Commit PROGRESS.md on the feature branch**: Stage and commit before merging so this entry is part of the merged PR.

### 5. Update ROADMAP.md (if applicable)
- [ ] **Check for ROADMAP**: Look for `docs/ROADMAP.md`. If absent, skip this step entirely.
- [ ] **If present**: Check whether any of the closed issues appear in it. If so, remove those entries — ROADMAP is forward-looking; completed work belongs in PROGRESS.md only. Commit alongside PROGRESS.md if changes were made.

### 6. Merge
- [ ] **Merge via GitHub CLI**: `gh pr merge <PR_NUMBER>`
- [ ] **Verify**: Confirm the merge completed successfully.

### 7. Close Issues
- [ ] **Close each issue**: For each issue number in the closing set (from Step 1), run `gh issue close <number>`
- [ ] **Verify**: Confirm each issue is now closed with `gh issue view <number> --json state`

### 8. Clean Branches
- [ ] **Switch to main**: `git checkout main`
- [ ] **Pull latest**: `git pull origin main`
- [ ] **Delete local branch**: `git branch -d <branch-name>` (use `-D` only if `-d` refuses and the user confirms no unmerged work will be lost)
- [ ] **Delete remote branch**: `git push origin --delete <branch-name>`

### 9. Confirm
Output a summary:
- Which issues were closed (numbers and titles)
- PR URL and merge confirmation
- Branch cleanup status (local and remote deleted)

## Success Criteria
✅ **All issues in the closing set are closed**
✅ **PR is merged**
✅ **PROGRESS.md updated with a changelog entry, committed on the feature branch**
✅ **Local and remote feature branches deleted**
✅ **Main is up to date locally**
