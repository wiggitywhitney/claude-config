#!/usr/bin/env bats
# ABOUTME: Tests for record-diff-review.sh — writes the verdict the push gate looks for.
# ABOUTME: Includes an integration case proving a recorded verdict actually satisfies the gate.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/record-diff-review.sh"
KEYGEN="$BATS_TEST_DIRNAME/../scripts/compute-diff-key.sh"
GATE="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/check-diff-review-required.sh"

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
    echo alpha >> "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit --quiet -m alpha
    chmod +x "$SCRIPT" 2>/dev/null || true
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "writes a verdict file named for the computed key" {
    run "$SCRIPT" -C "$REPO" --findings 0
    [ "$status" -eq 0 ]
    key=$("$KEYGEN" -C "$REPO")
    [ -f "$REPO/.claude/diff-review/$key.json" ]
}

@test "the recorded verdict satisfies the push gate" {
    "$SCRIPT" -C "$REPO" --findings 0
    python3 -c "
import json, sys
print(json.dumps({'tool_input': {'command': 'git push'}, 'cwd': sys.argv[1]}))
" "$REPO" > "$TMPDIR/input.json"
    run bash -c "\"$GATE\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "records the findings count and reviewer in the verdict" {
    "$SCRIPT" -C "$REPO" --findings 3 --reviewer diff-reviewer
    key=$("$KEYGEN" -C "$REPO")
    run python3 -c "
import json
d = json.load(open('$REPO/.claude/diff-review/$key.json'))
print(d['findings'], d['reviewer'], d['key'] == '$key')
"
    [ "$status" -eq 0 ]
    [ "$output" = "3 diff-reviewer True" ]
}

@test "writes valid JSON containing a recorded_at timestamp" {
    "$SCRIPT" -C "$REPO" --findings 0
    key=$("$KEYGEN" -C "$REPO")
    run python3 -c "
import json
d = json.load(open('$REPO/.claude/diff-review/$key.json'))
assert d['recorded_at'], 'missing timestamp'
print('ok')
"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "an explicit --key overrides the computed key, for benchmark worktrees" {
    run "$SCRIPT" -C "$REPO" --key deadbeef --findings 1
    [ "$status" -eq 0 ]
    [ -f "$REPO/.claude/diff-review/deadbeef.json" ]
}

@test "refuses to record without a findings count" {
    run "$SCRIPT" -C "$REPO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--findings"* ]]
}

@test "refuses a non-numeric findings count" {
    run "$SCRIPT" -C "$REPO" --findings many
    [ "$status" -ne 0 ]
}

@test "fails outside a git repository when no key is given" {
    run "$SCRIPT" -C "$TMPDIR" --findings 0
    [ "$status" -ne 0 ]
}
