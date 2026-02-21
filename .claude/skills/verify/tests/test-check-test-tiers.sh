#!/usr/bin/env bash
# test-check-test-tiers.sh — Tests for the test tier enforcement hook
#
# Exercises check-test-tiers.sh with various inputs:
# - Non-push/PR commands (should passthrough)
# - Projects with all test tiers (should passthrough)
# - Projects missing test tiers (should warn with allow)
# - Dotfile opt-outs (.skip-e2e, .skip-integration)
# - Unknown project types (should passthrough)
# - Edge cases
#
# Usage: bash .claude/skills/verify/tests/test-check-test-tiers.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/check-test-tiers.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create temp directories for different project scenarios
TEMP_BASE=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_BASE"
}
trap cleanup EXIT

# --- Setup test project directories ---

# Project with all tiers (Node.js)
PROJ_ALL="$TEMP_BASE/all-tiers"
mkdir -p "$PROJ_ALL/tests/unit" "$PROJ_ALL/tests/integration" "$PROJ_ALL/tests/e2e"
echo '{"scripts":{"test":"vitest"}}' > "$PROJ_ALL/package.json"
echo 'describe("unit", () => { it("works", () => {}) })' > "$PROJ_ALL/tests/unit/example.test.js"

# Project with unit only
PROJ_UNIT="$TEMP_BASE/unit-only"
mkdir -p "$PROJ_UNIT/src"
echo '{"scripts":{"test":"vitest"}}' > "$PROJ_UNIT/package.json"
echo 'describe("test", () => { it("works", () => {}) })' > "$PROJ_UNIT/src/app.test.js"

# Project with no tests
PROJ_NONE="$TEMP_BASE/no-tests"
mkdir -p "$PROJ_NONE/src"
echo '{"scripts":{"start":"node index.js"}}' > "$PROJ_NONE/package.json"

# Project with unit + integration, missing e2e
PROJ_NO_E2E="$TEMP_BASE/no-e2e"
mkdir -p "$PROJ_NO_E2E/tests/unit" "$PROJ_NO_E2E/tests/integration"
echo '{"scripts":{"test":"vitest"}}' > "$PROJ_NO_E2E/package.json"
echo 'describe("unit", () => {})' > "$PROJ_NO_E2E/tests/unit/example.test.js"
echo 'describe("integration", () => {})' > "$PROJ_NO_E2E/tests/integration/api.test.js"

# Project with .skip-e2e dotfile
PROJ_SKIP_E2E="$TEMP_BASE/skip-e2e"
mkdir -p "$PROJ_SKIP_E2E/tests/unit" "$PROJ_SKIP_E2E/tests/integration"
echo '{"scripts":{"test":"vitest"}}' > "$PROJ_SKIP_E2E/package.json"
echo 'describe("unit", () => {})' > "$PROJ_SKIP_E2E/tests/unit/example.test.js"
echo 'describe("integration", () => {})' > "$PROJ_SKIP_E2E/tests/integration/api.test.js"
touch "$PROJ_SKIP_E2E/.skip-e2e"

# Project with .skip-integration dotfile
PROJ_SKIP_INT="$TEMP_BASE/skip-integration"
mkdir -p "$PROJ_SKIP_INT/src"
echo '{"scripts":{"test":"vitest"}}' > "$PROJ_SKIP_INT/package.json"
echo 'describe("test", () => {})' > "$PROJ_SKIP_INT/src/app.test.js"
touch "$PROJ_SKIP_INT/.skip-integration"

# Project with both skip dotfiles
PROJ_SKIP_BOTH="$TEMP_BASE/skip-both"
mkdir -p "$PROJ_SKIP_BOTH/src"
echo '{"scripts":{"test":"vitest"}}' > "$PROJ_SKIP_BOTH/package.json"
echo 'describe("test", () => {})' > "$PROJ_SKIP_BOTH/src/app.test.js"
touch "$PROJ_SKIP_BOTH/.skip-e2e"
touch "$PROJ_SKIP_BOTH/.skip-integration"

# Unknown project (no package.json, no pyproject.toml)
PROJ_UNKNOWN="$TEMP_BASE/unknown"
mkdir -p "$PROJ_UNKNOWN"
echo "just a readme" > "$PROJ_UNKNOWN/README.md"

# --- Test helpers ---

run_hook() {
  local json="$1"
  echo "$json" | "$HOOK" 2>/dev/null
}

assert_silent() {
  local description="$1"
  local json="$2"
  TOTAL=$((TOTAL + 1))

  local output
  output=$(run_hook "$json")
  local exit_code=$?

  # Silent passthrough = exit 0 with empty output
  if [ $exit_code -eq 0 ] && [ -z "$output" ]; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected: silent passthrough (no output)\n"
    printf "       Got exit=%d, output=%s\n" "$exit_code" "$output"
  fi
}

assert_allow_with_warning() {
  local description="$1"
  local json="$2"
  local expected_tier="$3"
  TOTAL=$((TOTAL + 1))

  local output
  output=$(run_hook "$json")
  local exit_code=$?

  if [ $exit_code -eq 0 ] && echo "$output" | grep -q '"allow"' && echo "$output" | grep -qi "$expected_tier"; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected: allow with warning containing '%s'\n" "$expected_tier"
    printf "       Got exit=%d, output=%s\n" "$exit_code" "$output"
  fi
}

assert_no_deny() {
  local description="$1"
  local json="$2"
  TOTAL=$((TOTAL + 1))

  local output
  output=$(run_hook "$json")
  local exit_code=$?

  if [ $exit_code -eq 0 ] && ! echo "$output" | grep -q '"deny"'; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected: no deny (warn-only)\n"
    printf "       Got exit=%d, output=%s\n" "$exit_code" "$output"
  fi
}

assert_allow_silent_reason() {
  # Verify allow responses use additionalContext only (no permissionDecisionReason).
  # Decision 3 (PRD 11): allow hooks must not set permissionDecisionReason to
  # avoid confusing "Error: ... passed" messages when another hook denies.
  local description="$1"
  local json="$2"
  local expected_tier="$3"
  TOTAL=$((TOTAL + 1))

  local output
  output=$(run_hook "$json")
  local exit_code=$?

  if [ $exit_code -eq 0 ] && echo "$output" | grep -q '"allow"' && echo "$output" | grep -qi "$expected_tier" && ! echo "$output" | grep -q 'permissionDecisionReason'; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected: allow with warning in additionalContext only (no permissionDecisionReason)\n"
    printf "       Got exit=%d, output=%s\n" "$exit_code" "$output"
  fi
}

make_input() {
  local command="$1"
  local cwd="$2"
  HOOK_TEST_CMD="$command" HOOK_TEST_CWD="$cwd" python3 -c "
import json, os
cmd = os.environ['HOOK_TEST_CMD']
cwd = os.environ['HOOK_TEST_CWD']
print(json.dumps({
    'tool_name': 'Bash',
    'tool_input': {'command': cmd},
    'cwd': cwd
}))
"
}

echo ""
printf "${YELLOW}=== check-test-tiers.sh tests ===${NC}\n"
echo ""

# ─────────────────────────────────────────────
# Section 1: Non-push/PR commands (silent passthrough)
# ─────────────────────────────────────────────
printf "${YELLOW}--- Non-push/PR commands (should passthrough) ---${NC}\n"

assert_silent "git status passes through" \
  "$(make_input 'git status' "$PROJ_NONE")"

assert_silent "git commit passes through" \
  "$(make_input 'git commit -m "feat: add feature"' "$PROJ_NONE")"

assert_silent "npm test passes through" \
  "$(make_input 'npm test' "$PROJ_NONE")"

assert_silent "git log passes through" \
  "$(make_input 'git log --oneline' "$PROJ_NONE")"

# ─────────────────────────────────────────────
# Section 2: All tiers present (silent passthrough)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- All tiers present (should passthrough) ---${NC}\n"

assert_silent "push with all tiers passes through" \
  "$(make_input 'git push origin main' "$PROJ_ALL")"

assert_silent "PR create with all tiers passes through" \
  "$(make_input 'gh pr create --title "test"' "$PROJ_ALL")"

# ─────────────────────────────────────────────
# Section 3: Missing tiers (should warn, not block)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Missing tiers (should warn with allow) ---${NC}\n"

assert_allow_with_warning "push with no tests warns about unit" \
  "$(make_input 'git push' "$PROJ_NONE")" "unit"

assert_allow_with_warning "push with no tests warns about integration" \
  "$(make_input 'git push' "$PROJ_NONE")" "integration"

assert_allow_with_warning "push with no tests warns about e2e" \
  "$(make_input 'git push' "$PROJ_NONE")" "e2e"

assert_allow_with_warning "PR with unit-only warns about integration" \
  "$(make_input 'gh pr create --title "test"' "$PROJ_UNIT")" "integration"

assert_allow_with_warning "PR with unit-only warns about e2e" \
  "$(make_input 'gh pr create --title "test"' "$PROJ_UNIT")" "e2e"

assert_allow_with_warning "push missing e2e warns about e2e" \
  "$(make_input 'git push' "$PROJ_NO_E2E")" "e2e"

# ─────────────────────────────────────────────
# Section 3b: Silent allow — no permissionDecisionReason (Decision 3, PRD 11)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Silent allow — warning in additionalContext only ---${NC}\n"

assert_allow_silent_reason "push warning uses additionalContext only (no permissionDecisionReason)" \
  "$(make_input 'git push' "$PROJ_NONE")" "unit"

assert_allow_silent_reason "PR warning uses additionalContext only (no permissionDecisionReason)" \
  "$(make_input 'gh pr create --title \"test\"' "$PROJ_UNIT")" "integration"

# ─────────────────────────────────────────────
# Section 4: Never blocks (always allow)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Never blocks (should never deny) ---${NC}\n"

assert_no_deny "push with no tests never denies" \
  "$(make_input 'git push' "$PROJ_NONE")"

assert_no_deny "PR with no tests never denies" \
  "$(make_input 'gh pr create --title "test"' "$PROJ_NONE")"

assert_no_deny "push with unit-only never denies" \
  "$(make_input 'git push' "$PROJ_UNIT")"

# ─────────────────────────────────────────────
# Section 5: Dotfile opt-outs (Decision 16)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Dotfile opt-outs (should suppress warnings) ---${NC}\n"

assert_silent ".skip-e2e suppresses e2e warning" \
  "$(make_input 'git push' "$PROJ_SKIP_E2E")"

assert_allow_with_warning ".skip-integration still warns about e2e" \
  "$(make_input 'git push' "$PROJ_SKIP_INT")" "e2e"

assert_silent ".skip-e2e + .skip-integration suppresses all non-unit warnings" \
  "$(make_input 'git push' "$PROJ_SKIP_BOTH")"

# ─────────────────────────────────────────────
# Section 6: Unknown project types (silent passthrough)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Unknown project types (should passthrough) ---${NC}\n"

assert_silent "push in unknown project passes through" \
  "$(make_input 'git push' "$PROJ_UNKNOWN")"

assert_silent "PR create in unknown project passes through" \
  "$(make_input 'gh pr create --title "test"' "$PROJ_UNKNOWN")"

# ─────────────────────────────────────────────
# Section 7: Edge cases
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Edge cases ---${NC}\n"

assert_silent "empty command" \
  "$(make_input '' "$PROJ_NONE")"

assert_silent "malformed JSON handled gracefully" \
  '{"broken": true}'

assert_allow_with_warning "chained push command still triggers" \
  "$(make_input 'git add . && git push' "$PROJ_NONE")" "unit"

assert_allow_with_warning "push with -C flag triggers" \
  "$(make_input "git -C $PROJ_NONE push" '/tmp')" "unit"

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
