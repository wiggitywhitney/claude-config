# PRD #12: Python Test Harness for Verify Suite

**Status**: Open
**Priority**: Medium
**Created**: 2026-02-21
**Issue**: [#12](https://github.com/wiggitywhitney/claude-config/issues/12)

## Problem Statement

The verify test suite (8 bash files, ~2,637 lines in `.claude/skills/verify/tests/`) spawns 200-600 Python subprocesses per full run. Each test case invokes Python for:

1. **JSON input generation** (`make_input()`) — builds the PreToolUse hook event JSON
2. **JSON output parsing** (`json_field()`) — extracts nested fields from hook/script output
3. **Hook-internal parsing** — hooks themselves use `python3 -c` for JSON extraction

The first two are entirely eliminable by running the test harness in Python. The third is inherent to the bash hooks and out of scope.

**Impact**: The commit message tests alone (33 cases) take ~20 seconds. The full suite across all 8 test files adds significant friction to every push and PR from this repo. This discourages running tests locally and slows the development feedback loop.

### Test Discovery Gap

`detect-project.sh` finds test commands by reading standard config files (`package.json`, `go.mod`, `Makefile`, etc.). Projects without these files — including `claude-config` itself — return `test: null`, causing the PR hook to **silently skip the test phase entirely**. This means repos with non-standard test setups (shell test suites, custom runners, Python scripts without `pyproject.toml`) get no test coverage at the PR gate despite having tests.

This gap affects any project where tests exist but aren't discoverable through conventional package manager config. The Python test harness migration must also solve test discovery so the PR hook can find and run the tests.

## Solution

Rewrite the test harness in Python (stdlib only, no external dependencies), keeping all hooks as bash scripts. JSON generation and parsing become in-memory Python operations. Only hook/script invocations remain as subprocesses.

### Architecture

```text
.claude/skills/verify/tests/
  run_tests.py                      # Runner: discovers test_*.py, combined summary
  test_harness.py                   # Shared: colors, assertions, hook runner, JSON builders
  test_check_commit_message.py      # Replaces test-check-commit-message.sh
  test_check_branch_protection.py   # Replaces test-check-branch-protection.sh
  test_check_coderabbit_required.py # Replaces test-check-coderabbit-required.sh
  test_check_test_tiers.py          # Replaces test-check-test-tiers.sh
  test_detect_project.py            # Replaces test-detect-project.sh
  test_detect_test_tiers.py         # Replaces test-detect-test-tiers.sh
  test_lint_changed.py              # Replaces test-lint-changed.sh
  test_security_check.py            # Replaces test-security-check.sh
```

### Shared Module (`test_harness.py`)

Provides:
- **JSON builders**: `make_hook_input(command, cwd)` — in-memory, no subprocess
- **JSON parsing**: `json_field(json_str, field_path)` — in-memory, no subprocess
- **Hook runner**: `run_hook(hook_path, json_input)` — subprocess.run with stdin piping
- **Script runner**: `run_script(script_path, args, cwd, env)` — subprocess.run with env control
- **Fixture helpers**: `setup_git_repo()`, `write_file()` — Python equivalents of bash setup
- **Assertions**: `TestResults` class with `assert_allow`, `assert_deny`, `assert_field`, `assert_contains`, etc.
- **Reporter**: Colored PASS/FAIL output matching current terminal format

### Test Runner (`run_tests.py`)

- Discovers `test_*.py` files (excluding `test_harness.py`)
- Each module exports `run_tests() -> (passed, failed, total)`
- Supports filtering: `python3 run_tests.py check_commit_message`
- Prints combined summary with timing

## Success Criteria

- [ ] All 8 bash test files have equivalent Python replacements
- [ ] Python test suite produces identical pass/fail results as bash suite
- [ ] Full suite runtime reduced by at least 50% compared to bash version
- [x] Each test file is independently runnable (`python3 test_check_commit_message.py`)
- [x] Combined runner works (`python3 run_tests.py`)
- [x] No external Python dependencies required (stdlib only)
- [ ] Bash test files removed after Python equivalents confirmed
- [ ] `detect-project.sh` discovers test commands for non-standard projects (including this repo)
- [ ] PR hook successfully runs tests for `claude-config` (no more silent skip)
- [ ] Any project can declare its test command via `.claude/verify.json` override

## Architecture Decisions

### Decision 1: stdlib Only, No pytest

**Date**: 2026-02-21
**Decision**: Use only Python standard library (json, subprocess, tempfile, os, sys). No pytest or other external dependencies.
**Rationale**: This repo has no Python package management infrastructure (no requirements.txt, no pyproject.toml). Adding pytest would require adding package management. The tests are simple assertions — stdlib is sufficient.
**Impact**: Custom `TestResults` class instead of pytest fixtures/assertions. Trade-off is acceptable for zero-dependency operation.

### Decision 2: Functions + Dicts Over unittest/dataclasses

**Date**: 2026-02-21
**Decision**: Use plain functions and dicts rather than unittest.TestCase or dataclasses for test structure.
**Rationale**: The existing test mental model is flat functions organized by sections, not class hierarchies. Tests are checking exit codes and string matching on stdout — plain functions with dicts are the right abstraction level.
**Impact**: Each test file has a `run_tests()` function with sequential assertion calls, matching the current bash structure.

### Decision 3: Each File Standalone + Combined Runner

**Date**: 2026-02-21
**Decision**: Each test file is independently runnable AND a combined runner discovers/runs all tests.
**Rationale**: Matches current behavior where each `.sh` file runs independently. The runner adds combined summary and timing. Developers can run a single test file during development, full suite during verification.
**Impact**: Small boilerplate in each file (`if __name__ == '__main__'` block), but straightforward.

### Decision 4: Phased Migration with Side-by-Side Validation

**Date**: 2026-02-21
**Decision**: Keep bash `.sh` files alongside Python `.py` files until Python versions are confirmed equivalent. Remove bash files only in the final milestone.
**Rationale**: Prevents regressions during migration. Each milestone can be validated by running both versions and comparing results.
**Impact**: Temporary file duplication during migration. Cleanup happens in Milestone 4.

## Content Location Map

| Component | File | Change Type |
|-----------|------|-------------|
| Shared test framework | `.claude/skills/verify/tests/test_harness.py` | New |
| Test runner | `.claude/skills/verify/tests/run_tests.py` | New |
| Commit message tests | `.claude/skills/verify/tests/test_check_commit_message.py` | New (replaces .sh) |
| Branch protection tests | `.claude/skills/verify/tests/test_check_branch_protection.py` | New (replaces .sh) |
| CodeRabbit tests | `.claude/skills/verify/tests/test_check_coderabbit_required.py` | New (replaces .sh) |
| Test tiers hook tests | `.claude/skills/verify/tests/test_check_test_tiers.py` | New (replaces .sh) |
| Project detection tests | `.claude/skills/verify/tests/test_detect_project.py` | New (replaces .sh) |
| Test tier detection tests | `.claude/skills/verify/tests/test_detect_test_tiers.py` | New (replaces .sh) |
| Lint tests | `.claude/skills/verify/tests/test_lint_changed.py` | New (replaces .sh) |
| Security tests | `.claude/skills/verify/tests/test_security_check.py` | New (replaces .sh) |
| Bash test files (8) | `.claude/skills/verify/tests/test-*.sh` | Delete in Milestone 4 |

## Implementation Milestones

### Milestone 1: Shared Framework + 3 Highest-Impact Tests
- [x] Create `test_harness.py` with JSON builders, hook/script runner, assertions, reporter
- [x] Create `run_tests.py` test discovery and combined runner
- [x] Port `test-check-commit-message.sh` to `test_check_commit_message.py`
- [x] Port `test-detect-project.sh` to `test_detect_project.py`
- [x] Port `test-detect-test-tiers.sh` to `test_detect_test_tiers.py`
- [x] Validate: Python tests produce identical pass/fail results as bash equivalents

### Milestone 2: Remaining PreToolUse Hook Tests
- [ ] Port `test-check-branch-protection.sh` to `test_check_branch_protection.py`
- [ ] Port `test-check-coderabbit-required.sh` to `test_check_coderabbit_required.py`
- [ ] Port `test-check-test-tiers.sh` to `test_check_test_tiers.py`
- [ ] Validate: all 6 Python test files pass, matching bash results

### Milestone 3: Filesystem-Heavy Tests
- [ ] Port `test-lint-changed.sh` to `test_lint_changed.py`
- [ ] Port `test-security-check.sh` to `test_security_check.py`
- [ ] Validate: all 8 Python test files pass, matching bash results

### Milestone 4: Test Discovery and Hook Integration
- [ ] Add test discovery to `detect-project.sh` for non-standard projects:
  - Check for `run_tests.py` (this repo's Python test runner)
  - Check for executable `test-*.sh` files in common locations
  - Support a `.claude/verify.json` override file where any project can declare its test command explicitly
- [ ] Wire the Python test runner as the detected test command for `claude-config`
- [ ] Verify the PR hook (`pre-pr-hook.sh`) now discovers and runs tests for this repo

### Milestone 5: Cleanup
- [ ] Remove all 8 bash test files (`test-*.sh`)
- [ ] Update any references to `.sh` test files in settings or documentation
- [ ] Measure and document before/after performance (target: 50%+ improvement)

## Dependencies

None — all changes are within the existing verify test infrastructure.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Python version incompatibility (type hints syntax) | Low | Medium | Use only Python 3.8+ syntax (no `tuple[str, int]` union syntax); macOS ships 3.9+ |
| Subtle behavioral differences between bash and Python test execution | Medium | Low | Side-by-side validation in each milestone; keep bash files until confirmed |
| Hook scripts depend on specific stdin encoding | Low | Low | `subprocess.run(text=True)` handles UTF-8 correctly |

## Out of Scope

- Rewriting the hook scripts themselves (they remain bash)
- Adding pytest or other external Python dependencies
- Changing the hook stdin/stdout JSON contract
- Parallelizing test execution (sequential is fine at this scale)
