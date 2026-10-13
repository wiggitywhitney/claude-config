---
paths: ["**/*traceloop*", "**/*openllmetry*", "**/instrumentation.*", "**/sdk-init*", "**/package.json"]
---

# Traceloop (OpenLLMetry JS) Instrumentation Gotchas

Verified 2026-10-08 against `@traceloop/instrumentation-*` 0.27.0 on Node 25.8.0, using a fake local model server rather than real API calls. Applies when wiring a standalone `@traceloop/instrumentation-*` package into an OTel Node SDK setup, not when using `@traceloop/node-server-sdk`'s own `initialize()`. Source of record: spinybacked-orbweaver's `docs/research/openllmetry-traceloop-status-2026-10.md`.

## Under ESM on a current OTel SDK, the module hook never fires

Every `@traceloop/instrumentation-*` 0.27.0 package pins `@opentelemetry/instrumentation` `^0.203.0`, which brings its own `import-in-the-middle` 1.15.0. A current SDK (`@opentelemetry/sdk-node` 0.223.0) hoists `@opentelemetry/instrumentation` 0.223.0 and `import-in-the-middle` 3.5.2. The ESM loader hook an app registers, `register('@opentelemetry/instrumentation/hook.mjs', import.meta.url)`, is the hoisted copy, and the Traceloop package's nested copy never sees the import.

- ESM, hoisted loader hook registered: **0 spans.** No error is raised.
- ESM, Traceloop's own nested copy of `hook.mjs` registered instead: 1 span. That result confirms the version skew is the cause.
- CommonJS: the `require` hook works, 1 span.

**Do NOT count on the app's loader hook to instrument a `@traceloop` package under ESM.** To confirm the skew in a given project, run `npm ls @opentelemetry/instrumentation`: a nested `0.203.x` under a `@traceloop/instrumentation-*` package beside a hoisted current version is this case.

**The working ESM path is an explicit `manuallyInstrument(<sdk module>)` call** on the same instance that is in the SDK's `instrumentations` array. It produced 1 span with no loader hook. With both the hook and `manuallyInstrument`, there was still 1 span and no double-wrapping, though that was checked on `@traceloop/instrumentation-anthropic` only.

For comparison, `@opentelemetry/instrumentation-openai` 0.21.0 pins the current `@opentelemetry/instrumentation` and has no `manuallyInstrument` at all. Under ESM it needs the loader hook: 0 spans without it, 1 with it.

## `manuallyInstrument()` takes a different argument in every package, and a bare call throws

Calling `manuallyInstrument()` with no argument throws for 12 of the 13 packages. There is no generic call shape, so check this table before writing one. The table is for 0.27.0. These packages are pre-1.0, and earlier minor versions have changed the argument, so re-check the installed `.d.ts` after any upgrade:

| Package | Argument that wraps the SDK |
|---|---|
| anthropic, bedrock, vertexai, cohere, llamaindex, pinecone, qdrant | the ESM namespace (`import * as sdk from '...'`) |
| openai, together | the default export |
| mcp | `{ Client }` from `@modelcontextprotocol/sdk/client/index.js`. The class is `McpInstrumentation`, not `MCPInstrumentation` |
| google-generativeai | the CommonJS module, via `createRequire(import.meta.url)('@google/genai')`. The class is `GenAIInstrumentation` |
| langchain | `{ callbackManagerModule }`. Its constructor already patches `CallbackManager` by itself, which is why LangChain apps produce spans without this call |
| chromadb | none: **`@traceloop/instrumentation-chromadb` is a no-op** and wraps nothing. The bare call succeeds only because the method body is empty |

## Standalone instrumentations ignore `TRACELOOP_TRACE_CONTENT`

The environment variable is read only by `@traceloop/node-server-sdk`. A standalone instrumentation reads the `traceContent` constructor option and nothing else, and that option defaults to `true` for the LLM packages. **Prompts and completions are captured by default.** Setting `TRACELOOP_TRACE_CONTENT=false` does not turn this off. Pass `traceContent: false` to each constructor instead.
