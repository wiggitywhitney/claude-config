# ABOUTME: Tests that the verify test harness builds fixtures in their own repositories
# ABOUTME: Guards against git location variables inherited from a linked-worktree push
"""Tests for test_harness.py repository isolation.

Git exports GIT_DIR to hooks run from a linked worktree. A fixture builder that
inherits it would reinitialize the enclosing repository instead of creating its
own, setting core.bare and adding commits to the real branch. These tests run the
harness in a child interpreter with those variables pointing at a sentinel
repository and assert the sentinel is untouched.
"""

import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, TempDir, setup_git_repo

GIT = shutil.which("git")
if not GIT:
    raise RuntimeError("git not found on PATH")  # noqa: TRY003

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))

CHILD_SCRIPT = """
import sys, tempfile
sys.path.insert(0, {tests_dir!r})
import test_harness
fixture = tempfile.mkdtemp()
test_harness.setup_git_repo(fixture, branch="main")
print(fixture)
"""


def _git_output(repo, *args):
    """Run git in repo and return its stripped stdout."""
    result = subprocess.run(
        [GIT, *args], cwd=repo, capture_output=True, text=True,
    )
    return result.stdout.strip()


def run_tests():
    """Build a fixture while GIT_DIR names a linked worktree and assert nothing else changes."""
    t = TestResults("test_harness isolation tests")
    t.header()

    with TempDir() as sentinel, TempDir() as worktree_parent:
        setup_git_repo(sentinel, branch="main")
        worktree = os.path.join(worktree_parent, "worktree")
        subprocess.run(
            [GIT, "worktree", "add", "--quiet", worktree, "-b", "feat"],
            cwd=sentinel, capture_output=True, check=True,
        )
        # The git directory git exports as GIT_DIR to hooks run from this worktree
        sentinel_git_dir = _git_output(worktree, "rev-parse", "--absolute-git-dir")

        t.section("A child inherits GIT_DIR pointing at a linked worktree's git directory")

        env = os.environ.copy()
        env["GIT_DIR"] = sentinel_git_dir
        child = subprocess.run(
            [sys.executable, "-c", CHILD_SCRIPT.format(tests_dir=TESTS_DIR)],
            env=env, capture_output=True, text=True,
        )
        fixture = child.stdout.strip()

        t.assert_exit_code("child builds its fixture without error", child.returncode, 0)
        t.assert_equal(
            "fixture is its own repository",
            os.path.isdir(os.path.join(fixture, ".git")) if fixture else False,
            True,
        )
        t.assert_equal(
            "the other repository is not reconfigured as bare",
            _git_output(sentinel, "config", "--get", "core.bare"),
            "false",
        )
        t.assert_equal(
            "the worktree's branch gains no commits",
            _git_output(worktree, "rev-list", "--count", "HEAD"),
            "1",
        )

        if fixture:
            shutil.rmtree(fixture, ignore_errors=True)

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    _, failed, _ = run_tests()
    sys.exit(1 if failed else 0)
