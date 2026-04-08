---
name: prds-get
description: Fetch all open GitHub issues — PRDs and standalone issues — for project planning
category: project-management
---

# Get Open PRDs and Issues

Fetch all open GitHub issues from this project: PRDs (labeled `PRD`) and standalone issues (everything else). Present both in a single overview for project planning.

**Note**: If any `gh` command fails with "command not found", inform the user that GitHub CLI is required and provide the installation link: https://cli.github.com/

## Process

1. **Fetch all open issues** in a single call:
   ```bash
   gh issue list --state open --json number,title,url,labels,body,createdAt,updatedAt
   ```
   Split the results into two groups:
   - **PRDs**: issues where any label name equals `PRD`
   - **Standalone issues**: everything else

2. **Present PRDs** as a table:
   - Issue number (as a clickable GitHub link), title, last updated date
   - Check the current branch name (`git branch --show-current`). If it matches `feature/prd-<number>-*`, mark that PRD as `(active)` in the table.

3. **Present standalone issues** as a separate table:
   - Issue number (as a clickable GitHub link), title, last updated date
   - Note any that reference a PRD (e.g., "blocked by #47") based on issue body text (already fetched in step 1; do not make per-issue API calls for comments unless the user asks for deeper analysis)

4. **Dependency and blocking analysis** across both groups:
   - Which PRDs block which issues (look for "blocked by", "depends on", "after #X" in issue bodies)
   - Which PRDs depend on other PRDs
   - Which standalone issues could be worked in parallel with the active PRD

5. **Next steps suggestion** based on the full picture:
   - What to work on next given current dependencies and the active branch
   - Issues that are unblocked and ready to start
   - PRDs that need attention or are stalled
