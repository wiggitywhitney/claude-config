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

# GNU coreutils shadows BSD stat on this machine, and the two disagree on -f.
stat_mode() {
    stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"
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
    # The path must be followed by whitespace INSIDE the span. An earlier version of
    # this test wrote `@...mentioned.md` with the closing backtick immediately after
    # .md — which the matcher rejects anyway, since a backtick is not whitespace, EOL,
    # or ")". So it passed whether or not strip_code ran, and tested nothing. Mutation
    # testing on 2026-08-04 caught that. This shape mirrors the real case in
    # global/CLAUDE.md, which mentions `@~/.claude/rules/<technology>-gotchas.md syntax`
    # inside a span while genuinely not importing it.
    printf 'Reference rules with `@~/.claude/rules/mentioned.md syntax` in prose.\n' \
        >> "$FAKE_REPO/global/CLAUDE.md"
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
    # Loaded at startup, yes. Surviving compaction is a separate claim and is untested
    # for project-level imports — asserted in its own test below.
    [[ "$line" == *'| yes |'* ]]
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

    # Three always-loaded items now: both CLAUDE.md files and the imported rule. The
    # project CLAUDE.md exists here because project_reference created it.
    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    project_bytes="$(wc -c < "$FAKE_REPO/.claude/CLAUDE.md" | tr -d ' ')"
    rule_bytes="$(wc -c < "$FAKE_REPO/rules/project-only.md" | tr -d ' ')"
    expected=$((claude_bytes + project_bytes + rule_bytes))
    grep -q "| \*\*Always-loaded total\*\* | \*\*3\*\* | \*\*${expected}\*\* |" "$(INVENTORY)"
}

@test "a project-only import is marked untested for compaction, not measured" {
    bare_rule "project-only.md"
    project_reference "project-only.md"
    run "$SCRIPT" "$FAKE_REPO"

    # Only user-level imports were measured surviving compaction. The project CLAUDE.md
    # came back with load_reason: compact but produced no include record for either of
    # its imports, so project-level re-resolution is an open question. Reporting "yes"
    # here would have the script assert what the research explicitly says is unknown —
    # the same defect as the old survives='untested' verdict, inverted.
    line="$(grep 'project-only' "$(INVENTORY)")"
    [[ "$line" == *'untested'* ]]
    [[ "$line" != *'| yes | yes |'* ]]
}

@test "a rule referenced from both CLAUDE.md files keeps the measured verdict" {
    bare_rule "both-sources.md"
    reference "rules/both-sources.md"
    project_reference "both-sources.md"
    run "$SCRIPT" "$FAKE_REPO"

    line="$(grep 'both-sources' "$(INVENTORY)")"
    [[ "$line" == *'| yes | yes |'* ]]
    [[ "$line" != *'untested'* ]]
}

@test "the project CLAUDE.md counts toward the always-loaded total" {
    scoped_rule "ondemand.md" '"**/*.ts"'
    mkdir -p "$FAKE_REPO/.claude"
    printf '# Project instructions\n' > "$FAKE_REPO/.claude/CLAUDE.md"
    run "$SCRIPT" "$FAKE_REPO"

    # The project CLAUDE.md is itself always-loaded — the compaction probe recorded it
    # returning with load_reason: compact. Counting global/CLAUDE.md but not this one
    # understates the always-loaded set by its full size, which is the same class of
    # omission as finding 3 (an import living outside the repo).
    global_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    project_bytes="$(wc -c < "$FAKE_REPO/.claude/CLAUDE.md" | tr -d ' ')"
    expected=$((global_bytes + project_bytes))
    grep -q "| \*\*Always-loaded total\*\* | \*\*2\*\* | \*\*${expected}\*\* |" "$(INVENTORY)"
}

@test "the project CLAUDE.md is reported as its own line item" {
    mkdir -p "$FAKE_REPO/.claude"
    printf '# Project instructions\n' > "$FAKE_REPO/.claude/CLAUDE.md"
    scoped_rule "a.md" '"**/*.ts"'
    run "$SCRIPT" "$FAKE_REPO"
    grep -q '`.claude/CLAUDE.md`' "$(INVENTORY)"
}

@test "a repo with no project CLAUDE.md counts only the global one" {
    scoped_rule "a.md" '"**/*.ts"'
    [ ! -f "$FAKE_REPO/.claude/CLAUDE.md" ]
    run "$SCRIPT" "$FAKE_REPO"

    global_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    grep -q "| \*\*Always-loaded total\*\* | \*\*1\*\* | \*\*${global_bytes}\*\* |" "$(INVENTORY)"
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
    # `paths:` must sit at the start of a line below the block, or the test proves
    # nothing: an earlier version wrote "This rule discusses paths: in prose", which no
    # ^paths: pattern matches regardless of where the frontmatter boundary is drawn.
    # Mutation testing on 2026-08-04 caught that.
    printf -- '---\ndescription: x\n---\n\npaths: ["**/*.ts"] written in prose, not frontmatter.\n' \
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
    # 3, not 4: the whitespace separating "description:" from its value is YAML
    # syntax, not description content, and must not be charged to the budget.
    grep -q '| Startup listing cost (descriptions only) | 3 |' "$(INVENTORY)"
}

@test "extra whitespace after description: is not charged to the listing cost" {
    make_skill "padded" 'name: padded
description:      abc' 10
    run "$SCRIPT" "$FAKE_REPO"

    grep -q '| Startup listing cost (descriptions only) | 3 |' "$(INVENTORY)"
}

@test "a non-ASCII description is measured in bytes, not characters" {
    # "café" is 4 characters but 5 bytes — é is two bytes in UTF-8. The report
    # labels this column as bytes, so the byte count is the correct answer.
    make_skill "accented" 'name: accented
description: café' 10
    run "$SCRIPT" "$FAKE_REPO"

    grep -q '| Startup listing cost (descriptions only) | 5 |' "$(INVENTORY)"
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
    # The project CLAUDE.md must come along, or this test cannot see the very class of
    # defect that motivated scanning it — a rule imported there while also paths:-scoped
    # would look clean here.
    mkdir -p "$FAKE_REPO/.claude"
    cp "$REAL_ROOT/.claude/CLAUDE.md" "$FAKE_REPO/.claude/CLAUDE.md"

    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]
    # Every rule in the real set must land in exactly one mechanism.
    ! grep -q 'both — defect' "$(INVENTORY)"
    # And none may be bare. Checking only the both-defect case would let a new unscoped
    # rule — the #108 regression — pass unnoticed.
    ! grep -q 'session_start' "$(INVENTORY)"
    grep -q 'No bare rule files' "$(INVENTORY)"

    # The three assertions above are all negative — they pass if traversal skips a
    # rule file or a whole nested directory, because a rule that was never visited
    # cannot be misclassified. Assert positively that every copied rule has a row,
    # so a traversal that silently stops being recursive fails here.
    local missing=0 rel
    while IFS= read -r rel; do
        if ! grep -qF -- "\`$rel\`" "$(INVENTORY)"; then
            printf 'no inventory row for %s\n' "$rel" >&2
            missing=1
        fi
    done < <(cd "$FAKE_REPO" && find rules -name '*.md' -not -name 'README.md' | sort)
    [ "$missing" -eq 0 ]
}

# The #108 baseline covered global/CLAUDE.md plus its own imports and nothing else.
# Before 2026-08-04 the script summed global-sourced and project-sourced includes into one
# figure and compared that against the baseline, so adding a project-level import — a real
# import in the wrong column — reported as growth in the global set. The two tests below
# pin the split. All three tests added here were run against the pre-split script and
# observed to fail, then against the current one and observed to pass.
@test "a project-sourced import is excluded from the #108 baseline comparison" {
    bare_rule "project-only.md"
    project_reference "project-only.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    # The comparison must count global/CLAUDE.md alone here, since no rule is referenced
    # from it. Were the project import folded in, "measured now" would exceed this.
    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    grep -q "| Same components measured now | ${claude_bytes} |" "$(INVENTORY)"
    grep -q "| Drift | $((claude_bytes - 56994)) |" "$(INVENTORY)"
}

@test "global-sourced and project-sourced imports are reported on separate budget rows" {
    bare_rule "from-global.md"
    reference "rules/from-global.md"
    bare_rule "from-project.md"
    project_reference "from-project.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    global_rule_bytes="$(wc -c < "$FAKE_REPO/rules/from-global.md" | tr -d ' ')"
    project_rule_bytes="$(wc -c < "$FAKE_REPO/rules/from-project.md" | tr -d ' ')"
    # Distinct byte counts per source, not one merged figure.
    grep -q "referenced rules from \`global/CLAUDE.md\` (\`include\`) | ${global_rule_bytes} |" "$(INVENTORY)"
    grep -q "referenced rules from \`.claude/CLAUDE.md\` (\`include\`) | ${project_rule_bytes} |" "$(INVENTORY)"
}

# The budget table omitted .claude/CLAUDE.md entirely while the rule totals counted it,
# so the generated budget reproduced the 6,609-byte undercount that scanning the project
# file was supposed to have fixed. A budget is the artifact a byte target gets set from,
# which makes an omission there worse than one in a status line.
@test "the always-loaded budget includes the project CLAUDE.md and its imports" {
    bare_rule "from-project.md"
    project_reference "from-project.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    project_bytes="$(wc -c < "$FAKE_REPO/.claude/CLAUDE.md" | tr -d ' ')"
    grep -q "| \`.claude/CLAUDE.md\` | ${project_bytes} |" "$(INVENTORY)"

    # And the stated total must actually contain those bytes, not just list the row.
    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    rule_bytes="$(wc -c < "$FAKE_REPO/rules/from-project.md" | tr -d ' ')"
    grep -q "Configuration and rules subtotal:\*\* $((claude_bytes + project_bytes + rule_bytes)) bytes" "$(INVENTORY)"
}

# A rule that is both paths:-scoped and @-imported is a defect the inventory flags. Its
# compaction verdict still has to follow the import's source: only user-level imports were
# observed re-resolving, so a defect imported solely from the project CLAUDE.md must read
# untested. Reporting "yes" there asserts a measured verdict for the one case the research
# lists as unknown — inside the row whose whole purpose is to flag a problem.
@test "a both-mechanisms rule imported only from the project CLAUDE.md is untested for compaction" {
    scoped_rule "dual-project.md" '"**/*.ts"'
    project_reference "dual-project.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    line="$(grep 'dual-project' "$(INVENTORY)")"
    [[ "$line" == *'both — defect'* ]]
    [[ "$line" == *'untested'* ]]
}

@test "a both-mechanisms rule imported from the global CLAUDE.md still reports survives yes" {
    scoped_rule "dual-global.md" '"**/*.ts"'
    reference "rules/dual-global.md"
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    # The global case has a measured verdict; splitting by source must not downgrade it.
    line="$(grep 'dual-global' "$(INVENTORY)")"
    [[ "$line" == *'both — defect'* ]]
    [[ "$line" != *'untested'* ]]
}

# Skill descriptions load into the startup listing every session, so they are part of the
# real always-loaded cost. The budget listed them as a component and then omitted them
# from the stated total, which made the total contradict its own table.
@test "the budget separates the configuration subtotal from the total including skills" {
    bare_rule "from-project.md"
    project_reference "from-project.md"
    make_skill "listed-skill" "description: A skill whose description loads at startup" 400
    run "$SCRIPT" "$FAKE_REPO"
    [ "$status" -eq 0 ]

    claude_bytes="$(wc -c < "$FAKE_REPO/global/CLAUDE.md" | tr -d ' ')"
    project_bytes="$(wc -c < "$FAKE_REPO/.claude/CLAUDE.md" | tr -d ' ')"
    rule_bytes="$(wc -c < "$FAKE_REPO/rules/from-project.md" | tr -d ' ')"
    config_subtotal=$((claude_bytes + project_bytes + rule_bytes))

    # The subtotal keeps the meaning earlier measurements and Decision 42 refer to.
    grep -q "Configuration and rules subtotal:\*\* ${config_subtotal} bytes" "$(INVENTORY)"

    # And the second figure must exceed it by exactly the skill-description bytes, so a
    # skill listed in the table can never again be absent from the total.
    desc_line="$(grep 'Skill descriptions, this repo only' "$(INVENTORY)")"
    desc_bytes="$(printf '%s' "$desc_line" | awk -F'|' '{gsub(/ /,"",$3); print $3}')"
    [ "$desc_bytes" -gt 0 ]
    grep -q "including skill descriptions:\*\* $((config_subtotal + desc_bytes)) bytes" "$(INVENTORY)"
}

@test "aborts when a CLAUDE.md exists but cannot be scanned for @-references" {
    scoped_rule "scoped.md" '"**/*.ts"'
    if [ "$(id -u)" -eq 0 ]; then skip "chmod 000 does not block root"; fi
    orig_mode="$(stat_mode "$FAKE_REPO/global/CLAUDE.md")"
    chmod 000 "$FAKE_REPO/global/CLAUDE.md"
    run bash "$SCRIPT" "$FAKE_REPO"
    chmod "$orig_mode" "$FAKE_REPO/global/CLAUDE.md"
    [ "$status" -ne 0 ]
    [[ "$output" == *"failed to scan"* ]]
}
