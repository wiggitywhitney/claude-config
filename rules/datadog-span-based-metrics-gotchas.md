# Datadog Span-Based Metrics Gotchas

Verified 2026-06-16 against Datadog docs: Generate Metrics from Spans, Trace Metrics Namespace. Applies when using Datadog's "Generate Metrics from Spans" feature or relying on auto-generated Trace Metrics.

## Two distinct systems — auto-generated Trace Metrics vs custom span-based metrics

Datadog creates two kinds of metrics from spans:

1. **Auto-generated Trace Metrics** (`trace.<span_name>.hits`, `trace.<span_name>.errors`, `trace.<span_name>` distribution) — computed from 100% of traffic, built-in tags only, no billing as custom metrics
2. **Custom span-based metrics** (user-defined names, created via APM UI or `POST /api/v2/apm/config/metrics`) — billed as custom metrics, 15-month retention, requires group-by configuration

These are not interchangeable. Most docs use the term "span-based metrics" loosely to mean either one.

## Custom span attributes are silently dropped from auto-generated Trace Metrics

Auto-generated Trace Metrics only carry a fixed tag set: `env`, `service`, `version`, `resource`, `resource_name`, `http.status_code`, `rpc.grpc.status_code`, host tags, and primary tags.

**Source says:** "Other tags set on spans are not available as tags on traces metrics." ([Trace Metrics Namespace](https://docs.datadoghq.com/tracing/metrics/metrics_namespace/))

To use custom span attributes (e.g., `llm.model`, `commit.sha`) as metric dimensions, you must create a separate custom metric via "Generate Metrics from Spans." There is no way to add dimensions to auto-generated Trace Metrics.

## Custom metric names cannot start with `trace.*`

The `trace.*` namespace is reserved for auto-generated Trace Metrics. Naming custom metrics `trace.my_service.errors` will conflict. Use a different namespace (e.g., `myservice.span.errors`, `commit_story.llm.duration`).

## Filter ≠ group-by — only group-by drives cardinality

In "Generate Metrics from Spans," cardinality risk lives exclusively in the group-by field:
- **Filter** (which spans are counted): safe for any attribute, even user IDs — scopes the metric, does not multiply series
- **Group-by (dimensions)**: creates one time series per unique value — 100k users = 100k series

Using a user ID in the filter is fine. Using a user ID as a group-by dimension will cause cardinality explosion.

**Source says:** "avoid grouping by unbounded or extremely high cardinality attributes like timestamps, user IDs, request IDs, or session IDs" ([Generate Metrics from Spans](https://docs.datadoghq.com/tracing/trace_pipeline/generate_metrics/))

## Metrics are not emitted until the trace is complete

Custom metrics from traces are held until the trace closes.

**Source says:** "Metrics generated from traces are emitted after a trace completes. For long-running traces, the delay increases accordingly (for example, a 45-minute trace's metric cannot be emitted until trace completion)." ([Generate Metrics from Spans](https://docs.datadoghq.com/tracing/trace_pipeline/generate_metrics/))

For short-lived operations this is negligible. For long-running batch jobs, alerts built on these metrics won't fire until after the job completes — too late for active incidents.

## Dropped spans cannot generate custom metrics

Only spans that pass ingestion controls reach the custom metrics pipeline. Spans dropped by head-based sampling or ingestion filters produce no custom metrics. Auto-generated Trace Metrics (from the Datadog Agent / Datadog Connector) are unaffected — they run on 100% of traffic before sampling.

## OTel SDK-level sampling degrades Trace Metrics accuracy

If the OTel SDK's native sampler runs before spans reach the Datadog Collector, Trace Metrics are computed from the sampled subset, not 100% of traffic.

**Source says:** "The OpenTelemetry SDK's native sampling mechanisms lower the number of spans sent to the Datadog collector, resulting in sampled and potentially inaccurate trace metrics." ([Trace Metrics Namespace](https://docs.datadoghq.com/tracing/metrics/metrics_namespace/))

Fix: move sampling from the OTel SDK to the OTel Collector level. When all spans arrive at the Collector before any are dropped, the Datadog Connector can compute Trace Metrics from 100% of traffic. Place the Datadog Connector upstream of any tail sampler in the Collector pipeline.

## Infinite Cardinality Metrics coverage of span-based custom metrics is unconfirmed (as of 2026-06-16)

Datadog's Infinite Cardinality Metrics (GA June 9, 2026) prices metrics per metric name rather than per time series. Whether span-based custom metrics from "Generate Metrics from Spans" fall under this pricing model is not confirmed in the docs. The "Generate Metrics from Spans" docs still say "billed as custom metrics" with no mention of Infinite Cardinality. Do NOT assume high-cardinality group-by dimensions are cost-free under this model until Datadog confirms it.
