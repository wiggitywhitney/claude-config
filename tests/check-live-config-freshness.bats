#!/usr/bin/env bats
# ABOUTME: Tests for scripts/check-live-config-freshness.sh — the SessionStart hook
# ABOUTME: that keeps the claude-config-live worktree fast-forwarded to origin/main

SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-live-config-freshness.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    export ORIGIN="$TMPDIR/origin.git"
    export WORKTREE="$TMPDIR/worktree"

    git init --bare --initial-branch=main --quiet "$ORIGIN"

    git clone --quiet "$ORIGIN" "$TMPDIR/seed"
    git -C "$TMPDIR/seed" config user.email "test@test.com"
    git -C "$TMPDIR/seed" config user.name "Test"
    echo "v1" > "$TMPDIR/seed/file.txt"
    git -C "$TMPDIR/seed" add file.txt
    git -C "$TMPDIR/seed" commit -m "initial" --quiet
    git -C "$TMPDIR/seed" push --quiet origin main

    git clone --quiet "$ORIGIN" "$WORKTREE"
    git -C "$WORKTREE" config user.email "test@test.com"
    git -C "$WORKTREE" config user.name "Test"
}

teardown() {
    rm -rf "$TMPDIR"
}

run_hook() {
    CLAUDE_CONFIG_LIVE_WORKTREE="$WORKTREE" run bash -c "echo '{\"session_id\":\"test\",\"hook_event_name\":\"SessionStart\"}' | '$SCRIPT'"
}

@test "warns when the worktree directory does not exist" {
    CLAUDE_CONFIG_LIVE_WORKTREE="$TMPDIR/does-not-exist" run bash -c "echo '{\"session_id\":\"test\"}' | '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"worktree not found"* ]]
}

@test "exits silently when already up to date with origin/main" {
    run_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "fast-forwards silently when origin has new commits and the worktree is clean" {
    echo "v2" > "$TMPDIR/seed/file.txt"
    git -C "$TMPDIR/seed" commit -am "second commit" --quiet
    git -C "$TMPDIR/seed" push --quiet origin main

    run_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    [ "$(cat "$WORKTREE/file.txt")" = "v2" ]
}

@test "warns with a real git error when an untracked file conflicts with an incoming change" {
    echo "v2" > "$TMPDIR/seed/newfile.txt"
    git -C "$TMPDIR/seed" add newfile.txt
    git -C "$TMPDIR/seed" commit -m "adds newfile" --quiet
    git -C "$TMPDIR/seed" push --quiet origin main

    echo "conflicting local content" > "$WORKTREE/newfile.txt"

    run_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not fast-forward"* ]]
    [[ "$output" == *"overwritten"* ]]
}

@test "warns with a real git error when the worktree has a local commit of its own" {
    echo "local change" > "$WORKTREE/file.txt"
    git -C "$WORKTREE" commit -am "a local commit this worktree should never have" --quiet

    echo "v2" > "$TMPDIR/seed/file.txt"
    git -C "$TMPDIR/seed" commit -am "second commit" --quiet
    git -C "$TMPDIR/seed" push --quiet origin main

    run_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not fast-forward"* ]]
}

@test "warns with a real git error when the fetch itself fails" {
    git -C "$WORKTREE" remote set-url origin "$TMPDIR/origin-does-not-exist.git"

    run_hook
    [ "$status" -eq 0 ]
    [[ "$output" == *"failed to fetch origin/main"* ]]
}

@test "output is valid JSON with the SessionStart envelope when a warning fires" {
    CLAUDE_CONFIG_LIVE_WORKTREE="$TMPDIR/does-not-exist" run bash -c "echo '{\"session_id\":\"test\"}' | '$SCRIPT'"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import sys, json
obj = json.load(sys.stdin)
assert obj['hookSpecificOutput']['hookEventName'] == 'SessionStart'
assert 'claude-config-live' in obj['hookSpecificOutput']['additionalContext']
"
}
