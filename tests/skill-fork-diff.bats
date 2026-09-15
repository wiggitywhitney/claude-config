#!/usr/bin/env bats
# ABOUTME: Tests for scripts/skill-fork-diff.sh
# ABOUTME: Verifies leading-frontmatter-only stripping, trailing-blank normalization, and both-sides churn counting

SCRIPT="$BATS_TEST_DIRNAME/../scripts/skill-fork-diff.sh"

# The script's canonical manifest is hardcoded on purpose, so fixtures must supply
# all eight rather than the suite narrowing the list.
SKILLS=(prd-create prd-start prd-next prd-update-progress prd-update-decisions prd-done prd-close prds-get)

setup() {
    TMPDIR="$(mktemp -d)"
    export UPSTREAM="$TMPDIR/upstream"
    export REPO_ROOT="$TMPDIR/hers"
    export ANCESTOR=""

    mkdir -p "$UPSTREAM/shared-prompts"
    for s in "${SKILLS[@]}"; do
        printf -- '# %s\n\nBody line.\n' "$s" > "$UPSTREAM/shared-prompts/$s.md"
    done

    git -C "$UPSTREAM" init --quiet
    git -C "$UPSTREAM" config user.email test@example.com
    git -C "$UPSTREAM" config user.name Test
    git -C "$UPSTREAM" add -A
    git -C "$UPSTREAM" commit --quiet -m "ancestor"
    ANCESTOR="$(git -C "$UPSTREAM" rev-parse HEAD)"
    export ANCESTOR

    # His current copies and hers both start identical to the ancestor.
    for s in "${SKILLS[@]}"; do
        mkdir -p "$UPSTREAM/.claude/skills/dot-ai-$s" "$REPO_ROOT/.claude/skills/$s"
        cp "$UPSTREAM/shared-prompts/$s.md" "$UPSTREAM/.claude/skills/dot-ai-$s/SKILL.md"
        cp "$UPSTREAM/shared-prompts/$s.md" "$REPO_ROOT/.claude/skills/$s/SKILL.md"
    done
}

teardown() {
    rm -rf "$TMPDIR"
}

# Returns the HER_MOVED column for a given skill row.
her_moved() {
    echo "$output" | awk -v s="$1" '$1==s {print $6}'
}

his_moved() {
    echo "$output" | awk -v s="$1" '$1==s {print $5}'
}

total_moved() {
    echo "$output" | awk '$1=="TOTAL" {print $2, $3}'
}

@test "reports zero movement when every copy matches the ancestor" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(total_moved)" = "0 0" ]
}

@test "counts both sides of the diff, not just additions" {
    # Replace one line: one removal plus one addition is two lines of churn.
    printf -- '# prd-next\n\nDifferent body line.\n' > "$REPO_ROOT/.claude/skills/prd-next/SKILL.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(her_moved prd-next)" -eq 2 ]
}

@test "strips a leading frontmatter block so it is not counted as movement" {
    printf -- '---\nname: prd-done\n---\n\n# prd-done\n\nBody line.\n' \
        > "$REPO_ROOT/.claude/skills/prd-done/SKILL.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(her_moved prd-done)" -eq 0 ]
}

@test "preserves a --- horizontal rule in the body rather than stripping through it" {
    # This is the documented trap: deleting through the *second* --- would swallow
    # the body below the rule and under-report the difference.
    printf -- '---\nname: prd-start\n---\n\n# prd-start\n\nBody line.\n\n---\n\nTail section.\n' \
        > "$REPO_ROOT/.claude/skills/prd-start/SKILL.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    # The rule and the tail are body content, so they register as added lines.
    [ "$(her_moved prd-start)" -gt 0 ]
    # And the retained body must actually contain the tail: her body is longer
    # than the ancestor's by the rule plus the tail plus their blank lines.
    her_body="$(echo "$output" | awk '$1=="prd-start" {print $4}')"
    anc_body="$(echo "$output" | awk '$1=="prd-start" {print $2}')"
    [ "$her_body" -gt "$anc_body" ]
}

@test "ignores trailing blank lines added at end of file" {
    # The frontmatter-to-skill conversion appends one; it is an artifact, not movement.
    printf -- '# prd-close\n\nBody line.\n\n\n' > "$UPSTREAM/.claude/skills/dot-ai-prd-close/SKILL.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(his_moved prd-close)" -eq 0 ]
}

@test "attributes movement to the side that actually moved" {
    printf -- '# prd-create\n\nBody line.\nHis extra line.\n' \
        > "$UPSTREAM/.claude/skills/dot-ai-prd-create/SKILL.md"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(his_moved prd-create)" -eq 1 ]
    [ "$(her_moved prd-create)" -eq 0 ]
}

@test "covers prds-get, which a prd-* glob would omit" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^prds-get'
}

@test "fails loudly when a manifest skill is missing rather than skipping it" {
    rm -rf "$REPO_ROOT/.claude/skills/prd-done"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}
