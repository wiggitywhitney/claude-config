#!/usr/bin/env bash
# test-check-branch-protection.sh — Tests for the branch protection hook
#
# Exercises check-branch-protection.sh with various inputs:
# - Non-commit commands (should passthrough)
# - Commits on feature branches (should passthrough)
# - Commits on main/master (should deny)
# - Commits on main/master with .skip-branching (should passthrough)
# - Edge cases
#
# Usage: bash verify/tests/test-check-branch-protection.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/check-branch-protection.sh"

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create a temp git repo for testing
TEMP_DIR=$(mktemp -d)
git -C "$TEMP_DIR" init -b main --quiet 2>/dev/null
# Create an initial commit so branch exists
git -C "$TEMP_DIR" commit --allow-empty -m "initial" --quiet 2>/dev/null

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
printf "${YELLOW}=== check-branch-protection.sh tests ===${NC}\n"
echo ""

# ─────────────────────────────────────────────
# Section 1: Non-commit commands (silent passthrough)
# ─────────────────────────────────────────────
printf "${YELLOW}--- Non-commit commands (should passthrough) ---${NC}\n"

assert_allow "git status passes through" \
  "$(make_input 'git status' "$TEMP_DIR")"

assert_allow "git push passes through" \
  "$(make_input 'git push origin main' "$TEMP_DIR")"

assert_allow "npm test passes through" \
  "$(make_input 'npm test' "$TEMP_DIR")"

# ─────────────────────────────────────────────
# Section 2: Commits on feature branches (should passthrough)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Commits on feature branches (should passthrough) ---${NC}\n"

# Create and switch to a feature branch
git -C "$TEMP_DIR" checkout -b feature/test-branch --quiet 2>/dev/null

assert_allow "commit on feature branch passes through" \
  "$(make_input 'git commit -m "feat: add feature"' "$TEMP_DIR")"

assert_allow "chained commit on feature branch passes through" \
  "$(make_input 'git add . && git commit -m "fix: update"' "$TEMP_DIR")"

# ─────────────────────────────────────────────
# Section 3: Commits on main (should deny)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Commits on main/master (should deny) ---${NC}\n"

# Switch back to main
git -C "$TEMP_DIR" checkout main --quiet 2>/dev/null

assert_deny "commit on main is blocked" \
  "$(make_input 'git commit -m "fix: direct to main"' "$TEMP_DIR")"

assert_deny "chained commit on main is blocked" \
  "$(make_input 'git add . && git commit -m "fix: chained on main"' "$TEMP_DIR")"

# Test master branch (subdirectory of TEMP_DIR so it's covered by the EXIT trap)
TEMP_MASTER="$TEMP_DIR/master-repo"
mkdir -p "$TEMP_MASTER"
git -C "$TEMP_MASTER" init -b master --quiet 2>/dev/null
git -C "$TEMP_MASTER" commit --allow-empty -m "initial" --quiet 2>/dev/null

assert_deny "commit on master is blocked" \
  "$(make_input 'git commit -m "fix: direct to master"' "$TEMP_MASTER")"

# ─────────────────────────────────────────────
# Section 4: .skip-branching opt-out (should passthrough)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- .skip-branching opt-out (should passthrough) ---${NC}\n"

# Create .skip-branching file
touch "$TEMP_DIR/.skip-branching"

assert_allow "commit on main with .skip-branching passes through" \
  "$(make_input 'git commit -m "fix: allowed on main"' "$TEMP_DIR")"

# Clean up dotfile
rm "$TEMP_DIR/.skip-branching"

# Verify it blocks again after removing dotfile
assert_deny "commit on main blocked again after removing .skip-branching" \
  "$(make_input 'git commit -m "fix: blocked again"' "$TEMP_DIR")"

# ─────────────────────────────────────────────
# Section 5: Edge cases
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Edge cases ---${NC}\n"

assert_allow "non-git directory passes through" \
  "$(make_input 'git commit -m "test"' '/tmp')"

# Switch to feature branch for -C tests
git -C "$TEMP_DIR" checkout feature/test-branch --quiet 2>/dev/null

assert_allow "commit with -C to feature branch passes through" \
  "$(make_input "git -C $TEMP_DIR commit -m \"test\"" '/tmp')"

# Switch back to main — -C should use the target repo's branch, not cwd's
git -C "$TEMP_DIR" checkout main --quiet 2>/dev/null

assert_deny "commit with -C to main is blocked" \
  "$(make_input "git -C $TEMP_DIR commit -m \"test\"" '/tmp')"

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
