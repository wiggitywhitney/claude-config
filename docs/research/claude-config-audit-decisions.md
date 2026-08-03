# claude-config Audit & Redesign — Running Decision Log

Live record of decisions made while scoping the claude-config audit. Appended to as decisions are made, **not** reconstructed at the end. This file is the raw material for the eventual spec file, and the checklist an audit agent verifies the PRD against.

Started 2026-08-02. Source: the claude-config scoping session of 2026-08-02, recorded in the local Claude Code session transcript directory for this project. The absolute path and session identifier are deliberately not recorded here — the PRD's redaction rule forbids writing personal paths into tracked files, and this line violated it. Resolve the transcript by date from the local session directory.

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

  **Resolved by #108 on 2026-08-02.** Re-measuring the same 19 files at the pre-fix commit gives 96,671 bytes, 34 more than the recorded 96,637 — the files drifted slightly between the original measurement and the fix. The recorded baseline stands; the 34-byte gap is noted rather than reconciled, since no conclusion turns on it.

  | Always-loaded surface | Before | After |
  |---|---|---|
  | `global/CLAUDE.md` | 19,377 | 16,137 |
  | 11 `@`-referenced rule files | 40,310 | 40,857 |
  | 19 bare rule files | 96,671 | 0 |
  | **Total** | **156,358** | **56,994** |

  A 99,364-byte reduction, about 64%, or roughly 25k tokens per session. All five double-loaded rules shed their now-redundant frontmatter, yet the `@`-referenced set still grew by 547 bytes on net. Four of the five shrank — `datadog-environment.md` by 158 bytes, `git-workflow.md` by 121, `infrastructure-safety.md` by 201, `issue-juggling.md` by 106, totalling 586 — while the fifth, `adopting-new-technologies.md`, grew by 1,133 because it also gained the frontmatter requirement that prevents the defect from recurring. Eliminating `paths: ["**/*"]` on three files also stops re-injection on every file read — a real saving that this table does not capture, because it scales with how many files a session touches rather than being a fixed per-session cost.
- **Approval friction is not an allowlist problem, and it is not a single problem.** At least two distinct trigger classes were observed during scoping, each with a different reason string and a different remedy:
  - `Contains simple_expansion` — any shell expansion (`$var`, `$(...)`, backticks, `for` loops) makes Claude Code stop trying to match the allowlist at all. The command name is never evaluated, so no allowlist entry can fix it.
  - `Compound command contains cd with output redirection - manual approval required to prevent path resolution bypass` — a hard security rule against `cd X && ... > file`, independent of the allowlist and independent of expansion.
  - `This command changes directory before running git, which can execute untrusted hooks from the target directory` — a distinct security rule against `cd X && git ...`, with no redirection involved. Avoidable entirely by using `git -C <path>`.

  - **Filesystem path access** — a Bash command touching a directory the project has not granted prompts, offering "always allow access to `<dir>/` from this project." Observed for `/tmp/` (writing scratch files) and `research/` (reading a file with `sed`). This class is about *where* the command touches rather than how it is written, and it is the only one with a one-time permanent grant offered in the prompt itself.

    **Important correction to an earlier claim here:** this class was initially recorded as untouched by the command-shape discipline. That is wrong. The path check applies to **Bash**, not to the Read, Grep, and Glob tools — so the "use dedicated tools instead of shell invocations" clause does prevent it for every read. Both observed instances came from reaching for `sed` or a shell redirect where a tool existed. What the discipline does *not* cover is genuine writes to scratch directories, which is where the permanent grant is the right answer.

  The first three observed classes were triggered by Claude writing compound one-liners when single-purpose calls or dedicated tools were available; the fourth was not. That a fourth class with an entirely different mechanism appeared within an hour of the first three is direct evidence that three observations were not a survey — the permissions milestone must mine full history rather than extrapolating from what happened to be noticed. **Current observed mitigation — not a proven-complete one: never `cd` inside a Bash call, always `git -C <path>`, no `&&` chains, and use Read/Glob/Grep instead of `ls`/`cat`/`grep` shell invocations.** That covers the three **command-shape** classes outright, and covers the path-access class for reads — because the path check applies to Bash and not to the Read, Grep, and Glob tools. It does not cover genuine writes to scratch directories, where accepting the one-time grant the prompt offers is the right answer. A general remedy is pending the permissions milestone. Whether further classes exist is unknown until that milestone mines full session history and produces the frequency-ranked taxonomy — four observations are not a survey either. That this had to be relearned three times in one session is itself evidence for the audit: guidance Claude has written down and agreed to still loses to habit within the same conversation, which is an argument for enforcement over documentation.

  Both examples were caused by Claude writing needlessly clever one-liners when purpose-built tools were available — the second one immediately after Claude had described the discipline that would have prevented it. M3 must build a full taxonomy of trigger classes from real session data rather than assuming one cause, and must separate "settings can fix this" from "only changed behavior can fix this."

  **Further instances observed 2026-08-02 during work on #110/#108.** Both are additional evidence for the path-access class, and one extends its documented boundary:

  - `printf '\n' >> .claude/skills/prd-update-decisions/SKILL.v1-yolo.md && tail -c 20 ... | xxd | tail -2` — prompted with "Claude requested permissions to write to `<path>`, but you haven't granted it yet," offering "always allow access to `prd-update-decisions/` from this project." **This is a write to an ordinary tracked project file, not a scratch directory.** The **Important correction** paragraph in the filesystem path-access bullet above scopes the uncovered remainder of this class to "genuine writes to scratch directories" — that scoping is too narrow. Bash writes to *any* not-yet-granted path inside the project prompt as well. The sharper statement: the path check applies to Bash and not to Read/Grep/Glob for reads, and not to Edit/Write for writes. Edit calls against files in that same directory ran unprompted in the same session, seconds earlier. So the dedicated-tools clause does cover this instance too — the remedy was `Edit`, not a shell redirect — and the genuinely uncovered remainder is narrower still: writes to paths where no Edit/Write equivalent applies.
  - `cd <skills-dir> && for d in prd-close prd-create ...; do echo ...; diff -u ...; done` — a `cd` plus `for`-loop plus `&&` chain, hitting the `cd` rule and `Contains simple_expansion` at once. Preventable by `git -C`-style absolute paths and one call per item, which is the already-recorded discipline. Counts as a recurrence, not a new class.

  **Two further trigger classes surfaced later in the same session, neither reducible to the four above:**

  - **Unallowlisted command inside a pipeline, no reason string at all.** `git ls-tree -r -l HEAD rules/ | awk '{print $4, $5}' | sort` prompted with the bare text "This command requires approval" and offered "don't ask again for: `awk '{print $4, $5}'`". The `awk` script is single-quoted, so no shell expansion occurs and this is *not* `simple_expansion` — the check is evaluating each command in the pipeline separately and `awk` is not allowlisted. Two instances observed. Distinguishing feature: the offered grant is keyed to the **exact literal script text**, so it is worthless for any awk invocation that differs by a character. This is the one class where growing the allowlist plausibly does help, but only at the command level (`awk`, `sort`), never at the argument level.
  - **`Contains command_substitution` — a separate reason string from `Contains simple_expansion`.** `git cat-file -s $(git rev-parse HEAD:global/CLAUDE.md)` produced `command_substitution`, not `simple_expansion`. The earlier entry above folded `$(...)` into the `simple_expansion` class; that is wrong, they are reported distinctly. Whether they share a remedy is unknown. Avoidable here by running the two commands separately.

  A **seventh** class appeared later the same day: `sed command contains operations that require explicit approval (e.g., write commands, execute commands)`, fired by `git show <ref>:<path> | sed -n '/## Open Threads/,$p'`. That script contains no `w` or `e` command — it is purely a print range — so the checker is conservative about sed scripts in general rather than parsing them for write operations. The remedy is the existing dedicated-tools clause: use Read rather than piping through sed. This is the third class whose remedy is "stop reaching for a shell one-liner when a tool exists," which strengthens the case that the discipline is the highest-leverage single change.

  Seven classes are now observed, up from four, and three of the seven were found only because someone happened to screenshot the prompt. **This is the strongest available argument for M3's evidence-mining approach over any amount of careful reasoning about what Claude Code probably checks.**

  Recurrence count is now the useful signal: the command-shape discipline has been written down, agreed to, and then violated again in a *later session* than the one that produced it — five separate times within this one session, across `for` loops, `cd` chains, and shell redirects. M3 should treat "documented but not enforced" as the null hypothesis and design for enforcement.
- **Interactive/YOLO divergence survey (all eight PRD skill pairs — the seven `prd-*` skills plus `prds-get` — 2026-08-02).** Produced by issue #110 so M5 can start from it rather than rediscovering it. Every pair was diffed with `diff -u SKILL.md SKILL.v1-yolo.md`. *Intentional* means an autonomy difference that should persist; *accidental* means a fix that failed to mirror.

  | Pair | Divergence | Class | Disposition |
  |---|---|---|---|
  | `prd-done` | YOLO fetched only `/pulls/{n}/comments`, and only as a suggestion; interactive requires all three CodeRabbit channels | accidental | fixed in #110 — three-channel block plus the empty-result ambiguity note ported to YOLO |
  | `prd-done` | Interactive has a post-fix re-review loop; YOLO had none, so it could merge without re-checking after pushing fixes | accidental | fixed in #110 — re-review bullet with rate-limit `@coderabbitai review` trigger added to YOLO |
  | `prd-done` | Step 3.6b acceptance-gate detection and the `run-acceptance` label existed only in YOLO | accidental | fixed in #110 — 3.6b and the four-way label matrix ported to interactive |
  | `prd-done` | Step 2.5 gap handling: interactive stops and asks the user; YOLO implements the missing work and re-runs the agent | intentional | left as is |
  | `prd-done` | Step 3.4: interactive proposes and asks for confirmation; YOLO auto-fills | intentional | left as is |
  | `prd-done` | Step 3.5: interactive asks before executing template requirements; YOLO auto-executes read-only checks and gates mutating ones | intentional | left as is |
  | `prd-done` | Step 4.0: interactive uses `/anki` with a full-PRD scan and duplicate check; YOLO uses `/anki-yolo` capped at 5 cards | intentional | left as is |
  | `prd-done` | Step 4.1 triage: interactive defers to user decision; YOLO does autonomous triage | intentional | left as is |
  | `prd-done` | YOLO has a `prd-loop-continue` Hook Detection section | intentional | left as is — loop-specific |
  | `prd-create` | Acceptance Gate Label Reminder section existed only in YOLO | accidental | fixed in #110 — ported to interactive |
  | `prd-create` | YOLO stages `docs/ROADMAP.md` but dropped `- Added to ROADMAP.md ([timeframe] section)` from its own commit-message template | accidental | fixed in #110 — bullet restored |
  | `prd-create` | Interactive presents a numbered Option 1 / Option 2 next-step choice; YOLO always commits and pushes | intentional | left as is |
  | `prd-close` | Interactive asks the user to confirm closure and asks for implementation evidence; YOLO gathers evidence from context and git history | intentional | left as is |
  | `prd-next` | YOLO is a near-total rewrite: Autonomous Decision Protocol, 9 steps collapsed to 8, implementation driven rather than user-driven, `/clear` loop | intentional | left as is — this is the file M5 plans to generalize as the escalation contract |
  | `prd-start` | YOLO auto-invokes `/prd-next`; interactive stops and instructs the user to run it | intentional | left as is |
  | `prd-start` | Emoji stripped from YOLO headings (`## Progress Log ✅` → `## Progress Log`, `🚀` dropped) | intentional | left as is — consistent stylistic choice across YOLO variants |
  | `prd-update-decisions` | YOLO auto-detects the target PRD; interactive asks | intentional | left as is |
  | `prd-update-decisions` | YOLO file had no trailing newline | accidental | fixed in #110 |
  | `prd-update-progress` | YOLO applies updates directly, skips the confirmation step, and compresses the next-step messages | intentional | left as is |
  | `prd-update-progress` | YOLO states "Do NOT push after committing" more strongly and explains why | intentional | left as is |
  | `prds-get` | none — `diff -q` reports the files identical | — | — |

  Every divergence classified accidental was fixed in #110; none were deferred to a tracking issue.

- **The existing Michael research is stale.** `docs/research/michael-forrester-workflow.md` and `docs/research/michael-autonomous-execution-principles.md` describe a workflow he has since changed, and the clone at `~/Documents/Repositories/forrester-workflow` is only part of his current setup. The Michael spike (PRD M6) is a fresh spike, not a validation pass, and the existing docs are updated as part of it. Whitney has additional repos to supply.
- **Existing related research:** `docs/research/prd-workflow-principles.md`, `docs/research/claude-code-autonomous-capabilities.md`.
- **There are three parallel implementations of one lifecycle, not two.** Each of the 8 `prd-*` skill directories contains both a `SKILL.md` (interactive) and a `SKILL.v1-yolo.md` (autonomous) — 1,807 lines of shadow implementation. `/make-autonomous` symlinks `.claude/skills/prd-*/SKILL.md` to the repo's `SKILL.v1-yolo.md` per project, so which set is live depends on invisible per-project state. Add the 6 `issue-*` skills and that is three families maintained by hand.
- **The drift is real and has already shipped a bug.** Through April 2026 each pair was updated in a single commit. Since June they have diverged: the `prd-update-progress` `--no-color` fix landed in `SKILL.md` on 2026-06-04 and reached the YOLO variant on 2026-06-15, eleven days later as a separate commit. The `prd-done` three-channel CodeRabbit fetch (2026-06-16) **never reached the YOLO variant at all** — verified by grep. Autonomous mode therefore still uses the old single-channel fetch and silently misses CodeRabbit findings, in the exact mode where no human is watching.
- **The YOLO symlinks are installed in nine repos**, all eight PRD-lifecycle skills each — the seven matching `prd-*` plus `prds-get`, which does not match that glob — since 2026-03-04: `cluster-whisperer`, `kubecon-2026-gitops`, `spinybacked-orbweaver`, `spinybacked-orbweaver-eval`, `project-signal-boost`, `KubeHound-Demo`, `commit-story-v2`, `content-manager`, `scaling-on-satisfaction`. These are permanent symlinks, not a mode toggle — project skills shadow global ones, so in those repos the YOLO variant is what runs every time, interactive session or not. None of those repos has `make-careful` installed, so there is no supported way to revert.
- **The divergence runs in both directions, and has produced a bug on each side.** The `prd-done` pair is not "one neglected copy" — each file has content the other lacks:
  - *Interactive only:* the three-channel CodeRabbit fetch and the re-review loop; richer Anki scope (whole-PRD sourcing, dedupe scan against existing cards).
  - *YOLO only:* acceptance-gate detection and the `run-acceptance` label (step 3.6b); safer requirement execution (classify read-only / mutating / external, auto-execute only read-only); `prd-loop-continue` hook detection; autonomous CodeRabbit triage.

  Consequence: global `CLAUDE.md` states that `/prd-done` adds the `run-acceptance` label automatically. That is **only true in the YOLO variant.** In claude-config itself — which uses the interactive skills — the documented behavior does not happen. So each path silently violates a different documented guarantee.
- **Superseded 2026-08-02 by the full survey above, which found six accidental divergences rather than the two bugs known when this was written.** The original note read: two pairs have confirmed behavioral divergence — `prd-done` and `prd-next` — and the remaining six were not examined beyond line counts, which showed differences of 3–23 lines each; do not read that as "no divergence." That caution was well founded. The six break down as three in `prd-done`, two in `prd-create`, and one in `prd-update-decisions`. `prd-done` differs by only five lines and still hid four intentional behavioral differences alongside its three accidental ones, and diffing the other six pairs in full turned up the remaining three. The line-count heuristic would have missed every one of those three. `prd-next` YOLO is 184 lines against 302 interactive, replacing context-detection ceremony with an explicit **Autonomous Decision Protocol** — proceed-when and stop-when criteria. That protocol is the mechanism that makes reduced oversight safe, and it currently exists in exactly one of sixteen files. Generalizing it is higher-value than any individual bug fix.
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
- **Deferred, with Whitney's lean recorded:** is `vfarcic/dot-ai-infra` (his permanent cluster) in scope? Her position on 2026-08-02 — she has no established need for persistent infrastructure, and the You Choose demo that might justify one is explicitly out of scope for this PRD. Revisit only if the Viktor spike shows the swarm depends on cluster-side components, which would make it a prerequisite rather than a curiosity.
- What is `vfarcic/dot-ai` actually for, beyond distributing skills into projects? Unknown as of 2026-08-02, and deliberately not guessed at — M4 establishes it.
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
- [x] PR #111 merged 2026-08-02 after seven CodeRabbit rounds (9, 4, 2, 2, 8, 1, 0 findings); branch deleted locally and remotely; the three recovered journal files verified present on `main` at `9cec6f9` before deletion
- [x] Reference repos recorded — Viktor's three confirmed, Michael's primary confirmed by him directly, plus a two-stage selection method for his remaining repos and `wiggitywhitney/claude-personal` added to scope. All of it lives in M1 of the PRD; this table below is a snapshot, not the selection
- [x] **#110 and #108 — done 2026-08-02.** Worked together on one branch rather than sequentially, which turned out to be the right call: both touch `setup.sh` and the `prd-done` skills, so splitting them would have created the conflict the original ordering note was trying to avoid. Results are recorded above — the divergence survey and the before/after measurement. Two corrections to the notes as originally written: the bare-file count was 19, not 20 (`gog-cli-gotchas.md` was already in the list of 19), and re-measuring those files at the pre-fix commit gives 96,671 bytes rather than the recorded 96,637
- [ ] Both issues carry a model gate: confirm Opus 5 before starting, and stop and ask if the session is on anything else. Managed settings pin Sonnet 5 on restart, so a fresh session defaults to the wrong model
- [x] Carry the "one decision, two places" theme into the spec — done 2026-08-02. **Stated once, in the PRD**, as the decision row on the organizing principle plus the `## Coupled pairs` and `## Decisions` requirements in M8's output format. Deliberately **not** restated here: copying it into both files would create precisely the pair it describes. Read it in `prds/109-claude-config-audit-redesign.md`.

## Repos to examine

| Owner | Repo | Status |
|---|---|---|
| Viktor | `https://github.com/vfarcic/dot-agent-deck` — his current setup. `.dot-agent-deck.toml` describes his agent-swarm roles for a project and is what he says he now relies on heavily; current skills in `.claude/skills/` | Confirmed 2026-08-02, not yet cloned |
| Viktor | `https://github.com/vfarcic/dot-ai` — how he distributes skills into each project, and the probable origin of the `prd-*` skills Whitney forked. Broader purpose unknown — establish it, do not assume | Confirmed 2026-08-02, not yet cloned |
| Viktor | `https://github.com/vfarcic/dot-ai-infra` — his permanent cluster | Confirmed 2026-08-02, not yet cloned. **Scope unresolved** — see open questions |
| Michael | `peopleforrester/llm-coding-workflow` — his workflow system: own `claude-config/`, `netcup-*`, `wsl2-specific/naruto/`, `tasks.yaml`, `PROJECT_STATE.md`, `decisions.md` | Cloned and **pulled current 2026-08-02** (HEAD `418cd9f`, 500 commits since the prior clone). 52 MB, 702 files, 11 PRDs |
| Michael | `peopleforrester/claude-dotfiles` — production-ready Claude Code configurations, skills, templates; updated 2026-07-29 | Candidate, awaiting Whitney's confirmation |
| Michael | `peopleforrester/Brain_spec_skills_claude` — Claude Code skills for spec-driven development | Candidate, awaiting confirmation |
| Michael | `observe-claude-code`, `mcp_best_practices`, `agentic-covenants`, `MCP_Server_Claude_Doc_monitor`, `copilot-cli-enterprise-patterns`, `Webinar_Claude_Code_Hands_On` | Pass the subject filter as of 2026-08-02; 20 public repos total, roughly nine qualify |

> **This table is a snapshot, not the selection.** M1 re-runs the enumeration and applies the subject filter fresh; its result supersedes these rows. Do not treat a repo's absence here as a decision to skip it.
