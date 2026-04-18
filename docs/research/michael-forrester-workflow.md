# Research: Michael Forrester's LLM Coding Workflow

**Project:** claude-config
**Last Updated:** 2026-04-15

## Update Log

| Date | Summary |
|------|---------|
| 2026-04-07 | Initial research — cloned private repo peopleforrester/llm-coding-workflow, read all key files |
| 2026-04-15 | Re-pulled before PRD #58 implementation. 8 commits merged since initial research — added structured task management (tasks.yaml + tasks.sh), repo-backup system, PRD workflow templates, and new skills (init-state, prd, repo-backup, task). Key changes affecting PRD #58 milestones documented inline below. |


## Findings

### What the Repo Is

**Repo:** `peopleforrester/llm-coding-workflow` (cloned locally as `forrester-workflow`)

A workflow optimization system built around a Python CLI ("Observatory") that deterministically audits Claude Code sessions — zero LLM calls, parses JSONL session files — plus a full shareable `claude-config/` with 40 skills, 8 hooks, 46 rule files, and a doc scraper. Core principle: **deterministic scripts for all operations, LLM only for judgment and narrative synthesis.**

### Ideas for `claude-config` (Coding Workflow)

#### High confidence — directly applicable, low effort

**`config-sync.sh`** — Detects drift between live `~/.claude/` and the claude-config repo using `rsync --dry-run --itemize-changes`. Supports `--apply live` (update repo from live) and `--apply repo` (adopt repo into live). Today we manually edited `~/.claude/rules/git-workflow.md` AND `rules/git-workflow.md` separately — this script catches that automatically. Implementation at `~/Documents/Repositories/forrester-workflow/scripts/config-sync.sh`.

**As of 2026-04-15:** No changes. The excludes file (`scripts/config-sync-excludes.txt`) is the richer artifact — it documents every ephemeral `~/.claude/` directory that should never be synced: `projects/`, `memory/`, `cache/`, `agents/`, `plugins/`, `statsig/`, `*.jsonl`, `settings.local.json`, `keybindings.json`, etc. Whitney's version needs an equivalent list. Note: the dry-run uses `--checksum` for accuracy; apply mode uses size+mtime for speed — keep this asymmetry intentional.

---

**`/post-compact` skill** — Re-anchor context after a `/compact` event. Reads CLAUDE.md, PROJECT_STATE.md, git state, reports orientation. Whitney has no equivalent. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/post-compact/SKILL.md`.

**As of 2026-04-15:** Step 4 now mentions checking `tasks.yaml` alongside `_execution-state.md`. Skip for Whitney — she uses Claude Code's built-in task system (TaskCreate/TaskUpdate/TaskList), not a YAML file. Adapt step 2 to read the active PRD (any `prds/*.md` containing `Status: In Progress`) instead of PROJECT_STATE.md.

---

**`auto-reanchor.sh` PostCompact hook** — Fires automatically after every compaction without manual invocation. Outputs an orientation block (repo, branch, last 3 commits, dirty files, next step from PROJECT_STATE). Complements the `/post-compact` skill. Hook at `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-reanchor.sh`.

**As of 2026-04-15:** Added `tasks.yaml` awareness — checks for `claimed`/`interrupted` tasks via `yq` and surfaces them in the orientation block. Skip for Whitney (same reason as above — she uses Claude Code's built-in task system). Replace the PROJECT_STATE.md next-step check with an active PRD check. Core structure is unchanged: outputs to stderr so it lands in `additionalContext`, reads git state and recent commits.

---

**Stop hook: auto-test** — Runs tests after every Claude response (not just every commit). Non-blocking (always exit 0). Creates zero-friction TDD feedback loop. Whitney's test enforcement is commit-gated only. Hook at `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-test-on-stop.sh`.

**As of 2026-04-15:** No changes to the reference implementation. However, it only detects Python (`pyproject.toml`/`setup.py`), npm, and Cargo — not bats. Whitney's codebase is primarily bash scripts tested with bats-core. Add bats detection as the first check: look for `tests/` containing `*.bats` files and run `bats tests/`. Also add vitest detection: if `package.json` contains `"vitest"`, run `npx vitest run` rather than `npm test`.

---

**`/continue` skill** — Reads TaskList, PROJECT_STATE.md or PRD state, git log, git status, summarizes what to pick up next. Useful at the start of any session resuming work. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/continue/SKILL.md`.

**As of 2026-04-15:** Step 1 now calls `TaskList` to surface in-progress tasks from previous sessions (Michael added structured task management and integrated it here). Adopt this for Whitney's version — use Claude Code's built-in `TaskList` in step 1 instead of checking tasks.yaml. Read the active PRD instead of PROJECT_STATE.md. The core structure (assess → summarize → propose next step → confirm before acting) is unchanged.

---

#### Medium confidence — applicable but more setup

**`/plan-execute` skill** — Compaction-resilient execution with `_execution-state.md` on disk. Re-reads state file before every task (never trusts conversation memory). Explicitly addresses "100% hallucination rate after mid-task compaction in Plan Mode." More granular than PRD progress tracking; useful for long implementations where compaction is likely. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/plan-execute/SKILL.md`.

**As of 2026-04-15:** No changes. Key patterns still hold: `_execution-state.md` as state file, re-read before every task, stop on 3 consecutive test failures, commit after every task.

---

**`/cost-tracker` equivalent** — Whitney has no visibility into Claude Code session costs. Michael's Observatory parses `~/.claude/projects/` JSONL session files to show cost per session and cost per repo. A lightweight version could be a simple bash script over the JSONL files.

**As of 2026-04-15:** The reference skill now wraps an "Observatory CLI" (`uv run --project /home/michael/repos/workflow/llm-coding-workflow workflow tokens --days <N> --format json`) rather than a standalone script — Whitney doesn't have this Python project. Implement a self-contained `scripts/cost-tracker.sh` using bash/jq to parse `~/.claude/projects/*/` JSONL files directly. The skill wraps the script. Run `/research anthropic pricing` before hardcoding any rates — pricing tiers change and training data may be stale.

---

**`/review-recency` skill** — Freshness check for outdated dependency versions, deprecated patterns, stale rules. Complements `/research`.

---

**Ralph loop detection** in SessionStart hook — Detects when Claude is cycling on failures via `.claude/ralph-loop.local.md` state file. Small addition to the existing session-start hook.

**As of 2026-04-15:** The SessionStart hook has been significantly updated since initial research:
- Reads hook input from stdin as JSON: `INPUT=$(cat)` then `CWD=$(echo "$INPUT" | jq -r '.cwd // empty')` — adopt this pattern
- Ralph loop detection is already present in the reference: checks `.claude/ralph-loop.local.md` and adds to `FINDINGS`
- Opt-out dotfile: `.skip-session-resume` in the repo root suppresses the hook — adopt this
- Uses plain text output via `echo -e "$DIRECTIVE"` (not a JSON wrapper) — correct for SessionStart
- Added `tasks.yaml` state reporting — skip for Whitney
- Replace PROJECT_STATE.md pending-task check with an active PRD check (look for `prds/*.md` containing `Status: In Progress`)

Check `~/.claude/settings.json` for how Whitney's existing SessionStart behavior is wired before modifying anything.

---

**Sycophancy detection** — Michael's Observatory runs 8 regex patterns against Claude's own responses in session JSONL files, flagging flattery and agree-without-pushback patterns. Novel — detects AI behavior degradation over time.

---

### Ideas for `Journal` Repo (Personal Assistant Workflow)

#### High confidence — directly applicable

**Stop hook for session harvesting** — `harvest-journal.sh` fires on every session end (Stop event) and triggers a background shell script that captures session metadata (cost, files touched, repo, branch, commits) into the journal. Whitney's `commit-story` MCP journal capture is LLM-based and manual. A deterministic Stop hook would feed the journal reliably without requiring any manual invocation. Hook at `~/Documents/Repositories/forrester-workflow/claude-config/hooks/harvest-journal.sh`.

**`/summary-session` skill** — End-of-session summary artifact: decisions made, files touched, approximate cost, efficiency observations, patterns worth codifying as skills/hooks. Whitney has nothing that produces this structured artifact. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/summary-session/SKILL.md`.

**Weekly JSON trend snapshots** — `assessments/weekly/YYYY-Wnn.json` with structured scores (TDD adherence, cost, patterns detected, sycophancy rate). Enables week-over-week trending. Whitney's journal summaries are narrative-only; this adds queryable structure.

#### Medium confidence — useful but requires more thought

**`/summary-weekly` skill** — CLI gathers data, LLM narrates trends and suggests 1-2 focus areas for next week. Complements what the journal already does but adds the workflow-health angle. Skill at `~/Documents/Repositories/forrester-workflow/claude-config/skills/summary-weekly/SKILL.md`.

**CURRENT-CONTEXT.md auto-population** — Whitney's CURRENT-CONTEXT.md is manually populated and currently stale. Michael's session harvester + weekly digest pipeline auto-regenerates context from git activity, session data, and journal entries. A nightly cron job that populates CURRENT-CONTEXT.md deterministically from git log + session JSONL files is the right direction.

**Per-session decision log** — Michael has `decisions/<repo-name>.md` per-repo decision logs. Whitney captures decisions in PRD milestones but has no lightweight per-repo decision log.

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
- `~/Documents/Repositories/forrester-workflow/scripts/config-sync-excludes.txt` — excludes list for sync
- `~/Documents/Repositories/forrester-workflow/assessments/weekly/2026-W14.json` — live workflow health snapshot (W14 2026: overall score 0.865)
