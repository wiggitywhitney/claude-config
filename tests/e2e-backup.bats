#!/usr/bin/env bats
# ABOUTME: End-to-end test for scripts/backup-private-files.sh — full multi-repo backup scenario
# ABOUTME: Tests all backup paths together: journal/, design-decisions.md, and .private-sync additions.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/backup-private-files.sh"

setup() {
    TMPDIR="$(mktemp -d)"

    export REPOS_DIR="$TMPDIR/repos"
    mkdir -p "$REPOS_DIR"

    export CLAUDE_PERSONAL_DIR="$TMPDIR/claude-personal"
    mkdir -p "$CLAUDE_PERSONAL_DIR"
    git -C "$CLAUDE_PERSONAL_DIR" init --quiet
    git -C "$CLAUDE_PERSONAL_DIR" config user.email "test@example.com"
    git -C "$CLAUDE_PERSONAL_DIR" config user.name "Test"
    git -C "$CLAUDE_PERSONAL_DIR" config commit.gpgsign false

    # ── Repo setup ────────────────────────────────────────────────────────────

    # repo-one: has journal/, design-decisions.md, AND a .private-sync extra path
    mkdir -p "$REPOS_DIR/repo-one"
    git init "$REPOS_DIR/repo-one" --quiet
    mkdir -p "$REPOS_DIR/repo-one/journal/entries"
    echo "day one" > "$REPOS_DIR/repo-one/journal/entries/2026-04-13.md"
    mkdir -p "$REPOS_DIR/repo-one/.claude"
    echo "# Decisions" > "$REPOS_DIR/repo-one/.claude/design-decisions.md"
    echo "docs/private-notes.md" > "$REPOS_DIR/repo-one/.private-sync"
    mkdir -p "$REPOS_DIR/repo-one/docs"
    echo "private content" > "$REPOS_DIR/repo-one/docs/private-notes.md"

    # repo-two: has journal/ only (no design-decisions.md, no .private-sync)
    mkdir -p "$REPOS_DIR/repo-two"
    git init "$REPOS_DIR/repo-two" --quiet
    mkdir -p "$REPOS_DIR/repo-two/journal/entries"
    echo "day two" > "$REPOS_DIR/repo-two/journal/entries/2026-04-12.md"

    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Helper ────────────────────────────────────────────────────────────────────

_commit_count() {
    git -C "$CLAUDE_PERSONAL_DIR" rev-list --count HEAD 2>/dev/null || echo "0"
}

# ── Full multi-repo backup ────────────────────────────────────────────────────

@test "full backup: journal/ backed up from repo-one" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/repo-one/journal/entries/2026-04-13.md" ]
    [ "$(cat "$CLAUDE_PERSONAL_DIR/private-files/repo-one/journal/entries/2026-04-13.md")" = "day one" ]
}

@test "full backup: design-decisions.md backed up from repo-one" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/repo-one/.claude/design-decisions.md" ]
    [[ "$output" == *"[OK] backed up repo-one/.claude/design-decisions.md"* ]]
}

@test "full backup: .private-sync extra path backed up from repo-one" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/repo-one/docs/private-notes.md" ]
    [ "$(cat "$CLAUDE_PERSONAL_DIR/private-files/repo-one/docs/private-notes.md")" = "private content" ]
    [[ "$output" == *"[OK] backed up repo-one/docs/private-notes.md"* ]]
}

@test "full backup: journal/ backed up from repo-two" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/repo-two/journal/entries/2026-04-12.md" ]
    [ "$(cat "$CLAUDE_PERSONAL_DIR/private-files/repo-two/journal/entries/2026-04-12.md")" = "day two" ]
}

@test "full backup: design-decisions.md skipped for repo-two (does not exist)" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "$CLAUDE_PERSONAL_DIR/private-files/repo-two/.claude/design-decisions.md" ]
    [[ "$output" == *"[SKIPPED] repo-two/.claude/design-decisions.md"* ]]
}

@test "full backup: commits all changes to claude-personal in one run" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(_commit_count)" -gt 0 ]
}

@test "full backup: exit code 0 with mixed results" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "full backup dry-run: no files copied, no commit" {
    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [ ! -d "$CLAUDE_PERSONAL_DIR/private-files" ]
    [ "$(_commit_count)" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would back up repo-one/journal"* ]]
    [[ "$output" == *"[DRY RUN] Would back up repo-two/journal"* ]]
}
