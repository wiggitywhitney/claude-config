---
paths: ["**/evaluation/**", "**/otelcol*.y*ml", "**/*.vals.yaml"]
---

# IS Scoring — OTel Collector Setup Gotchas

IS scoring runs the target app against an OTel Collector to capture OTLP traces, then scores them with `evaluation/is/score-is.js`. The Collector writes traces to `eval-traces.json` for IS scoring **and** forwards them to Datadog APM via the Datadog exporter — both exporters run in parallel.

The Datadog Agent's embedded OTLP HTTP receiver has been permanently disabled in `/opt/datadog-agent/etc/datadog.yaml` (the `http:` block removed from `otlp_config.receiver.protocols`). `otelcol-contrib` owns port 4318 without interference — no Agent stop/start required before or after a scoring run.

## Preferred: Binary download (no Docker required)

Download `otelcol-contrib` for macOS ARM64 from the [releases page](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases). Place on PATH (e.g., `~/.local/bin/`). Run from the eval repo root with `vals exec` to inject `DD_API_KEY`:

```bash
vals exec -f .vals.yaml -- bash -c 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH" && otelcol-contrib --config evaluation/is/otelcol-config.yaml > /tmp/otelcol.log 2>&1' &
```

This writes traces to `evaluation/is/eval-traces.json` and forwards them to Datadog APM. After the run, query `service:<target>` in Datadog MCP to retrieve `service.instance.id` for trace verification.

## Fallback: Docker via Colima

**Always check Colima is running first** — Claude Code sessions don't start it automatically.

Four flags are all required together or the container crashes / Datadog export fails:

```bash
vals exec -f .vals.yaml -- bash -c 'docker run -d --name eval-collector -p 4318:4318 -e DD_API_KEY=$DD_API_KEY --user "$(id -u):$(id -g)" -w /etc/otelcol -v /absolute/path/to/evaluation/is:/etc/otelcol otel/opentelemetry-collector-contrib:latest --config /etc/otelcol/otelcol-config.yaml'
```

- `vals exec` — injects `DD_API_KEY` into the environment; without it the Datadog exporter starts but sends nothing (empty API key, silent failure)
- `-e DD_API_KEY=$DD_API_KEY` — passes the injected key into the container
- `--user $(id -u):$(id -g)` — container runs as host user; without it, root can't write to host-owned mount
- `-w /etc/otelcol` — sets working dir inside container so `./eval-traces.json` resolves to the mounted volume; without it, the file exporter tries to write to the container root (`/eval-traces.json`) and fails with permission denied
- **Absolute path for the volume mount** — `$(pwd)` expansion is unreliable in some shell contexts; use the full path

**Pre-create the output file** before starting the container:

```bash
touch evaluation/is/eval-traces.json
```

## `otelcol-config.yaml` is the single shared config for all eval targets

`spinybacked-orbweaver-eval/evaluation/is/otelcol-config.yaml` is used for every IS scoring run, regardless of the target repo (commit-story-v2, taze, any future target). Changes to this file apply globally — fix it once, it applies everywhere. Do not remove or replace the file exporter when adding new exporters — both must run in parallel.

## OTel SDK packages for target apps

The target app's `examples/instrumentation.js` requires the full OTel SDK (not just the API). Install as devDependencies on the instrumented branch before running IS scoring:

```bash
npm install --save-dev @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-http @opentelemetry/sdk-trace-base @opentelemetry/resources
```

These are not committed — install only for the IS scoring run, then restore the branch.

## Persistent collector via macOS LaunchAgent (2026-07-08+)

`otelcol-contrib` now runs as a `launchd` LaunchAgent (`~/Library/LaunchAgents/com.whitney.otelcol-contrib.plist`, label `com.whitney.otelcol-contrib`) with `RunAtLoad` and `KeepAlive` both `true`. It survives crashes (auto-respawns) and should already be listening on port 4318 in virtually every session — the manual start step below is now a fallback for when the LaunchAgent isn't loaded, not the normal path.

Three gotchas surfaced building this LaunchAgent, all specific to running `vals exec`/`otelcol-contrib` under `launchd` rather than an interactive shell:

- **`vals exec` strips `PATH` for its own subprocess even when `PATH` was exported in the outer shell first.** Exporting `PATH="/opt/homebrew/bin:$PATH"` before `vals exec -- otelcol-contrib ...` still fails with `executable file not found in $PATH` — the export doesn't propagate into the environment `vals exec` builds for the command after `--`. Fix: nest a second `bash -c` *inside* `vals exec --` and re-export `PATH` there: `vals exec -f .vals.yaml -- bash -c 'export PATH="..." && otelcol-contrib ...'`. This is the same pattern documented above for plain `bash -c` contexts — confirmed to also apply when the outer process is a `launchd` job.
- **`otelcol-contrib` may actually be installed at `~/.local/bin`, not `/opt/homebrew/bin`** — verify with `which otelcol-contrib` rather than assuming the Homebrew path. Add whichever directory it's actually in to the `PATH` export (both directories is safest).
- **`launchd`'s default working directory is `/` (read-only on macOS) when no `WorkingDirectory` key is set.** The shared `otelcol-config.yaml` file exporter uses a relative path (`./eval-traces.json`), which under `launchd`'s default cwd resolves to `/eval-traces.json` and fails with `read-only file system`. Fix: add a `WorkingDirectory` key to the plist pointing at the directory containing `otelcol-config.yaml` (`~/Documents/Repositories/spinybacked-orbweaver-eval/evaluation/is`). A stray `eval-traces.json` file appearing in an unrelated repo's root is a symptom of this same issue from a past manual start — the collector was launched with that repo as cwd.
- **`WorkingDirectory` (and other plain plist string values) are NOT shell-expanded by `launchd`** — a literal absolute path is required. This differs from the `ProgramArguments` array entries above, which are handed to `/bin/bash -c` and therefore DO expand `$HOME`/env vars, because bash does the expanding, not launchd. Writing `$HOME/...` directly into `WorkingDirectory` (or any other plain `<string>` value outside a `bash -c` argument) fails silently with launchd falling back to its default cwd (`/`) rather than erroring — easy to miss since the symptom looks identical to the "no `WorkingDirectory` key set" case above.

Debug with `launchctl list com.whitney.otelcol-contrib` (shows `PID`, `LastExitStatus`) and the log at `/tmp/otelcol-contrib.log`. Reload after editing the plist: `launchctl unload ~/Library/LaunchAgents/com.whitney.otelcol-contrib.plist && launchctl load ~/Library/LaunchAgents/com.whitney.otelcol-contrib.plist`.

## Full sequence for a scoring run

Check if otelcol-contrib is already running (the LaunchAgent above should mean this is almost always true):
```bash
lsof -i :4318 -sTCP:LISTEN
```
If the output shows `otelcol-c` (otelcol-contrib) as the listening process, skip the start step below — the existing instance is ready. If a different process holds the port, that's a stale or unrelated listener — do not reuse it; resolve the conflict before starting the collector.

If otelcol-contrib is not running (the LaunchAgent isn't loaded), start it manually as a fallback — use `vals exec` to inject `DD_API_KEY`:
```bash
vals exec -f ~/Documents/Repositories/spinybacked-orbweaver-eval/.vals.yaml -- bash -c 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH" && otelcol-contrib --config ~/Documents/Repositories/spinybacked-orbweaver-eval/evaluation/is/otelcol-config.yaml > /tmp/otelcol.log 2>&1' &
COLLECTOR_PID=$!
until lsof -i :4318 >/dev/null 2>&1; do sleep 0.5; done
```

Or via Docker (see flags above) with `DD_API_KEY` injected:
```bash
vals exec -f ~/Documents/Repositories/spinybacked-orbweaver-eval/.vals.yaml -- bash -c 'docker run -d --name eval-collector -p 4318:4318 -e DD_API_KEY=$DD_API_KEY --user "$(id -u):$(id -g)" -w /etc/otelcol -v /absolute/path/to/evaluation/is:/etc/otelcol otel/opentelemetry-collector-contrib:latest --config /etc/otelcol/otelcol-config.yaml'
```

Checkout instrument branch and install SDK:
```bash
git -C ~/Documents/Repositories/<target> checkout <instrument-branch>
npm --prefix ~/Documents/Repositories/<target> install --save-dev @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-http @opentelemetry/sdk-trace-base @opentelemetry/resources
```

Run the target app with instrumentation (from the target repo directory):
```bash
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces node --import ./examples/instrumentation.js ./bin/<entrypoint>.js --dry-run
```

Score and save:
```bash
node evaluation/is/score-is.js evaluation/is/eval-traces.json --target <target> > evaluation/<target>/run-<N>/is-score.md
```

Clean up:
```bash
if [ -n "${COLLECTOR_PID:-}" ]; then kill "$COLLECTOR_PID"; fi
git -C ~/Documents/Repositories/<target> checkout main
```

If you used Docker instead of the binary collector, run: `docker stop eval-collector && docker rm eval-collector`

## What the score means

- **90/100** is achievable with only 3 committed files (release-it run-3: 4 INTERNAL spans, 7/8 rules pass)
- **RES-001** (service.instance.id absent) is a common miss — the bootstrap sets `service.name` and `service.version` but not `service.instance.id`
- **SPA-001** (INTERNAL spans) — global default is 30; per-target overrides in `SPA001_PER_TARGET_LIMITS`: `taze` → not_applicable (null), `commit-story-v2` → 55 (max observed 48 in run-24). Pass `--target <name>` to the CLI to activate per-target thresholds.
- **MET rules** are always "not applicable" for CLI apps that produce no OTel metrics
- Applicable rules: ~8 of 15; skipped: ~7 (multi-instance, k8s, metrics)
