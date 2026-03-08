# Design Decisions & Anti-Regression Guide
**Generated:** 2026-03-04 04:58
**Project:** /Users/whitney.lee/Documents/Repositories/claude-config
**Session:** dd1b5dfc-3f99-4c97-91eb-6a1617cca36e
**Compaction trigger:** auto

## CURRENT APPROACH

PRD #3 (Claude Code Telemetry to Datadog) is being **closed/abandoned**. The `/prd-close 3` skill is in progress — we're at Step 3/4 (updating PRD metadata and archiving to `prds/done/`).

The useful artifacts from this work (official Datadog MCP server config, make-autonomous fix) were already merged to main via **PR #27**.

## REJECTED APPROACHES — DO NOT SUGGEST THESE

- [REJECTED] **Local OTEL export to Datadog Agent on localhost:4318**: Managed settings from Datadog (Whitney's employer) override all user OTEL env vars (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_METRICS_EXPORTER`, etc.) via MDM. These have highest precedence and cannot be overridden by `settings.json`. Telemetry is locked to `ai-devx-api.us1.prod.dog`.
- [REJECTED] **Prometheus dual-export (`otlp,prometheus`)**: Would require `OTEL_METRICS_EXPORTER` to be overridable — it's not, managed settings lock it.
- [REJECTED] **Per-signal endpoint overrides**: `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` etc. are also set by managed settings.
- [REJECTED] **Community npm package `@winor30/mcp-server-datadog`**: Whitney works at Datadog — must use the official server. Was in `.mcp.json` briefly, replaced immediately.
- [REJECTED] **vals-based DD_API_KEY/DD_APP_KEY injection for MCP**: Not needed — official Datadog MCP server uses OAuth (browser login), not API keys.
- [REJECTED] **Adding Datadog MCP via `claude mcp add --scope project`**: While cluster-whisperer uses this pattern (stored in `~/.claude.json`), Whitney approved putting it in `.mcp.json` for this repo (committed/shared).

## KEY DESIGN DECISIONS

1. **Official Datadog MCP server is remote HTTP + OAuth** — config is `{"type": "http", "url": "https://mcp.datadoghq.com/api/unstable/mcp-server/mcp"}` in `.mcp.json`. No local process, no API keys.
2. **PRD #3 abandoned due to managed settings** — the blocker is fundamental (MDM precedence), not a configuration error.
3. **PR #27 merged to main** — contains two changes: (a) official Datadog MCP server in `.mcp.json`, (b) fix to `.claude/skills/prds-get/SKILL.v1-yolo.md` for make-autonomous.
4. **Advocacy-skills doc updated** — `docs/claude-code-otel-telemetry.md` in the advocacy-skills repo now documents the managed settings blocker.
5. **Settings.json OTEL env vars reverted** — removed from `~/.claude/settings.json` since they're overridden anyway.
6. **Anki cards saved** — 5 cards in `CARDS MADE - Claude Code OTEL Telemetry and Managed Settings.md`.

## HARD CONSTRAINTS

- Managed settings (MDM) have highest precedence in Claude Code — user `settings.json` cannot override them.
- CodeRabbit review required before any PR merge (non-negotiable per CLAUDE.md).
- Never commit directly to main — feature branches + PRs required. (Exception: `/prd-close` for metadata-only PRD closures.)
- PRD workflow: `/prd-close` for abandoned PRDs, `/prd-done` for implemented ones.

## EXPLICIT DO-NOTs

- Do NOT attempt to configure OTEL env vars in settings.json — managed settings override them
- Do NOT use the community `@winor30/mcp-server-datadog` package
- Do NOT add API key headers to the Datadog MCP server config — it uses OAuth
- Do NOT use `/prd-done` for this PRD — it was abandoned, not implemented; use `/prd-close`
- Do NOT create a new branch for the PRD close — `/prd-close` commits directly to main (it's a metadata-only change, no code)

## CURRENT STATE

**Completed:**
- PR #27 merged to main (Datadog MCP server + make-autonomous fix)
- Advocacy-skills doc updated with managed settings finding
- Settings.json OTEL env vars reverted
- Anki cards saved
- PRD file already staged as renamed: `prds/3-claude-code-telemetry-datadog.md` → `prds/done/3-claude-code-telemetry-datadog.md`

**In progress:**
- `/prd-close 3` workflow — need to:
  1. Update PRD metadata (status, closed date, closure reason)
  2. Commit the archive move + metadata update to main
  3. Close GitHub issue #25 with closure comment
  4. Journal entry via `journal_capture_context`

**Closure reason:** "Abandoned — Datadog managed settings (MDM) override all user OTEL env vars, preventing export to personal Datadog org. Blocker is fundamental, not a config issue."