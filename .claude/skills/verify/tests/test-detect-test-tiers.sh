#!/usr/bin/env bash
# test-detect-test-tiers.sh — Tests for Go test tier detection in detect-test-tiers.sh
#
# Exercises detect-test-tiers.sh with Go project configurations:
# - Go project with no tests
# - Go project with unit tests only (_test.go without build tags)
# - Go project with integration tests (build tags and directory conventions)
# - Go project with e2e tests (build tags, envtest, Kind)
# - Go project with all tiers
# - Edge cases (mixed build tags, nested directories)
#
# Also includes regression tests for Node.js/Python detection.
#
# Usage: bash .claude/skills/verify/tests/test-detect-test-tiers.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT="$SCRIPT_DIR/../scripts/detect-test-tiers.sh"

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
print(val)
" 2>/dev/null
}

# --- Test helpers ---

assert_tier() {
  local description="$1"
  local json="$2"
  local tier="$3"
  local expected="$4"
  TOTAL=$((TOTAL + 1))

  local actual
  actual=$(json_field "$json" "test_tiers.$tier")

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Tier: %s\n" "$tier"
    printf "       Expected: %s\n" "$expected"
    printf "       Got:      %s\n" "$actual"
  fi
}

assert_project_type() {
  local description="$1"
  local json="$2"
  local expected="$3"
  TOTAL=$((TOTAL + 1))

  local actual
  actual=$(json_field "$json" "project_type")

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected project_type: %s\n" "$expected"
    printf "       Got:                   %s\n" "$actual"
  fi
}

# --- Setup Go test project directories ---

# Go project with no tests
GO_NO_TESTS="$TEMP_BASE/go-no-tests"
mkdir -p "$GO_NO_TESTS"
echo 'module example.com/test' > "$GO_NO_TESTS/go.mod"
cat > "$GO_NO_TESTS/main.go" << 'EOF'
package main

func main() {}
EOF

# Go project with unit tests only (plain _test.go, no build tags)
GO_UNIT_ONLY="$TEMP_BASE/go-unit-only"
mkdir -p "$GO_UNIT_ONLY/pkg/handler"
echo 'module example.com/test' > "$GO_UNIT_ONLY/go.mod"
cat > "$GO_UNIT_ONLY/pkg/handler/handler_test.go" << 'EOF'
package handler

import "testing"

func TestHandleRequest(t *testing.T) {
	t.Log("unit test")
}
EOF

# Go project with integration build tag
GO_INTEGRATION_TAG="$TEMP_BASE/go-integration-tag"
mkdir -p "$GO_INTEGRATION_TAG/pkg"
echo 'module example.com/test' > "$GO_INTEGRATION_TAG/go.mod"
cat > "$GO_INTEGRATION_TAG/pkg/db_test.go" << 'EOF'
package pkg

import "testing"

func TestDBConnection(t *testing.T) {
	t.Log("unit test")
}
EOF
cat > "$GO_INTEGRATION_TAG/pkg/db_integration_test.go" << 'EOF'
//go:build integration

package pkg

import "testing"

func TestDBIntegration(t *testing.T) {
	t.Log("integration test")
}
EOF

# Go project with tests/integration/ directory convention
GO_INTEGRATION_DIR="$TEMP_BASE/go-integration-dir"
mkdir -p "$GO_INTEGRATION_DIR/tests/integration"
echo 'module example.com/test' > "$GO_INTEGRATION_DIR/go.mod"
cat > "$GO_INTEGRATION_DIR/main_test.go" << 'EOF'
package main

import "testing"

func TestMain(t *testing.T) {
	t.Log("unit test")
}
EOF
cat > "$GO_INTEGRATION_DIR/tests/integration/api_test.go" << 'EOF'
package integration

import "testing"

func TestAPI(t *testing.T) {
	t.Log("integration test")
}
EOF

# Go project with e2e build tag
GO_E2E_TAG="$TEMP_BASE/go-e2e-tag"
mkdir -p "$GO_E2E_TAG/test"
echo 'module example.com/test' > "$GO_E2E_TAG/go.mod"
cat > "$GO_E2E_TAG/main_test.go" << 'EOF'
package main

import "testing"

func TestMain(t *testing.T) {
	t.Log("unit test")
}
EOF
cat > "$GO_E2E_TAG/test/e2e_test.go" << 'EOF'
//go:build e2e

package test

import "testing"

func TestE2E(t *testing.T) {
	t.Log("e2e test")
}
EOF

# Go project with envtest (Kubebuilder pattern)
GO_ENVTEST="$TEMP_BASE/go-envtest"
mkdir -p "$GO_ENVTEST/internal/controller"
echo 'module example.com/test' > "$GO_ENVTEST/go.mod"
cat > "$GO_ENVTEST/internal/controller/suite_test.go" << 'EOF'
package controller

import (
	"testing"

	"sigs.k8s.io/controller-runtime/pkg/envtest"
)

var testEnv *envtest.Environment

func TestMain(m *testing.M) {
	testEnv = &envtest.Environment{}
}
EOF

# Go project with Kind cluster setup
GO_KIND="$TEMP_BASE/go-kind"
mkdir -p "$GO_KIND/test/e2e"
echo 'module example.com/test' > "$GO_KIND/go.mod"
cat > "$GO_KIND/main_test.go" << 'EOF'
package main

import "testing"

func TestMain(t *testing.T) {
	t.Log("unit test")
}
EOF
cat > "$GO_KIND/test/e2e/cluster_test.go" << 'EOF'
package e2e

import (
	"testing"

	"sigs.k8s.io/kind/pkg/cluster"
)

func TestClusterSetup(t *testing.T) {
	provider := cluster.NewProvider()
	_ = provider
}
EOF

# Go project with all three tiers
GO_ALL_TIERS="$TEMP_BASE/go-all-tiers"
mkdir -p "$GO_ALL_TIERS/pkg" "$GO_ALL_TIERS/test/e2e"
echo 'module example.com/test' > "$GO_ALL_TIERS/go.mod"
cat > "$GO_ALL_TIERS/pkg/handler_test.go" << 'EOF'
package pkg

import "testing"

func TestHandler(t *testing.T) {
	t.Log("unit test")
}
EOF
cat > "$GO_ALL_TIERS/pkg/handler_integration_test.go" << 'EOF'
//go:build integration

package pkg

import "testing"

func TestHandlerIntegration(t *testing.T) {
	t.Log("integration test")
}
EOF
cat > "$GO_ALL_TIERS/test/e2e/e2e_test.go" << 'EOF'
//go:build e2e

package e2e

import "testing"

func TestEndToEnd(t *testing.T) {
	t.Log("e2e test")
}
EOF

# Go project with tests/e2e/ directory (no build tag)
GO_E2E_DIR="$TEMP_BASE/go-e2e-dir"
mkdir -p "$GO_E2E_DIR/tests/e2e"
echo 'module example.com/test' > "$GO_E2E_DIR/go.mod"
cat > "$GO_E2E_DIR/main_test.go" << 'EOF'
package main

import "testing"

func TestMain(t *testing.T) {
	t.Log("unit test")
}
EOF
cat > "$GO_E2E_DIR/tests/e2e/smoke_test.go" << 'EOF'
package e2e

import "testing"

func TestSmoke(t *testing.T) {
	t.Log("e2e test")
}
EOF

# Go project where only build-tagged files exist (no plain unit tests)
GO_ONLY_TAGGED="$TEMP_BASE/go-only-tagged"
mkdir -p "$GO_ONLY_TAGGED/pkg"
echo 'module example.com/test' > "$GO_ONLY_TAGGED/go.mod"
cat > "$GO_ONLY_TAGGED/pkg/integration_test.go" << 'EOF'
//go:build integration

package pkg

import "testing"

func TestIntegration(t *testing.T) {
	t.Log("integration only")
}
EOF

# ─────────────────────────────────────────────
echo ""
printf "${YELLOW}=== detect-test-tiers.sh Go detection tests ===${NC}\n"

# ─────────────────────────────────────────────
# Section 1: Go project with no tests
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go project with no tests ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_NO_TESTS")

assert_project_type "detected as go project" \
  "$OUTPUT" "go"

assert_tier "no unit tests detected" \
  "$OUTPUT" "unit" "False"

assert_tier "no integration tests detected" \
  "$OUTPUT" "integration" "False"

assert_tier "no e2e tests detected" \
  "$OUTPUT" "e2e" "False"

# ─────────────────────────────────────────────
# Section 2: Go project with unit tests only
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go project with unit tests only ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_UNIT_ONLY")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "no integration tests" \
  "$OUTPUT" "integration" "False"

assert_tier "no e2e tests" \
  "$OUTPUT" "e2e" "False"

# ─────────────────────────────────────────────
# Section 3: Go integration via build tag
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go integration tests (build tag) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_INTEGRATION_TAG")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "integration detected via build tag" \
  "$OUTPUT" "integration" "True"

assert_tier "no e2e tests" \
  "$OUTPUT" "e2e" "False"

# ─────────────────────────────────────────────
# Section 4: Go integration via directory convention
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go integration tests (directory convention) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_INTEGRATION_DIR")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "integration detected via directory" \
  "$OUTPUT" "integration" "True"

assert_tier "no e2e tests" \
  "$OUTPUT" "e2e" "False"

# ─────────────────────────────────────────────
# Section 5: Go e2e via build tag
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go e2e tests (build tag) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_E2E_TAG")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "no integration tests" \
  "$OUTPUT" "integration" "False"

assert_tier "e2e detected via build tag" \
  "$OUTPUT" "e2e" "True"

# ─────────────────────────────────────────────
# Section 6: Go e2e via envtest (Kubebuilder)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go e2e tests (envtest) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_ENVTEST")

assert_tier "e2e detected via envtest import" \
  "$OUTPUT" "e2e" "True"

# ─────────────────────────────────────────────
# Section 7: Go e2e via Kind
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go e2e tests (Kind) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_KIND")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "e2e detected via Kind import" \
  "$OUTPUT" "e2e" "True"

# ─────────────────────────────────────────────
# Section 8: Go e2e via tests/e2e/ directory
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go e2e tests (directory convention) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_E2E_DIR")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "no integration tests" \
  "$OUTPUT" "integration" "False"

assert_tier "e2e detected via directory" \
  "$OUTPUT" "e2e" "True"

# ─────────────────────────────────────────────
# Section 9: Go project with all tiers
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go project with all tiers ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_ALL_TIERS")

assert_tier "unit tests detected" \
  "$OUTPUT" "unit" "True"

assert_tier "integration tests detected" \
  "$OUTPUT" "integration" "True"

assert_tier "e2e tests detected" \
  "$OUTPUT" "e2e" "True"

# ─────────────────────────────────────────────
# Section 10: Go project with only build-tagged tests (no plain unit tests)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Go project with only tagged tests (no unit) ---${NC}\n"

OUTPUT=$("$DETECT" "$GO_ONLY_TAGGED")

assert_tier "no unit tests (all files have build tags)" \
  "$OUTPUT" "unit" "False"

assert_tier "integration detected via build tag" \
  "$OUTPUT" "integration" "True"

assert_tier "no e2e tests" \
  "$OUTPUT" "e2e" "False"

# ─────────────────────────────────────────────
# Section 11: Node.js regression (ensure Go changes don't break existing)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Node.js regression ---${NC}\n"

NODE_PROJ="$TEMP_BASE/node-regression"
mkdir -p "$NODE_PROJ/tests/unit" "$NODE_PROJ/tests/integration"
echo '{"scripts":{"test":"vitest"}}' > "$NODE_PROJ/package.json"
echo 'describe("unit", () => {})' > "$NODE_PROJ/tests/unit/example.test.js"
echo 'describe("int", () => {})' > "$NODE_PROJ/tests/integration/api.test.js"

OUTPUT=$("$DETECT" "$NODE_PROJ")

assert_project_type "Node.js still detected correctly" \
  "$OUTPUT" "node-javascript"

assert_tier "Node.js unit still works" \
  "$OUTPUT" "unit" "True"

assert_tier "Node.js integration still works" \
  "$OUTPUT" "integration" "True"

assert_tier "Node.js e2e still correctly absent" \
  "$OUTPUT" "e2e" "False"

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
