"""Tests for lint-changed.sh diff-scoped linting.

Exercises lint-changed.sh with various project configurations:
- JS/TS linting (existing behavior, regression)
- Go linting with golangci-lint (staged + branch scope)
- Go linting fallback to go vet
- Mixed JS+Go projects
- No lintable files changed

Usage: python3 .claude/skills/verify/tests/test_lint_changed.py
"""

import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, script_path, run_script_combined, TempDir,
    setup_git_repo, write_file, make_executable,
)

LINT_CHANGED = script_path("lint-changed.sh")


def _git(repo, *args):
    """Run a git command in a repo."""
    return subprocess.run(
        ["git"] + list(args),
        cwd=repo, capture_output=True, text=True,
    )


def _setup_fake_bins(temp_base):
    """Create fake binaries for testing. Returns (fake_bin_dir, fail_bin_dir)."""
    fake_bin = os.path.join(temp_base, "fake-bin")
    os.makedirs(fake_bin, exist_ok=True)

    # Fake golangci-lint that succeeds
    write_file(temp_base, "fake-bin/golangci-lint",
        '#!/usr/bin/env bash\n'
        'echo "GOLANGCI_ARGS: $*" >> "${GOLANGCI_LOG:-/dev/null}"\n'
        'echo "golangci-lint: no issues found"\n'
        'exit 0\n'
    )
    make_executable(os.path.join(fake_bin, "golangci-lint"))

    # Fake npx (for ESLint) that succeeds
    write_file(temp_base, "fake-bin/npx",
        '#!/usr/bin/env bash\n'
        'echo "npx: $*"\n'
        'exit 0\n'
    )
    make_executable(os.path.join(fake_bin, "npx"))

    # Fake golangci-lint that fails (in separate directory)
    fail_bin = os.path.join(temp_base, "fail-bin")
    os.makedirs(fail_bin, exist_ok=True)
    write_file(temp_base, "fail-bin/golangci-lint",
        '#!/usr/bin/env bash\n'
        'echo "GOLANGCI_ARGS: $*" >> "${GOLANGCI_LOG:-/dev/null}"\n'
        'echo "main.go:10: exported function Foo should have comment (golint)"\n'
        'exit 1\n'
    )
    make_executable(os.path.join(fail_bin, "golangci-lint"))

    return fake_bin, fail_bin


def _path_with(directory):
    """Return PATH with directory prepended."""
    return directory + ":" + os.environ.get("PATH", "")


def _path_without_golangci_lint(fake_bin):
    """Return PATH with fake_bin and any real golangci-lint directory removed."""
    current = os.environ.get("PATH", "")
    dirs = current.split(":")
    dirs = [d for d in dirs if d != fake_bin]
    real = shutil.which("golangci-lint")
    if real:
        real_dir = os.path.dirname(real)
        dirs = [d for d in dirs if d != real_dir]
    return ":".join(dirs)


def run_tests():
    t = TestResults("lint-changed.sh tests")
    t.header()

    with TempDir() as temp_base:
        fake_bin, fail_bin = _setup_fake_bins(temp_base)
        path_with_lint = _path_with(fake_bin)
        path_without_lint = _path_without_golangci_lint(fake_bin)

        # ─── Section 1: No lintable files changed ───
        t.section("No lintable files changed")

        repo_none = os.path.join(temp_base, "repo-none")
        os.makedirs(repo_none)
        setup_git_repo(repo_none)
        write_file(repo_none, "README.md", "readme\n")
        _git(repo_none, "add", "README.md")

        env = dict(os.environ, PATH=path_with_lint)
        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_none, "", env=env)

        t.assert_exit_code("exits 0 when no lintable files", exit_code, 0)
        t.assert_contains("reports no lintable files", output,
                          "No lintable files changed")

        # ─── Section 2: JS/TS files (regression) ───
        t.section("JS/TS linting (regression)")

        repo_js = os.path.join(temp_base, "repo-js")
        os.makedirs(repo_js)
        setup_git_repo(repo_js)
        write_file(repo_js, "eslint.config.js", "{}\n")
        _git(repo_js, "add", "eslint.config.js")
        _git(repo_js, "commit", "-q", "-m", "add eslint config")
        write_file(repo_js, "index.js", "console.log('hi')\n")
        _git(repo_js, "add", "index.js")

        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_js, "npm run lint", env=env)

        t.assert_exit_code("exits 0 for JS lint pass", exit_code, 0)
        t.assert_contains("reports linting JS files", output, "changed file(s)")
        t.assert_contains("lists index.js", output, "index.js")

        # ─── Section 3: Go staged with golangci-lint ───
        t.section("Go staged linting with golangci-lint")

        repo_go_staged = os.path.join(temp_base, "repo-go-staged")
        os.makedirs(repo_go_staged)
        setup_git_repo(repo_go_staged)
        write_file(repo_go_staged, "go.mod", "module example.com/test\n")
        _git(repo_go_staged, "add", "go.mod")
        _git(repo_go_staged, "commit", "-q", "-m", "add go.mod")
        write_file(repo_go_staged, "main.go", "package main\n")
        write_file(repo_go_staged, "util.go", "package util\n")
        _git(repo_go_staged, "add", "main.go", "util.go")

        golangci_log = os.path.join(temp_base, "golangci-staged.log")
        write_file(temp_base, "golangci-staged.log", "")
        env_go = dict(os.environ, PATH=path_with_lint, GOLANGCI_LOG=golangci_log)

        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_go_staged, "go vet ./...", env=env_go)

        t.assert_exit_code("exits 0 for Go staged lint pass", exit_code, 0)
        t.assert_contains("reports linting Go files", output, "changed file(s)")
        t.assert_contains("lists main.go", output, "main.go")

        with open(golangci_log) as f:
            golangci_call = f.read()
        t.assert_contains("golangci-lint called with 'run'",
                          golangci_call, "run")
        t.assert_not_contains(
            "golangci-lint NOT called with --new-from-rev for staged",
            golangci_call, "--new-from-rev")

        # ─── Section 4: Go branch with golangci-lint ───
        t.section("Go branch linting with golangci-lint")

        repo_go_branch = os.path.join(temp_base, "repo-go-branch")
        os.makedirs(repo_go_branch)
        setup_git_repo(repo_go_branch)
        write_file(repo_go_branch, "go.mod", "module example.com/test\n")
        _git(repo_go_branch, "add", "go.mod")
        _git(repo_go_branch, "commit", "-q", "-m", "add go.mod")
        _git(repo_go_branch, "checkout", "-q", "-b", "feature")
        write_file(repo_go_branch, "main.go", "package main\n")
        _git(repo_go_branch, "add", "main.go")
        _git(repo_go_branch, "commit", "-q", "-m", "add main.go")

        golangci_log_branch = os.path.join(temp_base, "golangci-branch.log")
        write_file(temp_base, "golangci-branch.log", "")
        env_branch = dict(os.environ, PATH=path_with_lint,
                          GOLANGCI_LOG=golangci_log_branch)

        exit_code, output = run_script_combined(
            LINT_CHANGED, "HEAD~1", repo_go_branch, "go vet ./...",
            env=env_branch)

        t.assert_exit_code("exits 0 for Go branch lint pass", exit_code, 0)

        with open(golangci_log_branch) as f:
            golangci_call = f.read()
        t.assert_contains("golangci-lint uses --new-from-rev for branch scope",
                          golangci_call, "--new-from-rev")

        # ─── Section 5: Go fallback when no golangci-lint ───
        t.section("Go linting fallback (no golangci-lint)")

        repo_go_fallback = os.path.join(temp_base, "repo-go-fallback")
        os.makedirs(repo_go_fallback)
        setup_git_repo(repo_go_fallback)
        write_file(repo_go_fallback, "go.mod", "module example.com/test\n")
        _git(repo_go_fallback, "add", "go.mod")
        _git(repo_go_fallback, "commit", "-q", "-m", "add go.mod")
        write_file(repo_go_fallback, "main.go", "package main\n")
        _git(repo_go_fallback, "add", "main.go")

        env_no_lint = dict(os.environ, PATH=path_without_lint)
        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_go_fallback, "echo FALLBACK_RAN",
            env=env_no_lint)

        t.assert_exit_code("exits 0 with fallback command", exit_code, 0)
        t.assert_contains("runs fallback command", output, "FALLBACK_RAN")

        # ─── Section 6: Go no linter, no fallback ───
        t.section("Go linting skipped (no linter, no fallback)")

        repo_go_skip = os.path.join(temp_base, "repo-go-skip")
        os.makedirs(repo_go_skip)
        setup_git_repo(repo_go_skip)
        write_file(repo_go_skip, "go.mod", "module example.com/test\n")
        _git(repo_go_skip, "add", "go.mod")
        _git(repo_go_skip, "commit", "-q", "-m", "add go.mod")
        write_file(repo_go_skip, "main.go", "package main\n")
        _git(repo_go_skip, "add", "main.go")

        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_go_skip, "", env=env_no_lint)

        t.assert_exit_code("exits 0 when no linter available", exit_code, 0)
        t.assert_contains("reports no linter detected", output,
                          "No linter detected")

        # ─── Section 7: Go lint failure propagates exit code ───
        t.section("Go lint failure exit code")

        repo_go_fail = os.path.join(temp_base, "repo-go-fail")
        os.makedirs(repo_go_fail)
        setup_git_repo(repo_go_fail)
        write_file(repo_go_fail, "go.mod", "module example.com/test\n")
        _git(repo_go_fail, "add", "go.mod")
        _git(repo_go_fail, "commit", "-q", "-m", "add go.mod")
        write_file(repo_go_fail, "main.go", "package main\n")
        _git(repo_go_fail, "add", "main.go")

        path_with_fail = fail_bin + ":" + path_without_lint
        env_fail = dict(os.environ, PATH=path_with_fail)
        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_go_fail, "", env=env_fail)

        t.assert_exit_code("exits 1 when Go lint fails", exit_code, 1)
        t.assert_contains("reports lint FAILED", output, "RESULT: lint FAILED")

        # ─── Section 8: Mixed JS + Go project ───
        t.section("Mixed JS + Go project")

        repo_mixed = os.path.join(temp_base, "repo-mixed")
        os.makedirs(repo_mixed)
        setup_git_repo(repo_mixed)
        write_file(repo_mixed, "eslint.config.js", "{}\n")
        write_file(repo_mixed, "go.mod", "module example.com/test\n")
        _git(repo_mixed, "add", "eslint.config.js", "go.mod")
        _git(repo_mixed, "commit", "-q", "-m", "setup")
        write_file(repo_mixed, "index.js", "console.log('hi')\n")
        write_file(repo_mixed, "main.go", "package main\n")
        _git(repo_mixed, "add", "index.js", "main.go")

        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_mixed, "", env=env)

        t.assert_exit_code("exits 0 for mixed project lint pass", exit_code, 0)
        t.assert_contains("lists index.js in output", output, "index.js")
        t.assert_contains("lists main.go in output", output, "main.go")

        # ─── Section 9: Only non-lintable files (.py) ───
        t.section("Only .py files changed (not lintable)")

        repo_py = os.path.join(temp_base, "repo-py")
        os.makedirs(repo_py)
        setup_git_repo(repo_py)
        write_file(repo_py, "script.py", 'print("hi")\n')
        _git(repo_py, "add", "script.py")

        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_py, "", env=env)

        t.assert_exit_code("exits 0 when only .py files changed", exit_code, 0)
        t.assert_contains("reports no lintable files", output,
                          "No lintable files changed")

        # ─── Section 10: golangci-lint config detection ───
        t.section("golangci-lint config detection")

        repo_go_config = os.path.join(temp_base, "repo-go-config")
        os.makedirs(repo_go_config)
        setup_git_repo(repo_go_config)
        write_file(repo_go_config, "go.mod", "module example.com/test\n")
        write_file(repo_go_config, ".golangci.yml", "linters:\n")
        _git(repo_go_config, "add", "go.mod", ".golangci.yml")
        _git(repo_go_config, "commit", "-q", "-m", "setup")
        write_file(repo_go_config, "main.go", "package main\n")
        _git(repo_go_config, "add", "main.go")

        golangci_log_config = os.path.join(temp_base, "golangci-config.log")
        write_file(temp_base, "golangci-config.log", "")
        env_config = dict(os.environ, PATH=path_with_lint,
                          GOLANGCI_LOG=golangci_log_config)

        exit_code, output = run_script_combined(
            LINT_CHANGED, "staged", repo_go_config, "go vet ./...",
            env=env_config)

        t.assert_exit_code("exits 0 with golangci-lint config present",
                           exit_code, 0)

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
