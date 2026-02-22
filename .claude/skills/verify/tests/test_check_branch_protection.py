"""Tests for check-branch-protection.sh hook.

Exercises the hook with:
- Non-commit commands (should passthrough silently)
- Commits on feature branches (should passthrough)
- Commits on main/master (should deny)
- Commits on main/master with .skip-branching (should passthrough)
- Edge cases (non-git dir, -C flag)
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, hook_path, make_hook_input, TempDir, setup_git_repo, write_file,
)

HOOK = hook_path("check-branch-protection.sh")


def run_tests():
    t = TestResults("check-branch-protection.sh tests")
    t.header()

    with TempDir() as temp_dir:
        # Set up a git repo on main with a feature branch
        setup_git_repo(temp_dir, branch="main")
        subprocess.run(
            ["git", "checkout", "-b", "feature/test-branch", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )
        # Switch back to main for initial tests
        subprocess.run(
            ["git", "checkout", "main", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        # ─── Section 1: Non-commit commands (silent passthrough) ───
        t.section("Non-commit commands (should passthrough)")

        t.assert_allow("git status passes through",
                       HOOK, make_hook_input("git status", temp_dir))

        t.assert_allow("git push passes through",
                       HOOK, make_hook_input("git push origin main", temp_dir))

        t.assert_allow("npm test passes through",
                       HOOK, make_hook_input("npm test", temp_dir))

        # ─── Section 2: Commits on feature branches (should passthrough) ───
        t.section("Commits on feature branches (should passthrough)")

        subprocess.run(
            ["git", "checkout", "feature/test-branch", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        t.assert_allow("commit on feature branch passes through",
                       HOOK, make_hook_input('git commit -m "feat: add feature"', temp_dir))

        t.assert_allow("chained commit on feature branch passes through",
                       HOOK, make_hook_input('git add . && git commit -m "fix: update"', temp_dir))

        # ─── Section 3: Commits on main/master (should deny) ───
        t.section("Commits on main/master (should deny)")

        subprocess.run(
            ["git", "checkout", "main", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        t.assert_deny("commit on main is blocked",
                      HOOK, make_hook_input('git commit -m "fix: direct to main"', temp_dir))

        t.assert_deny("chained commit on main is blocked",
                      HOOK, make_hook_input('git add . && git commit -m "fix: chained on main"', temp_dir))

        # Test master branch in a subdirectory
        master_dir = os.path.join(temp_dir, "master-repo")
        os.makedirs(master_dir)
        setup_git_repo(master_dir, branch="master")

        t.assert_deny("commit on master is blocked",
                      HOOK, make_hook_input('git commit -m "fix: direct to master"', master_dir))

        # ─── Section 4: .skip-branching opt-out (should passthrough) ───
        t.section(".skip-branching opt-out (should passthrough)")

        # Back on main in the main temp_dir
        write_file(temp_dir, ".skip-branching")

        t.assert_allow("commit on main with .skip-branching passes through",
                       HOOK, make_hook_input('git commit -m "fix: allowed on main"', temp_dir))

        os.remove(os.path.join(temp_dir, ".skip-branching"))

        t.assert_deny("commit on main blocked again after removing .skip-branching",
                      HOOK, make_hook_input('git commit -m "fix: blocked again"', temp_dir))

        # ─── Section 5: Edge cases ───
        t.section("Edge cases")

        t.assert_allow("non-git directory passes through",
                       HOOK, make_hook_input('git commit -m "test"', "/tmp"))

        # Switch to feature branch for -C tests
        subprocess.run(
            ["git", "checkout", "feature/test-branch", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        t.assert_allow("commit with -C to feature branch passes through",
                       HOOK, make_hook_input(
                           f'git -C {temp_dir} commit -m "test"', "/tmp"))

        # Switch back to main for -C deny test
        subprocess.run(
            ["git", "checkout", "main", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        t.assert_deny("commit with -C to main is blocked",
                      HOOK, make_hook_input(
                          f'git -C {temp_dir} commit -m "test"', "/tmp"))

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
