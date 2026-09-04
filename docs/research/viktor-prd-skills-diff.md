# Skill families diffed: a three-way comparison

Written 2026-09-03. This document is the evidence product of Milestone B4 of PRD #109. It compares this repo's PRD-lifecycle and issue-lifecycle skills against the upstream repo they were forked from, deep-reads the upstream skills that have no counterpart here, and records the migration's starting conditions.

**It decides nothing.** Milestone C1 decides. Where this document says one variant is stronger than another, that is an assessment offered to C1, not a verdict. Where it labels an upstream skill adopt-now or adopt-with-swarm, that is a timeline label, not a recommendation to adopt.

## Provenance

Every claim below was measured against these exact states, pulled at read time per the PRD's refresh rule.

| Repo | Commit read | Date | Role |
|---|---|---|---|
| `research/repos/dot-ai` | `ac67ff1ca8ab9f286e44c1863efd2598e8be7a39` | 2026-09-02 | Holds both the ancestor (in history) and his current PRD skills (in tree) |
| `research/repos/dot-agent-deck` | `01537583b4c1ef9c389dd0f4d1e31bb3f762b891` | 2026-09-03 | Holds the six-plus-one skills with no counterpart here, and the swarm roles |
| this repo | `feature/prd-109-claude-config-audit-redesign` | 2026-09-03 | Hers |

**Both clones were meaningfully stale when this milestone began** — `dot-ai` by 8 commits, `dot-agent-deck` by 82. The refresh changed what this milestone had to cover. Three consequences, all recorded below in place: Decision 76's shared-eight figures survived unchanged, Decision 76a needed re-verification and held for the eight but not beyond them, and a 533-line PRD skill appeared that the milestone's plan does not name.

## 1. The fork point, with its verification evidence

**Ancestor:** `dot-ai` commit `84c80f17f7ff30c9ed000758cfdc3f9a892e4a40`, 2026-02-10, "feat: enable mock server fixtures for tools and prompts endpoints". Path lineage `shared-prompts/<skill>.md`.

What makes this the fork rather than a plausible candidate:

- The commit exists and is reachable in the current clone (`git cat-file -t 84c80f17` returns `commit` at the SHA above).
- `git ls-tree 84c80f17 shared-prompts/` lists ten files, of which eight are exactly the eight PRD-lifecycle skills in the canonical manifest: `prd-close`, `prd-create`, `prd-done`, `prd-next`, `prd-start`, `prd-update-decisions`, `prd-update-progress`, `prds-get`. The other two (`generate-cicd`, `generate-dockerfile`) were never forked here. **`prds-get` is present in the ancestor**, which matters because it is the skill a `prd-*` glob silently omits.
- The path lineage is a rename, not a coincidence: upstream's current copies live at `.claude/skills/dot-ai-<skill>/SKILL.md` and hers at `.claude/skills/<skill>/SKILL.md`, and six of the eight bodies are still content-identical to the ancestor at this commit (measured in §2), which no unrelated commit would produce.

**His current is unambiguous for these eight (Decision 76a re-verified).** All eight `SKILL.md` files are byte-identical between `dot-ai` and `dot-agent-deck` at the SHAs above, confirmed by `cmp` per file. Read either.

**Decision 76a does not generalize past those eight.** `dot-ai-prd-full` is 14 lines in `dot-ai` and 36 lines in `dot-agent-deck` — the `dot-ai` copy is an older stub carrying only a description and arguments, while the deck copy carries the whole mechanism. Decision 76c describes the 36-line deck version, so that decision's content stands, but a future reader who takes "read either clone" as a general rule will read the wrong file for this skill. `dot-ai-worktree-prd` is identical across both at 50 lines.

## 2. The who-moved split

Measured by `scripts/skill-fork-diff.sh`, committed alongside this document so the numbers are reproducible rather than asserted. Churn counts both sides of the diff — lines removed as well as added.

| Skill | Ancestor body | His body | Her body | He moved | She moved |
|---|---:|---:|---:|---:|---:|
| `prd-create` | 203 | 203 | 223 | 0 | 38 |
| `prd-start` | 181 | 194 | 226 | **13** | 47 |
| `prd-next` | 257 | 257 | 296 | 0 | 49 |
| `prd-update-progress` | 313 | 313 | 409 | 0 | 102 |
| `prd-update-decisions` | 92 | 99 | 129 | **7** | 45 |
| `prd-done` | 335 | 335 | 400 | 0 | 87 |
| `prd-close` | 277 | 277 | 277 | 0 | **0** |
| `prds-get` | 42 | 42 | 33 | 0 | 51 |
| **Total** | | | | **20** | **419** |

Both of Decision 76's headline figures reproduce exactly. Two facts recorded with no disposition attached:

- **Six of his eight are content-identical in body to the ancestor.** He moved lines in `prd-start` and `prd-update-decisions` only.
- **`prd-close` is identical across all three.** Neither party has touched it since the fork.

**The measurement trap, hit and corrected.** A first run reported 28 lines moved by him and a uniform 1-line change in six skills whose bodies the PRD says are identical. The extra line in each case is a single blank line at end of file, added by the frontmatter-to-skill conversion. Stripping trailing blank lines before diffing yields exactly 20 and leaves 419 unchanged. The script now normalizes this, and the fix is worth stating rather than silently applying: a uniform, implausibly small delta appearing across many files at once is an artifact signature, not a finding. This is the same defect class as the frontmatter trap the PRD already names — a figure that disagrees with the tool that produced it.

### What he moved, line by line

His whole divergence is 20 lines across two skills, and both additions are the same kind of thing: a step the ancestor left implicit.

**`prd-start`, 13 lines** — a new `### Issue Assignment` section instructing `gh issue edit [issue-id] --add-assignee @me` immediately after PRD selection, "so others do not pick up the same PRD and work on it in parallel," plus three one-line echoes of it elsewhere in the file (an `**Assignee**: @[username] ✅` row in the readiness checklist, an `**Assignee**: @[username]` line in the status block, and a `- ✅ Assign the GitHub issue to the current user to prevent duplicate work` bullet in the success criteria).

**`prd-update-decisions`, 7 lines** — a new `### Task and Milestone Updates` block under the decision-impact step, listing five actions a decision can require: create new tasks, add new milestones, update existing tasks, remove or defer tasks, reorder priorities.

Both are concurrency-and-cascade concerns. Neither depends on his swarm.

### What she moved, by section

Section-granularity summaries, per the re-aimed milestone. Each entry gives what the section does, why it is there where that is recoverable from git history or the decision log, and a keep-or-collapse note for C1. Headings unchanged from the ancestor are omitted.

#### `prd-update-progress` (102 lines moved)

| Section | Status | What it does | Why it is there | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `## Process Overview` | Rewritten | Numbered table of contents for the workflow steps | Renumbered when Step 8.5 was added (`4f53d07`), again when Step 8.6 was inserted (`7ccf764`) | Hand-maintained mirror of the step headings; it has already drifted once per addition. Any renumbering must update it too |
| `### Update PROGRESS.md (If Present)` | New | Before committing, check for a repo-root `PROGRESS.md` and append dated, externally-readable entries under `## [Unreleased]` | `fe5023f`, building on PROGRESS.md integration from `d37f866` | Self-contained with good and bad examples; near-duplicate of the block in `prd-start`. Extraction candidate |
| `### Commit Message Guidelines` | Rewritten | Commit-message guidance, closing with push timing | `7ccf764` changed the closing note from "do not push unless requested" to "push in Step 8.6, after CodeRabbit has run and been triaged" | One-sentence change, tightly coupled to Step 8.6; should move with it |
| `## Step 8.5: CodeRabbit CLI Review` | New | Run `coderabbit review --committed --base origin/main` in the background after committing; triage before proceeding | `4f53d07` added it; `11dba56` corrected the command in four places; `4d0a5fc` made it "the only review between writing code and opening a PR" | Already defers to `~/.claude/rules/git-workflow.md` rather than restating it. Good precedent for collapsing the other CodeRabbit blocks the same way |
| `## Step 8.6: Push the branch` | New | Push only once every finding is triaged; run in background, verify via `git rev-list`, never `--no-verify` | `7ccf764`, whose message records the repo had reached 44 unpushed commits across 19 days including 22 journal files with nothing surfacing the gap | Long and generic push mechanics; the reasoning is incident-specific but the mechanics are reusable. Extraction candidate |
| `## Step 8.7: Decision Awareness Check` | New | After implementation, assess whether design decisions emerged and run `/prd-update-decisions` if so | `e18acfe`, to capture decisions while context is fresh | Short nudge; overlaps in purpose with Step 8.9's decisions bullet. Merge candidate |
| `## Step 8.9: Handoff Verification` | New | Five mandatory actions before suggesting `/clear`: decisions, PROGRESS.md, open questions, next-task entry point, workarounds | Added as a "Handoff Readiness Check" in `305ee28`, then rewritten in `107662f` (issue #89) **because the original was a self-assessment checklist agents answered reflexively** — converted so each item is an action to complete, not a question to answer | Long, generic, not specific to progress-updating; overlaps Step 8.7 and the PROGRESS.md handling above. Strong consolidation candidate |
| `## Step 9: Next Steps Based on PRD Status` | Rewritten | Transition into the completion-status branches | `4f53d07` added a mention of addressing CodeRabbit findings | Trivial wording change |

#### `prd-done` (87 lines moved)

| Section | Status | What it does | Why it is there | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `### 2.5. Pre-PR Verification` | New | Launches a verification agent that maps every milestone's success criteria to observable code evidence using an Exists → Substantive → Wired check and reports gaps in a table before PR creation | `beb6866`, closing issue #72, to catch milestones marked complete without evidence | Self-contained but long (an embedded agent prompt). The three-level check also lives in `~/.claude/rules/testing-rules.md`. Extraction candidate |
| `### 3. Pull Request Creation` | Rewritten | Release-label detection scoped to release labels only (3.6), an independent acceptance-gate label check (3.6b), combined label creation, and `/code-review` immediately after PR creation | `a8a421b` ported 3.6b in from the YOLO variant where it existed alone; `7d7a980` sharpened the 3.6 heading because it still read as governing every label; `e8195bd` added `/code-review` | The label matrix is mechanical and self-contained; the `/code-review` paragraph duplicates `git-workflow.md`. Trim to a rule reference |
| `### 4. Review and Merge Process` | Rewritten | Adds Anki capture (4.0) during the CodeRabbit wait; requires all three CodeRabbit API channels with a positive-evidence `commit_id` check rather than absence-of-findings; adds a Fix/Defer/Skip triage rubric and a re-review loop | `4ce0b44` (Anki), `1b0a8e1` (three-channel fetch and re-review loop), `813b39b` (the positive-evidence correction, whose message records that the earlier description overstated what it proved), `6e5202b` (triage rubric) | **The longest and most duplicated section in either family.** The three-channel commands, the `commit_id` logic, and the triage rubric all also live in `git-workflow.md` and in `prd-update-progress`. Strongest single extraction candidate |

#### `prd-next` (49 lines moved)

| Section | Status | What it does | Why it is there | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `## Step 6b: Create Milestone Task List` | New | After confirmation, create one task per unchecked checkbox in the current milestone only, set the confirmed one in progress, wire dependencies | `3ea003c` | Self-contained, 34 lines with a worked example; unique to this skill today. Extraction candidate only if other skills grow the same need |
| `## Step 8: Implementation` | New | States the step is user-driven with no LLM action, and that Step 9 must not begin until the user signals completion | `81e9433`, after CodeRabbit flagged that "Implementation" existed in the overview list with no body | Three lines. The same stop-and-hand-off shape recurs in `prd-start` and in Step 9; a consolidation pass could unify the phrasing |

#### `prd-start` (47 lines moved)

| Section | Status | What it does | Why it is there | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `## Step 3b: Create PROGRESS.md (If Not Present)` | New | After branch setup, skip if `PROGRESS.md` exists; otherwise count unique human contributors via `git log --format='%aN'` to decide gitignored (multi-contributor) versus tracked (solo), create from a fixed template, display confirmation | `d37f866` (PRD #30); fixed by `99f8e65`, which corrected contributor counting from name+email pairs to names only, since one person with several emails was over-counted | Bootstrapping logic, not judgment — a strong candidate for extraction into a script. The twin logic already exists in `prd-update-progress`, and the contributor one-liner is exactly the kind of snippet that drifts between copies |

#### `prd-update-decisions` (45 lines moved)

| Section | Status | What it does | Why it is there | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `## Process Overview` | Rewritten | Five numbered stages ending in downstream propagation, replacing the ancestor's six | `978322e` added the fifth; `b890086` aligned the numbering with the actual step headings — **the ancestor's overview had never matched its own body** (six listed stages, four `## Step` headings) | Demonstrates the overview-versus-body drift risk other skills should be checked for |
| `### Decision Log Updates` | Rewritten | Adds one instruction: when a decision creates work, add a milestone item referencing the decision by number | `252010a` | Single bullet, conceptually paired with Step 5 below. Treat as one linked mechanism when consolidating |
| `## Step 5: Downstream Milestone Propagation` | New | After logging a decision, scan every incomplete milestone for changes to scope, criteria, approach, or dependencies; update affected ones with an inline note referencing the decision; excludes current-milestone-only, purely retrospective, and already-captured-in-Step-4 cases; reports which milestones were touched | `978322e` — decisions recorded only in the log are invisible to an agent that reads milestone text as its instructions. Refined by `b890086` and by `f7e108c`, which replaced a vague "briefly tell the user" with a concrete report string per `/write-prompt` review | Longest new section across the three (36 lines, four subheadings). Its exclusion logic and before/after example would extract cleanly. **Check `issue-update-decisions` for a near-duplicate** |

#### `prd-create` (38 lines moved)

| Section | Status | What it does | Why it is there | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `### Step 5: Create PRD as a Project Management Document` | Rewritten | Adds a callout that milestones will be reviewed with `/write-prompt` as agent instructions, plus two milestone characteristics: research-explicit (direct the implementer to run `/research <specific question>`, include full output) and research-output propagation (a dependent milestone opens with a "Step 0: Read [prior output]" gate) | `1f76f7a` and `fe6ecc7` | Self-contained and PRD-creation-specific. Could become a shared milestone-authoring checklist if other skills need the same conventions |
| `## Workflow` | Rewritten | Adds step 7, "Prompt Quality Review" — run `/write-prompt` on the milestones before committing | `1f76f7a`, same commit as the Step 5 callout | Duplicates the Step 5 callout's intent within the same file. Merge the two mentions |
| `## Acceptance Gate Label Reminder (If Applicable)` | New | Detects acceptance-gate configuration and notes in the PRD that the eventual PR needs the `run-acceptance` label | `a8a421b`. The decision log records this existed **only in the YOLO variant** and was ported to interactive to remove an accidental divergence | Detection already lives in a shared script; only the what-to-do-with-it prose is skill-local. Keep as a pointer |
| `### Option 2: Commit and Push for Later` | Rewritten | Replaces a commented-out ROADMAP reminder with an executable conditional, so the commit message's claim of a ROADMAP update is never false; normalizes `/prd-start` | `e42af51` (CodeRabbit), `dfae0f6` | The stage-only-if-exists pattern may recur in `prd-done`; worth checking for duplication |

#### `prds-get` (51 lines moved, body shrank 43 → 34)

Substantially rewritten rather than extended, so removals are recorded as their own entries.

| Section | Status | What it does or did | Why | Keep-or-collapse note for C1 |
|---|---|---|---|---|
| `## Process` | Rewritten | One `gh issue list` call fetching all open issues, split client-side into PRD-labeled and standalone; two tables; marks the PRD matching `feature/prd-<n>-*` as active; dependency and blocking analysis across both groups | `6657d1c`, resolving issue #61 — the skill previously saw only PRD-labeled issues and missed standalone issues relevant to planning | The single-call-split-client-side pattern and the active-branch detection are reusable by other skills that need to know the active PRD |
| Ancestor step 3, "Meaningful Categorization" | **Removed** | Grouped PRDs by impact category (architecture, UX, developer experience, AI, operations, integration) with an explanation per category | Not recoverable from git history or the decision log | A content-generation instruction, distinct in kind from the current mechanics. If categorization is still wanted it needs re-adding, not assuming |
| Ancestor step 4, "Priority Analysis" | **Removed in part** | Asked which PRDs are recently updated or actively discussed, which are foundational versus incremental, which are blocked | Not recoverable for the dropped half | The dependency half survived and was generalized. The foundational-versus-incremental and recency framing is genuinely gone; reintroduce explicitly if next-task quality regressed without it |

## 3. The skills he has that she has none of

Seven skills, not the six the milestone names. `prd-queue` (533 lines) appeared in the 82 commits pulled at the start of this milestone and did not exist when B4 was re-aimed on 2026-09-02. It is his newest PRD-lifecycle thinking, which is what this section is for, so it is included; adding it was approved in session on 2026-09-03.

Each was read in full. Four things per skill: problem, mechanism, swarm dependence, label.

### `prd-queue` — 533 lines, `dot-agent-deck`

**Problem.** With several open PRDs tracked as labeled GitHub issues, deciding which are genuinely safe to start now is hard: some have no PRD document yet, some are already being worked by a PR or a branch or an abandoned worktree, some belong to the other maintainer. This is the PRD member of a three-skill queue family (`issue-queue`, `pr-review-queue`, `prd-queue`).

**Mechanism.** A nine-step selection-then-dispatch pipeline, mechanical except for two questions put to the human.

- *Step 0* (36–51): `git fetch origin --quiet`, then verify every claim about code or PRD state against `origin/main` via `git grep`, never against the local checkout, because a stale checkout inverts "still unimplemented" silently.
- *Step 0b* (53–92): decide whether to fast-forward the base that dispatched units are cut from, since `git worktree add` with no start-point resolves to `HEAD`. Three preconditions must all hold — no tracked changes, `HEAD` is `main`, `main` not ahead of `origin/main` — before `git merge --ff-only origin/main`. Any failure is reported for the runner to resolve rather than resolved automatically. The step exists because of a dated incident (2026-08-30) where two PRDs were dispatched from a base six commits stale and neither could see the code its own PRD was about.
- *Step 1* (94–105): resolve identity at runtime via `gh api user`; every dispatched task requests review from the other maintainer.
- *Step 2* (107–133): `gh issue list --limit 300`, `jq` filter for the `PRD` label (the inverse of `issue-queue`'s filter, flagged in the file as the most likely copy-paste bug), unassigned-or-mine, then check the limit was not truncated.
- *Step 3* (135–149): `git ls-tree origin/main prds/` for a matching document. No document means flagged as needing `/prd-create` first, never a silent drop.
- *Step 4* (151–217): three independent in-flight checks — a GraphQL query on `closingIssuesReferences`, a read of open PR bodies for PRDs advanced without a formal closing reference (a PRD spans several PRs and only the last closes it), and a scan of branches and sibling worktrees under two naming conventions plus any off-convention `*dispatch*` branch.
- *Step 5* (219–236): print survivors with exclusion notes; stop and report if none survive rather than asking how many to dispatch; otherwise ask how many, recommending one or two.
- *Step 6* (238–268): claim by re-reading assignees immediately before writing (narrowing, not closing, the race), assign, then name the unit `prd-<n>` — **never derived from the PRD's own text**, an injection concern — and check the branch name is free without ever deleting a taken one.
- *Step 7* (270–301): two questions the runner must answer explicitly and that are never inferred — shape (single agent or team), asked per PRD because it selects the template; and provider, asked once per session because it is a property of credits, not work.
- *Step 8* (303–513): compose the task **in a file**, never inline through a shell (substitution mangles backticks and quotes) and never via heredoc (a task line can terminate it early). PRD-derived text — title, body, labels, comments, all attacker-writable on a public tracker — is fenced and labeled as untrusted data, never instructions. Two mutually exclusive templates: 8a for a single agent, pointing at `/prd-full`; 8b for a team, deliberately *not* pointing at `/prd-full`, because that would make the orchestrator self-implement instead of delegate.
- *Step 9* (525–534): report per unit, including the base's distance from `origin/main` at dispatch time.

**Swarm dependence.** Case (b). Steps 0 through 6 and 9 — roughly 400 of 533 lines — are pure `git`, `gh`, and `jq` with no reference to panes, roles, or the deck runtime. The dependence is concentrated in step 7's provider fork, template 8b, and the `dot-agent-deck dispatch` calls, plus a hard prerequisite: the skill exits without `DOT_AGENT_DECK_PANE_ID` (line 30). Template 8a is the single-agent branch and already describes what a single-session runner would want.

**Label: adopt-with-swarm**, with the caveat that this undersells the file. It is effectively a standalone selection pipeline with a swarm-specific dispatch layer grafted on. Adopting it means extracting the swarm-independent majority, which is a rewrite rather than a copy.

### `pr-review-queue` — 513 lines, `dot-agent-deck`

**Problem.** A maintainer cannot tell from `gh pr list` which PRs are actually waiting on them. Unresolved review threads are not a field the REST list API exposes, and a `CHANGES_REQUESTED` decision carrying zero inline threads looks identical to a clear PR under a naive check. Measured on his own repo, a thread-only rule both admits PRs that are someone else's homework and drops his own PRs sitting on unanswered feedback.

**Mechanism.**

- *Step 0* (23–65): same base-freshness discipline as `prd-queue` — fetch, check branch, cleanliness, and `git rev-list --left-right --count HEAD...origin/main`, then `git merge --ff-only`, never `git pull`. Four named failure cases hand the decision to the runner.
- *Step 1* (67–148): a paginated GraphQL query (97–134) pulling `reviewDecision`, `reviewThreads(first:100){nodes{isResolved}}`, assignees, and requested reviewers, because thread counts are unavailable through `gh pr list --json`. **The exclusion rule is two-part:** exclude only if the PR is not authored by the runner *and* (`unresolved > 0` *or* `reviewDecision == CHANGES_REQUESTED`). Both halves are required precisely because a changes-requested review can carry no inline threads. Two pagination bounds are enforced procedurally — the PR list and each PR's thread list — and until both are exhausted an `unresolved: 0` reading is treated as unproven rather than zero (line 140).
- *Step 2* (150–162): print included and excluded with reasoning, ask how many, refuse to default to all.
- *Step 3* (164–210): immediately before dispatching each PR, re-run `verify-pr/scan.sh` and a single-PR version of the step-1 query, and skip if the PR is no longer open or has since become someone else's homework.
- *Step 3b* (212–250): prevent double-dispatch by checking for an existing branch, then establish whether the claim is *live* by walking `/proc/[pid]/cwd` or `lsof` for a process whose working directory is inside the worktree — **explicitly rejecting directory mtime as a liveness signal**, since a unit can sit idle in a polling loop for 700-plus minutes while genuinely alive.
- *Step 4* (252–449): compose a task file, never an inline task, because PR title and branch name are attacker-controlled. Push permission is keyed strictly to authorship: own PR may push, with a scope bound forbidding unrelated changes such as a stray `cargo fmt`; anyone else's PR, never. A tailored risk note is derived from `scan.sh`'s file-classification buckets (table at 316–330).
- *Steps 5 through 8* (451–513): restate guardrails as per-task text; naming and collision checks that never auto-delete a stale branch, because that can destroy an unread report; and an explicit statement that there is no return channel — the dispatched unit's final message in its own pane is the report.

**How it decides a review is complete:** never a single field. Threads must be fully paged *and* `reviewDecision` read, then the two-part rule applied, re-verified once at listing and again immediately before dispatch.

**Swarm dependence.** Case (b). The queue-building logic references no roles or concurrency. What genuinely depends on the deck is the dispatch primitive, step 3b's process-liveness check, the pane-as-report model, and the branch-naming scheme. The file itself notes that for a single named PR the recommended path is `/verify-pr` directly, since "dispatching a single unit just adds a worktree between you and the answer" (line 15).

**Label: adopt-with-swarm**, on the artifact. The portable substance is narrower and sharper than the file: the two-part exclusion rule, the pagination-completeness discipline, and the re-check-immediately-before-acting step.

### `issue-queue` — 354 lines, `dot-agent-deck`

**Problem.** On a shared backlog, "pick something to work on" is deceptively hard — duplicates, issues already fixed by an unmerged PR that never declared a closing reference, issues someone else claimed, and a stale checkout that makes present code look missing. It exists because this happened: issue #490 was dispatched into a bug already being fixed on a differently-named branch, producing a duplicate PR, and a `main` twelve commits behind once produced a false "code does not exist" read.

**Mechanism.** The same nine-step shape as `prd-queue`, with the label filter inverted. Step 0 (31–86) is the base-freshness gate. Step 2 (99–124) pulls up to 300 issues and checks `jq 'length'` against the limit to detect truncation. Step 3 (125–195) runs the three independent in-flight checks, each documented with the failure case that made the previous layer insufficient. Step 4 (196–211) detects duplicates and coupling by grepping issue bodies for shared backtick-quoted symbols and source paths, **because title similarity alone was insufficient** — two issues shared zero title words and the same function. Steps 6 through 9 claim, name, compose a fenced task file, and report.

**Swarm dependence.** Case (c) for the dispatch action, case (a) for the selection pipeline. The prerequisite section states plainly that `dot-agent-deck dispatch` exits without `DOT_AGENT_DECK_PANE_ID`, and that "selection still works and is worth reporting, but nothing can be dispatched from here" (25–29). Steps 0 through 6 touch nothing but `git`, `gh`, and `jq`.

**Label: adopt-with-swarm** on the artifact, because steps 7 and 8 are about his dispatch binary and stripping them leaves a skill that never says what to do with what it selected. The selection methodology is separately valuable.

### `verify-pr` — 284 lines plus `checks.sh`, `dot-agent-deck`

**Problem.** Deciding whether to merge someone else's PR — a human contributor, Renovate, or another agent's output — where checking out the branch can execute their code, where a green check can hide unread findings, where a skipped test silently counts as a pass, and where the review worktree itself can produce false failures indistinguishable from real ones.

**Mechanism.** Eight phases communicating through a `KEY=value` stream grammar.

- *Phase 0, scan* (35–63): `scan.sh <pr>` from the main checkout, creating nothing. Four outputs are decision points: `READ_DIFF_BEFORE_RUNNING` forces reading `.claude/**`, `.github/**`, and build-script diffs *before* creating a worktree, stopping outright on anything resembling exfiltration; `PR_AUTHOR_ASSOCIATION` forces reading the whole diff before running gates, since test code executes under the runner; `PR_DRAFT`/`PR_STATE`; and `WORKFLOWS_AWAITING_APPROVAL`.
- *Phase 1, isolate* (65–81): `setup.sh` creates a sibling worktree from `refs/pull/<n>/head` and merges `origin/main` into it, because CI tests the merge commit rather than the bare head.
- *Phase 1b, release held CI* (83–121): before approving a withheld fork run, read every `.github/workflows/**` diff line against a six-item checklist, and distinguish `pull_request` (secrets withheld from forks) from `pull_request_target` and `workflow_run`, which run off the base branch's definition and are always a stop.
- *Phase 2, gates* (123–158): `checks.sh` runs in the background, polling `summary.tsv` and a `DONE` sentinel rather than blocking. It runs cheapest-first and **never stops at the first failure**: fmt, clippy across both feature sets (the only step anywhere that type-checks the 24 real-agent test files), release build, `test-fast`, linkage check, Windows cross, audit — each recorded as passed, failed, skipped, or blocked, with blocked distinguished from skipped. The opt-in e2e step (297–364) uses `--success-output=final` **specifically because the runner silently counts a skipped real-agent test as passed**, then greps for skip lines and emits an `ATTENTION` row telling the reviewer to re-run with a force-fail environment variable to convert unrunnable coverage into an explicit failure.
- *Phase 5, attribute before judging* (176–205): re-run failures at the merge base — but with the explicit caveat that **the worktree is not a control**, citing a real incident (#352) where a test failed identically in the PR worktree and a clean-`main` worktree because of path-length sensitivity, and was nearly misattributed to `main`.
- *Phase 6, verdict* (207–263): exactly one of five — merge, merge with follow-up, request changes, do not merge, or blocked-cannot-verify — written to a gitignored file, never posted to GitHub.
- *Phase 7* (265–284): tear down with `git worktree remove` before `git branch -D`, after a `git log` check that no local commits would be lost.

**Swarm dependence.** Case (a). Neither `SKILL.md` nor `checks.sh` references panes, roles, orchestration, or dispatch anywhere. It is single-agent by construction.

**Label: adopt-now.** The Rust-specific gate list would not transfer, but that is a tooling mismatch rather than a swarm dependency. The transferable substance is procedural: the scan-before-touching discipline, the workflow-approval checklist, the never-stop-at-first-failure gate harness with blocked distinct from skipped, the skip-counted-as-pass trap and its force-fail remedy, the worktree-is-not-a-control caution, and the fixed five-verdict vocabulary.

### `reproduce-first` — 65 lines, `dot-agent-deck`

**Problem.** The instinct to jump from a bug report to "obviously the cause is X" produces confidently wrong diagnoses. Two case studies record first-guess causes that were wrong, where writing a test that failed for the user's stated reason exposed the real defect — and in one case a second, stacked one. It also targets tests that pass trivially and give false confidence.

**Mechanism.** Eight ordered steps, where "the order is the whole point" (line 15): restate the symptom at the user's altitude, not a technical abstraction; find the existing test covering the surface and extend rather than duplicate, with an explicit bias order of extend over modify over write-new; assert at the user-visible outcome rather than an adjacent artifact; run it and confirm it fails **for the user's reason**, reading the message to check it names their symptom rather than a harness bug; add a control test isolating the cause; fix; watch it go green, then **prove each fix is load-bearing by reverting one change at a time and confirming red returns**; run the wider tier before reporting done. Four traps follow (43–53): prove the assertion can actually fail, since never having observed it fail is not evidence; prefer the real configuration over a cheap stand-in; keep stand-ins narrow, since a blanket `git` stub once broke an unrelated path; reproduce on the reporter's machine rather than inferring locally; and if it cannot be reproduced, say so rather than presenting an unverified fix as verified.

**Swarm dependence.** Case (b), and barely — nothing references roles or delegation. The project-specific test tooling would need adaptation, which is unrelated to the swarm.

**Label: adopt-now.** The discipline is generic and aligns with the TDD rule already in `~/.claude/rules/testing-rules.md`; only the Rust commands need swapping.

### `dot-ai-worktree-prd` — 50 lines, identical in both clones

**Problem.** Starting PRD work on the current checkout risks colliding with in-progress work, and a fresh worktree silently loses gitignored local settings.

**Mechanism.** Four steps. Infer the PRD number from context and ask if absent (13–18). Run `create.sh` with the number and, if known, the title, otherwise letting the script look it up (19–29). Copy `.claude/settings.local.json` into the new worktree because it is untracked, skipping silently if absent (31–38). Branch on the script's `SUCCESS`/`ERROR` signal (40–43). No loop, no gate beyond that branch.

**Swarm dependence.** Case (a). Plain `git worktree` plumbing.

**Label: adopt-now**, subject to reading `create.sh` (not read here) and to a fit question rather than a dependency one: her `/prd-start` already creates branches, so this would need to slot in rather than duplicate.

### `dot-ai-prd-full` — 36 lines, `dot-agent-deck` copy

**Problem.** Running a PRD to completion normally means sitting through every confirmation checkpoint that `/prd-start`, `/prd-next`, `/prd-update-progress`, and `/prd-done` each pause for.

**Mechanism.** An arguments gate that aborts rather than auto-detecting. Then **the autonomy mechanism itself, which is a single global rule** (15–19): for the duration of the run, treat the sub-skills' built-in "wait for the user," "ask before proceeding," and "STOP here" instructions as overridden, and proceed with the proposed answer. Standard guardrails for genuinely destructive actions survive it. Then a five-step flow: isolate per mode; run `/prd-start`, skipping its branch creation; loop `/prd-next` (implementing in the same turn) plus `/prd-update-progress` **without resetting conversation context** until complete; run `/prd-done` only through PR creation; and then — explicitly not stopping at PR creation — poll until both CI and bot reviews settle, fetch the inline findings from the comments endpoint because the summary comment and review state do not carry them, report the findings rather than the check states, and resolve them before stopping. Either way it stops before merge.

**Swarm dependence.** Case (b), and the distinction matters: **the autonomy is not the swarm.** It is a prompt-level suppression rule that works identically whether one session runs all four sub-skills or a role runs one. Exactly one line names a role, the parenthetical about delegating the polling step to a `release` worker.

**Label: adopt-with-swarm**, not because the mechanism needs a swarm but because it needs a substrate she does not have — it composes his four `dot-ai-prd-*` skills, and hers have different gates — and because the suppression scope is a decision that should be made deliberately rather than inherited. Routed to Milestone D1 as evidence per Decision 76c, with no verdict attached.

### The six swarm roles

From `.dot-agent-deck.toml`. Three orchestrations exist: `mixed` (105–247, the default, six roles), `anthropic` (254–280), and `GPT` (294–320). The latter two are `extends = "mixed"` overlays that restate only the six command lines, so provider choice does not fork the workflow — a deliberate guard against three hand-maintained copies drifting.

| Role | Lines | Assignment | What it does |
|---|---|---|---|
| orchestrator | 109–184 | Claude Opus | Never implements, reviews, or audits — delegates only. Seven phases, with exactly **two** stops for the user: test-plan approval before any code changes, and merge confirmation at the end |
| coder | 186–191 | Claude | Implements. In a TDD chain, makes the tester's failing test pass by changing production code only, and is **forbidden from editing tester-authored tests** — suspected-wrong tests are reported back. Must run fmt, clippy, and tests, and must commit and verify a clean tree before signalling done |
| reviewer | 193–198 | **pi harness, Opus** — deliberately a different vendor from the implementers | Correctness, consistency, edge cases, missed requirements. Findings only, never modifies code |
| auditor | 200–205 | **opencode, GPT at xhigh effort** — the second deliberately different vendor | Security and unsafe patterns. Findings only |
| tester | 207–224 | Claude (with a commented-out GPT alternative annotated "credits exhausted 2026-08-26") | Authors the failing test, confirms red with its signature, hands to coder, re-runs for green. Asserts on observable end-state rather than internal routing so tests survive refactors. **Forbidden from modifying production code or delegating** |
| release | 226–247 | Claude Sonnet — deliberately cheaper than the Opus and xhigh roles | Runs `/prd-done`. Never modifies source. On any failure, reports the exact error and **stops rather than self-diagnosing**. Must fetch inline findings from the comments endpoint and must never read a green check or a commented review state as nothing-to-read — carrying a dated correction (2026-07-30) from a real incident where exactly that misread happened |

**The rule mechanism, stated precisely, because this is the part most likely to be misread as transferable enforcement.** Two different things share the name. `[[modes.rules]]` (70–76) is genuinely tool-enforced: a pattern matched against a command, setting `watch = false` to suppress reactive-pane behavior for routine cargo and git-inspection commands. Role behavior is *not* that. Each role carries a `prompt_template` — natural-language instruction handed to the launched agent. **Nothing verifies that the coder actually ran clippy, or that the tester did not touch production code.** The only structurally enforced role-level fields are `start`, `clear`, `default`, and `extends`. Enforcement of everything else is the agent's own compliance, backstopped by the orchestrator reading the report.

Transferable to a single session, provisionally: the test-plan-first gate; the two-gates-only rule chosen by "might the human have walked away" rather than "every pause" (line 166); the TDD chain shape with the implementer forbidden from editing the tests; report-blockers-instead-of-guessing; the explicit-recipient rule for notifications; and never treating a green check as nothing-to-read. Genuinely swarm-dependent: cross-vendor independent review, provider redundancy via `extends`, and pane suppression.

### Adoption labels, collected

| Skill or pattern | Label | Load-bearing reason |
|---|---|---|
| `verify-pr` | **adopt-now** | No swarm reference anywhere; single-agent by construction |
| `reproduce-first` | **adopt-now** | Generic TDD discipline; only test tooling needs swapping |
| `dot-ai-worktree-prd` | **adopt-now** | Plain `git worktree` plumbing |
| Six-role prompting patterns (test-plan gate, two-gates rule, TDD chain, report-don't-guess, green-check caution) | **adopt-now** | These were only ever prompting, not orchestration |
| `prd-queue` | adopt-with-swarm | ~400 of 533 lines are swarm-free selection logic, but the artifact hard-fails without a deck pane |
| `pr-review-queue` | adopt-with-swarm | Queue logic is portable; liveness checks and pane-as-report are not |
| `issue-queue` | adopt-with-swarm | Same shape; stripping dispatch leaves no instruction on what to do with the selection |
| `dot-ai-prd-full` | adopt-with-swarm | Autonomy mechanism is portable; the substrate and suppression scope are not |
| Cross-vendor independent review | adopt-with-swarm | The independence *is* the different vendor |
| Provider redundancy via `extends` | adopt-with-swarm | Meaningless without multiple agent commands |

## 4. The `issue-*` family: a structural comparison

Per Decision 76b, these six have no upstream ancestor — his only `issue-*` skill is `issue-queue`, a selection builder standing in no counterpart relationship to a lifecycle. So this is a comparison against the `prd-*` family for the parallel-implementation problem Decision 9 named.

### Lifecycle steps present in one family and not the other

| Stage | `prd-*` | `issue-*` | Note |
|---|---|---|---|
| Create | `prd-create` | `issue-create` | Both |
| Start | `prd-start` | `issue-start` | Both, but see the divergence below |
| Next | `prd-next` | `issue-next` | **Same name, different job** — see below |
| Update progress | `prd-update-progress` | `issue-update-progress` | Both |
| Update decisions | `prd-update-decisions` | `issue-update-decisions` | Both |
| Done | `prd-done` | `issue-done` | Both |
| Close | `prd-close` | **absent** | No `issue-close`; the issue family has no path for "already implemented or no longer needed" |
| Fetch/survey | `prds-get` | shared | `prds-get` fetches PRDs *and* standalone issues, so it serves both families despite its name and its placement in the PRD manifest |

**The `*-next` pair is the sharpest finding, and it is worse than duplication.** `prd-next` analyses a PRD, recommends the single highest-priority task, and discusses its design — its steps are detection, documentation and implementation analysis, completion assessment, dependency analysis, strategic value, recommendation, task list, design discussion. `issue-next` does something else entirely: fresh-session pickup, reconstructing working context from the most recent checkpoint comment and the git log — its steps are identify context, fetch checkpoint, read git log, synthesize brief, create tasks from checklist, proceed. Two skills share a name and a family position while performing different functions. Anyone reasoning by analogy from one to the other will be wrong.

**Step-level asymmetries within the shared stages.** `prd-start` has a Step 2 "PRD Readiness Validation" (requirements validation, documentation analysis, an implementation readiness checklist) with no `issue-start` counterpart. `issue-start` has a Step 2 "Analyze Juggling Candidates" with no `prd-start` counterpart. `issue-create` makes `/write-prompt` review its own numbered Step 3; `prd-create` carries it as workflow step 7 and again as a callout in Step 5.

### Shared procedures: which diverged and which did not

- **PROGRESS.md creation has *not* diverged.** `prd-start` Step 3b and `issue-start` Step 4b are 45 and 42 lines respectively, with the same four subsections in the same order — check for existing, contributor detection, create, display confirmation. Duplicated, but in sync.
- **The CodeRabbit procedure *has* diverged**, and across three families rather than two. See §6.
- **ROADMAP.md lifecycle updates** appear in both create skills and in `prd-close`, `prd-done`, and `issue-done`.

## 5. The eight interactive/YOLO pairs

Divergence measured per pair, both sides of the diff:

| Pair | Churn |
|---|---:|
| `prd-next` | 349 |
| `prd-done` | 86 |
| `prd-create` | 50 |
| `prd-update-progress` | 49 |
| `prd-start` | 24 |
| `prd-update-decisions` | 12 |
| `prd-close` | 5 |
| `prds-get` | **0** |

`prds-get` is an identical pair. One of the eight has no divergence at all.

Every divergence, with an assessment for C1. **No keep-which verdict is recorded here.**

| # | Pair | The divergence | Stronger, and why | Trade-off |
|---|---|---|---|---|
| 1 | `prd-next` | YOLO carries a `## Autonomous Decision Protocol` immediately after the intro; interactive has none | **YOLO.** It is the only explicit escalation contract in all sixteen files, and its placement at the top is exactly what the compaction finding in §8 argues for | The contract was written for autonomous operation; generalizing it to the interactive posture is C1's design work, not a copy |
| 2 | `prd-next` | Interactive keeps expansive detection prose, worked examples, and per-step confidence rubrics; YOLO compresses the same steps to bullets | **Split.** Interactive is more teachable and its examples disambiguate; YOLO is 1,005 tokens smaller for the same procedure | Compression bought real headroom against the cap. The examples are what a weaker model leans on |
| 3 | `prd-next` | Interactive Step 8 is "user implements, no LLM action"; YOLO drives an implement-and-loop cycle | **Neither on merit; they encode different postures.** This is the posture axis of Decision 33a, not a content difference | Recorded so C1 does not mistake a posture choice for a quality difference |
| 4 | `prd-done` | Interactive surfaces verification gaps and stops; YOLO implements the missing work and re-runs the verifier | **YOLO on autonomy, interactive on safety.** YOLO closes the loop; interactive keeps a human between a gap and its fix | A gap can mean the milestone was mis-scoped, which is not an agent's call |
| 5 | `prd-done` | Interactive proposes each PR field and asks for confirmation; YOLO auto-fills with best judgment | **YOLO for unattended runs, interactive for accuracy.** Manual-testing and security fields are exactly where invention is most likely | Seven confirmation prompts is heavy friction for fields that are usually obvious |
| 6 | `prd-done` | Interactive proposes template requirements and asks before executing; YOLO classifies each as read-only, local-mutating, or network/external, auto-runs read-only only, and requires confirmation for the rest | **YOLO, clearly.** It replaces a blanket prompt with a risk classification, giving more autonomy *and* a tighter bound on what runs unattended | The classification must be right; a miscategorised mutating command runs without asking |
| 7 | `prd-done` | Anki capture: interactive scanned the finished-cards directory to dedupe and sourced from the whole PRD, decision log, and full diff; YOLO capped at five cards with no dedupe scan | **Interactive.** Dedupe and whole-PRD sourcing were the substance | **Resolved 2026-09-04, outside C1.** Whitney no longer uses the step. Section 4.0 was removed from both variants and the interactive version's sourcing strategy extracted to a new `/make-anki-cards` skill. This divergence is closed; C1 has nothing to decide here |
| 8 | `prd-done` | Rate-limit channel: interactive says "a rate-limit notice"; YOLO names the channel, `/issues/{n}/comments` | **YOLO.** Naming the channel makes the check executable | None |
| 9 | `prd-done` | Re-review loop: YOLO adds that CodeRabbit does not auto-retry and gives the literal `gh pr comment` command | **YOLO.** Interactive states the loop; YOLO states how to restart it when stalled | None |
| 10 | `prd-done` | **YOLO alone carries: "Clearing this loop is not approval."** A review with no remaining findings, an empty review, and a rate-limited review that never ran all look identical, so human approval is still required before merge | **YOLO, and this is the most important single divergence in the table.** It is the same positive-evidence reasoning the interactive variant applies to `commit_id`, extended to the merge gate — and it exists only in the variant with less human oversight | No trade-off identified: it constrains the merge gate without costing autonomy anywhere else |
| 11 | `prd-done` | Completion criteria: interactive says "all tests passing in production"; YOLO says "all CI/CD tests and checks are passing" | **YOLO.** Nothing tests in production; the interactive line describes something that does not happen | None |
| 12 | `prd-done` | Findings triage: interactive lets the user decide which to implement; YOLO explains, recommends, and follows its own recommendation, pausing only for ambiguity or architectural concerns | **Posture, not merit** | Pairs with #10: YOLO is autonomous in triage and explicitly not in the merge decision |
| 13 | `prd-update-progress` | Interactive proposes checkbox updates and waits; YOLO applies them from evidence, pausing only on genuine ambiguity | **Posture.** YOLO adds "conservative: only mark complete when evidence is clear," which is a real guard | Reflexive confirmation of proposals is weak oversight |
| 14 | `prd-update-progress` | Interactive enumerates four confirmation-handling cases (partial acceptance, additional context, scope clarification, future planning); YOLO drops them | **Interactive**, if any confirmation step survives; these cases are what makes one useful | Dead weight in a posture that does not pause |
| 15 | `prd-update-progress` | Interactive presents next steps as a numbered instruction block; YOLO as a one-line `/clear` → `/prd-next` | **YOLO on economy** | Interactive's version is clearer to a newcomer |
| 16 | `prd-create` | Interactive offers a numbered start-now-or-later choice; YOLO always commits and pushes immediately, noting the branch-protection exemption | **YOLO on the exemption fact**, which interactive omits entirely | The choice itself is posture |
| 17 | `prd-start` | Interactive hands off with an explicit "STOP HERE — DO NOT" list; YOLO immediately invokes `/prd-next` via the Skill tool | **Posture.** Interactive's stop list is unusually emphatic, which suggests it was added after a real overrun | — |
| 18 | `prd-update-decisions` | Interactive asks which PRD; YOLO auto-detects through five prioritized signals, asking only when ambiguous | **YOLO.** Auto-detection with an ambiguity fallback strictly dominates always-asking | None |
| 19 | `prd-close` | Interactive confirms with the user and asks for implementation evidence; YOLO gathers evidence from context, git history, and linked repos | **Interactive on the confirmation** (closing a PRD is irreversible bookkeeping), **YOLO on evidence gathering** | — |

**Two corrections to the PRD's known-cases list, which the milestone spec warned not to treat as exhaustive.** First, it names the three-channel CodeRabbit fetch as a place the interactive variant is stronger. That is no longer so: both variants carry the three-channel fetch, and on the surrounding details — the rate-limit channel, the re-review restart command, and the not-approval warning — YOLO is the stronger of the two. The decision log records the original divergence as fixed in #110, so the list appears to predate that fix. Second, the assessment above finds nineteen divergences where the list anticipated a handful.

## 6. Repeated procedures: extraction candidates

Enumerated deliberately by grep across both skill families, both variants, the rules directory, and both CLAUDE.md files. Listed, not extracted — extraction is C1's call.

| Procedure | Copies | Where |
|---|---:|---|
| **Three-channel CodeRabbit fetch** | 5 | `git-workflow.md`, project `CLAUDE.md`, `prd-done` (both variants), `issue-done` |
| 7-minute CodeRabbit timer | 9 | `git-workflow.md`, `hooks-reference.md`, `issue-juggling.md`, project `CLAUDE.md`, `prd-done` ×2, `prd-update-progress` ×2, `issue-done` |
| CodeRabbit triage rubric | 7 | global `CLAUDE.md`, `git-workflow.md`, `rules/README.md`, `code-review`, `prd-update-progress` ×2, `issue-update-progress` |
| PROGRESS.md entry format and creation | 12 | global `CLAUDE.md`, `hooks-reference.md`, `prd-dependency-management.md`, `rules/README.md`, `prd-start` ×2, `prd-update-progress` ×2, `issue-create`, `issue-start`, `issue-update-progress`, `issue-done` |
| ROADMAP.md lifecycle update | 9 | global `CLAUDE.md`, `prd-create` ×2, `prd-close` ×2, `prd-done` ×2, `issue-create`, `issue-done` |
| Acceptance-gate detection and `run-acceptance` | 6 | `git-workflow.md`, `prd-create` ×2, `prd-done` ×2, `issue-done` |
| Exists → Substantive → Wired | 4 | `testing-rules.md`, `prd-done` ×2, `issue-done` |
| `/write-prompt` review gate | 9 | global `CLAUDE.md`, `git-workflow.md`, `hooks-reference.md`, `code-review`, `write-prompt`, `prd-create` ×2, `issue-create`, `issue-done` |

**The CodeRabbit family is the clearest case and spans all three implementations** — the rules layer, the PRD family, and the issue family — which is precisely the shape that already shipped the live bug the PRD names. PROGRESS.md is the highest-count case at twelve copies, and unlike CodeRabbit it has not yet drifted, which makes it the cheapest to collapse before it does.

## 7. The Autonomous Decision Protocol, as raw material

It exists in exactly one of the sixteen PRD skill files: `.claude/skills/prd-next/SKILL.v1-yolo.md`, lines 15–30. It is absent from the interactive `prd-next`. Verbatim:

```markdown
## Autonomous Decision Protocol

**Proceed without pausing when:**
- The task is clearly defined in the PRD
- The implementation approach follows established codebase patterns
- Design decisions are local (naming, file organization, internal structure)
- TDD cycle proceeds normally (write test → implement → verify)

**Stop and surface to the user when:**
- Implementation requires **deviating from what the PRD explicitly specifies**
- A design decision has **architectural implications** beyond the current task
- The PRD is **ambiguous** — multiple valid interpretations exist
- A PRD assumption turns out to be **wrong** or conflicts with existing code
- The change would **alter behavior outside the current task's scope**

When in doubt about whether something is "on spec," pause. The cost of a quick check is low; the cost of a wrong assumption compounds.
```

**How it is structured.** Two categories and no third: proceed, or stop and surface. There is no intermediate tier — no "proceed but note it," no "ask permission first." Routing is condition matching rather than scoring or confidence: each bullet names a concrete situational trigger, and the agent checks whether the situation matches a listed trigger on either side. The proceed triggers are about clarity, pattern-conformance, locality, and normal progress; the stop triggers are about spec deviation, architectural reach, ambiguity, falsified assumptions, and out-of-scope effects.

**The boundary is handled explicitly**, which is the part worth preserving. When a situation matches neither list cleanly, or plausibly matches both, the closing sentence resolves it by defaulting to caution, and justifies that default with an asymmetric-cost argument rather than leaving the ambiguous case unaddressed. A generalized contract that drops the closing sentence would lose the only rule covering the cases the lists do not enumerate.

Note its position: **first content section in the file, immediately after the intro.** That placement is independently validated by §8.

## 8. Compaction cap measurement

After a compaction, invoked skill bodies are re-injected but capped at 5,000 tokens per skill and 25,000 total, truncated from the bottom. Measured with `tiktoken` (`cl100k_base`). That is not Anthropic's tokenizer, so treat these as close approximations rather than exact counts; the margins below are wide enough that the conclusions do not turn on the difference.

| Skill | Interactive | YOLO |
|---|---:|---:|
| `prd-done` | **5,761** | **5,582** |
| `prd-update-progress` | 4,481 | 4,360 |
| `prd-next` | 2,959 | 1,954 |
| `prd-create` | 2,350 | 2,180 |
| `prd-close` | 2,030 | 2,016 |
| `prd-start` | 2,002 | 1,958 |
| `prd-update-decisions` | 1,423 | 1,530 |
| `prds-get` | 449 | 449 |
| **PRD family total** | **21,455** | 20,029 |
| Issue family total (6) | 9,405 | — |

Three findings:

1. **`prd-done` exceeded the per-skill cap in both variants** — 5,761 and 5,582 against a cap of 5,000.
2. **What it lost was not filler.** Truncating at 5,000 tokens cut mid-way through `#### 4.1. Check Review Status` and discarded `### 5. Issue Closure`, `### 6. Branch Cleanup`, and the entire `## Success Criteria` section — 45 lines in the interactive variant, 31 in YOLO. After a compaction, an agent finishing a PRD had a truncated CodeRabbit verification procedure, no issue-closure instructions, no branch-cleanup instructions, and no success criteria at all.
3. **`prd-update-progress` is at 90 percent of the cap**, so it is roughly one added section from the same failure. And both families together total 30,860 tokens against the 25,000 aggregate cap, which matters for any consolidation that would see both loaded in one session.

This is direct evidence for placing the generalized escalation contract at the top of every consolidated file, and it strengthens that argument beyond what the milestone anticipated: instruction order in these files is already a correctness property.

### Finding 1 was fixed on 2026-09-04 rather than carried to C1

Both variants are now under the cap and nothing truncates:

| | Measured | Now | Change |
|---|---:|---:|---:|
| `prd-done` interactive | 5,761 | **4,974** | −787 |
| `prd-done` YOLO | 5,582 | **4,987** | −595 |

Two cuts got there, neither of which removed a behaviour. First, every restatement of an always-loaded rule was replaced with a pointer to it — the three-channel `gh api` block, the positive-evidence `commit_id` test, the Fix/Defer/Skip rubric, and the `/code-review` explanation, all of which live in `~/.claude/rules/git-workflow.md`. A similarity scan against the always-loaded rules now returns zero overlapping lines. Second, section 4.0's Anki capture was removed at Whitney's direction, since she no longer uses it, and the interactive variant's sourcing strategy was extracted into a new `/make-anki-cards` skill.

**Do not read this as the constraint being retired.** The remaining headroom is 26 and 13 tokens, well under one percent, and these counts come from `tiktoken` rather than Anthropic's tokenizer, so whether the files are genuinely under the real cap is unresolved. The fragility is not theoretical: during this same session a one-line correctness fix pushed the YOLO variant back over the cap and had to be reworded. **C1 should treat "under 5,000 with real margin" as a hard constraint on the consolidation**, because the current state satisfies the letter of the cap and none of its spirit. Getting genuine margin needs a structural change — splitting the file, or extracting section 3's PR-template machinery — which is C1's call rather than something to do ad hoc.

Two other corrections were made to `prd-done` in the same pass, both in each variant. A backreference reading "re-run all three `gh api` calls from above" was repaired, since those calls had moved out to the rule file. And `Clean commit history: Squash or organize commits for clear history` was corrected to forbid squashing, because it contradicted the always-loaded rule "Don't squash git commits" — a live instruction to violate a rule, unrelated to sizing and found while editing.

## 9. Migration starting conditions

### Inertness, confirmed across the full set by script

`scripts/check-skill-symlink-inertness.sh` walks every repo in the workspace, and for each lifecycle skill checks both halves of the precedence rule: whether a project-level file exists, and whether a personally-installed skill of the same name exists to shadow it. Claude Code resolves skills personal-over-project — the reverse of its rule precedence — so a personal copy makes the project symlink inert.

**Result: 128 project-level lifecycle symlinks across 16 repos, every one of them inert. Zero live.** All eight PRD skills are installed personally at `~/.claude/skills/prd-*`, so every project symlink is shadowed. Decision 32's single-repo live test generalizes, and this is now measured rather than extrapolated.

### The consumer list is 16 repos, not 9

The nine repos the PRD names are confirmed exactly, and all nine point at `SKILL.v1-yolo.md`:

`cluster-whisperer`, `commit-story-v2`, `content-manager`, `kubecon-2026-gitops`, `KubeHound-Demo`, `project-signal-boost`, `scaling-on-satisfaction`, `spinybacked-orbweaver`, `spinybacked-orbweaver-eval`.

**Seven further repos symlink the interactive `SKILL.md` and appear in no list in the PRD:**

`ai-platform-demo-archive`, `commit_story`, `commit-story-v1`, `k8s-vectordb-sync`, `mcp-hello-world`, `spider-rainbows`, `telemetry-agent-research`.

Each carries all eight PRD skills, so the migration's sweep is 16 repos × 8 symlinks = 128, not 72. A migration scoped to the nine YOLO repos would leave 56 dangling symlinks in seven repos. This is exactly the gap the "enumerate every consumer" criterion exists to catch, and it was invisible to a search that looked only for YOLO symlinks.

**No repo symlinks any `issue-*` skill.** The issue family has no project-level consumers at all; it exists only as the personal install. Whatever C1 decides about that family's disposition, its migration cost is zero repos.

Five further repos have a `.claude/skills` directory with no lifecycle skills in it: `advocacy-skills`, `choose-your-ai-adventure`, `learning-center`, `slide-helper`, `websites-securitylabs`.

## 10. What this leaves for Milestone C1

Facts established here that C1 needs, and the questions this milestone deliberately did not answer:

- The consolidation target count is genuinely open. `prd-close` is identical across all three parties, `prds-get` is an identical pair and serves both families despite its name, and the six `issue-*` skills have no ancestor.
- `prd-done` was over the 5,000-token cap and was brought under it on 2026-09-04, but with under one percent of margin against an estimated token count. "Under 5,000 with real margin" is a hard constraint on the consolidation, not a preference, and the current state does not satisfy it.
- Divergence #7 is closed, not deferred: the Anki step is gone from both variants and lives in `/make-anki-cards`. Eighteen divergences remain for C1, not nineteen.
- The escalation contract's raw material is §7, including its boundary rule. Its current position — first content section — is validated by §8.
- Nineteen interactive/YOLO divergences were found and assessed. Eighteen remain undecided for C1; #7 was closed on 2026-09-04 when the Anki step was removed. Divergence #10 is the only one for which no trade-off could be identified on either side; C1 decides what follows from that.
- The extraction candidates in §6 are enumerated and counted; the CodeRabbit family spans all three implementations, and PROGRESS.md is the largest and has not yet drifted.
- The migration sweep is 16 repos and 128 symlinks, all inert.
- Live-testing every autonomous behavior promoted to the default path (Decision 33) does not belong here: this milestone promotes nothing and records no verdicts. It runs with C1's promotion decisions.
