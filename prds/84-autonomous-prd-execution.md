# PRD #84: Autonomous PRD Execution

**Status**: Draft
**Created**: 2026-04-17
**Issue**: https://github.com/wiggitywhitney/claude-config/issues/84
**Research**:
- [PRD workflow principles](../docs/research/prd-workflow-principles.md) — how the current PRD skills work, what state lives where, the atomic-commit invariant, YOLO variants, TaskCreate state machine, hooks that touch PRDs
- [Michael Forrester autonomous execution principles](../docs/research/michael-autonomous-execution-principles.md) — `plan-execute`, `long-run`, `tasks.yaml`, GUPP, compaction recovery patterns, the staging-branch fork, Design Forks for Whitney's Designer
- [Claude Code autonomous capabilities](../docs/research/claude-code-autonomous-capabilities.md) — 2026 platform constraints: self-clear vs. spawn-session, compaction behavior, Ralph loops, stuck detection gap

## Problem

The current PRD workflow is interactive — the user manually invokes each skill at milestone boundaries (`/prd-next`, `/prd-update-progress`) and directs implementation between them. This works well for conscious, keyboard-present execution but limits throughput. Work that could run unattended — a full PRD end-to-end, or a queue of PRDs overnight — instead waits for the user at every transition.

Key limitations of the interactive model:
- Every skill chain hand-off (`"Now run /prd-update-progress"`) is a human prompt, not a machine trigger
- Mid-milestone reasoning is never persisted — compaction inside a long milestone loses in-flight design thinking
- Failure detection relies on the user noticing ("is Claude stuck in a loop?")
- No mechanism to run a queue of PRDs without being asked which one is next

## Solution

Design an autonomous PRD execution system built on existing PRD infrastructure, informed by Michael Forrester's `plan-execute` / `long-run` / `tasks.yaml` patterns — adapted for this repo's feature-branch-per-PRD model and the mandatory PR gate.

The adaptation is load-bearing, not cosmetic. Michael's system assumes a shared `staging` branch with no PR gate; this repo uses feature branches that must merge via CodeRabbit + human review. Michael's unit of work is a flat task list; this repo's unit is a milestone inside a PRD with an atomic-commit invariant. The autonomous system must therefore:
- Stop at PR creation, not merge
- Respect the atomic-commit rule (code + PRD checkbox + PROGRESS.md in one SHA)
- Persist mid-milestone reasoning durably (a surface that currently doesn't exist)
- Build on the existing YOLO skill variants and `/make-autonomous` toggle rather than reinventing the confirmation-gate layer

## Milestones

- [ ] M1: Extend `/make-autonomous` allowlist for headless `claude -p`
- [ ] M2: Run tests on every push (`pre-push-verify.sh` enhancement)
- [ ] M3: Orchestrator script `scripts/autonomous-prd.sh`
- [ ] M4: Pause-handling rule + YOLO skill updates for headless mode
- [ ] M5: End-to-end validation
- [ ] M6: User-facing documentation

---

### M1: Extend `/make-autonomous` allowlist for headless `claude -p`

**Step 0:** Read before starting: Decision 4 in the Decision Log below (exact allowlist entries and rationale); [Claude Code autonomous capabilities](../docs/research/claude-code-autonomous-capabilities.md) §1 (why `claude -p` is the right primitive and why permission prompts will stall it in headless mode).

**What:** Add twelve permission entries to `/make-autonomous`'s allowlist instruction block so that an autonomous `claude -p` child session can run tests, manage tasks, spawn agents, and schedule wake-ups without hitting permission prompts.

**Why:** Audit confirmed `/make-autonomous` already covers ~85% of what autonomous-mode needs (git, gh, PRD skills, Read/Edit/Write). The remaining twelve entries are trivial JSON additions; without them, `claude -p` stalls on the first `npm test`, `bats`, `TaskCreate`, `Agent`, or `ScheduleWakeup` call — defeating autonomy. This milestone is a prerequisite to M3 because the orchestrator's pre-flight check verifies `/make-autonomous` has been applied.

**To implement:**
- Edit `.claude/skills/make-autonomous/SKILL.md` to add these entries to the `permissions.allow` instruction block: `Bash(npm test*)`, `Bash(npm run build*)`, `Bash(npm run *)`, `Bash(npx vitest*)`, `Bash(pytest*)`, `Bash(bats*)`, `TaskCreate`, `TaskUpdate`, `TaskGet`, `TaskList`, `Agent`, `ScheduleWakeup`
- Read `.claude/skills/make-careful/SKILL.md` to confirm whether symmetric removals are needed; skip if careful mode resets the full allowlist rather than subtracting specific entries
- Run `/write-prompt` on the updated `/make-autonomous` SKILL.md; apply all high-severity findings before committing
- Add or extend bats tests (e.g., `tests/make-autonomous.bats`) that apply `/make-autonomous` to a temp repo and assert the resulting `.claude/settings.local.json` contains each of the twelve new entries

**Success criteria:**
- Running `/make-autonomous` in a fresh repo produces a `.claude/settings.local.json` with all twelve new entries present
- `/write-prompt` review returns no high-severity findings on the updated skill
- Bats tests pass

---

### M2: Run tests on every push (`pre-push-verify.sh` enhancement)

**Step 0:** Read before starting: Decision 5 in the Decision Log below (rationale, convention, spinybacked-orbweaver audit); `hooks/git/checks/pre-push-verify.sh` (current PR-conditional test block); `hooks/git/lib/detect-project.sh` (how `CMD_TEST` is extracted from verify.json and package.json).

**What:** Modify `pre-push-verify.sh` to run the project's `test` command unconditionally on every push, not only when an open PR exists. Preserve the existing expanded-security-when-PR-exists behavior and the docs-only early exit.

**Why:** Today's hooks run tests only when an open PR exists for the branch. For autonomous PRD execution, the first N milestones push without a PR — so no hook-level test enforcement runs. Broken tests could accumulate until `/prd-done` creates the PR and CI finally catches them, potentially unwinding many milestones' worth of committed work. Running tests on every push closes the gap without adding mode-detection logic; the existing verify.json convention (`test` = fast/safe, `acceptance_test` = expensive/API-calling) is the mechanism for excluding e2e and external-service-calling tests.

**To implement:**
- Edit `hooks/git/checks/pre-push-verify.sh`:
  - Extract `CMD_TEST` from `detect-project.sh` output using the same pattern as `CMD_BUILD` / `CMD_TYPECHECK` in `pre-commit-verify.sh`
  - After the existing security phase, if `CMD_TEST` is non-empty, call `verify-phase.sh test "$CMD_TEST" "$PROJECT_DIR"` regardless of `HAS_PR`
  - If `CMD_TEST` is empty (repo has no test command defined), skip silently with no failure
  - Preserve the expanded-security-when-PR-exists behavior unchanged
  - Preserve the docs-only early exit unchanged
- Extend bats tests in `tests/git-hook-checks.bats` covering these cases:
  - Test command runs on push to a feature branch with no open PR
  - Test command runs on push to a feature branch with an open PR
  - Test failures produce a clear blocking error message (non-zero exit, stderr mentions which phase failed)
  - Docs-only push skips tests (preserved behavior)
  - Missing `CMD_TEST` is skipped silently without error

**Success criteria:**
- Tests run on every push where `CMD_TEST` is defined, regardless of PR state
- New bats test cases pass
- Existing git-hook bats suite continues to pass
- Manual verification: pushing a scratch branch from claude-config with a broken test blocks the push with a clear message; pushing docs-only changes skips tests as before

---

### M3: Orchestrator script `scripts/autonomous-prd.sh`

**Step 0:** Read before starting: [Claude Code autonomous capabilities](../docs/research/claude-code-autonomous-capabilities.md) §3–§5 (Ralph loops, stuck detection, design implications); [PRD workflow principles](../docs/research/prd-workflow-principles.md) §3 (the skill chain children execute); Decisions 2 and 3 in the Decision Log below (Ralph loop architecture, pause marker mechanism).

**What:** Implement the bash while-loop orchestrator that drives autonomous PRD execution. It pre-flight-checks that `/make-autonomous` has been applied, greps the active PRD for pause markers before each iteration, spawns `claude -p` per milestone with a structured prompt, enforces a per-milestone iteration cap, writes a pause marker on cap reach, and logs each iteration to `_autonomous-run.log`.

**Why:** This is the deterministic orchestration layer — the single non-Claude component of the system. Per Decision 2, the outer loop must live in a shell script rather than a parent Claude session so it has no context limits and no compaction risk of its own. The iteration cap is the community-validated stop mechanism (snarktank/ralph); the pause marker (Decision 3) consolidates stuck detection and human-in-the-loop handoff into one mechanism, consistent with Decision 1 (PRD is the state file).

**To implement:**
- Create `scripts/autonomous-prd.sh` with:
  - Usage: `scripts/autonomous-prd.sh <prd-number> [--dry-run] [--max-attempts N]` (default `max-attempts=5`, tunable from real usage per M5 findings)
  - **Pre-flight check**: grep `.claude/settings.local.json` for a distinctive entry added by `/make-autonomous` (e.g., `TaskCreate`); if missing, exit with a message instructing the user to run `/make-autonomous` first and why
  - **Pre-spawn check before each iteration**: `grep -n '^\*\*Paused' prds/<N>-*.md`; if found, print the full pause block and exit cleanly with a reminder that the marker must be removed (after addressing the underlying cause) before resuming
  - **Main loop**:
    - Read the active PRD; if all milestones are `[x]`, break to the completion branch
    - Track iteration count for the current milestone by reading `_autonomous-run.log` entries; if the log file is missing (first run), start at 0
    - If iterations for the current milestone reach `--max-attempts`, write `**Paused — iteration cap reached on M<n>:** <N> attempts, last commit <sha>` into that milestone's section in the PRD, commit the PRD-only change with a `docs(prd-<N>)` message, and exit
    - Otherwise, spawn `claude -p` with the child prompt template (see below). The template lives in its own file — do not inline it in the shell script
- **Design the child prompt template as a first-class artifact.** The prompt sent to every `claude -p` child is the runtime system prompt for autonomous execution — it is load-bearing. Steps:
  - Draft a prompt template covering: (a) identify the next milestone using `/prd-next`, (b) implement it following TDD (hooks enforce quality gates), (c) invoke `/prd-update-progress` when the milestone is complete, (d) if a human decision is needed, write `**Paused — needs Whitney:** <analysis>` into the active milestone and exit — do NOT try to ask interactively, and (e) exit cleanly after `/prd-update-progress` — the orchestrator handles the next iteration (do NOT run `/clear`)
  - Run `/write-prompt` on the template; apply all high-severity findings
  - Store the template at `scripts/autonomous-prd-child-prompt.md` (or equivalent); the orchestrator reads this file at spawn time and passes it to `claude -p` via stdin or `-p` argument
    - Log each iteration to `_autonomous-run.log` with timestamp, milestone number, iteration number, child exit code
  - **Completion branch**: when all milestones are `[x]` and no PR exists yet, spawn one final `claude -p` to invoke `/prd-done`; after the PR is created the script exits
  - **`--dry-run`**: prints the plan (pre-flight status, pause state, next-milestone identification, first-spawn prompt) without spawning any `claude -p` or writing anything
- Add bats tests in `tests/autonomous-prd.bats` covering:
  - Pre-flight check fails with a clear message when `/make-autonomous` hasn't been applied
  - Pre-spawn grep correctly detects a `**Paused` marker and exits without spawning
  - `--dry-run` makes no spawns, writes no files, creates no commits
  - Iteration counter respects `--max-attempts` and writes the cap marker on reach
  - `_autonomous-run.log` is written with the expected structure (timestamp, milestone, iteration, exit code)

**Success criteria:**
- All bats tests pass
- `scripts/autonomous-prd.sh --dry-run 84` (against PRD 84 itself, after its milestones are written) produces a sensible plan output
- Each failure mode (missing `/make-autonomous`, active pause marker, iteration cap reached) produces a clear, actionable message to the user
- The child prompt template exists at its decided location (e.g., `scripts/autonomous-prd-child-prompt.md`) and has passed `/write-prompt` review
- Mode-detection mechanism (the file marker path OR env var name that signals "autonomous mode" to YOLO skills) is documented in a comment block at the top of `scripts/autonomous-prd.sh`, so M4 has an unambiguous reference for what to detect

---

### M4: Pause-handling rule + YOLO skill updates for headless mode

**Step 0:** Read before starting: Decisions 1, 2, 3 in the Decision Log below; the current `.claude/skills/prd-next/SKILL.v1-yolo.md` (Step 8 has a `/clear` loop that won't work in headless mode; the Autonomous Decision Protocol's "stop and surface" criteria need adapting to pause-marker writing); `.claude/skills/prd-update-progress/SKILL.v1-yolo.md` (Step 9's "Next steps" message assumes a human reader); `scripts/auto-reanchor.sh` lines 38–42 (dead `_execution-state.md` block that Decision 1 rules out).

**What:** Three tightly coupled pieces: (1) create `rules/autonomous-pause-handling.md` documenting the pause-marker lifecycle; (2) update the YOLO variants of `/prd-next` and `/prd-update-progress` to work correctly in a headless `claude -p` child (no `/clear` reliance, pause-marker-writing for needs-human moments); (3) remove the dead `_execution-state.md` reference from `auto-reanchor.sh`.

**Why:** Without the rule, a user may remove a pause marker without addressing the underlying cause, and the orchestrator or child will just re-write it on the next iteration — a silent infinite re-pause. Without the skill updates, `claude -p` children either attempt `/clear` (which fails silently — it's a CLI-only command) or stall trying to ask interactive questions. The `auto-reanchor.sh` cleanup aligns it with Decision 1 (no `_execution-state.md`) so it doesn't mislead a re-anchored session into looking for a file that doesn't exist.

**To implement:**
- Create `rules/autonomous-pause-handling.md` covering:
  - What the `**Paused — <reason>:** <detail>` marker means (child-written "needs Whitney" vs. orchestrator-written "iteration cap reached")
  - The resume protocol: address the underlying cause (make the decision, or fix the condition causing the cap); commit the resolution via `/prd-update-progress`; remove the pause marker from the PRD; restart the orchestrator
  - The failure mode this prevents: stripping the marker without addressing the cause will cause the orchestrator or child to re-write it on the next iteration — a silent loop
- Add a line in global `~/.claude/CLAUDE.md` under the PRD Workflow section referencing the new rule
- Modify `.claude/skills/prd-next/SKILL.v1-yolo.md`:
  - Replace Step 8's `/clear`-and-loop block with a mode-aware branch: in autonomous mode (detect via a marker set by the orchestrator — file or env var, determined during M3 wiring), the child simply exits cleanly after `/prd-update-progress` because the orchestrator handles the next iteration; in interactive mode, retain the current manual-`/clear` guidance
  - Extend the Autonomous Decision Protocol's "Stop and surface to the user when..." section: in autonomous mode, "surface" means writing `**Paused — needs Whitney:** <your analysis of the decision needed>` into the active milestone section and exiting, not asking a question
- Modify `.claude/skills/prd-update-progress/SKILL.v1-yolo.md`:
  - Make Step 9's "Next steps" message agnostic: state that continuation is handled by the orchestrator in autonomous mode, with the interactive `/clear → /prd-next` prompt only applying when not in autonomous mode
- Run `/write-prompt` on each modified skill and the new rule; apply all high-severity findings before committing
- Modify `scripts/auto-reanchor.sh`: remove lines 38–42 (the `_execution-state.md` existence check) and the corresponding output line (52); update the ABOUTME header if it mentions execution state
- Update the existing bats tests for `auto-reanchor.sh` to reflect the removed block

**Success criteria:**
- `rules/autonomous-pause-handling.md` exists and covers marker meanings, resume protocol, and the re-pause failure-mode warning
- Global CLAUDE.md references the new rule
- Modified YOLO skills read correctly in both interactive and autonomous modes (verified by read-through and `/write-prompt` review)
- `/write-prompt` reviews return no high-severity findings on modified files
- `scripts/auto-reanchor.sh` no longer references `_execution-state.md`
- Existing bats tests for `auto-reanchor.sh` pass (updated to remove dead-block assertions if any)

---

### M5: End-to-end validation

**Step 0:** Read before starting: the actually shipped M2, M3, M4 artifacts (the code on disk, not the milestone text); [Claude Code autonomous capabilities](../docs/research/claude-code-autonomous-capabilities.md) §4 (stuck detection expected behavior) for framing what legitimate stuck-vs-slow looks like.

**What:** Create a scratch test PRD with three milestones designed to exercise each orchestrator behavior — happy path, iteration cap, human-in-the-loop pause. Run the orchestrator against each scenario and verify correct behavior end-to-end. Capture any tuning needs (iteration cap value, prompt wording, pause-marker format) as new Decision Log rows.

**Why:** Unit tests from M2 and M3 cover plumbing in isolation. Only end-to-end runs against a real `claude -p` chain prove the full system works — skills, hooks, permissions, pause mechanism all together. Tuning parameters are best set from observed behavior; guessing up front wastes implementation time that can be spent iterating on real data.

**To implement:**
- Create a scratch test PRD (e.g., `prds/test-autonomous-smoke.md` — not a numbered production PRD) with three milestones:
  - **Happy path**: trivial implementation — add a file, implement one tiny function, write a passing test
  - **Iteration cap**: a milestone whose success criteria are intentionally impossible or require resources not present (e.g., "connect to a service that doesn't exist")
  - **Human-in-the-loop**: a milestone whose description explicitly instructs the child to pause for Whitney's decision (no attempt to implement first)
- Run `scripts/autonomous-prd.sh` against each scenario, resetting state between runs; observe behavior
- Document observations: iteration counts, elapsed time per milestone, pause-marker format and placement, log file structure
- If tuning is needed, add new Decision Log rows in PRD 84 (e.g., "Decision 6: Max-attempts set to 4 based on observation that most milestones need 1–2 attempts") and adjust the orchestrator or prompt accordingly
- Delete or archive the scratch test PRD after validation; record a short validation-run summary in PRD 84's Progress section

**Success criteria:**
- Happy path: the orchestrator completes the scratch PRD end-to-end and creates a real PR
- Iteration cap: the orchestrator writes the cap pause marker after `--max-attempts` and exits; a subsequent re-run exits cleanly on the pre-spawn check
- Human-in-the-loop: the child writes the needs-Whitney marker and exits cleanly; the orchestrator's next iteration detects the marker and exits; removing the marker and restarting resumes the loop
- Any discovered tuning needs are captured as Decision Log rows before the milestone is marked complete
- Scratch test PRD is cleaned up after validation

---

### M6: User-facing documentation

**Step 0:** Read before starting: all three research docs in `docs/research/` for context on why the system is shaped the way it is; this PRD (problem, solution, all decisions, all milestones); the final shipped `scripts/autonomous-prd.sh` and `rules/autonomous-pause-handling.md` so the documentation describes actual behavior rather than aspirational behavior.

**What:** Invoke `/write-docs` to produce `docs/autonomous-prd-execution.md` — a user-facing guide covering prerequisites, invocation, monitoring, pause handling, resume flow, and troubleshooting. Update `README.md` to link to the new doc.

**Why:** Without documentation, only a reader of PRD 84 can use the feature. The intended user is Whitney herself (future-Whitney after this session's context is gone) and any collaborator who encounters an autonomous-mode run. Per the global CLAUDE.md rule, `/write-docs` (not hand-written documentation) is used because it validates every documented command by running it and capturing real output — preventing docs drift as the orchestrator evolves.

**To implement:**
- Invoke `/write-docs` to produce `docs/autonomous-prd-execution.md` covering:
  - **Prerequisites**: `/make-autonomous` applied to the target repo; a PRD started via `/prd-start`; the repo's `test` command excludes e2e and external-service-calling tests (reference Decision 5 convention)
  - **Invocation**: `scripts/autonomous-prd.sh <prd-number>` with `--dry-run` and `--max-attempts` flag examples
  - **Monitoring during a run**: `_autonomous-run.log` structure, reading `git log`, reading the PRD's checkbox state, reading PROGRESS.md for narrative progress
  - **Pause handling**: examples of both marker types (cap-reached and needs-human); link to `rules/autonomous-pause-handling.md` for the full protocol
  - **Resume flow**: address the pause cause, commit through normal PRD flow, remove the marker, restart the orchestrator
  - **Stopping**: Ctrl-C behavior and explicit kill instructions
  - **Troubleshooting**: common failure modes — missing `/make-autonomous`, malformed PRD, iteration cap on a legitimately large milestone, tests failing with no obvious cause
- Update `README.md` to add an "Autonomous PRD Execution" section linking to the new doc under a discoverable heading
- `/write-docs` validates every example command by running it against a test environment and capturing real output

**Success criteria:**
- `docs/autonomous-prd-execution.md` answers the question "I want to work through PRD X autonomously — how?" end to end
- Every command shown in the doc is validated by `/write-docs` (real commands, real output captured)
- `README.md` references the new doc under a discoverable heading

## Alternatives Considered

The following approaches were discussed during design and deliberately not adopted. The reasoning is preserved here so a future reader (or implementor) can tell what was considered rather than missed.

- **Separate `_execution-state.md` state file** (Michael Forrester's pattern): rejected in Decision 1. The PRD file already serves the role — it persists state on disk, is committed atomically, and is read by existing infrastructure (`auto-reanchor.sh`, `/continue`, `/post-compact`). Introducing a second state file would duplicate state and force a synchronization problem.

- **Task-grain unit of work / sub-task checkboxes inside milestones**: rejected in Decision 1. Milestones are already the atomic commit unit; inner-checkbox tracking would duplicate state and break the atomic-commit invariant. The existing YOLO skills do not track sub-task state.

- **`tasks.yaml` + GUPP principle** (Michael's newer structured task system, covered in PRD 3 of his repo): rejected in Decision 1. Adds dependency tracking and crash-recovery semantics that the existing PRD structure already provides at milestone grain.

- **WIP commits during milestone execution** (interim commits that don't flip the milestone checkbox): rejected during Decision 1 / Decision 2 design. The atomic-commit invariant (code + PRD checkbox + PROGRESS.md in one SHA) is the basis of `auto-reanchor.sh`'s "last `[x]` = last commit" recovery logic; WIP commits would break it without adding enough value to justify the reshaping.

- **Claude Code parent orchestrator that spawns `claude -p` children and babysits them** (Option B in the architecture discussion): rejected for Decision 2. The parent session has its own context limits and compaction risk; a shell script orchestrator has neither and is deterministic.

- **Hybrid observer — shell drives, Claude Code optionally observes via a `/status` skill** (Option C): rejected for Decision 2. More complex than the pure shell script for no meaningful gain — a post-run review via `/continue` or direct log reading covers the observation need.

- **Self-clearing via `/clear` from within a session**: not possible. Per the [Claude Agent SDK slash commands documentation](https://code.claude.com/docs/en/agent-sdk/slash-commands), `/clear` is a CLI-only command; Claude cannot invoke it programmatically. Replaced with `claude -p`, which spawns a fresh Claude Code session (functionally equivalent for orchestration purposes).

- **Git progress check as a stuck-detection signal** (orchestrator compares git HEAD before/after each iteration and flags "no new commit in N iterations"): rejected during Decision 3 design. Each milestone runs in its own fresh `claude -p` process, so no-new-commit-in-N-iterations adds no information beyond the hard iteration cap. Also false-positives on legitimately slow milestones (research-heavy, mid-refactor).

- **Stop hook (`auto-test-on-stop`) adopted for autonomous mode**: declined. Originally skipped for interactive mode in [PRD 58 Decision 6](./58-workflow-session-hygiene.md) (latency cost per response outweighed benefit). For autonomous mode the rationale initially flipped ("no Whitney at keyboard to run tests manually"), but Decision 5 here (tests on every push) closes the actual coverage gap without per-response test latency. The `/prd-next` YOLO prompt already mandates TDD, so children run tests themselves via `Bash(bats*)` etc. between changes.

- **PostCompact hook auto-invoking the `/post-compact` skill via an `additionalContext` nudge**: initially proposed as a separate decision, retracted when we discovered `scripts/auto-reanchor.sh` (shipped under PRD 58 M2) is already a PostCompact hook whose output includes the line *"ACTION: Re-read CLAUDE.md and the active PRD now to restore full context."* The nudge mechanism is already in place; no new decision or implementation needed. M4 includes a small cleanup to remove the hook's dead `_execution-state.md` reference.

- **Adding a new `unit_test` slot to `verify.json` schema**: considered for Decision 5, rejected in favor of reusing the existing `test` / `acceptance_test` split. The existing schema already expresses "fast safe" vs. "expensive"; the burden is on each repo to use the slots correctly rather than on the schema to add a third tier.

## Design Decisions

| # | Date | Decision | Rationale | Downstream Impact |
|---|------|----------|-----------|-------------------|
| 1 | 2026-04-18 | Unit of work is milestone-grain. The PRD file itself is the execution state file — no separate `_execution-state.md`. | The existing PRD workflow already treats milestones as the atomic unit: each milestone maps to one commit, sub-task deliverables are tracked as bulleted `To implement` items within the milestone (not as separate checkbox state), and PROGRESS.md provides the per-commit narrative. Michael's `_execution-state.md` was solving a problem this repo doesn't have — he has no PRD equivalent. Introducing task-grain tracking would break the atomic-commit invariant, duplicate state, and ignore infrastructure (`auto-reanchor.sh`, `/continue`, `/post-compact`) that already reads PRDs for recovery. | All remaining milestones of PRD 84 build on the existing PRD structure rather than replacing it. No new `_execution-state.md` file. Mid-milestone compaction becomes a narrower, targeted problem addressed by Decision 2. |
| 2 | 2026-04-18 | Autonomous execution is a shell-driven Ralph loop using `claude -p`. An outer bash script (e.g., `scripts/autonomous-prd.sh`) iterates through milestones; each milestone runs in a fresh `claude -p` child session. | Claude cannot self-`/clear` (CLI-only per the Agent SDK docs), but `claude -p` spawns a new headless Claude Code session with the same skills, hooks, and settings — functionally equivalent to `/clear` for orchestration purposes. The Ralph loop pattern (coined by Geoffrey Huntley, [ghuntley.com/loop](https://ghuntley.com/loop/)) is the canonical autonomous architecture: fresh context per iteration, state persists on disk, git diffs signal progress. The shell orchestrator is deterministic with no context limits of its own. Each child is full Claude Code (not raw Anthropic SDK) so the existing workflow toolchain — `/prd-next`, `/prd-update-progress`, hooks, CodeRabbit review — carries over unchanged. | Compaction within a single `claude -p` iteration becomes the narrow edge case, handled by existing `auto-reanchor.sh`. Permission model must be solved for autonomous children (`/make-autonomous` is the hook). Stuck detection (hard iteration caps + git progress checks) will be a future decision. An implementation milestone will create `scripts/autonomous-prd.sh` as the orchestrator. |
| 3 | 2026-04-18 | Pause mechanism: both stuck detection and human-in-the-loop handoff use a single marker (`**Paused — <reason>:** <detail>`) written directly into the active milestone section of the PRD. The orchestrator greps the PRD before each iteration; if `**Paused` is found, it exits and reports the reason without spawning the next child. | Consolidates two failure modes into one mechanism, consistent with Decision 1 (PRD is the state file). No separate state files, no dedicated skill, no extra notification channel. The child writes the marker when it needs a decision (milestone text instructs it to); the orchestrator writes the marker when the per-milestone iteration cap is reached. Community consensus (snarktank/ralph, frankbria/ralph-claude-code, Michael's analyzer) is that robust automated stuck detection is unsolved — start with a hard iteration cap and tune from usage, don't over-engineer. | Implementation must include: (1) pre-spawn `grep '\*\*Paused'` in `scripts/autonomous-prd.sh`; (2) a child-side convention documented in the milestone prompt — "if you need a human decision, write `**Paused — needs Whitney:** <analysis/question>` into the active milestone and exit"; (3) **a global rule (in `~/.claude/CLAUDE.md` or a new `rules/autonomous-pause-handling.md`) documenting the pause-handling protocol — the pause marker MUST be removed before restarting the orchestrator or the loop will refuse to resume**; (4) iteration cap threshold (e.g., 3–5) TBD at implementation time, tunable from real usage. |
| 4 | 2026-04-18 | Permission model: extend the existing `/make-autonomous` skill's allowlist to cover the tools and commands an autonomous `claude -p` child needs for a full PRD milestone. The orchestrator does a pre-flight check — if `/make-autonomous` has not been run in the target repo, it exits and tells the user to run it first. | Audit of `/make-autonomous` found that ~85% of what's needed is already in its allowlist (git ops, gh CLI, PRD skills, Read/Edit/Write). The remaining gaps are trivial JSON additions — no structural change, no new CLI flags, no separate permission infrastructure. `/make-autonomous` already exists as the designated autonomous-mode on-switch; leveraging it is consistent with the rest of the design (lean on existing infrastructure, don't reinvent). | Extension is a milestone within this PRD. Exact entries to add to `permissions.allow` in `/make-autonomous`'s configuration: `Bash(npm test*)`, `Bash(npm run build*)`, `Bash(npm run *)`, `Bash(npx vitest*)`, `Bash(pytest*)`, `Bash(bats*)`, `TaskCreate`, `TaskUpdate`, `TaskGet`, `TaskList`, `Agent`, `ScheduleWakeup`. Without these, `claude -p` stalls on permission prompts for test runs, task tracking, and sub-agent spawning. `/make-careful` may need symmetric removals but probably does not — careful mode keeps most things off by design. |
| 5 | 2026-04-18 | Pre-push git hook runs the `test` command unconditionally, not only when a PR exists. Each repo's verify.json convention (`test` = fast/safe, `acceptance_test` = expensive/API-calling) is the mechanism for excluding e2e and external-service-calling tests from push-time runs. | Reading the actual hook files revealed `pre-commit-verify.sh` runs build/typecheck/lint only (no tests) and `pre-push-verify.sh` runs tests only when an open PR already exists. For autonomous mode before PR creation, no hook-level test enforcement exists — broken tests could accumulate across many committed milestones before CI catches them. Running tests on every push closes the gap without adding mode-detection logic, leveraging the existing verify.json schema's `test`/`acceptance_test` split. Spinybacked-orbweaver audit confirmed its `test` command already excludes acceptance-gate and API-calling tests via vitest config exclusions — the change is safe without per-repo cleanup there. | Adds a milestone to PRD 84 for the `pre-push-verify.sh` change and its bats test. Convention for new repos opting into autonomous mode: `test` command must exclude e2e and external-service-calling tests; put those in `acceptance_test` instead. Other existing repos may need verify.json audits when first used autonomously — case-by-case, not blocking for this PRD. |

## Progress

_Updated by `/prd-update-progress` as milestones complete._
