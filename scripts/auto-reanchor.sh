#!/usr/bin/env bash
# ABOUTME: PostCompact hook — re-anchors context after compaction to prevent instruction amnesia.
# ABOUTME: Reads git state and active PRD, outputs orientation block to additionalContext.

set -uo pipefail

# Find repo root (if in a git repo)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

if [[ -z "$REPO_ROOT" ]]; then
    echo "Not in a git repository — skipping re-anchor." >&2
    exit 0
fi

REPO_NAME=$(basename "$REPO_ROOT")
BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "detached")
STATUS=$(git -C "$REPO_ROOT" status --short 2>/dev/null | head -10)
RECENT=$(git -C "$REPO_ROOT" log --oneline -3 2>/dev/null || echo "no commits")

# Check for active PRD (any prds/*.md with "Status: In Progress")
ACTIVE_PRD=""
PRD_NEXT_STEP=""
if [[ -d "$REPO_ROOT/prds" ]]; then
    ACTIVE_PRD=$(grep -rl -- "Status.*In Progress" "$REPO_ROOT/prds/"*.md 2>/dev/null | head -1 || true)
    if [[ -n "$ACTIVE_PRD" ]]; then
        PRD_NAME=$(basename "$ACTIVE_PRD")
        # Find the first unchecked milestone
        PRD_NEXT_STEP=$(grep -m1 -- '^- \[ \]' "$ACTIVE_PRD" 2>/dev/null | sed 's/^- \[ \] //' || true)
        ACTIVE_PRD="$PRD_NAME"
    fi
fi

# Check for CLAUDE.md
HAS_CLAUDE_MD="no"
[[ -f "$REPO_ROOT/CLAUDE.md" ]] && HAS_CLAUDE_MD="yes"
[[ -f "$REPO_ROOT/.claude/CLAUDE.md" ]] && HAS_CLAUDE_MD="yes"

# Check for execution state (plan-execute skill)
EXEC_STATE=""
if [[ -f "$REPO_ROOT/_execution-state.md" ]]; then
    EXEC_STATE="Active execution state found — read _execution-state.md"
fi

# Output orientation block to stderr so it lands in additionalContext
{
    echo "--- POST-COMPACTION RE-ANCHOR ---"
    echo "Repo: $REPO_NAME | Branch: $BRANCH | CLAUDE.md: $HAS_CLAUDE_MD"
    echo "Recent commits: $RECENT"
    [[ -n "$STATUS" ]] && echo "Dirty files: $STATUS" || echo "Working tree: clean"
    [[ -n "$ACTIVE_PRD" ]] && echo "Active PRD: $ACTIVE_PRD" || echo "Active PRD: none"
    [[ -n "$PRD_NEXT_STEP" ]] && echo "Next milestone: $PRD_NEXT_STEP"
    [[ -n "$EXEC_STATE" ]] && echo "$EXEC_STATE"
    if [[ -n "$EXEC_STATE" ]]; then
        echo "ACTION: Re-read CLAUDE.md, the active PRD, and _execution-state.md now to restore full context."
    else
        echo "ACTION: Re-read CLAUDE.md and the active PRD now to restore full context."
    fi
    echo "---"
} >&2

exit 0
