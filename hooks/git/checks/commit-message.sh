#!/usr/bin/env bash
# ABOUTME: commit-msg check — blocks AI/Claude/Anthropic attribution in commit messages
# ABOUTME: Called by commit-msg dispatcher with the commit message file path as $1

set -uo pipefail

COMMIT_MSG_FILE="${1:-}"

if [[ -z "$COMMIT_MSG_FILE" ]] || [[ ! -f "$COMMIT_MSG_FILE" ]]; then
    exit 0  # No file or file missing — allow silently
fi

COMMIT_MSG_CONTENT="$(cat "$COMMIT_MSG_FILE")"

RESULT=$(COMMIT_MSG_CONTENT="$COMMIT_MSG_CONTENT" python3 << 'PYEOF'
import re, os, sys

msg = os.environ.get("COMMIT_MSG_CONTENT", "")

if not msg:
    print("ALLOW")
    sys.exit(0)

# Path-aware patterns: exclude "claude" when adjacent to path characters (/, ., -)
# e.g., ~/.claude/, CLAUDE.md, claude-config are file paths — not AI attribution
patterns = [
    (r"(?<![/.])\bclaude\s*code\b", "Claude Code"),
    (r"(?<![/.\-])\bclaude\b(?![/.\-])", "Claude"),
    (r"(?<![/.\-])\banthropic\b(?![/.\-])", "Anthropic"),
    (r"generated\s+with\s+(ai|claude|anthropic|llm|gpt|copilot)", "Generated with AI"),
    (r"co-authored-by[^\n]*claude", "Co-Authored-By Claude"),
    (r"co-authored-by[^\n]*anthropic", "Co-Authored-By Anthropic"),
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

if [[ "$RESULT" == ALLOW ]]; then
    exit 0
fi

if [[ "$RESULT" == DENY:* ]]; then
    MATCHED="${RESULT#DENY:}"
    echo "ERROR: Commit message contains AI/Claude reference: \"$MATCHED\"" >&2
    echo "Commit messages must describe the technical change only." >&2
    echo "Never reference Claude, AI, Anthropic, or include Co-Authored-By AI attribution." >&2
    echo "Rewrite the commit message without AI references." >&2
    exit 1
fi

# Fallback — allow
exit 0
