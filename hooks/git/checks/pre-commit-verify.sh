#!/usr/bin/env bash
# ABOUTME: pre-commit check — runs build, typecheck, and lint verification before committing
# ABOUTME: Blocks the commit if any phase fails; docs-only commits are skipped automatically

set -uo pipefail

# Resolve lib directory (checks/ → parent → lib/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Get project directory (the git repo root)
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Docs-only early exit: skip verification when all staged files are documentation-only.
# Build, typecheck, and lint are code-oriented — irrelevant for pure docs changes.
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
if [[ -n "$STAGED_FILES" ]] && echo "$STAGED_FILES" | "$LIB_DIR/is-docs-only.sh"; then
    exit 0
fi

# Run project detection to find available verification commands
DETECTION=$("$LIB_DIR/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown"}')

CMD_BUILD=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('build') or '')" 2>/dev/null || echo "")
CMD_TYPECHECK=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('typecheck') or '')" 2>/dev/null || echo "")
CMD_LINT=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('lint') or '')" 2>/dev/null || echo "")

# If no verification commands are available, nothing to do
if [[ -z "$CMD_BUILD" && -z "$CMD_TYPECHECK" && -z "$CMD_LINT" ]]; then
    exit 0
fi

FAILED_PHASE=""

# Phase 1: Build
if [[ -n "$CMD_BUILD" ]]; then
    if ! "$LIB_DIR/verify-phase.sh" "build" "$CMD_BUILD" "$PROJECT_DIR"; then
        FAILED_PHASE="build"
    fi
fi

# Phase 2: Type Check (only if build passed)
if [[ -z "$FAILED_PHASE" && -n "$CMD_TYPECHECK" ]]; then
    if ! "$LIB_DIR/verify-phase.sh" "typecheck" "$CMD_TYPECHECK" "$PROJECT_DIR"; then
        FAILED_PHASE="typecheck"
    fi
fi

# Phase 3: Lint scoped to staged files (only if earlier phases passed)
if [[ -z "$FAILED_PHASE" && -n "$CMD_LINT" ]]; then
    if ! "$LIB_DIR/lint-changed.sh" "staged" "$PROJECT_DIR" "$CMD_LINT"; then
        FAILED_PHASE="lint"
    fi
fi

if [[ -n "$FAILED_PHASE" ]]; then
    echo "" >&2
    echo "ERROR: Commit blocked — $FAILED_PHASE verification failed." >&2
    echo "Fix the underlying errors. Do NOT add suppression annotations (@ts-ignore, type:ignore, lint-disable) to bypass." >&2
    echo "The one exception: eslint-disable-line no-console is allowed for intentional CLI output." >&2
    exit 1
fi

exit 0
