#!/usr/bin/env bats
# ABOUTME: Tests for compute-diff-key.sh — the shared key both the dispatch step and the push gate use.
# ABOUTME: Builds real git fixtures with a bare remote rather than mocking git.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/compute-diff-key.sh"

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
}

teardown() {
    rm -rf "$TMPDIR"
}

# Add a commit on a feature branch so there is something outgoing.
add_outgoing_commit() {
    local content="$1"
    echo "$content" >> "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit --quiet -m "$content"
}

@test "prints a 64-character hex key for an outgoing diff" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    run "$SCRIPT" -C "$REPO"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "key is stable across invocations when nothing changed" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    first=$("$SCRIPT" -C "$REPO")
    second=$("$SCRIPT" -C "$REPO")
    [ "$first" = "$second" ]
}

@test "key changes when a commit is added" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    before=$("$SCRIPT" -C "$REPO")
    add_outgoing_commit beta
    after=$("$SCRIPT" -C "$REPO")
    [ "$before" != "$after" ]
}

@test "key changes when the last commit is amended to different content" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    before=$("$SCRIPT" -C "$REPO")
    echo extra >> "$REPO/file.txt"
    git -C "$REPO" add file.txt
    git -C "$REPO" commit --quiet --amend -m alpha
    after=$("$SCRIPT" -C "$REPO")
    [ "$before" != "$after" ]
}

@test "uses origin/main when the branch has no upstream set" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    run "$SCRIPT" -C "$REPO"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9a-f]{64}$ ]]
}

@test "prefers the configured upstream over origin/main" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    git -C "$REPO" push --quiet -u origin feature
    with_upstream=$("$SCRIPT" -C "$REPO")
    # With feature pushed, nothing is outgoing, so the diff is empty.
    empty=$(printf '' | shasum -a 256 | awk '{print $1}')
    [ "$with_upstream" = "$empty" ]
}

@test "fails loudly when neither an upstream nor origin/main exists" {
    git -C "$REPO" remote remove origin
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    run "$SCRIPT" -C "$REPO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no base"* ]]
}

@test "fails when the target directory is not a git repository" {
    run "$SCRIPT" -C "$TMPDIR"
    [ "$status" -ne 0 ]
}

@test "--print-base prints the resolved base instead of the key" {
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    run "$SCRIPT" -C "$REPO" --print-base
    [ "$status" -eq 0 ]
    expected=$(git -C "$REPO" rev-parse refs/remotes/origin/main)
    [ "$output" = "$expected" ]
}

@test "--print-base fails the same way when there is no base" {
    git -C "$REPO" remote remove origin
    git -C "$REPO" checkout --quiet -b feature
    add_outgoing_commit alpha
    run "$SCRIPT" -C "$REPO" --print-base
    [ "$status" -ne 0 ]
    [[ "$output" == *"no base"* ]]
}
