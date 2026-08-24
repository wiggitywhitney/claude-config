#!/usr/bin/env bash
# ABOUTME: Prints a content hash of the outgoing diff, used as the verdict key for diff review.
# ABOUTME: Called by both the dispatch step and the push gate so the two cannot disagree on the key.
#
# compute-diff-key.sh — the shared key for the diff-review push gate
#
# Keying the verdict to diff *content* rather than to a commit SHA is what makes
# a stale verdict unable to satisfy a later push: adding a commit, amending one,
# or discovering that more is outgoing than the review assumed all change the
# hash, so the gate stops finding a verdict for it.
#
# Base resolution, in order. Each step is tried only because the previous one
# found nothing, and exhausting them is a hard failure rather than a default:
#   1. the branch's configured upstream
#   2. origin/main
#   3. no base — exit non-zero and say so, because guessing a base would produce
#      a key that looks valid and describes the wrong diff
#
# Usage: compute-diff-key.sh [-C <dir>] [--print-base]
# Output: 64-character hex digest on stdout, or the resolved base commit with
#         --print-base. The base is exposed so callers that need the diff text
#         can ask for it rather than restating this resolution order in prose,
#         which would leave two descriptions of one fact free to drift apart.
#
# Exit codes:
#   0 — key printed
#   1 — not a git repository, or no base to diff against
#   2 — bad usage

set -uo pipefail

DIR="."
PRINT_BASE=no
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print-base)
      PRINT_BASE=yes
      shift
      ;;
    -C)
      if [[ $# -lt 2 ]]; then
        echo "compute-diff-key.sh: -C requires a directory" >&2
        exit 2
      fi
      DIR="$2"
      shift 2
      ;;
    *)
      echo "compute-diff-key.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if ! git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "compute-diff-key.sh: not a git repository: $DIR" >&2
  exit 1
fi

BASE=$(git -C "$DIR" rev-parse --verify --quiet '@{upstream}') || BASE=""
if [[ -z "$BASE" ]]; then
  BASE=$(git -C "$DIR" rev-parse --verify --quiet 'refs/remotes/origin/main') || BASE=""
fi
if [[ -z "$BASE" ]]; then
  echo "compute-diff-key.sh: no base to diff against — the branch has no upstream and origin/main does not exist" >&2
  exit 1
fi

if [[ "$PRINT_BASE" == yes ]]; then
  echo "$BASE"
  exit 0
fi

if ! DIFF=$(git -C "$DIR" diff "$BASE...HEAD"); then
  echo "compute-diff-key.sh: failed to diff against $BASE" >&2
  exit 1
fi

printf '%s' "$DIFF" | shasum -a 256 | awk '{print $1}'
