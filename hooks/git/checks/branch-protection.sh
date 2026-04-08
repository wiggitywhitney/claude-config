#!/usr/bin/env bash
# ABOUTME: pre-commit check — blocks commits to main/master branches
# ABOUTME: Docs-only exemption for *.md and .gitignore files; respects .skip-branching opt-out

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    exit 0  # Not inside a git repo — allow
fi

if [[ -f "$REPO_ROOT/.skip-branching" ]]; then
    exit 0  # Repo opted out of branch protection
fi

BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
if [[ -z "$BRANCH" ]]; then
    exit 0  # Detached HEAD — allow
fi

if [[ "$BRANCH" != "main" ]] && [[ "$BRANCH" != "master" ]]; then
    exit 0  # Not a protected branch — allow
fi

# On a protected branch — check docs-only exemption
# Only allow if every staged file is *.md or .gitignore, with A/M status only
STAGED="$(git diff --cached --name-status 2>/dev/null || echo "")"
if [[ -z "$STAGED" ]]; then
    exit 0  # Nothing staged — git will reject the commit before this hook matters
fi

if [[ -n "$STAGED" ]]; then
    DOCS_ONLY=true
    while IFS=$'\t' read -r status filepath _rest; do
        # Only allow Added (A) or Modified (M) statuses
        case "$status" in
            A|M) ;;
            *) DOCS_ONLY=false; break ;;
        esac
        # Block any non-.md, non-.gitignore file
        if [[ "$filepath" != *.md ]] && [[ "$(basename "$filepath")" != .gitignore ]]; then
            DOCS_ONLY=false
            break
        fi
    done <<< "$STAGED"

    if [[ "$DOCS_ONLY" = true ]]; then
        exit 0  # Docs-only commit on protected branch — allow
    fi
fi

echo "ERROR: Cannot commit directly to the \"$BRANCH\" branch." >&2
echo "Create a feature branch first: git checkout -b feature/<name>" >&2
echo "To opt out of this check for this repo: touch .skip-branching" >&2
exit 1
