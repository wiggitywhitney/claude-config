# Git Workflow

- Always work on feature branches. Never commit directly to main.
- Don't squash git commits.
- Create a new PR to merge to main anytime there are codebase additions.
- PRs require CodeRabbit review examined and approved by human before merge.
- The pre-push hook runs CodeRabbit CLI review (advisory). When findings appear, fix issues and push again before creating a PR.
- **CodeRabbit CLI manual invocation:** When you need to run a CodeRabbit CLI review outside the pre-push hook (e.g., reviewing a PRD or doc-only branch), use:
  ```bash
  coderabbit review --committed --base origin/main 2>&1
  ```
  Run in background — reviews take 1-7+ minutes. If CodeRabbit returns a rate-limit error with a wait time (e.g., "please try after 4 minutes and 29 seconds"), set a background sleep timer for that duration and retry automatically. Key gotchas:
  - As of CLI v0.7.0, plain text is the default output mode and `--plain` is no longer a recognized flag — passing it now errors with "unknown option '--plain'" before the review even starts. Verify with `coderabbit review --help` if a command errors immediately, since flag names have changed across versions.
  - As of CLI v0.7.0, use `--committed` for branch-vs-base comparison, not `--type committed` (the `--type` flag itself no longer exists). The default (no flag) reviews tracked changes; `--uncommitted` reviews staged/tracked edits; `--include-untracked` adds untracked files.
  - Always use `origin/main` (not `main`) as the base ref.
  - The branch must have commits that the base doesn't — if you cherry-pick from main, the CLI sees no diff.
  - Do NOT use `--no-color` — this flag is not recognized and causes the CLI to exit with an error.
  - **Detecting a hung background review**: If a background CodeRabbit review appears stuck (e.g., "Summarizing changes... Xs elapsed" never advancing for far longer than a normal 1-7 minute run), don't assume it will eventually finish — check `ps aux | grep -i coderabbit` for the actual OS-level process. A process with negligible accumulated CPU time (e.g., `0:00.42`) despite a start time hours in the past is hung, not working. Fix: `kill -9` both the `coderabbit review` process and its parent shell wrapper, confirm no coderabbit-review process remains via a follow-up `ps aux`, then restart the review fresh as a new background task.
  - **A "completed" background-task notification does not mean the review finished.** When a `coderabbit review ... &`/`nohup` background task reports "completed (exit code 0)," that only means the backgrounding shell wrapper exited after launching the subprocess — the actual `coderabbit review` process (which takes 1-7+ minutes) is very likely still running. Treat every such notification as a launch confirmation, not a completion signal. Verify the real state before reading results: find the actual PID with `ps aux | grep -i "coderabbit review"`, then block on it directly — `while ps -p <PID> > /dev/null 2>&1; do sleep 15; done; cat <logfile>` — rather than trusting the notification. Confirmed repeatedly across multiple review cycles.
- After creating a PR, immediately run `/code-review` in the session — **except** for: docs-only PRs (markdown, SKILL.md, CLAUDE.md, rules files); standalone issue fixes where ≤2 non-test source files changed, the changes are self-contained (each file is independently modified with no complex cross-file interactions), new tests directly cover the changed logic, and CodeRabbit CLI found no blocking findings; or other small/obvious code changes where CodeRabbit coverage is sufficient. `/code-review` and CodeRabbit find different issue classes — `/code-review` catches CLAUDE.md compliance, bugs, and historical context issues; CodeRabbit catches security and correctness issues. Address both sets of findings before merging. If CodeRabbit is rate-limited and never posts a review, `/code-review` provides full coverage; do not block the merge indefinitely waiting for CodeRabbit.
- After creating a PR, start a background sleep timer (7 minutes) to poll for the CodeRabbit review. When the timer fires, fetch all CodeRabbit findings using three `gh api` calls — CodeRabbit posts to all three channels and missing any one means missing findings:
  ```bash
  gh api --paginate repos/OWNER/REPO/pulls/PR_NUMBER/reviews --jq '.[] | {user: .user.login, state, body}'
  gh api --paginate repos/OWNER/REPO/pulls/PR_NUMBER/comments --jq '.[] | {user: .user.login, path, line, body}'
  gh api --paginate repos/OWNER/REPO/issues/PR_NUMBER/comments --jq '.[] | {user: .user.login, body}'
  ```
  - `/pulls/{n}/reviews` — full review bodies including "outside diff range" findings (most content lives here)
  - `/pulls/{n}/comments` — inline comments attached to specific diff lines
  - `/issues/{n}/comments` — conversation-level notices (e.g., "reviews paused") and rate-limit notices

  `--paginate` is required: without it each call returns only the first 30 results, so a PR with many findings silently reports a subset. The filter must be a **streaming** one (`.[] | {...}`) rather than a wrapped array (`[.[] | {...}]`) — with `--paginate`, gh applies the filter per page, so a wrapped filter emits one array per page instead of one combined result. Do **not** reach for `--slurp` here: gh rejects it outright with "the `--slurp` option is not supported with `--jq` or `--template`". Verified against gh on 2026-08-02.

  **Confirm the review ran by positive evidence, not by absence of findings.** "Reviewed and found nothing," "rate-limited and never ran," and "reviewed an older commit" are indistinguishable if you only check whether findings came back. A rate-limit notice proves the second case; its absence proves nothing. Compare `git rev-parse HEAD` against the `commit_id` of CodeRabbit's reviews — no match means the review is still pending for this head, not that it is clean.

  Present all findings to the user.
- **CodeRabbit PR rate limit:** When the issues/comments channel shows a rate-limit notice, CodeRabbit does NOT auto-retry — it stops entirely. You must manually trigger a re-review by posting `@coderabbitai review` as a PR comment (`gh pr comment PR_NUMBER --body "@coderabbitai review"`), then start another 7-minute timer to poll for the result.
- After pushing fixes for CodeRabbit feedback, start another 7-minute timer to check for the re-review before merging.
- **CodeRabbit triage rubric** for non-critical findings:
  - **Fix** if the finding is real and the only reason not to fix it is effort — effort alone is not a reason to skip.
  - **Defer** if the finding is real and worth addressing, but complexity or scope makes it better suited to a dedicated issue than an inline fix. Create a GitHub issue; run `/write-prompt` on the issue body before creating it.
  - **Skip** if the suggestion misunderstands the code, or if fix complexity genuinely outweighs the benefit and the finding is not worth tracking at all.
- **Before linking an issue in a PR description (`Closes #N`)**: every unchecked acceptance criteria checkbox in that issue must be either (a) implemented and committed in the current branch, or (b) tracked in a new open issue filed before the PR is created. If any checkbox is unchecked and has no tracking issue, remove the `Closes #N` reference — do not close the issue with this PR. Deferring acceptance criteria requires explicit human approval in the current session; never defer silently or unilaterally.
- **After merging a PR**, delete the local and remote feature branch immediately. Don't leave stale branches accumulating.
- NEVER include references to Claude, AI, Anthropic, or Co-Authored-By AI attribution in commit messages. Write commit messages as if authored by a human developer.
- Repos may override rules via dotfiles (`.skip-branching`, `.skip-coderabbit`).
- **Global gitignore makes `git add` exit 1 on already-tracked files.** `~/.gitignore_global` (set via `git config core.excludesfile`) contains a personal `prds/` exclusion pattern. In repos that track `prds/*.md` files, plain `git add <path-under-prds/>` prints "The following paths are ignored by one of your .gitignore files: prds — hint: Use -f if you really want to add them" and **exits 1**. Git complains about the ignored parent directory, not the file.

  Two details that are easy to get wrong:
  - **The exit code lies about the outcome.** The add exits 1 but the modification *is* staged anyway. A script checking `$?` will treat a successful staging as a failure. Verified by reproduction, 2026-08-02.
  - **This is repo-specific, so testing in the wrong repo gives the wrong answer.** `claude-config/.gitignore` contains `!prds/`, which negates the global rule — `git add prds/foo.md` works there with no error. Journal has no such negation, so it hits the error. A check run in claude-config will wrongly conclude the problem does not exist.

  Fix for a single add: use `git add -u <path>`, which stages tracked modifications without consulting ignore rules and exits 0 cleanly — no need for the discouraged `-f`. Durable fix for a repo that legitimately tracks `prds/`: add `!prds/` to that repo's `.gitignore`, as claude-config already does.
- **Acceptance gate labeling:** When creating a PR for a project with acceptance gate tests (`.github/workflows/acceptance-gate.yml` exists or `.claude/verify.json` contains `"acceptance_test"`), add `--label run-acceptance` to the `gh pr create` command. This triggers the acceptance gate CI workflow. The `/prd-done` skill handles this automatically for PRD-driven PRs; apply the same convention for manual PRs.
