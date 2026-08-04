#!/usr/bin/env bash
# ABOUTME: Verifies every rules/ file has exactly one loading mechanism.
# ABOUTME: A rule is either paths:-scoped or @-referenced from a CLAUDE.md — never both, never neither.

set -uo pipefail

# Resolve the repo root so the script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"

readonly RULES_DIR="$REPO_ROOT/rules"
readonly CLAUDE_MD="$REPO_ROOT/global/CLAUDE.md"

# Every CLAUDE.md that can carry @-imports, not just the global one. Until 2026-08-04
# this script read global/CLAUDE.md alone, so rules/hooks-reference.md and
# rules/bats-bash-testing.md — both paths:-scoped AND @-referenced from
# .claude/CLAUDE.md — passed as correctly configured. ~/.claude/rules symlinks to this
# repo's rules/, so those imports resolve to the same files carrying the frontmatter,
# which is the exact both-mechanisms case this check exists to reject. A check whose
# notion of "the always-loaded set" comes from one file cannot see a violation living
# in another, and it reports a confident pass while doing so.
readonly PROJECT_CLAUDE_MD="$REPO_ROOT/.claude/CLAUDE.md"

# No exemptions. rules/README.md was exempt until 2026-08-03 on the stated grounds
# that it "is never loaded by either mechanism" — which was false. Measured with an
# InstructionsLoaded hook, it loaded at session_start on every session, costing 7,477
# bytes, because an unscoped .md file in rules/ loads unconditionally. The exemption is
# why nobody noticed for four months: the one check that would have caught it had been
# told to skip the one file that was wrong. It now carries paths: frontmatter and is
# held to the same requirement as every other rule.
readonly EXEMPT_BASENAMES=()

if [[ ! -d "$RULES_DIR" ]]; then
    echo "check-rule-frontmatter: no rules directory at $RULES_DIR" >&2
    exit 1
fi

if [[ ! -f "$CLAUDE_MD" ]]; then
    echo "check-rule-frontmatter: no global/CLAUDE.md at $CLAUDE_MD" >&2
    exit 1
fi

# Collect the @-referenced set from each CLAUDE.md rather than hardcoding a list, so
# adding or removing an @-reference needs no corresponding edit here. Kept per-source
# rather than merged, so a failure message can name the file to edit — "pick one" is
# not actionable when the reader does not know which of two files holds the reference.
# Code spans and fenced blocks are stripped before scanning, matching what Claude Code's
# import parser does and what measure-context-load.sh has always done. Without this, a
# rule mentioned inside a markdown example — which global/CLAUDE.md does deliberately,
# to name reference pointers without importing them — is read as a real import, and a
# correctly paths:-scoped rule gets rejected as carrying both mechanisms.
scan_references() {
    local md="$1"
    [[ -f "$md" ]] || return 0
    sed -e '/^[[:space:]]*```/,/^[[:space:]]*```/d' "$md" \
        | sed -e 's/`[^`]*`//g' \
        | grep -o '@~/\.claude/rules/[A-Za-z0-9._/-]*\.md' \
        | sed 's|@~/\.claude/rules/||' | sort -u
}

global_referenced=$(scan_references "$CLAUDE_MD")
project_referenced=$(scan_references "$PROJECT_CLAUDE_MD")

# Echoes the source path when referenced, empty otherwise.
reference_source() {
    local rel="$1"
    if printf '%s\n' "$global_referenced" | grep -qxF "$rel"; then
        echo "global/CLAUDE.md"
    elif printf '%s\n' "$project_referenced" | grep -qxF "$rel"; then
        echo ".claude/CLAUDE.md"
    fi
}

is_exempt() {
    local base
    base="$(basename "$1")"
    local exempt
    # The ${arr[@]+...} guard is required, not stylistic: under `set -u`, bash 3.2 —
    # which is what /bin/bash is on macOS — treats "${arr[@]}" on an empty array as an
    # unbound variable and aborts. The array is currently empty, so without this the
    # script fails on every run under /bin/bash while passing under Homebrew bash 5.
    for exempt in ${EXEMPT_BASENAMES[@]+"${EXEMPT_BASENAMES[@]}"}; do
        [[ "$base" == "$exempt" ]] && return 0
    done
    return 1
}

failures=0

report() {
    echo "FAIL  rules/$1: $2" >&2
    failures=$((failures + 1))
}

while IFS= read -r file; do
    is_exempt "$file" && continue

    rel="${file#"$RULES_DIR"/}"

    # A paths: key only counts as frontmatter when it sits inside a leading
    # `---` block. A stray "paths:" in prose must not satisfy the check.
    has_paths=false
    wildcard=false
    if [[ "$(head -n 1 "$file")" == "---" ]]; then
        frontmatter=$(awk 'NR==1 && $0=="---" {next} /^---$/ {exit} {print}' "$file")
        if printf '%s\n' "$frontmatter" | grep -q '^paths:'; then
            has_paths=true
            # Catch `**/*` in every YAML shape a paths list can legally take:
            # an inline list on the key line, single- or double-quoted, and a
            # block sequence whose items sit on their own lines. Unquoted
            # `**/*` is not valid YAML in either shape, so it is not matched —
            # such a file fails to parse and never loads regardless.
            if printf '%s\n' "$frontmatter" | grep -qE "^paths:.*[\"']\*\*/\*[\"']"; then
                wildcard=true
            elif printf '%s\n' "$frontmatter" | grep -qE "^[[:space:]]*-[[:space:]]*[\"']\*\*/\*[\"'][[:space:]]*(#.*)?$"; then
                wildcard=true
            fi
        fi
    fi

    ref_source="$(reference_source "$rel")"

    if [[ -n "$ref_source" ]]; then
        if [[ "$has_paths" == true ]]; then
            report "$rel" "both @-referenced from $ref_source and paths:-scoped — pick one"
        fi
    else
        if [[ "$has_paths" == false ]]; then
            report "$rel" "no paths: frontmatter and not @-referenced from any CLAUDE.md — it loads in every session"
        fi
    fi

    if [[ "$wildcard" == true ]]; then
        report "$rel" 'paths: ["**/*"] is not scoping — it re-injects on every file read'
    fi
done < <(find "$RULES_DIR" -name '*.md' | sort)

if [[ "$failures" -gt 0 ]]; then
    echo "" >&2
    echo "$failures rule-loading problem(s) found. Every rules/ file needs exactly one" >&2
    echo "loading mechanism: paths: frontmatter for on-demand rules, or an" >&2
    echo "@-reference in a CLAUDE.md for rules that apply to every session." >&2
    exit 1
fi

echo "All rules have exactly one loading mechanism."
