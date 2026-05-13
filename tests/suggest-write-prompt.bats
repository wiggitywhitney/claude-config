#!/usr/bin/env bats
# ABOUTME: Tests for suggest-write-prompt.sh PostToolUse hook
# ABOUTME: Verifies the hook fires for all AI-consumed document types and stays silent otherwise

SCRIPT="$BATS_TEST_DIRNAME/../.claude/skills/verify/scripts/suggest-write-prompt.sh"

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

# ── Existing triggers: must continue to fire ──────────────────────────────────

@test "fires for Write on SKILL.md" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/.claude/skills/my-skill/SKILL.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
    [[ "$output" == *"write-prompt"* ]]
}

@test "fires for Edit on SKILL.v1-yolo.md" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/.claude/skills/my-skill/SKILL.v1-yolo.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires for Write on CLAUDE.md" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/CLAUDE.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

# ── New triggers: prds/ files ─────────────────────────────────────────────────

@test "fires for Write on a prds/ file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/93-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires for Edit on a prds/ file" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/prds/93-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires for Edit on a prds/done/ file" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/prds/done/47-old-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

# ── New triggers: rules/ files ────────────────────────────────────────────────

@test "fires for Write on a rules/ file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/Users/whitney/.claude/rules/my-rule.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires for Edit on a rules/ file" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/rules/testing-rules.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

# ── New triggers: *-prompt.md and *-spec.md ───────────────────────────────────

@test "fires for Write on a *-prompt.md file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/system-prompt.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires for Write on a *-spec.md file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/agent-spec.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "fires for Edit on a *-spec.md file" {
    write_input '{"tool_name":"Edit","tool_input":{"file_path":"/repo/docs/crawler-spec.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

# ── Output format ─────────────────────────────────────────────────────────────

@test "output is valid JSON with correct hookSpecificOutput schema" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/prds/93-my-feature.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['hookSpecificOutput']['hookEventName'] == 'PostToolUse'
assert 'additionalContext' in d['hookSpecificOutput']
"
}

# ── Bash path: gh issue create ────────────────────────────────────────────────

@test "bash path fires after successful gh issue create" {
    fake_url="https://github.com/wiggitywhitney/claude-config/issues/99"
    write_input "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"gh issue create --title test\"},\"tool_response\":\"$fake_url\"}"
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"additionalContext"* ]]
}

@test "bash path is silent for gh issue create that produced no github url" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh issue create --title test"},"tool_response":"error: could not create"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Negative cases: must stay silent ─────────────────────────────────────────

@test "silent for Write on a plain markdown file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/docs/README.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Write on a shell script" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/scripts/deploy.sh"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for Write on a TypeScript file" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/src/index.ts"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for missing file_path" {
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

@test "silent for Bash tool on non-issue-create commands" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"git status"},"tool_response":"nothing to commit"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for gh issue list (not create)" {
    write_input '{"tool_name":"Bash","tool_input":{"command":"gh issue list"},"tool_response":"#1 some issue"}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "silent for a file whose path happens to contain the word rules but is not in a rules/ dir" {
    write_input '{"tool_name":"Write","tool_input":{"file_path":"/repo/docs/business-rules-overview.md"}}'
    run bash -c "\"$SCRIPT\" < \"$TMPDIR/input.json\""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
