#!/usr/bin/env bash
# ABOUTME: PreToolUse hook that gates PR creation on expanded security, tests, and advisory acceptance gate
# ABOUTME: Runs after commit (build/typecheck/lint) and push (security) tiers; includes optional acceptance tests
# pre-pr-hook.sh — PreToolUse hook that gates PR creation on expanded security + tests
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects gh pr create commands, runs expanded security checks and tests,
# and blocks PR creation if any phase fails.
#
# This is the incremental final tier of verification:
#   git commit   → build, typecheck, lint (pre-commit-hook.sh)
#   git push     → standard security (pre-push-hook.sh)
#   gh pr create → expanded security, tests (this hook, blocking)
#   gh pr create → acceptance gate tests with live API (this hook, advisory)
#
# Each tier runs only checks not covered by earlier tiers.
# Acceptance gate tests are advisory — they never block PR creation but
# require human review of results before Claude proceeds.
#
# Expanded security checks include everything beyond standard mode:
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

# Run project detection (needed for test command)
DETECTION=$("$SCRIPT_DIR/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown"}')

# Extract test command — build, typecheck, and lint already passed at commit time
CMD_TEST=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('test') or '')" 2>/dev/null || echo "")

# Extract acceptance test command (advisory tier)
CMD_ACCEPTANCE_TEST=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('acceptance_test') or '')" 2>/dev/null || echo "")

# Fallback detection: acceptance-gate.test.ts files + .vals.yaml (PRD 28, Decision 3)
if [[ -z "$CMD_ACCEPTANCE_TEST" ]] && [[ -f "$PROJECT_DIR/.vals.yaml" ]]; then
  ACCEPTANCE_FILES=$(find "$PROJECT_DIR/test" -name "acceptance-gate.test.ts" 2>/dev/null | head -1)
  if [[ -n "$ACCEPTANCE_FILES" ]]; then
    CMD_ACCEPTANCE_TEST="vals exec -f .vals.yaml -- bash -c 'shopt -s globstar && npx vitest run test/**/acceptance-gate.test.ts'"
  fi
fi

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

# Docs-only early exit: skip verification if all branch changes are documentation-only.
# Security and test checks are code-oriented — irrelevant for docs (Decision 4, PRD 11).
if [ -n "$DIFF_BASE" ]; then
  BRANCH_FILES=$(git -C "$PROJECT_DIR" diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null || echo "")
  if [ -n "$BRANCH_FILES" ] && echo "$BRANCH_FILES" | "$SCRIPT_DIR/is-docs-only.sh"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"verify: PR skipped — docs-only changes detected (no code files in branch diff)"}}'
    exit 0
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

# Pre-PR verification: Security (expanded) → Tests
# Build, typecheck, and lint already passed at commit time.
# Standard security already passed at push time.
# This tier adds expanded security and tests only.

# Phase 1: Security (pre-pr expanded mode, before tests per Decision 12)
security_output=$("$SCRIPT_DIR/security-check.sh" "pre-pr" "$PROJECT_DIR" "$DIFF_BASE" 2>&1)
if [ $? -ne 0 ]; then
  FAILED_PHASE="security"
  FAILURE_OUTPUT="$security_output"
fi

# Phase 2: Tests (most expensive blocking phase)
if [ -z "$FAILED_PHASE" ]; then
  run_phase "test" "$CMD_TEST" || true
fi

# Phase 3: Acceptance gate tests (advisory — never blocks PR creation)
# Only runs after standard phases pass. No point spending API money if PR is blocked anyway.

# Inject --reporter=verbose for vitest commands (PRD 35, M1)
# Verbose output makes failure root cause identifiable without digging through logs.
if [[ -n "$CMD_ACCEPTANCE_TEST" ]] && echo "$CMD_ACCEPTANCE_TEST" | grep -q 'vitest' && ! echo "$CMD_ACCEPTANCE_TEST" | grep -q '\-\-reporter'; then
  CMD_ACCEPTANCE_TEST=$(echo "$CMD_ACCEPTANCE_TEST" | sed 's/vitest run/vitest run --reporter=verbose/')
fi

ACCEPTANCE_CONTEXT=""
if [[ -z "$FAILED_PHASE" ]] && [[ -n "$CMD_ACCEPTANCE_TEST" ]]; then
  acceptance_output=$(cd "$PROJECT_DIR" && timeout 1800 bash -c "$CMD_ACCEPTANCE_TEST" 2>&1)
  acceptance_exit=$?

  # Check for timeout (exit code 124 from timeout command)
  if [[ $acceptance_exit -eq 124 ]]; then
    ACCEPTANCE_CONTEXT="MANDATORY: Acceptance gate tests timed out after 1800 seconds. You MUST present this to the user and get explicit approval before proceeding with PR creation without full acceptance results."
  # Check if vals/API key was unavailable (exit code 127 = command not found, or specific error patterns)
  elif [[ $acceptance_exit -eq 127 ]] || \
     echo "$acceptance_output" | grep -qiE '(vals: command not found|vals: not found|ANTHROPIC_API_KEY.*(missing|not set)|API[_ ]?KEY.*(missing|not set)|secret.*(missing|not found))' 2>/dev/null; then
    ACCEPTANCE_CONTEXT="Acceptance gate tests skipped — vals or API key not available."
  else
    # Sanitize and truncate output
    acceptance_output=$(echo "$acceptance_output" | head -c 8000)
    ACCEPTANCE_CONTEXT="MANDATORY: Acceptance gate tests with live API completed. You MUST present these results to the user and get explicit approval before proceeding with PR creation. Do NOT continue automatically.

$acceptance_output"
  fi
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

reason = f'PR creation blocked — security+tests check failed at phase: {phase}. Fix the underlying code to resolve the error. NEVER add suppression annotations (@ts-ignore, type:ignore, lint-disable) to bypass the check — fix the actual problem. The ONE exception: eslint-disable-line no-console is allowed for intentional CLI output (the security check already accepts it).\n\n{output}'
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
  BASE_CONTEXT="verify: PR security+tests check passed (expanded security, tests) ✓"
  if [[ -n "$ACCEPTANCE_CONTEXT" ]]; then
    # Append acceptance gate results — Claude must present these to the user
    VERIFY_BASE_CONTEXT="$BASE_CONTEXT" VERIFY_ACCEPTANCE_CONTEXT="$ACCEPTANCE_CONTEXT" python3 -c "
import json, os

base = os.environ['VERIFY_BASE_CONTEXT']
acceptance = os.environ['VERIFY_ACCEPTANCE_CONTEXT']

# Sanitize: remove invalid Unicode surrogates
acceptance = acceptance.encode('utf-8', errors='replace').decode('utf-8')

context = base + '\n\n' + acceptance
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'allow',
        'additionalContext': context
    }
}
print(json.dumps(result))
"
  else
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"'"$BASE_CONTEXT"'"}}'
  fi
fi
