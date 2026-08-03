# PRD #109: claude-config Audit & Redesign

**Status**: Draft
**Created**: 2026-08-02
**Issue**: https://github.com/wiggitywhitney/claude-config/issues/109
**Research**:
- [claude-config audit decision log](../docs/research/claude-config-audit-decisions.md) — the running record of every decision, finding, and open question from the scoping conversation. **Read this first.** It is the authoritative source for why this PRD is shaped the way it is.
- [PRD workflow principles](../docs/research/prd-workflow-principles.md) — how the current PRD skills work, what state lives where, the atomic-commit invariant
- [Michael Forrester workflow](../docs/research/michael-forrester-workflow.md) — **stale**, describes a workflow he has since changed; updated by M6
- [Michael Forrester autonomous execution principles](../docs/research/michael-autonomous-execution-principles.md) — **stale**, same caveat
- [Claude Code autonomous capabilities](../docs/research/claude-code-autonomous-capabilities.md) — 2026 platform constraints

## Problem

The claude-config workflow has grown organically for months. It works, but living inside it daily has become friction rather than leverage:

- **Rules reach context through four uncoordinated mechanisms** — `@`-references in `global/CLAUDE.md`, `paths:` frontmatter, bare files with no frontmatter, and an index that describes files as "not auto-loaded" when they are. Measured on 2026-08-02: 96,637 bytes (~24k tokens) of irrelevant rule content in every session. Tracked separately as issue #108.
- **Sessions compact constantly**, and each compaction loses in-flight reasoning.
- **Auto-approval prompts interrupt routine work.** The cause is not allowlist gaps — Claude Code refuses to match any allowlist entry when a command contains shell expansion, so the command name is never evaluated.
- **The skill families have drifted.** Seven `prd-*` skills and six `issue-*` skills are near-parallel implementations of the same lifecycle, with nothing enforcing that a change to one mirrors into the other.
- **Accumulated infrastructure has not been pruned.** 14 Claude Code hooks and a set of native git hooks have accreted without a review pass.

Underneath all of it: it is unclear which parts of the system are worth building on and which should be replaced. That question cannot be answered by implementing — it has to be answered by looking, comparing, and deciding.

## Solution

Run a structured audit and produce a **spec file** recording concrete keep / rebuild / replace decisions. This PRD's deliverable is that document, not an implementation. The spec then spawns one or more separate implementation PRDs.

The audit has four inputs:

1. **Current platform behavior** — what Claude Code actually does today with rules, skills, context, compaction, and permissions, researched against current documentation rather than training data. This is a fast-moving area and training data has already proven unreliable here.
2. **Viktor Farcic's workflow** — his role-based agent swarm, and his PRD skills, which the current `prd-*` skills were originally derived from and have since diverged from.
3. **Michael Forrester's workflow** — his current setup, which has changed since the existing research was written.
4. **Repo-native findings** — problems visible only from inside claude-config itself, which no external comparison would surface.

The fourth input is load-bearing and easy to lose. The audit must not become "adopt what Viktor and Michael do." Named examples already identified: the hook collection likely contains removable and consolidatable hooks, and the two skill families may need to collapse into one.

**Falling back to the current way of working must remain possible.** The spec records what stays intact under every scenario it proposes.

## Process — how decisions get made in this PRD

This section is binding on the implementing AI and is not optional.

**Whitney decides. Claude recommends.** Present findings, state a clear recommendation and the reasoning behind it, then ask and wait. Never decide ahead of her, and never present a decision as already made. This overrides the YOLO-mode instruction in `.claude/CLAUDE.md` for anything that is a genuine choice; YOLO still applies to executing a decision she has already made.

**One question at a time.** Never present a numbered list of two or more questions in a single message. Ask, resolve, then ask the next.

**Decide policies, not instances.** Where a change touches many files, propose a single rule covering all of them and ask her to approve or edit the rule — then apply it mechanically. Do not ask for per-file or per-instance approval. Per-instance approval is miserable at scale and buries the actual choice inside the noise.

**Check in with Whitney after every milestone.** Do not chain milestones. Finish one, present what it found, and wait. This was an explicit instruction when the audit was first scoped and it applies to every milestone in this PRD, including the ones that look mechanical.

**Verify against the conversation continuously, not only at M9.** After each milestone, extract the human turns from that milestone's session transcript and diff them against this PRD and the decision log. Anything said and not written down gets written down before the next milestone starts. M9 is the final pass over the finished spec; it is not the only time this check runs. Waiting until the end would mean discovering at M9 that an instruction given at M1 was never captured, after seven milestones had already been built on the gap.

**Log decisions as they are made,** to `docs/research/claude-config-audit-decisions.md`, in the same turn they are made. Do not batch them for later reconstruction. The scoping conversation for this PRD was long and decision-dense; compaction summarizes lossily and the running log is the defense against that.

### Claims carry their evidence

**Never write that something works, is fixed, is complete, or is current without stating the observation that shows it.** "I edited the file" needs no evidence — it describes an action. "The hook works now" is a claim about the world and needs the check that proves it, in the same sentence.

This binds every milestone report, `PROGRESS.md` entry, commit message, and status update in this PRD. Where the observation cannot be produced, say what was done and stop there: *"replaced three flags; not yet verified against the CLI"* is a complete and honest sentence.

Applies with particular force to before/after measurements, which are this PRD's primary evidence, and to any statement that a milestone's success criteria are met.

### Reference repos are refreshed at read time, not at clone time

**Every milestone that reads a reference repo pulls it first, and records the commit SHA it actually read.** This applies to repos cloned during M1, to `~/Documents/Repositories/forrester-workflow`, to `~/Documents/Repositories/claude-personal`, and to anything else already on disk.

Cloning happens once in M1; the spikes that read those clones run later, potentially much later. A clone that was current when it was taken is not current when it is read. Michael pushed to `llm-coding-workflow` during the planning conversation on 2026-08-02 — 500 commits had accumulated since the previous clone, and he said he was still pushing as he said it. Viktor's repos will drift the same way between M1 and M4.

Recording the SHA matters as much as pulling: a finding attributed to "his current setup" is unverifiable later unless the state it came from is named. Every spike document states the repo and SHA it was written against.

### Model protocol

Every milestone carries a **Model** line. Milestones whose output is a *judgment* — research where training data is unreliable, the comparison spikes, the classification policy, the spec — require the strongest available model. Milestones whose output is *retrieval or mechanical transformation* run on whatever is active and delegate bulk reading to Sonnet subagents.

Claude cannot change its own model. `/model` is a command Whitney types; there is no tool for it. The protocol is therefore:

1. At the start of every milestone, read the current model from the session environment.
2. If it matches the milestone's **Model** line, proceed without comment. Do not interrupt her to confirm something already true.
3. If it does not match, stop before doing any work. Name the current model, name the required one, and ask her to switch.
4. After she switches, **verify by reading the environment again** rather than accepting her word. Only then begin the milestone.

This matters because Whitney's managed settings pin Sonnet 5 on restart. Unless she re-selects, every new session defaults to the weaker model — and this PRD is made almost entirely of judgment calls.

## Milestones

- [ ] M1: Reference repos gathered and cloned
- [ ] M2: Current-behavior research — rules, skills, context, compaction
- [ ] M3: Current-behavior research — permissions and approval friction
- [ ] M4: Viktor swarm workflow spike
- [ ] M5: Skill families diffed and an autonomous-first consolidation designed
- [ ] M6: Michael workflow spike
- [ ] M7: Repo-native audit — hooks, skills, general cleanup
- [ ] M7b: PRD #84 resolved and retired, and issue #98 with it
- [ ] M8: Spec file written and signed off
- [ ] M9: Audit-agent verification pass against the decision log and session transcript

---

### M1: Reference repos gathered and cloned

**Model:** Any. Mechanical — cloning and confirming. No switch needed.

**Step 0:** Read [the decision log](../docs/research/claude-config-audit-decisions.md), specifically the "Repos to examine" table.

**What:** Ask Whitney for every repo link she wants examined, then clone each one locally into a scratch directory that is excluded from version control.

**Why:** Fetching these via web search or WebFetch hit GitHub crawl-blocking during scoping. Local clones sidestep that entirely. Gathering happens once, up front, because M4, M5, and M6 all depend on the clones existing — if cloning were folded into the first spike, the later ones would either redo it or silently depend on leftover state.

**To implement:**
- Clone Viktor's repos. The list is confirmed:
  - **`vfarcic/dot-agent-deck`** — his *current* setup. Skills live in `.claude/skills/`. `.dot-agent-deck.toml` describes the roles of his agent swarm for that project, and he says he now relies heavily on it. Treat the TOML as his center of gravity, not the skills.
  - **`vfarcic/dot-ai`** — how he distributes skills into each project, and the probable origin of the `prd-*` skills Whitney forked. Purpose otherwise unknown; do not assume.
  - **`vfarcic/dot-ai-infra`** — his permanent cluster.
- **Establish the fork point before diffing anything.** Whitney's `prd-*` skills were forked from `dot-ai`, but his current skills live in `dot-agent-deck`. That makes a two-way diff misleading. Find the closest common ancestor in `dot-ai` and run a three-way comparison — ancestor, his current, hers — so M5 can distinguish "he changed this," "she changed this," and "both changed it independently." A two-way diff collapses those three cases into one and will produce recommendations that quietly discard her deliberate divergences.
- Clone Michael's repos, owner `peopleforrester`:
  - **`llm-coding-workflow`** — confirmed and already cloned at `~/Documents/Repositories/forrester-workflow`; pulled current on 2026-08-02 (500 commits since the prior clone, HEAD `418cd9f`). 52 MB, 702 tracked files, 11 PRDs. Contains its own `claude-config/` (`AGENTS.md`, `CLAUDE.md`, `fleet`, `hooks`, `rules`, `settings.json`, `shell`, `skills`, `systemd`), plus `netcup-*`, `wsl2-specific/` including `naruto/` for terminal layout snapshots, `tasks.yaml`, `PROJECT_STATE.md`, `plan.md`, and `decisions.md`.
  - **Michael confirmed on 2026-08-02 that `llm-coding-workflow` is the primary repo** — "that is where the latest Opus 5 juice is" — and said he was still pushing changes at the time. **Re-pull immediately before the spike runs**, not just at clone time; the clone taken during planning is already behind.
  - **"Primary" does not mean "only" — the other active repos are examined too, and that is not optional.** Whitney asked for this explicitly. Do not treat his confirmation above as permission to stop at one repo.
  - **Selection is two stages: a script narrows by recency, then judgment narrows by subject.** Recency alone is useless here — he is prolific, and on 2026-08-02 all 20 of his public repos had been updated within 90 days, so that filter removed nothing.
    1. **Enumerate deterministically.** `gh repo list peopleforrester --json name,description,updatedAt`. Record the full output so the selection can be audited.
    2. **Then judge each name and description against one question:** could this plausibly contain part of how he configures or runs a coding agent? Clone those. This is a semantic judgment and correctly belongs to a model rather than a script — consistent with the deterministic-enumeration rule, which governs enumeration, not relevance.
  - **Include** anything touching Claude Code configuration, skills, rules, hooks, agent workflow, coding-agent tooling, or agent observability — even for a different tool, since a Copilot or MCP pattern may still reveal how he structures things. **Exclude** subject-matter projects that merely happen to be built with agents: games, websites, podcasts, demo platforms, pricing data, book manuscripts.
  - Applying that on 2026-08-02 gives roughly nine of twenty: `llm-coding-workflow`, `claude-dotfiles`, `Brain_spec_skills_claude`, `observe-claude-code`, `mcp_best_practices`, `agentic-covenants`, `MCP_Server_Claude_Doc_monitor`, `copilot-cli-enterprise-patterns`, `Webinar_Claude_Code_Hands_On`. Re-run the enumeration rather than trusting this list — he was actively pushing on the day it was written. When a name is ambiguous, clone it: a discarded clone costs nothing, a skipped one costs a finding nobody knows is missing.
- **Include Whitney's own second configuration repo.** `wiggitywhitney/claude-personal`, cloned at `~/Documents/Repositories/claude-personal` — 101 tracked files (`memory/`, `scripts/`, `tests/`), last commit 2026-04-12. It exists to hold the parts of her Claude Code setup that cannot be public, so that a new machine can be provisioned from both repos together. Her configuration is therefore split across two repositories, which makes `claude-config` and `claude-personal` a coupled pair by construction — see the organizing principle. The audit is incomplete if it only looks at one of them.
- Clone into `research/repos/`. Confirm that path is gitignored; if it is not, add it to `.gitignore` before cloning. Do not commit clone contents.
- Confirm each clone succeeded and print a directory listing.
- Record the resolved list — owner, repo, URL, local path, commit SHA at clone time — in the "Repos to examine" table of the decision log. Later milestones cite that table, and the SHA makes a finding reproducible after upstream moves.

**Success criteria:**
- Every repo Whitney named is cloned and readable locally
- Michael's repo enumeration was re-run at clone time and its full output recorded, and every repo judged plausibly related to configuring or running a coding agent is cloned — not only `llm-coding-workflow`. The recorded output lists each repo with a clone-or-skip decision and a one-line reason, so the filter can be audited rather than taken on trust
- `wiggitywhitney/claude-personal` is cloned or, if already present, pulled current — Whitney's configuration spans two repositories and the local copy may be behind
- `research/repos/` is gitignored, and if that ignore rule had to be added it is committed before the worktree check
- `git status` is clean after cloning and after that commit
- A directory listing has been shown to Whitney and she has confirmed nothing is missing

---

### M2: Current-behavior research — rules, skills, context, compaction

**Model:** Opus 5. Judgment — separating current fact from stale training data, and designing the classification policy.

**Step 0:** Read the "Findings that shaped the plan" section of [the decision log](../docs/research/claude-config-audit-decisions.md). Two findings gate this milestone: GitHub issue #21858 has been ruled out by live test, and the 96,637-byte context leak has been measured and is tracked in issue #108. Do not re-litigate either.

**What:** Establish what Claude Code actually does today with rules, skills, context, and compaction — then produce a measured inventory of what loads in this setup and why.

**Why:** This is a fast-moving area and training data is unreliable. During scoping, a widely-repeated claim about path-scoped rules being silently broken turned out not to apply here, and the real defect was the opposite and more mundane. Every downstream decision about keep-as-rule versus move-to-`CLAUDE.md` versus make-a-skill depends on getting this factual base right.

**To implement:**
- Run `/research how Claude Code loads rules, skills, and CLAUDE.md into context, and what compaction does to each` — start from `code.claude.com/docs/en/context-window` and the Claude Code changelog. Include all `/research` output verbatim with source links and confidence scores; do not summarize it away.
- Run `/research whether Claude Code skills can be installed globally or only per-project, and what changed recently` — this is needed for M4, where Viktor's "never global" position has to be evaluated on current facts.
- Produce a measured inventory at `docs/research/claude-config-load-inventory.md` — a table with one row per file in `rules/` and per skill, with columns: path / loading mechanism / bytes / loaded in a fresh session (yes-no) / why. Totals at the bottom. Record the measurement date and whether issue #108 had merged at the time, since that changes the numbers.
- Ask Whitney to run `/context` and `/memory` and paste the output. Claude cannot invoke these — they are user-typed commands. Reconcile her output against the inventory and note any discrepancy.
- Recommend, per rule, one of: stays a path-scoped rule / moves to `global/CLAUDE.md` for durability across compaction / moves to a hook / becomes an on-demand skill. Present this as a **policy** — a small set of rules for classifying any file — not as 40 individual recommendations. Use the existing hook configuration as evidence for what is already enforced outside model judgment.
- **Inherit the unmet size goal from PRD #43** (closed 2026-03-16, archived to `prds/done/` on 2026-08-03; read its superseded header first). That PRD set out to bring `global/CLAUDE.md` under 150 lines. It shipped its six extracted rule files and missed the goal: the file was 202 lines on 2026-08-03, more than the 172 that prompted the work. **Set the target in always-loaded bytes rather than lines** — lines were always a proxy, and #108 established the real measurement at 56,994 bytes across `global/CLAUDE.md` plus the eleven `@`-referenced rules. Propose a budget Whitney approves, and note that PRD #43 failed partly because its chosen mechanism could not achieve its goal: `@`-referencing an extracted file removes nothing from the always-loaded set.
  - Carry forward PRD #43's Decision 2 as an input rather than relitigating it: short domain-specific sections stay inline, because extracting a four-line section costs more in file overhead than it saves.

**Success criteria:**
- `/research` output for both questions is captured in `docs/research/` with sources
- A measured load inventory exists covering every file in `rules/` and every skill
- Whitney's `/context` and `/memory` output has been reconciled against the inventory
- A classification policy has been presented to Whitney and she has approved or edited it
- An always-loaded byte budget for `global/CLAUDE.md` plus its `@`-referenced rules is proposed and approved, replacing PRD #43's unmet 150-line target
- The resulting decisions are logged in the decision log

---

### M3: Current-behavior research — permissions and approval friction

**Model:** Opus 5. Judgment — building the trigger taxonomy and separating settings-fixable classes from behavior-only ones.

**Step 0:** Read the approval-friction finding in [the decision log](../docs/research/claude-config-audit-decisions.md). Four trigger classes are already documented — `Contains simple_expansion`, the `cd`-with-output-redirection rule, the `cd`-before-`git` rule, and filesystem path access to `/tmp/` — and none is fixable by growing the command allowlist. Do not restart the diagnosis; extend it.

Note that the fourth class has a different mechanism from the first three: it is about which paths a command touches rather than how the command is written, and it offers a one-time permanent grant in the prompt itself. Do not assume the classes share a remedy.

Note also that all three were self-inflicted by Claude writing compound one-liners, and that the correct behavior was written down and then violated twice more in the same session. Weigh that when deciding where the remedy belongs: documentation that the model agrees with and then ignores is not a remedy.

**What:** Determine how to reduce approval prompts, using evidence from actual session history rather than guesses about what commands might be needed.

**Why:** Approval prompts are a daily irritant and a direct hit to the "joy to use" goal. The cause is now understood, but the remedy is not — it splits into a settings question that needs current research and an allowlist question that needs data.

**To implement:**
- Run `/research Claude Code sandbox and permission-mode settings, and whether any of them allow read-only bash commands containing shell expansion to run without prompting` — the current `~/.claude/settings.json` has `skipDangerousModePermissionPrompt` set but no sandbox or default-mode configuration. Include all output with sources.
- **Redact before writing anything to a tracked file.** Session JSONL transcripts contain API tokens, secret values, absolute personal paths, and customer data. Keep raw extracts in a scratch location outside the repository and delete them when the milestone ends. Commit only aggregated output: command classes (not full command lines), counts, and sanitized reason-string labels. Generalize or strip any path containing a username, any string resembling a credential, and any customer or third-party identifier. **The same policy binds M9**, which reads the same transcripts.
- Mine `~/.claude/projects/*/*.jsonl` for every Bash command actually run across recorded sessions, and for every approval prompt and its reason string. Build a **taxonomy of trigger classes** ranked by how often each fires. Two are already known — shell expansion, and `cd` with output redirection — but do not assume the list is complete. For each class, state plainly whether a settings change could eliminate it or whether only changed Claude behavior can.
- Recommend a rebuilt allowlist grounded in that frequency data, plus any settings change the research supports. Present as a policy Whitney approves, not a list of individual entries she vets.
- Write the behavioral guidance that reduces prompts regardless of settings — prefer Grep/Glob/Read over Bash for search and inspection, write literal commands without variable expansion, use absolute paths instead of `cd X && ...`, and put genuine logic in a script file invoked plainly. Decide with Whitney where this guidance lives so it survives compaction.

**Success criteria:**
- `/research` output on sandbox and permission-mode settings is captured with sources
- `docs/research/claude-config-permission-audit.md` exists, containing the frequency-ranked command inventory and the trigger taxonomy, with each class labeled settings-fixable or behavior-only
- A rebuilt allowlist and any settings change have been recommended and approved by Whitney
- Behavioral guidance is written and its location decided
- Decisions logged

---

### M4: Viktor swarm workflow spike

**Model:** Opus 5 on the main thread — the already-have / have-worse / have-nothing calls are judgment. Delegate bulk file reading of the clone to Sonnet subagents.

**Step 0:** M1 must be complete — the clones must exist. **Pull all three Viktor repos before reading them** and record the SHAs; M1 may have run long before this milestone. Read M2's output on global-versus-project skill installation; Viktor's position cannot be fairly evaluated without it.

**What:** Summarize Viktor's role-based agent swarm — `.dot-agent-deck.toml`, the orchestrator / coder / reviewer / auditor / tester / release roles — and identify specifically where it solves a problem the current setup has no answer for.

**Why:** This is the largest structural difference between his workflow and Whitney's, and it overlaps directly with the parallel-work problem she named as the change most likely to affect how her day feels. The question is not "is his approach good" but "which specific gap does it fill here."

**To implement:**
- Start with `.dot-agent-deck.toml`. It is the primary artifact of this spike — his own framing is that it describes the roles of his agent swarm for a project and that he now relies heavily on it. The skills are downstream of that structure, so read the TOML first and let it frame everything else. Do not go deep on his PRD skills — that is M5.
- Then read the `.claude/` setup in `dot-agent-deck`, and `dot-ai` for how he distributes skills into projects. The purpose of `dot-ai` beyond skill distribution is unknown; establish what it actually is rather than assuming.
- Document how roles are defined, how work is dispatched between them, and what state coordinates them.
- Examine how he distributes skills into projects, and evaluate his "skills are always per-project, never global" position against M2's findings. Note that his stated reason is portability — clone onto a different laptop and it works.
- For each capability, state plainly whether Whitney already has an equivalent, has a worse equivalent, or has nothing.
- Cover the parallel-work angle explicitly: tmux, running multiple agents concurrently, and how his swarm handles or avoids it.

**Success criteria:**
- `docs/research/viktor-swarm-workflow.md` exists, covering roles, dispatch, coordination state, and skill distribution
- Each capability is labeled: already have / have worse / have nothing
- The global-versus-project skill question is answered against current platform behavior, not assertion
- Decisions logged

---

### M5: Skill families diffed and an autonomous-first consolidation designed

**Model:** Opus 5. Judgment throughout — "what is genuinely better in mine" is the exact call a weaker model gets wrong by deferring to whatever it read most recently.

**Step 0:** M1 must be complete. Read M4's output — the swarm findings determine which of Viktor's PRD-skill features are only meaningful inside a swarm.

**What:** Diff Viktor's current PRD-related skills against this repo's PRD-lifecycle and issue-lifecycle skills, and label every difference by adoption timeline.

**Canonical skill manifest.** Use this exact list for comparison, consolidation, and migration; do not re-derive it from a glob, because `prd-*` silently excludes `prds-get`.

- **PRD lifecycle, 8 skills:** `prd-create`, `prd-start`, `prd-next`, `prd-update-progress`, `prd-update-decisions`, `prd-done`, `prd-close`, `prds-get`. Each has both a `SKILL.md` and a `SKILL.v1-yolo.md` — **16 files, 8 pairs.**
- **Issue lifecycle, 6 skills:** `issue-create`, `issue-start`, `issue-next`, `issue-update-progress`, `issue-update-decisions`, `issue-done`. No YOLO variants — **6 files.**
- **Not a skill:** `prd-loop-continue` is `scripts/prd-loop-continue.sh`, a SessionStart hook script installed by `/make-autonomous`. It is in scope for migration because the consolidation may change what it invokes, but it is not part of the 22 skill files and must not be counted as one.

Total in scope: **22 skill files** across 14 skills. Any count that disagrees with this manifest is wrong.

**Why:** Whitney's PRD skills were originally derived from Viktor's, and both have evolved independently since. Some of what he has now will be directly portable; some will only make sense if she later adopts his swarm. Conflating those two timelines would either import machinery she cannot use or cause her to dismiss something she could use today.

**To implement:**
- Read his current PRD-related skills in `dot-agent-deck`'s `.claude/skills/`, **and** locate the ancestor versions in `dot-ai` that Whitney's were forked from. Run the comparison three ways — ancestor, his, hers — per the decision log. Label each difference by who moved: he did, she did, or both did independently. A difference where only she moved is a deliberate divergence and the default is to keep it; the burden is on his version to be better, not merely newer to her.
- Diff against this repo's `prd-create`, `prd-start`, `prd-next`, `prd-update-progress`, `prd-update-decisions`, `prd-done`, `prd-close`.
- For each difference, state: where the two have diverged, what is genuinely better in his, and what is genuinely better in hers. Do not default to his being better because it is newer to her.
- Label every candidate adoption as either **adopt now** (works standalone) or **adopt only with the swarm** (depends on his rule-based sub-agent system). These are different timelines and must not be mixed.
- Extend the same analysis to the six `issue-*` skills and to the eight `SKILL.v1-yolo.md` autonomous variants. **There are three parallel implementations of one lifecycle, not two** — see the decision log finding. Nothing enforces that a change to one family reaches the others, and that has already shipped a live bug: the `prd-done` three-channel CodeRabbit fetch never reached the YOLO variant, so autonomous mode misses findings today.
- Design the consolidation. The direction is settled by the "prioritize autonomy" and "escalation contract" decisions: **collapse the sixteen PRD skill files — eight `SKILL.md` plus eight `SKILL.v1-yolo.md` — down to eight, autonomous-first**, with interactive confirmation gates as the exception rather than the base. That count covers the `prd-*` family only. The six `issue-*` skills are a separate open question resolved in this same milestone: decide whether they merge into one lifecycle with two entry points or stay a distinct family, then state the resulting final file count for both families together and extend the migration plan to cover whichever answer is chosen. A second file requiring hand-mirroring has been tested for four months and produced a bug on each side; do not propose another variant-as-separate-file scheme.
- Generalize `prd-next`'s **Autonomous Decision Protocol** — its explicit proceed-when and stop-when lists — into every lifecycle skill as the standard escalation contract. This is the mechanism that makes reduced oversight safe, and it currently exists in one file out of sixteen. Design it once, informed by M4's findings on how Viktor's roles handle the same problem at swarm scale.
- **Extract repeated procedures into scripts as part of the merge.** Any multi-step procedure spelled out as prose in more than one skill — the three-channel CodeRabbit fetch and its re-review loop being the clearest case, spanning `git-workflow.md`, `prd-done`, and `issue-done` — becomes a single script the skills invoke. Collapsing the prose removes both the duplication and the dependence on whoever reads it executing every step. Enumerate these while diffing; they are easy to mistake for ordinary duplication and skip.
- Merge divergences on merit, not origin. Where the autonomous variant is better (acceptance-gate detection, read-only/mutating/external command classification, autonomous triage), keep it. Where the interactive variant is better (three-channel CodeRabbit fetch, whole-PRD Anki sourcing with dedupe), keep that. Enumerate every divergence across all eight pairs — do not assume the two already found are the only ones.
- Plan the migration. Nine repos symlink `.claude/skills/prd-*/SKILL.md` to `SKILL.v1-yolo.md` in this repo: `cluster-whisperer`, `kubecon-2026-gitops`, `spinybacked-orbweaver`, `spinybacked-orbweaver-eval`, `project-signal-boost`, `KubeHound-Demo`, `commit-story-v2`, `content-manager`, `scaling-on-satisfaction`. Deleting the YOLO files breaks all of them. The migration must be scripted and idempotent.

**Success criteria:**
- `docs/research/viktor-prd-skills-diff.md` exists, covering all eight PRD-lifecycle skills — the seven matching `prd-*` plus `prds-get` — all six `issue-*` skills, and all eight `SKILL.v1-yolo.md` variants
- Every adoption candidate is labeled adopt-now or adopt-with-swarm
- A complete divergence table exists for all eight interactive/YOLO pairs, with a keep-which decision per divergence
- A consolidation design exists: eight autonomous-first PRD-lifecycle files, with a generalized escalation contract, and a scripted idempotent migration for the nine repos carrying PRD skill symlinks
- The six issue-lifecycle skills have a **recorded disposition** — merged into one lifecycle with two entry points, or kept as a separate family — with the reasoning stated either way. M5 cannot pass with only the PRD-family result documented
- A **combined final file count** is stated, covering both families against the canonical 22-file manifest
- The migration plan covers **every** repo consuming either family, not only the nine with PRD symlinks — enumerate consumers rather than assuming the PRD-symlinked set is complete
- Whitney has approved the consolidation design before any file is deleted
- Decisions logged

---

### M6: Michael workflow spike

**Model:** Opus 5 on the main thread. Delegate bulk file reading of the clones to Sonnet subagents.

**Step 0:** M1 must be complete. Read `docs/research/michael-forrester-workflow.md` and `docs/research/michael-autonomous-execution-principles.md` **as historical baselines only** — Whitney has confirmed his workflow has changed since they were written. Do not treat them as current.

**What:** Research Michael's current setup fresh, and update the two stale research documents to match.

**Why:** The existing research shaped PRD #84 and is now out of date. Leaving stale documents in `docs/research/` is worse than having none, because future work will read them and act on them. This milestone both produces new findings and repairs the record.

**To implement:**
- Pull `~/Documents/Repositories/forrester-workflow` and every other Michael repo gathered in M1, and record the SHA read for each. He commits daily; a clone taken at M1 is stale by definition.
- Document his current workflow with the same treatment M4 gives Viktor's: capabilities, and for each one whether Whitney already has an equivalent, a worse equivalent, or nothing.
- Cover the parallel-work angle explicitly — tmux and Netcup were both named as things he has solved and she has not.
- Update `michael-forrester-workflow.md` and `michael-autonomous-execution-principles.md` in place. Mark clearly what changed from the previous version, so anyone who read the old version can see the delta.
- Note any place where the stale research has already influenced this repo — PRD #84 in particular — and flag it for Whitney rather than silently reworking it.

**Success criteria:**
- `docs/research/michael-forrester-workflow.md` covers his current setup, with capabilities labeled already have / have worse / have nothing
- Both stale research documents updated in place, with changes from the previous version marked
- Any downstream impact on existing PRDs is flagged to Whitney
- Decisions logged

---

### M7: Repo-native audit — hooks, skills, general cleanup, and cross-repo config sprawl

**Model:** Opus 5 on the main thread — remove / consolidate / repair / keep is judgment, and "is this rule still true" needs a model willing to say no.

**Enumeration is deterministic, classification is not.** Every raw sweep in this milestone — finding repos with a `.claude/` directory, listing hooks, listing skills, reading frontmatter, resolving symlink targets, collecting file sizes and last-modified dates — is done by a script whose output is reproducible, not by a model looking around. Per the global standard: prefer deterministic scripts for operational tasks; use AI for content understanding and synthesis. Sonnet subagents may classify and summarize what the scripts produce, and may invoke those scripts, but must not substitute their own search for the enumeration. A completeness claim backed by a model's sweep is not a completeness claim.

**Step 0:** Read M2's load inventory. This milestone covers what that inventory does not: hooks, scripts, and accumulated cruft.

**M6 gates the design work in this milestone.** Read its output before designing anything. As of 2026-08-02 Michael's `llm-coding-workflow` already contains working implementations of at least three things this milestone is otherwise asked to invent: a config-drift check with tests written first, a generated rules table, and a fix for rules not being reachable. Designing our own and discovering his afterward would waste the effort and would itself be an instance of the pattern this PRD is organized around.

**What:** Audit claude-config on its own terms and produce a list of things to remove, consolidate, or repair — findings that no comparison against another person's workflow would surface.

**Why:** The audit's centre of gravity naturally drifts toward "adopt what Viktor and Michael do." Whitney explicitly asked that repo-native findings get their own place, and named the hook collection as a likely source. There are currently 14 Claude Code hooks — 5 PreToolUse, 7 PostToolUse, 1 SessionStart, 1 PostCompact — plus native git hook dispatchers and an existing `hooks/archive/`. Seven PostToolUse hooks means substantial advisory output on ordinary tool calls; two fired on a single `gh issue create` during scoping.

**To implement:**
- Inventory every hook: what it enforces, whether it blocks or advises, whether it still fires, and whether its rule is still true. Identify hooks that duplicate each other or that duplicate a rule already stated in `CLAUDE.md`.
- Assess whether advisory PostToolUse hooks are earning their cost. An advisory hook that fires constantly and is usually already satisfied is noise that trains the reader to skim.
- Inventory the skills directory the same way — unused skills, skills superseded by others, skills that should be rules or hooks instead.
- Review `scripts/`, `templates/`, `profiles/`, `config/`, and `hooks/archive/` for dead material.
- Check whether `setup.sh` still reflects what the repo actually installs.
- Note the `/issue-create` gap found during scoping: the skill has no branch for bringing an already-created issue into compliance.
- **Fix the tracked settings symlink — this is a diagnosed defect with a candidate fix, not an open question.** `~/.claude/settings.json` symlinks to the tracked `config/settings.json`, so every settings write Claude Code makes becomes a git diff here. Observed twice: a model change in the working tree on 2026-08-02, and on 2026-08-03 `"model": "opus[1m]"` rewritten to `"sonnet[1m]"` mid-session and reverted rather than committed. Committing it would have flipped the tracked default to the weaker model. Removing the `model` key does not help — `/model` rewrites it. The candidate fix is to stop tracking the live file, since `settings.template.json` plus `setup.sh`'s resolve-and-merge already provides the provisioning path; the repo carries both and needs only the template. Evaluate that fix, then check every remaining symlink target under `~/.claude/` for the same shape and identify which tracked files tooling can mutate.
  - Report the configured model defaults, and record that the source is outside this repo: `/Library/Application Support/ClaudeCode/managed-settings.json` is root-owned Datadog policy setting `model: sonnet`, `effortLevel: medium`, and `CLAUDE_CODE_DISABLE_FAST_MODE: 1`. Managed settings outrank user settings, so no change here makes Opus survive a restart. **Resolved 2026-08-03: Whitney selects the model manually at the start of every session and has accepted that as the standing workflow.** Do not research override mechanisms, propose automation, or raise this as a finding again. Report the configured defaults as a fact about the environment and move on.
- PRD #84's disposition is **not** part of this milestone. It moved to M7b, which resolves it end to end rather than planning a triage for someone else. Do not sort, salvage, or plan for that branch here.
- **Audit the other repos, not just this one.** The scoping instruction was that "all the repos, really, should probably be edited — I bet some can be removed and cleaned up." Discover the repo set by enumerating **every** repository under `~/Documents/Repositories/` containing a `.claude/` directory — not only those with `.claude/skills/`, which would skip a repo carrying just a `settings.local.json`. As a lower bound, twenty-one have `.claude/skills/` and nine carry the YOLO symlinks. Inventory what Claude Code configuration each discovered repo actually has — project `CLAUDE.md`, `.claude/skills/`, `.claude/settings.local.json`, installed git hooks, `.skip-*` dotfiles — and identify what is stale, duplicated, orphaned, or pointing at scripts that no longer exist. Produce a per-repo remove / consolidate / repair / keep recommendation. Do not modify other repos in this milestone; recommend only, and let the spec decide what a cleanup PRD would do.
- **Design the check for unevidenced completion claims.** Per the decision on evidence-bearing claims, a `PROGRESS.md` entry or commit message asserting a state — fixed, working, complete, current, verified, passing — is half of a coupled pair whose other half is the system. Recommend a remedy at the strongest tier available: scripting the recurring verifications so the observation is produced automatically, before falling back to a hook that flags the vocabulary and asks what backs it. Note honestly that the hook is an assert and catches only the words it knows.
- **Inventory prose procedures that should be scripts.** Sweep the rules and skills for multi-step sequences a reader must execute in full for the result to be correct — API calls to several endpoints, ordered git operations, verification loops. Each is a collapse candidate. Flag in particular any procedure whose partial execution looks identical to success, since nothing will ever surface the omission.
- **Design a coupled-pair warning hook, and derive its pair list rather than declaring one.** Of the fourteen existing hooks, twelve fire on a file operation and two on a lifecycle event (`SessionStart`, `PostCompact`); none fires on a relationship between files. A PostToolUse hook that says "you edited `prd-done/SKILL.md` — its partner `SKILL.v1-yolo.md` was last touched two months ago" would have caught four of the five divergences found during scoping, at the moment they were created. Derive pairs by construction wherever possible — any `*.v1-yolo.md` beside a `SKILL.md` is a pair; any script path named inside a rule file is a pair; **any tracked file that differs between `main` and an unmerged local branch is a pair** (Decision 28), enumerable with `git branch --no-merged main` and `git diff --name-only main <branch>` — because a hand-maintained registry of pairs would itself be a second place a decision lives. This is the only remedy that reduces the rate of *new* pairs instead of cleaning up known ones.

  The branch-versus-main class is worth calling out separately because it has a property the others lack: the stale half is known in advance. For an unmerged branch, `main`'s copy cannot reflect that branch's work, so there is no "which side is current" ambiguity to resolve — only a question of whether the reader knows to look. This PRD got it wrong for PRD #84 before the class was named.
- Recommend a mechanism for detecting stalled work. PRD #84 reached six of eight milestones and then sat unpushed for four months with no hook, skill, or session-start check surfacing it. Whatever the redesign produces needs a way to notice this class of silence. Note that the branch was also the only copy of five journal files, four of them absent from main — so stalled-work detection is a data-loss concern, not only a throughput one.
- Present findings as a categorized list — remove / consolidate / repair / keep — for Whitney to approve as a set.

**Success criteria:**
- `docs/research/claude-config-repo-audit.md` exists, containing a complete hook inventory with a remove / consolidate / repair / keep recommendation for each
- A skills inventory with the same treatment
- Dead material in `scripts/`, `templates/`, `profiles/`, `config/`, and `hooks/archive/` identified
- A cross-repo configuration inventory exists covering every repo with a `.claude/` directory, with a remove / consolidate / repair / keep recommendation per repo and no other repo modified
- Every enumeration behind the inventories is produced by a committed, re-runnable script, not by a model's sweep — re-running it reproduces the same list
- A coupled-pair warning hook is designed, with its pair-discovery method stated and shown to be **derived by construction** rather than from a maintained list, plus the set of pairs that method currently finds and an honest statement of which known pairs it misses
- A stalled-work detection mechanism is recommended, with the reasoning for the approach chosen
- Whitney has approved the categorized list

---

### M7b: PRD #84 resolved and retired, and issue #98 with it

**Numbered M7b rather than M8 deliberately.** Renumbering the later milestones would mean updating roughly eleven cross-references to M8 and M9 scattered through this document, and stale cross-references are the exact defect Decision 28 records. Do not "fix" this to M8.

**Model:** Opus 5 on the main thread. Every verdict here is a judgment call with an irreversible consequence attached, and one of the three outcomes deletes work permanently.

**Step 0:** Read M4, M5, and M6 first. All three gate this milestone. Whether PRD #84's architecture is still the right one is precisely what those spikes determine, so no verdict reached before they complete is worth anything.

**What:** Resolve PRD #84 completely. By the end of this milestone the branch `feature/prd-84-autonomous-prd-execution` no longer exists, issue #84 is closed, `prds/84-autonomous-prd-execution.md` is in `prds/done/`, and nothing about PRD #84 remains on anyone's list.

**Why:** PRD #84 reached six of its eight milestones in April, then sat unpushed for four months. It is the clearest instance in this repo of work that was neither finished nor abandoned, and the cost of that limbo is ongoing: it holds a branch nobody dares delete, it made a claim in this PRD that turned out to be wrong, and until 2026-08-03 it was the sole copy of five journal files. Planning a triage for some future PRD is how it got stranded in the first place, so this milestone performs the disposition rather than scheduling it.

**This milestone performs implementation, by explicit exception (Decision 29).** Everywhere else this PRD defers implementation to the PRDs its spec produces. That deferral does not apply here. Merging a surviving piece, deleting the branch, and closing the issue all happen inside this milestone.

#### The three verdicts

Every piece of work on the branch receives exactly one:

1. **Trash.** No value in the code and no lesson worth recording. It goes away with the branch and is never mentioned again.
2. **The code lives.** It is merged to main, and PRD #84's approach for that piece becomes part of the canonical workflow the spec describes.
3. **The learnings live, the code does not.** What was discovered is written into the spec; the implementation is discarded with the branch.

**Assign no verdict before this milestone runs, and record none in this PRD.** The facts below are recorded precisely so that whoever performs this milestone can reach their own conclusions from evidence rather than inheriting someone else's. A presumptive verdict written here would decide the question in advance while appearing to leave it open.

**Constraint on verdict 2:** a piece cannot take verdict 2 if it modifies a file that M5's consolidation restructures. Merging it would only be undone when the consolidation is implemented. Such a piece takes verdict 3 instead — its idea reaches the spec, its code does not.

#### Facts about the branch, recorded 2026-08-03

Re-verify each before relying on it; main moves.

- 88 commits behind main. A trial merge (`git merge-tree --write-tree main <branch>`) reports five conflicts: `PROGRESS.md`, `config/settings.json`, `rules/microblog-api-gotchas.md`, and add/add conflicts on `journal/entries/2026-05/2026-05-16.md` and `journal/summaries/daily/2026-05-14.md`. The branch cannot be merged without conflict resolution, and two of the five conflicts are journal files.
- No remote counterpart exists. The branch has never been pushed, so it is a single local copy.
- Its journal content was rescued to main on 2026-08-03: two files main lacked entirely and branch-only lines in two others. **Re-run the check before deleting anything** rather than trusting this line — `git diff --numstat main <branch> -- journal/` — because the rule against losing journal files does not admit exceptions and this note could be wrong.
- The branch's own copy of `prds/84-autonomous-prd-execution.md` is the authority on its state (Decision 28): eight milestones, M1–M6 checked. Main's copy shows seven with everything unchecked.

**Work on the branch, by PRD #84 milestone.** Descriptions only — no assessment.

| PRD #84 milestone | Files | What it does |
|---|---|---|
| M1 | `.claude/skills/make-autonomous/SKILL.md`, `make-careful/SKILL.md`, `tests/make-autonomous.bats` | Adds twelve permission entries so a headless `claude -p` session can run tests, manage tasks, spawn agents, and schedule wake-ups; matching removals in careful mode |
| M2 | `hooks/git/checks/pre-push-verify.sh`, `tests/git-hook-checks.bats` | Runs the project test command on every push rather than only when a PR is open |
| M3 | `scripts/autonomous-prd.sh`, `scripts/autonomous-prd-child-prompt.md`, `tests/autonomous-prd.bats` | Orchestrator that spawns child sessions and writes an active-run marker |
| M4 | `scripts/check-autonomous-run.sh`, `tests/check-autonomous-run.bats`, `scripts/install-git-hooks.sh` | SessionStart detection of an in-progress autonomous run |
| M5 | `rules/autonomous-pause-handling.md`, `.claude/skills/prd-next/SKILL.v1-yolo.md`, `prd-update-progress/SKILL.v1-yolo.md` | Pause-handling rule and YOLO skill changes for headless operation |
| — | two `prd-9999` commits | Smoke-test scaffolding created while validating the loop |
| — | `docs/research/claude-code-autonomous-capabilities.md`, `docs/research/index.md`, `rules/bats-bash-testing.md`, `rules/microblog-api-gotchas.md`, `.gitignore`, `global/CLAUDE.md`, `PROGRESS.md`, `config/settings.json` | Incidental edits alongside the milestone work |

PRD #84's two unfinished milestones are its M7, an end-to-end run against `spinybacked-orbweaver` PRD #752, and its M8, user documentation. Neither is completed here. If the spec needs either capability, the spec states that requirement in its own terms rather than inheriting PRD #84's milestone framing.

Its Decision 1 rejected Michael's `_execution-state.md` and `tasks.yaml` patterns on the strength of research that M6 replaces. Re-examine that reasoning against M6's findings.

#### Issue #98 resolves here too

Issue #98 (`scripts/autonomous-issues.sh`, opened 2026-05-15, untouched since) is **downstream of this milestone's verdicts, not a parallel case.** It has no work product at all: no `autonomous-issues.sh` exists in any commit on any branch, and no branch was ever created for it. Verified 2026-08-03.

What it does have is a hard dependency on PRD #84's code. Every item in its own "Read before starting" list — `scripts/autonomous-prd.sh`, `scripts/autonomous-prd-child-prompt.md`, the active-run marker format, and M4's SessionStart collision detection — exists only on the branch this milestone may delete, and its instructions say to reuse those conventions and keep them identical. If the orchestrator does not survive, #98 becomes an issue directing a future implementer to read four files that do not exist. That is worse than either outcome, so it cannot be left untouched.

- If the orchestrator row takes the code-lives verdict, #98 stays open and becomes actionable as written.
- Otherwise #98 is closed, and the requirement behind it — unattended execution over a flat queue of standalone issues, not only over PRD milestones — is carried into the spec in the spec's own terms, with no reference to PRD #84's conventions.

Either way, #98 does not survive this milestone as an open issue pointing at deleted files. Its one genuinely independent design claim is worth weighing on its merits when the spec is written: that a flat issue queue and a milestone-structured PRD queue should be two focused mechanisms rather than one generalized one. That is a live question about the canonical workflow, not an inherited answer.

**To implement:**
- Read M4, M5, and M6 output. Re-verify the facts above, including that #98 still has no work product.
- Assign one of the three verdicts to every row of the work table, with the reasoning for each.
- Resolve #98 per the two branches above, and record which applied.
- Present the completed table to Whitney and get her approval before acting on any row. Approval covers the set, not each row separately.
- Write the verdict-3 learnings into the spec. This happens inside PRD #109; do not schedule it elsewhere.
- If any row took verdict 2, merge that work to main through a PR, following the normal review gate.
- Confirm no journal content exists only on the branch. If any does, rescue it to main first.
- Delete the branch, locally and on any remote it reached.
- Close issue #84 with a comment recording each row's verdict, and move `prds/84-autonomous-prd-execution.md` to `prds/done/`.
- Remove the stale-copy warning from that file's header — once the branch is gone, the warning describes a branch that no longer exists.

**Success criteria:**
- Every row of the work table carries exactly one verdict and the reasoning behind it
- Whitney has approved the completed verdict table
- Every verdict-3 learning is present in the spec, verifiable by pointing at where
- No journal content exists only on the deleted branch, shown by the diff command rather than asserted
- `feature/prd-84-autonomous-prd-execution` does not exist
- Issue #84 is closed with the verdicts recorded, and its PRD file is in `prds/done/` with the stale-copy warning removed
- Issue #98 is either open and actionable without referring to deleted files, or closed with its requirement carried into the spec — and which of the two happened is recorded
- No open item anywhere refers to PRD #84 as pending work, and no open item references a file that this milestone deleted
- Decisions logged

---

### M8: Spec file written and signed off

**Model:** Opus 5. The highest-judgment milestone in the PRD — everything else exists to feed it.

**Step 0:** Read the full decision log and the output of M2 through M7b. Every one of those milestones gates this one.

**What:** Write a spec file in this repo recording concrete decisions: what to keep building on, what to tear down and recreate, and whether any part warrants a separate system rather than a modification of this one.

**Why:** A conversational summary evaporates. The spec is the artifact that survives, and it is what the implementation PRDs are generated from. It has to be specific enough that a cold reader could act on it.

**To implement:**
- Before writing, ask Whitney the real open questions surfaced across M2–M7b — one at a time, per the Process section. Do not guess at her preferences to avoid asking.
- Structure the spec around decisions, not findings. Each entry states what was decided, what was rejected, and why.
- Record explicitly **what stays intact under every scenario** — the fallback path to the current way of working must be legible. Whitney has to be able to revert if the new approach does not pan out.
- Identify which implementation PRDs the spec should spawn and in what order. Do not create them in this milestone; recommend them and let Whitney decide the number and sequencing.
- Note that issue #108 is a blocking dependency for implementation work, and confirm its status before the spec proposes anything that depends on rule loading being fixed.
- Run `/write-prompt` on the spec before presenting it. The spec is a prompt — future agents will read it and act on it.

**Output format.** The spec is written to `docs/claude-config-redesign-spec.md` — `docs/`, not `docs/research/`, because it is a decision record rather than a research artifact. Required sections, in this order:

1. `## Verdict` — one paragraph. Which of three outcomes applies: keep building on the current system, tear down and recreate parts of it, or build a separate system alongside it. State it plainly in the first sentence.
2. `## Coupled pairs` — the inventory. Every place in the system where one decision must be recorded in two or more locations to take effect: documentation and its implementation, skill and variant, rule and hook, index and reality, PRD and decision log, global config and per-repo config, **and completion claim versus actual state** (see the decision on evidence-bearing claims — a `PROGRESS.md` entry or commit message asserting something works is one half of a pair whose other half is the system itself). One row per pair, with what currently keeps them in sync (usually nothing) and whether they are known to have diverged. This section comes **before** the decisions because the decisions are dispositions of these pairs.

3. `## Decisions` — a table with columns Decision / Rejected alternative / Rationale / Which PRD implements it. A decision with no rejected alternative recorded is incomplete; if nothing was seriously considered and discarded, say so explicitly rather than leaving the cell empty.

   **Organize this section by remedy, not by subsystem** — three subsections in this order:
   - `### Collapse` — the second place stops existing. Preferred; nothing left to diverge.
   - `### Derive` — one artifact is generated from the other, so they cannot disagree.
   - `### Assert` — a check fails when they diverge.

   Justify every entry that lands in `Assert` by stating why collapse and derive were both rejected for that pair. Assert is the weakest remedy: it only catches pairs someone already enumerated, and every instance found during scoping was a pair nobody had. A spec whose decisions are mostly asserts has described the problem rather than solved it.

   A pair from the inventory may also be resolved as `Accept` — deliberately left duplicated. That is a legitimate outcome, but it must be stated with its reason, not left off the list.
4. `## What stays intact` — the fallback path. For every proposed change, what remains working if that change is reverted, and what the revert procedure is. This section is not optional and cannot be deferred to an implementation PRD.
5. `## Proposed implementation PRDs` — numbered, ordered, each with a one-line scope and its dependencies. Recommendations only; Whitney decides the final set.
6. `## Open questions carried forward` — anything unresolved, and what would resolve it.

A spec that summarizes findings instead of recording decisions has failed this milestone, however well written. The test: every entry in `## Decisions` names something that will or will not be done, not something that was learned.

**Success criteria:**
- `docs/claude-config-redesign-spec.md` exists with all six required sections present and populated
- Every pair in `## Coupled pairs` has a disposition in `## Decisions` — collapse, derive, assert, or accept — with no pair left unaddressed, and every `assert` justified by why collapse and derive were rejected
- The fallback path is documented — what stays intact under every proposed scenario
- Recommended implementation PRDs are listed with an order, and Whitney has decided on them
- `/write-prompt` has been run and high-severity findings applied
- Whitney has explicitly signed off

---

### M9: Audit-agent verification pass

**Model:** Opus 5 (1M context) — **required, not preferred.** This milestone diffs multi-hundred-KB session transcripts against three documents. A smaller context window forces chunking, and chunking is how a decision goes missing in the one milestone whose entire job is catching missing decisions.

**Step 0:** M8 must be complete and signed off.

**What:** Verify that the spec and this PRD together capture everything decided during the scoping and audit conversations, using the raw session transcript as ground truth.

**Why:** The scoping conversation for this PRD was long and decision-dense, and the audit conversations will be longer. Compaction summarizes lossily, and decisions made in conversation have a real chance of never reaching a document. The session transcripts persist on disk regardless of compaction, so this check is possible — but only if someone deliberately runs it.

**To implement:**
- Apply M3's redaction policy. These are the same transcripts, with the same secrets in them. Raw extracts stay outside the repository; only findings reach a tracked file.
- Read the session transcripts in `~/.claude/projects/-Users-whitney-lee-Documents-Repositories-claude-config/`. The scoping conversation for this PRD is `a32b6735-ae87-47d4-9fdf-5cdbe24805a9.jsonl`; later audit sessions will add more.
- Extract every decision, rejected alternative, constraint, and open question from the transcripts.
- Diff that against the decision log, this PRD, and the spec file. Report anything present in conversation but absent from all three.
- Apply the cold-AI test to the spec: could someone with no access to these conversations act on it using only what is written?
- Add anything missing to the appropriate document rather than only reporting it.

**Success criteria:**
- Every decision found in the transcripts is present in the decision log, this PRD, or the spec
- Gaps found have been added to the appropriate document, not just listed
- The cold-AI test has been applied to the spec and any failures repaired

---

## Dependencies

- **Issue #110** (bidirectional drift between interactive and autonomous `prd-done`) does not block this PRD. It stops two live bugs while the audit runs, and its divergence table feeds M5 directly. M5 must read it before starting.
- **Issue #108** (three rule-loading defects) blocks the implementation PRDs this spec spawns, not this PRD itself. This PRD is written first; #108 is executed after. When #108 is started, it must be started with the `/issue-start` skill.
- M4, M5, and M6 all depend on M1's clones.
- M5 depends on M4. M7b depends on M4, M5, and M6. M8 depends on M2 through M7b. M9 depends on M8.

## Decision Log

| # | Decision | Rationale |
|---|---|---|
| 1 | The goal is a workflow current with what AI can do now, and a joy to use — wise, efficient, happy, productive. | Explicitly **not** driven by the You Choose Episode 1 deadline, and unrelated to the house-hunting spike. Both were considered as framing and ruled out. |
| 2 | This PRD is audit → decide → spec. Its deliverable is a spec file, not an implementation. | The outcome is unknown at the start. Writing implementation acceptance criteria before the research would either pre-commit to an answer or produce criteria too vague to fail. |
| 3 | The spec spawns one or more separate implementation PRDs. | "Fix rule loading," "rebuild the permission model," and "adopt parallel agent workflows" have little in common beyond the repo. One combined PRD would create the cross-PRD tangle the repo's own rules warn against. |
| 4 | 100% human decides. Claude recommends, asks one question at a time, never decides ahead of Whitney. | She has to live inside this workflow daily. A decision made for her is one she never evaluated, and it silently becomes load-bearing. Overrides YOLO mode for genuine choices. |
| 5 | The PRD is written first; issue #108 is executed after. | The scoping conversation is decision-dense and should be captured while fresh. #108 is fully specified and can be executed any time before implementation. Doing #108 first was considered and rejected. |
| 5a | When #108 is started, it must be started with `/issue-start`. | Ad-hoc execution already caused rework once on `/issue-create`. |
| 6 | The "reference pointer" index moves out of `global/CLAUDE.md` to `rules/README.md` in full. No shortened version stays behind. | Once every rule is correctly path-scoped the index does nothing functional, and it is the exact artifact that drifted out of sync with reality for four months. |
| 7 | The parallel-work problem (tmux, Netcup, concurrent agents) is in scope of the research and the spec. | Named in the 2026-08-02 morning pages as the change most likely to affect how the day feels, and it overlaps directly with Viktor's swarm roles. |
| 8 | Permission and approval friction is in scope of this PRD, out of scope of #108. | Diagnosed but not solved — needs research plus evidence mining, unlike #108 which is fully specified. |
| 9 | The `/issue-*` skills are a named workstream, updated after the `/prd-*` skills. | Seven `prd-*` and six `issue-*` skills are near-parallel implementations of the same lifecycle, with nothing enforcing that a change to one mirrors into the other. |
| 10 | The audit must leave room for findings native to this repo, not only findings derived from Viktor's or Michael's setups. | Named examples: the git hook collection likely contains removable and consolidatable hooks; general repo cleanup. |
| 11 | Falling back to the current way of working must remain possible. The spec records what stays intact under every scenario. | Stated requirement — the new system may not pan out. |
| 12 | Decisions are logged continuously to the decision log, and M9 verifies the finished documents against the raw session transcript. | Compaction summarizes lossily. The transcript persists on disk regardless, so late reconstruction is possible — but a running log is cheaper and catches drift earlier. |
| 13 | Whitney decides policies, not instances. | Decision 4 is about control over what the system becomes, not over mechanical execution. Per-instance approval is miserable at scale and buries the actual choice. |
| 14 | The existing Michael research is stale and M6 is a fresh spike, not a validation pass. | Whitney confirmed his workflow has changed since those documents were written. Leaving them unmarked would let future work act on outdated findings. |
| 15 | Every milestone declares a required **Model**. Claude reads the session model at milestone start, proceeds silently on a match, and stops to ask Whitney to switch on a mismatch — then re-reads the environment to verify rather than accepting her word. | Claude cannot invoke `/model`; it is user-typed. A directive phrased as "switch models here" would be silently unexecutable. Verification beats confirmation because Whitney's managed settings pin Sonnet 5 on restart, so the wrong model is the default, not the exception. Per-milestone model and effort are not expressible in the current PRD skills at all — logged as a redesign finding for M7. |
| 16 | **Prioritize autonomy.** Whitney wants less oversight of Claude, not more. Where the audit must choose between an autonomous and an interactive pattern, autonomous wins by default. Take best practices from both, but the confirmation-gated version is the exception, not the base. | Stated guiding principle. This does **not** conflict with decision 4 — she decides the shape of the system, then wants that system to run with less babysitting. Design authority stays human; runtime supervision goes down. Consequence: skill consolidation merges toward the autonomous variant, not away from it. |
| 17 | The escalation contract — explicit proceed-when and stop-when criteria, as in `prd-next`'s Autonomous Decision Protocol — is what makes reduced oversight safe, and it must be generalized to every lifecycle skill. | It currently exists in exactly one of sixteen skill files. Autonomy without a crisp escalation contract is not autonomy, it is unsupervised guessing. This is higher-value than any individual bug fix in the skill set. |
| 17a | **"One decision, two places" is the spec's organizing principle.** A decision that must be recorded in two places to take effect, where updating one gives no signal that the other is now stale, is the root pattern behind most findings in this audit. The spec organizes its decisions by remedy — **collapse** (make the second place stop existing), **derive** (generate one from the other so they cannot disagree), **assert** (a check that fails on divergence) — in that strict order of preference, rather than by subsystem. | Five independent instances surfaced during scoping alone: CLI flags documented but not implemented in the hook; the three-channel CodeRabbit fetch added to one skill variant and not the other; acceptance-gate labeling added to the other variant only, while `CLAUDE.md` claimed both had it; an Anki card-cap raise that landed without the constraint justifying it; and a flag repair that fixed three of four flags in one command. The context leak and the permission friction are the same pattern — configuration living in more places than anyone tracks. Each half stays individually valid, so nothing errors and no test fails. **Assert is the weakest remedy** because it only catches pairs someone already thought of; every instance found in this audit was a pair nobody had enumerated. |
| 18 | Claude checks in with Whitney after **every** milestone. Milestones are not chained. | Explicit instruction when the audit was first scoped, and it was missing from the first draft of this PRD — found by the transcript audit on 2026-08-02. |
| 19 | Conversation-versus-document verification runs **after every milestone**, not only at M9. | Also found by the transcript audit. Waiting until M9 would mean discovering at the end that an instruction given at M1 was never captured, after seven milestones had been built on the gap. M9 remains the final pass over the finished spec. |
| 20 | The existing Michael research is stale; M6 is a fresh spike that also repairs the two outdated documents in place. | Whitney confirmed his workflow changed since they were written. Leaving them unmarked would let future work act on outdated findings — PRD #84 already did exactly that. |
| 21 | M7 audits Claude Code configuration across **all** repos, not only claude-config — recommend-only, no other repo modified in this PRD. | "All the repos, really, should probably be edited — I bet some can be removed and cleaned up." Twenty-one repos have a `.claude/skills/` directory and nine carry YOLO symlinks, so the sprawl is real and measurable. Also found by the transcript audit. |
| 22 | This PRD was itself created using the pre-redesign process — the current `/prd-create`, `/issue-create`, and `/write-prompt` skills, with their current friction. | It serves as a baseline. Whatever the redesign produces should be measurably better to use than what produced this document. |

| 23 | The Viktor skill comparison is a **three-way** diff — common ancestor in `dot-ai`, his current version in `dot-agent-deck`, and Whitney's — not a two-way diff of his current against hers. | Her `prd-*` skills were forked from `dot-ai`; his current skills live in `dot-agent-deck`. A two-way diff cannot distinguish "he changed this" from "she changed this" from "both changed it independently," and collapsing those three cases produces recommendations that quietly discard her deliberate divergences as though they were staleness. |
| 24 | `.dot-agent-deck.toml` is the primary artifact of the Viktor spike, ahead of his skills. | His own framing: the TOML describes the roles of his agent swarm for a project, and he now relies heavily on it. The skills are downstream of that structure. |

| 25 | **Every enumeration in this PRD is produced by a committed, re-runnable script; models classify and synthesize but never enumerate.** Applies to M2's load inventory, M3's command and prompt-reason mining, M7's hook/skill/cross-repo sweeps, and M9's transcript extraction. | The global standard already says to prefer deterministic scripts for operational tasks and reserve AI for content understanding and synthesis. Beyond that, several milestones make completeness claims — "every file in `rules/`", "every repo with a `.claude/` directory" — and a completeness claim backed by a model looking around is not a completeness claim. Scripts also make the numbers reproducible later, which matters because this PRD's before/after measurements are its evidence. |

| 26 | **A multi-step procedure that must be executed correctly becomes a script, not prose in a skill.** This is a form of collapse: N prose steps can be partially executed and silently half-done; one command either runs or fails. When the spec finds a procedure written out as instructions in more than one skill or rule, the default disposition is to extract it into a script that all of them call. | The three-channel CodeRabbit fetch is the worked example. It is currently prose in `git-workflow.md`, prose in `prd-done/SKILL.md`, and absent from `prd-done/SKILL.v1-yolo.md` — so it is simultaneously a duplicated-decision pair and a remember-to-do-it-right procedure. Both failure modes fired during scoping on 2026-08-02: the YOLO variant has been fetching one channel of three since June, and Claude — with the rule loaded in context and having just documented the bug — fetched two of three by hand and reported the review as processed. Two findings were missed. A procedure whose correctness depends on the reader remembering all its steps will eventually be executed partially, and partial execution here is indistinguishable from success. |

| 27 | **A claim about the state of the world must carry the observation that supports it, in the same sentence.** Verbs describing an action taken ("edited the file") are self-evidencing and need nothing. Verbs describing a resulting state — fixed, working, complete, current, verified, passing — are claims about reality and require the observation attached. If the observation cannot be produced, the claim cannot be written. `PROGRESS.md` entries and commit messages state what changed and what was observed as separate clauses, never collapsed into one. | Three instances during scoping on 2026-08-02, all the same shape: the CodeRabbit hook was called "fixed" when three of four invalid flags had been replaced and the fourth was never checked against `--help`; the approval-prompt mitigation was called "narrow and complete" on the strength of three observations; a clone was called "current" when it was 500 commits behind. In each case the summary was written in the same breath as the action, before any verification could have occurred, and the observation that would have falsified it was available and not made. This is a coupled pair — the claim and the reality — with nothing holding them together, and partial truth reads identically to complete truth. It matters more as oversight decreases: the point of prioritizing autonomy is that Whitney is watching less closely, which means the claims have to carry their own evidence. |
| 28 | **When a document exists on both an unmerged branch and main, the branch version is the authority on that branch's own state — read it, not main's.** For PRD #84 specifically, M7b reads the branch's copy of the PRD file. Any statement about an unmerged branch's progress that was derived from main's copy is suspect and needs re-deriving. | The milestone counts diverged and this PRD recorded the wrong one. Main's `prds/84-autonomous-prd-execution.md` lists seven milestones with documentation as M7 and every checkbox unchecked; the branch's lists eight, with M1–M6 checked, an added M7 for real-PRD validation against spinybacked-orbweaver PRD #752, and documentation moved to M8. This PRD said "six of seven" in two places, which understated the remaining work and mischaracterised it as documentation-only when one of the two remaining milestones is external validation. The cause is the same coupled-pair pattern this PRD is organized around, with an extra twist: for an unmerged branch, main's copy is *structurally* guaranteed to be the stale half, so the usual "which side is current" question has a known answer. Verified 2026-08-03 by reading both copies. |
| 29 | **PRD #84 is resolved inside this PRD, not planned for a later one — M7b performs the disposition, merges anything that survives, deletes the branch, and closes the issue.** This is an explicit exception to this PRD's rule that implementation is deferred to the PRDs its spec produces. Each piece of work on the branch takes one of three verdicts: trash, the code lives, or the learnings live and the code does not. | The earlier text said "this milestone plans the triage; it does not perform it," which is the same move that stranded PRD #84 in the first place: six milestones finished in April, then four months of limbo because the remaining step belonged to nobody in particular. A plan handed to a future PRD is indistinguishable from no plan if that PRD is never written. Whitney's instruction was that #84 be completely off the plate at the end of the milestone — closed, branch gone, never thought about again — which is only achievable if the milestone acts. The limbo also had a cost beyond drag: the branch was the sole copy of five journal files, and a stalled branch nobody will delete is a data-loss risk that grows with time. |
| 30 | **A PRD records the evidence bearing on an open decision and never a presumptive answer to it.** Facts, measurements, and descriptions belong in the milestone; verdicts, likely outcomes, and default dispositions do not. Where a milestone exists to make a judgment, the document's job is to make that judgment well-informed rather than pre-made. | Written while drafting M7b. A per-item table of likely verdicts was proposed and rejected: a recommendation written into a PRD is read by the agent performing the milestone as the answer, not as an input, so it decides the question in advance while appearing to leave it open. The converse error is just as real, though — stripping the *facts* along with the opinions would force rediscovery of things like the branch being 88 commits behind with five merge conflicts, and an agent under time pressure may simply not re-derive them and then choose a verdict on a false premise about cost. So the rule cuts precisely between the two: record that a change is a ten-line edit touching no skill file; do not record that it therefore deserves to survive. |

## Open Questions

Carried from the decision log. These are answered during the milestones, not before.

- Should `/issue-*` and `/prd-*` collapse into one lifecycle with two entry points, or stay two families? *(M5)*
- Which specific rules stay rules, which move to `CLAUDE.md` or hooks for durability, and which become on-demand skills? *(M2)*
- Global versus project-level skills — Viktor's position is "never global." Does that hold once #21858 is ruled out? *(M2, M4)*
- Is there a sandbox or permission-mode setting that eliminates the `simple_expansion` prompt class outright? *(M3)*
- How many implementation PRDs should the spec produce, and in what order? *(M8)*
- Which additional Michael repos should be cloned? *(M1)*
- Which git hooks can be removed or consolidated? *(M7)*
