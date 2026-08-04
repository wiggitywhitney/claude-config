#!/usr/bin/env bats
# ABOUTME: Tests for scripts/measure-context-load.sh
# ABOUTME: Verifies each rule and skill is classified by its real loading mechanism, that the totals separate include bytes from bare-rule bytes, and that the inventory file is written rather than only printed

SCRIPT="$BATS_TEST_DIRNAME/../scripts/measure-context-load.sh"

setup() {
    TMPDIR="$(mktemp -d)"
    export FAKE_REPO="$TMPDIR/repo"
    mkdir -p "$FAKE_REPO/rules/languages" \
             "$FAKE_REPO/global" \
             "$FAKE_REPO/docs/research" \
             "$FAKE_REPO/.claude/skills"
    # Callers append their own @-references to this file.
    printf '# Global Standards\n\n' > "$FAKE_REPO/global/CLAUDE.md"
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

INVENTORY() { printf '%s' "$FAKE_REPO/docs/research/claude-config-load-inventory.md"; }

scoped_rule() {
    printf -- '---\npaths: [%s]\n---\n\n# Scoped\n' "$2" > "$FAKE_REPO/rules/$1"
}

bare_rule() {
    printf -- '# Bare\n\nSome guidance.\n' > "$FAKE_REPO/rules/$1"
}

# Appends an @-reference line to global/CLAUDE.md. The optional second argument is
# trailing prose on the same line, which is what exercises the whitespace class.
reference() {
    printf '@~/.claude/%s%s\n' "$1" "${2:-}" >> "$FAKE_REPO/global/CLAUDE.md"
}

# Writes a skill of a given body size. $1 name, $2 frontmatter body, $3 filler bytes.
make_skill() {
    local name="$1" frontmatter="$2" filler="${3:-0}"
    mkdir -p "$FAKE_REPO/.claude/skills/$name"
    local f="$FAKE_REPO/.claude/skills/$name/SKILL.md"
    printf -- '---\n%s\n---\n\n# %s\n\n' "$frontmatter" "$name" > "$f"
    if [[ "$filler" -gt 0 ]]; then
        head -c "$filler" /dev/zero | tr '\0' 'a' >> "$f"
    fi
}

# ------------------------------------------------------------------ classification

@test "a paths:-scoped rule is path_glob_match, not loaded at startup, and does not survive compaction" {
    scoped_rule "pino-gotchas.md" '"**/*pino*"'
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    line="$(grep 'pino-gotchas' "$(INVENTORY)")"
    [[ "$line" == *'path_glob_match'* ]]
    [[ "$line" == *'| no |'* ]]
    [[ "$line" == *'**no**'* ]]
}

@test "an @-referenced rule is include, loaded at startup, and survives compaction" {
    bare_rule "git-workflow.md"
    reference "rules/git-workflow.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    line="$(grep 'git-workflow' "$(INVENTORY)")"
    [[ "$line" == *'include'* ]]
    [[ "$line" == *'| yes | yes |'* ]]
}

@test "the include verdict names compaction survival, not an unverified claim" {
    bare_rule "git-workflow.md"
    reference "rules/git-workflow.md"
    run "$SCRIPT" "$FAKE_REPO"

    # Regression guard: the script once emitted survives='untested' with the note
    # "Compaction behavior unverified", which every re-run wrote over the measured
    # finding in the companion research doc.
    ! grep -q 'untested' "$(INVENTORY)"
    ! grep -q 'Compaction behavior unverified' "$(INVENTORY)"
    grep -q 're-resolved through its parent' "$(INVENTORY)"
}

@test "a rule with neither mechanism is session_start and is reported as a regression" {
    bare_rule "orphan.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    line="$(grep 'orphan' "$(INVENTORY)")"
    [[ "$line" == *'session_start'* ]]
    grep -q '1 bare rule file(s) found' "$(INVENTORY)"
    grep -q 'a non-zero count here is a regression' "$(INVENTORY)"
}

@test "a rule carrying both mechanisms is flagged as a defect" {
    scoped_rule "doubled.md" '"**/*.ts"'
    reference "rules/doubled.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    line="$(grep 'doubled' "$(INVENTORY)")"
    [[ "$line" == *'both — defect'* ]]
    [[ "$line" == *'loads twice'* ]]
}

@test "no bare rules produces the held-at-zero message instead of the regression message" {
    scoped_rule "scoped.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"

    grep -q 'No bare rule files' "$(INVENTORY)"
    ! grep -q 'bare rule file(s) found' "$(INVENTORY)"
}

# ------------------------------------------------------------------ @-reference parsing

@test "an @-path inside a code span is a mention, not an import" {
    bare_rule "mentioned.md"
    # Backticked, exactly how global/CLAUDE.md names reference-pointer rules that are
    # deliberately NOT imported. Misreading these inflates the always-loaded total.
    printf 'Read `@~/.claude/rules/mentioned.md` when debugging.\n' >> "$FAKE_REPO/global/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'mentioned' "$(INVENTORY)")"
    [[ "$line" == *'session_start'* ]]
    [[ "$line" != *'include'* ]]
}

@test "an @-path inside a fenced code block is a mention, not an import" {
    bare_rule "fenced.md"
    {
        printf '```markdown\n'
        printf '@~/.claude/rules/fenced.md\n'
        printf '```\n'
    } >> "$FAKE_REPO/global/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'fenced' "$(INVENTORY)")"
    [[ "$line" == *'session_start'* ]]
}

@test "an @-reference followed by prose on the same line still counts as an import" {
    bare_rule "trailing.md"
    # Regression guard for a portability bug: the pattern used \s, a GNU extension that
    # BSD grep treats as a literal "s". Under the system grep on macOS this reference
    # was misclassified as not-referenced and silently dropped from the always-loaded
    # total. The prose deliberately starts with "s" to catch a reintroduction.
    reference "rules/trailing.md" " see this for details"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'trailing' "$(INVENTORY)")"
    [[ "$line" == *'include'* ]]
}

@test "an @-reference is still found when global/CLAUDE.md exceeds the pipe buffer" {
    bare_rule "early.md"
    reference "rules/early.md"
    # Pad past the 64 KB pipe buffer. With `grep -q`, grep exits as soon as it matches
    # near the top, closing the pipe; sed then dies of SIGPIPE, and under `pipefail`
    # that non-zero status propagates — so a rule that DID match gets classified as
    # unreferenced and silently drops out of the always-loaded total.
    for _ in $(seq 1 2000); do
        printf 'Padding prose to push this file past the pipe buffer boundary.\n' \
            >> "$FAKE_REPO/global/CLAUDE.md"
    done
    [ "$(wc -c < "$FAKE_REPO/global/CLAUDE.md")" -gt 65536 ]

    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    line="$(grep 'early' "$(INVENTORY)")"
    [[ "$line" == *'include'* ]]
}

# The project .claude/CLAUDE.md carries @-imports too. Until 2026-08-04 the script read
# global/CLAUDE.md alone, so rules referenced only from the project file were reported as
# on-demand — understating the always-loaded total by their full byte count.
project_reference() {
    mkdir -p "$FAKE_REPO/.claude"
    printf 'Full reference: @~/.claude/rules/%s\n' "$1" >> "$FAKE_REPO/.claude/CLAUDE.md"
}

@test "a rule @-referenced only from the project CLAUDE.md counts as include" {
    bare_rule "project-only.md"
    project_reference "project-only.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    line="$(grep 'project-only' "$(INVENTORY)")"
    [[ "$line" == *'include'* ]]
    [[ "$line" == *'| yes | yes |'* ]]
}

@test "a project-referenced rule is counted as an import, not as a bare rule" {
    bare_rule "project-only.md"
    project_reference "project-only.md"
    run "$SCRIPT" "$FAKE_REPO"

    # Asserting the always-loaded total alone would pass either way: a misclassified
    # bare rule lands in the same bucket. The bare count is what discriminates, and it
    # matters on its own — issue #108 drove it to zero and a non-zero count reads as a
    # regression.
    grep -q 'No bare rule files' "$(INVENTORY)"

    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    rule_bytes="$(wc -c < "$FAKE_REPO/rules/project-only.md" | tr -d ' ')"
    expected=$((claude_bytes + rule_bytes))
    grep -q "| \*\*Always-loaded total\*\* | \*\*2\*\* | \*\*${expected}\*\* |" "$(INVENTORY)"
}

@test "a paths:-scoped rule also referenced from the project CLAUDE.md is the both-mechanisms defect" {
    scoped_rule "doubled-project.md" '"**/*.sh"'
    project_reference "doubled-project.md"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'doubled-project' "$(INVENTORY)")"
    [[ "$line" == *'both — defect'* ]]
}

@test "a missing project CLAUDE.md is not an error" {
    scoped_rule "fine.md" '"**/*.ts"'
    [ ! -f "$FAKE_REPO/.claude/CLAUDE.md" ]
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
}

@test "a nested rule path is matched" {
    bare_rule "languages/shell.md"
    reference "rules/languages/shell.md"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'languages/shell' "$(INVENTORY)")"
    [[ "$line" == *'include'* ]]
}

@test "paths: below the frontmatter block does not count as scoping" {
    printf -- '---\ndescription: x\n---\n\nThis rule discusses paths: in prose.\n' \
        > "$FAKE_REPO/rules/prose.md"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'prose' "$(INVENTORY)")"
    [[ "$line" == *'session_start'* ]]
}

# ------------------------------------------------------------------ totals

@test "the always-loaded total counts global/CLAUDE.md alongside the rules" {
    bare_rule "one.md"
    reference "rules/one.md"
    run "$SCRIPT" "$FAKE_REPO"

    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    rule_bytes="$(wc -c < "$FAKE_REPO/rules/one.md" | tr -d ' ')"
    expected=$((claude_bytes + rule_bytes))

    grep -q "| \*\*Always-loaded total\*\* | \*\*2\*\* | \*\*${expected}\*\* |" "$(INVENTORY)"
}

@test "on-demand bytes are excluded from the always-loaded total" {
    scoped_rule "ondemand.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"

    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    grep -q "| \*\*Always-loaded total\*\* | \*\*1\*\* | \*\*${claude_bytes}\*\* |" "$(INVENTORY)"
    grep -q '| On-demand path-scoped rules | 1 |' "$(INVENTORY)"
}

@test "global/CLAUDE.md line count is reported against the documented target" {
    run "$SCRIPT" "$FAKE_REPO"
    grep -q '200-line target' "$(INVENTORY)"
}

# ------------------------------------------------------------------ skills

@test "a skill under the cap is not flagged" {
    make_skill "small" 'name: small
description: does a small thing' 100
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep '`small`' "$(INVENTORY)")"
    [[ "$line" == *'| no |'* ]]
    grep -q '| Skills estimated over the 5,000-token cap on both ratios | 0 |' "$(INVENTORY)"
}

@test "a skill over the cap on both ratios is flagged and counted" {
    # 5000 tokens at the prose ratio of 2.8 bytes/token is 14,000 bytes.
    make_skill "huge" 'name: huge
description: does a big thing' 20000
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep '`huge`' "$(INVENTORY)")"
    [[ "$line" == *'over on both estimates'* ]]
    grep -q '| Skills estimated over the 5,000-token cap on both ratios | 1 |' "$(INVENTORY)"
}

@test "a skill over the cap only on the dense ratio is counted separately" {
    # Between the two thresholds: over 5000 tokens at 2.4 bytes/token (12,000 bytes)
    # but under it at 2.8 (14,000 bytes).
    make_skill "borderline" 'name: borderline
description: sits between the two ratios' 13000
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep '`borderline`' "$(INVENTORY)")"
    [[ "$line" == *'over on the dense estimate only'* ]]
    grep -q '| Skills over on the dense ratio only | 1 |' "$(INVENTORY)"
}

@test "disable-model-invocation removes a skill from the startup listing at zero description cost" {
    make_skill "sideeffect" 'name: sideeffect
description: commits and pushes, so it is user-invoked only
disable-model-invocation: true' 100
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep '`sideeffect`' "$(INVENTORY)")"
    [[ "$line" == *'no — user-invoked only'* ]]
    # Its description must not be charged to the startup listing.
    grep -q '| Startup listing cost (descriptions only) | 0 |' "$(INVENTORY)"
}

@test "a skill without disable-model-invocation is charged for its description" {
    make_skill "listed" 'name: listed
description: abc' 10
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep '`listed`' "$(INVENTORY)")"
    [[ "$line" == *'| yes |'* ]]
    grep -q '| Startup listing cost (descriptions only) | 4 |' "$(INVENTORY)"
}

@test "a repo with no skills directory still produces an inventory" {
    rm -rf "$FAKE_REPO/.claude/skills"
    scoped_rule "only.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    grep -q '| Skills | 0 |' "$(INVENTORY)"
}

@test "the cap counts are labeled estimates rather than observations" {
    make_skill "any" 'name: any
description: x' 10
    run "$SCRIPT" "$FAKE_REPO"
    grep -q 'These counts are estimates, not observations' "$(INVENTORY)"
}

# ------------------------------------------------------------------ output contract

@test "the inventory file is written, not merely printed to stdout" {
    scoped_rule "a.md" '"**/*.ts"'
    [ ! -f "$(INVENTORY)" ]
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    [ -f "$(INVENTORY)" ]
    # The banner claims the file is overwritten wholesale, so it has to exist on disk.
    grep -q 'GENERATED FILE' "$(INVENTORY)"
}

@test "status output goes to the real stdout, not into the inventory" {
    scoped_rule "a.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"
    [[ "$output" == *"Wrote"* ]]
    ! grep -q 'Wrote ' "$(INVENTORY)"
}

@test "an existing inventory is replaced rather than appended to" {
    scoped_rule "a.md" '"**/*.ts"'
    printf 'stale content that must not survive\n' > "$(INVENTORY)"
    run "$SCRIPT" "$FAKE_REPO"
    ! grep -q 'stale content' "$(INVENTORY)"
}

@test "a missing rules directory fails loudly instead of writing an empty rules table" {
    scoped_rule "a.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    good_inventory="$(cat "$(INVENTORY)")"

    # find fails inside the process substitution but the loop still exits 0, so without
    # an explicit guard the script replaces a good inventory with one reporting zero
    # rules — indistinguishable from a genuine measurement of an empty rules/ tree.
    rm -rf "$FAKE_REPO/rules"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
    [ "$(cat "$(INVENTORY)")" = "$good_inventory" ]
}

@test "a missing global/CLAUDE.md fails loudly instead of producing an empty inventory" {
    rm "$FAKE_REPO/global/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
    [ ! -f "$(INVENTORY)" ]
}

@test "the generated file points analysis at the findings doc it does not own" {
    scoped_rule "a.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"
    # The split exists so a re-run cannot destroy hand-written analysis.
    grep -q 'claude-config-load-findings.md' "$(INVENTORY)"
    grep -q 'no script writes to' "$(INVENTORY)"
}

@test "running against the real repository succeeds and classifies every rule" {
    REAL_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # Copy the real rules and global CLAUDE.md into the fixture rather than running
    # against the repo itself, so the suite can never rewrite the tracked inventory.
    rm -rf "$FAKE_REPO/rules" "$FAKE_REPO/global"
    cp -R "$REAL_ROOT/rules" "$FAKE_REPO/rules"
    cp -R "$REAL_ROOT/global" "$FAKE_REPO/global"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    # Every rule in the real set must land in exactly one mechanism, so none may be
    # reported as carrying both.
    ! grep -q 'both — defect' "$(INVENTORY)"
}
