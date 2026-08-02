# claude-config Audit & Redesign — Running Decision Log

Live record of decisions made while scoping the claude-config audit. Appended to as decisions are made, **not** reconstructed at the end. This file is the raw material for the eventual spec file, and the checklist an audit agent verifies the PRD against.

Started 2026-08-02. Source conversation transcript: `~/.claude/projects/-Users-whitney-lee-Documents-Repositories-claude-config/a32b6735-ae87-47d4-9fdf-5cdbe24805a9.jsonl`

---

## Decisions

> **Numbering here is local to this file and does not match the PRD's Decision Log IDs.** `prds/109-claude-config-audit-redesign.md` is authoritative for decision numbering; cross-reference by decision text, never by number. Two hand-maintained numbering schemes across two files is the same "one decision, two places" failure mode this audit keeps finding — the redesign should replace both with stable slugs rather than integers.

| # | Decision | Rationale |
|---|---|---|
| 1 | The goal is a workflow that is current with what AI can actually do now, and a joy to use — wise, efficient, happy, productive. | Explicitly **not** driven by the You Choose Episode 1 deadline, and unrelated to the house-hunting research spike. Both were considered and ruled out as framing. |
| 2 | This PRD is **audit → decide → spec**. Its deliverable is a spec file, not an implementation. | The outcome is unknown at the start. Writing implementation acceptance criteria before the research would either pre-commit to an answer or produce criteria too vague to fail. |
| 3 | The spec spawns one or more separate implementation PRDs. | "Fix rule loading," "rebuild the permission model," and "adopt parallel agent workflows" have little in common beyond the repo. Forcing them into one PRD would create the cross-PRD tangle the repo's own rules warn against. |
| 4 | **100% human decides.** Claude presents findings and a recommendation, asks one question at a time, and never decides ahead of Whitney. Written into the PRD's process section. | She has to live inside this workflow daily. A decision made for her is one she never evaluated, and it silently becomes load-bearing. Overrides YOLO mode for genuine choices; YOLO still applies to executing decisions already made. |
| 5 | The **PRD is written first**; issue #108 is executed after it. #108 is a blocking dependency of the PRD's implementation, not a prerequisite for writing it. | The scoping conversation is decision-dense and should be captured while fresh. #108 is fully specified and can be executed at any point before implementation begins. Doing #108 first was considered and rejected. |
| 5a | When #108 is started, it must be started with the `/issue-start` skill. | Consistency with the repo's own lifecycle skills; ad-hoc execution already caused rework once on `/issue-create`. |
| 6 | The "reference pointer" index is removed from `global/CLAUDE.md` entirely and reproduced at `rules/README.md`. No shortened version stays behind. | Once every rule is correctly path-scoped the index does nothing functional, and it is the exact artifact that drifted out of sync with reality for four months. |
| 7 | The parallel-work problem (tmux, Netcup, multiple concurrent agents) **is in scope** of the research and the spec. | Named in the 2026-08-02 morning pages as the change most likely to affect how the day feels, and it overlaps directly with Viktor's swarm roles. |
| 8 | Permission and auto-approval friction is in scope of the PRD, out of scope of #108. | Diagnosed but not yet solved — needs research plus evidence mining, unlike #108 which is fully specified. |
| 9 | The `/issue-*` skills are a named workstream in the spec, updated after the `/prd-*` skills. | Seven `prd-*` and six `issue-*` skills are near-parallel implementations of the same lifecycle. Nothing enforces that a change to one mirrors into the other. |
| 10 | The audit must leave room for findings native to this repo, not only findings derived from Viktor's or Michael's setups. | Named examples: the git hook collection likely contains removable and consolidatable hooks; general cleanup across the repo. |
| 11 | Falling back to the current way of working must remain possible. The spec records what stays intact under every scenario. | Stated requirement — the new system may not pan out. |
| 12 | Decisions are logged to this file continuously, and an audit agent verifies the finished PRD against both this file and the raw session transcript. | The scoping conversation is long and decision-dense; compaction summarizes lossily. The transcript persists on disk regardless of compaction, so late reconstruction is possible — but a running log is cheaper and catches drift earlier. |
| 14 | Every PRD milestone declares a required **Model**. Claude reads the session model at milestone start, proceeds silently on a match, and stops to ask Whitney to switch on a mismatch — then re-reads the environment to verify rather than accepting her word. Judgment milestones require the strongest model; retrieval milestones run on whatever is active and delegate bulk reading to Sonnet subagents. | Claude cannot invoke `/model`; it is user-typed, so a self-executing directive is impossible. Verification beats confirmation because Whitney's managed settings pin Sonnet 5 on restart — the wrong model is the default, not the exception. Per-milestone model and effort are not expressible in the current PRD skills at all; logged as a redesign finding. |
| 15 | **Prioritize autonomy.** Whitney wants less oversight of Claude, not more. Where the audit must choose between an autonomous and an interactive pattern, autonomous wins by default; take best practices from both, but the confirmation-gated version is the exception, not the base. | Stated guiding principle, 2026-08-02. Note this does **not** conflict with decision 4 — she decides the *shape of the system*, and then wants that system to run with less babysitting. Design authority stays human; runtime supervision goes down. |
| 17 | The skill-variant problem is split in two: issue #110 fixes only the two live bugs and the `/make-careful` gap now; the actual sixteen-to-eight consolidation happens in PRD #109 M5, after M4. | Stopping the bleeding is cheap and reaches all nine repos through one source file. The real merge needs a judgment call per divergence and a scripted migration, and it should be designed once — after Viktor's swarm findings, since his roles solve the same escalation problem at larger scale. Hand-mirroring fixes into both files as an ongoing practice was explicitly rejected: four months of it produced two bugs and a false statement in global `CLAUDE.md`. |
| 16 | The escalation contract — explicit proceed-when and stop-when criteria, as in `prd-next`'s Autonomous Decision Protocol — must be generalized to every lifecycle skill. | It exists in exactly one of sixteen skill files. Autonomy without a crisp escalation contract is unsupervised guessing, not autonomy. Higher-value than any individual bug fix in the skill set. |
| 13 | **Whitney decides policies, not instances.** Where a change touches many files, Claude proposes a single rule covering all of them; she approves or edits the rule, and Claude applies it mechanically. She does not want per-file or per-instance approval. | Decision 4 (human decides) is about control over what the system becomes, not over mechanical execution. Per-instance approval is miserable at scale and buries the actual choice. Applies to #108's glob assignment and to every later bulk change. |

## Findings that shaped the plan

- **GitHub issue #21858 does not affect this setup.** Verified by live test on 2026-08-02: reading a `.sh` file loaded `hooks-reference.md` and `rules/languages/shell.md` on demand. Path-scoped rules in `~/.claude/rules/` work. The premise the original plan was built on is dead.
- **Measured context leak:** 19 bare rule files = 96,637 bytes (~24k tokens) per session; 5 files double-loaded via both `@`-reference and `paths:`; 3 of those scoped `["**/*"]` and re-injected on every file read. Baseline for #108.
- **Approval friction is not an allowlist problem, and it is not a single problem.** At least two distinct trigger classes were observed during scoping, each with a different reason string and a different remedy:
  - `Contains simple_expansion` — any shell expansion (`$var`, `$(...)`, backticks, `for` loops) makes Claude Code stop trying to match the allowlist at all. The command name is never evaluated, so no allowlist entry can fix it.
  - `Compound command contains cd with output redirection - manual approval required to prevent path resolution bypass` — a hard security rule against `cd X && ... > file`, independent of the allowlist and independent of expansion.

  Both examples were caused by Claude writing needlessly clever one-liners when purpose-built tools were available — the second one immediately after Claude had described the discipline that would have prevented it. M3 must build a full taxonomy of trigger classes from real session data rather than assuming one cause, and must separate "settings can fix this" from "only changed behavior can fix this."
- **The existing Michael research is stale.** `docs/research/michael-forrester-workflow.md` and `docs/research/michael-autonomous-execution-principles.md` describe a workflow he has since changed, and the clone at `~/Documents/Repositories/forrester-workflow` is only part of his current setup. The Michael spike (PRD M6) is a fresh spike, not a validation pass, and the existing docs are updated as part of it. Whitney has additional repos to supply.
- **Existing related research:** `docs/research/prd-workflow-principles.md`, `docs/research/claude-code-autonomous-capabilities.md`.
- **There are three parallel implementations of one lifecycle, not two.** Each of the 8 `prd-*` skill directories contains both a `SKILL.md` (interactive) and a `SKILL.v1-yolo.md` (autonomous) — 1,807 lines of shadow implementation. `/make-autonomous` symlinks `.claude/skills/prd-*/SKILL.md` to the repo's `SKILL.v1-yolo.md` per project, so which set is live depends on invisible per-project state. Add the 6 `issue-*` skills and that is three families maintained by hand.
- **The drift is real and has already shipped a bug.** Through April 2026 each pair was updated in a single commit. Since June they have diverged: the `prd-update-progress` `--no-color` fix landed in `SKILL.md` on 2026-06-04 and reached the YOLO variant on 2026-06-15, eleven days later as a separate commit. The `prd-done` three-channel CodeRabbit fetch (2026-06-16) **never reached the YOLO variant at all** — verified by grep. Autonomous mode therefore still uses the old single-channel fetch and silently misses CodeRabbit findings, in the exact mode where no human is watching.
- **The YOLO symlinks are installed in nine repos**, all eight PRD-lifecycle skills each — the seven matching `prd-*` plus `prds-get`, which does not match that glob — since 2026-03-04: `cluster-whisperer`, `kubecon-2026-gitops`, `spinybacked-orbweaver`, `spinybacked-orbweaver-eval`, `project-signal-boost`, `KubeHound-Demo`, `commit-story-v2`, `content-manager`, `scaling-on-satisfaction`. These are permanent symlinks, not a mode toggle — project skills shadow global ones, so in those repos the YOLO variant is what runs every time, interactive session or not. None of those repos has `make-careful` installed, so there is no supported way to revert.
- **The divergence runs in both directions, and has produced a bug on each side.** The `prd-done` pair is not "one neglected copy" — each file has content the other lacks:
  - *Interactive only:* the three-channel CodeRabbit fetch and the re-review loop; richer Anki scope (whole-PRD sourcing, dedupe scan against existing cards).
  - *YOLO only:* acceptance-gate detection and the `run-acceptance` label (step 3.6b); safer requirement execution (classify read-only / mutating / external, auto-execute only read-only); `prd-loop-continue` hook detection; autonomous CodeRabbit triage.

  Consequence: global `CLAUDE.md` states that `/prd-done` adds the `run-acceptance` label automatically. That is **only true in the YOLO variant.** In claude-config itself — which uses the interactive skills — the documented behavior does not happen. So each path silently violates a different documented guarantee.
- **Only `prd-next` has real behavioral divergence; the other seven pairs differ mainly in the `description:` frontmatter.** `prd-next` YOLO is 184 lines against 302 interactive, replacing context-detection ceremony with an explicit **Autonomous Decision Protocol** — proceed-when and stop-when criteria. That protocol is the mechanism that makes reduced oversight safe, and it currently exists in exactly one of sixteen files. Generalizing it is higher-value than any individual bug fix.
- **`~/.claude/settings.json` is a symlink into the repo, so Claude Code writes through it into tracked files.** It points at `claude-config/config/settings.json`. On 2026-08-02 the working tree showed an uncommitted change from `"model": "opus[1m]"` to `"model": "sonnet[1m]"` — the managed-settings Sonnet pin written straight into a tracked repo file. Committing without noticing would make the weaker model the repo's committed default and propagate it to any machine bootstrapped from this repo. Two findings for M7: tooling can silently rewrite tracked config through symlinks, and the model default lives in a file nobody reviews.
- **`/make-careful` is not symlinked into `~/.claude/skills/` but `/make-autonomous` is.** Autonomy can be switched on from any repo and switched off only where the skill happens to be installed.
- **Hook inventory:** 14 Claude Code hooks (5 PreToolUse, 7 PostToolUse, 1 SessionStart, 1 PostCompact) plus native git hooks in `hooks/git/`, with an existing `hooks/archive/`.

## Open questions

- Should `/issue-*` and `/prd-*` collapse into one lifecycle with two entry points, or stay two families?
- Which specific rules stay rules, which move to `CLAUDE.md` or hooks for durability, and which become on-demand skills?
- Global versus project-level skills — Viktor's position is "never global." Does that hold once #21858 is ruled out?
- Is there a sandbox or permission-mode setting that eliminates the `simple_expansion` prompt class outright?
- How many implementation PRDs should the spec produce, and in what order?
- Which additional Michael repos should be cloned beyond `llm-coding-workflow`?
- Which git hooks can be removed or consolidated?

## Discarded, recorded here so it is not re-discovered

`stash@{2}` (PRD 24, March 2026) contained an alternate `.mcp.json` wiring for the CodeRabbit MCP server. It was **not** recovered and the stash was dropped on 2026-08-02. Recorded in case the question comes back:

```json
"coderabbitai": {
  "command": "vals",
  "args": ["exec", "-i", "-f", ".vals.yaml", "--", "/opt/homebrew/bin/npx", "coderabbitai-mcp@latest"]
}
```

Rejected because the current `npx` + `${GITHUB_PAT}` configuration works (the CodeRabbit MCP tools are live), `datadog-mcp-gotchas.md` argues against wrapping MCP servers in `vals exec`, and the hardcoded `/opt/homebrew/bin/npx` is fragile across machines.

## Open threads

Live commitments made in conversation that have no other home. Delete a line only when it is genuinely done, not when it is merely discussed.

- [x] Apply CodeRabbit findings 1–4 on PR #111 — done 2026-08-02
- [x] Add the #8 corrections to `git-workflow.md` — done 2026-08-02, backed by a scratch-repo reproduction
- [x] Inspect and empty all three stashes; drop them — done 2026-08-02. Three journal files recovered across them, one requiring a merge rather than an overwrite
- [x] Repair the pre-push CodeRabbit hook, which had been failing on removed v0.7.0 flags and exiting 0 — done 2026-08-02
- [ ] CodeRabbit re-review on PR #111, then merge and delete the branch locally and remotely
- [ ] Start #108 with `/issue-start` (rule-loading defects)
- [ ] Start #110 with `/issue-start` (interactive/autonomous `prd-done` drift)
- [ ] Supply the M1 repo list: confirm Viktor's three, name Michael's additional repos
- [x] Carry the "one decision, two places" theme into the spec — done 2026-08-02. **Stated once, in the PRD**, as the decision row on the organizing principle plus the `## Coupled pairs` and `## Decisions` requirements in M8's output format. Deliberately **not** restated here: copying it into both files would create precisely the pair it describes. Read it in `prds/109-claude-config-audit-redesign.md`.

## Repos to examine

| Owner | Repo | Status |
|---|---|---|
| Viktor | `https://github.com/vfarcic/dot-agent-deck` — swarm roles, `.dot-agent-deck.toml`, and PRD skills in `.claude/skills/` | Not yet cloned |
| Viktor | `https://github.com/vfarcic/dot-ai-infra` — permanent cluster | Not yet cloned |
| Viktor | `https://github.com/vfarcic/dot-ai` — skill distribution into projects | Not yet cloned, needs confirmation |
| Michael | `llm-coding-workflow` | Cloned at `~/Documents/Repositories/forrester-workflow` — stale, needs re-pull |
| Michael | Additional repos | Whitney to supply |
