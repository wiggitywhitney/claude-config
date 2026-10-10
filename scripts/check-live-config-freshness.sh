#!/usr/bin/env bash
# ABOUTME: SessionStart hook that keeps the claude-config-live worktree current with origin/main
# ABOUTME: Fails loudly via additionalContext on a dirty worktree or a failed fetch/merge, never silently

set -uo pipefail

# Read and discard stdin (SessionStart passes JSON payload, we don't need it)
cat > /dev/null

LIVE_WORKTREE="${CLAUDE_CONFIG_LIVE_WORKTREE:-$HOME/Documents/Repositories/claude-config-live}"

emit_warning() {
    local message="$1"
    local json_message
    json_message=$(printf '%s' "$message" | python3 -c "
import sys, json
print(json.dumps(sys.stdin.read().rstrip()))
" 2>/dev/null)

    # An empty json_message would emit invalid JSON, which a hook runner skips
    # silently — exactly the invisible-failure shape this script exists to avoid.
    if [[ -z "$json_message" ]]; then
        echo "check-live-config-freshness: failed to encode the warning message" >&2
        exit 0
    fi

    printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' "$json_message"
    exit 0
}

if [[ ! -e "$LIVE_WORKTREE/.git" ]]; then
    emit_warning "claude-config-live worktree not found at ${LIVE_WORKTREE} — ~/.claude/rules and ~/.claude/CLAUDE.md may be reading stale or broken symlinks. Recreate the worktree or update CLAUDE_CONFIG_LIVE_WORKTREE."
fi

# No separate "is it dirty" pre-check: a worktree running the journal commit
# hook routinely picks up untracked scratch files that have nothing to do with
# rules/ or global/'s freshness, and a blanket git-status check would warn on
# that noise constantly. Let git's own fetch/merge be the authority on whether
# anything actually blocks the update, and surface its real error if so.
FETCH_OUTPUT=$(git -C "$LIVE_WORKTREE" fetch origin main 2>&1)
FETCH_EXIT=$?

if (( FETCH_EXIT != 0 )); then
    emit_warning "claude-config-live worktree at ${LIVE_WORKTREE} failed to fetch origin/main — ~/.claude/rules and ~/.claude/CLAUDE.md may be stale. git said: $(printf '%s' "$FETCH_OUTPUT" | head -1)"
fi

MERGE_OUTPUT=$(git -C "$LIVE_WORKTREE" merge --ff-only origin/main 2>&1)
MERGE_EXIT=$?

if (( MERGE_EXIT != 0 )); then
    emit_warning "claude-config-live worktree at ${LIVE_WORKTREE} could not fast-forward to origin/main — ~/.claude/rules and ~/.claude/CLAUDE.md may be stale. This usually means either the worktree has local commits of its own (which it should never have) or an uncommitted/untracked file conflicts with an incoming change. git said: $(printf '%s' "$MERGE_OUTPUT" | head -1)"
fi

# Up to date and nothing went wrong — silent exit, matching check-running-clusters.sh's convention.
exit 0
