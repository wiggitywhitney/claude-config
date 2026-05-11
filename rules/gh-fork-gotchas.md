# GitHub CLI Fork Gotchas

## `gh pr create` defaults to the upstream repo, not the fork

When a local repo has both `origin` (your fork) and `upstream` remotes, `gh pr create` reads the upstream as the "parent" repository and targets it by default — even though `origin` is your fork and the branch was pushed there.

**Fix:** Always specify `--repo` and `--base` explicitly when creating PRs in forked repos:

```bash
gh pr create --repo wiggitywhitney/REPO --base main --head BRANCH --title "..." --body "..."
```

This applies to every forked repo in the workspace, not just release-it. Any repo cloned from a fork will have this behavior. Symptoms: the PR URL shows the upstream org/owner instead of `wiggitywhitney`, and the PR may be inappropriate for the upstream project.

**Affected repos (known forks):** `release-it` (fork of `release-it/release-it`). Add others here as discovered.

## Checking whether a repo is a fork before creating a PR

```bash
git remote -v | grep upstream
```

If `upstream` appears, the repo is a fork — use `--repo wiggitywhitney/REPO` in all `gh pr create` calls.
