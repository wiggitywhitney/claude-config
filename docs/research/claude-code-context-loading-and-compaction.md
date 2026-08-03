# Research: How Claude Code Loads Rules, Skills, and CLAUDE.md — and What Compaction Does to Each

**Project:** claude-config
**Last Updated:** 2026-08-03
**Claude Code version verified against:** 2.1.220 (read from `claude --version` on 2026-08-03)
**Produced for:** PRD #109 M2

## Update Log
| Date | Summary |
|------|---------|
| 2026-08-03 | Initial research. Extends `claude-code-autonomous-capabilities.md` (2026-05-31), which covered compaction but never mentioned `rules/` or `paths:` frontmatter. |

## Prior research this builds on

`docs/research/claude-code-autonomous-capabilities.md` (2026-05-31) covers compaction triggers, the `PreCompact`/`PostCompact` hooks, and a preserve/drop/re-inject list. That list is **correct but incomplete in a way that matters here**: it says "CLAUDE.md files" are re-injected without distinguishing project-root from nested, and it does not mention `rules/` files at all. Both distinctions are load-bearing for M2's classification policy. This document refines rather than replaces it.

---

## Summary

Loading mechanism determines compaction survival, and nothing else does. Importance, position, and file size are irrelevant. There are five load reasons, and Claude Code names them itself: `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact`.

The finding that drives M2's policy: **`paths:`-scoped rules do not survive compaction.** They enter message history when their trigger file is read, so compaction summarizes them away like any other message. They return only when a matching file is read again. Meanwhile the mechanism that *is* durable — unscoped rules and `@`-imports — is exactly the always-loaded set issue #108 spent its effort shrinking.

So the classification policy is not choosing between good and bad mechanisms. It is pricing a real trade-off: **durability across compaction costs always-loaded bytes, and there is no mechanism that gives both.**

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

**Interpretation:** Directly actionable for the skill consolidation in M5. A long `SKILL.md` silently loses its tail after a compaction, so ordering inside the file is a correctness property, not a style preference. The escalation contract M5 plans to generalize belongs near the top of every file for this reason. Worth measuring whether any current skill exceeds 5,000 tokens.

**4. The skill *listing* is the one startup item that does not come back.** 🟢

**Source says:** "One-line descriptions of available skills so Claude knows what it can invoke. Full skill content loads only when Claude actually uses one. Skills with `disable-model-invocation: true` are not in this list. They stay completely out of context until you invoke them with `/name`. Unlike the rest of the startup content, this listing is not re-injected after `/compact`. Only skills you actually invoked get preserved." ([Explore the context window](https://code.claude.com/docs/en/context-window))

**Interpretation:** After a compaction, Claude loses awareness that uninvoked skills exist. This corroborates the prior research doc's version of the same finding. Practical consequence: a long session that compacts becomes progressively less likely to reach for a skill on its own.

**5. `disable-model-invocation: true` makes a skill cost literally zero context until typed.** 🟢

**Source says:** "Set `disable-model-invocation: true` on skills with side effects like committing, deploying, or sending messages. They stay out of context entirely until you need them." ([Explore the context window](https://code.claude.com/docs/en/context-window))

**Interpretation:** This is a free byte reduction the repo is not currently using, and it applies cleanly to the lifecycle skills — `prd-done`, `prd-update-progress`, `issue-done` and similar all have side effects and are always invoked deliberately by name. Setting it removes their descriptions from the startup listing at no behavioral cost. Flagging for M2's policy and M7's skills inventory.

**6. There is a hook that reports exactly which instruction files load and why — including at compaction.** 🟢 (existence and load reasons) / 🟡 (payload schema)

**Source says:** "| `InstructionsLoaded` | When a CLAUDE.md or `.claude/rules/*.md` file is loaded into context. Fires at session start and when files are lazily loaded during a session |" ([Hooks reference](https://code.claude.com/docs/en/hooks))

**Source says:** "| `InstructionsLoaded` | load reason | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` |" (same page)

**Verified locally rather than taken on trust:** `strings` on the v2.1.220 binary contains `InstructionsLoaded` and all five load-reason values. The docs pages truncate before the full JSON payload schema, so the exact field names are not yet confirmed — that part is 🟡 and should be settled by registering the hook and reading one real payload.

**Interpretation:** This is the right instrument for M2's load inventory. Decision 25 requires enumeration by re-runnable script rather than a model looking around, and this hook is the platform's own account of what loaded, which beats inferring mechanism from frontmatter. The `compact` matcher value also makes the open question in the Conflicting Findings section below directly testable.

**7. A rule with no frontmatter loads at the same priority as `.claude/CLAUDE.md`.** 🟢

**Source says:** "Rules without `paths` frontmatter are loaded at launch with the same priority as `.claude/CLAUDE.md`." ([How Claude remembers your project](https://code.claude.com/docs/en/memory))

**Source says:** "Rules without a `paths` field are loaded unconditionally and apply to all files." (same page)

**Interpretation:** Confirms the #108 baseline was measuring a real cost, and confirms the repo's one-mechanism rule is the correct invariant. Nothing to change; recording it because the classification policy needs the fact stated.

**8. `/doctor` will now propose CLAUDE.md trims, and the trim heuristic is a good policy input.** 🟢

**Source says:** "Added a `/doctor` check that proposes trimming checked-in `CLAUDE.md` files by cutting content Claude could derive from the codebase" ([Changelog](https://code.claude.com/docs/en/changelog), v2.1.206)

**Source says:** "it cuts content Claude can derive from the codebase, such as directory layouts, dependency lists, and architecture overviews, and keeps pitfalls, rationale, and conventions that differ from tool defaults." ([How Claude remembers your project](https://code.claude.com/docs/en/memory))

**Interpretation:** Anthropic's own keep/cut line — cut what is derivable from the repo, keep what contradicts a default — is a sharper classification criterion than "is this important," and it is worth adopting into M2's policy rather than inventing one. `/doctor` is also a second measurement Whitney can run alongside `/context`, and it is available at 2.1.220.

**9. Re-invoking a loaded skill used to duplicate its instructions in context. Fixed at 2.1.202.** 🟢

**Source says:** "Fixed re-invoking an already-loaded skill appending a duplicate copy of its instructions to context" ([Changelog](https://code.claude.com/docs/en/changelog), v2.1.202)

**Interpretation:** Relevant only as a caveat on old measurements. Any context measurement taken before 2.1.202 may be inflated by duplicate skill bodies, so pre-#108 numbers taken during a skill-heavy session are not straightforwardly comparable. Does not affect the #108 baseline, which measured files on disk rather than a live session.

---

## Findings: the loading model

The five load reasons, from Claude Code's own matcher vocabulary, mapped to what produces each:

| Load reason | Produced by | Enters | Survives compaction |
|---|---|---|---|
| `session_start` | `~/.claude/CLAUDE.md`, project `CLAUDE.md`, `CLAUDE.local.md`, and unscoped `rules/*.md` | Startup, outside message history | Yes, re-injected from disk 🟢 |
| `include` | `@path` imports expanded from a CLAUDE.md | Startup, alongside the referencing file | Undetermined — see Conflicting Findings 🟡 |
| `path_glob_match` | `rules/*.md` carrying `paths:` frontmatter | Message history, when a matching file is read | **No** 🟢 |
| `nested_traversal` | `CLAUDE.md` in a subdirectory below cwd | Message history, when a file in that subdirectory is read | **No** 🟢 |
| `compact` | Re-injection after a compaction event | Startup position | n/a — this *is* the re-injection |

Load order, broadest to most specific: managed policy, then user (`~/.claude/`), then project, then local. Rules follow the same shape — "User-level rules are loaded before project rules, giving project rules higher priority." ([memory docs](https://code.claude.com/docs/en/memory))

Size limits worth recording:

- CLAUDE.md: **"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."** No hard cap — "CLAUDE.md files are loaded in full regardless of length." 🟢
- `MEMORY.md`: first 200 lines or 25KB, whichever comes first. Hard cutoff; content past it is dropped on load. 🟢
- Skill bodies at compaction: 5,000 tokens per skill, 25,000 total. 🟢

One mechanism claim worth noting because it contradicts a common assumption: CLAUDE.md is **not** part of the system prompt. "CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself." 🟢 The genuine system-prompt-level mechanism is `--append-system-prompt`, which "must be passed every invocation, so it's better suited to scripts and automation than interactive use."

---

## Conflicting Findings

### Whether `@`-imported files are re-injected after compaction

This is unresolved and it matters more than any other open point here, because **all eleven of Whitney's always-loaded rule files reach context through `@`-reference**, not as unscoped rules. If `include` content is not re-injected, the eleven rules that were deliberately made always-loaded are absent for the remainder of every compacted session, and the repo's whole loading strategy rests on an untested assumption.

- **The official compaction table does not list imports at all.** Its rows are "Project-root CLAUDE.md and unscoped rules," "Auto memory," "Rules with `paths:` frontmatter," "Nested CLAUDE.md," "Invoked skill bodies," and "Hooks." ([context window docs](https://code.claude.com/docs/en/context-window)) Neither `include` nor "user-level CLAUDE.md" appears as a row.
- **A secondary source infers survival from the loading mechanism:** because imports are "expanded and loaded into context at launch," they are part of the startup bundle and return with it. Presented explicitly as inference — "The docs don't state this word-for-word for user-level files specifically, so treat it as an inference from the loading mechanism rather than an explicit guarantee."
- **[Issue #24460](https://github.com/anthropics/claude-code/issues/24460)** reports the opposite in practice, that CLAUDE.md contents get summarized along with conversation history after `/compact`. The issue is marked stale and was filed against an older version.

**Interpretation:** The docs' silence is not evidence either way, and the inference is plausible but unverified. Per this PRD's rule that claims carry their evidence, the honest position is that **we do not currently know**, and no part of M2's policy should assume durability for `@`-imported rules until it is measured.

**This is cheaply testable and should be tested, not reasoned about.** Register an `InstructionsLoaded` hook with matcher `compact`, log every payload to a file, force a compaction, and read which paths appear with which reason. That produces a deterministic answer, satisfies Decision 25's script requirement, and settles whether the always-loaded set is actually always loaded. Recommending this as the first concrete step of M2's inventory work.

---

## Recommendation

Three things follow directly from the findings and are worth carrying into the classification policy:

1. **Treat compaction durability as a purchased property, not a default.** The only durable mechanisms cost always-loaded bytes. A rule earns those bytes by being one that would cause a wrong action if it vanished mid-session; everything else path-scopes and accepts reloading on trigger. This gives the policy a single discriminating question instead of a taste judgment.

2. **Adopt Anthropic's trim line rather than inventing one:** cut what Claude can derive from the codebase, keep pitfalls, rationale, and conventions that differ from tool defaults. It is more decidable than "is this important," and `/doctor` applies the same heuristic, so the policy and the tooling agree.

3. **Measure before deciding.** Two facts the policy depends on are unverified: whether `@`-imports survive compaction, and whether any `SKILL.md` exceeds the 5,000-token truncation cap. Both are measurable with a script today, and the `InstructionsLoaded` hook makes the first one a direct observation rather than an inference.

Free win available independent of the policy: `disable-model-invocation: true` on the side-effect lifecycle skills removes their descriptions from every session's startup listing at no behavioral cost.

---

## Caveats

- Verified against **2.1.220** only. Several findings are version-gated (`/doctor` trim at 2.1.206, symlink glob matching at 2.1.198, brace-expansion budget at 2.1.217, duplicate-skill fix at 2.1.202), so any of this is wrong for an older install.
- The `InstructionsLoaded` **payload schema is unconfirmed.** Its existence and load-reason vocabulary are verified in the local binary; the field names are not. Read one real payload before writing a script that parses it.
- `InstructionsLoaded` does not appear anywhere in the visible changelog, so its introduction version is unknown. Present at 2.1.220.
- The changelog page truncated at 2.1.179, so older entries were not checked.
- The `include` compaction behavior is unresolved. See Conflicting Findings; do not build on either answer yet.
- Docs pages for hooks truncated before the per-event schemas. The load-reason table was recoverable; the payload examples were not.

---

## Sources

- [Explore the context window](https://code.claude.com/docs/en/context-window) — the "What survives compaction" table, the startup load timeline, skill-body caps, and the skill-listing exception. Primary source for most findings here.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) — `paths:` frontmatter semantics, unscoped-rule priority, the statement that imports do not reduce context, CLAUDE.md size targets, `MEMORY.md` limits, and the `InstructionsLoaded` debugging tip.
- [Hooks reference](https://code.claude.com/docs/en/hooks) — `InstructionsLoaded` firing conditions and its five load-reason matcher values; `PreCompact` can block on exit 2, `PostCompact` cannot.
- [Changelog](https://code.claude.com/docs/en/changelog) — version gates for `/doctor` trim (2.1.206), symlink rule matching (2.1.198), brace-expansion budget (2.1.217), duplicate skill instructions (2.1.202), nested-rules setting-source fix (2.1.211).
- [Issue #24460](https://github.com/anthropics/claude-code/issues/24460) — user report that CLAUDE.md is summarized rather than re-injected; stale, older version, recorded as a conflicting data point.
- Local binary inspection, `claude --version` and `strings`, 2026-08-03 — confirmed `InstructionsLoaded` and all five load reasons present at 2.1.220.
