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

# A second CLAUDE.md carries @-imports too. Until 2026-08-04 this script read only
# global/CLAUDE.md, so two rules that were both paths:-scoped and @-referenced from
# .claude/CLAUDE.md passed as correctly configured.
project_reference() {
    mkdir -p "$FAKE_REPO/.claude"
    printf 'Full reference: @~/.claude/rules/%s\n' "$1" >> "$FAKE_REPO/.claude/CLAUDE.md"
}

@test "honors an @-reference from the project .claude/CLAUDE.md" {
    bare_rule "project-referenced.md"
    project_reference "project-referenced.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "fails when a rule is paths:-scoped and @-referenced from the project CLAUDE.md" {
    scoped_rule "hooks-reference.md" '"**/*.sh"'
    project_reference "hooks-reference.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hooks-reference.md"* ]]
    [[ "$output" == *"pick one"* ]]
}

@test "names which CLAUDE.md carries the reference so the fix is unambiguous" {
    scoped_rule "hooks-reference.md" '"**/*.sh"'
    project_reference "hooks-reference.md"
    run "$SCRIPT" "$FAKE_REPO"
    [[ "$output" == *".claude/CLAUDE.md"* ]]
}

@test "a missing project CLAUDE.md is not an error" {
    scoped_rule "fine.md" '"**/*.ts"'
    [ ! -f "$FAKE_REPO/.claude/CLAUDE.md" ]
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "an @-path inside a code span is a mention, not an import" {
    # global/CLAUDE.md names reference-pointer rules inside backticks precisely because
    # a code span is not an import. measure-context-load.sh has always stripped code
    # before scanning; this checker did not, so a correctly paths:-scoped rule that
    # happened to be mentioned in an example was rejected as both-mechanisms.
    scoped_rule "pino-gotchas.md" '"**/*pino*"'
    printf 'Write it as `@~/.claude/rules/pino-gotchas.md syntax` in prose.\n' \
        >> "$FAKE_REPO/global/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "an @-path inside a fenced code block is a mention, not an import" {
    scoped_rule "pino-gotchas.md" '"**/*pino*"'
    {
        printf '```markdown\n'
        printf '@~/.claude/rules/pino-gotchas.md\n'
        printf '```\n'
    } >> "$FAKE_REPO/global/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
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

@test "does not exempt rules/README.md: an unscoped index loads every session" {
    # Exempt until 2026-08-03 on the false premise that it never loads. Measured with
    # an InstructionsLoaded hook, it loaded at session_start every session. The
    # exemption is why that went unnoticed, so the index is now held to the same
    # one-mechanism requirement as every other rule.
    printf -- '# Rules Index\n' > "$FAKE_REPO/rules/README.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 1 ]
    [[ "$output" == *"README.md"* ]]
}

@test "accepts rules/README.md once it carries paths: frontmatter" {
    printf -- '---\npaths: ["rules/**/*.md"]\n---\n\n# Rules Index\n' \
        > "$FAKE_REPO/rules/README.md"
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
