---
description: Dispatch the diff-reviewer sub-agent against a diff and report what it finds. Read-only; nothing gates on the result.
---

Get a second read on a diff before it goes anywhere. Nothing enforces this — you run it when you want it.

## Process

**Step 1 — decide what is being reviewed, and say so.** Usually the outgoing work:

```bash
git diff @{upstream}...HEAD
```

If the branch has no upstream, use `origin/main...HEAD` instead. For a single commit, `git show <sha> --format=` is the exact form to hand over.

**Step 2 — check the size before dispatching.** Count the diff lines. Beyond roughly a thousand, the reviewer runs out of turns and returns something that looks like a clean result but is a truncated one — measured on 2026-08-25, where two of three runs stopped at the cap and reported almost nothing. Split a large diff into coherent groups — files that change together for one reason, such as a script and its test, or a config and the code that reads it — rather than one file per part. A mechanical per-file split can separate the two halves of a producer-consumer defect (the exact class of thing this reviewer hunts for) into different parts, where neither part alone shows the mismatch.

**Step 3 — dispatch the reviewer.** Spawn the `diff-reviewer` sub-agent, giving it the diff text or the exact command that produces it. It cold-starts with none of this conversation, so the task string carries the context: the diff, the branch, and the base. Do not summarize the diff for it — a summary is the author's reading of the change, which is the reading under review.

**Step 4 — check that it finished.** The reviewer ends with `FINDINGS: <n>`. If it returns `FINDINGS: INCOMPLETE`, or no such line, it ran out of room: re-dispatch the unreviewed part rather than reporting a count from a partial pass. If the diff was split, every part needs its own count, and overlapping findings on the same file and line are merged before reporting a total.

**Step 5 — resolve on agreement, not severity.** Decide whether you agree with each finding. Blockers, suggestions, and nits get the same filter: agree and fix it, or disagree and say why. Do not triage by severity — the label is the reviewer's guess, and the defects this reviewer exists to catch would all have been labelled minor.

**Step 6 — report the findings and what you did about them.** That is the whole output. Nothing is recorded, and no push or commit depends on it.

## What this is and is not

It is a same-vendor second read, tuned to four defect classes this repository has actually shipped. Scored 2026-08-25 against three real ones: it caught the two where a claim contradicted evidence written elsewhere, and missed the logic error in a shell loop — which it inspected and declared sound. **Trust it on assertions; do not treat silence on code as a clean bill of health.**

CodeRabbit remains the stronger check: different vendor, no truncation at 15,000 lines, and it runs at push time already. This is for the moment before that, when you want a read without waiting.
