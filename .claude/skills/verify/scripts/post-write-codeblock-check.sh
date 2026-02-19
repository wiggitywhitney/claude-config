#!/usr/bin/env bash
# post-write-codeblock-check.sh — PostToolUse hook for Write|Edit on markdown files
#
# Installed as a Claude Code PostToolUse hook on Write|Edit.
# Checks written/edited markdown files for bare code blocks and feeds
# back an error to Claude if found.
#
# Input: JSON on stdin from Claude Code (PostToolUse event)
# Output: JSON on stdout with decision if violations found
#
# Exit codes:
#   0 — Check passed or file is not markdown

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from the hook input
FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Resolve script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run the markdown code block checker
CHECK_OUTPUT=$("$SCRIPT_DIR/check-markdown-codeblocks.sh" "$FILE_PATH" 2>&1)
CHECK_EXIT=$?

if [ $CHECK_EXIT -eq 1 ]; then
  # Violations found — feed back to Claude
  VERIFY_CHECK_OUTPUT="$CHECK_OUTPUT" python3 -c "
import json, os
output = os.environ['VERIFY_CHECK_OUTPUT']
result = {
    'decision': 'block',
    'reason': output
}
print(json.dumps(result))
"
fi

# Exit 0 regardless — PostToolUse can't undo the write,
# but the decision/reason feeds back to Claude
exit 0
