---
name: write-docs
description: Write validated documentation by executing real commands and capturing actual output. Use this skill whenever documentation writing is needed — from PRD milestones, CLAUDE.md instructions, or user requests.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# /write-docs — Validated Documentation Workflow

Write accurate, user-focused documentation by executing real commands and capturing actual output. Never invent examples — every command and its output must come from real execution.

## When to Use /write-docs

- Writing a new feature guide, setup guide, or README
- Updating existing documentation after code changes
- Writing API reference documentation
- Documenting a workflow or tutorial with executable steps
- Any documentation that includes command examples or output

## Proactive Invocation

Claude Code should use this skill's workflow — not ad-hoc documentation writing — whenever it encounters a task that requires writing documentation. This includes:

- **PRD milestones** that involve writing guides, READMEs, or reference docs
- **CLAUDE.md instructions** that request documentation for a feature or project
- **User requests** like "write docs for X", "document this feature", or "update the README"

The difference matters: ad-hoc writing invents examples and skips validation. This skill executes commands, captures real output, and gates each section on user confirmation.

## Invocation

- User says: `/write-docs`
- Claude Code invokes this workflow when documentation writing is part of a larger task

## Core Rules

These rules are non-negotiable throughout the entire workflow:

1. **NEVER invent command output.** Every code block showing command output must come from actual execution in this session. If a command fails, document the failure — do not substitute imagined success output.
2. **NEVER write a section without user confirmation.** Present each section, wait for explicit approval, then proceed. Do not batch multiple sections.
3. **Fix broken docs before writing new ones.** If existing documentation fails during environment setup, STOP and discuss fixing it with the user before proceeding.
4. **Write for users, not developers.** Use the simplest language that is still accurate. Avoid jargon when plain language works. Define terms on first use.
5. **Document error cases alongside success paths.** Show what happens when things go wrong, not just the happy path.
6. **Claude runs infrastructure commands; user runs interactive operations.** Claude executes bash commands, build steps, and CLI tools directly. Ask the user to run anything requiring a browser, GUI, authenticated web session, or interactive tool — then incorporate their output.

## Phase 1: Identify Documentation Target

Ask the user what they want to document. Gather enough context to plan the work.

1. **What to document**: New feature guide, update existing docs, API reference, setup guide, README, tutorial, or something else?
2. **Target audience**: Who will read this? (New users, existing users, contributors, operators)
3. **Scope**: What specific functionality or workflow should the docs cover?
4. **Existing docs**: Are there existing docs to build on or update? If so, read them.
5. **File location**: Where should the docs live? Respect the project's existing documentation structure. If no convention exists, suggest:
   - Feature guides: `docs/guides/`
   - Setup guides: `docs/setup/`
   - API reference: `docs/api/`
   - README: project root

After gathering context, confirm the documentation plan with the user before proceeding.

## Phase 2: Environment Setup

Ensure a clean, reproducible starting state before writing any documentation.

1. **Detect project type**: Run `.claude/skills/verify/scripts/detect-project.sh` (from the `/verify` skill) if available. Otherwise, check for `package.json`, `Makefile`, `go.mod`, `pyproject.toml`, `Cargo.toml`, or other project markers to understand the tech stack.
2. **Follow existing setup docs**: If the project has setup documentation (README, CONTRIBUTING.md, setup guide), follow those steps to set up the environment. This validates existing docs as a side effect. If no setup docs exist, use project markers from step 1 to run standard setup commands (e.g., `npm install`, `pip install -e .`, `go mod download`) and note what was needed — this becomes input for the Prerequisites section.
3. **If existing docs are broken**: STOP immediately. Tell the user: "The existing setup documentation failed at step X. Before writing new docs, we should fix the existing setup docs. Here's what went wrong: [details]." Do not proceed until the user decides how to handle it.
4. **Verify clean state**: Run build, lint, or test commands as appropriate to confirm the environment is working before documenting anything.
5. **Note prerequisites**: Record what was needed to get the environment working — these become the Prerequisites section of the documentation.

## Phase 3: Outline

Present a section-by-section outline for user approval before writing anything.

1. **Draft the outline**: Based on the documentation target and audience, propose a section structure with brief descriptions of what each section will cover.
2. **Include for each section**:
   - Section title
   - One-line description of content
   - Whether it includes executable examples (commands to run and capture)
3. **Present the outline** and wait for user confirmation. The user may reorder, add, remove, or modify sections.
4. **Do not write any content until the outline is approved.**

### Outline format

```markdown
## Proposed Outline: [Document Title]

1. **[Section Name]** — [What this section covers]. [Includes executable examples: yes/no]
2. **[Section Name]** — [What this section covers]. [Includes executable examples: yes/no]
3. ...

Does this structure work? I'll write one section at a time for your review.
```

## Phase 4: Write Chunk-by-Chunk

Write one section at a time. For each section in the approved outline:

### Step 4a: Execute commands first
- Run every command that will appear in the section
- Capture the actual output
- If a command fails, capture the error — do not retry silently or substitute different output
- If a command requires user interaction (browser, GUI, authenticated session), ask the user to run it and share the output

### Step 4b: Write the section
- Write the section text using real output from Step 4a
- Format command examples as fenced code blocks with appropriate language tags
- Include the actual output, not a cleaned-up or abbreviated version (unless the output is extremely long, in which case truncate with a clear note)
- Add context that helps the reader understand what the command does and what the output means

### Step 4c: Present for confirmation
- Show the completed section to the user
- Wait for explicit approval before proceeding to the next section
- If the user requests changes, revise and present again
- Do not begin the next section until the current one is approved

### Step 4d: Write to file
- After approval, write the section to the documentation file
- Use Write to create the file with the first section; use Write (full file rewrite) or Edit (targeting end-of-file content) to add subsequent sections

Repeat Steps 4a-4d for each section in the outline.

## Phase 5: Cross-Reference Check

After all sections are written and approved:

1. **Verify internal links**: Check that all links within the document point to valid anchors or files.
2. **Check external references**: If the document references other docs in the project, verify those files exist and the references are accurate.
3. **Update index pages**: If the project has a documentation index, table of contents, or sidebar config, update it to include the new document.
4. **Check for broken references**: Search for other documents that reference the same topic — they may need updates to point to the new docs.
5. **Present any issues found** and fix them with user approval.

## Phase 6: Final Review

Present the completed documentation for a final review.

1. **Show the full document**: Present the entire document so the user can see the complete picture.
2. **Highlight key decisions**: Remind the user of any choices made during writing (e.g., "We documented the error case for invalid tokens in section 3").
3. **Note any gaps**: If there are aspects of the feature that were not documented (intentionally or due to scope), mention them.
4. **Suggest follow-up**: If any related documentation should be updated or created, mention it.

Wait for the user's final approval before considering the documentation complete.

## Quality Checklist

Before presenting the final document, verify:

- [ ] Every command example was executed in this session and output is real
- [ ] No invented, hypothetical, or placeholder output exists anywhere in the document
- [ ] Each section was individually approved by the user
- [ ] Error cases are documented, not just happy paths
- [ ] Language is user-appropriate (no unnecessary jargon)
- [ ] All internal links resolve correctly
- [ ] Prerequisites are complete and accurate
- [ ] Code blocks have appropriate language tags
