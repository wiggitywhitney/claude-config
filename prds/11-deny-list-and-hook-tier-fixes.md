# PRD #11: Deny List Glob Gap & Incremental Hook Tiers

**Status**: Open
**Priority**: High (Urgent)
**Created**: 2026-02-21
**Issue**: [#11](https://github.com/wiggitywhitney/claude-config/issues/11)

## Problem Statement

Three gaps discovered during the PRD #8 Milestone 5 validation pass against a real Go project:

### 1. Deny List Glob Gap (Security)

`Read(**/.npmrc)` in `~/.claude/settings.json` doesn't match `~/.npmrc` at the home directory root. The `**/` glob pattern requires at least one directory component, so it matches `foo/.npmrc` and `foo/bar/.npmrc` but NOT `.npmrc` at the current working directory root. This means npm auth tokens in `~/.npmrc` are readable by Claude Code despite the deny list entry.

The same gap exists for other `**/`-only patterns in the deny list:
- `Read(**/credentials*)` — doesn't match `credentials.json` at root
- `Read(**/secrets/**)` — doesn't match `secrets/` at root

### 2. Redundant Hook Verification Tiers (Performance)

The current hook tiers repeat work already completed by earlier tiers:

| Tier | Current Phases | Redundant Work |
|------|---------------|----------------|
| Commit | Build, Typecheck, Lint | None (base tier) |
| Push | Build, Typecheck, Lint, Security, Tests | Build, Typecheck, Lint (already passed at commit) |
| PR | Build, Typecheck, Lint, Security (expanded), Tests | Build, Typecheck, Lint (already passed at commit), Standard security (already passed at push) |

Each tier should be incremental — only running checks not already performed by earlier tiers. TDD handles test execution during development, so tests at PR creation serve as the formal gate.

### 3. Confusing Hook Allow Messages on Deny (UX)

When one hook denies an action (e.g., branch protection blocks a commit to main), other hooks that passed still show their "allow" messages in the UI. Claude Code prefixes these with "Error:" and renders them in red, creating a confusing display like:

```text
Error: verify: commit quick+lint passed ✓
```

The message says "passed" but appears as a red error. This happens because allow hooks set `permissionDecisionReason` (user-visible text) even on success. When the overall action is denied by another hook, all hook outputs are shown in error styling — making passing hooks look like failures.

### 4. Docs-Only Changes Run Full Verification (Performance)

All three verification hooks trigger on every git operation regardless of what files changed. A commit that only edits `.md` files still runs build, typecheck, and lint. A push with only documentation changes still runs security checks. This wastes time and adds friction to documentation workflows, where none of the code-oriented checks are relevant.

## Solution

### 1. Deny List Fix

Add root-level patterns alongside existing `**/` patterns for all sensitive file types that only have subdirectory coverage:

| Current Pattern | Missing Root Pattern |
|----------------|---------------------|
| `Read(**/.npmrc)` | `Read(.npmrc)` |
| `Read(**/credentials*)` | `Read(credentials*)` |
| `Read(**/secrets/**)` | `Read(secrets/**)` |

Patterns that already have both root and subdirectory coverage (no change needed):
- `.env` / `.env.*` — already have `Read(.env)` and `Read(**/.env)`
- `*.pem` / `*.key` — already have `Read(*.pem)` and `Read(**/*.pem)`
- `id_rsa*` / `id_ed25519*` — root-level patterns, no `**/` needed (these live in `~/.ssh/` which is separately denied)

### 2. Incremental Hook Tiers

Make each tier run only the checks that are new at that level:

| Tier | Incremental Phases | Rationale |
|------|-------------------|-----------|
| Commit | Build, Typecheck, Lint | Quality gates — catch syntax/type/style errors early |
| Push | Standard Security | Security gate — catch debug code, .only leaks |
| PR | Expanded Security, Tests | Formal gate — npm audit, secrets grep, .env check, full test suite |

The PR tier includes expanded security (npm audit, hardcoded secrets, .env validation) because these checks are too slow for every push but must run before code review. Standard security at push covers the fast checks (debug code, .only).

### 3. Silent Allow Responses

Hooks should only set `permissionDecisionReason` (user-visible) when **denying**. For allow responses, use only `additionalContext` (Claude-visible, not shown in UI). This prevents passing hooks from showing confusing "Error: ... passed" messages when another hook denies the action.

### 4. Docs-Only Early Exit

Add a shared utility that checks whether all changed files are documentation-only (`.md`, `.mdx`, `.txt`, images). Each verification hook calls it early and skips verification if no code files changed. Conservative allowlist — only file types that can never affect build, lint, security, or tests.

## Success Criteria

- [ ] `Read(.npmrc)` is denied at root level (verified by checking deny list)
- [ ] `Read(credentials*)` is denied at root level
- [ ] `Read(secrets/**)` is denied at root level
- [ ] Pre-push hook runs ONLY security (no build/typecheck/lint)
- [ ] Pre-PR hook runs ONLY expanded security + tests (no build/typecheck/lint)
- [ ] Pre-commit hook unchanged (build/typecheck/lint)
- [ ] All existing verification tests still pass
- [ ] Hook comments and success messages updated to reflect new tier responsibilities
- [ ] Allow hooks use `additionalContext` only (no `permissionDecisionReason`) — no confusing red "passed" messages
- [ ] Docs-only commits skip build/typecheck/lint verification
- [ ] Docs-only pushes skip security verification
- [ ] Docs-only PRs skip security+tests verification
- [ ] Mixed changes (docs + code) still trigger full verification

## Architecture Decisions

### Decision 1: Root Pattern Alongside Subdirectory Pattern

**Date**: 2026-02-21
**Decision**: Add explicit root-level patterns (e.g., `Read(.npmrc)`) alongside existing `**/` patterns rather than replacing them with a single pattern.
**Rationale**: There's no single glob that reliably matches both root and all subdirectories across all glob implementations. Using two patterns (`Read(.npmrc)` + `Read(**/.npmrc)`) is explicit and unambiguous. The deny list is not performance-sensitive.
**Impact**: Three new entries added to the deny list in `~/.claude/settings.json`.

### Decision 2: PR Tier Keeps Expanded Security

**Date**: 2026-02-21
**Decision**: The PR tier runs expanded security (npm audit, secrets grep, .env check) in addition to tests, even though push already ran standard security.
**Rationale**: Standard security (debug code, .only) and expanded security (npm audit, hardcoded secrets, .env) are different check sets. npm audit is too slow for every push. The expanded checks are incremental — they run checks that push didn't cover.
**Impact**: PR tier runs expanded security + tests. Push tier runs standard security only.

### Decision 3: Silent Allow, Verbose Deny

**Date**: 2026-02-21
**Decision**: Hook allow responses should omit `permissionDecisionReason` and only set `additionalContext`. Deny responses keep both fields.
**Rationale**: Claude Code renders all hook outputs in error styling when any hook denies. `permissionDecisionReason` is user-visible text — showing "passed ✓" in red as an "Error:" is actively misleading. `additionalContext` is Claude-visible only and won't appear in the UI, so Claude still gets the context it needs without confusing the user.
**Impact**: All three verification hooks (pre-commit, pre-push, pre-pr) and supplementary hooks need their allow responses updated.

### Decision 4: Docs-Only Early Exit with Conservative Allowlist

**Date**: 2026-02-21
**Decision**: Add a shared `is-docs-only.sh` utility that all three verification hooks call early. If all changed files match a conservative allowlist of documentation-only extensions, skip verification entirely.
**Rationale**: Build, typecheck, lint, security, and tests are all code-oriented checks. Running them on documentation-only changes wastes time without catching anything. A conservative allowlist (`.md`, `.mdx`, `.txt`, images) ensures we never skip verification for files that could affect code behavior — config files (`.yml`, `.json`, `.toml`) are excluded from the allowlist because they can affect builds and tests.
**Impact**: New shared utility script. Each hook adds an early-exit call (~5 lines). Docs-only commits/pushes/PRs become near-instant.

## Content Location Map

| Component | File | Change Type |
|-----------|------|-------------|
| Deny list | `~/.claude/settings.json` | Add 3 root-level deny patterns |
| Push hook | `.claude/skills/verify/scripts/pre-push-hook.sh` | Remove build/typecheck/lint phases, silent allow |
| PR hook | `.claude/skills/verify/scripts/pre-pr-hook.sh` | Remove build/typecheck/lint phases, silent allow |
| Commit hook | `.claude/skills/verify/scripts/pre-commit-hook.sh` | Silent allow |
| Supplementary hooks | `.claude/skills/verify/scripts/check-*.sh` | Silent allow |
| Docs-only utility | `.claude/skills/verify/scripts/is-docs-only.sh` | New shared utility |
| CLAUDE.md | `.claude/CLAUDE.md` | Update hook tier documentation comments |
| Global CLAUDE.md | `~/.claude/CLAUDE.md` | Update hook tier documentation comments |

## Implementation Milestones

### Milestone 1: Fix Deny List Glob Gap in settings.json
- [x] Add `Read(.npmrc)` to deny list
- [x] Add `Read(credentials*)` to deny list
- [x] Add `Read(secrets/**)` to deny list
- [x] Verify the three new patterns are positioned near their `**/` counterparts for readability

### Milestone 2: Make Pre-Push Hook Incremental (Security Only)
- [x] Remove build, typecheck, and lint phases from `pre-push-hook.sh`
- [x] Keep standard security check as the only verification phase
- [x] Update header comments to reflect new tier responsibility
- [x] Update success message from "full verification" to "security check"

### Milestone 3: Make Pre-PR Hook Incremental (Expanded Security + Tests)
- [ ] Remove build, typecheck, and lint phases from `pre-pr-hook.sh`
- [ ] Keep expanded security and tests as the only verification phases
- [ ] Update header comments to reflect new tier responsibility
- [ ] Update success message from "pre-pr verification" to "security+tests check"

### Milestone 4: Silent Allow Responses for All Hooks
- [ ] Update `pre-commit-hook.sh` allow response: remove `permissionDecisionReason`, keep `additionalContext`
- [ ] Update `pre-push-hook.sh` allow response: same pattern
- [ ] Update `pre-pr-hook.sh` allow response: same pattern
- [ ] Update `check-branch-protection.sh` allow response (if it has one)
- [ ] Update `check-commit-message.sh` allow response (if it has one)
- [ ] Update `check-coderabbit-required.sh` allow response (if it has one)
- [ ] Update `check-test-tiers.sh` allow response (if it has one)
- [ ] Deny responses unchanged — still show `permissionDecisionReason` for user feedback

### Milestone 5: Update Documentation and Verify
- [ ] Update CLAUDE.md hook tier comments in both project and global CLAUDE.md
- [ ] Run existing verification tests to confirm no regressions
- [ ] Manual smoke test: commit (should build/typecheck/lint), push (should security only), PR readiness (should security+test only)

### Milestone 6: Docs-Only Early Exit (Decision 4)
- [ ] Create `is-docs-only.sh` shared utility that checks if all changed files are documentation-only
- [ ] Add early-exit call to `pre-commit-hook.sh` (check staged files)
- [ ] Add early-exit call to `pre-push-hook.sh` (check branch diff)
- [ ] Add early-exit call to `pre-pr-hook.sh` (check branch diff)
- [ ] Verify mixed changes (docs + code) still trigger full verification

## Dependencies

None — all changes are within the existing claude-config infrastructure.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Glob behavior varies across Claude Code versions | Low | High | Using explicit patterns (no clever globs) eliminates ambiguity |
| Removing build/lint from push misses regressions after rebase | Low | Medium | Build/lint already ran at commit time; if commits pass, the code is clean. Rebases that break things will fail at PR tier tests |
| Expanded security at PR tier could be slow | Low | Low | npm audit and grep are fast; this is already the existing behavior, just without the redundant phases before it |

## Out of Scope

- Restructuring the deny list format or organization beyond the glob fix
- Adding new file types to the deny list
- CI/CD pipeline changes (hooks are local development tooling)
