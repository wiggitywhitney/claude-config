#!/usr/bin/env bats
# ABOUTME: Tests for post-write-codeblock-check.sh PostToolUse hook
# ABOUTME: Verifies it invokes the checker only for markdown, calls the Python checker directly, and blocks on bare fences

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/post-write-codeblock-check.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    chmod +x "$SCRIPT" 2>/dev/null || true
}

teardown() {
    rm -rf "$TMPDIR"
}

# Copy the hook into an isolated directory beside stub checkers, so we can
# observe which checker it invokes. Each stub records that it ran.
stage_with_stubs() {
    cp "$SCRIPT" "$TMPDIR/hook.sh"
    chmod +x "$TMPDIR/hook.sh"
    cat > "$TMPDIR/check-markdown-codeblocks.sh" <<STUB
#!/usr/bin/env bash
touch "$TMPDIR/invoked-sh"
exit 0
STUB
    cat > "$TMPDIR/check-markdown-codeblocks.py" <<STUB
open("$TMPDIR/invoked-py", "w").close()
STUB
    chmod +x "$TMPDIR/check-markdown-codeblocks.sh" "$TMPDIR/check-markdown-codeblocks.py"
}

# ── Which checker gets invoked ────────────────────────────────────────────────

@test "invokes the Python checker directly for a markdown file" {
    stage_with_stubs
    printf '# hi\n' > "$TMPDIR/doc.md"
    run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/doc.md\"}}' | \"$TMPDIR/hook.sh\""
    [ "$status" -eq 0 ]
    [ -f "$TMPDIR/invoked-py" ]
    [ ! -f "$TMPDIR/invoked-sh" ]
}

@test "never invokes the retired shell wrapper" {
    stage_with_stubs
    printf 'echo hi\n' > "$TMPDIR/script.sh"
    run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/script.sh\"}}' | \"$TMPDIR/hook.sh\""
    [ "$status" -eq 0 ]
    [ ! -f "$TMPDIR/invoked-sh" ]
}

@test "stays silent for a non-markdown file" {
    printf 'echo hi\n' > "$TMPDIR/script.sh"
    run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/script.sh\"}}' | \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "invokes no checker when file_path is absent" {
    stage_with_stubs
    run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{}}' | \"$TMPDIR/hook.sh\""
    [ "$status" -eq 0 ]
    [ ! -f "$TMPDIR/invoked-py" ]
    [ ! -f "$TMPDIR/invoked-sh" ]
}

# ── End-to-end against the real checker ───────────────────────────────────────

@test "blocks on a markdown file containing a bare code fence" {
    printf 'text\n\n```\nbare\n```\n' > "$TMPDIR/bare.md"
    run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/bare.md\"}}' | \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'"decision": "block"'* ]]
    [[ "$output" == *"bare code block"* ]]
}

@test "stays silent on a markdown file whose fences are all labelled" {
    printf 'text\n\n```bash\nlabelled\n```\n' > "$TMPDIR/clean.md"
    run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMPDIR/clean.md\"}}' | \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
