#!/usr/bin/env bats
# ABOUTME: Tests for hooks/git/checks/check-prompt-generality.sh
# ABOUTME: Verifies advisory check fires only when src/agent/prompt.ts is staged

CHECKS_DIR="$BATS_TEST_DIRNAME/../hooks/git/checks"

setup() {
    TMPDIR="$(mktemp -d)"
    export GIT_REPO="$TMPDIR/testrepo"
    export GIT_CONFIG_GLOBAL=/dev/null
    git init "$GIT_REPO" --quiet
    git -C "$GIT_REPO" config user.email "test@test.com"
    git -C "$GIT_REPO" config user.name "Test"
    git -C "$GIT_REPO" symbolic-ref HEAD refs/heads/main
    touch "$GIT_REPO/.gitkeep"
    git -C "$GIT_REPO" add .gitkeep
    git -C "$GIT_REPO" commit -m "initial commit" --quiet
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "check-prompt-generality: silent and exits 0 when nothing is staged" {
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check-prompt-generality: silent and exits 0 when unrelated file is staged" {
    echo "some code" > "$GIT_REPO/other-file.ts"
    git -C "$GIT_REPO" add other-file.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check-prompt-generality: silent and exits 0 when similarly named file is staged" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "other content" > "$GIT_REPO/src/agent/prompt-v2.ts"
    git -C "$GIT_REPO" add src/agent/prompt-v2.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check-prompt-generality: prints advisory when src/agent/prompt.ts is staged" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "export const prompt = 'test';" > "$GIT_REPO/src/agent/prompt.ts"
    git -C "$GIT_REPO" add src/agent/prompt.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ADVISORY"* ]]
}

@test "check-prompt-generality: prints question 1 about principles applying to any project" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "export const prompt = 'test';" > "$GIT_REPO/src/agent/prompt.ts"
    git -C "$GIT_REPO" add src/agent/prompt.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"any project"* ]]
}

@test "check-prompt-generality: prints question 2 about root cause vs symptom" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "export const prompt = 'test';" > "$GIT_REPO/src/agent/prompt.ts"
    git -C "$GIT_REPO" add src/agent/prompt.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"root cause"* ]]
}

@test "check-prompt-generality: prints question 3 about synthetic namespaces" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "export const prompt = 'test';" > "$GIT_REPO/src/agent/prompt.ts"
    git -C "$GIT_REPO" add src/agent/prompt.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"my_service"* ]]
}

@test "check-prompt-generality: exits 0 when src/agent/prompt.ts staged alongside other files" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "export const prompt = 'test';" > "$GIT_REPO/src/agent/prompt.ts"
    echo "other code" > "$GIT_REPO/src/other.ts"
    git -C "$GIT_REPO" add src/agent/prompt.ts src/other.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "check-prompt-generality: always exits 0 — never blocks commit" {
    mkdir -p "$GIT_REPO/src/agent"
    echo "export const prompt = 'test with commit_story namespace';" > "$GIT_REPO/src/agent/prompt.ts"
    git -C "$GIT_REPO" add src/agent/prompt.ts
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/check-prompt-generality.sh\" 2>&1"
    [ "$status" -eq 0 ]
}
