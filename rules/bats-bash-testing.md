---
paths: ["**/*.bats", "**/tests/**/*.sh"]
---

# Bats Bash Testing

Use **bats-core** (installed via `brew install bats-core`) for all bash script test suites. This is the actively maintained community fork — the original `sstephenson/bats` is archived and dead.

## Gotchas

**`assert_output` and `assert_success` are NOT built in.** They come from the optional `bats-assert` package. Use plain bash assertions instead unless you explicitly install the library:
```bash
[ "$status" -eq 0 ]
[[ "$output" == *"expected phrase"* ]]
```

**`run` executes in a subshell.** Shell variable changes inside `run` don't persist. Exported env vars work fine.

**Flags on `run` need an explicit version declaration or the suite prints a warning on every run.** `run --separate-stderr`, `run --keep-empty-lines`, and the `run -N` exit-code form all require bats 1.5.0+, and bats emits `BW02: Using flags on run requires at least BATS_VERSION=1.5.0` unless the file declares it. The warning does not fail the suite, so it survives as permanent noise in output that is supposed to be pristine. Declare it near the top of the file, above the first test:
```bash
bats_require_minimum_version 1.5.0
```

**A repo-level git hook test can fail for reasons that have nothing to do with the hook.** `core.hooksPath`, when set in global or system git config, overrides `.git/hooks` for **every** repository — including the temporary fixture repos a test creates. On a machine where it points somewhere root-owned, an installer under test writes at the managed path and fails with `Permission denied`, and every downstream assertion about `.git/hooks/<name>` then fails as a consequence. The symptom looks like a broken installer; the cause is machine configuration. Check it before debugging the script:
```bash
git config --get core.hooksPath
```
A test suite that asserts against `.git/hooks` cannot pass on such a machine as written. Either set `core.hooksPath=` (empty) for the fixture repo inside `setup()`, or assert against the path git will actually use.

**`run my_function` works when `my_function` is defined in the .bats file.** `run` uses command substitution `$()` internally — a subshell of the current process, not a new `bash -c` invocation. Functions defined in the test file (or sourced via `load`) are visible without `export -f`.

**`export -f` is only needed inside `run bash -c "..."`** — because `bash -c` spawns a new process that can't see parent-shell functions. Pattern:
```bash
my_helper() { jq -e '.limit == 42'; }
export -f my_helper
run bash -c "command args | my_helper"
```

**Mocked functions bleed into bats internals.** Functions defined at top level of a .bats file are also visible to bats's own cleanup code. Mocking `rm`, `exit`, or other system commands can break bats's exit traps. Fix: define mocks inside `setup()` or the `@test` body, and `unset -f` the mock in `teardown()`. The bats maintainers have marked this Wontfix.

**Pipes don't work with `run`:**
```bash
# WRONG — pipe is outside run:
run echo "test" | grep "test"

# Correct — wrap in subshell:
run bash -c 'echo "test" | grep "test"'

# Also correct — use bats_pipe (added in v1.10.0):
run bats_pipe echo "test" \| grep "test"   # note: \| not |
```

**`run` output crosstalk (fixed in v1.13.0).** Before v1.13, `$output`/`$stderr`/`$lines`/`$stderr_lines` from an earlier `run` call could leak into a later `run` if the later call produced no output. Upgrade to v1.13.0+ to avoid silent false passes.

**`BATS_TEST_TIMEOUT` with `run` was broken until v1.13.0.** Processes started via `run` were not killed when the timeout fired — they'd be orphaned and hang the suite. Fixed in v1.13.0.

**GNU date shadows macOS date.** On this machine, `/opt/homebrew/opt/coreutils/libexec/gnubin/date` is first in PATH. The macOS system date is at `/bin/date` (not `/usr/bin/date`). Scripts and tests using macOS `date -v-1d` syntax must call `/bin/date` explicitly.

**A passing test is not evidence the test can fail.** A suite retrofitted onto working code can assert things that hold for reasons unrelated to the behavior named in the test. Verify by reintroducing the defect the test claims to catch and confirming it goes red. Two examples found this way in `tests/measure-context-load.bats` on 2026-08-04:

- A test proving a backticked `` `@path` `` is a mention rather than an import put the closing backtick immediately after the path — which the matcher rejects anyway, since a backtick is not whitespace. It passed whether or not the stripping code ran.
- A test proving `paths:` below the frontmatter block does not count wrote it mid-sentence in prose, where no `^paths:` pattern matches it regardless.

**When mutating, remove the behavior — do not relocate it.** Pointing a guard at a different nonexistent path makes it fire unconditionally, so the test still passes and the mutation reports a false failure against a sound test. Delete the block instead.

**BSD grep rejects patterns starting with `-` as unknown options.** macOS ships BSD grep (`/usr/bin/grep`). If the grep pattern could start with a dash (e.g., a task line like `- [ ] ...`), always add `--` after the flags to end option parsing: `grep -qF -- "- [ ] pattern" file`.

**`setup_file()` runs once per file, not per test.** Use `setup()` / `teardown()` for per-test temp directory isolation.

## File placement

- Put test files in a `tests/` directory at the repo root
- Name files `<script-name>.bats`
- Reference the script under test with a path relative to `$BATS_TEST_DIRNAME`

## Minimum working pattern

```bash
#!/usr/bin/env bats
# ABOUTME: Tests for <script-name>.sh

SCRIPT="$BATS_TEST_DIRNAME/../.claude/scripts/<script-name>.sh"

setup() {
    TMPDIR=$(mktemp -d)
    export RELEVANT_ENV_VAR="$TMPDIR/something"
    chmod +x "$SCRIPT"
}

teardown() {
    rm -rf "$TMPDIR"
}

@test "describes expected behavior" {
    run "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected text"* ]]
}
```

## Running

```bash
bats tests/my-script.bats                     # single file
bats tests/                                   # all .bats files
bats tests/my-script.bats --filter "fragment" # matching tests only
bats tests/my-script.bats --abort             # stop on first failure (v1.13.0+)
bats tests/my-script.bats --negative-filter "fragment"  # exclude matching tests (v1.13.0+)
```
