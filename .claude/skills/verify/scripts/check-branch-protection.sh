#!/usr/bin/env bash
# check-branch-protection.sh — PreToolUse hook that blocks commits to main/master
#
# Installed as a Claude Code PreToolUse hook on Bash.
# Detects git commit commands and blocks them if the current branch is main or
# master. Repos can opt out by placing a `.skip-branching` file at the project root.
#
# Docs-only exemption: commits that only add or modify *.md files are allowed
# directly on main/master. Deletions, renames, and non-.md files still require
# a feature branch.
#
# Decision 16: Per-repo rule overrides via dotfiles.
# Global CLAUDE.md rule: "Always work on feature branches. Never commit directly to main."
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

# Only act on git commit commands
# Must handle: git commit, git -C <path> commit, && git commit, etc.
if ! echo "$COMMAND" | grep -qE '(^|\s|&&\s*|;\s*)git\s+(-[a-zA-Z]\s+\S+\s+)*commit\b'; then
  exit 0  # Not a commit command, silent passthrough
fi

# Determine project directory from hook input
# If git -C <path> is used, that path overrides cwd
PROJECT_DIR=$(echo "$COMMAND" | grep -oE '\-C\s+\S+' | head -1 | sed 's/^-C[[:space:]]*//' || true)
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd','.'))" 2>/dev/null || echo ".")
fi

# Check for .skip-branching opt-out
if [ -f "$PROJECT_DIR/.skip-branching" ]; then
  exit 0  # Repo opted out of branch protection
fi

# Get current branch name
BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")

# If we can't determine the branch (detached HEAD, not a git repo), allow
if [ -z "$BRANCH" ]; then
  exit 0
fi

# Block commits to main or master — unless all staged files are docs-only
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  # Check if this is a docs-only commit (all staged files are *.md, no deletions/renames)
  STAGED=$(git -C "$PROJECT_DIR" diff --cached --name-status 2>/dev/null || echo "")
  if [ -n "$STAGED" ]; then
    DOCS_ONLY=true
    while IFS=$'\t' read -r status filepath _rest; do
      # Only allow Added (A) or Modified (M) statuses
      case "$status" in
        A|M) ;;
        *) DOCS_ONLY=false; break ;;
      esac
      # Block any non-.md file
      if [[ "$filepath" != *.md ]]; then
        DOCS_ONLY=false
        break
      fi
    done <<< "$STAGED"
    if [ "$DOCS_ONLY" = true ]; then
      exit 0  # Docs-only commit on protected branch — allow
    fi
  fi

  python3 -c "
import json
reason = (
    'Commit blocked — committing directly to the '
    '\"$BRANCH\" branch is not allowed. '
    'Create a feature branch first: git checkout -b feature/<name>. '
    'To opt out of this check for this repo, create a .skip-branching file at the project root.'
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

# Not on a protected branch — silent passthrough
exit 0
