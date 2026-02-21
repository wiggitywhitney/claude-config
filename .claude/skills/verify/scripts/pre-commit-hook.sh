#!/usr/bin/env bash
# pre-commit-hook.sh — PreToolUse hook that gates git commit on quick+lint verification
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects git commit commands, runs quick+lint verification (Build, Type Check,
# Lint) and blocks the commit if any phase fails.
#
# This is the lightest tier of verification (Decision 10):
#   git commit  → quick+lint (this hook)
#   git push    → full verification (pre-push-hook.sh)
#   gh pr create → pre-pr verification (pre-pr-hook.sh)
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

# Only act on git commit commands
# Must handle: git commit, git -C <path> commit, && git commit, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*commit\b'; then
  exit 0  # Not a commit command, allow it
fi

# Determine project directory from hook input
# If git -C <path> is used, that path overrides cwd
PROJECT_DIR=$(echo "$COMMAND" | grep -oE '\-C\s+\S+' | head -1 | sed 's/^-C[[:space:]]*//' || true)
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Resolve script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run project detection
DETECTION=$("$SCRIPT_DIR/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown"}')

PROJECT_TYPE=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('project_type','unknown'))" 2>/dev/null || echo "unknown")

# Extract available commands for quick+lint mode (Build, Type Check, Lint only)
CMD_BUILD=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('build') or '')" 2>/dev/null || echo "")
CMD_TYPECHECK=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('typecheck') or '')" 2>/dev/null || echo "")
CMD_LINT=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('lint') or '')" 2>/dev/null || echo "")

# Run verification phases in order, stop on first failure
FAILED_PHASE=""
FAILURE_OUTPUT=""

run_phase() {
  local phase_name="$1"
  local phase_cmd="$2"

  if [ -z "$phase_cmd" ]; then
    return 0  # Skip phases with no command
  fi

  local output
  output=$("$SCRIPT_DIR/verify-phase.sh" "$phase_name" "$phase_cmd" "$PROJECT_DIR" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    FAILED_PHASE="$phase_name"
    FAILURE_OUTPUT="$output"
    return 1
  fi
  return 0
}

# Quick+lint mode: Build → Type Check → Lint (Decision 10)
# Security and tests are deferred to push and PR hooks respectively.

# Phase 1: Build
run_phase "build" "$CMD_BUILD" || true

# Phase 2: Type Check (only if build passed)
if [ -z "$FAILED_PHASE" ]; then
  run_phase "typecheck" "$CMD_TYPECHECK" || true
fi

# Phase 3: Lint — scoped to staged files only (Decision 7)
if [ -z "$FAILED_PHASE" ]; then
  lint_output=$("$SCRIPT_DIR/lint-changed.sh" "staged" "$PROJECT_DIR" "$CMD_LINT" 2>&1)
  if [ $? -ne 0 ]; then
    FAILED_PHASE="lint"
    FAILURE_OUTPUT="$lint_output"
  fi
fi

# Return decision
if [ -n "$FAILED_PHASE" ]; then
  # Verification failed — deny the commit
  # Pass data via environment variables to avoid shell interpolation issues
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

reason = f'Verification failed at phase: {phase}. Fix the underlying code to resolve the error. NEVER add suppression annotations (@ts-ignore, type:ignore, lint-disable) to bypass the check — fix the actual problem. The ONE exception: eslint-disable-line no-console is allowed for intentional CLI output (the security check already accepts it).\n\n{output}'
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
  # All phases passed — use additionalContext only (Claude-visible, not shown in UI).
  # permissionDecisionReason is omitted on allow to prevent confusing "Error: ... passed"
  # messages when another hook denies the same action (Decision 3, PRD 11).
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"verify: commit quick+lint passed (build, typecheck, lint) ✓"}}'
fi
