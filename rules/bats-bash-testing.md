# Bats Bash Testing

Use **bats-core** (installed via `brew install bats-core`) for all bash script test suites. This is the actively maintained community fork — the original `sstephenson/bats` is archived and dead.

## Gotchas

**`assert_output` and `assert_success` are NOT built in.** They come from the optional `bats-assert` package. Use plain bash assertions instead unless you explicitly install the library:
```bash
[ "$status" -eq 0 ]
[[ "$output" == *"expected phrase"* ]]
```

**`run` executes in a subshell.** Shell variable changes inside `run` don't persist. Exported env vars work fine.

**Pipes don't work with `run`:**
```bash
# WRONG:
run echo "test" | grep "test"

# Correct:
run bash -c 'echo "test" | grep "test"'
```

**GNU date shadows macOS date.** On this machine, `/opt/homebrew/opt/coreutils/libexec/gnubin/date` is first in PATH. The macOS system date is at `/bin/date` (not `/usr/bin/date`). Scripts and tests using macOS `date -v-1d` syntax must call `/bin/date` explicitly.

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
```
