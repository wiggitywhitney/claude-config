#!/usr/bin/env bash
# ABOUTME: Backs up per-repo private files to claude-personal before switching machines.
# ABOUTME: Syncs journal/, .claude/design-decisions.md, and .private-sync extras per repo.

set -euo pipefail

REPOS_DIR="${REPOS_DIR:-$HOME/Documents/Repositories}"
CLAUDE_PERSONAL_DIR="${CLAUDE_PERSONAL_DIR:-$HOME/Documents/Repositories/claude-personal}"
DRY_RUN=0

# Paths synced from every repo by default (relative to repo root)
readonly DEFAULT_SYNC_PATHS=("journal" ".claude/design-decisions.md")

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --repos-dir)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --repos-dir requires a path argument" >&2
                exit 1
            fi
            REPOS_DIR="$2"
            shift 2
            ;;
        --claude-personal-dir)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --claude-personal-dir requires a path argument" >&2
                exit 1
            fi
            CLAUDE_PERSONAL_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ── Output helpers ────────────────────────────────────────────────────────────

ok()      { echo "[OK] backed up $*"; }
skipped() { echo "[SKIPPED] $* — not found"; }
dry_run() { echo "[DRY RUN] Would back up $*"; }

# ── Prerequisite checks ───────────────────────────────────────────────────────

if [[ ! -d "$CLAUDE_PERSONAL_DIR/.git" ]]; then
    echo "Error: $CLAUDE_PERSONAL_DIR is not a git repository." >&2
    exit 1
fi

if [[ ! -d "$REPOS_DIR" ]]; then
    echo "Error: repos directory not found at $REPOS_DIR" >&2
    exit 1
fi

# ── Backup loop ───────────────────────────────────────────────────────────────

for repo_path in "$REPOS_DIR"/*/; do
    [[ -d "$repo_path/.git" ]] || continue
    repo_name="$(basename "$repo_path")"

    # Build sync list: defaults plus any paths in .private-sync
    sync_paths=("${DEFAULT_SYNC_PATHS[@]}")
    if [[ -f "$repo_path/.private-sync" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && sync_paths+=("$line")
        done < "$repo_path/.private-sync"
    fi

    for rel_path in "${sync_paths[@]}"; do
        src="$repo_path/$rel_path"
        dst="$CLAUDE_PERSONAL_DIR/private-files/$repo_name/$rel_path"

        if [[ ! -e "$src" ]]; then
            skipped "$repo_name/$rel_path"
            continue
        fi

        if [[ "$DRY_RUN" -eq 1 ]]; then
            dry_run "$repo_name/$rel_path"
            continue
        fi

        mkdir -p "$(dirname "$dst")"
        if [[ -d "$src" ]]; then
            rm -rf "$dst"
            cp -r "$src" "$dst"
        else
            cp "$src" "$dst"
        fi
        ok "$repo_name/$rel_path"
    done
done

# ── Commit to claude-personal ─────────────────────────────────────────────────

if [[ "$DRY_RUN" -eq 0 ]] && [[ -d "$CLAUDE_PERSONAL_DIR/private-files" ]]; then
    git -C "$CLAUDE_PERSONAL_DIR" add private-files/
    if ! git -C "$CLAUDE_PERSONAL_DIR" diff --cached --quiet; then
        git -C "$CLAUDE_PERSONAL_DIR" commit -m "chore: back up private files from local repos"
    fi
fi
