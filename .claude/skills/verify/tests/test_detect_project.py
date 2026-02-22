"""Tests for detect-project.sh command detection.

Exercises detect-project.sh with various project configurations:
- Node.js projects (existing behavior, regression)
- Go projects with/without Makefile
- Go projects with/without golangci-lint
- Unknown projects
- Typecheck behavior per language
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, script_path, run_script, TempDir, write_file, make_executable,
)

DETECT = script_path("detect-project.sh")


def _run_detect(project_dir, extra_path=None):
    """Run detect-project.sh against a directory, optionally prepending to PATH."""
    env = os.environ.copy()
    if extra_path:
        env["PATH"] = extra_path + ":" + env.get("PATH", "")
    _, stdout = run_script(DETECT, project_dir, env=env)
    return stdout.strip()


def _path_without_golangci_lint():
    """Return PATH with golangci-lint locations stripped."""
    return ":".join(
        p for p in os.environ.get("PATH", "").split(":")
        if "golangci-lint" not in p
    )


def run_tests():
    t = TestResults("detect-project.sh tests")
    t.header()

    with TempDir() as tmp:
        # ── Setup: fake golangci-lint binary ──
        fake_bin = os.path.join(tmp, "fake-bin")
        os.makedirs(fake_bin)
        write_file(fake_bin, "golangci-lint",
                   '#!/usr/bin/env bash\necho "golangci-lint fake"\n')
        make_executable(os.path.join(fake_bin, "golangci-lint"))

        path_with_lint = fake_bin + ":" + os.environ.get("PATH", "")
        path_without_lint = _path_without_golangci_lint()

        # ── Setup: Go project with Makefile (all targets) ──
        go_makefile_all = os.path.join(tmp, "go-makefile-all")
        os.makedirs(go_makefile_all)
        write_file(go_makefile_all, "go.mod", "module example.com/test\n")
        write_file(go_makefile_all, "Makefile",
                   ".PHONY: build lint test vet\n\n"
                   "build:\n\tgo build ./...\n\n"
                   "lint:\n\tgolangci-lint run\n\n"
                   "test:\n\tgo test ./...\n\n"
                   "vet:\n\tgo vet ./...\n")

        # ── Setup: Go project with partial Makefile (no lint) ──
        go_makefile_partial = os.path.join(tmp, "go-makefile-partial")
        os.makedirs(go_makefile_partial)
        write_file(go_makefile_partial, "go.mod", "module example.com/test\n")
        write_file(go_makefile_partial, "Makefile",
                   ".PHONY: build test\n\n"
                   "build:\n\tgo build ./...\n\n"
                   "test:\n\tgo test ./...\n")

        # ── Setup: Go project without Makefile ──
        go_no_makefile = os.path.join(tmp, "go-no-makefile")
        os.makedirs(go_no_makefile)
        write_file(go_no_makefile, "go.mod", "module example.com/test\n")

        # ── Setup: Node.js project ──
        node_project = os.path.join(tmp, "node-project")
        os.makedirs(node_project)
        write_file(node_project, "package.json",
                   '{"scripts":{"build":"tsc","lint":"eslint .","test":"vitest"}}')
        write_file(node_project, "tsconfig.json", "{}")

        # ── Setup: Unknown project ──
        unknown_project = os.path.join(tmp, "unknown")
        os.makedirs(unknown_project)
        write_file(unknown_project, "README.md", "readme\n")

        # ── Section 1: Go with Makefile (all targets) ──
        t.section("Go with Makefile (all targets)")

        output = _run_detect(go_makefile_all, extra_path=fake_bin)

        t.assert_field("project type is go",
                       output, "project_type", "go")
        t.assert_field("config_files.go_mod is True",
                       output, "config_files.go_mod", "True")
        t.assert_field("build uses make build",
                       output, "commands.build", "make build")
        t.assert_field("lint uses make lint",
                       output, "commands.lint", "make lint")
        t.assert_field("test uses make test",
                       output, "commands.test", "make test")
        t.assert_field_empty("typecheck is empty for Go",
                             output, "commands.typecheck")

        # ── Section 2: Go with partial Makefile (no lint target) ──
        t.section("Go with partial Makefile (no lint target)")

        env_with = os.environ.copy()
        env_with["PATH"] = path_with_lint
        _, stdout = run_script(DETECT, go_makefile_partial, env=env_with)
        output = stdout.strip()

        t.assert_field("build uses make build",
                       output, "commands.build", "make build")
        t.assert_field("lint falls back to golangci-lint run",
                       output, "commands.lint", "golangci-lint run")
        t.assert_field("test uses make test",
                       output, "commands.test", "make test")

        env_without = os.environ.copy()
        env_without["PATH"] = path_without_lint
        _, stdout = run_script(DETECT, go_makefile_partial, env=env_without)
        output = stdout.strip()

        t.assert_field("lint falls back to go vet without golangci-lint",
                       output, "commands.lint", "go vet ./...")

        # ── Section 3: Go without Makefile ──
        t.section("Go without Makefile")

        env_with["PATH"] = path_with_lint
        _, stdout = run_script(DETECT, go_no_makefile, env=env_with)
        output = stdout.strip()

        t.assert_field("build is go build",
                       output, "commands.build", "go build ./...")
        t.assert_field("lint is golangci-lint run",
                       output, "commands.lint", "golangci-lint run")
        t.assert_field("test is go test",
                       output, "commands.test", "go test ./...")
        t.assert_field_empty("typecheck is empty",
                             output, "commands.typecheck")

        env_without["PATH"] = path_without_lint
        _, stdout = run_script(DETECT, go_no_makefile, env=env_without)
        output = stdout.strip()

        t.assert_field("lint falls back to go vet without golangci-lint",
                       output, "commands.lint", "go vet ./...")
        t.assert_field("build still go build without golangci-lint",
                       output, "commands.build", "go build ./...")
        t.assert_field("test still go test without golangci-lint",
                       output, "commands.test", "go test ./...")

        # ── Section 4: Node.js project (regression) ──
        t.section("Node.js project (regression)")

        output = _run_detect(node_project)

        t.assert_field("project type is node-typescript",
                       output, "project_type", "node-typescript")
        t.assert_field("build is npm run build",
                       output, "commands.build", "npm run build")
        t.assert_field("lint is npm run lint",
                       output, "commands.lint", "npm run lint")
        t.assert_field("test is npm run test",
                       output, "commands.test", "npm run test")

        # ── Section 5: Unknown project ──
        t.section("Unknown project")

        output = _run_detect(unknown_project)

        t.assert_field("project type is unknown",
                       output, "project_type", "unknown")
        t.assert_field_empty("build is empty",
                             output, "commands.build")
        t.assert_field_empty("lint is empty",
                             output, "commands.lint")
        t.assert_field_empty("test is empty",
                             output, "commands.test")
        t.assert_field_empty("typecheck is empty",
                             output, "commands.typecheck")

        # ── Section 6: Go Makefile with vet target ──
        t.section("Go Makefile vet target detection")

        go_makefile_vet = os.path.join(tmp, "go-makefile-vet")
        os.makedirs(go_makefile_vet)
        write_file(go_makefile_vet, "go.mod", "module example.com/test\n")
        write_file(go_makefile_vet, "Makefile",
                   ".PHONY: build test vet\n\n"
                   "build:\n\tgo build ./...\n\n"
                   "test:\n\tgo test ./...\n\n"
                   "vet:\n\tgo vet ./...\n")

        env_without["PATH"] = path_without_lint
        _, stdout = run_script(DETECT, go_makefile_vet, env=env_without)
        output = stdout.strip()

        t.assert_field("lint uses make vet when no lint target and no golangci-lint",
                       output, "commands.lint", "make vet")

        # ── Section 7: verify.json override — test command ──
        t.section("verify.json override — test command only")

        verify_test_only = os.path.join(tmp, "verify-test-only")
        os.makedirs(os.path.join(verify_test_only, ".claude"))
        write_file(verify_test_only, "README.md", "readme\n")
        write_file(verify_test_only, ".claude/verify.json",
                   '{"commands": {"test": "python3 run_tests.py"}}')

        output = _run_detect(verify_test_only)

        t.assert_field("project type is unknown (no standard config)",
                       output, "project_type", "unknown")
        t.assert_field("test command from verify.json",
                       output, "commands.test", "python3 run_tests.py")
        t.assert_field_empty("build still empty (not in verify.json)",
                             output, "commands.build")
        t.assert_field_empty("lint still empty (not in verify.json)",
                             output, "commands.lint")

        # ── Section 8: verify.json override — all commands ──
        t.section("verify.json override — all commands")

        verify_all = os.path.join(tmp, "verify-all-cmds")
        os.makedirs(os.path.join(verify_all, ".claude"))
        write_file(verify_all, "README.md", "readme\n")
        write_file(verify_all, ".claude/verify.json",
                   '{"commands": {"build": "make build", "lint": "make lint",'
                   ' "test": "make test", "typecheck": "make typecheck"}}')

        output = _run_detect(verify_all)

        t.assert_field("build from verify.json",
                       output, "commands.build", "make build")
        t.assert_field("typecheck from verify.json",
                       output, "commands.typecheck", "make typecheck")
        t.assert_field("lint from verify.json",
                       output, "commands.lint", "make lint")
        t.assert_field("test from verify.json",
                       output, "commands.test", "make test")

        # ── Section 9: verify.json overrides auto-detected commands ──
        t.section("verify.json overrides auto-detected commands")

        verify_override = os.path.join(tmp, "verify-override")
        os.makedirs(os.path.join(verify_override, ".claude"))
        write_file(verify_override, "package.json",
                   '{"scripts":{"build":"tsc","test":"vitest"}}')
        write_file(verify_override, ".claude/verify.json",
                   '{"commands": {"test": "python3 custom_tests.py"}}')

        output = _run_detect(verify_override)

        t.assert_field("project type still detected from package.json",
                       output, "project_type", "node-javascript")
        t.assert_field("test overridden by verify.json",
                       output, "commands.test", "python3 custom_tests.py")
        t.assert_field("build still auto-detected from package.json",
                       output, "commands.build", "npm run build")

        # ── Section 10: verify.json partial override preserves auto-detect ──
        t.section("verify.json partial override preserves auto-detect")

        verify_partial = os.path.join(tmp, "verify-partial")
        os.makedirs(os.path.join(verify_partial, ".claude"))
        write_file(verify_partial, "go.mod", "module example.com/test\n")
        write_file(verify_partial, ".claude/verify.json",
                   '{"commands": {"test": "python3 run_tests.py"}}')

        output = _run_detect(verify_partial)

        t.assert_field("project type still go",
                       output, "project_type", "go")
        t.assert_field("test overridden by verify.json",
                       output, "commands.test", "python3 run_tests.py")
        t.assert_field("build still auto-detected for go",
                       output, "commands.build", "go build ./...")

        # ── Section 11: invalid verify.json is ignored ──
        t.section("invalid verify.json is gracefully ignored")

        verify_invalid = os.path.join(tmp, "verify-invalid")
        os.makedirs(os.path.join(verify_invalid, ".claude"))
        write_file(verify_invalid, "go.mod", "module example.com/test\n")
        write_file(verify_invalid, ".claude/verify.json", "not valid json{{{")

        output = _run_detect(verify_invalid)

        t.assert_field("project type still go despite bad verify.json",
                       output, "project_type", "go")
        t.assert_field("test falls through to auto-detect",
                       output, "commands.test", "go test ./...")

        # ── Section 12: run_tests.py fallback detection ──
        t.section("run_tests.py fallback detection")

        fallback_project = os.path.join(tmp, "fallback-runner")
        os.makedirs(fallback_project)
        write_file(fallback_project, "README.md", "readme\n")
        write_file(fallback_project, "run_tests.py",
                   "#!/usr/bin/env python3\nprint('tests')\n")

        output = _run_detect(fallback_project)

        t.assert_field("project type is unknown",
                       output, "project_type", "unknown")
        t.assert_field("test detected from run_tests.py in root",
                       output, "commands.test", "python3 run_tests.py")

        # ── Section 13: no fallback when no run_tests.py ──
        t.section("no fallback without run_tests.py")

        no_runner = os.path.join(tmp, "no-runner")
        os.makedirs(no_runner)
        write_file(no_runner, "README.md", "readme\n")

        output = _run_detect(no_runner)

        t.assert_field_empty("test still empty without run_tests.py",
                             output, "commands.test")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
