# ABOUTME: Tests for pre-pr-hook.sh async CI acceptance gate path (PRD 35, M2)
# ABOUTME: Exercises acceptance_test_ci workflow trigger, fallback to sync, and gh unavailability
"""Tests for pre-pr-hook.sh async CI acceptance gate.

Exercises the async CI path added by PRD 35 M2:
- acceptance_test_ci in verify.json triggers gh workflow run
- Hook returns immediately with advisory context linking to CI run
- Falls back to sync when gh CLI is unavailable
- Falls back to sync when workflow trigger fails
- Sync acceptance_test still works unchanged (backward compat)
- detect-project.sh extracts acceptance_test_ci key
"""

import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, hook_path, script_path, run_script, make_hook_input, TempDir,
    setup_git_repo, write_file, make_executable,
)

HOOK = hook_path("pre-pr-hook.sh")
DETECT = script_path("detect-project.sh")


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
    """Set up a git repo with a code file on a feature branch."""
    setup_git_repo(temp_dir, branch="main")

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
    t = TestResults("pre-pr-hook.sh async CI acceptance gate tests (PRD 35, M2)")
    t.header()

    # ─── Section 1: detect-project.sh extracts acceptance_test_ci ───
    t.section("detect-project.sh extracts acceptance_test_ci from verify.json")

    with TempDir() as temp_dir:
        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "vals exec -f .vals.yaml -- npx vitest run test/**/acceptance-gate.test.ts",
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        _, stdout = run_script(DETECT, temp_dir)
        detection = stdout.strip()

        try:
            data = json.loads(detection)
            ci_value = data.get("commands", {}).get("acceptance_test_ci")
            if ci_value == "acceptance-gate.yml":
                t._pass("acceptance_test_ci extracted from verify.json")
            else:
                t._fail("acceptance_test_ci extracted from verify.json",
                         f"expected 'acceptance-gate.yml', got {ci_value!r}")
        except (json.JSONDecodeError, TypeError) as e:
            t._fail("acceptance_test_ci extracted from verify.json",
                     f"JSON parse error: {e}\noutput: {detection}")

    # ─── Section 2: detect-project.sh omits acceptance_test_ci when absent ───
    t.section("detect-project.sh omits acceptance_test_ci when not configured")

    with TempDir() as temp_dir:
        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'tests pass'"
            }
        }))

        _, stdout = run_script(DETECT, temp_dir)
        detection = stdout.strip()

        try:
            data = json.loads(detection)
            ci_value = data.get("commands", {}).get("acceptance_test_ci")
            if ci_value is None:
                t._pass("acceptance_test_ci is null when not configured")
            else:
                t._fail("acceptance_test_ci is null when not configured",
                         f"expected None, got {ci_value!r}")
        except (json.JSONDecodeError, TypeError) as e:
            t._fail("acceptance_test_ci is null when not configured",
                     f"JSON parse error: {e}")

    # ─── Section 3: Async CI path triggers gh workflow run ───
    t.section("Async CI path triggers gh workflow run")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create fake gh that logs its args
        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        gh_log = os.path.join(temp_dir, "gh-call.log")
        write_file(temp_dir, "fake-bin/gh",
                   f'#!/bin/bash\necho "gh-called: $@" > "{gh_log}"\necho "gh-args: $@"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'sync test output'",
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed with async CI path")
        else:
            t._fail("PR creation allowed with async CI path",
                     f"exit={exit_code}, output={output}")

        # Should mention CI/workflow/Actions in the context
        if "workflow" in context.lower() or "ci" in context.lower() or "actions" in context.lower():
            t._pass("advisory context mentions CI workflow")
        else:
            t._fail("advisory context mentions CI workflow",
                     f"context={context}")

        # Should NOT contain sync test output (async path skips sync execution)
        if "sync test output" not in context:
            t._pass("sync acceptance test not executed when CI path active")
        else:
            t._fail("sync acceptance test not executed when CI path active",
                     f"context={context}")

        # Should NOT have MANDATORY wording (CI results come later)
        if "Do NOT continue automatically" not in context:
            t._pass("no blocking MANDATORY wording for async CI path")
        else:
            t._fail("no blocking MANDATORY wording for async CI path",
                     f"context={context}")

    # ─── Section 4: Async CI falls back to sync when gh unavailable ───
    t.section("Falls back to sync when gh CLI unavailable")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create a fake gh that doesn't exist — use a PATH prefix with no gh
        # but keep the rest of PATH so python3, git, etc. still work
        no_gh_dir = os.path.join(temp_dir, "no-gh-bin")
        os.makedirs(no_gh_dir)
        # Shadow gh with a script that exits 127 (command not found behavior)
        write_file(temp_dir, "no-gh-bin/gh",
                   '#!/bin/bash\nexit 127\n')
        # Don't make it executable — command -v gh will fail

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'sync fallback output'",
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        # Remove gh from PATH by filtering it out
        path_without_gh = ":".join(
            p for p in os.environ.get("PATH", "").split(":")
            if not os.path.isfile(os.path.join(p, "gh"))
        )
        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            env_override={"PATH": path_without_gh})

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed on sync fallback")
        else:
            t._fail("PR creation allowed on sync fallback",
                     f"exit={exit_code}, output={output}")

        # Should fall back to sync and show sync output
        if "sync fallback output" in context:
            t._pass("sync acceptance test ran as fallback")
        else:
            t._fail("sync acceptance test ran as fallback",
                     f"context={context}")

    # ─── Section 5: Async CI falls back to sync when workflow trigger fails ───
    t.section("Falls back to sync when workflow trigger fails")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create fake gh that fails on workflow run
        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        write_file(temp_dir, "fake-bin/gh",
                   '#!/bin/bash\nif [[ "$1" == "workflow" ]]; then echo "could not create workflow dispatch event" >&2; exit 1; fi\necho "gh: $@"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'sync after gh failure'",
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        context = parse_context(output)

        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed after workflow trigger failure")
        else:
            t._fail("PR creation allowed after workflow trigger failure",
                     f"exit={exit_code}, output={output}")

        if "sync after gh failure" in context:
            t._pass("sync acceptance test ran after workflow trigger failure")
        else:
            t._fail("sync acceptance test ran after workflow trigger failure",
                     f"context={context}")

    # ─── Section 6: Backward compat — sync-only repos unchanged ───
    t.section("Backward compat: sync-only repos work unchanged")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "echo 'sync only output'"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir))

        context = parse_context(output)

        if "sync only output" in context:
            t._pass("sync-only repo still runs acceptance tests synchronously")
        else:
            t._fail("sync-only repo still runs acceptance tests synchronously",
                     f"context={context}")

        if "MANDATORY" in context:
            t._pass("MANDATORY wording preserved for sync path")
        else:
            t._fail("MANDATORY wording preserved for sync path",
                     f"context={context}")

    # ─── Section 7: Async CI path includes branch name in workflow trigger ───
    t.section("Async CI includes branch ref in workflow trigger")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create fake gh that captures full args
        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        gh_log = os.path.join(temp_dir, "gh-args.log")
        write_file(temp_dir, "fake-bin/gh",
                   f'#!/bin/bash\necho "$@" >> "{gh_log}"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        # Read what gh was called with
        if os.path.exists(gh_log):
            with open(gh_log) as f:
                gh_args = f.read()

            if "--ref" in gh_args and "feature/test" in gh_args:
                t._pass("gh workflow run includes --ref with branch name")
            else:
                t._fail("gh workflow run includes --ref with branch name",
                         f"gh args: {gh_args}")

            if "acceptance-gate.yml" in gh_args:
                t._pass("gh workflow run uses correct workflow filename")
            else:
                t._fail("gh workflow run uses correct workflow filename",
                         f"gh args: {gh_args}")
        else:
            t._fail("gh workflow run includes --ref with branch name",
                     "gh was never called (no log file)")
            t._fail("gh workflow run uses correct workflow filename",
                     "gh was never called (no log file)")

    # ─── Section 8: Standard phases fail → async CI trigger skipped ───
    t.section("Standard phases fail: async CI trigger skipped")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create fake gh that logs calls
        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        gh_log = os.path.join(temp_dir, "gh-calls.log")
        write_file(temp_dir, "fake-bin/gh",
                   f'#!/bin/bash\necho "$@" >> "{gh_log}"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "test": "echo 'test failure' && exit 1",
                "acceptance_test": "echo 'should not run sync'",
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        # PR should be denied due to test failure
        if exit_code == 0 and '"deny"' in output:
            t._pass("PR denied when test phase fails")
        else:
            t._fail("PR denied when test phase fails",
                     f"exit={exit_code}, output={output}")

        # gh workflow run should NOT have been called
        if os.path.exists(gh_log):
            with open(gh_log) as f:
                gh_calls = f.read()
            if "workflow" in gh_calls:
                t._fail("gh workflow run not called when phases fail",
                         f"gh was called: {gh_calls}")
            else:
                t._pass("gh workflow run not called when phases fail")
        else:
            t._pass("gh workflow run not called when phases fail")

    # ─── Section 9: Workflow trigger fails → verbose injection on sync fallback ───
    t.section("Workflow trigger fails: sync fallback gets verbose reporter")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create fake gh that fails on workflow run
        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        write_file(temp_dir, "fake-bin/gh",
                   '#!/bin/bash\nif [[ "$1" == "workflow" ]]; then exit 1; fi\necho "gh: $@"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        # Create fake npx that prints its args
        write_file(temp_dir, "fake-bin/npx",
                   "#!/bin/bash\necho \"npx-args: $@\"\n")
        make_executable(os.path.join(temp_dir, "fake-bin", "npx"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test": "npx vitest run test/acceptance-gate.test.ts",
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        context = parse_context(output)

        # Sync fallback should have verbose reporter injected
        if "--reporter=verbose" in context:
            t._pass("sync fallback vitest command gets --reporter=verbose")
        else:
            t._fail("sync fallback vitest command gets --reporter=verbose",
                     f"context={context}")

    # ─── Section 10: CI-only config, trigger fails → graceful no-op ───
    t.section("CI-only (no sync command), trigger fails: graceful handling")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        # Create fake gh that fails on workflow run
        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        write_file(temp_dir, "fake-bin/gh",
                   '#!/bin/bash\nif [[ "$1" == "workflow" ]]; then exit 1; fi\necho "gh: $@"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        # Only acceptance_test_ci, no acceptance_test
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test_ci": "acceptance-gate.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        context = parse_context(output)

        # Should still allow PR (acceptance is advisory)
        if exit_code == 0 and '"allow"' in output:
            t._pass("PR creation allowed when CI trigger fails and no sync fallback")
        else:
            t._fail("PR creation allowed when CI trigger fails and no sync fallback",
                     f"exit={exit_code}, output={output}")

        # Should NOT have MANDATORY wording (nothing ran)
        if "MANDATORY" not in context:
            t._pass("no MANDATORY wording when no acceptance tests ran")
        else:
            t._fail("no MANDATORY wording when no acceptance tests ran",
                     f"context={context}")

    # ─── Section 11: Async CI context includes workflow name and branch ───
    t.section("Async CI context includes specific workflow name and branch")

    with TempDir() as temp_dir:
        setup_repo_with_code(temp_dir)

        bin_dir = os.path.join(temp_dir, "fake-bin")
        os.makedirs(bin_dir)
        write_file(temp_dir, "fake-bin/gh",
                   '#!/bin/bash\necho "ok"\n')
        make_executable(os.path.join(temp_dir, "fake-bin", "gh"))

        os.makedirs(os.path.join(temp_dir, ".claude"), exist_ok=True)
        write_file(temp_dir, ".claude/verify.json", json.dumps({
            "commands": {
                "acceptance_test_ci": "my-custom-workflow.yml"
            }
        }))

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("gh pr create --title test", temp_dir),
            extra_path=bin_dir)

        context = parse_context(output)

        if "my-custom-workflow.yml" in context:
            t._pass("context includes specific workflow filename")
        else:
            t._fail("context includes specific workflow filename",
                     f"context={context}")

        if "feature/test" in context:
            t._pass("context includes branch name")
        else:
            t._fail("context includes branch name",
                     f"context={context}")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
