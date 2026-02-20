#!/usr/bin/env bash
# security-check.sh — Run security checks for verification
#
# Usage: security-check.sh [mode] [project-directory] [diff-base]
#
# Modes:
#   standard — Check for debug code and .only (default)
#   pre-pr   — Standard checks + npm audit + secrets + .env check
#
# Diff scoping (Decision 7):
#   When diff-base is provided, checks only added lines in git diff <diff-base>...HEAD.
#   When omitted, checks the whole repo via git grep. Hooks pass a diff-base for
#   fast, focused checks; the /verify skill omits it for full-codebase scans.
#
# Skipping paths:
#   Third-party/vendor files can be excluded from ALL security checks by adding
#   path patterns to .verify-skip in the project root (one pattern per line).
#   Example: .obsidian/plugins/ to skip Obsidian plugin vendor code.
#
#   For inline suppression of individual lines, add an eslint-disable comment
#   (e.g., // eslint-disable-line no-console).
#
# Known vulnerabilities:
#   npm audit findings for packages with no available fix can be acknowledged in
#   .audit-known-vulns (one package name per line, comments with #). Listed
#   packages are excluded from findings in both diff-scoped and repo-scoped modes.
#
# Exit codes:
#   0 — All checks passed
#   1 — Issues found (details printed to stdout)
#   2 — Invalid arguments

set -uo pipefail

MODE="${1:-standard}"
PROJECT_DIR="${2:-.}"
DIFF_BASE="${3:-}"

# Validate mode
if [ "$MODE" != "standard" ] && [ "$MODE" != "pre-pr" ]; then
  echo "ERROR: Invalid mode '$MODE'. Supported modes: standard, pre-pr"
  exit 2
fi

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || { echo "ERROR: Cannot resolve project directory: ${2:-.}"; exit 2; }
cd "$PROJECT_DIR" || exit 2

ISSUES_FOUND=0
FINDINGS=""

add_finding() {
  FINDINGS="${FINDINGS}  - $1\n"
  ISSUES_FOUND=1
}

# --- Build exclusion lists ---

echo "=== Security Check (mode: $MODE${DIFF_BASE:+, scoped to branch diff}) ==="
echo "Directory: $PROJECT_DIR"
echo "---"

# Base exclusions (applied to ALL checks including .only)
BASE_SKIP=(':!node_modules')

# Exclude CLI entry points listed in package.json bin field
if [ -f "$PROJECT_DIR/package.json" ]; then
  BIN_FILES=$(SECURITY_PKG_PATH="$PROJECT_DIR/package.json" python3 -c "
import json, os
try:
    with open(os.environ['SECURITY_PKG_PATH']) as f:
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
      BASE_SKIP+=(":!$bin_file")
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
      BASE_SKIP+=(":!$pattern")
    fi
  done < "$SKIP_FILE"
fi

# Source file exclusions (for console.log/debugger — excludes test files too)
SOURCE_SKIP=("${BASE_SKIP[@]}" ':!*.test.*' ':!*.spec.*' ':!*__tests__*' ':!scripts/test-*')

# Read .audit-known-vulns for accepted npm audit vulnerabilities (package names, one per line).
# Listed packages are excluded from audit findings in both diff-scoped and repo-scoped modes.
# Use this for known vulnerabilities with no available fix.
AUDIT_KNOWN_VULNS=()
if [ -f "$PROJECT_DIR/.audit-known-vulns" ]; then
  while IFS= read -r vuln; do
    vuln=$(echo "$vuln" | sed 's/#.*//' | xargs)
    if [ -n "$vuln" ]; then
      AUDIT_KNOWN_VULNS+=("$vuln")
    fi
  done < "$PROJECT_DIR/.audit-known-vulns"
fi

# --- Helper: grep added lines in a git diff ---
# Usage: diff_grep <pattern> <exclude_pattern> <diff_base> <pathspecs...>
# Returns matches in file:line:content format (same as git grep -n)
# Note: exclude filtering uses grep -v (not awk) for macOS awk compatibility.
diff_grep() {
  local search_pattern="$1"
  local exclude_pattern="$2"
  local base="$3"
  shift 3

  local results
  results=$(git diff "$base"...HEAD -U0 -- "$@" 2>/dev/null | awk \
    -v pat="$search_pattern" '
    /^diff --git/ { file = $3; sub(/^a\//, "", file) }
    /^@@/ {
      s = $3
      sub(/^\+/, "", s)
      split(s, a, ",")
      line = a[1] + 0
      off = 0
    }
    /^\+[^+]/ {
      if ($0 ~ pat) {
        print file ":" (line + off) ":" substr($0, 2)
      }
      off++
    }
    /^\+$/ { off++ }
  ' || true)

  # Apply exclude filter if provided
  if [ -n "$exclude_pattern" ] && [ -n "$results" ]; then
    echo "$results" | grep -v "$exclude_pattern" || true
  else
    echo "$results"
  fi
}

# --- Standard checks (run in all modes) ---

if [ -n "$DIFF_BASE" ]; then
  # Diff-scoped: only check added lines in branch changes (Decision 7)

  CONSOLE_LOGS=$(diff_grep 'console\.log' 'eslint-disable' "$DIFF_BASE" \
    '*.js' '*.ts' '*.jsx' '*.tsx' "${SOURCE_SKIP[@]}")

  DEBUGGERS=$(diff_grep 'debugger' 'eslint-disable' "$DIFF_BASE" \
    '*.js' '*.ts' '*.jsx' '*.tsx' "${SOURCE_SKIP[@]}")

  ONLY_TESTS=$(diff_grep '\.only[[:space:]]*\(' '' "$DIFF_BASE" \
    '*.test.*' '*.spec.*' '*__tests__*' "${BASE_SKIP[@]}")
else
  # Repo-scoped: check all tracked files (for /verify skill ad-hoc use)

  # Lines with eslint-disable comments are filtered out (intentional usage)
  CONSOLE_LOGS=$(git grep -n 'console\.log' -- '*.js' '*.ts' '*.jsx' '*.tsx' "${SOURCE_SKIP[@]}" 2>/dev/null | grep -v 'eslint-disable' || true)

  DEBUGGERS=$(git grep -n 'debugger' -- '*.js' '*.ts' '*.jsx' '*.tsx' "${SOURCE_SKIP[@]}" 2>/dev/null | grep -v 'eslint-disable' || true)

  # .only uses BASE_SKIP (not SOURCE_SKIP) so test file includes aren't cancelled out
  ONLY_TESTS=$(git grep -n '\.only[[:space:]]*(' -- '*.test.*' '*.spec.*' '*__tests__*' "${BASE_SKIP[@]}" 2>/dev/null || true)
fi

# Process findings (same for both scopes)
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

if [ -n "$DEBUGGERS" ]; then
  add_finding "Found debugger statements:"
  while IFS= read -r line; do
    if [ ${#line} -gt 200 ]; then
      line="${line:0:200}..."
    fi
    FINDINGS="${FINDINGS}    $line\n"
  done <<< "$DEBUGGERS"
fi

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

  if [ -n "$DIFF_BASE" ]; then
    # Diff-scoped: check branch diff for .env files and secrets

    # Check for .env files in branch changes (honoring .verify-skip)
    ENV_FILES=$(git diff --name-only "$DIFF_BASE"...HEAD -- "${BASE_SKIP[@]}" 2>/dev/null | grep -E '\.env' || true)
    if [ -n "$ENV_FILES" ]; then
      add_finding "Found .env files in branch changes:"
      while IFS= read -r line; do
        FINDINGS="${FINDINGS}    $line\n"
      done <<< "$ENV_FILES"
    fi

    # Check for hardcoded secrets/API keys in branch diff (added lines only, honoring .verify-skip)
    BRANCH_DIFF=$(git diff "$DIFF_BASE"...HEAD -- "${BASE_SKIP[@]}" 2>/dev/null || true)
    if [ -n "$BRANCH_DIFF" ]; then
      SECRET_PATTERNS='(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key|private[_-]?key|password)\s*[=:]\s*["'"'"'][^\s"'"'"']{8,}'
      SECRETS_FOUND=$(echo "$BRANCH_DIFF" | grep -E '^\+[^+]' | grep -iE "$SECRET_PATTERNS" || true)
      if [ -n "$SECRETS_FOUND" ]; then
        add_finding "Possible hardcoded secrets in branch changes:"
        while IFS= read -r line; do
          FINDINGS="${FINDINGS}    $line\n"
        done <<< "$SECRETS_FOUND"
      fi
    fi
  else
    # Repo-scoped: check staged diff (original behavior for /verify skill)

    # Check for .env files staged for commit (honoring .verify-skip)
    STAGED_ENV=$(git diff --cached --name-only -- "${BASE_SKIP[@]}" 2>/dev/null | grep -E '\.env' || true)
    if [ -n "$STAGED_ENV" ]; then
      add_finding "Found .env files staged for commit:"
      while IFS= read -r line; do
        FINDINGS="${FINDINGS}    $line\n"
      done <<< "$STAGED_ENV"
    fi

    # Check for hardcoded secrets/API keys in staged diff (honoring .verify-skip)
    STAGED_DIFF=$(git diff --cached -- "${BASE_SKIP[@]}" 2>/dev/null || true)
    if [ -n "$STAGED_DIFF" ]; then
      # Look for common secret patterns in added lines only
      SECRET_PATTERNS='(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key|private[_-]?key|password)\s*[=:]\s*["'"'"'][^\s"'"'"']{8,}'
      SECRETS_FOUND=$(echo "$STAGED_DIFF" | grep -E '^\+[^+]' | grep -iE "$SECRET_PATTERNS" || true)
      if [ -n "$SECRETS_FOUND" ]; then
        add_finding "Possible hardcoded secrets in staged changes:"
        while IFS= read -r line; do
          FINDINGS="${FINDINGS}    $line\n"
        done <<< "$SECRETS_FOUND"
      fi
    fi
  fi

  # npm audit — diff-scoped when DIFF_BASE is provided (Decision 7)
  if [ -f "$PROJECT_DIR/package.json" ] && command -v npm &>/dev/null; then
    if [ -n "$DIFF_BASE" ]; then
      # Diff-scoped: only flag NEW vulnerabilities introduced by this branch
      DEP_FILES_CHANGED=$(git diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null | grep -E '(package\.json|package-lock\.json)$' || true)

      if [ -n "$DEP_FILES_CHANGED" ]; then
        echo "Running npm audit (dependency files changed — comparing against base)..."
        AUDIT_TMPDIR=$(mktemp -d)
        trap 'rm -rf "$AUDIT_TMPDIR"' EXIT

        # Audit current branch
        npm audit --json > "$AUDIT_TMPDIR/branch.json" 2>/dev/null || true

        # Reconstruct base lockfile for comparison
        git show "$DIFF_BASE:package.json" > "$AUDIT_TMPDIR/package.json" 2>/dev/null || true
        git show "$DIFF_BASE:package-lock.json" > "$AUDIT_TMPDIR/package-lock.json" 2>/dev/null || true
        (cd "$AUDIT_TMPDIR" && npm audit --json --package-lock-only > base.json 2>/dev/null || true)

        # Compare: only count vulnerabilities not present on base and not in .audit-known-vulns
        KNOWN_VULNS_JSON=$(printf '%s\n' "${AUDIT_KNOWN_VULNS[@]+"${AUDIT_KNOWN_VULNS[@]}"}" | python3 -c "
import sys, json
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))
" 2>/dev/null || echo "[]")

        NEW_VULN_COUNT=$(AUDIT_KNOWN_VULNS_JSON="$KNOWN_VULNS_JSON" \
          AUDIT_BRANCH_JSON="$AUDIT_TMPDIR/branch.json" \
          AUDIT_BASE_JSON="$AUDIT_TMPDIR/base.json" \
          python3 -c "
import json, os

def load_vuln_keys(path):
    try:
        with open(path) as f:
            data = json.load(f)
        return set(data.get('vulnerabilities', {}).keys())
    except Exception:
        return set()

known = set(json.loads(os.environ['AUDIT_KNOWN_VULNS_JSON']))
branch = load_vuln_keys(os.environ['AUDIT_BRANCH_JSON'])
base = load_vuln_keys(os.environ['AUDIT_BASE_JSON'])
print(len(branch - base - known))
" 2>/dev/null || echo "0")

        if [ "$NEW_VULN_COUNT" -gt 0 ] 2>/dev/null; then
          add_finding "npm audit found $NEW_VULN_COUNT NEW vulnerability(ies) introduced by this branch. Run 'npm audit' for details."
        fi
      fi
    else
      # Repo-scoped: check all vulnerabilities, minus .audit-known-vulns (for /verify skill ad-hoc use)
      echo "Running npm audit..."
      KNOWN_VULNS_JSON=$(printf '%s\n' "${AUDIT_KNOWN_VULNS[@]+"${AUDIT_KNOWN_VULNS[@]}"}" | python3 -c "
import sys, json
print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))
" 2>/dev/null || echo "[]")

      VULN_COUNT=$(npm audit --json 2>/dev/null | AUDIT_KNOWN_VULNS_JSON="$KNOWN_VULNS_JSON" python3 -c "
import json, sys, os
try:
    data = json.load(sys.stdin)
    known = set(json.loads(os.environ['AUDIT_KNOWN_VULNS_JSON']))
    if 'vulnerabilities' in data:
        unknown = set(data['vulnerabilities'].keys()) - known
        total = len(unknown)
    elif 'metadata' in data and 'vulnerabilities' in data['metadata']:
        total = data['metadata']['vulnerabilities'].get('total', 0)
    else:
        total = 0
    print(total)
except Exception:
    print(0)
" 2>/dev/null || echo "0")
      if [ "$VULN_COUNT" -gt 0 ] 2>/dev/null; then
        add_finding "npm audit found $VULN_COUNT vulnerability(ies) (excluding known). Run 'npm audit' for details."
      fi
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
  echo "  For npm audit vulnerabilities with NO AVAILABLE FIX:"
  echo "    Add the package name to .audit-known-vulns in the project root (one per line)."
  echo "    Example: echo 'nth-check' >> .audit-known-vulns"
  echo "    Re-evaluate periodically — fixes may become available."
  echo ""
  echo "RESULT: Security check FAILED"
fi

exit $ISSUES_FOUND
