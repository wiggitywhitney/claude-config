# PRD #58: Workflow Session Hygiene Improvements

**Status**: Not Started
**Created**: 2026-04-07
**Issue**: https://github.com/wiggitywhitney/claude-config/issues/58
**Research**: [Michael Forrester's workflow](../docs/research/michael-forrester-workflow.md) — repo at `~/Documents/Repositories/forrester-workflow`

## Problem

Claude Code sessions have several recurring failure modes that this repo does nothing about:

- **Compaction amnesia**: After `/compact`, critical context (project identity, branch state, active rules) is silently dropped. There's no automatic re-anchoring and no manual skill to invoke.
- **Config drift**: Live `~/.claude/` edits routinely diverge from the claude-config repo. We discovered this today — both `~/.claude/rules/git-workflow.md` and `rules/git-workflow.md` were edited separately with no tooling to detect or reconcile the difference.
- **No test feedback loop**: Tests only run at commit time (pre-commit hook). There's no signal during a session that code changes broke something before committing.
- **No session resume**: Starting work after a break requires manually reading git log, git status, and PRD files to reconstruct where you left off.
- **No compaction-safe execution**: Long multi-step plans frequently get corrupted by compaction mid-run. There's no external state file that survives context loss.
- **Failure cycling undetected**: Claude can get stuck repeating the same failing approach (a "Ralph loop") with no hook to surface it.
- **No cost visibility**: There's no easy way to see how much individual sessions or repos are costing.

## Solution

Add seven targeted improvements, all drawn from Michael Forrester's workflow. Each has a working implementation in `~/Documents/Repositories/forrester-workflow/` to read before implementing.

## Milestones

- [ ] M1: Config sync script
- [ ] M2: Post-compact skill and auto-reanchor hook
- [ ] M3: Stop hook — auto-test on response
- [ ] M4: `/continue` skill — session resume
- [ ] M5: `/plan-execute` skill — compaction-resilient execution
- [ ] M6: Ralph loop detection in SessionStart hook
- [ ] M7: `/cost-tracker` skill

---

## M1: Config sync script
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

**What**: A `scripts/config-sync.sh` that detects drift between live `~/.claude/` and the claude-config repo using `rsync --dry-run`. Supports `--apply live` (update repo from live) and `--apply repo` (adopt repo into live).

**Why**: Today we edited both `~/.claude/rules/git-workflow.md` and the repo's `rules/git-workflow.md` as separate files. Without a sync script, these will diverge over time.

**Reference implementation**: `~/Documents/Repositories/forrester-workflow/scripts/config-sync.sh` — **before writing any code, read this file and summarize the key patterns to yourself.** Do NOT implement without reading it first. It uses `rsync --itemize-changes` to detect drift and shows colored diffs for modified files. Also has a `config-sync-excludes.txt` file to skip ephemeral files (memory, projects/, etc.) — read that too to understand what to exclude in Whitney's version.

**Acceptance criteria**:
- `scripts/config-sync.sh` with no args shows drift (dry-run) between `~/.claude/` and the repo's live config directories
- `--apply live` copies live → repo; `--apply repo` copies repo → live
- Excludes memory files, projects/, and other ephemeral `~/.claude/` content that shouldn't be in the repo
- Has a bats test suite

---

## M2: Post-compact skill and auto-reanchor hook

**What**: Two parts that work together:
1. `/post-compact` skill — a manually-invokable skill that re-reads CLAUDE.md, PRD state, and git state, then reports orientation
2. `auto-reanchor.sh` PostCompact hook — fires automatically after every `/compact` event without manual invocation

**Why**: After compaction, Claude silently loses context about branch, active PRD, and rules. The hook provides automatic recovery; the skill provides manual recovery for mid-session use.

**Reference implementations**: **Before writing any code, read both files and summarize the key patterns to yourself.** Do NOT implement without reading them first.
- Skill: `~/Documents/Repositories/forrester-workflow/claude-config/skills/post-compact/SKILL.md` — lightweight, reads 4 sources, confirms orientation, and exits. Does NOT re-assess all project state (that's `/continue`).
- Hook: `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-reanchor.sh` — outputs an orientation block to stderr (so it lands in `additionalContext`). Includes repo, branch, last 3 commits, dirty files, next step from PROJECT_STATE.md, and whether `_execution-state.md` is active.

**Note**: Whitney uses PRDs instead of PROJECT_STATE.md. Adapt the hook and skill to read from the active PRD (check `prds/` for any file with `Status: In Progress`) rather than PROJECT_STATE.md.

**Acceptance criteria**:
- `/post-compact` skill exists and re-anchors context when invoked
- PostCompact hook fires automatically and outputs an orientation block
- Both adapted for Whitney's PRD-based state (not PROJECT_STATE.md)
- Skill reviewed with `/write-prompt` before committing

---

## M3: Stop hook — auto-test on response
**Step 0:** Read related research before starting: [Research: bats-core v1.12/v1.13 Changes and run Behavior](../docs/research/bats-core.md)

**What**: A `Stop` event hook that runs the project's test suite after every Claude response. Non-blocking (always exits 0). Only runs if a test command is detectable.

**Why**: Currently tests only run at commit (pre-commit hook). This creates a long feedback loop. Auto-running tests after each response catches breakage immediately without requiring manual runs.

**Reference implementation**: `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-test-on-stop.sh` — **before writing any code, read this file and summarize the key patterns to yourself.** Do NOT implement without reading it first. Key pattern: detect what test runner is present (`bats`, `pytest`, `npm test`, etc.) before running, and run from the repo root. Always exit 0 regardless of test outcome — this is advisory feedback, not a gate.

**Acceptance criteria**:
- Stop hook registered in `settings.json`
- Detects `bats`, `pytest`, `npm test`/`npx vitest`, `cargo test` and runs the appropriate one
- Always exits 0 (never blocks)
- Has a bats test suite

---

## M4: `/continue` skill — session resume

**What**: A skill that reads PRD state, git log, git status, and task list to summarize where work left off and suggest the next step.

**Why**: Starting work after a break currently requires manually piecing together state from multiple sources. A skill that does this in one invocation saves time and prevents context errors.

**Reference implementation**: `~/Documents/Repositories/forrester-workflow/claude-config/skills/continue/SKILL.md` — **before writing any code, read this file and summarize the key patterns to yourself.** Do NOT implement without reading it first. Note it reads `PROJECT_STATE.md` — adapt for Whitney's PRDs. The pattern is: assess → summarize → propose next step → ask to confirm before acting.

**Note**: Read the active PRD (any file in `prds/` with `Status: In Progress`) instead of PROJECT_STATE.md.

**Acceptance criteria**:
- `/continue` skill exists
- Reads active PRD, git log, git status, and task list
- Outputs: last activity, current branch, pending PRD milestones, suggested next step
- Asks user to confirm before starting work
- Skill reviewed with `/write-prompt` before committing

---

## M5: `/plan-execute` skill — compaction-resilient execution

**What**: A skill that persists plan execution state to `_execution-state.md` on disk, re-reads it before every task, and handles compaction recovery gracefully.

**Why**: Long multi-step implementations frequently get corrupted mid-run when context compacts. State in conversation memory is lost. Writing state to disk means work survives compaction and session restarts.

**Reference implementation**: `~/Documents/Repositories/forrester-workflow/claude-config/skills/plan-execute/SKILL.md` — **before writing any code, read this file and summarize the key patterns to yourself.** Do NOT implement without reading it first. Key patterns:
- Always re-read `_execution-state.md` before each task — never trust conversation memory
- Update state file after every task completes (with commit hash)
- Stop execution after 3 consecutive test failures rather than looping
- The state file format (template is in the skill) includes compaction counter and failure tracking

**Acceptance criteria**:
- `/plan-execute` skill exists
- Creates `_execution-state.md` from a plan if one doesn't exist
- Re-reads state before each task
- Updates state after each task with commit hash
- Stops and reports to user after 3 consecutive test failures
- Skill reviewed with `/write-prompt` before committing

---

## M6: Ralph loop detection in SessionStart hook

**What**: Add Ralph loop detection to the existing `session-start` hook behavior. A "Ralph loop" is Claude repeating the same failing approach in a cycle. Detect it via a `.claude/ralph-loop.local.md` state file in the repo.

**Why**: When Claude gets stuck, it can cycle for many turns before a human notices. Surfacing "Ralph loop state detected" at session start prompts the user to break the cycle with a different approach.

**Reference implementation**: `~/Documents/Repositories/forrester-workflow/claude-config/hooks/session-start.sh` — **before writing any code, read this file and summarize the key patterns to yourself.** Do NOT implement without reading it first. The Ralph loop detection section is simple: check for `.claude/ralph-loop.local.md`, surface it in the session-start output if present.

**Important — creation vs. detection**: This milestone only implements *detection* — surfacing the file at session start. `.claude/ralph-loop.local.md` is created manually by the user (or a future skill) when a failure cycle is recognized mid-session. Note this limitation in a comment in the hook so a future implementor knows detection and creation are separate concerns.

**Note**: Whitney's SessionStart hook enforcement is done differently than Michael's. Check `~/.claude/settings.json` for how the existing session-start behavior is wired before modifying it.

**Acceptance criteria**:
- SessionStart hook checks for `.claude/ralph-loop.local.md`
- If present, surfaces a warning in `additionalContext`
- `.claude/ralph-loop.local.md` is added to `.gitignore`
- Has a bats test

---

## M7: `/cost-tracker` skill

**What**: A skill that parses Claude Code session JSONL files in `~/.claude/projects/` to show token usage and cost per session and per repo.

**Why**: Whitney has no visibility into how much individual sessions or repos cost. Without this, there's no way to notice cost outliers or track spend over time.

**Reference implementation**: `~/Documents/Repositories/forrester-workflow/claude-config/skills/cost-tracker/SKILL.md` and `~/Documents/Repositories/forrester-workflow/src/workflow/analyzers/tokens.py` — **before writing any code, read both files and summarize the key patterns to yourself.** Do NOT implement without reading them first. Michael's implementation is a Python CLI. Prefer a bash/jq script over Python — do NOT reach for Python unless bash cannot handle the complexity cleanly.

**Note**: JSONL files in `~/.claude/projects/` contain session data with token counts. The cost calculation uses Anthropic pricing tiers. Verify current pricing before hardcoding any rates — run `/research anthropic pricing` if needed.

**Acceptance criteria**:
- `/cost-tracker` skill exists
- Shows cost breakdown: by session (last N days) and by repo
- Shows cache hit ratio
- Deterministic (no LLM calls in the data gathering step)
- Has a bats test suite for the underlying script
- Skill reviewed with `/write-prompt` before committing

---

## Design Decisions

_Record decisions here as they are made during implementation._

---

## Progress

_Updated by `/prd-update-progress` as milestones complete._
