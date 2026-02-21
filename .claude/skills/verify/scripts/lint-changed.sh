#!/usr/bin/env bash
# lint-changed.sh — Run lint on changed files only (diff-scoped)
#
# Usage: lint-changed.sh <scope> <project-dir> [fallback-lint-command]
#
# Arguments:
#   scope              — "staged" for commit hook, or a git ref for branch diff (e.g., "origin/main")
#   project-dir        — Directory to run in
#   fallback-lint-cmd  — Full lint command to fall back to if scoped linting unavailable (optional)
#
# Scoping behavior:
#   - "staged" → git diff --cached (files being committed)
#   - "<ref>"  → git diff <ref>...HEAD (files changed on branch)
#
# Supports JS/TS files (.js, .ts, .jsx, .tsx, .mjs, .cjs) via ESLint
# and Go files (.go) via golangci-lint (falling back to go vet).
# If no lintable files changed, skips with exit code 0.
#
# Exit codes:
#   0 — Lint passed (or no lintable files changed)
#   1 — Lint failed

set -uo pipefail

SCOPE="${1:-staged}"
PROJECT_DIR="${2:-.}"
FALLBACK_CMD="${3:-}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || { echo "ERROR: Cannot resolve project directory: ${2:-.}"; exit 1; }
cd "$PROJECT_DIR" || exit 1

# Get changed files based on scope
if [ "$SCOPE" = "staged" ]; then
  CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || echo "")
else
  CHANGED_FILES=$(git diff "$SCOPE"...HEAD --name-only --diff-filter=ACMR 2>/dev/null || echo "")
fi

# Filter to lintable file extensions by ecosystem
JS_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx|mjs|cjs)$' || echo "")
GO_FILES=$(echo "$CHANGED_FILES" | grep -E '\.go$' || echo "")

# Strip empty lines
JS_FILES=$(echo "$JS_FILES" | sed '/^$/d')
GO_FILES=$(echo "$GO_FILES" | sed '/^$/d')

# Combine for reporting
ALL_LINT_FILES=""
if [ -n "$JS_FILES" ]; then
  ALL_LINT_FILES="$JS_FILES"
fi
if [ -n "$GO_FILES" ]; then
  if [ -n "$ALL_LINT_FILES" ]; then
    ALL_LINT_FILES="$ALL_LINT_FILES
$GO_FILES"
  else
    ALL_LINT_FILES="$GO_FILES"
  fi
fi

if [ -z "$ALL_LINT_FILES" ]; then
  echo "=== Phase: lint ==="
  echo "No lintable files changed — skipping"
  echo "---"
  echo "RESULT: lint PASSED (no files to lint)"
  exit 0
fi

FILE_COUNT=$(echo "$ALL_LINT_FILES" | wc -l | tr -d ' ')

echo "=== Phase: lint ==="
echo "Linting $FILE_COUNT changed file(s):"
echo "$ALL_LINT_FILES"
echo "---"

# Track overall exit code (fail if any linter fails)
OVERALL_EXIT=0

# --- JS/TS linting ---

if [ -n "$JS_FILES" ]; then
  JS_FILE_ARGS=$(echo "$JS_FILES" | tr '\n' ' ')

  # Detect ESLint config (flat or legacy)
  HAS_ESLINT=false
  if [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.ts" ] || \
     [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.yml" ] || [ -f ".eslintrc.yaml" ]; then
    HAS_ESLINT=true
  fi

  if [ "$HAS_ESLINT" = true ]; then
    eval "npx eslint $JS_FILE_ARGS" 2>&1
    JS_EXIT=$?
  elif [ -n "$FALLBACK_CMD" ] && [ -z "$GO_FILES" ]; then
    # Only use fallback for JS if there are no Go files
    # (fallback is project-specific — avoid running a Go fallback for JS files)
    echo "(Cannot scope JS/TS to changed files — running full lint)"
    eval "$FALLBACK_CMD" 2>&1
    JS_EXIT=$?
  else
    echo "No JS/TS linter detected — skipping JS/TS files"
    JS_EXIT=0
  fi

  if [ "$JS_EXIT" -ne 0 ]; then
    OVERALL_EXIT=$JS_EXIT
  fi
fi

# --- Go linting ---

if [ -n "$GO_FILES" ]; then
  GO_FILE_ARGS=$(echo "$GO_FILES" | tr '\n' ' ')

  # Detect golangci-lint availability
  HAS_GOLANGCI_LINT=false
  if command -v golangci-lint &>/dev/null; then
    HAS_GOLANGCI_LINT=true
  fi

  if [ "$HAS_GOLANGCI_LINT" = true ]; then
    if [ "$SCOPE" = "staged" ]; then
      # Staged scope: lint specific changed files
      # shellcheck disable=SC2086  # Word splitting is intentional — GO_FILE_ARGS is space-separated file list
      golangci-lint run $GO_FILE_ARGS 2>&1
      GO_EXIT=$?
    else
      # Branch scope: use --new-from-rev for diff-scoped linting
      golangci-lint run --new-from-rev="$SCOPE" ./... 2>&1
      GO_EXIT=$?
    fi
  elif [ -n "$FALLBACK_CMD" ]; then
    echo "(Cannot scope Go to changed files — running full lint)"
    eval "$FALLBACK_CMD" 2>&1
    GO_EXIT=$?
  else
    echo "No linter detected — skipping"
    GO_EXIT=0
  fi

  if [ "$GO_EXIT" -ne 0 ]; then
    OVERALL_EXIT=$GO_EXIT
  fi
fi

# --- Final result ---

echo "---"
if [ $OVERALL_EXIT -eq 0 ]; then
  echo "RESULT: lint PASSED"
else
  echo "RESULT: lint FAILED (exit code $OVERALL_EXIT)"
fi

exit $OVERALL_EXIT
