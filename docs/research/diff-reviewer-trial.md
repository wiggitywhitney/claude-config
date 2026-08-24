# Reviewer sub-agent trial — build record

Produced by the reviewer sub-agent trial (Decision 66) of [PRD #109](../../prds/109-claude-config-audit-redesign.md). **The trial is incomplete.** The three artefacts are built and the push gate is demonstrated working; the reviewer has not yet been scored against the three benchmark diffs, so the number the trial exists to produce does not exist yet.

Built 2026-08-24 against branch `feature/prd-109-claude-config-audit-redesign` at `d89d1e8`.

## What was built

| Artefact | Path | What enforces it |
|---|---|---|
| The reviewer | `.claude/agents/diff-reviewer.md` | `tools: Read, Grep, Glob, Bash` — no `Write`, no `Edit`, so findings-only is a property of the platform rather than a request in prose. `maxTurns: 30` is the only runaway protection, because no timeout or stall detection exists |
| The dispatch step | `.claude/commands/diff-review.md`, `scripts/compute-diff-key.sh`, `scripts/record-diff-review.sh` | The judgment is the sub-agent's; naming the file, resolving the base, and writing valid JSON are deterministic and live in scripts |
| The push gate | `.claude/skills/verify/scripts/check-diff-review-required.sh`, registered in `.claude/settings.json` | `PreToolUse` on `Bash`, emitting `permissionDecision: deny`. Shape copied from `check-coderabbit-required.sh` |

Test coverage: 30 bats assertions across `tests/compute-diff-key.bats` (10), `tests/check-diff-review-required.bats` (12), and `tests/record-diff-review.bats` (8). All 30 pass, run 2026-08-24.

## The gate, demonstrated rather than asserted

Both staleness properties were shown with real `git push --dry-run` attempts from this repository, refused by Claude Code's permission layer — not by calling the hook script directly.

**A push with no verdict is refused.** Outgoing key `ce7348a1bb12`; the push returned `Push blocked — no diff review verdict exists for the outgoing diff (key ce7348a1bb12)`.

**A verdict for an earlier diff does not satisfy a later push.** A verdict was recorded under key `cfeea327e3e3`, computed from the same base against `HEAD~1`, and left on disk. The push was refused with the same message naming `ce7348a1bb12`, so the gate matched on content rather than on the mere existence of a verdict. Both demonstration verdicts were deleted afterwards, leaving the gate protecting.

**The gate blocked its own first commit.** The commit message explaining what the gate does contained the words `git push`, inside a `<<'EOF'` heredoc feeding `git commit -F -`. The hook stripped quoted strings, as `check-coderabbit-required.sh` does, but quote-stripping never sees inside a heredoc body, so the message matched and a plain commit was denied. Fixed by stripping heredoc bodies before matching, with two tests covering it — one that a heredoc mentioning a push passes through, one that a real push chained after such a heredoc is still blocked. Worth stating plainly: this hook was copied from a hook that had already been given a defence against this exact class, and the copy inherited the defence without inheriting its full coverage.

**The gate refuses the whole Bash command, not just the push.** A compound command that recorded a verdict and then pushed was denied in its entirety, so none of the setup ran either. This is correct for a gate — it evaluates the command text before anything executes — and it means any script that arranges state and then pushes has to be split across two invocations.

## Why the verdict is keyed to diff content

`compute-diff-key.sh` prints a SHA-256 of `git diff <base>...HEAD`, with the base resolved as the branch's upstream, then `origin/main`, then a hard failure. Keying to a commit SHA was the simpler alternative and was rejected: a SHA does not change when the outgoing set grows because the remote branch is further behind than the review assumed, and that case ends with a verdict that describes less than what is being pushed.

The script exposes `--print-base` so the dispatch step can produce the diff text without restating the resolution order. That restatement was the alternative, and it would have created two descriptions of one fact free to drift apart — which is the first defect class the reviewer is being built to catch.

## What the reviewer hunts for

Four classes, taken from PRD Decision 66 rather than from Viktor's generic list: a claim whose stated basis is already disproved elsewhere in the repository; a figure that disagrees with the tool that generates it; a reference to a file, script, or flag that no longer exists; an assertion of state with no observation beside it.

Two of Viktor's practices carried across. Every prohibition in the prompt states the failure it prevents, which is what lets his config survive being read by cold-starting agents. And the dispatch step filters findings on agreement rather than severity, because the three defects on record here would all have been labelled minor.

**The prompt deliberately contains no worked examples**, against the general rule that 3–5 diverse examples improve a prompt. The four classes are derived from the same three commits the reviewer is about to be scored against, so examples drawn from them would be answer-key leakage and the benchmark would measure recall rather than review skill. Worth adding once a score exists.

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
