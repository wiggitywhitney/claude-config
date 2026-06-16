---
name: issue-create
description: Draft, polish, and create a well-formed GitHub issue with required structure
category: project-management
---

# Issue Creation Slash Command

## Process

### Step 1: Gather the Issue Concept
Ask the user to describe the problem this issue addresses. Ask one question at a time (per CLAUDE.md rule on multiple questions). Continue the gather flow one question per turn until you have: the solution approach, any known acceptance criteria, and the priority (High / Medium / Low) needed for ROADMAP placement.

### Step 2: Draft the Issue Body
Produce a well-formed issue body:
- `## Problem` section (1-3 sentences describing the problem)
- `## Solution` section (1-3 sentences with key constraints if known)
- `## Acceptance Criteria` section (checklist if the user provided criteria; omit if not)
- Final checklist item: `- [ ] Update PROGRESS.md with a changelog entry`

### Step 3: Review with /write-prompt
Invoke `/write-prompt` on the draft body before creating the issue. Apply all high-severity findings. Do not skip this step.

**IMPORTANT: Steps 2 and 3 must happen before Step 4.** Draft and review the body before creating the issue — the issue number is not needed until Step 4.

### Step 4: Create the Issue
Run `gh issue create` with the polished body using a heredoc to handle multi-line content correctly. Add relevant labels if context makes them obvious.

```bash
gh issue create --title "..." --body "$(cat <<'EOF'
[body here]
EOF
)"
```

### Step 5: Update ROADMAP.md (If It Exists)
Check if `docs/ROADMAP.md` exists. If it does, add the new issue to the appropriate timeframe section. See [Update ROADMAP.md](#update-roadmapmd-if-it-exists) below.

### Step 6: Confirm
Output the issue URL and number.

## GitHub Issue Template

```markdown
## Problem

[1-3 sentences describing the problem]

## Solution

[1-3 sentences describing the solution approach and key constraints]

## Acceptance Criteria

- [ ] [criterion 1]
- [ ] [criterion 2]

## Checklist

- [ ] Update PROGRESS.md with a changelog entry
```

Omit the `## Acceptance Criteria` section entirely if the user did not provide criteria. The `## Checklist` section with the PROGRESS.md checkbox is always required and must never be omitted.

## Discussion Guidelines

### Issue Planning Questions
1. **Problem Understanding**: "What specific problem does this issue address?"
2. **User Impact**: "Who is affected and how does the current behavior hurt them?"
3. **Solution Scope**: "What are the core changes required?"
4. **Acceptance Criteria**: "How will we know this issue is resolved?"
5. **Dependencies**: "Does this depend on other issues or open PRDs?"
6. **Priority**: "How urgent is this? Does it block other work?"
7. **Risk Assessment**: "What could go wrong with the proposed solution?"
8. **Validation Strategy**: "How will we test and validate the implementation?"

### Discussion Tips:
- **Clarify ambiguity**: If something isn't clear, ask follow-up questions until you understand
- **One question at a time**: Per CLAUDE.md — never dump multiple questions at once
- **Challenge assumptions**: Help the user think through edge cases, alternatives, and unintended consequences
- **Prioritize ruthlessly**: Help distinguish between must-have and nice-to-have based on user impact
- **Focus on the problem first**: Understand the problem fully before committing to a solution

**Note**: If any `gh` command fails with "command not found", inform the user that GitHub CLI is required and provide the installation link: https://cli.github.com/

## Workflow

1. **Gather**: Ask about the problem, then follow up for solution and criteria (one question at a time)
2. **Draft Issue Body**: Produce the issue body using the template above
3. **Review**: Run `/write-prompt` on the draft — apply all high-severity findings before creating
4. **Create Issue**: Run `gh issue create` with the polished body
5. **Update ROADMAP.md**: Check if `docs/ROADMAP.md` exists; if so, add an entry
6. **Confirm**: Output the issue URL and number

## Update ROADMAP.md (If It Exists)

After creating the issue, check if `docs/ROADMAP.md` exists. If it does, add the new issue to the appropriate timeframe section based on priority:
- **High Priority** → Short-term section
- **Medium Priority** → Medium-term section
- **Low Priority** → Long-term section

Format: `- [Brief issue description] ([issue #NNN](issue-url)) — [1-line rationale or blocked-by]`

The ROADMAP.md update will be included in the commit at the end of the workflow (Option 2).

## Next Steps After Issue Creation

After completing the issue, present the user with numbered options:

```text
✅ Issue Created Successfully!

**GitHub Issue**: #[issue-number]
[issue-url]

What would you like to do next?

**1. Start working on this issue now**
   Begin implementation immediately (recommended if you're ready to start)

**2. Save issue for later**
   The issue is filed and ready when you are

Please enter 1 or 2:
```

### Option 1: Start Working Now

If user chooses option 1:

---

**Issue created.**

To start working on this issue, run `/issue-start [issue-number]`

---

### Option 2: Save for Later

If user chooses option 2, commit the ROADMAP.md update if one was made:

```bash
# If docs/ROADMAP.md was updated, stage and commit it:
git add docs/ROADMAP.md
git commit -m "docs: add issue #[issue-number] to ROADMAP.md [skip ci]"
git pull --rebase origin main && git push origin main
```

**Confirmation Message:**
```text
✅ Issue filed and ROADMAP.md updated

The issue is now available at [issue-url]. To start working on it later, run:
/issue-start [issue-number]
```

If ROADMAP.md was not updated (file doesn't exist or no entry was needed), skip the commit and confirm the issue URL only.

## Important Notes

- **PROGRESS.md checkbox**: Always the final item in the issue body — never omit it
- **Review is mandatory**: `/write-prompt` must run before `gh issue create` — do not skip
- **One question at a time**: Ask about the problem first; follow up for solution and criteria separately
- **ROADMAP.md is conditional**: Only update if `docs/ROADMAP.md` exists in the repo
- **Draft before create**: Unlike PRD creation, there is no issue-number dependency on the filename — always draft and review before creating the issue
