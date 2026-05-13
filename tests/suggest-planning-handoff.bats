#!/usr/bin/env bats
# ABOUTME: Tests for suggest-planning-handoff.sh PostToolUse hook
# ABOUTME: Verifies the hook fires after issue creation and new PRD file creation, and stays silent otherwise

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/suggest-planning-handoff.sh"

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

# ── Positive: gh issue create ─────────────────────────────────────────────────

@test "fires after successful gh issue create" {
    fake_url="https://github.com/wiggitywhitney/claude-config/issues/94"
    write_input "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"gh issue create --title test\"},\"tool_response\":\"$fake_url\"}"
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "advisory message contains the three planning-handoff questions" {
    fake_url="https://github.com/wiggitywhitney/claude-config/issues/94"
    write_input "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"gh issue create --title test\"},\"tool_response\":\"$fake_url\"}"
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"decisions"* ]]
    [[ "$output" == *"open questions"* ]]
    [[ "$output" == *"cold AI"* ]]
}

@test "output is valid JSON with correct hookSpecificOutput schema" {
    fake_url="https://github.com/wiggitywhitney/claude-config/issues/94"
    write_input "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"gh issue create --title test\"},\"tool_response\":\"$fake_url\"}"
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['hookSpecificOutput']['hookEventName'] == 'PostToolUse'
assert 'additionalContext' in d['hookSpecificOutput']
"
}

# ── Positive: Write tool on prds/ file (new file creation) ────────────────────

@test "fires after Write tool creates a file under prds/" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/94-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "prds/ Write trigger also emits the three questions" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/94-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"decisions"* ]]
    [[ "$output" == *"open questions"* ]]
    [[ "$output" == *"cold AI"* ]]
}

@test "fires after Write tool creates a file under prds/done/" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/done/47-old-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires after Write on relative prds/ path (no leading slash)" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"prds/94-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

# ── Negative: Edit on prds/ must NOT fire ────────────────────────────────────

@test "silent for Edit on a prds/ file" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/prds/94-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Negative: other gh subcommands must NOT fire ──────────────────────────────

@test "silent for gh issue list" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh issue list"},"tool_response":"#1 some issue"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for gh issue edit" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh issue edit 94 --body new body"},"tool_response":"https://github.com/wiggitywhitney/claude-config/issues/94"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for gh issue comment" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh issue comment 94 --body test"},"tool_response":"https://github.com/wiggitywhitney/claude-config/issues/94"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for gh pr create" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"},"tool_response":"https://github.com/wiggitywhitney/claude-config/pull/95"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for failed gh issue create (no github url in response)" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh issue create --title test"},"tool_response":"error: could not create"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Negative: Write on non-prds/ files must NOT fire ─────────────────────────

@test "silent for Write on a SKILL.md file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/.claude/skills/foo/SKILL.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Write on a rules/ file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/rules/my-rule.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Write on a plain source file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/scripts/deploy.sh"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for missing file_path in Write" {
    write_input '{"tool_name":"Write","tool_input":{}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for empty file_path in Write" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":""}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for git status bash command" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"git status"},"tool_response":"nothing to commit"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
