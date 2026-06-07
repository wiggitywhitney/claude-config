#!/bin/bash
# ABOUTME: SessionStart hook — warns if CONTRIBUTING.md or pr-checklist.md changed since last review

repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
[[ -n "$repo_root" ]] || exit 0

sha_file="$repo_root/.git/info/contributing-reviewed-sha"
[[ -f "$sha_file" ]] || exit 0

stored_sha=$(cat "$sha_file")
current_sha=$(git -C "$repo_root" log -1 --format="%H" -- CONTRIBUTING.md docs/lab-development/pr-checklist.md 2>/dev/null)

[[ -n "$current_sha" && "$current_sha" != "$stored_sha" ]] || exit 0

echo "⚠️  CONTRIBUTING.md or pr-checklist.md has changed since CLAUDE.local.md was last reviewed."
echo "   Run: git -C \"$repo_root\" log --oneline \"$stored_sha\"..HEAD -- CONTRIBUTING.md docs/lab-development/pr-checklist.md"
echo "   Update CLAUDE.local.md if needed, then: echo \$new_sha > \"$sha_file\""
