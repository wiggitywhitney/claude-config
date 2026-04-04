---
name: write-docs
description: Write validated documentation by executing real commands and capturing actual output. Use this skill whenever documentation writing is needed — from PRD milestones, CLAUDE.md instructions, or user requests.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# /write-docs — Validated Documentation Workflow

Test existing docs for accuracy, then write new documentation one section at a time using only real command output. Every example must be executed before it is written.

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

The difference matters: ad-hoc writing invents examples and skips validation. This skill tests existing docs for accuracy, executes all commands, captures real output, and validates every example with evidence — not assumptions.

## Invocation

- User says: `/write-docs`
- Claude Code invokes this workflow when documentation writing is part of a larger task

## Core Rules

These rules are non-negotiable throughout the entire workflow:

1. **NEVER invent command output.** Every code block showing command output must come from actual execution in this session. If a command fails, document the failure — do not substitute imagined success output.
2. **Write sections directly.** After executing commands and capturing real output, write the section to the file immediately using Write or Edit. Do not show proposed markdown in a code block and ask "should I write this?" — just write it. The user will interrupt if changes are needed.
3. **Fix broken docs before writing new ones.** If existing documentation fails during Broken Docs Detection or Environment Setup, STOP and discuss fixing it with the user before proceeding.
4. **Write for users, not developers.** Use the simplest language that is still accurate. Avoid jargon when plain language works. Define terms on first use.
5. **Document error cases alongside success paths.** Show what happens when things go wrong, not just the happy path.
6. **Claude runs infrastructure commands; user runs interactive operations.** Claude executes bash commands, build steps, and CLI tools directly. Ask the user to run anything requiring a browser, GUI, authenticated web session, or interactive tool — then incorporate their output. When a tool or dependency is missing, install it automatically for project-specific dependencies (npm packages, pip packages, go modules). Confirm with the user before installing system-level tools (e.g., via brew, apt, or curl-pipe-sh).
7. **Use full flags in commands.** Always use long-form flags (e.g., `--filename` not `-f`, `--namespace` not `-n`, `--output` not `-o`). Full flags are self-documenting for users who are unfamiliar with the tools.

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

Use `AskUserQuestion` to present questions 1-5 together in a single prompt. After gathering responses, confirm the documentation plan before proceeding.

If the documentation target involves a technology or API that is new to this project, or one that changes frequently (CLI tools, cloud APIs, package managers), run `/research <technology>` before Phase 2. This surfaces current best practices, breaking changes, and version-specific gotchas — preventing the outline from being built on stale patterns.

## Phase 2: Broken Docs Detection

Before writing anything, test existing documentation for accuracy. This surfaces broken instructions, stale examples, and output mismatches before building on a faulty foundation.

**Run this phase when:** Existing documentation covers the feature or workflow being targeted.
**Skip this phase when:** No relevant existing docs exist (entirely new feature, first doc in the project).

### Step 2a: Locate Existing Docs

Find all documentation files related to the target:

1. Search for `.md` files in `docs/`, `README*`, `CONTRIBUTING*`, and adjacent directories
2. Narrow to files covering the relevant feature, workflow, or setup path
3. List the docs that will be checked before running anything

### Step 2b: Extract and Execute Examples

For each documentation file found:

1. Read the file and identify all fenced code blocks
2. Classify each block:
   - **Command** — something to run (bash, shell, CLI command)
   - **Output** — expected result following a command block
   - **Config/other** — configuration snippets, JSON, YAML, or code samples not meant to be executed
3. Execute each **command** block, capturing actual output (stdout + stderr). Skip commands that could be destructive (e.g., `rm -rf`, `DROP TABLE`, `kubectl delete`, database wipes) — mark these as ⚠️ Skipped with the reason.
4. If an **output** block follows a command, compare actual vs. claimed output. Ignore non-deterministic differences: timestamps, request/session IDs, absolute paths, hostnames, and ports. Focus on exit codes, error messages, data structure, and key output fields. When in doubt, mark as ⚠️ Skipped rather than ❌ Fail.
5. Mark each tested section:
   - ✅ **Pass** — command ran without error; output matches claimed output (or no output block to compare)
   - ❌ **Fail** — command errored, or key output fields differ from what the doc claims
   - ⚠️ **Skipped** — requires authentication, live external service, interactive session, GUI, or is potentially destructive

### Step 2c: Report Findings

Present a structured findings table:

```markdown
## Broken Docs Scan

| Doc | Section | Status | Issue |
|-----|---------|--------|-------|
| README.md | Installation | ✅ Pass | — |
| docs/setup.md | Step 3 | ❌ Fail | `npm install` exits code 1 — peer dependency conflict |
| docs/api.md | Authentication | ⚠️ Skipped | Requires live API key |

**Summary:** 3 docs checked · 1 passed · 1 failed · 1 skipped
```

If no relevant existing docs exist, state this briefly and proceed to Phase 3.

### Step 2d: Decision Gate

> **Gate — Broken Docs:** Are there failures that must be resolved before writing new docs? If issues were found, present them and wait for the user's decision before proceeding to Phase 3. Do not silently skip failures or assume they're acceptable — surface them explicitly.

If a failure looks like version drift rather than a local environment issue (unknown flag, renamed package, changed output format, different error shape), run `/research <tool>` to find the current correct syntax before deciding whether to fix or proceed.

If issues were found, ask the user:

> "Found [N] issues in existing docs. How would you like to proceed?
> - **Fix first** — Fix the broken sections before writing new documentation
> - **Proceed** — Continue with new documentation, leaving existing issues in place
> - **Fix blockers only** — Fix only the issues that directly affect the new documentation"

Wait for the user's choice before proceeding to Phase 3.

If zero issues were found, proceed to Phase 3 automatically with a brief note: "All tested doc sections passed — proceeding to environment setup."

## Phase 3: Environment Setup

Ensure a clean, reproducible starting state before writing any documentation.

1. **Detect project type**: Run `~/.claude/skills/verify/scripts/detect-project.sh` (from the `/verify` skill) if available. Otherwise, check for `package.json`, `Makefile`, `go.mod`, `pyproject.toml`, `Cargo.toml`, or other project markers to understand the tech stack.
2. **Follow existing setup docs**: If the project has setup documentation (README, CONTRIBUTING.md, setup guide), follow those steps to set up the environment. If Phase 2 already validated the setup docs, this should proceed without surprises. If no setup docs exist, use project markers from step 1 to run standard setup commands (e.g., `npm install`, `pip install --editable .`, `go mod download`) and note what was needed — this becomes input for the Prerequisites section.
3. **If existing docs are broken**: STOP immediately. Tell the user what failed and discuss fixing it before proceeding.
4. **Verify clean state**: Run build, lint, or test commands as appropriate to confirm the environment is working before documenting anything.
5. **Note prerequisites**: Record what was needed to get the environment working — these become the Prerequisites section of the documentation.

## Phase 4: Outline

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

Does this structure work? I'll write one section at a time.
```

## Phase 5: Write Chunk-by-Chunk

Write one section at a time. For each section in the approved outline:

### Step 5a: Execute commands first
- Run every command that will appear in the section — NEVER skip a command because it seems simple, obvious, or standard
- Capture the actual output
- If a command can't run because a tool or dependency is missing: auto-install project-level dependencies (npm, pip, go modules, etc.) without asking; for system-level tools (brew, apt, curl-pipe-sh, etc.) confirm with the user first per Rule 6 above
- If a command fails, capture the error — do not retry silently or substitute different output
- If a command requires user interaction (browser, GUI, authenticated session), ask the user to run it and share the output

### Step 5b: Write and apply the section
- Write the section using real output from Step 5a
- Apply the edit directly using Write (first section) or Edit (subsequent sections) — do not show the markdown in a code block and ask "should I write this?" — just write it
- Format command examples as fenced code blocks with appropriate language tags
- Include the actual output, not a cleaned-up or abbreviated version (unless extremely long, in which case truncate with a clear note)
- Add context that helps the reader understand what the command does and what the output means

### Step 5c: Proceed to the next section
- Proceed immediately to the next section in the outline and repeat Steps 5a–5b
- The user will interrupt if the section just written needs revision

Repeat Steps 5a–5c for each section in the outline.

## Phase 6: Cross-Reference Check

After all sections are written:

1. **Verify internal links**: Check that all links within the document point to valid anchors or files.
2. **Check external references**: If the document references other docs in the project, verify those files exist and the references are accurate.
3. **Update index pages**: If the project has a documentation index, table of contents, or sidebar config, update it to include the new document.
4. **Check for broken references**: Search for other documents that reference the same topic — they may need updates to point to the new docs.
5. **Present any issues found** and fix them with user approval.

## Phase 7: Final Review

Present the completed documentation for a final review.

1. **Show the full document**: Present the entire document so the user can see the complete picture.
2. **Highlight key decisions**: Remind the user of any choices made during writing (e.g., "We documented the error case for invalid tokens in section 3").
3. **Note any gaps**: If there are aspects of the feature that were not documented (intentionally or due to scope), mention them.
4. **Suggest follow-up**: If any related documentation should be updated or created, mention it.

Wait for the user's final approval before considering the documentation complete.

## Quality Checklist

Before presenting the final document, verify:

- [ ] Broken Docs Detection ran — existing doc sections were tested or explicitly skipped with reason
- [ ] Every command example was executed in this session and output is real
- [ ] No invented, hypothetical, or placeholder output exists anywhere in the document
- [ ] Error cases are documented, not just happy paths
- [ ] Language is user-appropriate (no unnecessary jargon)
- [ ] All internal links resolve correctly
- [ ] Prerequisites are complete and accurate
- [ ] Code blocks have appropriate language tags
- [ ] All commands use long-form flags, not abbreviated flags
