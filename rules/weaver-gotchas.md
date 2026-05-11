# Weaver Gotchas

## v0.22.1 breaking changes (released 2026-03-13)

### Template auto-escaping is now off by default

Previously, Weaver inferred whether to auto-escape based on the template file extension (e.g., `.html` got HTML escaping). As of v0.22.1, auto-escaping is **off by default regardless of extension**. When writing templates that produce HTML or JSON output, explicitly set the escaping mode per-template in `weaver.yaml`:

```yaml
# weaver.yaml — auto_escape is set per-template entry (v0.22.1+)
templates:
  - pattern: "*.html"
    auto_escape: html
  - pattern: "*.json"
    auto_escape: json
  - pattern: "*.txt"
    auto_escape: none
```

If templates are written assuming the old extension-based behavior, output will be unescaped silently — no error, just wrong output.

### Definition schema v2 files must use `file_format`

Any definition schema file that previously declared `version: "2"` must be updated to use:

```yaml
file_format: definition/2
```

The old `version: "2"` key is no longer recognized. Weaver will not error loudly — it will silently ignore or misparse the file.

## Registry dependency import syntax (weaver 0.21.2)

`dependencies:` in `registry_manifest.yaml` declares a dependency on another registry (e.g., OTel semconv):
```yaml
dependencies:
  - name: otel
    registry_path: https://github.com/open-telemetry/semantic-conventions@v1.29.0[model]
```
- Only **one dependency** is supported in weaver 0.21.2.
- Deprecated `semconv_version` + `schema_base_url` format is still accepted but emits warnings.

**`imports: attribute_groups: [wildcard]` is schema-invalid in weaver 0.21.2.** The field `attribute_groups` is not recognized — adding it causes an immediate diagnostic error. Do not use this syntax.

**`--include-unreferenced` produces ~5MB payload from OTel semconv** — completely unsuitable for LLM agent context. Do not pass to production `resolveSchema` calls.

**`extends: <group-id>` works** for pulling specific OTel attribute groups into a local group, but requires knowing exact group IDs — no wildcards.

**Consequence for spiny-orb**: dependency attributes only appear in `weaver registry resolve` output if the local registry has explicit `ref:` or `extends:` references to specific groups. A bare `dependencies:` entry with no local references produces an empty resolved schema (unless `--include-unreferenced` is used, which is impractical).

## Spawning Weaver as a subprocess — always pass HOME explicitly

When code spawns `weaver` as a child process (e.g., via `execFile` or `execFileSync`), Weaver needs `HOME` to locate `~/.weaver/vdir_cache` for dependency caching. If HOME is not explicitly passed in the subprocess env options, Weaver cannot cache downloaded registry dependencies and will hang on the network request — silently, with no useful error.

**Do not rely on env inheritance.** Some launchers (e.g., `caffeinate -s`, `vals exec -i`) strip or do not propagate HOME to child processes. Always pass it explicitly. When HOME is missing, Weaver hangs on the OTel semconv dependency download; `execFileSync` eventually fires with `error.code === 'ETIMEDOUT'` — treat this as a HOME propagation failure, not a schema error.

```typescript
import { homedir } from 'node:os';

execFileSync('weaver', ['registry', 'check', '-r', registryPath], {
  env: { ...process.env, HOME: process.env.HOME || homedir() },
  timeout: 30000,
  stdio: 'pipe',
});
```

This applies to every `execFile` / `execFileSync` / `spawn` call that invokes the `weaver` binary. The end-user does not need to configure anything — this is a code-level responsibility.

## `weaver registry live-check --format` is space-separated, not `=`

The output format flag is `--format json` (space-separated), **not** `--format=json`. The `=` form fails silently or errors depending on Weaver version.

`--diagnostic-format` is a different flag that controls startup diagnostic loading messages — not the compliance report output. Do not confuse the two.

**Weaver 0.21.2 JSON output shape** (single JSON object, both keys at top level):
```json
{"samples": [...], "statistics": {"total_entities": N, "total_entities_by_type": {"span": N}, ...}}
```
- `statistics.total_entities === 0` → no spans received
- `statistics.total_entities_by_type.span` → span count
- `statistics.total_advisories` → total policy findings (0 = fully compliant)
- `registry_coverage: 1.0` does NOT mean compliant — attributes can still have advisories

**Weaver 0.22.1 changed the output format (breaking):** Streams individual entity JSON objects to stdout as spans arrive, then writes the statistics object LAST as a standalone JSON. The statistics are no longer wrapped in a `"statistics"` key:

```jsonl
{"resource": {"attributes": [...], "live_check_result": {...}}}
{"span": {"name": "...", ...}}
...
{"total_entities": N, "total_entities_by_type": {"span": N}, "total_advisories": N, ...}
```

To parse: find the LAST JSON object in stdout and look for `total_entities` at the top level. `parseComplianceReport` in `src/coordinator/live-check.ts` handles both formats.

**The `/stop` HTTP endpoint returns "OK" in 0.22.1, not the compliance report.** The actual report streams to stdout during Weaver shutdown. Do NOT rely on the HTTP response body for the compliance data. Read stdout instead, and wait for the Weaver process to fully exit before reading it (the statistics object is written during shutdown, after the HTTP response).

**Race condition with SDK-based telemetry:** When the test command exits, async gRPC spans may still be in transit. Calling `/stop` immediately after the test process exits causes "OK" with no data because Weaver hasn't received the spans yet. Add a 2-second delay between the test process exit and the `/stop` call to allow gRPC data to arrive and be processed.

**Weaver binary location:** Installed by the Weaver installer script to `~/.cargo/bin/weaver`. Not in standard system PATH. When running under launchers that strip PATH (e.g., `vals exec` strips to minimal PATH and clears `HOME`), weaver will not be found. Use `os.homedir()` (not `$HOME`) to construct the path, and add `~/.cargo/bin` to `process.env.PATH` before spawning weaver.

## spinybacked-orbweaver context

This project uses `weaver registry resolve/diff/live-check` only. No templates or definition schema files exist yet. When codegen is added (planned for a future PRD), write all templates and configuration targeting v0.22.1 behavior from the start — do not assume old defaults.
