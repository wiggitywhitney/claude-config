# Archived Claude Code Hooks

These Claude Code PreToolUse hook scripts were migrated to native git hooks in PRD #47 (Milestone 2).

The logic from each script now lives in `hooks/git/checks/` and fires as native git hooks
(pre-commit, commit-msg, pre-push) via `scripts/install-git-hooks.sh`.

## Why native git hooks

Claude Code hooks fire only when Claude Code's Bash tool is used. Native git hooks fire for
every git operation — both manual terminal use and Claude Code — providing stronger enforcement.

## Migrated scripts

| Archived file | Replaces | Native hook |
|---|---|---|
| `check-commit-message.sh` | `hooks/git/checks/commit-message.sh` | `commit-msg` |
| `check-branch-protection.sh` | `hooks/git/checks/branch-protection.sh` | `pre-commit` |
| `check-progress-md.sh` | `hooks/git/checks/progress-md.sh` | `pre-commit` |
| `check-test-tiers.sh` | `hooks/git/checks/test-tiers.sh` | `pre-push` |
| `pre-commit-hook.sh` | `hooks/git/checks/pre-commit-verify.sh` | `pre-commit` |
| `pre-push-hook.sh` | `hooks/git/checks/pre-push-verify.sh` | `pre-push` |

These files are kept for reference. They are no longer registered in `settings.json`.
