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

if [ "$HAS_GOMOD" = true ]; then
  PROJECT_TYPE="go"
elif [ "$HAS_TSCONFIG" = true ] && [ "$HAS_PACKAGE_JSON" = true ]; then
  PROJECT_TYPE="node-typescript"
elif [ "$HAS_PACKAGE_JSON" = true ]; then
  PROJECT_TYPE="node-javascript"
elif [ "$HAS_PYPROJECT" = true ]; then
  PROJECT_TYPE="python"
elif [ "$HAS_CARGO" = true ]; then
  PROJECT_TYPE="rust"
fi

# --- Detect available commands ---

if [ "$HAS_GOMOD" = true ]; then
  # Go project command detection
  # Decision 1: Prefer Makefile targets over raw Go commands
  HAS_MAKEFILE=false
  if [ -f "$PROJECT_DIR/Makefile" ]; then
    HAS_MAKEFILE=true
  fi

  # Detect build command
  if [ "$HAS_MAKEFILE" = true ] && grep -qE '^build[[:space:]]*:' "$PROJECT_DIR/Makefile"; then
    CMD_BUILD="make build"
  else
    CMD_BUILD="go build ./..."
  fi

  # Decision 3: CMD_TYPECHECK left empty — go build implies typecheck

  # Detect lint command
  # Priority: Makefile lint target > golangci-lint > Makefile vet target > go vet
  if [ "$HAS_MAKEFILE" = true ] && grep -qE '^lint[[:space:]]*:' "$PROJECT_DIR/Makefile"; then
    CMD_LINT="make lint"
  elif command -v golangci-lint &>/dev/null; then
    CMD_LINT="golangci-lint run"
  elif [ "$HAS_MAKEFILE" = true ] && grep -qE '^vet[[:space:]]*:' "$PROJECT_DIR/Makefile"; then
    CMD_LINT="make vet"
  else
    CMD_LINT="go vet ./..."
  fi

  # Detect test command
  if [ "$HAS_MAKEFILE" = true ] && grep -qE '^test[[:space:]]*:' "$PROJECT_DIR/Makefile"; then
    CMD_TEST="make test"
  else
    CMD_TEST="go test ./..."
  fi

elif [ "$HAS_PACKAGE_JSON" = true ]; then
  # Read package.json scripts using python3 (available on macOS)
  SCRIPTS_JSON=$(DETECT_PKG_PATH="$PROJECT_DIR/package.json" python3 -c "
import json, sys, os
try:
    with open(os.environ['DETECT_PKG_PATH']) as f:
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
  elif [ -f "$PROJECT_DIR/.eslintrc.json" ] || [ -f "$PROJECT_DIR/.eslintrc.js" ] || [ -f "$PROJECT_DIR/.eslintrc.yml" ] || [ -f "$PROJECT_DIR/.eslintrc.yaml" ] || [ -f "$PROJECT_DIR/eslint.config.js" ] || [ -f "$PROJECT_DIR/eslint.config.mjs" ] || [ -f "$PROJECT_DIR/eslint.config.ts" ]; then
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

DETECT_PROJECT_DIR="$PROJECT_DIR" \
DETECT_PROJECT_TYPE="$PROJECT_TYPE" \
DETECT_HAS_PKG_JSON="$HAS_PACKAGE_JSON" \
DETECT_HAS_TSCONFIG="$HAS_TSCONFIG" \
DETECT_HAS_PYPROJECT="$HAS_PYPROJECT" \
DETECT_HAS_GOMOD="$HAS_GOMOD" \
DETECT_HAS_CARGO="$HAS_CARGO" \
DETECT_CMD_BUILD="$CMD_BUILD" \
DETECT_CMD_TYPECHECK="$CMD_TYPECHECK" \
DETECT_CMD_LINT="$CMD_LINT" \
DETECT_CMD_TEST="$CMD_TEST" \
DETECT_PKG_MANAGER="$( [ "$HAS_PACKAGE_JSON" = true ] && echo "$PKG_MANAGER" || echo "" )" \
python3 -c "
import json, os
result = {
    'project_dir': os.environ['DETECT_PROJECT_DIR'],
    'project_type': os.environ['DETECT_PROJECT_TYPE'],
    'config_files': {
        'package_json': os.environ['DETECT_HAS_PKG_JSON'] == 'true',
        'tsconfig': os.environ['DETECT_HAS_TSCONFIG'] == 'true',
        'pyproject': os.environ['DETECT_HAS_PYPROJECT'] == 'true',
        'go_mod': os.environ['DETECT_HAS_GOMOD'] == 'true',
        'cargo': os.environ['DETECT_HAS_CARGO'] == 'true'
    },
    'commands': {
        'build': os.environ['DETECT_CMD_BUILD'] or None,
        'typecheck': os.environ['DETECT_CMD_TYPECHECK'] or None,
        'lint': os.environ['DETECT_CMD_LINT'] or None,
        'test': os.environ['DETECT_CMD_TEST'] or None
    },
    'package_manager': os.environ['DETECT_PKG_MANAGER'] or None
}
print(json.dumps(result, indent=2))
"
