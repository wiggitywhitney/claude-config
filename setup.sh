#!/usr/bin/env bash
# setup.sh — Portable Claude Code configuration installer
#
# Milestone 1: Resolves settings.template.json with machine-specific paths.
#
# Usage:
#   ./setup.sh                        Print resolved settings to stdout
#   ./setup.sh --output FILE          Write resolved settings to FILE
#   ./setup.sh --validate             Resolve and validate paths (no file output)
#   ./setup.sh --template FILE        Use a custom template (default: settings.template.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CONFIG_DIR="$SCRIPT_DIR"

# Defaults
TEMPLATE="$CLAUDE_CONFIG_DIR/settings.template.json"
OUTPUT=""
VALIDATE_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --validate)
            VALIDATE_ONLY=true
            shift
            ;;
        --template)
            TEMPLATE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: setup.sh [--output FILE] [--validate] [--template FILE]" >&2
            exit 1
            ;;
    esac
done

# Verify template exists
if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Template not found: $TEMPLATE" >&2
    exit 1
fi

# Resolve placeholders — use | as sed delimiter to avoid escaping /
RESOLVED=$(sed "s|\\\$CLAUDE_CONFIG_DIR|${CLAUDE_CONFIG_DIR}|g" "$TEMPLATE")

# Validate JSON
if ! echo "$RESOLVED" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "Error: Resolved template is not valid JSON" >&2
    exit 1
fi

# Validate that all hook command paths exist on disk
MISSING_PATHS=$(echo "$RESOLVED" | python3 -c "
import json, sys, os
data = json.load(sys.stdin)
missing = []
for event_type, matchers in data.get('hooks', {}).items():
    for matcher in matchers:
        for hook in matcher.get('hooks', []):
            path = hook.get('command', '')
            if path and not os.path.isfile(path):
                missing.append(path)
for p in missing:
    print(p)
" 2>/dev/null)

if [[ -n "$MISSING_PATHS" ]]; then
    echo "Error: Hook script paths do not exist:" >&2
    echo "$MISSING_PATHS" >&2
    exit 1
fi

# Validate-only mode: report and exit
if [[ "$VALIDATE_ONLY" == true ]]; then
    echo "All hook paths valid. Template resolves correctly."
    exit 0
fi

# Output resolved settings
if [[ -n "$OUTPUT" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    echo "$RESOLVED" > "$OUTPUT"
else
    echo "$RESOLVED"
fi
