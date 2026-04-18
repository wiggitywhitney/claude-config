#!/usr/bin/env bats
# ABOUTME: Tests for scripts/cost-tracker.sh
# ABOUTME: Verifies JSONL parsing, cost calculation, grouping, filtering, and output format

SCRIPT="$BATS_TEST_DIRNAME/../scripts/cost-tracker.sh"

# Emit one assistant JSONL record to stdout
make_record() {
    local session_id="$1" cwd="$2" model="$3"
    local input="$4" cc="$5" cr="$6" output="$7" timestamp="$8"
    printf '{"type":"assistant","sessionId":"%s","cwd":"%s","gitBranch":"main","timestamp":"%s","message":{"model":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' \
        "$session_id" "$cwd" "$timestamp" "$model" "$input" "$cc" "$cr" "$output"
}

setup() {
    PROJECTS_DIR=$(mktemp -d)
    chmod +x "$SCRIPT"
    # Dynamic timestamps — avoids hardcoded dates becoming stale
    RECENT_TS=$(date -u +"%Y-%m-%dT10:00:00Z")
    OLD_TS="2025-01-01T00:00:00Z"
}

teardown() {
    rm -rf "$PROJECTS_DIR"
}

# ── Basic exit behavior ───────────────────────────────────────────────────────

@test "exits 0 when projects directory is empty" {
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
}

@test "exits 0 when projects directory does not exist" {
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR/nope\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
}

@test "shows no-data message when directory has no JSONL files" {
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"No sessions"* ]]
}

# ── Cost calculation per model ────────────────────────────────────────────────

@test "calculates correct cost for 1M Sonnet 4.6 input tokens" {
    # $3.00/MTok input → $3.00
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$3.00'* ]]
}

@test "calculates correct cost for 1M Opus 4.7 input tokens" {
    # $5.00/MTok input → $5.00 (not $15 — pricing updated since forrester sessions.py)
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-opus-4-7" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$5.00'* ]]
}

@test "calculates correct cost for 1M Opus 4.6 input tokens" {
    # $5.00/MTok input → $5.00
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-opus-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$5.00'* ]]
}

@test "calculates correct cost for 1M Haiku 4.5 input tokens" {
    # $1.00/MTok input → $1.00 (not $0.80 — pricing updated since forrester sessions.py)
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-haiku-4-5-20251001" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$1.00'* ]]
}

@test "accumulates tokens from multiple messages in the same session" {
    # Two messages in one session: 500k + 500k = 1M input → $3.00 Sonnet
    mkdir -p "$PROJECTS_DIR/proj-a"
    {
        make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 500000 0 0 0 "$RECENT_TS"
        make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 500000 0 0 0 "2026-04-18T10:01:00Z"
    } > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$3.00'* ]]
}

@test "calculates cache create cost at correct rate for Sonnet 4.6" {
    # $3.75/MTok cache create → $3.75
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 0 1000000 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$3.75'* ]]
}

@test "calculates output token cost at correct rate for Sonnet 4.6" {
    # $15.00/MTok output → $15.00
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 0 0 0 1000000 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$15.00'* ]]
}

# ── Session count ─────────────────────────────────────────────────────────────

@test "shows correct session count" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    {
        make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS"
        make_record "s2" "/repos/proj-a" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS"
    } > "$PROJECTS_DIR/proj-a/sessions.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"2 session"* ]]
}

# ── By-repo breakdown ─────────────────────────────────────────────────────────

@test "shows by-repo section" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"By Repo"* ]]
    [[ "$output" == *"proj-a"* ]]
}

@test "lists multiple repos in by-repo section" {
    mkdir -p "$PROJECTS_DIR/proj-a" "$PROJECTS_DIR/proj-b"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    make_record "s2" "/repos/proj-b" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-b/s2.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"proj-a"* ]]
    [[ "$output" == *"proj-b"* ]]
}

# ── By-model breakdown ────────────────────────────────────────────────────────

@test "shows by-model section" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"By Model"* ]]
    [[ "$output" == *"claude-sonnet-4-6"* ]]
}

# ── Cache hit ratio ───────────────────────────────────────────────────────────

@test "shows cache hit ratio" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    # 300k cache_read, 700k input → 30% cache ratio
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 700000 0 300000 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cache"* ]]
    [[ "$output" == *"30%"* ]]
}

@test "flags low cache ratio when below 70 percent" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    # 0% cache read → 0% ratio, should show warning
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"⚠"* ]]
}

@test "shows good indicator when cache ratio is 70 percent or above" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    # 800k cache_read, 200k input → 80% cache ratio
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 200000 0 800000 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"✓"* ]]
}

# ── Date filtering ────────────────────────────────────────────────────────────

@test "excludes sessions older than the requested day range" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    {
        # Old record: 2025-01-01 — well outside any reasonable --days window
        make_record "s-old" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "2025-01-01T00:00:00Z"
        # Recent record: today
        make_record "s-new" "/repos/proj-a" "claude-sonnet-4-6" 1000 0 0 0 "$RECENT_TS"
    } > "$PROJECTS_DIR/proj-a/sessions.jsonl"
    # With --days 7 only the recent session should count; total cost << $3.00
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\" 7"
    [ "$status" -eq 0 ]
    # If old session were included, total would be ~$3.00; recent-only is ~$0.000003
    [[ "$output" != *'$3.'* ]]
}

@test "includes sessions within the requested day range" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\" 7"
    [ "$status" -eq 0 ]
    [[ "$output" == *'$3.00'* ]]
}

# ── --repo filter ─────────────────────────────────────────────────────────────

@test "--repo filter shows only the specified repo" {
    mkdir -p "$PROJECTS_DIR/proj-a" "$PROJECTS_DIR/proj-b"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    make_record "s2" "/repos/proj-b" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-b/s2.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\" --repo proj-a"
    [ "$status" -eq 0 ]
    [[ "$output" == *"proj-a"* ]]
    [[ "$output" != *"proj-b"* ]]
}

@test "--repo filter with no matching sessions shows no-data message" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\" --repo nonexistent"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No sessions"* ]]
}

# ── Report header ─────────────────────────────────────────────────────────────

@test "report header includes the day range" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 100 0 0 50 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\" 14"
    [ "$status" -eq 0 ]
    [[ "$output" == *"14"* ]]
}

# ── Robustness ────────────────────────────────────────────────────────────────

@test "skips non-assistant record types without error" {
    mkdir -p "$PROJECTS_DIR/proj-a"
    {
        printf '{"type":"user","sessionId":"s1","cwd":"/repos/proj-a","timestamp":"$RECENT_TS","message":{"content":[]}}\n'
        printf '{"type":"permission-mode","permissionMode":"default","sessionId":"s1"}\n'
        make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS"
    } > "$PROJECTS_DIR/proj-a/s1.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    [[ "$output" == *'$3.00'* ]]
}

@test "--repo without a value prints error and exits non-zero" {
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\" --repo"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a value"* ]]
}

@test "handles JSONL files across multiple project subdirectories" {
    mkdir -p "$PROJECTS_DIR/proj-a" "$PROJECTS_DIR/proj-b"
    make_record "s1" "/repos/proj-a" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-a/s1.jsonl"
    make_record "s2" "/repos/proj-b" "claude-sonnet-4-6" 1000000 0 0 0 "$RECENT_TS" \
        > "$PROJECTS_DIR/proj-b/s2.jsonl"
    run bash -c "CLAUDE_PROJECTS_DIR=\"$PROJECTS_DIR\" \"$SCRIPT\""
    [ "$status" -eq 0 ]
    # Two sessions × $3.00 = $6.00
    [[ "$output" == *'$6.00'* ]]
}
