#!/usr/bin/env bats
# ABOUTME: Tests for scripts/audit-enumerate.sh
# ABOUTME: Verifies the four A4 audit enumerations emit newline-delimited JSON reproducibly, one object per row

# Required for the --separate-stderr flag on `run`, used to prove stdout carries only JSON.
bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../scripts/audit-enumerate.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    export FAKE_REPO="$TMPDIR/repo"
    mkdir -p "$FAKE_REPO/rules" "$FAKE_REPO/global" "$FAKE_REPO/hooks/git" \
             "$FAKE_REPO/scripts" "$FAKE_REPO/.claude/skills"
    printf '# Global\n' > "$FAKE_REPO/global/CLAUDE.md"
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

# Writes a Claude Code settings file declaring the given hook event and command.
settings_with_hook() {
    local event="$1" command="$2"
    mkdir -p "$FAKE_REPO/config"
    cat > "$FAKE_REPO/config/settings.json" <<EOF
{
  "hooks": {
    "$event": [
      { "hooks": [ { "type": "command", "command": "$command" } ] }
    ]
  }
}
EOF
}

# Writes a skill directory with a SKILL.md carrying the given frontmatter name.
skill() {
    local name="$1"
    mkdir -p "$FAKE_REPO/.claude/skills/$name"
    printf -- '---\nname: %s\ndescription: Does a thing.\n---\n\n# %s\n' "$name" "$name" \
        > "$FAKE_REPO/.claude/skills/$name/SKILL.md"
}

# --- Interface contract -------------------------------------------------------

@test "exits nonzero and names the valid subcommands when given none" {
    run "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"hooks"* ]]
    [[ "$output" == *"skills"* ]]
    [[ "$output" == *"repos"* ]]
    [[ "$output" == *"pairs"* ]]
}

@test "exits nonzero on an unrecognized subcommand" {
    run "$SCRIPT" definitely-not-a-subcommand "$FAKE_REPO"
    [ "$status" -ne 0 ]
}

@test "accepts all four documented subcommands" {
    for sub in hooks skills repos pairs; do
        run "$SCRIPT" "$sub" "$FAKE_REPO"
        [ "$status" -eq 0 ]
    done
}

# --- Output format: newline-delimited JSON, stdout only ----------------------

@test "hooks emits one JSON object per line with no wrapping array" {
    settings_with_hook "PreToolUse" "scripts/check-aboutme.sh"
    run "$SCRIPT" hooks "$FAKE_REPO"
    [ "$status" -eq 0 ]
    # Every line must parse as a standalone JSON object.
    while IFS= read -r line; do
        [ -n "$line" ]
        echo "$line" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert isinstance(o, dict)'
    done <<< "$output"
    [[ "$output" != "["* ]]
}

@test "skills emits one JSON object per line with no wrapping array" {
    skill "prd-next"
    run "$SCRIPT" skills "$FAKE_REPO"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin if l.strip()]'
    [[ "$output" != "["* ]]
}

@test "progress and warnings go to stderr, keeping stdout pipeable" {
    settings_with_hook "PreToolUse" "scripts/check-aboutme.sh"
    run --separate-stderr "$SCRIPT" hooks "$FAKE_REPO"
    [ "$status" -eq 0 ]
    # stdout carries only JSON — every line parses.
    echo "$stdout" | python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin if l.strip()]'
}

@test "emits nothing on stdout when there is nothing to enumerate" {
    run "$SCRIPT" skills "$FAKE_REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- Reproducibility ---------------------------------------------------------

@test "re-running a subcommand reproduces byte-identical output" {
    skill "prd-next"
    skill "issue-start"
    run "$SCRIPT" skills "$FAKE_REPO"
    first="$output"
    run "$SCRIPT" skills "$FAKE_REPO"
    [ "$output" = "$first" ]
}

@test "output order is deterministic regardless of filesystem order" {
    skill "zebra"
    skill "alpha"
    skill "middle"
    run "$SCRIPT" skills "$FAKE_REPO"
    names="$(echo "$output" | python3 -c 'import json,sys; print(" ".join(json.loads(l)["name"] for l in sys.stdin if l.strip()))')"
    [ "$names" = "alpha middle zebra" ]
}

# --- hooks subcommand content ------------------------------------------------

@test "hooks records the event name and the command for each hook" {
    settings_with_hook "PostToolUse" "scripts/suggest-write-prompt.sh"
    run "$SCRIPT" hooks "$FAKE_REPO"
    [[ "$output" == *"PostToolUse"* ]]
    [[ "$output" == *"suggest-write-prompt.sh"* ]]
}

@test "hooks reports whether the hook command exists on disk" {
    settings_with_hook "PreToolUse" "scripts/gone-missing.sh"
    run "$SCRIPT" hooks "$FAKE_REPO"
    exists="$(echo "$output" | python3 -c 'import json,sys; print(json.loads(sys.stdin.readline())["command_exists"])')"
    [ "$exists" = "False" ]
}

@test "hooks marks a hook command that does exist" {
    printf '#!/usr/bin/env bash\n' > "$FAKE_REPO/scripts/real.sh"
    settings_with_hook "PreToolUse" "scripts/real.sh"
    run "$SCRIPT" hooks "$FAKE_REPO"
    exists="$(echo "$output" | python3 -c 'import json,sys; print(json.loads(sys.stdin.readline())["command_exists"])')"
    [ "$exists" = "True" ]
}

@test "hooks includes native git hooks alongside Claude Code hooks" {
    printf '#!/usr/bin/env bash\n' > "$FAKE_REPO/hooks/git/pre-commit"
    run "$SCRIPT" hooks "$FAKE_REPO"
    [[ "$output" == *"pre-commit"* ]]
    [[ "$output" == *"git"* ]]
}

# --- skills subcommand content -----------------------------------------------

@test "skills records name, path, and byte size" {
    skill "prd-done"
    run "$SCRIPT" skills "$FAKE_REPO"
    obj="$(echo "$output" | head -1)"
    echo "$obj" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert o["name"]=="prd-done"; assert o["bytes"]>0; assert "SKILL.md" in o["path"]'
}

@test "skills treats a .claude/commands file as a skill definition" {
    mkdir -p "$FAKE_REPO/.claude/commands"
    printf '# Deploy\n' > "$FAKE_REPO/.claude/commands/deploy.md"
    run "$SCRIPT" skills "$FAKE_REPO"
    [[ "$output" == *"deploy"* ]]
    [[ "$output" == *"command"* ]]
}

@test "skills flags the name collision where a command and a skill both define one slash command" {
    skill "deploy"
    mkdir -p "$FAKE_REPO/.claude/commands"
    printf '# Deploy\n' > "$FAKE_REPO/.claude/commands/deploy.md"
    run "$SCRIPT" skills "$FAKE_REPO"
    [[ "$output" == *"collision"* ]]
}

# --- pairs subcommand content ------------------------------------------------

@test "pairs derives a v1-yolo variant beside a SKILL.md as a coupled pair" {
    skill "prd-done"
    printf -- '---\nname: prd-done\n---\n\n# YOLO\n' \
        > "$FAKE_REPO/.claude/skills/prd-done/SKILL.v1-yolo.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SKILL.v1-yolo.md"* ]]
    [[ "$output" == *"yolo-variant"* ]]
}

@test "pairs derives a rule naming a script path as a coupled pair" {
    printf -- '---\npaths: ["**/*.ts"]\n---\n\nRun `scripts/check-rule-frontmatter.sh` to verify.\n' \
        > "$FAKE_REPO/rules/some-rule.md"
    printf '#!/usr/bin/env bash\n' > "$FAKE_REPO/scripts/check-rule-frontmatter.sh"
    run "$SCRIPT" pairs "$FAKE_REPO"
    [[ "$output" == *"check-rule-frontmatter.sh"* ]]
    [[ "$output" == *"rule-names-script"* ]]
}

@test "pairs flags a rule naming a script that does not exist" {
    printf -- '---\npaths: ["**/*.ts"]\n---\n\nRun `scripts/vanished.sh` first.\n' \
        > "$FAKE_REPO/rules/stale-rule.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    [[ "$output" == *"vanished.sh"* ]]
    broken="$(echo "$output" | python3 -c 'import json,sys; print(any(not json.loads(l).get("target_exists", True) for l in sys.stdin if l.strip()))')"
    [ "$broken" = "True" ]
}

@test "pairs resolves a skill-relative script path against the skill's own directory" {
    # A SKILL.md saying `bash scripts/foo.sh` means the skill's own scripts/ subdirectory, not the
    # repo's. Resolving only against the repo root reports a live reference as broken.
    skill "verify"
    mkdir -p "$FAKE_REPO/.claude/skills/verify/scripts"
    printf '#!/usr/bin/env bash\n' > "$FAKE_REPO/.claude/skills/verify/scripts/detect-project.sh"
    printf 'Run `scripts/detect-project.sh` to begin.\n' >> "$FAKE_REPO/.claude/skills/verify/SKILL.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    [ "$status" -eq 0 ]
    broken="$(echo "$output" | python3 -c 'import json,sys; print(any(not json.loads(l).get("target_exists", True) for l in sys.stdin if l.strip()))')"
    [ "$broken" = "False" ]
}

@test "pairs records which base a skill-relative reference resolved against" {
    skill "verify"
    mkdir -p "$FAKE_REPO/.claude/skills/verify/scripts"
    printf '#!/usr/bin/env bash\n' > "$FAKE_REPO/.claude/skills/verify/scripts/detect-project.sh"
    printf 'Run `scripts/detect-project.sh` to begin.\n' >> "$FAKE_REPO/.claude/skills/verify/SKILL.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    [[ "$output" == *"skills/verify/scripts/detect-project.sh"* ]]
}

@test "pairs still flags a skill-relative reference that resolves nowhere" {
    skill "write-docs"
    printf 'Run `scripts/absent.sh` to begin.\n' >> "$FAKE_REPO/.claude/skills/write-docs/SKILL.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    broken="$(echo "$output" | python3 -c 'import json,sys; print(any(not json.loads(l).get("target_exists", True) for l in sys.stdin if l.strip()))')"
    [ "$broken" = "True" ]
}

@test "pairs does not match a script path out of the middle of a longer path" {
    # `~/.claude/skills/verify/scripts/detect-project.sh` must not be read as a repo-relative
    # `scripts/detect-project.sh`. Matching a suffix of a longer path invents a broken reference.
    skill "write-docs"
    printf 'Run `~/.claude/skills/verify/scripts/detect-project.sh` if available.\n' \
        >> "$FAKE_REPO/.claude/skills/write-docs/SKILL.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    [ "$status" -eq 0 ]
    [[ "$output" != *"detect-project.sh"* ]]
}

@test "pairs labels every row with the derivation class that produced it" {
    skill "prd-done"
    printf -- '---\nname: prd-done\n---\n' > "$FAKE_REPO/.claude/skills/prd-done/SKILL.v1-yolo.md"
    run "$SCRIPT" pairs "$FAKE_REPO"
    echo "$output" | python3 -c 'import json,sys; [json.loads(l)["derivation"] for l in sys.stdin if l.strip()]'
}

# --- repos subcommand content ------------------------------------------------

@test "repos enumerates every directory with a .claude directory under the search root" {
    mkdir -p "$TMPDIR/search/repo-a/.claude" "$TMPDIR/search/repo-b/.claude/skills"
    mkdir -p "$TMPDIR/search/not-a-repo"
    run "$SCRIPT" repos "$FAKE_REPO" "$TMPDIR/search"
    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-a"* ]]
    [[ "$output" == *"repo-b"* ]]
    [[ "$output" != *"not-a-repo"* ]]
}

@test "repos finds a repo carrying only settings.local.json and no skills directory" {
    mkdir -p "$TMPDIR/search/settings-only/.claude"
    printf '{}' > "$TMPDIR/search/settings-only/.claude/settings.local.json"
    run "$SCRIPT" repos "$FAKE_REPO" "$TMPDIR/search"
    [[ "$output" == *"settings-only"* ]]
}

@test "repos separates what is installed from what actually runs" {
    mkdir -p "$TMPDIR/search/repo-c/.claude/skills/prd-done"
    printf -- '---\nname: prd-done\n---\n' > "$TMPDIR/search/repo-c/.claude/skills/prd-done/SKILL.md"
    run "$SCRIPT" repos "$FAKE_REPO" "$TMPDIR/search"
    obj="$(echo "$output" | python3 -c 'import json,sys; import json as j; [print(l.strip()) for l in sys.stdin if "repo-c" in l]' | head -1)"
    echo "$obj" | python3 -c 'import json,sys; o=json.load(sys.stdin); assert "skills_installed" in o; assert "skills_effective" in o'
}

@test "repos records an inert YOLO symlink as installed but not effective" {
    mkdir -p "$TMPDIR/search/repo-d/.claude/skills"
    printf -- '---\nname: prd-done\n---\n' > "$TMPDIR/yolo-source.md"
    ln -s "$TMPDIR/yolo-source.md" "$TMPDIR/search/repo-d/.claude/skills/prd-done.md"
    run "$SCRIPT" repos "$FAKE_REPO" "$TMPDIR/search"
    [ "$status" -eq 0 ]
    [[ "$output" == *"repo-d"* ]]
}

@test "repos does not modify any repo it enumerates" {
    mkdir -p "$TMPDIR/search/repo-e/.claude"
    printf '{}' > "$TMPDIR/search/repo-e/.claude/settings.local.json"
    before="$(find "$TMPDIR/search" -type f -exec shasum {} \; | sort)"
    run "$SCRIPT" repos "$FAKE_REPO" "$TMPDIR/search"
    after="$(find "$TMPDIR/search" -type f -exec shasum {} \; | sort)"
    [ "$before" = "$after" ]
}
