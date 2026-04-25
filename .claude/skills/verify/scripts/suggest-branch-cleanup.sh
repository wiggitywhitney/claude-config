#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — reminds Claude to delete branches and close linked issues after gh pr merge.
# ABOUTME: Fires only on successful Bash tool calls that invoke gh pr merge. Advisory only (exit 0 always).

set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

[[ "$TOOL_NAME" != "Bash" ]] && exit 0

python3 -c "
import json, sys, re

data = json.load(sys.stdin)
command = data.get('tool_input', {}).get('command', '')

# Require gh pr merge at string start or immediately after a shell command separator.
# Using ^\s* / &&\s* / ||\s* / ;\s* avoids false positives from 'echo gh pr merge' etc.
if not re.search(r'(^\s*|&&\s*|\|\|\s*|;\s*)gh\s+pr\s+merge\b', command):
    sys.exit(0)

# Only fire if the merge succeeded — check tool_response for the gh success phrase.
# Matching 'merged pull request' avoids false positives from failure messages
# like 'was not merged' that also contain the word 'merged'.
response = str(data.get('tool_response', ''))
if 'merged pull request' not in response.lower():
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
