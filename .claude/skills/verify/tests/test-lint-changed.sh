#!/usr/bin/env bash
# test-lint-changed.sh — Tests for lint-changed.sh diff-scoped linting
#
# Exercises lint-changed.sh with various project configurations:
# - JS/TS linting (existing behavior, regression)
# - Go linting with golangci-lint (staged + branch scope)
# - Go linting fallback to go vet
# - Mixed JS+Go projects
# - No lintable files changed
#
# Usage: bash .claude/skills/verify/tests/test-lint-changed.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINT_CHANGED="$SCRIPT_DIR/../scripts/lint-changed.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create temp directories for test fixtures
TEMP_BASE=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_BASE"
}
trap cleanup EXIT

# --- Test helpers ---

assert_output_contains() {
  local description="$1"
  local output="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))

  if echo "$output" | grep -qF -- "$expected"; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected to contain: '%s'\n" "$expected"
    printf "       Got: '%s'\n" "$output"
  fi
}

assert_output_not_contains() {
  local description="$1"
  local output="$2"
  local unexpected="$3"
  TOTAL=$((TOTAL + 1))

  if ! echo "$output" | grep -qF -- "$unexpected"; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected NOT to contain: '%s'\n" "$unexpected"
    printf "       Got: '%s'\n" "$output"
  fi
}

assert_exit_code() {
  local description="$1"
  local actual="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))

  if [ "$actual" -eq "$expected" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected exit code: %d\n" "$expected"
    printf "       Got: %d\n" "$actual"
  fi
}

# --- Setup: create a git repo for testing ---

setup_git_repo() {
  local repo_dir="$1"
  mkdir -p "$repo_dir"
  cd "$repo_dir" || return 1
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # Initial commit so we have a HEAD
  echo "init" > .gitkeep
  git add .gitkeep
  git commit -q -m "initial"
}

# --- Setup: fake binaries ---

FAKE_BIN="$TEMP_BASE/fake-bin"
mkdir -p "$FAKE_BIN"

# Fake golangci-lint that succeeds (simulates clean lint)
cat > "$FAKE_BIN/golangci-lint" << 'SCRIPT'
#!/usr/bin/env bash
# Record invocation args for test assertions
echo "GOLANGCI_ARGS: $*" >> "${GOLANGCI_LOG:-/dev/null}"
echo "golangci-lint: no issues found"
exit 0
SCRIPT
chmod +x "$FAKE_BIN/golangci-lint"

# Fake golangci-lint that fails (simulates lint errors)
cat > "$FAKE_BIN/golangci-lint-fail" << 'SCRIPT'
#!/usr/bin/env bash
echo "GOLANGCI_ARGS: $*" >> "${GOLANGCI_LOG:-/dev/null}"
echo "main.go:10: exported function Foo should have comment (golint)"
exit 1
SCRIPT
chmod +x "$FAKE_BIN/golangci-lint-fail"

# Fake npx (for ESLint) that succeeds
cat > "$FAKE_BIN/npx" << 'SCRIPT'
#!/usr/bin/env bash
echo "npx: $*"
exit 0
SCRIPT
chmod +x "$FAKE_BIN/npx"

# PATH with fake golangci-lint
PATH_WITH_LINT="$FAKE_BIN:$PATH"

# PATH without golangci-lint (strip fake bin and any real golangci-lint)
PATH_WITHOUT_LINT=$(echo "$PATH" | tr ':' '\n' | grep -v "$FAKE_BIN" | grep -v golangci-lint | tr '\n' ':' | sed 's/:$//')

# ─────────────────────────────────────────────
echo ""
printf "${YELLOW}=== lint-changed.sh tests ===${NC}\n"

# ─────────────────────────────────────────────
# Section 1: No lintable files changed
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- No lintable files changed ---${NC}\n"

REPO_NONE="$TEMP_BASE/repo-none"
setup_git_repo "$REPO_NONE"
# Stage a non-lintable file
echo "readme" > README.md
git add README.md

OUTPUT=$(PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "staged" "$REPO_NONE" "" 2>&1)
EXIT=$?

assert_exit_code "exits 0 when no lintable files" "$EXIT" 0
assert_output_contains "reports no lintable files" "$OUTPUT" "No lintable files changed"

# ─────────────────────────────────────────────
# Section 2: JS/TS files (regression — existing behavior)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- JS/TS linting (regression) ---${NC}\n"

REPO_JS="$TEMP_BASE/repo-js"
setup_git_repo "$REPO_JS"
# Create ESLint config so ESLint path is taken
echo '{}' > eslint.config.js
git add eslint.config.js
git commit -q -m "add eslint config"
# Stage a JS file
echo "console.log('hi')" > index.js
git add index.js

OUTPUT=$(PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "staged" "$REPO_JS" "npm run lint" 2>&1)
EXIT=$?

assert_exit_code "exits 0 for JS lint pass" "$EXIT" 0
assert_output_contains "reports linting JS files" "$OUTPUT" "changed file(s)"
assert_output_contains "lists index.js" "$OUTPUT" "index.js"

# ─────────────────────────────────────────────
# Section 3: Go files — staged scope with golangci-lint
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go staged linting with golangci-lint ---${NC}\n"

REPO_GO_STAGED="$TEMP_BASE/repo-go-staged"
setup_git_repo "$REPO_GO_STAGED"
echo 'module example.com/test' > go.mod
git add go.mod
git commit -q -m "add go.mod"
# Stage Go files
echo 'package main' > main.go
echo 'package util' > util.go
git add main.go util.go

GOLANGCI_LOG="$TEMP_BASE/golangci-staged.log"
> "$GOLANGCI_LOG"

OUTPUT=$(GOLANGCI_LOG="$GOLANGCI_LOG" PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "staged" "$REPO_GO_STAGED" "go vet ./..." 2>&1)
EXIT=$?

assert_exit_code "exits 0 for Go staged lint pass" "$EXIT" 0
assert_output_contains "reports linting Go files" "$OUTPUT" "changed file(s)"
assert_output_contains "lists main.go" "$OUTPUT" "main.go"

# Verify golangci-lint was called with file args (not --new-from-rev)
GOLANGCI_CALL=$(cat "$GOLANGCI_LOG")
assert_output_contains "golangci-lint called with 'run'" "$GOLANGCI_CALL" "run"
assert_output_not_contains "golangci-lint NOT called with --new-from-rev for staged" "$GOLANGCI_CALL" "--new-from-rev"

# ─────────────────────────────────────────────
# Section 4: Go files — branch scope with golangci-lint
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go branch linting with golangci-lint ---${NC}\n"

REPO_GO_BRANCH="$TEMP_BASE/repo-go-branch"
setup_git_repo "$REPO_GO_BRANCH"
echo 'module example.com/test' > go.mod
git add go.mod
git commit -q -m "add go.mod"
# Create a branch with Go file changes
git checkout -q -b feature
echo 'package main' > main.go
git add main.go
git commit -q -m "add main.go"

GOLANGCI_LOG="$TEMP_BASE/golangci-branch.log"
> "$GOLANGCI_LOG"

# Use HEAD~1 as the diff base (simulating branch diff)
OUTPUT=$(GOLANGCI_LOG="$GOLANGCI_LOG" PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "HEAD~1" "$REPO_GO_BRANCH" "go vet ./..." 2>&1)
EXIT=$?

assert_exit_code "exits 0 for Go branch lint pass" "$EXIT" 0

# Verify golangci-lint was called with --new-from-rev
GOLANGCI_CALL=$(cat "$GOLANGCI_LOG")
assert_output_contains "golangci-lint uses --new-from-rev for branch scope" "$GOLANGCI_CALL" "--new-from-rev"

# ─────────────────────────────────────────────
# Section 5: Go files — fallback when no golangci-lint
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go linting fallback (no golangci-lint) ---${NC}\n"

REPO_GO_FALLBACK="$TEMP_BASE/repo-go-fallback"
setup_git_repo "$REPO_GO_FALLBACK"
echo 'module example.com/test' > go.mod
git add go.mod
git commit -q -m "add go.mod"
echo 'package main' > main.go
git add main.go

OUTPUT=$(PATH="$PATH_WITHOUT_LINT" "$LINT_CHANGED" "staged" "$REPO_GO_FALLBACK" "echo FALLBACK_RAN" 2>&1)
EXIT=$?

assert_exit_code "exits 0 with fallback command" "$EXIT" 0
assert_output_contains "runs fallback command" "$OUTPUT" "FALLBACK_RAN"

# ─────────────────────────────────────────────
# Section 6: Go files — no golangci-lint, no fallback
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go linting skipped (no linter, no fallback) ---${NC}\n"

REPO_GO_SKIP="$TEMP_BASE/repo-go-skip"
setup_git_repo "$REPO_GO_SKIP"
echo 'module example.com/test' > go.mod
git add go.mod
git commit -q -m "add go.mod"
echo 'package main' > main.go
git add main.go

OUTPUT=$(PATH="$PATH_WITHOUT_LINT" "$LINT_CHANGED" "staged" "$REPO_GO_SKIP" "" 2>&1)
EXIT=$?

assert_exit_code "exits 0 when no linter available" "$EXIT" 0
assert_output_contains "reports no linter detected" "$OUTPUT" "No linter detected"

# ─────────────────────────────────────────────
# Section 7: Go lint failure propagates exit code
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go lint failure exit code ---${NC}\n"

REPO_GO_FAIL="$TEMP_BASE/repo-go-fail"
setup_git_repo "$REPO_GO_FAIL"
echo 'module example.com/test' > go.mod
git add go.mod
git commit -q -m "add go.mod"
echo 'package main' > main.go
git add main.go

# Use the failing golangci-lint fake
FAIL_BIN="$TEMP_BASE/fail-bin"
mkdir -p "$FAIL_BIN"
cp "$FAKE_BIN/golangci-lint-fail" "$FAIL_BIN/golangci-lint"
PATH_WITH_FAIL_LINT="$FAIL_BIN:$PATH_WITHOUT_LINT"

OUTPUT=$(PATH="$PATH_WITH_FAIL_LINT" "$LINT_CHANGED" "staged" "$REPO_GO_FAIL" "" 2>&1)
EXIT=$?

assert_exit_code "exits 1 when Go lint fails" "$EXIT" 1
assert_output_contains "reports lint FAILED" "$OUTPUT" "RESULT: lint FAILED"

# ─────────────────────────────────────────────
# Section 8: Mixed JS + Go project
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Mixed JS + Go project ---${NC}\n"

REPO_MIXED="$TEMP_BASE/repo-mixed"
setup_git_repo "$REPO_MIXED"
echo '{}' > eslint.config.js
echo 'module example.com/test' > go.mod
git add eslint.config.js go.mod
git commit -q -m "setup"
# Stage both JS and Go files
echo "console.log('hi')" > index.js
echo 'package main' > main.go
git add index.js main.go

OUTPUT=$(PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "staged" "$REPO_MIXED" "" 2>&1)
EXIT=$?

assert_exit_code "exits 0 for mixed project lint pass" "$EXIT" 0
assert_output_contains "lists index.js in output" "$OUTPUT" "index.js"
assert_output_contains "lists main.go in output" "$OUTPUT" "main.go"

# ─────────────────────────────────────────────
# Section 9: Only non-Go, non-JS files changed
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Only .py files changed (not lintable) ---${NC}\n"

REPO_PY="$TEMP_BASE/repo-py"
setup_git_repo "$REPO_PY"
echo 'print("hi")' > script.py
git add script.py

OUTPUT=$(PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "staged" "$REPO_PY" "" 2>&1)
EXIT=$?

assert_exit_code "exits 0 when only .py files changed" "$EXIT" 0
assert_output_contains "reports no lintable files" "$OUTPUT" "No lintable files changed"

# ─────────────────────────────────────────────
# Section 10: golangci-lint config detection
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- golangci-lint config detection ---${NC}\n"

REPO_GO_CONFIG="$TEMP_BASE/repo-go-config"
setup_git_repo "$REPO_GO_CONFIG"
echo 'module example.com/test' > go.mod
echo 'linters:' > .golangci.yml
git add go.mod .golangci.yml
git commit -q -m "setup"
echo 'package main' > main.go
git add main.go

GOLANGCI_LOG="$TEMP_BASE/golangci-config.log"
> "$GOLANGCI_LOG"

OUTPUT=$(GOLANGCI_LOG="$GOLANGCI_LOG" PATH="$PATH_WITH_LINT" "$LINT_CHANGED" "staged" "$REPO_GO_CONFIG" "go vet ./..." 2>&1)
EXIT=$?

assert_exit_code "exits 0 with golangci-lint config present" "$EXIT" 0

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
