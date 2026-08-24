---
description: Dispatch the diff-reviewer sub-agent against the outgoing diff and record a verdict the push gate accepts.
---

Review the outgoing diff before it is pushed, then record the verdict.

## Process

**Step 1 — identify the diff.** Get the verdict key and the base it was measured against from the same script, so the diff you review and the key you record cannot describe different things:

```
scripts/compute-diff-key.sh
scripts/compute-diff-key.sh --print-base
```

Produce the diff text with `git diff <base>...HEAD`, using the base that second command printed. Do not work out the base yourself — the script owns that resolution, and a second copy of the rule in your head is free to disagree with it.

If it exits non-zero, stop and report why. A key that cannot be computed means the push gate cannot be satisfied, and inventing a base would produce a verdict describing the wrong diff.

**Step 2 — dispatch the reviewer.** Spawn the `diff-reviewer` sub-agent with the full outgoing diff in its prompt. It cold-starts with none of this conversation, so the task string carries the context: the diff itself, the branch, and the base it is measured against. Do not summarize the diff for it — a summary is the author's reading of the change, which is the reading under review.

**Step 3 — read the findings yourself before recording anything.** The reviewer returns a list and a `FINDINGS: <n>` line.

If it returns `FINDINGS: INCOMPLETE`, or returns no such line at all, the review did not finish. Do not record a verdict: the gate cannot tell a partial review from a clean one, so recording it would let unreviewed content through. Dispatch again, splitting the diff by file if it was too large to finish in one run.

**Step 4 — resolve on agreement, not on severity.** Work through every finding and decide whether you agree with it. Blockers, suggestions, and nits are all subject to the same filter: agree, and fix it; disagree, and say why in the notes. Shipping past a finding you agree with needs a stated reason, not silence. Do not triage by severity — the severity label is the reviewer's guess, and the three defects this reviewer exists to catch would all have been labelled minor.

**Step 5 — record the verdict.** If fixing findings changed the diff, the key changed with it: recompute it and dispatch a fresh review rather than recording the old verdict against new content. Then:

```
scripts/record-diff-review.sh --findings <n> --notes "<what you resolved and what you disagreed with>"
```

**Step 6 — report, and leave the push to the author.** This command does not push. Report the finding count, what was fixed, and what was disagreed with, and say the verdict is recorded. If a later push is still blocked, the diff moved after the review was recorded, which is the gate working rather than failing.

## What this does not do

The gate checks that a review happened, not that its findings were resolved — that filter is Step 4 and it is convention, enforced by nothing. Say so in the notes when you ship past a finding, so the record shows the decision was made rather than missed.
