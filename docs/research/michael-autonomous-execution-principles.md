# Michael Forrester's Autonomous Execution System — Design Principles

**Purpose:** Extract the load-bearing design principles from Michael Forrester's `/plan-execute` and `/long-run` skills to inform Whitney's own autonomous PRD execution system.

**Sources read:**
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/plan-execute/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/long-run/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/plan/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/post-compact/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/continue/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/init-state/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/task/SKILL.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-reanchor.sh`
- `~/Documents/Repositories/forrester-workflow/claude-config/hooks/session-start.sh`
- `~/Documents/Repositories/forrester-workflow/claude-config/hooks/auto-test-on-stop.sh`
- `~/Documents/Repositories/forrester-workflow/claude-config/hooks/check-commit-message.sh`
- `~/Documents/Repositories/forrester-workflow/claude-config/rules/state-persistence.md`
- `~/Documents/Repositories/forrester-workflow/claude-config/settings.json`
- `~/Documents/Repositories/forrester-workflow/claude-config/skills/evals/evals.json`
- `~/Documents/Repositories/forrester-workflow/scripts/tasks.sh`
- `~/Documents/Repositories/forrester-workflow/prds/3-structured-task-management.md`
- `~/Documents/Repositories/forrester-workflow/PROJECT_STATE.md`

**Key observation up front:** The `/plan-execute` and `/long-run` skills are each a single SKILL.md file. There are no helper scripts, no external templates, no utility Python code behind them. The entire autonomous-execution contract is enforced by prompt alone, reinforced by a PostCompact hook (`auto-reanchor.sh`), a SessionStart hook (`session-start.sh`), and a Stop hook (`auto-test-on-stop.sh`). That minimalism is the first load-bearing design choice: **all the smarts are in the prompt, and all the durability is on disk.**

---

## 1. State File Design — `_execution-state.md`

### Template (quoted verbatim from `plan-execute/SKILL.md`)

```markdown
# Execution State

## Plan Source
file: plan.md

## Progress
- [ ] Task 1: [description] — commit: pending
- [ ] Task 2: [description] — commit: pending
- [ ] Task 3: [description] — commit: pending

## Current Task
Index: 1
Description: [from plan]
Status: not started

## Context Health
Last checked: [ISO timestamp]
Compactions this session: 0

## Failure Tracking
Consecutive test failures: 0
```

### Field-by-field intent

| Section | Field | Purpose |
|---|---|---|
| `Plan Source` | `file:` | Points to the immutable plan document (`plan.md`). The state file is mutable state layered on top of a stable plan — the plan is the spec, the state file is the cursor. |
| `Progress` | Checkbox list with `— commit: <hash\|pending>` | Dual-purpose row: one line serves both as the human-readable checklist and as the git-hash ledger tying each task to its commit. Completing a task flips `[ ]` to `[x]` AND replaces `pending` with the commit hash. |
| `Current Task` | `Index`, `Description`, `Status` | Explicit cursor. `Index` is an integer pointer into the Progress list. `Description` is a denormalized copy so Claude doesn't have to cross-reference the plan to know what it's doing. `Status` is a micro-state (not started / in progress / failed). |
| `Context Health` | `Last checked`, `Compactions this session` | Self-reported telemetry. Claude writes here when it notices degradation. The compaction counter is updated by the PostCompact hook's orientation block (not the skill itself). |
| `Failure Tracking` | `Consecutive test failures` | Counter used by the 3-strike rule. Reset to 0 on success, incremented on failure. |

### Load-bearing design choices

1. **Markdown, not JSON/YAML.** The state file is for a human AND an LLM. Markdown reads naturally both ways; no parser needed.
2. **Denormalization is deliberate.** The current task description appears in TWO places (the Progress list and the Current Task block). This is a prompt-engineering safeguard: if Claude reads only one, it still gets the answer. Redundancy is defense against sloppy reads.
3. **Commit hash in the same row as the checkbox.** This is the critical integrity link. It means you can reconstruct state from git if the file is lost (read commit messages → match tasks), AND you can detect drift (state says task 2 is done at commit X, but `git log` has no commit X → file is stale or lying).
4. **One file, repo root.** No directory structure, no naming scheme by date. `_execution-state.md` with a leading underscore to sort to the top of file listings. Presence of the file IS the "in-progress" signal.
5. **Ephemeral by default.** Quote: *"After the plan is fully executed: The user decides whether to keep or delete `_execution-state.md`. It can be committed as a run log or discarded."* The state file is run-log scratch, not a permanent artifact.

---

## 2. The Execution Loop

### The 4-phase inner loop (quoted from `plan-execute/SKILL.md`)

For each task:

**Phase 1 — Pre-Task Check:**
> - Re-read `_execution-state.md` to confirm current task (do NOT rely on memory)
> - Re-read the specific task description from the plan file
> - If context feels degraded (repeating yourself, losing track), run `/post-compact`

**Phase 2 — Execute with TDD:**
> - Write tests for the task (if applicable)
> - Implement minimal code to pass tests
> - Run the full test suite

**Phase 3 — Post-Task Update:**
> - If tests pass: `git commit` with descriptive message; update `_execution-state.md` (mark complete, record commit hash, advance index)
> - If tests fail: attempt fix (max 2 retries per task); if still failing after 2 retries, update state with failure details, stop, report

**Phase 4 — Checkpoint Decision:**
> - All tasks complete → Write completion summary, exit
> - 3 consecutive test failures → Emergency stop
> - Context feels degraded → Commit all work, update state, suggest fresh session with `@_execution-state.md Continue from Task N`

### Decision matrix at the end of each iteration

| Condition | Action | Category |
|---|---|---|
| Current task succeeded, more tasks remain | Continue to next task | Continue |
| All tasks complete | Write completion summary, exit cleanly | Stop (success) |
| 2 retries exhausted on one task | Record failure, stop | Stop (failure) — escalate |
| 3 consecutive failures across tasks | Emergency stop | Stop (failure) — escalate |
| Context degradation detected | Commit, update state, suggest restart | Stop (graceful) — escalate |

### Missing from Michael's loop: the PR gate

Michael's loop ends at "all tasks complete → write completion summary, exit." That works because his autonomous workflow merges directly to the `staging` branch without an external review gate. **Whitney's workflow does not have this property.** Every PRD completion produces a PR that must go through:

1. CodeRabbit CLI review (advisory, pre-push)
2. `gh pr create` (branch-to-main PR)
3. CodeRabbit PR review (blocking, must be addressed)
4. `/code-review` skill run in-session
5. Human approval
6. Merge
7. Branch cleanup

An autonomous PRD executor must extend the decision matrix with a **PR gate stop** that the skill itself cannot clear:

| Condition | Action | Category |
|---|---|---|
| All milestones/tasks complete, PR not yet created | Push, create PR with `gh pr create`, invoke `/code-review`, stop | Stop (handoff) — human required |
| PR exists, CodeRabbit review pending | Wait/stop until review arrives | Stop (blocked on external) |
| PR exists, CodeRabbit review has findings | Surface findings, stop for triage | Stop (blocked on decision) |
| PR approved and merged | Resume on next PRD | Continue at PRD granularity |

**Key consequence:** "stop cleanly and handoff" becomes a first-class loop outcome, distinct from "stop because of failure." The skill must be able to distinguish these — a handoff stop at a PR gate is successful completion of a PRD, whereas a failure stop means something broke. Both commit and write state, but they route the user's next action differently (merge + next PRD vs. investigate + fix).

Michael's design does not need this distinction because `staging` has no external gate. Whitney's design must bake it in from the start.

### Load-bearing design choices

- **No explicit "ask user" branch inside the main loop.** The skill does not ask for mid-execution input. It either continues, stops cleanly, or stops with a flag. Resumption is the user's action (by starting a new session).
- **TDD is baked into Phase 2.** Tests gate progress. Quote from `long-run`: *"Tests gate progress: never advance with failing tests."*
- **Checkpoint decision is its own phase.** It is not an afterthought at the end of execution — it runs after every task, ensuring the loop can stop cleanly at any iteration boundary.

---

## 3. "Never Trust Conversation Memory" Pattern

### Where it appears

1. **Plan-execute Pre-Task Check (step 1 of every iteration):** *"Re-read `_execution-state.md` to confirm current task (do NOT rely on memory)"*
2. **Long-run Execute Tasks in Loop (step 1 of every iteration):** *"Re-read `_execution-state.md` — never trust conversation memory."*
3. **Long-run Checkpointing Rules:** *"State file records what git doesn't — current task index, retry count, failure details, context health observations."*
4. **Plan-execute Key Principles:** *"Disk over memory: The state file is the source of truth, not conversation context."*

### The failure mode this prevents

Quote from `plan-execute/SKILL.md` purpose section:

> This directly prevents the documented 100% hallucination rate after mid-task compaction in Plan Mode.

The concrete failure sequence Michael is defending against:
1. Session starts. Plan is loaded. Task 3 of 10 is complete.
2. Compaction fires. Half the conversation is summarized or dropped.
3. Without re-reading state, Claude "remembers" (via the summary) that task 2 was the last one it finished, or hallucinates a different set of tasks, or starts over from task 1.
4. The re-read makes compaction a no-op — whatever the summary says, the disk is authoritative.

### Design consequences

- **Pre-task re-read is mandatory, not discretionary.** Every iteration starts by opening the same file. It would be tempting (from a latency perspective) to cache — Michael doesn't.
- **The plan file and the state file are read separately.** Phase 1 says "re-read `_execution-state.md`" AND "re-read the specific task description from the plan file." Two files, two reads, every task. Again: redundancy as defense.
- **Trust order is codified in Recovery section:** *"Trust git over the state file if they disagree."* Disk > state file > git log is a total ordering, but git beats the state file when they conflict (because git history is immutable and the state file is writable).

---

## 4. Compaction Recovery

### How the skill distinguishes "resuming" from "starting fresh"

Entry point logic (plan-execute):

> 1. Check for `_execution-state.md` in the repo root.
>    - **If it exists**: Read it. Resume from the recorded current task.
>    - **If it doesn't exist**: Look for `plan.md` or ask the user for a plan. Create `_execution-state.md` from the plan using the template below.
> 2. Confirm orientation with the user:
>    - "Resuming from Task N: [description]" or "Starting fresh from Task 1"
>    - Show total tasks, completed count, current branch

The file's presence is the sole signal. No metadata, no timestamps checked — if `_execution-state.md` exists, resume; otherwise, fresh.

### What happens differently on resume vs fresh start

| Behavior | Fresh start | Resume |
|---|---|---|
| Create state file | Yes, from plan template | No, read existing |
| Start task index | 1 | From `Current Task.Index` field |
| User confirmation | "Starting fresh from Task 1" | "Resuming from Task N" |
| Branch check | Expected: clean tree on `staging` (per long-run prereqs) | Current branch is taken as-is |

### The PostCompact hook as a layered defense

`auto-reanchor.sh` runs automatically on every compaction event (wired in `settings.json` under `"PostCompact"`). Relevant lines:

```bash
# Check for execution state (plan-execute)
EXEC_STATE=""
if [ -f "$REPO_ROOT/_execution-state.md" ]; then
    EXEC_STATE="Active execution state found — read _execution-state.md"
fi
```

And its output goes to stderr (which becomes `additionalContext` in Claude's post-compact prompt):

```bash
cat >&2 <<EOF
--- POST-COMPACTION RE-ANCHOR ---
Repo: $REPO_NAME | Branch: $BRANCH | CLAUDE.md: $HAS_CLAUDE_MD | PROJECT_STATE.md: $HAS_STATE
Recent commits: $RECENT
...
$([ -n "$EXEC_STATE" ] && echo "$EXEC_STATE")
...
ACTION: Re-read CLAUDE.md and PROJECT_STATE.md now to restore full context.
---
EOF
```

This means: the hook doesn't reload state itself — it **reminds Claude to reload state**. The reload is always the LLM's action, triggered by the hook's directive. This preserves the invariant that all state reads go through Claude, so Claude's memory and disk stay in sync.

### The `/post-compact` skill as a third layer

If Claude notices context degradation during execution (per Phase 1: "If context feels degraded... run `/post-compact`"), it can manually invoke the skill. The skill re-reads CLAUDE.md, PROJECT_STATE.md, checks git state, and reports orientation. Note the complementary split:
- `auto-reanchor.sh` (automatic, hook-triggered) — prints a terse orientation block
- `/post-compact` (manual, skill-triggered) — does a deeper re-read of config files
- `_execution-state.md` re-read (mandatory, every task) — the finest-grained recovery

### Load-bearing design choices

1. **Three layers of compaction recovery, but they are NOT equally automated.** The three layers operate at different time scales:
   - **Per-iteration re-read** (Phase 1 of the execution loop): Claude opens `_execution-state.md` before every task. This is automatic *if the skill is followed* — it is a prompt instruction, not a runtime enforcement. A single lapse skips it.
   - **PostCompact hook** (`auto-reanchor.sh`): The hook runs automatically on every compaction event and prints an orientation directive to stderr. But the directive itself doesn't reload state — it *tells Claude to reload state*. The re-read is still Claude's action, not the hook's. The hook is a **nudge**, not an injection. If Claude ignores the directive, recovery silently fails.
   - **Manual `/post-compact`**: Claude invokes the skill *only if it notices degradation* (per Phase 1: "If context feels degraded... run `/post-compact`"). There is no external trigger. If Claude's self-assessment is wrong, the skill is never invoked.

   The correct framing is: the loop is prompt-driven at every level. Hooks provide input to prompts; they do not recover state on their own. A system that described these three layers as "automatic recovery" would overstate their robustness.
2. **Hook output → `additionalContext` → LLM re-read** is the only path state re-enters Claude's working memory. The hook never edits files; only Claude does.
3. **File presence as state.** The system doesn't ask "am I resuming?" by checking a flag — it checks a file's existence. Simple, no false positives from corruption.

## 4b. The Stop Hook as a TDD Loop Tightener

The Stop hook (`auto-test-on-stop.sh`, wired via `settings.json` under `"Stop"`) fires **after every Claude response ends**, runs the test suite in a non-blocking mode, and reports pass/fail back to the next turn's context as a terse one-liner.

### Why it matters for the autonomous loop

The execution loop's Phase 2 (Execute with TDD) says: *"Write tests / Implement / Run the full test suite."* On the surface this looks like it demands a manual test invocation every iteration. In practice, **the Stop hook has already run the test suite between iterations.** When Phase 2 begins, Claude's context already contains the last run's verdict.

This changes the loop's cost profile materially:
- Phase 2 can be brief — the TDD feedback is already in context.
- Claude doesn't have to invoke `npm test` / `pytest` / `cargo test` explicitly in the main flow; the hook is doing it.
- The per-task retry counter is fed by results Claude already knows about, not results it has to re-query.

The combination of Stop hook + Phase 2 is: **tests are always fresh, and the loop never operates with a stale test signal.**

### Why Whitney should reconsider skipping it

Whitney's PRD 58 skipped M3 (this hook) — captured in Decision 6 of that PRD — because her workflow is interactive and the hook's latency/noise during conversational work outweighed the benefit. That calculus is correct for interactive use.

**For an autonomous loop, the calculus inverts.** Interactive sessions want quiet hooks; autonomous sessions want the opposite — every piece of signal that can be surfaced automatically is one less thing prompt discipline has to carry. If the autonomous executor is running without user supervision, its single most reliable input is the test runner's verdict, and the Stop hook delivers that without any prompt-level action.

Recommendation for Whitney's designer: treat the Stop hook as a **per-repo opt-in gated on autonomous mode.** `/make-autonomous` turns it on; `/make-careful` turns it off. The hook is dormant during interactive work and active during autonomous runs. This sidesteps the original noise objection while reclaiming the feedback tightness the autonomous loop needs.

---

## 5. Failure Detection and Escalation

### What counts as a failure

Two failure categories, explicit in the skill:

**Per-task test failure:**
> If tests fail: Attempt fix (max 2 retries per task). If still failing after 2 retries: update state file with failure details, stop execution, report to user.

**Session-wide consecutive failures:**
> 3 consecutive test failures → Emergency stop

These are not the same counter. Per-task retries reset when you move on; consecutive failures accumulate across tasks.

### Stop conditions — the two-counter state machine

Reading `plan-execute` and `long-run` together resolves the ambiguity in the "3-strike" wording: there are **two independent counters running simultaneously**, each with its own increment rule, reset rule, and stop threshold. A single "retry counter" interpretation is wrong — the skills need both.

| Counter | Scope | Increment rule | Reset rule | Stop threshold |
|---|---|---|---|---|
| **Per-task retry counter** | Local to the current task | +1 on each failing test run of the current task | Reset to 0 when the task passes and the loop advances; reset to 0 when the loop begins a new task | 2 retries exhausted (i.e., 3 total attempts: 1 initial + 2 retries) → stop and report |
| **Session-wide consecutive failure counter** (`Consecutive test failures` in state file) | Whole run | +1 each time a task stops with failing tests | Reset to 0 when any task passes | 3 → emergency stop |

Worked example:
- Task 1 fails, fails, fails (3 attempts, per-task counter = 3) → task stops. Session counter = 1.
- Task 2 fails, fails, passes on third try → task advances. Per-task counter resets. Session counter = 0 (success resets it).
- Task 3 fails 3 times → task stops. Session counter = 1.
- Task 4 fails 3 times → task stops. Session counter = 2.
- Task 5 fails 3 times → task stops. Session counter = 3 → **emergency stop.**

The critical design insight: **a single flaky test does not tank the session**, but a pattern of failures does. The per-task counter ensures the skill doesn't loop forever on one broken task; the session counter ensures it stops when the trend indicates something systemic (environment broken, plan wrong, model confused).

Both counters write through to `_execution-state.md` at the end of any failed task so recovery from compaction or crash preserves them.

### Source text (quoted verbatim)

From `long-run` Execution Protocol:
> **Test failure**: Attempt fix (max 2 retries per task). On third failure: update state with failure details, commit passing work, stop.

From `plan-execute` Phase 4 Checkpoint Decision:
> 3 consecutive test failures → Emergency stop

The "3 consecutive test failures" refers to the session-wide counter, not the per-task retry budget. They are counting different events.

### Additional escalation triggers

From `long-run` and `plan-execute`:
- **Context degradation** (repeated ideas, circular reasoning, lost track) → commit, update state, recommend user restart with `@_execution-state.md Continue from Task N`
- **>75% context consumption** (heuristic, not measured programmatically) → checkpoint and stop
- **Unexpected error** (anything not anticipated) → *"Record in state file, commit what works, stop."*

### PR gate stops (added for Whitney's workflow)

These do not exist in Michael's skills — they are mandatory additions for Whitney because auto-merge is not allowed:

- **PR creation point** → stop after `gh pr create` + `/code-review`. Do not auto-advance to the next PRD. Human approval of review findings is required before resumption.
- **CodeRabbit review pending** → stop and report. The executor must not push more commits that would change the diff under active review.
- **CodeRabbit findings to triage** → surface all findings via the three `gh api` calls (reviews, comments, issues/comments) and stop. Each finding needs a fix/defer/skip decision that the executor cannot make autonomously.
- **PR merged, branch deleted** → this is the actual completion signal for a PRD. The next autonomous run starts from a clean main, not from a still-open feature branch.

The shape of the stop is identical to failure stops (commit, write state, report) but the user's action differs: PR-gate stops are expected checkpoints, not emergencies. The state file should distinguish them so `/continue` can describe "you have a PR awaiting review" vs. "you have a failed task needing fix."

### How failures surface to the user

All escalation paths have the same shape:
1. Write failure details to `_execution-state.md` (what failed, why, at which task)
2. Commit whatever work is passing (never leave uncommitted garbage)
3. Print a report to the user with a resume instruction

Quote from `long-run` Key Principles:
> **Never push through confusion** — stopping early with state preserved is always better than producing broken code.

### Load-bearing design choices

1. **Two counters, not one.** Per-task retries and session-consecutive failures are tracked separately so a flaky test run doesn't force a stop, but a trend of failures does.
2. **Commit before stopping.** Every escalation ends with a `git commit` of the passing work. This is what makes resumption possible — the checkpoint exists on disk, not just in the state file.
3. **Failure is never silent.** No fallback, no auto-skip. Stop and report; let the user decide. This aligns with Whitney's global rule: *"NEVER add fallback mechanisms without explicit permission. Code should fail explicitly rather than silently fall back to defaults."*

---

## 6. Commit Cadence

### When the skill commits

**Rule: one task = one commit.** Quoted from multiple places:

- Plan-execute: *"Commit after every task: Creates rollback points"*
- Long-run Checkpointing Rules: *"Commit after every task — creates rollback points."*
- Long-run Checkpointing Rules: *"Never batch multiple tasks into one commit — defeats rollback."*

### What goes in commit messages

The skill says only *"`git commit` with descriptive message"* — no enforced template. Practically this means the commit message describes the task that was completed. The discipline is: the commit message should let someone reading `git log --oneline` reconstruct the task list.

### Commit-message quality is load-bearing for recovery

This is easy to under-weight. The autonomous recovery path in both `plan-execute` and `/continue` reads `git log` when the state file is missing, stale, or contradicts itself ("Trust git over the state file if they disagree"). If commit messages are vague — "fix stuff", "wip", "updates" — that recovery path degrades into guesswork. Specifically:

- `_execution-state.md` records a commit hash per task row. If that hash is present in git log with a clear message, recovery is one `git show` away.
- If the hash is missing (file drifted from git), the executor has to reconstruct task→commit mapping from the log. Vague messages make this impossible.
- The session-wide consecutive-failure counter can also be reconstructed from commit history (counting passing-work commits vs. stop-and-record commits) — but only if commit messages distinguish the two.

Michael mitigates this with a PreToolUse hook, **`check-commit-message.sh`** (wired in `settings.json` under `"PreToolUse"` matcher `"Bash"`), which blocks commits whose messages contain AI/Claude/Anthropic attribution patterns — ensuring messages stay professional and task-focused. The hook does not enforce a positive template (e.g., "must mention the task ID"), only a negative one. That is enough to keep messages from being cluttered with model disclaimers.

**For Whitney's autonomous design:** the executor must produce commit messages structured enough that a future `/continue` can parse them reliably. Options:

- **Enforced prefix convention** via a commit-msg hook: `feat(prd-N): M<milestone> — <task>` or similar. Extends Whitney's existing `check-commit-message.sh` pattern.
- **Task ID in every message** if adopting `tasks.yaml`: `tk-a1b2: exponential backoff with retries`. Enables exact parsing.
- **Structured trailer**: `Task-Id: tk-a1b2`, `PRD: 58`, `Milestone: M5` as git trailers. Parses cleanly with `git log --format=...` or `git interpret-trailers`.

Vague messages are a silent recovery tax. Treat message structure as part of the state-durability contract, not as an optional convention.

### How commit hashes tie back to execution state

The Progress section of `_execution-state.md` has the form:

```markdown
- [x] Task 1: [description] — commit: abc1234
- [x] Task 2: [description] — commit: def5678
- [ ] Task 3: [description] — commit: pending
```

Every completed task row carries its commit hash. This enables:
- **Bidirectional traceability**: task → commit and commit → task.
- **Drift detection**: if a recorded commit hash isn't in `git log`, the state file is wrong. (Recovery resolves this by trusting git.)
- **Safe rollback**: revert a commit and uncheck the row; the next run re-executes the task.

### Load-bearing design choices

1. **Atomic task-commit coupling.** Because one task = one commit, a commit is both the durability mechanism AND the progress marker. You cannot be "half done" with a task in this system — you either committed or you didn't.
2. **Git as the ultimate source of truth.** Quote: *"Trust git over the state file if they disagree."* The state file is a convenience layer; git is the truth.
3. **The state file is derivable from git.** In principle, you could regenerate most of `_execution-state.md` by parsing `git log` against the plan. The state file exists for cheap reads and for fields git doesn't track (retry count, context health).

---

## 7. Assumptions About User Absence

### What the skill decides autonomously

- Which task to start with on resume (from `Current Task.Index`)
- Whether to retry a failing test (up to 2 retries)
- Whether tests are "passing" enough to advance
- Commit message wording
- Whether context feels degraded enough to stop
- Whether to invoke `/post-compact` mid-execution

### What the skill escalates

- Any task that fails 3 times total
- 3 consecutive failures across tasks (session-wide trend)
- Context degradation (suggests user restart session)
- Unexpected errors
- Completion (reports summary, awaits next instruction)
- **Whether to keep or delete `_execution-state.md`** after completion

### The implicit model of "Claude can proceed unsupervised when..."

Reading across `plan-execute` and `long-run`, the implicit rules are:

1. **A plan exists and is fixed.** The user has already consented to the goals. Claude is not redefining scope mid-run.
2. **The steps are decomposable and testable.** Quote from `long-run` prereqs: *"The plan must decompose into independently committable steps."*
3. **Clean tree, designated branch.** Quote: *"The repo must be on the `staging` branch with a clean working tree."* No autonomous execution on messy state.
4. **Tests are the oracle.** Because TDD is baked in, Claude has an objective signal of "did this work." Without tests, the autonomous loop has no basis for Phase 4 decisions.
5. **Stopping is free.** Nothing bad happens when you stop — state is on disk, work is committed. So the bias is heavily toward stopping over pushing through uncertainty.

### Load-bearing design choices

1. **The skill does NOT make scope decisions.** It executes a pre-approved plan. If the plan doesn't cover a case, the skill stops — it does not freelance.
2. **Autonomy is time-bounded by tests, not by task count.** The loop runs as long as tests pass and context is healthy. It does not have an internal "I've done enough" heuristic.
3. **Every stopping point is a safe resumption point.** The user's cost of interrupting is zero — which is what makes unsupervised execution acceptable.

---

## 8. Integration With Other Systems

### What Michael's system assumes exists

| Artifact | Purpose | Required? |
|---|---|---|
| `plan.md` | Immutable task list the state file refers to | Yes (or user must be present to supply one) |
| `_execution-state.md` | Mutable cursor (created by skill) | Created on first run |
| `PROJECT_STATE.md` | Durable per-repo state (separate from execution state) | Expected by post-compact and auto-reanchor hooks |
| `CLAUDE.md` | Project-level rules re-read on compaction | Expected |
| PostCompact hook (`auto-reanchor.sh`) | Automatic re-anchor after compaction | Wired via `settings.json` |
| SessionStart hook (`session-start.sh`) | Surfaces pending state at session start | Wired via `settings.json` |
| Stop hook (`auto-test-on-stop.sh`) | Non-blocking test run after each response — tightens the TDD loop | Wired via `settings.json` |
| `/post-compact` skill | Manual re-anchor | Expected |
| `/plan` skill | Produces the `plan.md` that `plan-execute` consumes | Prerequisite |
| `/continue` skill | Session-start resume (reads PROJECT_STATE.md, git log) | Paired with `/init-state` and `/plan-execute` |
| `staging` branch | Designated branch for autonomous work | Expected |
| Test runner (pytest / npm / cargo) | Called by Stop hook and by Phase 2 of loop | Auto-detected by hook |

### The ecosystem in one picture

```text
┌─────────────────────────────────────────────────────────────┐
│                    USER                                      │
│                     │                                        │
│        ┌────────────┼────────────┐                           │
│        ▼            ▼            ▼                           │
│    /plan       /plan-execute   /continue                     │
│    (creates    (executes it)   (session resume)              │
│    plan.md)                                                  │
│        │                                                     │
│        └──────────┬─────┐                                    │
│                   ▼     ▼                                    │
│              plan.md  _execution-state.md                    │
│                          ▲                                   │
│                          │ read on every task                │
│                          │ updated on every commit           │
│                                                              │
│   Hooks (always running):                                    │
│   SessionStart → session-start.sh → surfaces pending state   │
│   PostCompact  → auto-reanchor.sh → directs re-read          │
│   Stop         → auto-test-on-stop.sh → reports test status  │
└──────────────────────────────────────────────────────────────┘
```

### What Whitney doesn't have an equivalent for

- **`staging` branch workflow** — Whitney uses feature branches per PRD, not a shared `staging`. This is a **structural fork**, not a cosmetic difference — see callout below.
- **`plan.md`** — Whitney has PRDs in `prds/` with structured milestones; these replace `plan.md`. But note: Michael's plans are flat task lists, while PRDs have milestones with their own acceptance criteria. The unit of work differs.
- **`PROJECT_STATE.md`** — Whitney has PRD PROGRESS.md sections instead. Different naming, different scope (per-PRD not per-repo).
- **Observatory** — Michael has workflow telemetry (session JSONL parsing, weekly digest). Whitney does not.
- **`tasks.yaml`** — Michael's newer structured task system. Whitney uses Claude Code's built-in TaskCreate/TaskUpdate/TaskList instead.

### The staging-branch fork is load-bearing for state-file lifecycle

Michael's `_execution-state.md` is a file that lives on the `staging` branch. Because `staging` is long-lived and shared across PRDs, the state file can persist across runs — it is checked in, checked out, updated, committed. The file and the branch have the same lifecycle: both are permanent fixtures of the repo.

Whitney's workflow is the opposite shape: every PRD runs on its own feature branch (`feature/prd-N-slug`), which is created from main, ships a PR, merges, and is **deleted**. Every branch is ephemeral. This forces a mandatory design decision that Michael's system never has to face:

> **Where does the state file live for a PRD-scoped autonomous run?**
>
> 1. **On the feature branch only** (deleted when the branch is deleted after merge). Matches branch lifecycle. Loses run-log history. Clean.
> 2. **On main**, like `PROGRESS.md` in each PRD file. Persists forever. But then it must be committed on the feature branch before merge, which means it appears in the PR diff.
> 3. **Not committed** — `.gitignored`, local only. Survives the branch (doesn't get deleted with the ref), but does not survive a fresh clone or a new machine.
> 4. **Hybrid**: live on the feature branch during execution; on PR merge, copy a summary into the PRD's `## Progress` or `## Decision Log` section for permanence, then drop the raw state file.

This is not a minor detail — it determines what "resume" even means. If the state file is on the feature branch and the feature branch is gone, recovery has to come from git log + PRD progress markers (the way Michael's recovery falls back to git log when the state file lies). If it is on main, multiple PRD branches could collide on the same file. If it is `.gitignored`, a new machine cannot resume at all.

**Treat this as a mandatory design decision the new PRD must answer before any implementation.** It shapes the recovery semantics for everything downstream.

### What Whitney has a different equivalent for

| Michael | Whitney |
|---|---|
| `plan.md` | `prds/<feature-name>.md` with milestones |
| `PROJECT_STATE.md` | PRD `## Progress` / `PROGRESS.md` section per PRD |
| `/plan` | `/prd-create` |
| `/plan-execute` | (Gap — this is what PRD 58 M5 may fill) |
| `/continue` | `/continue` (already adopted in M4 of PRD 58) |
| `/post-compact` | `/post-compact` (already adopted in M2 of PRD 58) |
| `auto-reanchor.sh` PostCompact hook | `auto-reanchor.sh` (already adopted in M2 of PRD 58) |
| `session-start.sh` SessionStart hook | Existing SessionStart hook (already wired) |
| `auto-test-on-stop.sh` Stop hook | Skipped per PRD 58 M3 (judged to be an autonomous pattern, not a universal one) |
| TDD per task | TDD per task + CodeRabbit PR review before merge |
| Single `staging` branch | Feature branch per PRD (must be mergeable from main independently) |
| `_execution-state.md` | (Gap — needs design) |

### What Whitney has that Michael doesn't, relevant to autonomous execution

- **CodeRabbit review gate** — PRs require review before merge. An autonomous executor cannot merge a PR itself; human approval is still mandatory at PR boundaries.
- **`/code-review` skill** — Runs immediately after PR creation. Another gate the executor needs to handle.
- **`make-autonomous` / `make-careful` skills** — Already scaffold YOLO mode for a project. An autonomous executor would want to check which mode is active.
- **`/write-docs` and `/write-prompt` skills** — Mandatory for docs and prompts. An executor writing milestone docs must invoke these.
- **PRD decision cascade** — When a Decision Log row is added to a PRD, downstream milestones must be re-evaluated. An executor doing autonomous PRD work needs to respect this.

---

## 9. Structured Task Management — `tasks.yaml` and the GUPP Principle

This is a **parallel, newer state system** Michael added after the basic `plan-execute` / `long-run` skills (documented in his PRD 3, "Structured Task Management with Crash Recovery," created 2026-04-10). It is not a replacement for `_execution-state.md` — it is a second, independent state machine intended for a different grain of work. Understanding both, and how they differ, is essential before designing Whitney's system.

### What `tasks.yaml` is

A **machine-readable** YAML file at the repo root, containing a list of structured tasks with IDs, statuses, priorities, and dependency links. Committed to git. Managed via the `/task` skill, which delegates to `scripts/tasks.sh` for deterministic YAML manipulation (`yq`-based).

Quoted schema from PRD 3 and `scripts/tasks.sh`:

```yaml
version: 1
tasks:
  - id: tk-a1b2
    title: "Add retry logic to dispatch loop"
    status: ready          # blocked | ready | claimed | interrupted | done
    priority: high         # high | medium | low
    blocks: [tk-c3d4]      # IDs this task blocks (downstream)
    blocked_by: []         # IDs blocking this task (upstream)
    claimed_by: null       # session identifier when claimed (e.g., "session-1712781234")
    created: 2026-04-10
    notes: "See dispatch.py §4.2"
```

ID format: `tk-` + 4 hex chars (e.g., `tk-a1b2`). Generated by `printf 'tk-%04x' $((RANDOM))`.

A sibling file, `tasks-history.yaml`, is an **append-only archive** of completed tasks. When a task hits `done`, the script moves it out of `tasks.yaml` and into `tasks-history.yaml` with a one-line completion summary.

### How it relates to `_execution-state.md`

These are **two different state machines solving two different problems**, and they can coexist:

| Dimension | `_execution-state.md` | `tasks.yaml` |
|---|---|---|
| Unit of work | Task in a plan (index-addressed) | Independent task (ID-addressed) |
| Ordering | Linear, 1..N; plan defines order | DAG; dependencies define order |
| Parallelism | None — single cursor | Multi-agent capable (claim locks) |
| Produced by | `/plan` creating `plan.md` | `/task new`, or manually |
| State format | Markdown, denormalized for LLM reads | YAML, deterministic for scripts |
| Lifecycle | Created at run start, potentially deleted on completion | Persistent; tasks come and go, file stays |
| Recovery grain | Resume at Task N of a single plan | Resume claimed task across sessions |
| Who reads it | The LLM | The LLM AND hooks (via yq) |

They do not compete. `_execution-state.md` is for "a plan I am walking linearly." `tasks.yaml` is for "a queue of independently triagable work items with dependencies." A large autonomous run could, in principle, use both: one `tasks.yaml` holding the PRD-level work, and a short-lived `_execution-state.md` inside each claimed task while it executes.

### The GUPP principle (Gas Town "Git-Update-Pull-Push")

Borrowed from Steve Yegge's Gas Town workflow: **"If there is work on your hook, you MUST run it."** Translated to Michael's system: if a new session starts and finds a `claimed` or `interrupted` task in `tasks.yaml`, the session picks it up automatically — no explicit `/continue` invocation required.

This is a structurally different recovery model from `_execution-state.md`:

- `_execution-state.md` recovery is **pull-based**: the user (or a skill) must invoke `/plan-execute` or `/continue` to read state and resume.
- `tasks.yaml` recovery is **push-based**: hooks surface the claimed/interrupted task at session start and compaction, nudging Claude to resume without explicit invocation.

The `auto-reanchor.sh` hook reads `tasks.yaml` on every compaction and prints the claimed/interrupted task into the orientation block:

```bash
if [ -f "$REPO_ROOT/tasks.yaml" ] && command -v yq >/dev/null 2>&1; then
    CLAIMED=$(yq '.tasks[] | select(.status == "claimed") | .id + " — " + .title' "$REPO_ROOT/tasks.yaml" 2>/dev/null || true)
    INTERRUPTED=$(yq '.tasks[] | select(.status == "interrupted") | .id + " — " + .title' "$REPO_ROOT/tasks.yaml" 2>/dev/null || true)
    if [ -n "$CLAIMED" ]; then
        ACTIVE_TASK="ACTIVE TASK (resume): $CLAIMED"
    elif [ -n "$INTERRUPTED" ]; then
        ACTIVE_TASK="INTERRUPTED TASK (check before resuming): $INTERRUPTED"
    fi
fi
```

The directive at the end of the reanchor block is: *"Re-read CLAUDE.md and PROJECT_STATE.md now to restore full context. Check tasks.yaml for current task state."* The GUPP property falls out of this — the hook makes sure the agent sees the claimed task, and prompt discipline carries the rest.

### Dependency tracking via `blocks` / `blocked_by`

Every task carries two lists:

- `blocks: [ids...]` — downstream tasks this task prevents from starting
- `blocked_by: [ids...]` — upstream tasks that must complete before this task can start

Status auto-derives from dependencies:
- If `blocked_by` is non-empty, status is `blocked`.
- When an upstream task completes (`/task done`), the script walks its `blocks` list, removes itself from each downstream task's `blocked_by`, and flips any downstream task whose `blocked_by` is now empty from `blocked` to `ready`.

This is implemented deterministically in `tasks.sh`:

```bash
# From cmd_done — unblock downstream tasks
blocks_list="$(yq ".tasks[${idx}].blocks[]" "${TASKS_FILE}")"
while IFS= read -r blocked_id; do
    bidx="$(find_task_index "${blocked_id}")"
    yq -i "del(.tasks[${bidx}].blocked_by[] | select(. == \"${id}\"))" "${TASKS_FILE}"
    remaining="$(yq ".tasks[${bidx}].blocked_by | length" "${TASKS_FILE}")"
    if [[ "${remaining}" -eq 0 ]]; then
        yq -i ".tasks[${bidx}].status = \"ready\"" "${TASKS_FILE}"
    fi
done <<< "${blocks_list}"
```

**Why this matters for autonomous execution:** without dependency tracking, an autonomous executor could pick up a task that is nominally "next" but actually blocked on work that hasn't happened yet. That produces broken code, confused state, or worse — commits that pass tests locally but will be undone when the blocker eventually resolves. Losing dependency tracking is a correctness bug, not a convenience one.

### Claim / release semantics (`status: claimed` + `claimed_by`)

`/task claim <id>` is atomic and **locks** a task to a single session:

```bash
# cmd_claim
if [[ "${status}" == "claimed" ]]; then die "Task ${id} is already claimed."; fi
if [[ "${status}" == "blocked" ]]; then die "Task ${id} is blocked. Resolve dependencies first."; fi
yq -i ".tasks[${idx}].status = \"claimed\" | .tasks[${idx}].claimed_by = \"session-$(date +%s)\"" "${TASKS_FILE}"
```

`claimed_by` stores a session identifier (a unix-timestamp string) so that worktree agents running in parallel can tell each other's claims apart. The claim is the lock.

Release comes in two shapes:

1. **Normal release: `/task done <id> <summary>`** — removes the task from `tasks.yaml`, appends a completion entry to `tasks-history.yaml`, and unblocks downstream tasks.
2. **Interrupt release: `/task interrupt`** — called by the SessionEnd hook. Sweeps all `claimed` tasks back to `interrupted` and clears `claimed_by`. An `interrupted` task can only be re-claimed by a future `/task claim` — it does not auto-resume. Quote from the skill: *"Interrupted tasks revert to ready on the next claim attempt — agent must consciously decide to resume."*

This prevents a class of bug: a session crash leaves a task nominally "claimed" by a session that no longer exists, and a future agent could either (a) inherit that claim silently and clobber work, or (b) respect the stale claim and refuse to pick up anything. The interrupt-on-session-end + conscious re-claim pattern eliminates both outcomes.

### Why Whitney must decide about `tasks.yaml` explicitly

Michael's PRD 3 is, in effect, a **retrofit** on top of `plan-execute` / `long-run`. He shipped the simpler system first, then layered structured tasks on top. Whitney is designing from whole cloth and has to decide whether to:

1. **Adopt both systems** — `_execution-state.md` for linear plan walks and `tasks.yaml` for structured task queues. More power, more surface area.
2. **Adopt only `_execution-state.md`** — simpler, but loses dependency tracking, GUPP recovery, and multi-agent claim semantics.
3. **Adopt only `tasks.yaml`** — structural and machine-readable, but loses the plan/cursor separation that makes linear PRD execution easy to reason about.
4. **Build a PRD-native equivalent** — a third state format designed around PRDs with milestones, which is Whitney's natural unit, rather than inheriting either of Michael's shapes.

The key pieces Whitney cannot lose no matter which path she takes:
- Dependency awareness (whether via `blocked_by` or via PRD-dependency-management rules)
- A conscious re-claim step after crash (no silent auto-resume)
- Machine-readable state parseable by hooks, not only by the LLM

---

## Load-Bearing Patterns (Summary for Design)

If Whitney adopts this for autonomous PRD execution, these are the patterns that MUST carry over:

1. **Disk state with a denormalized cursor.** One markdown file at repo root, with the current-task description present in two places, and the plan reference external.
2. **Re-read before every task.** Both the cursor file AND the plan file. No caching.
3. **One task = one commit = one row update.** Atomic progress unit; never batch.
4. **Commit hash in the cursor row.** Enables drift detection and git-as-truth recovery.
5. **Layered compaction defense.** Three mechanisms: PostCompact hook, `/post-compact` skill, mandatory per-task state re-read.
6. **Two failure counters.** Per-task retries (reset on task completion) and session-wide consecutive failures (cumulative).
7. **Stop is free.** Every stopping point commits and writes state. Bias toward stopping over pushing through.
8. **Tests as the loop oracle.** No TDD, no autonomous loop — Phase 4 decisions lose their ground truth.
9. **File presence as resume signal.** No flags, no timestamps — `_execution-state.md` exists means "in progress."
10. **All state reads go through Claude.** Hooks direct Claude to read files; they never patch Claude's memory directly.

## Patterns That Feel Fragile

Worth calling out for Whitney's design, these are the places Michael's system is held together by prompt discipline alone:

1. **"Never trust memory" is enforced only by text.** Nothing prevents Claude from skipping the re-read. The skill relies on the LLM following the instruction every iteration; one lapse could corrupt state.
2. **The `Context Health` and `Consecutive test failures` counters are self-reported by the LLM.** No external process increments them. Claude has to be honest about degradation and failures.
3. **The "3-strike rule" counter has a semantic ambiguity** (per-task vs. across-task) that resolves only by reading both skills together. A single consolidated definition would be clearer.
4. **Commit hash drift is only caught at recovery time.** The skill doesn't verify commit hashes before advancing — it only relies on git as an arbiter when state is suspect.
5. **"Context feels degraded" is a vibe check with no external verification.** Michael offers three heuristics plus a fourth threshold — repeated ideas, losing track, circular reasoning, and >75% context consumption — but **none of them are programmatically measured.** They are entirely self-reported by the LLM. Nothing confirms Claude actually ran the check before advancing; nothing catches dishonest or inattentive self-assessment.

   **Options for Whitney's design, ordered by engineering cost:**
   - **Acknowledge as a known limitation.** Leave it self-reported, but surface this explicitly in the state-file schema and in the recovery documentation so future operators aren't surprised when the executor blows past its own degradation signals. Cheapest, least safe.
   - **Add measurable proxies** that the executor or a hook can check deterministically. Examples:
     - Same commit message stem repeated in the last 3–5 commits → likely re-doing work, stop.
     - Same test file modified 3+ times without the failing test flipping to green → stuck, stop.
     - `_execution-state.md` has been read but the `Current Task.Index` field hasn't changed in N iterations → not making progress, stop.
     - Turn count since last successful task > K → heuristic time cap.
   - **Add a validation hook** (PreToolUse on `git commit` or on state-file write) that fails the step unless a "context-check" field in `_execution-state.md` was updated within the last iteration. Cheapest way to force the check, at the cost of hook-config complexity and potential false blocks.
   - **Token-budget tracking**: the 75% figure could become real if the Stop hook reports approximate input-token consumption. This is not something Claude Code exposes natively today, but an approximation via transcript line count or file-size heuristics is possible.

   Whichever path Whitney picks, the new PRD should **explicitly name it** rather than inheriting Michael's self-reported model by default. Self-reporting is the status quo only because Michael accepted the fragility — Whitney can choose not to.
6. **PRD-milestone unit differs from task unit.** Michael's plans are flat tasks. A PRD milestone may contain many tasks, and a milestone is the commitable unit in Whitney's world. The adaptation will need to decide: is the cursor at task-grain or milestone-grain? Task-grain matches Michael's design more faithfully; milestone-grain matches Whitney's existing workflow. A hybrid ("current milestone, current step within milestone") may be cleanest.
7. **No mechanism handles PRD dependency discovery mid-execution.** If the executor hits a cross-PRD dependency, Michael's model doesn't cover this. Whitney's rule (*"Every milestone must be implementable assuming only what is currently on main"*) must be enforced by the PRD design phase, not the execution phase — otherwise the executor will hang.
8. **The skill assumes CI/CodeRabbit are absent.** For Whitney, the PR gate means the "all tasks complete → exit cleanly" path can't just end — it needs to create a PR, handle CodeRabbit findings, and potentially iterate. This is a significant shape change.

## Design Forks for Whitney's Designer

These are the explicit decisions the new autonomous-PRD-execution PRD must make. Each has been raised in context above; this is the consolidated list. The designer should not start writing milestones without picking an answer for each — these choices cascade into the state-file schema, the hook wiring, and the recovery semantics.

1. **Unit of work.** Task-grain (Michael's `plan.md` flat list), milestone-grain (Whitney's PRD structure), or a hybrid where the cursor records both `Current Milestone` and `Current Task Within Milestone`? Task-grain most faithfully reproduces Michael's loop; milestone-grain most cleanly matches the existing PRD workflow. The hybrid is probably cleanest but adds one more field to the state file. Picking determines whether `_execution-state.md` has one cursor or two.

2. **State-file scope and branch lifecycle.** Where does `_execution-state.md` (or its Whitney-equivalent) live?
   - Repo-level persistent (Michael's staging model): impossible if feature branches are ephemeral.
   - Per-feature-branch, deleted on merge: natural, but loses run history.
   - On main, updated in-PR: collides between concurrent PRDs.
   - Hybrid: ephemeral file during execution + summary into PRD on merge.

   This choice determines what "resume" can even mean after a merge.

3. **PR gate integration.** The autonomous loop must stop at PR creation, wait for CodeRabbit + human review, and resume either (a) to address findings on the same branch or (b) on a new PRD after merge. Decide the state-file fields needed to express "PR awaiting review" as a first-class state, and the resumption protocol for findings-triage.

4. **Structured tasks.** Adopt the dual-system (`_execution-state.md` + `tasks.yaml`) that Michael ended up with? Adopt only one? Or build a PRD-native state format that replaces both? Dropping `tasks.yaml`'s dependency tracking requires Whitney's PRD-dependency-management rules to carry the full load of ordering correctness.

5. **Stop hook adoption.** Reconsider PRD 58's M3 skip. Interactive sessions correctly judged the Stop hook too noisy; autonomous runs may need it. Options: enable it globally and live with noise during interactive work; enable it only under `/make-autonomous`; or leave it off and replace with an explicit test-run invocation inside Phase 2.

6. **Context-health verification.** Inherit Michael's purely-self-reported model, or adopt one of the measurable-proxies / validation-hook / token-budget options listed in §"Patterns That Feel Fragile." Self-reporting is the status quo by default; Whitney should choose it deliberately rather than by inheritance.

7. **Commit-message discipline.** Vague messages break the recovery path that reads `git log` when the state file disagrees with disk. Decide the enforced convention (prefix template, task ID requirement, structured trailer) and wire the corresponding hook update.

8. **Cross-PRD dependency handling at execution time.** Whitney's design rule says every milestone must be completable from main alone, but the executor must still have a graceful behavior when it hits a dependency that slipped through design. Decide whether that is "stop and ask," "stop and auto-open a dependency issue," or "re-plan the milestone."

These eight questions sum to the scope of decisions that separate "port Michael's system" from "design an autonomous PRD executor." None of them have obvious right answers; all of them need answers before implementation.
