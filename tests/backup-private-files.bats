#!/usr/bin/env bats
# ABOUTME: Tests for scripts/backup-private-files.sh — per-repo private file backup to claude-personal

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

    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# Helper: create a fake git repo under REPOS_DIR
_make_repo() {
    local name="$1"
    mkdir -p "$REPOS_DIR/$name"
    git init "$REPOS_DIR/$name" --quiet
}

# Helper: count commits in claude-personal
_commit_count() {
    git -C "$CLAUDE_PERSONAL_DIR" rev-list --count HEAD 2>/dev/null || echo "0"
}

# ── Default path: journal/ ────────────────────────────────────────────────────

@test "backs up journal/ directory from repo" {
    _make_repo "my-project"
    mkdir -p "$REPOS_DIR/my-project/journal/entries"
    echo "entry content" > "$REPOS_DIR/my-project/journal/entries/2026-04-13.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] backed up my-project/journal"* ]]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/my-project/journal/entries/2026-04-13.md" ]
}

# ── Default path: .claude/design-decisions.md ────────────────────────────────

@test "backs up .claude/design-decisions.md from repo" {
    _make_repo "my-project"
    mkdir -p "$REPOS_DIR/my-project/.claude"
    echo "# Decisions" > "$REPOS_DIR/my-project/.claude/design-decisions.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] backed up my-project/.claude/design-decisions.md"* ]]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/my-project/.claude/design-decisions.md" ]
}

# ── .private-sync additions ───────────────────────────────────────────────────

@test "backs up additional path listed in .private-sync" {
    _make_repo "my-project"
    echo "docs/private-notes.md" > "$REPOS_DIR/my-project/.private-sync"
    mkdir -p "$REPOS_DIR/my-project/docs"
    echo "private notes" > "$REPOS_DIR/my-project/docs/private-notes.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] backed up my-project/docs/private-notes.md"* ]]
    [ -f "$CLAUDE_PERSONAL_DIR/private-files/my-project/docs/private-notes.md" ]
}

@test "skips path in .private-sync that does not exist in repo" {
    _make_repo "my-project"
    echo "nonexistent/file.md" > "$REPOS_DIR/my-project/.private-sync"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] my-project/nonexistent/file.md"* ]]
}

# ── Missing default paths ─────────────────────────────────────────────────────

@test "skips missing default paths without error" {
    _make_repo "my-project"
    # No journal/, no .claude/design-decisions.md

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] my-project/journal"* ]]
    [[ "$output" == *"[SKIPPED] my-project/.claude/design-decisions.md"* ]]
}

# ── Dry run ───────────────────────────────────────────────────────────────────

@test "dry-run shows would-back-up without copying files" {
    _make_repo "my-project"
    mkdir -p "$REPOS_DIR/my-project/journal"
    echo "entry" > "$REPOS_DIR/my-project/journal/2026-04-13.md"

    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would back up my-project/journal"* ]]
    [ ! -e "$CLAUDE_PERSONAL_DIR/private-files" ]
}

@test "dry-run makes no commit to claude-personal" {
    _make_repo "my-project"
    mkdir -p "$REPOS_DIR/my-project/journal"
    echo "entry" > "$REPOS_DIR/my-project/journal/2026-04-13.md"

    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [ "$(_commit_count)" -eq 0 ]
}

# ── No-op behavior ────────────────────────────────────────────────────────────

@test "no-op when nothing to back up makes no commit" {
    _make_repo "my-project"
    # Repo has no journal/ and no .claude/design-decisions.md

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"[OK]"* ]]
    [ "$(_commit_count)" -eq 0 ]
}

# ── Commit behavior ───────────────────────────────────────────────────────────

@test "commits to claude-personal after backing up files" {
    _make_repo "my-project"
    mkdir -p "$REPOS_DIR/my-project/journal"
    echo "entry" > "$REPOS_DIR/my-project/journal/2026-04-13.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(_commit_count)" -gt 0 ]
}

# ── Non-git directories ───────────────────────────────────────────────────────

@test "skips non-git directories in repos-dir" {
    mkdir -p "$REPOS_DIR/not-a-repo"
    echo "not git" > "$REPOS_DIR/not-a-repo/file.txt"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"not-a-repo"* ]]
}

# ── --repos-dir flag ─────────────────────────────────────────────────────────

@test "--repos-dir overrides default repos directory" {
    local custom_repos="$TMPDIR/custom-repos"
    mkdir -p "$custom_repos/my-project"
    git init "$custom_repos/my-project" --quiet
    mkdir -p "$custom_repos/my-project/journal"
    echo "entry" > "$custom_repos/my-project/journal/2026-04-13.md"

    run "$SCRIPT" --repos-dir "$custom_repos"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] backed up my-project/journal"* ]]
}
