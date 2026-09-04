#!/usr/bin/env bats
# ABOUTME: Tests for scripts/check-skill-symlink-inertness.sh
# ABOUTME: Verifies the personal-over-project precedence verdict, the live-symlink warning, and dangling detection

SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-skill-symlink-inertness.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    export WORKSPACE="$TMPDIR/workspace"
    export PERSONAL="$TMPDIR/personal"
    export SOURCE="$TMPDIR/source"
    mkdir -p "$WORKSPACE" "$PERSONAL" "$SOURCE"
}

teardown() {
    rm -rf "$TMPDIR"
}

# Creates the shared file a project symlink points at.
make_source() {
    mkdir -p "$SOURCE/$1"
    printf -- '# %s\n' "$1" > "$SOURCE/$1/$2"
}

# Installs a personally-scoped skill, which is what shadows a project one.
install_personal() {
    mkdir -p "$PERSONAL/$1"
    printf -- '# %s\n' "$1" > "$PERSONAL/$1/SKILL.md"
}

# Symlinks a project-level skill in a repo to the shared source file.
link_project() {
    local repo="$1" skill="$2" target="$3"
    mkdir -p "$WORKSPACE/$repo/.claude/skills/$skill"
    ln -s "$SOURCE/$skill/$target" "$WORKSPACE/$repo/.claude/skills/$skill/SKILL.md"
}

@test "reports INERT when a personal skill shadows the project symlink" {
    make_source prd-done SKILL.v1-yolo.md
    install_personal prd-done
    link_project demo-repo prd-done SKILL.v1-yolo.md

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "INERT (shadowed by personal prd-done)"
    echo "$output" | grep -q "inert=1 live=0"
}

@test "reports LIVE and warns when nothing shadows the project symlink" {
    make_source prd-done SKILL.v1-yolo.md
    link_project demo-repo prd-done SKILL.v1-yolo.md
    # No install_personal, so precedence never kicks in.

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "LIVE (no personal prd-done to shadow it)"
    echo "$output" | grep -q "live=1"
    echo "$output" | grep -q "WARNING: at least one project skill is NOT shadowed"
}

@test "does not warn when every symlink is shadowed" {
    make_source prd-done SKILL.v1-yolo.md
    install_personal prd-done
    link_project demo-repo prd-done SKILL.v1-yolo.md

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "WARNING"
}

@test "records the symlink target so YOLO and interactive consumers are distinguishable" {
    make_source prd-done SKILL.v1-yolo.md
    make_source prd-start SKILL.md
    install_personal prd-done
    install_personal prd-start
    link_project yolo-repo prd-done SKILL.v1-yolo.md
    link_project interactive-repo prd-start SKILL.md

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "target: .*prd-done/SKILL.v1-yolo.md"
    echo "$output" | grep -q "target: .*prd-start/SKILL.md"
}

@test "flags a dangling symlink rather than reporting it as ordinary" {
    make_source prd-done SKILL.v1-yolo.md
    install_personal prd-done
    link_project demo-repo prd-done SKILL.v1-yolo.md
    rm -rf "$SOURCE/prd-done"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DANGLING"
}

@test "skips claude-config itself, which is the source rather than a consumer" {
    make_source prd-done SKILL.v1-yolo.md
    install_personal prd-done
    link_project claude-config prd-done SKILL.v1-yolo.md

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "inert=0 live=0"
}

@test "notes a repo that has a skills directory but no lifecycle skills" {
    mkdir -p "$WORKSPACE/other-repo/.claude/skills/some-unrelated-skill"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "(has .claude/skills, no lifecycle skills)"
    echo "$output" | grep -q "repos-with-skills-but-no-lifecycle=1"
}

@test "ignores a repo with no .claude/skills directory at all" {
    mkdir -p "$WORKSPACE/plain-repo/src"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "plain-repo"
}

@test "checks issue-* skills as well as prd-*" {
    make_source issue-done SKILL.md
    install_personal issue-done
    link_project demo-repo issue-done SKILL.md

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "issue-done .*INERT"
}

@test "counts prds-get, which a prd-* glob would omit" {
    make_source prds-get SKILL.md
    install_personal prds-get
    link_project demo-repo prds-get SKILL.md

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "prds-get .*INERT"
}
