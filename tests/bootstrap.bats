#!/usr/bin/env bats
# ABOUTME: Tests for scripts/bootstrap.sh — idempotent Claude environment bootstrap

SCRIPT="$BATS_TEST_DIRNAME/../scripts/bootstrap.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    export CLAUDE_DIR="$TMPDIR/dot-claude"
    mkdir -p "$CLAUDE_DIR"

    export CLAUDE_PERSONAL_DIR="$TMPDIR/claude-personal"
    mkdir -p "$CLAUDE_PERSONAL_DIR"
    git init "$CLAUDE_PERSONAL_DIR" --quiet

    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Prerequisite checks ───────────────────────────────────────────────────────

@test "fails when CLAUDE_DIR does not exist" {
    export CLAUDE_DIR="$TMPDIR/nonexistent"
    run "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "fails when claude-personal dir does not exist" {
    run "$SCRIPT" --claude-personal-dir "$TMPDIR/nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "fails when --claude-personal-dir has no argument" {
    run "$SCRIPT" --claude-personal-dir
    [ "$status" -eq 1 ]
    [[ "$output" == *"requires a path argument"* ]]
}

@test "fails when claude-personal dir is not a git repo" {
    mkdir -p "$TMPDIR/not-a-repo"
    run "$SCRIPT" --claude-personal-dir "$TMPDIR/not-a-repo"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a git repository"* ]]
}

# ── Dry-run ───────────────────────────────────────────────────────────────────

@test "dry-run produces no filesystem changes" {
    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN]"* ]]
    [ ! -e "$CLAUDE_DIR/settings.json" ]
}

@test "dry-run with existing wrong-target symlink makes no changes" {
    ln -s "/tmp/some-other-target" "$CLAUDE_DIR/settings.json"
    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN]"* ]]
    [ "$(readlink "$CLAUDE_DIR/settings.json")" = "/tmp/some-other-target" ]
    [ ! -e "$CLAUDE_DIR/settings.json.pre-bootstrap-backup" ]
}

@test "dry-run with existing regular file makes no changes" {
    echo "old settings" > "$CLAUDE_DIR/settings.json"
    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN]"* ]]
    [ -f "$CLAUDE_DIR/settings.json" ]
    [ ! -L "$CLAUDE_DIR/settings.json" ]
    [ ! -e "$CLAUDE_DIR/settings.json.pre-bootstrap-backup" ]
}

# ── settings.json symlink ─────────────────────────────────────────────────────

@test "creates symlink on fresh setup" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_DIR/settings.json" ]
    [[ "$output" == *"[OK]"* ]]
}

@test "symlink points to config/settings.json in repo root" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    expected_target="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/config/settings.json"
    [ "$(readlink "$CLAUDE_DIR/settings.json")" = "$expected_target" ]
}

@test "idempotent re-run prints SKIPPED" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] settings.json symlink already correct"* ]]
}

@test "backs up regular file and creates symlink" {
    echo "old settings content" > "$CLAUDE_DIR/settings.json"
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_DIR/settings.json" ]
    [ -f "$CLAUDE_DIR/settings.json.pre-bootstrap-backup" ]
    [[ "$output" == *"[BACKED UP]"* ]]
    [[ "$output" == *"[OK]"* ]]
}

@test "backup preserves original file contents" {
    echo "old settings content" > "$CLAUDE_DIR/settings.json"
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$CLAUDE_DIR/settings.json.pre-bootstrap-backup")" = "old settings content" ]
}

@test "replaces wrong-target symlink and backs it up" {
    ln -s "/tmp/some-other-target" "$CLAUDE_DIR/settings.json"
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_DIR/settings.json" ]
    [ -L "$CLAUDE_DIR/settings.json.pre-bootstrap-backup" ]
    [ "$(readlink "$CLAUDE_DIR/settings.json.pre-bootstrap-backup")" = "/tmp/some-other-target" ]
    [[ "$output" == *"[BACKED UP]"* ]]
}

@test "wrong-target symlink replaced with correct target" {
    ln -s "/tmp/some-other-target" "$CLAUDE_DIR/settings.json"
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    expected_target="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/config/settings.json"
    [ "$(readlink "$CLAUDE_DIR/settings.json")" = "$expected_target" ]
}
