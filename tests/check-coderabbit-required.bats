#!/usr/bin/env bats
# ABOUTME: Tests for check-coderabbit-required.sh — verifies all three CodeRabbit channels are checked.
# ABOUTME: Uses a fake gh binary to simulate different review configurations without real API calls.

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/check-coderabbit-required.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    mkdir -p "$TMPDIR/bin"
    chmod +x "$SCRIPT" 2>/dev/null || true
}

teardown() {
    rm -rf "$TMPDIR"
}

# Write a JSON hook payload to $TMPDIR/input.json
write_input() {
    printf '%s' "$1" > "$TMPDIR/input.json"
}

# Create a fake gh binary with specified review counts per channel.
# Args: pull_reviews inline_comments issue_comments
make_fake_gh() {
    local pull_reviews="${1:-0}"
    local inline_comments="${2:-0}"
    local issue_comments="${3:-0}"
    cat > "$TMPDIR/bin/gh" <<GHEOF
#!/usr/bin/env bash
# Output one line per match so wc -l gives the correct count (matching --paginate behavior)
emit_lines() { local n="\$1"; for i in \$(seq 1 "\$n" 2>/dev/null); do echo 1; done; }
if [[ "\$*" == *"pulls/42/reviews"* ]]; then
    emit_lines "$pull_reviews"
elif [[ "\$*" == *"pulls/42/comments"* ]]; then
    emit_lines "$inline_comments"
elif [[ "\$*" == *"issues/42/comments"* ]]; then
    emit_lines "$issue_comments"
fi
GHEOF
    chmod +x "$TMPDIR/bin/gh"
}

# Merge command using --repo to skip git-remote detection
MERGE_CMD='gh pr merge 42 --merge --delete-branch --repo testowner/testrepo'

# ── Allow cases: hook should pass through silently ────────────────────────────

@test "allows merge when review is in pull reviews channel only" {
    make_fake_gh 1 0 0
    write_input "{\"tool_input\":{\"command\":\"$MERGE_CMD\"},\"cwd\":\"/tmp\"}"
    run bash -c "PATH=\"$TMPDIR/bin:\$PATH\" \"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows merge when review is only in inline comments channel" {
    make_fake_gh 0 1 0
    write_input "{\"tool_input\":{\"command\":\"$MERGE_CMD\"},\"cwd\":\"/tmp\"}"
    run bash -c "PATH=\"$TMPDIR/bin:\$PATH\" \"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "allows merge when review is only in issue comments channel (the previously-broken case)" {
    make_fake_gh 0 0 1
    write_input "{\"tool_input\":{\"command\":\"$MERGE_CMD\"},\"cwd\":\"/tmp\"}"
    run bash -c "PATH=\"$TMPDIR/bin:\$PATH\" \"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Block case: no review in any channel ──────────────────────────────────────

@test "blocks merge when no CodeRabbit review in any channel" {
    make_fake_gh 0 0 0
    write_input "{\"tool_input\":{\"command\":\"$MERGE_CMD\"},\"cwd\":\"/tmp\"}"
    run bash -c "PATH=\"$TMPDIR/bin:\$PATH\" \"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['permissionDecision']=='deny'"
    [[ "$output" == *"CodeRabbit review is required"* ]]
}

# ── Passthrough: non-merge commands ──────────────────────────────────────────

@test "passes through non-merge gh commands silently" {
    make_fake_gh 0 0 0
    write_input '{"tool_input":{"command":"gh pr list"},"cwd":"/tmp"}'
    run bash -c "PATH=\"$TMPDIR/bin:\$PATH\" \"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "passes through non-gh commands silently" {
    make_fake_gh 0 0 0
    write_input '{"tool_input":{"command":"git status"},"cwd":"/tmp"}'
    run bash -c "PATH=\"$TMPDIR/bin:\$PATH\" \"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
