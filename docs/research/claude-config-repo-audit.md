# claude-config repo-native audit

Produced by Milestone A4 of [PRD #109](../../prds/109-claude-config-audit-redesign.md). Findings here are the ones visible only from inside `claude-config` — no comparison against another person's workflow would surface them.

Every enumeration behind the inventories below is produced by a committed, re-runnable script. Where a claim asserts a state of the world, the observation that shows it appears alongside it.

---

## Test suite baseline, recorded before any A4 change

Recorded 2026-08-05 on branch `feature/prd-109-claude-config-audit-redesign`, before this milestone modified anything. The milestone requires this baseline first, so that later work is neither blamed for these failures nor allowed to dismiss them as already broken.

Command: `for f in tests/*.bats; do bats "$f"; done`, counting `ok` and `not ok` lines per suite.

| Suite | Pass | Fail |
|---|---|---|
| `tests/auto-reanchor.bats` | 17 | 0 |
| `tests/backup-private-files.bats` | 11 | 0 |
| `tests/bootstrap.bats` | 38 | 0 |
| `tests/cascade-decision-check.bats` | 10 | 0 |
| `tests/check-coderabbit-required.bats` | 6 | 0 |
| `tests/check-prompt-generality.bats` | 9 | 0 |
| `tests/check-rule-frontmatter.bats` | 28 | 0 |
| `tests/cost-tracker.bats` | 26 | 0 |
| `tests/e2e-backup.bats` | 8 | 0 |
| `tests/e2e-bootstrap.bats` | 11 | 0 |
| `tests/e2e-sync-repos.bats` | 6 | 0 |
| `tests/git-hook-checks.bats` | 40 | 4 |
| `tests/install-git-hooks.bats` | 11 | 10 |
| `tests/measure-context-load.bats` | 44 | 0 |
| `tests/measure-prompt-rate.bats` | 14 | 0 |
| `tests/progress-md-pr.bats` | 5 | 0 |
| `tests/suggest-branch-cleanup.bats` | 8 | 0 |
| `tests/suggest-planning-handoff.bats` | 19 | 0 |
| `tests/suggest-write-prompt.bats` | 24 | 0 |
| `tests/sync-repos.bats` | 11 | 0 |
| **Total** | **346** | **14** |

The failure count matches what the PRD documented on 2026-08-04. Two details in the PRD's description of these failures are wrong, and both change what the fix would be.

**The ten failures are all in `install-git-hooks.bats`. `bootstrap.bats` passes 38 of 38.** The PRD attributes the ten to those two suites jointly.

**They are not "exiting 127, command not found."** The observed cause is `core.hooksPath`. Git's global config on this machine sets `core.hooksPath = /usr/local/dd/global_hooks`, a root-owned Datadog-managed directory:

```text
$ git config --global --get core.hooksPath
/usr/local/dd/global_hooks
$ ls -la /usr/local/dd/global_hooks/ | head -3
drwxr-xr-x 23 root wheel 736 May 19 23:53 .
-rwxr-xr-x  1 root wheel 978 Mar 16 04:37 commit-msg
```

When `core.hooksPath` is set, it overrides `.git/hooks` for every repository, including the temporary fixture repos the tests create. So the installer writes at the managed path rather than into the fixture, and the write is refused:

```text
mv: cannot move '/usr/local/dd/global_hooks/pre-commit' to '.../pre-commit.bak.20260805091729': Permission denied
ln: failed to create symbolic link '/usr/local/dd/global_hooks/pre-commit': Permission denied
```

Each failing assertion is then the expected consequence: `[ -L "$GIT_REPO/.git/hooks/pre-commit" ]` fails because nothing was installed there.

**The four `progress-md:` failures in `git-hook-checks.bats` are exactly as documented.** Every one fails at `git add prds/01-feature.md` with `The following paths are ignored by one of your .gitignore files: prds`. `~/.gitignore_global` excludes `prds/`; this repo negates it with `!prds/` but the test's temporary fixture does not, so the fixture inherits the exclusion.

**Both groups are environment-dependent rather than product defects, and neither can pass anywhere on this machine as written.** That is the shared shape: each test asserts against a path that a machine-level configuration has redirected or excluded out from under it.

### The native git hooks do fire in real use

The `core.hooksPath` finding raises an obvious worry — that the entire native git hook tier described in `.claude/CLAUDE.md` is inert, since git consults the managed directory instead of `.git/hooks`. It is not inert. The Datadog dispatcher chains back to repo-level hooks after its own secret scan:

```text
$ tail -2 /usr/local/dd/global_hooks/pre-commit
#execute repo-level hook
$dir/run-local-hooks -repo_name="${repo_name}" ... -hooktype="${hook}" ... -- "$@"
```

Verified rather than inferred from that line. In a throwaway repository inheriting the same global `core.hooksPath`, a `.git/hooks/pre-commit` that echoes a marker ran during a real commit:

```text
$ git config --get core.hooksPath
/usr/local/dd/global_hooks
$ git commit -m "test: chain probe"
REPO_LEVEL_HOOK_FIRED
[master (root-commit) 1f2f0df] test: chain probe
```

So the installed symlinks in `.git/hooks/` are live. The tests fail on the installation path, not on the execution path — which means the ten failures are a test-environment defect and carry no evidence that enforcement is broken.

---

## The enumerator

`scripts/audit-enumerate.sh` produces every list this document classifies, with 29 bats tests in `tests/audit-enumerate.bats`. Four subcommands, each emitting newline-delimited JSON on stdout and warnings on stderr:

```bash
./scripts/audit-enumerate.sh hooks    # Claude Code hooks from every settings file, plus native git hooks
./scripts/audit-enumerate.sh skills   # skills and .claude/commands definitions, with collisions
./scripts/audit-enumerate.sh pairs    # coupled pairs, derived by construction
./scripts/audit-enumerate.sh repos    # every directory under ~/Documents/Repositories with a .claude/
```

Counts as of 2026-08-05: **17 Claude Code hook entries** across 15 distinct scripts, plus 3 native git hooks; **26 skills**; **80 coupled pairs**; **26 repos** carrying Claude Code configuration.

### The hook count was wrong, and the reason is the finding

The PRD recorded 14 Claude Code hooks — 5 `PreToolUse`, 7 `PostToolUse`, 1 `SessionStart`, 1 `PostCompact`. The enumerator reports 17: `PreToolUse` 5, `PostToolUse` 8, `SessionStart` 3, `PostCompact` 1. Two causes.

**"How many hooks" has no answer until the unit is stated.** `suggest-planning-handoff.sh` and `suggest-write-prompt.sh` are each registered twice — once matching `Write|Edit`, once matching `Bash`:

| Script | Event | Matcher |
|---|---|---|
| `suggest-planning-handoff.sh` | `PostToolUse` | `Write\|Edit` |
| `suggest-planning-handoff.sh` | `PostToolUse` | `Bash` |
| `suggest-write-prompt.sh` | `PostToolUse` | `Write\|Edit` |
| `suggest-write-prompt.sh` | `PostToolUse` | `Bash` |

So 17 registered entries and 15 distinct scripts are both correct, for different questions. This repeats the class-individuation problem Milestone A3 hit with permission trigger classes, and the same remedy applies: state the unit rather than quoting a bare number.

**One hook is invisible to any sweep that reads tracked settings only.** 16 of the 17 entries live in `config/settings.json`. The seventeenth — a `SessionStart` hook running `prd-loop-continue.sh` — is declared in `.claude/settings.local.json`, which is gitignored.

That is the third occurrence of one defect shape. Milestone A2 found it twice: a rules index that loaded unconditionally while the tooling called it on-demand, and an always-loaded import living outside the repository. Each time, a count was enumerated from places someone remembered rather than derived from what membership means. The enumerator reads four settings files for this reason, and a fifth appearing later has to be added there rather than counted by hand — which is a mitigation, not a fix, because the list of files is still a remembered list.

### A coupled pair inside the coupled-pair tooling

Surfaced by CodeRabbit on 2026-08-05 and fixed the same day. `check-rule-frontmatter.sh` and `measure-context-load.sh` each answer "is this rule `@`-referenced," and they answered differently. The measurer required a boundary after the extension — whitespace, end-of-line, or a closing paren. The checker did not, so `@rules/example.md.bak` counted as a reference to `rules/example.md` in one script and not the other, and a `paths:`-scoped rule could be reported as carrying both loading mechanisms because an unrelated longer path happened to start with its name.

Two implementations of one definition, drifting apart with nothing to notice — the exact shape this milestone is cataloguing, living inside the tooling built to catch it. Both now require the boundary, with a regression test that fails without the fix.

Worth carrying into Milestone C1: the remedy applied here is the weakest of the three the PRD ranks. `derive` would be one implementation used by both scripts; what landed is two implementations that currently agree. The stronger fix was out of scope for a review-response, and it belongs on the list.

### The enumerator's own first run produced five false positives

Recorded because the milestone's instruction is to ask of every check, *what would this check fail to notice* — and the answer came from running it, not reading it.

**Four from resolution base.** A path written in a `SKILL.md` resolves against the skill's own directory, not the repo root: `.claude/skills/verify/SKILL.md` saying `bash scripts/detect-project.sh` means `.claude/skills/verify/scripts/detect-project.sh`, which exists. Resolving against the repo root alone reported four live references as broken.

**One from regex anchoring.** A pattern matching `scripts/detect-project.sh` also matches the tail of `~/.claude/skills/verify/scripts/detect-project.sh`, so a fully-qualified home path was read as a broken repo-relative path. Fixed with a lookbehind requiring the match to start where a path actually starts.

Both are covered by tests that failed before the fix. After it, `rule-names-script` pairs fell from 15 to 11 and broken non-branch targets from 5 to 0 — so every one of the original "broken reference" findings was an artifact of the check rather than a defect in the repo. A verdict list built from that first run would have recommended repairing four things that were never broken.

