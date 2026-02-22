"""Tests for check-coderabbit-required.sh hook.

Exercises the hook with:
- Non-merge commands (should passthrough silently)
- PR merge with .skip-coderabbit (should passthrough)
- PR merge without .skip-coderabbit (should deny)
- Edge cases

Note: Tests that verify actual CodeRabbit review status via GitHub API
are skipped in this unit test suite (they require network access and a real PR).
Those are covered by manual integration testing.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, hook_path, make_hook_input, TempDir, write_file

HOOK = hook_path("check-coderabbit-required.sh")


def run_tests():
    t = TestResults("check-coderabbit-required.sh tests")
    t.header()

    with TempDir() as temp_dir:

        # ─── Section 1: Non-merge commands (silent passthrough) ───
        t.section("Non-merge commands (should passthrough)")

        t.assert_allow("git status passes through",
                       HOOK, make_hook_input("git status", temp_dir))

        t.assert_allow("git push passes through",
                       HOOK, make_hook_input("git push origin main", temp_dir))

        t.assert_allow("gh pr create passes through",
                       HOOK, make_hook_input('gh pr create --title "test"', temp_dir))

        t.assert_allow("gh pr view passes through",
                       HOOK, make_hook_input("gh pr view 123", temp_dir))

        t.assert_allow("npm test passes through",
                       HOOK, make_hook_input("npm test", temp_dir))

        # ─── Section 2: PR merge with .skip-coderabbit (should passthrough) ───
        t.section("PR merge with .skip-coderabbit (should passthrough)")

        write_file(temp_dir, ".skip-coderabbit")

        t.assert_allow("gh pr merge with .skip-coderabbit passes through",
                       HOOK, make_hook_input("gh pr merge 123", temp_dir))

        t.assert_allow("gh pr merge --squash with .skip-coderabbit passes through",
                       HOOK, make_hook_input("gh pr merge 123 --squash", temp_dir))

        t.assert_allow("chained gh pr merge with .skip-coderabbit passes through",
                       HOOK, make_hook_input('echo "merging" && gh pr merge 123', temp_dir))

        os.remove(os.path.join(temp_dir, ".skip-coderabbit"))

        # ─── Section 3: PR merge without .skip-coderabbit (should deny) ───
        t.section("PR merge without .skip-coderabbit (should deny)")

        t.assert_deny("gh pr merge without .skip-coderabbit is blocked",
                      HOOK, make_hook_input("gh pr merge 123", temp_dir))

        t.assert_deny("gh pr merge with flags without .skip-coderabbit is blocked",
                      HOOK, make_hook_input("gh pr merge 123 --merge --delete-branch", temp_dir))

        t.assert_deny("chained gh pr merge without .skip-coderabbit is blocked",
                      HOOK, make_hook_input('echo "merging" && gh pr merge 456', temp_dir))

        # ─── Section 4: Edge cases ───
        t.section("Edge cases")

        t.assert_allow("empty command passes through",
                       HOOK, make_hook_input("", temp_dir))

        t.assert_allow("malformed JSON handled gracefully",
                       HOOK, '{"broken": true}')

    exit_code = t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
