---
paths: ["**/*.ts", "**/*.js", "**/*.py", "**/*.sh", "**/settings.json"]
description: Datadog AI Gateway routing for Claude Code and how to bypass it
---

# Datadog Enterprise Environment

Claude Code routes through the Datadog AI Gateway via two env vars set in `settings.json`:
- `ANTHROPIC_BASE_URL` — points to `ai-gateway.us1.ddbuild.io`
- `ANTHROPIC_CUSTOM_HEADERS` — gateway-required headers (`source`, `org-id`, `provider`, auth)

Both are auto-read by `@anthropic-ai/sdk` and `@langchain/anthropic`, so **any subprocess calling the Anthropic API** routes through the gateway and fails if headers are wrong or missing (`400 Missing required header: source`).

**Fix:** Strip **both** vars so calls go directly to Anthropic:
```bash
env -u ANTHROPIC_CUSTOM_HEADERS -u ANTHROPIC_BASE_URL vals exec -i -f .vals.yaml -- command
```
