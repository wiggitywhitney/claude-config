# ABOUTME: Test suite for the check-aboutme.sh PreToolUse hook
# ABOUTME: Validates ABOUTME header enforcement across file types, skip lists, and edge cases
"""Tests for check-aboutme.sh hook.

Exercises the PreToolUse hook on Write|Edit with:
- Write operations with/without ABOUTME headers
- Edit operations on files with/without ABOUTME headers
- Edit operations that add ABOUTME headers (fix-and-retry flow)
- Skip list files (config, markdown, index files, generated files)
- Multiple file types and comment syntaxes
- Edge cases (shebangs, empty content, unknown extensions)
"""

import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, hook_path, run_hook, TempDir, write_file


HOOK = hook_path("check-aboutme.sh")


def make_write_input(file_path, content):
    """Build PreToolUse JSON for a Write tool event."""
    return json.dumps({
        "tool_name": "Write",
        "tool_input": {"file_path": file_path, "content": content},
    })


def make_edit_input(file_path, old_string="old", new_string="new"):
    """Build PreToolUse JSON for an Edit tool event."""
    return json.dumps({
        "tool_name": "Edit",
        "tool_input": {
            "file_path": file_path,
            "old_string": old_string,
            "new_string": new_string,
        },
    })


def run_tests():
    t = TestResults("check-aboutme.sh tests")
    t.header()

    # ─── Section 1: Write with ABOUTME headers (should allow) ───
    t.section("Write with ABOUTME headers (should allow)")

    t.assert_allow(
        "Python file with ABOUTME header",
        HOOK,
        make_write_input("src/app.py",
                         "# ABOUTME: Main application entry point\n# ABOUTME: Handles CLI argument parsing\nimport sys\n"))

    t.assert_allow(
        "TypeScript file with ABOUTME header",
        HOOK,
        make_write_input("src/utils.ts",
                         "// ABOUTME: Utility functions for string manipulation\n// ABOUTME: Used across the application\nexport function trim() {}\n"))

    t.assert_allow(
        "JavaScript file with ABOUTME header",
        HOOK,
        make_write_input("src/index.js",
                         "// ABOUTME: Express server setup\n// ABOUTME: Configures middleware and routes\nconst express = require('express');\n"))

    t.assert_allow(
        "Bash file with ABOUTME after shebang",
        HOOK,
        make_write_input("src/deploy.sh",
                         "#!/usr/bin/env bash\n# ABOUTME: Deployment script for production\n# ABOUTME: Handles rolling updates\nset -euo pipefail\n"))

    t.assert_allow(
        "TSX file with ABOUTME header",
        HOOK,
        make_write_input("src/Button.tsx",
                         "// ABOUTME: Reusable button component\n// ABOUTME: Supports primary and secondary variants\nimport React from 'react';\n"))

    t.assert_allow(
        "JSX file with ABOUTME header",
        HOOK,
        make_write_input("src/App.jsx",
                         "// ABOUTME: Root application component\n// ABOUTME: Sets up routing and global state\nimport React from 'react';\n"))

    t.assert_allow(
        "Single ABOUTME line is sufficient",
        HOOK,
        make_write_input("src/simple.py",
                         "# ABOUTME: Simple utility module\nimport os\n"))

    # ─── Section 2: Write without ABOUTME headers (should deny) ───
    t.section("Write without ABOUTME headers (should deny)")

    t.assert_deny_contains(
        "Python file missing ABOUTME",
        HOOK,
        make_write_input("src/app.py",
                         "import sys\n\ndef main():\n    pass\n"),
        "ABOUTME")

    t.assert_deny_contains(
        "TypeScript file missing ABOUTME",
        HOOK,
        make_write_input("src/utils.ts",
                         "export function trim(s: string): string {\n  return s.trim();\n}\n"),
        "ABOUTME")

    t.assert_deny_contains(
        "JavaScript file missing ABOUTME",
        HOOK,
        make_write_input("src/server.js",
                         "const express = require('express');\nconst app = express();\n"),
        "ABOUTME")

    t.assert_deny_contains(
        "Bash file missing ABOUTME",
        HOOK,
        make_write_input("src/run.sh",
                         "#!/usr/bin/env bash\nset -euo pipefail\necho 'hello'\n"),
        "ABOUTME")

    t.assert_deny_contains(
        "TSX file missing ABOUTME",
        HOOK,
        make_write_input("src/Card.tsx",
                         "import React from 'react';\nexport const Card = () => <div />;\n"),
        "ABOUTME")

    t.assert_deny_contains(
        "JSX file missing ABOUTME",
        HOOK,
        make_write_input("src/List.jsx",
                         "import React from 'react';\nexport const List = () => <ul />;\n"),
        "ABOUTME")

    # ─── Section 3: Edit on files WITH ABOUTME on disk (should allow) ───
    t.section("Edit on files with ABOUTME on disk (should allow)")

    with TempDir() as tmp:
        # Python file with ABOUTME
        py_file = write_file(tmp, "module.py",
                             "# ABOUTME: Module for data processing\n# ABOUTME: Transforms input records\nimport json\n\ndef process(): pass\n")
        t.assert_allow(
            "Edit Python file that has ABOUTME on disk",
            HOOK,
            make_edit_input(py_file, "def process(): pass", "def process(data): return data"))

        # TypeScript file with ABOUTME
        ts_file = write_file(tmp, "service.ts",
                             "// ABOUTME: API service layer\n// ABOUTME: Handles HTTP requests\nexport class Service {}\n")
        t.assert_allow(
            "Edit TypeScript file that has ABOUTME on disk",
            HOOK,
            make_edit_input(ts_file, "export class Service {}", "export class Service { fetch() {} }"))

        # Bash file with ABOUTME after shebang
        sh_file = write_file(tmp, "build.sh",
                             "#!/usr/bin/env bash\n# ABOUTME: Build script\n# ABOUTME: Compiles and packages\necho 'building'\n")
        t.assert_allow(
            "Edit Bash file that has ABOUTME after shebang",
            HOOK,
            make_edit_input(sh_file, "echo 'building'", "echo 'building v2'"))

    # ─── Section 4: Edit on files WITHOUT ABOUTME on disk (should deny) ───
    t.section("Edit on files without ABOUTME on disk (should deny)")

    with TempDir() as tmp:
        # Python file without ABOUTME
        py_file = write_file(tmp, "legacy.py",
                             "import os\n\ndef old_function():\n    pass\n")
        t.assert_deny_contains(
            "Edit Python file missing ABOUTME on disk",
            HOOK,
            make_edit_input(py_file, "def old_function():\n    pass",
                            "def old_function():\n    return True"),
            "ABOUTME")

        # TypeScript file without ABOUTME
        ts_file = write_file(tmp, "legacy.ts",
                             "export const value = 42;\n")
        t.assert_deny_contains(
            "Edit TypeScript file missing ABOUTME on disk",
            HOOK,
            make_edit_input(ts_file, "export const value = 42;",
                            "export const value = 43;"),
            "ABOUTME")

    # ─── Section 5: Edit that ADDS ABOUTME (fix-and-retry, should allow) ───
    t.section("Edit adding ABOUTME header (fix-and-retry flow)")

    with TempDir() as tmp:
        # File without ABOUTME, but new_string adds it
        py_file = write_file(tmp, "fixme.py",
                             "import os\n\ndef work(): pass\n")
        t.assert_allow(
            "Edit adding ABOUTME to Python file",
            HOOK,
            make_edit_input(py_file,
                            "import os",
                            "# ABOUTME: Worker module\n# ABOUTME: Processes background jobs\nimport os"))

        ts_file = write_file(tmp, "fixme.ts",
                             "export const x = 1;\n")
        t.assert_allow(
            "Edit adding ABOUTME to TypeScript file",
            HOOK,
            make_edit_input(ts_file,
                            "export const x = 1;",
                            "// ABOUTME: Config constants\n// ABOUTME: Exported values\nexport const x = 1;"))

    # ─── Section 6: Skip list files (should allow silently) ───
    t.section("Skip list files (should allow)")

    # Python init files
    t.assert_allow(
        "Skip __init__.py",
        HOOK,
        make_write_input("src/pkg/__init__.py",
                         "from .module import something\n"))

    # Config files (no comment syntax / not meaningful)
    t.assert_allow(
        "Skip .json files",
        HOOK,
        make_write_input("src/package.json",
                         '{"name": "test"}\n'))

    t.assert_allow(
        "Skip .yaml files",
        HOOK,
        make_write_input("src/config.yaml",
                         "key: value\n"))

    t.assert_allow(
        "Skip .yml files",
        HOOK,
        make_write_input("src/docker-compose.yml",
                         "version: '3'\n"))

    t.assert_allow(
        "Skip .toml files",
        HOOK,
        make_write_input("src/pyproject.toml",
                         "[project]\nname = 'test'\n"))

    # Markdown files (own heading conventions)
    t.assert_allow(
        "Skip .md files",
        HOOK,
        make_write_input("src/README.md",
                         "# My Project\n\nSome description.\n"))

    # CSS files (not in supported list)
    t.assert_allow(
        "Skip .css files (unsupported extension)",
        HOOK,
        make_write_input("src/styles.css",
                         "body { margin: 0; }\n"))

    # HTML files
    t.assert_allow(
        "Skip .html files (unsupported extension)",
        HOOK,
        make_write_input("src/index.html",
                         "<html><body>Hello</body></html>\n"))

    # Lock files
    t.assert_allow(
        "Skip package-lock.json",
        HOOK,
        make_write_input("src/package-lock.json",
                         '{"lockfileVersion": 3}\n'))

    # Env files
    t.assert_allow(
        "Skip .env files",
        HOOK,
        make_write_input("src/.env",
                         "SECRET=value\n"))

    # .cfg files
    t.assert_allow(
        "Skip .cfg files",
        HOOK,
        make_write_input("src/setup.cfg",
                         "[metadata]\nname = test\n"))

    # .ini files
    t.assert_allow(
        "Skip .ini files",
        HOOK,
        make_write_input("src/config.ini",
                         "[section]\nkey = value\n"))

    # Generated/vendored files
    t.assert_allow(
        "Skip files in node_modules",
        HOOK,
        make_write_input("src/node_modules/pkg/index.js",
                         "module.exports = {};\n"))

    t.assert_allow(
        "Skip files in relative node_modules path",
        HOOK,
        make_write_input("node_modules/pkg/index.js",
                         "module.exports = {};\n"))

    t.assert_allow(
        "Skip .min.js files",
        HOOK,
        make_write_input("src/bundle.min.js",
                         "!function(){}\n"))

    t.assert_allow(
        "Skip .d.ts declaration files",
        HOOK,
        make_write_input("src/types.d.ts",
                         "declare module 'test' {}\n"))

    t.assert_allow(
        "Skip .map files",
        HOOK,
        make_write_input("src/bundle.js.map",
                         '{"version":3}\n'))

    # ─── Section 7: Edge cases ───
    t.section("Edge cases")

    t.assert_allow(
        "Empty content Write (no file path extension)",
        HOOK,
        make_write_input("src/Makefile", "all:\n\techo hello\n"))

    t.assert_allow(
        "File with no extension is skipped",
        HOOK,
        make_write_input("src/Dockerfile",
                         "FROM node:18\nRUN npm install\n"))

    t.assert_deny_contains(
        "ABOUTME in wrong position (not in first 3 lines) for Python",
        HOOK,
        make_write_input("src/late.py",
                         "import os\nimport sys\nimport json\n# ABOUTME: Too late\ndef main(): pass\n"),
        "ABOUTME")

    t.assert_allow(
        "ABOUTME on line 3 (within first 3 lines)",
        HOOK,
        make_write_input("src/third.py",
                         "# Some comment\n# Another comment\n# ABOUTME: This is on line 3\ndef main(): pass\n"))

    t.assert_allow(
        "Bash shebang + ABOUTME on line 2 is fine",
        HOOK,
        make_write_input("src/script.sh",
                         "#!/bin/bash\n# ABOUTME: Script purpose\nset -e\n"))

    # ─── Section 8: Edit on non-existent file (should allow gracefully) ───
    t.section("Edit on non-existent file (graceful handling)")

    with TempDir() as tmp:
        missing_file = os.path.join(tmp, "nonexistent.py")
        t.assert_allow(
            "Edit on file that doesn't exist on disk allows gracefully",
            HOOK,
            make_edit_input(missing_file, "old code", "new code"))

    # ─── Section 9: Multiple file types comment syntax ───
    t.section("Comment syntax per file type")

    # Verify that Python uses # and TS uses // correctly
    t.assert_deny_contains(
        "Python file with // ABOUTME (wrong comment syntax) is denied",
        HOOK,
        make_write_input("src/wrong.py",
                         "// ABOUTME: Wrong syntax for Python\n// ABOUTME: Should use hash\ndef main(): pass\n"),
        "ABOUTME")

    t.assert_deny_contains(
        "TypeScript file with # ABOUTME (wrong comment syntax) is denied",
        HOOK,
        make_write_input("src/wrong.ts",
                         "# ABOUTME: Wrong syntax for TypeScript\n# ABOUTME: Should use double-slash\nexport const x = 1;\n"),
        "ABOUTME")

    t.assert_allow(
        "Bash file with # ABOUTME (correct syntax) is allowed",
        HOOK,
        make_write_input("src/correct.sh",
                         "# ABOUTME: Correct bash syntax\n# ABOUTME: Uses hash comment\necho hello\n"))

    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
