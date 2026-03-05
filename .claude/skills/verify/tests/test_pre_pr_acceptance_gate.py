# ABOUTME: Tests for pre-pr-hook.sh acceptance gate behavior (PRD 28)
# ABOUTME: Exercises advisory acceptance tests, graceful skip, mandatory review wording
"""Tests for pre-pr-hook.sh acceptance gate tests.

Exercises the acceptance gate tier added by PRD 28:
- No acceptance tests configured (silent skip)
- Acceptance test via verify.json (runs, output in additionalContext)
- Acceptance test failure (advisory — still allows PR creation)
- Vals unavailable (graceful skip message)
- Standard phases fail (acceptance tests skipped entirely)
- Fallback detection (acceptance-gate.test.ts + .vals.yaml)
"""

import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, hook_path, make_hook_input, TempDir, setup_git_repo,
    write_file, make_executable,
)

HOOK = hook_path("pre-pr-hook.sh")


def run_hook_with_env(hook, json_input, extra_path=None, env_override=None):
    """Run a hook with modified environment."""
    env = os.environ.copy()
    if extra_path:
        env["PATH"] = f"{extra_path}:{env['PATH']}"
    if env_override:
        env.update(env_override)

    result = subprocess.run(
        [hook],
        input=json_input,
        capture_output=True,
        text=True,
        env=env,
        timeout=60,
    )
    return result.returncode, result.stdout


def setup_repo_with_code(temp_dir):
    """Set up a git repo with a code file on a feature branch.

    Creates origin/main so diff base works, and adds a simple code file
    that passes security checks.
    """
    setup_git_repo(temp_dir, branch="main")

    # Create a bare remote so origin/main exists
    bare_dir = os.path.join(temp_dir, ".bare-remote")
    subprocess.run(
        ["git", "clone", "--bare", "--quiet", temp_dir, bare_dir],
        capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "remote", "add", "origin", bare_dir],
        cwd=temp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "fetch", "origin", "--quiet"],
        cwd=temp_dir, capture_output=True, check=True,
    )

    # Create feature branch with a code change
    subprocess.run(
        ["git", "checkout", "-b", "feature/test", "--quiet"],
        cwd=temp_dir, capture_output=True, check=True,
    )
    write_file(temp_dir, "src/app.py", "# ABOUTME: Main application\nprint('hello')\n")
    subprocess.run(
        ["git", "add", "src/app.py"],
        cwd=temp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "feat: add app", "--quiet"],
        cwd=temp_dir, capture_output=True, check=True,
    )
    return temp_dir


def parse_context(output):
    """Extract additionalContext from hook JSON output."""
    try:
        data = json.loads(output)
        return data.get("hookSpecificOutput", {}).get("additionalContext", "")
    except (json.JSONDecodeError, TypeError):
        return ""


def run_tests():
    t = TestResults("pre-pr-hook.sh acceptance gate tests")
    t.header()

    # ─── Section 1: No acceptance tests configured ───
    t.section("No acceptance tests (silent skip)")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed without acceptance tests")
        else:
            t._fail("PR creation allowed without acceptance tests",
                     f"exit={exit_code}, output={output}")

        if "MANDATORY" not in context and "acceptance" not in context.lower():
            t._pass("no acceptance context when no tests configured")
        else:
            t._fail("no acceptance context when no tests configured",
                     f"context={context}")

    # ─── Section 2: Acceptance test via verify.json (passing) ───
    t.section("Acceptance test via verify.json (passing)")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Configure acceptance test that succeeds
        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'All acceptance tests passed'"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed with passing acceptance tests")
        else:
            t._fail("PR creation allowed with passing acceptance tests",
                     f"exit={exit_code}, output={output}")

        if "MANDATORY" in context:
            t._pass("MANDATORY review wording present in additionalContext")
        else:
            t._fail("MANDATORY review wording present in additionalContext",
                     f"context={context}")

        if "All acceptance tests passed" in context:
            t._pass("acceptance test output included in additionalContext")
        else:
            t._fail("acceptance test output included in additionalContext",
                     f"context={context}")

        if "Do NOT continue automatically" in context:
            t._pass("stop instruction present in additionalContext")
        else:
            t._fail("stop instruction present in additionalContext",
                     f"context={context}")

    # ─── Section 3: Acceptance test failure (advisory — still allows) ───
    t.section("Acceptance test failure (advisory)")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'FAIL: 2 tests failed' && exit 1"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation still allowed when acceptance tests fail")
        else:
            t._fail("PR creation still allowed when acceptance tests fail",
                     f"exit={exit_code}, output={output}")

        if "MANDATORY" in context:
            t._pass("MANDATORY wording present even on failure")
        else:
            t._fail("MANDATORY wording present even on failure",
                     f"context={context}")

        if "FAIL: 2 tests failed" in context:
            t._pass("failure output included in additionalContext")
        else:
            t._fail("failure output included in additionalContext",
                     f"context={context}")

        if '"deny"' not in output:
            t._pass("no deny decision for acceptance test failure")
        else:
            t._fail("no deny decision for acceptance test failure",
                     f"output={output}")

    # ─── Section 4: Vals unavailable (graceful skip) ───
    t.section("Vals unavailable (graceful skip)")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'vals: command not found' >&2 && exit 127"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed when vals unavailable")
        else:
            t._fail("PR creation allowed when vals unavailable",
                     f"exit={exit_code}, output={output}")

        if "skipped" in context.lower() and "vals" in context.lower():
            t._pass("skip message mentions vals unavailability")
        else:
            t._fail("skip message mentions vals unavailability",
                     f"context={context}")

        if "MANDATORY" not in context:
            t._pass("no MANDATORY wording when vals unavailable (just skip note)")
        else:
            t._fail("no MANDATORY wording when vals unavailable (just skip note)",
                     f"context={context}")

    # ─── Section 5: Standard phases fail → acceptance tests skipped ───
    t.section("Standard phases fail (acceptance tests skipped)")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        # Add a console.log to trigger security failure
        write_file(temp_dir, "src/debug.ts", "console.log('debug leak');")
        subprocess.run(
            ["git", "add", "src/debug.ts"],
            cwd=temp_dir, capture_output=True, check=True,
        )
        subprocess.run(
            ["git", "commit", "-m", "add debug", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'THIS SHOULD NOT RUN'"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        if exit_code == 0 and '"deny"' in output:
            t._pass("PR denied when security fails")
        else:
            t._fail("PR denied when security fails",
                     f"exit={exit_code}, output={output}")

        if "THIS SHOULD NOT RUN" not in output:
            t._pass("acceptance tests skipped when standard phases fail")
        else:
            t._fail("acceptance tests skipped when standard phases fail",
                     f"output={output}")

    # ─── Section 6: Fallback detection (file pattern + .vals.yaml) ───
    t.section("Fallback detection (acceptance-gate.test.ts + .vals.yaml)")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create acceptance-gate.test.ts file and .vals.yaml (no verify.json)
        os.makedirs(os.path.join(temp_dir, "test"), exist_ok=True)
        write_file(temp_dir, "test/acceptance-gate.test.ts",
                   "// acceptance gate test\n")
        write_file(temp_dir, ".vals.yaml", "# vals config\n")

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        # The fallback detection should construct a vals exec command.
        # It will fail (vals/vitest not available in test env), but the
        # important thing is it tried — we should see acceptance context.
        if "acceptance" in context.lower() or "vals" in context.lower():
            t._pass("fallback detection triggered acceptance gate")
        else:
            t._fail("fallback detection triggered acceptance gate",
                     f"context={context}")

    # ─── Section 7: verify.json security pass context preserved ───
    t.section("Base security+tests context preserved with acceptance")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'acceptance output here'"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        if "security+tests check passed" in context:
            t._pass("base verification pass message preserved")
        else:
            t._fail("base verification pass message preserved",
                     f"context={context}")

        if "acceptance output here" in context:
            t._pass("acceptance output also present")
        else:
            t._fail("acceptance output also present",
                     f"context={context}")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
