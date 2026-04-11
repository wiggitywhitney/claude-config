#!/usr/bin/env bats
# ABOUTME: Tests for cascade-decision-check.sh PostToolUse hook
# ABOUTME: Verifies the hook fires (with additionalContext) only for prds/ files via Write/Edit

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/cascade-decision-check.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    chmod +x "$SCRIPT" 2>/dev/null || true
}

teardown() {
    rm -rf "$TMPDIR"
}

# Write a JSON payload to $TMPDIR/input.json for use in tests
write_input() {
    printf '%s' "$1" > "$TMPDIR/input.json"
}

# ── Positive cases: hook should fire ─────────────────────────────────────────

@test "fires for Write on prds/ file - outputs additionalContext JSON" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/47-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
    [[ "$output" == *"Decision Log"* ]]
}

@test "fires for Edit on prds/ file - outputs additionalContext JSON" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/prds/63-bootstrap.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "output is valid JSON when hook fires" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/47-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    echo "$output" | python3 -m json.tool > /dev/null
}

@test "additionalContext instructs Claude to cascade-evaluate milestones" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/47-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"milestone"* ]]
}

# ── Negative cases: hook should be silent ────────────────────────────────────

@test "silent for Write on non-prds file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/scripts/foo.sh"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Edit on prds/done/ file" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/prds/done/47-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Bash tool even with prds/ in command" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"cat prds/47-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for missing file_path key" {
    write_input '{"tool_name":"Write","tool_input":{}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for empty file_path" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":""}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Write on CLAUDE.md outside prds/" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/global/CLAUDE.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
