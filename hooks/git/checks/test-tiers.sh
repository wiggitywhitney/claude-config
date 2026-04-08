#!/usr/bin/env bash
# ABOUTME: pre-push advisory check — warns when test tiers (unit, integration, e2e) are missing
# ABOUTME: Never blocks the push (always exits 0); respects .skip-integration and .skip-e2e opt-outs

set -uo pipefail

# pre-push dispatcher passes remote name and URL as positional args
REMOTE_NAME="${1:-}"
REMOTE_URL="${2:-}"

# Project root is cwd when a native pre-push hook fires
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# Locate detect-test-tiers.sh in the sibling lib/ directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT_SCRIPT="$SCRIPT_DIR/../lib/detect-test-tiers.sh"

if [[ ! -f "$DETECT_SCRIPT" ]]; then
    exit 0  # Detection script unavailable — skip silently
fi

TIER_DETECTION="$("$DETECT_SCRIPT" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown","test_tiers":{"unit":false,"integration":false,"e2e":false}}')"

PROJECT_TYPE="$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('project_type','unknown'))" 2>/dev/null || echo "unknown")"

if [[ "$PROJECT_TYPE" = "unknown" ]]; then
    exit 0  # No detectable project type — skip silently
fi

HAS_UNIT="$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('test_tiers',{}).get('unit',False))" 2>/dev/null || echo "False")"
HAS_INTEGRATION="$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('test_tiers',{}).get('integration',False))" 2>/dev/null || echo "False")"
HAS_E2E="$(echo "$TIER_DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('test_tiers',{}).get('e2e',False))" 2>/dev/null || echo "False")"

SKIP_INTEGRATION=false
SKIP_E2E=false
[[ -f "$PROJECT_DIR/.skip-integration" ]] && SKIP_INTEGRATION=true
[[ -f "$PROJECT_DIR/.skip-e2e" ]] && SKIP_E2E=true

MISSING_TIERS=()
[[ "$HAS_UNIT" = "False" ]] && MISSING_TIERS+=("unit")
[[ "$HAS_INTEGRATION" = "False" ]] && [[ "$SKIP_INTEGRATION" = false ]] && MISSING_TIERS+=("integration")
[[ "$HAS_E2E" = "False" ]] && [[ "$SKIP_E2E" = false ]] && MISSING_TIERS+=("e2e")

if [[ ${#MISSING_TIERS[@]} -eq 0 ]]; then
    exit 0
fi

MISSING_STR="$(IFS=', '; echo "${MISSING_TIERS[*]}")"

{
    echo "WARNING: Missing test tiers ($MISSING_STR) for $PROJECT_TYPE project."
    [[ "$HAS_UNIT" = "False" ]] && echo "  unit: every project needs unit tests — write them before proceeding."
    if [[ "$HAS_INTEGRATION" = "False" ]] && [[ "$SKIP_INTEGRATION" = false ]]; then
        echo "  integration: if this project has external integrations, write integration tests."
        echo "    To suppress: touch .skip-integration"
    fi
    if [[ "$HAS_E2E" = "False" ]] && [[ "$SKIP_E2E" = false ]]; then
        echo "  e2e: if this project has user-facing workflows, write e2e tests."
        echo "    To suppress: touch .skip-e2e"
    fi
} >&2

exit 0  # Advisory only — never blocks
