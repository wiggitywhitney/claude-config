#!/bin/bash
# ABOUTME: PostToolUse hook — runs vale on .md files after Write/Edit in repos with .vale.ini

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')

[[ "$file_path" == *.md ]] || exit 0

repo_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)
[[ -n "$repo_root" && -f "$repo_root/.vale.ini" ]] || exit 0

cd "$repo_root" || exit 0
vale --minAlertLevel error "$file_path" 2>/dev/null
