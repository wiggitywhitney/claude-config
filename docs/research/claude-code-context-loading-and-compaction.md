# Research: How Claude Code Loads Rules, Skills, and CLAUDE.md — and What Compaction Does to Each

**Project:** claude-config
**Last Updated:** 2026-08-04
**Claude Code version verified against:** 2.1.220 (read from `claude --version` on 2026-08-03)
**Produced for:** PRD #109 Milestone A2

## Update Log

| Date | Summary |
|------|---------|
| 2026-08-03 | Initial research. Extends `claude-code-autonomous-capabilities.md` (2026-05-31), which covered compaction but never mentioned `rules/` or `paths:` frontmatter. |
| 2026-08-04 | Scoped the measured `include` result to user-level imports. Project-level imports are untested — the project `CLAUDE.md` returned with `load_reason: compact` but produced no `include` record for either of its own two imports. Added managed-policy `CLAUDE.md` to the `session_start` row. Withdrew the `disable-model-invocation` recommendation, which described a behavior change as free. |
| 2026-08-03 | Resolved the open `@`-import question by direct measurement. Removed the Conflicting Findings section and replaced it with Resolved Questions carrying the captured payloads; corrected the `include` row of the load-reason table from "undetermined" to "yes"; narrowed recommendation 3 to the one fact still unmeasured. |

## Prior research this builds on

`docs/research/claude-code-autonomous-capabilities.md` (2026-05-31) covers compaction triggers, the `PreCompact`/`PostCompact` hooks, and a preserve/drop/re-inject list. That list is **correct but incomplete in a way that matters here**: it says "CLAUDE.md files" are re-injected without distinguishing project-root from nested, and it does not mention `rules/` files at all. Both distinctions are load-bearing for the classification policy, which Decision 34 assigns to Milestone C1. This document refines rather than replaces it.

---

## Summary

**For instruction files** — CLAUDE.md and `rules/*.md` — the loading mechanism alone determines whether content is re-injected after compaction. Importance and position are irrelevant, and so is size: an unscoped rule comes back whole no matter how large. There are five load reasons, and Claude Code names them itself: `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`.

**Skills are the exception, and it is a real one.** An invoked skill body is re-injected but *truncated* to 5,000 tokens from the bottom, so for skills both size and instruction order decide what survives — see finding 3. Do not carry the instruction-file rule over to skills.

The finding that drives the classification policy (Milestone C1): **`paths:`-scoped rules do not survive compaction.** They enter message history when their trigger file is read, so compaction summarizes them away like any other message. They return only when a matching file is read again. Meanwhile the mechanism that *is* durable — unscoped rules and `@`-imports — is exactly the always-loaded set issue #108 spent its effort shrinking.

So the classification policy is not choosing between good and bad mechanisms. It is pricing a real trade-off: **durability across compaction costs always-loaded bytes, and there is no mechanism that gives both.**

**Scope limit on the `@`-import half, stated here because this summary is what downstream work reads.** The durability result was measured for imports from `~/.claude/CLAUDE.md`. Imports from a *project* `.claude/CLAUDE.md` were not established by that run — the project root returned with `load_reason: compact` but produced no `include` record for either of its imports, which is consistent with three different explanations and settles none of them. Treat project-level import durability as unmeasured until a second probe runs; see the open question in the Resolved Questions section below. Milestone C1's byte budget depends on the answer, so an unqualified "`@`-imports are durable" read from this summary would put unmeasured bytes in a measured column.

---

## Surprises and Gotchas

**1. `@`-imports do not reduce context. This is stated outright, and it is the diagnosis of why PRD #43 missed its goal.** 🟢

**Source says:** "Splitting into `@path` imports helps organization but doesn't reduce context, since imported files load at launch." ([How Claude remembers your project](https://code.claude.com/docs/en/memory))

**Source also says:** "Imported files are expanded and loaded into context at launch alongside the CLAUDE.md that references them." (same page)

**Interpretation:** PRD #43 set out to shrink `global/CLAUDE.md` and shipped six extracted rule files that it then `@`-referenced back in. Per the primary source, that operation moves bytes between files and removes none from the always-loaded set. The PRD's own retrospective reached this conclusion; this is independent confirmation from the platform docs rather than inference from the outcome.

**2. `paths:`-scoped rules are lost at compaction. The docs say so in a table and then say it again in prose.** 🟢

**Source says:** "| Rules with `paths:` frontmatter | Lost until a matching file is read again |" ([Explore the context window](https://code.claude.com/docs/en/context-window))

**Source says:** "Path-scoped rules and nested CLAUDE.md files load into message history when their trigger file is read, so compaction summarizes them away with everything else. They reload the next time Claude reads a matching file. If a rule must persist across compaction, drop the `paths:` frontmatter or move it to the project-root CLAUDE.md." (same page)

**Interpretation:** This is the direct answer to the PRD's open question about which rules stay path-scoped. Path-scoping is correct for a rule whose relevance is genuinely bounded by the file being touched, and wrong for any rule that must hold for a whole session regardless of what gets read. The docs offer only two remedies and both cost always-loaded bytes.

**3. Invoked skill bodies are re-injected, but capped and truncated from the bottom.** 🟢

**Source says:** "| Invoked skill bodies | Re-injected, capped at 5,000 tokens per skill and 25,000 tokens total; oldest dropped first |" ([Explore the context window](https://code.claude.com/docs/en/context-window))

**Source says:** "Skill bodies are re-injected after compaction, but large skills are truncated to fit the per-skill cap, and the oldest invoked skills are dropped once the total budget is exceeded. Truncation keeps the start of the file, so put the most important instructions near the top of `SKILL.md`." (same page)

**Interpretation:** Directly actionable for the skill consolidation in Milestone B4. A long `SKILL.md` silently loses its tail after a compaction, so ordering inside the file is a correctness property, not a style preference. The escalation contract Milestone B4 plans to generalize belongs near the top of every file for this reason. Worth measuring whether any current skill exceeds 5,000 tokens.

**4. The skill *listing* is the one startup item that does not come back.** 🟢

**Source says:** "One-line descriptions of available skills so Claude knows what it can invoke. Full skill content loads only when Claude actually uses one. Skills with `disable-model-invocation: true` are not in this list. They stay completely out of context until you invoke them with `/name`. Unlike the rest of the startup content, this listing is not re-injected after `/compact`. Only skills you actually invoked get preserved." ([Explore the context window](https://code.claude.com/docs/en/context-window))

**Interpretation:** After a compaction, Claude loses awareness that uninvoked skills exist. This corroborates the prior research doc's version of the same finding. Practical consequence: a long session that compacts becomes progressively less likely to reach for a skill on its own.

**5. `disable-model-invocation: true` makes a skill cost zero context until typed — and `typed` is the catch, because it also stops the model invoking it.** 🟢

**Source says:** "Set `disable-model-invocation: true` on skills with side effects like committing, deploying, or sending messages. They stay out of context entirely until you need them." ([Explore the context window](https://code.claude.com/docs/en/context-window))

**Interpretation, corrected — this is not a free win, and an earlier version of this document wrongly said it was.** The byte reduction is real: the description leaves the startup listing entirely. But the flag does exactly what its name says — it **removes the model's ability to invoke the skill at all.** The skill becomes reachable only by a human typing `/name`. That is a behavior change, not a no-op.

**It conflicts directly with this repo's autonomy goal.** Decision 15 prioritizes autonomy and less oversight; the autonomous PRD loop is designed for Claude to reach `prd-update-progress` and `prd-done` on its own. Setting the flag on exactly those skills would break the loop, and the byte saving is small next to that. The trade is therefore per-skill and genuinely a decision rather than a cleanup:

- **Sound candidates:** skills that only ever make sense when a human deliberately starts them, where model invocation is unwanted anyway.
- **Wrong candidates:** any skill an autonomous run must reach by itself — which is most of the lifecycle set, and is why "the side-effect skills" was the wrong selection criterion. Side effects are the reason to *want* autonomous invocation of them, not to forbid it.

Flagging for **Milestone C1** as a decision with a real cost on both sides, not for Milestone A4 as an inventory item.

**6. There is a hook that reports exactly which instruction files load and why — including at compaction.** 🟢 (existence, load reasons, and — since this was first written — the payload schema)

**Source says:** "| `InstructionsLoaded` | When a CLAUDE.md or `.claude/rules/*.md` file is loaded into context. Fires at session start and when files are lazily loaded during a session |" ([Hooks reference](https://code.claude.com/docs/en/hooks))

**Source says:** "| `InstructionsLoaded` | load reason | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` |" (same page)

**Verified locally rather than taken on trust:** `strings` on the v2.1.220 binary contains `InstructionsLoaded` and all five load-reason values.

**Schema resolved 2026-08-03, after this section was first written.** The docs pages truncate before the JSON payload schema, so it was recorded here as unconfirmed. It has since been observed directly by registering the hook and capturing real payloads. Fields present on **every** record: `cwd`, `file_path`, `hook_event_name`, `load_reason`, `memory_type`, `session_id`, `transcript_path`, `prompt_id`. Additional fields appear **conditionally, keyed to the load reason** — `include` records carry `parent_file_path`, and `path_glob_match` records carry `globs` and `trigger_file_path`. **Treat this list as observed rather than complete**; other reasons may carry fields not yet seen, since only three of the five reasons have been captured. The two conditional groups matter in practice: `parent_file_path` is what makes import re-injection attributable to its parent, `trigger_file_path` names the file whose read pulled a scoped rule in, and `prompt_id` is what groups a compaction's records into one batch. Method and captured output in [claude-config-load-findings.md](claude-config-load-findings.md).

**Interpretation:** This is the right instrument for Milestone A2's load inventory. Decision 25 requires enumeration by re-runnable script rather than a model looking around, and this hook is the platform's own account of what loaded, which beats inferring mechanism from frontmatter. The `compact` matcher value also made the `@`-import question directly testable, and it is what settled it — see Resolved Questions below.

**7. A rule with no frontmatter loads at the same priority as `.claude/CLAUDE.md`.** 🟢

**Source says:** "Rules without `paths` frontmatter are loaded at launch with the same priority as `.claude/CLAUDE.md`." ([How Claude remembers your project](https://code.claude.com/docs/en/memory))

**Source says:** "Rules without a `paths` field are loaded unconditionally and apply to all files." (same page)

**Interpretation:** Confirms the #108 baseline was measuring a real cost, and confirms the repo's one-mechanism rule is the correct invariant. Nothing to change; recording it because the classification policy needs the fact stated.

**8. `/doctor` will now propose CLAUDE.md trims, and the trim heuristic is a good policy input.** 🟢

**Source says:** "Added a `/doctor` check that proposes trimming checked-in `CLAUDE.md` files by cutting content Claude could derive from the codebase" ([Changelog](https://code.claude.com/docs/en/changelog), v2.1.206)

**Source says:** "it cuts content Claude can derive from the codebase, such as directory layouts, dependency lists, and architecture overviews, and keeps pitfalls, rationale, and conventions that differ from tool defaults." ([How Claude remembers your project](https://code.claude.com/docs/en/memory))

**Interpretation:** Anthropic's own keep/cut line — cut what is derivable from the repo, keep what contradicts a default — is a sharper classification criterion than "is this important," and it is worth adopting into Milestone C1's policy rather than inventing one. `/doctor` is also a second measurement Whitney can run alongside `/context`, and it is available at 2.1.220.

**9. Re-invoking a loaded skill used to duplicate its instructions in context. Fixed at 2.1.202.** 🟢

**Source says:** "Fixed re-invoking an already-loaded skill appending a duplicate copy of its instructions to context" ([Changelog](https://code.claude.com/docs/en/changelog), v2.1.202)

**Interpretation:** Relevant only as a caveat on old measurements. Any context measurement taken before 2.1.202 may be inflated by duplicate skill bodies, so pre-#108 numbers taken during a skill-heavy session are not straightforwardly comparable. Does not affect the #108 baseline, which measured files on disk rather than a live session.

---

## Findings: the loading model

The five load reasons, from Claude Code's own matcher vocabulary, mapped to what produces each:

| Load reason | Produced by | Enters | Survives compaction |
|---|---|---|---|
| `session_start` | Managed-policy `CLAUDE.md`, `~/.claude/CLAUDE.md`, project `CLAUDE.md`, `CLAUDE.local.md`, and unscoped `rules/*.md` | Startup, outside message history | Yes, re-injected 🟢 — whether from disk or from cache was not measured; see Resolved Questions |
| `include` | `@path` imports expanded from **any** CLAUDE.md, user-level or project-level | Startup, alongside the referencing file | Yes for user-level imports 🟢 — measured, see Resolved Questions. **Project-level imports untested** — see the caveat below |
| `path_glob_match` | `rules/*.md` carrying `paths:` frontmatter | Message history, when a matching file is read | **No** 🟢 |
| `nested_traversal` | `CLAUDE.md` in a subdirectory below cwd | Message history, when a file in that subdirectory is read | **No** 🟢 |
| `compact` | Re-injection after a compaction event | Startup position | n/a — this *is* the re-injection |

**Caveat on the `include` row, added 2026-08-04.** The measurement covered imports from `~/.claude/CLAUDE.md` only. In the same capture, the project `CLAUDE.md` returned with `load_reason: compact` but produced **no** `include` records for its own two `@`-imports, while all twelve of the user-level imports did return. Whether project-level imports are re-resolved, load only at `session_start`, or fail to resolve at all is unsettled — see finding 6 in [claude-config-load-findings.md](claude-config-load-findings.md). Do not assume the user-level result generalizes to project-level imports.

Load order, broadest to most specific: managed policy, then user (`~/.claude/`), then project, then local. Rules follow the same shape — "User-level rules are loaded before project rules, giving project rules higher priority." ([memory docs](https://code.claude.com/docs/en/memory))

Size limits worth recording:

- CLAUDE.md: **"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."** No hard cap — "CLAUDE.md files are loaded in full regardless of length." 🟢
- `MEMORY.md`: first 200 lines or 25KB, whichever comes first. Hard cutoff; content past it is dropped on load. 🟢
- Skill bodies at compaction: 5,000 tokens per skill, 25,000 total. 🟢

One mechanism claim worth noting because it contradicts a common assumption: CLAUDE.md is **not** part of the system prompt. "CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself." 🟢 The genuine system-prompt-level mechanism is `--append-system-prompt`, which "must be passed every invocation, so it's better suited to scripts and automation than interactive use."

---

## Resolved Questions

### Whether `@`-imported files are re-injected after compaction — YES, measured

**Answer: they are re-injected.** Observed directly on 2026-08-03 at 2.1.220 by registering an `InstructionsLoaded` hook, running `/compact` in an interactive session with ~230k tokens of history, and reading every payload written after the compaction. All eleven `@`-referenced rule files reappeared, plus the `@`-referenced `CURRENT-CONTEXT.md`.

**The label is the trap.** The two root memory files reappear with `load_reason: compact`; their imports reappear with `load_reason: include` and a `parent_file_path` pointing back at the root. So the mechanism is *re-resolution* rather than a distinct compaction path: the roots are re-injected and their `@`-imports are re-resolved through them.

**Whether that re-resolution reads from disk or replays a cached expansion is not established here.** The payloads prove the records appear and name their parent; they say nothing about the source. The distinction matters in one practical case — editing a rule file mid-session and then compacting — so treat "picks up on-disk edits" as untested rather than implied. Filtering on `load_reason == "compact"` alone shows only the two roots and makes imports look dropped, which is the most likely origin of the issue #24460 report.

Captured evidence, one line per file, trimmed to the fields that matter (all share the single post-compaction `prompt_id`):

```json
{"file_path":"~/.claude/CLAUDE.md","memory_type":"User","load_reason":"compact"}
{"file_path":"…/claude-config/.claude/CLAUDE.md","memory_type":"Project","load_reason":"compact"}
{"file_path":"~/.claude/rules/writing-voice.md","load_reason":"include","parent_file_path":"~/.claude/CLAUDE.md"}
{"file_path":"~/.claude/rules/git-workflow.md","load_reason":"include","parent_file_path":"~/.claude/CLAUDE.md"}
```

…and ten more `include` records: `testing-rules`, `gh-fork-gotchas`, `issue-juggling`, `infrastructure-safety`, `datadog-environment`, `vals-secrets`, `aboutme-headers`, `adopting-new-technologies`, `macos-image-processing`, plus `~/Documents/Journal/CURRENT-CONTEXT.md`. Twelve `include` records in total — the eleven `@`-referenced rules and the one `@`-referenced file outside this repository.

**The same run confirmed the negative case, which is the stronger half of the result.** `rules/datadog-mcp-gotchas.md` was in context before the compaction — loaded via `path_glob_match` when `config/settings.json` was read — and produced **no** post-compaction record. A path-scoped rule that was live is genuinely gone until its glob fires again. `rules/README.md`, newly path-scoped in this same PRD, likewise did not return, confirming that fix.

**Scope of the claim.** This was a manual `/compact`. Auto-compaction is documented as behaving identically and the payload structure of prior auto-compactions in the transcript matches, but only the manual trigger was observed. The measurement is one run at one version; the mechanism (re-resolution of the root file) is stable enough to rely on, but re-verify after a major version bump.

**Consequence for the classification policy:** tier 4 buys what it claims. `@`-import is a durable mechanism, indistinguishable from an unscoped rule in both cost and survival. The trade-off in this document's summary stands unchanged — durability still costs always-loaded bytes — but the eleven rules Whitney deliberately made always-loaded are in fact always loaded.

### Prior state of this question (retained for provenance)

Before the measurement, the evidence pointed three ways and mattered more than any other open point here, because **all eleven of Whitney's always-loaded rule files reach context through `@`-reference**, not as unscoped rules.

- **The official compaction table does not list imports at all.** Its rows are "Project-root CLAUDE.md and unscoped rules," "Auto memory," "Rules with `paths:` frontmatter," "Nested CLAUDE.md," "Invoked skill bodies," and "Hooks." ([context window docs](https://code.claude.com/docs/en/context-window)) Neither `include` nor "user-level CLAUDE.md" appears as a row.
- **A secondary source infers survival from the loading mechanism:** because imports are "expanded and loaded into context at launch," they are part of the startup bundle and return with it. Presented explicitly as inference — "The docs don't state this word-for-word for user-level files specifically, so treat it as an inference from the loading mechanism rather than an explicit guarantee."
- **[Issue #24460](https://github.com/anthropics/claude-code/issues/24460)** reports the opposite in practice, that CLAUDE.md contents get summarized along with conversation history after `/compact`. The issue is marked stale and was filed against an older version.

**How it resolved:** the secondary source's inference was right, and the docs' omission of an `include` row from the compaction table is a real gap rather than a signal.

**What this does *not* establish is that issue #24460 was wrong.** One manual compaction at 2.1.220 says what the platform does now; it says nothing about what an older version did. Three readings remain open and the evidence here does not choose between them: the behavior changed between that version and this one; the reporter read `load_reason: compact` as the complete re-injection list and saw two files where twelve more were arriving under a different label; or something about that setup differed. The labeling trap is the explanation that requires no error on anyone's part, which is why it is the most likely — not because the report has been disproved.

**Method note worth keeping.** The test only works interactively. `/compact` is not dispatchable in headless `claude -p`, and transcript mining cannot answer it either — instruction content never appears in the transcript's message history at all, so re-injection happens outside the logged record. A passive `InstructionsLoaded` hook plus a human running `/compact` is the only instrument that reaches this. Hooks added to `settings.local.json` take effect mid-session with no restart, which is what makes the passive approach practical.

---

## Recommendation

Three things follow directly from the findings and are worth carrying into the classification policy:

1. **Treat compaction durability as a purchased property, not a default.** The only durable mechanisms cost always-loaded bytes. A rule earns those bytes by being one that would cause a wrong action if it vanished mid-session; everything else path-scopes and accepts reloading on trigger. This gives the policy a single discriminating question instead of a taste judgment.

2. **Adopt Anthropic's trim line rather than inventing one:** cut what Claude can derive from the codebase, keep pitfalls, rationale, and conventions that differ from tool defaults. It is more decidable than "is this important," and `/doctor` applies the same heuristic, so the policy and the tooling agree.

3. **Measure before deciding.** Two facts the policy depended on were unverified. The first — whether `@`-imports survive compaction — is now measured **for imports from `~/.claude/CLAUDE.md` only: those do** (see Resolved Questions). **Project-level imports from `.claude/CLAUDE.md` were not tested by that run and remain unmeasured.** State the limit wherever this result is used: Milestone C1's byte budget rests on it, and 10,937 bytes of rule content hangs on the untested half, so the budget must record that portion as an assumption rather than an observation. The second, whether any `SKILL.md` exceeds the 5,000-token truncation cap, remains an *estimate* from `scripts/measure-context-load.sh` rather than a confirmed reading; the byte-to-token ratio is calibrated against one `/context` sample, so files near the cap could fall either side of it.

**No free win here, contrary to an earlier version of this document.** `disable-model-invocation: true` does remove a skill's description from every session's startup listing, but it also removes the model's ability to invoke that skill — leaving it reachable only by a human typing `/name`. Recommending it for "the side-effect lifecycle skills" was backwards: those are precisely the skills an autonomous run has to reach on its own, and Decision 15 prioritizes autonomy. Milestone C1 decides it per skill, weighing bytes against reachability. See finding 5.

---

## Caveats

- Verified against **2.1.220** only. Several findings are version-gated (`/doctor` trim at 2.1.206, symlink glob matching at 2.1.198, brace-expansion budget at 2.1.217, duplicate-skill fix at 2.1.202), so any of this is wrong for an older install.
- The `InstructionsLoaded` payload schema **was** unconfirmed when this document was first written and has since been observed directly — see finding 6. Field names are now known.
- `InstructionsLoaded` does not appear anywhere in the visible changelog, so its introduction version is unknown. Present at 2.1.220.
- The changelog page truncated at 2.1.179, so older entries were not checked.
- The `include` compaction result rests on a single manual `/compact` at 2.1.220. Auto-compaction was not directly observed. Re-verify after a major version bump.
- Docs pages for hooks truncated before the per-event schemas. The load-reason table was recoverable; the payload examples were not.

---

## Sources

- [Explore the context window](https://code.claude.com/docs/en/context-window) — the "What survives compaction" table, the startup load timeline, skill-body caps, and the skill-listing exception. Primary source for most findings here.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) — `paths:` frontmatter semantics, unscoped-rule priority, the statement that imports do not reduce context, CLAUDE.md size targets, `MEMORY.md` limits, and the `InstructionsLoaded` debugging tip.
- [Hooks reference](https://code.claude.com/docs/en/hooks) — `InstructionsLoaded` firing conditions and its five load-reason matcher values; `PreCompact` can block on exit 2, `PostCompact` cannot.
- [Changelog](https://code.claude.com/docs/en/changelog) — version gates for `/doctor` trim (2.1.206), symlink rule matching (2.1.198), brace-expansion budget (2.1.217), duplicate skill instructions (2.1.202), nested-rules setting-source fix (2.1.211).
- [Issue #24460](https://github.com/anthropics/claude-code/issues/24460) — user report that CLAUDE.md is summarized rather than re-injected; stale, older version, recorded as a conflicting data point.
- Local binary inspection, `claude --version` and `strings`, 2026-08-03 — confirmed `InstructionsLoaded` and all five load reasons present at 2.1.220.
