# claude-config Load Findings

**Last Updated:** 2026-08-03
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

**Read the labels carefully — this is where the question went wrong for other people.** Imports come back as `include`, each carrying `parent_file_path: ~/.claude/CLAUDE.md`. Only the two root files carry `compact`. The mechanism is re-resolution: compaction re-reads the roots from disk, and expanding them pulls the imports along. Anyone filtering for `load_reason == "compact"` sees two files and concludes imports were dropped, which is the likeliest reading behind [issue #24460](https://github.com/anthropics/claude-code/issues/24460). The report was not fabricated; it was an artifact of the labeling.

**The negative control fired in the same run, and it is the more useful half.** `rules/datadog-mcp-gotchas.md` was live in context before the compaction, loaded via `path_glob_match` when `config/settings.json` was read to arm the probe. It produced **no** post-compaction record. A path-scoped rule that was in context is genuinely gone until its glob matches again — the docs' claim, now observed rather than trusted. `rules/README.md`, path-scoped earlier in this same milestone, also stayed absent, independently confirming finding 1's fix.

**Method, and three things that make it work.**

1. **The probe must be interactive.** `/compact` is not dispatchable in headless `claude -p`, so the throwaway-settings approach that worked for the `session_start` case cannot reach this one. Transcript mining is also a dead end: instruction content never appears in the transcript's message history, so re-injection happens entirely outside the logged record.
2. **Put the hook in `.claude/settings.local.json`.** It is gitignored, so no tracked file is mutated and the tracked-settings symlink defect does not apply. Back up the original first.
3. **Verify the probe is live before compacting.** Hooks added to `settings.local.json` take effect mid-session with no restart — itself a finding worth keeping. Confirm by reading a file that triggers a path-scoped rule and checking that the log grew. A dead probe costs the session's whole context for no data, and the session cannot be un-compacted.

**Consequence for the classification policy.** `@`-import is a durable mechanism, equivalent to an unscoped rule in both survival and cost. The trade-off stands as stated — durability is bought with always-loaded bytes — but it is now priced with a measurement instead of an assumption. Those bytes are paid in every session and re-paid after every compaction, so there is no hidden discount that would make the always-loaded set cheaper than the inventory says.

**Scope.** One run, one version (2.1.220), manual trigger only. Auto-compaction is documented as identical and prior auto-compactions in the transcript carry matching metadata structure, but it was not directly observed. Re-verify after a major version bump.
