#!/usr/bin/env bash
# test-security-check.sh — Tests for security-check.sh
#
# Exercises security-check.sh with Go project configurations:
# - Go fmt.Print in library packages (detected)
# - Go fmt.Print in main packages (skipped)
# - Go log.Print in library packages (detected)
# - Go debug prints with //nolint (skipped)
# - Go _test.go files (skipped)
# - Go vendor directory (skipped)
# - .verify-skip exclusion for Go files
# - Diff-scoped Go detection
# - JS console.log regression
#
# Usage: bash .claude/skills/verify/tests/test-security-check.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECURITY_CHECK="$SCRIPT_DIR/../scripts/security-check.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEMP_BASE=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_BASE"
}
trap cleanup EXIT

# --- Test helpers ---

assert_contains() {
  local description="$1"
  local output="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))

  if echo "$output" | grep -qF "$expected"; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected output to contain: %s\n" "$expected"
  fi
}

assert_not_contains() {
  local description="$1"
  local output="$2"
  local unexpected="$3"
  TOTAL=$((TOTAL + 1))

  if echo "$output" | grep -qF "$unexpected"; then
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Output should NOT contain: %s\n" "$unexpected"
  else
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  fi
}

assert_exit_code() {
  local description="$1"
  local actual="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected exit code: %s\n" "$expected"
    printf "       Got: %s\n" "$actual"
  fi
}

# --- Setup helpers ---

# Create a Go project with various debug print patterns in a git repo
setup_go_project() {
  local project_dir="$1"
  mkdir -p "$project_dir/internal/service"
  mkdir -p "$project_dir/cmd/myapp"
  mkdir -p "$project_dir/vendor/thirdparty"

  echo 'module example.com/test' > "$project_dir/go.mod"

  # Library package with fmt.Println (SHOULD be detected)
  cat > "$project_dir/internal/service/handler.go" << 'GOEOF'
package service

import "fmt"

func Handle() {
	fmt.Println("debug: handling request")
}
GOEOF

  # Library package with fmt.Printf (SHOULD be detected)
  cat > "$project_dir/internal/service/format.go" << 'GOEOF'
package service

import "fmt"

func Format(n int) {
	fmt.Printf("debug value: %d\n", n)
}
GOEOF

  # Library package with log.Println (SHOULD be detected)
  cat > "$project_dir/internal/service/logger.go" << 'GOEOF'
package service

import "log"

func Init() {
	log.Println("initializing service")
}
GOEOF

  # Main package with fmt.Println (should NOT be detected)
  cat > "$project_dir/cmd/myapp/main.go" << 'GOEOF'
package main

import "fmt"

func main() {
	fmt.Println("Starting application")
}
GOEOF

  # Library package with //nolint suppression (should NOT be detected)
  cat > "$project_dir/internal/service/intentional.go" << 'GOEOF'
package service

import "fmt"

func DebugOutput() {
	fmt.Println("intentional output") //nolint
}
GOEOF

  # Library package with // nolint (space variant, should NOT be detected)
  cat > "$project_dir/internal/service/spaced.go" << 'GOEOF'
package service

import "fmt"

func SpacedNolint() {
	fmt.Println("spaced nolint") // nolint
}
GOEOF

  # Test file with fmt.Println (should NOT be detected)
  cat > "$project_dir/internal/service/handler_test.go" << 'GOEOF'
package service

import (
	"fmt"
	"testing"
)

func TestHandle(t *testing.T) {
	fmt.Println("test debug output")
}
GOEOF

  # Vendor file with fmt.Println (should NOT be detected)
  cat > "$project_dir/vendor/thirdparty/lib.go" << 'GOEOF'
package thirdparty

import "fmt"

func Lib() {
	fmt.Println("vendor code")
}
GOEOF

  # Initialize git repo and commit
  (cd "$project_dir" && git init -q && git add -A && git commit -q -m "initial")
}

# Create a Go project for diff-scoped testing
setup_go_diff_project() {
  local project_dir="$1"
  mkdir -p "$project_dir/internal/service"
  mkdir -p "$project_dir/cmd/myapp"

  echo 'module example.com/test' > "$project_dir/go.mod"

  # Clean initial commit (no debug prints)
  cat > "$project_dir/internal/service/handler.go" << 'GOEOF'
package service

func Handle() {
	// clean code
}
GOEOF

  cat > "$project_dir/cmd/myapp/main.go" << 'GOEOF'
package main

func main() {
	// clean main
}
GOEOF

  (cd "$project_dir" && git init -q && git add -A && git commit -q -m "initial")

  # Store the base commit
  local base_commit
  base_commit=$(cd "$project_dir" && git rev-parse HEAD)
  echo "$base_commit"

  # Add debug prints in a second commit
  cat > "$project_dir/internal/service/handler.go" << 'GOEOF'
package service

import "fmt"

func Handle() {
	fmt.Println("debug added in branch")
}
GOEOF

  cat > "$project_dir/cmd/myapp/main.go" << 'GOEOF'
package main

import "fmt"

func main() {
	fmt.Println("main output added in branch")
}
GOEOF

  (cd "$project_dir" && git add -A && git commit -q -m "add debug prints")
}

# Create a project with .verify-skip for Go files
setup_go_verify_skip_project() {
  local project_dir="$1"
  mkdir -p "$project_dir/internal/service"
  mkdir -p "$project_dir/generated"

  echo 'module example.com/test' > "$project_dir/go.mod"

  # Library package with fmt.Println (SHOULD be detected)
  cat > "$project_dir/internal/service/handler.go" << 'GOEOF'
package service

import "fmt"

func Handle() {
	fmt.Println("debug in service")
}
GOEOF

  # Generated code with fmt.Println (should NOT be detected — in .verify-skip)
  cat > "$project_dir/generated/zz_generated.go" << 'GOEOF'
package generated

import "fmt"

func Generated() {
	fmt.Println("generated code")
}
GOEOF

  # .verify-skip excludes generated directory
  echo 'generated/' > "$project_dir/.verify-skip"

  (cd "$project_dir" && git init -q && git add -A && git commit -q -m "initial")
}

# Create a clean Go project (no debug prints)
setup_clean_go_project() {
  local project_dir="$1"
  mkdir -p "$project_dir/internal/service"

  echo 'module example.com/test' > "$project_dir/go.mod"

  cat > "$project_dir/internal/service/handler.go" << 'GOEOF'
package service

func Handle() {
	// clean code, no debug prints
}
GOEOF

  (cd "$project_dir" && git init -q && git add -A && git commit -q -m "initial")
}

# Create a JS project for regression testing
setup_js_project() {
  local project_dir="$1"
  mkdir -p "$project_dir/src"

  echo '{"name":"test"}' > "$project_dir/package.json"

  cat > "$project_dir/src/index.js" << 'JSEOF'
function main() {
  console.log("debug output");
}
JSEOF

  (cd "$project_dir" && git init -q && git add -A && git commit -q -m "initial")
}

# ─────────────────────────────────────────────
echo ""
printf "${YELLOW}=== security-check.sh tests ===${NC}\n"

# ─────────────────────────────────────────────
# Section 1: Go debug code detection (repo-scoped)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go debug code detection (repo-scoped) ---${NC}\n"

GO_PROJECT="$TEMP_BASE/go-project"
setup_go_project "$GO_PROJECT"

OUTPUT=$("$SECURITY_CHECK" standard "$GO_PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_contains "detects fmt.Println in library package" \
  "$OUTPUT" "handler.go"

assert_contains "detects fmt.Printf in library package" \
  "$OUTPUT" "format.go"

assert_contains "detects log.Println in library package" \
  "$OUTPUT" "logger.go"

assert_not_contains "skips fmt.Println in main package" \
  "$OUTPUT" "main.go"

assert_not_contains "skips fmt.Println with //nolint" \
  "$OUTPUT" "intentional.go"

assert_not_contains "skips fmt.Println with // nolint (spaced)" \
  "$OUTPUT" "spaced.go"

assert_not_contains "skips fmt.Println in _test.go files" \
  "$OUTPUT" "handler_test.go"

assert_not_contains "skips fmt.Println in vendor directory" \
  "$OUTPUT" "vendor/"

assert_contains "shows fmt.Print finding category" \
  "$OUTPUT" "fmt.Print"

assert_contains "shows log.Print finding category" \
  "$OUTPUT" "log.Print"

assert_exit_code "exits 1 when Go debug prints found" \
  "$EXIT_CODE" "1"

# ─────────────────────────────────────────────
# Section 2: Go diff-scoped detection
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go debug code detection (diff-scoped) ---${NC}\n"

GO_DIFF_PROJECT="$TEMP_BASE/go-diff-project"
BASE_COMMIT=$(setup_go_diff_project "$GO_DIFF_PROJECT")

OUTPUT=$("$SECURITY_CHECK" standard "$GO_DIFF_PROJECT" "$BASE_COMMIT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_contains "diff-scoped: detects fmt.Println in library package" \
  "$OUTPUT" "handler.go"

assert_not_contains "diff-scoped: skips fmt.Println in main package" \
  "$OUTPUT" "main.go"

assert_exit_code "diff-scoped: exits 1 when Go debug prints found" \
  "$EXIT_CODE" "1"

# ─────────────────────────────────────────────
# Section 3: .verify-skip exclusion for Go files
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- .verify-skip exclusion for Go files ---${NC}\n"

GO_SKIP_PROJECT="$TEMP_BASE/go-skip-project"
setup_go_verify_skip_project "$GO_SKIP_PROJECT"

OUTPUT=$("$SECURITY_CHECK" standard "$GO_SKIP_PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_contains "detects fmt.Println outside .verify-skip paths" \
  "$OUTPUT" "handler.go"

assert_not_contains "skips fmt.Println inside .verify-skip paths" \
  "$OUTPUT" "generated/"

assert_exit_code "exits 1 for non-skipped Go debug prints" \
  "$EXIT_CODE" "1"

# ─────────────────────────────────────────────
# Section 4: Clean Go project (no findings)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Clean Go project (no findings) ---${NC}\n"

CLEAN_GO="$TEMP_BASE/clean-go"
setup_clean_go_project "$CLEAN_GO"

OUTPUT=$("$SECURITY_CHECK" standard "$CLEAN_GO" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_contains "clean Go project passes" \
  "$OUTPUT" "PASSED"

assert_exit_code "exits 0 for clean Go project" \
  "$EXIT_CODE" "0"

# ─────────────────────────────────────────────
# Section 5: JS console.log regression
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- JS console.log regression ---${NC}\n"

JS_PROJECT="$TEMP_BASE/js-project"
setup_js_project "$JS_PROJECT"

OUTPUT=$("$SECURITY_CHECK" standard "$JS_PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_contains "still detects JS console.log" \
  "$OUTPUT" "console.log"

assert_exit_code "exits 1 for JS console.log" \
  "$EXIT_CODE" "1"

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
printf "${YELLOW}=== Results ===${NC}\n"
printf "  Total: %d | ${GREEN}Passed: %d${NC} | ${RED}Failed: %d${NC}\n" "$TOTAL" "$PASS" "$FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
