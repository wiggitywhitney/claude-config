#!/usr/bin/env bats
# ABOUTME: End-to-end test for scripts/sync-repos.sh — full multi-repo sync scenario
# ABOUTME: Tests clone, pull, and skip behaviors together with a realistic repo list.

SCRIPT="$BATS_TEST_DIRNAME/../scripts/sync-repos.sh"

setup() {
    TMPDIR="$(mktemp -d)"

    export REPOS_DIR="$TMPDIR/repos"
    mkdir -p "$REPOS_DIR"

    export GIT_AUTHOR_NAME="Test User"
    export GIT_AUTHOR_EMAIL="test@example.com"
    export GIT_COMMITTER_NAME="Test User"
    export GIT_COMMITTER_EMAIL="test@example.com"

    # Shared JSON file the mock gh reads
    MOCK_GH_LIST="$TMPDIR/gh-list.json"
    export MOCK_GH_REPO_LIST="$MOCK_GH_LIST"

    # Mock gh binary
    MOCK_BIN="$TMPDIR/mock-bin"
    mkdir -p "$MOCK_BIN"
    cat > "$MOCK_BIN/gh" << 'GHEOF'
#!/usr/bin/env bash
if [[ "$1" == "repo" && "$2" == "list" ]]; then
    cat "$MOCK_GH_REPO_LIST"
elif [[ "$1" == "repo" && "$2" == "clone" ]]; then
    dest="$4"
    mkdir -p "$dest"
    git init "$dest" --quiet
fi
GHEOF
    chmod +x "$MOCK_BIN/gh"
    export PATH="$MOCK_BIN:$PATH"

    # ── Repo setup ────────────────────────────────────────────────────────────

    # repo-present: already cloned, origin has 2 new commits (should pull)
    origin_present="$TMPDIR/origin-present"
    git init "$origin_present" --quiet
    git -C "$origin_present" commit --allow-empty -m "initial" --quiet
    git clone "$origin_present" "$REPOS_DIR/repo-present" --quiet 2>/dev/null
    git -C "$origin_present" commit --allow-empty -m "second" --quiet
    git -C "$origin_present" commit --allow-empty -m "third" --quiet

    # repo-new: not on disk yet (should be cloned)
    # repo-old: not on disk, pushed 12 months ago (should be skipped)

    # Build the gh repo list JSON with all three repos
    recent=$(date -d "1 month ago" --iso-8601=seconds)
    old=$(date -d "12 months ago" --iso-8601=seconds)
    printf '[{"nameWithOwner":"owner/repo-present","pushedAt":"%s"},{"nameWithOwner":"owner/repo-new","pushedAt":"%s"},{"nameWithOwner":"owner/repo-old","pushedAt":"%s"}]\n' \
        "$recent" "$recent" "$old" > "$MOCK_GH_LIST"

    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── Full multi-repo sync ───────────────────────────────────────────────────────

@test "full sync: pulls present repo with commit count" {
    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] pulled repo-present (2 commits)"* ]]
}

@test "full sync: clones absent repo within activity window" {
    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] cloned repo-new"* ]]
    [ -d "$REPOS_DIR/repo-new/.git" ]
}

@test "full sync: skips repo outside activity window" {
    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"[SKIPPED] repo-old — not active in last 6 months"* ]]
}

@test "full sync: all three behaviors in one run" {
    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"[OK] pulled repo-present"* ]]
    [[ "$output" == *"[OK] cloned repo-new"* ]]
    [[ "$output" == *"[SKIPPED] repo-old"* ]]
}

@test "full sync: exit code 0 when all behaviors mixed" {
    run "$SCRIPT" --months 6
    [ "$status" -eq 0 ]
}

@test "full sync dry-run: no filesystem changes" {
    before_present=$(git -C "$REPOS_DIR/repo-present" rev-parse HEAD)

    run "$SCRIPT" --months 6 --dry-run
    [ "$status" -eq 0 ]

    # repo-present HEAD unchanged
    after_present=$(git -C "$REPOS_DIR/repo-present" rev-parse HEAD)
    [ "$before_present" = "$after_present" ]

    # repo-new not cloned
    [ ! -d "$REPOS_DIR/repo-new" ]

    [[ "$output" == *"[DRY RUN] Would pull repo-present"* ]]
    [[ "$output" == *"[DRY RUN] Would clone repo-new"* ]]
}
