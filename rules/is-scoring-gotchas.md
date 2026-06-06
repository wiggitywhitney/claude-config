# IS Scoring — OTel Collector Setup Gotchas

IS scoring runs the target app against an OTel Collector to capture OTLP traces, then scores them with `evaluation/is/score-is.js`. The Collector writes traces to `eval-traces.json` for IS scoring **and** forwards them to Datadog APM via the Datadog exporter — both exporters run in parallel.

## Preferred: Binary download (no Docker required)

Download `otelcol-contrib` for macOS ARM64 from the [releases page](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases). Place on PATH (e.g., `~/.local/bin/`). Run from the eval repo root with `vals exec` to inject `DD_API_KEY`:

```bash
vals exec -f .vals.yaml -- bash -c 'export PATH="/opt/homebrew/bin:$PATH" && otelcol-contrib --config evaluation/is/otelcol-config.yaml > /tmp/otelcol.log 2>&1' &
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

## Port 4318 Conflict with Datadog Agent

The Datadog Agent occupies port 4318. Stop it first; restart after.

```bash
datadog-agent stop
```

```bash
datadog-agent start
```

Both work without sudo. `sudo launchctl stop/start com.datadoghq.agent` also works but is unnecessary.

## OTel SDK packages for target apps

The target app's `examples/instrumentation.js` requires the full OTel SDK (not just the API). Install as devDependencies on the instrumented branch before running IS scoring:

```bash
npm install --save-dev @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-http @opentelemetry/sdk-trace-base @opentelemetry/resources
```

These are not committed — install only for the IS scoring run, then restore the branch.

## Full sequence for a scoring run

```bash
datadog-agent stop
```

Start the Collector (binary preferred) — use `vals exec` to inject `DD_API_KEY`:
```bash
vals exec -f ~/Documents/Repositories/spinybacked-orbweaver-eval/.vals.yaml -- bash -c 'export PATH="/opt/homebrew/bin:$PATH" && otelcol-contrib --config ~/Documents/Repositories/spinybacked-orbweaver-eval/evaluation/is/otelcol-config.yaml > /tmp/otelcol.log 2>&1' &
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
node evaluation/is/score-is.js evaluation/is/eval-traces.json > evaluation/<target>/run-<N>/is-score.md
```

Clean up:
```bash
kill $COLLECTOR_PID
git -C ~/Documents/Repositories/<target> checkout main
datadog-agent start
```

For Docker cleanup instead: `docker stop eval-collector && docker rm eval-collector`

## What the score means

- **90/100** is achievable with only 3 committed files (release-it run-3: 4 INTERNAL spans, 7/8 rules pass)
- **RES-001** (service.instance.id absent) is a common miss — the bootstrap sets `service.name` and `service.version` but not `service.instance.id`
- **SPA-001** (≤10 INTERNAL spans) — the calibration is 10 spans; small instrumented sets pass easily
- **MET rules** are always "not applicable" for CLI apps that produce no OTel metrics
- Applicable rules: ~8 of 15; skipped: ~7 (multi-instance, k8s, metrics)
