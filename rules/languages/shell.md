---
paths: ["**/*.sh"]
---

# Shell Script Rules

- Start scripts with `#!/usr/bin/env bash` for portability.
- Use `set -uo pipefail` at the top of scripts. Add `set -e` only when early exit on any error is desired.
- **With `set -u`, expanding a possibly-empty array needs a guard, or the script aborts on macOS.** `/bin/bash` is 3.2, which treats `"${arr[@]}"` on an empty array as an unbound variable and exits 1. Bash 5 from Homebrew does not, so a script can pass when run as `bash script.sh` and fail as `/bin/bash script.sh` or from a git hook. Write `${arr[@]+"${arr[@]}"}` whenever the array can be empty — including arrays that are non-empty today but might be emptied later, which is how this bug usually arrives.

  ```bash
  # Aborts under /bin/bash when EXEMPT is empty
  for item in "${EXEMPT[@]}"; do ...; done

  # Safe on both
  for item in ${EXEMPT[@]+"${EXEMPT[@]}"}; do ...; done
  ```

  Test with `/bin/bash` explicitly, not just `bash`, before trusting a script that a hook will run.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `[[ ]]` over `[ ]` for conditionals (bash-specific but safer).
- Use `$(command)` over backticks for command substitution.
- Prefer `local` for variables inside functions to avoid polluting the global scope.
- Use `readonly` for constants.
