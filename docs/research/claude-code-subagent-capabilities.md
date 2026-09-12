# Sub-agent capabilities — the question Milestone B2 could not bank

Answered 2026-08-24 under Decision 65's safeguard: a mechanism that looks central and expensive to adopt gets its capability question checked the moment it appears, rather than waiting for Milestone B1. **The remaining six questions stay with Milestone B1.**

Sources for the documentation-derived claims: [sub-agents](https://code.claude.com/docs/en/sub-agents.md), [permissions](https://code.claude.com/docs/en/permissions.md), [agent-teams](https://code.claude.com/docs/en/agent-teams.md).

**Not every claim here comes from documentation, and the corrections are the ones that do not.** Rows marked "corrected 2026-08-25" come from observed behaviour during the reviewer sub-agent trial, not from a docs page — which is why they contradict what the docs implied. Where a row cites an observation, treat the observation as the authority.

## The question, and the answer that matters

**Can a sub-agent run a different vendor's model from its parent?**

**A different Claude tier: yes.** The `model` field in a sub-agent definition takes `sonnet`, `opus`, `haiku`, `fable`, a full Anthropic model ID, or `inherit`. Resolution order is `CLAUDE_CODE_SUBAGENT_MODEL`, then the per-invocation parameter, then the definition field, then the parent's model.

**A different vendor: no. There is no mechanism — not in frontmatter, not through the SDK, not through MCP.**

**This is the finding that constrains the redesign**, because the mixed-vendor review is the single most transferable idea in Viktor's setup, and its whole rationale is that *a checker sharing the author's model shares the author's blind spots*. Substituting Haiku for Opus keeps the family and the training lineage, so it dilutes exactly the property that made the idea worth having.

### The consequence nobody had noticed: Whitney already has the mixed-vendor reviewer

**CodeRabbit is a different-vendor checker already wired into this workflow, and it has been doing precisely the job Viktor's reviewer role does.** In the week of 2026-08-18 it caught three claims stated as fact and wrong — the `core.hooksPath` diagnosis for ten failing tests, an uninstall regression introduced two days *after* the fix it had reviewed, and a set of stale hook references. None of those were style nits; two were defects in code, and one would have sent a reader to apply a remedy for a cause that had already been disproved.

So the gap is not that no independent checker exists. **The gap is when it runs and who has to drive it.** CodeRabbit runs at push or PR time, must be triggered, takes one to nine minutes, and returns a list Whitney reads and triages. Viktor's reviewer runs inside the loop, and his orchestrator resolves the findings before the human sees anything.

**That reframes the question for Milestone C1** from "how do we get a second model to check the work" to "how do we move the check we already have earlier, and let something other than Whitney triage it."

## The other answers, and what each permits

| Question | Answer | Mechanism |
|---|---|---|
| Restrict a sub-agent to a tool subset | **Yes** | `tools:` allowlist or `disallowedTools:` denylist in frontmatter; wildcards supported, including `mcp__*` |
| Forbid editing specific file paths | **Partial** | **No `paths:` frontmatter exists.** Achieved with a `PreToolUse` hook that inspects the tool input and blocks by path, or `isolation: worktree`, or `permissionMode` plus `additionalDirectories` |
| Dispatch in parallel | **Yes** | Default **20** concurrent sub-agents per session, **3** levels of nesting; both configurable by env var since v2.1.217 |
| Reduce what the sub-agent sees | **Partial** | Context is fresh and isolated — no parent conversation history, no parent memory. **CLAUDE.md is always loaded and cannot be suppressed** on a custom sub-agent |
| Detect a stalled sub-agent | **Partly — corrected 2026-08-25** | **The sub-agent has no self-detection; the harness does.** This row read "No — no idle or stall detection exists" until a scoring run in the reviewer trial was killed by a task-level stream watchdog after 600 seconds of no progress. So there is a stall backstop, it is not configurable from the agent definition, and it is not something the sub-agent reports about itself. `maxTurns:` remains the only cap the definition controls, alongside `TaskStop` and a manual stop. A sub-agent that hits an API error reports the failure rather than hanging |
| Route a question back to the parent mid-run | **No, for sub-agents** | A sub-agent returns a final summary only. Bidirectional messaging and lead approval exist for **agent-team teammates**, which are experimental and gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |

## Mapping Viktor's mechanisms onto what is available

| Viktor's mechanism | Natively available? | How |
|---|---|---|
| Orchestrator forbidden from doing the work | **Yes** | A sub-agent definition with `disallowedTools: Write, Edit` for the orchestrating role |
| **Coder may not edit the tester's tests** | **Yes, via a hook** | A `PreToolUse` hook blocking `Write`/`Edit` on test paths. **This repo already runs exactly this shape** — `check-aboutme.sh` is a `PreToolUse` hook that blocks writes on a path-and-content condition |
| Review and audit in parallel, neither may modify code | **Yes** | Two sub-agents with a read-only `tools:` set, dispatched concurrently |
| Findings resolved by agreement, not severity | **Yes** | Prompt-level; no platform support needed |
| Idle-worker detection (his daemon, 120 minutes) | **Partly — corrected 2026-08-25** | Not configurable, but not absent: a task-level stream watchdog killed a stalled sub-agent after 600 seconds. Viktor's 120 minutes is a deliberate threshold he chose; this is a fixed one you inherit. `maxTurns:` is the only bound the definition sets, and it bounds work rather than idleness |
| Mixed-vendor checking | **No** | Requires external orchestration — or CodeRabbit, already installed and already doing it |

**Three of Viktor's four self-verification mechanisms are natively available today.** The fourth, mixed-vendor review, is not — and is already covered by a tool in this workflow that runs later than it should.

## What this does not settle

**Two rows above were measured further by the reviewer trial on 2026-08-25 — read [that build record](diff-reviewer-trial.md) before relying on this table.** The stall row is corrected in place. Separately, `maxTurns:` turns out to be more than a runaway cap: set low it silently truncates a real review and returns something indistinguishable from a clean result, and a prompt instructing the sub-agent to report an incomplete run cannot help, because the cap fires before the sub-agent gets a turn to report it.

Cost, at scale. **Per-run cost is no longer unmeasured — corrected 2026-08-25.** Each completed sub-agent reports its own token usage, so no instrument needed restoring: the reviewer trial's runs came back between 74,030 and 105,533 tokens each for diffs of 176 to 1,010 lines, and a run truncated by `maxTurns` cost as much as a useful one. What remains unestimated is the multiple — twenty concurrent sub-agents at high reasoning effort — and the dollar figure, since the reported number is tokens. **If Milestone C1 proposes a fan-out design, multiply the measured per-run figure by the fan-out and say the result before Whitney adopts it.**

## A note on how this answer was obtained

Dispatched to a documentation-checking sub-agent rather than answered from memory, and every claim above carries a source URL. That is itself a small instance of the pattern under evaluation: the parent delegated a verification question, the sub-agent returned sourced findings, and the parent did not have to read the documentation. The limitation is equally visible — the sub-agent returned one summary at the end, with no way to ask a follow-up mid-run, which is exactly the constraint the routing row above records.
