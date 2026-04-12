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

    export REPOS_DIR="$TMPDIR/repos"
    mkdir -p "$REPOS_DIR"

    export HOOK_INSTALL_LOG="$TMPDIR/hook-install.log"
    cat > "$TMPDIR/mock-install-hooks.sh" << 'EOF'
#!/usr/bin/env bash
echo "$1" >> "$HOOK_INSTALL_LOG"
EOF
    chmod +x "$TMPDIR/mock-install-hooks.sh"
    export INSTALL_HOOKS_SCRIPT="$TMPDIR/mock-install-hooks.sh"

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

# ── Memory file restore ───────────────────────────────────────────────────────

@test "fresh restore creates memory file in correct location" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/memory/test-project"
    echo "memory content" > "$CLAUDE_PERSONAL_DIR/memory/test-project/notes.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]

    HOME_PREFIX=$(echo "$HOME/Documents/Repositories" | sed 's|[/.]|-|g')
    expected="$CLAUDE_DIR/projects/${HOME_PREFIX}-test-project/memory/notes.md"
    [ -f "$expected" ]
    [ "$(cat "$expected")" = "memory content" ]
    [[ "$output" == *"[OK] Restored memory: test-project/notes.md"* ]]
}

@test "memory restore is idempotent with identical content" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/memory/test-project"
    echo "memory content" > "$CLAUDE_PERSONAL_DIR/memory/test-project/notes.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] memory: test-project/notes.md (identical)"* ]]
}

@test "memory restore overwrites when repo content differs from local" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/memory/test-project"
    echo "original content" > "$CLAUDE_PERSONAL_DIR/memory/test-project/notes.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]

    echo "updated content" > "$CLAUDE_PERSONAL_DIR/memory/test-project/notes.md"
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] Updated memory: test-project/notes.md"* ]]

    HOME_PREFIX=$(echo "$HOME/Documents/Repositories" | sed 's|[/.]|-|g')
    expected="$CLAUDE_DIR/projects/${HOME_PREFIX}-test-project/memory/notes.md"
    [ "$(cat "$expected")" = "updated content" ]
}

@test "memory restore uses HOME-encoding to compute project path" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/memory/my-project"
    echo "test" > "$CLAUDE_PERSONAL_DIR/memory/my-project/file.md"

    run "$SCRIPT"
    [ "$status" -eq 0 ]

    # Verify encoding rule: $HOME/Documents/Repositories → sed 's|[/.]|-|g'
    expected_prefix=$(echo "$HOME/Documents/Repositories" | sed 's|[/.]|-|g')
    expected_dir="$CLAUDE_DIR/projects/${expected_prefix}-my-project/memory"
    [ -d "$expected_dir" ]
    [ -f "$expected_dir/file.md" ]
}

# ── Git hook installation ─────────────────────────────────────────────────────

@test "installs hooks in discovered git repo" {
    mkdir -p "$REPOS_DIR/my-repo/.git"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] git hooks installed: my-repo"* ]]
    [ -f "$HOOK_INSTALL_LOG" ]
    grep -q "my-repo" "$HOOK_INSTALL_LOG"
}

@test "skips repo with .skip-git-hooks" {
    mkdir -p "$REPOS_DIR/my-repo/.git"
    touch "$REPOS_DIR/my-repo/.skip-git-hooks"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] git hooks: my-repo"* ]]
    [ ! -f "$HOOK_INSTALL_LOG" ]
}

@test "hook installation is idempotent" {
    mkdir -p "$REPOS_DIR/my-repo/.git"

    run "$SCRIPT"
    [ "$status" -eq 0 ]

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] git hooks installed: my-repo"* ]]
}

@test "dry-run prints would-install without calling installer" {
    mkdir -p "$REPOS_DIR/my-repo/.git"

    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would install git hooks in my-repo"* ]]
    [ ! -f "$HOOK_INSTALL_LOG" ]
}

@test "skips non-git directories under REPOS_DIR" {
    mkdir -p "$REPOS_DIR/not-a-repo"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "$HOOK_INSTALL_LOG" ]
}

# ── settings.local.json restore ───────────────────────────────────────────────

@test "fresh restore creates settings.local.json when repo exists" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/my-project"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/my-project/settings.local.json"
    mkdir -p "$REPOS_DIR/my-project/.git"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$REPOS_DIR/my-project/.claude/settings.local.json" ]
    [ "$(cat "$REPOS_DIR/my-project/.claude/settings.local.json")" = '{"permissions":{}}' ]
    [[ "$output" == *"[OK] Restored settings.local.json: my-project"* ]]
}

@test "settings.local.json restore is idempotent with identical content" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/my-project"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/my-project/settings.local.json"
    mkdir -p "$REPOS_DIR/my-project/.git"

    run "$SCRIPT"
    [ "$status" -eq 0 ]

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] settings.local.json: my-project (identical)"* ]]
}

@test "settings.local.json restore overwrites when content differs" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/my-project"
    echo '{"original":true}' > "$CLAUDE_PERSONAL_DIR/local-settings/my-project/settings.local.json"
    mkdir -p "$REPOS_DIR/my-project/.git"
    mkdir -p "$REPOS_DIR/my-project/.claude"
    echo '{"stale":true}' > "$REPOS_DIR/my-project/.claude/settings.local.json"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(cat "$REPOS_DIR/my-project/.claude/settings.local.json")" = '{"original":true}' ]
    [[ "$output" == *"[OK] Updated settings.local.json: my-project"* ]]
}

@test "skips settings.local.json when repo not cloned" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/missing-project"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/missing-project/settings.local.json"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -d "$REPOS_DIR/missing-project" ]
    [[ "$output" == *"[SKIPPED] settings.local.json: missing-project — repo not cloned yet"* ]]
}

@test "prints re-run reminder when repos were skipped" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/missing-project"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/missing-project/settings.local.json"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Re-run bootstrap after cloning the above repos to restore their settings."* ]]
}

@test "no re-run reminder when no repos were skipped" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/present-project"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/present-project/settings.local.json"
    mkdir -p "$REPOS_DIR/present-project/.git"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Re-run bootstrap"* ]]
}

@test "dry-run shows settings.local.json restore without writing" {
    mkdir -p "$CLAUDE_PERSONAL_DIR/local-settings/my-project"
    echo '{"permissions":{}}' > "$CLAUDE_PERSONAL_DIR/local-settings/my-project/settings.local.json"
    mkdir -p "$REPOS_DIR/my-project/.git"

    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would restore settings.local.json: my-project"* ]]
    [ ! -f "$REPOS_DIR/my-project/.claude/settings.local.json" ]
}

@test "no-op when local-settings directory does not exist" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"settings.local.json"* ]]
}
