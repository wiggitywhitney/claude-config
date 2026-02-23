# /research - Structured Technical Research

Research a topic, technology, or question using web search and documentation. Produces a concise synthesis with cited sources — not a raw data dump.

## When to Use /research

- Evaluating a technology or tool for a project
- Comparing alternatives (e.g., "Redis vs Valkey", "uv vs poetry")
- Investigating a concept or architecture pattern
- Finding current documentation for an API or library
- Answering "how does X work?" or "what's the best way to do Y?"
- **Adopting a new technology** into an existing project (see Phase 5 below)

## Invocation

User says: `/research <topic or question>`

## Research Process

### Phase 1: Scope the Question
1. Restate the research question clearly
2. Identify 2-3 specific sub-questions to investigate
3. Note what context exists locally (current project stack, constraints)
4. Check `~/.claude/rules/` for an existing rule file covering this technology — if one exists, read it and note what it already covers

### Phase 2: Search and Gather
1. **WebSearch** for the primary question using current year for recency — prioritize latest GA'd version numbers
2. **WebFetch** the top 2-3 most relevant results (official docs, reputable sources)
3. If comparing alternatives, search for each independently
4. If the topic relates to the current codebase, **Glob/Grep** to understand existing usage
5. Prefer primary sources: official documentation and scientific studies > blog posts > forums > AI summaries
6. **Explicitly search for known issues, breaking changes, and migration gotchas** — these are the highest-value findings
7. **Verify before citing**: For each claim you plan to include, **WebFetch and read the specific page** you are citing. Do not cite a URL you have not fetched and read in this session.

### Phase 3: Synthesize
1. Distill findings into a concise summary (not a raw paste of web content)
2. For comparisons, use a structured table with clear criteria
3. For how-to questions, provide a concrete example
4. For evaluations, state a clear recommendation with rationale
5. **Separate the surprising from the obvious** — lead with findings that contradict common assumptions, recent breaking changes, or gotchas that tutorials skip over. Do not waste space on what any experienced developer would already know.
6. **Separate source claims from interpretation** — clearly distinguish what the sources actually say from your synthesis or inference. For example, if the Aider docs say whole mode is "easiest," do not restate that as "most reliable" — those are different claims. Quote the source, then offer your interpretation separately.
7. **Cite exact quotes** — for each factual claim, include the exact quote from the source with the URL. This forces verification against the actual source rather than synthesis from memory.

### Phase 4: Present
1. Lead with the answer or recommendation
2. Support with evidence from sources
3. Include a **Sources** section with URLs
4. Flag anything uncertain or conflicting across sources
5. **Flag confidence levels** — mark each finding as **high**, **medium**, or **low** confidence based on source quality and corroboration

### Phase 5: Document Adoption Gotchas (when researching for a new project adoption)
If the research is for a technology being introduced into a project:
1. Collect all surprises, breaking changes, non-obvious defaults, and gotchas into a path-scoped rule file (e.g., `rules/kubebuilder-gotchas.md` with appropriate `paths:` frontmatter)
2. Keep it concise — bullet points, not a tutorial. Only what would bite someone who assumed training-data knowledge was sufficient.
3. Reference the rule file from the project's `CLAUDE.md` using `@path/to/file` import syntax
4. If an existing rule file in `~/.claude/rules/` covers this technology, note any discrepancies between the rule file and current official docs

## Output Format

```markdown
## Research: {topic}

### Summary
{1-3 sentence answer or recommendation}

### Surprises & Gotchas
{Findings that contradict common assumptions or training data — the highest-value section}

### Findings
{Structured findings — tables for comparisons, bullets for facts.
 Each finding includes a confidence tag: 🟢 high / 🟡 medium / 🔴 low.
 For each factual claim, include the exact quote and source URL.}

**Source says:** "{exact quote}" ([Source Title](URL))
**Interpretation:** {your synthesis or inference, clearly separated}

### Recommendation
{Clear recommendation with rationale, if applicable}

### Caveats
{Limitations, version constraints, things to watch out for}

### Sources
- [Source Title](URL) — {one-line note on what it provided}
- [Source Title](URL) — {one-line note}
```

## Key Principles

- **Answer first, evidence second** — lead with the recommendation, not five paragraphs of background
- **Surprises over basics** — prioritize what training data gets wrong. Breaking changes, deprecated-but-still-taught patterns, and non-obvious defaults are more valuable than "here's how to install it"
- **Cite exact quotes with URLs** — every factual claim must include the exact quote from the source and the URL. This forces verification against the actual source rather than synthesis from memory.
- **Read what you cite** — before including a source, WebFetch and read the specific page. Do not cite URLs you have not fetched and read in this session.
- **Source vs. interpretation** — clearly separate what the sources actually say from your inference. If the docs say X is "easiest," do not restate that as "most reliable" without flagging the reinterpretation.
- **Flag confidence** — mark each finding as high/medium/low confidence. High = verified against primary source. Medium = single source or indirect. Low = inferred or conflicting sources.
- **Never trust training data** — always WebSearch for versions, API signatures, configuration defaults, and "recommended" patterns. The model's knowledge has a cutoff and frameworks move fast. Prioritize latest GA'd version numbers.
- **Respect the stack** — frame recommendations within the existing toolchain (TypeScript, Go, Python, Kubebuilder, Shell, YAML)
- **Be opinionated** — "it depends" is not a useful answer. State a recommendation, then note when the alternative is better

## Tools Used

- WebSearch (primary research)
- WebFetch (reading specific pages)
- Glob, Grep, Read (local codebase context)
- Write (rule files for gotchas documentation, when adopting new tech)
