# claude-config repo-native audit

Produced by Milestone A4 of [PRD #109](../../prds/109-claude-config-audit-redesign.md). Findings here are the ones visible only from inside `claude-config` — no comparison against another person's workflow would surface them.

Every enumeration behind the inventories below is produced by a committed, re-runnable script. Where a claim asserts a state of the world, the observation that shows it appears alongside it.

---

## Test suite baseline, recorded before any A4 change

Recorded 2026-08-05 on branch `feature/prd-109-claude-config-audit-redesign`. The milestone requires this baseline first, so that later work is neither blamed for these failures nor allowed to dismiss them as already broken.

Command: `for f in tests/*.bats; do bats "$f"; done`, counting `ok` and `not ok` lines per suite.

**This table was wrong when first written, and the error is worth more than the numbers.** It was labelled "before this milestone modified anything" and totalled 346 passing. Two suites were missing from it: `tests/audit-enumerate.bats`, the enumerator's own 29 tests, which this same document describes two sections below; and one test added to `tests/check-rule-frontmatter.bats` the same day by this milestone's `@`-reference fix. So a document asserting a baseline omitted the 29 tests it also reports building. The PRD compounded it by instructing future readers not to re-run the baseline — an unevidenced completion claim of exactly the class Milestone A4 is cataloguing, sitting inside A4's own evidence section. Re-derived by running every suite individually, 2026-08-05.

The label was also wrong in a second way: "before any A4 change" has no referent, because building the enumerator and fixing the scanners were themselves A4 work. Three distinct numbers, all with 14 failures:

| Snapshot | Pass | Fail |
|---|---|---|
| As originally recorded (incomplete) | 346 | 14 |
| Same commit, with the omitted suite and test restored | 376 | 14 |
| Current, after the hook inventory added tests across five suites and deleted `tests/auto-reanchor.bats` with its script | 376 | 14 |

**The 14 failures are identical across all three, which is the claim that actually matters.** They remain the two documented groups below. No change made in this milestone has added a failure.

Per-suite, current:

| Suite | Pass | Fail |
|---|---|---|
| `tests/audit-enumerate.bats` | 30 | 0 |
| `tests/backup-private-files.bats` | 11 | 0 |
| `tests/bootstrap.bats` | 38 | 0 |
| `tests/cascade-decision-check.bats` | 10 | 0 |
| `tests/check-coderabbit-required.bats` | 9 | 0 |
| `tests/check-prompt-generality.bats` | 9 | 0 |
| `tests/check-rule-frontmatter.bats` | 31 | 0 |
| `tests/e2e-backup.bats` | 8 | 0 |
| `tests/e2e-bootstrap.bats` | 11 | 0 |
| `tests/e2e-sync-repos.bats` | 6 | 0 |
| `tests/git-hook-checks.bats` | 40 | 4 |
| `tests/install-git-hooks.bats` | 11 | 10 |
| `tests/measure-context-load.bats` | 47 | 0 |
| `tests/measure-prompt-rate.bats` | 14 | 0 |
| `tests/post-write-codeblock-check.bats` | 6 | 0 |
| `tests/progress-md-pr.bats` | 5 | 0 |
| `tests/suggest-branch-cleanup.bats` | 12 | 0 |
| `tests/suggest-planning-handoff.bats` | 19 | 0 |
| `tests/suggest-write-prompt.bats` | 24 | 0 |
| `tests/sync-repos.bats` | 11 | 0 |
| **Total** | **352** | **14** |

**Table re-measured 2026-08-20 and it no longer matches the 376 above it, deliberately.** Two changes since: `tests/measure-context-load.bats` gained two tests for the description byte-counting repair (45 → 47), and `tests/cost-tracker.bats` was deleted with its skill (26 → 0), so 376 − 26 + 2 = 352. **The 14 failures are unchanged and identical in name**, which is the property the baseline exists to protect — no work in this milestone has added a failure, across every re-measurement.

The failure count matches what the PRD documented on 2026-08-04. Two details in the PRD's description of these failures are wrong, and both change what the fix would be.

**The ten failures are all in `install-git-hooks.bats`. `bootstrap.bats` passes 38 of 38.** The PRD attributes the ten to those two suites jointly.

**They are not "exiting 127, command not found."** **⚠️ Read the 2026-08-07 correction below before using anything in the next three paragraphs — a clean CI runner disproved this diagnosis, and a reader who stopped here on 2026-08-18 acted on it and was wrong.** The paragraphs are kept because the mechanism they describe is real on this machine and because the disproof is only legible against the claim it retired. The cause of the ten failures is **unknown**.

The mechanism, as observed on this laptop: `core.hooksPath`. Git's global config on this machine sets `core.hooksPath = /usr/local/dd/global_hooks`, a root-owned Datadog-managed directory:

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

**Corrected 2026-08-07 by running the suites on a clean CI runner. The `core.hooksPath` diagnosis above was overstated, and the correction matters more than the original finding.**

The ten `install-git-hooks` failures were attributed to `core.hooksPath` as though that were established. On a macOS GitHub Actions runner, which has no managed hooks path and no `~/.gitignore_global`, **they fail identically** — same assertion, `[ -L "$GIT_REPO/.git/hooks/pre-commit" ]`, at the same line. So `core.hooksPath` is at most a contributing cause on this machine, not the explanation. The four `progress-md` failures do behave as diagnosed: they are absent from the runner's failures, consistent with the global-gitignore cause.

**The runner also failed 43 tests that pass here**, which reframes the whole thing:

| Suite | Failures on this machine | Failures on a clean runner |
|---|---:|---:|
| verify (`.claude/skills/verify/tests/`) | 0 | 26 |
| bats (`tests/*.bats`) | 14 | 27 |
| python (`tests/test_*.py`) | 0 ⚠️ | 0 ⚠️ |

⚠️ **Both zeros are meaningless and were taken as reassurance for twelve days.** `tests/test_setup.py` was crashing at test 3 of 156 with an uncaught `FileNotFoundError`, so the run produced no failure lines to count — the tally saw zero failures because it saw nothing at all. Diagnosed and repaired 2026-08-19; see the `setup.sh` section below. **A zero in a failure column means "nothing failed" only if a total accompanies it.**

The verify-suite failures are one module: the commit-message check returns `exit=2` for every input, including messages it should pass through. The extra bats failures are suites that clone and pull real repositories, and one that needs an authenticated `gh`.

**So the reason nothing automated ever ran these tests is probably not that no gate looked at them. It is that large parts of the suite cannot run anywhere but this laptop.** They were never automatable, so they were never automated. That is a stronger and less comfortable finding than the original, and it is the one to carry into Milestone C1: a test suite that encodes its author's machine is a coupled pair between the tests and one computer, with nothing holding the two together.

**Both groups are now tracked, as of 2026-08-20.** [#115](https://github.com/wiggitywhitney/claude-config/issues/115) covers the ten `install-git-hooks` failures — the genuine bug that reproduces everywhere with an unknown cause. [#116](https://github.com/wiggitywhitney/claude-config/issues/116) covers the machine-dependence: the four `progress-md` failures, the 43 runner-only failures, and the absent CI they block. They were split because the first is a bounded debugging task and the second is an open-ended design problem, and combining them would bury the fixable half. **Whichever of these documents outlives this PRD, the issues are where the work lives now.**

**Neither group of failures is a product defect. Both are tests asserting against paths a machine-level configuration has moved out from under them — and now, tests asserting against a machine that only exists in one place.**

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

Counts when the enumerator was built, 2026-08-05: **17 Claude Code hook entries** across 15 distinct scripts, plus 3 native git hooks; **26 skills**; **80 coupled pairs**; **26 repos** carrying Claude Code configuration.

**After that same day's removals, 2026-08-05: 14 hook entries across 12 scripts plus the 3 git hooks, 24 skills, 87 pairs, 26 repos.** Two more scripts were removed later, so the hook figure here is a dated snapshot and not the current set — **measured 2026-08-18: 12 entries across 10 scripts**. `PostCompact` is no longer a configured event. The pair count rose while three scripts were deleted because that class counts branch-versus-main differences, which today's commits added — further evidence for Decision 57 that it is not measuring what its name claims.

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

### Two skills document a CodeRabbit command that no longer runs

Found 2026-08-05 while following `/prd-update-progress` literally. Both `.claude/skills/prd-update-progress/SKILL.md:326` and `.claude/skills/issue-update-progress/SKILL.md:132` instruct:

```bash
coderabbit review --plain --type committed --base origin/main
```

Verified against the installed CLI rather than inferred:

```text
$ coderabbit review --plain --type committed --base origin/main
error: unknown option '--plain'
```

Both flags were removed in CLI v0.7.0 — `--plain` is now the default output mode, and `--committed` replaced `--type committed`. The command errors before the review starts, so an agent following either skill literally gets no review and may read the failure as "CodeRabbit found nothing."

Following the thread found **six places** stating this one command, four of them stale:

| Location | State before 2026-08-05 |
|---|---|
| `~/.claude/rules/git-workflow.md` | Correct, and explicitly warns about both removals |
| `hooks/git/lib/coderabbit-review.sh` | Correct — fixed 2026-08-02 |
| `.claude/skills/prd-update-progress/SKILL.md` | Stale |
| `.claude/skills/prd-update-progress/SKILL.v1-yolo.md` | Stale |
| `.claude/skills/issue-update-progress/SKILL.md` | Stale |
| `.claude/skills/verify/scripts/coderabbit-review.sh` | Stale, plus the rejected `--no-color` and `--cwd` |

**The last row is the finding.** `hooks/git/lib/coderabbit-review.sh` and `.claude/skills/verify/scripts/coderabbit-review.sh` are two copies of the same script. On 2026-08-02 the first was diagnosed and repaired — the `PROGRESS.md` entry for that day says the pre-push hook "had been silently doing nothing" because the CLI errored and the helper converted the failure into a clean exit. **The second copy was never touched.** Three days later it still carried all four bad flags, verified by running it:

```text
$ bash .claude/skills/verify/scripts/coderabbit-review.sh
=== CodeRabbit CLI Review ===
---
CodeRabbit CLI review failed (exit 1) — skipping
```

**Correction to a claim made while investigating this: the live pre-push review is not broken.** The native git hook calls `hooks/git/lib/coderabbit-review.sh`, the repaired copy, and `--committed` and `--dir` are both confirmed valid against `coderabbit review --help`. The stale copy is reached only through `.claude/skills/verify/scripts/pre-push-hook.sh`, which appears superseded by `hooks/git/` and is not registered in any settings file the hook enumeration found. Running the stale copy directly is what produced the failure above; it is not what runs on push.

**That failure mode is worth naming separately, because it is the one this PRD keeps looking for.** `|| { echo "failed (exit $EXIT_CODE) — skipping"; exit 0; }` renders a rejected-flags error indistinguishable from the benign "CodeRabbit not installed" skip. A reader sees "skipping" and infers nothing is wrong. That is partial execution looking identical to success, and it is why the 2026-08-02 instance survived long enough to be called silent.

**The history shows this is whack-a-mole, not a one-off.** Journal entries record `--no-color` being removed from a CodeRabbit command in `prd-update-progress` on 2026-06-02, again on 2026-06-04, and again on 2026-06-15 — three separate fixes to the same class in different copies, before the 2026-08-02 fix to a fifth, before today's fix to the remaining four.

**No tracked-versus-live drift exists for these skills, and the reason is worth recording for the symlink sweep.** Each skill under `~/.claude/skills/` is a symlink to its directory in this repo:

```text
$ ls -ld ~/.claude/skills/prd-update-progress
... ~/.claude/skills/prd-update-progress -> .../claude-config/.claude/skills/prd-update-progress
```

So the tracked file and the loaded file are one file, and editing the repo copy changes what runs immediately — no sync step, and no possibility of the two diverging. That is the opposite arrangement from `~/.claude/settings.json`, where the same symlinking makes tooling writes appear as git diffs. Same mechanism, desirable in one direction and not the other, which is the distinction the settings-symlink evaluation has to draw.

**Recommended verdict: repair now, collapse in Milestone C1.** All four stale copies were corrected on 2026-08-05, which resolves today's instance and nothing structural. The real remedy is that no skill should state the command at all. `git-workflow.md` is `@`-referenced and therefore always in context, so every skill can point at it, and the two duplicate scripts should become one. Until then the next flag change starts this over.

### A coupled pair inside the coupled-pair tooling

Surfaced by CodeRabbit on 2026-08-05 and fixed the same day. `check-rule-frontmatter.sh` and `measure-context-load.sh` each answer "is this rule `@`-referenced," and they answered differently. The measurer required a boundary after the extension — whitespace, end-of-line, or a closing paren. The checker did not, so `@rules/example.md.bak` counted as a reference to `rules/example.md` in one script and not the other, and a `paths:`-scoped rule could be reported as carrying both loading mechanisms because an unrelated longer path happened to start with its name.

Two implementations of one definition, drifting apart with nothing to notice — the exact shape this milestone is cataloguing, living inside the tooling built to catch it. Both now require the boundary, with a regression test that fails without the fix.

Worth carrying into Milestone C1: the remedy applied here is the weakest of the three the PRD ranks. `derive` would be one implementation used by both scripts; what landed is two implementations that currently agree. The stronger fix was out of scope for a review-response, and it belongs on the list.

### The enumerator's own first run produced five false positives

Recorded because the milestone's instruction is to ask of every check, *what would this check fail to notice* — and the answer came from running it, not reading it.

**Four from resolution base.** A path written in a `SKILL.md` resolves against the skill's own directory, not the repo root: `.claude/skills/verify/SKILL.md` saying `bash scripts/detect-project.sh` means `.claude/skills/verify/scripts/detect-project.sh`, which exists. Resolving against the repo root alone reported four live references as broken.

**One from regex anchoring.** A pattern matching `scripts/detect-project.sh` also matches the tail of `~/.claude/skills/verify/scripts/detect-project.sh`, so a fully-qualified home path was read as a broken repo-relative path. Fixed with a lookbehind requiring the match to start where a path actually starts.

Both are covered by tests that failed before the fix. After it, `rule-names-script` pairs fell from 15 to 11 and broken non-branch targets from 5 to 0 — so every one of the original "broken reference" findings was an artifact of the check rather than a defect in the repo. A verdict list built from that first run would have recommended repairing four things that were never broken.

### A relationship-aware hook existed, and Milestone C1 should inherit its design before rebuilding it

`scripts/check-contributing-freshness.sh` was removed on 2026-08-05. Its mechanism is the finding, and it survives here because Milestone C1 is scheduled to design a coupled-pair warning hook from scratch.

**Correct a claim in the PRD when next updating it.** Milestone A4 states that of the existing hooks, "twelve fire on a file operation and two on a lifecycle event (`SessionStart`, `PostCompact`); none fires on a relationship between files." The first half was already corrected — the unit is 17 registered entries across 15 distinct scripts, not 14. The second half was also false, and this hook was the counterexample. Route the correction through `/prd-update-decisions` rather than editing the PRD directly.

**What it did.** learning-center keeps a `CLAUDE.local.md` that condenses that repo's contributing rules and points at `docs/lab-development/pr-checklist.md` as the fuller source. Two files, one body of knowledge. The hook stored the commit SHA of the last reconciliation in `.git/info/contributing-reviewed-sha` and warned at session start when the authoritative files had moved past it.

**Why that mechanism matters more than the hook did.** The enumerator's three derivation classes all infer pairs from filename shape, which is why they found none of the three real pairs discovered by hand — those were the same knowledge under different names. This mechanism does not infer the pair at all: the pair is declared and the reconciliation point is recorded. That is the shape that works exactly where derivation fails. The tension to resolve in Milestone C1 is that a declared pair is an `assert`, and Decision 17a ranks `derive` above `assert` — but for pairs no filename pattern can relate, an assert may be the only option available, and this was a working instance rather than a proposal.

**The trap it teaches, which is the more valuable half.** It answered "have the authoritative docs changed?" with `git log` against the local checkout, so it could only see changes already fetched and merged. The learning-center clone has **never been fetched** — no `FETCH_HEAD` exists — and sits 45 commits ahead and 4 behind an `origin/main` last known on 2026-05-22. So a drift detector built to catch other people's edits was structurally blind to them, and would have reported "fresh" indefinitely. This is the fourth instance in this audit of a check that passes confidently while unable to see where the violation would live, after the two Milestone A2 found and the enumerator's gitignored-settings gap. **Any coupled-pair mechanism C1 designs must state which side of the pair it can actually observe.**

**A second finding fell out of the same investigation.** That unfetched clone, 45 commits ahead on branch `TRAIN-3466-k8s-updates-DASH`, is a stalled-work and potential data-loss instance in a repo nobody was watching — and an instance of the branch-versus-main coupled-pair class, found by following a thread rather than by enumeration. It belongs in the evidence this milestone owes the stalled-work detector.

**Why removal still cost nothing.** The hook never produced output in its life: it became a registered `SessionStart` hook only on 2026-08-02, recovered from a May stash, and the files it watched last changed 2026-05-07 in local history. It served one dormant repo, its state lived in untracked `.git/info/` so a fresh clone started unarmed and no teammate had it, and both the mechanism and the trap are recorded above. Its cost was never the reason to remove it — a `SessionStart` hook runs twice per session, not per tool call.


## Hook inventory

**Status: all 15 original Claude Code scripts settled with Whitney. The three native git hooks were deliberately not audited — see below.** Rendered from `./scripts/audit-enumerate.sh hooks`, not typed by hand. Re-run it to reproduce the rows; the verdict column is the judgment half and is not derivable.

**State the unit whenever a hook count appears.** Two scripts (`suggest-planning-handoff.sh`, `suggest-write-prompt.sh`) are each registered twice, once on `Write|Edit` and once on `Bash`, so "how many hooks" has two correct answers. The set went from **17 registered entries across 15 distinct scripts** to **12 across 10**, measured 2026-08-18 with `./scripts/audit-enumerate.sh hooks`. Ten scripts kept or repaired, five removed. `PostCompact` is no longer a configured event.

**This line read "14 across 12" until 2026-08-18, and the error is the same one the audit keeps finding.** It was written after three removals and not updated after the next two, so it undercounted the removals — and a reader reconciling it against the table below would land on a third figure again, because `google-mcp-safety-hook.py` is settled in prose under its own heading rather than as a table row. Five scripts were removed in total: `prd-loop-continue.sh`, `vale-on-edit.sh`, `check-contributing-freshness.sh`, `auto-reanchor.sh`, and `google-mcp-safety-hook.py`. **Any count here must come from the enumerator, not from counting rows in the table underneath it.**

### Settled

| Script | Event | Fires on | Verdict |
|---|---|---|---|
| `cascade-decision-check.sh` | PostToolUse | any edit to `prds/*.md`, excluding `prds/done/` | **keep as is** — fires on every PRD edit, not only Decision Log additions, and that dumbness is the point: the cost is one paragraph, the failure mode of a precise version is a missed cascade, and Whitney values that the cascade never gets missed |
| `suggest-write-prompt.sh` | PostToolUse ×2 | `SKILL.md`, `CLAUDE.md`, anything under `prds/` or `rules/`, `*-prompt.md`, `*-spec.md`, plus successful `gh issue create` | **keep as is** — a narrowing to `Write`-only for `prds/` was offered and declined |
| `suggest-planning-handoff.sh` | PostToolUse ×2 | `Write` to `prds/`, plus successful `gh issue create` | **keep as is** — cheapest hook in the set and its content (decisions from *this conversation*) is the one thing no static rule can supply. Known defect left unfixed by choice: its `prds/` match includes `prds/done/`, which `cascade-decision-check.sh` excludes, so two scripts answer "what is an active PRD" differently |
| `check-aboutme.sh` | PreToolUse | `Write`/`Edit` on `.py .sh .ts .tsx .js .jsx` | **keep as is** — verified blocking, exempting, and fix-and-retry paths. **23 of 84 tracked code files lack the header it enforces; backfilling them was explicitly declined 2026-08-05 and is not to be re-raised.** The hook only sees files someone touches, so it cannot reach the rest |
| `check-coderabbit-required.sh` | PreToolUse | `gh pr merge`, unless `.skip-coderabbit` exists | **repaired** — the only hook in the set that fails *closed* everywhere, which is right for a gate. But its channel counting returned `"0\n0"` whenever a `gh api` call failed, so all three numeric comparisons errored with `[: integer expected` and it reported "no CodeRabbit review found" when the lookup had actually failed. Same decision either way; wrong cause, and the two need different responses. Now counts once, and denies with a distinct "could not be verified" message (9 tests) |
| `pre-pr-hook.sh` | PreToolUse | `gh pr create`; also reached via the push tier when the branch has an open PR | **keep the hook, fix what it verifies** — the hook works; the command it runs covers a fraction of the repo. See below |
| `gogcli-safety-hook.py` | PreToolUse | `Bash` commands invoking the Google CLI | **keep, unchanged, and do not "fix" its over-blocking** — see below |
| `prd-loop-continue.sh` | *removed* | `SessionStart` matcher `clear`, declared in gitignored `.claude/settings.local.json` | **removed** — the autonomous loop primitive, and it never worked; see below |
| `post-write-codeblock-check.sh` | PostToolUse | any `Write`/`Edit`; the checker decides what is markdown | **repaired** — deleted a passthrough layer whose whole body re-invoked the Python checker, added the ABOUTME header it was missing, first tests written (6) |
| `suggest-branch-cleanup.sh` | PostToolUse | successful `gh pr merge` only | **repaired** — no longer advises deleting a branch `gh` already deleted; handles `--delete-branch`, `-d`, and `=false` (12 tests) |
| `check-running-clusters.sh` | SessionStart | every session | **repaired, and it had never worked** — see below (44 tests) |
| `vale-on-edit.sh` | *removed* | markdown edits in repos with `.vale.ini` | **removed** — one repo of 26 had that config, last committed to in May; a project linter does not belong in the global set |
| `check-contributing-freshness.sh` | *removed* | every session | **removed** — never produced output in its life; mechanism and blind spot preserved above as input to Milestone C1 |
| `auto-reanchor.sh` | *removed* | PostCompact | **removed** — could not work: stderr on exit 0 reaches only the debug log, and `PostCompact` supports no context injection |

### The cluster alarm's cloud half had never fired

Recorded separately because it is the most expensive defect found. `check-running-clusters.sh` warns about clusters left running, with GKE billed hourly and Kind free. The GKE query ran against whatever project the local `gcloud` config named, discarded the command's error, and treated failure as "nothing running". No project was configured, so the call failed every time and the alarm was silent by construction — **the half with money attached, silent; the free half, working.**

Three compounding faults: the error was swallowed by `2>/dev/null || true`; the query filtered to two hardcoded name prefixes, so the forgotten cluster least likely to be found is the one that never got a conventional name; and the tests stubbed `gcloud` and asserted only the success path, which is the repo's own rule against mocking local CLIs, and is what hid it. Now resolves the project explicitly, reports a missing configuration or failed call as a *problem* rather than as an absence of clusters, drops the filter, and emits the documented `hookSpecificOutput` envelope rather than a bare object that worked only through a `SessionStart` convenience. **Positive detection is still verified against stubs only** — the one accessible project has zero clusters.

`~/.claude/rules/infrastructure-safety.md` waived mandatory teardown gates on the strength of this alarm. That sentence was corrected the same day.

### Deliberately not audited: the three native git hooks

**Whitney's call, 2026-08-18. This is a recorded choice, not an omission, and Milestone C1 inherits the gap knowingly.** The three dispatchers — `pre-commit`, `commit-msg`, `pre-push` — and the eight check scripts they run carry **no verdict**. Nobody should later read the settled table above as covering them.

What the gap covers, so C1 knows its exact shape. The dispatchers are thin — 36, 36, and 41 lines, each resolving its own symlink and then running checks with an accumulate-rather-than-fail-fast `run_check`. The enforcement lives in the eight checks:

| Dispatcher | Checks it runs |
|---|---|
| `pre-commit` | `branch-protection.sh`, `progress-md.sh`, `pre-commit-verify.sh`, `check-prompt-generality.sh` |
| `commit-msg` | `commit-message.sh` |
| `pre-push` | `test-tiers.sh`, `progress-md-pr.sh`, `pre-push-verify.sh` |

All eight are named in at least one bats file, which distinguishes them from the two safety hooks that had no coverage at all. Coverage was not assessed for adequacy — only for existence.

**What argued for auditing, preserved so the decision can be re-opened on its own reasoning rather than re-derived.** These are the only hooks in the setup that stop a real git operation rather than a tool call, so their pass-through path has months of live exercise behind it and needs nothing; their *blocking* path has none. A hook that has quietly stopped blocking is indistinguishable from one with nothing to block, and that shape was found four times elsewhere in this audit — the cluster alarm's silent cloud half, `auto-reanchor`'s unreachable output channel, `check-contributing-freshness` never once producing output, and the CodeRabbit gate reporting "no review found" when the lookup had failed. One of the eight is already known partly defective: `pre-push-verify.sh` resolved to a test command running 466 tests while 376 bats tests went unrun.

**Two facts worth keeping regardless, both cheap and both already established.**

- **`commit-msg` has demonstrated itself unprompted**, rejecting a commit on 2026-08-05 whose message contained the word "Claude." That is enforcement observed on a live commit, not a test — and it is the only blocking path in the eight with live evidence behind it.
- **Repo-local `core.hooksPath` overrides the Datadog global one, so these hooks *can* be exercised end to end in a temp fixture.** Probed 2026-08-18: in a throwaway repo, `git config core.hooksPath <fixture>` resolved to the fixture rather than `/usr/local/dd/global_hooks`, and a fixture `pre-commit` printed its marker during a real `git commit`. **The marker was observed; the resulting block was not — the probe's pipeline swallowed git's exit code.** So the override is confirmed and the block is not. **Its only use is method: it removes the obstacle to exercising these hooks end to end if this audit is ever re-opened. It is not a fix for the ten failing `install-git-hooks.bats` tests**, and the first version of this bullet claimed it was.

  **That wrong claim is worth keeping as the finding, because of how it was reached and what it exposes.** This bullet asserted the override was "a candidate fix for the 10 failing tests, whose diagnosed cause is that same global override," and went on to argue that `rules/bats-bash-testing.md` already held an unapplied remedy for ten of this repo's own failing tests. Both are false, and **the corrected baseline section of this same document already said so** — the clean CI runner of 2026-08-07 disproved the `core.hooksPath` diagnosis for exactly those ten, which fail identically on a runner that has no managed hooks path. Only the four `progress-md` failures behave as diagnosed.

  **How the error happened is the transferable part: the PRD was read and this document was not.** PRD Milestone A4's failing-test section still asserted `core.hooksPath` as *the* cause on 2026-08-18, eleven days after the runner disproved it, so a cold agent reading the PRD for orientation inherited a diagnosis this document had already retired. The PRD has been corrected. **Two lessons, both already stated elsewhere in this audit and both violated here.** A claim about the world needs the observation that shows it, in the same breath — "candidate fix" was reasoning from a diagnosis, not an observation, and it took a reviewer to catch it. And where two documents describe one fact, the one a reader reaches first wins regardless of which is correct, which is the coupled-pair problem this milestone catalogues, appearing inside the milestone's own evidence.

### Method note

Every verdict above came from running the hook against a payload, not from reading it. That found: the cluster alarm's dead cloud half, `auto-reanchor`'s unreachable output channel, `check-contributing-freshness` never having fired, and the `--delete-branch` redundancy. It also produced one false alarm — four `check-aboutme` cases appeared to pass silently until the test payload turned out to be malformed JSON, which the hook fails open on. Reading alone would have missed all four real defects and would not have caught the false one either.

### Nothing automated has ever run most of this repo's tests

The three local tiers are commit → build/typecheck/lint, push → standard security escalating to tests when the branch has an open PR, and `gh pr create` → expanded security plus tests. The test command they all resolve to comes from `.claude/verify.json`:

```json
{"commands": {"test": "python3 .claude/skills/verify/tests/run_tests.py"}}
```

That runner discovers `test_*.py` files **inside `.claude/skills/verify/tests/` only**. Measured 2026-08-06:

| Suite | Tests | Runtime | Run by any gate before 2026-08-06 |
|---|---|---:|---|
| `.claude/skills/verify/tests/` | 466 | 89s | yes |
| `tests/*.bats` | 376 | 208s | **no** |
| `tests/test_*.py` | 4 suites | 18s | **no** |

There were also **no CI workflows at all** — no `.github/workflows/` directory existed. Grepping every hook and script for `bats` returned two hits, a permission entry and a file counter. So the only thing that ever ran the bats suite was a person typing the command.

**This answers a question the PRD carried open.** Milestone A4 recorded that "fourteen tests fail on `main` today, and nothing tracks them." Nothing tracks them because no gate looks at the suite they live in. Every tier reported green over fourteen red tests, indefinitely, because the failures were never inside the thing being checked.

**A workflow was written and run, and it is deliberately not merged (2026-08-07).** Wiring the full suite into the local tiers would have added three and a half minutes to *every push* during a review cycle, since the push tier escalates to tests whenever a PR is open. So the suites belong on a runner instead, overlapping the CodeRabbit wait that already happens, at no cost in local waiting. `.github/workflows/tests.yml` does that and lives on the unmerged branch `feature/ci-test-workflow`, not here.

**It is unmerged because its first run is red, and a permanently-failing check is worse than no check** — it trains the reader to ignore it, which is the advisory-noise problem this audit spent its time removing. The first run's results are recorded in the corrected baseline section above: 26 verify failures and 27 bats failures on a clean runner, against 14 here. Merging CI is blocked on making the suite runnable off this machine, which is its own work rather than a milestone finding.

**Two things the run established that nothing else could.** It disproved the `core.hooksPath` diagnosis, and it revealed 43 tests that pass here only because this machine has network access, credentials, and real repositories sitting where the tests expect them.

**A reminder was considered and rejected.** Under Decision 17a an advisory notice is the weakest tier, and a reminder to run a three-and-a-half-minute suite is one a reader correctly ignores most of the time. The same reasoning that removed advisory noise elsewhere in this audit applies to adding it here.

**The first CI run was an experiment, and it disproved the prediction that motivated it.** The prediction was that ten of the fourteen failures blame `core.hooksPath` from managed policy and four blame `~/.gitignore_global`, so a runner having neither would show them passing. What happened: the four gitignore-caused failures did pass, the ten did not — they reproduce identically on a clean runner — and 43 further tests failed there that pass here. The corrected baseline section above carries the numbers. The lesson is that the experiment was worth running precisely because the reasoning behind the prediction was sound and still wrong.

---

### The Google CLI safety hook over-blocks on purpose, and that is the right call

Verified 2026-08-17 across every category it claims to cover: sends, deletions, calendar events with attendees, drive permission changes, and writes to non-allowlisted spreadsheets are each denied with a specific reason, while reads and unrelated commands pass silently.

**It matches the text of the command rather than an invocation.** Echoing a blocked command is denied, and so is a shell loop that merely carries such a string as test data. That is not hypothetical: it blocked the first attempt to exercise it, and the test payloads had to be assembled from string fragments inside Python before the hook could be tested at all. It then blocked the attempt to *document* this behaviour, because the write was a shell heredoc containing the example — this section had to be written with the file-editing tools instead, which the hook does not watch.

`suggest-branch-cleanup.sh` guards against exactly this shape, anchoring its match at a command boundary so that echoing the command stays silent. Two hooks in one repo, one false-positive shape, one guarded and one not.

**The inconsistency is correct and must be preserved.** This is the only hook in the set where a false negative sends an irreversible message to a real person, while a false positive costs one retyped command. That asymmetry justifies over-blocking here and justifies the opposite call for an advisory. **Anyone later reconciling these two hooks for consistency would be trading a cheap annoyance for an expensive failure.** Recorded so the reconciliation does not happen by tidiness.

### The YouTube MCP safety hook guarded a server that cannot start — removed

`scripts/google-mcp-safety-hook.py` denied delete and upload on YouTube MCP tools. Verified 2026-08-17 that it did exactly that, and correctly allowed listing and transcript downloads.

**It was removed because the capability it guarded is unreachable.** `~/.claude.json` configures a `youtube` MCP server whose command is `~/.claude/scripts/youtube-mcp-wrapper.sh`, **and that file does not exist**, so the server cannot start. That is why no upload or delete tool appears in a session at all. The only working YouTube server is `youtube-transcripts`, which exposes a download tool the hook allowed anyway.

The judgement matches the one applied to `vale-on-edit.sh`: a guard for something not present is removed, and rebuilt deliberately if the thing returns. Restoring an upload-capable server is a deliberate act, and the right moment to add a guard back.

**Two pieces of dead configuration fell out of this, both outside the repo:**

- The `youtube` MCP server entry in `~/.claude.json` points at a missing wrapper script. It should be removed or repaired; it currently fails silently at every session start.
- `~/.claude/scripts/` contains exactly one file, `gogcli-safety-hook.py`, a copy of the script tracked here at `scripts/gogcli-safety-hook.py`. The registered hook path is the repo copy, so the other is an orphaned duplicate. **This is a same-basename-in-a-different-directory pair — one of the two candidate derivation classes Decision 57 asks Milestone C1 to test — and it is the third real pair found by following a thread rather than by enumeration.**

### Neither safety hook has any test coverage

`scripts/gogcli-safety-hook.py` is 292 lines of blocking logic guarding irreversible actions that reach other people, and `tests/` contains nothing for it, while every other blocking hook in the set has a suite. The same was true of the 96-line YouTube hook removed above — so of the two safety hooks that existed, neither was ever tested and one turned out to be guarding an unreachable path.

The cause is the paragraph above: a hook matching on command text is awkward to test, because the harness has to carry the trigger string without tripping it. Awkward-to-test code tends to stay untested, and blocking logic protecting irreversible actions is the worst possible place for that to be true. **The "keep" verdict on these two rests entirely on one manual exercise run, not on anything re-runnable** — which is exactly the kind of unevidenced standing claim this milestone is cataloguing elsewhere.

---

### The autonomous loop primitive never worked, and step 2 of 3 was a no-op for months

`scripts/prd-loop-continue.sh` was a `SessionStart` hook with matcher `clear`. On a `feature/prd-NNN-*` branch it found the PRD, counted unchecked items, and injected a directive to invoke `/prd-next` (or `/prd-done` when nothing remained). Exercised 2026-08-18 it produced exactly that, and its count was correct — 9 unchecked, matching the checklist.

**Whitney's report is the decisive evidence: it has never worked.** The documented mechanism agrees. The official hooks documentation cautions to "write the text as factual statements rather than imperative system instructions," because "text framed as out-of-band system commands can trigger Claude's prompt-injection defenses, which causes Claude to surface the text to you instead of treating it as context." The injected text read `MANDATORY ACTION REQUIRED`, `You MUST invoke /prd-next immediately`, `INVOKE /prd-next NOW`. Unlike `auto-reanchor.sh` it was at least on a supported event, where plain stdout does become context — so the mechanism was right and the framing defeated it.

**Two further defects found while exercising it:**

- **Its second counter was dead.** It counted unchecked work two ways: markdown checkboxes, and milestone headings lacking a completion marker. The heading pattern required a digit immediately after "Milestone", and this PRD names its milestones `Milestone A4`, `Milestone B1`, `Milestone C2`. **Twelve headings, zero matched.** The total was right only because the checkbox counter carried it; a heading-style PRD with letter IDs would have reported zero remaining and directed the session to `/prd-done`.
- **It contradicted Decision 4.** "100% human decides… never decides ahead of Whitney" against "Do not ask for confirmation. Do not summarize or explain." Both deliberate, the conflict live in the configuration rather than on paper. Removal resolves it in favour of Decision 4.

**The removal was sequenced to avoid trading a no-op for a breakage.** Eight repositories carried a live registration — claude-config, cluster-whisperer, commit-story-v2, content-manager, kubecon-2026-gitops, KubeHound-Demo, scaling-on-satisfaction, spinybacked-orbweaver. Deleting the script first would have left eight `SessionStart` hooks pointing at a missing file, firing on every `/clear`. So: `/make-autonomous` stopped installing it, all eight registrations were stripped (each file backed up first, all still parse), and only then were the script and its tests deleted.

**This is an exception to the milestone's no-other-repos rule, taken deliberately.** The files edited are gitignored local settings; no repository's tracked content changed. Recorded as an exception rather than a precedent.

**What it means beyond the hook.** `/make-autonomous` advertised three actions and one of them did nothing, so the summary at the top of that skill was wrong for as long as the hook existed. The YOLO skill variants also instructed the reader to install it and warned when it was absent — guidance to install something that could not work. That is a subsystem-level finding for the skills inventory: **the autonomous mode's loop primitive was inert, so whatever made the loop appear to run was the YOLO skill descriptions' trigger language, not the hook.** Milestone C1 should not treat the loop as a working mechanism it merely needs to tidy.

**One piece of dead configuration deliberately left in place:** `content-manager`'s local settings carry a permission-allowlist string naming this hook, for a command that checked whether it was installed. Harmless and now pointless, in another repo's gitignored file.

**Correcting something recorded in conversation and nearly recorded here: `research/repos/` is not dead material.** It was twice described during this milestone as an 86 MB stray worth a verdict in the dead-material sweep. It is Milestone A1's deliverable — six reference clones including `dot-ai` and `dot-agent-deck`, which Milestones B2 and B4 read — and it is gitignored deliberately at `.gitignore` line 8. 86 MB is what six clones weigh. The dead-material sweep should skip it.

**Cleanup note on the eight-repo edit.** Each `settings.local.json` was backed up before editing, and six of those eight backups sat in repositories where git could see them — one `git add .` away from committing personal configuration into a shared repo. After confirming every live file still parses and no `SessionStart` registration remains, the backups were relocated to `~/.claude-config-backups/2026-08-18-prd-loop-removal/` rather than deleted, so the safety net survives outside every working tree. `content-manager` retains one permission-allowlist string naming the retired hook; its hooks block is confirmed empty.

---

## Skills inventory

**Status: enumerated and classified 2026-08-19. Fourteen lifecycle skills carry a deliberate deferral rather than a verdict — see below.** Rendered from `./scripts/audit-enumerate.sh skills`, run twice against two different roots. The verdict column is the judgment half and is not derivable.

**Measured 2026-08-19.** Two runs, because one was not enough and the reason is the finding:

```bash
./scripts/audit-enumerate.sh skills           # repo root — 24 skills, 276,855 bytes (2026-08-19)
                                              # now 23 skills + 1 command after Decision 62
./scripts/audit-enumerate.sh skills "$HOME"   # user level — 25 definitions: 24 skills + 1 command
```

### The audit had been running this tool at half its reach, and the tool was never the problem

Every skills figure in this audit before today came from the repo-root run. That run reports 24 skills and cannot see anything installed directly at user level, because it scans a repository and `~/.claude/` is not one. The second invocation — same script, same subcommand, different `repo_root` — sees the user level and finds **two live definitions that exist nowhere else**:

| Definition | Kind | Bytes | Where it lives | Tracked in `claude-config`? | Tracked in `claude-personal`? |
|---|---|---|---|---|---|
| `podcast-review-loop` | skill | 3,817 | `~/.claude/skills/podcast-review-loop/` | no | no |
| `design-decisions` | command | 1,074 | `~/.claude/commands/design-decisions.md` | no | no |

Both load in every session on this machine. Neither is in either configuration repository, and `scripts/backup-private-files.sh` does not cover them — it syncs `journal/` and `.claude/design-decisions.md` per repo, so `~/.claude/` is outside its scope entirely.

**This is the same defect shape the audit has now hit five times, and the correction to the earlier framing matters.** The tool is not blind: it handles `.claude/commands/` (it is how `design-decisions` was found) and it accepts the root as an argument. The gap was that nobody passed the second root. A first draft of this section said the enumerator "cannot see user-level skills," which would have sent someone to modify a script that already worked — the same error as claiming a documented remedy existed for the ten failing tests. **Run it against both roots; do not change it.**

**`design-decisions` is the instance Milestone A4 predicted and had not yet found.** The milestone says to include `.claude/commands/` because a command file is a third place a definition can live, and a sweep reading only `.claude/skills/` would report a repo as clean while a command file does something. That was written as a hypothetical. It is real, it is `/design-decisions`, it has been reachable since 2026-03-02, and no skills sweep in this audit saw it until today.

**The data-loss half is the part that needs a decision, not the byte count.** `podcast-review-loop` is 3,817 bytes existing in exactly one place, on one laptop, tracked by nothing and backed up by nothing. Milestone A4 already records that PRD #84's branch being the sole copy of five journal files makes stalled-work detection "a data-loss concern, not only a throughput one." This is the same concern reached by a different route: not work stranded on a branch, but configuration that was never committed anywhere. A machine rebuild provisioned from `claude-config` plus `claude-personal` — which is exactly what those two repos exist to make possible — silently loses both definitions.

### `cost-tracker` was reachable only from inside this repository, and is now removed

**Resolved 2026-08-20 by the one piece of evidence an audit cannot generate: its author has never used it (Decision 62).** The skill, `scripts/cost-tracker.sh`, and 26 bats tests — 25 KB across three files — are deleted. Nothing in `README.md`, no skill, rule, or hook invoked it; every remaining mention is historical except PRD #84's unfinished Milestone 7, which Milestone D1 is now warned about. Git history keeps it recoverable.

**The finding worth carrying is about the question, not the skill.** This inventory had framed it as an inconsistency to repair — 23 skills symlinked globally and this one not — and recommended fixing it. That framing assumed the skill should exist and only asked where it should be reachable from. **A usage question was never asked, and it was the one that mattered.** Milestone C1 should apply test 0 before the classification tests for exactly this reason: "should this exist at all" outranks "where should this live", and an inventory that only measures placement will keep recommending tidier arrangements of things nobody wants.

**Two figures moved, and one of them is the byte-counting repair showing up in real data.** Re-running `scripts/measure-context-load.sh` after the removal drops the skill body total to 274,206 bytes and the startup listing cost to 2,283. Part of that is `cost-tracker` leaving; part is the description measurement itself being corrected on 2026-08-18, which had been charging the whitespace that separates a YAML field name from its value. `anki` moved 126 → 125 description bytes and `code-review` 27 → 26 — one byte each, in every skill, which is what that fix predicted and what confirms it against real input rather than a fixture.

**The always-loaded total is unchanged at 72,258 bytes,** because skill *bodies* load only on invocation; only the descriptions are always paid. Milestone C1's byte budget should not expect skill deletions to move that number much.

The original finding, kept because it is the evidence that prompted the question:

Twenty-three of the repo's 24 skills are symlinked into `~/.claude/skills/` and work in any directory. `cost-tracker` is not symlinked. It resolves today only because sessions run from `claude-config`, where `.claude/skills/` loads as project-level skills — so the one skill whose subject is cross-repo spend is the one that cannot be invoked from another repo. Whether that is deliberate is Whitney's call; nothing in the repo records an intent either way.

### Verdicts

Nothing is stale enough to remove on age: every one of the 24 is tracked, and the oldest last touched is 2026-03-11.

| Skill | Bytes | Last touched | Verdict |
|---|---:|---|---|
| `anki` | 33,781 | 2026-08-02 | **keep** — with `anki-yolo` it is 66,902 bytes, 24% of all skill bytes in the repo. That is a consolidation candidate for Milestone C1, not a removal: the two differ by approval behaviour, the same careful/YOLO axis the lifecycle families use |
| `anki-yolo` | 33,121 | 2026-08-02 | **keep, consolidation candidate** — see above |
| `write-prompt` | 14,671 | 2026-04-08 | **keep** — load-bearing; a hook advises invoking it on every prompt-shaped file, and this audit used it |
| `write-docs` | 14,584 | 2026-04-06 | **keep** — mandated by `CLAUDE.md` for user-facing docs |
| `research` | 14,568 | 2026-04-06 | **keep** — mandated before adopting any new technology |
| `code-review` | 9,801 | 2026-04-18 | **keep** — a symlinked plugin skill; its exclusion rules live in `rules/git-workflow.md` |
| `verify` | 4,992 | 2026-08-06 | **keep** — hosts the hook scripts and the test runner the gates resolve to |
| `cost-tracker` | 2,649 | 2026-04-18 | **removed 2026-08-20 (Decision 62)** — Whitney built it and has never used it, which settles the symlink question by dissolving it. See below |
| `make-autonomous` | 6,217 | 2026-08-18 | **repaired 2026-08-19** — advertised a `SessionStart` hook it no longer installs and an automatic resume after `/clear` that no mechanism performs |
| `make-careful` | 8,071 | 2026-08-18 | **repaired 2026-08-19** — its summary described removing that hook as current work, contradicting its own Step 3 |
| `podcast-review-loop` | 3,817 | untracked | **decision needed** — commit it to one of the two repos, or accept that it is machine-local and unrecoverable |
| `design-decisions` | 1,074 | untracked | **decision needed** — same, and it is a command rather than a skill, so it is also the one instance proving A4's third-place hypothesis |

**The fourteen lifecycle skills — the eight `prd-*` and six `issue-*` — are inventoried here and carry no verdict, deliberately.** Their sizes and dates are in the enumerator output; `prd-done` at 25,130 bytes and `prd-update-progress` at 17,839 are the two largest. Assigning them remove / consolidate / repair / keep verdicts here would duplicate work this PRD has already assigned elsewhere and would reach it with less evidence: Milestone B4 produces the three-way diff against Viktor's ancestor and current skills, and Milestone C1 decides whether the two families collapse into one lifecycle with two entry points. **A verdict reached here would be a verdict reached before Milestone B4 exists, which is the sequencing defect the phase structure was created to remove.** What this milestone owes them is the measurement, and that is recorded.

**One measurement they should carry forward.** Milestone B4 is told to check whether any `SKILL.md` exceeds the 5,000-token post-compaction truncation cap, since a long file silently loses its tail. `prd-done` and `prd-update-progress` are the candidates by size, and the estimate available today is a byte-to-token ratio calibrated against a single `/context` sample — an estimate, not a reading. Do not treat either as confirmed on that basis.

### `setup.sh` did not reflect what the repo installs, and had stopped working entirely

Milestone A4 asks whether `setup.sh` still reflects what the repo actually installs. It did not, in two independent ways, and the second one had broken provisioning outright.

**It provisioned 6 of 24 skills.** `--symlinks` carried a hand-written list — `verify`, `research`, `write-prompt`, `write-docs`, `make-autonomous`, `make-careful` — while `.claude/skills/` holds 24. The 18 missing include every `prd-*` and every `issue-*` skill, so a machine provisioned by the documented path came up with **no `/prd-next` and no `/prd-done`**: the lifecycle this entire PRD is about. The 17 that work on this laptop do so because someone made those symlinks by hand at some point, and nothing records when or why. `--uninstall` carried the same list, so it would also have stranded any link the list had not been updated with.

Fixed by derivation rather than by extending the list: both loops now read `.claude/skills/*/SKILL.md` and `.claude/commands/*.md`. Decision 17a ranks `derive` above `assert`, and this is why — a list of names cannot drift out of step with the directory it is a copy of if it *is* the directory. Verified by mutation: reinstating the six-name filter makes the new test fail and name all 18 missing skills.

**`setup.sh` exited 1 on every invocation, so it installed nothing at all.** It validates that each hook path in the template exists, and `settings.template.json` still pointed at `scripts/google-mcp-safety-hook.py` — the YouTube MCP guard removed earlier in this same milestone:

```text
$ bash setup.sh --output /tmp/x/settings.json
Error: Hook script paths do not exist:
  .../scripts/google-mcp-safety-hook.py
exit=1
```

**That single deletion was recorded in four places and cleaned in one.** This is the coupled-pair failure this milestone catalogues, found by following a thread rather than by any filename-derived rule — the same way all the other real pairs were found:

| Place the deleted hook was recorded | State before 2026-08-19 |
|---|---|
| `config/settings.json` (live) | cleaned at removal time |
| `settings.template.json` | **stale** — broke `setup.sh` for every user |
| `tests/test_setup.py`, custom-template fixture | **stale** — crashed the suite |
| `tests/test_setup.py`, `test_symlinks_standalone_scripts_in_repo` | **stale** — asserted the deleted file exists |

**The fourth row is the one that should have caught this, and it never ran.** It asserts the script exists and would have failed loudly. It never executed, because the second row crashed the suite in an earlier test — `python3 tests/test_setup.py` raised `FileNotFoundError` at test 3 of 156 and aborted. The suite has no per-test isolation, so one exception ends the run.

**And the crash was invisible to the measurement.** The CI comparison table above records `tests/test_*.py` as 0 failures on both machines. That was true in the only sense the tally could see: a crashed run emits no failure lines. **Zero failures and "the suite never got past test 3" are the same reading.** Every other count corrected in this audit was wrong about a quantity; this one was wrong about whether anything had been measured at all. When a suite reports no failures, check that it reported a total.

After repair: **156 of 156 passing**, up from a run that aborted after 2. Four tests were added or repaired — two asserting the derived provisioning, and the hardcoded `expected 11` hook-path count replaced by a figure derived from the template, since a literal there fails whenever a hook is added or removed and makes the failure read as "someone changed the hooks" rather than "a hook path is broken".

**One test was written and did not run, which is worth recording because it nearly shipped.** This suite registers tests by explicit call inside `run_tests()`, so the two new functions did nothing when appended to the file — and appending them after the `if __name__ == "__main__"` block meant they were not even defined when `run_tests()` executed. Both were caught by watching the total rise by one instead of three. A test that exists, is correct, and is never called is indistinguishable from coverage.

---

## Document sizes, measured 2026-08-20

Milestone C1 sets the threshold; Decision 37 assigns the measurement here. Bytes and lines, largest first.

| Document | Bytes | Lines |
|---|---:|---:|
| `prds/109-claude-config-audit-redesign.md` | 222,330 | 953 |
| `docs/research/claude-config-audit-decisions.md` | 85,870 | 342 |
| `docs/research/claude-config-repo-audit.md` | 59,374 | 487 |
| `docs/research/michael-autonomous-execution-principles.md` | 55,480 | 739 |
| `docs/research/prd-workflow-principles.md` | 51,383 | 495 |
| `docs/research/claude-code-context-loading-and-compaction.md` | 27,764 | 218 |
| `docs/research/claude-code-permission-modes.md` | 25,024 | 229 |
| `docs/research/claude-config-load-findings.md` | 24,688 | 238 |
| `docs/research/claude-code-skill-installation-scope.md` | 14,604 | 149 |
| `docs/research/claude-config-load-inventory.md` | 13,922 | 176 |
| `docs/research/claude-code-autonomous-capabilities.md` | 12,758 | 221 |
| `docs/research/michael-forrester-workflow.md` | 12,210 | 136 |
| `docs/research/bats-core.md` | 8,523 | 134 |
| `docs/research/index.md` | 2,240 | 15 |

**The measurement's own finding: the separation rule did not hold, and the documents it was written to protect are the two largest.** Decision 37 was made because the decision log had reached 41 KB and the PRD 560 lines. The decision log is now **85,870 bytes — more than double** — and the PRD is **953 lines, 222 KB**, which is larger than every research document combined bar two. A rule stating where text belongs, adopted and agreed, was followed into a doubling. That is the third instance in this audit of documentation-tier remedy failing where a check would have held, alongside command-shape discipline and TDD ordering, and it is the direct argument for Milestone C1 attaching a check to this rule rather than restating it.

**Attributing it honestly: a large share of the recent growth is this milestone's own.** The corrections of 2026-08-18 to 2026-08-20 added several hundred lines to the PRD and this document, each one a correction that carried its reasoning so a future reader would not repeat the error. That is the tension Milestone C1 has to price: the writing that makes an error non-repeatable is the same writing that makes the document too long to read. A threshold that only counts bytes will penalise exactly the entries most worth keeping. Consider measuring growth *rate*, or capping the PRD alone while letting research documents grow, rather than one number across all of them.

---

## Dead material in `scripts/`, `templates/`, `profiles/`, `config/`, and `hooks/archive/`

Answered once, in prose, per Decision 56 — no subcommand. "Referenced by" below means a non-journal, non-PROGRESS mention in tracked content: journal entries and changelog rows record that a thing once existed and are not uses.

**`profiles/` is an empty, untracked directory.** Zero files, zero tracked by git, created 2026-02-18 and never populated. **Remove**, and drop it from the PRD's list of directories to review — the instruction has been sending readers to look at nothing. It is not a deletion with any risk attached, since git has never held anything in it.

**`hooks/archive/claude-code/` — 7 files, 38 KB — is superseded and referenced by nothing that runs.** Its own README says the logic moved to `hooks/git/checks/` in PRD #47, which is closed and in `prds/done/`. Every reference is historical. **Remove.** The argument for keeping an archive directory is recoverability, and git history already provides that with better fidelity than a copy that no longer matches anything — a copy which is, by construction, a second place the old logic lives.

**`scripts/migrate-prd-109-milestone-ids.sh` is a one-time migration that has already run.** Written 2026-08-03 to renumber this PRD's milestone IDs, referenced only by this PRD and the decision log. **Remove when this PRD closes**, not before: the PRD still cites it as the record of how the renumbering was done. Flagged here so it does not become permanent by inattention, which is how most of this list arrived.

**`scripts/populate-anki-image-bank.sh` and `scripts/rename-anki-bank-images.sh` have no reference anywhere except one journal entry from the day they were written (2026-04-05).** Neither anki skill mentions them; no script, test, or document invokes them. **Remove unless Whitney runs them by hand** — that is the one thing this sweep cannot see, and the reason this is a recommendation rather than a deletion.

**Keep, with the reason each is live:**

| Path | Why it stays |
|---|---|
| `scripts/detect-acceptance-gate.sh` | invoked by four PRD skills and covered by `tests/test_detect_acceptance_gate.py` |
| `scripts/sync-repos.sh` | documented in `README.md` and `docs/new-machine-setup.md` |
| `templates/acceptance-gate-ci.yml` | asserted against by `test_workflow_template.py` |
| `templates/claude-md-general.md`, `claude-md-nodejs.md` | 387 B and 438 B, documented in `README.md`; too small to be worth a decision either way |
| `config/settings.json` | the live settings file; its tracking is a known defect evaluated separately |
| everything else in `scripts/` | invoked by hooks, gates, or this audit |

---

## Cross-repo configuration, enumerated 2026-08-22

**The enumeration ran; the per-repo judgment pass was dropped (Decision 63).** This table is the measurement. The verdict column that was planned for it is replaced by Whitney's direct answer on which repositories are still live, because "do you still work here" is the question that decides a repo's config, and no amount of file measurement reaches it. Produced by `./scripts/audit-enumerate.sh repos`, with last-commit dates added.

| Repo | Last commit | Skills | Commands | CLAUDE.md | Git hooks | Skip dotfiles |
|---|---|---:|---:|:-:|---:|---|
| `advocacy-skills` | 2026-03-17 | 8 | 0 | y | 3 | .skip-branching,.skip-coderabbit |
| `aie-website` | 2026-08-02 | 0 | 0 | y | 0 | - |
| `choose-your-ai-adventure` | 2026-01-27 | 9 | 0 | y | 4 | - |
| `claude-config` | 2026-08-20 | 23 | 1 | y | 4 | - |
| `cluster-whisperer` | 2026-05-16 | 8 | 0 | y | 4 | - |
| `commit-story-v1` | 2026-01-28 | 10 | 0 | y | 3 | - |
| `commit-story-v2` | 2026-07-21 | 8 | 0 | y | 4 | - |
| `commit_story` | 2026-01-28 | 10 | 0 | y | 4 | - |
| `content-manager` | 2026-08-04 | 8 | 0 | y | 4 | - |
| `k8s-vectordb-sync` | 2026-03-11 | 8 | 0 | y | 4 | - |
| `kubecon-2026-gitops` | 2026-03-23 | 8 | 0 | y | 4 | - |
| `KubeHound-Demo` | 2026-03-25 | 8 | 0 | - | 4 | - |
| `learning-center` | 2026-05-21 | 0 | 2 | y | 3 | .skip-coderabbit |
| `mcp-hello-world` | 2026-01-27 | 8 | 0 | y | 3 | - |
| `platform-vibez` | 2025-08-13 | 0 | 1 | - | 3 | - |
| `project-signal-boost` | 2026-05-28 | 8 | 0 | y | 0 | - |
| `rounds-agenticburn` | 2026-06-29 | 0 | 0 | y | 0 | - |
| `scaling-on-satisfaction` | 2026-03-16 | 8 | 0 | y | 4 | - |
| `slide-helper` | 2026-06-22 | 1 | 0 | y | 0 | - |
| `spider-rainbows` | 2026-01-20 | 8 | 0 | y | 4 | - |
| `spinybacked-orbweaver` | 2026-08-18 | 10 | 0 | y | 4 | .skip-e2e |
| `spinybacked-orbweaver-eval` | 2026-07-21 | 8 | 0 | y | 4 | - |
| `telemetry-agent-research` | 2026-03-02 | 9 | 0 | y | 4 | - |
| `telemetry-agent-spec-v3` | 2026-02-24 | 0 | 0 | - | 3 | - |
| `Unleash_an_Agent_Watch_It_Burn` | 2026-06-29 | 0 | 0 | y | 0 | - |
| `websites-securitylabs` | 2026-02-19 | 1 | 0 | - | 3 | - |

**Patterns visible without judging any single repo:**

- **Eighteen of 26 carry exactly 8 skills**, which is the standard set installed into a project. Deviations: `claude-config` (23, its own), `commit-story-v1` and `commit_story` (10), `spinybacked-orbweaver` (10), `choose-your-ai-adventure` and `telemetry-agent-research` (9), `slide-helper` and `websites-securitylabs` (1), and six repos with none.
- **Git-hook installation is inconsistent and nothing explains it.** Fifteen repos have 4 hooks, seven have 3, and five have none. The 4-versus-3 split is `post-commit`, which belongs to commit-story rather than this repo's installer, so the meaningful reading is that five repos carrying Claude Code config have no git enforcement at all.
- **Two repos have `.claude/commands/` and no skills** — `learning-center` (2 commands) and `platform-vibez` (1). These are the third-place definitions Milestone A4 predicted: a sweep reading only `.claude/skills/` reports both as clean while a command file is live in each.
- **Staleness spans three years.** `platform-vibez` last saw a commit on 2025-08-13, over a year ago. Nine repos have not been touched since March 2026 or earlier. Four are active this month.

**No repository other than `claude-config` was modified.** The one prior exception is recorded in Decision 58, where eight repositories' gitignored local settings were cleaned of a registration pointing at a deleted hook.

### Which repositories are live — answered by Whitney, 2026-08-22

The verdict column the enumeration could not produce. **Nothing in these repositories was modified, and no cleanup is proposed for them.**

**Dormant — will not be worked in again:** `platform-vibez`, `mcp-hello-world`, `commit_story`, `commit-story-v1`, `telemetry-agent-spec-v3`, `telemetry-agent-research`.

**Still live, of the stale-looking ones offered:** `spider-rainbows`, `choose-your-ai-adventure`, `websites-securitylabs`. Old last-commit dates, not abandoned.

**What this answer is for, and what it is not.** Removing agent configuration from a dormant repository buys nothing measurable: that configuration only loads when a session runs in that directory, so eight unused symlinks and a `settings.local.json` in a repo nobody opens cost no context and no tokens. **Do not schedule a cleanup pass over these.** What the answer buys is a smaller blast radius for the migration Phase C will design — every repository carrying the standard 8 skill symlinks is a place a skill-family consolidation must either update or knowingly leave dangling, and the difference between touching 26 and touching 20 is the difference between a migration that ships and one that stalls.

**A correction worth recording, because it was caught by Whitney rather than by the audit.** This section originally claimed the `post-commit` hook that writes journal entries runs from `commit_story`, offered as a reason to treat that directory carefully. She asked whether it was actually `commit-story-v2`. It is:

```text
$ readlink node_modules/commit-story
../../commit-story-v2
```

The hook resolves its package by following that npm-link symlink and running `src/index.js` from the target. So all three directories are correctly classified — `commit_story` and `commit-story-v1` (both last committed 2026-01-28) are dormant, and `commit-story-v2` (2026-07-21) is the live one. **The claim was asserted from directory names rather than checked, in a document whose stated rule is that a claim about the world carries the observation that shows it.** One `readlink` settled it.

**One live consumer sits in a dormant repository.** `telemetry-agent-research` also npm-links `commit-story` to `../../commit-story-v2`. Harmless while nothing moves, and a dangling link the day `commit-story-v2` is renamed or relocated — recorded so that rename knows about it.

**Three directories for one project is itself the pattern this audit is about.** `commit_story` and `commit-story-v1` were last committed on the same day and both superseded by a third. Nothing in either marks it as superseded; the only signal is a symlink in an unrelated repository's `node_modules`.

### Which skills are actually used — answered by Whitney, 2026-08-23

**All eight `prd-*` skills are in active use:** `prd-create`, `prd-start`, `prd-next`, `prd-update-progress`, `prd-update-decisions`, `prd-done`, `prd-close`, `prds-get`. None is dead weight.

**This is a negative result and it matters as much as a positive one would have.** The question was asked because `cost-tracker` had just shown that an inventory can measure a skill thoroughly and still miss that nobody wants it, and the same could plausibly have been true of a family installed into twenty repositories by habit. It was not. **So the skill consolidation Phase C decides cannot shrink the surface by deletion — every one of these has to survive in some form**, whether the two families collapse into one lifecycle or stay separate.

That reshapes what Milestone B4 is diffing for. It is not looking for skills to drop; it is looking for whether fourteen live entry points can be expressed as fewer, and what Viktor did about the same problem. **A consolidation that reduces the count by removing capability is off the table before the diff starts.**
