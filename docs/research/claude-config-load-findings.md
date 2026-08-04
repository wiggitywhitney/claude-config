# claude-config Load Findings

**Last Updated:** 2026-08-04
**Produced for:** PRD #109 Milestone A2
**Measured against:** Claude Code 2.1.220, with issue #108 already merged

Hand-written. The measurements this reasons about live in [claude-config-load-inventory.md](claude-config-load-inventory.md), which `scripts/measure-context-load.sh` generates and overwrites. **No script writes to this file.** The split is deliberate: an earlier version kept generated tables and hand-written analysis in one file, where any re-run of the script would have destroyed the analysis — a coupled-pair defect created while auditing coupled-pair defects.

Platform behavior these findings depend on: [claude-code-context-loading-and-compaction.md](claude-code-context-loading-and-compaction.md).

---

## 1. `rules/README.md` loaded in every session, and the checker that should have caught it exempted it on a false premise — **fixed 2026-08-03**

> **Resolved.** The file now carries `paths: ["rules/**/*.md", "**/.claude/rules/**/*.md"]`, so it loads when someone is working on rules rather than in every session. The `check-rule-frontmatter.sh` exemption is removed and its test now asserts the opposite of what it asserted before. **Verified by re-running the `InstructionsLoaded` probe: `rules/README.md` no longer appears in a fresh session's load list at all**, where it previously appeared with `load_reason: session_start`. That is roughly 3,100 tokens off every session.
>
> Fixed here rather than deferred to the spec after Whitney applied the CodeRabbit triage rubric: the deferral reasons are a different repo, work needing its own milestone, merge-conflict risk, or blocked investigation, and this was none of them. "PRD scope" was effort dressed as principle.
>
> **Note for the design milestone:** this is an `assert` remedy, the weakest tier. The index still has to be maintained by hand alongside the rules it describes, so it can still drift in content even though it no longer leaks context. Michael reportedly has a *generated* rules table, which would be a `derive` remedy and would remove the second place entirely. The finding below is preserved as written because the reasoning still applies to that decision.

### Original finding, as measured before the fix

**Everything from here to the end of this section describes the pre-fix state and is retained as the evidence record.** It is not a description of how the repo behaves now — see the Resolved note above for that. Read every present-tense claim below as "as of the morning of 2026-08-03, before the fix landed."

**7,477 bytes, ~3.1k tokens, every session.** Confirmed three independent ways, all three measured pre-fix:

| Method | Evidence (pre-fix) |
|---|---|
| `scripts/measure-context-load.sh` | Classified `session_start` (bare) — no `paths:`, no `@`-reference |
| `InstructionsLoaded` hook | Reported `load_reason: session_start` for `claude-config/rules/README.md` |
| `/context` | Lists it under Memory files at 3.1k tokens |

The platform rule: *"Rules without a `paths` field are loaded unconditionally and apply to all files."*

`scripts/check-rule-frontmatter.sh` exempts it:

> `# rules/README.md is the human-facing index, not a rule. It is never loaded by`
> `# either mechanism, so holding it to the one-mechanism requirement is wrong.`

The second sentence is false. The premise of the exemption is what kept it false — the check that exists to enforce one loading mechanism was told to skip the one file that has the wrong one.

**This defeats Decision 6.** That decision moved the index out of `global/CLAUDE.md` precisely so it would stop costing tokens every session. `rules/README.md` opens by asserting the same benefit:

> *"It lives here rather than in `global/CLAUDE.md` because an index in `CLAUDE.md` costs tokens in every session, whether or not anyone needs it."*

The index moved from one always-loaded location to another and saved nothing. Three artifacts — the decision, the file's own first paragraph, and the checker's exemption comment — all record a benefit that was never delivered. An unusually clean instance of the pattern this audit is organized around, and the only one so far where a *check* is part of the pair.

**Original disposition, superseded the same day:** *"Not fixed here. This PRD produces a spec. The disposition belongs to the spec, and the checker and its bats tests belong to Milestone A4's review."* Overturned when Whitney applied the CodeRabbit triage rubric — see the Resolved note at the top of this section. **What remains open is only the `derive` follow-up**: replacing the hand-maintained index with a generated one, which is Milestone C1's call informed by Milestone B3. The unconditional load and the false checker exemption are both fixed.

## 2. Seven skills are estimated over the compaction truncation cap, and one more on the dense ratio

After a compaction an invoked skill body is re-injected **truncated to 5,000 tokens, keeping the start of the file**, with a 25,000-token total budget across all invoked skills and oldest dropped first.

| Skill | Bytes | Est. tokens | Status (estimated, not observed) |
|---|---:|---:|---|
| `anki` | 33,781 | ~12,064 | Over — more than double the cap |
| `anki-yolo` | 33,121 | ~11,828 | Over |
| `prd-done` | 25,130 | ~8,975 | Over |
| `prd-update-progress` | 17,336 | ~6,191 | Over |
| `write-prompt` | 14,671 | ~5,239 | Over |
| `write-docs` | 14,584 | ~5,208 | Over |
| `research` | 14,568 | ~5,202 | Over |
| `prd-next` | 13,468 | ~4,810 | At risk — over on the dense estimate |

Five of the eight are workflow skills whose **closing** steps are the ones estimated to fall past the cap: merge, cleanup, verification, commit. `prd-done`'s three-channel CodeRabbit fetch and merge sequence are estimated to sit in the region compaction would truncate. Stated as an estimate deliberately — the byte positions are measured, but where the 5,000-token boundary lands inside a given file is not, so which specific instructions get cut is inferred from the ratio rather than observed.

**Consequence for Milestone B4:** instruction order inside a `SKILL.md` is a correctness property, not a style preference. The generalized escalation contract belongs at the top of every consolidated file. Anything that must survive cannot be at the bottom.

**Correction to an earlier version of this finding.** It first reported three skills over the cap, using a bytes/4 token estimate. That understated tokens by roughly 30%. Recalibrating against real `/context` output moved the count to **seven over on both ratios, plus one over on the dense ratio only.**

**These remain estimates, not observations, and should not be restated as confirmed.** The ratio was calibrated against `/context` output for *memory files*; no per-skill tokenization was measured, so a skill near the boundary could fall either way. `prd-next` at ~4,810 on the prose ratio and ~5,611 on the dense one is exactly that case. Turning these into observations means invoking each skill and reading its token count from `/context`. The earlier version of this finding made the opposite mistake — presenting an estimate alongside measured byte counts, which made it look equally solid.

## 3. The always-loaded set is larger than the #108 baseline records

`~/Documents/Journal/CURRENT-CONTEXT.md` is `@`-referenced from `global/CLAUDE.md` and loads every session (~305 tokens). It is outside this repository, so #108's count of "11 `@`-referenced rule files" excludes it by construction and no sweep of `rules/` will ever find it.

**Implication for the byte budget:** count imports by *observed load*, from the `InstructionsLoaded` hook or `/context`, never by globbing a directory. A directory-scoped budget is guaranteed to understate the real total, and the amount it understates by is invisible.

## 4. The `@`-referenced set has grown 16% since #108, and one file is 46% of it

The 11 `@`-referenced rules now total 47,482 bytes against the 40,857 recorded at the #108 fix — a 6,625-byte increase in roughly one day.

The growth is real rather than a measurement artifact. `writing-voice.md` gained content in commits `39b180f` and `c640dd0`. At 21,825 bytes it is now the largest always-loaded file in the system and 46% of the `@`-referenced total by itself.

Worth stating plainly: `writing-voice.md` is also the file most likely to keep growing, because `global/CLAUDE.md` instructs that corrections be written into it immediately and without asking. That is a good rule with an unbudgeted cost, and it is the clearest available demonstration that **a budget without an automated check is a number in a document, not a constraint.**

---

## 6. Two rules carry both mechanisms, and neither the checker nor this inventory can see it — the project `CLAUDE.md` is unscanned

**Found 2026-08-04, from a CodeRabbit finding about untraversed import graphs. It makes the always-loaded figure in the inventory unreliable, so read it before quoting that number.**

`rules/hooks-reference.md` (6,951 bytes) and `rules/bats-bash-testing.md` (3,986 bytes) each carry `paths:` frontmatter **and** are `@`-referenced — from `claude-config/.claude/CLAUDE.md`, not from `global/CLAUDE.md`:

```text
.claude/CLAUDE.md:98  Full reference: @~/.claude/rules/hooks-reference.md
.claude/CLAUDE.md:103 Bats gotchas and patterns: @~/.claude/rules/bats-bash-testing.md
```

`~/.claude/rules` is a symlink to this repo's `rules/`, so those imports resolve to the very same files that carry the `paths:` frontmatter. That is the both-mechanisms case the repo's own rule forbids in as many words: *"must **not** also define `paths:`, which would load them twice."*

**Both tools that exist to catch this are blind to it, for the same reason.** `scripts/check-rule-frontmatter.sh` derives the `@`-referenced set by reading `global/CLAUDE.md` and only that file; `scripts/measure-context-load.sh` does the same. Neither knows a second `CLAUDE.md` also carries imports. So:

| | Reports | Actually |
|---|---|---|
| `check-rule-frontmatter.sh` | "All rules have exactly one loading mechanism." | Two rules have two |
| `claude-config-load-inventory.md` | Both `path_glob_match`, not loaded at startup, does not survive compaction | `@`-referenced from a loaded `CLAUDE.md` |

**This is the third instance of the audit's organizing pattern, and the second where a *check* is one half of the pair.** Finding 1 was a checker told to skip the one file that violated the rule. This is a checker whose definition of "the always-loaded set" comes from one file when the system has two. Both produce a confident pass over a real violation, which is worse than no check.

**What is *not* established: whether these two files actually double-load.** The compaction probe recorded the project `CLAUDE.md` returning with `load_reason: compact` but produced **no** `include` record for either import, while all twelve of `global/CLAUDE.md`'s imports did return as `include`. Three readings remain open and this evidence does not choose between them: project-level imports are not re-resolved after compaction the way user-level ones are; they load at `session_start` and the probe was installed too late to see it; or the import is not resolving at all. **Settling it needs one more probe-plus-compaction run** — the same method as finding 5, watching specifically for `parent_file_path` pointing at the project `CLAUDE.md`.

**Byte exposure:** 10,937 bytes, against the 63,619 the inventory recorded at the time. If they load, that figure is roughly **17% low**, and Milestone C1's byte budget would be set against a number wrong in the unsafe direction. (The recorded total has since been corrected to 70,228 for a separate reason — see finding 7.)

### Resolved 2026-08-04, and the repo had already made the call

Whitney chose to fix both scripts immediately. Doing so turned the invisible violation into a failing check that named the file to edit:

```text
FAIL  rules/bats-bash-testing.md: both @-referenced from .claude/CLAUDE.md and paths:-scoped — pick one
FAIL  rules/hooks-reference.md: both @-referenced from .claude/CLAUDE.md and paths:-scoped — pick one
```

**The per-file remedy then turned out not to be an open question at all.** `global/CLAUDE.md` already refers to both files — as backticked pointers carrying an explicit annotation:

> - Hook details (**reference pointer, not auto-loaded** — read only when a hook fires unexpectedly or you need to know what a specific hook checks): `~/.claude/rules/hooks-reference.md`
> - Bats gotchas and patterns (**reference pointer, not auto-loaded** — read only when writing or debugging a bash test suite): `~/.claude/rules/bats-bash-testing.md`

So the decision was made, written down, and stated twice — and `.claude/CLAUDE.md` contradicted it by importing the same two files for real. **This is the purest instance of the organizing pattern found so far:** not a decision that drifted out of date, but one recorded in two places where the two disagreed from the start, with no error surface to reveal it. The remedy was alignment with an existing decision rather than a new judgment, so it was applied directly: both imports in `.claude/CLAUDE.md` are now backticked pointers matching the global file's wording.

**Both scripts now scan two `CLAUDE.md` files — `global/CLAUDE.md` and `.claude/CLAUDE.md` — rather than one.** *(Corrected 2026-08-04: this said "every `CLAUDE.md`," which overstates it. A repo-root or nested `CLAUDE.md` picked up by directory traversal is still unscanned by both tools; neither is in use here today, so the gap is latent rather than a live undercount. Tracked as an open question on PRD #109.)* The checker names which file carries the reference, because "pick one" is not actionable when the reader does not know where the reference lives. Test coverage added to both suites, each written to fail first.

**The rule bytes were unchanged by this remedy, but the total was wrong for a second, independent reason — see finding 7.** Removing the stray imports restored the state the global file already described, so the two files stayed on-demand and the rules subtotal held at 63,619. Had the opposite remedy been chosen it would have been **74,556**. But the inventory was also omitting the project `CLAUDE.md`'s own 6,609 bytes, which are always-loaded in their own right. **The corrected always-loaded total is 70,228.**

**Still unresolved, and unaffected by this fix:** whether project-level `@`-imports are re-resolved after compaction at all. The probe produced no `include` record for either, and that question outlives the two files that raised it — any future project-level import inherits it. Tracked as an open question on the PRD, owned by Milestone A4.

---

## 7. The project `CLAUDE.md` was never counted — the always-loaded total is 70,228, not 63,619

**Found 2026-08-04, immediately after finding 6, and from the same blind spot.** Teaching the tools to *read* `.claude/CLAUDE.md` for imports did not make them *count* it. The inventory added `global/CLAUDE.md`'s bytes to the always-loaded total and silently omitted the project one, which is always-loaded in its own right — the compaction probe recorded it returning with `load_reason: compact`, exactly like the global file.

| Component | Files | Bytes |
|---|---:|---:|
| `global/CLAUDE.md` | 1 | 16,137 |
| `.claude/CLAUDE.md` | 1 | **6,609 — previously uncounted** |
| `@`-referenced rules | 11 | 47,482 |
| **Always-loaded total** | **13** | **70,228** |

Reported as its own row rather than folded into one figure, because the #108 baseline never included it and a merged number invites a comparison that does not hold.

**This is the third time the always-loaded set has turned out to be larger than the tooling said**, each time for a different reason: an unscoped index (finding 1), an import living outside the repository (finding 3), and now the project instructions file itself. The pattern is not carelessness about any one file — it is that **the measurement kept being built from a list of places someone remembered, rather than from the definition of what "always-loaded" means.** Milestone C1 should treat "is this derived or enumerated" as a standing question about every count this audit produces, and Milestone A4 should assume more of these exist.

**Consequence:** the byte budget is set against **70,228**, and the figure is 10.4% higher than what Milestone A2 reported for most of its life.

---

## Reconciliation against `/context` and `/memory`

Run by Whitney on 2026-08-03 in this repository. Required by Milestone A2, since neither command can be invoked by Claude.

**This is the pre-fix baseline.** It was captured before `rules/README.md` was scoped, which is why that file appears in the table below at 3.1k tokens. The post-fix verification is separate and is recorded in finding 1: a later probe in a fresh session showed the file absent from the load list entirely. The two results are a before and an after, not a contradiction — but re-running `/context` today would show 15 memory files rather than 16, and roughly 26.4k tokens rather than 29.5k.

### Memory files: 16 files, 29.5k tokens (pre-fix)

Every file the script and hook predicted appeared, with no extras and none missing. Per-file token counts sum to ~29.59k against the reported 29.5k, which is rounding.

| Reconciliation question | Answer |
|---|---|
| Does `rules/README.md` appear? | **Yes**, 3.1k tokens. Third independent confirmation of finding 1. Since fixed — it no longer appears |
| Does `CURRENT-CONTEXT.md` appear? | **Yes**, 305 tokens. Confirms finding 3 |
| Do the totals match the script? | Yes, once tokens are calibrated against bytes — see below |

### The one discrepancy, and what it corrected

The script originally estimated tokens at bytes/4. Real ratios from `/context`:

| File | Bytes | Reported tokens | Bytes per token |
|---|---:|---:|---:|
| `writing-voice.md` | 21,825 | 7,700 | 2.84 |
| `global/CLAUDE.md` | 16,137 | 5,800 | 2.78 |
| `git-workflow.md` | 9,975 | 3,600 | 2.77 |
| `rules/README.md` | 7,477 | 3,100 | 2.41 |

Prose sits near 2.8 bytes per token; table-heavy content reaches 2.4, tokenizing denser. The script now uses 2.8 as its estimate and 2.4 as a conservative worst case, with the calibration recorded in a comment beside the constants. This is what moved finding 2 from three skills to eight.

### What `/memory` added

`/memory` lists the `@`-referenced rules as **`L`** entries, each annotated "Saved in `~/.claude/CLAUDE.md`". So the platform models them as *imports belonging to* user CLAUDE.md rather than as independent memory files.

At the time this was written it was a data point rather than an answer: it made re-injection more plausible — if they are part of `~/.claude/CLAUDE.md`'s expansion, they would travel with it — but the docs' compaction table names "project-root CLAUDE.md" specifically and has no row for imports or for user-level CLAUDE.md.

**Finding 5 has since settled it by measurement, and `/memory`'s model turned out to be the right intuition.** Imports do travel with the parent, and the observed payloads make the relationship explicit through `parent_file_path`. Recorded here as the evidence that pointed the right way, not as an open question.

### Skill listing cost is only partly controllable from this repo

`/context` reports 44 skills at 3.3k tokens. The script sees only the 26 in this repo. Breakdown from `/context`:

| Source | Approx. tokens | Controllable here |
|---|---:|---|
| User skills (from claude-config) | ~1,210 | Yes |
| Built-in skills | ~1,500 | No |
| Plugin skills | ~370 | Only by disabling plugins |
| Project skills | ~120 | Yes |

**Roughly 40% of the startup skill listing is built-in and cannot be trimmed by any change to this repo.** A budget that targets total skill-listing tokens would be partly unachievable by construction. Budget the repo-controlled portion only.

---

## 5. `include` content **is** re-injected after compaction — measured 2026-08-03

This was the last open question gating the classification policy, and the answer is yes. Every always-loaded rule in this system arrives via `include`, so the durability of the whole always-loaded set turned on it.

**Result.** A manual `/compact` in a session with roughly 230k tokens of history produced 14 `InstructionsLoaded` records, all sharing one post-compaction `prompt_id`:

| File | `memory_type` | `load_reason` |
|---|---|---|
| `~/.claude/CLAUDE.md` | User | `compact` |
| `claude-config/.claude/CLAUDE.md` | Project | `compact` |
| The 11 `@`-referenced rules, plus `~/Documents/Journal/CURRENT-CONTEXT.md` | User | `include` |

**Read the labels carefully — this is where the question went wrong for other people.** Imports come back as `include`, each carrying `parent_file_path: ~/.claude/CLAUDE.md`. Only the two root files carry `compact`. The mechanism is re-resolution: the roots are re-injected and their imports are re-resolved through them. Whether that reads from disk or replays a cached expansion is not established — the payloads name the parent but not the source.

Anyone filtering for `load_reason == "compact"` sees two files and concludes imports were dropped, which is the likeliest reading behind [issue #24460](https://github.com/anthropics/claude-code/issues/24460). **Likeliest, not proven.** One manual compaction at 2.1.220 cannot establish what an older version did, so changed behavior remains equally consistent with the evidence. The labeling explanation is preferred because it requires no one to have erred, which is a reason to favor a hypothesis and not a reason to call the matter closed.

**The negative control fired in the same run, and it is the more useful half.** `rules/datadog-mcp-gotchas.md` was live in context before the compaction, loaded via `path_glob_match` when `config/settings.json` was read to arm the probe. It produced **no** post-compaction record. A path-scoped rule that was in context is genuinely gone until its glob matches again — the docs' claim, now observed rather than trusted. `rules/README.md`, path-scoped earlier in this same milestone, also stayed absent, independently confirming finding 1's fix.

**Method, and three things that make it work.**

1. **The probe must be interactive.** `/compact` is not dispatchable in headless `claude -p`, so the throwaway-settings approach that worked for the `session_start` case cannot reach this one. Transcript mining is also a dead end: instruction content never appears in the transcript's message history, so re-injection happens entirely outside the logged record.
2. **Put the hook in `.claude/settings.local.json`.** It is gitignored, so no tracked file is mutated and the tracked-settings symlink defect does not apply. Back up the original first.
3. **Verify the probe is live before compacting.** Hooks added to `settings.local.json` take effect mid-session with no restart — itself a finding worth keeping. Confirm by reading a file that triggers a path-scoped rule and checking that the log grew. A dead probe costs the session's whole context for no data, and the session cannot be un-compacted.

**Consequence for the classification policy.** `@`-import is a durable mechanism, equivalent to an unscoped rule in both survival and cost. The trade-off stands as stated — durability is bought with always-loaded bytes — but it is now priced with a measurement instead of an assumption. Those bytes are paid in every session and re-paid after every compaction, so there is no hidden discount that would make the always-loaded set cheaper than the inventory says.

**Scope.** One run, one version (2.1.220), manual trigger only. Auto-compaction is documented as identical and prior auto-compactions in the transcript carry matching metadata structure, but it was not directly observed. Re-verify after a major version bump.
