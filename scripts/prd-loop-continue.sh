#!/usr/bin/env bash
# SessionStart (clear) hook: Detects if we're on a PRD feature branch and
# injects continuation guidance after /clear.
#
# stdout → gets injected into Claude's context (this is the injection mechanism)
# stderr → shown to the user only, not to Claude

set -euo pipefail

# Read the JSON payload from stdin
PAYLOAD=$(cat)

# Extract cwd from payload; fall back to $PWD
CWD=$(printf '%s' "$PAYLOAD" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('cwd') or '')
except Exception:
    print('')
" 2>/dev/null || true)

if [[ -z "$CWD" ]]; then
    CWD="$PWD"
fi

# Check if we're in a git repo and get current branch
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || true)
if [[ -z "$BRANCH" ]]; then
    exit 0  # Not in a git repo — no-op
fi

# Check if on a feature/prd-* branch
if [[ ! "$BRANCH" =~ ^feature/prd-([0-9]+) ]]; then
    exit 0  # Not on a PRD branch — no-op
fi

PRD_NUMBER="${BASH_REMATCH[1]}"

# Find the PRD file (match by number prefix)
PRD_DIR="$CWD/prds"
if [[ ! -d "$PRD_DIR" ]]; then
    echo "[prd-loop] No prds/ directory found" >&2
    exit 0
fi

# Use shell glob to find the PRD file by number prefix
PRD_FILE=""
for f in "$PRD_DIR"/"${PRD_NUMBER}"-*.md; do
    if [[ -f "$f" ]]; then
        PRD_FILE="$f"
        break
    fi
done

if [[ -z "$PRD_FILE" ]]; then
    echo "[prd-loop] No PRD file found matching #${PRD_NUMBER} in $PRD_DIR" >&2
    exit 0
fi

PRD_BASENAME=$(basename "$PRD_FILE")

# Count unchecked items: lines matching "- [ ] " (standard markdown checkbox)
# Only count actual unchecked [ ] — not [~] deferred or [!] blocked
UNCHECKED=$(grep -cE '^[[:space:]]*- \[ \] ' "$PRD_FILE" 2>/dev/null || true)
UNCHECKED=${UNCHECKED:-0}

if [[ "$UNCHECKED" -gt 0 ]]; then
    # Items remain — inject /prd-next guidance
    cat <<EOF
You are continuing PRD work after a /clear checkpoint.

**Active PRD**: #${PRD_NUMBER} (${PRD_BASENAME})
**Branch**: ${BRANCH}
**Remaining items**: ${UNCHECKED} unchecked

Continue the autonomous loop by running \`/prd-next\`.
EOF
else
    # All items complete (or no checkboxes) — inject /prd-done guidance
    cat <<EOF
You are continuing PRD work after a /clear checkpoint.

**Active PRD**: #${PRD_NUMBER} (${PRD_BASENAME})
**Branch**: ${BRANCH}
**Status**: All PRD items are complete!

Run \`/prd-done\` to create the PR, process CodeRabbit review, and close the issue.
EOF
fi
