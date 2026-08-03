#!/usr/bin/env bash
# ABOUTME: Verifies every rules/ file has exactly one loading mechanism.
# ABOUTME: A rule is either paths:-scoped or @-referenced from global/CLAUDE.md — never both, never neither.

set -uo pipefail

# Resolve the repo root so the script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"

readonly RULES_DIR="$REPO_ROOT/rules"
readonly CLAUDE_MD="$REPO_ROOT/global/CLAUDE.md"

# rules/README.md is the human-facing index, not a rule. It is never loaded by
# either mechanism, so holding it to the one-mechanism requirement is wrong.
readonly EXEMPT_BASENAMES=("README.md")

if [[ ! -d "$RULES_DIR" ]]; then
    echo "check-rule-frontmatter: no rules directory at $RULES_DIR" >&2
    exit 1
fi

if [[ ! -f "$CLAUDE_MD" ]]; then
    echo "check-rule-frontmatter: no global/CLAUDE.md at $CLAUDE_MD" >&2
    exit 1
fi

# Collect the @-referenced set from CLAUDE.md rather than hardcoding a list, so
# adding or removing an @-reference needs no corresponding edit here.
referenced=$(grep -o '@~/\.claude/rules/[A-Za-z0-9._/-]*\.md' "$CLAUDE_MD" \
    | sed 's|@~/\.claude/rules/||' | sort -u)

is_referenced() {
    local rel="$1"
    printf '%s\n' "$referenced" | grep -qxF "$rel"
}

is_exempt() {
    local base
    base="$(basename "$1")"
    local exempt
    for exempt in "${EXEMPT_BASENAMES[@]}"; do
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
            elif printf '%s\n' "$frontmatter" | grep -qE "^[[:space:]]*-[[:space:]]*[\"']\*\*/\*[\"'][[:space:]]*$"; then
                wildcard=true
            fi
        fi
    fi

    if is_referenced "$rel"; then
        if [[ "$has_paths" == true ]]; then
            report "$rel" "both @-referenced from global/CLAUDE.md and paths:-scoped — pick one"
        fi
    else
        if [[ "$has_paths" == false ]]; then
            report "$rel" "no paths: frontmatter and not @-referenced from global/CLAUDE.md — it loads in every session"
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
    echo "@-reference in global/CLAUDE.md for rules that apply to every session." >&2
    exit 1
fi

echo "All rules have exactly one loading mechanism."
