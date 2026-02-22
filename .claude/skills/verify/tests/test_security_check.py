"""Tests for security-check.sh.

Exercises security-check.sh with Go project configurations:
- Go fmt.Print in library packages (detected)
- Go fmt.Print in main packages (skipped)
- Go log.Print in library packages (detected)
- Go debug prints with //nolint (skipped)
- Go _test.go files (skipped)
- Go vendor directory (skipped)
- .verify-skip exclusion for Go files
- Diff-scoped Go detection
- JS console.log regression

Usage: python3 .claude/skills/verify/tests/test_security_check.py
"""

import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, script_path, run_script_combined, TempDir, write_file,
)

SECURITY_CHECK = script_path("security-check.sh")


def _git(repo, *args):
    """Run a git command in a repo."""
    return subprocess.run(
        ["git"] + list(args),
        cwd=repo, capture_output=True, text=True,
    )


def _init_repo(path):
    """Initialize a git repo with all files committed."""
    _git(path, "init", "-q")
    _git(path, "config", "user.email", "test@test.com")
    _git(path, "config", "user.name", "Test")
    _git(path, "add", "-A")
    _git(path, "commit", "-q", "-m", "initial")


def _setup_go_project(project_dir):
    """Create a Go project with various debug print patterns."""
    os.makedirs(os.path.join(project_dir, "internal", "service"), exist_ok=True)
    os.makedirs(os.path.join(project_dir, "cmd", "myapp"), exist_ok=True)
    os.makedirs(os.path.join(project_dir, "vendor", "thirdparty"), exist_ok=True)

    write_file(project_dir, "go.mod", "module example.com/test\n")

    # Library package with fmt.Println (SHOULD be detected)
    write_file(project_dir, "internal/service/handler.go",
        'package service\n\nimport "fmt"\n\n'
        'func Handle() {\n\tfmt.Println("debug: handling request")\n}\n')

    # Library package with fmt.Printf (SHOULD be detected)
    write_file(project_dir, "internal/service/format.go",
        'package service\n\nimport "fmt"\n\n'
        'func Format(n int) {\n\tfmt.Printf("debug value: %d\\n", n)\n}\n')

    # Library package with log.Println (SHOULD be detected)
    write_file(project_dir, "internal/service/logger.go",
        'package service\n\nimport "log"\n\n'
        'func Init() {\n\tlog.Println("initializing service")\n}\n')

    # Main package with fmt.Println (should NOT be detected)
    write_file(project_dir, "cmd/myapp/main.go",
        'package main\n\nimport "fmt"\n\n'
        'func main() {\n\tfmt.Println("Starting application")\n}\n')

    # Library with //nolint suppression (should NOT be detected)
    write_file(project_dir, "internal/service/intentional.go",
        'package service\n\nimport "fmt"\n\n'
        'func DebugOutput() {\n\tfmt.Println("intentional output") //nolint\n}\n')

    # Library with // nolint spaced (should NOT be detected)
    write_file(project_dir, "internal/service/spaced.go",
        'package service\n\nimport "fmt"\n\n'
        'func SpacedNolint() {\n\tfmt.Println("spaced nolint") // nolint\n}\n')

    # Test file (should NOT be detected)
    write_file(project_dir, "internal/service/handler_test.go",
        'package service\n\nimport (\n\t"fmt"\n\t"testing"\n)\n\n'
        'func TestHandle(t *testing.T) {\n\tfmt.Println("test debug output")\n}\n')

    # Vendor file (should NOT be detected)
    write_file(project_dir, "vendor/thirdparty/lib.go",
        'package thirdparty\n\nimport "fmt"\n\n'
        'func Lib() {\n\tfmt.Println("vendor code")\n}\n')

    _init_repo(project_dir)


def _setup_go_diff_project(project_dir):
    """Create a Go project for diff-scoped testing. Returns base commit hash."""
    os.makedirs(os.path.join(project_dir, "internal", "service"), exist_ok=True)
    os.makedirs(os.path.join(project_dir, "cmd", "myapp"), exist_ok=True)

    write_file(project_dir, "go.mod", "module example.com/test\n")

    # Clean initial commit
    write_file(project_dir, "internal/service/handler.go",
        'package service\n\nfunc Handle() {\n\t// clean code\n}\n')
    write_file(project_dir, "cmd/myapp/main.go",
        'package main\n\nfunc main() {\n\t// clean main\n}\n')

    _init_repo(project_dir)

    base_commit = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=project_dir, capture_output=True, text=True,
    ).stdout.strip()

    # Add debug prints in second commit
    write_file(project_dir, "internal/service/handler.go",
        'package service\n\nimport "fmt"\n\n'
        'func Handle() {\n\tfmt.Println("debug added in branch")\n}\n')
    write_file(project_dir, "cmd/myapp/main.go",
        'package main\n\nimport "fmt"\n\n'
        'func main() {\n\tfmt.Println("main output added in branch")\n}\n')

    _git(project_dir, "add", "-A")
    _git(project_dir, "commit", "-q", "-m", "add debug prints")

    return base_commit


def _setup_go_verify_skip_project(project_dir):
    """Create a Go project with .verify-skip for generated code."""
    os.makedirs(os.path.join(project_dir, "internal", "service"), exist_ok=True)
    os.makedirs(os.path.join(project_dir, "generated"), exist_ok=True)

    write_file(project_dir, "go.mod", "module example.com/test\n")

    write_file(project_dir, "internal/service/handler.go",
        'package service\n\nimport "fmt"\n\n'
        'func Handle() {\n\tfmt.Println("debug in service")\n}\n')

    write_file(project_dir, "generated/zz_generated.go",
        'package generated\n\nimport "fmt"\n\n'
        'func Generated() {\n\tfmt.Println("generated code")\n}\n')

    write_file(project_dir, ".verify-skip", "generated/\n")

    _init_repo(project_dir)


def _setup_clean_go_project(project_dir):
    """Create a Go project with no debug prints."""
    os.makedirs(os.path.join(project_dir, "internal", "service"), exist_ok=True)

    write_file(project_dir, "go.mod", "module example.com/test\n")
    write_file(project_dir, "internal/service/handler.go",
        'package service\n\nfunc Handle() {\n\t// clean code, no debug prints\n}\n')

    _init_repo(project_dir)


def _setup_js_project(project_dir):
    """Create a JS project with console.log for regression testing."""
    os.makedirs(os.path.join(project_dir, "src"), exist_ok=True)

    write_file(project_dir, "package.json", '{"name":"test"}\n')
    write_file(project_dir, "src/index.js",
        'function main() {\n  console.log("debug output");\n}\n')

    _init_repo(project_dir)


def run_tests():
    t = TestResults("security-check.sh tests")
    t.header()

    with TempDir() as temp_base:
        # ─── Section 1: Go debug code detection (repo-scoped) ───
        t.section("Go debug code detection (repo-scoped)")

        go_project = os.path.join(temp_base, "go-project")
        os.makedirs(go_project)
        _setup_go_project(go_project)

        exit_code, output = run_script_combined(
            SECURITY_CHECK, "standard", go_project)

        t.assert_contains("detects fmt.Println in library package",
                          output, "handler.go")
        t.assert_contains("detects fmt.Printf in library package",
                          output, "format.go")
        t.assert_contains("detects log.Println in library package",
                          output, "logger.go")
        t.assert_not_contains("skips fmt.Println in main package",
                              output, "main.go")
        t.assert_not_contains("skips fmt.Println with //nolint",
                              output, "intentional.go")
        t.assert_not_contains("skips fmt.Println with // nolint (spaced)",
                              output, "spaced.go")
        t.assert_not_contains("skips fmt.Println in _test.go files",
                              output, "handler_test.go")
        t.assert_not_contains("skips fmt.Println in vendor directory",
                              output, "vendor/")
        t.assert_contains("shows fmt.Print finding category",
                          output, "fmt.Print")
        t.assert_contains("shows log.Print finding category",
                          output, "log.Print")
        t.assert_exit_code("exits 1 when Go debug prints found",
                           exit_code, 1)

        # ─── Section 2: Go diff-scoped detection ───
        t.section("Go debug code detection (diff-scoped)")

        go_diff_project = os.path.join(temp_base, "go-diff-project")
        os.makedirs(go_diff_project)
        base_commit = _setup_go_diff_project(go_diff_project)

        exit_code, output = run_script_combined(
            SECURITY_CHECK, "standard", go_diff_project, base_commit)

        t.assert_contains("diff-scoped: detects fmt.Println in library package",
                          output, "handler.go")
        t.assert_not_contains("diff-scoped: skips fmt.Println in main package",
                              output, "main.go")
        t.assert_exit_code("diff-scoped: exits 1 when Go debug prints found",
                           exit_code, 1)

        # ─── Section 3: .verify-skip exclusion ───
        t.section(".verify-skip exclusion for Go files")

        go_skip_project = os.path.join(temp_base, "go-skip-project")
        os.makedirs(go_skip_project)
        _setup_go_verify_skip_project(go_skip_project)

        exit_code, output = run_script_combined(
            SECURITY_CHECK, "standard", go_skip_project)

        t.assert_contains("detects fmt.Println outside .verify-skip paths",
                          output, "handler.go")
        t.assert_not_contains("skips fmt.Println inside .verify-skip paths",
                              output, "generated/")
        t.assert_exit_code("exits 1 for non-skipped Go debug prints",
                           exit_code, 1)

        # ─── Section 4: Clean Go project (no findings) ───
        t.section("Clean Go project (no findings)")

        clean_go = os.path.join(temp_base, "clean-go")
        os.makedirs(clean_go)
        _setup_clean_go_project(clean_go)

        exit_code, output = run_script_combined(
            SECURITY_CHECK, "standard", clean_go)

        t.assert_contains("clean Go project passes", output, "PASSED")
        t.assert_exit_code("exits 0 for clean Go project", exit_code, 0)

        # ─── Section 5: JS console.log regression ───
        t.section("JS console.log regression")

        js_project = os.path.join(temp_base, "js-project")
        os.makedirs(js_project)
        _setup_js_project(js_project)

        exit_code, output = run_script_combined(
            SECURITY_CHECK, "standard", js_project)

        t.assert_contains("still detects JS console.log", output, "console.log")
        t.assert_exit_code("exits 1 for JS console.log", exit_code, 1)

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
