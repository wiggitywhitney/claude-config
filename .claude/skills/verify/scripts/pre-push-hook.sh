#!/usr/bin/env bash
# pre-push-hook.sh — PreToolUse hook that gates git push on security checks
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects git push commands and runs security checks. If the branch has an
# open PR, escalates to expanded security + tests (PR-tier verification)
# to catch regressions from post-review refactors. Otherwise, runs standard
# security only.
#
# After blocking checks pass, runs an advisory CodeRabbit CLI review.
# CLI review findings are surfaced in additionalContext so Claude can
# address issues before creating a PR. The review never blocks the push.
#
# Verification tiers:
#   git commit   → build, typecheck, lint (pre-commit-hook.sh)
#   git push     → standard security (this hook, no PR)
#   git push     → expanded security + tests (this hook, open PR detected)
#   git push     → CodeRabbit CLI review (advisory, all pushes)
#   gh pr create → expanded security, tests (pre-pr-hook.sh)
#
# PR detection uses `gh pr list` when available. If gh is unavailable or
# the API call fails, falls back to standard security only.
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision
#
# Exit codes:
#   0 — Decision returned via JSON (allow or deny)
#   1 — Unexpected error

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command from the hook input
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on git push commands
# Must handle: git push, git -C <path> push, && git push, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*push\b'; then
  exit 0  # Not a push command, allow it
fi

# Determine project directory from hook input
# If git -C <path> is used, that path overrides cwd
PROJECT_DIR=$(echo "$COMMAND" | grep -oE '\-C\s+\S+' | head -1 | sed 's/^-C[[:space:]]*//' || true)
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Resolve script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Compute diff base for scoping security checks (Decision 7)
# Hooks scope checks to branch changes, not the whole repo.
DIFF_BASE=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "")
if [ -z "$DIFF_BASE" ]; then
  if git -C "$PROJECT_DIR" rev-parse --verify origin/main &>/dev/null; then
    DIFF_BASE="origin/main"
  elif git -C "$PROJECT_DIR" rev-parse --verify origin/master &>/dev/null; then
    DIFF_BASE="origin/master"
  fi
fi

# Docs-only early exit: skip verification if all branch changes are documentation-only.
# Security checks are code-oriented — irrelevant for docs (Decision 4, PRD 11).
if [ -n "$DIFF_BASE" ]; then
  BRANCH_FILES=$(git -C "$PROJECT_DIR" diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null || echo "")
  if [ -n "$BRANCH_FILES" ] && echo "$BRANCH_FILES" | "$SCRIPT_DIR/is-docs-only.sh"; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"verify: push skipped — docs-only changes detected (no code files in branch diff)"}}'
    exit 0
  fi
fi

# Detect if pushing to a branch with an open PR.
# If so, escalate to PR-tier verification (expanded security + tests).
# This catches regressions from post-review refactors that would otherwise
# only be caught by CI after push.
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
HAS_PR=false

if [[ -n "$BRANCH" && "$BRANCH" != "HEAD" ]] && command -v gh &>/dev/null; then
  PR_JSON=$(gh pr list --head "$BRANCH" --state open --json number --limit 1 2>/dev/null || echo "[]")
  PR_COUNT=$(echo "$PR_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$PR_COUNT" != "0" ]]; then
    HAS_PR=true
  fi
fi

# Run verification phases
# Build, typecheck, and lint already passed at commit time.
FAILED_PHASE=""
FAILURE_OUTPUT=""

if [[ "$HAS_PR" == true ]]; then
  # PR exists — run PR-tier verification (expanded security + tests)
  # This ensures tests run on every push to a PR branch, not just at PR creation.

  # Phase 1: Expanded security
  security_output=$("$SCRIPT_DIR/security-check.sh" "pre-pr" "$PROJECT_DIR" "$DIFF_BASE" 2>&1)
  if [[ $? -ne 0 ]]; then
    FAILED_PHASE="security"
    FAILURE_OUTPUT="$security_output"
  fi

  # Phase 2: Tests (only if security passed)
  if [[ -z "$FAILED_PHASE" ]]; then
    DETECTION=$("$SCRIPT_DIR/detect-project.sh" "$PROJECT_DIR" 2>/dev/null || echo '{"project_type":"unknown"}')
    CMD_TEST=$(echo "$DETECTION" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commands',{}).get('test') or '')" 2>/dev/null || echo "")
    if [[ -n "$CMD_TEST" ]]; then
      test_output=$("$SCRIPT_DIR/verify-phase.sh" "test" "$CMD_TEST" "$PROJECT_DIR" 2>&1)
      if [[ $? -ne 0 ]]; then
        FAILED_PHASE="test"
        FAILURE_OUTPUT="$test_output"
      fi
    fi
  fi

  VERIFY_TIER="security+tests"
else
  # No PR (or gh unavailable) — standard security only
  security_output=$("$SCRIPT_DIR/security-check.sh" "standard" "$PROJECT_DIR" "$DIFF_BASE" 2>&1)
  if [[ $? -ne 0 ]]; then
    FAILED_PHASE="security"
    FAILURE_OUTPUT="$security_output"
  fi

  VERIFY_TIER="standard security"
fi

# CodeRabbit CLI review (advisory — does not block push)
# Runs after blocking checks pass. Findings are surfaced in additionalContext
# so Claude can address issues before creating a PR (PRD #5, Decision 3).
CODERABBIT_FINDINGS=""
if [[ -z "$FAILED_PHASE" ]] && [[ ! -f "$PROJECT_DIR/.skip-coderabbit" ]]; then
  # Compute base branch for CLI review (always compare against default branch,
  # not the upstream tracking ref — we want the full feature branch diff)
  REVIEW_BASE=""
  if git -C "$PROJECT_DIR" rev-parse --verify origin/main &>/dev/null; then
    REVIEW_BASE="origin/main"
  elif git -C "$PROJECT_DIR" rev-parse --verify origin/master &>/dev/null; then
    REVIEW_BASE="origin/master"
  fi

  if [[ -n "$REVIEW_BASE" ]]; then
    REVIEW_RAW=$("$SCRIPT_DIR/coderabbit-review.sh" "$PROJECT_DIR" "$REVIEW_BASE" 2>&1 || true)
    # Only treat output as findings when it contains actual review issue blocks.
    # The review script emits banners/status lines on clean runs that shouldn't
    # be surfaced as findings in additionalContext.
    if echo "$REVIEW_RAW" | grep -qE '^File:|^Type:[[:space:]]*potential_issue|^Comment:'; then
      CODERABBIT_FINDINGS="$REVIEW_RAW"
    fi
  fi
fi

# Return decision
if [[ -n "$FAILED_PHASE" ]]; then
  # Verification failed — deny the push
  VERIFY_FAILED_PHASE="$FAILED_PHASE" VERIFY_FAILURE_OUTPUT="$FAILURE_OUTPUT" VERIFY_TIER="$VERIFY_TIER" python3 -c "
import json, os

phase = os.environ['VERIFY_FAILED_PHASE']
output = os.environ['VERIFY_FAILURE_OUTPUT']
tier = os.environ['VERIFY_TIER']

# Sanitize output: remove invalid Unicode surrogates that break JSON serialization
output = output.encode('utf-8', errors='replace').decode('utf-8')

# Truncate to prevent oversized API payloads
MAX_OUTPUT = 4000
if len(output) > MAX_OUTPUT:
    output = output[:MAX_OUTPUT] + '\n\n... (output truncated)'

reason = f'Push blocked — {tier} check failed at phase: {phase}. Fix the underlying code to resolve the error. NEVER add suppression annotations (@ts-ignore, type:ignore, lint-disable) to bypass the check — fix the actual problem. The ONE exception: eslint-disable-line no-console is allowed for intentional CLI output (the security check already accepts it).\n\n{output}'
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
else
  # All checks passed — use additionalContext only (Claude-visible, not shown in UI).
  # permissionDecisionReason is omitted on allow to prevent confusing "Error: ... passed"
  # messages when another hook denies the same action (Decision 3, PRD 11).
  if [[ -n "$CODERABBIT_FINDINGS" ]]; then
    # Use python3 for proper JSON encoding of multiline review output
    VERIFY_TIER="$VERIFY_TIER" CODERABBIT_FINDINGS="$CODERABBIT_FINDINGS" python3 -c "
import json, os

tier = os.environ['VERIFY_TIER']
findings = os.environ['CODERABBIT_FINDINGS']

# Sanitize output: remove invalid Unicode surrogates that break JSON serialization
findings = findings.encode('utf-8', errors='replace').decode('utf-8')

# Truncate to prevent oversized API payloads
MAX = 4000
if len(findings) > MAX:
    findings = findings[:MAX] + '\n\n... (output truncated)'

context = f'verify: push check passed ({tier}) ✓\n\nCodeRabbit CLI review findings (advisory — address before creating PR):\n{findings}'
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'allow',
        'additionalContext': context
    }
}
print(json.dumps(result))
"
  else
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"additionalContext\":\"verify: push check passed ($VERIFY_TIER) ✓\"}}"
  fi
fi
