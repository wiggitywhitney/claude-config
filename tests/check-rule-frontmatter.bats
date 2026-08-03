#!/usr/bin/env bats
# ABOUTME: Tests for scripts/check-rule-frontmatter.sh
# ABOUTME: Verifies each rules/ file has exactly one loading mechanism — paths: or @-reference, never both, never neither

SCRIPT="$BATS_TEST_DIRNAME/../scripts/check-rule-frontmatter.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    export FAKE_REPO="$TMPDIR/repo"
    mkdir -p "$FAKE_REPO/rules/languages" "$FAKE_REPO/global"
    cat > "$FAKE_REPO/global/CLAUDE.md" <<'EOF'
# Global Standards

Always-loaded rules:

@~/.claude/rules/always-loaded.md
EOF
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# Writes a rule file with paths: frontmatter.
scoped_rule() {
    printf -- '---\npaths: [%s]\n---\n\n# Scoped\n' "$2" > "$FAKE_REPO/rules/$1"
}

# Writes a rule file with no frontmatter at all.
bare_rule() {
    printf -- '# Bare\n\nSome guidance.\n' > "$FAKE_REPO/rules/$1"
}

@test "passes when a rule is paths:-scoped and not @-referenced" {
    scoped_rule "pino-gotchas.md" '"**/*pino*"'
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    [[ "$output" == *"exactly one loading mechanism"* ]]
}

@test "passes when a rule is @-referenced and has no frontmatter" {
    bare_rule "always-loaded.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "fails when a rule has neither paths: nor an @-reference" {
    bare_rule "orphan-gotchas.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"orphan-gotchas.md"* ]]
    [[ "$output" == *"loads in every session"* ]]
}

@test "fails when a rule is both @-referenced and paths:-scoped" {
    scoped_rule "always-loaded.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"always-loaded.md"* ]]
    [[ "$output" == *"pick one"* ]]
}

@test "fails when a rule uses the ** / * wildcard as its scope" {
    scoped_rule "too-broad.md" '"**/*"'
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"too-broad.md"* ]]
    [[ "$output" == *"not scoping"* ]]
}

@test "reports every offending file, not just the first" {
    bare_rule "orphan-one.md"
    bare_rule "orphan-two.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"orphan-one.md"* ]]
    [[ "$output" == *"orphan-two.md"* ]]
    [[ "$output" == *"2 rule-loading problem(s) found"* ]]
}

@test "checks files in rules/ subdirectories" {
    printf -- '# Shell\n' > "$FAKE_REPO/rules/languages/shell.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"languages/shell.md"* ]]
}

@test "exempts rules/README.md, which is an index rather than a rule" {
    printf -- '# Rules Index\n' > "$FAKE_REPO/rules/README.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "does not count a bare paths: line in prose as frontmatter" {
    printf -- '# Prose\n\npaths: ["**/*.ts"] appears here as an example, not as frontmatter.\n' \
        > "$FAKE_REPO/rules/prose-gotchas.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"prose-gotchas.md"* ]]
}

@test "does not count a paths: line below the frontmatter block as frontmatter" {
    printf -- '---\ndescription: no paths key here\n---\n\n# Body\n\npaths: ["**/*.ts"]\n' \
        > "$FAKE_REPO/rules/late-paths.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"late-paths.md"* ]]
}

@test "catches the ** / * wildcard in a single-quoted inline list" {
    printf -- "---\npaths: ['**/*']\n---\n\n# Single quoted\n" > "$FAKE_REPO/rules/single-quoted.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"single-quoted.md"* ]]
    [[ "$output" == *"not scoping"* ]]
}

@test "catches the ** / * wildcard in a double-quoted block sequence" {
    printf -- '---\npaths:\n  - "**/*"\n---\n\n# Block sequence\n' > "$FAKE_REPO/rules/block-double.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"block-double.md"* ]]
    [[ "$output" == *"not scoping"* ]]
}

@test "catches the ** / * wildcard in a single-quoted block sequence" {
    printf -- "---\npaths:\n  - '**/*'\n---\n\n# Block sequence\n" > "$FAKE_REPO/rules/block-single.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"block-single.md"* ]]
    [[ "$output" == *"not scoping"* ]]
}

@test "catches the ** / * wildcard in a block sequence with a trailing comment" {
    printf -- '---\npaths:\n  - "**/*"  # everything, for now\n---\n\n# Commented\n' \
        > "$FAKE_REPO/rules/block-commented.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"block-commented.md"* ]]
    [[ "$output" == *"not scoping"* ]]
}

@test "accepts a real scope written as a block sequence" {
    printf -- '---\npaths:\n  - "**/*.ts"\n  - "**/package.json"\n---\n\n# Block sequence\n' \
        > "$FAKE_REPO/rules/block-scoped.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "fails with a clear message when the rules directory is missing" {
    rm -rf "$FAKE_REPO/rules"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no rules directory"* ]]
}

@test "fails with a clear message when global/CLAUDE.md is missing" {
    rm -f "$FAKE_REPO/global/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no global/CLAUDE.md"* ]]
}

@test "the real repo passes its own check" {
    run "$SCRIPT" "$BATS_TEST_DIRNAME/.."
    [ "$status" -eq 0 ]
}
