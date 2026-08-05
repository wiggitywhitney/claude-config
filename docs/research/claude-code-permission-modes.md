# Research: Claude Code Permission Modes, Sandbox, and Auto Mode

**Project:** claude-config
**Last Updated:** 2026-08-04
**Claude Code version checked against:** 2.1.222 (`claude --version`, run 2026-08-04)
**Produced by:** PRD #109, Milestone A3 half one (the relief pass)

## Update Log

| Date | Summary |
|------|---------|
| 2026-08-04 | Initial research. Documentation pass on permission modes, the sandboxed Bash tool, and auto mode, verified against Whitney's live settings files and the Milestone A3 instrument log. |

---

## How to read the confidence and verification labels

Every claim below carries two labels, because they answer different questions:

- **Confidence** — how well-sourced the claim is. 🟢 primary source, quoted. 🟡 single source or indirect. 🔴 inferred.
- **Verification** — whether it was checked against *this machine*. **Verified-here** means a file was read or a command was run on Whitney's setup today. **Documentation-only** means the docs say it and nothing local was checked.

Milestone B1 re-runs this pass against whatever version ships then. The version pin above is the thing that makes that re-check meaningful.

---

## Summary

Claude Code has a permission mode built for exactly the problem Milestone A3 is measuring — it is called **auto mode**, and the documentation section describing it is titled "Eliminate permission prompts with auto mode." It replaces the approval prompt with a separate classifier model that reviews each action.

**State of play, so the two are not confused.** The measurement window in this document is the **pre-adoption** baseline: those sessions ran in `default` (Manual) and `acceptEdits`, and neither of those changes how a Bash command is approved. **Auto mode was then adopted provisionally on 2026-08-04** and is the current default in `config/settings.json`. So every rate below describes the setup as it was *before* the change this document recommends.

Two findings shape what auto mode would and would not fix here:

1. It would reach the **largest observed trigger classes**, because those classes exist only as a consequence of matching commands against an allowlist by string. Auto mode routes anything the rules do not resolve to the classifier instead of to a prompt.
2. It would **not** reach two of the recorded classes, because those come from Whitney's own `permissions.ask` rules, and explicit ask rules force a prompt in every mode — including auto mode and including `bypassPermissions`.

---

## Surprises and gotchas

These are the findings that change the plan. Everything else is reference.

### The two "over-matching glob" classes are `ask` rules, and no permission mode can fix them

**Verified-here.** 🟢 The decision log records `Bash(git merge*)` catching `git merge-tree`, and `Bash(rm *)` catching `rm -f /tmp/scratch`, and describes them as "explicitly *configured* permission rules whose globs over-match." Reading `~/.claude/settings.json` today confirms the mechanism precisely: both live in the **`ask`** array, not the `allow` array.

That distinction is load-bearing, because ask rules are the one thing that survives every escape hatch.

**Source says:** "Modes set the baseline. Layer permission rules on top to pre-approve or block specific tools. These controls apply in every mode, including `bypassPermissions`: deny rules and explicit ask rules" ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Source says:** "Content-scoped ask rules like the ones below are evaluated before the classifier and always force a permission prompt, even in auto mode, because an explicit ask rule is your stated intent to be prompted for that action." ([Configure auto mode](https://code.claude.com/docs/en/auto-mode-config.md))

**Interpretation:** these two classes are immune to auto mode, to the sandbox, and even to `--dangerously-skip-permissions`. The only remedy is editing the rules themselves — narrowing `Bash(rm *)` and `Bash(git merge*)` so they stop catching harmless operations. That makes them a *separate* remedy track from everything else in the taxonomy, and it is worth saying so plainly in Milestone C1 rather than letting "turn on auto mode" look like a whole answer.

### The recorded sessions ran in two modes, and the mode is not what drives the prompt rate

**Verified-here.** 🟢 Before auto mode was adopted, `~/.claude/settings.json` set no `permissions.defaultMode` key, so sessions started in `default` (Manual) and reached `acceptEdits` mid-session with `Shift+Tab`. Both appear in the log.

**Every figure below comes from one run of `scripts/measure-prompt-rate.sh` over one named window** — `--since 2026-08-04T15:00:00Z --until 2026-08-05T00:40:00Z`, which resolves to observed bounds `15:10:40Z .. 00:39:57Z`. An earlier draft of this table mixed an unbounded run with the PRD's bounded one and so did not reconcile; that is exactly the defect a single named window prevents.

| Mode | `PermissionRequest` | `PreToolUse` | Rate |
|------|--------------------:|-------------:|-----:|
| `acceptEdits` | 18 | 194 | 9.3% |
| `default` (Manual) | 3 | 49 | 6.1% |
| **Total** | **21** | **243** | **8.6%** |

Prompts by inferred trigger class over the same window: heredoc 7, other 6, expansion 4, non-Bash 3, ask-rule 1.

**Interpretation:** the looser of the two modes shows the *higher* prompt rate, on a small sample for Manual (49 calls). Whatever the mode is doing, it is not the variable that explains the observed prompts — which is exactly what the documentation predicts, because `acceptEdits` widens file edits and a short list of filesystem commands and leaves every other Bash command on the prompting path. Both modes gate an inline `python3` heredoc identically.

This is the sharpest available argument that the remedy has to change the *mechanism* rather than loosen the mode: two modes, a 3× difference in strictness for edits, and no meaningful difference in prompt rate.

**A methodology warning worth keeping.** The first version of this finding claimed all sessions ran in Manual mode. It was produced by `grep -o '"permission_mode":"[a-z]*"'`, whose character class silently excludes `acceptEdits` — the majority case. The wrong answer looked clean and internally consistent. Decision 25's rule about measuring with a committed script rather than an ad hoc read exists for this failure mode, and this is a live instance of it: the fix is that `scripts/measure-prompt-rate.sh` has a test asserting mixed-mode input is counted, so the same slip cannot recur silently.

### Nothing in the org's managed settings blocks auto mode

**Verified-here.** 🟢 Read `/Library/Application Support/ClaudeCode/managed-settings.json` in full. It sets `apiKeyHelper`, `model: "sonnet"`, `effortLevel: "medium"`, and a block of OTel and gateway environment variables. It does **not** set `permissions.disableAutoMode`, `permissions.disableBypassPermissionsMode`, `allowManagedPermissionRulesOnly`, or any `sandbox` key.

**Source says:** "on Team and Enterprise, auto mode is available by default. Administrators can turn it off for the organization by setting `permissions.disableAutoMode` to `"disable"` in managed settings." ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Interpretation:** Datadog has not turned auto mode off. This was the most likely blocker in an enterprise-managed environment and it is not present.

### The model requirement is met on both the pinned model and the one Whitney selects

**Verified-here** for the model values; **documentation-only** for the requirement itself. 🟢 Managed settings pin `model: "sonnet"`; Whitney re-selects Opus 5 per session.

**Source says:** "on the Anthropic API and Claude Platform on AWS, Claude Opus 4.6 or later, Sonnet 4.6 or later, or Fable 5 ... Older models, including Sonnet 4.5, Opus 4.5, Haiku, and claude-3 models, are not supported on any provider." ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Interpretation:** Sonnet 5 and Opus 5 both clear the bar. Unlike the model protocol in the PRD, auto mode does not degrade when managed settings win on restart.

### Auto mode fixes the command-shape classes by removing the string-matching step, not by matching better

**Documentation-only.** 🟢 This is the mechanism worth understanding, because it explains why growing the allowlist never worked.

**Source says:** the classifier decision order is "1. Actions matching your allow, ask, or deny rules resolve immediately ... 2. Read-only actions and file edits in your working directory are auto-approved ... 3. Everything else goes to the classifier." ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Interpretation:** in Manual mode, step 3 is "prompt the user." A `python3` heredoc fails to match `Bash(python3:*)` because of how the command is written, falls through, and prompts. In auto mode the same command falls through the same way and reaches a classifier that judges what it *does* rather than how it is spelled. This is why the 227-entry allowlist did not help and auto mode plausibly would: the allowlist competes with the parser, the classifier ignores it.

### Auto mode drops some of Whitney's existing allow rules while it is active

**Documentation-only.** 🟡 A side effect worth stating before adoption, because it makes some currently-instant approvals slower rather than faster.

**Source says:** "On entering auto mode, broad allow rules that grant arbitrary code execution are dropped: Blanket `Bash(*)` or `PowerShell(*)`; Wildcarded interpreters like `Bash(python*)`; Package-manager run commands; `Agent` allow rules. Narrow rules like `Bash(npm test)` carry over. Dropped rules are restored when you leave auto mode." ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Interpretation:** Whitney's `Bash(node *)` is a wildcarded interpreter and `Bash(npm run *)` is a package-manager run command, so both are likely suspended in auto mode and routed to the classifier instead. This costs a round-trip, not a prompt. Whether `Bash(git *)` counts as broad is not stated either way in the documentation — flagging it as unresolved rather than guessing.

### The sandbox is a real alternative on macOS with nothing to install, but it introduces a new prompt class

**Documentation-only.** 🟢

**Source says:** "On macOS, there is nothing to install: sandboxing uses the built-in Seatbelt framework." And on auto-allow mode: "when a command can be sandboxed, Claude Code runs it inside the sandbox and approves it automatically, without asking your permission." ([Configure the sandboxed Bash tool](https://code.claude.com/docs/en/sandboxing.md))

**Source says:** "**Domain restrictions**: no domains are pre-allowed by default. The first time a command needs a new domain, Claude Code prompts for approval."

**Interpretation:** the sandbox would also defeat the command-shape classes, and it does so with an OS boundary rather than a model judgment, which is a stronger guarantee. But it trades one prompt class for another — every new network domain prompts until allowlisted — and macOS has known tool breakage: `gh`, `gcloud`, and `terraform` "may fail TLS verification under Seatbelt," and `docker` "is incompatible with the sandbox." Whitney's workflow uses `gh` constantly. Adopting the sandbox is therefore a larger change with more configuration ahead of it, not a smaller one.

### Auto mode stops being auto after repeated blocks

**Documentation-only.** 🟢 Relevant because Milestone A3's whole subject is unattended running.

**Source says:** "If the classifier blocks an action 3 times in a row or 20 times total, auto mode pauses and Claude Code resumes prompting. Approving the prompted action resumes auto mode. These thresholds are not configurable." And: "In non-interactive mode with the `-p` flag, repeated blocks abort the session since there is no user to prompt." ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Interpretation:** auto mode is not a guarantee of an uninterrupted session, and for the Ralph-loop style `claude -p` architecture that `claude-code-autonomous-capabilities.md` recommends for PRD #84, repeated blocks are fatal rather than merely annoying. That is an argument for configuring `autoMode.environment` before relying on it unattended, and it belongs in Milestone C1's decision.

### The docs never explain the `simple_expansion` class

**Verified-here** (by searching the fetched page). 🟡 The permissions page documents the read-only command set, the `cd`-with-`git` rule, and the `cd`-with-output-redirect rule — three of the classes in the decision log — but contains no reason string resembling `simple_expansion` and no statement that shell expansion defeats allowlist matching.

The closest the documentation comes is a warning that argument-constraining patterns are fragile:

**Source says:** "Bash permission patterns that try to constrain command arguments are fragile. For example, `Bash(curl http://github.com/ *)` intends to restrict curl to GitHub URLs, but won't match variations like ... Variables: `URL=http://github.com && curl $URL`" ([Configure permissions](https://code.claude.com/docs/en/permissions.md))

**Interpretation:** this corroborates the behavior but does not document the trigger class. It confirms Decision 44's finding from the other direction — the class set really is undocumented internals, so Milestone A3's binary extraction is the only complete source and cannot be replaced by a documentation pass.

---

## Findings: the modes

All rows **documentation-only**, quoted from [Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md). 🟢

| Mode | Runs without asking (verbatim) | Notes for this setup |
|------|-------------------------------|----------------------|
| `default` (Manual) | "Reads only" | What every recorded session ran in |
| `acceptEdits` | "Reads, file edits, and common filesystem commands (`mkdir`, `touch`, `mv`, `cp`, etc.)" | Also auto-approves `rm` and `sed` — but Whitney's `Bash(rm *)` ask rule overrides that |
| `plan` | "Reads, plus classifier-approved commands when auto mode is available" | Not a friction remedy |
| `auto` | "Everything, with background safety checks" | The candidate |
| `dontAsk` | "Only pre-approved tools" | Auto-*denies* anything not allowlisted; for CI |
| `bypassPermissions` | "Everything" | "Only use this mode in isolated environments like containers, VMs" |

**How each is set** (🟢 documentation-only): `Shift+Tab` cycles `default` → `acceptEdits` → `plan` mid-session; `--permission-mode <name>` at startup; `permissions.defaultMode` in a settings file for a persistent default.

**One placement gotcha that would silently waste the change** (🟢 documentation-only):

**Source says:** "If you set `defaultMode: "auto"` in settings and the session starts in `default` mode with no error, the setting is likely in `.claude/settings.json` or `.claude/settings.local.json`. Claude Code v2.1.142 and later ignore `auto` from those files so a repository cannot grant itself auto mode. Move it to `~/.claude/settings.json`."

`defaultMode: "auto"` must go in **user settings**. Putting it in the project file fails silently — no error, just Manual mode.

---

## Findings: what auto mode blocks by default

**Documentation-only.** 🟢 The full lists are long and versioned; `claude auto-mode defaults` prints them as JSON, and running `claude auto-mode config` on this machine on 2026-08-04 returned the effective config (~60 KB of prose rules), which confirms the subcommand works here.

The categories most likely to matter for Whitney's daily work:

- **Allowed by default**: local file operations in the working directory; installing declared dependencies; read-only HTTP; "Pushing to any branch of the repository you're working in, including the default branch"; creating a pull request that matches the request.
- **Blocked by default**: force push; `git reset --hard`, `git checkout -- .`, `git restore .`, `git clean -fd`, `git stash drop`, `git stash clear`; `git commit --amend` on a commit not created this session or already pushed; `curl | bash`; production deploys.

**Interpretation:** the blocked list overlaps heavily with what Whitney's own `ask` rules already cover — `git reset --hard`, `git clean*`, `git restore*`, `git checkout -- *`, `git push --force*`. Those stay prompts under an ask rule rather than becoming classifier blocks, which is the safer of the two behaviors and means adopting auto mode does not quietly loosen her existing git guardrails.

One caveat about stating boundaries in conversation rather than in rules (🟢 documentation-only):

**Source says:** "Boundaries are not stored as rules. The classifier re-reads them from the transcript on each check, so a boundary can be lost if context compaction removes the message that stated it. For a hard guarantee, add a deny rule instead."

**Interpretation:** this is the same "documentation loses to habit / context loses to compaction" pattern the PRD has now recorded four times, appearing here as a platform behavior. A spoken boundary is not durable; a rule is.

---

## Recommendation

**Adopt `permissions.defaultMode: "auto"` in `~/.claude/settings.json` as the provisional change.**

Rationale, in order of weight:

1. It is the platform's own answer to the exact question Milestone A3 exists to ask, and the docs name it as such.
2. It targets the classes that dominate the measured baseline. Heredocs were the largest single class at 7 of 21 in the full window recorded above — the earlier partial window of 16 prompts put it at 6, and quoting that figure here contradicted this document's own evidence table. And every one of them is a command-shape failure that the classifier path bypasses entirely.
3. Every prerequisite is verified present: model qualifies, org has not disabled it, no managed setting overrides it.
4. It is genuinely reversible — `Shift+Tab` leaves it for the session, deleting one key reverts it permanently, and dropped allow rules are restored on exit.
5. It is cheaper to try than the sandbox, which needs `excludedCommands` work for `gh` and `docker` on macOS before it would be usable.

**Risks, stated plainly:**

- **It is not a safety guarantee.** The docs are explicit: "Auto mode reduces permission prompts but does not guarantee safety. Use it for tasks where you trust the general direction, not as a replacement for review on sensitive operations." A classifier can be wrong in both directions.
- **It costs tokens and latency.** "Classifier calls count toward your token usage. Each check sends a portion of the transcript plus the pending action, adding a round-trip before execution."
- **It will not fix two of the recorded classes.** The `Bash(rm *)` and `Bash(git merge*)` ask rules keep prompting. If the before/after measurement is read without knowing that, auto mode will look like it underperformed.
- **It can pause itself.** Three consecutive or twenty total classifier blocks return the session to prompting.
- **Two of her allow rules go dormant while it is active** (`Bash(node *)`, `Bash(npm run *)`), adding a classifier round-trip where there was an instant approval.

**Not recommended provisionally:** `bypassPermissions` (the docs restrict it to isolated containers and VMs, and it would disable the protected-path guards on `.claude/` and `.git` that have caught real mistakes); `dontAsk` (auto-denies rather than auto-approves — wrong shape for interactive work); the sandbox (a bigger change with macOS tool breakage to work through first, and it deserves its own evaluation in Milestone B1 rather than a rushed provisional adoption).

## Caveats

- **Auto mode works through the Datadog AI Gateway. Verified 2026-08-04.** 🟢 This was the last open prerequisite: Whitney's traffic routes through `ANTHROPIC_BASE_URL=https://ai-gateway.us1.ddbuild.io` with a `provider: anthropic` header, and the docs enumerate supported providers without describing a custom base URL fronting the Anthropic API. Whitney cycled to auto mode with `Shift+Tab` and the status bar reported `⏵⏵ auto mode on`, so the gateway is treated as the Anthropic API for this requirement. Recorded because it was inference until she checked it, and because a future gateway change could revoke it silently.
- **`defaultMode` sets the starting mode; it does not switch a running session.** 🟢 Verified the same day: adding `"defaultMode": "auto"` to the settings file produced no change in the live session's status bar, which is the documented behavior rather than a failure — "As a default: set `defaultMode` in a settings file." Mid-session switching is `Shift+Tab`. Worth stating because the settings edit looks inert if you check for it in the session that made it.
- Everything labeled documentation-only describes version 2.1.222's documentation, not this machine's behavior.
- The version moves fast: between 2.1.190 and 2.1.222 the changelog carries dozens of permission-related entries, including several that changed which commands prompt. Milestone B1 re-runs this pass for that reason.

## Sources

- [Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md) — the six modes, the auto mode section, the classifier decision order, protected paths, fallback thresholds
- [Configure the sandboxed Bash tool](https://code.claude.com/docs/en/sandboxing.md) — sandbox modes, macOS Seatbelt, filesystem and network isolation, tool incompatibilities
- [Configure auto mode](https://code.claude.com/docs/en/auto-mode-config.md) — `autoMode.environment`, the four rule tiers, ask rules as a human checkpoint, the `claude auto-mode` subcommands
- [Configure permissions](https://code.claude.com/docs/en/permissions.md) — the built-in read-only command set, rule syntax, the argument-pattern fragility warning
- [Claude Code settings](https://code.claude.com/docs/en/settings.md) — `autoMode`, `disableAutoMode`, `allowManagedPermissionRulesOnly`, settings precedence
- [Claude Code CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) — permission-related entries from 2.1.190 to 2.1.222
- Local, read 2026-08-04: `~/.claude/settings.json`; `/Library/Application Support/ClaudeCode/managed-settings.json`; `~/.claude-a3-scratch/permission-events.jsonl`; `claude --version`; `claude auto-mode config`
