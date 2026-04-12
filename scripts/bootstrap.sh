#!/usr/bin/env bash
# ABOUTME: Idempotent bootstrap script for restoring a full Claude development environment
# ABOUTME: on a new machine. Run after cloning claude-config and claude-personal.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

DRY_RUN=0
CLAUDE_PERSONAL_DIR="${CLAUDE_PERSONAL_DIR:-$HOME/Documents/Repositories/claude-personal}"

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
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

ok()        { echo "[OK] $*"; }
skipped()   { echo "[SKIPPED] $*"; }
backed_up() { echo "[BACKED UP] $*"; }
dry_run()   { echo "[DRY RUN] $*"; }

# ── Prerequisite checks ───────────────────────────────────────────────────────

if [[ ! -d "$CLAUDE_DIR" ]]; then
    echo "Error: $CLAUDE_DIR does not exist. Cannot bootstrap." >&2
    exit 1
fi

if [[ ! -d "$CLAUDE_PERSONAL_DIR" ]]; then
    echo "Error: claude-personal directory not found at $CLAUDE_PERSONAL_DIR" >&2
    echo "Clone it first: git clone git@github.com:wiggitywhitney/claude-personal.git \"$CLAUDE_PERSONAL_DIR\"" >&2
    exit 1
fi

if [[ ! -d "$CLAUDE_PERSONAL_DIR/.git" ]]; then
    echo "Error: $CLAUDE_PERSONAL_DIR exists but is not a git repository." >&2
    exit 1
fi

# ── Step 1: settings.json symlink ─────────────────────────────────────────────

SETTINGS_TARGET="$REPO_ROOT/config/settings.json"
SETTINGS_LINK="$CLAUDE_DIR/settings.json"

if [[ -L "$SETTINGS_LINK" ]]; then
    current_target="$(readlink "$SETTINGS_LINK")"
    if [[ "$current_target" == "$SETTINGS_TARGET" ]]; then
        skipped "settings.json symlink already correct"
    else
        if [[ "$DRY_RUN" -eq 1 ]]; then
            dry_run "Would back up $SETTINGS_LINK → ${SETTINGS_LINK}.pre-bootstrap-backup"
            dry_run "Would create symlink $SETTINGS_LINK → $SETTINGS_TARGET"
        else
            mv "$SETTINGS_LINK" "${SETTINGS_LINK}.pre-bootstrap-backup"
            ln -s "$SETTINGS_TARGET" "$SETTINGS_LINK"
            backed_up "settings.json (was pointing to $current_target)"
            ok "settings.json symlink created → $SETTINGS_TARGET"
        fi
    fi
elif [[ -e "$SETTINGS_LINK" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run "Would back up $SETTINGS_LINK → ${SETTINGS_LINK}.pre-bootstrap-backup"
        dry_run "Would create symlink $SETTINGS_LINK → $SETTINGS_TARGET"
    else
        mv "$SETTINGS_LINK" "${SETTINGS_LINK}.pre-bootstrap-backup"
        ln -s "$SETTINGS_TARGET" "$SETTINGS_LINK"
        backed_up "settings.json (was a regular file)"
        ok "settings.json symlink created → $SETTINGS_TARGET"
    fi
else
    if [[ "$DRY_RUN" -eq 1 ]]; then
        dry_run "Would create symlink $SETTINGS_LINK → $SETTINGS_TARGET"
    else
        ln -s "$SETTINGS_TARGET" "$SETTINGS_LINK"
        ok "settings.json symlink created → $SETTINGS_TARGET"
    fi
fi

# ── Step 2: Memory file restore ───────────────────────────────────────────────

MEMORY_SRC="$CLAUDE_PERSONAL_DIR/memory"
# Encode the standard repo prefix once: $HOME/Documents/Repositories → sed 's|[/.]|-|g'
# Do NOT use $(whoami) — macOS usernames with dots encode as hyphens in project paths.
HOME_PREFIX=$(echo "$HOME/Documents/Repositories" | sed 's|[/.]|-|g')

if [[ -d "$MEMORY_SRC" ]]; then
    for project_dir in "$MEMORY_SRC"/*/; do
        [[ -d "$project_dir" ]] || continue
        project_name="$(basename "$project_dir")"

        # Names starting with '-' are full encoded paths (fallback for non-standard
        # repo locations stored during push). Use them as-is without adding the prefix.
        if [[ "$project_name" == -* ]]; then
            encoded_path="$project_name"
        else
            encoded_path="${HOME_PREFIX}-${project_name}"
        fi

        target_dir="$CLAUDE_DIR/projects/$encoded_path/memory"

        for src_file in "$project_dir"*.md; do
            [[ -f "$src_file" ]] || continue
            filename="$(basename "$src_file")"
            dst_file="$target_dir/$filename"

            if [[ "$DRY_RUN" -eq 1 ]]; then
                if [[ -f "$dst_file" ]] && cmp -s "$src_file" "$dst_file"; then
                    dry_run "Would skip memory: $project_name/$filename (identical)"
                elif [[ -f "$dst_file" ]]; then
                    dry_run "Would update memory: $project_name/$filename"
                else
                    dry_run "Would restore memory: $project_name/$filename"
                fi
            else
                mkdir -p "$target_dir"
                if [[ -f "$dst_file" ]]; then
                    if cmp -s "$src_file" "$dst_file"; then
                        skipped "memory: $project_name/$filename (identical)"
                    else
                        cp "$src_file" "$dst_file"
                        ok "Updated memory: $project_name/$filename"
                    fi
                else
                    cp "$src_file" "$dst_file"
                    ok "Restored memory: $project_name/$filename"
                fi
            fi
        done
    done
fi
