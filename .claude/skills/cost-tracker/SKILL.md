---
name: cost-tracker
description: Show Claude Code token usage and cost broken down by repo and model. Use when checking session spend, which repo costs the most, cache efficiency, or total cost over a period. Triggers on "how much did that cost", "token usage", "cost breakdown", "cache hit rate", "which repo is most expensive", "billing", or "how much am I spending".
triggers:
  - "/cost-tracker"
  - "how much did that cost"
  - "token usage"
  - "cost breakdown"
  - "cache hit rate"
  - "which repo is most expensive"
---

# /cost-tracker — Token & Cost Visibility

Quick cost breakdown from Claude Code session data. The underlying script is deterministic — no LLM judgment is used to gather data. LLM interpretation is used only to surface actionable insights.

## Invocation

```text
/cost-tracker          # last 7 days (default)
/cost-tracker 30       # last 30 days
/cost-tracker --repo claude-config   # filter to one repo
/cost-tracker 14 --repo Journal      # combine both options
```

## Steps

1. **Parse the arguments** from the invocation: extract DAYS (default 7) and --repo NAME if present.

2. **Run the cost-tracker script:**
   ```bash
   bash ~/Documents/Repositories/claude-config/scripts/cost-tracker.sh [DAYS] [--repo NAME]
   ```
   The script reads `~/.claude/projects/` JSONL files and outputs a formatted report. If the script fails or produces no output, report the error verbatim and stop.

3. **Present the output** from the script verbatim — do not reformat or summarize it.

4. **Interpret the cache hit ratio:**
   - `✓` (≥ 70%) — no action needed
   - `⚠` (< 70%) — explain what prompt caching is and suggest two concrete improvements:
     1. Keep system prompts long and stable across turns (they become the cache anchor)
     2. Place the large, stable content (rules, docs, context) at the top of the prompt, before the dynamic per-turn content

5. **Flag cost outliers** if any single repo exceeds 2× the per-repo average cost. Name the repo and note it as worth investigating.

## Constraints

- Do NOT make any API calls or read any files beyond running the script.
- Do NOT suggest upgrading or downgrading models unless explicitly asked.
- The script handles all date math, pricing, and aggregation. Trust its output.
