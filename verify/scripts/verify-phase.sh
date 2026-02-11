#!/usr/bin/env bash
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

set -uo pipefail

PHASE="${1:-}"
COMMAND="${2:-}"
PROJECT_DIR="${3:-.}"

if [ -z "$PHASE" ] || [ -z "$COMMAND" ]; then
  echo "ERROR: Usage: verify-phase.sh <phase> <command> [project-directory]"
  exit 2
fi

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo "=== Phase: $PHASE ==="
echo "Command: $COMMAND"
echo "Directory: $PROJECT_DIR"
echo "---"

# Run the command in the project directory
cd "$PROJECT_DIR"
eval "$COMMAND" 2>&1
EXIT_CODE=$?

echo "---"
if [ $EXIT_CODE -eq 0 ]; then
  echo "RESULT: $PHASE PASSED"
else
  echo "RESULT: $PHASE FAILED (exit code $EXIT_CODE)"
fi

exit $EXIT_CODE
