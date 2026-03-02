---
name: prd-next
description: Analyze existing PRD to identify and recommend the single highest-priority task to work on next
category: project-management
---

# PRD Next - Autonomous Task Loop

## Instructions

You drive an autonomous implementation loop: identify the next task from a PRD, design the approach, implement it (TDD, hooks enforce quality), update progress, then loop back for the next task. The loop runs until the milestone is complete or a genuine decision point requires user input.

## Autonomous Decision Protocol

**Proceed without pausing when:**
- The task is clearly defined in the PRD
- The implementation approach follows established codebase patterns
- Design decisions are local (naming, file organization, internal structure)
- TDD cycle proceeds normally (write test → implement → verify)

**Stop and surface to the user when:**
- Implementation requires **deviating from what the PRD explicitly specifies**
- A design decision has **architectural implications** beyond the current task
- The PRD is **ambiguous** — multiple valid interpretations exist
- A PRD assumption turns out to be **wrong** or conflicts with existing code
- The change would **alter behavior outside the current task's scope**

When in doubt about whether something is "on spec," pause. The cost of a quick check is low; the cost of a wrong assumption compounds.

## Process Overview

1. **Detect PRD** - Identify target PRD from context or auto-detection
2. **Analyze State** - Understand what's implemented vs what's remaining
3. **Recommend Task** - Present the highest-priority next task with rationale
4. **Create Task List** - Create milestone tasks for progress tracking
5. **Design Approach** - Plan the implementation
6. **Implement** - Execute the implementation (TDD, hooks enforce quality)
7. **Update Progress** - Auto-invoke `/prd-update-progress` to commit and update PRD
8. **Loop or Halt** - Clear context and loop back, or present completion summary

## Step 1: Detect PRD

### Context Awareness Check

**Skip detection/analysis if recent conversation shows:**
- Recent PRD work discussed, specific PRD mentioned, PRD-specific commands used, or clear work context for a known PRD

**If context is clear:** Skip to Step 3 (Recommend Task) using the known PRD and conversation history.

**If context is unclear:** Auto-detect using these signals (priority order):

1. **Git Branch Analysis** - `feature/prd-12-*` → PRD 12
2. **Recent Git Commits** - Commit messages referencing PRD numbers
3. **Git Status Analysis** - Modified PRD files
4. **Available PRDs Discovery** - List `prds/*.md` files
5. **Fallback** - Ask user to specify (only if all detection fails)

**Detection Logic:**
- **High Confidence**: Branch name matches PRD pattern
- **Medium Confidence**: Modified PRD files or recent commits mention PRD
- **Low Confidence**: Multiple PRDs, use heuristics
- **No Context**: Ask user

**Once PRD is identified:** Read the PRD file, analyze completion status, identify patterns in completed vs remaining work.

## Step 2: Analyze State (Only if Context Unclear)

### Documentation & Implementation Analysis
- **Read referenced documentation**: Check "Content Location Map" in PRD for feature specs
- **Code discovery**: Use Grep/Glob to find related files, modules, tests, dependencies
- **Gap analysis**: Compare documented vs implemented state
- **Technical feasibility**: Check for dependency conflicts, breaking changes, integration points

### Completion Assessment
Count and categorize all checkboxes: `[x]` completed, `[ ]` pending, `[~]` deferred, `[!]` blocked. Calculate phase completion percentages.

### Dependency & Priority Analysis
Identify critical path items that block other work, enable major capabilities, or resolve current blockers. Prioritize items that unblock the most downstream work and deliver user-visible value.

## Step 3: Recommend Task

Present the highest-priority task. This is "show your work" — the user sees the reasoning and can interrupt if they disagree.

```markdown
## Next: [Specific Task Name]

**Why**: [2-3 sentences — why this is highest priority right now]

**Unlocks**: [What becomes possible after this]

**Dependencies met**: [What's already complete that makes this ready]

**Success criteria**: [How you'll know it's done]
```

Proceed directly to Step 4 after presenting. Do not ask for confirmation — the user will interrupt if they disagree with the recommendation.

## Step 4: Create Milestone Task List

Create tasks for the **current milestone only** using TaskCreate.

### Process

1. **Identify the current milestone** from the PRD (the one containing the recommended task)
2. **Create a task for each unchecked item** in that milestone:
   - `subject`: The milestone checkbox item text (imperative form)
   - `description`: PRD number, milestone name, relevant context
   - `activeForm`: Present continuous form (e.g., "Implementing retry logic")
3. **Set the recommended task to `in_progress`**
4. **Set dependencies** if milestone items have a natural ordering

### Rules
- Only create tasks for the current milestone
- One task per unchecked `[ ]` item — skip `[x]` items
- Keep subjects concise — use PRD checkbox text
- When a new milestone starts, mark prior milestone tasks as `completed` or `deleted`, then create fresh tasks

## Step 5: Design Approach

Plan the implementation before writing code:

- **Architecture**: How this fits into the existing codebase
- **Key changes**: What files need to be created/modified
- **Testing strategy**: What tests to write first (TDD — tests before implementation)
- **Integration points**: How it connects with existing code

Present the approach as part of the flow. Proceed to implementation unless a design decision triggers the pause criteria from the Autonomous Decision Protocol.

## Step 6: Implement

Execute the implementation following TDD and existing project standards:

1. **Write failing tests** for the task's success criteria
2. **Implement** minimal code to pass the tests
3. **Verify** tests pass, refactor as needed
4. **Quality gates are enforced by hooks** — pre-commit runs build/typecheck/lint, pre-push runs security checks

Continue implementing until the task's success criteria are met. If you hit a blocker that triggers the pause criteria, surface it to the user.

## Step 7: Update Progress

After implementation is complete, invoke `/prd-update-progress` using the Skill tool. Do not tell the user to run it — just run it.

**IMPORTANT**: `/prd-update-progress` handles PRD checkbox updates, commits, and journaling. Do not duplicate this work manually.

## Step 8: Loop or Halt

After `/prd-update-progress` completes:

### If unchecked PRD items remain (any milestone):
1. Run `/clear` to reset context — this is a **verification checkpoint**
2. The fresh instance re-reads the PRD, verifies actual state against checkboxes, and picks up the next task (which may be in the next milestone)
3. The loop continues from Step 1

The loop runs across milestone boundaries. `/clear` provides the verification checkpoint — the fresh instance re-reads the PRD from scratch, so milestone transitions are naturally validated.

### If all PRD items are complete:
Present a completion summary and halt:

```markdown
## PRD Complete

**PRD**: [PRD name] (#[number])
**Milestones completed**: [List of milestones]
**Total commits**: [Count]

All PRD items are done. Run `/prd-done` to create the PR, process CodeRabbit review, and close the issue.
```

## Success Criteria

This command should:
- Identify the single highest-value task based on current PRD state
- Provide clear rationale (show your work) so the user can course-correct
- Drive autonomous implementation with TDD and hook-enforced quality
- Pause only for genuine ambiguity or PRD deviations
- Self-verify via `/clear` between task iterations
- Run continuously across milestones until the PRD is complete
