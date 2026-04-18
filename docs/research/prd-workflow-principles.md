# PRD Workflow Principles

Extracted from the `/prd-*` skills in `.claude/skills/prd-*/`, related hooks, and supporting rules. This document captures the design intent of the current (human-gated) PRD workflow so it can inform a future autonomous-execution system that works end-to-end without human check-ins between milestones.

Sources read:
- `.claude/skills/prd-create/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/prd-start/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/prd-next/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/prd-update-progress/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/prd-update-decisions/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/prd-done/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/prd-close/SKILL.md` + `SKILL.v1-yolo.md`
- `.claude/skills/make-autonomous/SKILL.md`
- `.claude/skills/make-careful/SKILL.md`
- `.claude/skills/post-compact/SKILL.md`
- `.claude/skills/continue/SKILL.md`
- `.claude/CLAUDE.md` (project)
- `rules/prd-dependency-management.md`
- `rules/hooks-reference.md`
- `hooks/git/checks/progress-md.sh`
- `.claude/skills/verify/scripts/cascade-decision-check.sh`
- `scripts/auto-reanchor.sh`
- `scripts/prd-loop-continue.sh`
- `config/settings.json`

---

## 1. Division of Responsibilities

The skills partition PRD lifecycle work into seven narrow roles. Each skill explicitly refuses work that belongs to a neighbor — the boundaries are not accidental.

### `/prd-create` — Author the plan, never start work
Owns: GitHub issue creation (issue first, to obtain the ID that will name the PRD file), PRD file creation at `prds/[issue-id]-[feature-name].md`, milestone definition (5–10 meaningful milestones, not micro-tasks), `ROADMAP.md` update, and a `[skip ci]` commit directly to main if the user chooses "save for later."

Non-scope: does not create a feature branch, does not begin implementation. Explicitly hands off to `/prd-start [issue-id]` or exits after a skip-CI commit.

Deliberate choice: the issue is created *before* the PRD file because the issue ID is needed to name the file correctly. The skill calls this out as "CRITICAL" — an ordering constraint, not a preference.

### `/prd-start` — Set up the execution environment, then step aside
Owns: target PRD identification (argument → conversation context → branch heuristics → file globbing → user prompt as fallback), PRD readiness validation (requirements, success criteria, dependencies), feature branch creation (`feature/prd-[issue-id]-[feature-name]`), dependency install, and creating `PROGRESS.md` with contributor-aware gitignore behavior.

Non-scope: does **not** identify tasks, does **not** recommend implementation priorities, does **not** start work. The skill ends with a hard stop:

> `⚠️ STOP HERE - DO NOT: Identify or recommend tasks to work on / Analyze implementation priorities or critical paths / Start any implementation work / Continue beyond presenting the handoff message`
>
> `/prd-next handles all task identification and implementation guidance.`

The separation exists because task selection requires the same analytical work done by `/prd-next`; duplicating it here would cause drift.

### `/prd-next` — Pick one task, design it, then hand implementation to the user
Owns: detecting whether PRD context is already clear from conversation (skip detection if so); otherwise PRD auto-detection; gap analysis between docs and code; checkbox-state assessment (`[x]`/`[ ]`/`[~]`/`[!]`); dependency/value analysis; recommending a **single** highest-priority task; on confirmation, creating TaskCreate entries **for the current milestone only** (one task per unchecked checkbox, skip already-checked items); and design discussion for the recommended task.

Non-scope: does not implement (Step 8 is literally "user-driven — no LLM action required"), does not edit the PRD file, does not commit. On user-signalled completion, it exits with a one-line instruction to run `/prd-update-progress`:

> `**CRITICAL: Do NOT update the PRD yourself. Do NOT edit PRD files directly. Your job is to prompt the user to run the update command.**`

The "one task at a time" design is intentional — it keeps teams focused and the user in control of scope.

### `/prd-update-progress` — Atomic progress checkpoint
Owns: mapping conversation context (first) and git history (fallback) to PRD checkbox completions; the conservative completion policy ("only mark items complete with direct evidence"); comprehensive progress reporting; divergence flagging between plan and reality; the `PROGRESS.md` narrative entry (dated, feature-level, written for an external reader); **atomic commit of implementation + PRD + PROGRESS.md together** (`git add .` is mandatory, not selective); milestone-boundary CodeRabbit CLI review; and a decision-awareness check that prompts `/prd-update-decisions` when design pivots happened in-session.

Non-scope: does not push (the skill is explicit — "Do NOT push commits unless explicitly requested by the user"), does not create PRs, does not close PRDs.

The atomicity is load-bearing: code changes and the checkbox flips that describe them must land in one commit so git history is the canonical record. `git add .` is explicit — "DO NOT selectively add only PRD files."

### `/prd-update-decisions` — Write decisions down and cascade them
Owns: extracting design decisions from conversation; recording them in the PRD Decision Log with date, rationale, and impact; updating requirements / architecture / code examples to match; **propagating decisions to downstream incomplete milestones** so the milestone text itself (which future agents read as instructions) reflects the new reality.

Non-scope: does not commit (it produces edits that a later `/prd-update-progress` commits with the next code change), does not implement.

Key design insight captured in the skill:

> `decisions that sit only in the decision log become invisible to future implementing agents who read milestone descriptions as their working instructions.`

This is why propagation is mandatory, not optional. It implicitly treats milestones as prompts.

### `/prd-done` — Close out the implementation lifecycle with a PR
Owns: detecting whether the completion is documentation-only (commit-to-main-with-skip-ci) or a code implementation (full PR flow); pre-completion validation (every checkbox complete, docs updated, no blockers); moving the PRD file to `prds/done/`; updating `ROADMAP.md`; **Pre-PR verification via a sub-agent** that reads every milestone criterion and applies the three-level check (Exists → Substantive → Wired) with a per-criterion evidence table; PR template discovery, parsing, auto-fill, and label detection via `.github/release.yml`; `gh pr create`; invoking `/code-review`; the 7-minute CodeRabbit wait + the three-endpoint finding fetch; merge; issue closure; local/remote branch deletion; and Anki knowledge capture during the review wait.

Non-scope: does not flip PRD checkboxes (that is `/prd-update-progress`'s job from before completion), does not create new milestones.

### `/prd-close` — Terminate a PRD that will never be built here
Owns: closing a PRD that is satisfied externally, superseded, duplicate, or deferred. Updates status metadata, moves the file to `prds/done/`, prunes `ROADMAP.md`, reopens + rewrites + closes the GitHub issue with a comprehensive reason, and commits directly to main with `[skip ci]`.

Non-scope: does not create a PR (there is no code). Explicitly orthogonal to `/prd-done`:

> `DO NOT use /prd-close when: You just finished implementing the PRD (use /prd-done instead).`

---

---

## 1.5. Dual-Mode Skills: Careful and YOLO Variants

Every PRD skill ships in **two parallel files**: `SKILL.md` (careful, human-gated) and `SKILL.v1-yolo.md` (autonomous, self-driving). The active variant is swapped *structurally* via symlink — not chosen at runtime by the skill itself.

### The parallel files

`.claude/skills/prd-*/` contains two files for each of: `prd-create`, `prd-start`, `prd-next`, `prd-update-progress`, `prd-update-decisions`, `prd-done`, `prd-close`, and `prds-get`. The differences are concrete, not cosmetic:

- **Frontmatter `description:`** — Careful uses passive language ("Analyze existing PRD to identify and recommend…"). YOLO uses an *active trigger* ("INVOKE AUTOMATICALLY after `/prd-start` completes or after `/clear` on a PRD feature branch. Identifies and starts the next highest-priority PRD task without asking.") — so the harness can auto-invoke rather than waiting for the user to type the slash command.
- **Confirmation gates** — Careful has user-facing "Do you want to work on this task?" prompts. YOLO replaces them with an **Autonomous Decision Protocol**: a named list of "proceed without pausing" vs. "stop and surface" triggers. Pauses are reserved for genuine ambiguity (PRD deviation, architectural implications, multiple valid interpretations, wrong assumptions, scope creep), not for routine workflow transitions.
- **Hand-off style** — Careful skills end with "run `/prd-update-progress`." YOLO skills instead `Skill`-invoke the next step (e.g., `/prd-next` calls `/prd-update-progress` directly after implementation, and after the commit lands, it instructs the user to `/clear` and re-invoke).
- **Loop primitive** — YOLO `/prd-next` introduces a `/clear` → auto-resume loop that the careful variant doesn't have. After each milestone's work commits, `/clear` resets context and a SessionStart hook (`prd-loop-continue.sh`) re-injects orientation so the fresh instance re-invokes `/prd-next`.

### The mode-toggle skills

- **`/make-autonomous`** installs YOLO mode for a project: creates symlinks from `.claude/skills/prd-*/SKILL.md` → `$CLAUDE_CONFIG/.claude/skills/prd-*/SKILL.v1-yolo.md`, installs the `SessionStart[matcher=clear]` → `prd-loop-continue.sh` hook in `.claude/settings.local.json`, and adds a frictionless permission allowlist (git, gh, ls, Skill invocations, WebFetch/WebSearch).
- **`/make-careful`** reverses it: swaps symlinks to point at the careful `SKILL.md`, removes the SessionStart hook, removes the permission entries.

Both skills are idempotent and only touch `.claude/settings.local.json` (auto-gitignored, so mode is a per-clone local choice).

### Why this matters for autonomous design

- **Interactive confirmation gates are already a structural knob.** An autonomous PRD executor should not invent a new "skip confirmations" flag — it should build on top of the YOLO variants, which already encode the correct decision protocol (what is trivial vs. load-bearing). The boundary between "proceed" and "stop" is the same boundary the autonomous system must respect.
- **The `/clear` verification checkpoint** is a deliberate design choice: the fresh instance re-reads the PRD from scratch between milestones, so milestone transitions are validated by a clean read rather than trusted from conversation context. Any autonomous executor needs an equivalent — running the whole PRD in one context is both expensive and error-prone.
- **Mode is a repo-level setting, not a per-session flag.** Symlinks + local settings mean YOLO mode persists across sessions, restarts, and `/clear`. This is the right shape for an autonomous system: it should not have to re-arm itself each time.

---

## 2. State Model

State lives in five places. The model is deliberately distributed — each surface has a different audience and durability profile.

### PRD file (`prds/[issue-id]-[feature-name].md`) — canonical intent and structural progress
- **Milestone checkboxes** (`[ ]`, `[x]`, `[~]`, `[!]`) — the only authoritative record of "what is done." Machine-readable; hooks grep them.
- **Decision Log table** — rationale + date + impact, durable. Rows are additive; the cascade hook watches for new ones.
- **Implementation approach, requirements, success criteria, code examples, risks** — all live in the PRD and are updated in place as decisions land.
- **Status field** (`In Progress`, `Complete`) — used by `auto-reanchor.sh` and `/continue` to find the active PRD via grep.

The PRD is the instruction set for future AI implementors. Milestone text is read as a prompt — which is why `/prd-create` runs `/write-prompt` over it before commit, and why `/prd-update-decisions` cascades updates into downstream milestone descriptions.

### `PROGRESS.md` (repo root) — narrative, human-facing, dated feature log
- Created lazily by `/prd-start` if absent.
- `.gitignore` behavior is contributor-count-aware: multi-contributor repos hide it to avoid merge conflicts; solo repos track it publicly.
- Written in Keep-a-Changelog-ish format under `## [Unreleased]` with `### Added` / `### Changed` / `### Fixed`.
- Entries are dated (`(YYYY-MM-DD)`), feature-level, no PRD/milestone references — the skill explicitly says "write for an external reader... skip internal references like PRD numbers, milestone codes, and task IDs — these are meaningless outside the project."
- Staged and committed atomically with the code + PRD diff in the same `/prd-update-progress` commit.

### TaskCreate entries — current milestone's active work
- Created by `/prd-next` on user confirmation, **only for the current milestone**, one-to-one with unchecked checkboxes.
- Recycled when a milestone completes: old tasks marked `completed` or `deleted`, a fresh set created for the next milestone.
- Surface: ephemeral — they drive in-session orientation and `/continue` checks them, but they are not durable state across sessions beyond what TaskGet surfaces.

### Git commits and branches — the durable execution record
- One feature branch per PRD (`feature/prd-[issue-id]-[feature-name]`).
- Commits reference the PRD (`feat(prd-X): …`).
- Each commit is atomic: implementation + PRD checkbox flips + `PROGRESS.md` entry, together. This is the commit-level truth that hooks, `/continue`, and `auto-reanchor.sh` rely on.
- Push is gated (hook-enforced CodeRabbit pre-push review), but commit is not.
- Branch delete happens at `/prd-done` step 6.

### GitHub issue — the public-facing anchor and the PRD's ID source
- Short, stable body; links to the PRD file.
- Labelled `PRD` for discoverability.
- Reopened briefly by `/prd-close` to update its description, then closed again.
- Closed with a detailed completion comment by `/prd-done` or `/prd-close`.

### Interaction patterns between surfaces
- **Checkbox flip → PROGRESS.md entry → commit** is mandatory and atomic, enforced by `progress-md.sh` pre-commit hook.
- **New decision → PRD Decision Log row → downstream milestone updates** is prompted by `cascade-decision-check.sh` (advisory) and `/prd-update-decisions` (enforcing).
- **PRD status = "In Progress"** is the discovery key for re-anchoring skills.
- **PRD file location** (`prds/` vs `prds/done/`) signals lifecycle state and is load-bearing for the cascade-decision hook (fires on active PRDs only).

---

---

## 2.5. Milestone Text Is a Prompt (Named Principle)

Milestone text is not documentation. It is the runnable instruction set that a future implementing agent (possibly a fresh post-`/clear` instance) reads word-for-word as its task brief. This principle is enforced structurally in multiple places:

### Structural enforcement

1. **`/prd-create` runs `/write-prompt` over milestones before commit.** Step 7 of prd-create is literally titled "Prompt Quality Review" and says: *"Run `/write-prompt` on the milestones section as AI agent instructions — milestone text is executed by a future AI implementor, making it a de-facto prompt. Apply all suggested improvements before committing. Do not skip this step."* The careful and YOLO variants both contain this step.

2. **`/prd-update-decisions` cascades decisions into downstream milestone text.** Not into a "decisions appendix" — into the milestone descriptions themselves. The skill's own wording: *"decisions that sit only in the decision log become invisible to future implementing agents who read milestone descriptions as their working instructions."*

3. **`cascade-decision-check.sh` scans *all open PRDs*, not just the current one.** When any `prds/*.md` is edited, the hook fires and emits a prompt asking Claude to: *"(1) review all remaining milestones in this PRD for impact and update any affected by the new decision; (2) scan other open PRDs in `prds/` by reading their titles and summaries — if relevant, open them and update affected milestones."* Cross-PRD propagation is baked in; a decision that affects another PRD's milestone is expected to be propagated during the session it was recorded in.

4. **Milestone items can reference Decision Log rows inline** (e.g., `"Implement X (Decision 16)"`) so future AI has explicit backpointers to rationale without having to reconstruct it.

### Why this is the single most important quality input for autonomous runs

An autonomous PRD executor will not be able to ask "what did you mean by this?" — the milestone text is what it acts on. Every ambiguity in the milestone becomes either (a) a pause-and-surface event (interrupting autonomy), (b) a wrong-direction implementation (wasting tokens and rework), or (c) a silent divergence where the code ships but doesn't match intent. The `/write-prompt` review at authoring time and the decision-cascade at update time are the only mechanisms that keep the milestone text synchronized with what the implementer should actually do.

### Design implications for an autonomous system

- Treat the PRD file as the canonical prompt. Any autonomous implementer must re-read it from disk at every milestone boundary (the `/clear` loop exists for exactly this reason — see §1.5).
- The quality of an autonomous run is bounded above by the quality of the milestone text. Investment in authoring (the 10-question design conversation in `/prd-create`, the `/write-prompt` review, the decision-cascade machinery) is not overhead — it is the compiler step.
- Cross-PRD decision propagation is required for correctness. An autonomous system that completes a milestone in PRD-A and triggers a decision in its log must check PRD-B, PRD-C, etc. before proceeding. `cascade-decision-check.sh` is advisory today; in autonomous mode, it likely needs to be enforcing.

---

## 3. Workflow / Skill Chain

Typical PRD from conception to merge:

```text
/prd-create   (manual invocation by user)
    └── creates issue → creates prds/[id]-[name].md → [skip ci] commit to main
    │    OR hands off with "run /prd-start [id]"
    ▼
/prd-start [id]   (manual, often immediately after prd-create option 1)
    └── validates readiness → creates feature branch → creates PROGRESS.md
    │    hands off with "run /prd-next"
    ▼
/prd-next   (manual; re-entered after every milestone boundary)
    └── picks ONE task → creates TaskCreate entries for current milestone
    │    → design discussion → USER IMPLEMENTS
    │    hands off with "run /prd-update-progress"
    ▼
/prd-update-progress   (manual, after implementation is done)
    └── maps changes to PRD checkboxes → updates PROGRESS.md
    │    → atomic commit (code + PRD + PROGRESS.md)
    │    → CodeRabbit CLI review locally
    │    → decision-awareness check (may prompt /prd-update-decisions)
    │    hands off with "run /prd-next" OR "run /prd-done" if 100%
    ▼
(loop: /prd-next ↔ /prd-update-progress per milestone,
 with /prd-update-decisions inserted when design pivots happen)
    ▼
/prd-done   (manual, only when 100% checkboxes complete)
    └── pre-PR sub-agent verification (3-level check per criterion)
    │    → push → gh pr create → /code-review (in-session)
    │    → 7-min CodeRabbit wait → review all three endpoints
    │    → fix findings → re-review → merge → delete branch → close issue
```

Ancillary / recovery skills:

- **`/post-compact`** — fires automatically via the `PostCompact` hook (`auto-reanchor.sh`) and can also be invoked manually. Mid-session orientation only; does **not** assess tasks or start work.
- **`/continue`** — manual at session start; reads the full layered state (PRD + PROGRESS.md + git + tasks + journal) and suggests a next step, but waits for user confirmation before acting.
- **`/prd-close`** — orthogonal terminal path; used when a PRD will never be built in this repo.

Every hand-off is an explicit instruction to the user to invoke the next skill in careful mode. YOLO mode replaces these with direct Skill-tool invocations plus the `/clear` loop primitive (see §1.5).

### TaskCreate Cleanup-and-Recreate Is a Required State Machine

TaskCreate entries are not a bookkeeping nicety — they are a required, cyclic control-flow element tied to milestone boundaries:

1. `/prd-next` identifies the current milestone (the one containing the recommended task).
2. `/prd-next` creates TaskCreate entries **only for that milestone**, one-to-one with unchecked `[ ]` items. Already-`[x]` items are skipped.
3. The user (or YOLO loop) implements.
4. `/prd-update-progress` commits, which flips checkboxes `[ ]` → `[x]`.
5. On the next `/prd-next` invocation (usually after `/clear` in YOLO mode), the skill detects the milestone boundary and explicitly **marks prior-milestone tasks `completed` or `deleted`, then creates a fresh set for the new milestone**. The YOLO skill's Step 4 spells this out: *"When a new milestone starts, mark prior milestone tasks as `completed` or `deleted`, then create fresh tasks."*

**Why this matters for autonomous design.** An autonomous executor that doesn't implement this cleanup will accumulate stale tasks from completed milestones. The task list becomes polluted, `/continue` starts surfacing "in progress" tasks that are actually finished (their checkbox is already `[x]` on disk), and any prioritizer looking at TaskList for "what's next" gets noise. The state machine is:

```text
        ┌────────────────────────────────────┐
        ▼                                    │
  [Milestone N  ──► TaskCreate entries  ──► Implement ──► /prd-update-progress]
        │                                    │               (flips [ ] → [x])
        │                                    │
        └────────────────────────────────────┘
                            │
                            ▼
          On next /prd-next: old tasks → completed/deleted,
          new tasks created for Milestone N+1
```

The cycle is tight and invariant: **one milestone = one TaskCreate cohort**. Cross-milestone tasks are not allowed. An autonomous system must either implement this same cleanup-and-recreate pattern or abandon TaskCreate entirely as an execution queue.

---

## 4. Assumptions About User Presence

The workflow assumes the user is at the keyboard at virtually every phase transition. The skills are designed with interaction gates:

| Skill | User-presence assumption | Irreversible actions |
|---|---|---|
| `/prd-create` | Highly interactive — 10-question planning conversation, section-by-section review, final option prompt ("1 or 2") | Creates GitHub issue; commits PRD to main with `[skip ci]` |
| `/prd-start` | Interactive for PRD detection fallback; otherwise low interaction | Creates feature branch; creates `PROGRESS.md`; may edit `.gitignore` |
| `/prd-next` | Critical user confirmation gate: "Do you want to work on this task?"; then design discussion; then "user implements the task" is an explicit pause | Creates TaskCreate entries (reversible) |
| `/prd-update-progress` | User confirmation on proposed checkbox completions; CodeRabbit finding triage | **Commits** (locally — not pushed unless asked) |
| `/prd-update-decisions` | Interactive decision extraction and confirmation | Edits PRD file (no commit — rides with next `/prd-update-progress`) |
| `/prd-done` | Many user gates: pre-PR verification report review, PR info confirmation ("yes/confirm"), template requirements "Should I execute these now?", CodeRabbit triage, final merge decision | Pushes to remote; creates PR; merges PR; closes issue; deletes branches |
| `/prd-close` | User confirmation of closure reason | Commits to main; closes issue |

**Claude Code's project-level CLAUDE.md enables YOLO mode for this repo** — it explicitly instructs Claude to "proceed without trivial confirmations" and to "follow your own recommendation" on CodeRabbit feedback. But YOLO mode is a conversational convention, not a structural change; the skill text itself still contains explicit confirmation prompts.

**What is already nearly autonomy-safe**:
- `/prd-start` (deterministic after a PRD argument is given)
- `/prd-update-progress` (analysis + commit, with context-first recovery; only interactive where it needs to confirm checkbox completions and handle CodeRabbit triage)
- `/prd-close` (deterministic once reason is supplied)

**What currently demands interaction most insistently**:
- `/prd-create` (the 10-question design conversation is the whole point of the skill)
- `/prd-next`'s single-task recommendation gate ("Do you want to work on this task?")
- `/prd-done`'s pre-PR verification review and the "confirm" gate before PR creation
- CodeRabbit finding triage anywhere it appears

**What is irreversible and must remain gated even in autonomous mode**:
- PR merge (`gh pr merge`)
- `git push --force` / reset --hard (already gated via `ask` in settings.json)
- Issue closure with a comprehensive comment (low-cost to reopen, but public-facing)

---

## 5. Compaction Resilience Today

State survives compaction if it lives outside the conversation. State that lives only in-conversation is lost.

**Survives compaction (durable):**
- PRD file contents, including checkboxes and Decision Log
- `PROGRESS.md` entries
- Git commits and branch state
- GitHub issue state
- TaskCreate entries (fetched via TaskList after compaction)

**Lost on compaction:**
- The reasoning thread of the current milestone (why we chose this approach, what we tried and rejected)
- Uncommitted in-flight design decisions not yet in the Decision Log
- Conversation-only task triage or CodeRabbit finding discussion
- Which specific task within the current milestone is `in_progress` (preserved in TaskCreate, but the *context around why* is not)

**Recovery mechanisms currently in place:**

1. **`PostCompact` hook → `auto-reanchor.sh`** fires automatically after `/compact`. It greps `prds/` for "Status.*In Progress", reads the first `[ ]` milestone, reports branch + recent commits + dirty files, and instructs: "Re-read CLAUDE.md and the active PRD now to restore full context."

2. **`/post-compact` skill** is the manual counterpart — same goal, same sources, slightly richer (reads `_execution-state.md` from the plan-execute skill if present). Explicit constraint: "Do NOT start implementing work during this skill. Orientation only."

3. **`/continue` skill** is the heavier session-start recovery — reads PROGRESS.md narrative, TaskList, and layered journal context (today's raw entries, yesterday's daily summary, most recent weekly and monthly summaries). Asks for user confirmation before resuming.

4. **Atomic commits** are the key architectural resilience mechanism. Because every `/prd-update-progress` commits code + PRD + PROGRESS.md together, `git log` is a sufficient reconstruction surface: the state on disk after the last commit is consistent, and the PROGRESS.md narrative + PRD checkbox flips are self-describing.

The design philosophy is: **conversation is ephemeral, commits are truth**. Anything the workflow depends on must be written to disk before the next compaction risk.

### Mid-milestone compaction is the unsolved problem

The slogan "commits are truth" undersells the weakness. Commits happen *only at milestone boundaries* (that's the whole point of atomicity — see §6). For a non-trivial milestone that takes many turns to implement, **the entire reasoning thread between milestone start and milestone-end commit is one-shot and unrecoverable**:

- **What got lost** is not "what we decided" (the Decision Log captures that) and not "what we did" (git diff captures that). It is specifically *the path we took and the alternatives we rejected* — the rationale for why the code ended up the way it did when the milestone text did not prescribe a single path.
- **When implementation reasonably diverges from the milestone description** (unforeseen complexity, an assumption that turns out to be wrong, a refactor the milestone didn't anticipate), the rationale for the divergence lives only in the conversation. If compaction fires before the commit, the next instance sees code that doesn't match the milestone and has no context for why.
- **The Decision Log captures *crystallized* decisions**, not in-flight ones. By design: `/prd-update-decisions` is invoked at milestone boundaries alongside `/prd-update-progress`, not mid-implementation. This is intentional (it prevents decision-log churn on exploratory moves), but it means compaction mid-milestone wipes the exploration.
- **`_execution-state.md`** (from the plan-execute skill) is the closest existing primitive but is not standardized across the PRD workflow — `auto-reanchor.sh` only mentions it as an optional bonus.

### Design implications for an autonomous system

An autonomous executor that spends many turns on a single milestone (realistic for any non-trivial work) will cross compaction boundaries mid-milestone. It needs **at least one** of:

1. **Finer-grained durable commits** (breaking atomicity — see §6 for why that's expensive).
2. **A standardized mid-milestone scratch file** (e.g., `.prd-scratch.md` or a structured section in PROGRESS.md under `[In Progress]`) that gets written to disk on every meaningful turn and cleaned up at milestone completion. This is additive and doesn't break the atomicity invariant.
3. **Structured in-milestone journaling** via the `post_compact` boundary — i.e., before allowing compaction, flush the reasoning trail to disk as structured notes tied to the active milestone, so the post-compact re-anchor can rehydrate it.

The new PRD should pick one deliberately. Doing nothing guarantees that long milestones will silently lose context at compaction boundaries.

---

## 6. Commit Ownership and Atomicity

**Only `/prd-update-progress` commits on the feature branch during implementation.** This is load-bearing. `/prd-create` and `/prd-close` also commit, but they commit *directly to main* with `[skip ci]` for docs-only changes (PRD file creation and PRD file archival, respectively) — they do not touch the feature branch or implementation code.

The skill is blunt:

> `# MANDATORY: Stage ALL files - implementation work AND PRD updates together`
> `# DO NOT selectively add only PRD files - commit everything as one atomic unit`
> `git add .`

The commit includes, in one SHA:
1. Implementation changes (source, tests, config)
2. PRD checkbox flips (`[ ]` → `[x]`)
3. `PROGRESS.md` narrative entry (dated, feature-level)
4. Any in-session PRD updates from `/prd-update-decisions` (the decision updates don't commit independently; they ride with the next implementation commit)

**Why atomicity matters:**

- The pre-commit hook `progress-md.sh` enforces it: if staged PRD diffs show new `[x]` checkboxes but `PROGRESS.md` is not staged, the commit is blocked with an explicit error. Behavior is gated on `PROGRESS.md` existing at the repo root.
- Git history becomes the canonical reconstruction surface. A single SHA tells you exactly what was implemented, which milestone item it satisfied, and what the narrative summary is.
- Future AI implementors reading history can trust that checked boxes correspond to shipped code.
- The `auto-reanchor.sh` hook can report "last completed milestone" reliably because the commit that flipped the checkbox also shipped the code.

**Commits that are *not* from `/prd-update-progress`:**
- `/prd-create` — `[skip ci]` commit to main with the new PRD file only (no code yet).
- `/prd-done` — the final merge commit (which is a PR merge, not a fresh commit).
- `/prd-close` — `[skip ci]` commit to main with the archived PRD + updated issue link.

**CLAUDE.md explicitly forbids manual commits during PRD work:**

> `**Do NOT commit manually during PRD work.** /prd-update-progress handles commits, PRD updates, and journaling together.`

This is stated as a global rule, not a skill-local one — the commit ownership is meant to be invariant across all PRD-related sessions.

**Pushing is separate from committing.** `/prd-update-progress` explicitly does not push ("commits preserve local progress checkpoints without affecting remote branches"). The user decides when to push; `/prd-done` is the first skill that pushes, and the push triggers the CodeRabbit CLI pre-push review.

**Commit message convention:** `feat(prd-X): implement [brief description]` with a body that lists achievements, flags "Updated PRD checkboxes for completed items," and gives a `Progress: X% complete` line. The `prd-X` prefix is the traceability anchor.

### The atomic-commit invariant depends on a specific recovery mechanism

`auto-reanchor.sh` operationalizes atomicity as a recovery primitive. The script literally greps the active PRD for `^- \[ \]` (the first unchecked checkbox) and reports it as the "next milestone" — implicit in this is the assumption that everything above it is already `[x]`, that every `[x]` corresponds to a commit on the current branch, and that *the most recent commit* represents the current ground state. Any autonomous system that breaks this assumption (e.g., commits code without flipping a checkbox, or flips a checkbox without landing the code in the same SHA) silently breaks re-anchoring. The `progress-md.sh` pre-commit hook is the structural enforcement that prevents the second failure mode; there is no hook preventing the first, so discipline relies on commit ownership being centralized in `/prd-update-progress`.

### Granularity tradeoff — a design constraint for the autonomous PRD

The atomic-commit rule encodes a tight coupling: **one commit = one (or more) milestone checkbox flips + the code that satisfies them + the PROGRESS.md narrative**. This is wonderful for recovery (the last `[x]` is provably reconstructable from `git log`) and brutal for checkpoint granularity. Specifically:

- An autonomous executor that wants **finer-grained checkpoints** (e.g., a per-subtask commit to survive mid-milestone compaction, per §5) has two bad options:
  - **Commit per subtask without checkbox flips** — this violates the invariant `progress-md.sh` enforces. Not technically blocked by the hook (the hook only blocks commits that flip checkboxes *without* updating PROGRESS.md, not commits that don't flip checkboxes at all), but it breaks the re-anchoring assumption that "last commit = current ground state with respect to the PRD."
  - **Commit per subtask *with* a micro-checkbox flip** — this requires decomposing milestones into checkable subtasks, which fights against the "5–10 meaningful milestones, not micro-tasks" principle in `/prd-create` and would force milestone rewrites mid-execution.

- The right fix is a third path the current system does not implement: **an orthogonal scratch/checkpoint mechanism that is not tied to milestone checkboxes**. Options include per-subtask WIP commits on a disposable shadow branch, or a mid-milestone `.prd-scratch.md` that is durable but not committed. The autonomous PRD should choose one deliberately, knowing it will have to reconcile with the atomic-commit invariant on the feature branch.

**This is the single most important design constraint the new PRD must address**: either preserve atomicity and solve mid-milestone durability some other way, or break atomicity explicitly and update the recovery mechanism (`auto-reanchor.sh`, `/continue`, `/post-compact`) to match. Doing nothing means the new system will either lose context at compaction (§5) or silently break recovery (§6).

---

## 7. Hooks That Touch the PRD Workflow

Five hooks participate, each with a deliberate severity choice (exit 2 = block; exit 0 with additionalContext = advise).

### `progress-md.sh` (native git pre-commit — BLOCKING)
Fires on every commit. If `PROGRESS.md` exists at the repo root, scans staged PRD diffs for new `[x]` lines. If any are present and `PROGRESS.md` is not also staged, blocks the commit with:

> `PRD checkboxes were marked complete but PROGRESS.md was not updated.`

This is the structural enforcement of the checkbox ↔ narrative ↔ commit atomicity described in §6. It is a hard gate; the user would have to `--no-verify` to bypass.

### `branch-protection.sh` (native git pre-commit — BLOCKING)
Prevents commits on `main`/`master` unless they are docs-only. `/prd-create`, `/prd-close`, and the docs-only branch of `/prd-done` all rely on the docs-only exemption to commit PRD files directly to main.

### `commit-message.sh` (native git commit-msg — BLOCKING)
Rejects commits that mention Claude/AI/Anthropic/`Co-Authored-By`. Shapes what `/prd-update-progress` and `/prd-done` can write in commit messages — "Write commit messages as if authored by a human developer."

### `cascade-decision-check.sh` (Claude Code PostToolUse — ADVISORY)
Fires on `Write|Edit` to active PRD files (`prds/*.md` but not `prds/done/*.md`). Emits a message instructing Claude to:

> `check whether a row was added to the "## Decision Log" table. If yes, cascade-evaluate: (1) review all remaining milestones in this PRD for impact and update any affected by the new decision; (2) scan other open PRDs in prds/ by reading their titles and summaries — if relevant, open them and update affected milestones.`

Advisory because the check cannot reliably detect whether a decision row was added — it defers the judgment to Claude on every PRD edit. Pairs with `/prd-update-decisions`' explicit propagation step; the hook is a backstop.

### `auto-reanchor.sh` (Claude Code PostCompact — ADVISORY)
Fires after compaction. Detects the active PRD via grep of "Status.*In Progress", extracts the first unchecked milestone, and emits:

> `Active PRD: <name> | Next milestone: <text>`
> `ACTION: Re-read CLAUDE.md and the active PRD now to restore full context.`

This is the automated half of the compaction-resilience story; `/post-compact` is the manual half.

### Push/PR-level hooks that indirectly gate PRD work
- **`pre-push-verify.sh`** gates push on security verification; escalates to "expanded security + tests" when an open PR exists; runs advisory CodeRabbit CLI after.
- **`pre-pr-hook.sh`** (PreToolUse on Bash) gates PR creation on security + tests verification and runs advisory acceptance gate tests when configured. Results require human approval before PR creation continues.
- **`check-coderabbit-required.sh`** (PreToolUse on Bash) blocks PR merge without CodeRabbit review.

These are orchestrated by `/prd-done` but affect any PR flow.

### Severity summary — hard gates vs. soft reminders

For an autonomous system, the distinction between blocking and advisory is crucial — a hard gate will halt the run; an advisory reminder will appear in `additionalContext` and can be observed or ignored. Map:

| Hook | Event | Severity | Autonomous implication |
|---|---|---|---|
| `progress-md.sh` | git pre-commit | **Blocking** (exit 1) | Hard gate. An autonomous commit attempt that flips checkboxes without staging PROGRESS.md will fail. Must stage atomically. |
| `branch-protection.sh` | git pre-commit | **Blocking** (exit 1) | Hard gate on main/master (except docs-only). Feature branch work is unaffected. |
| `commit-message.sh` | git commit-msg | **Blocking** (exit 1) | Hard gate on AI/Claude/Co-Authored-By references. Autonomous commit messages must be written in human-authored voice. |
| `check-aboutme.sh` | Claude PreToolUse Write/Edit | **Blocking** (exit 2) | Hard gate on missing ABOUTME headers for code files. |
| `check-coderabbit-required.sh` | Claude PreToolUse Bash (`gh pr merge`) | **Blocking** (exit 2) | Hard gate — autonomous merge is not allowed without a CodeRabbit review on the PR. |
| `pre-pr-hook.sh` | Claude PreToolUse Bash (`gh pr create`) | **Blocking on verification fail** | Security + tests must pass; acceptance gate tests are advisory but *require human approval to continue* — a true autonomy break. |
| `pre-push-verify.sh` | git pre-push | **Blocking on verification fail** | Security verification is a hard gate; the embedded CodeRabbit CLI review is advisory. |
| `auto-reanchor.sh` | Claude PostCompact | **Advisory** (exit 0 + additionalContext) | Soft reminder. Provides orientation; no execution gate. |
| `cascade-decision-check.sh` | Claude PostToolUse Write/Edit | **Advisory** (exit 0 + additionalContext) | Soft reminder. In YOLO mode, compliance is non-deterministic — the hook cannot enforce cascading. |
| `suggest-write-prompt.sh` | Claude PostToolUse Write/Edit, Bash | **Advisory** | Soft reminder after SKILL.md/CLAUDE.md edits or `gh issue create`. |
| `post-write-codeblock-check.sh` | Claude PostToolUse Write/Edit | **Advisory** | Soft reminder about bare code blocks in markdown. |
| `test-tiers.sh` | git pre-push | **Advisory (warn only)** | Does not block even when unit/integration/e2e tiers are missing. |

Pattern: `exit 2` (Claude Code) or `exit 1` (git) = block. `exit 0` with `additionalContext` = advise. The project's hook-authoring convention (from `.claude/CLAUDE.md`) is: *"Use exit 2 (blocking deny) only for zero-tolerance rules that must never be violated. Use exit 0 with advisory `additionalContext` for style and quality guidance where violations are informational, not blocking."*

### CodeRabbit triage has different stakes at different stages

There are **two** CodeRabbit checkpoints in the PRD workflow, and conflating them is a design error:

1. **Local pre-commit CodeRabbit CLI review inside `/prd-update-progress` Step 8.5** — runs `coderabbit review --plain --type committed --base origin/main` locally against the feature branch. This is *milestone-boundary triage*: findings can be fixed immediately, skipped with rationale, or deferred to a GitHub issue via the standard rubric (Fix / Defer / Skip). No one else has seen these findings yet. The cost of skipping is low; the cost of fixing is low. Autonomous mode can apply the rubric itself.

2. **Post-PR CodeRabbit GitHub review in `/prd-done` (and enforced by `check-coderabbit-required.sh`)** — blocks merge. Findings are public-facing on the PR. The same Fix/Defer/Skip rubric applies in wording, but the **stakes are asymmetric**: *"Every PR must go through CodeRabbit review before merge. This is a hard requirement, not optional."* (project CLAUDE.md). Autonomous mode should default to "fix" for all non-trivial findings and must respect the blocking-merge gate even when other gates are relaxed.

For an autonomous system, this means CodeRabbit triage is not a single behavior — it is a **stage-dependent policy**. Local triage (stage 1) can be aggressive and fast; PR triage (stage 2) is conservative and human-approved in spirit even when run by an agent.

---

## 8. Surprises and Tensions

Things that stood out while extracting:

**Tension — "YOLO mode" vs skill-internal gates (resolved structurally).** Project CLAUDE.md instructs Claude to proceed without trivial confirmations, but the *careful* skill texts contain explicit "Do you want to work on this task?" and "Proceed with closure? (yes/no)" prompts. The resolution is structural rather than conversational: the careful and YOLO variants are separate files (§1.5), and `/make-autonomous` / `/make-careful` toggle which is active. An autonomous executor should not re-solve this via conversational override; it should ensure YOLO variants are installed via `/make-autonomous`. The open design question shifts: **should autonomous-mode execution invoke careful SKILL.md variants at all, ever?** (E.g., fall back to careful for `/prd-create` authoring conversations.) The two files are currently isomorphic in process but differ on pause triggers — the YOLO Autonomous Decision Protocol is the spec for where pauses remain load-bearing.

**Tension — `/prd-next` creates TaskCreate entries but doesn't use them itself.** The skill creates tasks at step 6b, then immediately hands off to the user for implementation at step 8. The tasks exist primarily for `/continue` and for the next `/prd-next` invocation to recognize the milestone boundary. An autonomous system may either ignore TaskCreate entirely or use them as the primary execution queue.

**Tension — the conservative completion policy is at odds with autonomy.** `/prd-update-progress` says "DO NOT mark complete unless there is direct evidence" and relies on conservative interpretation backed by user confirmation. An autonomous system can't defer to a user; it must make those calls itself, or it must commit eagerly and expect the acceptance phase to catch gaps. `/prd-done`'s three-level-verification sub-agent (Exists → Substantive → Wired) may be the right primitive to lift into per-milestone verification.

**Atomic-commit-or-bust is the core invariant.** Almost every design decision — the progress-md hook, the "never manually commit" rule, the "`git add .` is mandatory" wording, the reliance on git log for recovery — reinforces the same idea: every checkbox flip ships code in the same SHA. An autonomous system that commits more granularly (e.g., per sub-task) would break re-anchoring logic that assumes "last `[x]` = last commit = current ground state."

**The PRD file is explicitly treated as a prompt.** Multiple skills call this out:
- `/prd-create` runs `/write-prompt` over the milestones section before commit.
- `/prd-update-decisions` cascades decisions into milestone text because "milestone descriptions [are read] as their working instructions."
- Milestone items can be written with references like `"Implement X (Decision 16)"` so future AI has full context.

For an autonomous system, this is the critical signal: milestone text is not documentation, it is runnable instructions. Milestone quality determines autonomous-run quality.

**The hand-off-with-instruction pattern may be autonomy's enemy.** Every skill ends with something like "run `/prd-next`" or "run `/prd-update-progress`." These are bridges specifically for human-in-the-loop sessions. An autonomous system needs a different chaining primitive — perhaps a "PRD runner" that holds the outer loop state and invokes skills internally without surfacing the "run X next" prompts.

**The single-task gate in `/prd-next` conflicts with milestone-scoped task creation.** The skill recommends *one* task, but step 6b creates TaskCreate entries for *every* unchecked item in the current milestone. The gate is about "are you ready to start working?" not about the scope of the task list. For autonomy, the gate disappears but the milestone-scoped task list is still useful as a milestone-execution queue.

**`/prd-done`'s pre-PR verification is aspirational, not automated.** The three-level check (Exists → Substantive → Wired) with a per-criterion evidence table is a **prompt template** embedded in the skill text — a block-quoted instruction telling Claude to "Launch verification agent with the following task." There is no structural mechanism today that guarantees a sub-agent is actually launched, that its output is actually a criterion-by-criterion table, or that gaps actually block PR creation. In YOLO mode, compliance is a best-effort behavior of the active instance. An autonomous PRD executor that wants this verification to be real — especially as a per-milestone gate, not just a per-PRD one — must **implement it as an explicit sub-agent invocation with a structured output contract** (JSON schema, parseable pass/fail, evidence-table validation), not rely on prompt-embedded block quotes. Lifting the three-level check earlier into the per-milestone loop is the right direction; doing so requires turning the template into a mechanism.

**Cross-PRD dependency management assumes pause-and-resume.** `rules/prd-dependency-management.md` says when a hard blocker is discovered, "pause work on the blocked PRD at its current committed state... finish and merge the upstream PRD first... resume the blocked PRD." An autonomous system that runs PRDs end-to-end would need to detect the blocker early (ideally at design time, the rule's first recommendation) because mid-run pause-and-switch requires human judgment about priority.

**Compaction resilience is good for orientation, weak for in-milestone reasoning.** Everything after the last commit is at risk. An autonomous system that spends many turns on one milestone needs a durable scratch — either more frequent commits (breaking atomicity), an in-progress scratch file that gets cleaned up at milestone completion, or a structured in-milestone journal.
