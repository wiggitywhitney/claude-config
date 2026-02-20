#!/usr/bin/env bash
# lint-changed.sh — Run lint on changed files only (diff-scoped)
#
# Usage: lint-changed.sh <scope> <project-dir> [fallback-lint-command]
#
# Arguments:
#   scope              — "staged" for commit hook, or a git ref for branch diff (e.g., "origin/main")
#   project-dir        — Directory to run in
#   fallback-lint-cmd  — Full lint command to fall back to if ESLint can't be scoped (optional)
#
# Scoping behavior:
#   - "staged" → git diff --cached (files being committed)
#   - "<ref>"  → git diff <ref>...HEAD (files changed on branch)
#
# Only lints JS/TS files (.js, .ts, .jsx, .tsx, .mjs, .cjs).
# If no lintable files changed, skips with exit code 0.
# Uses ESLint directly when config is detected, falls back to full lint command otherwise.
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

# Filter to lintable file extensions (JS/TS ecosystem)
LINT_FILES=$(echo "$CHANGED_FILES" | grep -E '\.(js|ts|jsx|tsx|mjs|cjs)$' || echo "")

# Strip empty lines
LINT_FILES=$(echo "$LINT_FILES" | sed '/^$/d')

if [ -z "$LINT_FILES" ]; then
  echo "=== Phase: lint ==="
  echo "No lintable files changed — skipping"
  echo "---"
  echo "RESULT: lint PASSED (no files to lint)"
  exit 0
fi

FILE_COUNT=$(echo "$LINT_FILES" | wc -l | tr -d ' ')

echo "=== Phase: lint ==="
echo "Linting $FILE_COUNT changed file(s):"
echo "$LINT_FILES"
echo "---"

# Convert newlines to space-separated args
FILE_ARGS=$(echo "$LINT_FILES" | tr '\n' ' ')

# Detect ESLint config (flat or legacy)
HAS_ESLINT=false
if [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ] || [ -f "eslint.config.ts" ] || \
   [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.yml" ] || [ -f ".eslintrc.yaml" ]; then
  HAS_ESLINT=true
fi

if [ "$HAS_ESLINT" = true ]; then
  # Run ESLint on just the changed files
  eval "npx eslint $FILE_ARGS" 2>&1
  EXIT_CODE=$?
elif [ -n "$FALLBACK_CMD" ]; then
  # No ESLint config detected — fall back to the full lint command
  echo "(Cannot scope to changed files — running full lint)"
  eval "$FALLBACK_CMD" 2>&1
  EXIT_CODE=$?
else
  echo "No linter detected — skipping"
  EXIT_CODE=0
fi

echo "---"
if [ $EXIT_CODE -eq 0 ]; then
  echo "RESULT: lint PASSED"
else
  echo "RESULT: lint FAILED (exit code $EXIT_CODE)"
fi

exit $EXIT_CODE
