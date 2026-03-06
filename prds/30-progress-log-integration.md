# PRD #30: Progress Log Integration

## Problem

Progress logs go stale because nothing enforces their updates. In spinybacked-orbweaver, a CHANGELOG.md was used as a development progress log, but since nothing in the workflow enforced updates, it became stale and confusing. Adding a milestone checkbox doesn't solve enforcement — it's just another checkbox that can be ignored.

## Solution

Integrate PROGRESS.md into the PRD skill workflow:

1. **`/prd-start` creates PROGRESS.md** if it doesn't exist, with contributor-aware gitignore behavior
2. **`/prd-update-progress` appends to PROGRESS.md** automatically during the commit step — enforcement through automation, not checkboxes
3. **Opt-in via file existence** — if PROGRESS.md exists, update it; if not, skip. Projects that don't want it simply don't create it.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Enforcement mechanism | Embed in `/prd-update-progress` commit step | Checkboxes can be ignored; automation in the skill itself ensures updates happen |
| Creation trigger | `/prd-start` | Natural moment — beginning work on a feature branch |
| Opt-in mechanism | File existence | No config needed. Create the file to opt in, delete to opt out |
| Entry granularity | Feature-level, not module-level | "Added coordinator orchestration with three error categories" not "Updated src/coordinator/schema-hash.ts" |
| Gitignore behavior | Based on contributor count | Solo contributor = public file; multi-contributor = gitignored (avoids merge conflicts, keeps it as personal tracking) |
| Contributor detection | `git log` unique authors filtered for bot patterns | Filter out `[bot]`, `dependabot`, `github-actions` — but NOT `noreply` (GitHub default for human users) |
| Format | Keep a Changelog style with [Unreleased] section | Familiar format, proven to work in spinybacked-orbweaver |
| No separate milestone | Do not add a "Progress log updated" milestone to PRDs | The update is automatic — a milestone would be redundant ceremony |

## Scope

### In Scope

- Update `/prd-start` (both SKILL.md and SKILL.v1-yolo.md) to create PROGRESS.md
- Update `/prd-update-progress` (both SKILL.md and SKILL.v1-yolo.md) to append entries during commit
- Contributor detection heuristic for gitignore decision
- PROGRESS.md template with Keep a Changelog format

### Out of Scope

- User-facing CHANGELOG.md (separate concern for npm publishing)
- Retroactive backfilling of existing projects' history
- Changes to CLAUDE.md rules
- Changes to other PRD skills (prd-create, prd-next, prd-done, etc.)

## Implementation Details

### Contributor Detection (in `/prd-start`)

```bash
# Count human-looking contributors (noreply is normal for GitHub users — don't filter it)
human_count=$(git log --format='%aN <%aE>' | sort -u | grep -v -i -E '\[bot\]|dependabot|github-actions' | wc -l | tr -d ' ')

if [ "$human_count" -gt 1 ]; then
    # Multi-contributor: add to .gitignore
fi
```

### PROGRESS.md Template

```markdown
# Progress Log

Development progress log for [project-name]. Tracks implementation milestones across PRD work.

## [Unreleased]

### Added
```

### `/prd-update-progress` Integration

During Step 8 (Commit), after staging implementation files and PRD updates:

1. Check if PROGRESS.md exists
2. If yes, append feature-level entries under `## [Unreleased]` / `### Added` (or Changed/Fixed as appropriate)
3. Entries describe what was accomplished at feature level, not file level
4. Stage PROGRESS.md with the rest of the commit

## Files to Modify

- `.claude/skills/prd-start/SKILL.md` — add PROGRESS.md creation step
- `.claude/skills/prd-start/SKILL.v1-yolo.md` — same change for YOLO variant
- `.claude/skills/prd-update-progress/SKILL.md` — add PROGRESS.md update in commit step
- `.claude/skills/prd-update-progress/SKILL.v1-yolo.md` — same change for YOLO variant

## Milestones

- [ ] **Milestone 1: `/prd-start` creates PROGRESS.md** — Both SKILL.md and SKILL.v1-yolo.md updated with contributor-aware creation logic
- [ ] **Milestone 2: `/prd-update-progress` appends to PROGRESS.md** — Both SKILL.md and SKILL.v1-yolo.md updated with automatic progress log entries during commit step
- [ ] **Milestone 3: PROGRESS.md rolled out to active repos** — Create PROGRESS.md in all active repos (gitignored in kubecon-2026-gitops; public in all others). Rename spinybacked-orbweaver's CHANGELOG.md to PROGRESS.md.
- [ ] **Milestone 4: Verified end-to-end** — Run `/prd-start` in a repo to confirm PROGRESS.md creation and gitignore logic, then run `/prd-update-progress` to confirm appending works

## Repo Rollout

Active repos getting PROGRESS.md (repos with commits in the last month, minus exclusions):

| Repo | Gitignored? | Notes |
|---|---|---|
| spinybacked-orbweaver | No | Rename existing CHANGELOG.md to PROGRESS.md |
| scaling-on-satisfaction | No | |
| claude-config | No | |
| kubecon-2026-gitops | Yes | Shared with Thomas Vitale |
| commit-story-v2 | No | |
| cluster-whisperer | No | |
| telemetry-agent-research | No | |
| k8s-vectordb-sync | No | |
| claude-compaction-hook | No | |
| telemetry-agent-spec-v3 | No | |
| commit-story-v2-eval | No | |

**Excluded:** websites-securitylabs, advocacy-skills

## Risks

| Risk | Mitigation |
|---|---|
| YOLO and careful variants drift apart | Both variants share the same logic for this feature; changes are additive to existing steps |
| Contributor detection false positives | Conservative filter — only `[bot]`, `dependabot`, `github-actions` excluded; human `noreply` emails preserved |
| Merge conflicts in PROGRESS.md (multi-contributor) | Mitigated by gitignoring in multi-contributor repos |

## Status

- **Phase**: Not started
- **Created**: 2026-03-06
