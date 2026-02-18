# PRD #3: Claude Code Telemetry to Datadog

**Status**: Not Started
**Priority**: Medium
**Created**: 2026-02-18
**GitHub Issue**: [#3](https://github.com/wiggitywhitney/claude-config/issues/3)
**Context**: Claude Code supports OpenTelemetry export via settings.json env vars. The cluster-whisperer project already sends OTLP data to a local Datadog Agent — that infrastructure can be reused with service-level tagging to separate the data.

---

## Problem

No visibility into Claude Code usage patterns across all projects on this machine. Token consumption, API latency, tool call frequency, error rates, and session duration are all invisible. Without telemetry, there's no way to understand how the AI assistant is performing, identify cost drivers, or spot patterns in usage.

## Solution

Configure Claude Code's OpenTelemetry export to send telemetry data to the existing local Datadog Agent (already running for cluster-whisperer at `localhost:4318`). Use service-level tagging (`service:claude-code`) to separate Claude Code data from cluster-whisperer data (`service:cluster-whisperer`) within the same Datadog org. Build a dashboard for usage insights.

## Reference Implementations

### Claude Code OTEL Settings
From `peopleforrester/llm-coding-workflow` `claude-config/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp"
  }
}
```

### Cluster-Whisperer Datadog Setup
The cluster-whisperer project on this machine already sends OTLP data to Datadog:
- **Datadog Agent**: Local agent with OTLP ingestion on port 4318 (HTTP)
- **Secrets**: DD_API_KEY and DD_APP_KEY managed via `vals` (GCP Secrets Manager)
- **Tagging**: Uses `service:cluster-whisperer` and GenAI semantic conventions
- **Documentation**: `~/Documents/Repositories/cluster-whisperer/docs/opentelemetry.md`
- **PRD Reference**: `~/Documents/Repositories/cluster-whisperer/prds/done/8-datadog-observability.md`

## Deliverables

### 1. Research: Claude Code OTEL Emissions
Investigate what telemetry data Claude Code actually emits when OTEL is enabled. Document the available metrics, traces, and attributes.

### 2. Settings.json Configuration
Add OTEL environment variables to `~/.claude/settings.json` that route telemetry to the local Datadog Agent with proper service tagging.

### 3. Datadog Agent Verification
Confirm the local Datadog Agent accepts Claude Code's OTEL data alongside cluster-whisperer data, properly separated by service tags.

### 4. Datadog Dashboard
Build a dashboard showing Claude Code usage insights: token usage, session patterns, tool call frequency, error rates, and any other available metrics.

## Success Criteria

- [ ] Claude Code telemetry data appears in Datadog, tagged `service:claude-code`
- [ ] Cluster-whisperer data remains separate and unaffected
- [ ] Dashboard provides meaningful usage insights
- [ ] Configuration is documented for reproducibility

## Milestones

### Milestone 1: Research — What Does Claude Code Emit?
Investigate Claude Code's OTEL telemetry output. Enable the env vars, inspect what data arrives at the collector, and document available metrics/traces/attributes.

- [ ] Enable `CLAUDE_CODE_ENABLE_TELEMETRY` and `OTEL_METRICS_EXPORTER` in settings.json
- [ ] Capture and document what telemetry data Claude Code sends (metrics, traces, attributes)
- [ ] Determine if additional OTEL env vars are needed (endpoint, protocol, service name)
- [ ] Document findings in `research/claude-code-otel-emissions.md`

### Milestone 2: Datadog Integration
Configure the local Datadog Agent to receive and properly tag Claude Code telemetry. Verify data separation from cluster-whisperer.

- [ ] Configure settings.json env vars for proper OTLP endpoint and service tagging
- [ ] Verify Claude Code data appears in Datadog with `service:claude-code` tag
- [ ] Verify cluster-whisperer data is unaffected and properly separated
- [ ] Document the configuration in this repo

### Milestone 3: Dashboard and Insights
Build a Datadog dashboard that surfaces useful Claude Code usage patterns.

- [ ] Create Datadog dashboard for Claude Code telemetry
- [ ] Include key metrics: token usage, API latency, tool call frequency, error rates
- [ ] Add any session-level or project-level breakdowns available from the data
- [ ] Document dashboard location and how to access it

## Out of Scope

- Separate Datadog org (same org with service tagging provides sufficient isolation)
- Custom instrumentation of Claude Code internals (use whatever OTEL data it exposes)
- Alerting/monitors (can be added later once baseline usage patterns are understood)
- Cluster-whisperer modifications (its setup is reference only, not changing it)

## Decision Log

### Decision 1: Same Org, Different Tags
- **Date**: 2026-02-18
- **Decision**: Use the existing Datadog org with `service:claude-code` tagging rather than creating a separate Datadog org.
- **Rationale**: A separate org adds organizational overhead (separate billing, login, API keys) that isn't justified for one person's data. Service-level tagging provides equivalent filtering power with zero additional infrastructure. Migration to a separate org remains possible later if needed.
- **Impact**: No new Datadog org setup required. Reuse existing DD_API_KEY and Datadog Agent infrastructure from cluster-whisperer.

### Decision 2: Start with Default Emissions
- **Date**: 2026-02-18
- **Decision**: Start with whatever telemetry Claude Code emits by default via OTEL, rather than targeting specific metrics upfront.
- **Rationale**: Claude Code's OTEL output isn't well-documented publicly. A research-first approach (enable it, see what arrives) is more practical than specifying desired metrics that may not be available. The dashboard can be refined once we know what data exists.
- **Impact**: Milestone 1 is research-focused. Dashboard scope in Milestone 3 depends on Milestone 1 findings.
