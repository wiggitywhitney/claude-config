# Reviewer sub-agent trial — build record

Produced by the reviewer sub-agent trial (Decision 66) of [PRD #109](../../prds/109-claude-config-audit-redesign.md). **Outcome, 2026-08-26: the push gate was removed. The reviewer was kept as a command you invoke deliberately.**

The trial did what Decision 66 built it to do — it produced enough evidence to decide, and the decision went against the mechanism. Whitney called the apparatus unneeded complexity and she was right, on grounds this repository's own research had already recorded before any of it was built: [the capability findings](claude-code-subagent-capabilities.md) say plainly that CodeRabbit is a different-vendor checker already wired in, and that *"the gap is not that no independent checker exists. The gap is when it runs and who has to drive it."* A second checker was built anyway, and it is same-vendor — which discards the exact property that made Viktor's reviewer worth copying.

**What decided it**, beyond the 2-of-3 score:

- CodeRabbit handled a 15,207-line, 111-file diff without dropping a file. The sub-agent truncated at 1,010 lines.
- CodeRabbit found both of the gate's own bypasses — `git -C push`, then the quoted-path variant — and caught that the read-only claim was overstated. The mechanism built to catch defects was a net producer of them.
- The gate accepted any recorded verdict. Its integrity rested on the notes being honest, which makes it a speed bump rather than a guarantee.
- Once pushing became a step in `/prd-update-progress`, the gate turned every progress update into a stop. Its first real use had already spent a conversation to release nineteen days of journal files sitting on one laptop — friction pointing the wrong way.
- It refused the command that deleted it, because that command ended by testing whether the deletion had worked.

**Removed:** the `PreToolUse` hook and its project settings registration, `compute-diff-key.sh`, `record-diff-review.sh`, and their three bats suites. **Kept:** `.claude/agents/diff-reviewer.md` and `/diff-review`, rewritten to dispatch and report with nothing gating on the result.

**What survives and feeds Milestone C1** is everything the trial measured, all of it still true with the artefacts gone: the per-run cost figures, the `maxTurns` truncation behaviour, the stall-watchdog correction, and the finding that a same-vendor reviewer is strong on assertions and unproven on code.

**Scored 2026-08-25: the reviewer caught 2 of the 3 defects it was built for.** The artefacts are built, the push gate is demonstrated working, and the catch count exists. One criterion remains open — Whitney has not yet used the gate on a real push, so whether the interruption is tolerable is unanswered.

Built 2026-08-24 against branch `feature/prd-109-claude-config-audit-redesign` at `d89d1e8`.

## What was built

| Artefact | Path | What enforces it |
|---|---|---|
| The reviewer | `.claude/agents/diff-reviewer.md` | `tools: Read, Grep, Glob, Bash` — no `Write`, no `Edit`. `maxTurns: 30` is the only runaway protection, because no timeout or stall detection exists. **Read-only is partly enforced and partly asked for**, see below |
| The dispatch step | `.claude/commands/diff-review.md`, `scripts/compute-diff-key.sh`, `scripts/record-diff-review.sh` | The judgment is the sub-agent's; naming the file, resolving the base, and writing valid JSON are deterministic and live in scripts |
| The push gate | `.claude/skills/verify/scripts/check-diff-review-required.sh`, registered in `.claude/settings.json` | `PreToolUse` on `Bash`, emitting `permissionDecision: deny`. Shape copied from `check-coderabbit-required.sh` |

Test coverage: 37 bats assertions across `tests/compute-diff-key.bats` (10), `tests/check-diff-review-required.bats` (19), and `tests/record-diff-review.bats` (8). All 37 pass, run 2026-08-24. Counted with `grep -c '^@test'` per suite rather than from memory — the earlier figure here was stale twice over.

## The gate, demonstrated rather than asserted

Both staleness properties were shown with real `git push --dry-run` attempts from this repository, refused by Claude Code's permission layer — not by calling the hook script directly.

**A push with no verdict is refused.** Outgoing key `ce7348a1bb12`; the push returned `Push blocked — no diff review verdict exists for the outgoing diff (key ce7348a1bb12)`.

**A verdict for an earlier diff does not satisfy a later push.** A verdict was recorded under key `cfeea327e3e3`, computed from the same base against `HEAD~1`, and left on disk. The push was refused with the same message naming `ce7348a1bb12`, so the gate matched on content rather than on the mere existence of a verdict. Both demonstration verdicts were deleted afterwards, leaving the gate protecting.

**The gate blocked its own first commit.** The commit message explaining what the gate does contained the words `git push`, inside a `<<'EOF'` heredoc feeding `git commit -F -`. The hook stripped quoted strings, as `check-coderabbit-required.sh` does, but quote-stripping never sees inside a heredoc body, so the message matched and a plain commit was denied. Fixed by stripping heredoc bodies before matching, with two tests covering it — one that a heredoc mentioning a push passes through, one that a real push chained after such a heredoc is still blocked. Worth stating plainly: this hook was copied from a hook that had already been given a defence against this exact class, and the copy inherited the defence without inheriting its full coverage.

**Then it blocked its own next commit, for a different reason.** After heredoc stripping was added, a `-m` message spanning several lines got through: the quote-stripping was a line-based `sed`, and a quoted span that opens on one line and closes three lines later leaves its middle lines exposed to the matcher. Fixed by stripping quoted spans across the whole command rather than line by line. **Two false positives, both from the same root assumption** — that the text being matched is one line, and that the defence copied from `check-coderabbit-required.sh` was complete because it existed.

**The gate refuses the whole Bash command, not just the push.** A compound command that recorded a verdict and then pushed was denied in its entirety, so none of the setup ran either. This is correct for a gate — it evaluates the command text before anything executes — and it means any script that arranges state and then pushes has to be split across two invocations.

## Why the verdict is keyed to diff content

`compute-diff-key.sh` prints a SHA-256 of `git diff <base>...HEAD`, with the base resolved as the branch's upstream, then `origin/main`, then a hard failure. Keying to a commit SHA was the simpler alternative and was rejected: a SHA does not change when the outgoing set grows because the remote branch is further behind than the review assumed, and that case ends with a verdict that describes less than what is being pushed.

The script exposes `--print-base` so the dispatch step can produce the diff text without restating the resolution order. That restatement was the alternative, and it would have created two descriptions of one fact free to drift apart — which is the first defect class the reviewer is being built to catch.

## What the reviewer hunts for

Four classes, taken from PRD Decision 66 rather than from Viktor's generic list: a claim whose stated basis is already disproved elsewhere in the repository; a figure that disagrees with the tool that generates it; a reference to a file, script, or flag that no longer exists; an assertion of state with no observation beside it.

Two of Viktor's practices carried across. Every prohibition in the prompt states the failure it prevents, which is what lets his config survive being read by cold-starting agents. And the dispatch step filters findings on agreement rather than severity, because the three defects on record here would all have been labelled minor.

**The prompt deliberately contains no worked examples**, against the general rule that 3–5 diverse examples improve a prompt. The four classes are derived from the same three commits the reviewer is about to be scored against, so examples drawn from them would be answer-key leakage and the benchmark would measure recall rather than review skill. Worth adding once a score exists.

## The score: 2 of 3

Scored 2026-08-25 against the commits that *introduced* each defect, each in a worktree checked out at that commit so the reviewer could not read the correction that was written later. **The pass criteria were fixed in writing before any result was seen**, to stop the score being graded generously after the fact.

| # | Commit reviewed | Target defect | Result |
|---|---|---|---|
| 1 | `806bbc6` | A `core.hooksPath` diagnosis offered as a candidate fix, already disproved elsewhere in the same document | **Catch** |
| 2 | `e1fb336` | Hook counts corrected in one place and left contradicting in others | **Catch** |
| 3 | `0a3faa6` | An uninstall path that strands symlinks whose repo source was deleted | **Miss** |

**Case 1 caught it cleanly and cited its evidence.** It quoted the diff's "candidate fix for the 10 failing `install-git-hooks`" claim, then named lines 79, 81 and 328 of the same document, where the clean CI runner had already disproved that diagnosis. It also found something not on the benchmark: PRD line 492 still read "Current counts: 17 hook entries" in present tense and undated, four lines from the correction, in the very commit whose job was fixing counts.

**Case 2 caught it by running the tool.** It found `14 Claude Code hooks` surviving in two places after the diff corrected the figure to 17 entries across 15 scripts, one of them in `claude-config-audit-decisions.md` — a file the diff itself edits. Separately it reconstructed the pre-fix reference check and re-ran the shipped one, establishing that the write-up's "five false positives" is four, with the breakdown mislabelled. That is a figure produced by a tool in this repository which the write-up did not re-derive, caught by re-deriving it.

**Case 3 is the miss, and it is worse than an oversight.** The reviewer read the uninstall loop, compared it against the install loop, and cleared it: "the install and uninstall loops enumerate the same predicate." The symmetry *is* the defect — uninstall builds its list from repository sources, so a skill deleted from the repo is never enumerated and its installed symlink is never removed. It inspected the exact lines and read the bug as correctness, which is the same conclusion the original author reached. Its prompt also named the installer and its test file, so it was pointed at the right file and still missed; that makes the miss stronger evidence, not weaker.

**What it found instead of case 3's defect was still real, and still live.** It reported that `scripts/google-mcp-safety-hook.py` had been deleted while `README.md` and `rules/hooks-reference.md` still documented it. Checked against the current repository on 2026-08-25: both references are still there, and the rule file still tells any session that reads it that the hook exists and fires on YouTube MCP calls. Defect class 3, found a week after the fact, in a file that shapes agent behaviour.

**The honest reading.** Two of three, on a benchmark built from this repository's own measured failures, is enough to keep going and not enough to trust. The two catches are both *claim-versus-evidence* defects, where the contradicting evidence is written down somewhere the reviewer can read or a tool can produce. The miss is a *logic* defect, where being right requires reasoning about what a loop will do rather than comparing two texts. That split is the finding worth carrying into Milestone C1: this reviewer is a strong checker of assertions and an unproven checker of code.

## The scoring run, and what it cost to obtain

**`maxTurns` truncates a legitimate review and does not announce it.** Two of the three first attempts stopped at exactly 30 tool uses — the configured cap — and returned only their opening sentence. Nothing in the result says "incomplete"; it looks like a reviewer that found nothing and barely tried. The agent prompt instructs the reviewer to end with `FINDINGS: INCOMPLETE` if it runs out of room, and **that safeguard is unreachable**: the cap fires before the reviewer gets a turn to report it. A prompt cannot protect against the mechanism that stops the prompt. The cap was raised to 80 after the first round.

This is the sharpest operational finding of the trial. `maxTurns` is the only runaway protection the platform offers, and set low enough to be useful as protection it silently becomes a correctness problem — a truncated review that a caller cannot distinguish from a clean one is exactly what the push gate would then accept.

**A stalled sub-agent is detected after all, contradicting what was banked.** [The capability findings](claude-code-subagent-capabilities.md) record stall detection as "No — no idle or stall detection exists. Only `maxTurns`." One scoring attempt was killed by a task-level stream watchdog after 600 seconds of no progress. The sub-agent has no self-detection, but the harness does, and the distinction was not drawn when that table was written. **Correct the capability table before Milestone B1 reads it.**

**Cost is measurable after all, in tokens rather than dollars.** Decision 62 removed `/cost-tracker` and the trial expected to report cost as unmeasured. Each completed sub-agent returns its own token usage, which is a real per-run figure: the three first attempts consumed 84,629, 93,000, and 82,229 tokens. So a review of a 176-to-1000-line diff costs on the order of 80,000 to 95,000 tokens, and a run that truncates costs as much as one that succeeds — the 93,000-token run returned nothing. That is the number Milestone C1 needs before proposing any fan-out design, and it did not require restoring an instrument.

**One scoring prompt was contaminated and the run was discarded.** A retry prompt for the counts case told the reviewer that numbers stated as current were the highest-value thing to verify and that the repository held a tool to produce them — which is the defect being scored. That run was killed rather than counted. The re-run for the uninstall case carries a milder hint naming the installer and its test file, which narrows the location without naming the defect; its result is recorded as weaker evidence than the unaided one.

## Read-only is weaker than the success criterion implies

Decision 66 asks for a reviewer that is "read-only because its tool list omits `Write` and `Edit` — not because its prompt asks it to behave." The tool list does omit both. It includes `Bash`, which the spec also names, and **`Bash` can write** — a redirect, a `git checkout`, a script with side effects. So the guarantee is narrower than the criterion's wording suggests: the ordinary editing path is closed by the platform, and everything else rests on the prompt, which is the mechanism the criterion was written to avoid relying on.

Removing `Bash` would restore the guarantee and break the reviewer. Defect class 2 is a figure that disagrees with the tool that generates it, and catching it means running the generator. The trial keeps `Bash` and states the limitation rather than quietly satisfying the criterion on a technicality. Raised by CodeRabbit on 2026-08-24; a real narrowing of a claim this document had overstated.

Whether to close the gap — a `PreToolUse` hook restricting the reviewer's `Bash` to an allowlist of read-only commands — is an open question for after the scoring run, because it is machinery to protect a role that has not yet earned its place.

## The benchmark, and a correction to how the PRD frames it

The PRD's table names the commit that **fixed** each miss. Reviewing those diffs would measure whether the reviewer objects to correct work. Each miss has an identifiable **introducing** commit, and those are what should be scored:

| # | Introduced by | Fixed by | What was wrong |
|---|---|---|---|
| 1 | `806bbc6` | `f859b16` | The `core.hooksPath` diagnosis for ten failing tests, already disproved by a clean CI run recorded in the same repository |
| 2 | `e1fb336` | `806bbc6` | Counts reported as current that disagreed with the enumerator and with each other |
| 3 | `0a3faa6` | `f77fc46` | An uninstall path stranding symlinks whose repo source was deleted |

`806bbc6` appears in both columns: it fixed the counts and introduced the false claim in the same commit.

Scoring runs in a worktree checked out at the introducing commit, so the reviewer sees the repository as it stood then. In the current checkout the written correction for all three is already present, and Grep would hand the reviewer the answer.

Three worktrees are checked out and **left in place deliberately** for the scoring run: `/tmp/bench-806bbc6`, `/tmp/bench-e1fb336`, `/tmp/bench-0a3faa6`. Remove them with `git worktree remove <path>` once the score is recorded.

## Platform behaviour observed

**A new slash command is available immediately; a new sub-agent definition was not.** `/diff-review` was dispatchable as soon as the file was written. Dispatching `diff-reviewer` in the same session failed with `Agent type 'diff-reviewer' not found`, listing only the built-in agents. It became available later in the same session without a restart. So the two artefact types do not refresh on the same schedule, and a plan that assumes a new agent is immediately dispatchable can fail. This is one observation, not a measured interval.

## Cost

**Not recorded, because no run has happened yet and no instrument exists.** `/cost-tracker` was removed on 2026-08-20 as unused (Decision 62). The scoring run is the first opportunity to record a figure, and doing so means finding a measurement method first.

## What remains before this trial can be judged

- The reviewer has not been run against any of the three benchmark diffs, so the catch count is unknown. A zero is a legitimate outcome and is to be recorded as one.
- Cost per run is unmeasured.
- Whitney has not yet used the gate on a real push, so whether the interruption is tolerable is unanswered.
