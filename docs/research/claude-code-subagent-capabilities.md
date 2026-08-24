# Sub-agent capabilities — the question Milestone B2 could not bank

Answered 2026-08-24 under Decision 65's safeguard: a mechanism that looks central and expensive to adopt gets its capability question checked the moment it appears, rather than waiting for Milestone B1. **The remaining five questions stay with Milestone B1.**

Sources, all official documentation: [sub-agents](https://code.claude.com/docs/en/sub-agents.md), [permissions](https://code.claude.com/docs/en/permissions.md), [agent-teams](https://code.claude.com/docs/en/agent-teams.md).

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
| Detect a stalled sub-agent | **No** | No idle or stall detection exists. Only `maxTurns:` as a hard cap, `TaskStop`, or a manual stop. A sub-agent that hits an API error does report the failure rather than hanging |
| Route a question back to the parent mid-run | **No, for sub-agents** | A sub-agent returns a final summary only. Bidirectional messaging and lead approval exist for **agent-team teammates**, which are experimental and gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |

## Mapping Viktor's mechanisms onto what is available

| Viktor's mechanism | Natively available? | How |
|---|---|---|
| Orchestrator forbidden from doing the work | **Yes** | A sub-agent definition with `disallowedTools: Write, Edit` for the orchestrating role |
| **Coder may not edit the tester's tests** | **Yes, via a hook** | A `PreToolUse` hook blocking `Write`/`Edit` on test paths. **This repo already runs exactly this shape** — `check-aboutme.sh` is a `PreToolUse` hook that blocks writes on a path-and-content condition |
| Review and audit in parallel, neither may modify code | **Yes** | Two sub-agents with a read-only `tools:` set, dispatched concurrently |
| Findings resolved by agreement, not severity | **Yes** | Prompt-level; no platform support needed |
| Idle-worker detection (his daemon, 120 minutes) | **No** | Substitute `maxTurns:`; there is no timeout |
| Mixed-vendor checking | **No** | Requires external orchestration — or CodeRabbit, already installed and already doing it |

**Three of Viktor's four self-verification mechanisms are natively available today.** The fourth, mixed-vendor review, is not — and is already covered by a tool in this workflow that runs later than it should.

## What this does not settle

Cost. Twenty concurrent sub-agents at high reasoning effort is a real number, and nothing here estimates it. `/cost-tracker` was removed as unused on 2026-08-20 (Decision 62), so no instrument exists. **If Milestone C1 proposes a fan-out design, it should say what a run costs before Whitney adopts it**, which probably means restoring some measurement first.

## A note on how this answer was obtained

Dispatched to a documentation-checking sub-agent rather than answered from memory, and every claim above carries a source URL. That is itself a small instance of the pattern under evaluation: the parent delegated a verification question, the sub-agent returned sourced findings, and the parent did not have to read the documentation. The limitation is equally visible — the sub-agent returned one summary at the end, with no way to ask a follow-up mid-run, which is exactly the constraint the routing row above records.
