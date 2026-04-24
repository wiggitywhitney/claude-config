#!/usr/bin/env bats
# ABOUTME: Tests for hooks/git/checks/progress-md-pr.sh — PROGRESS.md pre-push enforcement
# ABOUTME: Covers pass cases and the non-interactive warning path

SCRIPT="$BATS_TEST_DIRNAME/../hooks/git/checks/progress-md-pr.sh"

setup() {
    TMPDIR="$(mktemp -d)"

    # Bare repo acts as origin
    ORIGIN_REPO="$TMPDIR/origin.git"
    git init --bare "$ORIGIN_REPO" --quiet

    # Test repo with origin pointing at the bare repo
    TEST_REPO="$TMPDIR/testrepo"
    git init "$TEST_REPO" --quiet
    git -C "$TEST_REPO" config user.email "test@test.com"
    git -C "$TEST_REPO" config user.name "Test"
    git -C "$TEST_REPO" symbolic-ref HEAD refs/heads/main
    git -C "$TEST_REPO" remote add origin "$ORIGIN_REPO"

    # Initial commit on main, pushed to origin
    touch "$TEST_REPO/.gitkeep"
    git -C "$TEST_REPO" add .gitkeep
    git -C "$TEST_REPO" commit -m "initial commit" --quiet
    git -C "$TEST_REPO" push origin main --quiet

    export TMPDIR ORIGIN_REPO TEST_REPO SCRIPT
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Pass cases ────────────────────────────────────────────────────────────────

@test "progress-md-pr: passes when repo has no PROGRESS.md" {
    run bash -c 'cd "$TEST_REPO" && "$SCRIPT" origin "$ORIGIN_REPO"'
    [ "$status" -eq 0 ]
}

@test "progress-md-pr: passes when base ref cannot be determined" {
    echo "- (2026-01-01) Entry" > "$TEST_REPO/PROGRESS.md"
    git -C "$TEST_REPO" add PROGRESS.md
    git -C "$TEST_REPO" commit -m "add PROGRESS.md" --quiet

    # Pass an unknown remote name so tracking ref lookup fails
    run bash -c 'cd "$TEST_REPO" && "$SCRIPT" nonexistent "$ORIGIN_REPO"'
    [ "$status" -eq 0 ]
}

@test "progress-md-pr: passes when PROGRESS.md has changes on branch vs base" {
    # Push PROGRESS.md to origin/main
    echo "- (2026-01-01) Initial entry" > "$TEST_REPO/PROGRESS.md"
    git -C "$TEST_REPO" add PROGRESS.md
    git -C "$TEST_REPO" commit -m "add PROGRESS.md" --quiet
    git -C "$TEST_REPO" push origin main --quiet

    # Feature branch adds a new entry
    git -C "$TEST_REPO" checkout -b feature/test-progress --quiet
    echo "- (2026-04-24) New entry" >> "$TEST_REPO/PROGRESS.md"
    git -C "$TEST_REPO" add PROGRESS.md
    git -C "$TEST_REPO" commit -m "update PROGRESS.md" --quiet

    run bash -c 'cd "$TEST_REPO" && "$SCRIPT" origin "$ORIGIN_REPO"'
    [ "$status" -eq 0 ]
}

@test "progress-md-pr: passes when branch has no commits vs base" {
    # Push PROGRESS.md to origin/main, stay on main — zero branch commits
    echo "- (2026-01-01) Entry" > "$TEST_REPO/PROGRESS.md"
    git -C "$TEST_REPO" add PROGRESS.md
    git -C "$TEST_REPO" commit -m "add PROGRESS.md" --quiet
    git -C "$TEST_REPO" push origin main --quiet

    run bash -c 'cd "$TEST_REPO" && "$SCRIPT" origin "$ORIGIN_REPO"'
    [ "$status" -eq 0 ]
}

# ── Non-interactive path ──────────────────────────────────────────────────────

@test "progress-md-pr: prints warning and exits 0 when no TTY and PROGRESS.md has no branch changes" {
    # Push PROGRESS.md to origin/main
    echo "- (2026-01-01) Initial entry" > "$TEST_REPO/PROGRESS.md"
    git -C "$TEST_REPO" add PROGRESS.md
    git -C "$TEST_REPO" commit -m "add PROGRESS.md" --quiet
    git -C "$TEST_REPO" push origin main --quiet

    # Feature branch with commits but no PROGRESS.md changes
    git -C "$TEST_REPO" checkout -b feature/no-progress --quiet
    echo "some code" > "$TEST_REPO/src.sh"
    git -C "$TEST_REPO" add src.sh
    git -C "$TEST_REPO" commit -m "add code without PROGRESS.md" --quiet

    # PROGRESS_MD_PR_NO_TTY=1 forces the non-interactive path
    run bash -c 'cd "$TEST_REPO" && PROGRESS_MD_PR_NO_TTY=1 "$SCRIPT" origin "$ORIGIN_REPO"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
}
