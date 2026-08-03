---
paths: ["**/*pino*", "**/logger.*", "**/instrumentation.*", "**/package.json"]
---

# Pino Gotchas

Verified 2026-06-19 against pino v10.3.1, @opentelemetry/instrumentation-pino v0.65.0, import-in-the-middle v3.0.0, and @opentelemetry/sdk-node v0.213.0 on Node.js v22+.

## IITM ESM loader hook is required for log-trace correlation on Node v22+

`@opentelemetry/instrumentation-pino` uses `import-in-the-middle` (IITM) to intercept pino's module load and inject `trace_id`/`span_id` into log records. On Node.js v22+, ESM-imported CJS modules like pino do NOT route through `require-in-the-middle` hooks automatically — the IITM ESM loader hook must be registered explicitly before any application code imports pino.

**Symptom**: `PinoInstrumentation` is initialized, spans are active, but pino log records have no `trace_id` or `span_id`. No error is thrown. This silently fails on Node v22+.

**Root cause**: IITM v3.x changed the hook registration API. The OTel SDK creates Hook instances internally, but in ESM contexts on Node v22+, `Hook.sendModulesToLoader` is null unless a message channel has been established via `module.register()` first.

**Fix**: Call this before `sdk.start()` in the `--import` bootstrap file:

```js
import { register } from 'node:module';
import { createAddHookMessageChannel } from 'import-in-the-middle';

const { registerOptions, waitForAllMessagesAcknowledged } = createAddHookMessageChannel();
register('import-in-the-middle/hook.mjs', import.meta.url, registerOptions);
await waitForAllMessagesAcknowledged();

// NOW sdk.start() — pino will be intercepted when app code imports it
sdk.start();
```

Also add `import-in-the-middle` as an explicit runtime dependency (not devDependency) — the `--import` bootstrap needs it at production startup, and production installs commonly prune devDependencies. It is a transitive dep via `@opentelemetry/instrumentation-pino`, but declaring it explicitly pins the version, makes the dependency relationship visible, and guarantees it survives a devDependency-pruned install.

This pattern applies to any OTel instrumentation that intercepts ESM-imported CJS modules on Node v22+.

## pino v10 is current — not v9

Training data may suggest pino v9 as the latest. As of Feb 2026, pino v10.3.1 is current. Only breaking change from v9: drops Node 18.0–18.18 support.

pino v10 requires `^18.19.0 || >=20.6.0`. If a project's `engines` field says `>=18.0.0`, update it.

## @opentelemetry/instrumentation-pino supports pino v10

The older README (v0.46.1) shows `>=5.14.0 <10` — this is stale. The current main branch supports `>=5.14.0 <11`. Current npm version: 0.65.0. Pino v10 is supported.

"Log sending" (OTLP export) requires pino v7+. "Log correlation" (trace_id/span_id injection) requires v5.14.0+.

## pino is CJS but ESM default import works

`import pino from 'pino'` works in `"type": "module"` projects. The ESM friction only appears with `pino.transport()` (worker-thread transports), which use `thread-stream` and have `__dirname`-undefined issues in ESM. For stdout logging without a custom transport, there is no issue.

## MCP server constraint: must NOT use the shared stdout logger

MCP servers use stdio transport — stdout carries JSON-RPC messages. Any logging via pino (which defaults to stdout) will corrupt the protocol. Configure a separate logger for MCP server use:

```js
import pino from 'pino';
const logger = pino({ level: 'info' }, process.stderr); // second arg = destination stream
```

## Error serialization: first-arg pattern is idiomatic

Both are equivalent — prefer the first form:
```js
logger.error(err, 'message');          // idiomatic: Error auto-wraps into { err }
logger.error({ err }, 'message');     // explicit
```

Passing an Error as the first argument (merging object) produces an `err` field in the JSON output containing `type`, `message`, and `stack`. The second argument must be the message string.

## Default JSON output format

```json
{"level":30,"time":1531257112193,"msg":"hello world","pid":55956,"hostname":"x"}
```

- Level is numeric: trace=10, debug=20, info=30, warn=40, error=50, fatal=60
- pid and hostname are auto-added; suppress with `base: null`
- No transport config needed for stdout JSON — it's the default

## Shared logger module (ESM)

```js
// src/logger.js
import pino from 'pino';
export default pino({ level: process.env.LOG_LEVEL ?? 'info' });
```
