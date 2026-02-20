# PRD #8: Go Language Verification Support

**Status**: In Progress
**Priority**: High
**Created**: 2026-02-20
**Issue**: [#8](https://github.com/wiggitywhitney/claude-config/issues/8)

## Problem Statement

The shared verification infrastructure (`detect-project.sh`, hooks, language rules) only has command detection for Node.js projects. Go projects are detected by type (`project_type: "go"`) but get empty commands — no build, typecheck, lint, or test verification runs. This means YOLO mode has no guardrails for Go projects.

Additionally:
- `lint-changed.sh` only supports JS/TS file extensions — Go files are ignored
- `detect-test-tiers.sh` detects `project_type: "go"` but has no Go-specific test tier heuristics
- `rules/languages/go.md` is a placeholder stub with no actual rules
- Security check patterns in `security-check.sh` only scan JS/TS files for debug code

## Solution

Add full Go project support across the verification infrastructure:
1. **Command detection** — detect `go build`, `go vet`, `golangci-lint`, `go test`, and Makefile targets
2. **Lint scoping** — extend `lint-changed.sh` to scope Go linting to changed `.go` files
3. **Test tier detection** — add Go test tier heuristics (unit `_test.go`, integration `//go:build integration`, e2e Kind/envtest)
4. **Language rules** — populate `rules/languages/go.md` with Go-specific patterns from real usage
5. **Security checks** — extend debug code detection to Go (e.g., `fmt.Println` in non-main packages)
6. **Validation** — verify against k8s-vectordb-sync (a real Kubebuilder project)

## Success Criteria

- [x] `detect-project.sh` returns correct build/typecheck/lint/test commands for a Go project with `go.mod`
- [x] `detect-project.sh` detects and uses Makefile targets when available (Kubebuilder pattern)
- [x] `lint-changed.sh` scopes `golangci-lint` to changed `.go` files on commit, full lint on push
- [ ] `detect-test-tiers.sh` correctly identifies Go unit, integration, and e2e test tiers
- [ ] Pre-commit hook runs `go build`/`go vet`/`golangci-lint` for Go projects
- [ ] Pre-push hook runs full test suite for Go projects
- [ ] `rules/languages/go.md` contains actionable Go patterns from real Kubebuilder usage
- [ ] All verification hooks pass cleanly on k8s-vectordb-sync after scaffolding

## Architecture Decisions

### Decision 1: Makefile-First Detection for Go

**Date**: 2026-02-20
**Decision**: When a Go project has a Makefile, prefer Makefile targets (`make build`, `make lint`, `make test`) over raw Go commands. Fall back to Go CLI commands when no Makefile exists.
**Rationale**: Kubebuilder and most Go projects use Makefiles as the standard build orchestration layer. Makefile targets often include additional setup (code generation, manifests, etc.) that raw `go build` would miss. This matches how developers actually build Go projects.
**Impact**: `detect-project.sh` checks for Makefile targets first, falls back to `go build ./...` etc.

### Decision 2: golangci-lint as Primary Linter

**Date**: 2026-02-20
**Decision**: Use `golangci-lint` as the primary Go linter when available, fall back to `go vet` when it's not installed.
**Rationale**: `golangci-lint` is the standard Go meta-linter that runs `go vet` plus dozens of additional checks. It supports `--new-from-rev` for diff-scoped linting (analogous to ESLint on changed files). `go vet` alone is useful but limited.
**Impact**: `detect-project.sh` checks `command -v golangci-lint`, lint-changed.sh uses `--new-from-rev` for scoping.

### Decision 3: Go Build Implies Typecheck

**Date**: 2026-02-20
**Decision**: For Go projects, `CMD_TYPECHECK` is left empty because `go build` already performs full type checking.
**Rationale**: Unlike TypeScript where build and typecheck are separate steps (`tsc --noEmit` vs `npm run build`), the Go compiler does type checking as part of compilation. Running a separate typecheck phase would be redundant.
**Impact**: Pre-commit hook runs Build (go build) → Lint (golangci-lint), skipping the typecheck phase.

### Decision 4: Build Tag Convention for Test Tiers

**Date**: 2026-02-20
**Decision**: Detect Go integration tests via `//go:build integration` build tags, and e2e tests via `//go:build e2e` tags or envtest/Kind usage.
**Rationale**: Go's build tag system is the idiomatic way to separate test tiers. `go test ./...` runs unit tests by default; `go test -tags=integration ./...` adds integration tests. This is the convention used by Kubebuilder controller-runtime projects.
**Impact**: `detect-test-tiers.sh` greps for build tags and envtest imports.

## Content Location Map

All changes are within the existing claude-config verification infrastructure:

| Component | File | Change Type |
|-----------|------|-------------|
| Command detection | `.claude/skills/verify/scripts/detect-project.sh` | Extend |
| Lint scoping | `.claude/skills/verify/scripts/lint-changed.sh` | Extend |
| Test tier detection | `.claude/skills/verify/scripts/detect-test-tiers.sh` | Extend |
| Security checks | `.claude/skills/verify/scripts/security-check.sh` | Extend |
| Go language rules | `rules/languages/go.md` | Populate |
| Tests | `.claude/skills/verify/tests/` | New test files |

## Implementation Milestones

### Milestone 1: Go Command Detection in detect-project.sh
- [x] Add Go command detection block (parallel to the Node.js block at lines 69-123)
- [x] Detect Makefile targets: `make build`, `make lint`, `make test`, `make vet`
- [x] Fall back to Go CLI: `go build ./...`, `go vet ./...`, `go test ./...`
- [x] Detect `golangci-lint` availability and prefer it over `go vet` for lint command
- [x] Leave `CMD_TYPECHECK` empty (Decision 3: go build implies typecheck)
- [x] Write tests validating Go detection with and without Makefile

### Milestone 2: Go Lint Scoping in lint-changed.sh
- [x] Extend file extension filter to include `.go` files
- [x] Add Go linter detection (golangci-lint config, or fall back to go vet)
- [x] Implement diff-scoped Go linting using `golangci-lint run --new-from-rev=<ref>` for branch scope
- [x] For staged scope, lint changed `.go` files directly: `golangci-lint run <files>`
- [x] Write tests validating Go lint scoping

### Milestone 3: Go Test Tier Detection in detect-test-tiers.sh
- [ ] Add Go test tier detection block (parallel to Node.js and Python blocks)
- [ ] Unit: detect `_test.go` files without integration/e2e build tags
- [ ] Integration: detect `//go:build integration` tags or `tests/integration/` directory
- [ ] E2E: detect `//go:build e2e` tags, envtest usage, or Kind cluster setup
- [ ] Write tests validating Go test tier detection

### Milestone 4: Go Security Checks and Language Rules
- [ ] Extend `security-check.sh` debug code patterns to Go files (`fmt.Println`, `fmt.Printf` in non-main packages, `log.Print` without structured logger)
- [ ] Populate `rules/languages/go.md` with patterns from real Kubebuilder usage
- [ ] Ensure `.verify-skip` and eslint-disable equivalents work for Go (e.g., `//nolint` comments)

### Milestone 5: Integration Validation Against k8s-vectordb-sync
- [ ] Run full verification suite against k8s-vectordb-sync after Kubebuilder scaffolding
- [ ] Verify pre-commit hook detects and runs Go build + lint
- [ ] Verify pre-push hook runs Go tests
- [ ] Verify test tier warnings are accurate
- [ ] Fix any edge cases discovered during real-project validation

## Dependencies

- **k8s-vectordb-sync** — Real Go project for validation (Milestone 5). Must have `go.mod` and basic scaffolding before M5 can run.
- **golangci-lint** — Must be installed on dev machine for full lint support. Detection should gracefully fall back to `go vet` when unavailable.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Makefile target names vary across projects | Medium | Medium | Check common targets (`build`, `lint`, `test`, `vet`), don't assume non-standard names |
| golangci-lint not installed on all machines | Medium | Low | Graceful fallback to `go vet`; document golangci-lint as recommended |
| Go build tags for test tiers not universally adopted | Low | Medium | Also check directory conventions (`tests/integration/`, `tests/e2e/`) as fallback |
| fmt.Println false positives in CLI main packages | Medium | Medium | Only flag `fmt.Print*` in non-main packages; skip files with `package main` |

## Out of Scope

- Python/Rust command detection (separate PRD if needed)
- CI/CD pipeline configuration for Go projects (belongs in k8s-vectordb-sync PRD)
- Go module proxy or dependency management tooling
- IDE integration or editor-specific Go tooling
