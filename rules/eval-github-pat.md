# Eval Run GitHub PAT Setup

When setting up a new eval target repo, a fine-grained PAT scoped to the fork is required for spiny-orb to push the instrument branch and create a PR.

## What Works (from commit-story-v2 run-11 fix after 8 failed runs)

A **fine-grained PAT** with `push: true` (Contents: Read and write) and `pull_requests: write` (Pull requests: Read and write), verified with `git push --dry-run` to a non-existent branch before running.

## Why Classic Tokens Fail

Classic/OAuth tokens (`X-OAuth-Scopes: repo`) can fail with "Password authentication is not supported for Git operations" when the token stored in GCP Secret Manager isn't formatted correctly or wasn't created as a PAT. Fine-grained PATs have no `X-OAuth-Scopes` header — permissions are repo-specific and visible in GitHub settings.

## Setup Steps for Each New Eval Target

1. **Fork first** — the PAT must be scoped to the fork (`wiggitywhitney/<target>`), which must exist before you can create the PAT.

2. **Create fine-grained PAT** at `github.com/settings/personal-access-tokens/new`:
   - Resource owner: wiggitywhitney
   - Repository access: Only select repositories → `wiggitywhitney/<target>`
   - Permissions: Contents **Read and write** + Pull requests **Read and write**

3. **Store in GCP Secret Manager** as `github-token-<target>` (e.g., `github-token-taze`).

4. **Add to both `.vals.yaml` files** — the eval repo's and the target fork's:
   ```yaml
   GITHUB_TOKEN_<TARGET>: ref+gcpsecrets://demoo-ooclock/github-token-<target>
   ```
   Also add a comment: `# Fine-grained PAT scoped to wiggitywhitney/<target> with contents:write and pull_requests:write`

5. **Verify before running** — push to a **non-existent branch** (matching what spiny-orb actually does at runtime):
   ```bash
   vals exec -i -f .vals.yaml -- bash -c 'git -C ~/Documents/Repositories/<target> push --dry-run https://x-access-token:$GITHUB_TOKEN_<TARGET>@github.com/wiggitywhitney/<target>.git HEAD:refs/heads/spiny-orb/auth-test'
   ```
   Replace `<TARGET>` (e.g. `TAZE`) and `<target>` (e.g. `taze`). Must succeed without authentication errors. "Password authentication is not supported" or 403 means wrong token — stop and regenerate.

   **Do NOT use `HEAD:main` for verification.** If the local clone is behind remote main, git rejects with "rejected: fetch first" — which looks like a problem but is just a stale local branch. spiny-orb pushes a new branch (`spiny-orb/instrument-TIMESTAMP`), so the right test is against a branch that doesn't exist yet.

6. **Use in instrument command** — Before providing the command to Whitney, create the `debug-dumps/` directory for the run. Then give her the full command including `--thinking` and `--debug-dump-dir` — without those flags, failure diagnosis requires re-running the entire eval:
   ```bash
   caffeinate -s env -u ANTHROPIC_CUSTOM_HEADERS -u ANTHROPIC_BASE_URL vals exec -i -f .vals.yaml -- bash -c 'GITHUB_TOKEN=$GITHUB_TOKEN_<TARGET> node ~/Documents/Repositories/spinybacked-orbweaver/bin/spiny-orb.js instrument src --verbose --thinking --debug-dump-dir ~/Documents/Repositories/spinybacked-orbweaver-eval/evaluation/<target>/run-N/debug-dumps 2>&1 | tee ~/Documents/Repositories/spinybacked-orbweaver-eval/evaluation/<target>/run-N/spiny-orb-output.log'
   ```
   Replace `<TARGET>` with the target-specific env var name (e.g. `TAZE`, `COMMITIZEN`), `<target>` with the lowercase repo name, `N` with the run number, and `src` with the target's source directory (e.g., `lib` for release-it).

## "rejected: fetch first" Is Not a Permission Error

If a dry-run returns "rejected: fetch first", the token authenticated successfully — GitHub accepted the credentials. The rejection is because the local branch is behind the remote, not a permission failure. Use the non-existent-branch dry-run in step 5 to avoid this confusion entirely.

## Do Not Use `gh auth status` to Verify

`gh auth status` shows OAuth scopes for classic tokens but shows nothing useful for fine-grained PATs. It does not test write access. Only `git push --dry-run` to a non-existent branch confirms the token can actually push.
