#!/usr/bin/env bash
# check-commit-message.sh — PreToolUse hook that blocks AI/Claude references in commit messages
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects git commit commands, extracts ONLY the commit message text, and blocks
# if it contains references to Claude, AI, Anthropic, or Co-Authored-By attribution.
#
# Decision 17: Professional commit messages — no AI attribution.
# Prompt-level rule already exists in global CLAUDE.md; this adds deterministic
# hook enforcement.
#
# Message extraction strategy (avoiding false positives):
#   The hook does NOT scan the full command string. It extracts only the commit
#   message to avoid false-positive matches on file paths (e.g., git add claude-config/).
#   Three extraction methods tried in order:
#     1. Heredoc: $(cat <<'EOF' ... EOF) — Claude Code's default format
#     2. -m "message" or -m 'message'
#     3. --message="message" or --message='message'
#   If no message extracted, the hook allows silently (no false-positive blocking).
#
# Reference: peopleforrester/llm-coding-workflow claude-config/hooks/check-commit-message.sh
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision (deny only; silent passthrough on allow)
#
# Exit codes:
#   0 — Decision returned via JSON, or silent passthrough (allow)
#   1 — Unexpected error

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command from the hook input
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on git commit commands
# Must handle: git commit, git -C <path> commit, && git commit, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*commit\b'; then
  exit 0  # Not a commit command, silent passthrough
fi

# Extract commit message and check for AI references using Python
# Python handles heredoc, -m, and --message formats reliably across platforms
# (grep -oP is GNU-only and unavailable on macOS)
# Command passed via env var — cannot use pipe+heredoc together (both claim stdin)
RESULT=$(COMMIT_MSG_CMD="$COMMAND" python3 << 'PYEOF'
import re
import sys
import os

command = os.environ.get("COMMIT_MSG_CMD", "")

msg = ""

# Format 1: Heredoc — $(cat <<'EOF' ... EOF) — Claude Code's default commit format
heredoc_match = re.search(r"<<'?\"?EOF'?\"?\s*\n(.*?)\n\s*EOF", command, re.DOTALL)
if heredoc_match:
    msg = heredoc_match.group(1)

# Format 2: -m "message" or -m 'message' (backreference ensures matching quotes)
if not msg:
    m_match = re.search(r"""-m\s+(["'])(.+?)\1""", command, re.DOTALL)
    if m_match:
        msg = m_match.group(2)

# Format 3: --message="message" or --message='message'
if not msg:
    msg_match = re.search(r"""--message=(["'])(.+?)\1""", command, re.DOTALL)
    if msg_match:
        msg = msg_match.group(2)

# No message extracted — allow silently rather than false-positive block
if not msg:
    print("ALLOW")
    sys.exit(0)

# Check for AI/Claude references in the commit message (case-insensitive)
patterns = [
    (r"claude\s*code", "Claude Code"),
    (r"\bclaude\b", "Claude"),
    (r"\banthropic\b", "Anthropic"),
    (r"generated\s+with\s+(ai|claude|anthropic|llm|gpt|copilot)", "Generated with AI"),
    (r"co-authored-by.*claude", "Co-Authored-By Claude"),
    (r"co-authored-by.*anthropic", "Co-Authored-By Anthropic"),
    (r"\bai\s+assistant\b", "AI assistant"),
    (r"\bai[- ]generated\b", "AI-generated"),
    (r"language\s+model", "language model"),
]

for pattern, label in patterns:
    match = re.search(pattern, msg, re.IGNORECASE)
    if match:
        print(f"DENY:{match.group(0)}")
        sys.exit(0)

print("ALLOW")
PYEOF
)

# If Python failed, allow rather than false-positive block
if [ $? -ne 0 ]; then
  exit 0
fi

# Clean message — silent passthrough
if [[ "$RESULT" == ALLOW ]]; then
  exit 0
fi

# AI reference found — deny with structured JSON
if [[ "$RESULT" == DENY:* ]]; then
  MATCHED="${RESULT#DENY:}"
  COMMIT_MSG_MATCHED="$MATCHED" python3 -c "
import json, os

matched = os.environ['COMMIT_MSG_MATCHED']
reason = (
    f'Commit message contains AI/Claude reference: \"{matched}\". '
    f'Commit messages must describe the technical change only — never reference '
    f'Claude, AI, Anthropic, or include Co-Authored-By AI attribution. '
    f'Rewrite the commit message without AI references.'
)
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
  exit 0
fi

# Fallback: silent passthrough
exit 0
