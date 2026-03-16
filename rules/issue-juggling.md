---
paths: ["**/*"]
description: Autonomous issue queue workflow for juggling multiple GitHub issues
---

# Issue Juggling

When told to "juggle" issues or work through a queue of issues autonomously:

- Each issue gets its own feature branch and PR.
- For each issue: create branch, write failing tests first, implement fix, run full suite, push, create PR.
- The pre-push hook runs CodeRabbit CLI review (advisory). Address any CLI findings before creating the PR — these are cheaper to fix pre-PR than post-PR.
- Start 7-minute background timer for CodeRabbit PR review. Address findings, push fixes, start another timer for re-review.
- After merge, switch to main, pull, move to next issue. Clean up merged branches at the end.
- If an issue is blocked, skip it and flag it when presenting status.
