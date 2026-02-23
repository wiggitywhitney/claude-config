---
name: write-prompt
description: Write high-quality system prompts for AI agents or Claude Code skills
argument-hint: "[review|migrate]"
---

# /write-prompt — Structured Prompt Engineering

Write high-quality system prompts for AI agents or Claude Code skills. Guides through building or reviewing prompts using validated research on what actually works.

## When to Use /write-prompt

- Writing a system prompt for an API call (Messages API, Bedrock, etc.)
- Writing a Claude Code skill (SKILL.md file)
- Reviewing an existing prompt or skill for anti-patterns
- Adapting a prompt from one model generation to another (e.g., Claude 4.5 → 4.6)

## Invocation

- `/write-prompt` — start the guided workflow
- `/write-prompt review` — review an existing prompt or skill the user provides
- `/write-prompt migrate` — adapt an existing prompt for a different model

## Phase 1: Gather Context

Ask the user these questions before generating guidance. Present them together using AskUserQuestion.

1. **Prompt type**: Are you writing a system prompt for an API call, or a Claude Code skill?
2. **Target model**: What model will this run on? (Claude Opus 4.6, Claude Sonnet 4.6, Claude 4.5/Haiku 4.5, other/unknown)
3. **Task type**: What kind of task? (Code transformation, analysis/reasoning, content generation, tool-using agent, interactive workflow)
4. **Starting point**: Are you starting from scratch, or do you have an existing prompt to improve?

If the user provides an existing prompt, go to Phase 3 (Review). Otherwise, proceed to Phase 2.

## Phase 2: Build the Prompt

Guide the user through building the prompt section by section. For each section, explain what it should contain, ask the user for their specific content, then help them refine it.

### Section ordering for system prompts (API calls)

Build the prompt in this order:

1. **Role and constraints** — Who the model is, what it must not do, scope boundaries
2. **Context / schema / reference material** — Background the model needs to do the job
3. **Explicit rules** — Enumerated instructions, numbered for clarity
4. **Examples** — 3-5 diverse examples (see Examples guidance below)
5. **Input data** — Where the user's input will go (use XML tags or clear delimiters)
6. **Output format specification** — The most precise section; exact format, what to include/exclude, what constitutes failure
7. **Operational metadata** — Model identity, version constraints, any runtime notes

### Section ordering for Claude Code skills

Skills run inside Claude Code, which already has its own system prompt, personality, and tool access. Adjust accordingly:

1. **Purpose and invocation** — What the skill does, how it's triggered, what arguments it accepts
2. **Workflow steps** — Procedural, numbered phases. Emphasize the *process to follow* rather than stating the goal upfront. This is critical for skills — Claude Code follows procedures more reliably than it infers intent from goals.
3. **Rules and constraints** — Enumerated. Use negative constraints ("Do NOT...") for known failure modes. Use format specifications for completeness requirements.
4. **Output format** — What the skill produces and how it should be structured
5. **Quality checklist** — A list the skill checks before presenting output to the user

Skills do NOT typically need:
- Role framing (Claude Code already has one) — unless the skill requires behavior that differs from Claude Code's defaults
- Examples for output format anchoring — instead, reference style files on disk for skills that produce formatted content
- Input data section — skills receive input interactively

### Guiding each section

For each section, do the following:

1. Explain what belongs here (1-2 sentences)
2. Ask the user for their specific content
3. Draft the section based on their input
4. Flag any of the five missing information categories (see below) that aren't yet addressed
5. Move to the next section

After all sections are drafted, present the complete prompt and run the anti-pattern check (Phase 3).

## Phase 3: Review for Anti-Patterns and Missing Information

### Five categories of missing information

Check the prompt for these five categories that cause incorrect output (from Nam et al., "Prompting LLMs for Code Editing: Struggles and Remedies", April 2025, FORGE '26):

1. **Missing specifics** — The prompt says what to do but omits concrete details. "Refactor this function" without specifying which pattern, target structure, or what to preserve.
2. **Missing operationalization plan** — The prompt states a goal but doesn't break it into steps. "Add error handling" without specifying where, what to catch, what to do in each case.
3. **Faulty scope/localization** — The prompt doesn't clearly identify which parts to modify and which to leave alone.
4. **Missing codebase context** — The prompt doesn't include surrounding code, types, imports, or conventions the model needs.
5. **Missing output format** — The prompt doesn't specify what the output should look like — full file, diff, just the changed function, with or without fences.

For each gap found, explain what's missing and ask the user how to fill it.

### Anti-patterns to flag

Flag these if present. Explain why each is harmful and suggest a replacement.

**Emotional/motivational language (always flag):**
- Tipping promises ("$200 tip for correct answer")
- Disability/accessibility claims used as motivation ("I'm blind and can't read truncated code")
- Threat-based motivation ("If you truncate code, bad things will happen")
- Emotional appeals ("This is very important to my career")

These produce worse benchmark scores than baseline prompts. Format design choices have far more impact than motivational language. (Source: Aider unified diff research, https://aider.chat/2023/12/21/unified-diffs.html)

**Model-version-dependent anti-patterns (flag based on target model):**

For Claude 4.6 models only:
- Vague anti-laziness directives ("do not be lazy", "try harder") — these are motivational language that amplifies already-proactive behavior, causing runaway thinking or write-then-rewrite loops. Instead, use explicit depth instructions ("comprehensive", "include edge cases") or format specifications ("Output format: complete source file. Files containing placeholder comments will fail validation."). (Sources: [Anthropic best practices](https://claude.com/blog/best-practices-for-prompt-engineering), [platform release notes](https://platform.claude.com/docs/en/release-notes/overview))
- Explicit think-tool instructions ("use the think tool to plan your approach") — these cause over-planning. The model thinks effectively without being told to. Use the `effort` API parameter (`output_config.effort`: low/medium/high/max) to control thinking depth instead of `budget_tokens`, which is deprecated for 4.6 models.
- Aggressive tool-use language ("You MUST use [tool]", "If in doubt, use [tool]") — replace with "Use [tool] when it would enhance your understanding of the problem." Claude 4.x models overtrigger on aggressive language.
- Prefilled responses on the last assistant turn — Opus 4.6 does not support prefilling assistant messages, and prefilling is incompatible with extended thinking. Use structured outputs (`output_config.format`), XML tags, or direct instructions instead. (Source: [Feb 5, 2026 release notes](https://platform.claude.com/docs/en/release-notes/overview))

For Claude 4.5 and earlier:
- The word "think" in Claude Code contexts when extended thinking is off — Claude Code treats "think" as a request for deeper extended thinking. In the raw API, extended thinking is controlled via the `thinking` parameter, not prompt wording. For Claude Code skills, replace with "consider", "evaluate", or "assess" unless you intend to trigger deeper thinking.

**Structural anti-patterns (always flag):**
- Single "golden" example instead of 3-5 diverse examples — risks overfitting to that example's details
- Positive aspirations without negative constraints — "Write clean code" is less effective than "Do NOT refactor existing code. Do NOT hallucinate imports not in the allowlist."
- Vague output format — "Return the result" instead of specifying exact format, delimiters, what to include/exclude
- Goal-first structure in skills — skills should lead with process steps, not goals. The user's global CLAUDE.md says: "When creating prompts for AI agents, emphasize the process to follow rather than stating the goal upfront."

### Known code transformation failure modes

When the prompt involves code transformation, check for guards against these documented failure modes (from Khati et al., "Detecting and Correcting Hallucinations in LLM-Generated Code", FORGE '26):

- Mis-typed API calls (incorrect method signatures, wrong parameter types): ~55% of hallucinations
- Hallucinated imports (inventing packages that don't exist): ~24%
- Incomplete edits / truncation: common with large inputs
- Lost semantics (subtly changing behavior while modifying code)
- Lazy code / elision ("// ... rest of function" placeholders)
- Variable shadowing

For each applicable failure mode, suggest a specific negative constraint to add.

## Examples Guidance

When the prompt needs examples, guide the user to create effective ones:

- **3-5 examples minimum** — more examples = better performance, especially for complex tasks (Anthropic multishot prompting docs)
- **Diverse** — cover happy path, edge cases, and cases where the model should NOT act (skip/refuse)
- **Carefully crafted** — bad examples are worse than no examples. Claude takes them literally.
- **Wrapped in XML tags** — use `<example>` tags nested within `<examples>` for structure
- **No single golden example** — one perfect example risks overfitting to its specific details

## Chain-of-Thought Guidance

When to recommend CoT:
- Analysis, reasoning, multi-step problems, decisions with tradeoffs
- Complex math, multi-step analysis, writing complex documents

When to recommend skipping CoT:
- Well-constrained transformations with explicit rules
- Repetitive format-following tasks
- Tasks where the output format is fully specified

For Claude 4.6 specifically: do NOT add CoT instructions to the prompt. Use the `effort` API parameter instead. The model's adaptive thinking handles this automatically. Adding explicit thinking instructions causes runaway thinking or write-then-rewrite loops.

(Source: Anthropic chain-of-thought docs, https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought)

## Output Format

When reviewing a prompt, present findings as:

```markdown
## Prompt Review: {brief description}

### Missing Information
{List each of the 5 categories with status: addressed / missing / partially addressed}

### Anti-Patterns Found
{Each anti-pattern with explanation, severity, and suggested fix}

### Model-Specific Issues
{Issues specific to the target model}

### Strengths
{What the prompt does well}

### Suggested Revision
{The revised prompt, or specific sections to change}
```

## Sources

All guidance in this skill is sourced from:

- Anthropic prompt engineering docs — https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview
- Anthropic Claude 4.6 best practices — https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/claude-4-best-practices
- Anthropic multishot prompting — https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/multishot-prompting
- Anthropic chain-of-thought — https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/chain-of-thought
- Nam et al., "Prompting LLMs for Code Editing: Struggles and Remedies", April 2025 — https://arxiv.org/abs/2504.20196
- Khati et al., "Detecting and Correcting Hallucinations in LLM-Generated Code", FORGE '26 — https://arxiv.org/abs/2601.19106
- Aider unified diff research — https://aider.chat/2023/12/21/unified-diffs.html
- Osmani, "My LLM Coding Workflow going into 2026" — https://addyosmani.com/blog/ai-coding-workflow/
- Hertwig, "Code Surgery" — https://fabianhertwig.com/blog/coding-assistants-file-edits/
