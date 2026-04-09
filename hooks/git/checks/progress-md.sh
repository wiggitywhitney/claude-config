#!/usr/bin/env bash
# ABOUTME: pre-commit check — blocks commits when PRD checkboxes completed but PROGRESS.md not staged
# ABOUTME: Only fires when PROGRESS.md exists in the repo

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    exit 0
fi

if [[ ! -f "$REPO_ROOT/PROGRESS.md" ]]; then
    exit 0  # No PROGRESS.md in this repo — nothing to enforce
fi

STAGED_PRD_FILES="$(git diff --cached --name-only -- 'prds/*.md' 'prds/**/*.md' 2>/dev/null || echo "")"
if [[ -z "$STAGED_PRD_FILES" ]]; then
    exit 0  # No PRD files staged
fi

# Check if staged PRD diffs contain newly checked boxes (lines added with [x])
if ! git diff --cached -- 'prds/*.md' 'prds/**/*.md' 2>/dev/null | grep -qiE '^\+\s*-\s*\[[xX]\]'; then
    exit 0  # No new checkbox completions in staged PRD diff
fi

# Check if PROGRESS.md is staged
if git diff --cached --name-only 2>/dev/null | grep -qFx -- 'PROGRESS.md'; then
    exit 0  # PROGRESS.md is staged — all good
fi

echo "ERROR: PRD checkboxes were marked complete but PROGRESS.md was not updated." >&2
echo "Add a feature-level entry under ## [Unreleased] in PROGRESS.md describing" >&2
echo "the completed work, then stage it: git add PROGRESS.md" >&2
exit 1
