# Research: Michael Forrester's LLM Coding Workflow

**Project:** claude-config
**Last Updated:** 2026-04-07

## Update Log

| Date | Summary |
|------|---------|
| 2026-04-07 | Initial research — cloned private repo peopleforrester/llm-coding-workflow, read all key files |


## Findings

### What the Repo Is

**Repo:** `~/Documents/Repositories/forrester-workflow` (cloned from `peopleforrester/llm-coding-workflow` — private, Whitney has access)

A workflow optimization system built around a Python CLI ("Observatory") that deterministically audits Claude Code sessions — zero LLM calls, parses JSONL session files — plus a full shareable `claude-config/` with 40 skills, 8 hooks, 46 rule files, and a doc scraper. Core principle: **deterministic scripts for all operations, LLM only for judgment and narrative synthesis.**

### Ideas for `claude-config` (Coding Workflow)

#### High confidence — directly applicable, low effort

**`config-sync.sh`** — Detects drift between live `~/.claude/` and the claude-config repo using `rsync --dry-run --itemize-changes`. Supports `--apply live` (update repo from live) and `--apply repo` (adopt repo into live). Today we manually edited `~/.claude/rules/git-workflow.md` AND `rules/git-workflow.md` separately — this script catches that automatically. Implementation at `~/Documents/Repositories/forrester-workflow/scripts/config-sync.sh`.

**`/post-compact` skill** — Re-anchor context after a `/compact` event. Reads CLAUDE.md, PROJECT_STATE.md, git state, reports orientation. Whitney has no equivalent. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/post-compact/SKILL.md`.

**`auto-reanchor.sh` PostCompact hook** — Fires automatically after every compaction without manual invocation. Outputs an orientation block (repo, branch, last 3 commits, dirty files, next step from PROJECT_STATE). Complements the `/post-compact` skill. Hook at `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-reanchor.sh`.

**Stop hook: auto-test** — Runs tests after every Claude response (not just every commit). Non-blocking (always exit 0). Creates zero-friction TDD feedback loop. Whitney's test enforcement is commit-gated only. Hook at `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-test-on-stop.sh`.

**`/continue` skill** — Reads TaskList, PROJECT_STATE.md or PRD state, git log, git status, summarizes what to pick up next. Useful at the start of any session resuming work. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/continue/SKILL.md`.

#### Medium confidence — applicable but more setup

**`/plan-execute` skill** — Compaction-resilient execution with `_execution-state.md` on disk. Re-reads state file before every task (never trusts conversation memory). Explicitly addresses "100% hallucination rate after mid-task compaction in Plan Mode." More granular than PRD progress tracking; useful for long implementations where compaction is likely. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/plan-execute/SKILL.md`.

**`/cost-tracker` equivalent** — Whitney has no visibility into Claude Code session costs. Michael's Observatory parses `~/.claude/projects/` JSONL session files to show cost per session and cost per repo. A lightweight version could be a simple bash script over the JSONL files.

**`/review-recency` skill** — Freshness check for outdated dependency versions, deprecated patterns, stale rules. Complements `/research`.

**Ralph loop detection** in SessionStart hook — Detects when Claude is cycling on failures via `.claude/ralph-loop.local.md` state file. Small addition to the existing session-start hook.

**Sycophancy detection** — Michael's Observatory runs 8 regex patterns against Claude's own responses in session JSONL files, flagging flattery and agree-without-pushback patterns. Novel — detects AI behavior degradation over time.

### Ideas for `Journal` Repo (Personal Assistant Workflow)

#### High confidence — directly applicable

**Stop hook for session harvesting** — `harvest-journal.sh` fires on every session end (Stop event) and triggers a background shell script that captures session metadata (cost, files touched, repo, branch, commits) into the journal. Whitney's `commit-story` MCP journal capture is LLM-based and manual. A deterministic Stop hook would feed the journal reliably without requiring any manual invocation. Hook at `~/Documents/Repositories/forrester-workflow/claude-config/hooks/harvest-journal.sh`.

**`/summary-session` skill** — End-of-session summary artifact: decisions made, files touched, approximate cost, efficiency observations, patterns worth codifying as skills/hooks. Whitney has nothing that produces this structured artifact. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/summary-session/SKILL.md`.

**Weekly JSON trend snapshots** — `assessments/weekly/YYYY-Wnn.json` with structured scores (TDD adherence, cost, patterns detected, sycophancy rate). Enables week-over-week trending. Whitney's journal summaries are narrative-only; this adds queryable structure.

#### Medium confidence — useful but requires more thought

**`/summary-weekly` skill** — CLI gathers data, LLM narrates trends and suggests 1-2 focus areas for next week. Complements what the journal already does but adds the workflow-health angle. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/summary-weekly/SKILL.md`.

**CURRENT-CONTEXT.md auto-population** — Whitney's CURRENT-CONTEXT.md is manually populated and currently stale. Michael's session harvester + weekly digest pipeline auto-regenerates context from git activity, session data, and journal entries. A nightly cron job that populates CURRENT-CONTEXT.md deterministically from git log + session JSONL files is the right direction.

**Per-session decision log** — Michael has `decisions/<repo-name>.md` per-repo decision logs. Whitney captures decisions in PRD milestones but has no lightweight per-repo decision log outside of PRDs.

### What Whitney Has That Michael Doesn't

- CodeRabbit review integration
- PRD workflow with milestone tracking
- Anki card creation from conversations
- vals secrets management
- Presentation slide rules (Quarto + Reveal.js)
- Kyverno/Datadog/k8s-specific tooling
- `/write-prompt` skill for AI agent authoring
- `/write-docs` skill for validated documentation

### Key Principle Alignment

Michael and Whitney share the same core principles (deterministic over probabilistic, scripts for operations, AI for judgment). The gaps are mostly about session hygiene: compaction resilience, cost visibility, and automated journal harvesting.

## Sources
- `~/Documents/Repositories/forrester-workflow/README.md` — full observatory architecture and skill inventory
- `~/Documents/Repositories/forrester-workflow/claude-config/CLAUDE.md` — global dev standards
- `~/Documents/Repositories/forrester-workflow/docs/workflow-optimization-audit-2026-04-05.md` — workflow gap analysis with rationale
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/*/SKILL.md` — skill implementations
- `~/Documents/Repositories/forrester-workflow/claude-config/hooks/*.sh` — hook implementations
- `~/Documents/Repositories/forrester-workflow/claude-config/rules/state-persistence.md` — PROJECT_STATE.md pattern
- `~/Documents/Repositories/forrester-workflow/scripts/config-sync.sh` — config drift detection implementation
- `~/Documents/Repositories/forrester-workflow/assessments/weekly/2026-W14.json` — live workflow health snapshot (W14 2026: overall score 0.865)
