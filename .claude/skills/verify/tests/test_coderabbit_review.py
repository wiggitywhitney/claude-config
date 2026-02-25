"""Tests for coderabbit-review.sh — CodeRabbit CLI review integration.

Exercises the script with:
- CLI not installed (no coderabbit in PATH, no ~/.local/bin/coderabbit)
- No base branch determinable
- CLI returns findings (mock)
- CLI returns clean review (mock)
- CLI fails / times out (mock)
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, script_path, TempDir, setup_git_repo,
    write_file, make_executable, run_script_combined,
)

SCRIPT = script_path("coderabbit-review.sh")


def create_mock_coderabbit(temp_dir, output="No issues found.", exit_code=0):
    """Create a mock coderabbit CLI that returns fixed output.

    Uses a separate file for output to avoid shell-quote injection issues.
    Returns the path to a bin directory that should be prepended to PATH.
    """
    bin_dir = os.path.join(temp_dir, "mock-bin")
    os.makedirs(bin_dir, exist_ok=True)
    output_file = os.path.join(bin_dir, "coderabbit-output.txt")
    with open(output_file, "w") as f:
        f.write(output)
    cr_script = os.path.join(bin_dir, "coderabbit")
    write_file(temp_dir, "mock-bin/coderabbit", f"""#!/usr/bin/env bash
# Mock coderabbit CLI for testing
if echo "$@" | grep -q "review"; then
    cat "{output_file}"
    exit {exit_code}
fi
exit 0
""")
    make_executable(cr_script)
    return bin_dir


def run_review(project_dir, base_branch="", extra_path=None, home_override=None):
    """Run coderabbit-review.sh with controlled environment."""
    env = os.environ.copy()
    if extra_path:
        env["PATH"] = f"{extra_path}:{env['PATH']}"
    if home_override:
        env["HOME"] = home_override

    args = [SCRIPT, project_dir]
    if base_branch:
        args.append(base_branch)

    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        env=env,
        timeout=30,
    )
    return result.returncode, result.stdout + result.stderr


def run_tests():
    t = TestResults("coderabbit-review.sh tests")
    t.header()

    # ─── Section 1: CLI not installed ───
    t.section("CLI not installed")

    with TempDir() as temp_dir:
        repo = setup_git_repo(temp_dir)

        # Use a minimal PATH that excludes coderabbit, and a fake HOME.
        # os.defpath provides the OS default PATH (portable across platforms).
        fake_home = os.path.join(temp_dir, "fake-home")
        os.makedirs(fake_home, exist_ok=True)
        minimal_env = os.environ.copy()
        minimal_env["PATH"] = os.defpath
        minimal_env["HOME"] = fake_home

        result = subprocess.run(
            [SCRIPT, repo, "main"],
            capture_output=True,
            text=True,
            env=minimal_env,
            timeout=10,
        )

        t.assert_equal("exits 0 when CLI not installed", result.returncode, 0)
        t.assert_contains("reports CLI not installed",
                          result.stdout, "not installed")

    # ─── Section 2: No base branch ───
    t.section("No base branch determinable")

    with TempDir() as temp_dir:
        repo = setup_git_repo(temp_dir)
        mock_bin = create_mock_coderabbit(temp_dir)

        # Don't provide a base branch and repo has no origin/main
        exit_code, output = run_review(repo, extra_path=mock_bin)

        t.assert_equal("exits 0 when no base branch", exit_code, 0)
        t.assert_contains("reports no base branch",
                          output, "Cannot determine base branch")

    # ─── Section 3: CLI returns findings ───
    t.section("CLI returns review findings")

    with TempDir() as temp_dir:
        repo = setup_git_repo(temp_dir)
        findings = "Issue: Missing error handling in src/app.ts:42"
        mock_bin = create_mock_coderabbit(temp_dir, output=findings)

        exit_code, output = run_review(repo, base_branch="main",
                                       extra_path=mock_bin)

        t.assert_equal("exits 0 with findings", exit_code, 0)
        t.assert_contains("includes review findings", output, findings)
        t.assert_contains("reports review complete",
                          output, "CodeRabbit CLI review complete")

    # ─── Section 4: CLI returns clean review ───
    t.section("CLI returns clean review (no issues)")

    with TempDir() as temp_dir:
        repo = setup_git_repo(temp_dir)
        mock_bin = create_mock_coderabbit(temp_dir, output="No issues found.")

        exit_code, output = run_review(repo, base_branch="main",
                                       extra_path=mock_bin)

        t.assert_equal("exits 0 with clean review", exit_code, 0)
        t.assert_contains("includes clean output", output, "No issues found.")

    # ─── Section 5: CLI fails ───
    t.section("CLI failure handling")

    with TempDir() as temp_dir:
        repo = setup_git_repo(temp_dir)
        mock_bin = create_mock_coderabbit(temp_dir, output="", exit_code=1)

        exit_code, output = run_review(repo, base_branch="main",
                                       extra_path=mock_bin)

        t.assert_equal("exits 0 when CLI fails", exit_code, 0)
        t.assert_contains("reports failure gracefully",
                          output, "skipping")

    # ─── Section 6: Explicit base branch passed through ───
    t.section("Base branch handling")

    with TempDir() as temp_dir:
        repo = setup_git_repo(temp_dir)
        mock_bin = create_mock_coderabbit(temp_dir, output="Clean.")

        exit_code, output = run_review(repo, base_branch="origin/main",
                                       extra_path=mock_bin)

        t.assert_equal("exits 0 with explicit base", exit_code, 0)
        t.assert_contains("reports base branch",
                          output, "origin/main")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
