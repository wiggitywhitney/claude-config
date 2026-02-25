"""Tests for pre-push-hook.sh — PR detection and verification tier escalation.

Exercises the hook with:
- Non-push commands (should passthrough silently)
- Push to branch with no open PR (standard security only)
- Push to branch with open PR (expanded security + tests)
- gh CLI unavailable (fallback to standard security)
- CodeRabbit CLI review integration (advisory, skip with .skip-coderabbit)
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

HOOK = hook_path("pre-push-hook.sh")


def create_mock_gh(temp_dir, pr_response="[]"):
    """Create a mock gh CLI that returns a fixed response for 'pr list' calls.

    Returns the path to a bin directory that should be prepended to PATH.
    """
    bin_dir = os.path.join(temp_dir, "mock-bin")
    os.makedirs(bin_dir, exist_ok=True)
    gh_script = os.path.join(bin_dir, "gh")
    write_file(temp_dir, "mock-bin/gh", f"""#!/usr/bin/env bash
# Mock gh CLI for testing PR detection
if echo "$@" | grep -q "pr list"; then
    echo '{pr_response}'
    exit 0
fi
# Unknown command — pass through
exit 0
""")
    make_executable(gh_script)
    return bin_dir


def create_mock_coderabbit(bin_dir, output="No issues found.", exit_code=0):
    """Create a mock coderabbit CLI in an existing bin directory.

    Uses a separate file for output to avoid shell-quote injection issues.
    Adds a 'coderabbit' script to bin_dir that returns fixed output for 'review' calls.
    """
    output_file = os.path.join(bin_dir, "coderabbit-output.txt")
    with open(output_file, "w") as f:
        f.write(output)
    cr_script = os.path.join(bin_dir, "coderabbit")
    with open(cr_script, "w") as f:
        f.write(f"""#!/usr/bin/env bash
# Mock coderabbit CLI for testing
if echo "$@" | grep -q "review"; then
    cat "{output_file}"
    exit {exit_code}
fi
exit 0
""")
    make_executable(cr_script)


def run_hook_with_env(hook, json_input, extra_path=None):
    """Run a hook with modified PATH for gh mocking.

    If extra_path is provided, it's prepended to PATH.
    """
    env = os.environ.copy()
    if extra_path:
        env["PATH"] = f"{extra_path}:{env['PATH']}"

    result = subprocess.run(
        [hook],
        input=json_input,
        capture_output=True,
        text=True,
        env=env,
        timeout=30,
    )
    return result.returncode, result.stdout


def setup_repo_with_branch(temp_dir, branch_name="feature/test",
                           with_remote=False):
    """Set up a git repo on main with a feature branch containing a code change.

    If with_remote=True, creates a bare repo as a remote so origin/main exists.
    This is needed for tests that exercise CodeRabbit CLI review (which needs
    origin/main as a comparison base).
    """
    setup_git_repo(temp_dir, branch="main")

    if with_remote:
        # Create a bare repo as the remote
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

    # Create a feature branch with a code file change
    subprocess.run(
        ["git", "checkout", "-b", branch_name, "--quiet"],
        cwd=temp_dir, capture_output=True, check=True,
    )
    write_file(temp_dir, "src/app.ts", "export const VERSION = '1.0.0';")
    subprocess.run(
        ["git", "add", "src/app.ts"],
        cwd=temp_dir, capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "feat: add app", "--quiet"],
        cwd=temp_dir, capture_output=True, check=True,
    )
    return temp_dir


def run_tests():
    t = TestResults("pre-push-hook.sh tests")
    t.header()

    # ─── Section 1: Non-push commands (silent passthrough) ───
    t.section("Non-push commands (should passthrough)")

    with TempDir() as temp_dir:
        setup_git_repo(temp_dir)

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git status", temp_dir))
        if exit_code == 0 and output.strip() == "":
            t._pass("git status passes through silently")
        else:
            t._fail("git status passes through silently",
                     f"exit={exit_code}, output={output}")

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("npm test", temp_dir))
        if exit_code == 0 and output.strip() == "":
            t._pass("npm test passes through silently")
        else:
            t._fail("npm test passes through silently",
                     f"exit={exit_code}, output={output}")

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git commit -m 'test'", temp_dir))
        if exit_code == 0 and output.strip() == "":
            t._pass("git commit passes through silently")
        else:
            t._fail("git commit passes through silently",
                     f"exit={exit_code}, output={output}")

    # ─── Section 2: Push with no open PR (standard security only) ───
    t.section("Push with no open PR (standard security only)")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir)
        mock_bin = create_mock_gh(temp_dir, pr_response="[]")

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git push origin feature/test", temp_dir),
            extra_path=mock_bin)

        if exit_code == 0 and '"allow"' in output:
            t._pass("push with no PR returns allow")
        else:
            t._fail("push with no PR returns allow",
                     f"exit={exit_code}, output={output}")

        # Verify it ran standard security (not expanded)
        if "standard security" in output:
            t._pass("push with no PR reports standard security")
        else:
            t._fail("push with no PR reports standard security",
                     f"output={output}")

    # ─── Section 3: Push with open PR (expanded security + tests) ───
    t.section("Push with open PR (expanded security + tests)")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir)
        mock_bin = create_mock_gh(temp_dir, pr_response='[{"number": 42}]')

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git push origin feature/test", temp_dir),
            extra_path=mock_bin)

        if exit_code == 0:
            t._pass("push with open PR completes without error")
        else:
            t._fail("push with open PR completes without error",
                     f"exit={exit_code}, output={output}")

        # Verify it escalated to PR-tier verification
        if "pr-tier" in output.lower() or "expanded security" in output.lower() or "security+tests" in output.lower():
            t._pass("push with open PR reports PR-tier verification")
        else:
            t._fail("push with open PR reports PR-tier verification",
                     f"output={output}")

    # ─── Section 4: gh CLI unavailable (fallback to standard security) ───
    t.section("gh unavailable (fallback to standard security)")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir)
        # Create a mock gh that fails (simulates gh not authenticated or unavailable)
        mock_bin = os.path.join(temp_dir, "broken-gh-bin")
        os.makedirs(mock_bin, exist_ok=True)
        broken_gh = os.path.join(mock_bin, "gh")
        write_file(temp_dir, "broken-gh-bin/gh", "#!/usr/bin/env bash\nexit 1\n")
        make_executable(broken_gh)

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git push origin feature/test", temp_dir),
            extra_path=mock_bin)

        if exit_code == 0 and '"allow"' in output:
            t._pass("push with broken gh falls back to allow")
        else:
            t._fail("push with broken gh falls back to allow",
                     f"exit={exit_code}, output={output}")

        if "standard security" in output:
            t._pass("push with broken gh reports standard security (fallback)")
        else:
            t._fail("push with broken gh reports standard security (fallback)",
                     f"output={output}")

    # ─── Section 5: Push detection patterns ───
    t.section("Push command detection patterns")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir)
        mock_bin = create_mock_gh(temp_dir, pr_response="[]")

        # Chained push command
        # Any JSON decision (allow or deny) means the hook detected the push
        # (as opposed to silent passthrough with no output)
        exit_code, output = run_hook_with_env(
            HOOK,
            make_hook_input("git add . && git push origin feature/test", temp_dir),
            extra_path=mock_bin)
        if exit_code == 0 and ('"allow"' in output or '"deny"' in output):
            t._pass("chained git push is detected")
        else:
            t._fail("chained git push is detected",
                     f"exit={exit_code}, output={output}")

        # Push with -u flag
        exit_code, output = run_hook_with_env(
            HOOK,
            make_hook_input("git push -u origin feature/test", temp_dir),
            extra_path=mock_bin)
        if exit_code == 0 and ('"allow"' in output or '"deny"' in output):
            t._pass("git push -u is detected")
        else:
            t._fail("git push -u is detected",
                     f"exit={exit_code}, output={output}")

    # ─── Section 6: CodeRabbit CLI review (advisory findings in additionalContext) ───
    t.section("CodeRabbit CLI review (advisory)")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir, with_remote=True)
        mock_bin = create_mock_gh(temp_dir, pr_response="[]")
        create_mock_coderabbit(mock_bin,
                               output="Issue: Missing error handling in src/app.ts:42")

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git push origin feature/test", temp_dir),
            extra_path=mock_bin)

        if exit_code == 0 and '"allow"' in output:
            t._pass("push with CodeRabbit findings still returns allow")
        else:
            t._fail("push with CodeRabbit findings still returns allow",
                     f"exit={exit_code}, output={output}")

        # Parse JSON and verify findings are in the additionalContext field
        try:
            data = json.loads(output)
            context = data["hookSpecificOutput"]["additionalContext"]
            has_findings = "CodeRabbit CLI review" in context
        except (json.JSONDecodeError, KeyError):
            has_findings = False
            context = ""

        if has_findings:
            t._pass("CodeRabbit findings appear in additionalContext field")
        else:
            t._fail("CodeRabbit findings appear in additionalContext field",
                     f"additionalContext={context!r}, output={output}")

    # ─── Section 7: .skip-coderabbit skips CLI review ───
    t.section("CodeRabbit CLI review skipped with .skip-coderabbit")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir)
        mock_bin = create_mock_gh(temp_dir, pr_response="[]")
        create_mock_coderabbit(mock_bin,
                               output="Issue: This should not appear")
        # Create .skip-coderabbit in the project directory
        write_file(temp_dir, ".skip-coderabbit", "")

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git push origin feature/test", temp_dir),
            extra_path=mock_bin)

        if exit_code == 0 and '"allow"' in output:
            t._pass("push with .skip-coderabbit returns allow")
        else:
            t._fail("push with .skip-coderabbit returns allow",
                     f"exit={exit_code}, output={output}")

        if "CodeRabbit CLI review" not in output:
            t._pass(".skip-coderabbit suppresses CLI review output")
        else:
            t._fail(".skip-coderabbit suppresses CLI review output",
                     f"output={output}")

    # ─── Section 8: CodeRabbit review skipped when security fails ───
    t.section("CodeRabbit CLI review skipped on security failure")

    with TempDir() as temp_dir:
        setup_repo_with_branch(temp_dir)
        mock_bin = create_mock_gh(temp_dir, pr_response="[]")
        create_mock_coderabbit(mock_bin,
                               output="Issue: This should not appear")

        # Add a console.log to trigger a security check failure
        write_file(temp_dir, "src/debug.ts", "console.log('debug');")
        subprocess.run(
            ["git", "add", "src/debug.ts"],
            cwd=temp_dir, capture_output=True, check=True,
        )
        subprocess.run(
            ["git", "commit", "-m", "add debug code", "--quiet"],
            cwd=temp_dir, capture_output=True, check=True,
        )

        exit_code, output = run_hook_with_env(
            HOOK, make_hook_input("git push origin feature/test", temp_dir),
            extra_path=mock_bin)

        if exit_code == 0 and '"deny"' in output:
            t._pass("push with security failure returns deny")
        else:
            t._fail("push with security failure returns deny",
                     f"exit={exit_code}, output={output}")

        if "CodeRabbit CLI review" not in output:
            t._pass("CodeRabbit review not run when security fails")
        else:
            t._fail("CodeRabbit review not run when security fails",
                     f"output={output}")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
