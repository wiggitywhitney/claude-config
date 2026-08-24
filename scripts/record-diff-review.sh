#!/usr/bin/env bash
# ABOUTME: Writes the diff-review verdict file that the push gate looks for.
# ABOUTME: Defaults the verdict key to the current outgoing diff; --key exists for benchmark worktrees.
#
# record-diff-review.sh — the deterministic half of the diff-review dispatch
#
# The judgment belongs to the sub-agent; naming the file, stamping the time, and
# writing valid JSON do not, so they live here rather than in a prompt. This is
# also what keeps the key honest: the recorder derives it from the same script
# the gate uses instead of accepting whatever the reviewer believed it read.
#
# Usage:
#   record-diff-review.sh [-C <dir>] --findings <n> [--reviewer <name>] [--key <key>] [--notes <text>]
#
# Exit codes:
#   0 — verdict written
#   1 — the key could not be computed
#   2 — bad usage

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYGEN="$SCRIPT_DIR/compute-diff-key.sh"

DIR="."
KEY=""
FINDINGS=""
REVIEWER="diff-reviewer"
NOTES=""

usage() {
  echo "usage: record-diff-review.sh [-C <dir>] --findings <n> [--reviewer <name>] [--key <key>] [--notes <text>]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -C|--key|--findings|--reviewer|--notes)
      if [[ $# -lt 2 ]]; then
        echo "record-diff-review.sh: $1 requires a value" >&2
        usage
        exit 2
      fi
      case "$1" in
        -C) DIR="$2" ;;
        --key) KEY="$2" ;;
        --findings) FINDINGS="$2" ;;
        --reviewer) REVIEWER="$2" ;;
        --notes) NOTES="$2" ;;
      esac
      shift 2
      ;;
    *)
      echo "record-diff-review.sh: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$FINDINGS" ]]; then
  echo "record-diff-review.sh: --findings is required — a verdict with no count is not a verdict" >&2
  usage
  exit 2
fi

if ! [[ "$FINDINGS" =~ ^[0-9]+$ ]]; then
  echo "record-diff-review.sh: --findings must be a non-negative integer, got: $FINDINGS" >&2
  exit 2
fi

if [[ -z "$KEY" ]]; then
  if ! KEY=$("$KEYGEN" -C "$DIR"); then
    echo "record-diff-review.sh: could not compute the verdict key for $DIR" >&2
    exit 1
  fi
fi

OUT_DIR="$DIR/.claude/diff-review"
mkdir -p "$OUT_DIR"

HOOK_KEY="$KEY" HOOK_FINDINGS="$FINDINGS" HOOK_REVIEWER="$REVIEWER" HOOK_NOTES="$NOTES" \
  python3 -c "
import json, os
from datetime import datetime, timezone

verdict = {
    'key': os.environ['HOOK_KEY'],
    'findings': int(os.environ['HOOK_FINDINGS']),
    'reviewer': os.environ['HOOK_REVIEWER'],
    'notes': os.environ['HOOK_NOTES'],
    'recorded_at': datetime.now(timezone.utc).isoformat(),
}
print(json.dumps(verdict, indent=2))
" > "$OUT_DIR/$KEY.json" || {
  echo "record-diff-review.sh: failed to write the verdict" >&2
  exit 1
}

echo "Recorded verdict for ${KEY:0:12} — $FINDINGS finding(s), reviewer $REVIEWER"
