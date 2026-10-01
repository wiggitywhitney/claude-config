# ABOUTME: Tests for check-coderabbit-required.sh using a stand-in gh instead of GitHub
# ABOUTME: Results are the same from a plain directory, a git checkout, or a linked worktree
"""Tests for check-coderabbit-required.sh hook.

Exercises the hook with:
- Non-merge commands (should passthrough silently)
- PR merge with .skip-coderabbit (should passthrough)
- PR merge without .skip-coderabbit (should deny)
- Cross-repo merges (--repo flag and cd path resolution)
- Review lookup outcomes (review found, lookup failed, no pull request)
- Edge cases

The hook decides from what `gh` returns for the repository, the current branch's
pull request, and the review channels. Every test runs with a stand-in `gh` ahead of
the real one on PATH, so no result depends on the directory the suite runs from, on
which pull requests exist in the enclosing repository, or on network access.
"""

import contextlib
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, hook_path, make_hook_input, TempDir, write_file, make_executable,
)

HOOK = hook_path("check-coderabbit-required.sh")

# Answers only the calls the hook makes. Behavior is set through environment variables:
#   STUB_REVIEWED_PRS  space-separated pull request numbers that have a CodeRabbit review
#   STUB_CURRENT_PR    the number `gh pr view` reports; unset means no pull request
#   STUB_API_FAIL      when set, `gh api` calls fail
STUB_GH = """#!/usr/bin/env bash
case "$1" in
  repo) echo "stub-owner/stub-repo" ;;
  pr)
    if [ -n "${STUB_CURRENT_PR:-}" ]; then echo "$STUB_CURRENT_PR"; else exit 1; fi
    ;;
  api)
    [ -n "${STUB_API_FAIL:-}" ] && exit 1
    for arg in "$@"; do
      if [[ "$arg" =~ /pulls/([0-9]+)/reviews$ ]]; then
        for pr in ${STUB_REVIEWED_PRS:-}; do
          [ "$pr" = "${BASH_REMATCH[1]}" ] && echo 1
        done
      fi
    done
    ;;
  *)
    echo "stand-in gh: unexpected call: $*" >&2
    exit 97
    ;;
esac
"""

STUB_GH_PATH = None


@contextlib.contextmanager
def _env(**overrides):
    """Set environment variables for the block, then restore the previous values."""
    saved = {name: os.environ.get(name) for name in overrides}
    os.environ.update(overrides)
    try:
        yield
    finally:
        for name, value in saved.items():
            if value is None:
                os.environ.pop(name, None)
            else:
                os.environ[name] = value


def run_tests():
    """Run every test with a stand-in gh ahead of the real one on PATH."""
    global STUB_GH_PATH
    with TempDir() as stub_dir:
        STUB_GH_PATH = os.path.join(stub_dir, "gh")
        write_file(stub_dir, "gh", STUB_GH)
        make_executable(STUB_GH_PATH)
        with _env(PATH=stub_dir + os.pathsep + os.environ.get("PATH", ""),
                  STUB_REVIEWED_PRS="777"):
            return _run_tests()


def _run_tests():
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

        # ─── Section 4: Cross-repo merges (cd path resolves .skip-coderabbit) ───
        t.section("Cross-repo merges (cd path)")

        # Create a "remote repo" dir with .skip-coderabbit
        remote_repo = os.path.join(temp_dir, "remote-repo")
        os.makedirs(remote_repo)
        write_file(remote_repo, ".skip-coderabbit")

        # cd to the remote repo in the command — should find .skip-coderabbit there
        t.assert_allow(
            "cd /path && gh pr merge finds .skip-coderabbit at cd path",
            HOOK,
            make_hook_input(
                f"cd {remote_repo} && gh pr merge 1 --merge",
                temp_dir  # cwd is temp_dir (no .skip-coderabbit)
            ))

        # Without cd, same command from temp_dir should deny
        t.assert_deny(
            "gh pr merge without cd denies when cwd lacks .skip-coderabbit",
            HOOK,
            make_hook_input(
                "gh pr merge 1 --repo owner/repo --merge",
                temp_dir
            ))

        # Semicolon-chained cd also works
        t.assert_allow(
            "cd /path ; gh pr merge finds .skip-coderabbit via semicolon chain",
            HOOK,
            make_hook_input(
                f"cd {remote_repo} ; gh pr merge 1 --merge",
                temp_dir
            ))

        os.remove(os.path.join(remote_repo, ".skip-coderabbit"))

        # ─── Section 5: Edge cases ───
        t.section("Edge cases")

        t.assert_allow("empty command passes through",
                       HOOK, make_hook_input("", temp_dir))

        t.assert_allow("malformed JSON handled gracefully",
                       HOOK, '{"broken": true}')

        # ─── Section 6: Review lookup outcomes (stand-in gh) ───
        t.section("Review lookup outcomes (stand-in gh)")

        t.assert_equal("gh resolves to the stand-in, not a real GitHub client",
                       shutil.which("gh"), STUB_GH_PATH)

        t.assert_allow("gh pr merge passes when the pull request has a CodeRabbit review",
                       HOOK, make_hook_input("gh pr merge 777", temp_dir))

        with _env(STUB_API_FAIL="1"):
            t.assert_deny_contains(
                "gh pr merge is denied when the review lookup fails",
                HOOK, make_hook_input("gh pr merge 777", temp_dir),
                "could not be verified")

        with _env(STUB_CURRENT_PR="777"):
            t.assert_allow(
                "gh pr merge with no number uses the current branch's pull request",
                HOOK, make_hook_input("gh pr merge --merge", temp_dir))

        t.assert_deny_contains(
            "gh pr merge with no number is denied when the branch has no pull request",
            HOOK, make_hook_input("gh pr merge --merge", temp_dir),
            "Could not determine PR number")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
