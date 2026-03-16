---
paths: ["**/*"]
description: Process for researching and adopting new frameworks, libraries, and tools
---

# Adopting New Technologies

- Before writing code with a framework, library, or tool that is new to the current project, **stop and research it first**. WebSearch official documentation using the current year. Use `/research <technology>` for thorough investigation.
- Check `~/.claude/rules/` for an existing rule file covering this technology. If one exists, verify its guidance is current rather than researching from scratch.
- When adopting a new framework, API, or tool pattern in a project, check official documentation for current best practices — prioritizing recency and anything that contradicts common assumptions.
- Document surprises (breaking changes, non-obvious gotchas, patterns that differ from conventions) in a path-scoped rule file and reference it from CLAUDE.md using `@path/to/file` import syntax.
- Focus on what the model's training data is most likely to get wrong, not what's already well-known.
- Do not document the obvious. Prioritize the surprising.
- Never trust training data for version numbers, API signatures, or configuration defaults when the technology is new to the project or has had recent major releases. Verify against official docs.
- Skip this process when the technology is already established in the project — existing imports, configuration, and tests indicate prior adoption.
