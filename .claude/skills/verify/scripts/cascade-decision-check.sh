#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — advises cascade-evaluating downstream milestones when a PRD file is edited.
# ABOUTME: Fires on Write|Edit to prds/ files (excluding prds/done/). Advisory only (exit 0 always).

set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only fire for active PRD files: prds/<name>.md, not prds/done/<name>.md
if ! echo "$FILE_PATH" | grep -qE 'prds/[^/]+\.md$'; then
  exit 0
fi

python3 -c "
import json
msg = (
    'PRD file edited: check whether a row was added to the \"## Decision Log\" table. '
    'If yes, cascade-evaluate: (1) review all remaining milestones in this PRD for impact '
    'and update any affected by the new decision; (2) scan other open PRDs in prds/ by '
    'reading their titles and summaries — if relevant, open them and update affected '
    'milestones. Skip the cascade if no Decision Log row was added.'
)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': msg
    }
}))
"

exit 0
