---
paths: ["**/*.sh"]
---

# Shell Script Rules

- Start scripts with `#!/usr/bin/env bash` for portability.
- Use `set -uo pipefail` at the top of scripts. Add `set -e` only when early exit on any error is desired.
- **`pipefail` plus `grep -q` at the end of a pipe is a silent-wrong-answer trap.** `grep -q` exits the moment it matches. If the upstream command is still writing, it takes SIGPIPE and exits 141, and `pipefail` promotes that to the pipeline's status — so a pipeline that **did** find its match reports failure. Nothing errors; the caller just gets the wrong boolean.

  It is size-dependent, which is what makes it dangerous: below the 64 KB pipe buffer the upstream finishes in one write and the bug never appears, so it ships green and surfaces later when an input file grows.

  ```bash
  # Wrong under `set -o pipefail`: returns non-zero on a large file whose match is early
  strip_code "$file" | grep -qE "$pattern"

  # Right: grep reads all of stdin, so the upstream never sees a closed pipe
  strip_code "$file" | grep -E "$pattern" >/dev/null
  ```

  Reserve `-q` for when grep reads a file directly (`grep -q pat file`) — no pipe, no trap. Confirmed by reproduction in `tests/measure-context-load.bats`, 2026-08-04.
- **`\s` is a GNU extension. BSD grep — which is `/usr/bin/grep` on macOS — treats it as a literal `s`.** A pattern like `"foo\.md(\s|$)"` silently stops matching `foo.md ` and starts matching `foo.mds`. It fails quietly rather than erroring, and it works on Linux CI while failing on the developer's laptop. Use the POSIX class `[[:space:]]` instead. The same applies to `\d`, `\w`, and `\b`.
- **With `set -u`, expanding a possibly-empty array needs a guard, or the script aborts on macOS.** `/bin/bash` is 3.2, which treats `"${arr[@]}"` on an empty array as an unbound variable and exits 1. Bash 5 from Homebrew does not, so a script can pass when run as `bash script.sh` and fail as `/bin/bash script.sh` or from a git hook. Write `${arr[@]+"${arr[@]}"}` whenever the array can be empty — including arrays that are non-empty today but might be emptied later, which is how this bug usually arrives.

  ```bash
  # Aborts under /bin/bash when EXEMPT is empty
  for item in "${EXEMPT[@]}"; do ...; done

  # Safe on both
  for item in ${EXEMPT[@]+"${EXEMPT[@]}"}; do ...; done
  ```

  **The outer level of `${arr[@]+"${arr[@]}"}` must stay unquoted.** It looks like an unquoted expansion that a linter or a later reader should "fix" to `"${arr[@]+"${arr[@]}"}"`, and doing that breaks it — the whole point is that the `+` alternate substitutes the *already-quoted* inner expansion, so wrapping the outer level collapses the array into one word. Leave it as written; the quoting is inside, where it belongs.

  Test with `/bin/bash` explicitly, not just `bash`, before trusting a script that a hook will run.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `[[ ]]` over `[ ]` for conditionals (bash-specific but safer).
- Use `$(command)` over backticks for command substitution.
- Prefer `local` for variables inside functions to avoid polluting the global scope.
- Use `readonly` for constants.
