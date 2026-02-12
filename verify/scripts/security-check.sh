#!/usr/bin/env bash
# security-check.sh — Run security checks for pre-PR verification
#
# Usage: security-check.sh [mode] [project-directory]
#
# Modes:
#   standard — Check for debug code and .only in tracked files (default)
#   pre-pr   — Standard checks + npm audit + secrets in staged diff + .env staging check
#
# Skipping paths:
#   Third-party/vendor files can be excluded from ALL security checks by adding
#   path patterns to .verify-skip in the project root (one pattern per line).
#   Example: .obsidian/plugins/ to skip Obsidian plugin vendor code.
#
#   For inline suppression of individual lines, add an eslint-disable comment
#   (e.g., // eslint-disable-line no-console).
#
# Exit codes:
#   0 — All checks passed
#   1 — Issues found (details printed to stdout)
#   2 — Invalid arguments

set -uo pipefail

MODE="${1:-standard}"
PROJECT_DIR="${2:-.}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
cd "$PROJECT_DIR"

ISSUES_FOUND=0
FINDINGS=""

add_finding() {
  FINDINGS="${FINDINGS}  - $1\n"
  ISSUES_FOUND=1
}

# --- Standard checks (run in all modes) ---

echo "=== Security Check (mode: $MODE) ==="
echo "Directory: $PROJECT_DIR"
echo "---"

# Build shared exclusion list for ALL security checks
# These paths are skipped for console.log, debugger, AND .only checks
SKIP_PATHS=(':!node_modules' ':!*.test.*' ':!*.spec.*' ':!*__tests__*' ':!scripts/test-*')

# Exclude CLI entry points listed in package.json bin field
if [ -f "$PROJECT_DIR/package.json" ]; then
  BIN_FILES=$(python3 -c "
import json
try:
    with open('$PROJECT_DIR/package.json') as f:
        pkg = json.load(f)
    bin_field = pkg.get('bin', {})
    if isinstance(bin_field, str):
        print(bin_field)
    elif isinstance(bin_field, dict):
        for path in bin_field.values():
            print(path)
except Exception:
    pass
" 2>/dev/null || true)
  while IFS= read -r bin_file; do
    if [ -n "$bin_file" ]; then
      SKIP_PATHS+=(":!$bin_file")
    fi
  done <<< "$BIN_FILES"
fi

# Read .verify-skip for additional path exclusions (applies to ALL checks)
# Also support legacy .console-allow for backwards compatibility
SKIP_FILE=""
if [ -f "$PROJECT_DIR/.verify-skip" ]; then
  SKIP_FILE="$PROJECT_DIR/.verify-skip"
elif [ -f "$PROJECT_DIR/.console-allow" ]; then
  SKIP_FILE="$PROJECT_DIR/.console-allow"
fi

if [ -n "$SKIP_FILE" ]; then
  while IFS= read -r pattern; do
    # Skip empty lines and comments
    pattern=$(echo "$pattern" | sed 's/#.*//' | xargs)
    if [ -n "$pattern" ]; then
      SKIP_PATHS+=(":!$pattern")
    fi
  done < "$SKIP_FILE"
fi

# Check for console.log in source files
# Excluded: node_modules, test files, test scripts, CLI entry points, .verify-skip patterns
# Lines with eslint-disable comments are filtered out (intentional usage)
CONSOLE_LOGS=$(git grep -n 'console\.log' -- '*.js' '*.ts' '*.jsx' '*.tsx' "${SKIP_PATHS[@]}" 2>/dev/null | grep -v 'eslint-disable' || true)
if [ -n "$CONSOLE_LOGS" ]; then
  add_finding "Found console.log statements in source files:"
  while IFS= read -r line; do
    # Truncate long lines (minified vendor JS can be thousands of chars with invalid Unicode)
    if [ ${#line} -gt 200 ]; then
      line="${line:0:200}..."
    fi
    FINDINGS="${FINDINGS}    $line\n"
  done <<< "$CONSOLE_LOGS"
fi

# Check for debugger statements (eslint-disable filter applied here too)
DEBUGGERS=$(git grep -n 'debugger' -- '*.js' '*.ts' '*.jsx' '*.tsx' "${SKIP_PATHS[@]}" 2>/dev/null | grep -v 'eslint-disable' || true)
if [ -n "$DEBUGGERS" ]; then
  add_finding "Found debugger statements:"
  while IFS= read -r line; do
    if [ ${#line} -gt 200 ]; then
      line="${line:0:200}..."
    fi
    FINDINGS="${FINDINGS}    $line\n"
  done <<< "$DEBUGGERS"
fi

# Check for .only in test files (focused tests that skip other tests)
ONLY_TESTS=$(git grep -n '\.only' -- '*.test.*' '*.spec.*' '*__tests__*' "${SKIP_PATHS[@]}" 2>/dev/null || true)
if [ -n "$ONLY_TESTS" ]; then
  add_finding "Found .only in test files (focused tests that skip others):"
  while IFS= read -r line; do
    if [ ${#line} -gt 200 ]; then
      line="${line:0:200}..."
    fi
    FINDINGS="${FINDINGS}    $line\n"
  done <<< "$ONLY_TESTS"
fi

# --- Pre-PR additional checks ---

if [ "$MODE" = "pre-pr" ]; then

  # Check for .env files staged for commit
  STAGED_ENV=$(git diff --cached --name-only 2>/dev/null | grep -E '\.env' || true)
  if [ -n "$STAGED_ENV" ]; then
    add_finding "Found .env files staged for commit:"
    while IFS= read -r line; do
      FINDINGS="${FINDINGS}    $line\n"
    done <<< "$STAGED_ENV"
  fi

  # Check for hardcoded secrets/API keys in staged diff
  STAGED_DIFF=$(git diff --cached 2>/dev/null || true)
  if [ -n "$STAGED_DIFF" ]; then
    # Look for common secret patterns in added lines only
    SECRET_PATTERNS='(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key|private[_-]?key|password)\s*[=:]\s*["\x27][^\s"'\'']{8,}'
    SECRETS_FOUND=$(echo "$STAGED_DIFF" | grep -E '^\+' | grep -iE "$SECRET_PATTERNS" || true)
    if [ -n "$SECRETS_FOUND" ]; then
      add_finding "Possible hardcoded secrets in staged changes:"
      while IFS= read -r line; do
        FINDINGS="${FINDINGS}    $line\n"
      done <<< "$SECRETS_FOUND"
    fi
  fi

  # Run npm audit if package.json exists
  if [ -f "$PROJECT_DIR/package.json" ] && command -v npm &>/dev/null; then
    echo "Running npm audit..."
    AUDIT_OUTPUT=$(npm audit --json 2>/dev/null || true)
    VULN_COUNT=$(echo "$AUDIT_OUTPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # npm audit JSON format varies by version
    if 'metadata' in data and 'vulnerabilities' in data['metadata']:
        total = data['metadata']['vulnerabilities'].get('total', 0)
    elif 'vulnerabilities' in data:
        total = len(data['vulnerabilities'])
    else:
        total = 0
    print(total)
except Exception:
    print(0)
" 2>/dev/null || echo "0")
    if [ "$VULN_COUNT" -gt 0 ] 2>/dev/null; then
      add_finding "npm audit found $VULN_COUNT vulnerability(ies). Run 'npm audit' for details."
    fi
  fi
fi

# --- Output results ---

echo ""
if [ $ISSUES_FOUND -eq 0 ]; then
  echo "RESULT: Security check PASSED"
else
  echo "FINDINGS:"
  echo -e "$FINDINGS"
  echo "HOW TO FIX:"
  echo ""
  echo "  If this is YOUR code — fix the issue (remove debug code, unfocus tests)."
  echo ""
  echo "  If this is THIRD-PARTY/VENDOR code you don't control:"
  echo "    Add the file or directory path to .verify-skip in the project root."
  echo "    Example: echo '.obsidian/plugins/' >> .verify-skip"
  echo "    This skips the path for ALL security checks (console.log, debugger, .only)."
  echo ""
  echo "  For INTENTIONAL console.log in your own code (CLI output, logging):"
  echo "    Add // eslint-disable-line no-console on the line."
  echo ""
  echo "RESULT: Security check FAILED"
fi

exit $ISSUES_FOUND
