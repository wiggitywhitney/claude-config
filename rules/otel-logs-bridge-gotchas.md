---
paths: ["**/instrumentation.*", "**/logger.*", "**/*otel*", "**/package.json"]
---

# OTel Logs Bridge API Gotchas (Node.js)

Verified 2026-06-16 against opentelemetry.io spec, npm package docs, and opentelemetry-js GitHub. Applies when adding OTel log-trace correlation to a Node.js project.

## `@opentelemetry/sdk-logs` is still experimental — not GA in June 2026

The package lives in `experimental/packages` in the opentelemetry-js repo and is versioned at `>=0.200.x` (the project's unstable versioning scheme). Breaking changes between releases are explicitly possible.

`@opentelemetry/api-logs` is also experimental (alpha). When the logs signal is promoted to stable, `api-logs` will be deprecated in favor of `@opentelemetry/api`.

**Do not assume GA/stable for either package.** Check the [opentelemetry-js releases](https://github.com/open-telemetry/opentelemetry-js) before committing to a version in production.

## `console.log` has NO automatic bridge — manual-only path

The Logs Bridge API's automatic trace context injection only works for supported structured logging libraries: winston (`@opentelemetry/instrumentation-winston`), pino (`@opentelemetry/instrumentation-pino`), bunyan (`@opentelemetry/instrumentation-bunyan`). There is no `@opentelemetry/instrumentation-console` package.

For `console.log`/`console.error`, trace context must be extracted manually:

```js
const api = require('@opentelemetry/api');
const span = api.trace.getSpan(api.context.active());
if (span) {
  const { traceId, spanId, traceFlags } = span.spanContext();
  console.log(JSON.stringify({ msg: 'text', trace_id: traceId, span_id: spanId }));
}
```

Manual injection only requires `@opentelemetry/api`. Logs are NOT routed through the OTel SDK pipeline — they go to stdout. A Datadog Agent or Collector `filelog` receiver must parse them from there.

## SDK must be initialized before logging libraries load

The instrumentation packages (winston, pino, bunyan) patch the logging library at load time. If the logging library is `require()`d before `sdk.start()` is called, the bridge is not installed and no trace context is injected. Always initialize OTel before any other module loads:

```js
// instrumentation.js — loaded FIRST via --require or --import
const sdk = new NodeSDK({ ... });
sdk.start();
// Only after this do other modules load
```

## Automatic injection uses `LogRecord` objects routed through OTLP — different pipeline from stdout logs

When using a supported logger (winston/pino), the bridge creates `LogRecord` objects that flow through `LogRecordProcessor` → `LogRecordExporter` → OTLP. These are a separate pipeline from stdout/stderr. A Collector or backend configured for OTLP log ingestion receives them — but stdout is untouched.

This means you may end up with logs in two places (OTLP pipeline AND stdout) depending on instrumentation config. Check the instrumentation package's options for a flag to suppress SDK-route forwarding for specific transports if you want to avoid duplication.

## Multiple `@opentelemetry/api-logs` versions share the same global — version conflict is NOT a blocker

When `@opentelemetry/instrumentation-pino@0.65.0` is installed alongside `@opentelemetry/sdk-node@0.213.0`, npm installs two separate copies of `api-logs`: 0.213.0 (hoisted) and 0.219.0 (nested inside instrumentation-pino). Despite this, `logs.setGlobalLoggerProvider()` from either version sets the provider that both can see, because both use `Symbol.for('io.opentelemetry.js.api.logs')` as the registry key on `globalThis`. The `API_BACKWARDS_COMPATIBILITY_VERSION = 1` is identical in both versions, so the getter resolves correctly. Do NOT add an `overrides` entry for `@opentelemetry/api-logs` to force a single version — it is unnecessary and may introduce its own compatibility issues. Verified in commit-story-v2 June 2026.

## `traceBased` filter silently drops logs from unsampled traces

`LoggerProvider` supports `{ traceBased: true }` per logger pattern. When enabled, any log emitted outside an active sampled span is dropped entirely. This reduces volume but can silently discard startup/shutdown logs and background job logs that run outside a trace.
