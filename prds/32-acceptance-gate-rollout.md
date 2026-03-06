# PRD #32: Acceptance Gate Test Rollout

## Problem

The acceptance gate infrastructure (PRD #28) is built and working — `pre-pr-hook.sh` detects `acceptance_test` in `.claude/verify.json`, runs the tests via `vals exec`, and presents results for human review. Two repos have it: spinybacked-orbweaver (reference implementation) and scaling-on-satisfaction. But 4 other repos that call the Anthropic API still lack acceptance gate tests, meaning their PRs merge without verifying the real API integration works.

## Solution

Roll out acceptance gate tests to all repos that use the Anthropic API. For each repo:
1. Write an `acceptance-gate.test.*` file that calls the main API-consuming function with real inputs
2. Create/update `.claude/verify.json` with the `acceptance_test` command
3. Create `.vals.yaml` if missing (telemetry-agent-spec-v3)

Tests are lightweight integration smoke tests — call the real function, verify the response shape is correct and content is non-empty. Not exhaustive coverage; just "the API integration isn't broken."

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Test granularity | Smoke test the main entry function per repo | Keeps costs low while proving the integration works end-to-end |
| Test pattern | `describe.skipIf(!API_KEY_AVAILABLE)` with visible warning | Skip is allowed but must log clearly why tests were skipped — never silent |
| Timeout | 120s per test | LLM API calls can be slow; avoid false failures |
| Work location | Each repo gets its own branch + PR | Changes are repo-specific; cross-repo PRs aren't possible |
| vals.yaml pattern | Same GCP secret ref across all repos | All repos share the same Anthropic key from `demoo-ooclock` project |

## Scope

### In Scope

| Repo | Has verify.json | Has vals.yaml | Test framework | Main API function |
|---|---|---|---|---|
| commit-story-v2 | No | Yes | Vitest (JS) | `generateJournalSections()` |
| cluster-whisperer | No | Yes | Vitest (TS) | `inferCapability()`, `invokeInvestigator()` |
| telemetry-agent-spec-v3 | No | No | Vitest (TS) | `callAnthropic()`, `runInstrumentationAgent()` |
| commit-story-v2-eval | No | Yes | Vitest (JS) | `generateJournalSections()` |

### Out of Scope

- Repos that don't call the Anthropic API (telemetry-agent-research, k8s-vectordb-sync, claude-compaction-hook, kubecon-2026-gitops, claude-config)
- Changes to the acceptance gate infrastructure itself (pre-pr-hook.sh, detect-project.sh)
- CI/CD workflows for acceptance tests (known gap — CI lacks vals/GCP Secrets Manager access; local hooks + human review enforce for now; CI enforcement is potential follow-up work requiring GitHub Actions secrets setup)
- Repos already rolled out (spinybacked-orbweaver, scaling-on-satisfaction)

## Milestones

- [x] **Milestone 1: commit-story-v2** — acceptance-gate.test.js calling `generateJournalSections()` with real API, verify.json configured
- [ ] **Milestone 2: cluster-whisperer** — acceptance-gate.test.ts calling `inferCapability()` with real API, verify.json configured
- [ ] **Milestone 3: telemetry-agent-spec-v3** — acceptance-gate.test.ts calling `callAnthropic()` or `runInstrumentationAgent()` with real API, verify.json and vals.yaml configured
- [ ] **Milestone 4: commit-story-v2-eval** — acceptance-gate.test.js calling `generateJournalSections()` with real API, verify.json configured

## Per-Repo Deliverables

Each milestone produces:
1. `test/**/acceptance-gate.test.{js,ts}` — test file with `describe.skipIf(!API_KEY_AVAILABLE)` guard that logs a visible warning when skipping
2. `.claude/verify.json` — `{"commands": {"acceptance_test": "vals exec -f .vals.yaml -- npx vitest run test/**/acceptance-gate.test.*"}}`
3. `.vals.yaml` (only if missing) — with `ANTHROPIC_API_KEY` ref to GCP Secrets Manager

## Reference Implementation

spinybacked-orbweaver's pattern:
- Test file: `test/acceptance-gate.test.ts`
- Guard: `const API_KEY_AVAILABLE = !!process.env.ANTHROPIC_API_KEY;` + `describe.skipIf(!API_KEY_AVAILABLE)`
- verify.json: `{"commands": {"acceptance_test": "vals exec -f .vals.yaml -- npx vitest run test/**/acceptance-gate.test.ts"}}`
- Timeout: `{ timeout: 120_000 }` on each test

## Risks

| Risk | Mitigation |
|---|---|
| API costs from test runs | Tests are smoke-level (1-2 API calls per repo); only run at PR time |
| Flaky tests from LLM non-determinism | Assert response shape/structure, not exact content |
| Missing vals on some machines | `describe.skipIf(!API_KEY_AVAILABLE)` skips with visible warning; pre-pr-hook reports skip reason in additionalContext |

## Status

- **Phase**: Ready for implementation
- **Created**: 2026-03-06
