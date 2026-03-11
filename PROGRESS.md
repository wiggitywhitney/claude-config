# Progress Log

Development progress log for claude-config. Tracks implementation milestones across PRD work.

## [Unreleased]

### Added

- Rolled out PROGRESS.md to all 11 active repos with Keep a Changelog template
- Gitignored PROGRESS.md in kubecon-2026-gitops (multi-contributor repo)
- Verified end-to-end PROGRESS.md workflow across spinybacked-orbweaver and scaling-on-satisfaction
- Acceptance gate test rolled out to commit-story-v2 (PRD #32, milestone 1)
- Acceptance gate test rolled out to cluster-whisperer (PRD #32, milestone 2)
- Acceptance gate test rolled out to telemetry-agent-spec-v3 with vals.yaml (PRD #32, milestone 3)
- Acceptance gate test rolled out to commit-story-v2-eval (PRD #32, milestone 4)
- Verbose reporter injection for vitest acceptance gate commands in pre-pr-hook.sh (PRD #35, M1)
- Fallback glob command uses `bash -c 'shopt -s globstar && ...'` for proper `**` expansion (PRD #35, M1)
- Async CI acceptance gate path in pre-pr-hook.sh — triggers GitHub Actions workflow via `gh workflow run` instead of blocking locally (PRD #35, M2)
- `acceptance_test_ci` key in verify.json for repos to opt into async CI workflow trigger (PRD #35, M2)
- Graceful fallback to sync execution when `gh` CLI unavailable or workflow trigger fails (PRD #35, M2)
- Reference GitHub Actions workflow template for acceptance gate CI (`templates/acceptance-gate-ci.yml`) with 45-min timeout, verbose reporter, parallel execution example (PRD #35, M3)
- Workflow template tests validating YAML structure, triggers, timeouts, secrets, and documentation (PRD #35, M3)
- Adopted async acceptance gate CI in spinybacked-orbweaver — parallel matrix strategy (core + coordinator), Weaver install, `acceptance_test_ci` key in verify.json (PRD #35, M4)
- Edge case tests for async CI acceptance gate: standard phase failure skips CI trigger, workflow trigger failure falls back to sync with verbose reporter, CI-only config graceful no-op, context includes workflow name and branch (PRD #35, M5)
- Rolled out async acceptance gate CI to commit-story-v2-eval and scaling-on-satisfaction — each repo gets `acceptance-gate.yml` workflow and `acceptance_test_ci` key in verify.json (PRD #35, M6)
- `run-acceptance` label reminder in `/prd-create` skill for projects with acceptance gate tests (PRD #37, M1)
- Auto-add `run-acceptance` label in `/prd-done` skill step 3.6b, additive to release.yml labels (PRD #37, M2)
- Documented `run-acceptance` labeling convention in global CLAUDE.md Git Workflow section (PRD #37, M3)
- Centralized acceptance gate detection script (`scripts/detect-acceptance-gate.sh`) with 20 tests (PRD #37, M4)
- Verified detection against real repos: spinybacked-orbweaver, commit-story-v2-eval (true), claude-config (false) (PRD #37, M5)
- (2026-03-11) Cluster lifecycle reminder script (`scripts/check-running-clusters.sh`) — detects running Kind and GKE clusters, outputs JSON reminder with teardown hints, graceful degradation for missing tools (PRD #39, M1)
- (2026-03-11) 31 tests for cluster-check script covering detection, graceful degradation, teardown hints, and error handling (PRD #39, M5)
- (2026-03-11) Wired cluster-check script as global SessionStart hook in `~/.claude/settings.json` — fires on every session start, silent when no clusters running (PRD #39, M2)
- (2026-03-11) Verified no mandatory teardown exit gates remain in cluster-whisperer or kubecon-2026-gitops PRDs (PRD #39, M4)
- (2026-03-11) End-to-end verification: hook detected real Kind cluster at session start, output valid JSON with teardown command, silent when no clusters (PRD #39, M6)

### Changed

- (2026-03-11) Softened infrastructure safety rule in global CLAUDE.md — replaced mandatory teardown gates with awareness-based approach via SessionStart hook (PRD #39, M3)

- (2026-03-11) Added `(YYYY-MM-DD)` date prefix to PROGRESS.md entry format in prd-update-progress and prd-start skills (both yolo and careful variants)

### Fixed

- Contributor detection counts unique names instead of name+email pairs (same person with multiple emails no longer inflates count)
- (2026-03-11) Restored all 8 careful skill variants as real files — were incorrectly replaced with symlinks to yolo variants in commit 21a0d6c
