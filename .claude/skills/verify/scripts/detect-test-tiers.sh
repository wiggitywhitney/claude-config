#!/usr/bin/env bash
# detect-test-tiers.sh — Detect which test tiers exist in a project
#
# Usage: detect-test-tiers.sh [project-directory]
# Output: JSON object with test tier presence booleans
#
# Detects whether a project has unit, integration, and e2e tests
# by checking for directory conventions, config files, package.json
# scripts, and test file patterns. Does NOT run any tests — only detection.
#
# Detection heuristics per project type:
#
#   Node.js/TypeScript:
#     Unit:        *.test.{js,ts,jsx,tsx} or *.spec.* files, OR tests/unit/ dir
#     Integration: tests/integration/ dir, OR test:integration script in package.json
#     E2E:         playwright/cypress config, tests/e2e/ dir, OR test:e2e script
#
#   Python:
#     Unit:        tests/unit/ dir, OR test_*.py files in tests/
#     Integration: tests/integration/ dir with test_*.py files
#     E2E:         tests/e2e/ dir, OR selenium/playwright in dependencies

set -euo pipefail

PROJECT_DIR="${1:-.}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Initialize tier results
HAS_UNIT=false
HAS_INTEGRATION=false
HAS_E2E=false

# Detect project type (lightweight — just enough to choose detection strategy)
PROJECT_TYPE="unknown"
if [ -f "$PROJECT_DIR/package.json" ]; then
  if [ -f "$PROJECT_DIR/tsconfig.json" ]; then
    PROJECT_TYPE="node-typescript"
  else
    PROJECT_TYPE="node-javascript"
  fi
elif [ -f "$PROJECT_DIR/pyproject.toml" ]; then
  PROJECT_TYPE="python"
elif [ -f "$PROJECT_DIR/go.mod" ]; then
  PROJECT_TYPE="go"
fi

# --- Node.js / TypeScript detection ---

if [ "$PROJECT_TYPE" = "node-typescript" ] || [ "$PROJECT_TYPE" = "node-javascript" ]; then

  # Read package.json scripts once
  SCRIPTS_JSON=$(python3 -c "
import json
try:
    with open('$PROJECT_DIR/package.json') as f:
        scripts = json.load(f).get('scripts', {})
    print(json.dumps(scripts))
except Exception:
    print('{}')
" 2>/dev/null || echo '{}')

  # Read package.json devDependencies once
  DEV_DEPS_JSON=$(python3 -c "
import json
try:
    with open('$PROJECT_DIR/package.json') as f:
        pkg = json.load(f)
    deps = pkg.get('devDependencies', {})
    deps.update(pkg.get('dependencies', {}))
    print(json.dumps(deps))
except Exception:
    print('{}')
" 2>/dev/null || echo '{}')

  # --- Unit tests ---
  # Check for test files (colocated or in test dirs)
  if [ -d "$PROJECT_DIR/tests/unit" ] || [ -d "$PROJECT_DIR/test/unit" ] || [ -d "$PROJECT_DIR/__tests__" ]; then
    HAS_UNIT=true
  fi

  # Check for test script in package.json
  if [ "$HAS_UNIT" = false ]; then
    if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; sys.exit(0 if 'test' in json.load(sys.stdin) else 1)" 2>/dev/null; then
      # Has a test script — check if test files actually exist
      if find "$PROJECT_DIR" -maxdepth 4 \
        \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.jsx" -o -name "*.test.tsx" \
           -o -name "*.spec.js" -o -name "*.spec.ts" -o -name "*.spec.jsx" -o -name "*.spec.tsx" \) \
        -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1 | grep -q .; then
        HAS_UNIT=true
      fi
    fi
  fi

  # Also check without a test script — test files alone count
  if [ "$HAS_UNIT" = false ]; then
    if find "$PROJECT_DIR" -maxdepth 4 \
      \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.jsx" -o -name "*.test.tsx" \
         -o -name "*.spec.js" -o -name "*.spec.ts" -o -name "*.spec.jsx" -o -name "*.spec.tsx" \) \
      -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1 | grep -q .; then
      HAS_UNIT=true
    fi
  fi

  # --- Integration tests ---
  if [ -d "$PROJECT_DIR/tests/integration" ] || [ -d "$PROJECT_DIR/test/integration" ]; then
    HAS_INTEGRATION=true
  fi

  if [ "$HAS_INTEGRATION" = false ]; then
    if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if 'test:integration' in s or 'test-integration' in s else 1)" 2>/dev/null; then
      HAS_INTEGRATION=true
    fi
  fi

  # --- E2E tests ---
  # Check for e2e test directories
  if [ -d "$PROJECT_DIR/tests/e2e" ] || [ -d "$PROJECT_DIR/test/e2e" ] || [ -d "$PROJECT_DIR/e2e" ]; then
    HAS_E2E=true
  fi

  # Check for Playwright config
  if [ "$HAS_E2E" = false ]; then
    for config in playwright.config.js playwright.config.ts playwright.config.mjs; do
      if [ -f "$PROJECT_DIR/$config" ]; then
        HAS_E2E=true
        break
      fi
    done
  fi

  # Check for Cypress config or directory
  if [ "$HAS_E2E" = false ]; then
    for config in cypress.config.js cypress.config.ts cypress.config.mjs; do
      if [ -f "$PROJECT_DIR/$config" ]; then
        HAS_E2E=true
        break
      fi
    done
    if [ "$HAS_E2E" = false ] && [ -d "$PROJECT_DIR/cypress" ]; then
      HAS_E2E=true
    fi
  fi

  # Check for e2e script in package.json
  if [ "$HAS_E2E" = false ]; then
    if echo "$SCRIPTS_JSON" | python3 -c "import json,sys; s=json.load(sys.stdin); sys.exit(0 if 'test:e2e' in s or 'test-e2e' in s or 'e2e' in s else 1)" 2>/dev/null; then
      HAS_E2E=true
    fi
  fi

  # Check for e2e frameworks in dependencies
  if [ "$HAS_E2E" = false ]; then
    if echo "$DEV_DEPS_JSON" | python3 -c "
import json, sys
deps = json.load(sys.stdin)
e2e_frameworks = ['@playwright/test', 'playwright', 'cypress', 'puppeteer', 'selenium-webdriver', 'webdriverio']
sys.exit(0 if any(f in deps for f in e2e_frameworks) else 1)
" 2>/dev/null; then
      HAS_E2E=true
    fi
  fi

fi

# --- Python detection ---

if [ "$PROJECT_TYPE" = "python" ]; then

  # --- Unit tests ---
  if [ -d "$PROJECT_DIR/tests/unit" ]; then
    # Check that it actually contains test files
    if find "$PROJECT_DIR/tests/unit" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
      HAS_UNIT=true
    fi
  fi

  # Fall back to test files in tests/ root (common for projects without tier directories)
  if [ "$HAS_UNIT" = false ] && [ -d "$PROJECT_DIR/tests" ]; then
    if find "$PROJECT_DIR/tests" -maxdepth 1 -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
      HAS_UNIT=true
    fi
  fi

  # --- Integration tests ---
  if [ -d "$PROJECT_DIR/tests/integration" ]; then
    if find "$PROJECT_DIR/tests/integration" -name "test_*.py" -o -name "*_test.py" 2>/dev/null | head -1 | grep -q .; then
      HAS_INTEGRATION=true
    fi
  fi

  # --- E2E tests ---
  if [ -d "$PROJECT_DIR/tests/e2e" ]; then
    HAS_E2E=true
  fi

  # Check for browser automation in dependencies
  if [ "$HAS_E2E" = false ]; then
    if python3 -c "
import sys
try:
    with open('$PROJECT_DIR/pyproject.toml') as f:
        content = f.read()
    e2e_deps = ['selenium', 'playwright', 'puppeteer', 'splinter']
    sys.exit(0 if any(d in content for d in e2e_deps) else 1)
except Exception:
    sys.exit(1)
" 2>/dev/null; then
      HAS_E2E=true
    fi
  fi

fi

# --- Output JSON ---

python3 -c "
import json
result = {
    'project_dir': '$PROJECT_DIR',
    'project_type': '$PROJECT_TYPE',
    'test_tiers': {
        'unit': $( [ "$HAS_UNIT" = true ] && echo 'True' || echo 'False' ),
        'integration': $( [ "$HAS_INTEGRATION" = true ] && echo 'True' || echo 'False' ),
        'e2e': $( [ "$HAS_E2E" = true ] && echo 'True' || echo 'False' )
    }
}
print(json.dumps(result, indent=2))
"
