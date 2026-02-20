# PRD #4: ABOUTME File Header Convention and Hook

**Status**: Not Started
**Priority**: Low
**Created**: 2026-02-18
**GitHub Issue**: [#4](https://github.com/wiggitywhitney/claude-config/issues/4)
**Context**: Inspired by the ABOUTME convention in `peopleforrester/llm-coding-workflow`. Every code file starts with a brief 2-line description of its purpose. A PreToolUse hook blocks on missing headers (exit 2), triggering fix-and-retry to gradually adopt the convention as files are created or modified.

---

## Problem

Code files lack consistent self-documentation. Understanding what a file does requires reading through the implementation. When navigating unfamiliar parts of a codebase — or returning to code after time away — there's no quick way to understand a file's purpose without reading it.

## Solution

Adopt an ABOUTME header convention where every code file starts with a brief 2-line comment describing what the file does. Enforce via a PreToolUse hook on Write|Edit that blocks (exit 2) when files are missing the header, triggering a fix-and-retry cycle. The convention is language-agnostic — the hook understands comment syntax for multiple languages.

### Convention Format

Each file starts with 2 lines using the appropriate comment syntax:

```python
# ABOUTME: Brief description of this file's purpose
# ABOUTME: What it does or provides
```

```typescript
// ABOUTME: Brief description of this file's purpose
// ABOUTME: What it does or provides
```

```bash
# ABOUTME: Brief description of this file's purpose
# ABOUTME: What it does or provides
```

## Reference Implementation

**Source**: [`peopleforrester/llm-coding-workflow/claude-config/hooks/check-aboutme.sh`](https://github.com/peopleforrester/llm-coding-workflow/blob/main/claude-config/hooks/check-aboutme.sh)

Key characteristics of the reference:
- PostToolUse hook on `Edit|Write` — fires after every file write/edit
- Python-specific (`.py` files only), skips `__init__.py`
- Checks first 3 lines for `# ABOUTME:` pattern
- Warns but never blocks (always exits 0)
- Registered in `settings.json` under `hooks.PostToolUse` with matcher `Edit|Write`

Whitney's implementation extends this to be language-agnostic, supporting multiple file types and comment syntaxes.

## Deliverables

### 1. ABOUTME Hook Script
A PreToolUse hook script that:
- Detects file type from extension
- For Write: checks `tool_input.content` for ABOUTME in first 3 lines
- For Edit: reads existing file from disk, checks first 3 lines for ABOUTME
- Blocks on missing headers (exit 2), triggering fix-and-retry
- Skips files that don't need headers (index files, config files, generated files)

### 2. Settings.json Registration
Register the hook in `~/.claude/settings.json` as a PreToolUse hook on `Write|Edit`.

### 3. CLAUDE.md Convention Documentation
Add the ABOUTME convention to the global CLAUDE.md so Claude knows to include headers when creating or modifying files.

## Success Criteria

- [ ] Hook blocks on missing ABOUTME headers for supported file types (exit 2, fix-and-retry)
- [ ] Multiple languages supported (Python, TypeScript/JavaScript, Bash, at minimum)
- [ ] Existing files gain headers organically as they're modified (no backfill required)
- [ ] Convention documented in global CLAUDE.md

## Milestones

### Milestone 1: Hook Implementation
Build the ABOUTME check hook, supporting multiple file types and comment syntaxes.

- [ ] Hook script created, handling `.py`, `.ts`, `.js`, `.sh` files at minimum
- [ ] Appropriate comment syntax detection per file type
- [ ] Skip list for files that don't need headers (`__init__.py`, `index.ts` re-exports, config files, generated files)
- [ ] Hook registered in `~/.claude/settings.json`
- [ ] Tested across multiple file types in a real project

### Milestone 2: Convention Adoption
Document the convention and verify it works in practice across projects.

- [ ] ABOUTME convention added to global CLAUDE.md
- [ ] Convention documented in HTML comment in CLAUDE.md once hook is working (hook-enforced rule)
- [ ] Verified that Claude adds ABOUTME headers to new files and warns on edited files missing them

## Out of Scope

- Retroactive backfill of existing files (headers are added organically as files are touched)
- Warn-only mode (Decision 1 chose full block for 100% adoption)
- Markdown files (they have their own heading conventions)
- JSON/YAML/config files (no comment syntax or not meaningful)

## Decision Log

### Decision 1: Full Block on Both Write and Edit
- **Date**: 2026-02-18
- **Decision**: The ABOUTME hook blocks both Write and Edit operations on files missing the ABOUTME header. Implemented as a PreToolUse hook.
- **Rationale**: Blocking provides 100% enforcement — no file ever exists without the header. For Write operations, the hook checks `tool_input.content` for ABOUTME in the first few lines. For Edit operations, the hook reads the existing file from disk and checks its first 3 lines. If missing, the hook blocks (exit 2), Claude adds the header, then retries. The extra round-trip is a one-time cost per pre-existing file — the gradual adoption mechanism working as designed. This differs from the reference implementation (which warns only) but aligns with Whitney's preference for deterministic enforcement.
- **Impact**: Hook is PreToolUse on `Write|Edit` (can block). Fix-and-retry pattern handles adoption of pre-existing files organically.

### Decision 2: Language-Agnostic from the Start
- **Date**: 2026-02-18
- **Decision**: Support multiple languages from the initial implementation rather than starting Python-only and extending later.
- **Rationale**: Whitney works primarily in TypeScript, not Python. A Python-only hook (like the reference implementation) would provide no value. The comment syntax mapping is straightforward (`#` for Python/Bash, `//` for TypeScript/JavaScript) and doesn't add meaningful complexity.
- **Impact**: Hook includes a file-extension-to-comment-syntax mapping from day one.
