#!/usr/bin/env bash
# ABOUTME: Detects whether a project has acceptance gate tests configured.
# ABOUTME: Exits 0 with "true" on stdout if detected, exits 0 with "false" otherwise.

# Usage: detect-acceptance-gate.sh [project-dir]
# If project-dir is omitted, uses current working directory.

set -euo pipefail

PROJECT_DIR="${1:-.}"

# Signal 1: .github/workflows/acceptance-gate.yml exists
if [[ -f "${PROJECT_DIR}/.github/workflows/acceptance-gate.yml" ]]; then
    echo "true"
    exit 0
fi

# Signal 2: .claude/verify.json contains an "acceptance_test" command
if [[ -f "${PROJECT_DIR}/.claude/verify.json" ]]; then
    if grep -q '"acceptance_test"' "${PROJECT_DIR}/.claude/verify.json" 2>/dev/null; then
        echo "true"
        exit 0
    fi
fi

echo "false"
exit 0
