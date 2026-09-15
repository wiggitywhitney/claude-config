#!/usr/bin/env bash
# ABOUTME: Three-way body-line measurement of the PRD-lifecycle skills against their upstream fork point.
# ABOUTME: Strips only the leading YAML frontmatter block so `---` horizontal rules in skill bodies are preserved.
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
UPSTREAM="${UPSTREAM:-$REPO_ROOT/research/repos/dot-ai}"
ANCESTOR="${ANCESTOR:-84c80f17f7ff30c9ed000758cfdc3f9a892e4a40}"

SKILLS=(prd-create prd-start prd-next prd-update-progress prd-update-decisions prd-done prd-close prds-get)

# Delete only a frontmatter block that opens on line 1. Anything else, including a
# `---` horizontal rule further down the body, is left alone.
strip_frontmatter() {
  awk 'NR==1 && $0=="---" { in_fm=1; next } in_fm { if ($0=="---") in_fm=0; next } { print }'
}

# Drop blank lines at both ends. The frontmatter-to-skill conversion appended one at
# the tail of every upstream skill, and stripping a frontmatter block leaves the blank
# line that followed it at the head. Neither is content, and both otherwise report as
# moved lines in files whose body is identical to the ancestor.
strip_edge_blanks() {
  awk '{ lines[NR]=$0 }
       END { first=0; last=0;
             for (i=1;i<=NR;i++) if (lines[i] ~ /[^[:space:]]/) { if (!first) first=i; last=i }
             for (i=first;i<=last;i++) print lines[i] }'
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '%-24s %8s %8s %8s %10s %10s %10s %10s\n' \
  SKILL ANC_BODY HIS_BODY HER_BODY HIS_MOVED HER_MOVED HIS_FILE HER_FILE

total_his=0
total_her=0
for s in "${SKILLS[@]}"; do
  git -C "$UPSTREAM" show "$ANCESTOR:shared-prompts/$s.md" > "$tmp/anc.raw"
  cp "$UPSTREAM/.claude/skills/dot-ai-$s/SKILL.md" "$tmp/his.raw"
  cp "$REPO_ROOT/.claude/skills/$s/SKILL.md" "$tmp/her.raw"

  for v in anc his her; do
    strip_frontmatter < "$tmp/$v.raw" | strip_edge_blanks > "$tmp/$v.body"
  done

  # Churn: both sides of the diff, matching how the fork-point figures were measured.
  his_moved=$(diff "$tmp/anc.body" "$tmp/his.body" | grep -c '^[<>]' || true)
  her_moved=$(diff "$tmp/anc.body" "$tmp/her.body" | grep -c '^[<>]' || true)
  # Whole-file churn, as the cross-check against an implausibly small body figure.
  his_file=$(diff "$tmp/anc.raw" "$tmp/his.raw" | grep -c '^[<>]' || true)
  her_file=$(diff "$tmp/anc.raw" "$tmp/her.raw" | grep -c '^[<>]' || true)

  printf '%-24s %8d %8d %8d %10d %10d %10d %10d\n' \
    "$s" "$(wc -l < "$tmp/anc.body")" "$(wc -l < "$tmp/his.body")" "$(wc -l < "$tmp/her.body")" \
    "$his_moved" "$her_moved" "$his_file" "$her_file"

  total_his=$((total_his + his_moved))
  total_her=$((total_her + her_moved))
done

printf '%-24s %8s %8s %8s %10d %10d\n' TOTAL '' '' '' "$total_his" "$total_her"
