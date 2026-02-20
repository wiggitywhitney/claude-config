---
paths: ["**/*.go", "**/go.mod", "**/.golangci.yml"]
---

# Go Rules

Rules for Go projects, particularly Kubebuilder/controller-runtime. Focuses on patterns AI models are likely to get wrong due to recent breaking changes.

## Versions (as of Feb 2026)

- Go: **1.24+** minimum for new projects (1.26 is current stable)
- golangci-lint: **v2.x** (v1 is EOL — v2 config format is incompatible)
- Kubebuilder: **v4.12**, controller-runtime: **v0.23**

## golangci-lint v2 (Breaking Change)

golangci-lint v2 uses an entirely different config format from v1. Every v1 config the model generates is wrong.

- Config files MUST start with `version: "2"`.
- `enable-all` / `disable-all` are gone. Use `linters.default: all` or `linters.default: none`.
- Formatters (`gofmt`, `goimports`, `gofumpt`, `gci`) moved to a separate `formatters:` section.
- `stylecheck`, `gosimple`, and `staticcheck` merged into a single `staticcheck` linter.
- `issues.exclude-dirs-use-default` removed — use `linters.exclusions.paths` instead.
- `${configDir}` replaced by `${base-path}`.
- Migrate old configs with: `golangci-lint migrate`.

## Tool Management (Go 1.24+)

The `tools.go` pattern (blank imports for build tools) is obsolete. Use the `tool` directive in `go.mod`:

```go
// go.mod
tool (
    github.com/golangci/golangci-lint/cmd/golangci-lint
    sigs.k8s.io/controller-tools/cmd/controller-gen
)
```

Add tools with `go get -tool <pkg>@<version>`. Run with `go tool <name>`.

## Concurrency

- Use `wg.Go(func() { ... })` instead of `wg.Add(1)` + `go func` + `defer wg.Done()` (Go 1.25+).
- Use `runtime.AddCleanup` instead of `runtime.SetFinalizer` (Go 1.24+). AddCleanup handles cycles and supports multiple cleanups per object.

## Pointers and new()

Go 1.26 allows `new(expression)`: `new(true)`, `new(42)`, `new("value")`. Use this instead of creating temporary variables to take their address — common in Kubernetes API types with pointer fields.

## Build Tags

- Use only `//go:build`. Never generate `// +build` lines — deprecated since Go 1.17.
- Test tiers: `//go:build integration`, `//go:build e2e` to separate test categories.

## Testing

- Use `t.Context()` instead of manual `context.WithCancel` + `t.Cleanup(cancel)` (Go 1.24+).
- Use `testing/synctest` for deterministic concurrent tests (stable in Go 1.25+). Provides fake clocks and goroutine isolation — ideal for controller reconciliation loops.
- Separate test tiers with build tags: unit (default), integration (`-tags=integration`), e2e (`-tags=e2e`).

## Logging (Kubebuilder)

- Use `logr` as the primary logging interface in controller-runtime projects.
- `slogr` package is deprecated. Use `logr.FromSlogHandler()` directly for slog bridge.
- Do not use `fmt.Println` or `log.Print` in library packages — use structured logging.

## Kubernetes Containers

- Go 1.25+ auto-tunes `GOMAXPROCS` to cgroup CPU limits on Linux. The `automaxprocs` package is no longer needed for new projects targeting Go 1.25+.

## Error Handling

- Use `errors.Join` for accumulating errors in loops (not `go.uber.org/multierr`).
- The joined error supports `errors.Is` and `errors.As` across all wrapped errors.

## Code Modernization

Run `go fix ./...` (Go 1.26) to auto-modernize code: `slices.Contains` over manual loops, `maps.Copy`/`Clone` over loops, `strings.CutPrefix` over `HasPrefix`+`TrimPrefix`, `wg.Go` over `Add`+`go`+`Done`, `t.Context()` over manual cancel, and more.
