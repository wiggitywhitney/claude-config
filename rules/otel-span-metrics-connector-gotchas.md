# OTel Span Metrics Connector Gotchas

Verified 2026-06-16 against opentelemetry-collector-contrib spanmetricsconnector README and GitHub issues. Applies to any project emitting span-based metrics via an OTel Collector pipeline.

## Component type was renamed

The component type is now `span_metrics`, not `spanmetrics`. The old name still works (deprecated, not yet removed) but use `span_metrics` in new configs. The component has always been called "Span Metrics Connector" in docs — the YAML type is what changed.

## Default cardinality limit is unlimited — no circuit breaker

`aggregation_cardinality_limit` defaults to `0`, which means unlimited. The connector will happily create millions of metric series if high-cardinality dimensions are added. Set an explicit limit (e.g., `aggregation_cardinality_limit: 100000`) in production. Overflow entries are tagged `otel.metric.overflow="true"`.

## Duration unit change incoming (feature gate)

Feature gate `connector.spanmetrics.useSecondAsDefaultMetricsUnit` will change the default `duration` metric unit from milliseconds (`ms`) to seconds (`s`) when promoted to stable. Any dashboard, alert, or SLO calibrated against `ms` thresholds will break silently — values become 1000× smaller. Pin the unit explicitly in config to avoid surprise:

```yaml
connectors:
  span_metrics:
    histogram:
      unit: ms  # explicit; default changes to 's' when useSecondAsDefaultMetricsUnit gate flips
```

## Never use TraceId or SpanId as dimensions — use Exemplars instead

`TraceId` and `SpanId` are unique per span. Using them as metric dimensions creates one series per span and instantly exhausts any cardinality limit. The correct mechanism for attaching trace context to metrics is **Exemplars**: a sample metric data point carries an attached `(TraceId, SpanId)` pair without creating a new dimension. Enable with `exemplars: { enabled: true }` in connector config.

## Place the connector upstream of any sampler

The connector processes spans as they flow through the pipeline. Head-based sampling upstream of the connector means metrics are computed on the sampled subset, not 100% of traffic. Place `spanmetrics/span_metrics` before any tail sampler or probabilistic sampler in the pipeline to get full-traffic metrics.

## Breaking changes from the old `spanmetrics` processor

The connector replaced an older processor component. Key renames that break existing configs:
- Attribute `operation` → `span.name`
- Metric `latency` → `duration`
- `_total` suffix dropped from metric names
- Prometheus-specific label sanitization removed

## Datadog Exporter no longer computes Trace Metrics (v0.95.0+)

Since collector-contrib v0.95.0, the Datadog Exporter does NOT compute Trace Metrics. A `datadog/connector` must be added to the pipeline explicitly. If upgrading from pre-0.95.0 and using only the Datadog Exporter, Trace Metrics will silently stop appearing in Datadog after upgrade.
