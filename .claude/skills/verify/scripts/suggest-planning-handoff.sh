#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — prompts planning-handoff check after issue creation or new PRD file creation.
# ABOUTME: Fires on Bash (gh issue create success) and Write (new prds/ file). Advisory only (exit 0 always).

set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

emit_advisory() {
  python3 -c "
import json
msg = (
    'Planning handoff check: before this session ends, verify the document captures everything a future AI needs.\n\n'
    '1. Decisions: Are there decisions from this conversation not in the document? '
    'This includes rejected alternatives, constraints discovered mid-discussion, and the reason we did not do X.\n'
    '2. Open questions: Are there open questions raised in this conversation that are not captured somewhere?\n'
    '3. Cold AI test: Could a cold AI act on this document with only what is written, '
    'or does it need something from this conversation to proceed?\n\n'
    'If anything is missing, add it to the document now before moving on.'
)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': msg
    }
}))
"
}

# ── Path 1: Write tool — new PRD file creation ───────────────────────────────
if [[ "$TOOL_NAME" == "Write" ]]; then
  FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
  [ -z "$FILE_PATH" ] && exit 0

  if [[ "$FILE_PATH" == */prds/* || "$FILE_PATH" == prds/* ]]; then
    emit_advisory
  fi
  exit 0
fi

# ── Path 2: Bash — check for successful gh issue create ──────────────────────
if [[ "$TOOL_NAME" == "Bash" ]]; then
  RESULT=$(echo "$INPUT" | python3 -c "
import json, sys, re

data = json.load(sys.stdin)
command = data.get('tool_input', {}).get('command', '')
response = data.get('tool_response', {})

# Only fire for gh issue create commands (not list, edit, comment, etc.)
if not re.search(r'(^|\s|&&\s*|;\s*)gh\s+issue\s+create\b', command):
    print('SKIP')
    sys.exit(0)

# Only fire on success — response must contain a GitHub issues URL
stdout = str(response) if response else ''
if 'github.com' not in stdout or '/issues/' not in stdout:
    print('SKIP')
    sys.exit(0)

print('FIRE')
" 2>/dev/null || echo "SKIP")

  if [[ "$RESULT" == "FIRE" ]]; then
    emit_advisory
  fi
  exit 0
fi

exit 0
