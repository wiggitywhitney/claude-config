# ABOUTME: Tests for suggest-write-prompt.sh PostToolUse hook.
# ABOUTME: Verifies advisory output fires for SKILL.md and CLAUDE.md, silent for all other files.

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, hook_path, run_hook

HOOK = hook_path("suggest-write-prompt.sh")


def make_input(file_path: str) -> str:
    return json.dumps({"tool_input": {"file_path": file_path}})


def has_advisory(stdout: str) -> bool:
    if not stdout.strip():
        return False
    try:
        data = json.loads(stdout)
        ctx = data.get("hookSpecificOutput", {}).get("additionalContext", "")
        return "write-prompt" in ctx.lower()
    except (json.JSONDecodeError, AttributeError):
        return False


def run_tests():
    t = TestResults("suggest-write-prompt")
    t.header()

    t.section("Matching files — advisory emitted")

    exit_code, stdout = run_hook(HOOK, make_input("/project/.claude/skills/anki/SKILL.md"))
    t.assert_equal("SKILL.md exits 0", exit_code, 0)
    t.assert_equal("SKILL.md emits /write-prompt advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_input("/project/.claude/skills/prd-create/SKILL.v1-yolo.md"))
    t.assert_equal("SKILL.v1-yolo.md exits 0", exit_code, 0)
    t.assert_equal("SKILL.v1-yolo.md emits /write-prompt advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_input("/project/CLAUDE.md"))
    t.assert_equal("CLAUDE.md exits 0", exit_code, 0)
    t.assert_equal("CLAUDE.md emits /write-prompt advisory", has_advisory(stdout), True)

    exit_code, stdout = run_hook(HOOK, make_input("/project/docs/CLAUDE.md"))
    t.assert_equal("nested CLAUDE.md exits 0", exit_code, 0)
    t.assert_equal("nested CLAUDE.md emits /write-prompt advisory", has_advisory(stdout), True)

    t.section("Non-matching files — silent")

    for path in ["/project/src/main.ts", "/project/scripts/setup.py",
                 "/project/README.md", "/project/main.go"]:
        exit_code, stdout = run_hook(HOOK, make_input(path))
        t.assert_equal(f"{path} exits 0", exit_code, 0)
        t.assert_equal(f"{path} produces no output", stdout.strip(), "")

    t.section("Edge cases")

    exit_code, stdout = run_hook(HOOK, make_input(""))
    t.assert_equal("empty path exits 0", exit_code, 0)
    t.assert_equal("empty path produces no output", stdout.strip(), "")

    return t.passed, t.failed, t.passed + t.failed


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
