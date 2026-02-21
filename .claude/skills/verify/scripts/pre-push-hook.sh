#!/usr/bin/env bash
# pre-push-hook.sh — PreToolUse hook that gates git push on standard security check
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects git push commands, runs standard security checks (debug code,
# .only leaks) and blocks the push if any check fails.
#
# This is the incremental middle tier of verification:
#   git commit   → build, typecheck, lint (pre-commit-hook.sh)
#   git push     → standard security (this hook)
#   gh pr create → expanded security, tests (pre-pr-hook.sh)
#
# Each tier runs only checks not covered by earlier tiers.
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision
#
# Exit codes:
#   0 — Decision returned via JSON (allow or deny)
#   1 — Unexpected error

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command from the hook input
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on git push commands
# Must handle: git push, git -C <path> push, && git push, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*push\b'; then
  exit 0  # Not a push command, allow it
fi

# Determine project directory from hook input
# If git -C <path> is used, that path overrides cwd
PROJECT_DIR=$(echo "$COMMAND" | grep -oE '\-C\s+\S+' | head -1 | sed 's/^-C[[:space:]]*//' || true)
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Resolve script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Compute diff base for scoping security checks (Decision 7)
# Hooks scope checks to branch changes, not the whole repo.
DIFF_BASE=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
if [ -z "$DIFF_BASE" ]; then
  if git -C "$PROJECT_DIR" rev-parse --verify origin/main &>/dev/null; then
    DIFF_BASE="origin/main"
  elif git -C "$PROJECT_DIR" rev-parse --verify origin/master &>/dev/null; then
    DIFF_BASE="origin/master"
  fi
fi

# Run standard security check (the only phase at push tier)
# Build, typecheck, and lint already passed at commit time.
# Expanded security and tests are deferred to the PR tier.
FAILED_PHASE=""
FAILURE_OUTPUT=""

security_output=$("$SCRIPT_DIR/security-check.sh" "standard" "$PROJECT_DIR" "$DIFF_BASE" 2>&1)
if [ $? -ne 0 ]; then
  FAILED_PHASE="security"
  FAILURE_OUTPUT="$security_output"
fi

# Return decision
if [ -n "$FAILED_PHASE" ]; then
  # Security check failed — deny the push
  VERIFY_FAILED_PHASE="$FAILED_PHASE" VERIFY_FAILURE_OUTPUT="$FAILURE_OUTPUT" python3 -c "
import json, os

phase = os.environ['VERIFY_FAILED_PHASE']
output = os.environ['VERIFY_FAILURE_OUTPUT']

# Sanitize output: remove invalid Unicode surrogates that break JSON serialization
output = output.encode('utf-8', errors='replace').decode('utf-8')

# Truncate to prevent oversized API payloads
MAX_OUTPUT = 4000
if len(output) > MAX_OUTPUT:
    output = output[:MAX_OUTPUT] + '\n\n... (output truncated)'

reason = f'Push blocked — security check failed at phase: {phase}. Fix the underlying code to resolve the error. NEVER add suppression annotations (@ts-ignore, type:ignore, lint-disable) to bypass the check — fix the actual problem. The ONE exception: eslint-disable-line no-console is allowed for intentional CLI output (the security check already accepts it).\n\n{output}'
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
else
  # Security check passed — use additionalContext only (Claude-visible, not shown in UI).
  # permissionDecisionReason is omitted on allow to prevent confusing "Error: ... passed"
  # messages when another hook denies the same action (Decision 3, PRD 11).
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"verify: push security check passed (standard security) ✓"}}'
fi
