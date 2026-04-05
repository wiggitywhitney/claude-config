#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — advises running /write-prompt when a SKILL.md or CLAUDE.md is edited.
# ABOUTME: Advisory only (exit 0 always). Never blocks the edit.

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

if [[ "$BASENAME" == "SKILL.md" || "$BASENAME" == "SKILL.v1-yolo.md" || "$BASENAME" == "CLAUDE.md" ]]; then
  python3 -c "
import json, sys
path = sys.argv[1]
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PostToolUse',
    'additionalContext': '/write-prompt reminder: ' + path + ' was modified. Run /write-prompt on this file to review for anti-patterns before committing.'
  }
}))
" "$FILE_PATH"
fi

exit 0
