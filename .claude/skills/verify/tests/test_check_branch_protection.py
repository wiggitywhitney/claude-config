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

    # ─── Section 6: Docs-only exemption on main ───
    # Use a fresh repo for docs-only tests to avoid interference with staged files
    with TempDir() as docs_dir:
        setup_git_repo(docs_dir, branch="main")

        t.section("Docs-only exemption on main (should allow)")

        # New .md file — should be allowed
        write_file(docs_dir, "README.md", "# Hello")
        subprocess.run(
            ["git", "add", "README.md"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_allow("new .md file on main is allowed",
                       HOOK, make_hook_input('git commit -m "docs: add readme"', docs_dir))
        # Actually commit to clear staging area
        subprocess.run(
            ["git", "commit", "-m", "docs: add readme", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # Modified .md file — should be allowed
        write_file(docs_dir, "README.md", "# Hello World\nUpdated content.")
        subprocess.run(
            ["git", "add", "README.md"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_allow("modified .md file on main is allowed",
                       HOOK, make_hook_input('git commit -m "docs: update readme"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "docs: update readme", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # .md file in subdirectory (e.g. journal/) — should be allowed
        write_file(docs_dir, "journal/2026-02-24.md", "Journal entry")
        subprocess.run(
            ["git", "add", "journal/2026-02-24.md"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_allow("nested .md file on main is allowed",
                       HOOK, make_hook_input('git commit -m "docs: journal entry"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "docs: journal entry", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # Multiple .md files — should be allowed
        write_file(docs_dir, "CHANGELOG.md", "# Changelog")
        write_file(docs_dir, "docs/guide.md", "# Guide")
        subprocess.run(
            ["git", "add", "CHANGELOG.md", "docs/guide.md"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_allow("multiple .md files on main is allowed",
                       HOOK, make_hook_input('git commit -m "docs: add docs"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "docs: add docs", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        t.section("Docs-only exemption on main (should deny)")

        # Mixed commit: .md + .py — should be denied
        write_file(docs_dir, "notes.md", "Notes")
        write_file(docs_dir, "script.py", "print('hi')")
        subprocess.run(
            ["git", "add", "notes.md", "script.py"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_deny("mixed .md + code on main is blocked",
                       HOOK, make_hook_input('git commit -m "mixed commit"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "mixed commit", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # Non-.md file alone — should be denied
        write_file(docs_dir, "config.yaml", "key: value")
        subprocess.run(
            ["git", "add", "config.yaml"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_deny("non-.md file on main is blocked",
                       HOOK, make_hook_input('git commit -m "add config"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "add config", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # .txt file — should be denied (only .md is exempted)
        write_file(docs_dir, "notes.txt", "some notes")
        subprocess.run(
            ["git", "add", "notes.txt"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_deny(".txt file on main is blocked",
                       HOOK, make_hook_input('git commit -m "add txt"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "add txt", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # Deleted .md file — should be denied
        subprocess.run(
            ["git", "rm", "README.md", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_deny("deleted .md file on main is blocked",
                       HOOK, make_hook_input('git commit -m "remove readme"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "remove readme", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # Renamed .md file — should be denied
        write_file(docs_dir, "old-name.md", "Content for rename test")
        subprocess.run(
            ["git", "add", "old-name.md"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        subprocess.run(
            ["git", "commit", "-m", "add file for rename", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        subprocess.run(
            ["git", "mv", "old-name.md", "new-name.md"],
            cwd=docs_dir, capture_output=True, check=True,
        )
        t.assert_deny("renamed .md file on main is blocked",
                       HOOK, make_hook_input('git commit -m "rename doc"', docs_dir))
        subprocess.run(
            ["git", "commit", "-m", "rename doc", "--quiet"],
            cwd=docs_dir, capture_output=True, check=True,
        )

        # Nothing staged — should deny (no exemption, no files to check)
        t.section("Docs-only exemption edge cases")

        t.assert_deny("commit with nothing staged on main is blocked",
                       HOOK, make_hook_input('git commit -m "empty"', docs_dir))

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
