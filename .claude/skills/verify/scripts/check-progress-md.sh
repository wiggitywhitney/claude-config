#!/usr/bin/env bash
# ABOUTME: PreToolUse hook that blocks git commit when PRD checkboxes are marked done but PROGRESS.md is not updated
# ABOUTME: Ensures progress log stays in sync with PRD milestone completions
# check-progress-md.sh — PreToolUse hook for PROGRESS.md enforcement
#
# Fires on git commit. If staged PRD files contain newly checked boxes
# (- [x]) and PROGRESS.md exists in the repo but is not staged, blocks
# the commit with instructions to update PROGRESS.md.
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision (deny or silent passthrough)
#
# Exit codes:
#   0 — Decision returned via JSON, or silent passthrough (allow)

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on git commit commands
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*commit\b'; then
  exit 0
fi

# Determine project directory
PROJECT_DIR=$(echo "$COMMAND" | grep -oE '\-C\s+\S+' | head -1 | sed 's/^-C[[:space:]]*//' || true)
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Normalize to repository root so path checks work from any cwd
REPO_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO_ROOT" ]]; then
  exit 0  # Not inside a git repository
fi
PROJECT_DIR="$REPO_ROOT"

# Check if PROGRESS.md exists in the repo
if [[ ! -f "$PROJECT_DIR/PROGRESS.md" ]]; then
  exit 0  # No PROGRESS.md in this repo, nothing to enforce
fi

# Check if any prds/*.md files are staged
STAGED_PRD_FILES=$(git -C "$PROJECT_DIR" diff --cached --name-only -- 'prds/*.md' 'prds/**/*.md' 2>/dev/null || echo "")
if [[ -z "$STAGED_PRD_FILES" ]]; then
  exit 0  # No PRD files staged, nothing to check
fi

# Check if staged PRD diffs contain newly checked boxes (lines added with [x])
if ! git -C "$PROJECT_DIR" diff --cached -- 'prds/*.md' 'prds/**/*.md' 2>/dev/null | grep -qiE '^\+\s*-\s*\[[xX]\]'; then
  exit 0  # No new checkbox completions, skip
fi

# Check if PROGRESS.md is staged
if git -C "$PROJECT_DIR" diff --cached --name-only | grep -q '^PROGRESS.md$'; then
  exit 0  # PROGRESS.md is staged, all good
fi

# PROGRESS.md exists, PRD checkboxes were completed, but PROGRESS.md not staged — deny
python3 -c "
import json

reason = (
    'PRD checkboxes were marked complete but PROGRESS.md was not updated. '
    'Add a feature-level entry under ## [Unreleased] in PROGRESS.md describing '
    'the completed work, then stage it with the commit.'
)
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
