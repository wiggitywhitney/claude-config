# CodeRabbit CLI Evaluation

Research findings for PRD #5, Milestone 1: hands-on evaluation of CodeRabbit CLI capabilities, comparison with GitHub-based reviews, token/cost analysis, and limitations.

---

## Summary

CodeRabbit CLI (v0.3.6) is a local code review tool that runs the same AI-powered analysis as the GitHub PR review but before a PR is created. It installs as a standalone binary, authenticates via browser, and produces structured output suitable for AI agent consumption. A dedicated Claude Code plugin (`/plugin install coderabbit`) provides the cleanest integration path.

The CLI catches real issues — in testing against this repo it found legitimate problems (missing quality checklist entries, frontmatter tool declarations). However, `--prompt-only` mode (designed for AI agents) produced fewer findings than `--plain` mode on identical code, suggesting different severity thresholds between modes.

---

## Installation & Setup

| Step | Command | Notes |
|---|---|---|
| Install CLI | `curl -fsSL https://cli.coderabbit.ai/install.sh \| sh` | Downloads binary to `~/.local/bin/coderabbit` |
| Authenticate | `coderabbit auth login` | Opens browser for token exchange |
| Check status | `coderabbit auth status` | Verifies authentication |
| Short alias | `cr` | Symlinked during install |
| Claude Code plugin | `/plugin install coderabbit` | Provides `/coderabbit:review` skill |

**Platform support**: macOS (Intel/Apple Silicon), Linux. Windows requires WSL.

**Version tested**: 0.3.6 (latest as of 2026-02-25).

---

## Commands & Flags

```text
coderabbit review [options]

Options:
  --plain                  Detailed plain text output
  --prompt-only            Minimal output for AI agents (implies --plain)
  -t, --type <type>        Review scope: all (default), committed, uncommitted
  --base <branch>          Base branch for comparison
  --base-commit <commit>   Base commit for comparison
  --cwd <path>             Working directory (must contain git repo)
  -c, --config <files>     Additional instruction files (e.g., claude.md, coderabbit.yaml)
  --no-color               Disable colored output
```

**Interactive mode** (no flags) provides a TUI experience. **Plain mode** gives structured text. **Prompt-only** is the most token-efficient.

---

## Hands-On Test Results

### Test environment

- Repo: `wiggitywhitney/claude-config`
- Branch: `feature/prd-5-coderabbit-cli-integration` (off main)
- Changed file: `.claude/skills/anki/SKILL.md` (added Terminology Provenance section)

### Results by mode

| Run | Flags | Duration | Findings | Details |
|---|---|---|---|---|
| 1 | `--plain --type all --base main` | ~30s | 1 | Quality checklist missing entry for MANDATORY section |
| 2 | `--prompt-only --type all --base main` | ~25s | 0 | Same code, no findings surfaced |
| 3 | `--plain --type committed --base main` | instant | Error | "No files found for review" — no commits on branch |
| 4 | `--plain --type uncommitted --base main` | ~30s | 1 | Different finding: `allowed-tools` frontmatter missing WebSearch/WebFetch + checklist gap |

### Key observations

1. **`--prompt-only` drops findings**: On identical code, `--prompt-only` returned zero findings while `--plain` returned one. This is a behavioral difference, not just a formatting change. The `--prompt-only` mode appears to apply a higher severity threshold.

2. **`--type` affects analysis depth**: `--type uncommitted` produced a more detailed finding than `--type all` on the same file. The `uncommitted` review caught both the `allowed-tools` frontmatter issue AND the checklist gap, while `all` only caught the checklist gap.

3. **`--type committed` requires actual commits**: Fails with "No files found" if changes are only in the working tree. Logical but needs awareness in workflow design.

4. **Review speed**: All runs completed in under 30 seconds. The docs warn of 7-30+ minutes for large changesets — small changes are fast.

5. **Finding quality**: Both findings were legitimate and actionable. The CLI correctly identified that new MANDATORY sections referenced tools not declared in the skill frontmatter.

### Sample CLI output format

```text
============================================================================
File: .claude/skills/anki/SKILL.md
Line: 117 to 124
Type: potential_issue

Comment:
Add a Quality Checklist entry for the new MANDATORY section.

[Detailed explanation of the issue...]

📝 Proposed addition to the Quality Checklist
[Diff showing suggested fix...]

Prompt for AI Agent:
Verify each finding against the current code and only fix it if needed.
[Detailed instructions for automated fixing...]
```

---

## Comparison: CLI vs GitHub PR Review

### Review characteristics

| Aspect | CLI Review | GitHub PR Review |
|---|---|---|
| **Trigger** | Manual (`coderabbit review`) or plugin (`/coderabbit:review`) | Automatic on PR creation/push |
| **Scope** | Working tree, committed, or all changes | Full PR diff against base branch |
| **Speed** | ~30s for small changes | ~5 min for typical PRs |
| **Output location** | Terminal / stdout | GitHub PR comments |
| **Finding format** | Plain text with file/line/type/comment/diff/agent-prompt | Inline PR comments with severity, suggested changes, agent prompts |
| **Severity levels** | Type field (e.g., `potential_issue`) | Severity badges (Major, Minor) + categories (Actionable, Nitpick) |
| **Multi-file review** | Yes | Yes |
| **Configuration** | `.coderabbit.yaml`, CLI flags | `.coderabbit.yaml`, UI settings |
| **CLAUDE.md awareness** | Yes (Pro plan required) | Yes (Pro plan required) |
| **Incremental reviews** | Manual re-run | Automatic on each push |
| **Conversation/threading** | None — one-shot output | Threaded comments, resolution tracking |

### Finding comparison (PR #18 as baseline)

PR #18 GitHub review (3 review rounds, 5 files) found:
- **2 actionable comments**: docs-only exemption documentation gap, branch protection status whitelist issue
- **3 nitpick comments**: hyphenation, TRY003 linter suppression, test harness `git` path
- **1 out-of-diff comment**: CLAUDE.md cross-referencing

The CLI review against the current branch (1 file changed) found:
- **1 finding** (`--plain`): Quality checklist gap
- **1 finding** (`--type uncommitted`): `allowed-tools` frontmatter + checklist gap

**Assessment**: The GitHub review has access to full PR context (multiple files, commit history, linked issues) and produces richer, more diverse findings. The CLI works on a per-invocation basis against whatever diff you specify. The GitHub review caught cross-file issues (test harness calling `git` without full path) that the CLI couldn't catch on a single-file change. However, the CLI's findings were equally legitimate on the code it reviewed.

### Complementary, not replacement

The CLI and GitHub review serve different purposes:
- **CLI**: Catch issues early, before committing or creating a PR. Fast feedback loop.
- **GitHub review**: Comprehensive review of the full PR, with conversation threading and resolution tracking.

The most effective workflow would use both: CLI as a pre-commit/pre-push quality gate, GitHub review as the final check before merge.

---

## Token & Cost Analysis

### Current setup: MCP Server

The current CodeRabbit MCP server (`npx coderabbitai-mcp@latest`) loads 8 tool schemas into Claude Code's context on every session:

```text
- mcp__coderabbitai__get_coderabbit_reviews
- mcp__coderabbitai__get_review_details
- mcp__coderabbitai__get_review_comments
- mcp__coderabbitai__get_comment_details
- mcp__coderabbitai__resolve_comment
- mcp__coderabbitai__resolve_conversation
- (plus any others from the MCP server)
```

**Cost**: Tool schemas are injected into the system prompt for every conversation, consuming tokens even when code review isn't needed. This is the overhead the PRD identifies.

### Alternative: CLI via Bash

Running `coderabbit review --prompt-only` via the Bash tool only consumes tokens when invoked:
- No schema overhead in the system prompt
- Output is minimal (designed for AI agents)
- Only adds context when a review is actually requested

### Alternative: Claude Code Plugin

The plugin (`/plugin install coderabbit`) provides `/coderabbit:review` as a skill:
- Skill definition loaded only when invoked
- No persistent tool schemas in context
- Integrates natively with Claude Code's workflow
- Recommended by CodeRabbit's own docs

### Cost comparison

| Approach | Per-session overhead | Per-review cost | Total (no review) | Total (1 review) |
|---|---|---|---|---|
| MCP Server | ~8 tool schemas always loaded | Low (API call) | High | High |
| CLI via Bash | Zero | Review output in context | Zero | Low-Medium |
| Claude Code Plugin | Zero | Review output in context | Zero | Low-Medium |

### Pricing tiers

| Tier | Cost | CLI Reviews/hour | Notable features |
|---|---|---|---|
| Free | $0 | 2 | Basic static analysis |
| Trial | $0 (14 days) | 5 | Full Pro features |
| Pro | $24/month (annual) or $30/month | 8 | CLAUDE.md awareness, codebase learning, SAST tools |
| Enterprise | Custom | Higher | Self-hosting, SLA |

**For Whitney's workflow**: Active YOLO-mode development with frequent commits could easily exceed the 2/hour free tier. Pro ($24/month) provides 8/hour which should be sufficient. Whitney already has a Pro plan (the GitHub reviews show "Plan: Pro").

---

## Limitations & Gaps

### Compared to GitHub-based review

1. **No conversation threading**: CLI output is one-shot. GitHub review supports threaded discussions, comment resolution, and re-review on push.

2. **No incremental review**: Each CLI run is independent. GitHub reviews automatically re-review when new commits are pushed to a PR.

3. **No cross-PR context**: GitHub reviews can reference related PRs and linked issues. The CLI only sees the local diff.

4. **`--prompt-only` mode drops findings**: This is significant — the mode specifically designed for AI agents produces fewer results than `--plain`. Teams relying on `--prompt-only` may miss issues.

5. **No resolution tracking**: GitHub review comments can be marked as resolved. CLI findings have no state management.

6. **CLAUDE.md context requires Pro**: The CLI's ability to read project coding standards from `claude.md` is a paid feature.

### Compared to MCP server approach

1. **No review data querying**: The MCP server can query past reviews, get review details, and resolve comments programmatically. The CLI only produces new reviews.

2. **No comment resolution**: The MCP server's `resolve_comment` and `resolve_conversation` tools have no CLI equivalent.

3. **Can't check review status**: The MCP server can check if a PR has been reviewed. The CLI can't — it only creates reviews.

### General limitations

1. **Rate limits**: Free tier (2/hour) is restrictive for active development. Even Pro (8/hour) could be limiting during intensive review cycles.

2. **Git required**: Only works in git repositories. No support for other VCS.

3. **No Windows native support**: Requires WSL on Windows.

4. **Review duration variability**: Small changes review in ~30 seconds, but large changesets can take 7-30+ minutes.

5. **Binary distribution**: Installs as a standalone binary (not via npm/brew on macOS). Auto-updates are supported but the initial install requires `curl | sh`.

---

## Configuration Reference

### `.coderabbit.yaml` (relevant CLI options)

```yaml
language: "en-US"          # Review language
early_access: false         # Experimental features
reviews:
  profile: "chill"          # "chill" (lighter) or "assertive" (more detailed)
  path_filters:             # Include/exclude file patterns
    - "!node_modules/**"
    - "src/**"
  path_instructions:        # Per-path review guidance
    - path: "**/*.sh"
      instructions: "Check for shellcheck compliance"
  high_level_summary: true
  auto_review:
    enabled: true
    drafts: false
tone_instructions: ""       # Custom tone (max 250 chars)
```

### CLI-specific flags

```bash
# Review all changes against main
coderabbit review --plain --base main

# Review only uncommitted (working tree) changes
coderabbit review --plain --type uncommitted

# Token-efficient output for AI agents (WARNING: may drop findings)
coderabbit review --prompt-only --base main

# Pass additional instruction files
coderabbit review --plain -c .coderabbit.yaml claude.md
```

---

## Integration Paths for Claude Code

### Option A: Claude Code Plugin (Recommended)

```bash
# One-time setup
curl -fsSL https://cli.coderabbit.ai/install.sh | sh
coderabbit auth login
/plugin install coderabbit

# Usage
/coderabbit:review                    # All changes
/coderabbit:review committed          # Only committed changes
/coderabbit:review uncommitted        # Only uncommitted changes
/coderabbit:review --base main        # Compare against branch
```

**Pros**: Native integration, no tool schema overhead, clean UX.
**Cons**: Requires CLI installed first, plugin ecosystem is newer.

### Option B: CLI via Bash tool

```bash
# In Claude Code, invoke via Bash:
coderabbit review --plain --base main
```

**Pros**: Simple, no plugin dependency, full output.
**Cons**: Less integrated, requires Bash tool permission.

### Option C: Keep MCP Server (current)

```json
{
  "mcpServers": {
    "coderabbitai": {
      "command": "npx",
      "args": ["coderabbitai-mcp@latest"],
      "env": { "GITHUB_PAT": "${GITHUB_TOKEN}" }
    }
  }
}
```

**Pros**: Can query past reviews, resolve comments, check review status.
**Cons**: Tool schemas loaded every session, token overhead.

### Option D: Hybrid (Plugin + MCP for resolution)

Use the plugin for creating reviews (eliminates most token overhead), keep the MCP server only when you need to query/resolve GitHub PR comments.

---

## Sources

- [CodeRabbit CLI Documentation](https://docs.coderabbit.ai/cli) — installation, commands, flags, rate limits
- [CodeRabbit CLI Landing Page](https://www.coderabbit.ai/cli) — feature overview, AI integration
- [CodeRabbit Claude Code Integration](https://docs.coderabbit.ai/cli/claude-code-integration) — plugin setup, commands
- [CodeRabbit Plugin GitHub](https://github.com/coderabbitai/claude-plugin) — plugin README
- [CodeRabbit Pricing](https://www.coderabbit.ai/pricing) — tiers, costs, features
- [CodeRabbit Configuration Reference](https://docs.coderabbit.ai/reference/configuration) — full YAML config options
- [CodeRabbit CLI Blog Post](https://www.coderabbit.ai/blog/coderabbit-cli-free-ai-code-reviews-in-your-cli) — launch details
- [CodeRabbit Codex Integration](https://docs.coderabbit.ai/cli/codex-integration) — Codex comparison context

---

*Research conducted 2026-02-25 for PRD #5, Milestone 1.*
