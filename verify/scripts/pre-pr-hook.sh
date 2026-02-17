#!/usr/bin/env bash
# pre-pr-hook.sh — PreToolUse hook that gates PR creation on pre-pr verification
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects gh pr create commands, runs pre-pr verification (Build, Type Check,
# Lint, Security with expanded checks, Tests) and blocks PR creation if any
# phase fails.
#
# This is the heaviest tier of verification (Decision 10):
#   git commit   → quick+lint (pre-commit-hook.sh)
#   git push     → full verification (pre-push-hook.sh)
#   gh pr create → pre-pr verification (this hook)
#
# Pre-pr security checks include everything in standard mode plus:
#   - npm audit for dependency vulnerabilities
#   - Grep for hardcoded secrets/API keys in staged diff
#   - Check that no .env files are staged
#
# Phase ordering per Decision 12: Security before Tests (fail-fast).
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

# Only act on gh pr create commands
# Must handle: gh pr create, && gh pr create, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)gh\s+pr\s+create\b'; then
  exit 0  # Not a PR creation command, allow it
fi

# Determine project directory from hook input (gh doesn't use -C, rely on cwd)
PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")

# Resolve script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run project detection
DETECTION=$("$SCRIPT_DIR/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown"}')

PROJECT_TYPE=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('project_type','unknown'))" 2>/dev/null || echo "unknown")

# Extract available commands for pre-pr verification mode
CMD_BUILD=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('build') or '')" 2>/dev/null || echo "")
CMD_TYPECHECK=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('typecheck') or '')" 2>/dev/null || echo "")
CMD_LINT=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('lint') or '')" 2>/dev/null || echo "")
CMD_TEST=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('test') or '')" 2>/dev/null || echo "")

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

# Pre-PR verification: Build → Type Check → Lint → Security (expanded) → Tests (Decision 12)

# Phase 1: Build
run_phase "build" "$CMD_BUILD" || true

# Phase 2: Type Check
if [ -z "$FAILED_PHASE" ]; then
  run_phase "typecheck" "$CMD_TYPECHECK" || true
fi

# Phase 3: Lint
if [ -z "$FAILED_PHASE" ]; then
  run_phase "lint" "$CMD_LINT" || true
fi

# Phase 4: Security (pre-pr expanded mode, before tests per Decision 12)
if [ -z "$FAILED_PHASE" ]; then
  security_output=$("$SCRIPT_DIR/security-check.sh" "pre-pr" "$PROJECT_DIR" "$DIFF_BASE" 2>&1)
  if [ $? -ne 0 ]; then
    FAILED_PHASE="security"
    FAILURE_OUTPUT="$security_output"
  fi
fi

# Phase 5: Tests (last — most expensive phase)
if [ -z "$FAILED_PHASE" ]; then
  run_phase "test" "$CMD_TEST" || true
fi

# Return decision
if [ -n "$FAILED_PHASE" ]; then
  # Verification failed — deny PR creation
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

reason = f'PR creation blocked — pre-pr verification failed at phase: {phase}. Fix the issue and try again.\n\n{output}'
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
  # All phases passed
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"verify: pre-pr check passed ✓","additionalContext":"verify: pre-pr verification passed (build, typecheck, lint, security+audit, tests) ✓"}}'
fi
