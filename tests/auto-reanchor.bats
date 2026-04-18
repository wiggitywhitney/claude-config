#!/usr/bin/env bats
# ABOUTME: Tests for auto-reanchor.sh PostCompact hook
# ABOUTME: Verifies orientation block output, PRD detection, and edge case handling

SCRIPT="$BATS_TEST_DIRNAME/../scripts/auto-reanchor.sh"

# Initialize a minimal git repo in the given directory
init_test_repo() {
    local dir="$1"
    git -C "$dir" init --quiet
    git -C "$dir" config user.email "test@example.com"
    git -C "$dir" config user.name "Test User"
    git -C "$dir" config commit.gpgsign false
    echo "# Test" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" commit --quiet -m "initial commit"
}

setup() {
    TEST_DIR=$(mktemp -d)
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ── Exit behavior ─────────────────────────────────────────────────────────────

@test "always exits 0 outside a git repo" {
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "always exits 0 inside a git repo" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
}

# ── Non-git directory ─────────────────────────────────────────────────────────

@test "notifies and exits cleanly when not in a git repo" {
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Not in a git repository"* ]]
}

# ── Orientation block ─────────────────────────────────────────────────────────

@test "outputs orientation block header and footer" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"POST-COMPACTION RE-ANCHOR"* ]]
    [[ "$output" == *"---"* ]]
}

@test "includes repo name and branch in output" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repo:"* ]]
    [[ "$output" == *"Branch:"* ]]
}

@test "includes recent commits" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Recent commits:"* ]]
    [[ "$output" == *"initial commit"* ]]
}

@test "includes action instruction to re-read CLAUDE.md and PRD" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ACTION:"* ]]
}

# ── CLAUDE.md detection ───────────────────────────────────────────────────────

@test "reports CLAUDE.md: no when absent" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md: no"* ]]
}

@test "reports CLAUDE.md: yes when present in repo root" {
    init_test_repo "$TEST_DIR"
    echo "# Instructions" > "$TEST_DIR/CLAUDE.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md: yes"* ]]
}

@test "reports CLAUDE.md: yes when present in .claude/" {
    init_test_repo "$TEST_DIR"
    mkdir -p "$TEST_DIR/.claude"
    echo "# Instructions" > "$TEST_DIR/.claude/CLAUDE.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CLAUDE.md: yes"* ]]
}

# ── PRD detection ─────────────────────────────────────────────────────────────

@test "shows Active PRD: none when no prds/ directory" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active PRD: none"* ]]
}

@test "shows Active PRD: none when no PRD has Status: In Progress" {
    init_test_repo "$TEST_DIR"
    mkdir "$TEST_DIR/prds"
    printf '**Status**: Complete\n\n## Milestones\n\n- [x] M1: Done\n' > "$TEST_DIR/prds/10-done.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active PRD: none"* ]]
}

@test "detects active PRD by filename" {
    init_test_repo "$TEST_DIR"
    mkdir "$TEST_DIR/prds"
    printf '**Status**: In Progress\n## Milestones\n- [x] M1: Done\n- [ ] M2: Next step\n' > "$TEST_DIR/prds/58-test-prd.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active PRD: 58-test-prd.md"* ]]
}

@test "extracts first unchecked milestone as next step" {
    init_test_repo "$TEST_DIR"
    mkdir "$TEST_DIR/prds"
    printf '**Status**: In Progress\n\n## Milestones\n\n- [x] M1: Already done\n- [ ] M2: The next thing\n- [ ] M3: Future thing\n' > "$TEST_DIR/prds/58-test-prd.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next milestone: M2: The next thing"* ]]
}

@test "omits next milestone line when all milestones are checked" {
    init_test_repo "$TEST_DIR"
    mkdir "$TEST_DIR/prds"
    printf '**Status**: In Progress\n\n## Milestones\n\n- [x] M1: Done\n- [x] M2: Also done\n' > "$TEST_DIR/prds/58-test-prd.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Next milestone:"* ]]
}

# ── Execution state detection ─────────────────────────────────────────────────

@test "omits execution state line when _execution-state.md is absent" {
    init_test_repo "$TEST_DIR"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"execution state"* ]]
}

@test "surfaces execution state warning when _execution-state.md is present" {
    init_test_repo "$TEST_DIR"
    echo "# Execution State" > "$TEST_DIR/_execution-state.md"
    run bash -c "cd \"$TEST_DIR\" && \"$SCRIPT\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Active execution state found"* ]]
}
