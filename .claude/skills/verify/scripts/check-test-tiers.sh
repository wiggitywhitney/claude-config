#!/usr/bin/env bash
# check-test-tiers.sh — PreToolUse hook that warns about missing test tiers
#
# Installed as a PreToolUse hook on Bash.
# Detects git push and gh pr create commands, runs test tier detection,
# and warns (does NOT block) if unit, integration, or e2e tests are missing.
#
# Decision 18: Test tier enforcement as warn-only, not blocking.
# Decision 16: Respects .skip-e2e and .skip-integration dotfiles.
#
# Fires on the same events as pre-push-hook.sh and pre-pr-hook.sh but
# is purely advisory — always returns "allow".
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision (always allow)
#
# Exit codes:
#   0 — Decision returned via JSON (always allow, with advisory warnings)
#   1 — Unexpected error

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command from the hook input
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on git push and gh pr create commands
IS_PUSH=false
IS_PR=false

if echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*push\b'; then
  IS_PUSH=true
fi

if echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)gh\s+pr\s+create\b'; then
  IS_PR=true
fi

if [ "$IS_PUSH" = false ] && [ "$IS_PR" = false ]; then
  exit 0  # Not a push or PR command, silent passthrough
fi

# Determine project directory
PROJECT_DIR=$(echo "$COMMAND" | grep -oE '\-C\s+\S+' | head -1 | sed 's/^-C[[:space:]]*//' || true)
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Resolve script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run test tier detection
TIER_DETECTION=$("$SCRIPT_DIR/detect-test-tiers.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown","test_tiers":{"unit":false,"integration":false,"e2e":false}}')

PROJECT_TYPE=$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('project_type','unknown'))" 2>/dev/null || echo "unknown")

# Skip warning for unknown project types (no package.json, pyproject.toml, etc.)
if [ "$PROJECT_TYPE" = "unknown" ]; then
  exit 0  # Not a detectable project, silent passthrough
fi

# Extract tier results
HAS_UNIT=$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('test_tiers',{}).get('unit',False))" 2>/dev/null || echo "False")
HAS_INTEGRATION=$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('test_tiers',{}).get('integration',False))" 2>/dev/null || echo "False")
HAS_E2E=$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('test_tiers',{}).get('e2e',False))" 2>/dev/null || echo "False")

# Check for dotfile opt-outs (Decision 16)
SKIP_INTEGRATION=false
SKIP_E2E=false

if [ -f "$PROJECT_DIR/.skip-integration" ]; then
  SKIP_INTEGRATION=true
fi

if [ -f "$PROJECT_DIR/.skip-e2e" ]; then
  SKIP_E2E=true
fi

# Build list of missing tiers (not opted out)
MISSING_TIERS=""

if [ "$HAS_UNIT" = "False" ]; then
  MISSING_TIERS="unit"
fi

if [ "$HAS_INTEGRATION" = "False" ] && [ "$SKIP_INTEGRATION" = false ]; then
  if [ -n "$MISSING_TIERS" ]; then
    MISSING_TIERS="$MISSING_TIERS, integration"
  else
    MISSING_TIERS="integration"
  fi
fi

if [ "$HAS_E2E" = "False" ] && [ "$SKIP_E2E" = false ]; then
  if [ -n "$MISSING_TIERS" ]; then
    MISSING_TIERS="$MISSING_TIERS, e2e"
  else
    MISSING_TIERS="e2e"
  fi
fi

# If nothing is missing, silent passthrough
if [ -z "$MISSING_TIERS" ]; then
  exit 0
fi

# Warn about missing tiers (always allow — Decision 18)
# Uses additionalContext only (Claude-visible, not shown in UI).
# permissionDecisionReason is omitted on allow to prevent confusing "Error: ... passed"
# messages when another hook denies the same action (Decision 3, PRD 11).
WARN_MISSING="$MISSING_TIERS" WARN_PROJECT_TYPE="$PROJECT_TYPE" python3 -c "
import json, os

missing = os.environ['WARN_MISSING']
project_type = os.environ['WARN_PROJECT_TYPE']

result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'allow',
        'additionalContext': f'test-tier-warning: missing test tiers ({missing}) for {project_type} project. Consider adding test coverage. Use .skip-integration or .skip-e2e dotfiles to opt out. This is advisory only — not blocking.'
    }
}
print(json.dumps(result))
"
