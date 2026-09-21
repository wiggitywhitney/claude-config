# Research: Claude Code Permission Modes, Sandbox, and Auto Mode

**Project:** claude-config
**Last Updated:** 2026-09-19
**Claude Code version checked against:** 2.1.278 (`claude --version`, run 2026-09-19), for the escape-hatch probes added that day. The rest of the document was checked against 2.1.276 (run 2026-09-18) and 2.1.222 (run 2026-08-04), marked where a newer pass changed them.
**Produced by:** PRD #109, Milestone A3 half one (the relief pass); extended by Milestone B1 (the sandbox evaluation)

## Update Log

| Date | Summary |
|------|---------|
| 2026-08-04 | Initial research. Documentation pass on permission modes, the sandboxed Bash tool, and auto mode, verified against Whitney's live settings files and the Milestone A3 instrument log. |
| 2026-08-24 | Added the auto-mode live-dependency observation (classifier rate-limiting blocks `Bash` entirely) at the end of the document. |
| 2026-09-18 | Milestone B1 re-ran the pass against 2.1.276 and evaluated the sandboxed Bash tool empirically rather than from documentation. Two of this document's own claims are corrected: the sandbox's per-domain prompt class is largely obsolete, and the `gh` breakage is confirmed but presents as a credential error rather than a TLS one. See "Milestone B1: the sandboxed Bash tool, evaluated" at the end. |
| 2026-09-19 | Resolved the sandbox escape-hatch disagreement against 2.1.278 (Decision 95): the `dangerouslyDisableSandbox` fallback is model-mediated, not an automatic harness-level retry. See "The escape hatch is model-mediated, not a silent harness-level retry." |

---

## How to read the confidence and verification labels

Every claim below carries two labels, because they answer different questions:

- **Confidence** — how well-sourced the claim is. 🟢 primary source, quoted. 🟡 single source or indirect. 🔴 inferred.
- **Verification** — whether it was checked against *this machine*. **Verified-here** means a file was read or a command was run on Whitney's setup today. **Documentation-only** means the docs say it and nothing local was checked.

Milestone B1 re-runs this pass against whatever version ships then. The version pin above is the thing that makes that re-check meaningful.

---

## Summary

Claude Code has a permission mode built for exactly the problem Milestone A3 is measuring — it is called **auto mode**, and the documentation section describing it is titled "Eliminate permission prompts with auto mode." It replaces the approval prompt with a separate classifier model that reviews each action.

**State of play, so the two are not confused.** The measurement window in this document is the **pre-adoption** baseline: those sessions ran in `default` (Manual) and `acceptEdits`, and neither mode changed approval for the measured non-filesystem Bash commands. (`acceptEdits` does change approval for filesystem operations — see the per-mode table below. The trigger classes measured here were not filesystem operations, which is why the two modes' rates are comparable at all.) **Auto mode was then adopted provisionally on 2026-08-04** by setting `permissions.defaultMode` in `config/settings.json`, which takes effect because `~/.claude/settings.json` is a symlink to that tracked file.

**Do not assume `setup.sh` put it there, and do not use `setup.sh` to undo it.** `setup.sh --install` merges `settings.template.json` into `~/.claude/settings.json`; it never installs `config/settings.json`, the template carries no `permissions.defaultMode`, and the merge preserves an existing one. `setup.sh --uninstall` removes symlinks and leaves `~/.claude/settings.json` in place, reporting a backup path rather than restoring it. So the live configuration and the documented provisioning path disagree about which file is authoritative — recorded here as an input to Milestone A4's settings-symlink evaluation, not resolved. To roll auto mode back, remove the key directly:

Because the path is a symlink, the edit lands in the tracked file and shows up as a git diff here. Back the target up and replace it atomically rather than truncating it in place, so an interrupted write cannot leave the live settings unparseable:

```bash
python3 -c 'import json, os, shutil, tempfile; from pathlib import Path; p=(Path.home()/".claude/settings.json").resolve(); shutil.copy2(p, str(p)+".backup"); d=json.loads(p.read_text()); d.setdefault("permissions", {}).pop("defaultMode", None); fd, tmp = tempfile.mkstemp(dir=str(p.parent)); os.write(fd, (json.dumps(d, indent=2)+"\n").encode()); os.close(fd); os.replace(tmp, p)'
```

`resolve()` targets the file the symlink points at, so the symlink itself is preserved. So every rate below describes the setup as it was *before* the change this document recommends.

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

**Interpretation, stated no more strongly than the data allows: this window did not establish a mode effect.** The looser of the two modes shows the *higher* prompt rate, on a small sample for Manual (49 calls). That is an observation from a single mixed window, so it shows correlation and cannot establish that permission mode has no effect, nor that changing mode could not reduce prompts. Rejecting a mode-based remedy outright would need matched before-and-after windows, which this is not.

What it does do is fail to contradict the documentation, which predicts exactly this: `acceptEdits` widens file edits and a short list of filesystem commands while leaving every other Bash command on the prompting path, and both modes gate an inline `python3` heredoc identically.

So it is suggestive, not decisive, evidence that the remedy has to change the *mechanism* rather than loosen the mode.

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

**Interpretation:** in Manual mode, step 3 is "prompt the user." A `python3` heredoc fails to match `Bash(python3:*)` because of how the command is written, falls through, and prompts. In auto mode the same command falls through the same way and reaches a classifier that judges what it *does* rather than how it is spelled. This is why the 227-entry allowlist did not help and auto mode plausibly would: the allowlist competes with the parser, and the classifier only sees what the allowlist failed to match. **Auto mode does not ignore the allowlist** — per step 1, matching `allow`, `ask`, and `deny` rules still resolve first, and the classifier handles only what falls through. That distinction matters for the byte budget and for any future allowlist trim: an `ask` or `deny` rule keeps its force under auto mode, so the two `ask` rules Decision 50 identified are not neutralized by it.

### Auto mode drops some of Whitney's existing allow rules while it is active

**Documentation-only.** 🟡 A side effect worth stating before adoption, because it makes some currently-instant approvals slower rather than faster.

**Source says:** "On entering auto mode, broad allow rules that grant arbitrary code execution are dropped: Blanket `Bash(*)` or `PowerShell(*)`; Wildcarded interpreters like `Bash(python*)`; Package-manager run commands; `Agent` allow rules. Narrow rules like `Bash(npm test)` carry over. Dropped rules are restored when you leave auto mode." ([Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md))

**Interpretation:** Whitney's `Bash(node *)` is a wildcarded interpreter and `Bash(npm run *)` is a package-manager run command, so both are likely suspended in auto mode and routed to the classifier instead. This costs a round-trip, not a prompt. Whether `Bash(git *)` counts as broad is not stated either way in the documentation — flagging it as unresolved rather than guessing.

### The sandbox is a real alternative on macOS with nothing to install, but it introduces a new prompt class

> **Superseded in part, 2026-09-18 (Milestone B1).** The heading's "new prompt class" claim no longer holds at 2.1.276: a sandboxed command reaching an un-allowlisted domain does not prompt Whitney, it fails with a violation notice addressed to the model. The Go-CLI breakage is real for **`gh`, which is the only one of the three that was actually run** — confirmed by direct test, and surfacing as a credential error rather than a TLS one. `gcloud` and `terraform` remain documented possibilities that share the mechanism but were never tested here. Read this section as the 2.1.222 documentation pass and see "Milestone B1: the sandboxed Bash tool, evaluated" for what was measured.

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
2. It targets the classes that dominate the measured baseline. Heredocs were the largest single class at 7 of 21 in the full window recorded above — the earlier partial window of 16 prompts put it at 6, and quoting that figure here contradicted this document's own evidence table. And the command-shape classes are failures that the classifier path bypasses entirely — not a claim that all 21 recorded prompt events are addressed.
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

> **The sandbox deferral above was the right call, and Milestone B1 has now done the evaluation it asked for (2026-09-18).** The deferral reasoning held up: the tool breakage is real. What the documentation pass could not have told us is that the breakage is cheap to fix and the domain-prompt objection has since evaporated. See the final section.

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

## Auto mode has a live dependency, observed 2026-08-24

**When the classifier model is rate-limited, `Bash` stops working entirely** — the tool returns "auto mode cannot determine the safety of Bash right now" and refuses, rather than falling back to prompting. Read-only tools are unaffected: `Read`, `Write`, `Edit`, `Grep`, and `Glob` all continued working through the outage, and a file that could not be written with a shell heredoc was written with the `Write` tool seconds later.

**Two things follow.** Auto mode trades approval prompts for a dependency on a second model being available, which is a cost the mechanism-only reasoning behind Decision 55 did not consider — that reasoning correctly predicted the prompt reduction and could not have predicted this. And the practical workaround is worth knowing before it is needed: during an outage, prefer the file tools over shell equivalents, and expect anything requiring `git` or a CLI to be blocked until it clears.

Recorded as an observation from a single occurrence, not a measured rate. How often it happens is unknown.

---

# Milestone B1: the sandboxed Bash tool, evaluated

**Produced 2026-09-18. Claude Code 2.1.276, macOS (arm64).** Milestone A3 declined to evaluate the sandbox and handed it here (Decision 55). This section answers it by running the sandbox rather than reading about it: every claim below labelled **Verified-here** was produced by enabling the sandbox in a scratch settings file and observing what happened.

## Method, so the evidence is reproducible

The sandbox was enabled *without touching Whitney's live configuration*, using `--settings` — which the CLI documents as "Path to a settings JSON file or a JSON string to load additional settings from," so it layers on top rather than replacing. The probe settings were:

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "network": { "allowedDomains": ["github.com", "*.github.com"] }
  }
}
```

Probes ran as `claude -p --settings <file>` from a scratch directory under `/tmp`, with the prompt supplied on **stdin**. Prompt-on-stdin is not a stylistic choice: `--allowedTools` is variadic, so a prompt placed after it is swallowed as tool names and the run dies with "Input must be provided either through stdin or as a prompt argument." That cost one wasted probe.

**An unsandboxed baseline was captured first, and it is what makes the results attributable.** Before enabling anything: `gh auth status` reported `✓ Logged in to github.com account wiggitywhitney (keyring)` with a valid token, `curl https://api.github.com` returned 200, and `curl https://example.com` returned 200. Without that baseline a sandboxed failure cannot be distinguished from a pre-existing one — and in this evaluation that distinction turned out to be the whole finding.

## Verdict

**The sandbox works on this machine, its one real cost is cheap to fix, and the objection recorded against it in August has largely expired.** It is a viable adoption candidate for Milestone C1 — a stronger one than the August pass concluded. It is not a replacement for auto mode; the two are independent and combine.

## What was verified here

### Filesystem confinement is real, and confirmed by disk state rather than by reported output

**Verified-here.** 🟢 A sandboxed `touch /Users/whitney.lee/sbx_outside_probe.txt` failed with `touch: cannot touch '/Users/whitney.lee/sbx_outside_probe.txt': Operation not permitted`, while the same operation inside the working directory succeeded.

**The check that matters is that the file does not exist.** Listing the path afterward from an unsandboxed shell returns `No such file or directory`, and the inside-the-working-directory file is present. A denial message is a claim; an absent file is evidence. This distinction is worth keeping because the sandbox's own reporting was over-stated until recently — changelog 2.1.268 records "Fixed Bash sandbox instructions over-stating confinement: no unenforced path lists when filesystem isolation is off."

### Network egress filtering is real, and a blocked domain does not prompt Whitney

**Verified-here.** 🟢 This is the correction to this document's earlier objection. A sandboxed `curl https://example.com` — a host deliberately left out of `allowedDomains` — failed with:

```text
curl: (56) CONNECT tunnel failed, response 403

<sandbox_violations>
deny network-outbound example.com:443 (not in this command's allowed_domains — re-run the command with this host listed if it needs it)
</sandbox_violations>
```

`https://api.github.com` returned 200 in the same run, so the filter discriminates rather than blanket-denying.

**Interpretation:** the August pass recorded that the sandbox "trades one prompt class for another — every new network domain prompts until allowlisted," and treated that as a reason to defer. **No prompt reached Whitney.** The violation is addressed to the *model*, which is told to re-run naming the host. The mechanism is per-command allowed domains, added in **2.1.271** — after the August pass, which is why that pass could not have found it. The documentation now describes both paths: "Claude Code pre-allows no domains by default. The first time a command needs a new domain, Claude Code prompts for approval; in auto mode, Claude instead names the hosts a command needs on the command itself... for the classifier to review with it."

The cost model also improved: "Sandboxed network access adds no per-connection classifier requests. The classifier judges the hosts a command names together with the command in one review, and Claude Code checks each connection against the approved list without calling the classifier again."

So the deferral was correct for 2.1.222 and is stale for 2.1.276. **Whitney runs in auto mode**, which is exactly the configuration the carve-out applies to.

### `gh` does break — as Go TLS verification, presenting as a bogus credential error

**Verified-here.** 🟢 The most useful finding in this pass, because the symptom points away from the cause.

Three commands, same sandboxed session:

| Command | Result |
|---|---|
| `gh api repos/cli/cli --jq .name` | `tls: failed to verify certificate: x509: OSStatus -26276` |
| `gh auth status` | `X Failed to log in to github.com account wiggitywhitney (keyring)` / `The token in keyring is invalid.` |
| `curl -sS https://api.github.com/zen` | exit 0 — `Responsive is better than fast.` |

**`curl` succeeding is what isolates the cause.** Network egress, the filtering proxy, and the credential store are all exonerated: `curl` verifies against its own CA bundle, while Go's `crypto/x509` verifies through the macOS trust store. Only the Go path fails. **This confirms the documented claim for `gh` specifically, and only for `gh`.** The documentation says "tools such as `gh`, `gcloud`, and `terraform` may fail TLS verification under Seatbelt"; this pass turned the "may" into a concrete error code for the one tool it ran. `gcloud` and `terraform` were **not** tested. They plausibly share the failure because they share the mechanism — a Go binary verifying certificates through a Mach service the profile denies — but that is inference from the mechanism, not an observation, and it should not be written down as confirmed.

**The mechanism, from the generated Seatbelt profile in the shipped binary.** The profile allows `(allow mach-lookup (global-name "com.apple.securityd.xpc"))` by default but gates trustd behind a flag, with this comment in the generated policy:

```scheme
; trustd.agent - needed for Go TLS certificate verification (weaker network isolation)
(allow mach-lookup (global-name "com.apple.trustd.agent"))
```

Go's certificate verification needs `com.apple.trustd.agent`; the default profile denies that Mach lookup; TLS therefore fails inside the sandbox and nowhere else.

**The trap.** `gh auth status` says *the token in keyring is invalid*. The token is fine — the unsandboxed baseline shows it logged in and working, before and after. `gh` cannot validate the token because the validating API call cannot complete a TLS handshake, and it reports that as a credential problem. Anyone hitting this would plausibly run `gh auth login`, or `gh auth logout`, to repair something that was never broken. **A sub-agent reading only the sandboxed output concluded exactly that** — "failed for an unrelated reason — invalid/expired keyring tokens... not a sandbox restriction" — and was wrong. The baseline is the only reason that did not enter this document as a finding.

### The documented remedy works, and it is one line

**Verified-here.** 🟢 Re-running the same command with `"excludedCommands": ["gh *"]` added returned `cli`. `gh` is restored completely, by running outside the sandbox.

**The other documented remedy does not apply to this machine, and should not be used here.** The docs offer a branch: "If you are using `httpProxyPort` with a MITM proxy and custom CA, set `enableWeakerNetworkIsolation` to `true` instead." Whitney is not. **Verified-here** 🟢: no `HTTPS_PROXY`, `HTTP_PROXY`, `SSL_CERT_*`, `NODE_EXTRA_CA_CERTS` or `CURL_CA_BUNDLE` in the environment, and `git config --global --list --name-only` shows no `http.proxy`, `http.sslcainfo`, or `insteadof` entries. The flag's own description warns that "Enabling this opens a potential data exfiltration vector through the trustd service. Only enable if you need Go TLS verification." So the correct remedy here is `excludedCommands`, and reaching for `enableWeakerNetworkIsolation` would take on an exfiltration vector to solve a problem the narrower flag already solves.

**An untested third option, recorded as a hypothesis rather than a finding.** The binary also exposes `allowMachLookup` — "macOS only: Additional XPC/Mach service names to allow looking up," with trailing-wildcard support, documented as being for "1Password CLI, Playwright, or the iOS Simulator." Since the failure is precisely a denied Mach lookup of `com.apple.trustd.agent`, listing that one service in `allowMachLookup` may restore Go TLS without the blanket weakening. **This was not tested.** It is the narrower instrument if it works, and Milestone C1 should test it before settling the configuration.

### Directories named `hooks/` and `config/` are writable — which this repo needed

**Verified-here.** 🟢 Sandboxed writes to `hooks/probe.txt`, `hooks/nested.sh`, and `config/probe.txt` all succeeded, confirmed by listing the files afterward.

This is checked because changelog **2.1.275** records "Fixed sandboxed Bash commands being unable to write to project directories named `hooks/` or `config/`." `claude-config` has both at its root. The bug would have made the sandbox actively broken in this repo, and it was fixed one version before the version installed here. Worth stating plainly: had this evaluation run two weeks earlier, the answer would have been different for reasons that had nothing to do with the sandbox's design.

## An adoption trap: turning the sandbox on does not, by itself, create a boundary

**Verified-here** (from the shipped binary's own settings schema). 🟢 Two defaults undercut the guarantee, and both are settings Whitney would have to change deliberately:

- **`allowUnsandboxedCommands` defaults to `true`.** Its description: "Allow commands to run outside the sandbox via the `dangerouslyDisableSandbox` parameter. When false, the `dangerouslyDisableSandbox` parameter is completely ignored and all commands must run sandboxed. Default: true." So by default the model retains a parameter that leaves the sandbox at its own discretion. The `/sandbox` UI names these two states "Unsandboxed fallback allowed" and "Strict sandbox mode."
- **`failIfUnavailable` defaults to `false`.** Its description: "...if `sandbox.enabled` is true but the sandbox cannot start (missing dependencies or unsupported platform). When false (default), a warning is shown and commands run unsandboxed."

**Interpretation, and it matters for how the sandbox gets sold.** The sandbox's advantage over auto mode is that its boundary is enforced by the operating system rather than by a model's judgment. That advantage is *conditional on three settings*, two of which default the other way. A configuration of `{"sandbox": {"enabled": true}}` alone is weaker than it reads.

Claude Code's own internal test configuration sets the hardened shape — `enabled: true`, `failIfUnavailable: true`, `autoAllowBashIfSandboxed: false`, `allowUnsandboxedCommands: false` — which is a useful reference point for what the product considers a real boundary, though the third of those reintroduces prompting and is the opposite of what Whitney wants.

The binary also carries a diagnostic that enumerates, in priority order, every setting that weakens enforcement: `sandbox.enabledPlatforms excludes <platform>`, `sandbox.enabled is false`, `sandbox.failIfUnavailable is false (a missing backend would run the shell unconfined)`, `sandbox.allowUnsandboxedCommands is true`, `sandbox.excludedCommands exempts commands`, `sandbox.autoAllowBashIfSandboxed would run commands the operator never granted`, `sandbox.enableWeakerNestedSandbox exposes the host /proc`, `sandbox.enableWeakerNetworkIsolation loosens the egress lock`, `sandbox.allowAppleEvents removes macOS automation isolation`. That list is the platform's own account of the tradeoffs and is a better checklist than anything this audit would invent.

### The escape hatch is model-mediated, not a silent harness-level retry (resolved 2026-09-19)

**Verified-here.** 🟢 `rules/claude-code-sandbox-gotchas.md` described the `allowUnsandboxedCommands` fallback as a blocked command retrying unsandboxed "by default," which could be read as the harness performing the retry on its own. It does not. A blocked command stays blocked unless the model itself decides to re-issue the tool call with `dangerouslyDisableSandbox: true` — the same parameter this session's own Bash tool schema exposes to the model as an explicit, settable field, not an internal fallback.

Three `claude -p --settings` probes isolated this, each writing to `/tmp` (outside the sandbox's allowed paths, so a guaranteed block):

| Probe | Settings | Instruction | Result |
|---|---|---|---|
| 1 | `allowUnsandboxedCommands: false` | run the command once | Blocked: `operation not permitted`. No retry possible — the parameter is ignored, matching the settings-schema description. |
| 2 | `allowUnsandboxedCommands: true` (default) | run once, explicitly told **not** to retry or set `dangerouslyDisableSandbox` | Blocked: same `operation not permitted`, file never created. **No automatic fallback occurred** — the command stayed blocked because the model didn't choose to retry. |
| 3 | `allowUnsandboxedCommands: true` (default), `--dangerously-skip-permissions` | run the command, and "do whatever you think is appropriate" if blocked | Blocked once, then the model re-ran the same command with the sandbox disabled and it succeeded — file created, confirmed on disk. |

**Verdict: both source documents were describing the same mechanism from different angles, and neither was wrong, but the gotchas file's "by default" phrasing invited the automatic-retry reading.** `allowUnsandboxedCommands` governs whether the `dangerouslyDisableSandbox` parameter is *available* to the model at all (probe 1 vs. probes 2–3); it does not make the harness retry on the model's behalf (probe 2 vs. probe 3). The practical consequence for a hardened configuration is unchanged from the existing recommendation below: `allowUnsandboxedCommands: false` is the only setting that actually closes the hatch, because it removes the model's option rather than trusting the model not to exercise it.

`rules/claude-code-sandbox-gotchas.md` has been reworded to match this finding.

## Configuration shape, if Milestone C1 adopts it

Recorded as a starting point to argue with, not a recommendation to apply unreviewed. It keeps auto mode, keeps `gh` working, and closes the escape hatch:

```json
{
  "sandbox": {
    "enabled": true,
    "failIfUnavailable": true,
    "allowUnsandboxedCommands": false,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["gh *"]
  }
}
```

`autoAllowBashIfSandboxed` stays `true` — it is the friction relief, and it already defaults that way.

**`excludedCommands` contains exactly one entry, and the restraint is deliberate.** Every entry in that list is a hole in the boundary by the platform's own diagnostic, so an entry needs evidence rather than a plausible reason. `gh *` has it: `gh` was observed failing inside the sandbox and working again once exempted. Nothing else here has been tested.

**Do not add `docker *` or `colima *` to the block above without testing them first.** An earlier draft of this section listed both, which would have punched two unevidenced holes into any configuration copied from it. The documentation does recommend `excludedCommands` for `docker`, but that guidance is written for Docker Desktop, and under Colima `docker` reaches its daemon over a Unix socket — so **`allowUnixSockets` is the narrower instrument to evaluate first**, and an exemption may not be needed at all. `colima *` was never mentioned by the documentation or by any observation; it was inference. Both belong to the open question below, not to the configuration.

## Three claims that could not be settled here

Stated as open rather than resolved, because guessing them would defeat the point:

1. **`docker` is untestable on this machine right now.** `colima status` reports `colima is not running` and `~/.colima/default/docker.sock` does not exist, so any `docker` failure under the sandbox would be indistinguishable from the daemon being down. The docs' remedy is `excludedCommands: ["docker *"]`. **There is a wrinkle the documentation does not address:** Whitney uses Colima, so `docker` reaches its daemon over a **Unix socket** (`unix:///Users/whitney.lee/.colima/default/docker.sock`, confirmed from `docker context inspect`), and the sandbox blocks Unix sockets by default with `allowUnixSockets`/`allowAllUnixSockets` as the opt-in. The documented `docker` incompatibility is written for Docker Desktop; under Colima the socket path may be the operative constraint, and it may be addressable with `allowUnixSockets` rather than an exemption. Untested — Colima would need to be started first.
2. **Whether `allowMachLookup` can replace `enableWeakerNetworkIsolation`** for the trustd denial, as described above.
3. **Whether anything sandbox-relevant changed between 2.1.222 and 2.1.264.** The changelog fetch covering that interval truncated; entries were only recoverable from 2.1.265 onward. This is absence of evidence, not evidence of absence, and the interval spans most of the gap this re-check exists to cover.

## Capability labels

Applying the three-way labelling the other Phase B spikes use, so the spikes stay comparable:

| Capability | Label | Note |
|---|---|---|
| Sandboxed Bash tool (macOS Seatbelt) | **not used at all** | Verified absent: no `sandbox` key in `~/.claude/settings.json` or in managed settings |
| Per-command `allowed_domains` in auto mode | **not used at all** | Requires the sandbox; unreachable until it is enabled |
| `excludedCommands` | **not used at all** | The remedy that makes adoption viable here |
| `allowUnsandboxedCommands` / `failIfUnavailable` | **not used at all** | Both at weakening defaults, which is the trap above |
| Auto mode (`permissions.defaultMode: "auto"`) | **already used here** | Re-verified live this pass; see the re-check below |
| Credential masking (`sandbox.credentials`) | **not applicable** for now | A substantial subsystem, but it exists to protect secrets *from* sandboxed commands; no current need identified |
| `enableWeakerNetworkIsolation` | **not applicable** | Requires a MITM proxy and custom CA, verified absent here |

## Collapse candidates for Milestone C1

Per the milestone's instruction to hand forward a list rather than have C1 re-derive one:

- **`Bash(rm *)` and `Bash(git merge*)` as ask rules.** Decision 50 recorded that no permission mode can reach these because explicit ask rules survive every mode. The sandbox does not change that — but the sandbox *does* enforce, at the OS level, the thing the `rm` ask rule exists to approximate. Whether the ask rule can be narrowed once writes are confined to the working directory is a real question for C1, and it would remove the single largest remaining prompt class that auto mode cannot touch.
- **Protected-path guards on `.claude/` and `.git`.** The sandbox applies mandatory write protections to `.git/hooks`, `.git/config`, shell rc files, `.mcp.json`, `.vscode`/`.idea`, `.claude/commands`, and `.claude/agents` independently of any rule. Any hand-rolled rule covering the same paths is a candidate for removal, not merely for simplification.
- **`ultrareview`.** A shipped subcommand — "Run a cloud-hosted multi-agent code review of the current branch (or a PR)." Found while enumerating the CLI surface, and **since resolved: it will not be adopted, and it was never run.** It is Claude reviewing Claude, which is the configuration Viktor wrote, considered, and left commented out in favour of a mixed-vendor reviewer. The same pass found a live defect worth more than the subcommand was: a personal `code-review` skill shadows the bundled one by documented precedence, so `/code-review ultra` has been silently discarding the effort argument. See [the reviewer section](claude-code-subagent-capabilities.md) for both findings and the consolidation candidate they produce.

## Re-check of Milestone A3's auto-mode prerequisites, 2026-09-18

The milestone requires re-verifying these rather than inheriting them, since a gateway or managed-settings change could revoke availability silently. All **Verified-here** 🟢 against 2.1.276:

- **Auto mode is live.** `~/.claude/settings.json` sets `permissions.defaultMode: "auto"`. Still the adopted state, unchanged since 2026-08-04.
- **Managed settings still do not block it.** `/Library/Application Support/ClaudeCode/managed-settings.json` contains only `apiKeyHelper`, `effortLevel`, `env`, and `model`. No `permissions.disableAutoMode`, no `allowManagedPermissionRulesOnly`, and no `sandbox` key — so sandbox adoption is also not blocked by policy today. The binary does carry a policy-lock surface ("Sandbox settings are locked by policy. Sandbox provisioning is managed by your administrator," with `policyLocked` and `enabledSource` fields), so an administrator *could* lock it later; this is the thing to re-check if the sandbox ever stops behaving as configured.
- **`autoMode.environment` is still unconfigured.** No `autoMode` key exists in user or managed settings. This is the third item Milestone A3 handed forward and it remains open — it matters for unattended runs, where the docs state repeated classifier blocks abort a `-p` session outright.

### Two live auto-mode blocks, observed during this pass

**Verified-here.** 🟢 Recorded because they are friction data of exactly the kind Milestone A3 was measuring, and because they happened to a legitimate task.

Two probes in this evaluation were refused by the classifier, not by a permission rule: once with `Reason: [Credential Materialization]` for a command that would have printed a keychain secret to stdout, and once with `Reason: [Credential Exploration]` for a command that merely listed keychain metadata without printing any secret.

**Interpretation, both directions.** The first block was correct and caught a genuinely sloppy probe — the command would have materialized a live token into a log file. The second was more conservative than necessary: the command printed no secret value. Both are cheap to work around by dropping the probe, and neither produced a prompt Whitney had to answer. This is a concrete instance of the documented tradeoff — "Auto mode reduces permission prompts but does not guarantee safety" — running in the other direction: the classifier also blocks work that is safe. One occurrence of each, not a rate.

## Milestone B1: what `autoMode.environment` needs for unattended-run survival, closed 2026-09-21 (Decision 99)

**Documentation-only** 🟢, checked against [Configure auto mode](https://code.claude.com/docs/en/auto-mode-config.md) at the installed version (`claude --version` reports `2.1.278`, above every version gate the page names, so every described feature applies). **Verified-here** 🟢 that both `~/.claude/settings.json` and `/Library/Application Support/ClaudeCode/managed-settings.json` still contain no `autoMode` key at all — unchanged from the 2026-09-18 finding above, just re-confirmed at the current version by direct `grep`.

**The question this closes: what does `autoMode.environment` need to contain for an unattended run to survive repeated classifier blocks?** The honest answer is that `autoMode.environment` cannot make a run *survive* a block budget it has already exhausted — it can only reduce how often blocks happen in the first place, by removing false positives before they're spent.

- **The pause thresholds are not a knob `autoMode.environment` reaches.** Confirmed already above ("Auto mode stops being auto after repeated blocks"): 3 consecutive or 20 total classifier blocks pause auto mode, "these thresholds are not configurable," and in `-p` sessions repeated blocks abort outright. Nothing on the auto-mode-config page revisits or overrides that number. `environment` is a distinct field from the budget — it changes what the classifier *decides*, not how many decisions it's allowed to get wrong before stopping.
- **What `environment` actually does: it tells the classifier what "external" isn't.** By default the classifier trusts only the working directory and the current repo's configured remotes; everything else — another org's repo, a cloud bucket, an internal domain, a package registry — reads as a potential exfiltration target and is a candidate for a block. `environment` entries are prose (not regex/tool patterns) naming an organization's actual trusted infrastructure, and they're additive to the built-in list via a literal `"$defaults"` entry, so adding entries only removes false-positive blocks — it cannot loosen the `hard_deny` tier, which is unconditional regardless of `environment`, `allow`, or stated intent.
- **The four-tier precedence is where the real leverage is, and `environment` isn't one of the tiers.** `hard_deny` blocks unconditionally; `soft_deny` blocks next but user intent or an `allow` entry can clear it; `allow` overrides matching `soft_deny` as an exception; explicit user intent overrides remaining soft blocks if a message "directly and specifically describes the exact action." That last clause matters for an unattended `-p` run specifically: there's no interactive user mid-session to state intent, but **the initial prompt text itself is a message**, so a Ralph-loop prompt that names a specific action ("force-push this branch") clears the matching `soft_deny` the way a live human's message would. A general instruction ("clean up the repo") does not.
- **Concretely, for this setup right now:** with `autoMode` completely unset, the classifier has no knowledge of Whitney's actual infrastructure beyond the working repo and its remotes — any unattended task that legitimately touches a personal cloud bucket, an internal Datadog domain, or a package registry is running entirely on the built-in defaults' guesses. `/auto-mode-setup` (a built-in command, not a bundled skill, requiring v2.1.228+ and available at 2.1.278) is the concrete mechanism to populate `environment` from this project's `CLAUDE.md`/`README.md`/git remotes and from recent session commands, writing the draft to `~/.claude/settings.json` — the right scope for personal trusted infrastructure per the settings-scope table on the same page. Hand-authoring the prose entries directly is the alternative if the scan-and-draft flow isn't wanted.
- **So the practical recommendation for Milestone C1:** populate `autoMode.environment` (via `/auto-mode-setup` or by hand) before relying on any unattended run, because every block it prevents is one that doesn't count against the fixed, non-configurable budget — but do not expect `environment` alone to make repeated *legitimate* blocks survivable. If a task is genuinely going to trip `soft_deny` more than twice in a row (e.g., a task whose job is itself destructive-adjacent), the fix is either an `allow` entry for that specific pattern, explicit intent stated in the prompt itself, or restructuring the task — not a bigger `environment` list.

## Sources for this section

- [Configure the sandboxed Bash tool](https://code.claude.com/docs/en/sandboxing.md) — the settings surface, Seatbelt, the Go-CLI and `docker` incompatibilities and their remedies, domain behavior, credential masking
- [Choose a permission mode](https://code.claude.com/docs/en/permission-modes.md) — how the sandbox and auto mode combine, per-command allowed domains, what still prompts inside the sandbox
- [Claude Code CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md) — 2.1.268 (over-stated confinement), 2.1.271 (per-command `allowed_domains`), 2.1.275 (`hooks/` and `config/` writes)
- **Not fetched, and the right next stop:** `/docs/en/settings-reference.md` is where the per-key documentation actually lives; `/docs/en/settings.md` names `sandbox.enabled` once and documents none of the keys. Also unread and relevant: `/docs/en/sandbox-environments.md`, `/docs/en/network-config.md`, `/docs/en/managed-settings.md`. The documentation index at `code.claude.com/docs/llms.txt` enumerates 172 English pages.
- Local, 2026-09-18: `claude --version` (2.1.276); `claude --help`; `~/.claude/settings.json`; `/Library/Application Support/ClaudeCode/managed-settings.json`; `strings` over `~/.local/share/claude/versions/2.1.276`; `colima status`; `docker context inspect`; `git config --global --list --name-only`; four `claude -p --settings` probe sessions under `/tmp/sbx-test`
- Local, 2026-09-19: `claude --version` (2.1.278); three `claude -p --settings` probes against `/tmp` writes, isolating the `allowUnsandboxedCommands` escape hatch as model-mediated rather than automatic
- [Configure auto mode](https://code.claude.com/docs/en/auto-mode-config.md) — `autoMode.environment`, the four rule tiers (`hard_deny`/`soft_deny`/`allow`/explicit intent), `/auto-mode-setup`, `classifyAllShell`, the `claude auto-mode` subcommands
- Local, 2026-09-21: `claude --version` (2.1.278); `grep` for `autoMode` in `~/.claude/settings.json` and managed settings, both absent
