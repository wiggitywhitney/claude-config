# Research: Global Versus Project-Level Skill Installation

**Project:** claude-config
**Last Updated:** 2026-08-03
**Claude Code version verified against:** 2.1.220 (read from `claude --version` on 2026-08-03)
**Produced for:** PRD #109 Milestone A2, consumed by Milestone B2 (Viktor's "never global" position) and Milestone B4 (skill consolidation and migration)

## Update Log
| Date | Summary |
|------|---------|
| 2026-08-03 | Initial research. Includes a live test that contradicts a recorded finding in the audit decision log — see "The YOLO symlinks are inert." |

---

## Summary

Skills can be installed globally. `~/.claude/skills/<name>/SKILL.md` is a documented, first-class location scoped to "All your projects," so Viktor's "skills are always per-project, never global" is a **preference, not a platform constraint**. His stated reason — portability to another laptop — is a real benefit of per-project installation, and it is the only argument the platform leaves standing.

The finding that matters more for this repo is a precedence rule that runs opposite to intuition and opposite to how rules behave: **personal skills override project skills.** Verified by live test, this means the `SKILL.v1-yolo.md` symlinks installed in nine repos have never taken effect.

**`/make-autonomous` is partially inert, not wholly.** It does three things, and they have different fates: the YOLO skill symlinks (inert), a `SessionStart` hook for the `/clear` auto-resume loop (works — it lives in `settings.local.json`), and permission entries (works, same file). So since 2026-03-04 those nine repos have been running an autonomous *loop* driving *interactive* skills. That combination is worse than either mode alone, and it is a live prediction this finding makes: the loop fires, then the interactive skill stops to ask a human who isn't there.

---

## Surprises and Gotchas

**1. Personal skills override project skills. Rules work the opposite way.** 🟢

**Source says:** "When skills share the same name across levels, enterprise overrides personal, and personal overrides project. A skill at any of these levels also overrides a bundled skill with the same name." ([Extend Claude with skills](https://code.claude.com/docs/en/skills))

**Compare, for rules:** "User-level rules are loaded before project rules, giving project rules higher priority." ([How Claude remembers your project](https://code.claude.com/docs/en/memory))

**Interpretation:** Skills and rules have inverted precedence. For rules, project wins. For skills, personal wins. Nothing in either page cross-references the other, and the natural assumption — that project-specific configuration beats personal configuration, as it does nearly everywhere else — is wrong for exactly one of the two mechanisms. This is the root cause of finding 2.

**2. The YOLO symlinks are inert, so the autonomous skills have never run. `/make-autonomous` is partially inert, not wholly — its skill swap does nothing while its hook and permission entries work.** 🟢 — verified by live test

The audit decision log currently records the opposite: *"project skills shadow global ones, so in those repos the YOLO variant is what runs every time, interactive session or not."* **That is incorrect.**

Evidence, in order:

- Both variants declare `name: prd-done` and carry *different* `description` strings, so the loaded variant is observable from the skill listing:
  - Interactive: `Complete PRD implementation workflow - create branch, push changes, create PR, merge, and close issue`
  - YOLO: `Complete PRD implementation workflow - create PR, handle CodeRabbit review, merge, and close issue. Triggered by the /clear loop when all PRD items are done.`
- All eight PRD skills are installed **personally** under `~/.claude/skills/`, symlinked to the claude-config directories, which resolve to the interactive `SKILL.md`. Seven match `prd-*`; the eighth is **`prds-get`**, which does not match that glob and is therefore the one any glob-derived list silently omits.
- `cluster-whisperer` has the **project** override: `.claude/skills/prd-done/SKILL.md` → `claude-config/.claude/skills/prd-done/SKILL.v1-yolo.md`.
- Live test, run in `cluster-whisperer` on 2026-08-03:

  ```bash
  claude -p "Do not use any tools. From your available skills list only, print the exact description string for the skill named prd-done."
  ```

  Returned: `Complete PRD implementation workflow - create branch, push changes, create PR, merge, and close issue` — **the interactive description.**
- Broken-symlink explanation ruled out: `readlink -f` resolves to `SKILL.v1-yolo.md`, the file is readable, and it contains the string `clear loop`. The project skill is intact and loadable; it simply loses to the personal one.

**Interpretation:** In all nine repos carrying YOLO symlinks, the interactive skills are what actually run. Three consequences:

- **The autonomous skills have not run anywhere since 2026-03-04.** Whatever behavior Whitney attributed to autonomous mode in those repos came from the interactive skills. Note the precise scope: `/make-autonomous` also installs a `SessionStart` hook and permission entries via `settings.local.json`, and **those took effect normally.** Only the skill swap failed. The nine repos have therefore been running an autonomous loop over interactive skills — a state neither variant was designed for, where the loop resumes work and the skill then stops to ask for a confirmation nobody is present to give.
- **The most-cited bug in this audit had no live impact.** The decision log states that the YOLO variant's single-channel CodeRabbit fetch means "autonomous mode misses findings today." Since the YOLO variant never loaded, no CodeRabbit finding was ever missed through that path. The divergence was real; the consequence was not. Issue #110 fixed it regardless, which was still the right call.
- **Milestone B4's migration risk is smaller than recorded, but not zero.** Deleting the YOLO files changes no behavior in those nine repos. It does leave nine sets of dangling symlinks, which need cleanup — a tidiness problem rather than a breakage problem.

**3. Nested skills do not follow the override rule. They coexist under a qualified name.** 🟢

**Source says:** "If a nested skill shares a name with another skill, both stay available. For example, with a `deploy` skill at the project root and another in `apps/web/.claude/skills/`: The nested one appears under a directory-qualified name, `apps/web:deploy`." ([Extend Claude with skills](https://code.claude.com/docs/en/skills))

**Interpretation:** Same-name collision is resolved three different ways depending on level — enterprise/personal/project override each other, plugins namespace as `plugin:skill`, and nested directories qualify as `path:skill`. Worth recording because it is a viable route to keeping two variants of one lifecycle skill addressable at once, should Milestone B4 want that.

**4. Personal skills silently do not exist in Cowork, cloud sessions, or routines.** 🟢

**Source says:** "[Cowork] sessions and [cloud sessions], including [routines], don't read `~/.claude/skills/` on your machine." ([Extend Claude with skills](https://code.claude.com/docs/en/skills))

**Source says:** "If a skill exists only in `~/.claude/skills/` on your machine, Claude Code reports that the skill was not found when a [routine](/docs/en/routines) invokes it, because each routine run starts as a fresh remote session." (same page)

**Interpretation:** This is the strongest form of Viktor's portability argument and it is more concrete than "clone onto a different laptop." Whitney's entire skill set is personal-level, so none of it exists in a cloud session or a scheduled routine. If any part of the redesign wants to run unattended work in a cloud session, per-project committed skills or a plugin become a requirement rather than a preference. Feeds Milestone B2 directly.

**5. Skill changes take effect live, without a restart, except for new top-level directories.** 🟢

**Source says:** "Claude Code watches skill directories for file changes. When you add, edit, or remove a skill under `~/.claude/skills/`, the project `.claude/skills/`, or a `.claude/skills/` inside an `--add-dir` directory, Claude Code picks up the change within the current session, without a restart. If you create a top-level skills directory that didn't exist when the session started, restart Claude Code so it can watch the new directory." ([Extend Claude with skills](https://code.claude.com/docs/en/skills))

**Interpretation:** Reduces the friction cost of the Milestone B4 consolidation — edits to skills are testable in-session. The exception matters when the migration script creates a directory that did not previously exist.

**6. Custom commands and skills are now the same mechanism.** 🟢

**Source says:** "**Custom commands have been merged into skills.** A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way." ([Extend Claude with skills](https://code.claude.com/docs/en/skills))

**Source says:** "if a skill and a command share the same name, the skill takes precedence." (same page)

**Interpretation:** Any `.claude/commands/` files anywhere in the repo set are now a redundant third way to express a skill, and one more place a definition can hide. Milestone A4's cross-repo sweep should enumerate `.claude/commands/` alongside `.claude/skills/`.

---

## Findings: the four install locations

| Level | Location | Scope | Precedence |
|---|---|---|---|
| Enterprise | via [managed settings](https://code.claude.com/docs/en/settings) | All users in the organization | Highest 🟢 |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects | Overrides project 🟢 |
| Project | `.claude/skills/<name>/SKILL.md` | This project only | Lowest of the three 🟢 |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where the plugin is enabled | Namespaced, cannot conflict 🟢 |

Discovery details worth recording:

- Project skills load from `.claude/skills/` "in the directory where you start Claude Code and in every parent directory up to the repository root." 🟢
- `--add-dir` directories also contribute their `.claude/skills/`. 🟢
- Nested `.claude/skills/` below cwd become available when Claude reads a file in that subdirectory. 🟢
- Desktop scheduled tasks run locally and *do* load personal skills, unlike routines. 🟢

---

## Answering the PRD's open question

> *Global versus project-level skills — Viktor's position is "never global." Does that hold once #21858 is ruled out?*

**His position does not hold as a statement about the platform, and partially holds as a practice.** Global installation is supported and documented. But two real arguments survive:

1. **Portability**, his own reason. A per-project skill set travels with the clone.
2. **Cloud and routine sessions do not read `~/.claude/skills/` at all** — a sharper, documented consequence he may not have had in mind, and one that directly limits Whitney's current setup if unattended cloud execution is ever in scope.

The recommendation is not to adopt his position wholesale. It is to recognise that Whitney's current arrangement — everything personal, symlinked back to claude-config — has one concrete defect the platform caused, which is finding 2, and one latent limitation, which is finding 4.

---

## Recommendation

1. **Correct the decision log.** Its claim that project skills shadow global ones is wrong, and three downstream conclusions rest on it. This should be logged as a decision-log correction in the same turn it is accepted, per the PRD's continuous-logging rule.

2. **Decide what `/make-autonomous` should do,** given that its skill swap does nothing while its `SessionStart` hook and permission entries remain active. Those two halves need separate dispositions, and the live half is the one nobody has been accounting for: nine repos are running an auto-resume loop plus loosened permissions against interactive skills. The finding also removes the assumption that deleting YOLO files is dangerous, which makes the autonomous-first consolidation *cheaper* than planned — there is no live autonomous *skill* behavior to preserve. This is Whitney's call, not mine to make.

3. **Keep skills personal unless cloud or routine execution enters scope.** Portability is a real but currently theoretical benefit for a single-machine setup; the cloud-session limitation is the fact that would force the change.

4. **Add `.claude/commands/` to Milestone A4's cross-repo enumeration.** Commands and skills are one mechanism now, so a stray command file is an undiscovered skill definition.

---

## Caveats

- Verified against **2.1.220** only.
- The live test observed **one** skill, `prd-done`, in **one** repo, `cluster-whisperer`. The precedence rule is documented generally and the mechanism is identical across the other eight repos, but the other repos were not individually tested. Milestone B4 should confirm across the full set with a script rather than extrapolating — that is a cheap loop and this finding is load-bearing enough to deserve it.
- The test asked the model to report its own skill listing. That is a direct observation of what loaded, but it is mediated by the model's compliance with the prompt. A second confirmation route, if wanted: `InstructionsLoaded` covers CLAUDE.md and rules, not skills, so it does not help here; `/context` in a live session in one of those repos would.
- Enterprise-level skill installation was not investigated beyond noting it exists and ranks highest.

---

## Sources

- [Extend Claude with skills](https://code.claude.com/docs/en/skills) — the four install locations and their scopes, the personal-overrides-project precedence rule, nested-skill qualified naming, the Cowork/cloud/routine exclusion of `~/.claude/skills/`, live change detection, and the commands-merged-into-skills note.
- [How Claude remembers your project](https://code.claude.com/docs/en/memory) — the *opposite* precedence rule for rules, used for the comparison in finding 1.
- Live test in `~/Documents/Repositories/cluster-whisperer` via `claude -p`, 2026-08-03 — observed the interactive `prd-done` description loading despite a project-level YOLO symlink; broken-symlink explanation ruled out by `readlink -f` and a content grep.
- Local filesystem inspection of `~/.claude/skills/` and `cluster-whisperer/.claude/skills/prd-done/`, 2026-08-03.
