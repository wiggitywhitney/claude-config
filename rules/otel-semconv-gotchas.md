# OTel JS Semantic Conventions Gotchas

Verified against `@opentelemetry/semantic-conventions` v1.40.0.

## Two entry-points — stable and incubating are separate

```typescript
// Stable — semver-safe, use in published libraries
import { ATTR_HTTP_REQUEST_METHOD } from '@opentelemetry/semantic-conventions';

// Incubating — breaking changes allowed in minor releases
import { ATTR_RPC_METHOD } from '@opentelemetry/semantic-conventions/incubating';
```

Never mix stable and incubating constants in a single import statement. Importing stable constants from `/incubating` works (it re-exports them) but is incorrect style.

## DB attributes were renamed — training data has the old names

Old (incubating + deprecated) → New (stable):
- `db.system` → **`db.system.name`** (constant: `ATTR_DB_SYSTEM_NAME`)
- `db.statement` → **`db.query.text`** (constant: `ATTR_DB_QUERY_TEXT`)

LLMs trained before 2025 almost always suggest the deprecated names. Prompts must explicitly forbid `db.system` and `db.statement`.

## HTTP URL is `url.full`, not `http.url`

- `http.url` (`ATTR_HTTP_URL`) — incubating + deprecated
- `http.target` (`ATTR_HTTP_TARGET`) — incubating + deprecated
- Replacements: `url.full` (`ATTR_URL_FULL`), `url.path` (`ATTR_URL_PATH`), `url.query` (`ATTR_URL_QUERY`) — all **stable**

## `SEMATTRS_*` still compiles but is wrong

`SEMATTRS_HTTP_METHOD`, `SEMATTRS_HTTP_STATUS_CODE` etc. still export and compile but carry `@deprecated`. They also use OLD attribute strings (`http.method` not `http.request.method`). Do not use.

## RPC and messaging are fully incubating — no stable equivalents

All `ATTR_RPC_*` and `ATTR_MESSAGING_*` constants live in `/incubating`. No stable versions exist yet.

## Incubating really does break on minor bumps

CHANGELOG v1.33.1: `DB_SYSTEM_NAME_VALUE_*` exports were moved back to incubating. This is confirmed evidence that "no semver guarantee" means what it says.

## Stable attributes that are commonly needed

HTTP: `ATTR_HTTP_REQUEST_METHOD`, `ATTR_HTTP_RESPONSE_STATUS_CODE`, `ATTR_URL_FULL`, `ATTR_HTTP_ROUTE`  
DB: `ATTR_DB_SYSTEM_NAME`, `ATTR_DB_QUERY_TEXT`  
Service: `ATTR_SERVICE_NAME`, `ATTR_SERVICE_VERSION`  
Enum values: `HTTP_REQUEST_METHOD_VALUE_GET` etc., `DB_SYSTEM_NAME_VALUE_MYSQL` etc.

## `deployment.environment` is deprecated — use `deployment.environment.name`

Training data universally uses `deployment.environment` for the env tag. As of OTel semconv v1.27.0, this is **deprecated** in favor of `deployment.environment.name`.

- `deployment.environment.name` is the current attribute — Stable in the spec, but its JS constant lives in `/incubating` due to library promotion lag. Define it locally: `const ATTR_DEPLOYMENT_ENVIRONMENT_NAME = 'deployment.environment.name'`
- Datadog requires Agent >= 7.58.0 or Datadog Exporter >= v0.110.0 to recognize the new name. Fall back to `deployment.environment` only for older infrastructure.
- Affected Datadog mapping: `deployment.environment.name` → `env` tag

## Log record attributes (TraceId, SpanId) are NOT in the semconv registry

`TraceId`, `SpanId`, and `TraceFlags` for trace-to-log correlation are **top-level fields in the OTel Log Data Model spec** — not semantic convention attributes. There are no `ATTR_LOG_TRACE_ID` constants. They are auto-populated by the SDK bridge API and must be extracted from `span.spanContext()` for manual `console.log` output.

## All `log.record.*` semconv attributes are Development status

`log.record.uid`, `log.record.original`, `log.file.*`, `log.iostream` — all in Development/incubating. No stable log-record semantic convention attributes exist as of v1.40.0. Import from `/incubating` or define locally.

## `gen_ai.input.messages` / `gen_ai.output.messages` require a `parts` array — NOT the flat format

Training data and many tutorials show the flat format: `{"role":"user","content":"..."}`. The actual OTel GenAI semconv spec requires a `parts` array:

```json
[{"role": "user", "parts": [{"type": "text", "content": "the prompt text here"}]}]
```

The entire value is stored as a JSON-serialized string in the span attribute. The flat format silently stores without error but does not conform to the spec and may not render correctly in Datadog LLM Observability. Applies to any language — this is the wire format, not an SDK API.

## `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` value is `EVENT_ONLY` — NOT `true`

Under `gen_ai_latest_experimental` semconv (the opt-in required for Datadog LLM Observability), setting `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true` is an **invalid configuration**. It silently collects nothing — no error, no warning, just missing content on spans. The correct value is `EVENT_ONLY`:

```bash
OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=EVENT_ONLY
```

`EVENT_ONLY` emits prompt and completion content as span events rather than span attributes (avoids attribute size limits). Training data and tutorials commonly show `true` — this is correct for older semconv modes but wrong for `gen_ai_latest_experimental`. Verified against research/28-datadog-llm-obs-otlp-2026.md (Watch It Burn workshop, 2026-06-24).

---

`gen_ai.input.messages` holds the original input (before any processing); `gen_ai.output.messages` holds the output or transformed content. For a sanitization span capturing before/after content:

```python
span.set_attribute(
    "gen_ai.input.messages",
    json.dumps([{"role": "user", "parts": [{"type": "text", "content": original_text}]}])
)
span.set_attribute(
    "gen_ai.output.messages",
    json.dumps([{"role": "user", "parts": [{"type": "text", "content": sanitized_text}]}])
)
```
