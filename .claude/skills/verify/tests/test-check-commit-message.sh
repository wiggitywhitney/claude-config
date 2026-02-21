#!/usr/bin/env bash
# test-check-commit-message.sh — Tests for the commit message hook
#
# Exercises check-commit-message.sh with various inputs:
# - Non-commit commands (should passthrough silently)
# - Clean commit messages (should passthrough silently)
# - AI/Claude references in various formats (should deny)
# - False-positive resistance (file paths containing "claude")
# - All three message formats: heredoc, -m, --message
#
# Usage: bash verify/tests/test-check-commit-message.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../scripts/check-commit-message.sh"

PASS=0
FAIL=0
TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

  # Allow = exit 0 with no output (silent passthrough) or no deny in output
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

assert_deny_contains() {
  local description="$1"
  local json="$2"
  local expected_fragment="$3"
  TOTAL=$((TOTAL + 1))

  local output
  output=$(run_hook "$json")
  local exit_code=$?

  if [ $exit_code -eq 0 ] && echo "$output" | grep -q '"deny"' && echo "$output" | grep -qi "$expected_fragment"; then
    PASS=$((PASS + 1))
    printf "${GREEN}  PASS${NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    printf "${RED}  FAIL${NC} %s\n" "$description"
    printf "       Expected: deny containing '%s'\n" "$expected_fragment"
    printf "       Got exit=%d, output=%s\n" "$exit_code" "$output"
  fi
}

# Helper to build hook JSON input (uses env var to avoid shell quoting issues)
make_input() {
  local command="$1"
  HOOK_TEST_CMD="$command" python3 -c "
import json, os
cmd = os.environ['HOOK_TEST_CMD']
print(json.dumps({
    'tool_name': 'Bash',
    'tool_input': {'command': cmd},
    'cwd': '/tmp/test-project'
}))
"
}

echo ""
printf "${YELLOW}=== check-commit-message.sh tests ===${NC}\n"
echo ""

# ─────────────────────────────────────────────
# Section 1: Non-commit commands (silent passthrough)
# ─────────────────────────────────────────────
printf "${YELLOW}--- Non-commit commands (should passthrough) ---${NC}\n"

assert_allow "git status passes through" \
  "$(make_input 'git status')"

assert_allow "git push passes through" \
  "$(make_input 'git push origin main')"

assert_allow "git log passes through" \
  "$(make_input 'git log --oneline -5')"

assert_allow "npm test passes through" \
  "$(make_input 'npm test')"

assert_allow "ls passes through" \
  "$(make_input 'ls -la')"

# ─────────────────────────────────────────────
# Section 2: Clean commit messages (silent passthrough)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Clean commit messages (should passthrough) ---${NC}\n"

assert_allow "clean -m message" \
  "$(make_input 'git commit -m "fix: resolve null pointer in login flow"')"

assert_allow "clean --message message" \
  "$(make_input 'git commit --message="feat: add user authentication"')"

assert_allow "clean heredoc message" \
  "$(make_input "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nfix: resolve null pointer in login flow\nEOF\n)"')")"

assert_allow "commit with --amend and no message" \
  "$(make_input 'git commit --amend --no-edit')"

assert_allow "chained clean commit" \
  "$(make_input 'git add . && git commit -m "refactor: extract helper function"')"

# ─────────────────────────────────────────────
# Section 3: AI reference patterns (should deny)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- AI reference patterns with -m (should deny) ---${NC}\n"

assert_deny "blocks 'Claude Code' reference" \
  "$(make_input 'git commit -m "feat: add login - built with Claude Code"')"

assert_deny "blocks 'claude' reference" \
  "$(make_input 'git commit -m "fix: bug found by claude"')"

assert_deny "blocks 'Anthropic' reference" \
  "$(make_input 'git commit -m "feat: using Anthropic API patterns"')"

assert_deny "blocks 'Generated with' reference" \
  "$(make_input 'git commit -m "docs: generated with AI tooling"')"

assert_deny "blocks 'Co-Authored-By Claude' reference" \
  "$(make_input "$(printf 'git commit -m "feat: add feature\n\nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"')")"

assert_deny "blocks 'AI assistant' reference" \
  "$(make_input 'git commit -m "refactor: suggested by AI assistant"')"

assert_deny "blocks 'AI-generated' reference" \
  "$(make_input 'git commit -m "docs: AI-generated documentation"')"

assert_deny "blocks 'LLM' reference" \
  "$(make_input 'git commit -m "feat: output from LLM processing"')"

assert_deny "blocks 'language model' reference" \
  "$(make_input 'git commit -m "feat: language model integration"')"

assert_deny "blocks case-insensitive 'CLAUDE'" \
  "$(make_input 'git commit -m "fix: CLAUDE found this bug"')"

# ─────────────────────────────────────────────
# Section 4: AI references in heredoc format (should deny)
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- AI references in heredoc format (should deny) ---${NC}\n"

assert_deny "blocks Claude in heredoc" \
  "$(make_input "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nfeat: add feature\n\nCo-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>\nEOF\n)"')")"

assert_deny "blocks Generated with in heredoc" \
  "$(make_input "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nGenerated with Claude Code\nEOF\n)"')")"

# ─────────────────────────────────────────────
# Section 5: False-positive resistance
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- False-positive resistance ---${NC}\n"

# git add with claude in path, but clean commit message
assert_allow "file path with 'claude' in git add does not trigger" \
  "$(make_input 'git add claude-config/hooks/test.sh && git commit -m "fix: update hook logic"')"

assert_allow "file path with 'claude' in -C flag does not trigger" \
  "$(make_input 'git -C /path/to/claude-config commit -m "fix: update hook"')"

# File paths containing "claude" inside the commit message text itself
assert_allow "~/.claude/ path in commit message does not trigger" \
  "$(make_input 'git commit -m "feat: symlink config from ~/.claude/ directory"')"

assert_allow "CLAUDE.md filename in commit message does not trigger" \
  "$(make_input 'git commit -m "docs: update CLAUDE.md with new rules"')"

assert_allow ".claude/settings.json path in commit message does not trigger" \
  "$(make_input 'git commit -m "fix: update .claude/settings.json deny list"')"

assert_allow "claude-config repo name in commit message does not trigger" \
  "$(make_input 'git commit -m "feat: track global config in claude-config repo"')"

assert_allow "multiple path references with claude do not trigger" \
  "$(make_input 'git commit -m "feat: symlink ~/.claude/CLAUDE.md to claude-config/global/"')"

# ─────────────────────────────────────────────
# Section 6: Edge cases
# ─────────────────────────────────────────────
printf "\n${YELLOW}--- Edge cases ---${NC}\n"

assert_allow "empty command" \
  "$(make_input '')"

assert_allow "malformed JSON handled gracefully" \
  '{"broken": true}'

assert_allow "commit with -a flag and clean message" \
  "$(make_input 'git commit -a -m "fix: resolve race condition"')"

assert_deny "commit with -a flag and AI reference" \
  "$(make_input 'git commit -a -m "fix: claude found race condition"')"

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
