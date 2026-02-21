#!/usr/bin/env bash
# is-docs-only.sh — Check if a set of file paths are all documentation-only
#
# Reads file paths from stdin (one per line) and checks each against a
# conservative allowlist of documentation-only extensions. Exits 0 if ALL
# files are docs-only, exits 1 if ANY file could affect code behavior.
#
# Used by verification hooks to skip build/lint/security/test checks
# when changes are purely documentation (Decision 4, PRD 11).
#
# Usage:
#   git diff --cached --name-only | is-docs-only.sh   # staged files
#   git diff --name-only base...HEAD | is-docs-only.sh # branch diff
#
# Exit codes:
#   0 — All files are documentation-only (safe to skip verification)
#   1 — At least one file could affect code (run verification)

set -uo pipefail

# Conservative allowlist of documentation-only extensions.
# Only extensions that can NEVER affect build, lint, security, or tests.
# Config files (.yml, .json, .toml) are excluded — they can affect builds.
DOCS_PATTERN='\.(md|mdx|txt|png|jpg|jpeg|gif|svg|webp|ico)$'

# Read file list from stdin
FILES=$(cat)

# Empty file list is NOT docs-only — let the hook proceed normally.
# This handles edge cases like empty commits or no upstream diff.
if [ -z "$FILES" ]; then
  exit 1
fi

# Check each file against the allowlist
while IFS= read -r file; do
  # Skip empty lines
  [ -z "$file" ] && continue

  if ! echo "$file" | grep -qiE "$DOCS_PATTERN"; then
    # Found a non-docs file — must run verification
    exit 1
  fi
done <<< "$FILES"

# All files matched the docs-only allowlist
exit 0
