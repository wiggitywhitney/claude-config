#!/usr/bin/env bash
# ABOUTME: PreToolUse hook that blocks git push until a diff-review verdict exists for the outgoing diff.
# ABOUTME: The verdict is keyed to diff content, so a review of an earlier diff cannot satisfy a later push.
#
# check-diff-review-required.sh — the push gate for the diff-reviewer trial
#
# Installed as a Claude Code PreToolUse hook on Bash, registered in this repo's
# project settings rather than globally: the reviewer is on trial, and a gate
# that misfires should cost one repo rather than every repo.
#
# A hook is a shell script and cannot spawn a sub-agent, so it can only refuse
# to proceed. That refusal is the whole mechanism — it is what makes the review
# step mandatory rather than a habit that decays.
#
# Shape borrowed from check-coderabbit-required.sh, including its distinction
# between "no verdict" and "could not look," which need different actions from
# the reader: run the review, versus fix why the diff cannot be identified.
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision (deny only; silent passthrough on allow)
#
# Exit codes:
#   0 — Decision returned via JSON, or silent passthrough (allow)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYGEN="$SCRIPT_DIR/../../../../scripts/compute-diff-key.sh"

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Strip heredoc bodies, then quoted strings, before matching. A commit message
# or PR body that mentions pushing must not trip the gate, and quote-stripping
# alone never sees inside a <<'EOF' ... EOF body. This gate blocked its own first
# commit for exactly that reason: the message describing what the gate does
# contained the words it matches on.
COMMAND_NO_HEREDOC=""
HEREDOC_TERM=""
while IFS= read -r heredoc_line; do
  if [[ -n "$HEREDOC_TERM" ]]; then
    if [[ "${heredoc_line//[[:space:]]/}" == "$HEREDOC_TERM" ]]; then
      HEREDOC_TERM=""
    fi
    continue
  fi
  COMMAND_NO_HEREDOC+="$heredoc_line"$'\n'
  if [[ "$heredoc_line" =~ \<\<-?[[:space:]]*[\"\']?([A-Za-z_][A-Za-z0-9_]*)[\"\']? ]]; then
    HEREDOC_TERM="${BASH_REMATCH[1]}"
  fi
done <<< "$COMMAND"

COMMAND_NO_QUOTES=$(echo "$COMMAND_NO_HEREDOC" | sed -E "s/\"([^\"]*)\"/\"\"/g; s/'([^']*)'/\\'\\'/g; s/\\$\\(cat <<[^)]*\\)//g")
if ! echo "$COMMAND_NO_QUOTES" | grep -qE '(^|[[:space:]]|&&[[:space:]]*|;[[:space:]]*)git[[:space:]]+push([[:space:]]|;|$)'; then
  exit 0  # Not a push, silent passthrough
fi

# Resolve the repository the push would come from: a cd in the command wins over
# the session's cwd, because "cd <repo> && git push" pushes the repo, not the cwd.
CD_PATH=$(echo "$COMMAND" | grep -oE '(^|&&[[:space:]]*|;[[:space:]]*)cd[[:space:]]+[^ ;&]+' | head -1 | sed 's/.*cd[[:space:]]*//' || true)
if [[ -n "$CD_PATH" ]] && [[ -d "$CD_PATH" ]]; then
  PROJECT_DIR="$CD_PATH"
else
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Not a repository at all — nothing this gate can meaningfully say.
if ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

deny() {
  HOOK_DENY_REASON="$1" python3 -c "
import json, os
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': os.environ['HOOK_DENY_REASON']
    }
}
print(json.dumps(result, indent=1))
"
  exit 0
}

if ! KEY=$("$KEYGEN" -C "$PROJECT_DIR" 2>/dev/null); then
  deny "Push blocked — the outgoing diff could not be identified, so there is nothing to match a review verdict against. This is not evidence that a review is missing. Run scripts/compute-diff-key.sh to see why it failed; the usual cause is a branch with no upstream in a repo with no origin/main."
fi

# An empty outgoing diff has nothing to review.
EMPTY_KEY=$(printf '' | shasum -a 256 | awk '{print $1}')
if [[ "$KEY" == "$EMPTY_KEY" ]]; then
  exit 0
fi

VERDICT="$PROJECT_DIR/.claude/diff-review/$KEY.json"
if [[ -f "$VERDICT" ]]; then
  exit 0
fi

deny "Push blocked — no diff review verdict exists for the outgoing diff (key ${KEY:0:12}). Run /diff-review to dispatch the diff-reviewer sub-agent and record a verdict, then push again. A verdict recorded for an earlier diff does not carry over: the key is a hash of the diff content, so adding or amending a commit invalidates it deliberately."
