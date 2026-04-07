#!/usr/bin/env bats
# ABOUTME: Integration tests for scripts/install-git-hooks.sh bootstrap and git hook dispatchers

SCRIPT="$BATS_TEST_DIRNAME/../scripts/install-git-hooks.sh"
HOOKS_SRC="$(cd "$BATS_TEST_DIRNAME/../hooks/git" && pwd)"

setup() {
    TMPDIR="$(mktemp -d)"
    export GIT_REPO="$TMPDIR/testrepo"
    git init "$GIT_REPO" --quiet
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Bootstrap: basic installation ────────────────────────────────────────────

@test "bootstrap installs pre-commit symlink" {
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    [ -L "$GIT_REPO/.git/hooks/pre-commit" ]
}

@test "bootstrap installs commit-msg symlink" {
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    [ -L "$GIT_REPO/.git/hooks/commit-msg" ]
}

@test "bootstrap installs pre-push symlink" {
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    [ -L "$GIT_REPO/.git/hooks/pre-push" ]
}

@test "symlinks point to correct source files" {
    run "$SCRIPT" "$GIT_REPO"
    [ "$(readlink "$GIT_REPO/.git/hooks/pre-commit")" = "$HOOKS_SRC/pre-commit" ]
    [ "$(readlink "$GIT_REPO/.git/hooks/commit-msg")" = "$HOOKS_SRC/commit-msg" ]
    [ "$(readlink "$GIT_REPO/.git/hooks/pre-push")" = "$HOOKS_SRC/pre-push" ]
}

@test "bootstrap prints installation status" {
    run "$SCRIPT" "$GIT_REPO"
    [[ "$output" == *"pre-commit"* ]]
    [[ "$output" == *"commit-msg"* ]]
    [[ "$output" == *"pre-push"* ]]
}

# ── Bootstrap: idempotency ────────────────────────────────────────────────────

@test "running bootstrap twice is idempotent" {
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    # Symlinks still valid after second run
    [ -L "$GIT_REPO/.git/hooks/pre-commit" ]
    [ -L "$GIT_REPO/.git/hooks/commit-msg" ]
    [ -L "$GIT_REPO/.git/hooks/pre-push" ]
}

@test "re-running bootstrap prints up-to-date status" {
    "$SCRIPT" "$GIT_REPO"
    run "$SCRIPT" "$GIT_REPO"
    [[ "$output" == *"already installed"* ]]
}

# ── Bootstrap: existing hook handling ────────────────────────────────────────

@test "bootstrap backs up existing pre-commit hook before replacing" {
    echo '#!/usr/bin/env bash' > "$GIT_REPO/.git/hooks/pre-commit"
    chmod +x "$GIT_REPO/.git/hooks/pre-commit"
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    # Backup file was created
    backup_count=$(ls "$GIT_REPO/.git/hooks/pre-commit.bak."* 2>/dev/null | wc -l | tr -d ' ')
    [ "$backup_count" -gt 0 ]
    # Symlink was installed
    [ -L "$GIT_REPO/.git/hooks/pre-commit" ]
}

@test "bootstrap preserves existing post-commit hook" {
    echo '#!/usr/bin/env bash' > "$GIT_REPO/.git/hooks/post-commit"
    chmod +x "$GIT_REPO/.git/hooks/post-commit"
    run "$SCRIPT" "$GIT_REPO"
    [ "$status" -eq 0 ]
    # post-commit is untouched (still a real file, not a symlink)
    [ -f "$GIT_REPO/.git/hooks/post-commit" ]
    [ ! -L "$GIT_REPO/.git/hooks/post-commit" ]
}

@test "bootstrap does not install hooks not in its list" {
    run "$SCRIPT" "$GIT_REPO"
    [ ! -e "$GIT_REPO/.git/hooks/post-commit" ]
    [ ! -e "$GIT_REPO/.git/hooks/post-merge" ]
    [ ! -e "$GIT_REPO/.git/hooks/post-rewrite" ]
}

# ── Bootstrap: error handling ─────────────────────────────────────────────────

@test "bootstrap fails with error when target is not a git repo" {
    NON_REPO="$TMPDIR/notarepo"
    mkdir -p "$NON_REPO"
    run "$SCRIPT" "$NON_REPO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a git repository"* ]]
}

# ── Dispatchers: executability ────────────────────────────────────────────────

@test "pre-commit dispatcher is executable" {
    [ -x "$HOOKS_SRC/pre-commit" ]
}

@test "commit-msg dispatcher is executable" {
    [ -x "$HOOKS_SRC/commit-msg" ]
}

@test "pre-push dispatcher is executable" {
    [ -x "$HOOKS_SRC/pre-push" ]
}

# ── Dispatchers: behavior with no check scripts ───────────────────────────────

@test "pre-commit dispatcher exits 0 when no check scripts exist" {
    # Use an isolated hooks/git/ copy with an empty checks/ dir
    ISOLATED_HOOKS="$TMPDIR/hooks/git"
    mkdir -p "$ISOLATED_HOOKS/checks" "$ISOLATED_HOOKS/lib"
    cp "$HOOKS_SRC/pre-commit" "$ISOLATED_HOOKS/pre-commit"
    chmod +x "$ISOLATED_HOOKS/pre-commit"
    run "$ISOLATED_HOOKS/pre-commit"
    [ "$status" -eq 0 ]
}

@test "commit-msg dispatcher exits 0 when no check scripts exist" {
    ISOLATED_HOOKS="$TMPDIR/hooks/git"
    mkdir -p "$ISOLATED_HOOKS/checks" "$ISOLATED_HOOKS/lib"
    cp "$HOOKS_SRC/commit-msg" "$ISOLATED_HOOKS/commit-msg"
    chmod +x "$ISOLATED_HOOKS/commit-msg"
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "test commit message" > "$MSGFILE"
    run "$ISOLATED_HOOKS/commit-msg" "$MSGFILE"
    [ "$status" -eq 0 ]
}

@test "pre-push dispatcher exits 0 when no check scripts exist" {
    ISOLATED_HOOKS="$TMPDIR/hooks/git"
    mkdir -p "$ISOLATED_HOOKS/checks" "$ISOLATED_HOOKS/lib"
    cp "$HOOKS_SRC/pre-push" "$ISOLATED_HOOKS/pre-push"
    chmod +x "$ISOLATED_HOOKS/pre-push"
    run bash -c 'echo "refs/heads/main abc123 refs/heads/main abc123" | '"$ISOLATED_HOOKS/pre-push"' origin https://github.com/example/repo'
    [ "$status" -eq 0 ]
}

# ── Dispatchers: symlink invocation ──────────────────────────────────────────

@test "pre-commit dispatcher works when called via symlink" {
    "$SCRIPT" "$GIT_REPO"
    cd "$GIT_REPO"
    run .git/hooks/pre-commit
    [ "$status" -eq 0 ]
}

@test "commit-msg dispatcher works when called via symlink" {
    "$SCRIPT" "$GIT_REPO"
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "test commit message" > "$MSGFILE"
    cd "$GIT_REPO"
    run .git/hooks/commit-msg "$MSGFILE"
    [ "$status" -eq 0 ]
}

@test "pre-push dispatcher works when called via symlink" {
    "$SCRIPT" "$GIT_REPO"
    cd "$GIT_REPO"
    run bash -c 'echo "refs/heads/main abc123 refs/heads/main abc123" | .git/hooks/pre-push origin https://github.com/example/repo'
    [ "$status" -eq 0 ]
}

# ── End-to-end: install on claude-config itself ───────────────────────────────

@test "bootstrap installs hooks into claude-config repo itself" {
    CLAUDE_CONFIG_DIR="$BATS_TEST_DIRNAME/.."
    # Back up any existing non-symlink hooks so we can restore them after the test
    for hook in pre-commit commit-msg pre-push; do
        if [ -e "$CLAUDE_CONFIG_DIR/.git/hooks/$hook" ] && [ ! -L "$CLAUDE_CONFIG_DIR/.git/hooks/$hook" ]; then
            cp "$CLAUDE_CONFIG_DIR/.git/hooks/$hook" "$TMPDIR/$hook.bak"
        fi
    done

    run "$SCRIPT" "$CLAUDE_CONFIG_DIR"
    [ "$status" -eq 0 ]
    [ -L "$CLAUDE_CONFIG_DIR/.git/hooks/pre-commit" ]
    [ -L "$CLAUDE_CONFIG_DIR/.git/hooks/commit-msg" ]
    [ -L "$CLAUDE_CONFIG_DIR/.git/hooks/pre-push" ]

    # Restore any backed-up hooks so the real repo is left in its original state
    for hook in pre-commit commit-msg pre-push; do
        if [ -f "$TMPDIR/$hook.bak" ]; then
            rm -f "$CLAUDE_CONFIG_DIR/.git/hooks/$hook"
            cp "$TMPDIR/$hook.bak" "$CLAUDE_CONFIG_DIR/.git/hooks/$hook"
        fi
    done
}
