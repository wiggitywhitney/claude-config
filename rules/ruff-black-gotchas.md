---
paths: ["**/languages/python/validation.ts", "**/*ruff*", "**/*black*"]
---

# Ruff / Black CLI Gotchas

Verified against ruff 0.15.2, black 25.1.0, 2026-09-18.

- `ruff format -` and `black -` both read stdin and write formatted code to stdout with no other flags required. `ruff format -`'s stdin support is real but undocumented in `ruff format --help` (confirmed by a Ruff maintainer, still true as of 0.15.2) — don't conclude from `--help` alone that it doesn't exist.
- **Black gotcha:** on a parse failure, Black exits **123** but still writes the original, unformatted source to stdout unchanged. Checking "is stdout non-empty" to detect success is wrong — always branch on the exit code (or let `execFileSync` throw on non-zero exit and never read stdout on the error path).
- Ruff on a parse failure exits **2** with empty stdout and `error: Failed to parse at LINE:COL: ...` on stderr — the opposite of Black's behavior (empty stdout on failure, not the original source).
- `ruff check --fix` (the linter, not `ruff format`) does not support the same stdin→stdout round-trip — with `--fix` on stdin it only prints a summary count, not the fixed code. Not relevant to `ruff format`, but easy to confuse the two subcommands.
- Missing binary (`ruff`/`black` not installed): Node's `execFileSync` throws with `error.code === 'ENOENT'`. No separate `--version` probe is needed before attempting the real format call.
- `python3 -c "import sys; f=sys.argv[1]; compile(open(f).read(), f, 'exec')" FILE` on a syntax error writes the full traceback to stderr only (stdout empty), exit code 1. Pass the path as an argument rather than writing `f` bare inside `-c`, which raises `NameError` before it ever reaches `compile`. The traceback has two `File` lines — the first is always `File "<string>", line 1, in <module>` (an artifact of the `-c` wrapper, always line 1), and the real failing line number is on the **second** `File` line. A regex matching the first `File ".*", line (\d+)` occurrence always wrongly reports line 1.
