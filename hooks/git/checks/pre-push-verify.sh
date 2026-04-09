#!/usr/bin/env bash
# ABOUTME: pre-push check — runs security verification and advisory CodeRabbit CLI review on push
# ABOUTME: Escalates to expanded security+tests when an open PR is detected for the branch

set -uo pipefail

# Resolve lib directory (checks/ → parent → lib/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Arguments from git: remote name and URL
REMOTE_NAME="${1:-}"
REMOTE_URL="${2:-}"

# Get project directory (the git repo root)
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Compute diff base for scoping security checks to branch changes only.
# Prefer upstream tracking ref; fall back to origin/main or origin/master.
DIFF_BASE=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
if [[ -z "$DIFF_BASE" ]]; then
    if git rev-parse --verify origin/main &>/dev/null; then
        DIFF_BASE="origin/main"
    elif git rev-parse --verify origin/master &>/dev/null; then
        DIFF_BASE="origin/master"
    fi
fi

# Docs-only early exit: skip verification when all branch changes are documentation-only.
# Security checks are code-oriented — irrelevant for pure docs changes.
if [[ -n "$DIFF_BASE" ]]; then
    BRANCH_FILES=$(git diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null || echo "")
    if [[ -n "$BRANCH_FILES" ]] && echo "$BRANCH_FILES" | "$LIB_DIR/is-docs-only.sh"; then
        exit 0
    fi
fi

# Detect if pushing to a branch with an open PR.
# If so, escalate to expanded security + tests to catch post-review regressions.
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
HAS_PR=false

if [[ -n "$BRANCH" && "$BRANCH" != "HEAD" ]] && command -v gh &>/dev/null; then
    PR_JSON=$(gh pr list --head "$BRANCH" --state open --json number --limit 1 2>/dev/null || echo "[]")
    PR_COUNT=$(echo "$PR_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    if [[ "$PR_COUNT" != "0" ]]; then
        HAS_PR=true
    fi
fi

FAILED_PHASE=""

if [[ "$HAS_PR" == true ]]; then
    # PR exists — expanded security + tests
    VERIFY_TIER="security+tests"

    # Phase 1: Expanded security
    if ! "$LIB_DIR/security-check.sh" "pre-pr" "$PROJECT_DIR" "$DIFF_BASE"; then
        FAILED_PHASE="security"
    fi

    # Phase 2: Tests (only if security passed)
    if [[ -z "$FAILED_PHASE" ]]; then
        DETECTION=$("$LIB_DIR/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown"}')
        CMD_TEST=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('test') or '')" 2>/dev/null || echo "")
        if [[ -n "$CMD_TEST" ]]; then
            if ! "$LIB_DIR/verify-phase.sh" "test" "$CMD_TEST" "$PROJECT_DIR"; then
                FAILED_PHASE="test"
            fi
        fi
    fi
else
    # No PR (or gh unavailable) — standard security only
    VERIFY_TIER="standard security"

    if ! "$LIB_DIR/security-check.sh" "standard" "$PROJECT_DIR" "$DIFF_BASE"; then
        FAILED_PHASE="security"
    fi
fi

if [[ -n "$FAILED_PHASE" ]]; then
    echo "" >&2
    echo "ERROR: Push blocked — $FAILED_PHASE check failed ($VERIFY_TIER)." >&2
    echo "Fix the underlying errors. Do NOT add suppression annotations to bypass." >&2
    echo "The one exception: eslint-disable-line no-console is allowed for intentional CLI output." >&2
    exit 1
fi

# Advisory CodeRabbit CLI review (runs after blocking checks pass; never blocks push)
if [[ ! -f "$PROJECT_DIR/.skip-coderabbit" ]]; then
    REVIEW_BASE=""
    if git rev-parse --verify origin/main &>/dev/null; then
        REVIEW_BASE="origin/main"
    elif git rev-parse --verify origin/master &>/dev/null; then
        REVIEW_BASE="origin/master"
    fi

    if [[ -n "$REVIEW_BASE" ]]; then
        REVIEW_RAW=$("$LIB_DIR/coderabbit-review.sh" "$PROJECT_DIR" "$REVIEW_BASE" 2>&1 || true)
        # Only print findings when they contain actual review issue blocks
        if echo "$REVIEW_RAW" | grep -qE '^File:|^Type:[[:space:]]*potential_issue|^Comment:'; then
            echo ""
            echo "=== CodeRabbit Advisory Findings (address before creating a PR) ==="
            echo "$REVIEW_RAW"
        fi
    fi
fi

exit 0
