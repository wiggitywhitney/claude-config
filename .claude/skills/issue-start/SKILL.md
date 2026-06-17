---
name: issue-start
description: Recommend juggling pairs, user decides, create correctly-named branch for issue work
category: project-management
arguments:
  - name: issueNumber
    description: Issue number(s) to start working on (e.g., 42 or "98 101")
    required: false
---

# Issue Start - Begin Issue Work

**IMPORTANT**: Do NOT include time estimates or effort estimates in your responses.

## Process

### Step 0: Check for Issue Argument

**If `issueNumber` argument is provided (`{{issueNumber}}`):**
- Skip context check
- Use the provided issue number(s) directly
- Proceed to Step 2 (Analyze)

**If `issueNumber` argument is NOT provided:**
- Continue to Step 0b

### Step 0b: Context Awareness Check

**Check if issue context is already clear from recent conversation:**

Skip to Step 2 if recent conversation shows:
- **Recent issue work discussed** — "We're working on issue #42", "We just finished issue work", etc.
- **Specific issue mentioned** — "issue #X", a known open issue referenced by number or title
- **Issue-specific commands used** — Recent use of `/issue-update-progress` or `/issue-next` with a specific issue

**If context is clear:** Skip to Step 2 using the known issue(s).

**If context is unclear:** Continue to Step 1.

### Step 1: Read Input

Ask the user: "Which issue number(s) would you like to start working on?"

Wait for their response. If they are unsure, suggest running `gh issue list --state open` to see available issues.

**If multiple issue numbers are provided:** The working set is already defined. Skip to Step 4 (Create Branch).

**If one number is provided:** Proceed to Step 2 to analyze juggling candidates.

### Step 2: Analyze Juggling Candidates

Fetch all open issues:

```bash
gh issue list --state open --json number,title,body,labels
```

Identify issues that cluster well with the provided issue based on:
- **Related domain** — same subsystem, skill, rule file area, or feature scope
- **Similar implementation scope** — comparable size and effort
- **No blocking dependency** — neither issue must be completed before the other can start

Surface 1–3 juggling suggestions with brief rationale for each pairing. If no good candidates exist, state that clearly so the user can proceed solo.

Example output:
```markdown
## Juggling Candidates for Issue #42

**Option A: Work issue #42 alone**
The scope is self-contained and no related issues are ready.

**Option B: Pair issue #42 with #45**
Both touch the same rule file area (`rules/git-workflow.md`). Completing them together avoids
two separate review cycles for the same file region.

**Option C: Pair issue #42 with #51**
Both are documentation fixes with no code changes. Low risk to combine.

---
Work issue #42 alone, or with option B or C?
```

### Step 3: Wait for Decision

**MANDATORY: Wait for the user's answer before creating the branch.** The branch name encodes all issue numbers in the working set — the set must be finalized before the branch is created.

After the user decides, proceed to Step 4 with the confirmed working set.

### Step 4: Create Branch

#### Branch Naming Convention

`feature/<issue-numbers>-<semantic-description>`

- `<issue-numbers>`: hyphen-separated list of all issue numbers in the working set
- `<semantic-description>`: short kebab-case summary derived from the issues' titles or scope

Examples:
- Single issue: `feature/42-fix-auth-token-handling`
- Multi-issue: `feature/98-101-autonomous-issue-execution`

#### Git Branch Management

1. **Check current branch**: Run `git branch --show-current`
2. **If on `main` or `master`**: Create and switch to the feature branch:
   ```bash
   git checkout -b feature/<issue-numbers>-<semantic-description>
   ```
3. **If already on a feature branch**: Verify it matches the working set. If not, inform the user and ask how to proceed before continuing.

#### Step 4 Checkpoint (REQUIRED)

**Display this confirmation before proceeding to Step 4b:**

```markdown
## Branch Created ✅
- **Branch**: `feature/<issue-numbers>-<semantic-description>` ✅
- **Working set**: Issue #X — [title], Issue #Y — [title]
```

**DO NOT proceed to Step 4b until branch setup is confirmed.**

### Step 4b: Create PROGRESS.md (If Not Present)

After branch setup, create a progress log if the project does not already have one.

#### Check for Existing PROGRESS.md

Look for `PROGRESS.md` in the repository root. If it already exists, skip this step entirely.

#### Contributor Detection

Determine whether the repo has multiple human contributors to decide gitignore behavior:

```bash
human_count=$(git log --format='%aN' | sort -u | grep -v -i -E '\[bot\]|dependabot|github-actions' | wc -l | tr -d ' ')
```

- If `human_count > 1`: Add `PROGRESS.md` to `.gitignore` (avoids merge conflicts in multi-contributor repos)
- If `human_count <= 1`: Leave `PROGRESS.md` tracked (public file for solo contributor)

#### Create PROGRESS.md

Create `PROGRESS.md` in the repository root with this template (replace `[project-name]` with the actual repo name):

```markdown
# Progress Log

Development progress log for [project-name].

## [Unreleased]

### Added
```

#### Display Confirmation

```markdown
## Progress Log ✅
- **PROGRESS.md**: Created in repository root
- **Gitignore**: [Added to .gitignore (multi-contributor) / Tracked publicly (solo contributor)]
```

### Step 5: Hand Off to /issue-next

Present the final summary:

```markdown
## Ready to Work 🚀

**Working set**: Issue #X — [title][, Issue #Y — [title]]
**Branch**: `feature/<issue-numbers>-<semantic-description>`
```

Then immediately invoke `/issue-next` using the Skill tool to reconstruct full issue context and begin implementation.

## Success Criteria

This command should:
- ✅ Identify the working set of issue(s) before creating the branch
- ✅ Present juggling candidate recommendations with rationale
- ✅ Wait for the user's working-set decision before creating the branch
- ✅ Create a branch whose name encodes all issue numbers in the working set
- ✅ Auto-invoke `/issue-next` after branch creation to transition directly into work

## Notes

- The branch name is the machine-readable working set: `/issue-done` reads it to know which issues to close
- PROGRESS.md creation is identical to the `/prd-start` behavior — same contributor-detection logic applies
- If any `gh` command fails with "command not found", inform the user that GitHub CLI is required: https://cli.github.com/
