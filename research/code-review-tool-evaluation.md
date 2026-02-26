# Code Review Tool Evaluation: Codex vs CodeRabbit

Research findings for PRD #5, Milestone 2: evaluation of OpenAI Codex and alternatives as code review tools, compared against CodeRabbit CLI findings from Milestone 1.

---

## Summary

Codex and CodeRabbit are complementary tools, not direct replacements. Codex excels at catching deep logical issues and provides a built-in `/review` command in its CLI; CodeRabbit excels at coding style, conventions, and structured review output. For Whitney's hook-based workflow, **CodeRabbit CLI remains the better fit for pre-PR local review** — it's purpose-built for that use case, while Codex's review is a secondary feature of a general-purpose coding agent that requires a ChatGPT subscription ($20+/mo) on top of any CodeRabbit costs.

---

## Surprises & Gotchas

- **Codex `/review` is NOT a standalone tool** — it's a slash command inside the Codex CLI agent, which itself requires an OpenAI account and ChatGPT subscription. You can't `pip install` or `brew install` a lightweight reviewer. 🟢

- **Codex code reviews count against weekly caps, not hourly** — ChatGPT Plus gets only 10-25 reviews per *week*. That's potentially insufficient for active YOLO-mode development with multiple PRs per day. 🟢

- **`codex exec review` exists but is clunky for CI** — headless review works (`codex exec review --base main`) but output requires jq post-processing. Users report it's "a poor experience for CI/multi-agent workflows." 🟢

- **Codex uses `AGENTS.md` for review configuration**, not `.coderabbit.yaml` — completely different configuration ecosystem. 🟢

- **CodeRabbit + Codex are designed to work together** — CodeRabbit's `--prompt-only` mode was built specifically to feed findings to Codex for auto-fixing. They're officially documented as complementary. 🟡

- **Usage limit bugs are common** — multiple reports of "usage limit reached" errors when dashboard shows remaining capacity. Multi-account setups (personal + business) cause complications. 🟡

---

## Codex CLI `/review` Command

### Overview

The Codex CLI (open source, Rust, [github.com/openai/codex](https://github.com/openai/codex)) includes a built-in `/review` command that launches a dedicated code reviewer. It's read-only and won't modify the working tree.

**Source says:** "The /review command is read-only — Codex analyzes your code and reports findings without touching your working tree" ([Codex CLI Features](https://developers.openai.com/codex/cli/features/))

### Review Presets

The `/review` command offers 4 presets:

1. **Review against a base branch** — picks a local branch, diffs against upstream
2. **Review uncommitted changes** — inspects staged, unstaged, and untracked files
3. **Review a commit** — lists recent commits, reviews the chosen SHA
4. **Custom review instructions** — free-form prompt (e.g., "Focus on accessibility regressions")

### Headless Mode

`codex exec review` supports automation: 🟢

```bash
codex exec review --uncommitted
codex exec review --base main
codex exec review --commit <SHA> --title "..."
```

For structured output, users must "use JSONL mode and extract the last agent_message" via jq post-processing. ([GitHub Issue #6432](https://github.com/openai/codex/issues/6432))

**Interpretation:** This is significantly more friction than `coderabbit review --plain` which gives structured output directly. For a hook integration, CodeRabbit is cleaner.

### Configuration

- **Default model**: Uses current session model (default: gpt-5.3-codex)
- **Override**: Set `review_model` in `config.toml`
- **Review guidelines**: `AGENTS.md` file with a "Review guidelines" section
- **GitHub severity filter**: Only P0/P1 by default; adjustable in `AGENTS.md`

### Review Quality

🟡 Single user comparison report: Codex catches "the deepest logical issues" while CodeRabbit is "unmatched for coding style issues."

**Source says:** "Codex consistently catches the deepest logical issues, while CodeRabbit is still unmatched for coding style issues." ([Jinjing Liang on X](https://x.com/JinjingLiang/status/1989778903582581124))

**Interpretation:** Aligns with the tools' design — Codex is a general coding agent with deep reasoning, CodeRabbit is a purpose-built reviewer focused on conventions and patterns. Single data point; not a systematic comparison.

---

## Codex GitHub Integration

🟢 **`@codex review` in PR comments** triggers a GitHub-native code review. Can also enable automatic reviews on all PRs via [Codex settings](https://chatgpt.com/codex/settings/code-review).

**Source says:** "Mention @codex review in a pull request comment. Codex will react with 👀 and post a standard code review" ([Codex GitHub Integration](https://developers.openai.com/codex/integrations/github/))

### Build-Your-Own with Codex SDK

For CI/CD pipelines, the [Codex SDK cookbook](https://developers.openai.com/cookbook/examples/codex/build_code_review_with_codex_sdk/) documents building custom review pipelines with structured JSON output:

```bash
codex exec "Review my pull request!" --output-schema codex-output-schema.json
```

The structured output schema captures findings with title, body, confidence_score, priority, and code_location (file path + line ranges). Examples provided for GitHub Actions, GitLab CI, and Jenkins.

**Recommended model for DIY reviews:** gpt-5.2-codex.

---

## Pricing Comparison

### Subscription Plans

| Aspect | CodeRabbit | Codex (ChatGPT Plus) | Codex (ChatGPT Pro) |
|---|---|---|---|
| **Monthly cost** | $24/mo (Pro annual) or $30/mo | $20/mo | $200/mo |
| **Review cap** | 8/hour | 10-25/week | 100-250/week |
| **Local CLI** | Yes | Yes | Yes |
| **GitHub reviews** | Yes (automatic) | Yes (`@codex review`) | Yes |
| **Free tier** | 2 CLI reviews/hour | Limited trial | N/A |

🟢 **CodeRabbit Pro is more cost-effective for frequent reviews**: 8/hour (~192/day at max rate) vs 10-25/week for similar monthly cost.

### API Token Pricing (per 1M tokens, standard tier)

| Model | Input | Cached Input | Output |
|---|---|---|---|
| gpt-5.3-codex | $1.75 | $0.175 | $14.00 |
| gpt-5.2-codex | $1.75 | $0.175 | $14.00 |
| gpt-5.1-codex-mini | $0.25 | $0.025 | $2.00 |
| codex-mini-latest | $1.50 | $0.375 | $6.00 |

🟡 **Codex API route is flexible but expensive**: gpt-5.3-codex output at $14/1M tokens. A detailed review generating 2K output tokens costs ~$0.03 per review, but requires building the entire integration pipeline (out of scope per PRD #5).

### Credit Costs (ChatGPT plans)

| Task Type | gpt-5.3-codex | gpt-5.1-codex-mini |
|---|---|---|
| Local message | ~5 credits | ~1 credit |
| Cloud task | ~25 credits | N/A |
| Code review | ~25 credits | N/A |

---

## Integration Complexity

| Aspect | CodeRabbit CLI | Codex CLI `/review` | Codex API (DIY) |
|---|---|---|---|
| **Install** | `curl \| sh` + browser auth | Rust binary + OpenAI account | SDK + custom code |
| **Hook integration** | `coderabbit review --plain` | `codex exec review --base main` + jq | Custom script |
| **Output format** | Structured plain text | Unstructured (needs jq) | JSON (you define schema) |
| **Config file** | `.coderabbit.yaml` | `AGENTS.md` + `config.toml` | Custom |
| **Auth** | Browser token | OpenAI API key + ChatGPT sub | API key only |
| **Claude Code plugin** | Yes (`/coderabbit:review`) | No | N/A |
| **Dependencies** | Single binary | Rust binary + OpenAI account | OpenAI SDK |

---

## CodeRabbit + Codex Complementary Workflow

The tools are officially documented as complementary, not competing:

**Source says:** "The integration creates a tight feedback loop: CodeRabbit analyzes your code changes and surfaces specific issues, then Codex applies the fixes based on CodeRabbit's context-rich feedback." ([CodeRabbit Codex Integration](https://docs.coderabbit.ai/cli/codex-integration))

The workflow:
1. Ask Codex to implement a feature
2. Run `coderabbit --prompt-only` for token-efficient analysis
3. Codex reads CodeRabbit's findings and auto-fixes
4. Iterate until critical issues are resolved

CodeRabbit's `--prompt-only` mode delivers "succinct issue context" with "token-efficient formatting" optimized for AI agent consumption.

---

## Other Alternatives

### Qodo Merge (formerly CodiumAI) 🟡

- Open-source PR-Agent, fully self-hostable
- CLI tool available for terminal-based review
- Supports GitHub, GitLab, Bitbucket, Gitea
- Deep multi-repository understanding with cross-repo impact analysis
- Worth evaluating if self-hosting becomes important
- **Not hands-on tested** — noted for future reference

### GitHub Copilot PR Review 🟡

- Native GitHub integration, zero setup
- Review comments appear like human reviewer feedback
- Included with Copilot subscription
- Basic compared to CodeRabbit/Codex but friction-free
- **Not hands-on tested**

### Other Notable Tools

- **Cubic.dev** — claims deeper architectural understanding than CodeRabbit
- **Kodus "Kody"** — open-source AI code review agent
- **Sourcery** — free tier + on-prem option

None of these were hands-on tested for this evaluation.

---

## Known Issues & Limitations

### Codex-Specific

1. **Weekly review caps are restrictive**: 10-25/week on Plus is insufficient for active development with multiple daily PRs. 🟢
2. **Usage limit bugs**: Multiple reports of false "limit reached" errors. Multi-account setups cause complications. ([OpenAI Community](https://community.openai.com/t/code-review-usage-limit-issue/1370181), [GitHub Discussion #8503](https://github.com/openai/codex/discussions/8503)) 🟡
3. **CI output is unstructured**: `codex exec review` requires jq post-processing for structured data. 🟢
4. **Frontend framework weaknesses**: Some users report "frequent mistakes on basic tasks" with React and similar frameworks. 🟡
5. **No Claude Code plugin**: Unlike CodeRabbit, Codex has no native Claude Code integration. 🟢

### Compared to CodeRabbit CLI

1. **No conversation threading**: Codex CLI output is one-shot; no resolution tracking
2. **Different config ecosystem**: `AGENTS.md` vs `.coderabbit.yaml`
3. **Requires separate subscription**: ChatGPT Plus/Pro on top of any existing CodeRabbit plan
4. **No incremental review**: Each run is independent; no automatic re-review on push

---

## Recommendation

**Keep CodeRabbit as the primary code review tool.** Codex is not a CodeRabbit replacement. Here's why:

1. **Codex is a coding agent, not a code reviewer.** Its `/review` is a feature, not the product. CodeRabbit's entire purpose is code review, and it shows in output quality, structured formatting, and hook-friendliness.

2. **Rate limits kill the Codex-as-reviewer use case.** 10-25 reviews/week on the $20/mo plan is insufficient for active development. CodeRabbit Pro's 8/hour is far more suitable.

3. **Integration complexity favors CodeRabbit.** `coderabbit review --plain --base main` gives clean, structured output. Codex requires jq post-processing or building a custom pipeline.

4. **They're complementary by design.** CodeRabbit's `--prompt-only` mode was built to feed Codex. The documented best practice is to use both together, not choose one.

**For PRD #5's goal of reducing merge cycle latency**: The answer is CodeRabbit CLI as a pre-push hook (catching issues before PR creation), keeping the GitHub review as a final gate. Codex doesn't solve the latency problem — it creates a different one (weekly rate limits).

---

## Caveats

- Codex pricing and limits change frequently — the credit system has been revised multiple times. Verify current limits before any integration decision.
- The "Codex catches deeper logical issues" claim is from a single user report, not a systematic comparison.
- Codex API route could work for teams willing to build custom tooling, but that's explicitly out of scope for PRD #5 ("not building a custom code review tool").
- Qodo Merge was not hands-on tested — it's noted as a potential future alternative if self-hosting becomes a requirement.
- Confidence tags: 🟢 high (verified against primary source) / 🟡 medium (single source or indirect) / 🔴 low (inferred or conflicting)

---

## Sources

- [Codex CLI Features](https://developers.openai.com/codex/cli/features/) — `/review` command details, presets, models
- [Codex Pricing](https://developers.openai.com/codex/pricing/) — subscription tiers, credit costs, review caps
- [OpenAI API Pricing](https://developers.openai.com/api/docs/pricing/) — per-token costs for all Codex models
- [Build Code Review with Codex SDK](https://developers.openai.com/cookbook/examples/codex/build_code_review_with_codex_sdk/) — DIY review pipeline, structured output schema, CI examples
- [Codex GitHub Integration](https://developers.openai.com/codex/integrations/github/) — `@codex review`, automatic reviews, `AGENTS.md` config
- [CodeRabbit Codex Integration](https://docs.coderabbit.ai/cli/codex-integration) — complementary workflow, `--prompt-only` mode
- [GitHub: codex exec review issue #6432](https://github.com/openai/codex/issues/6432) — headless review status, CI friction
- [Jinjing Liang on X](https://x.com/JinjingLiang/status/1989778903582581124) — Codex vs CodeRabbit review quality comparison
- [GitHub: openai/codex](https://github.com/openai/codex) — open-source Rust CLI, Apache-2.0
- [OpenAI Community: Code Review Usage Limit Issue](https://community.openai.com/t/code-review-usage-limit-issue/1370181) — usage limit bugs
- [GitHub Discussion #8503](https://github.com/openai/codex/discussions/8503) — false "limit reached" errors
- [Qodo AI Code Review Tools 2026](https://www.qodo.ai/blog/best-ai-code-review-tools-2026/) — alternatives landscape

---

*Research conducted 2026-02-25 for PRD #5, Milestone 2.*
