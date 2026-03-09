# PRD #37: Propagate run-acceptance Label Strategy to PRD Workflow Skills

**Status**: Open
**Priority**: Medium
**Created**: 2026-03-08

## Problem

Acceptance gate tests call real LLM APIs, take ~28 minutes, and cost real money. Currently there's no standard mechanism in the PRD workflow skills to ensure these tests run on PRD-driven feature PRs while being skipped for quick-fix PRs. The pattern was established in spinybacked-orbweaver using a `run-acceptance` GitHub label that triggers the acceptance-gate CI workflow, but the PRD skills don't know about it.

## Solution

Update three touchpoints in the PRD workflow:

1. **`/prd-create`** — When creating a PRD for a project with acceptance gate tests, include a reminder in the generated PRD that the feature PR needs the `run-acceptance` label.
2. **`/prd-done`** — When creating the PR at the end of a PRD, automatically add `--label run-acceptance` if the repo has acceptance gate tests configured.
3. **Global CLAUDE.md** — Document the labeling convention in the Git Workflow section so it applies across all repos.

### Detection Logic

A repo has acceptance gate tests if either:
- `.github/workflows/acceptance-gate.yml` exists, OR
- `.claude/verify.json` contains an `"acceptance_test"` command

## Success Criteria

- PRD-driven feature PRs automatically get the `run-acceptance` label
- Quick-fix PRs (bug fixes, docs, dependency bumps) do not get the label
- The convention is documented so both humans and Claude Code follow it consistently
- No changes required in repos that don't have acceptance gate tests

## Milestones

- [x] M1: Update `/prd-create` skill to include `run-acceptance` label reminder in generated PRDs when acceptance gate tests are detected
- [x] M2: Update `/prd-done` skill to automatically add `run-acceptance` label to PRs created through the PRD workflow
- [x] M3: Update global `~/.claude/CLAUDE.md` Git Workflow section with `run-acceptance` labeling convention
- [x] M4: Tests covering the new detection logic and label application
- [x] M5: Verify end-to-end: create a test PRD in a repo with acceptance gate tests and confirm the label flows through

## Design Notes

- The `run-acceptance` label is additive — it doesn't replace any existing label logic (e.g., release.yml labels still apply separately).
- The weekly cron on main and manual `workflow_dispatch` remain as safety nets — this PRD only addresses the PR labeling path.
- Detection should be lightweight: check for file existence, not parse workflow YAML contents.
- Projects without acceptance gate tests should see zero behavioral change.

## Out of Scope

- Changes to the acceptance-gate.yml workflow itself (already working in spinybacked-orbweaver)
- Creating the `run-acceptance` label in repos that don't have it (the workflow creates it on first use)
- Acceptance gate tests for telemetry-spec-v3 (explicitly excluded per user decision)

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-08 | Use file existence detection (not YAML parsing) for acceptance gate check | Simpler, faster, no YAML parsing dependency |
| 2026-03-08 | Exclude telemetry-spec-v3 from acceptance gate tests | User decision — not needed for that project |
| 2026-03-08 | Label is additive to existing release.yml label logic | Avoids conflicts with changelog categorization |
