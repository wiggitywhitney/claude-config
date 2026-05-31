#!/usr/bin/env bash
# ABOUTME: pre-commit advisory check — prints prompt generality questions when src/agent/prompt.ts is staged
# ABOUTME: Never blocks the commit (always exits 0); silent when prompt file is not staged

set -uo pipefail

# Only fire when src/agent/prompt.ts is in the staged diff
if ! git diff --cached --name-only | grep -q "^src/agent/prompt\.ts$"; then
    exit 0
fi

{
    echo ""
    echo "ADVISORY: src/agent/prompt.ts is staged. Before committing, verify:"
    echo ""
    echo "  1. Does every piece of guidance express a principle that would apply to any project"
    echo "     — not a specific eval target's function names or namespace?"
    echo ""
    echo "  2. Does every piece of guidance address a root cause rather than a symptom"
    echo "     observed in one eval run?"
    echo ""
    echo "  3. Are all examples using synthetic namespaces (my_service, acme) rather than"
    echo "     real eval-target namespaces (commit_story, taze, dd)?"
    echo ""
} >&2

exit 0  # Advisory only — never blocks
