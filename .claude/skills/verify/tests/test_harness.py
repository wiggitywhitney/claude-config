"""Shared test framework for verify suite — stdlib only, no external dependencies.

Provides:
- JSON builders: make_hook_input() — in-memory, no subprocess
- JSON parsing: json_field() — in-memory, no subprocess
- Hook runner: run_hook() — subprocess.run with stdin piping
- Script runner: run_script() — subprocess.run with env control
- Fixture helpers: TempDir context manager, write_file(), setup_git_repo()
- Assertions: TestResults class with assert_allow, assert_deny, etc.
- Reporter: Colored PASS/FAIL output matching current terminal format
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil

# ── Colors ──────────────────────────────────────────────────────────

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"  # No Color


# ── Path Resolution ─────────────────────────────────────────────────

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.join(TESTS_DIR, "..", "scripts")


def hook_path(name):
    """Resolve path to a hook script by name (e.g. 'check-commit-message.sh')."""
    return os.path.join(SCRIPTS_DIR, name)


def script_path(name):
    """Resolve path to a utility script by name (e.g. 'detect-project.sh')."""
    return os.path.join(SCRIPTS_DIR, name)


# ── JSON Builders ───────────────────────────────────────────────────

def make_hook_input(command, cwd="/tmp/test-project"):
    """Build PreToolUse hook event JSON — in-memory, no subprocess."""
    return json.dumps({
        "tool_name": "Bash",
        "tool_input": {"command": command},
        "cwd": cwd,
    })


# ── JSON Parsing ────────────────────────────────────────────────────

def json_field(json_str, field_path):
    """Extract a nested field from JSON using dot-notation path.

    Returns the value as a string (matching bash behavior), or empty string
    if the field is missing or None.
    """
    try:
        data = json.loads(json_str)
    except (json.JSONDecodeError, TypeError):
        return ""
    keys = field_path.split(".")
    val = data
    for k in keys:
        if isinstance(val, dict) and k in val:
            val = val[k]
        else:
            return ""
    if val is None:
        return ""
    return str(val)


# ── Subprocess Runners ──────────────────────────────────────────────

def run_hook(hook, json_input):
    """Run a hook script, piping json_input to stdin.

    Returns (exit_code, stdout).
    """
    result = subprocess.run(
        [hook],
        input=json_input,
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout


def run_script(script, *args, env=None, cwd=None):
    """Run a utility script with positional args.

    Returns (exit_code, stdout).
    """
    cmd = [script] + list(args)
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
    )
    return result.returncode, result.stdout


# ── Fixture Helpers ─────────────────────────────────────────────────

class TempDir:
    """Context manager providing a temporary directory with auto-cleanup."""

    def __init__(self):
        self.path = None

    def __enter__(self):
        self.path = tempfile.mkdtemp()
        return self.path

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.path and os.path.exists(self.path):
            shutil.rmtree(self.path)
        return False


def write_file(base_dir, relative_path, content=""):
    """Write a file at base_dir/relative_path, creating parent dirs as needed."""
    full_path = os.path.join(base_dir, relative_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w") as f:
        f.write(content)
    return full_path


def setup_git_repo(path, branch="main"):
    """Initialize a git repo at path with an initial commit.

    Returns the repo path.
    """
    subprocess.run(
        ["git", "init", "-b", branch, "--quiet"],
        cwd=path,
        capture_output=True,
    )
    subprocess.run(
        ["git", "commit", "--allow-empty", "-m", "initial", "--quiet"],
        cwd=path,
        capture_output=True,
    )
    return path


def make_executable(path):
    """Make a file executable (chmod +x equivalent)."""
    os.chmod(path, os.stat(path).st_mode | 0o111)


# ── Test Results & Assertions ───────────────────────────────────────

class TestResults:
    """Tracks pass/fail counts and provides assertion methods.

    Each assertion method increments counters and prints colored output.
    """

    def __init__(self, suite_name="tests"):
        self.suite_name = suite_name
        self.passed = 0
        self.failed = 0
        self.total = 0

    def _pass(self, description):
        self.passed += 1
        self.total += 1
        print(f"{GREEN}  PASS{NC} {description}")

    def _fail(self, description, details=""):
        self.failed += 1
        self.total += 1
        print(f"{RED}  FAIL{NC} {description}")
        if details:
            for line in details.strip().split("\n"):
                print(f"       {line}")

    def section(self, title):
        """Print a section header."""
        print(f"\n{YELLOW}--- {title} ---{NC}")

    def header(self):
        """Print the suite header."""
        print(f"\n{YELLOW}=== {self.suite_name} ==={NC}\n")

    def summary(self):
        """Print results summary. Returns exit code (0=pass, 1=fail)."""
        print()
        print(f"{YELLOW}=== Results ==={NC}")
        print(
            f"  Total: {self.total} | "
            f"{GREEN}Passed: {self.passed}{NC} | "
            f"{RED}Failed: {self.failed}{NC}"
        )
        print()
        return 0 if self.failed == 0 else 1

    # ── Hook assertions (for PreToolUse hooks) ──

    def assert_allow(self, description, hook, json_input):
        """Assert hook allows the input (exit 0, no 'deny' in output)."""
        exit_code, output = run_hook(hook, json_input)
        if exit_code == 0 and '"deny"' not in output:
            self._pass(description)
        else:
            self._fail(description, (
                "Expected: allow (silent passthrough)\n"
                f"Got exit={exit_code}, output={output}"
            ))

    def assert_deny(self, description, hook, json_input):
        """Assert hook denies the input (exit 0, 'deny' in output)."""
        exit_code, output = run_hook(hook, json_input)
        if exit_code == 0 and '"deny"' in output:
            self._pass(description)
        else:
            self._fail(description, (
                "Expected: deny with JSON output\n"
                f"Got exit={exit_code}, output={output}"
            ))

    def assert_deny_contains(self, description, hook, json_input, fragment):
        """Assert hook denies and output contains fragment (case-insensitive)."""
        exit_code, output = run_hook(hook, json_input)
        if (exit_code == 0
                and '"deny"' in output
                and fragment.lower() in output.lower()):
            self._pass(description)
        else:
            self._fail(description, (
                f"Expected: deny containing '{fragment}'\n"
                f"Got exit={exit_code}, output={output}"
            ))

    # ── Field assertions (for script JSON output) ──

    def assert_field(self, description, json_str, field, expected):
        """Assert a JSON field equals expected value."""
        actual = json_field(json_str, field)
        if actual == expected:
            self._pass(description)
        else:
            self._fail(description, (
                f"Field: {field}\n"
                f"Expected: '{expected}'\n"
                f"Got:      '{actual}'"
            ))

    def assert_field_empty(self, description, json_str, field):
        """Assert a JSON field is empty/null/missing."""
        actual = json_field(json_str, field)
        if actual == "":
            self._pass(description)
        else:
            self._fail(description, (
                f"Field: {field}\n"
                f"Expected: empty/null\n"
                f"Got:      '{actual}'"
            ))

    def assert_tier(self, description, json_str, tier, expected):
        """Assert a test_tiers.<tier> field equals expected value."""
        self.assert_field(description, json_str, f"test_tiers.{tier}", expected)

    def assert_project_type(self, description, json_str, expected):
        """Assert the project_type field equals expected value."""
        self.assert_field(description, json_str, "project_type", expected)

    # ── Generic assertions ──

    def assert_equal(self, description, actual, expected):
        """Assert two values are equal."""
        if actual == expected:
            self._pass(description)
        else:
            self._fail(description, (
                f"Expected: {expected!r}\n"
                f"Got:      {actual!r}"
            ))

    def assert_contains(self, description, haystack, needle):
        """Assert haystack contains needle."""
        if needle in haystack:
            self._pass(description)
        else:
            self._fail(description, (
                f"Expected to contain: {needle!r}\n"
                f"In: {haystack!r}"
            ))

    def assert_exit_code(self, description, actual, expected):
        """Assert an exit code matches expected."""
        if actual == expected:
            self._pass(description)
        else:
            self._fail(description, (
                f"Expected exit code: {expected}\n"
                f"Got: {actual}"
            ))
