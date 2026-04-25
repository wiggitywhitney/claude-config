#!/usr/bin/env bats
# ABOUTME: Tests for suggest-branch-cleanup.sh PostToolUse hook
# ABOUTME: Verifies advisory fires only on successful gh pr merge; silent otherwise

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/suggest-branch-cleanup.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    chmod +x "$SCRIPT" 2>/dev/null || true
}

teardown() {
    rm -rf "$TMPDIR"
}

write_input() {
    printf '%s' "$1" > "$TMPDIR/input.json"
}

@test "fires advisory for successful gh pr merge" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 42 --merge"},"cwd":"/tmp","tool_response":"Merged pull request #42 (title)\n"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
    [[ "$output" == *"branch"* ]]
}

@test "silent for failed gh pr merge" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 42"},"cwd":"/tmp","tool_response":"error: pull request is not mergeable"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent when no tool_response present" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 42"},"cwd":"/tmp"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for gh pr create" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title foo"},"cwd":"/tmp"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for echo gh pr merge (not a command invocation)" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"echo gh pr merge"},"cwd":"/tmp"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for non-Bash tool" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/tmp/foo.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "handles invalid JSON without error" {
    write_input 'not valid json'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
}
