#!/usr/bin/env bash
# check-markdown-codeblocks.sh — Check markdown files for bare code blocks
#
# Usage: check-markdown-codeblocks.sh <file>
#
# Thin wrapper around check-markdown-codeblocks.py.
# Delegates to the Python script in the same directory.
#
# Exit codes:
#   0 — All code blocks have language specifiers (or file is not markdown)
#   1 — Found bare code blocks without language specifiers
#   2 — Invalid arguments

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/check-markdown-codeblocks.py" "$@"
