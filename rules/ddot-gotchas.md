# DDOT (Datadog Distribution of OpenTelemetry Collector) Gotchas

Verified 2026-06-16 against docs.datadoghq.com/opentelemetry/setup/ddot_collector/ and Datadog blog. Applies when deploying an OTel Collector in a Datadog environment.

## DDOT is embedded in the Datadog Agent — not a standalone binary

DDOT is NOT a separate OTel Collector process. It runs inside the Datadog Agent (v7.65+ required). Enabling it is a configuration flag, not a separate deployment. Consequences:

- A config error in the embedded Collector can affect broader Agent behavior (shared process)
- Custom components require the BYOC (Bring Your OTel Component) workflow — build a custom Agent binary, not just add a YAML file
- The OTel version bundled in DDOT may lag upstream releases (e.g., Agent v7.78.0 bundles OTel beta `v0.147.0` / stable `v1.53.0`)

## Curated component list — not a drop-in for otelcol-contrib

DDOT ships a curated subset of otelcol-contrib. Components NOT in DDOT (by default): Kafka receiver, cloud-specific receivers (AWS, GCP, Azure), most niche contrib exporters. Migrating an existing otelcol-contrib config to DDOT without auditing the component list may produce unclear errors or silently drop unrecognized components — audit against the list above before migrating.

**What IS included** (confirmed as of 2026-06-16):

Receivers: `filelogreceiver`, `fluentforwardreceiver`, `hostmetricsreceiver`, `jaegerreceiver`, `otlpreceiver`, `prometheusreceiver`, `receivercreator`, `zipkinreceiver`, `nopreceiver`

Processors: `attributesprocessor`, `batchprocessor`, `cumulativetodeltaprocessor`, `filterprocessor`, `groupbyattributeprocessor`, `k8sattributesprocessor`, `memorylimiterprocessor`, `probabilisticsamplerprocessor`, `resourcedetectionprocessor`, `resourceprocessor`, `tailsamplingprocessor`, `transformprocessor`

Exporters: `datadogexporter`, `debugexporter`, `loadbalancingexporter`, `otlpexporter`, `otlphttpexporter`, `sapmexporter`, `nopexporter`

Connectors: `datadogconnector`, `spanmetricsconnector`, `routingconnector` (v7.68.0+)

Datadog-exclusive (not in otelcol-contrib): Infrastructure Attribute Processor (auto-assigns k8s tags to OTLP telemetry), Converter, DD Flare Extension

## `routingprocessor` removed in v7.71.0

The `routingprocessor` was deprecated and **hard-removed** in Agent v7.71.0. Existing configs using it will fail on v7.71.0+. Replace with `routingconnector` (available since v7.68.0).

## `spanmetricsconnector` YAML type key may differ from otelcol-contrib

DDOT docs list the component as `spanmetricsconnector`. The upstream otelcol-contrib component type was renamed from `spanmetrics` → `span_metrics` in recent releases (see otel-span-metrics-connector-gotchas.md). Whether DDOT uses the new `span_metrics` YAML key, the deprecated `spanmetrics`, or something else is **unconfirmed** — verify against the current DDOT version before implementing. Do not assume the otelcol-contrib rename applies directly to DDOT.

## For the observability triangle (datadogconnector + spanmetricsconnector coexistence)

Both connectors are included in DDOT's curated list. The coexistence pipeline pattern from the OTel Demo works in DDOT without custom components. This is the right choice when Datadog Agent is already deployed in the environment.

## Fleet Automation is still in Preview

The remote configuration governance features (fleet-wide visibility, remote config pushes) require requesting access to the Preview. The embedded Collector works without Fleet Automation, but the operational management story requires it.

## Automatic Kubernetes metadata enrichment is opinionated

DDOT automatically enriches OTLP spans/metrics/logs with container, pod, and host metadata from Kubernetes. Useful for Datadog APM — but adds Datadog-specific tags that may be unexpected in multi-backend export scenarios (e.g., if you're also exporting to a non-Datadog backend).

## Minimum Agent version

v7.65+ required to enable DDOT. Some features have higher floors: `routingconnector` requires v7.68.0+.
