#!/usr/bin/env bash
# ABOUTME: Idempotent bootstrap script for restoring a full Claude development environment
# ABOUTME: on a new machine. Run after cloning claude-config and claude-personal.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

DRY_RUN=0
CLAUDE_PERSONAL_DIR="$HOME/Documents/Repositories/claude-personal"

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --claude-personal-dir)
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
