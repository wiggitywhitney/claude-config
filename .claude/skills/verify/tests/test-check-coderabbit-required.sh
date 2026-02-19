#!/usr/bin/env bash
# test-check-coderabbit-required.sh — Tests for the CodeRabbit review requirement hook
#
# Exercises check-coderabbit-required.sh with various inputs:
# - Non-merge commands (should passthrough)
# - PR merge with .skip-coderabbit (should passthrough)
# - PR merge without .skip-coderabbit (should deny)
# - Edge cases
#
# Note: Tests that verify actual CodeRabbit review status via GitHub API
# are skipped in this unit test suite (they require network access and a real PR).
# Those are covered by manual integration testing.
#
# Usage: bash verify/tests/test-check-coderabbit-required.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/check-coderabbit-required.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create a temp directory for testing
TEMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

run_hook() {
  local json="$1"
  echo "$json" | "$HOOK" 2>/dev/null
}

assert_allow() {
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
    printf "       Expected: allow (silent passthrough)\n"
    printf "       Got exit=%d, output=%s\n" "$exit_code" "$output"
  fi
}

assert_deny() {
  local description="$1"
  local json="$2"
  TOTAL=$((TOTAL + 1))

  local output
  output=$(run_hook "$json")
  local exit_code=$?

  if [ $exit_code -eq 0 ] && echo "$output" | grep -q '"deny"'; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected: deny with JSON output\n"
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
printf "${YELLOW}=== check-coderabbit-required.sh tests ===${NC}\n"
echo ""

# ─────────────────────────────────────────────
# Section 1: Non-merge commands (silent passthrough)
# ─────────────────────────────────────────────
printf "${YELLOW}--- Non-merge commands (should passthrough) ---${NC}\n"

assert_allow "git status passes through" \
  "$(make_input 'git status' "$TEMP_DIR")"

assert_allow "git push passes through" \
  "$(make_input 'git push origin main' "$TEMP_DIR")"

assert_allow "gh pr create passes through" \
  "$(make_input 'gh pr create --title "test"' "$TEMP_DIR")"

assert_allow "gh pr view passes through" \
  "$(make_input 'gh pr view 123' "$TEMP_DIR")"

assert_allow "npm test passes through" \
  "$(make_input 'npm test' "$TEMP_DIR")"

# ─────────────────────────────────────────────
# Section 2: PR merge with .skip-coderabbit (should passthrough)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- PR merge with .skip-coderabbit (should passthrough) ---${NC}\n"

touch "$TEMP_DIR/.skip-coderabbit"

assert_allow "gh pr merge with .skip-coderabbit passes through" \
  "$(make_input 'gh pr merge 123' "$TEMP_DIR")"

assert_allow "gh pr merge --squash with .skip-coderabbit passes through" \
  "$(make_input 'gh pr merge 123 --squash' "$TEMP_DIR")"

assert_allow "chained gh pr merge with .skip-coderabbit passes through" \
  "$(make_input 'echo "merging" && gh pr merge 123' "$TEMP_DIR")"

rm "$TEMP_DIR/.skip-coderabbit"

# ─────────────────────────────────────────────
# Section 3: PR merge without .skip-coderabbit (should deny)
# Note: Without a real git repo + GitHub remote, gh commands will fail,
# causing the hook to deny (can't verify review status).
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- PR merge without .skip-coderabbit (should deny) ---${NC}\n"

assert_deny "gh pr merge without .skip-coderabbit is blocked" \
  "$(make_input 'gh pr merge 123' "$TEMP_DIR")"

assert_deny "gh pr merge with flags without .skip-coderabbit is blocked" \
  "$(make_input 'gh pr merge 123 --merge --delete-branch' "$TEMP_DIR")"

assert_deny "chained gh pr merge without .skip-coderabbit is blocked" \
  "$(make_input 'echo "merging" && gh pr merge 456' "$TEMP_DIR")"

# ─────────────────────────────────────────────
# Section 4: Edge cases
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Edge cases ---${NC}\n"

assert_allow "empty command passes through" \
  "$(make_input '' "$TEMP_DIR")"

assert_allow "malformed JSON handled gracefully" \
  '{"broken": true}'

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
