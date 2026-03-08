# PRD #35: Async Acceptance Gate Tests with CI Integration

## Status: Open

## Problem

Acceptance gate tests block PR creation for ~28 minutes (spinybacked-orbweaver, measured 2026-03-08: 10 LLM-calling tests across 3 files), making iterative development painful. The current `pre-pr-hook.sh` runs acceptance tests synchronously — Claude and the developer sit idle waiting for results before the PR can be created. Additionally:

- **Terse failure output**: Vitest's default reporter doesn't include verbose failure details when running multiple test files, burying the actual failure reason.
- **No parallelism**: Acceptance tests run sequentially after security and standard test phases, adding to total wall time.
- **Blocking even when advisory**: Despite being "advisory" (never blocks PR creation), the tests still run synchronously and delay the PR creation flow.

## Solution

Make acceptance gate tests asynchronous by triggering a GitHub Actions CI workflow instead of running locally. The hook returns immediately with advisory context pointing to the CI run. Add verbose test output for better failure diagnostics.

### Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Where hook changes live | claude-config (pre-pr-hook.sh) | Universal infrastructure — all repos benefit |
| CI workflow location | Each repo that opts in | Workflows are repo-specific (different test commands, secrets) |
| Trigger mechanism | `gh workflow run` from the hook | Lightweight, no polling needed in the hook itself |
| Verbose output | Hook injects `--reporter=verbose` for vitest commands | Better failure diagnostics for all repos, not just CI |
| Opt-in mechanism | New `"acceptance_test_ci"` key in verify.json | Backward compatible — repos without it keep current sync behavior |
| Fallback behavior | If `gh` unavailable or workflow trigger fails, fall back to sync | Graceful degradation — never worse than current behavior |

## Milestones

- [x] **M1: Verbose test output in hook** — Detect vitest in acceptance test commands and inject `--reporter=verbose`. Fix the fallback glob command (`bash -c 'shopt -s globstar && ...'`). All repos benefit immediately without CI changes.
- [x] **M2: Async hook infrastructure** — Update `pre-pr-hook.sh` to support async mode: detect `"acceptance_test_ci"` in verify.json, trigger the workflow via `gh workflow run`, return immediately with advisory context linking to the CI run. Keep sync fallback when `gh` is unavailable.
- [x] **M3: GitHub Actions workflow template** — Create a reference workflow in claude-config that repos can copy/adapt. Handles: vals secrets injection, vitest with verbose reporter, 45-minute job timeout (Decision 7), status reporting. Document setup steps.
- [x] **M4: spinybacked-orbweaver adoption** — Add the CI workflow to spinybacked-orbweaver (3 test files, 10 LLM-calling tests, ~28min sequential). Update its verify.json with `"acceptance_test_ci"`, validate end-to-end that PR creation is fast and CI results appear on the PR.
- [x] **M5: Tests for hook changes** — Unit/integration tests for the new async path in pre-pr-hook.sh, including fallback behavior when gh is unavailable or workflow trigger fails.
- [x] **M6: Rollout to remaining repos** — Add CI workflows to repos with acceptance gates: commit-story-v2-eval and scaling-on-satisfaction. Each repo gets its own workflow adapted from the template. cluster-whisperer skipped (acceptance gate never merged to main). telemetry-agent-spec-v3 skipped (user opted out).

## Success Criteria

- PR creation completes in under 60 seconds (excluding standard security + test phases)
- Acceptance test results appear as CI status checks on the PR
- Verbose failure output makes root cause identifiable without digging through logs
- Repos without `acceptance_test_ci` continue working unchanged (backward compatible)
- Fallback to sync execution works when `gh` CLI is unavailable

## Risks

| Risk | Mitigation |
|---|---|
| CI secrets setup complexity | Document vals/GCP setup in workflow template; reference spiny-orbweaver as working example |
| GitHub Actions minutes cost | Acceptance tests only trigger on PR creation, not every push |
| Race condition: PR created before CI finishes | Advisory context tells developer to check CI before merging; CodeRabbit review fills the wait time naturally |
| Workflow trigger failure | Fall back to sync execution with clear messaging |
| Local output truncation on long runs | Observed: local background execution lost test output (exit 0, 119 bytes). CI captures logs reliably — this risk validates the async-to-CI approach |

## Decision Log

| Date | Decision | Rationale |
|---|---|---|
| 2026-03-08 | CI job timeout must be at least 45 minutes | spinybacked-orbweaver's 10 LLM-calling coordinator tests take ~28 min sequential. Individual tests range 130-230s normally but API latency spikes pushed some past 600s (observed: 734s, 792s, 877s, 1055s). Per-test timeouts were bumped to 1200s. CI needs headroom beyond the ~28min typical case. |
| 2026-03-08 | M6 scope reduced to commit-story-v2-eval and scaling-on-satisfaction | cluster-whisperer's acceptance gate (PRD #32 M2) was never merged to main — no acceptance_test in verify.json. telemetry-agent-spec-v3 excluded per user request. |
| 2026-03-08 | Run test files in parallel in CI | P1+P3 (9 tests, ~3.5min) and P4+P5 (25 tests, ~28min) can run concurrently. Local sequential execution took ~31min; parallel cut it to ~28min (P4+P5 is the bottleneck). CI should use matrix strategy or parallel jobs to exploit this. |
| 2026-03-08 | CI output capture is more reliable than local background tasks | Local background task output was truncated/lost multiple times during spinybacked-orbweaver testing — exit code 0 but only 119 bytes of output (vitest RUN header, no results). CI logs are reliably captured and accessible via `gh run view --log`. This is a strong argument for M2's async-to-CI approach over local background execution. |
| 2026-03-08 | spinybacked-orbweaver test structure: 3 files, 10 LLM tests | `test/acceptance-gate.test.ts` (3 tests, P1), `test/fix-loop/acceptance-gate.test.ts` (6 tests, P3), `test/coordinator/acceptance-gate.test.ts` (25 tests: 10 LLM-calling P4+P5, 15 deterministic). All require `vals exec -f .vals.yaml` for ANTHROPIC_API_KEY injection. This is the concrete configuration M4's CI workflow must support. |

## Prior Art

- PRD #28: Built the acceptance gate infrastructure in pre-pr-hook.sh
- PRD #32: Rolled out acceptance gates to all API-calling repos
- Current verify.json pattern: `"acceptance_test": "vals exec -f .vals.yaml -- ..."`
