#!/usr/bin/env bats
# ABOUTME: Tests for scripts/sync-repos.sh — syncs GitHub repos before bootstrap

SCRIPT="$BATS_TEST_DIRNAME/../scripts/sync-repos.sh"

setup() {
    TMPDIR="$(mktemp -d)"

    export REPOS_DIR="$TMPDIR/repos"
    mkdir -p "$REPOS_DIR"

    # Git identity required for test commits
    export GIT_AUTHOR_NAME="Test User"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Test User"
    export GIT_COMMITTER_EMAIL="test@example.com"

    # JSON file that mock gh 'repo list' returns
    MOCK_GH_LIST="$TMPDIR/gh-list.json"
    echo "[]" > "$MOCK_GH_LIST"
    export MOCK_GH_REPO_LIST="$MOCK_GH_LIST"

    # Mock gh binary — intercepts 'repo list' and 'repo clone'
    MOCK_BIN="$TMPDIR/mock-bin"
    mkdir -p "$MOCK_BIN"
    cat > "$MOCK_BIN/gh" << 'GHEOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "list" ]]; then
    cat "$MOCK_GH_REPO_LIST"
elif [[ "$1" == "repo" && "$2" == "clone" ]]; then
    # $3 = owner/repo-name  $4 = destination path
    if [[ "${MOCK_GH_CLONE_FAIL:-0}" == "1" ]]; then
        echo "error: repository not found" >&2
        exit 1
    fi
    dest="$4"
    mkdir -p "$dest"
    git init "$dest" --quiet
fi
GHEOF
    chmod +x "$MOCK_BIN/gh"
    export PATH="$MOCK_BIN:$PATH"

    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Helper: write a single-repo JSON list ─────────────────────────────────────

_write_list() {
    local name_with_owner="$1" pushed_at="$2"
    printf '[{"nameWithOwner":"%s","pushedAt":"%s"}]\n' \
        "$name_with_owner" "$pushed_at" > "$MOCK_GH_LIST"
}

# ── Core clone behavior ───────────────────────────────────────────────────────

@test "clones missing repo within active window" {
    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/new-repo" "$recent"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] cloned new-repo"* ]]
    [ -d "$REPOS_DIR/new-repo/.git" ]
}

@test "dry-run does not clone missing repo" {
    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/dry-repo" "$recent"

    run "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would clone dry-repo"* ]]
    [ ! -d "$REPOS_DIR/dry-repo" ]
}

# ── Core pull behavior ────────────────────────────────────────────────────────

@test "pulls existing repo and reports commit count" {
    # Create an origin with 1 commit, then clone it
    origin="$TMPDIR/origin-my-repo"
    git init "$origin" --quiet
    git -C "$origin" commit --allow-empty -m "initial" --quiet
    git clone "$origin" "$REPOS_DIR/my-repo" --quiet 2>/dev/null

    # Add 2 more commits to origin so the local clone is behind
    git -C "$origin" commit --allow-empty -m "second" --quiet
    git -C "$origin" commit --allow-empty -m "third" --quiet

    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/my-repo" "$recent"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] pulled my-repo (2 commits)"* ]]
}

@test "skips already-up-to-date repo" {
    origin="$TMPDIR/origin-current"
    git init "$origin" --quiet
    git -C "$origin" commit --allow-empty -m "initial" --quiet
    git clone "$origin" "$REPOS_DIR/current" --quiet 2>/dev/null

    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/current" "$recent"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] current — already up to date"* ]]
}

@test "dry-run does not pull existing repo" {
    origin="$TMPDIR/origin-dry-pull"
    git init "$origin" --quiet
    git -C "$origin" commit --allow-empty -m "initial" --quiet
    git clone "$origin" "$REPOS_DIR/dry-pull" --quiet 2>/dev/null
    git -C "$origin" commit --allow-empty -m "new remote commit" --quiet

    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/dry-pull" "$recent"

    before=$(git -C "$REPOS_DIR/dry-pull" rev-parse HEAD)
    run "$SCRIPT" --dry-run
    after=$(git -C "$REPOS_DIR/dry-pull" rev-parse HEAD)

    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY RUN] Would pull dry-pull"* ]]
    [ "$before" = "$after" ]
}

# ── Skip: local changes (non-fast-forward) ───────────────────────────────────

@test "skips repo with local changes that prevent fast-forward" {
    # Local and remote both diverge from the same base commit
    origin="$TMPDIR/origin-diverged"
    git init "$origin" --quiet
    git -C "$origin" commit --allow-empty -m "base" --quiet
    git clone "$origin" "$REPOS_DIR/diverged" --quiet 2>/dev/null

    # Local gets a commit that origin doesn't have
    git -C "$REPOS_DIR/diverged" commit --allow-empty -m "local only" --quiet

    # Origin gets a commit that local doesn't have — now they diverge
    git -C "$origin" commit --allow-empty -m "remote only" --quiet

    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/diverged" "$recent"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] diverged — local changes, run git pull manually"* ]]
}

# ── Skip: outside activity window ────────────────────────────────────────────

@test "skips repo outside N-month window" {
    old=$(date -d "12 months ago" --iso-8601=seconds)
    _write_list "owner/old-repo" "$old"

    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] old-repo — not active in last 6 months"* ]]
}

@test "respects --months flag boundary" {
    three_months_ago=$(date -d "3 months ago" --iso-8601=seconds)
    _write_list "owner/mid-repo" "$three_months_ago"

    # 2-month window: should be excluded
    run "$SCRIPT" --months 2
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] mid-repo — not active in last 2 months"* ]]

    # 6-month window: should be included (cloned since it's not on disk)
    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] cloned mid-repo"* ]]
}

# ── Flag: --repos-dir ─────────────────────────────────────────────────────────

@test "respects --repos-dir flag" {
    custom_dir="$TMPDIR/custom-repos"
    mkdir -p "$custom_dir"

    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/flag-repo" "$recent"

    run "$SCRIPT" --repos-dir "$custom_dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] cloned flag-repo"* ]]
    [ -d "$custom_dir/flag-repo/.git" ]
    [ ! -d "$REPOS_DIR/flag-repo" ]
}

# ── Clone error handling ──────────────────────────────────────────────────────

@test "reports error when clone fails" {
    recent=$(date -d "1 month ago" --iso-8601=seconds)
    _write_list "owner/fail-repo" "$recent"
    export MOCK_GH_CLONE_FAIL=1

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[ERROR] failed to clone fail-repo"* ]]
    [ ! -d "$REPOS_DIR/fail-repo" ]
}

# ── Empty repo list ───────────────────────────────────────────────────────────

@test "exits cleanly when repo list is empty" {
    echo "[]" > "$MOCK_GH_LIST"

    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
