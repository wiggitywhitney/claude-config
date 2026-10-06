#!/usr/bin/env bats
# ABOUTME: Tests that verify-phase.sh runs its command without git's repository-location variables
# ABOUTME: Guards against test fixtures resolving to the enclosing repository during a worktree push

VERIFY_PHASE="$BATS_TEST_DIRNAME/../hooks/git/lib/verify-phase.sh"

# Builds a scratch clone with a linked worktree, and a pre-push hook that runs a
# fixture builder through verify-phase.sh the way the real pre-push check does.
setup() {
    TMPDIR="$(mktemp -d)"
    REMOTE="$TMPDIR/remote.git"
    CLONE="$TMPDIR/clone"
    WORKTREE="$TMPDIR/worktree"

    git init --bare --quiet "$REMOTE"
    git init --quiet -b main "$CLONE"
    git -C "$CLONE" config user.email "real@example.com"
    git -C "$CLONE" config user.name "Real"
    # An absolute local hooks path keeps any globally configured hooks out of the fixture
    git -C "$CLONE" config core.hooksPath "$CLONE/.git/hooks"
    git -C "$CLONE" commit --allow-empty -m "initial" --quiet
    git -C "$CLONE" remote add origin "$REMOTE"
    git -C "$CLONE" push --quiet origin main

    git -C "$CLONE" worktree add --quiet "$WORKTREE" -b feat
    git -C "$WORKTREE" commit --allow-empty -m "worktree commit" --quiet

    # Stands in for a test fixture builder: initialize a repository from the current
    # directory and commit in it, the way the verify test harness does.
    cat > "$TMPDIR/build-fixture.sh" <<'EOF'
#!/usr/bin/env bash
set -e
fixture="$(mktemp -d)"
cd "$fixture"
git init --quiet -b main
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "fixture" --quiet
touch "$(dirname "$0")/fixture-built"
EOF
    chmod +x "$TMPDIR/build-fixture.sh"

    # A pre-push hook that runs the fixture builder through verify-phase.sh, as the
    # real pre-push check does when a branch has an open pull request.
    cat > "$CLONE/.git/hooks/pre-push" <<EOF
#!/usr/bin/env bash
cat > /dev/null
"$VERIFY_PHASE" test "$TMPDIR/build-fixture.sh" "\$PWD" > /dev/null 2>&1
EOF
    chmod +x "$CLONE/.git/hooks/pre-push"
}

# Removes the scratch repositories.
teardown() {
    rm -rf "$TMPDIR"
}

@test "a push from a linked worktree leaves the shared config and the worktree branch untouched" {
    index_before="$(git -C "$WORKTREE" ls-files --stage)"
    refs_before="$(git -C "$CLONE" for-each-ref --format='%(refname) %(objectname)' refs/heads)"

    run git -C "$WORKTREE" push origin feat
    [ "$status" -eq 0 ]
    # The hook ran the fixture builder to completion, so the assertions below exercise it
    [ -f "$TMPDIR/fixture-built" ]

    [ "$(git -C "$CLONE" config --get core.bare)" = "false" ]
    [ "$(git -C "$WORKTREE" log -1 --format=%an)" = "Real" ]
    [ "$(git -C "$WORKTREE" log -1 --format=%s)" = "worktree commit" ]
    [ -z "$(git -C "$CLONE" branch --list 'feature/test-branch')" ]
    [ "$(git -C "$WORKTREE" ls-files --stage)" = "$index_before" ]
    [ "$(git -C "$CLONE" for-each-ref --format='%(refname) %(objectname)' refs/heads)" = "$refs_before" ]
}

@test "the command runs with git's repository-location variables removed" {
    run env GIT_DIR=sentinel-value-126 GIT_WORK_TREE=sentinel-value-126 \
        GIT_INDEX_FILE=sentinel-value-126 GIT_COMMON_DIR=sentinel-value-126 \
        "$VERIFY_PHASE" test 'printenv GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR || echo UNSET' "$TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UNSET"* ]]
    [[ "$output" != *"sentinel-value-126"* ]]
}

@test "variables that do not locate a repository still reach the command" {
    run env VERIFY_PHASE_PROBE=kept "$VERIFY_PHASE" test 'printenv VERIFY_PHASE_PROBE' "$TMPDIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kept"* ]]
}
