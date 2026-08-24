---
paths: ["**/*.sh"]
---

# Shell Script Rules

- Start scripts with `#!/usr/bin/env bash` for portability.
- Use `set -uo pipefail` at the top of scripts. Add `set -e` only when early exit on any error is desired.
- **Never name an `awk -v` variable `log`, `index`, `length`, `split`, `sub`, `gsub`, `int`, `sin`, `cos`, or `exp`.** These are awk built-in functions, and assigning one produces no error — the reference silently evaluates to something else. Passing a file path in as `-v log="$FILE"` and printing it with `%s` yields `-inf`, because `log` resolves to the logarithm function rather than the string. Verified 2026-08-04.

  ```bash
  # Wrong: prints -inf, no error, no warning
  awk -v log="$LOGFILE" 'END { printf "measured %s\n", log }'

  # Right: any name that is not a built-in
  awk -v logpath="$LOGFILE" 'END { printf "measured %s\n", logpath }'
  ```

- **A `[a-z]*` character class in a `grep` pattern silently excludes camelCase values, which makes a wrong count look clean.** Counting JSON field values with `grep -o '"key":"[a-z]*"'` drops every value containing a capital — and because the surviving matches are internally consistent, the resulting total looks trustworthy. Verified 2026-08-04, where it dropped the majority case and produced a confident wrong conclusion. Use `[A-Za-z]` when the value's case is not guaranteed, and prefer `jq` over `grep` for structured data, where the field is addressed by name rather than by pattern.

- **`pipefail` plus `grep -q` at the end of a pipe is a silent-wrong-answer trap.** `grep -q` exits the moment it matches. If the upstream command is still writing, it takes SIGPIPE and exits 141, and `pipefail` promotes that to the pipeline's status — so a pipeline that **did** find its match reports failure. Nothing errors; the caller just gets the wrong boolean.

  It is size-dependent, which is what makes it dangerous: below the 64 KB pipe buffer the upstream finishes in one write and the bug never appears, so it ships green and surfaces later when an input file grows.

  ```bash
  # Wrong under `set -o pipefail`: returns non-zero on a large file whose match is early
  strip_code "$file" | grep -qE "$pattern"

  # Right: grep reads all of stdin, so the upstream never sees a closed pipe
  strip_code "$file" | grep -E "$pattern" >/dev/null
  ```

  Reserve `-q` for when grep reads a file directly (`grep -q pat file`) — no pipe, no trap. Confirmed by reproduction in `tests/measure-context-load.bats`, 2026-08-04.
- **`\s` is a GNU extension. BSD grep — which is `/usr/bin/grep` on macOS — treats it as a literal `s`.** A pattern like `"foo\.md(\s|$)"` silently stops matching `foo.md` followed by a space, and starts matching `foo.mds`. It fails quietly rather than erroring, and it works on Linux CI while failing on the developer's laptop. Use the POSIX class `[[:space:]]` instead. The same applies to `\d`, `\w`, and `\b`.
- **With `set -u`, expanding a possibly-empty array needs a guard, or the script aborts on macOS.** `/bin/bash` is 3.2, which treats `"${arr[@]}"` on an empty array as an unbound variable and exits 1. Bash 5 from Homebrew does not, so a script can pass when run as `bash script.sh` and fail as `/bin/bash script.sh` or from a git hook. Write `${arr[@]+"${arr[@]}"}` whenever the array can be empty — including arrays that are non-empty today but might be emptied later, which is how this bug usually arrives.

  ```bash
  # Aborts under /bin/bash when EXEMPT is empty
  for item in "${EXEMPT[@]}"; do ...; done

  # Safe on both
  for item in ${EXEMPT[@]+"${EXEMPT[@]}"}; do ...; done
  ```

  **The outer level of `${arr[@]+"${arr[@]}"}` must stay unquoted.** It looks like an unquoted expansion that a linter or a later reader should "fix" to `"${arr[@]+"${arr[@]}"}"`, and doing that breaks it — the whole point is that the `+` alternate substitutes the *already-quoted* inner expansion, so wrapping the outer level collapses the array into one word. Leave it as written; the quoting is inside, where it belongs.

  Test with `/bin/bash` explicitly, not just `bash`, before trusting a script that a hook will run.
- **An alternation inside a `sed` substitution collides with `|` as the delimiter.** `sed -E 's|^@(a/|b/)?x||'` fails with `RE error: parentheses not balanced`, because the first `|` of the alternation closes the pattern. It is easy to introduce when converting a working `grep -E` pattern into a `sed` expression, since the grep version has no delimiter to collide with. Pick a delimiter that cannot appear in the pattern — `#` or `,` — rather than escaping: `sed -E 's#^@(a/|b/)?x##'`.

  The failure is loud on stderr but does not stop the pipeline, so under `set -uo pipefail` without `set -e` the substitution silently produces no output and downstream logic sees an empty result. In `check-rule-frontmatter.sh` on 2026-08-04 that turned every `@`-referenced rule into an apparent "no loading mechanism" failure — eleven false failures from one delimiter. Run the script once after editing any `sed` expression; `bash -n` passes it, because the error is in the regex at runtime rather than in the shell syntax.
- **`${#var}` counts characters, not bytes, so it silently undercounts any non-ASCII value.** In a UTF-8 locale `é` is one character and two bytes, so a script that reports `${#desc}` under a column labelled "bytes" is wrong for every accented or non-Latin string — and right for ASCII, which is why it ships. Use `LC_ALL=C printf '%s' "$var" | wc -c | tr -d '[:space:]'`; the `LC_ALL=C` is what makes it a byte count, and the `tr` strips the leading padding `wc` adds on macOS.

  ```bash
  # Wrong when the value contains any non-ASCII character
  n="${#desc}"

  # Right: bytes, on both macOS and Linux
  n="$(LC_ALL=C printf '%s' "$desc" | wc -c | tr -d '[:space:]')"
  ```

  **Two byte-counting errors in one expression can cancel out and hide each other.** In `measure-context-load.sh` on 2026-08-18, `cut -d: -f2-` left the space after `description:` in the value *and* `${#desc}` counted characters — so for `description: café` the extra space compensated for `é`'s second byte and the total was accidentally correct. Neither error was visible from any test until they were separated. When a measurement is wrong, check whether it is wrong twice: strip the YAML separator with `"${v#"${v%%[![:space:]]*}"}"` before counting.
- **A trailing slash in a glob defeats `[ -L ]`, because the shell resolves the link before the test sees it.** `for d in "$DIR"/*/` looks equivalent to `for d in "$DIR"/*` with a directory filter, and it is not: the trailing slash makes each symlinked directory expand to a resolved path, so `[ -L "$d" ]` reports false for every one of them and a symlink guard silently passes everything through.

  ```bash
  # Wrong: symlinked directories are not detected, so the guard never fires
  for d in "$DIR"/*/; do
      [ -L "$d" ] && continue
  done

  # Right: no trailing slash, test the entry, then filter for directories
  for d in "$DIR"/*; do
      [ -L "$d" ] && continue
      [ -d "$d" ] || continue
  done
  ```

  **Two mechanisms usually protect this and only one of them is the guard, which matters when you test it.** `find "$symlinked_dir" -type f` also yields nothing, because `find` does not descend into a symlinked directory without `-L`. So deleting the `[ -L ]` guard can leave the test green while adding a trailing slash turns it red — the glob is doing the work. Confirmed by mutation in `claude-personal/tests/sync-push.bats`, 2026-08-22. Name the real mechanism in the comment; crediting the guard sends the next reader to defend the wrong line.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `[[ ]]` over `[ ]` for conditionals (bash-specific but safer).
- Use `$(command)` over backticks for command substitution.
- Prefer `local` for variables inside functions to avoid polluting the global scope.
- Use `readonly` for constants.
