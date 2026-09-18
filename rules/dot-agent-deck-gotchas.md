---
paths: ["**/.dot-agent-deck.toml", "**/dot-agent-deck*"]
---

# dot-agent-deck (vfarcic) Gotchas

- **Install is two separate commands**, easy to misread as one: `brew tap vfarcic/tap && brew install dot-agent-deck`, then separately `dot-agent-deck hooks install dot-agent-deck`.
- **Launch is a single bare command**: `dot-agent-deck` — no `start` subcommand, no separate daemon step. The first invocation auto-spawns the daemon and connects to it.
- **Intel Macs**: the Nix flake path is unsupported (`nixpkgs` dropped `x86_64-darwin`) — only release binaries and the Homebrew tap work. On Intel, brew isn't optional convenience, it's the only supported install path besides raw binaries.
- **devbox is not a dot-agent-deck dependency.** It only shows up in the tool's own docs as (a) an example wrapper for scheduled/dispatched agent launches, and (b) the recommended toolchain for *contributors to dot-agent-deck itself*. If a project's role scripts are wrapped in `devbox run <script>`, that's the project's own choice, not something the tool requires.
- **`agent = "claude"` (or the appropriate value) is required on every role invoked through a launcher** (e.g. `devbox run agent-coder`). The deck identifies an agent by reading the first word of a pane's command; a launcher hides that. Without the explicit `agent` key, the role gets no status tracking at all — no error, just silent loss of dashboard visibility.
- **`worker_response_timeout_minutes` must be a top-level key positioned above every `[[modes]]`/`[[orchestrations]]` table header.** TOML assigns any key written after a table header to that table — a misplaced timeout is silently absorbed into the last table, `dot-agent-deck validate` still reports the config valid, and the daemon quietly keeps the 120-minute default with no error anywhere.
- **Versioning is compatibility-first while in 0.x**: a protocol/compatibility-breaking change bumps the minor version, not major. Check CHANGELOG.md before upgrading minor versions.
- No native Windows support (WSL only); not relevant on macOS/Linux.
- Zero-config first launch: docs describe on-demand config generation (`Ctrl+d` then `g` in the dashboard, or `dot-agent-deck init`) but don't explicitly document what the empty-state screen looks like before generation — verify live rather than assuming a hard error or a specific empty-state UI.
