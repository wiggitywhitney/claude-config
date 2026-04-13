#!/usr/bin/env bash
# ABOUTME: Syncs active GitHub repos to the local machine before running bootstrap.
# ABOUTME: Clones missing repos and fast-forward-pulls existing ones.

set -euo pipefail

MONTHS="${MONTHS:-6}"
REPOS_DIR="${REPOS_DIR:-$HOME/Documents/Repositories}"
DRY_RUN=0

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --months)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --months requires a number argument" >&2
                exit 1
            fi
            MONTHS="$2"
            shift 2
            ;;
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
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ── Output helpers ────────────────────────────────────────────────────────────

ok()      { echo "[OK] $*"; }
skipped() { echo "[SKIPPED] $*"; }
dry_run() { echo "[DRY RUN] $*"; }

# ── Prerequisite checks ───────────────────────────────────────────────────────

if ! command -v gh > /dev/null 2>&1; then
    echo "Error: gh (GitHub CLI) is not installed or not in PATH." >&2
    exit 1
fi

if ! command -v jq > /dev/null 2>&1; then
    echo "Error: jq is not installed or not in PATH." >&2
    exit 1
fi

mkdir -p "$REPOS_DIR"

# ── Date threshold ────────────────────────────────────────────────────────────

# Uses GNU date (date -d), which is on PATH via coreutils on this machine.
threshold_epoch=$(date -d "${MONTHS} months ago" +%s)

# ── Repo sync loop ────────────────────────────────────────────────────────────

# Fetch and iterate over repos as tab-separated nameWithOwner<TAB>pushedAt rows.
while IFS=$'\t' read -r name_with_owner pushed_at; do
    repo_name="${name_with_owner##*/}"

    # Filter out repos outside the activity window
    pushed_epoch=$(date -d "$pushed_at" +%s)
    if [[ "$pushed_epoch" -lt "$threshold_epoch" ]]; then
        skipped "$repo_name — not active in last ${MONTHS} months"
        continue
    fi

    repo_path="$REPOS_DIR/$repo_name"

    if [[ ! -d "$repo_path/.git" ]]; then
        # Repo not present on disk — clone it
        if [[ "$DRY_RUN" -eq 1 ]]; then
            dry_run "Would clone $repo_name"
        else
            if gh repo clone "$name_with_owner" "$repo_path" > /dev/null 2>&1; then
                ok "cloned $repo_name"
            else
                echo "[ERROR] failed to clone $repo_name" >&2
            fi
        fi
    else
        # Repo already present — fast-forward pull
        if [[ "$DRY_RUN" -eq 1 ]]; then
            dry_run "Would pull $repo_name"
        else
            before=$(git -C "$repo_path" rev-parse HEAD)
            if git -C "$repo_path" pull --ff-only > /dev/null 2>&1; then
                after=$(git -C "$repo_path" rev-parse HEAD)
                if [[ "$before" == "$after" ]]; then
                    skipped "$repo_name — already up to date"
                else
                    count=$(git -C "$repo_path" rev-list --count "${before}..${after}")
                    ok "pulled $repo_name ($count commits)"
                fi
            else
                skipped "$repo_name — local changes, run git pull manually"
            fi
        fi
    fi
done < <(gh repo list --json nameWithOwner,pushedAt --limit 1000 | jq -r '.[] | [.nameWithOwner, .pushedAt] | @tsv')
