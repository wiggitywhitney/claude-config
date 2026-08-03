---
paths: ["**/instrumentation.*", "**/logger.*", "**/*otel*", "**/*.vals.yaml"]
---

# Datadog Log-Trace Correlation Gotchas (OTel SDK)

Verified 2026-06-16 against docs.datadoghq.com/opentelemetry/correlate/logs_and_traces/ and related pages. Applies when adding log-trace correlation to a Node.js project using the OTel SDK (not dd-trace).

## `dd.trace_id` 64-bit decimal conversion is NOT required — legacy requirement only

Training data commonly teaches converting OTel 128-bit trace IDs to a 64-bit decimal `dd.trace_id` field. This was required for the dd-trace SDK and older Datadog log pipelines.

For OTel SDK users: Datadog natively recognizes the OTel-standard field names `trace_id` and `span_id` with no conversion needed.

**Source says:** "Datadog automatically detects the `dd.trace_id` and `dd.span_id` convention used by Datadog SDKs, as well as the OpenTelemetry standards `trace_id` and `span_id`." ([Datadog docs](https://docs.datadoghq.com/opentelemetry/correlate/logs_and_traces/))

The OTel JS SDK already returns `span.spanContext().traceId` as a lowercase 32-char hex string — emit it directly without converting to decimal.

## Accepted format: 32-char lowercase hex for trace_id, 16-char for span_id

The required format is exact:
- `trace_id`: 32-character lowercase hexadecimal, no `0x` prefix (128-bit)
- `span_id`: 16-character lowercase hexadecimal, no `0x` prefix (64-bit)

The Node.js OTel SDK returns these in the correct format already. No padding or conversion needed.

## `service.name` is NOT automatically remapped to a Datadog log tag

OTel resource attributes (including `service.name`, `service.version`, `deployment.environment`) are not automatically converted to Datadog's standard tags in the log pipeline. They appear as raw OTel attributes.

For unified service tagging across logs, traces, and metrics, configure manual attribute remapping via Datadog Log Profiles or "Preprocessing for JSON logs."

**Source says:** "The Datadog Agent does not automatically convert OTel resource attributes (for example, `service.name`) to Datadog's standard tags." ([Datadog blog — Ingest OTel logs with Datadog Agent](https://www.datadoghq.com/blog/agent-otlp-log-ingestion/))

## Custom attribute names require Preprocessing for JSON logs config

The auto-detection of `trace_id` and `span_id` only applies to those exact OTel-standard field names. If your log output uses any other field name (e.g., `traceId`, `x-trace-id`), it will NOT be recognized as a trace ID automatically. Add the custom field to Datadog's "Preprocessing for JSON logs" configuration to enable correlation.

## OTLP pipeline auto-injects; file pipeline requires explicit fields

When logs flow through the OTLP pipeline (OTel SDK bridge → OTLP exporter → Datadog Agent), the Agent automatically injects `trace_id` values present in the LogRecord. No extra configuration needed.

When logs come from file/stdout scraping (Collector `filelog` receiver or Datadog Agent log pipeline), the `trace_id` and `span_id` fields must be explicitly present in the log JSON. The pipeline does not add them.

**Implication for `console.log` apps (like commit-story):** JSON log output to stdout must include `trace_id` and `span_id` fields explicitly for file-pipeline correlation to work.
