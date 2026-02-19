#!/usr/bin/env bash
# check-coderabbit-required.sh — PreToolUse hook that blocks PR merge without CodeRabbit review
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects gh pr merge commands and blocks them unless a `.skip-coderabbit` file
# exists at the project root. When CodeRabbit is required, the hook checks if
# a CodeRabbit review exists on the PR before allowing the merge.
#
# Decision 16: Per-repo rule overrides via dotfiles.
# Global CLAUDE.md rule: "PRs require CodeRabbit review examined and approved
# by human before merge."
# This hook adds deterministic enforcement of that rule.
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision (deny only; silent passthrough on allow)
#
# Exit codes:
#   0 — Decision returned via JSON, or silent passthrough (allow)
#   1 — Unexpected error

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the bash command from the hook input
COMMAND=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on gh pr merge commands
# Must handle: gh pr merge, && gh pr merge, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)gh\s+pr\s+merge\b'; then
  exit 0  # Not a PR merge command, silent passthrough
fi

# Determine project directory from hook input (gh doesn't use -C, rely on cwd)
PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")

# Check for .skip-coderabbit opt-out
if [ -f "$PROJECT_DIR/.skip-coderabbit" ]; then
  exit 0  # Repo opted out of CodeRabbit requirement
fi

# CodeRabbit is required — extract PR number and check for review
# Extract PR number from command (gh pr merge 123, gh pr merge <url>, or no number = current branch PR)
PR_NUMBER=$(echo "$COMMAND" | grep -oE 'gh\s+pr\s+merge\s+([0-9]+)' | grep -oE '[0-9]+' | head -1 || true)

# If no PR number in command, try to get it from current branch
if [ -z "$PR_NUMBER" ]; then
  PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")
fi

# If we still can't determine the PR, block with advisory
if [ -z "$PR_NUMBER" ]; then
  python3 -c "
import json
reason = (
    'PR merge blocked — CodeRabbit review is required before merging. '
    'Could not determine PR number to verify review status. '
    'Ensure a CodeRabbit review has been completed and approved. '
    'To opt out of this check for this repo, create a .skip-coderabbit file at the project root.'
)
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
  exit 0
fi

# Check if CodeRabbit has reviewed this PR
# Look for reviews from coderabbitai[bot] user
REPO_INFO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "$REPO_INFO" ]; then
  # Can't determine repo — block with advisory
  python3 -c "
import json
reason = (
    'PR merge blocked — CodeRabbit review is required before merging. '
    'Could not determine repository to verify review status. '
    'To opt out of this check for this repo, create a .skip-coderabbit file at the project root.'
)
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
  exit 0
fi

# Check for CodeRabbit review via GitHub API
CODERABBIT_REVIEW=$(gh api "repos/$REPO_INFO/pulls/$PR_NUMBER/reviews" --jq '[.[] | select(.user.login == "coderabbitai[bot]")] | length' 2>/dev/null || echo "0")

if [ "$CODERABBIT_REVIEW" -gt 0 ] 2>/dev/null; then
  # CodeRabbit has reviewed — allow merge
  exit 0
fi

# No CodeRabbit review found — block
PR_MERGE_PR="$PR_NUMBER" python3 -c "
import json, os

pr = os.environ['PR_MERGE_PR']
reason = (
    f'PR merge blocked — CodeRabbit review is required before merging PR #{pr}. '
    f'No CodeRabbit review found on this PR. Wait for CodeRabbit to complete its review, '
    f'then address all comments before merging. '
    f'To opt out of this check for this repo, create a .skip-coderabbit file at the project root.'
)
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
exit 0
