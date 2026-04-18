# Claude Code Autonomous Capabilities (2026)

## Purpose

This doc captures what the Claude Code platform actually supports for autonomous execution as of 2026-04. It is the third of three research docs that inform [PRD #84 — Autonomous PRD Execution](../../prds/84-autonomous-prd-execution.md):

- [prd-workflow-principles.md](./prd-workflow-principles.md) — what Whitney's current PRD workflow does
- [michael-autonomous-execution-principles.md](./michael-autonomous-execution-principles.md) — Michael Forrester's patterns
- **this doc** — what the Claude Code platform supports in 2026

Without this platform-capability layer, the design decisions in PRD #84 would be underspecified. A future reader would see "we chose a Ralph loop over self-clear" without the platform constraints that shaped the choice.

Research behind this doc: a `claude-code-guide` agent pass on self-clear and compaction behavior, plus a web + local-repo pass on Ralph loops.

---

## 1. Session control: can Claude self-clear?

**Short answer: no to `/clear`, but yes to "start a fresh session" — and the two are functionally equivalent for autonomous execution.**

### `/clear` is CLI-only

Per the [Claude Agent SDK slash commands documentation](https://code.claude.com/docs/en/agent-sdk/slash-commands):

> "The interactive `/clear` command is not available in the SDK. Each `query()` call already starts a fresh conversation."

Claude (the assistant) cannot trigger `/clear` on its own session.

### `/compact` is programmatically dispatchable, but does not give fresh context

`/compact` can be invoked by the model. But it compresses the existing session in-place — it does not give the fresh-context semantics that `/clear` gives. For "start each milestone with a clean slate," `/compact` is not an equivalent.

### `claude -p` IS functionally equivalent to `/clear`

The key insight: Claude can Bash `claude -p "prompt"`. This spawns a **new headless Claude Code session** with:
- Its own fresh context window
- The same skills, hooks, settings.json, CLAUDE.md, and MEMORY.md inherited from the user's config
- Environment variables inherited (including Datadog gateway routing)

From an orchestrator's perspective, spawning a new session via `claude -p` is indistinguishable from `/clear` — downstream work begins with a clean conversation but the same toolchain.

**Implication for PRD #84**: fresh-context-per-milestone is achievable. The "self-clear isn't possible so we must design around compaction" framing was incomplete — Claude CAN start fresh sessions; it just does it by spawning new processes, not by clearing its own.

---

## 2. Compaction behavior (current Claude Code)

### What triggers compaction

- **Token threshold**: automatic when the session approaches context limits
- **Explicit `/compact`**: user or model invocation (including via SDK)
- The system decides summarization aggressiveness based on token pressure — not a fixed-magnitude event

### Hook events

Per the [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks.md):

- **`PreCompact`** — fires before compaction; can block with exit code 2
- **`PostCompact`** — fires after compaction; advisory only (cannot block)

Both receive stdin JSON with session metadata. Both can return output that lands in Claude's `additionalContext`.

### What is preserved vs. dropped

**Dropped / summarized:**
- Older conversation messages → replaced with an AI-generated summary

**Preserved across compaction:**
- File edits (the working tree is not touched)
- High-level tool-call history (the summary knows "you edited X")

**Automatically re-injected after compaction:**
- CLAUDE.md files
- MEMORY.md auto-memory
- Environment info (cwd, git state)
- **Not re-injected**: skill descriptions for skills that were never invoked before compaction. Only skills actually used before compaction are still referenced.

### Recovery mechanisms

- **`/rewind`** — user-facing escape hatch to restore pre-compaction state ([Checkpointing Documentation](https://code.claude.com/docs/en/checkpointing.md))
- **`PostCompact` hook** — can inject custom re-orientation output (Whitney's `auto-reanchor.sh` uses this)
- **`/post-compact` skill** — manual re-anchoring flow for mid-session recovery
- **MEMORY.md** — persists durably across sessions, loaded on every session start

### What has changed since Michael's designs

Michael Forrester's patterns (early 2025) were built when compaction was more opaque — less automatic re-injection, fewer hook events. The `_execution-state.md` pattern was a workaround for "state in conversation memory is lost after compaction."

In current Claude Code:
- Automatic re-injection of CLAUDE.md, MEMORY.md, and git state covers much of what `_execution-state.md` manually persisted
- `PostCompact` hooks give programmatic re-orientation
- `/rewind` gives user-driven rollback

**Implication**: for Whitney's case (PRD file is the state file per Decision 1, existing `auto-reanchor.sh`), a separate `_execution-state.md` is redundant. The platform now handles what that file was created to solve.

---

## 3. Ralph loops

### Origin

The term was coined by **Geoffrey Huntley** in a post titled ["everything is a ralph loop"](https://ghuntley.com/loop/). Named after Ralph Wiggum from *The Simpsons* — the connection is implicit (the page shows Ralph on a looping rollercoaster/loom) but the community reads it as "cheerful stubbornness through repeated attempts": persistent iteration even when each attempt looks simple or flawed.

Huntley's post propagated through Twitter/X and Hacker News into multiple implementations:
- [snarktank/ralph](https://github.com/snarktank/ralph) — canonical shell-loop implementation
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) — with circuit breaker and rate limit
- [Anthropic's Ralph Loop plugin](https://claude.com/plugins/ralph-loop)

### What it is

A **while-loop that feeds the same prompt to an AI coding agent until an explicit completion signal**. Key mechanics:

- Each iteration runs in a **fresh context window** (via `claude -p` or equivalent SDK call)
- State persists on **the filesystem and git history**, not in conversation
- The agent self-exits via a "completion promise" (e.g., emitting `<promise>COMPLETE</promise>`) or the loop hits a max-iterations ceiling

Per the [claudefa.st guide](https://claudefa.st/blog/guide/mechanics/ralph-wiggum-technique), this works because:
1. Fresh contexts avoid compaction entirely
2. Git diffs provide deterministic progress signals
3. Tests provide deterministic success signals
4. The "same prompt every iteration" means the agent re-derives its plan from the current disk state each time — no conversation-memory dependency

### Real-world examples

- Huntley used a Ralph loop to build a programming language over ~3 months ([ghuntley.com/loop](https://ghuntley.com/loop/))
- YC hackathon teams shipped 6+ repos overnight for ~$297 in API cost ([awesomeclaude.ai/ralph-wiggum](https://awesomeclaude.ai/ralph-wiggum))

### Why this matches PRD #84

Ralph loops fit Whitney's PRD workflow naturally:
- PRD file persists on disk ✓ (Decision 1)
- Milestone = unit of work ✓
- Each iteration reads the PRD, works the next milestone, commits, exits
- Completion signal: all milestone checkboxes `[x]` and PR merged
- No fresh-context engineering required — `claude -p` provides it for free

---

## 4. Stuck detection (the unsolved problem)

A **stuck Ralph loop** is the degenerate case — the agent makes no progress across iterations. The loop keeps spinning, API costs accrue, but nothing ships.

### Community consensus: stuck detection is hard

No consulted source has a robust automated detection mechanism. The signals that exist are all coarse:

- **No new git commits across iterations** (Michael Forrester's `committed=False` flag — `forrester-workflow/src/workflow/analyzers/ralph.py:24`)
- **Max-iterations reached without completion promise** ([snarktank/ralph README](https://github.com/snarktank/ralph))
- **Repeated test failures across iterations** with no delta
- **External inference**: in Michael's analyzer, `stuck: bool` is an **input**, not something derived. Some upstream system has to decide.

### Michael's implementation

Michael's `ralph.py` is a **post-hoc analyzer**, not a detector:
- Scores a completed Ralph session on commit rate (40%), inverse stuck rate (30%), completion (30%) (`forrester-workflow/src/workflow/analyzers/constants.py:65-72`)
- The `stuck` flag is an input, not derived — the analyzer only surfaces it
- His session-start hook (`forrester-workflow/claude-config/hooks/session-start.sh:44`) checks for `.claude/ralph-loop.local.md` as a manual marker

**Key finding**: nobody has solved automated stuck detection. The robust escape hatches are:
1. **Hard iteration ceiling** (e.g., max 20 iterations)
2. **Completion promise as the only clean exit signal**
3. **Strong feedback loops** (tests, typecheck, CI green) so each iteration has a deterministic improvement signal
4. **Human review between runs**

### Breaking out of a stuck loop

Community techniques that work:
- Completion promise emitted by the model (requires the prompt to teach the model about it)
- Circuit breaker: track error patterns, exit if repeated
- Rate limit: cap iterations per hour
- Milestone-level feedback: if a milestone does not commit in N iterations, escalate

### Implication for PRD #84

Stuck detection is the hardest open problem. Design decisions for this implementation:
- **Hard iteration cap per milestone** (e.g., 5 attempts max)
- **Git progress check between iterations** (no new commit = escalate)
- **Escalate, not retry** when stuck — the loop stops, logs state, surfaces to user
- No claim to "solve" stuck detection; just detect it reliably enough to stop and ask

---

## 5. Design implications for PRD #84

Pulling it all together, the platform constraints shape the design as follows:

1. **Architecture: shell-driven Ralph loop.** Outer loop is a bash script (e.g., `scripts/autonomous-prd.sh`); each iteration spawns `claude -p`. The orchestrator is deterministic; all reasoning happens inside the child.

2. **Every child is Claude Code, not raw SDK.** Skills, hooks, settings, CLAUDE.md, MEMORY.md all carry over. No SDK rebuild — `claude -p` is the right primitive because it preserves the full workflow toolchain.

3. **Fresh context per milestone.** Each `claude -p` invocation gets a clean context. Compaction becomes a non-issue except within a single milestone iteration (rare, and handled by the existing `auto-reanchor.sh`).

4. **`_execution-state.md` is dropped.** The PRD file is the state file (Decision 1). Modern Claude Code compaction re-injection covers what Michael's state file was working around.

5. **Stuck detection: conservative.** Hard iteration caps, git progress checks, escalate-not-retry. Do not over-engineer — the community has not solved this either.

6. **Permission model needs prework.** `claude -p` in autonomous mode needs a permission strategy — either `--permission-mode acceptEdits`, pre-authorized permissions in settings.json, or the YOLO-mode equivalent. The existing `/make-autonomous` skill is the right hook for this.

7. **Orchestrator location: shell, not Claude.** The outer loop lives in a bash script, not in a parent Claude Code session. Rationale: the loop is deterministic and does not benefit from reasoning; a shell script has no context limits and no compaction risk of its own.

---

## Sources

### Claude Code platform docs
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks.md)
- [Slash Commands in the SDK](https://code.claude.com/docs/en/agent-sdk/slash-commands)
- [Checkpointing Documentation](https://code.claude.com/docs/en/checkpointing.md)

### Ralph loops (community)
- [Geoffrey Huntley — "everything is a ralph loop"](https://ghuntley.com/loop/)
- [GitHub — snarktank/ralph](https://github.com/snarktank/ralph)
- [GitHub — frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)
- [Anthropic — Ralph Loop plugin](https://claude.com/plugins/ralph-loop)
- [Awesome Claude — Ralph Wiggum Technique](https://awesomeclaude.ai/ralph-wiggum)
- [claudefa.st — Ralph Wiggum technique](https://claudefa.st/blog/guide/mechanics/ralph-wiggum-technique)

### Michael Forrester's implementation
- `/Users/whitney.lee/Documents/Repositories/forrester-workflow/src/workflow/analyzers/ralph.py`
- `/Users/whitney.lee/Documents/Repositories/forrester-workflow/src/workflow/analyzers/constants.py`
- `/Users/whitney.lee/Documents/Repositories/forrester-workflow/claude-config/hooks/session-start.sh`
