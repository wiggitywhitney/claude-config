# PRD #47: Native Git Hook Migration

## Problem

Claude Code hooks that enforce git operations (commit message checks, branch protection, build verification, security checks) are regex-based pattern matchers running inside Claude Code's tool-call interception layer. Research shows this layer can be behaviorally circumvented by the AI agent through creative command routing, alternative git command formats, and regex gaps — without technically "jailbreaking" the hook mechanism ([research/claude-code-hook-security.md](../research/claude-code-hook-security.md)).

Native git hooks run inside the git process itself. When `git commit` invokes a `pre-commit` hook, there is no alternative path — git will not create the commit if the hook returns non-zero. The agent would have to bypass git entirely, which is dramatically harder than crafting a bash command that dodges a regex.

## Solution

Migrate 6 git-related Claude Code hooks to native git hooks, providing deterministic process-level enforcement. Archive the Claude Code hooks in this repo and remove them from `settings.json`.

### Hooks to Migrate

| Claude Code Hook | Target Git Hook | Phase |
|---|---|---|
| `check-commit-message.sh` | `commit-msg` | 1 |
| `check-branch-protection.sh` | `pre-commit` | 1 |
| `check-progress-md.sh` | `pre-commit` | 1 |
| `check-test-tiers.sh` | `pre-push` (advisory) | 1 |
| `pre-commit-hook.sh` | `pre-commit` | 2 |
| `pre-push-hook.sh` | `pre-push` | 2 |

### Hooks That Stay as Claude Code Hooks

| Hook | Reason |
|---|---|
| `pre-pr-hook.sh` | Intercepts `gh pr create`, not a git command |
| `check-coderabbit-required.sh` | Intercepts `gh pr merge`, not a git command |

## Constraints

- **Corporate laptop**: `core.hooksPath` is globally set to `/usr/local/dd/global_hooks/` (Datadog enterprise). Cannot modify or override.
- **Datadog dispatches local hooks**: Datadog's global hooks are shims that execute `.git/hooks/` via `run-local-hooks` before running Datadog policy enforcement. This is how commit-story `post-commit` hooks work today across 15 repos.
- **No conflicts**: Commit-story hooks are `post-commit`. Migrated hooks are `pre-commit`, `commit-msg`, and `pre-push` — different git events.
- **Multiple hooks per event**: `pre-commit` needs to run both branch protection and progress-md checks (Phase 1), then also build/typecheck/lint verification (Phase 2). Requires a dispatcher pattern within `.git/hooks/pre-commit`.

## Architecture

### Hook Source of Truth

All hook scripts live in `claude-config/hooks/git/` (new directory). Each git event gets a dispatcher script and individual check scripts:

```text
hooks/git/
├── pre-commit           # dispatcher: runs all pre-commit checks
├── commit-msg           # dispatcher: runs all commit-msg checks
├── pre-push             # dispatcher: runs all pre-push checks
├── checks/
│   ├── commit-message.sh
│   ├── branch-protection.sh
│   ├── progress-md.sh
│   ├── test-tiers.sh       # advisory (warns, doesn't block)
│   ├── pre-commit-verify.sh  # Phase 2: build/typecheck/lint
│   └── pre-push-verify.sh    # Phase 2: security checks, PR-aware escalation
└── lib/
    ├── detect-project.sh    # Phase 2: shared infrastructure
    ├── verify-phase.sh      # Phase 2: shared infrastructure
    ├── security-check.sh    # Phase 2: shared infrastructure
    └── ...
```

### Hook Distribution

A bootstrap script (`scripts/install-git-hooks.sh`) installs hooks into any repo's `.git/hooks/` via symlinks pointing back to claude-config. Run once per repo. Idempotent — safe to re-run.

### Smart Error Messages

Every hook MUST print clear, actionable error messages that both humans and Claude can understand. These replace the `additionalContext` guidance from Claude Code hooks. Example:

```text
ERROR: Cannot commit directly to main.
Create a feature branch first: git checkout -b feature/your-feature-name
Opt out for this repo: touch .skip-branching
```

### Migration Model

Clean migration — not dual enforcement:
1. Native git hooks do all blocking and messaging
2. Claude Code hooks for migrated checks are archived to `hooks/archive/claude-code/` and removed from `settings.json`
3. Single source of truth per check

## Success Criteria (Global)

- All migrated hooks block the same operations they blocked before
- All migrated hooks print smart, actionable error messages (human-readable AND AI-parseable)
- Hooks fire for both manual git operations AND Claude Code git operations (via Datadog's `run-local-hooks` dispatch)
- Integration tests pass against real temp git repos
- Claude Code hooks for migrated checks are removed from `settings.json`
- Existing commit-story `post-commit` hooks are unaffected
- Datadog global hooks are untouched
- Opt-out dotfiles (`.skip-branching`, `.skip-coderabbit`, etc.) continue to work

## Milestones

### Milestone 1: Hook Infrastructure and Bootstrap

Set up the directory structure, dispatcher pattern, and bootstrap installer.

**Deliverables:**
- `hooks/git/` directory structure created
- Dispatcher scripts for `pre-commit`, `commit-msg`, and `pre-push` that iterate over check scripts and aggregate results
- `scripts/install-git-hooks.sh` bootstrap script that symlinks dispatchers into a repo's `.git/hooks/`
- Bootstrap handles existing hooks gracefully (backs up, warns, doesn't clobber commit-story post-commit)
- Integration test: bootstrap installs hooks into a temp repo, dispatchers execute, Datadog's `run-local-hooks` can invoke them

**Success Criteria:**
- Bootstrap is idempotent
- Dispatchers print clear status messages for each check that runs
- Existing `.git/hooks/post-commit` (commit-story) is preserved
- Running `install-git-hooks.sh` on claude-config itself works end-to-end

### Milestone 2: Migrate Clean Four Hooks

Migrate `check-commit-message.sh`, `check-branch-protection.sh`, `check-progress-md.sh`, and `check-test-tiers.sh` to native git hooks.

**Deliverables:**
- `hooks/git/checks/commit-message.sh` — blocks commits with AI/Claude/Anthropic/Co-Authored-By references; prints clear message explaining what was found and how to fix it
- `hooks/git/checks/branch-protection.sh` — blocks commits to main/master; prints message suggesting `git checkout -b`; respects `.skip-branching`; preserves docs-only exemption
- `hooks/git/checks/progress-md.sh` — blocks commits when PRD checkboxes are marked done but PROGRESS.md not staged; prints message listing which PRD files have new checkboxes and reminds to `git add PROGRESS.md`
- `hooks/git/checks/test-tiers.sh` — warns (does not block) when test tiers are missing on push/PR; prints advisory message listing which tiers are missing; respects `.skip-integration` and `.skip-e2e`
- Integration tests for each hook: attempt the blocked operation in a temp git repo, assert it fails with the correct error message; attempt the allowed operation, assert it succeeds
- Claude Code hooks for these 4 checks archived to `hooks/archive/claude-code/` and removed from `settings.json`

**Success Criteria:**
- Each hook blocks/warns on the same conditions as its Claude Code predecessor
- Each hook prints a smart, actionable error message that tells the user (or Claude) exactly what went wrong and how to fix it
- Opt-out dotfiles work identically
- Docs-only exemption in branch protection works identically
- Integration tests verify blocking, allowing, opt-out, and error message content
- Claude Code can read the error output and self-correct on the next attempt (validated manually)

### Milestone 3: Migrate Complex Two Hooks

Migrate `pre-commit-hook.sh` (build/typecheck/lint verification) and `pre-push-hook.sh` (security checks, PR-aware escalation, CodeRabbit CLI review) to native git hooks.

**Deliverables:**
- `hooks/git/checks/pre-commit-verify.sh` — runs build, typecheck, lint verification before commit; uses shared `detect-project.sh` and `verify-phase.sh` infrastructure; prints clear per-phase pass/fail messages with truncated output on failure; preserves docs-only early exit
- `hooks/git/checks/pre-push-verify.sh` — runs security checks before push; detects open PRs via `gh pr list` and escalates to expanded security + tests when PR exists; runs advisory CodeRabbit CLI review after blocking checks pass; prints clear messages for each phase; preserves docs-only early exit
- Shared infrastructure migrated to `hooks/git/lib/` (detect-project.sh, verify-phase.sh, security-check.sh, lint-changed.sh, is-docs-only.sh, coderabbit-review.sh)
- Integration tests for each hook covering: clean pass, phase failure with error message, docs-only skip, PR-aware escalation (for pre-push)
- Claude Code hooks for these 2 checks archived and removed from `settings.json`

**Success Criteria:**
- Each hook enforces the same verification tiers as its Claude Code predecessor
- Each hook prints smart, actionable error messages per phase (e.g., "TYPECHECK FAILED: 3 errors in src/index.ts — fix type errors before committing")
- Shared infrastructure (`detect-project.sh`, etc.) works from the new `hooks/git/lib/` location
- Docs-only early exit works identically
- PR-aware escalation in pre-push works identically (requires `gh` CLI)
- CodeRabbit CLI advisory review runs and prints findings without blocking
- Integration tests verify all paths including error message content

### Milestone 4: Rollout and Cleanup

Install hooks across all active repos, verify everything works, clean up.

**Deliverables:**
- Run `install-git-hooks.sh` across all active repos in `~/Documents/Repositories/`
- Verify native hooks fire correctly in each repo before proceeding
- Verify commit-story `post-commit` hooks still work in all 15 repos
- Verify Datadog global hooks still dispatch correctly
- **Only after all repos verified**: Remove all migrated hook entries from `~/.claude/settings.json`
- Archive original Claude Code hook scripts in `hooks/archive/claude-code/` with a README explaining the migration
- Update `rules/hooks-reference.md` to document the new git hook architecture
- Update project `CLAUDE.md` to reference the new hook system

**Safe rollout order (Decision 1):** Install native hooks and verify in all repos first. Remove from `settings.json` last, as a single final step. This ensures no repo has a coverage gap — if native hook installation fails in any repo, `settings.json` still provides enforcement while the issue is resolved.

**Success Criteria:**
- All active repos have native git hooks installed and working
- Manual `git commit` on main is blocked with smart error message in every repo
- Manual `git commit` with AI attribution is blocked with smart error message
- Claude Code git operations are blocked by the same hooks (via Datadog dispatch)
- Commit-story journaling continues to work in all repos
- No Claude Code hook entries remain for the 6 migrated hooks
- Documentation is updated

### Milestone 5: Future Exploration — Plugin Architecture Learnings

Evaluate whether patterns learned from studying Claude Code plugins (Skill Creator, Superpowers, Code Review) can improve the hook system or related skills.

**Deliverables:**
- Review plugin study findings (confidence scoring, multi-agent patterns, phased workflows with gate points)
- Assess applicability to hook error messages (e.g., confidence-scored warnings)
- Assess applicability to existing skills (`/verify`, `/anki`, `/write-prompt`, `/research`)
- Document recommendations for follow-up PRDs

**Success Criteria:**
- Written assessment with concrete recommendations
- Follow-up PRDs created for any approved improvements

## References

- [Research: Claude Code Hook Security](../research/claude-code-hook-security.md)
- [Current hooks reference](../rules/hooks-reference.md)
- [Git workflow rules](../../.claude/rules/git-workflow.md)
