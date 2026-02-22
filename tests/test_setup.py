#!/usr/bin/env python3
"""Tests for setup.sh — template resolution and settings generation.

Validates:
- $CLAUDE_CONFIG_DIR placeholder resolution
- Output is valid JSON
- All hook script paths in generated output exist on disk
- Edge cases: missing template, invalid template
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil

# Import test harness from verify tests
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(TESTS_DIR)
VERIFY_TESTS_DIR = os.path.join(REPO_DIR, ".claude", "skills", "verify", "tests")
sys.path.insert(0, VERIFY_TESTS_DIR)

from test_harness import TestResults, TempDir, write_file

SETUP_SCRIPT = os.path.join(REPO_DIR, "setup.sh")
TEMPLATE_FILE = os.path.join(REPO_DIR, "settings.template.json")


def run_setup(*args, env=None, cwd=None):
    """Run setup.sh with given arguments. Returns (exit_code, stdout, stderr)."""
    cmd = [SETUP_SCRIPT, *args]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
    )
    return result.returncode, result.stdout, result.stderr


def test_template_exists(t):
    """Template file must exist in repo root."""
    t.section("Template file")
    exists = os.path.isfile(TEMPLATE_FILE)
    t.assert_equal("settings.template.json exists", exists, True)


def test_template_has_placeholders(t):
    """Template must contain $CLAUDE_CONFIG_DIR placeholders."""
    t.section("Template placeholders")
    with open(TEMPLATE_FILE) as f:
        content = f.read()

    t.assert_contains(
        "template contains $CLAUDE_CONFIG_DIR",
        content, "$CLAUDE_CONFIG_DIR"
    )
    t.assert_not_contains(
        "template has no hardcoded home paths",
        content, "/Users/"
    )


def test_template_is_valid_json_structure(t):
    """Template with placeholders replaced should be valid JSON."""
    t.section("Template JSON structure")
    with open(TEMPLATE_FILE) as f:
        content = f.read()

    # Replace placeholder with a dummy path to validate JSON structure
    resolved = content.replace("$CLAUDE_CONFIG_DIR", "/tmp/fake-repo")
    try:
        data = json.loads(resolved)
        t.assert_equal("template resolves to valid JSON", True, True)
    except json.JSONDecodeError as e:
        t.assert_equal(f"template resolves to valid JSON (error: {e})", False, True)

    # Verify expected top-level keys
    t.assert_equal("has permissions key", "permissions" in data, True)
    t.assert_equal("has hooks key", "hooks" in data, True)
    t.assert_equal("has model key", "model" in data, True)


def test_resolve_to_stdout(t):
    """setup.sh with no --output should print resolved JSON to stdout."""
    t.section("Resolve to stdout")
    exit_code, stdout, stderr = run_setup()

    t.assert_equal("exits 0", exit_code, 0)

    # stdout should be valid JSON
    try:
        data = json.loads(stdout)
        t.assert_equal("stdout is valid JSON", True, True)
    except json.JSONDecodeError:
        t.assert_equal("stdout is valid JSON", False, True)
        return

    # No placeholders should remain
    t.assert_not_contains(
        "no $CLAUDE_CONFIG_DIR in output",
        stdout, "$CLAUDE_CONFIG_DIR"
    )

    # Paths should be resolved to real repo path
    t.assert_contains(
        "paths resolved to repo directory",
        stdout, REPO_DIR
    )


def test_resolve_to_file(t):
    """setup.sh --output FILE should write resolved JSON to file."""
    t.section("Resolve to file")
    with TempDir() as tmp:
        output_path = os.path.join(tmp, "settings.json")
        exit_code, stdout, stderr = run_setup("--output", output_path)

        t.assert_equal("exits 0", exit_code, 0)
        t.assert_equal("output file created", os.path.isfile(output_path), True)

        with open(output_path) as f:
            content = f.read()

        try:
            data = json.loads(content)
            t.assert_equal("output file is valid JSON", True, True)
        except json.JSONDecodeError:
            t.assert_equal("output file is valid JSON", False, True)
            return

        t.assert_not_contains(
            "no placeholders in output file",
            content, "$CLAUDE_CONFIG_DIR"
        )


def test_all_hook_paths_exist(t):
    """Every hook command path in the resolved output must exist on disk."""
    t.section("Hook path validation")
    exit_code, stdout, stderr = run_setup()

    if exit_code != 0:
        t.assert_equal("setup.sh must succeed for path validation", exit_code, 0)
        return

    data = json.loads(stdout)
    hooks = data.get("hooks", {})
    all_paths_valid = True
    checked = 0

    for event_type, matchers in hooks.items():
        for matcher in matchers:
            for hook in matcher.get("hooks", []):
                path = hook.get("command", "")
                if path:
                    checked += 1
                    exists = os.path.isfile(path)
                    t.assert_equal(
                        f"hook path exists: {os.path.basename(path)}",
                        exists, True
                    )
                    if not exists:
                        all_paths_valid = False

    t.assert_equal(f"checked {checked} hook paths (expected 10)", checked, 10)


def test_validate_flag(t):
    """setup.sh --validate should check paths and report without writing."""
    t.section("Validate mode")
    exit_code, stdout, stderr = run_setup("--validate")

    t.assert_equal("validate exits 0 when all paths exist", exit_code, 0)
    t.assert_contains("validate reports success", stdout, "valid")


def test_custom_template(t):
    """setup.sh --template FILE should use a custom template."""
    t.section("Custom template")
    with TempDir() as tmp:
        # Create a minimal template
        template = {
            "hooks": {
                "PreToolUse": [
                    {
                        "matcher": "Bash",
                        "hooks": [
                            {
                                "type": "command",
                                "command": "$CLAUDE_CONFIG_DIR/scripts/google-mcp-safety-hook.py"
                            }
                        ]
                    }
                ]
            }
        }
        template_path = write_file(tmp, "custom.template.json", json.dumps(template, indent=2))
        exit_code, stdout, stderr = run_setup("--template", template_path)

        t.assert_equal("exits 0 with custom template", exit_code, 0)

        data = json.loads(stdout)
        hook_path = data["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        t.assert_contains(
            "custom template paths resolved",
            hook_path, REPO_DIR
        )
        t.assert_not_contains(
            "no placeholder in resolved path",
            hook_path, "$CLAUDE_CONFIG_DIR"
        )


def test_missing_template_fails(t):
    """setup.sh should fail if template file doesn't exist."""
    t.section("Error handling")
    exit_code, stdout, stderr = run_setup("--template", "/nonexistent/template.json")

    t.assert_equal("exits non-zero for missing template", exit_code != 0, True)
    t.assert_contains("error mentions template", stderr.lower(), "template")


def test_idempotent(t):
    """Running setup.sh twice produces identical output."""
    t.section("Idempotency")
    _, stdout1, _ = run_setup()
    _, stdout2, _ = run_setup()

    t.assert_equal("two runs produce identical output", stdout1, stdout2)


def run_tests():
    t = TestResults("setup.sh — template resolution")
    t.header()

    test_template_exists(t)
    test_template_has_placeholders(t)
    test_template_is_valid_json_structure(t)
    test_resolve_to_stdout(t)
    test_resolve_to_file(t)
    test_all_hook_paths_exist(t)
    test_validate_flag(t)
    test_custom_template(t)
    test_missing_template_fails(t)
    test_idempotent(t)

    exit_code = t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
