---
paths: ["**/devbox.json", "**/devbox.lock"]
---

# devbox (Jetify) Gotchas

- **No Homebrew install path exists** — not a renamed tap, no tap at all. `brew install devbox` and `jetpack-io/devbox/devbox`/`jetify-com/devbox/devbox` do not work. The only local-machine install method is: `curl -fsSL https://get.jetify.com/devbox | bash`. An open GitHub feature request asking for brew support (#76, opened 2022) is still unresolved. For CI specifically, an official `jetify-com/devbox-install-action` GitHub Action exists (documented on a separate CI-specific page, not the general install page) — don't assume the curl script is the only option in a workflow file.
- **Never install Nix separately.** Devbox auto-installs Nix on first `devbox shell`/`devbox run` if it isn't already present (multi-user mode on macOS, single-user on Linux/WSL2).
- Custom scripts live under `shell.scripts` in `devbox.json`, each value a string or array of command strings:
  ```json
  { "shell": { "scripts": { "my-script": "some-command --flag" } } }
  ```
  Invoke with `devbox run my-script`. Scripts run in an interactive devbox shell that terminates when the script finishes.
- **Don't `source` a helper script from `init_hook` and then run it via `devbox run`** — this throws a "file not found" error in an open bug (#2108, #2607). Use `bash script.sh` instead of `source script.sh`.
- The `devbox.json` `$schema` field/URL is versioned and evolving — don't assume an old tutorial's schema URL is current; check `https://raw.githubusercontent.com/jetify-com/devbox/<version>/.schema/devbox.schema.json` at implementation time.
