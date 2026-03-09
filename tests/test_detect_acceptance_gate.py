#!/usr/bin/env python3
# ABOUTME: Tests for detect-acceptance-gate.sh — validates acceptance gate detection logic.
# ABOUTME: Covers workflow file detection, verify.json parsing, edge cases, and default directory behavior.
"""Tests for detect-acceptance-gate.sh — acceptance gate test detection.

Validates:
- Returns "false" for projects with no acceptance gate configuration
- Returns "true" when .github/workflows/acceptance-gate.yml exists
- Returns "true" when .claude/verify.json contains "acceptance_test"
- Returns "true" when both signals are present
- Returns "false" when verify.json exists but has no acceptance_test key
- Handles missing directories gracefully
- Defaults to current directory when no argument provided
"""

import os
import subprocess
import sys

# Import test harness from verify tests
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(TESTS_DIR)
VERIFY_TESTS_DIR = os.path.join(REPO_DIR, ".claude", "skills", "verify", "tests")
sys.path.insert(0, VERIFY_TESTS_DIR)

from test_harness import TestResults, TempDir, write_file

SCRIPT = os.path.join(REPO_DIR, "scripts", "detect-acceptance-gate.sh")


def run_detect(project_dir=None):
    """Run the detection script. Returns (exit_code, stdout_stripped)."""
    cmd = ["bash", SCRIPT]
    if project_dir is not None:
        cmd.append(project_dir)
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        cwd=project_dir,
    )
    return result.returncode, result.stdout.strip()


def run_tests():
    t = TestResults("detect-acceptance-gate.sh tests")
    t.header()

    # ─── Section 1: No acceptance gate configured ───
    t.section("No acceptance gate configured")

    # Empty project directory
    with TempDir() as tmp:
        exit_code, output = run_detect(tmp)
        t.assert_equal("empty project → exit 0", exit_code, 0)
        t.assert_equal("empty project → false", output, "false")

    # Project with unrelated files
    with TempDir() as tmp:
        write_file(tmp, ".github/workflows/ci.yml", "name: CI")
        write_file(tmp, ".claude/verify.json", '{"quick": "echo ok"}')
        exit_code, output = run_detect(tmp)
        t.assert_equal("unrelated files → exit 0", exit_code, 0)
        t.assert_equal("unrelated files → false", output, "false")

    # ─── Section 2: Workflow file detection ───
    t.section("Workflow file detection (.github/workflows/acceptance-gate.yml)")

    with TempDir() as tmp:
        write_file(tmp, ".github/workflows/acceptance-gate.yml", "name: Acceptance Gate")
        exit_code, output = run_detect(tmp)
        t.assert_equal("workflow exists → exit 0", exit_code, 0)
        t.assert_equal("workflow exists → true", output, "true")

    # ─── Section 3: verify.json detection ───
    t.section("verify.json detection (.claude/verify.json with acceptance_test)")

    with TempDir() as tmp:
        verify_json = '{"quick": "echo ok", "acceptance_test": "npx vitest run test/**/acceptance-gate.test.ts"}'
        write_file(tmp, ".claude/verify.json", verify_json)
        exit_code, output = run_detect(tmp)
        t.assert_equal("verify.json with acceptance_test → exit 0", exit_code, 0)
        t.assert_equal("verify.json with acceptance_test → true", output, "true")

    # verify.json exists but no acceptance_test key
    with TempDir() as tmp:
        write_file(tmp, ".claude/verify.json", '{"quick": "echo ok", "standard": "echo ok"}')
        exit_code, output = run_detect(tmp)
        t.assert_equal("verify.json without acceptance_test → exit 0", exit_code, 0)
        t.assert_equal("verify.json without acceptance_test → false", output, "false")

    # ─── Section 4: Both signals present ───
    t.section("Both signals present")

    with TempDir() as tmp:
        write_file(tmp, ".github/workflows/acceptance-gate.yml", "name: Acceptance Gate")
        verify_json = '{"acceptance_test": "npx vitest run"}'
        write_file(tmp, ".claude/verify.json", verify_json)
        exit_code, output = run_detect(tmp)
        t.assert_equal("both signals → exit 0", exit_code, 0)
        t.assert_equal("both signals → true", output, "true")

    # ─── Section 5: Edge cases ───
    t.section("Edge cases")

    # No .github directory at all
    with TempDir() as tmp:
        write_file(tmp, "README.md", "# Project")
        exit_code, output = run_detect(tmp)
        t.assert_equal("no .github dir → exit 0", exit_code, 0)
        t.assert_equal("no .github dir → false", output, "false")

    # No .claude directory at all
    with TempDir() as tmp:
        write_file(tmp, ".github/workflows/ci.yml", "name: CI")
        exit_code, output = run_detect(tmp)
        t.assert_equal("no .claude dir → exit 0", exit_code, 0)
        t.assert_equal("no .claude dir → false", output, "false")

    # verify.json with acceptance_test_ci (different key, should not match)
    with TempDir() as tmp:
        write_file(tmp, ".claude/verify.json", '{"acceptance_test_ci": "gh workflow run"}')
        exit_code, output = run_detect(tmp)
        t.assert_equal("acceptance_test_ci only → exit 0", exit_code, 0)
        # grep for "acceptance_test" (with quotes) does NOT match "acceptance_test_ci"
        # because the closing quote position differs — correct behavior
        t.assert_equal("acceptance_test_ci only → false (exact key match)", output, "false")

    # Default directory (no argument — uses cwd)
    with TempDir() as tmp:
        write_file(tmp, ".github/workflows/acceptance-gate.yml", "name: AG")
        result = subprocess.run(
            ["bash", SCRIPT],
            capture_output=True,
            text=True,
            cwd=tmp,
        )
        t.assert_equal("default dir (cwd) → exit 0", result.returncode, 0)
        t.assert_equal("default dir (cwd) → true", result.stdout.strip(), "true")

    return t.summary()


if __name__ == "__main__":
    sys.exit(run_tests())
