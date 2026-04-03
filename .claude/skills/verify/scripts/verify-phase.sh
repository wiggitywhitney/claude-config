#!/usr/bin/env bash
# ABOUTME: Run a single verification phase (build, typecheck, lint, test) and report pass/fail
# ABOUTME: Used by pre-commit, pre-push, and pre-pr hooks to execute and evaluate verification commands
# verify-phase.sh — Run a single verification phase
#
# Usage: verify-phase.sh <phase> <command> [project-directory]
#
# Arguments:
#   phase   — Name of the phase (build, typecheck, lint, test) for display
#   command — The actual command to run
#   project-directory — Directory to run in (defaults to current directory)
#
# Exit codes:
#   0 — Phase passed
#   1 — Phase failed
#   2 — Invalid arguments

set -u
# Note: pipefail intentionally omitted. This script has no pipelines of its own,
# and pipefail can interfere with eval'd commands that contain implicit pipelines
# (e.g., npm process trees). The exit code from eval captures the command's result.

PHASE="${1:-}"
COMMAND="${2:-}"
PROJECT_DIR="${3:-.}"

if [ -z "$PHASE" ] || [ -z "$COMMAND" ]; then
  echo "ERROR: Usage: verify-phase.sh <phase> <command> [project-directory]"
  exit 2
fi

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || {
  echo "ERROR: Cannot resolve project directory: ${3:-.}"
  exit 2
}

echo "=== Phase: $PHASE ==="
echo "Command: $COMMAND"
echo "Directory: $PROJECT_DIR"
echo "---"

# Capture output to temp file so we can emit a structured error transcript on failure
TMPOUT=$(mktemp)
trap 'rm -f "$TMPOUT"' EXIT

# Run the command in the project directory
cd "$PROJECT_DIR" || exit 2
eval "$COMMAND" 2>&1 | tee "$TMPOUT"
EXIT_CODE=${PIPESTATUS[0]}

echo "---"
if [ $EXIT_CODE -eq 0 ]; then
  echo "RESULT: $PHASE PASSED"
else
  echo "RESULT: $PHASE FAILED (exit code $EXIT_CODE)"

  # Emit a structured error transcript so the LLM can produce a targeted fix suggestion.
  # Also write to /tmp so repeated failures on the same phase can reference prior attempts.
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u)
  OUTPUT_TAIL=$(tail -20 "$TMPOUT")
  ERROR_JSON=$(python3 -c "
import json, sys
data = {
    'phase': sys.argv[1],
    'command': sys.argv[2],
    'exit_code': int(sys.argv[3]),
    'timestamp': sys.argv[4],
    'output_tail': sys.argv[5],
}
sys.stdout.write(json.dumps(data))
" "$PHASE" "$COMMAND" "$EXIT_CODE" "$TIMESTAMP" "$OUTPUT_TAIL" 2>/dev/null)

  if [ -n "$ERROR_JSON" ]; then
    echo "VERIFY_ERROR_CONTEXT: $ERROR_JSON"
    echo "$ERROR_JSON" > "/tmp/verify-last-error-${PHASE}.json"
  fi
fi

echo "VERIFY_EXIT: $EXIT_CODE"

exit $EXIT_CODE
