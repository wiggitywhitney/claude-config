#!/usr/bin/env bash
# setup.sh — Portable Claude Code configuration installer
#
# Resolves settings.template.json with machine-specific paths.
# Optionally merges resolved settings into an existing settings.json.
# Optionally creates symlinks for global CLAUDE.md, rules, and skills.
#
# Usage:
#   ./setup.sh                        Print resolved settings to stdout
#   ./setup.sh --output FILE          Write resolved settings to FILE
#   ./setup.sh --merge FILE           Merge resolved settings into existing FILE
#   ./setup.sh --validate             Resolve and validate paths (no file output)
#   ./setup.sh --template FILE        Use a custom template (default: settings.template.json)
#   ./setup.sh --symlinks             Create symlinks for CLAUDE.md, rules/, skills/verify
#   ./setup.sh --claude-dir DIR       Override ~/.claude target directory (for testing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CONFIG_DIR="$SCRIPT_DIR"

# Defaults
TEMPLATE="$CLAUDE_CONFIG_DIR/settings.template.json"
OUTPUT=""
MERGE_TARGET=""
VALIDATE_ONLY=false
CREATE_SYMLINKS=false
CLAUDE_DIR="$HOME/.claude"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --merge)
            MERGE_TARGET="$2"
            shift 2
            ;;
        --validate)
            VALIDATE_ONLY=true
            shift
            ;;
        --template)
            TEMPLATE="$2"
            shift 2
            ;;
        --symlinks)
            CREATE_SYMLINKS=true
            shift
            ;;
        --claude-dir)
            CLAUDE_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: setup.sh [--output FILE] [--merge FILE] [--validate] [--template FILE] [--symlinks] [--claude-dir DIR]" >&2
            exit 1
            ;;
    esac
done

# ── Symlinks mode ──────────────────────────────────────────────────
if [[ "$CREATE_SYMLINKS" == true ]]; then
    # Create claude dir if it doesn't exist
    mkdir -p "$CLAUDE_DIR"

    # Helper: create or verify a symlink
    # Usage: ensure_symlink TARGET LINK_PATH LABEL
    ensure_symlink() {
        local target="$1"
        local link_path="$2"
        local label="$3"

        if [[ -L "$link_path" ]]; then
            local current_target
            current_target=$(readlink "$link_path")
            if [[ "$current_target" == "$target" ]]; then
                echo "  $label: already linked" >&2
                return 0
            else
                echo "  $label: updating symlink" >&2
                rm "$link_path"
                ln -s "$target" "$link_path"
                return 0
            fi
        elif [[ -e "$link_path" ]]; then
            echo "Error: $link_path exists and is not a symlink. Remove it manually to proceed." >&2
            return 1
        else
            ln -s "$target" "$link_path"
            echo "  $label: created" >&2
            return 0
        fi
    }

    echo "Creating symlinks in $CLAUDE_DIR..." >&2

    # CLAUDE.md → repo global/CLAUDE.md
    ensure_symlink "$CLAUDE_CONFIG_DIR/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"

    # rules/ → repo rules/
    ensure_symlink "$CLAUDE_CONFIG_DIR/rules" "$CLAUDE_DIR/rules" "rules"

    # skills/verify → repo .claude/skills/verify
    mkdir -p "$CLAUDE_DIR/skills"
    ensure_symlink "$CLAUDE_CONFIG_DIR/.claude/skills/verify" "$CLAUDE_DIR/skills/verify" "skills/verify"

    echo "Symlinks complete." >&2
    exit 0
fi

# Verify template exists
if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Template not found: $TEMPLATE" >&2
    exit 1
fi

# Resolve placeholders — use | as sed delimiter to avoid escaping /
RESOLVED=$(sed "s|\\\$CLAUDE_CONFIG_DIR|${CLAUDE_CONFIG_DIR}|g" "$TEMPLATE")

# Validate JSON
if ! echo "$RESOLVED" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
    echo "Error: Resolved template is not valid JSON" >&2
    exit 1
fi

# Validate that all hook command paths exist on disk
MISSING_PATHS=$(echo "$RESOLVED" | python3 -c "
import json, sys, os
data = json.load(sys.stdin)
missing = []
for event_type, matchers in data.get('hooks', {}).items():
    for matcher in matchers:
        for hook in matcher.get('hooks', []):
            path = hook.get('command', '')
            if path and not os.path.isfile(path):
                missing.append(path)
for p in missing:
    print(p)
" 2>/dev/null)

if [[ -n "$MISSING_PATHS" ]]; then
    echo "Error: Hook script paths do not exist:" >&2
    echo "$MISSING_PATHS" >&2
    exit 1
fi

# Validate-only mode: report and exit
if [[ "$VALIDATE_ONLY" == true ]]; then
    echo "All hook paths valid. Template resolves correctly."
    exit 0
fi

# Merge mode: merge resolved template into existing settings
if [[ -n "$MERGE_TARGET" ]]; then
    # If target doesn't exist, just write the resolved template
    if [[ ! -f "$MERGE_TARGET" ]]; then
        mkdir -p "$(dirname "$MERGE_TARGET")"
        echo "$RESOLVED" > "$MERGE_TARGET"
        exit 0
    fi

    # Validate existing file is valid JSON
    if ! python3 -c "import json; json.load(open('$MERGE_TARGET'))" 2>/dev/null; then
        echo "Error: Existing settings file is not valid JSON: $MERGE_TARGET" >&2
        exit 1
    fi

    # Backup existing file
    BACKUP="${MERGE_TARGET}.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$MERGE_TARGET" "$BACKUP"

    # Merge using Python
    python3 -c "
import json, sys

resolved = json.loads(sys.stdin.read())

with open('$MERGE_TARGET') as f:
    existing = json.load(f)

# Merge hooks: for each event type, merge matchers by pattern
template_hooks = resolved.get('hooks', {})
existing_hooks = existing.get('hooks', {})
merged_hooks = dict(existing_hooks)

for event_type, template_matchers in template_hooks.items():
    if event_type not in merged_hooks:
        merged_hooks[event_type] = template_matchers
        continue

    existing_matchers = merged_hooks[event_type]
    # Build lookup of existing matchers by pattern
    existing_by_pattern = {}
    for m in existing_matchers:
        existing_by_pattern[m['matcher']] = m

    for tm in template_matchers:
        pattern = tm['matcher']
        if pattern not in existing_by_pattern:
            # New matcher — add it
            existing_matchers.append(tm)
        else:
            # Same matcher — merge hook commands (add new, skip duplicates)
            em = existing_by_pattern[pattern]
            existing_commands = {h['command'] for h in em.get('hooks', [])}
            for th in tm.get('hooks', []):
                if th['command'] not in existing_commands:
                    em['hooks'].append(th)

    merged_hooks[event_type] = existing_matchers

if merged_hooks:
    existing['hooks'] = merged_hooks

# Merge permissions: union lists
template_perms = resolved.get('permissions', {})
existing_perms = existing.get('permissions', {})

if template_perms:
    if 'permissions' not in existing:
        existing['permissions'] = {}

    for key in ('allow', 'deny', 'ask'):
        template_list = template_perms.get(key, [])
        existing_list = existing['permissions'].get(key, [])
        existing_set = set(existing_list)

        for entry in template_list:
            if entry not in existing_set:
                existing_list.append(entry)
                existing_set.add(entry)

        if existing_list:
            existing['permissions'][key] = existing_list

# Merge other keys: only set if not already present
for key, value in resolved.items():
    if key in ('hooks', 'permissions'):
        continue
    if key not in existing:
        existing[key] = value

with open('$MERGE_TARGET', 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
" <<< "$RESOLVED"

    exit 0
fi

# Output resolved settings
if [[ -n "$OUTPUT" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    echo "$RESOLVED" > "$OUTPUT"
else
    echo "$RESOLVED"
fi
