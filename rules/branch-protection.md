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

## Opt-Out

Place a `.skip-branching` file at the project root to disable branch protection entirely for that repo.
