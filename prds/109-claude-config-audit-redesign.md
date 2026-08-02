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

**Log decisions as they are made,** to `docs/research/claude-config-audit-decisions.md`, in the same turn they are made. Do not batch them for later reconstruction. The scoping conversation for this PRD was long and decision-dense; compaction summarizes lossily and the running log is the defense against that.

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
- [ ] M8: Spec file written and signed off
- [ ] M9: Audit-agent verification pass against the decision log and session transcript

---

### M1: Reference repos gathered and cloned

**Model:** Any. Mechanical — cloning and confirming. No switch needed.

**Step 0:** Read [the decision log](../docs/research/claude-config-audit-decisions.md), specifically the "Repos to examine" table.

**What:** Ask Whitney for every repo link she wants examined, then clone each one locally into a scratch directory that is excluded from version control.

**Why:** Fetching these via web search or WebFetch hit GitHub crawl-blocking during scoping. Local clones sidestep that entirely. Gathering happens once, up front, because M4, M5, and M6 all depend on the clones existing — if cloning were folded into the first spike, the later ones would either redo it or silently depend on leftover state.

**To implement:**
- Ask Whitney to confirm the Viktor repo list. Known candidates: `vfarcic/dot-agent-deck` (swarm roles, `.dot-agent-deck.toml`, and PRD skills in `.claude/skills/`), `vfarcic/dot-ai-infra` (permanent cluster), `vfarcic/dot-ai` (skill distribution into projects — needs confirmation that this is the right repo).
- Ask Whitney for Michael's repos. `llm-coding-workflow` is already cloned at `~/Documents/Repositories/forrester-workflow` but is stale — re-pull it. She has additional repos to supply.
- Clone into `research/repos/`. Confirm that path is gitignored; if it is not, add it to `.gitignore` before cloning. Do not commit clone contents.
- Confirm each clone succeeded and print a directory listing.
- Record the resolved list — owner, repo, URL, local path, commit SHA at clone time — in the "Repos to examine" table of the decision log. Later milestones cite that table, and the SHA makes a finding reproducible after upstream moves.

**Success criteria:**
- Every repo Whitney named is cloned and readable locally
- `research/repos/` is gitignored and `git status` is clean after cloning
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

**Success criteria:**
- `/research` output for both questions is captured in `docs/research/` with sources
- A measured load inventory exists covering every file in `rules/` and every skill
- Whitney's `/context` and `/memory` output has been reconciled against the inventory
- A classification policy has been presented to Whitney and she has approved or edited it
- The resulting decisions are logged in the decision log

---

### M3: Current-behavior research — permissions and approval friction

**Model:** Opus 5. Judgment — building the trigger taxonomy and separating settings-fixable classes from behavior-only ones.

**Step 0:** Read the approval-friction finding in [the decision log](../docs/research/claude-config-audit-decisions.md). Two trigger classes are already documented — `Contains simple_expansion` and the `cd` with output redirection security rule — and neither is fixable by growing the allowlist. Do not restart the diagnosis; extend it.

**What:** Determine how to reduce approval prompts, using evidence from actual session history rather than guesses about what commands might be needed.

**Why:** Approval prompts are a daily irritant and a direct hit to the "joy to use" goal. The cause is now understood, but the remedy is not — it splits into a settings question that needs current research and an allowlist question that needs data.

**To implement:**
- Run `/research Claude Code sandbox and permission-mode settings, and whether any of them allow read-only bash commands containing shell expansion to run without prompting` — the current `~/.claude/settings.json` has `skipDangerousModePermissionPrompt` set but no sandbox or default-mode configuration. Include all output with sources.
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

**Step 0:** M1 must be complete — the clones must exist. Read M2's output on global-versus-project skill installation; Viktor's position cannot be fairly evaluated without it.

**What:** Summarize Viktor's role-based agent swarm — `.dot-agent-deck.toml`, the orchestrator / coder / reviewer / auditor / tester / release roles — and identify specifically where it solves a problem the current setup has no answer for.

**Why:** This is the largest structural difference between his workflow and Whitney's, and it overlaps directly with the parallel-work problem she named as the change most likely to affect how her day feels. The question is not "is his approach good" but "which specific gap does it fill here."

**To implement:**
- Read `.dot-agent-deck.toml` and the `.claude/` setup in the local clone. Do not go deep on his PRD skills — that is M5.
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

**What:** Diff Viktor's current PRD-related skills against this repo's `prd-*` and `issue-*` skills, and label every difference by adoption timeline.

**Why:** Whitney's PRD skills were originally derived from Viktor's, and both have evolved independently since. Some of what he has now will be directly portable; some will only make sense if she later adopts his swarm. Conflating those two timelines would either import machinery she cannot use or cause her to dismiss something she could use today.

**To implement:**
- Read his PRD-related skills in the local clone's `.claude/skills/`.
- Diff against this repo's `prd-create`, `prd-start`, `prd-next`, `prd-update-progress`, `prd-update-decisions`, `prd-done`, `prd-close`.
- For each difference, state: where the two have diverged, what is genuinely better in his, and what is genuinely better in hers. Do not default to his being better because it is newer to her.
- Label every candidate adoption as either **adopt now** (works standalone) or **adopt only with the swarm** (depends on his rule-based sub-agent system). These are different timelines and must not be mixed.
- Extend the same analysis to the six `issue-*` skills and to the eight `SKILL.v1-yolo.md` autonomous variants. **There are three parallel implementations of one lifecycle, not two** — see the decision log finding. Nothing enforces that a change to one family reaches the others, and that has already shipped a live bug: the `prd-done` three-channel CodeRabbit fetch never reached the YOLO variant, so autonomous mode misses findings today.
- Design the consolidation. Per decisions 16 and 17, the direction is settled: **collapse sixteen files to eight, autonomous-first**, with the interactive confirmation gates as the exception rather than the base. A second file requiring hand-mirroring has been tested for four months and produced a bug on each side; do not propose another variant-as-separate-file scheme.
- Generalize `prd-next`'s **Autonomous Decision Protocol** — its explicit proceed-when and stop-when lists — into every lifecycle skill as the standard escalation contract. This is the mechanism that makes reduced oversight safe, and it currently exists in one file out of sixteen. Design it once, informed by M4's findings on how Viktor's roles handle the same problem at swarm scale.
- Merge divergences on merit, not origin. Where the autonomous variant is better (acceptance-gate detection, read-only/mutating/external command classification, autonomous triage), keep it. Where the interactive variant is better (three-channel CodeRabbit fetch, whole-PRD Anki sourcing with dedupe), keep that. Enumerate every divergence across all eight pairs — do not assume the two already found are the only ones.
- Plan the migration. Nine repos symlink `.claude/skills/prd-*/SKILL.md` to `SKILL.v1-yolo.md` in this repo: `cluster-whisperer`, `kubecon-2026-gitops`, `spinybacked-orbweaver`, `spinybacked-orbweaver-eval`, `project-signal-boost`, `KubeHound-Demo`, `commit-story-v2`, `content-manager`, `scaling-on-satisfaction`. Deleting the YOLO files breaks all of them. The migration must be scripted and idempotent.

**Success criteria:**
- `docs/research/viktor-prd-skills-diff.md` exists, covering all eight `prd-*` skills, all six `issue-*` skills, and all eight `SKILL.v1-yolo.md` variants
- Every adoption candidate is labeled adopt-now or adopt-with-swarm
- A complete divergence table exists for all eight interactive/YOLO pairs, with a keep-which decision per divergence
- A consolidation design exists: eight autonomous-first files, with a generalized escalation contract, and a scripted idempotent migration for the nine affected repos
- Whitney has approved the consolidation design before any file is deleted
- Decisions logged

---

### M6: Michael workflow spike

**Model:** Opus 5 on the main thread. Delegate bulk file reading of the clones to Sonnet subagents.

**Step 0:** M1 must be complete. Read `docs/research/michael-forrester-workflow.md` and `docs/research/michael-autonomous-execution-principles.md` **as historical baselines only** — Whitney has confirmed his workflow has changed since they were written. Do not treat them as current.

**What:** Research Michael's current setup fresh, and update the two stale research documents to match.

**Why:** The existing research shaped PRD #84 and is now out of date. Leaving stale documents in `docs/research/` is worse than having none, because future work will read them and act on them. This milestone both produces new findings and repairs the record.

**To implement:**
- Re-pull `~/Documents/Repositories/forrester-workflow` and clone the additional repos gathered in M1.
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

### M7: Repo-native audit — hooks, skills, general cleanup

**Model:** Opus 5 on the main thread — remove / consolidate / repair / keep is judgment, and "is this rule still true" needs a model willing to say no. Delegate the raw inventory sweep to Sonnet subagents.

**Step 0:** Read M2's load inventory. This milestone covers what that inventory does not: hooks, scripts, and accumulated cruft.

**What:** Audit claude-config on its own terms and produce a list of things to remove, consolidate, or repair — findings that no comparison against another person's workflow would surface.

**Why:** The audit's centre of gravity naturally drifts toward "adopt what Viktor and Michael do." Whitney explicitly asked that repo-native findings get their own place, and named the hook collection as a likely source. There are currently 14 Claude Code hooks — 5 PreToolUse, 7 PostToolUse, 1 SessionStart, 1 PostCompact — plus native git hook dispatchers and an existing `hooks/archive/`. Seven PostToolUse hooks means substantial advisory output on ordinary tool calls; two fired on a single `gh issue create` during scoping.

**To implement:**
- Inventory every hook: what it enforces, whether it blocks or advises, whether it still fires, and whether its rule is still true. Identify hooks that duplicate each other or that duplicate a rule already stated in `CLAUDE.md`.
- Assess whether advisory PostToolUse hooks are earning their cost. An advisory hook that fires constantly and is usually already satisfied is noise that trains the reader to skim.
- Inventory the skills directory the same way — unused skills, skills superseded by others, skills that should be rules or hooks instead.
- Review `scripts/`, `templates/`, `profiles/`, `config/`, and `hooks/archive/` for dead material.
- Check whether `setup.sh` still reflects what the repo actually installs.
- Note the `/issue-create` gap found during scoping: the skill has no branch for bringing an already-created issue into compliance.
- Present findings as a categorized list — remove / consolidate / repair / keep — for Whitney to approve as a set.

**Success criteria:**
- `docs/research/claude-config-repo-audit.md` exists, containing a complete hook inventory with a remove / consolidate / repair / keep recommendation for each
- A skills inventory with the same treatment
- Dead material in `scripts/`, `templates/`, `profiles/`, `config/`, and `hooks/archive/` identified
- Whitney has approved the categorized list
- Decisions logged

---

### M8: Spec file written and signed off

**Model:** Opus 5. The highest-judgment milestone in the PRD — everything else exists to feed it.

**Step 0:** Read the full decision log and the output of M2 through M7. Every one of those milestones gates this one.

**What:** Write a spec file in this repo recording concrete decisions: what to keep building on, what to tear down and recreate, and whether any part warrants a separate system rather than a modification of this one.

**Why:** A conversational summary evaporates. The spec is the artifact that survives, and it is what the implementation PRDs are generated from. It has to be specific enough that a cold reader could act on it.

**To implement:**
- Before writing, ask Whitney the real open questions surfaced across M2–M7 — one at a time, per the Process section. Do not guess at her preferences to avoid asking.
- Structure the spec around decisions, not findings. Each entry states what was decided, what was rejected, and why.
- Record explicitly **what stays intact under every scenario** — the fallback path to the current way of working must be legible. Whitney has to be able to revert if the new approach does not pan out.
- Identify which implementation PRDs the spec should spawn and in what order. Do not create them in this milestone; recommend them and let Whitney decide the number and sequencing.
- Note that issue #108 is a blocking dependency for implementation work, and confirm its status before the spec proposes anything that depends on rule loading being fixed.
- Run `/write-prompt` on the spec before presenting it. The spec is a prompt — future agents will read it and act on it.

**Output format.** The spec is written to `docs/claude-config-redesign-spec.md` — `docs/`, not `docs/research/`, because it is a decision record rather than a research artifact. Required sections, in this order:

1. `## Verdict` — one paragraph. Which of three outcomes applies: keep building on the current system, tear down and recreate parts of it, or build a separate system alongside it. State it plainly in the first sentence.
2. `## Decisions` — a table with columns Decision / Rejected alternative / Rationale / Which PRD implements it. One row per decision. A decision with no rejected alternative recorded is incomplete; if nothing was seriously considered and discarded, say so explicitly rather than leaving the cell empty.
3. `## What stays intact` — the fallback path. For every proposed change, what remains working if that change is reverted, and what the revert procedure is. This section is not optional and cannot be deferred to an implementation PRD.
4. `## Proposed implementation PRDs` — numbered, ordered, each with a one-line scope and its dependencies. Recommendations only; Whitney decides the final set.
5. `## Open questions carried forward` — anything unresolved, and what would resolve it.

A spec that summarizes findings instead of recording decisions has failed this milestone, however well written. The test: every entry in `## Decisions` names something that will or will not be done, not something that was learned.

**Success criteria:**
- `docs/claude-config-redesign-spec.md` exists with all five required sections present and populated
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
- M5 depends on M4. M8 depends on M2 through M7. M9 depends on M8.

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
| 18 | This PRD was itself created using the pre-redesign process — the current `/prd-create`, `/issue-create`, and `/write-prompt` skills, with their current friction. | It serves as a baseline. Whatever the redesign produces should be measurably better to use than what produced this document. |

## Open Questions

Carried from the decision log. These are answered during the milestones, not before.

- Should `/issue-*` and `/prd-*` collapse into one lifecycle with two entry points, or stay two families? *(M5)*
- Which specific rules stay rules, which move to `CLAUDE.md` or hooks for durability, and which become on-demand skills? *(M2)*
- Global versus project-level skills — Viktor's position is "never global." Does that hold once #21858 is ruled out? *(M2, M4)*
- Is there a sandbox or permission-mode setting that eliminates the `simple_expansion` prompt class outright? *(M3)*
- How many implementation PRDs should the spec produce, and in what order? *(M8)*
- Which additional Michael repos should be cloned? *(M1)*
- Which git hooks can be removed or consolidated? *(M7)*
