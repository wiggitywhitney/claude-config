#!/usr/bin/env bash
# coderabbit-review.sh — Run CodeRabbit CLI review on branch changes
#
# Usage: coderabbit-review.sh [project-directory] [base-branch]
#
# Runs `coderabbit review --plain --type committed --base <base-branch>`
# against the project directory and outputs findings.
#
# This is an advisory check — exit code is always 0 regardless of findings.
# The caller decides how to surface the output (e.g., additionalContext in hooks).
#
# Arguments:
#   project-directory — Directory to review (defaults to current directory)
#   base-branch       — Base branch for comparison (defaults to origin/main or origin/master)
#
# Exit codes:
#   0 — Always (advisory only; output indicates whether issues were found)

set -uo pipefail

PROJECT_DIR="${1:-.}"
BASE_BRANCH="${2:-}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || {
  echo "WARNING: Cannot resolve project directory"
  exit 0
}

# Determine base branch (always compare against default branch for full feature diff)
if [ -z "$BASE_BRANCH" ]; then
  if git -C "$PROJECT_DIR" rev-parse --verify origin/main &>/dev/null; then
    BASE_BRANCH="origin/main"
  elif git -C "$PROJECT_DIR" rev-parse --verify origin/master &>/dev/null; then
    BASE_BRANCH="origin/master"
  else
    echo "WARNING: Cannot determine base branch — skipping CodeRabbit CLI review"
    exit 0
  fi
fi

# Check if coderabbit CLI is installed
CODERABBIT_BIN=""
if command -v coderabbit &>/dev/null; then
  CODERABBIT_BIN="coderabbit"
elif [[ -x "${HOME}/.local/bin/coderabbit" ]]; then
  CODERABBIT_BIN="${HOME}/.local/bin/coderabbit"
fi

if [[ -z "$CODERABBIT_BIN" ]]; then
  echo "CodeRabbit CLI not installed — skipping local review"
  exit 0
fi

echo "=== CodeRabbit CLI Review ==="
echo "Directory: $PROJECT_DIR"
echo "Base: $BASE_BRANCH"
echo "---"

# Run review with timeout (7 min max; matches PR review wait time, so CLI review
# is always a net win over waiting for the GitHub-based review cycle)
# Use gtimeout on macOS (GNU coreutils), timeout on Linux, or no timeout as fallback
TIMEOUT_BIN=""
if command -v timeout &>/dev/null; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout &>/dev/null; then
  TIMEOUT_BIN="gtimeout"
fi

if [[ -n "$TIMEOUT_BIN" ]]; then
  REVIEW_OUTPUT=$("$TIMEOUT_BIN" 420 "$CODERABBIT_BIN" review --plain --type committed --base "$BASE_BRANCH" --no-color --cwd "$PROJECT_DIR" 2>&1) || {
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 124 ]]; then
      echo "CodeRabbit CLI review timed out (7m) — skipping"
    else
      echo "CodeRabbit CLI review failed (exit $EXIT_CODE) — skipping"
    fi
    exit 0
  }
else
  REVIEW_OUTPUT=$("$CODERABBIT_BIN" review --plain --type committed --base "$BASE_BRANCH" --no-color --cwd "$PROJECT_DIR" 2>&1) || {
    EXIT_CODE=$?
    echo "CodeRabbit CLI review failed (exit $EXIT_CODE) — skipping"
    exit 0
  }
fi

if [[ -n "$REVIEW_OUTPUT" ]]; then
  echo "$REVIEW_OUTPUT"
fi

echo "---"
echo "RESULT: CodeRabbit CLI review complete"
exit 0
