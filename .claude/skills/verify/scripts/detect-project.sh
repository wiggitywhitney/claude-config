#!/usr/bin/env bash
# detect-project.sh — Detect project type and available verification commands
#
# Usage: detect-project.sh [project-directory]
# Output: JSON object with project type and available commands
#
# Reads config files to determine project type and what verification
# commands are available. Does NOT run any commands — only detection.

set -euo pipefail

PROJECT_DIR="${1:-.}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Initialize detection results
PROJECT_TYPE="unknown"
HAS_PACKAGE_JSON=false
HAS_TSCONFIG=false
HAS_PYPROJECT=false
HAS_GOMOD=false
HAS_CARGO=false

# Available commands (empty string means not available)
CMD_BUILD=""
CMD_TYPECHECK=""
CMD_LINT=""
CMD_TEST=""

# --- Detect config files ---

if [ -f "$PROJECT_DIR/package.json" ]; then
  HAS_PACKAGE_JSON=true
fi

if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
  HAS_TSCONFIG=true
fi

if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  HAS_PYPROJECT=true
fi

if [ -f "$PROJECT_DIR/go.mod" ]; then
  HAS_GOMOD=true
fi

if [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  HAS_CARGO=true
fi

# --- Determine project type ---

if [ "$HAS_TSCONFIG" = true ] && [ "$HAS_PACKAGE_JSON" = true ]; then
  PROJECT_TYPE="node-typescript"
elif [ "$HAS_PACKAGE_JSON" = true ]; then
  PROJECT_TYPE="node-javascript"
elif [ "$HAS_PYPROJECT" = true ]; then
  PROJECT_TYPE="python"
elif [ "$HAS_GOMOD" = true ]; then
  PROJECT_TYPE="go"
elif [ "$HAS_CARGO" = true ]; then
  PROJECT_TYPE="rust"
fi

# --- Detect available commands (Node.js projects) ---

if [ "$HAS_PACKAGE_JSON" = true ]; then
  # Read package.json scripts using python3 (available on macOS)
  SCRIPTS_JSON=$(python3 -c "
import json, sys
try:
    with open('$PROJECT_DIR/package.json') as f:
        pkg = json.load(f)
    scripts = pkg.get('scripts', {})
    print(json.dumps(scripts))
except Exception:
    print('{}')
" 2>/dev/null || echo '{}')

  # Detect package manager
  PKG_MANAGER="npm"
  if [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
    PKG_MANAGER="pnpm"
  elif [ -f "$PROJECT_DIR/yarn.lock" ]; then
    PKG_MANAGER="yarn"
  elif [ -f "$PROJECT_DIR/bun.lockb" ] || [ -f "$PROJECT_DIR/bun.lock" ]; then
    PKG_MANAGER="bun"
  fi

  # Detect build command
  if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; sys.exit(0 if 'build' in json.load(sys.stdin) else 1)" 2>/dev/null; then
    CMD_BUILD="$PKG_MANAGER run build"
  elif [ "$HAS_TSCONFIG" = true ]; then
    CMD_BUILD="npx tsc --noEmit"
  fi

  # Detect typecheck command
  if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; sys.exit(0 if 'typecheck' in json.load(sys.stdin) else 1)" 2>/dev/null; then
    CMD_TYPECHECK="$PKG_MANAGER run typecheck"
  elif echo "$SCRIPTS_JSON" | python3 -c "import json,sys; sys.exit(0 if 'type-check' in json.load(sys.stdin) else 1)" 2>/dev/null; then
    CMD_TYPECHECK="$PKG_MANAGER run type-check"
  elif [ "$HAS_TSCONFIG" = true ]; then
    CMD_TYPECHECK="npx tsc --noEmit"
  fi

  # Detect lint command
  if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; sys.exit(0 if 'lint' in json.load(sys.stdin) else 1)" 2>/dev/null; then
    CMD_LINT="$PKG_MANAGER run lint"
  elif [ -f "$PROJECT_DIR/.eslintrc.json" ] || [ -f "$PROJECT_DIR/.eslintrc.js" ] || [ -f "$PROJECT_DIR/.eslintrc.yml" ] || [ -f "$PROJECT_DIR/eslint.config.js" ] || [ -f "$PROJECT_DIR/eslint.config.mjs" ]; then
    CMD_LINT="npx eslint ."
  fi

  # Detect test command
  if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; sys.exit(0 if 'test' in json.load(sys.stdin) else 1)" 2>/dev/null; then
    CMD_TEST="$PKG_MANAGER run test"
  elif [ -f "$PROJECT_DIR/jest.config.js" ] || [ -f "$PROJECT_DIR/jest.config.ts" ] || [ -f "$PROJECT_DIR/jest.config.mjs" ]; then
    CMD_TEST="npx jest"
  elif [ -f "$PROJECT_DIR/vitest.config.js" ] || [ -f "$PROJECT_DIR/vitest.config.ts" ] || [ -f "$PROJECT_DIR/vitest.config.mjs" ]; then
    CMD_TEST="npx vitest run"
  fi
fi

# --- Output JSON ---

python3 -c "
import json
result = {
    'project_dir': '$PROJECT_DIR',
    'project_type': '$PROJECT_TYPE',
    'config_files': {
        'package_json': $( [ "$HAS_PACKAGE_JSON" = true ] && echo 'True' || echo 'False' ),
        'tsconfig': $( [ "$HAS_TSCONFIG" = true ] && echo 'True' || echo 'False' ),
        'pyproject': $( [ "$HAS_PYPROJECT" = true ] && echo 'True' || echo 'False' ),
        'go_mod': $( [ "$HAS_GOMOD" = true ] && echo 'True' || echo 'False' ),
        'cargo': $( [ "$HAS_CARGO" = true ] && echo 'True' || echo 'False' )
    },
    'commands': {
        'build': '$CMD_BUILD' or None,
        'typecheck': '$CMD_TYPECHECK' or None,
        'lint': '$CMD_LINT' or None,
        'test': '$CMD_TEST' or None
    },
    'package_manager': '$( [ "$HAS_PACKAGE_JSON" = true ] && echo "$PKG_MANAGER" || echo "" )' or None
}
print(json.dumps(result, indent=2))
"
