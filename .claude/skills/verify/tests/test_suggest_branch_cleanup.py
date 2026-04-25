# ABOUTME: Tests for suggest-branch-cleanup.sh PostToolUse hook.
# ABOUTME: Verifies advisory fires on gh pr merge commands, silent for all other Bash calls.

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, hook_path, run_hook

HOOK = hook_path("suggest-branch-cleanup.sh")


def make_bash_input(command: str) -> str:
    return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})


def make_other_tool_input(tool_name: str) -> str:
    return json.dumps({"tool_name": tool_name, "tool_input": {}})


def has_advisory(stdout: str) -> bool:
    if not stdout.strip():
        return False
    try:
        data = json.loads(stdout)
        ctx = data.get("hookSpecificOutput", {}).get("additionalContext", "").lower()
        return "branch" in ctx and "issue" in ctx
    except (json.JSONDecodeError, AttributeError):
        return False


def run_tests():
    t = TestResults("suggest-branch-cleanup")
    t.header()

    t.section("gh pr merge commands — advisory emitted")

    exit_code, stdout = run_hook(HOOK, make_bash_input("gh pr merge 42 --merge"))
    t.assert_equal("basic gh pr merge exits 0", exit_code, 0)
    t.assert_equal("basic gh pr merge emits advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_bash_input("gh pr merge --squash"))
    t.assert_equal("gh pr merge --squash exits 0", exit_code, 0)
    t.assert_equal("gh pr merge --squash emits advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_bash_input("cd myrepo && gh pr merge 10 --rebase"))
    t.assert_equal("chained gh pr merge exits 0", exit_code, 0)
    t.assert_equal("chained gh pr merge emits advisory", has_advisory(stdout), True)

    t.section("Other Bash commands — silent")

    for command in [
        "gh pr create --title 'foo'",
        "gh pr list",
        "gh pr view 42",
        "git merge feature/foo",
        "git push origin --delete feature/my-branch",
        "echo 'gh pr merge'",
    ]:
        exit_code, stdout = run_hook(HOOK, make_bash_input(command))
        t.assert_equal(f"'{command}' exits 0", exit_code, 0)
        t.assert_equal(f"'{command}' produces no advisory", has_advisory(stdout), False)

    t.section("Non-Bash tools — silent")

    for tool in ["Write", "Edit", "Read"]:
        exit_code, stdout = run_hook(HOOK, make_other_tool_input(tool))
        t.assert_equal(f"{tool} tool exits 0", exit_code, 0)
        t.assert_equal(f"{tool} tool produces no advisory", stdout.strip(), "")

    t.section("Edge cases")

    exit_code, stdout = run_hook(HOOK, "{invalid json}")
    t.assert_equal("invalid JSON exits 0", exit_code, 0)

    exit_code, stdout = run_hook(HOOK, make_bash_input(""))
    t.assert_equal("empty command exits 0", exit_code, 0)
    t.assert_equal("empty command produces no advisory", has_advisory(stdout), False)

    t.summary()
    return t.failed == 0


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
