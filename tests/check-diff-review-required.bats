#!/usr/bin/env bats
# ABOUTME: Tests for check-diff-review-required.sh — the PreToolUse gate blocking git push without a review verdict.
# ABOUTME: Builds real git fixtures with a bare remote; the staleness cases are the reason this suite exists.

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/check-diff-review-required.sh"
KEYGEN="$BATS_TEST_DIRNAME/../scripts/compute-diff-key.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    REPO="$TMPDIR/repo"
    REMOTE="$TMPDIR/remote.git"
    git init --quiet --bare "$REMOTE"
    git init --quiet -b main "$REPO"
    git -C "$REPO" config user.email t@example.com
    git -C "$REPO" config user.name Tester
    git -C "$REPO" config commit.gpgsign false
    echo base > "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit --quiet -m base
    git -C "$REPO" remote add origin "$REMOTE"
    git -C "$REPO" push --quiet -u origin main
    git -C "$REPO" checkout --quiet -b feature
    chmod +x "$SCRIPT" 2>/dev/null || true
}

teardown() {
    rm -rf "$TMPDIR"
}

add_commit() {
    echo "$1" >> "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit --quiet -m "$1"
}

# Record a verdict for the repo's current outgoing diff.
record_current_verdict() {
    local key
    key=$("$KEYGEN" -C "$REPO")
    mkdir -p "$REPO/.claude/diff-review"
    echo '{"findings":0}' > "$REPO/.claude/diff-review/$key.json"
}

run_hook() {
    local command="$1" cwd="${2:-$REPO}"
    python3 -c "
import json, sys
print(json.dumps({'tool_input': {'command': sys.argv[1]}, 'cwd': sys.argv[2]}))
" "$command" "$cwd" > "$TMPDIR/input.json"
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
}

# ── Passthrough cases ─────────────────────────────────────────────────────────

@test "passes through silently for a command that is not a push" {
    add_commit alpha
    run_hook "git status"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "passes through silently when git push appears only inside a quoted string" {
    add_commit alpha
    run_hook "git commit -m \"remember to git push later\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "passes through silently when the working directory is not a git repository" {
    run_hook "git push" "$TMPDIR"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "passes through silently when nothing is outgoing" {
    git -C "$REPO" push --quiet -u origin feature
    run_hook "git push"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Allow case ────────────────────────────────────────────────────────────────

@test "allows the push when a verdict exists for the outgoing diff" {
    add_commit alpha
    record_current_verdict
    run_hook "git push"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Deny cases ────────────────────────────────────────────────────────────────

@test "blocks the push when no verdict exists" {
    add_commit alpha
    run_hook "git push"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
    [[ "$output" == *"no diff review verdict"* ]]
}

@test "blocks the push when the only verdict is stale" {
    add_commit alpha
    record_current_verdict
    add_commit beta
    run_hook "git push"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
    [[ "$output" == *"no diff review verdict"* ]]
}

@test "blocks a push chained after a cd, resolving the repo from the cd path" {
    add_commit alpha
    run_hook "cd $REPO && git push" "$TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "blocks push -u origin with an explicit branch" {
    add_commit alpha
    run_hook "git push -u origin feature"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "distinguishes an unidentifiable diff from a missing verdict" {
    git -C "$REPO" remote remove origin
    add_commit alpha
    run_hook "git push"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
    [[ "$output" == *"could not be identified"* ]]
    [[ "$output" != *"no diff review verdict"* ]]
}

@test "passes through when git push appears only inside a heredoc body" {
    add_commit alpha
    run_hook "$(printf 'git commit -F - <<%sEOF%s\nthe hook denies git push until a verdict exists\nEOF' "'" "'")"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "still blocks a real push chained after a heredoc command" {
    add_commit alpha
    run_hook "$(printf 'git commit -F - <<%sEOF%s\nmentions git push in the body\nEOF\ngit push' "'" "'")"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "blocks git -C <repo> push, which carries a global option before the subcommand" {
    add_commit alpha
    run_hook "git -C $REPO push" "$TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "blocks git --no-pager push" {
    add_commit alpha
    run_hook "git --no-pager push"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "does not treat 'git pushd' or similar as a push" {
    add_commit alpha
    run_hook "git pushed-branch-report"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "passes through when git push appears inside a multi-line quoted string" {
    add_commit alpha
    run_hook "$(printf 'git commit -m "first line of the message\nexplains that git push is blocked\nthird line"')"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "still blocks a real push after a multi-line quoted message" {
    add_commit alpha
    run_hook "$(printf 'git commit -m "mentions git push\nacross lines" && git push')"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "blocks git -C with a quoted repository path" {
    add_commit alpha
    run_hook "git -C \"$REPO\" push" "$TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}

@test "blocks git -C with a quoted path containing spaces" {
    add_commit alpha
    spaced="$TMPDIR/repo with spaces"
    cp -R "$REPO" "$spaced"
    run_hook "git -C \"$spaced\" push" "$TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision": "deny"'* ]]
}
