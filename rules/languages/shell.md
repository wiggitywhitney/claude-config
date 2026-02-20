---
paths: ["**/*.sh"]
---

# Shell Script Rules

- Start scripts with `#!/usr/bin/env bash` for portability.
- Use `set -uo pipefail` at the top of scripts. Add `set -e` only when early exit on any error is desired.
- Quote all variable expansions: `"$var"` not `$var`.
- Use `[[ ]]` over `[ ]` for conditionals (bash-specific but safer).
- Use `$(command)` over backticks for command substitution.
- Prefer `local` for variables inside functions to avoid polluting the global scope.
- Use `readonly` for constants.
