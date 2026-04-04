# ABOUTME: Tests for verify-phase.sh exit code correctness and structured error transcript output
# ABOUTME: Covers large output scenarios and VERIFY_ERROR_CONTEXT JSON emission on failure
"""Tests for verify-phase.sh — exit code correctness and structured error transcript output.

Exercises the phase runner with:
- Normal output (pass and fail)
- Large output (>4000 chars, matching truncation limit)
- Very large output (>20000 chars, matching real repos like spinybacked-orbweaver)
- Commands that produce mixed stdout/stderr
- Exit code accuracy through hook-style $() capture
"""

import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, script_path, run_script_combined, TempDir, write_file,
    make_executable,
)

VERIFY_PHASE = script_path("verify-phase.sh")


def create_test_command(temp_dir, name, stdout_lines, exit_code,
                        stderr_lines=None):
    """Create a test command script that produces specified output and exit code.

    Returns the path to the script.
    """
    stderr_part = ""
    if stderr_lines:
        stderr_part = "\n".join(
            f'echo "{line}" >&2' for line in stderr_lines
        )
        stderr_part = f"\n{stderr_part}"

    stdout_part = "\n".join(f'echo "{line}"' for line in stdout_lines)

    content = f"""#!/usr/bin/env bash
{stdout_part}{stderr_part}
exit {exit_code}
"""
    script = write_file(temp_dir, name, content)
    make_executable(script)
    return script


def generate_large_output_lines(count, line_template=None):
    """Generate a list of output lines simulating vitest test results."""
    if line_template is None:
        line_template = (
            "  ✓ src/module{i}/deeply/nested/test.spec.ts"
            " > should handle case {i} correctly ({i}ms)"
        )
    lines = [line_template.format(i=i) for i in range(1, count + 1)]
    lines.extend([
        "",
        f" Test Files  {count} passed ({count})",
        f"      Tests  {count * 10} passed ({count * 10})",
        "   Duration  57.23s",
    ])
    return lines


def simulate_hook_capture(verify_phase_path, phase, command, project_dir):
    """Simulate how hooks capture verify-phase.sh output via $().

    This is the exact pattern from pre-pr-hook.sh run_phase and
    pre-push-hook.sh test phase:

        output=$(verify-phase.sh ... 2>&1)
        exit_code=$?

    Returns (exit_code, output_length, last_output_line).
    """
    # Use bash -c to replicate the exact hook capture mechanism
    bash_script = (
        f'output=$("{verify_phase_path}" "{phase}" "{command}"'
        f' "{project_dir}" 2>&1)\n'
        f'exit_code=$?\n'
        f'echo "CAPTURE_EXIT:$exit_code"\n'
        f'echo "OUTPUT_LEN:${{#output}}"\n'
        f'echo "$output" | tail -1\n'
    )
    result = subprocess.run(
        ["bash", "-c", bash_script],
        capture_output=True,
        text=True,
        timeout=30,
    )
    lines = result.stdout.strip().split("\n")
    exit_code = -1
    output_len = -1
    last_line = ""
    for line in lines:
        if line.startswith("CAPTURE_EXIT:"):
            exit_code = int(line.split(":", 1)[1])
        elif line.startswith("OUTPUT_LEN:"):
            output_len = int(line.split(":", 1)[1])
        else:
            last_line = line
    return exit_code, output_len, last_line


def run_tests():
    t = TestResults("verify-phase.sh tests")
    t.header()

    # ─── Section 1: Basic pass/fail ───
    t.section("Basic pass and fail")

    with TempDir() as temp_dir:
        pass_cmd = create_test_command(
            temp_dir, "pass.sh", ["test output line 1", "all good"], 0
        )
        exit_code, output = run_script_combined(
            VERIFY_PHASE, "test", pass_cmd, temp_dir
        )
        t.assert_equal("passing command returns exit 0", exit_code, 0)
        t.assert_contains("passing output contains PASSED",
                          output, "RESULT: test PASSED")

        fail_cmd = create_test_command(
            temp_dir, "fail.sh", ["test output", "FAIL: something broke"], 1
        )
        exit_code, output = run_script_combined(
            VERIFY_PHASE, "test", fail_cmd, temp_dir
        )
        t.assert_equal("failing command returns exit 1", exit_code, 1)
        t.assert_contains("failing output contains FAILED",
                          output, "RESULT: test FAILED")

    # ─── Section 2: Large output (>4000 chars) ───
    t.section("Large output (>4000 chars, exit 0)")

    with TempDir() as temp_dir:
        lines = generate_large_output_lines(80)  # ~6000 chars
        large_pass = create_test_command(
            temp_dir, "large_pass.sh", lines, 0
        )

        # Direct execution
        exit_code, output = run_script_combined(
            VERIFY_PHASE, "test", large_pass, temp_dir
        )
        t.assert_equal("large output (6K): direct exit code is 0",
                        exit_code, 0)
        t.assert_contains("large output (6K): contains PASSED",
                          output, "RESULT: test PASSED")

        # Through $() capture (simulating hook behavior)
        cap_exit, cap_len, _cap_last = simulate_hook_capture(
            VERIFY_PHASE, "test", large_pass, temp_dir
        )
        t.assert_equal("large output (6K): captured exit code is 0",
                        cap_exit, 0)
        if cap_len > 4000:
            t._pass(f"large output (6K): output length {cap_len} > 4000")
        else:
            t._fail(f"large output (6K): output length {cap_len} > 4000",
                     f"Expected >4000, got {cap_len}")

    # ─── Section 3: Very large output (>20000 chars) ───
    t.section("Very large output (>20000 chars, exit 0)")

    with TempDir() as temp_dir:
        lines = generate_large_output_lines(300)  # ~25000 chars
        vlarge_pass = create_test_command(
            temp_dir, "vlarge_pass.sh", lines, 0
        )

        # Direct execution
        exit_code, output = run_script_combined(
            VERIFY_PHASE, "test", vlarge_pass, temp_dir
        )
        t.assert_equal("very large output (25K): direct exit code is 0",
                        exit_code, 0)
        t.assert_contains("very large output (25K): contains PASSED",
                          output, "RESULT: test PASSED")

        # Through $() capture (simulating hook behavior)
        cap_exit, cap_len, _cap_last = simulate_hook_capture(
            VERIFY_PHASE, "test", vlarge_pass, temp_dir
        )
        t.assert_equal("very large output (25K): captured exit code is 0",
                        cap_exit, 0)
        if cap_len > 20000:
            t._pass(
                f"very large output (25K): output length {cap_len} > 20000"
            )
        else:
            t._fail(
                f"very large output (25K): output length {cap_len} > 20000",
                f"Expected >20000, got {cap_len}",
            )

    # ─── Section 4: Large output with failure ───
    t.section("Large output with failure (exit 1)")

    with TempDir() as temp_dir:
        lines = generate_large_output_lines(200)  # ~16000 chars
        lines.append("FAIL: 3 tests failed")
        large_fail = create_test_command(
            temp_dir, "large_fail.sh", lines, 1
        )

        exit_code, output = run_script_combined(
            VERIFY_PHASE, "test", large_fail, temp_dir
        )
        t.assert_equal("large failing output: exit code is 1",
                        exit_code, 1)
        t.assert_contains("large failing output: contains FAILED",
                          output, "RESULT: test FAILED")

        cap_exit, _, _ = simulate_hook_capture(
            VERIFY_PHASE, "test", large_fail, temp_dir
        )
        t.assert_equal("large failing output: captured exit code is 1",
                        cap_exit, 1)

    # ─── Section 5: Mixed stdout/stderr with large output ───
    t.section("Mixed stdout/stderr with large output (exit 0)")

    with TempDir() as temp_dir:
        stdout_lines = generate_large_output_lines(150)  # ~12000 chars
        stderr_lines = [
            f"[warn] deprecation notice {i}" for i in range(50)
        ]
        mixed_pass = create_test_command(
            temp_dir, "mixed_pass.sh", stdout_lines, 0,
            stderr_lines=stderr_lines,
        )

        exit_code, output = run_script_combined(
            VERIFY_PHASE, "test", mixed_pass, temp_dir
        )
        t.assert_equal("mixed stdout/stderr: exit code is 0",
                        exit_code, 0)
        t.assert_contains("mixed stdout/stderr: contains PASSED",
                          output, "RESULT: test PASSED")

        cap_exit, cap_len, _ = simulate_hook_capture(
            VERIFY_PHASE, "test", mixed_pass, temp_dir
        )
        t.assert_equal("mixed stdout/stderr: captured exit code is 0",
                        cap_exit, 0)

    # ─── Section 6: Exit code preserved through temp file capture ───
    t.section("Exit code via temp file capture (proposed fix pattern)")

    with TempDir() as temp_dir:
        lines = generate_large_output_lines(300)
        vlarge_pass = create_test_command(
            temp_dir, "vlarge_tmpfile.sh", lines, 0
        )

        # Simulate the proposed temp file fix pattern
        bash_script = (
            f'tmpfile=$(mktemp)\n'
            f'"{VERIFY_PHASE}" "test" "{vlarge_pass}" "{temp_dir}"'
            f' > "$tmpfile" 2>&1\n'
            f'exit_code=$?\n'
            f'echo "TMPFILE_EXIT:$exit_code"\n'
            f'echo "TMPFILE_SIZE:$(wc -c < "$tmpfile" | tr -d " ")"\n'
            f'rm -f "$tmpfile"\n'
        )
        result = subprocess.run(
            ["bash", "-c", bash_script],
            capture_output=True,
            text=True,
            timeout=30,
        )
        tmp_exit = -1
        tmp_size = -1
        for line in result.stdout.strip().split("\n"):
            if line.startswith("TMPFILE_EXIT:"):
                tmp_exit = int(line.split(":", 1)[1])
            elif line.startswith("TMPFILE_SIZE:"):
                tmp_size = int(line.split(":", 1)[1])

        t.assert_equal("temp file capture: exit code is 0", tmp_exit, 0)
        if tmp_size > 20000:
            t._pass(f"temp file capture: output size {tmp_size} > 20000")
        else:
            t._fail(f"temp file capture: output size {tmp_size} > 20000",
                     f"Expected >20000, got {tmp_size}")

    # ─── Section 7: VERIFY_EXIT override (corrupted exit code) ───
    t.section("VERIFY_EXIT override for corrupted exit codes")

    with TempDir() as temp_dir:
        lines = generate_large_output_lines(200)
        pass_cmd = create_test_command(
            temp_dir, "pass_for_override.sh", lines, 0
        )

        # Simulate: verify-phase.sh exits 0, but something corrupts $? to 1.
        # The hook should detect VERIFY_EXIT: 0 in the temp file and
        # override the exit code back to 0.
        bash_script = (
            f'tmpfile=$(mktemp)\n'
            f'"{VERIFY_PHASE}" "test" "{pass_cmd}" "{temp_dir}"'
            f' > "$tmpfile" 2>&1\n'
            f'# Simulate corrupted exit code\n'
            f'false\n'
            f'test_exit=$?\n'
            f'# Belt-and-suspenders override using VERIFY_EXIT marker\n'
            f'if [[ $test_exit -ne 0 ]] && grep -q "^VERIFY_EXIT: 0$"'
            f' "$tmpfile" 2>/dev/null; then\n'
            f'  test_exit=0\n'
            f'fi\n'
            f'echo "OVERRIDE_EXIT:$test_exit"\n'
            f'rm -f "$tmpfile"\n'
        )
        result = subprocess.run(
            ["bash", "-c", bash_script],
            capture_output=True,
            text=True,
            timeout=30,
        )
        override_exit = -1
        for line in result.stdout.strip().split("\n"):
            if line.startswith("OVERRIDE_EXIT:"):
                override_exit = int(line.split(":", 1)[1])

        t.assert_equal(
            "corrupted exit code overridden to 0 via VERIFY_EXIT marker",
            override_exit, 0,
        )

    with TempDir() as temp_dir:
        lines = generate_large_output_lines(200)
        lines.append("FAIL: 3 tests failed")
        fail_cmd = create_test_command(
            temp_dir, "fail_no_override.sh", lines, 1
        )

        # Real failure: exit code is non-zero AND VERIFY_EXIT says non-zero.
        # Override should NOT trigger.
        bash_script = (
            f'tmpfile=$(mktemp)\n'
            f'"{VERIFY_PHASE}" "test" "{fail_cmd}" "{temp_dir}"'
            f' > "$tmpfile" 2>&1\n'
            f'test_exit=$?\n'
            f'if [[ $test_exit -ne 0 ]] && grep -q "^VERIFY_EXIT: 0$"'
            f' "$tmpfile" 2>/dev/null; then\n'
            f'  test_exit=0\n'
            f'fi\n'
            f'echo "NOOVERRIDE_EXIT:$test_exit"\n'
            f'rm -f "$tmpfile"\n'
        )
        result = subprocess.run(
            ["bash", "-c", bash_script],
            capture_output=True,
            text=True,
            timeout=30,
        )
        no_override_exit = -1
        for line in result.stdout.strip().split("\n"):
            if line.startswith("NOOVERRIDE_EXIT:"):
                no_override_exit = int(line.split(":", 1)[1])

        t.assert_equal(
            "real failure NOT overridden (VERIFY_EXIT shows non-zero)",
            no_override_exit, 1,
        )

    # ─── Section 8: Spoofed RESULT marker regression ───
    t.section("Spoofed RESULT marker does not bypass override")

    with TempDir() as temp_dir:
        # Command prints "RESULT: test PASSED" but exits 1.
        # verify-phase.sh will see exit 1 and write VERIFY_EXIT: 1.
        # The override must NOT trigger (VERIFY_EXIT != 0).
        spoof_cmd = create_test_command(
            temp_dir, "spoof_pass.sh",
            ["RESULT: test PASSED", "FAIL: something broke"], 1,
        )

        bash_script = (
            f'tmpfile=$(mktemp)\n'
            f'"{VERIFY_PHASE}" "test" "{spoof_cmd}" "{temp_dir}"'
            f' > "$tmpfile" 2>&1\n'
            f'test_exit=$?\n'
            f'if [[ $test_exit -ne 0 ]] && grep -q "^VERIFY_EXIT: 0$"'
            f' "$tmpfile" 2>/dev/null; then\n'
            f'  test_exit=0\n'
            f'fi\n'
            f'echo "SPOOF_EXIT:$test_exit"\n'
            f'rm -f "$tmpfile"\n'
        )
        result = subprocess.run(
            ["bash", "-c", bash_script],
            capture_output=True,
            text=True,
            timeout=30,
        )
        spoof_exit = -1
        for line in result.stdout.strip().split("\n"):
            if line.startswith("SPOOF_EXIT:"):
                spoof_exit = int(line.split(":", 1)[1])

        t.assert_equal(
            "spoofed RESULT: test PASSED in command output does NOT override",
            spoof_exit, 1,
        )

    # ─── Section 9: Structured error transcript on failure ───
    t.section("Structured error transcript on failure (VERIFY_ERROR_CONTEXT)")

    # Clean up any artifact from a prior test run before asserting on its existence
    _error_file = "/tmp/verify-last-error-phaseX.json"
    if os.path.exists(_error_file):
        os.remove(_error_file)

    with TempDir() as temp_dir:
        fail_cmd = create_test_command(
            temp_dir, "fail_with_error.sh",
            ["Starting tests...", "Error: connection refused", "FAIL: 2 tests failed"], 1,
        )
        exit_code, output = run_script_combined(
            VERIFY_PHASE, "phaseX", fail_cmd, temp_dir
        )
        t.assert_equal("failing command returns exit 1", exit_code, 1)
        t.assert_contains("output contains VERIFY_ERROR_CONTEXT",
                          output, "VERIFY_ERROR_CONTEXT: {")

        # Parse and validate JSON structure
        error_context = None
        for line in output.splitlines():
            if line.startswith("VERIFY_ERROR_CONTEXT: "):
                json_str = line[len("VERIFY_ERROR_CONTEXT: "):]
                try:
                    error_context = json.loads(json_str)
                except (json.JSONDecodeError, ValueError):
                    pass
                break

        if error_context is not None:
            t._pass("VERIFY_ERROR_CONTEXT is valid JSON")
            t.assert_equal("phase field matches argument",
                           error_context.get("phase"), "phaseX")
            t.assert_equal("exit_code field matches",
                           error_context.get("exit_code"), 1)
            if "command" in error_context:
                t._pass("error context includes command")
            else:
                t._fail("error context includes command", "missing 'command' key")
            if "timestamp" in error_context:
                t._pass("error context includes timestamp")
            else:
                t._fail("error context includes timestamp", "missing 'timestamp' key")
            if "output_tail" in error_context:
                t._pass("error context includes output_tail")
                output_tail = error_context["output_tail"]
            else:
                t._fail("error context includes output_tail", "missing 'output_tail' key")
                output_tail = ""
            if "connection refused" in output_tail:
                t._pass("output_tail captures relevant error text")
            else:
                t._fail("output_tail captures relevant error text",
                        f"got: {output_tail[:120]!r}")
        else:
            t._fail("VERIFY_ERROR_CONTEXT is valid JSON",
                    "could not parse JSON from VERIFY_ERROR_CONTEXT line")

        # Verify transcript persisted to temp file
        error_file = "/tmp/verify-last-error-phaseX.json"
        if os.path.exists(error_file):
            t._pass("error transcript written to /tmp/verify-last-error-<phase>.json")
            try:
                with open(error_file) as f:
                    file_data = json.load(f)
                t.assert_equal("persisted file has correct phase",
                               file_data.get("phase"), "phaseX")
            except (json.JSONDecodeError, OSError) as e:
                t._fail("persisted file is valid JSON", str(e))
        else:
            t._fail("error transcript written to /tmp/verify-last-error-<phase>.json",
                    f"{error_file} not found")
        # Clean up test artifact regardless of outcome
        if os.path.exists(error_file):
            os.remove(error_file)

    # Passing commands must NOT emit error context
    with TempDir() as temp_dir:
        pass_cmd = create_test_command(
            temp_dir, "pass_no_context.sh", ["all good"], 0
        )
        exit_code, output = run_script_combined(
            VERIFY_PHASE, "build", pass_cmd, temp_dir
        )
        t.assert_equal("passing command returns exit 0", exit_code, 0)
        t.assert_not_contains("passing command omits VERIFY_ERROR_CONTEXT",
                              output, "VERIFY_ERROR_CONTEXT")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
