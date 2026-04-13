# Code Review Plugin Evaluation

Evaluated 2026-04-13 against real PR diff (#79) in this repo.

## What the Plugin Does

**Source:** `~/.claude/plugins/marketplaces/claude-plugins-official/plugins/code-review/`

**Invocation:** `/code-review` (slash command, run on a PR branch in a Claude Code session)

**Input:** The current open PR. The plugin fetches the diff, PR description, and relevant CLAUDE.md files using the `gh` CLI.

**Process:**
1. Eligibility check (Haiku agent) — skips closed, draft, trivial, or already-reviewed PRs
2. Collects relevant CLAUDE.md files from the repo
3. Summarizes the PR changes (Haiku agent)
4. Launches 5 parallel Sonnet agents to independently review:
   - Agent 1: CLAUDE.md compliance
   - Agent 2: Bug detection (changes only, not pre-existing issues)
   - Agent 3: Git blame / historical context
   - Agent 4: Prior PR comments that may apply
   - Agent 5: Code comments compliance
5. Scores each issue 0–100 for confidence
6. Filters out issues below 80 confidence threshold
7. Posts a GitHub comment on the PR with high-confidence issues only

**Output format:** A GitHub PR comment with this structure:
```markdown
### Code review

Found N issues:

1. <brief description> (CLAUDE.md says "<...>")

https://github.com/owner/repo/blob/<full-sha>/path/file.ext#L10-L15

2. <brief description> (bug due to <explanation>)

https://github.com/owner/repo/blob/<full-sha>/path/file.ext#L88-L95
```

**Requirements:** `gh` CLI installed and authenticated. No subscription needed.

## Comparison to CodeRabbit

**What both tools cover:**
- Code correctness and bug detection
- Compliance with project conventions (CLAUDE.md / project rules)
- GitHub PR comment posting with code links

**What CodeRabbit adds:**
- Automatic triggering via pre-push hook — no manual invocation
- Inline diff-positioned comments (not just conversation comments)
- Subscription-managed rate limiting and queue

**What the plugin adds:**
- Historical context analysis via git blame (CodeRabbit does not do this)
- Prior PR comment cross-referencing — checks if past feedback applies again
- Code comment compliance — verifies changes match inline code guidance
- No subscription required

**Complementary, not overlapping:** On PR #79, CodeRabbit caught three security/correctness issues (path traversal, staged changes guard, exit code propagation) — all fixed before merge. The plugin found three *different* issues CodeRabbit missed: a GNU date runtime check gap, a `*.md` glob forward-compatibility limitation, and a PROGRESS entry style inconsistency. The tools appear to find different classes of issues.

**Output format differences:**
- CodeRabbit: inline diff comments positioned at the specific changed line
- Plugin: conversation-level comment with GitHub permalink links (functionally equivalent, slightly harder to navigate in a large diff)

## Fit Assessment

**Does it produce findings at a useful granularity?**
Yes. The analysis on PR #79 found 3 real issues above the 80-confidence threshold and filtered 6 false positives correctly. Issue descriptions include: the specific line, a clear explanation of why it's a problem, and a full-SHA GitHub permalink. The confidence scoring is effective — the 78-confidence clone-failure finding was correctly not surfaced because the behavior was intentional design.

**Does it work without a CodeRabbit subscription?**
Yes. The plugin uses the `gh` CLI and Claude agents. There is no external service dependency beyond GitHub itself. No subscription, rate limits, or API keys beyond what's already configured.

**Does invocation fit naturally into the existing git workflow?**
Mostly. The plugin is invoked manually as `/code-review` in a Claude Code session on an open PR branch. This differs from CodeRabbit, which runs automatically via the pre-push hook. For the target use case — a supplement when CodeRabbit is rate-limited — manual invocation is acceptable. The natural workflow becomes: push, see CodeRabbit is rate-limited, run `/code-review` as fallback.

## Recommendation

**Use plugin as-is** (proceed to Milestone 2a).

**Key tradeoff that drove the decision:** The plugin's findings are real and complementary to CodeRabbit's — it finds different issue classes rather than duplicating them. Building a custom skill would mean writing, testing, and maintaining something that already exists and demonstrably works. The manual invocation model is a minor friction cost that is acceptable for a fallback tool. The alternative (building custom) has higher upfront cost and would likely converge on the same architecture anyway, since the plugin's 5-agent design with confidence scoring is already the right approach.

**Note on `pr-review-toolkit`:** A second plugin in the registry (`pr-review-toolkit`) runs 6 specialized agents in-conversation rather than posting to GitHub. It is complementary to `/code-review` (pre-commit local review vs. post-push PR review) but is not a substitute for the CodeRabbit fallback use case since it does not post GitHub comments.
