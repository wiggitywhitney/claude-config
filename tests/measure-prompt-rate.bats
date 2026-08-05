#!/usr/bin/env bats

# Tests for scripts/measure-prompt-rate.sh — the PRD #109 Milestone A3 prompt-rate
# measurement required by Decision 25 (measure with a committed script, not by eye).

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/measure-prompt-rate.sh"
  LOG="${BATS_TEST_TMPDIR}/events.jsonl"
}

# Append one event record to the fixture log.
# Usage: add_event <event> <mode> <tool> <command> <logged_at>
add_event() {
  printf '{"hook_event_name":"%s","permission_mode":"%s","tool_name":"%s","tool_input":{"command":"%s"},"logged_at":"%s"}\n' \
    "$1" "$2" "$3" "$4" "$5" >> "$LOG"
}

@test "reports a rate of prompts per hundred tool calls" {
  for i in 01 02 03 04 05 06 07 08 09 10; do
    add_event PreToolUse default Bash "echo hello" "2026-08-04T10:${i}:00Z"
  done
  add_event PermissionRequest default Bash "echo hello" "2026-08-04T10:05:00Z"
  add_event PermissionRequest default Bash "echo hello" "2026-08-04T10:06:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tool calls:"*"10"* ]]
  [[ "$output" == *"Prompts:"*"2"* ]]
  [[ "$output" == *"20.0"* ]]
}

@test "names the log file it measured" {
  # Regression guard: passing the path into awk as 'log' shadowed awk's
  # logarithm built-in and printed '-inf' as the header on 2026-08-04.
  add_event PreToolUse default Bash "echo a" "2026-08-04T10:00:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"events.jsonl"* ]]
  [[ "$output" != *"inf"* ]]
}

@test "counts every permission mode, including camelCase mode names" {
  # Regression guard: a '[a-z]*' character class silently drops acceptEdits,
  # which produced a wrong all-Manual finding on 2026-08-04.
  add_event PreToolUse default Bash "echo a" "2026-08-04T10:01:00Z"
  add_event PreToolUse acceptEdits Bash "echo b" "2026-08-04T10:02:00Z"
  add_event PreToolUse acceptEdits Bash "echo c" "2026-08-04T10:03:00Z"
  add_event PermissionRequest acceptEdits Bash "echo d" "2026-08-04T10:04:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"acceptEdits"* ]]
  [[ "$output" == *"default"* ]]
}

@test "restricts counting to the requested window" {
  add_event PreToolUse default Bash "echo old" "2026-08-01T10:00:00Z"
  add_event PermissionRequest default Bash "echo old" "2026-08-01T10:00:00Z"
  add_event PreToolUse default Bash "echo new" "2026-08-04T10:00:00Z"
  add_event PreToolUse default Bash "echo new" "2026-08-04T11:00:00Z"

  run "$SCRIPT" --log "$LOG" --since 2026-08-04T00:00:00Z
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tool calls:"*"2"* ]]
  [[ "$output" == *"Prompts:"*"0"* ]]
}

@test "states the length of the observed window" {
  add_event PreToolUse default Bash "echo a" "2026-08-04T10:00:00Z"
  add_event PreToolUse default Bash "echo b" "2026-08-04T13:00:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3.0 hours"* ]]
}

@test "classifies an inline heredoc as the heredoc class" {
  add_event PreToolUse default Bash "echo plain" "2026-08-04T10:00:00Z"
  add_event PermissionRequest default Bash "python3 - <<PY" "2026-08-04T10:01:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"heredoc"* ]]
}

@test "classifies an ask-rule command ahead of its other shape features" {
  # rm reaches a configured ask rule, which no permission mode can suppress,
  # so it must not be filed under expansion just because it contains a variable.
  add_event PreToolUse default Bash "echo plain" "2026-08-04T10:00:00Z"
  add_event PermissionRequest default Bash "rm -f \$TMPDIR/scratch" "2026-08-04T10:01:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ask-rule"* ]]
  [[ "$output" != *"expansion"* ]]
}

@test "fails explicitly when the window holds no tool calls to divide by" {
  add_event PermissionRequest default Bash "echo a" "2026-08-04T10:00:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no PreToolUse events"* ]]
}

@test "fails loudly on a malformed timestamp rather than counting a partial window" {
  add_event PreToolUse default Bash "echo a" "2026-08-04T10:00:00Z"
  add_event PreToolUse default Bash "echo b" "2026-08-04T10:010:00Z"

  run "$SCRIPT" --log "$LOG"
  [ "$status" -ne 0 ]
  [[ "$output" != *"Rate:"* ]]
}

@test "fails when the log file does not exist" {
  run "$SCRIPT" --log "${BATS_TEST_TMPDIR}/absent.jsonl"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "rejects an unknown flag rather than ignoring it" {
  add_event PreToolUse default Bash "echo a" "2026-08-04T10:00:00Z"

  run "$SCRIPT" --log "$LOG" --bogus
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option"* ]]
}
