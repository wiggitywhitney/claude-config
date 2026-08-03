# claude-config Load Findings

**Last Updated:** 2026-08-03
**Produced for:** PRD #109 M2
**Measured against:** Claude Code 2.1.220, with issue #108 already merged

Hand-written. The measurements this reasons about live in [claude-config-load-inventory.md](claude-config-load-inventory.md), which `scripts/measure-context-load.sh` generates and overwrites. **No script writes to this file.** The split is deliberate: an earlier version kept generated tables and hand-written analysis in one file, where any re-run of the script would have destroyed the analysis — a coupled-pair defect created while auditing coupled-pair defects.

Platform behavior these findings depend on: [claude-code-context-loading-and-compaction.md](claude-code-context-loading-and-compaction.md).

---

## 1. `rules/README.md` loads in every session, and the checker that should catch it exempts it on a false premise

**7,477 bytes, ~3.1k tokens, every session.** Confirmed three independent ways:

| Method | Evidence |
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

**Not fixed here.** This PRD produces a spec. The disposition belongs to the spec, and the checker and its bats tests belong to M7's review.

## 2. Eight skills exceed or approach the compaction truncation cap

After a compaction an invoked skill body is re-injected **truncated to 5,000 tokens, keeping the start of the file**, with a 25,000-token total budget across all invoked skills and oldest dropped first.

| Skill | Bytes | Est. tokens | Status |
|---|---:|---:|---|
| `anki` | 33,781 | ~12,064 | Over — more than double the cap |
| `anki-yolo` | 33,121 | ~11,828 | Over |
| `prd-done` | 25,130 | ~8,975 | Over |
| `prd-update-progress` | 17,336 | ~6,191 | Over |
| `write-prompt` | 14,671 | ~5,239 | Over |
| `write-docs` | 14,584 | ~5,208 | Over |
| `research` | 14,568 | ~5,202 | Over |
| `prd-next` | 13,468 | ~4,810 | At risk — over on the dense estimate |

Five of the eight are workflow skills whose **closing** steps get cut: merge, cleanup, verification, commit. `prd-done`'s three-channel CodeRabbit fetch and merge sequence sit in exactly the region that becomes unreachable in a compacted session.

**Consequence for M5:** instruction order inside a `SKILL.md` is a correctness property, not a style preference. The generalized escalation contract belongs at the top of every consolidated file. Anything that must survive cannot be at the bottom.

**Correction to an earlier version of this finding.** It first reported three skills over the cap, using a bytes/4 token estimate. That understated tokens by roughly 30%. Recalibrating against real `/context` output moved the count from three to eight. The original figure was an unevidenced estimate presented alongside measured byte counts, which made it look equally solid; it was not.

## 3. The always-loaded set is larger than the #108 baseline records

`~/Documents/Journal/CURRENT-CONTEXT.md` is `@`-referenced from `global/CLAUDE.md` and loads every session (~305 tokens). It is outside this repository, so #108's count of "11 `@`-referenced rule files" excludes it by construction and no sweep of `rules/` will ever find it.

**Implication for the byte budget:** count imports by *observed load*, from the `InstructionsLoaded` hook or `/context`, never by globbing a directory. A directory-scoped budget is guaranteed to understate the real total, and the amount it understates by is invisible.

## 4. The `@`-referenced set has grown 16% since #108, and one file is 46% of it

The 11 `@`-referenced rules now total 47,482 bytes against the 40,857 recorded at the #108 fix — a 6,625-byte increase in roughly one day.

The growth is real rather than a measurement artifact. `writing-voice.md` gained content in commits `39b180f` and `c640dd0`. At 21,825 bytes it is now the largest always-loaded file in the system and 46% of the `@`-referenced total by itself.

Worth stating plainly: `writing-voice.md` is also the file most likely to keep growing, because `global/CLAUDE.md` instructs that corrections be written into it immediately and without asking. That is a good rule with an unbudgeted cost, and it is the clearest available demonstration that **a budget without an automated check is a number in a document, not a constraint.**

---

## Reconciliation against `/context` and `/memory`

Run by Whitney on 2026-08-03 in this repository. Required by M2, since neither command can be invoked by Claude.

### Memory files: 16 files, 29.5k tokens

Every file the script and hook predicted appeared, with no extras and none missing. Per-file token counts sum to ~29.59k against the reported 29.5k, which is rounding.

| Reconciliation question | Answer |
|---|---|
| Does `rules/README.md` appear? | **Yes**, 3.1k tokens. Third independent confirmation of finding 1 |
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

This is a data point for the open question below, not an answer to it. It makes re-injection more plausible — if they are part of `~/.claude/CLAUDE.md`'s expansion, they would travel with it — but the docs' compaction table names "project-root CLAUDE.md" specifically and has no row for imports or for user-level CLAUDE.md. Recorded as evidence, still unresolved.

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

## Open question that gates the classification policy

**Whether `include` content is re-injected after compaction. Still unresolved.**

Every always-loaded rule in this system arrives via `include`. The official compaction table has rows for "Project-root CLAUDE.md and unscoped rules" and for `paths:`-scoped rules, but **no row for imports and no row for user-level CLAUDE.md**. So the durability of the entire always-loaded set is unverified.

Evidence so far, none of it conclusive:

- `/memory` treats imports as belonging to `~/.claude/CLAUDE.md` — mildly favors re-injection.
- Imports are "expanded and loaded into context at launch," and startup content is what gets re-injected — favors re-injection by inference.
- [Issue #24460](https://github.com/anthropics/claude-code/issues/24460) reports CLAUDE.md being summarized rather than re-injected. Stale, older version.

**The method to settle it is known and cheap:** the same `InstructionsLoaded` hook with matcher `compact` will name every file that re-enters context after a compaction. It needs a session long enough to actually compact, which the probe deliberately was not.

Until it is run, no part of the classification policy should assume either answer. The stakes are concrete: if imports are not re-injected, then the eleven rules deliberately made always-loaded are absent for the remainder of every compacted session, and the durability half of the whole keep-as-rule-versus-move-to-CLAUDE.md trade-off is illusory.
