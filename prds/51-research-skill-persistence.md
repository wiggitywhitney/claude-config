# PRD #51: Upgrade /research Skill — Persistent Output and Research Reuse

**Status**: Active
**Priority**: Medium
**Created**: 2026-04-05
**GitHub Issue**: [#51](https://github.com/wiggitywhitney/claude-config/issues/51)

## Problem

The `/research` skill produces valuable, time-consuming, and costly output that disappears when the conversation ends. There is no mechanism to:

- Preserve research findings across sessions
- Know what has already been researched in a project
- Reuse prior research before launching expensive new research
- Build incrementally on prior findings as a topic evolves

Running research on the same topic twice — or slightly adjacent topics — wastes time and money and produces no compounding value.

## Solution

Every `/research` run writes its output to `docs/research/<topic-slug>.md` in the current project repo. Before starting new research, the skill checks a lightweight index (`docs/research/index.md`) for relevant prior work and reads it before beginning. Updates to existing files require an explicit changelog entry documenting what was removed (and why) and what was added. After saving, the skill scans open PRDs for relevant milestones and links the research file there.

## Design Decisions

### Decision 1 — Per-project storage in `docs/research/` (2026-04-05)
**Decision:** Research files live in `docs/research/` within each project repo, not in a global location.
**Rationale:** Research is almost always project-specific context. A global store would mix concerns and make relevance harder to judge. Projects that share a topic can independently maintain their own research file.
**Impact:** The skill must ensure `docs/research/` exists before writing. If the directory doesn't exist, create it.

### Decision 2 — Filename: `<topic-slug>.md`, date inside the file (2026-04-05)
**Decision:** Files are named by topic slug only (e.g., `anki-image-embed.md`). Dates are NOT in the filename. A prominent date header and changelog table live inside the file.
**Rationale:** Date-prefixed filenames are harder to find by topic. Date inside the file serves the staleness-detection purpose without hurting discoverability. The changelog table makes the research history visible when you open the file.
**Impact:** Naming convention: lowercase, hyphens, topic-descriptive. The "last updated" date in the index and the changelog table are the staleness signals.

### Decision 3 — Lightweight index in `docs/research/index.md` (2026-04-05)
**Decision:** Maintain `docs/research/index.md` as a one-line-per-file table: `| filename | brief description | last updated |`. This is what the skill reads at the start of every research run to check for relevant prior work.
**Rationale:** Listing all files and reading each one to assess relevance is slow as the directory grows. Keyword search is brittle — it misses semantic overlap. The index is fast to scan, semantically meaningful, and can be maintained with one append per research session.
**Impact:** Every research run must update the index: add a row for new files, update the `last updated` date for updated files.

### Decision 4 — Update existing files, don't create new ones (2026-04-05)
**Decision:** When research runs on a topic with an existing file, update the existing file rather than creating a new dated file.
**Rationale:** Accumulating dated copies creates noise and doesn't surface what's current. One canonical file per topic is easier to reference from PRDs and keeps the index compact.
**Impact:** The update protocol (Decision 5) enforces diligence to prevent lazy overwrites.

### Decision 5 — Mandatory changelog for every update (2026-04-05)
**Decision:** Every update to an existing research file must include a changelog table entry that explicitly names what was removed (and why it's stale) and what was added. The skill must read the entire existing file before writing anything. No silent overwrites.
**Rationale:** AI laziness during updates is the primary risk — it might append new findings without removing stale content, or overwrite without reading carefully. The changelog makes this visible: you cannot complete an update without justifying every removal. This is the structural forcing function.
**Impact:** The SKILL.md must explicitly require: (1) read the full existing file, (2) produce an internal "removing X (stale because Y), adding Z" summary, (3) write that summary as the changelog entry, (4) then rewrite the file.

### Decision 6 — Research file format (2026-04-05)
**Decision:** Every research file follows this structure:
```markdown
# Research: <Topic Name>

**Project:** <repo name>
**Last Updated:** YYYY-MM-DD

## Update Log
| Date | Summary |
|------|---------|
| YYYY-MM-DD | Initial research |
| YYYY-MM-DD | Removed X (stale: reason). Added Y. |

## Findings

<research content>

## Sources
```
**Rationale:** The date is prominent at the top (staleness signal). The changelog table is required by Decision 5. The structure is consistent across all projects so future AI invocations can parse it reliably.
**Impact:** The SKILL.md must include this template and require compliance.

### Decision 7 — PRD cross-referencing after save (2026-04-05)
**Decision:** After saving a research file, the skill scans all open PRDs in `prds/` (not `prds/done/`) for milestones or sections that reference the researched topic and adds a link to the research file in those locations.
**Rationale:** PRDs often reference research topics in their milestone instructions (e.g., "read the full research document"). Making the link explicit and current prevents drift between where research lives and where it's referenced. This was the pattern used in PRD #48, which manually referenced `research/plugin-architecture-patterns.md`.
**Impact:** The skill must scan `prds/*.md` after saving. The scan is semantic (AI judgment on relevance), not keyword-only. Links should be added in context — in the milestone or section where the topic is referenced — not as a generic footer.

## Milestones

### Milestone 1: Write research output to `docs/research/<topic-slug>.md` ✅

**Upgrade:**
- After completing research synthesis, save the output to `docs/research/<topic-slug>.md`
- Create `docs/research/` if it doesn't exist
- Use the research file format from Decision 6 (date header, Update Log table, Findings, Sources)
- If the file already exists, apply the update protocol from Decision 5 (read full file, produce changelog entry, rewrite)
- If the file is new, write a fresh file with the initial changelog entry

**Success Criteria:**
- Every research run produces a file in `docs/research/`
- New files match the Decision 6 template exactly
- Updates include a changelog entry naming removals (with reason) and additions
- No update overwrites the file without first reading the full existing content
- Run `/write-prompt` review on the updated SKILL.md after all changes are complete

### Milestone 2: Maintain `docs/research/index.md` ✅

**Upgrade:**
- After saving a research file, update `docs/research/index.md`:
  - New file: add a row `| filename | one-line description | YYYY-MM-DD |`
  - Updated file: update the `last updated` date in the existing row
- Create the index if it doesn't exist (with header row)

**Success Criteria:**
- Index exists and is current after every research run
- Every file in `docs/research/` has a corresponding index entry
- Index format matches: `| filename | brief description | last updated |`

### Milestone 3: Check index before starting new research ✅

**Upgrade:**
- At the start of every research run, before any web searching:
  - Check if `docs/research/` exists in the current project
  - If it exists, read `docs/research/index.md`
  - Identify any files that appear relevant to the current research topic (AI judgment)
  - Read those files in full before beginning new research
  - Note explicitly: "Found prior research: [files]. Building on it." or "No prior research found on this topic."

**Success Criteria:**
- The skill reads the index before any web searching when `docs/research/` exists
- Relevant prior files are read and incorporated into the new research session
- The skill explicitly surfaces what prior research was found (or confirms none exists)
- The skill does NOT re-research what's already well-covered in prior files; it extends or updates

### Milestone 4: PRD cross-referencing after save ✅

**Upgrade:**
- After saving a research file (new or updated), scan all files in `prds/` (not `prds/done/`)
- For each open PRD, check if any milestone or section references the researched topic
- If relevant references are found, add a link to the research file in that location
- Format: `[Research: topic-name](../docs/research/topic-slug.md)` or similar relative link
- If no relevant PRD sections are found, skip silently

**Success Criteria:**
- After saving, open PRDs are scanned for relevance
- Relevant PRD milestones receive a link to the research file
- Links use relative paths so they work from any context
- No PRD sections are modified except to add the research link

### Milestone 5: `/write-prompt` review of final SKILL.md ✅

Run `/write-prompt` on the updated `/research` SKILL.md after all other milestones are complete — not partway through. The review must cover the full updated skill including the persistence workflow, index check, update protocol, and PRD cross-referencing.

**Success Criteria:**
- `/write-prompt` review completed after ALL other changes are final
- No High or Medium severity findings remain unaddressed

## Implementation Notes

- Milestones 1 and 2 are tightly coupled — implement together in one session
- Milestone 3 depends on 1 and 2 (index must exist before checking it)
- Milestone 4 is independent of 3 and can be done alongside 1–2 if convenient
- Milestone 5 must be last
- The skill should handle projects with no `docs/` directory gracefully (create the path)
- The skill should handle the case where `/research` is invoked from a non-git directory — in that case, skip persistence and note it to the user
