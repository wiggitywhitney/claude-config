---
name: prd-update-decisions
description: Update PRD based on design decisions and strategic changes made during conversations
category: project-management
---

# PRD Update Decisions Slash Command

## Instructions

You are updating a PRD based on design decisions, strategic changes, and architectural choices made during conversations. This command captures conceptual changes that may not yet be reflected in code but affect requirements, approach, or scope.

## Process Overview

1. **Identify Target PRD** - Determine which PRD to update
2. **Analyze Conversation Context** - Review discussions for design decisions and strategic changes
3. **Assess Decision Impact** - Evaluate how decisions affect requirements, scope, and architecture
4. **Update PRD** - Record decisions, update requirements, approach, code examples, and risks
5. **Propagate to Downstream Milestones** - Update affected milestones to reflect new decisions

## Step 1: PRD Analysis

Auto-detect the target PRD using these signals (priority order):

1. **Conversation context**: Recent PRD work discussed, specific PRD mentioned
2. **Git branch**: `feature/prd-12-*` → PRD 12
3. **Recent commits**: Commit messages referencing PRD numbers
4. **Modified PRD files**: Recently changed files in `prds/`
5. **Available PRDs**: List `prds/*.md` files

If multiple PRDs are possible and context doesn't disambiguate, ask which one.

Then:
- Read the PRD file from `prds/[issue-id]-[feature-name].md`
- Understand current requirements, approach, and constraints
- Identify areas most likely to be affected by design decisions

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

## Step 3: Decision Impact Assessment

For each identified decision, assess:

### Impact Categories
- **Requirements Impact**: What requirements need to be added, modified, or removed?
- **Scope Impact**: Does this expand or contract the project scope?
- **Timeline Impact**: Does this affect project phases or delivery dates?
- **Architecture Impact**: Does this change technical constraints or approaches?
- **Code Example Impact**: Which examples, interfaces, or snippets become outdated?
- **Risk Impact**: Does this introduce new risks or mitigate existing ones?

### Decision Documentation Format
For each decision, record:
- **Decision**: What was decided
- **Date**: When the decision was made
- **Rationale**: Why this approach was chosen
- **Impact**: How this affects the PRD requirements, scope, or approach
- **Code Impact**: Which code examples, interfaces, or snippets need updating
- **Owner**: Who made or approved the decision

## Step 4: PRD Updates

Update the appropriate PRD sections:

### Decision Log Updates
- Add new resolved decisions with date and rationale
- Mark open questions as resolved if decisions were made
- Update decision impact on requirements and scope
- **Add corresponding milestone items** when a decision creates new work. Milestone items should reference the decision (e.g., "Implement X (Decision 16)") so future AI has full context on why the item exists

### Requirements Updates
- Modify functional requirements based on design changes
- Update non-functional requirements if performance/quality criteria changed
- Adjust success criteria if measurements or targets changed

### Implementation Approach Updates
- Update phases if sequencing or priorities changed
- Modify architecture decisions if technical approach evolved
- Adjust scope management if features were added, deferred, or removed

### Code Example Validation and Updates
- **Identify Outdated Examples**: Scan PRD for code snippets that may be affected by design decisions
- **Interface Changes**: Update examples when function signatures, parameter types, or return values change
- **API Modifications**: Revise examples when method names, class structures, or data formats evolve
- **Workflow Updates**: Update process examples when user interaction patterns or step sequences change
- **Mark for Verification**: Flag code examples that need manual testing to ensure they still work

### Risk and Dependency Updates
- Add new risks introduced by design decisions
- Update mitigation strategies if approach changed
- Modify dependencies if architectural changes affect integrations

## Step 5: Downstream Milestone Propagation

After recording decisions and updating the current PRD sections, propagate decision impact to downstream milestones. Decisions that sit only in the decision log become invisible to future implementing agents who read milestone descriptions as their working instructions.

### Process

1. **Identify incomplete milestones**: Scan all milestones in the PRD that are not yet marked complete
2. **For each new decision**, assess whether it affects any downstream milestone's:
   - **Description or scope**: Does the decision change what this milestone should deliver?
   - **Acceptance criteria**: Do success conditions need updating to reflect the new reality?
   - **Implementation approach**: Does the decision change how this milestone should be built?
   - **Dependencies**: Does the decision introduce or remove dependencies between milestones?
3. **Update affected milestones** with a brief note explaining what changed and why, referencing the decision number

### Update Format

When updating a milestone, add a concise note that:
- States what changed in the milestone (not the full decision rationale — that lives in the decision log)
- References the decision by number (e.g., "Updated per Decision 12")
- Preserves the milestone's existing structure and content
- Is placed inline where the affected content lives (e.g., next to the acceptance criterion that changed, or at the top of the milestone description if the scope changed broadly)

**Example:**
> **Before:** `- [ ] Implement custom auth flow with username/password`
>
> **After:** `- [ ] Implement OAuth provider integration (Updated per Decision 12: switched from custom auth to OAuth)`

### When NOT to Propagate

- The decision only affects the current milestone being worked on (already handled by Step 4)
- The decision is purely retrospective (documents what was done, doesn't change future work)
- The decision's only downstream impact is *new work*, which is already captured by a new milestone item added in Step 4's Decision Log Updates (new items are additions; propagation is about updating *existing* milestone content that is now stale)

### Report

After propagation, report which milestones were updated in a brief list (e.g., "Updated Milestone 3 and 5 per Decision 12: auth approach changed from custom to OAuth"), or confirm that no downstream milestones were affected.