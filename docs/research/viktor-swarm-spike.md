# Viktor's agent swarm — Milestone B2 spike

Produced by Milestone B2 of [PRD #109](../../prds/109-claude-config-audit-redesign.md). **This is the primary source of the redesign** (Decision 64): the live problem is oversight, and Whitney expects the ideas to come from here rather than from `claude-config`.

**Repos read, pulled 2026-08-24:**

| Repo | SHA | Last commit |
|---|---|---|
| `vfarcic/dot-agent-deck` | `c701932` | 2026-08-24 |
| `vfarcic/dot-ai` | `94a347b` | 2026-08-22 |
| `vfarcic/dot-ai-infra` | `f601f88` | 2026-08-22 |

`dot-agent-deck` had a commit the day it was read. Treat every finding as a snapshot of an actively moving target.

Primary sources: `.dot-agent-deck.toml` (220 lines, the orchestration definition) and `docs/orchestration.md`.

---

## What the thing actually is

`dot-agent-deck` is a Rust terminal dashboard that runs several agent CLI sessions as panes and passes messages between them. It is not a prompt pattern or a skill — it is a **daemon plus TUI** that owns process lifecycle, message delivery, and idle detection. Installed with `brew install dot-agent-deck`.

That matters for adoption: the swarm is not something you can copy into a `CLAUDE.md`. It is infrastructure.

## The six roles, and the fact that they are different models

| Role | Harness | Never does |
|---|---|---|
| orchestrator | claude (Opus) | implementation, review, or audit — **only delegates** |
| coder | claude (Opus) | edit the tester's tests |
| tester | codex | modify production code, delegate |
| reviewer | pi | modify code — findings only |
| auditor | opencode | modify code — findings only |
| release | claude (Sonnet) | modify source code |

**The reviewer, auditor, and tester run on a different vendor's model from the coder.** Viktor's comment calls this "dogfood: mixed agents" — three GPT harnesses on `gpt-5.6-sol` at xhigh reasoning effort, checking work produced by Claude. Each role has a commented-out all-Claude alternative, so the mixing is deliberate and reversible.

**This is the single most transferable idea in the spike.** A reviewer that shares the author's model shares the author's blind spots. Whitney's stated goal — "have you double-check your own work" — is measurably weak when the checker *is* the author: three claims in PRD #109 were stated as fact and disproved within a week, each caught by a different verifier, two of them by her.

## How delegation actually works

- The orchestrator delegates with a `--task` string; the deck delivers it into the target role's pane, prepending that role's `prompt_template`.
- A worker signals completion by running `dot-agent-deck work-done --task "<summary>"`.
- Delegation can fan out — reviewer and auditor are dispatched **in parallel** and both report back independently.
- If a role's pane is empty or its agent died, the delegation **creates a fresh one** from the role definition.
- A daemon watches for silence: `worker_response_timeout_minutes = 120`. A worker quiet past that is reported to the orchestrator as stuck.

**The constraint that shapes everything else:** workers cold-start with no memory of prior conversation, no access to other workers' outputs, and no shared scratchpad. Whatever is in `--task` is the entire context. The orchestrator prompt therefore carries an explicit context-handoff contract — include the file paths, summarize the prior worker's findings when chaining, paste exact error text when retrying, and for long context write `.dot-agent-deck/<task-slug>.md` and pass the path instead.

## The escalation boundary: exactly two user gates

This is the direct answer to "what does Viktor not have to approve."

**Gate 1 — test-plan approval.** Before any delegation, the orchestrator reads the PRD, produces a table of every observable behavior with a test tier and an action, and stops for sign-off.

**Gate 2 — merge confirmation.** After CI and review are green and the demo reel is posted, the user reviews and gives the go-ahead. Nothing merges without it.

**Everything between those two runs unattended:** the TDD chains, implementation, parallel review and audit, resolving findings, the e2e gate, opening the PR, waiting out CI and the automated reviewer, fetching inline findings, building and publishing a demo reel, and updating the changelog. The prompt says so explicitly at the pre-release step — *"This is NOT a user gate; do not pause for approval before delegating."*

**Workers never notify the user and never wait on the user.** A blocked worker returns its question through `work-done` and stops; the orchestrator turns it into one notification and pauses. That single rule is what keeps six agents from generating six interruptions.

## The notification rule, which is better than the gate list

Notifications go to Telegram at exactly four moments: escalation, merge gate, run finished, and worker-stuck. The selection criterion is stated outright and is the sharpest sentence in the file:

> The criterion is not "every pause for a human" but **every pause where the human may have walked away**.

The test-plan gate is deliberately **not** a notify moment, because it fires seconds into a run while the user is still watching — and the prompt says "do not add it back." A gate and a notification are different things, and conflating them is what produces noise.

## Self-verification: the headline finding

Milestone B2 was told to treat any agent-checks-agent mechanism as the headline. There are four, and they are structural rather than advisory:

1. **The orchestrator cannot do the work.** "You NEVER do implementation, review, or audit work yourself — only delegate." The role that decides is not the role that executes.
2. **The coder cannot touch the tester's tests.** "Never edit the tester-authored tests to force them green; if you think a tester test is wrong, report it back instead of editing it." This removes the most common way a TDD chain quietly degrades.
3. **Review and audit are separate roles on separate models, run in parallel**, both forbidden from modifying code.
4. **The resolution filter is agreement, not severity.** "Resolve every reviewer and auditor finding you agree with — blockers, suggestions, and nits alike. The filter is agree-or-disagree, not severity." Shipping past a finding requires a documented reason.

## Two details worth stealing that are not about swarms

**The config file carries its own postmortems.** The release role's prompt contains a dated correction block explaining that an earlier version told it the review gate was settled once a check went green — and that on PR #286 this caused a merge with two unread valid findings, one of which shipped and needed a follow-up. Same practice as this PRD's correction blocks, in a live operational prompt.

**A stated reason for every "do not."** Nearly every prohibition in the file is followed by the failure it prevents. That is why the file survives being read by six cold-starting agents.

## What this does not answer

- **Cost.** Nothing here says what a six-agent run costs, and every role at xhigh effort on a frontier model is not cheap. Whitney has no cost instrument any more — `/cost-tracker` was removed on 2026-08-20 as unused (Decision 62).
- **Whether the platform now does this natively.** Deliberately not answered here (Decision 65). Questions accumulated for Milestone B1 are listed below.
- **How it fails.** The file describes the happy path plus stuck-worker detection. What happens when the orchestrator itself compacts mid-run is not stated, and PRD #82 is referenced as the compaction-drops-instructions problem, suggesting it is live.

## Capability questions for Milestone B1

Accumulated rather than answered, per Decision 65:

1. Can sub-agents run on a **different model or vendor** from the parent? The mixed-model review is the highest-value idea here and it depends entirely on this.
2. Can a sub-agent be **forbidden from editing specific paths** — the coder-cannot-touch-tests rule — through tool or permission scoping?
3. Can sub-agents be **dispatched in parallel** and their results awaited independently, and what is the concurrency limit?
4. What does a sub-agent **see of the parent context** by default, and can that be reduced to an explicit task string?
5. Is there a native **idle or stuck detection** for a sub-agent that stops responding?
6. Can a sub-agent's result be routed back **without the user seeing it**, so one agent's question becomes the parent's decision rather than an interruption?

**Question 1 is the one to check immediately** rather than banking, per the safeguard in Decision 65 — a large part of the adoptable design rests on it.
