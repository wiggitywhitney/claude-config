#!/usr/bin/env bash
# ABOUTME: Bootstrap installer — symlinks native git hook dispatchers into a repo's .git/hooks/
# ABOUTME: Run once per repo; idempotent and safe to re-run. Never touches post-commit.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_SRC="$CLAUDE_CONFIG_DIR/hooks/git"

TARGET_REPO="${1:-$(pwd)}"

# Use git to resolve the hooks directory — handles both regular repos and worktrees
HOOKS_DST="$(git -C "$TARGET_REPO" rev-parse --git-path hooks 2>/dev/null || echo "")"

if [[ -z "$HOOKS_DST" ]] || [[ ! -d "$HOOKS_DST" ]]; then
    echo "ERROR: $TARGET_REPO is not a git repository or hooks directory not found" >&2
    exit 1
fi

# Hooks managed by this installer — never includes post-commit (reserved for commit-story)
readonly MANAGED_HOOKS=(pre-commit commit-msg pre-push)

installed=0
updated=0
skipped=0

for hook in "${MANAGED_HOOKS[@]}"; do
    src="$HOOKS_SRC/$hook"
    dst="$HOOKS_DST/$hook"

    if [[ ! -f "$src" ]]; then
        echo "  $hook: WARNING — source not found at $src, skipping" >&2
        continue
    fi

    if [[ -L "$dst" ]]; then
        current_target="$(readlink -f "$dst" 2>/dev/null || readlink "$dst")"
        resolved_src="$(readlink -f "$src" 2>/dev/null || echo "$src")"
        if [[ "$current_target" == "$resolved_src" ]]; then
            echo "  $hook: already installed (up to date)"
            (( skipped++ )) || true
            continue
        fi
        # Symlink exists but points elsewhere — update it
        ln -sf "$src" "$dst"
        echo "  $hook: updated symlink (was: $current_target -> now: $src)"
        (( updated++ )) || true
    elif [[ -f "$dst" ]]; then
        # Real file exists — back up before replacing
        backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dst" "$backup"
        echo "  $hook: backed up existing hook to $(basename "$backup")"
        ln -sf "$src" "$dst"
        echo "  $hook: installed symlink -> $src"
        (( installed++ )) || true
    else
        ln -sf "$src" "$dst"
        echo "  $hook: installed symlink -> $src"
        (( installed++ )) || true
    fi
done

echo ""
if (( installed > 0 || updated > 0 )); then
    echo "Installed $installed, updated $updated hook(s) in $TARGET_REPO"
else
    echo "All hooks already up to date in $TARGET_REPO"
fi
