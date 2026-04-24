#!/usr/bin/env bash
# ABOUTME: pre-push check — requires PROGRESS.md entry when branch has none vs base
# ABOUTME: Uses claude -p to draft an entry if missing; offers accept/edit/skip via /dev/tty

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    exit 0
fi

# Only enforce in repos that have PROGRESS.md
if [[ ! -f "$REPO_ROOT/PROGRESS.md" ]]; then
    exit 0
fi

# Determine base ref from the remote name passed by the dispatcher
REMOTE_NAME="${1:-origin}"
BASE_REF=""
if git rev-parse --verify "${REMOTE_NAME}/main" &>/dev/null; then
    BASE_REF="${REMOTE_NAME}/main"
elif git rev-parse --verify "${REMOTE_NAME}/master" &>/dev/null; then
    BASE_REF="${REMOTE_NAME}/master"
fi

if [[ -z "$BASE_REF" ]]; then
    exit 0  # Can't determine base — skip check
fi

# Skip if branch has no commits vs base (nothing to push)
COMMIT_COUNT="$(git rev-list "${BASE_REF}...HEAD" --count 2>/dev/null || echo "0")"
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
    exit 0
fi

# Pass if PROGRESS.md has any changes on this branch vs base
# git diff --quiet exits 0 = no differences, 1 = differences exist
if ! git diff --quiet "${BASE_REF}...HEAD" -- PROGRESS.md 2>/dev/null; then
    exit 0  # PROGRESS.md has changes — all good
fi

# No PROGRESS.md changes. Check if interactive prompting is possible.
# PROGRESS_MD_PR_NO_TTY=1 forces the non-interactive path (used in tests).
if [[ "${PROGRESS_MD_PR_NO_TTY:-}" == "1" ]] || ! { : > /dev/tty; } 2>/dev/null; then
    echo "WARNING: This branch has no PROGRESS.md changes. Add an entry before merging." >&2
    exit 0
fi

# Draft a PROGRESS.md entry using claude -p
COMMIT_MESSAGES="$(git log "${BASE_REF}...HEAD" --pretty=format:"%s" 2>/dev/null)"
TODAY="$(date +%Y-%m-%d)"
DRAFT=""

if command -v claude &>/dev/null; then
    PROMPT="Generate a single PROGRESS.md entry for these git commits. Output exactly one line formatted as: - (${TODAY}) [prose description of what changed and why, written for external readers unfamiliar with the project; describe the capability gained, not files changed; omit issue numbers, PRD references, and internal identifiers]. Output only the entry line — no other text.

Commits:
${COMMIT_MESSAGES}"
    DRAFT="$(env -u ANTHROPIC_CUSTOM_HEADERS -u ANTHROPIC_BASE_URL claude -p "$PROMPT" 2>/dev/null || true)"
fi

# Show prompt on /dev/tty
{
    echo ""
    echo "=== PROGRESS.md Update Required ==="
    echo "Branch has no PROGRESS.md changes vs ${BASE_REF}."
    echo ""
    if [[ -n "$DRAFT" ]]; then
        echo "Suggested entry:"
        echo ""
        echo "  $DRAFT"
        echo ""
        printf "Options: [a]ccept  [e]dit  [s]kip (bypass this push only): "
    else
        echo "(claude not available — cannot auto-draft)"
        echo ""
        printf "Options: [s]kip (bypass this push only)  [q]uit (update PROGRESS.md first): "
    fi
} > /dev/tty

read -r CHOICE < /dev/tty

# Insert ENTRY under "### Added" within "## [Unreleased]"; fall back to appending
_insert_progress_entry() {
    local progress_file="$1"
    local entry="$2"
    PROGRESS_ENTRY="$entry" python3 - "$progress_file" <<'PYEOF'
import sys, os

progress_file = sys.argv[1]
entry = os.environ['PROGRESS_ENTRY']

with open(progress_file) as f:
    content = f.read()

marker = "### Added\n\n"
idx = content.find(marker)
if idx != -1:
    insert_at = idx + len(marker)
    content = content[:insert_at] + entry + "\n" + content[insert_at:]
else:
    content = content.rstrip() + "\n\n" + entry + "\n"

with open(progress_file, 'w') as f:
    f.write(content)
PYEOF
}

case "${CHOICE,,}" in
    a|accept)
        _insert_progress_entry "$REPO_ROOT/PROGRESS.md" "$DRAFT"
        git -C "$REPO_ROOT" add PROGRESS.md
        git -C "$REPO_ROOT" commit -m "docs: add PROGRESS.md entry for branch changes" --quiet
        echo "" >&2
        echo "Committed PROGRESS.md update. Push again to include it." >&2
        exit 1
        ;;
    e|edit)
        TMPFILE="$(mktemp)"
        printf '%s\n' "$DRAFT" > "$TMPFILE"
        "${EDITOR:-vi}" "$TMPFILE" < /dev/tty > /dev/tty
        EDITED="$(< "$TMPFILE")"
        rm -f "$TMPFILE"
        if [[ -n "$EDITED" ]]; then
            _insert_progress_entry "$REPO_ROOT/PROGRESS.md" "$EDITED"
            git -C "$REPO_ROOT" add PROGRESS.md
            git -C "$REPO_ROOT" commit -m "docs: add PROGRESS.md entry for branch changes" --quiet
            echo "" >&2
            echo "Committed PROGRESS.md update. Push again to include it." >&2
            exit 1
        else
            echo "" >&2
            echo "Push blocked. PROGRESS.md entry was empty. Update PROGRESS.md and push again." >&2
            exit 1
        fi
        ;;
    s|skip)
        echo "" >&2
        echo "WARNING: Bypassing PROGRESS.md check. Update PROGRESS.md before merging." >&2
        exit 0
        ;;
    *)
        echo "" >&2
        echo "Push blocked. Update PROGRESS.md and push again." >&2
        exit 1
        ;;
esac
