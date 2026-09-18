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

---

# Milestone B1: the reviewer question, answered against 2.1.276

**Produced 2026-09-18. Claude Code 2.1.276.** This section closes the reviewer thread this document opened. It was prompted by finding `claude ultrareview` while enumerating the CLI surface, and it ends somewhere other than where it started: the decisive evidence turned out to be Viktor's own configuration rather than anything measured here.

## The answer: Viktor rejected the same-vendor reviewer explicitly

**Verified against the Milestone B2 record** (`vfarcic/dot-agent-deck` at `c701932`, read 2026-08-24). 🟢

Viktor's six roles run `reviewer` on the `pi` harness and `auditor` on `opencode`, both on `gpt-5.6-sol` at xhigh effort, checking work produced by Claude. **Each role carries a commented-out all-Claude alternative**, so the same-vendor configuration was written, considered, and deliberately left disabled.

**Interpretation, and it settles the question this section was opened to investigate.** `claude ultrareview` is Anthropic-hosted Claude reviewing Claude-authored code. That is precisely the configuration Viktor tried and switched off. Whitney's stated position (2026-09-18) is that she trusts his judgment and would follow his lead rather than run her own evaluation, and on this question his lead is unusually legible — not an absence of evidence about the same-vendor path, but a rejected alternative sitting in his live config. **So `ultrareview` was not run, and no evaluation of it is planned.** That is a decision, not a gap.

This is consistent with what this document already concluded from the other direction: the mixed-vendor property is the whole point, Claude Code cannot supply it (no vendor switch exists for sub-agents), and CodeRabbit already supplies it. Nothing in the reviewer thread has contradicted that.

**Two of Viktor's practices cost nothing and need no new infrastructure** — recorded here as Milestone C1 inputs, since both are already listed as natively available in the mapping table above:

- **Review and audit as two separate read-only roles, dispatched in parallel.** Two sub-agent definitions with a read-only `tools:` set.
- **The resolution filter is agreement, not severity.** His wording: "Resolve every reviewer and auditor finding you agree with — blockers, suggestions, and nits alike. The filter is agree-or-disagree, not severity." Shipping past a finding requires a documented reason. Purely prompt-level.

**What following his lead does *not* mean.** His mixed-vendor review depends on `dot-agent-deck` — a brew-installed Rust daemon and TUI plus three non-Claude CLI harnesses and a 220-line TOML. Adopting that is a project, not a setting, and it is explicitly out of scope here. Whitney already has the mixed-vendor checker; the open question remains the one this document framed earlier — *when* it runs and *who* triages it.

## What the bundled reviewer actually is, and the shadowing defect

Found while answering the above. Recorded because it is a live defect independent of any reviewer decision.

### `/code-review` is a bundled skill with effort levels and a cloud tier

**Verified-here** (strings from the shipped binary at `~/.local/share/claude/versions/2.1.276`). 🟢

- Effort levels, from the `ReportFindings` tool schema: `low`, `medium`, `high`, `xhigh`, `max`. The level typed last is remembered and reused; an unrecognized level is ignored with a warning. The product's own nudge reads "For a fast, cheap code review, try `/code-review low`: It runs the built-in skill at its lightest effort level."
- **A verify pass.** Candidate findings are handed to a sub-agent that "returns exactly one of **CONFIRMED / PLAUSIBLE / REFUTED**. Keep **CONFIRMED and PLAUSIBLE**. Drop REFUTED."
- **Prioritization under a cap:** "Correctness bugs always outrank cleanup, altitude, and conventions findings when the output cap forces a cut."
- **A specific footgun taxonomy**, including moved or extracted code that dropped a guard, dataclass defaults evaluated once, `hash()` non-determinism, lock-scope shrink, predicate methods with side effects, and setup/teardown asymmetry in tests.
- **Structured output** through a first-class `ReportFindings` tool, rendered by the host UI, with `category`, `short_summary`, `failure_scenario`, `verdict`, and a post-fix `outcome`.
- **`ultra` is its cloud tier.** `claude ultrareview [target]` runs "a cloud-hosted multi-agent code review of the current branch (or a PR number / base branch)", takes `--json` for the raw `bugs.json` payload, defaults to **not** posting, and has a **45-minute default timeout**.

### A personal skill of the same name shadows it, and this is documented behavior rather than a bug

**Documentation-quoted.** 🟢 From [Skills — resolve skills that share a name](https://code.claude.com/docs/en/skills.md#resolve-skills-that-share-a-name):

**Source says:** "Your skill replaces the bundled command, **but not its aliases**. A project `code-review` skill replaces `/code-review`, and the bundled alias `/review` never runs your skill."

**Verified-here** 🟢: `~/.claude/skills/code-review/` is a symlink into `claude-config/.claude/skills/code-review/SKILL.md`, carrying `description: Code review a pull request` and `disable-model-invocation: false`.

**Three consequences, and the second is the one that matters.**

1. `/code-review` has been running the personal copy, not the bundled skill.
2. **`/code-review ultra` never reached the cloud tier.** The personal copy has no effort-level parsing, so `ultra` arrives as a plain string argument and is ignored. Stated precisely: the capability was unreachable *through that name*, not unreachable outright — see the next point, which is what keeps this a fixable naming collision rather than a lost feature.
3. **`/review` reaches the bundled skill today**, because aliases are not shadowed. No configuration change is needed to try it.

The bundled skill's body is compiled into the binary, so there is **no on-disk April version to diff against**. The drift is visible in effect but not in detail.

### Three implementations of the same reviewer are installed

**Verified-here.** 🟢 `~/.claude/settings.json` lists `code-review@claude-plugins-official: true` in `enabledPlugins`, and `PROGRESS.md` records the origin on 2026-04-14: the official plugin was evaluated, then "plugin content copied to `.claude/skills/code-review/SKILL.md` and symlinked globally."

| Implementation | State | Distinctive capability |
|---|---|---|
| Personal skill (April copy of the plugin, symlinked from this repo) | **resolves `/code-review`** | `Defer` → creates a GitHub issue; 0–100 confidence scoring; two-tier table |
| `code-review@claude-plugins-official` | enabled, not reached by `/code-review` | whatever upstream ships now |
| Bundled skill | reachable via `/review` | verify pass, effort levels, cloud `ultra`, `ReportFindings` |

**This is the same failure shape Milestone B4 recorded for the `prd-*` skills** — fork from upstream, then drift — except the upstream here is Anthropic's own, and the fork wins by documented precedence rather than by accident.

### The fork's `Defer` disposition is genuinely not in the bundled skill

**Verified-here.** 🟢 This is why the fork should not simply be deleted.

The fork's `Defer` disposition creates a GitHub issue via `gh issue create`, runs `/write-prompt` on the issue body first, and records the issue number so it can be linked in the PR comment. The bundled skill's post-fix outcomes are only `fixed`, `no_change_needed`, and `skipped` — where `skipped` is documented as "real but not applied" and is tracked nowhere. Grepping the binary for any issue-creation mechanism (`gh issue create`, "create an issue for", "tracked in #") returns nothing.

**Interpretation:** the bundled skill produces exactly the outcome this repo's own CLAUDE.md warns against — "Future instances have no memory of deferred intent — silent deferrals disappear." The fork exists to close that gap and the bundled skill does not close it. Any consolidation that drops the fork has to replace `Defer`, not just absorb it.

## Collapse candidate for Milestone C1, with its own caveat

**Consolidate the three reviewers to one, and keep `Defer` as a thin layer rather than as a forked skill.** Maintaining a full copy of an upstream reviewer to obtain one disposition is the expensive way to hold that ground, and it costs the verify pass, the effort levels, and the cloud tier as a side effect.

**Deliberately not done in Milestone B1, and the reason is phase discipline.** Renaming or deleting the fork changes what `/code-review` means in `rules/git-workflow.md`, `rules/hooks-reference.md`, and the `issue-done`, `prd-done`, and `issue-create` skills, each of which instructs running it at a specific workflow point. B1 is a research milestone; the reviewer trial is flagged in the PRD as "the one place this PRD implements inside Phase B," which is to say the exception. Consolidation is Milestone C1's stated job. **`/code-review` keeps working unchanged in the meantime**, and `/review` is available for anyone who wants the bundled behavior today.

## Capability labels

| Capability | Label | Note |
|---|---|---|
| Bundled `/code-review` skill | **used worse here** | Shadowed by an April fork; the fork is the stalest of three installed implementations |
| Effort levels (`low`…`max`) | **not used at all** | Unreachable through `/code-review` while the fork shadows it |
| `claude ultrareview` / `ultra` tier | **not used at all — and not planned** | Same-vendor review; Viktor's rejected all-Claude alternative is the evidence against it |
| Verify pass (CONFIRMED/PLAUSIBLE/REFUTED) | **used worse here** | The fork scores 0–100 confidence with Haiku agents instead |
| `ReportFindings` structured output | **not used at all** | The fork posts a hand-formatted markdown table |
| `Defer` → GitHub issue | **already used here, and unique to the fork** | No bundled equivalent exists |
| Mixed-vendor review | **already used here** | CodeRabbit, unchanged from this document's earlier finding |

## What this section does not establish

- **No cost figure for `ultrareview`.** It was never run, so its price is unknown. B2's cost gap is unchanged: nobody knows what a six-agent xhigh run costs, and `/cost-tracker` was removed on 2026-08-20 as unused.
- **No quality comparison between the fork and the bundled skill.** The bundled skill's mechanism is richer on paper — a verify pass with a drop verdict beats a confidence score — but neither was run against a benchmark diff here. If C1 wants that comparison, PR #119 is the natural subject: it carries eleven already-triaged CodeRabbit inline findings plus review-body findings, so a run against it would have a known answer from a different vendor.
- **Whether the enabled `code-review` plugin differs from the bundled skill.** Both exist; only their names were compared.

## Sources for this section

- [Skills — resolve skills that share a name](https://code.claude.com/docs/en/skills.md#resolve-skills-that-share-a-name) — the shadowing rule and the alias exemption, quoted above
- Milestone B2's record of Viktor's six roles and their harnesses, including the commented-out all-Claude alternatives: [viktor-swarm-spike.md](viktor-swarm-spike.md)
- Local, 2026-09-18: `claude --version` (2.1.276); `claude ultrareview --help`; `strings` over `~/.local/share/claude/versions/2.1.276`; `~/.claude/settings.json` (`enabledPlugins`); `.claude/skills/code-review/SKILL.md`; `PROGRESS.md` entries for 2026-04-13 through 2026-04-15
