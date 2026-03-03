#!/usr/bin/env bash
# check-aboutme.sh — PreToolUse hook that enforces ABOUTME file headers
#
# Installed as a Claude Code PreToolUse hook on Write|Edit.
# Checks that code files include an ABOUTME header in the first 3 lines
# using the correct comment syntax for the file type.
#
# For Write: checks tool_input.content for ABOUTME in first 3 lines
# For Edit: reads existing file from disk; allows if new_string adds ABOUTME (fix-and-retry)
# Skips config, markdown, generated, and other non-code files.
#
# Input: JSON on stdin from Claude Code (PreToolUse event)
# Output: JSON on stdout with permissionDecision (deny only; silent passthrough on allow)
#
# Exit codes:
#   0 — Decision returned via JSON, or silent passthrough (allow)

set -uo pipefail

# Read hook input from stdin
INPUT=$(cat)

# All logic in Python for reliable JSON parsing and cross-platform compatibility
RESULT=$(HOOK_INPUT="$INPUT" python3 << 'PYEOF'
import json
import os
import sys

input_str = os.environ.get("HOOK_INPUT", "")
try:
    data = json.loads(input_str)
except (json.JSONDecodeError, TypeError):
    print("SKIP")
    sys.exit(0)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {})
file_path = tool_input.get("file_path", "")

if not file_path:
    print("SKIP")
    sys.exit(0)

# --- File extension and skip logic ---

basename = os.path.basename(file_path)
_, ext = os.path.splitext(basename)
ext = ext.lower()

# Skip: files in node_modules
if "/node_modules/" in file_path:
    print("SKIP")
    sys.exit(0)

# Skip: minified files
if basename.endswith(".min.js") or basename.endswith(".min.css"):
    print("SKIP")
    sys.exit(0)

# Skip: TypeScript declaration files
if basename.endswith(".d.ts"):
    print("SKIP")
    sys.exit(0)

# Skip: source map files
if basename.endswith(".js.map") or basename.endswith(".css.map"):
    print("SKIP")
    sys.exit(0)

# Skip: specific filenames that don't need headers
skip_basenames = {"__init__.py"}
if basename in skip_basenames:
    print("SKIP")
    sys.exit(0)

# Skip: unsupported extensions (config, markup, data, media, etc.)
skip_extensions = {
    ".json", ".yaml", ".yml", ".toml", ".cfg", ".ini",
    ".md", ".mdx", ".rst", ".txt",
    ".html", ".htm", ".xml", ".svg",
    ".css", ".scss", ".less", ".sass",
    ".env", ".lock",
    ".map", ".wasm",
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".webp",
    ".pdf", ".zip", ".tar", ".gz",
}
if ext in skip_extensions:
    print("SKIP")
    sys.exit(0)

# Supported extensions mapped to their comment prefix
COMMENT_PREFIXES = {
    ".py": "# ",
    ".sh": "# ",
    ".ts": "// ",
    ".tsx": "// ",
    ".js": "// ",
    ".jsx": "// ",
}

# Skip: extension not in supported list
if ext not in COMMENT_PREFIXES:
    print("SKIP")
    sys.exit(0)

prefix = COMMENT_PREFIXES[ext]
aboutme_marker = prefix + "ABOUTME:"


def has_aboutme(text):
    """Check if ABOUTME header exists in first 3 lines with correct comment syntax."""
    lines = text.split("\n")[:3]
    for line in lines:
        if line.startswith(aboutme_marker):
            return True
    return False


# --- Write tool: check content for ABOUTME ---
if tool_name == "Write":
    content = tool_input.get("content", "")
    if has_aboutme(content):
        print("ALLOW")
    else:
        print("DENY")
    sys.exit(0)

# --- Edit tool: check file on disk, or allow if adding ABOUTME ---
if tool_name == "Edit":
    new_string = tool_input.get("new_string", "")

    # If new_string contains the ABOUTME marker, this is a fix — allow it
    if aboutme_marker in new_string:
        print("ALLOW")
        sys.exit(0)

    # Read existing file from disk to check for ABOUTME
    try:
        with open(file_path, "r") as f:
            existing = f.read()
        if has_aboutme(existing):
            print("ALLOW")
        else:
            print("DENY")
    except (FileNotFoundError, PermissionError):
        # File doesn't exist on disk yet — allow gracefully
        print("ALLOW")
    sys.exit(0)

# Unknown tool name — skip
print("SKIP")
PYEOF
)

# If Python failed, allow rather than false-positive block
if [ $? -ne 0 ]; then
  exit 0
fi

# Silent passthrough for ALLOW and SKIP
if [[ "$RESULT" == "ALLOW" ]] || [[ "$RESULT" == "SKIP" ]]; then
  exit 0
fi

# Deny — block with structured JSON including helpful fix instructions
if [[ "$RESULT" == "DENY" ]]; then
  ABOUTME_FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "unknown")

  ABOUTME_FILE_PATH="$ABOUTME_FILE_PATH" python3 -c "
import json, os

file_path = os.environ['ABOUTME_FILE_PATH']
ext = os.path.splitext(file_path)[1].lower()

comment_prefixes = {'.py': '# ', '.sh': '# ', '.ts': '// ', '.tsx': '// ', '.js': '// ', '.jsx': '// '}
prefix = comment_prefixes.get(ext, '# ')

reason = (
    f'File \"{os.path.basename(file_path)}\" is missing an ABOUTME header. '
    f'Add 1-2 lines at the top of the file (after shebang if present) using this format:\n'
    f'{prefix}ABOUTME: Brief description of this file\\'s purpose\n'
    f'{prefix}ABOUTME: What it does or provides'
)
result = {
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}
print(json.dumps(result))
"
  exit 0
fi

# Fallback: silent passthrough
exit 0
