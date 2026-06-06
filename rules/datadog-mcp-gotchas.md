# Datadog MCP Server Gotchas

Verified June 2026 against `datadog-labs/claude-code-plugin` and official tools reference.

## Use the official Claude Code plugin, not manual MCP config

Install via: `/plugin install datadog@claude-plugins-official` (requires Claude Code v2.1.30+). Do NOT add a manual `mcpServers` entry in `settings.json` — if one already exists, remove it first to avoid conflicts.

## Two `/reload-plugins` calls required

One after installation, one after `/ddsetup` completes. Missing the second reload leaves the plugin in a broken state with no clear error.

## `vals exec` cannot wrap an MCP server subprocess

MCP servers are long-running processes spawned by Claude Code at session start, not launched by user commands. `vals exec` wraps a command and exits — it has no mechanism to inject env vars into a process Claude Code spawns later.

**Use OAuth (the plugin default) — it requires no API key management and sidesteps this entirely.** If OAuth is not available (headless/automated context), set the key-based env vars in `~/.zshrc` instead (see next gotcha).

## The `env` block in `settings.json` is silently ignored (known bug, open as of June 2026)

Do NOT use the `env` block in `mcpServers` config for `DD_API_KEY` / `DD_APPLICATION_KEY` / `DD_MCP_DOMAIN` — it may not reach the subprocess. Instead, set them in `~/.zshrc` so they are inherited from the parent shell when Claude Code starts.

## `DD_MCP_DOMAIN` is the domain only — no `https://`

Correct: `mcp.datadoghq.com`
Wrong: `https://mcp.datadoghq.com`

Passing a URL causes a silent connection failure.

## Multi-org: select the correct org during OAuth

If your Datadog account has multiple organizations, OAuth shows an org picker. Selecting the wrong org means all queries go to the wrong org. Re-run `/ddsetup` to re-authenticate with the correct org.

## Core APM tools available without Preview sign-up

The `apm` toolset is in Preview and requires sign-up. But the `core` toolset already includes:
- `get_datadog_trace` — fetch trace by ID (may truncate large traces — no pagination)
- `search_datadog_spans` — search spans by service, time, resource, tags
- `search_datadog_service_dependencies` — service dependency graph

Enable `core` first; only sign up for `apm` Preview if you need advanced analysis tools.

## `DD_MCP_TOOLSETS` env var overrides `/ddtoolsets` settings

Setting `DD_MCP_TOOLSETS=core,apm` in the environment takes precedence over whatever `/ddtoolsets` configured. Changes via `/ddtoolsets` won't apply until the env var is removed.
