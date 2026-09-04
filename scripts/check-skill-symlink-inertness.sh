#!/usr/bin/env bash
# ABOUTME: Confirms whether project-level PRD/issue skill symlinks are shadowed by personally-installed skills.
# ABOUTME: Claude Code resolves skills personal-over-project, so a personal copy makes the project symlink inert.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/Documents/Repositories}"
PERSONAL="${PERSONAL:-$HOME/.claude/skills}"

# The canonical lifecycle manifest. Do not re-derive from a glob: `prd-*` silently
# excludes prds-get.
SKILLS=(prd-create prd-start prd-next prd-update-progress prd-update-decisions prd-done prd-close prds-get
        issue-create issue-start issue-next issue-update-progress issue-update-decisions issue-done)

inert=0; live=0; absent=0

for repo_path in "$WORKSPACE"/*/; do
  repo="$(basename "$repo_path")"
  [ "$repo" = "claude-config" ] && continue
  [ -d "$repo_path/.claude/skills" ] || continue

  found_any=0
  for s in "${SKILLS[@]}"; do
    proj="$repo_path/.claude/skills/$s/SKILL.md"
    [ -e "$proj" ] || [ -L "$proj" ] || continue
    found_any=1

    target=""
    [ -L "$proj" ] && target="$(readlink "$proj")"
    dangling=""
    { [ -L "$proj" ] && [ ! -e "$proj" ]; } && dangling=" DANGLING"

    if [ -e "$PERSONAL/$s/SKILL.md" ]; then
      verdict="INERT (shadowed by personal $s)"
      inert=$((inert + 1))
    else
      verdict="LIVE (no personal $s to shadow it)"
      live=$((live + 1))
    fi
    printf '%-28s %-24s %s%s\n    target: %s\n' "$repo" "$s" "$verdict" "$dangling" "${target:-<regular file>}"
  done
  [ "$found_any" -eq 0 ] && { printf '%-28s %s\n' "$repo" "(has .claude/skills, no lifecycle skills)"; absent=$((absent + 1)); }
done

echo
echo "inert=$inert live=$live repos-with-skills-but-no-lifecycle=$absent"
[ "$live" -eq 0 ] || echo "WARNING: at least one project skill is NOT shadowed and would take effect."
