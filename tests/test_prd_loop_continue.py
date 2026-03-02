#!/usr/bin/env python3
"""Tests for prd-loop-continue.sh — SessionStart hook for PRD loop continuation.

Validates:
- No-op (silent) when not in a git repo
- No-op when on main/master branch
- No-op when on a non-PRD feature branch
- No-op when PRD file not found for branch number
- Injects "/prd-next" guidance when unchecked items remain
- Injects "/prd-done" guidance when all items are checked
- Handles mixed checked/unchecked items correctly
- Falls back to $PWD when cwd is empty in payload
"""

import json
import os
import subprocess
import sys

# Import test harness from verify tests
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(TESTS_DIR)
VERIFY_TESTS_DIR = os.path.join(REPO_DIR, ".claude", "skills", "verify", "tests")
sys.path.insert(0, VERIFY_TESTS_DIR)

from test_harness import TestResults, TempDir, setup_git_repo, write_file

HOOK = os.path.join(REPO_DIR, "scripts", "prd-loop-continue.sh")
GIT = "git"


def make_session_input(cwd, source="clear"):
    """Build SessionStart hook event JSON."""
    return json.dumps({
        "session_id": "test-session-123",
        "cwd": cwd,
        "source": source,
    })


def run_hook(json_input, env=None, cwd=None):
    """Run the hook script, piping json_input to stdin. Returns (exit_code, stdout, stderr)."""
    result = subprocess.run(
        ["bash", HOOK],
        input=json_input,
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
    )
    return result.returncode, result.stdout, result.stderr


PRD_WITH_UNCHECKED = """\
# PRD #12: Test Feature

**Status**: In Progress

## Milestones

- [x] Set up project structure
- [x] Implement core logic
- [ ] Add error handling
- [ ] Write integration tests
"""

PRD_ALL_CHECKED = """\
# PRD #12: Test Feature

**Status**: Complete

## Milestones

- [x] Set up project structure
- [x] Implement core logic
- [x] Add error handling
- [x] Write integration tests
"""

PRD_SINGLE_UNCHECKED = """\
# PRD #7: Small Feature

## Milestones

- [x] First task
- [ ] Last remaining task
"""

PRD_NO_CHECKBOXES = """\
# PRD #42: Simple Feature

Just a description with no checkboxes.
"""


def run_tests():
    t = TestResults("prd-loop-continue.sh tests")
    t.header()

    # ─── Section 1: No-op scenarios (should produce no stdout) ───
    t.section("No-op scenarios (no stdout)")

    # Not in a git repo
    with TempDir() as tmp:
        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("not in git repo → exit 0", exit_code, 0)
        t.assert_equal("not in git repo → no stdout", stdout, "")

    # On main branch
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("on main branch → exit 0", exit_code, 0)
        t.assert_equal("on main branch → no stdout", stdout, "")

    # On non-PRD feature branch
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/add-logging", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("non-PRD feature branch → exit 0", exit_code, 0)
        t.assert_equal("non-PRD feature branch → no stdout", stdout, "")

    # On PRD branch but no matching PRD file
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-99-missing", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        os.makedirs(os.path.join(tmp, "prds"))
        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("no matching PRD file → exit 0", exit_code, 0)
        t.assert_equal("no matching PRD file → no stdout", stdout, "")

    # On PRD branch but no prds/ directory
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-5-something", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("no prds/ directory → exit 0", exit_code, 0)
        t.assert_equal("no prds/ directory → no stdout", stdout, "")

    # ─── Section 2: Unchecked items → /prd-next guidance ───
    t.section("Unchecked items → /prd-next guidance")

    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-12-test-feature", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        write_file(tmp, "prds/12-test-feature.md", PRD_WITH_UNCHECKED)

        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("unchecked items → exit 0", exit_code, 0)
        t.assert_contains("unchecked items → mentions PRD number", stdout, "#12")
        t.assert_contains("unchecked items → mentions /prd-next", stdout, "/prd-next")
        t.assert_contains("unchecked items → mentions remaining count", stdout, "2")
        t.assert_not_contains("unchecked items → does not mention /prd-done", stdout, "/prd-done")

    # Single unchecked item
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-7-small-feature", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        write_file(tmp, "prds/7-small-feature.md", PRD_SINGLE_UNCHECKED)

        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("single unchecked → exit 0", exit_code, 0)
        t.assert_contains("single unchecked → mentions /prd-next", stdout, "/prd-next")
        t.assert_contains("single unchecked → count is 1", stdout, "1")

    # ─── Section 3: All items checked → /prd-done guidance ───
    t.section("All items checked → /prd-done guidance")

    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-12-test-feature", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        write_file(tmp, "prds/12-test-feature.md", PRD_ALL_CHECKED)

        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("all checked → exit 0", exit_code, 0)
        t.assert_contains("all checked → mentions PRD number", stdout, "#12")
        t.assert_contains("all checked → mentions /prd-done", stdout, "/prd-done")
        t.assert_not_contains("all checked → does not mention /prd-next", stdout, "/prd-next")

    # ─── Section 4: Edge cases ───
    t.section("Edge cases")

    # PRD with no checkboxes at all → treat as complete
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-42-simple", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        write_file(tmp, "prds/42-simple.md", PRD_NO_CHECKBOXES)

        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("no checkboxes → exit 0", exit_code, 0)
        t.assert_contains("no checkboxes → mentions /prd-done", stdout, "/prd-done")

    # Branch name with extra segments (feature/prd-12-multi-word-name)
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-12-multi-word-name", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        write_file(tmp, "prds/12-test-feature.md", PRD_WITH_UNCHECKED)

        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("multi-word branch → exit 0", exit_code, 0)
        t.assert_contains("multi-word branch → finds PRD correctly", stdout, "#12")
        t.assert_contains("multi-word branch → mentions /prd-next", stdout, "/prd-next")

    # Empty cwd in payload → falls back to env PWD
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-12-test", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        write_file(tmp, "prds/12-test-feature.md", PRD_WITH_UNCHECKED)

        empty_payload = json.dumps({"session_id": "test", "cwd": "", "source": "clear"})
        exit_code, stdout, stderr = run_hook(empty_payload, cwd=tmp)
        t.assert_equal("empty cwd fallback → exit 0", exit_code, 0)
        # With cwd pointing to the right place, $PWD fallback should work
        t.assert_contains("empty cwd fallback → finds PRD", stdout, "#12")

    # Deferred [~] and blocked [!] items should not count as unchecked
    with TempDir() as tmp:
        setup_git_repo(tmp, branch="main")
        subprocess.run(
            [GIT, "checkout", "-b", "feature/prd-15-deferred", "--quiet"],
            cwd=tmp, capture_output=True, check=True,
        )
        prd_deferred = """\
# PRD #15: Deferred Items

## Milestones

- [x] Done task
- [~] Deferred task
- [!] Blocked task
"""
        write_file(tmp, "prds/15-deferred.md", prd_deferred)

        exit_code, stdout, stderr = run_hook(make_session_input(tmp))
        t.assert_equal("deferred/blocked only → exit 0", exit_code, 0)
        t.assert_contains("deferred/blocked → treats as complete", stdout, "/prd-done")

    return t.summary()


if __name__ == "__main__":
    sys.exit(run_tests())
