#!/usr/bin/env bats
# ABOUTME: End-to-end test for scripts/bootstrap.sh — full new-machine restore scenario
# ABOUTME: Tests all steps together with two repos (one cloned, one absent).

SCRIPT="$BATS_TEST_DIRNAME/../scripts/bootstrap.sh"

setup() {
    TMPDIR="$(mktemp -d)"

    export CLAUDE_DIR="$TMPDIR/dot-claude"
    mkdir -p "$CLAUDE_DIR"

    export CLAUDE_PERSONAL_DIR="$TMPDIR/claude-personal"
    mkdir -p "$CLAUDE_PERSONAL_DIR"
    git init "$CLAUDE_PERSONAL_DIR" --quiet

    export REPOS_DIR="$TMPDIR/repos"
    mkdir -p "$REPOS_DIR"

    # Mock hook installer — logs called repo paths
    export HOOK_INSTALL_LOG="$TMPDIR/hook-install.log"
    cat > "$TMPDIR/mock-install-hooks.sh" << 'EOF'
#!/usr/bin/env bash
echo "$1" >> "$HOOK_INSTALL_LOG"
EOF
    chmod +x "$TMPDIR/mock-install-hooks.sh"
    export INSTALL_HOOKS_SCRIPT="$TMPDIR/mock-install-hooks.sh"

    # ── Repo setup ────────────────────────────────────────────────────────────
    # project-alpha: cloned and present
    mkdir -p "$REPOS_DIR/project-alpha/.git"

    # project-beta: not cloned — only a backup exists in claude-personal

    # ── claude-personal setup ─────────────────────────────────────────────────

    # Memory for project-alpha
    mkdir -p "$CLAUDE_PERSONAL_DIR/memory/project-alpha"
    echo "# Notes" > "$CLAUDE_PERSONAL_DIR/memory/project-alpha/notes.md"

    # settings.local.json for project-alpha (present) and project-beta (absent)
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/project-alpha"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/project-alpha/settings.local.json"
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/project-beta"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/project-beta/settings.local.json"

    # Private files for project-alpha (present) and project-beta (absent)
    mkdir -p "$CLAUDE_PERSONAL_DIR/private-files/project-alpha/journal/entries"
    echo "journal entry" > "$CLAUDE_PERSONAL_DIR/private-files/project-alpha/journal/entries/2026-04-13.md"
    mkdir -p "$CLAUDE_PERSONAL_DIR/private-files/project-alpha/.claude"
    echo "# Decisions" > "$CLAUDE_PERSONAL_DIR/private-files/project-alpha/.claude/design-decisions.md"
    mkdir -p "$CLAUDE_PERSONAL_DIR/private-files/project-beta/journal"
    echo "beta entry" > "$CLAUDE_PERSONAL_DIR/private-files/project-beta/journal/2026-04-12.md"

    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Full new-machine restore ───────────────────────────────────────────────────

@test "full restore: settings.json symlink created" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_DIR/settings.json" ]
    expected_target="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/config/settings.json"
    [ "$(readlink "$CLAUDE_DIR/settings.json")" = "$expected_target" ]
}

@test "full restore: memory file restored for project-alpha" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    HOME_PREFIX=$(echo "$HOME/Documents/Repositories" | sed 's|[/.]|-|g')
    expected="$CLAUDE_DIR/projects/${HOME_PREFIX}-project-alpha/memory/notes.md"
    [ -f "$expected" ]
    [ "$(cat "$expected")" = "# Notes" ]
}

@test "full restore: settings.local.json restored for present repo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$REPOS_DIR/project-alpha/.claude/settings.local.json" ]
    [ "$(cat "$REPOS_DIR/project-alpha/.claude/settings.local.json")" = '{"permissions":{}}' ]
}

@test "full restore: settings.local.json skipped for absent repo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -d "$REPOS_DIR/project-beta" ]
    [[ "$output" == *"[SKIPPED] settings.local.json: project-beta — repo not cloned yet"* ]]
}

@test "full restore: journal directory restored to present repo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$REPOS_DIR/project-alpha/journal/entries/2026-04-13.md" ]
    [ "$(cat "$REPOS_DIR/project-alpha/journal/entries/2026-04-13.md")" = "journal entry" ]
}

@test "full restore: design-decisions.md restored to present repo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$REPOS_DIR/project-alpha/.claude/design-decisions.md" ]
    [ "$(cat "$REPOS_DIR/project-alpha/.claude/design-decisions.md")" = "# Decisions" ]
}

@test "full restore: private files skipped for absent repo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] private files: project-beta — repo not cloned yet"* ]]
}

@test "full restore: git hooks installed in present repo" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$HOOK_INSTALL_LOG" ]
    grep -q "project-alpha" "$HOOK_INSTALL_LOG"
}

@test "full restore: re-run reminder printed when repos were skipped" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Re-run bootstrap after cloning the above repos to restore their files and settings."* ]]
}

@test "full restore: exit code 0 on partial success" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "full restore is idempotent: second run produces no errors" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] settings.json symlink already correct"* ]]
    [[ "$output" == *"(identical)"* ]]
}
