#!/usr/bin/env bash
# test-detect-project.sh — Tests for detect-project.sh command detection
#
# Exercises detect-project.sh with various project configurations:
# - Node.js projects (existing behavior, regression)
# - Go projects with/without Makefile
# - Go projects with/without golangci-lint
# - Unknown projects
# - Typecheck behavior per language
#
# Usage: bash .claude/skills/verify/tests/test-detect-project.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT="$SCRIPT_DIR/../scripts/detect-project.sh"

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

# --- Helper: extract JSON field ---

json_field() {
  local json="$1"
  local field="$2"
  echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
keys = '${field}'.split('.')
val = data
for k in keys:
    val = val[k]
print(val if val is not None else '')
" 2>/dev/null
}

# --- Test helpers ---

assert_field() {
  local description="$1"
  local json="$2"
  local field="$3"
  local expected="$4"
  TOTAL=$((TOTAL + 1))

  local actual
  actual=$(json_field "$json" "$field")

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Field: %s\n" "$field"
    printf "       Expected: '%s'\n" "$expected"
    printf "       Got:      '%s'\n" "$actual"
  fi
}

assert_field_empty() {
  local description="$1"
  local json="$2"
  local field="$3"
  TOTAL=$((TOTAL + 1))

  local actual
  actual=$(json_field "$json" "$field")

  if [ -z "$actual" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Field: %s\n" "$field"
    printf "       Expected: empty/null\n"
    printf "       Got:      '%s'\n" "$actual"
  fi
}

# --- Setup: fake golangci-lint binary ---

FAKE_BIN="$TEMP_BASE/fake-bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/golangci-lint" << 'SCRIPT'
#!/usr/bin/env bash
echo "golangci-lint fake"
SCRIPT
chmod +x "$FAKE_BIN/golangci-lint"

# PATH with fake golangci-lint
PATH_WITH_LINT="$FAKE_BIN:$PATH"

# PATH without golangci-lint (strip fake bin and any real golangci-lint)
PATH_WITHOUT_LINT=$(echo "$PATH" | tr ':' '\n' | grep -v golangci-lint | tr '\n' ':' | sed 's/:$//')

# --- Setup test project directories ---

# Go project with Makefile (all targets)
GO_MAKEFILE_ALL="$TEMP_BASE/go-makefile-all"
mkdir -p "$GO_MAKEFILE_ALL"
echo 'module example.com/test' > "$GO_MAKEFILE_ALL/go.mod"
cat > "$GO_MAKEFILE_ALL/Makefile" << 'EOF'
.PHONY: build lint test vet

build:
	go build ./...

lint:
	golangci-lint run

test:
	go test ./...

vet:
	go vet ./...
EOF

# Go project with Makefile (partial — build and test only, no lint)
GO_MAKEFILE_PARTIAL="$TEMP_BASE/go-makefile-partial"
mkdir -p "$GO_MAKEFILE_PARTIAL"
echo 'module example.com/test' > "$GO_MAKEFILE_PARTIAL/go.mod"
cat > "$GO_MAKEFILE_PARTIAL/Makefile" << 'EOF'
.PHONY: build test

build:
	go build ./...

test:
	go test ./...
EOF

# Go project without Makefile
GO_NO_MAKEFILE="$TEMP_BASE/go-no-makefile"
mkdir -p "$GO_NO_MAKEFILE"
echo 'module example.com/test' > "$GO_NO_MAKEFILE/go.mod"

# Node.js project (regression test)
NODE_PROJECT="$TEMP_BASE/node-project"
mkdir -p "$NODE_PROJECT"
echo '{"scripts":{"build":"tsc","lint":"eslint .","test":"vitest"}}' > "$NODE_PROJECT/package.json"
echo '{}' > "$NODE_PROJECT/tsconfig.json"

# Unknown project
UNKNOWN_PROJECT="$TEMP_BASE/unknown"
mkdir -p "$UNKNOWN_PROJECT"
echo "readme" > "$UNKNOWN_PROJECT/README.md"

# ─────────────────────────────────────────────
echo ""
printf "${YELLOW}=== detect-project.sh tests ===${NC}\n"

# ─────────────────────────────────────────────
# Section 1: Go project with Makefile (all targets)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go with Makefile (all targets) ---${NC}\n"

OUTPUT=$(PATH="$PATH_WITH_LINT" "$DETECT" "$GO_MAKEFILE_ALL")

assert_field "project type is go" \
  "$OUTPUT" "project_type" "go"

assert_field "config_files.go_mod is True" \
  "$OUTPUT" "config_files.go_mod" "True"

assert_field "build uses make build" \
  "$OUTPUT" "commands.build" "make build"

assert_field "lint uses make lint" \
  "$OUTPUT" "commands.lint" "make lint"

assert_field "test uses make test" \
  "$OUTPUT" "commands.test" "make test"

assert_field_empty "typecheck is empty for Go" \
  "$OUTPUT" "commands.typecheck"

# ─────────────────────────────────────────────
# Section 2: Go project with partial Makefile (no lint target)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go with partial Makefile (no lint target) ---${NC}\n"

# With golangci-lint available
OUTPUT=$(PATH="$PATH_WITH_LINT" "$DETECT" "$GO_MAKEFILE_PARTIAL")

assert_field "build uses make build" \
  "$OUTPUT" "commands.build" "make build"

assert_field "lint falls back to golangci-lint run" \
  "$OUTPUT" "commands.lint" "golangci-lint run"

assert_field "test uses make test" \
  "$OUTPUT" "commands.test" "make test"

# Without golangci-lint
OUTPUT=$(PATH="$PATH_WITHOUT_LINT" "$DETECT" "$GO_MAKEFILE_PARTIAL")

assert_field "lint falls back to go vet without golangci-lint" \
  "$OUTPUT" "commands.lint" "go vet ./..."

# ─────────────────────────────────────────────
# Section 3: Go project without Makefile
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go without Makefile ---${NC}\n"

# With golangci-lint available
OUTPUT=$(PATH="$PATH_WITH_LINT" "$DETECT" "$GO_NO_MAKEFILE")

assert_field "build is go build" \
  "$OUTPUT" "commands.build" "go build ./..."

assert_field "lint is golangci-lint run" \
  "$OUTPUT" "commands.lint" "golangci-lint run"

assert_field "test is go test" \
  "$OUTPUT" "commands.test" "go test ./..."

assert_field_empty "typecheck is empty" \
  "$OUTPUT" "commands.typecheck"

# Without golangci-lint
OUTPUT=$(PATH="$PATH_WITHOUT_LINT" "$DETECT" "$GO_NO_MAKEFILE")

assert_field "lint falls back to go vet without golangci-lint" \
  "$OUTPUT" "commands.lint" "go vet ./..."

assert_field "build still go build without golangci-lint" \
  "$OUTPUT" "commands.build" "go build ./..."

assert_field "test still go test without golangci-lint" \
  "$OUTPUT" "commands.test" "go test ./..."

# ─────────────────────────────────────────────
# Section 4: Node.js project (regression)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Node.js project (regression) ---${NC}\n"

OUTPUT=$("$DETECT" "$NODE_PROJECT")

assert_field "project type is node-typescript" \
  "$OUTPUT" "project_type" "node-typescript"

assert_field "build is npm run build" \
  "$OUTPUT" "commands.build" "npm run build"

assert_field "lint is npm run lint" \
  "$OUTPUT" "commands.lint" "npm run lint"

assert_field "test is npm run test" \
  "$OUTPUT" "commands.test" "npm run test"

# ─────────────────────────────────────────────
# Section 5: Unknown project
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Unknown project ---${NC}\n"

OUTPUT=$("$DETECT" "$UNKNOWN_PROJECT")

assert_field "project type is unknown" \
  "$OUTPUT" "project_type" "unknown"

assert_field_empty "build is empty" \
  "$OUTPUT" "commands.build"

assert_field_empty "lint is empty" \
  "$OUTPUT" "commands.lint"

assert_field_empty "test is empty" \
  "$OUTPUT" "commands.test"

assert_field_empty "typecheck is empty" \
  "$OUTPUT" "commands.typecheck"

# ─────────────────────────────────────────────
# Section 6: Go Makefile with vet target
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go Makefile vet target detection ---${NC}\n"

# When Makefile has vet but no dedicated lint, and no golangci-lint
GO_MAKEFILE_VET="$TEMP_BASE/go-makefile-vet"
mkdir -p "$GO_MAKEFILE_VET"
echo 'module example.com/test' > "$GO_MAKEFILE_VET/go.mod"
cat > "$GO_MAKEFILE_VET/Makefile" << 'EOF'
.PHONY: build test vet

build:
	go build ./...

test:
	go test ./...

vet:
	go vet ./...
EOF

OUTPUT=$(PATH="$PATH_WITHOUT_LINT" "$DETECT" "$GO_MAKEFILE_VET")

assert_field "lint uses make vet when no lint target and no golangci-lint" \
  "$OUTPUT" "commands.lint" "make vet"

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
