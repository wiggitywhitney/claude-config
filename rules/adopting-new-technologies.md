# Adopting New Technologies

- Before writing code with a framework, library, or tool that is new to the current project, **stop and invoke `/research <technology>`**. This is mandatory — do not skip it in favor of a quick WebSearch or relying on training data.
- Check `~/.claude/rules/` for an existing rule file covering this technology. If one exists, verify its guidance is current rather than researching from scratch.
- When adopting a new framework, API, or tool pattern in a project, check official documentation for current best practices — prioritizing recency and anything that contradicts common assumptions.
- Document surprises (breaking changes, non-obvious gotchas, patterns that differ from conventions) in a global rule file at `~/.claude/rules/<technology>-gotchas.md` — never a project-level `rules/` directory. If a rule file for the technology already exists, read it, add new findings, and remove stale ones — do not create a duplicate.
- **Every new gotcha file must open with `paths:` frontmatter.** A file with no frontmatter loads into every session regardless of relevance, so an unscoped gotcha file taxes every conversation that will never use it. Write the frontmatter in the same edit that creates the file, not as a follow-up.

  ```markdown
  ---
  paths: ["**/*pino*", "**/logger.*", "**/package.json"]
  ---

  # Pino Gotchas
  ```

  Derive the globs from the new rule's own subject matter rather than copying the ones above — they illustrate the shape, not the content. Scope to the narrowest set of files where the rule would actually change what gets written. Prefer name-based globs (`**/*linkedin*`, `**/otelcol*.y*ml`) over extension-wide ones; reach for an extension-wide glob (`**/*.ts`) only when the rule governs how ordinary source files in that language must be written. Never use `paths: ["**/*"]` — that is not scoping. Verify with `bash scripts/check-rule-frontmatter.sh` from the claude-config repo root, which fails on a missing, doubled, or `**/*` loading mechanism.

  If a technology has no plausible file trigger — the rule is about running a CLI rather than editing anything — do not create a standalone file for it. A file with no glob and no `@`-reference would never load, and the check rejects it. Fold the guidance into an existing always-loaded rule instead, and say in the pull request why no glob applies. Creating a new always-loaded rule is a last resort that needs explicit approval, because every one of them taxes every session.
- **Do not `@`-reference the new file from `CLAUDE.md`.** `@`-reference and `paths:` are alternative loading mechanisms, and a file carrying both loads twice. `@`-reference is reserved for the small set of rules that genuinely apply to every session; gotcha files are on-demand by nature. Instead, add a row to the matching table in `rules/README.md` — one line giving the rule, what triggers it, and what it covers. That index costs nothing per session because it is read on demand.
- Focus on what the model's training data is most likely to get wrong, not what's already well-known.
- Do not document the obvious. Prioritize the surprising.
- Never trust training data for version numbers, API signatures, or configuration defaults when the technology is new to the project or has had recent major releases. Verify against official docs.
- Skip this process when the technology is already established in the project — existing imports, configuration, and tests indicate prior adoption.
