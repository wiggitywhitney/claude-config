# ABOUTME: Tests for suggest-branch-cleanup.sh PostToolUse hook.
# ABOUTME: Verifies advisory fires only on successful gh pr merge commands, silent otherwise.

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, hook_path, make_hook_input, run_hook

HOOK = hook_path("suggest-branch-cleanup.sh")

SUCCESS_RESPONSE = "Merged pull request #42 (title)\n"
FAILURE_RESPONSE = "error: pull request is not mergeable"


def make_merge_input(command: str, response: str = SUCCESS_RESPONSE) -> str:
    data = json.loads(make_hook_input(command))
    data["tool_response"] = response
    return json.dumps(data)


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

    t.section("Successful gh pr merge — advisory emitted")

    exit_code, stdout = run_hook(HOOK, make_merge_input("gh pr merge 42 --merge"))
    t.assert_equal("basic merge exits 0", exit_code, 0)
    t.assert_equal("basic merge emits advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_merge_input("gh pr merge --squash"))
    t.assert_equal("squash merge exits 0", exit_code, 0)
    t.assert_equal("squash merge emits advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_merge_input("cd myrepo && gh pr merge 10 --rebase"))
    t.assert_equal("chained merge exits 0", exit_code, 0)
    t.assert_equal("chained merge emits advisory", has_advisory(stdout), True)

    t.section("Failed or missing tool_response — silent")

    exit_code, stdout = run_hook(HOOK, make_merge_input("gh pr merge 42", FAILURE_RESPONSE))
    t.assert_equal("failed merge exits 0", exit_code, 0)
    t.assert_equal("failed merge produces no advisory", has_advisory(stdout), False)

    exit_code, stdout = run_hook(HOOK, make_merge_input("gh pr merge 42", "error: pull request was not merged"))
    t.assert_equal("'was not merged' response exits 0", exit_code, 0)
    t.assert_equal("'was not merged' response produces no advisory", has_advisory(stdout), False)

    exit_code, stdout = run_hook(HOOK, make_hook_input("gh pr merge 42"))
    t.assert_equal("no tool_response exits 0", exit_code, 0)
    t.assert_equal("no tool_response produces no advisory", has_advisory(stdout), False)

    t.section("Other Bash commands — silent")

    for command in [
        "gh pr create --title 'foo'",
        "gh pr list",
        "gh pr view 42",
        "git merge feature/foo",
        "git push origin --delete feature/my-branch",
        "echo gh pr merge",
        "echo 'gh pr merge'",
    ]:
        exit_code, stdout = run_hook(HOOK, make_hook_input(command))
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

    exit_code, stdout = run_hook(HOOK, make_hook_input(""))
    t.assert_equal("empty command exits 0", exit_code, 0)
    t.assert_equal("empty command produces no advisory", has_advisory(stdout), False)

    return t.passed, t.failed, t.passed + t.failed


if __name__ == "__main__":
    passed, failed, _ = run_tests()
    sys.exit(0 if failed == 0 else 1)
