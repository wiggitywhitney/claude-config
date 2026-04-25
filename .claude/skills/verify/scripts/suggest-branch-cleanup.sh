#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — reminds Claude to delete branches and close linked issues after gh pr merge.
# ABOUTME: Fires on Bash tool calls containing "gh pr merge". Advisory only (exit 0 always).

set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

[[ "$TOOL_NAME" != "Bash" ]] && exit 0

python3 -c "
import json, sys, re

data = json.load(sys.stdin)
command = data.get('tool_input', {}).get('command', '')

if not re.search(r'(^|\s|&&\s*|;\s*)gh\s+pr\s+merge\b', command):
    sys.exit(0)

msg = (
    'Post-merge cleanup: Delete the feature branch locally and from the remote. '
    'Also confirm the linked GitHub issue was closed — either auto-closed via '
    'a Closes #NNN line in the PR, or close it manually now.'
)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': msg
    }
}))
" <<< "$INPUT" 2>/dev/null || true

exit 0
