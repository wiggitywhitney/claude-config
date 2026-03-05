# PRD #28: Acceptance Gate Tests in Pre-PR Hook

## Status: Complete (2026-03-05)

## Problem

Projects with expensive API-based acceptance tests (e.g., LLM integration tests that make real API calls) have no automated verification gate before PR creation. These tests:
- Require API keys injected via `vals exec`
- Cost real money per run (LLM API calls)
- Should only run after cheaper verification phases pass
- Need human review of results before PR creation continues

Currently the pre-PR hook runs security checks and standard tests, but has no concept of a separate "acceptance test" tier that requires secrets and human approval.

## Solution

Extend `pre-pr-hook.sh` to optionally detect and run acceptance gate tests after standard verification passes. The results are **advisory** (never block PR creation) but **mandatory for human review** (Claude must stop and present results before proceeding).

### Detection Strategy

Two detection methods, checked in order:

1. **Preferred**: `.claude/verify.json` with `"acceptance_test"` key in the `commands` object (detect-project.sh already reads this file)
2. **Fallback**: Presence of `test/**/acceptance-gate.test.ts` files AND a `.vals.yaml` file in the project root

If neither signal is present, skip silently. This hook fires in every repo — graceful skip is essential.

### Execution

- Run the acceptance test command (from verify.json or default: `vals exec -f .vals.yaml -- npx vitest run test/**/acceptance-gate.test.ts`)
- Advisory only — exit code does not block PR creation
- Results go into `additionalContext` with mandatory human review wording

### additionalContext Behavior

**When acceptance tests run (pass or fail)**:
```text
MANDATORY: Acceptance gate tests with live API completed. You MUST present these results to the user and get explicit approval before proceeding with PR creation. Do NOT continue automatically.

[full test output here]
```

**When vals/API key unavailable**:
```text
Acceptance gate tests skipped — vals or API key not available.
```

**When no acceptance tests detected**: Silent skip, no additionalContext addition.

## Technical Context

### Existing Pattern (detect-project.sh)

`detect-project.sh` already reads `.claude/verify.json` and extracts commands for build, typecheck, lint, and test. The acceptance_test key follows this same pattern. The spinybacked-orbweaver project already has this configured:

```json
{
  "commands": {
    "acceptance_test": "vals exec -f .vals.yaml -- npx vitest run test/**/acceptance-gate.test.ts"
  }
}
```

### Pre-PR Hook Flow (current)

1. Detect project type and commands
2. Check for docs-only changes (skip if so)
3. Run expanded security checks
4. Run tests
5. Return allow/deny

### Pre-PR Hook Flow (proposed)

1. Detect project type and commands
2. Check for docs-only changes (skip if so)
3. Run expanded security checks
4. Run tests
5. **NEW: Run acceptance gate tests (advisory)**
6. Return allow (with additionalContext if acceptance tests ran) or deny (if security/tests failed)

### Key Constraint

Acceptance tests run AFTER standard phases. If security or tests fail, the hook denies PR creation and acceptance tests are skipped entirely (no point spending API money if the PR is blocked anyway).

## Reference Implementation

- **First consumer**: spinybacked-orbweaver (`~/Documents/Repositories/spinybacked-orbweaver`)
  - 4 acceptance gate test files: `test/acceptance-gate.test.ts`, `test/validation/acceptance-gate.test.ts`, `test/fix-loop/acceptance-gate.test.ts`, `test/coordinator/acceptance-gate.test.ts`
  - Tests use `describe.skipIf(!API_KEY_AVAILABLE)` pattern
  - Uses `vals exec -f .vals.yaml` for secret injection

## Success Criteria

- Pre-PR hook detects acceptance tests via verify.json `acceptance_test` command
- Pre-PR hook falls back to file + .vals.yaml detection
- Acceptance tests run after standard verification passes
- Test failures do NOT block PR creation (advisory)
- additionalContext forces Claude to present results and get human approval
- Repos without acceptance tests see no behavior change (silent skip)
- Missing vals/API keys produce a brief skip note, not an error

## Milestones

- [x] 1. detect-project.sh extracts `acceptance_test` command from verify.json
- [x] 2. pre-pr-hook.sh runs acceptance gate tests after standard phases pass
- [x] 3. Advisory behavior: test failures allow PR creation but mandate human review via additionalContext
- [x] 4. Graceful skip when no acceptance tests detected or vals unavailable
- [x] 5. Tests for detection logic and hook behavior
- [x] 6. Documentation in CLAUDE.md describing the acceptance gate tier
  - Update global CLAUDE.md hook comments to show the 4-tier verification model:
    - `git commit` → build, typecheck, lint (pre-commit-hook.sh)
    - `git push` → standard security (pre-push-hook.sh)
    - `gh pr create` → expanded security, tests (pre-pr-hook.sh)
    - `gh pr create` → acceptance gate tests with live API (pre-pr-hook.sh, advisory)
  - Add to the hook comment block: `<!-- pre-pr-hook.sh also runs advisory acceptance gate tests when .claude/verify.json has an "acceptance_test" command; results require human approval before PR creation continues -->`
  - Document in the Testing section that repos can opt into acceptance gate tests by adding `"acceptance_test"` to `.claude/verify.json` commands object
  - Mention vals exec requirement for secret injection

## Decision Log

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Advisory, not blocking | Acceptance tests cost real money and may have flaky API dependencies. Blocking would create friction without proportional safety benefit. |
| 2 | Mandatory human review via additionalContext | Even though non-blocking, these tests exist for a reason. Claude must not silently proceed — human must see and approve results. |
| 3 | verify.json preferred over file convention | detect-project.sh already reads verify.json. Adding a key is simpler and more explicit than file-pattern detection. |
| 4 | Skip if standard phases fail | No point spending API money if the PR is going to be denied anyway. |
| 5 | vals availability check before running | Graceful degradation when secrets infrastructure isn't available (e.g., CI without vals, new machine setup). |

## Out of Scope

- Caching or deduplicating acceptance test runs across pushes
- Cost tracking or budgeting for API calls
- Parallel execution of acceptance tests with other phases
- Auto-retry on transient API failures
