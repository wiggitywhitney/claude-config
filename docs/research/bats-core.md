# Research: bats-core v1.12/v1.13 Changes and run Behavior

**Project:** claude-config
**Last Updated:** 2026-04-11

## Update Log
| Date | Summary |
|------|---------|
| 2026-04-11 | Initial research — v1.12/v1.13 changes, run + function visibility, stdin/pipe behavior, macOS issues |

## Findings

### Summary

`run my_helper` where `my_helper` is a function defined in the .bats file **works correctly** — functions are visible because `run` uses command substitution `$()` (a subshell of the current process), not `bash -c` (a new process). The `export -f` pattern is only needed when calling functions inside `run bash -c "..."`. v1.12 added `bats::on_failure`; v1.13 fixed a silent output-crosstalk bug in `run`, fixed timeouts under `run`, and added `--abort`/`--negative-filter`.

---

### Surprises and Gotchas

**`run` uses `$()` — functions ARE visible without `export -f`.**
`run` executes via command substitution (`output="$( "$@" )"`), which is a subshell of the current bash process, not a new bash invocation. The subshell inherits all function definitions from the parent shell. So `run my_helper` works when `my_helper` is defined in the .bats file or in a sourced helper.

**`export -f` is only needed for `run bash -c "..."`.**
The pattern `export -f my_func; run bash -c "my_func"` is required specifically when you spawn a new bash process via `bash -c`. That process cannot see parent-shell functions unless they're exported. This is distinct from `run my_func` directly.

**v1.13 fixed a silent crosstalk bug in `run`.**
Before v1.13.0, if `run` was called multiple times and an earlier invocation set `$output`/`$stderr`/`$lines`/`$stderr_lines`, those values could "leak" into a later `run` call if the later call produced no output. Fixed in PR #1105: "unset `output`, `stderr`, `lines`, `stderr_lines` at the start of `run` to avoid crosstalk between successive invocations."
Source: [v1.13.0 CHANGELOG](https://raw.githubusercontent.com/bats-core/bats-core/master/docs/CHANGELOG.md)

**`BATS_TEST_TIMEOUT` with `run` was broken until v1.13.**
Processes started with `run` were not killed by the test timeout. The timeout killed the bats process but left the child process (e.g., `tail -f`) orphaned, reparented to launchd (PID 1), holding open file descriptors and hanging the entire suite. Fixed in v1.13.0 via PR #1160.
Source: [Issue #1020](https://github.com/bats-core/bats-core/issues/1020)

**Mocked functions can bleed into bats internals.**
Functions defined at top level of a .bats file are visible to bats's own cleanup/teardown code, not just your tests. Mocking `rm` or other system commands can break bats's exit traps. The maintainer recommendation: "minimize the reach of the mock as much as possible: if possible constrain your mock to a subshell, else don't define it in free code, but in `setup` or the test function itself, [and] `unset -f` the mock in teardown." This is Wontfix by design.
Source: [Issue #230](https://github.com/bats-core/bats-core/issues/230)

**`bats_pipe` was introduced in v1.10.0, not a recent addition.**
Use `run bats_pipe command0 \| command1` (escaped `\|`, not `|`) for pipelines that need their stdout captured by `run`. Without `bats_pipe`, `run echo foo | grep bar` parses as `(run echo foo) | grep bar` — the pipe is outside `run`.

---

### v1.12.0 (2025-05-18)

**Source says:** "`bats::on_failure` hook that gets called when a test or `setup*` function fails" ([CHANGELOG](https://raw.githubusercontent.com/bats-core/bats-core/master/docs/CHANGELOG.md))
**Interpretation:** Useful for capturing debug state (env dump, log tail) on failure without wrapping every test.

Other fixes:
- `noclobber` shell option no longer breaks `bats-gather-tests`
- Fixed exit code 0 when `bats:focus` filters out all tests
- Solaris compatibility improvements

No breaking changes documented.

---

### v1.13.0 (2025-11-07)

**New flags:**
- `--abort` — stop test suite on first failure (fail-fast)
- `--negative-filter` — exclude tests matching the pattern

**Fixed:**
- **`run` output crosstalk** — `$output`, `$stderr`, `$lines`, `$stderr_lines` are now unset at the start of each `run` call (PR #1105). This was a silent bug.
- **`BATS_TEST_TIMEOUT` under `run`** — child processes under `run` are now properly killed (PR #1160)
- **`bats_test_function`** — `--tags` no longer required to be sorted (PR #1158)
- JUnit formatter: ANSI codes (color, cursor) fully stripped from XML; retried tests no longer appear multiple times; crash on `setup_suite` failure fixed

No breaking changes documented.

---

### `run` and Shell Functions — How It Works

The bats wiki documents that each test executes by re-evaluating the entire .bats file: "each individual run again evaluates the entire test file, then invokes the setup function, if defined, then invokes the specified test function."

The `run` function then executes via:
```bash
output="$( "${pre_command[@]}" "$@" )"
```

Since `$()` creates a subshell of the current process (not a new bash invocation), all functions in scope at the time `run` is called are available within the subshell. `run my_helper` works. The `export -f` pattern is only needed for the specific case of `run bash -c "my_helper"`.

This behavior has not changed across versions — it is consistent through v1.10, v1.11, v1.12, and v1.13.

---

### Stdin and Pipe Behavior

**Pipes with `run` are broken by bash's parser** — always have been:
```bash
run echo "test" | grep "test"   # WRONG: pipe is outside run
run bash -c 'echo "test" | grep "test"'   # Correct: wrapped in subshell
# Or since v1.10.0:
run bats_pipe echo "test" \| grep "test"  # bats_pipe handles it
```

**`run bash -c "..." < file` works as expected.** Stdin redirection in `run bash -c "cmd < file"` works normally — the file is opened and read by the `bash -c` subprocess. There are no known bats-specific issues with `< file` redirection inside `bash -c`.

**bats itself cannot read test definitions from stdin** — the runner requires a file argument, not piped input. This is a different limitation from stdin within tests.

---

### macOS-Specific Issues

No macOS-specific bugs were introduced in v1.12.0 or v1.13.0. The existing issues (GNU date shadowing macOS date, BSD grep rejecting patterns starting with `-`) are environmental, not bats version-specific. The timeout fix in v1.13 (PR #1160) was partially motivated by macOS behavior (launchd reparenting orphaned processes) but applies cross-platform.

**Confidence:** 🟡 medium — no macOS-only issues surfaced in release notes or open issues, but macOS-specific behavior isn't always called out explicitly.

---

### Version History Summary (v1.10–v1.13)

| Version | Date | Notable |
|---------|------|---------|
| v1.10.0 | 2022-07-15 | `bats_pipe` introduced; `run` option overwriting `i` fixed |
| v1.11.0 | 2023-03-24 | `bats_test_function` (dynamic test registration); IFS isolation fix; Bash ≥ 3.2 required |
| v1.12.0 | 2025-05-18 | `bats::on_failure` hook; `noclobber` fix |
| v1.13.0 | 2025-11-07 | `--abort` flag; `--negative-filter`; `run` output crosstalk fix; timeout fix |

## Sources

- [bats-core CHANGELOG (raw)](https://raw.githubusercontent.com/bats-core/bats-core/master/docs/CHANGELOG.md) — authoritative version-by-version changelog
- [v1.13.0 Release](https://github.com/bats-core/bats-core/releases/tag/v1.13.0) — release page with PR links
- [v1.12.0 Release](https://github.com/bats-core/bats-core/releases/tag/v1.12.0) — release page
- [writing-tests.md (GitHub source)](https://github.com/bats-core/bats-core/blob/master/docs/source/writing-tests.md) — run command documentation
- [Bats Evaluation Process wiki](https://github.com/bats-core/bats-core/wiki/Bats-Evaluation-Process) — how test files are evaluated n+1 times
- [test_functions.bash source](https://github.com/bats-core/bats-core/blob/master/lib/bats-core/test_functions.bash) — run() implementation uses `$()`
- [Issue #230: Failing run if functions are mocked](https://github.com/bats-core/bats-core/issues/230) — function mock bleed-through; Wontfix
- [Issue #1020: BATS_TEST_TIMEOUT not honored by run](https://github.com/bats-core/bats-core/issues/1020) — fixed in v1.13.0
- [BW01 warning docs](https://github.com/bats-core/bats-core/blob/master/docs/source/warnings/BW01.rst) — exit code 127 "command not found" from run
- [bashsupport.com bats_pipe docs](https://www.bashsupport.com/bats-core/functions/bats_pipe/) — bats_pipe usage
