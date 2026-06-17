---
name: issue-update-decisions
description: Update the active issue with a design decision and cascade impact to all open issues and PRDs
category: project-management
---

# Issue Update Decisions Slash Command

## Process Overview

1. **Identify Active Issue** - Determine which issue to record the decision in
2. **Analyze Conversation Context** - Review discussions for design decisions and strategic changes
3. **Assess Decision Impact** - Evaluate how the decision affects requirements, scope, and approach
4. **Update Issue** - Record the decision in the active issue's Decision Log
5. **Cascade to Open Issues and PRDs** - Update all affected open issues and PRD files to reflect the decision

## Step 1: Identify Active Issue

Run `git branch --show-current` to read the current branch name. Extract issue numbers from the branch name (format: `feature/<numbers>-<description>`). Fetch issue titles with `gh issue view <number> --json number,title`.

If the branch contains multiple issue numbers, ask the user which issue this decision most belongs to.

Read the current issue body with `gh issue view <number> --json body` to understand existing context and any existing Decision Log section.

## Step 2: Conversation Analysis

Review the conversation context for decision-making patterns:

### Design Decision Indicators
Look for conversation elements that suggest strategic changes:
- **Workflow changes**: "Let's simplify this to..." "What if we instead..."
- **Architecture decisions**: "I think we should use..." "The better approach would be..."
- **Requirement modifications**: "Actually, we don't need..." "We should also include..."
- **Scope adjustments**: "Let's defer this..." "This is more complex than we thought..."
- **User experience pivots**: "Users would prefer..." "This workflow makes more sense..."

### Specific Decision Types
- **Technical Architecture**: Framework choices, design patterns, data structures
- **User Experience**: Workflow changes, interface decisions, interaction models
- **Requirements**: New requirements, modified requirements, removed requirements
- **Scope Management**: Features added, deferred, or eliminated
- **Implementation Strategy**: Phasing changes, priority adjustments, approach modifications

If no clear decision is apparent from conversation context, ask the user: what was decided? What alternatives were considered? What is the rationale?

## Step 3: Decision Impact Assessment

For each identified decision, assess:

### Impact Categories
- **Requirements Impact**: What requirements need to be added, modified, or removed?
- **Scope Impact**: Does this expand or contract the project scope?
- **Timeline Impact**: Does this affect project phases or sequencing?
- **Architecture Impact**: Does this change technical constraints or approaches?
- **Code Example Impact**: Which examples, interfaces, or snippets in open PRD files become outdated?
- **Risk Impact**: Does this introduce new risks or mitigate existing ones?

### Decision Documentation Format
For each decision, record using this format:

`**[YYYY-MM-DD] [Short decision title]**: [description]. **Why**: [rationale]. **Alternatives**: [what was considered and rejected].`

## Step 4: Update Issue

Update the active issue's body to record the decision.

### Decision Log Updates

Fetch the current issue body with `gh issue view <number> --json body`.

If a `## Decision Log` section exists, append the new entry to it. If none exists, append a new `## Decision Log` section to the end of the issue body.

Propose the complete updated issue body to the user for confirmation before applying. Do not post until the user approves. Then write the merged body to a temp file and update via:

```bash
gh issue edit <number> --body-file /tmp/issue-body.md
```

If the decision directly contradicts acceptance criteria, scope, implementation approach, code examples, or risk statements elsewhere in the issue body, include those as additional edits in the same proposed body update.

## Step 5: Cascade to Open Issues and PRDs

After recording the decision in the active issue, propagate its impact to other open issues and PRD files. Decisions that sit only in the active issue become invisible to implementers working on related open work.

### Process

1. **Fetch all open issues**: Run `gh issue list --state open --json number,title,body` to get all open issues. Exclude the active issue (identified in Step 1) from the list when iterating — it was already updated in Step 4.
2. **Read all PRD files**: Read each file in `prds/*.md`.
3. **For each new decision**, assess whether it affects any open issue's or PRD's:
   - **Description or scope**: Does the decision change what this issue or milestone should deliver?
   - **Acceptance criteria**: Do success conditions need updating to reflect the new reality?
   - **Implementation approach**: Does the decision change how this issue or milestone should be built?
   - **Dependencies**: Does the decision introduce or remove dependencies?
4. **Apply updates automatically**: For each affected issue or PRD, apply the update directly using `gh issue edit` for issues and the Edit tool for PRD files. Only pause if a proposed update is genuinely ambiguous — for example, if it's unclear whether the decision changes an acceptance criterion or only adds context to it.

### Update Format

When updating an affected issue or PRD, add a concise note that:
- States what changed (not the full decision rationale — that lives in the active issue's Decision Log)
- References the decision with enough context to understand it (e.g., "Updated per decision: switched from X to Y")
- Preserves the existing structure and content
- Is placed inline where the affected content lives (e.g., next to the acceptance criterion that changed, or at the top of the milestone description if the scope changed broadly)

**Example:**
> **Before:** `- [ ] Implement custom auth flow with username/password`
>
> **After:** `- [ ] Implement OAuth provider integration (Updated per decision: switched from custom auth to OAuth)`

### When NOT to Cascade

- The decision only affects the active issue being worked on (already handled by Step 4)
- The decision is purely retrospective (documents what was done, doesn't change future work)
- The decision's only downstream impact is *new work* that doesn't exist in the other issue/PRD yet — open a new issue for net-new work rather than editing existing items

### Report

After cascading, report which issues and PRDs were updated in a brief list (e.g., "Updated issue #42 and prds/84-autonomous-prd.md per decision: auth approach changed from custom to OAuth"), or confirm that no other open work was affected.
