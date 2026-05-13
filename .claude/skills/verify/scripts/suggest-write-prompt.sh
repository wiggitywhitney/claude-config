#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — advises running /write-prompt when prompt-like files are edited or issues created.
# ABOUTME: Fires on Write|Edit (SKILL.md, CLAUDE.md) and Bash (gh issue create). Advisory only (exit 0 always).

set -uo pipefail

INPUT=$(cat)

# Detect which tool triggered us
TOOL_NAME=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")

# ── Path 1: Write|Edit — check if the file is a prompt-like document ────────
if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
  FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
  [ -z "$FILE_PATH" ] && exit 0

  BASENAME=$(basename "$FILE_PATH")
  if [[ "$BASENAME" == "SKILL.md" || "$BASENAME" == "SKILL.v1-yolo.md" || "$BASENAME" == "CLAUDE.md" || \
        "$FILE_PATH" == */prds/* || "$FILE_PATH" == prds/* || \
        "$FILE_PATH" == */rules/* || "$FILE_PATH" == rules/* || \
        "$BASENAME" == *-prompt.md || "$BASENAME" == *-spec.md ]]; then
    SUGGEST_FILE_PATH="$FILE_PATH" python3 -c "
import json, os
path = os.environ['SUGGEST_FILE_PATH']
msg = (
    '/write-prompt reminder: ' + path + ' was modified. '
    'Run /write-prompt on this file to review for anti-patterns before committing.\n\n'
    '/write-prompt applies to: SKILL.md files, CLAUDE.md files, PRDs, GitHub issues, system prompts, agent specs. '
    'Do NOT skip this because \"it\'s not a prompt.\" If an AI reads it and acts on it, it\'s a prompt.'
)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': msg
    }
}))
"
  fi
  exit 0
fi

# ── Path 2: Bash — check for successful gh issue create ─────────────────────
if [[ "$TOOL_NAME" == "Bash" ]]; then
  RESULT=$(echo "$INPUT" | python3 -c "
import json, sys, re

data = json.load(sys.stdin)
command = data.get('tool_input', {}).get('command', '')
response = data.get('tool_response', {})

# Only fire for gh issue create commands
if not re.search(r'(^|\s|&&\s*|;\s*)gh\s+issue\s+create\b', command):
    print('SKIP')
    sys.exit(0)

# Only fire on success (exit code 0)
# tool_response for Bash is a string containing stdout; check for a GitHub URL
# If the response contains a github issue URL, the command succeeded
stdout = str(response) if response else ''
if 'github.com' not in stdout or '/issues/' not in stdout:
    print('SKIP')
    sys.exit(0)

# Extract the issue URL from the response
url_match = re.search(r'https://github\.com/[^\s]+/issues/\d+', stdout)
url = url_match.group(0) if url_match else 'the issue'

print('FIRE:' + url)
" 2>/dev/null || echo "SKIP")

  if [[ "$RESULT" == FIRE:* ]]; then
    ISSUE_URL="${RESULT#FIRE:}"
    SUGGEST_ISSUE_URL="$ISSUE_URL" python3 -c "
import json, os
url = os.environ['SUGGEST_ISSUE_URL']
msg = (
    '/write-prompt check: Did you run /write-prompt on the issue body for ' + url + ' before creating it? '
    'If not, run it now. Any issue an AI will read and act on is a prompt.\n\n'
    '/write-prompt applies to: SKILL.md files, CLAUDE.md files, PRDs, GitHub issues, system prompts, agent specs.'
)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': msg
    }
}))
"
  fi
  exit 0
fi

exit 0
