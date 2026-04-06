---
description: Rules for preventing and recovering from cross-PRD dependencies that block clean merges
paths: ["prds/**/*.md", "**/PROGRESS.md"]
---

# PRD Dependency Management

Every PRD branch must be mergeable to main independently. A PRD milestone that cannot be completed without another feature branch being merged first is a dependency problem — it forces either simultaneous open branches (merge conflict risk) or awkward branch gymnastics.

## Prevention: Designing Dependency-Free PRDs

**Before writing milestones**, check open PRDs and their branches:
- Does any milestone require code, types, infrastructure, or APIs that exist only on a feature branch (not yet on main)?
- If yes, that milestone has a cross-PRD dependency. Fix it at design time — it is far cheaper than mid-implementation.

**Resolution options at design time:**

1. **Merge the upstream PRD first.** If PRD B's work is a hard prerequisite for PRD A, close or pause PRD A's design until B is merged. Then PRD A can assume B's work is on main.

2. **Restructure to avoid the dependency.** Design PRD A's milestones to work with main as it exists today. Treat the upstream feature as a future enhancement: ship PRD A in a way that works without it, and update in a later PRD after the dependency lands.

3. **Consolidate into one PRD.** If two features are so intertwined that neither can ship independently, they belong in the same PRD, not two.

**Design rule:** Every milestone must be implementable assuming only what is currently on `main`. Never write a milestone that assumes another feature branch's changes will be available.

## Recovery: Dependency Discovered Mid-Implementation

When you realize during implementation that a milestone cannot be completed without another feature branch:

1. **Stop immediately.** Do not attempt to branch off the upstream feature branch. Do not work around the dependency by copying code between branches.

2. **Assess the blocker type:**
   - *Hard blocker*: Cannot implement the milestone at all without the upstream changes.
   - *Soft blocker*: Could implement without the dependency, but the result would be worse or require rework later.

3. **For hard blockers:**
   - Add a note to the blocked PRD's PROGRESS.md explaining the dependency and what is needed.
   - Pause work on the blocked PRD at its current committed state.
   - Finish and merge the upstream PRD first (treating it as newly highest-priority).
   - Resume the blocked PRD after the upstream work is on main.

4. **For soft blockers:**
   - Restructure the current milestone to not require the dependency.
   - Defer any clean-up or integration work to a later milestone that will run after the dependency is expected to be merged.
   - Document the deferral in the milestone description so it is not forgotten.

5. **Never branch one PRD off another feature branch.** Every PRD branch starts from `main` and must be mergeable to `main` without requiring any other feature branch to merge first.

## Signals That a Dependency Problem Exists

- A milestone description says "requires work from PRD #X" or "after #X is merged"
- You find yourself doing `git cherry-pick` from another feature branch
- Two branches both modify the same shared utility or type definition
- A test fails because it imports something that only exists on a different branch
