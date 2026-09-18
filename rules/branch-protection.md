---
paths: ["**/*branch-protection*", "**/CLAUDE.md"]
---

# Branch Protection Rules

The `check-branch-protection.sh` hook enforces the "always work on feature branches" rule.

## Docs-Only Exemption

Commits that **only add or modify `*.md` files** are allowed directly on main/master without a feature branch. This unblocks journal entries, documentation updates, and CLAUDE.md tweaks from needing the full branch/PR/review workflow.

**Conditions for exemption (all must be true):**
- Every staged file has status `A` (added) or `M` (modified)
- Every staged file ends with `.md`
- No deletions (`D`), renames (`R`), copies (`C`), or type-changes (`T`)

**Still requires a feature branch:**
- Any non-`.md` file (`.txt`, `.yaml`, `.sh`, etc.)
- Deleting a `.md` file (could remove important context like rule files or guides)
- Renaming/moving a `.md` file (could break `@path/to/file` references in CLAUDE.md)
- Mixed commits (`.md` + non-`.md` files together)

## Where a new rule file should be committed

**A rule file only loads on branches whose commits contain it, so committing a new one to a feature branch takes it out of service everywhere else until that branch merges.** While a file is untracked it is present on every branch, which makes newly written rules look active — committing them to a single branch is what silently removes them.

The sequence that keeps a rule working everywhere:

1. Commit it to `main`. Rule files are `.md`, so the docs-only exemption above covers this without a branch or PR.
2. Merge `main` into any feature branch currently checked out, or the rule is missing there instead.

Doing only step 1 moves the dead zone rather than removing it. Observed 2026-09-18: four new gotcha files were committed to `main`, and switching back to the active feature branch deleted all four from the working tree and reverted an unrelated rule's edits, because that branch predated the commit.

Two things to do in the same commit, both easy to forget because nothing enforces them: give the file `paths:` frontmatter, and add its row to the table in `rules/README.md`. `scripts/check-rule-frontmatter.sh` checks the frontmatter but not the index, so a file can pass the gate while being invisible in the index.

## Opt-Out

Place a `.skip-branching` file at the project root to disable branch protection entirely for that repo.
