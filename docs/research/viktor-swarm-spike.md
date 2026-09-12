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
7. **Added by the Milestone B2 community-practices sweep (Decision 40).** Does a hook event exist that fires on **every user prompt**, not just session start or compaction — the mechanism a cited community case study credits with raising rule-compliance from ~20% to 84%? The shipped hook-event list enumerated on 2026-08-04 (Decision-log finding, `docs/research/claude-config-audit-decisions.md`) does not include anything named `UserPromptSubmit`, only `UserPromptExpansion` — check whether that event, some other name, or nothing at all fills this role before concluding the practice isn't adoptable.

**Question 1 is the one to check immediately** rather than banking, per the safeguard in Decision 65 — a large part of the adoptable design rests on it.

## Community-practices sweep (Decision 40, one hour, run 2026-09-01)

**What was searched:** two web searches — one on 2026-community practice for running Claude Code unattended over long sessions (permission modes, sandboxing, guardrails), one on community consensus for structural rule enforcement (hooks vs. prompt instructions). Both scoped to "does anyone do something neither Viktor nor Michael already does" rather than re-deriving what both spikes already answered — Decision 40's per-request the results are unfiltered against Milestone B1, since B1 runs after this milestone.

**Enforcement question — no new mechanism, one useful measurement.** The community consensus (Anthropic's own docs, several independent blog posts, and a security-focused engineering team, Trail of Bits) restates exactly what Viktor's and Michael's repos already demonstrate structurally: `PreToolUse`/`PostToolUse` hooks are deterministic and cannot be talked out of; `CLAUDE.md`/skill-level instructions are advisory and are followed inconsistently. Nothing here is a new mechanism beyond what both practitioner spikes and this repo's own hooks already use. One number is worth carrying forward as evidence, not as an adopted practice: a cited case study (Scott Spence, unverified beyond the blog citing it) reports a hook that auto-injects a TDD-phase-assessment reminder before every prompt raised a measured compliance rate from ~20% (skill/prompt guidance alone) to 84%. **Candidate not yet checked against this repo**: none of Viktor's, Michael's, or this repo's hooks fire on every single prompt (`UserPromptSubmit`) — the closest equivalents fire on session start or compaction only. Whether that event exists and is usable this way is a Milestone B1 capability question, not something this sweep answers.

**Unattended-operation question — no new mechanism found beyond a rollout-timeline correction.** Auto mode (already adopted here, Decision 48) is now the *default* permission mode for new Claude Code sessions on Pro/Max/Team plans as of 2026-08-14, per Anthropic's own engineering blog — worth noting as a platform-timeline fact, not a practice to adopt, since it's already running. `--dangerously-skip-permissions` combined with `/loop` or `/schedule` for scheduled unattended runs came up repeatedly, but Whitney already has `bypassPermissions`-equivalent posture via auto mode plus a deny list, and neither `/loop` nor `/schedule` as native slash commands were verified against documentation in this sweep — that verification, if the mechanism looks worth adopting, is Milestone B1's job per the safeguard above. The one practice found that neither Viktor's nor Michael's repo uses: **container isolation for fully unattended `--dangerously-skip-permissions` runs**, cited by community sources and by an Anthropic Safeguards-team researcher's own stated practice ("run this in a container, not your actual machine"). Michael's answer to the same problem is a monitored, deny-listed shared VPS (Netcup) rather than per-run containers; this is a genuinely different risk posture, not a strictly better one — worth naming to Milestone C1 as an alternative, not a recommendation.

**Nothing else survived the filter.** `.claudeignore` files, sandbox `denyRead` hardening for credential paths, and audit-log review are all either already covered by this repo's existing deny-list/hook approach or are Claude Code platform features already inventoried elsewhere (Milestone A3's permission-modes research). Community writing was otherwise restatement of the same auto-mode and hooks material Viktor's and Michael's own repos demonstrate more concretely, which matches Decision 40's own prediction of low yield.
