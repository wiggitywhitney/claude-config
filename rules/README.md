---
paths: ["rules/**/*.md", "**/.claude/rules/**/*.md"]
description: Index of every rule file, how each one loads, and what it covers
---

# Rules Index

Every file in this directory reaches a Claude Code session through exactly one mechanism. This index records which one, and what each rule covers. It lives here rather than in `global/CLAUDE.md` because an index in `CLAUDE.md` costs tokens in every session, whether or not anyone needs it.

`scripts/check-rule-frontmatter.sh` enforces the one-mechanism requirement, with tests in `tests/check-rule-frontmatter.bats`.

## The two mechanisms

**`paths:` frontmatter — loads on demand.** The rule enters context when you read or edit a file matching one of its globs, and stays out otherwise. This is the default for anything technology-specific.

```markdown
---
paths: ["**/*pino*", "**/logger.*", "**/package.json"]
---

# Pino Gotchas
```

**`@`-reference from `global/CLAUDE.md` — loads in every session.** Reserved for rules whose trigger is an *action* rather than a file type: running git, adopting a technology, touching infrastructure. Path scoping cannot express "the user is about to run a git command," so these stay always-loaded.

Never both — a file carrying both loads twice. Never neither — a file with no frontmatter loads unconditionally, which is the same cost as an `@`-reference without the deliberate choice. Never `paths: ["**/*"]`, which re-injects on every file read.

## Always loaded (`@`-referenced from `global/CLAUDE.md`)

| Rule | Covers |
|---|---|
| `aboutme-headers.md` | ABOUTME header requirement for code files, and which types are exempt |
| `adopting-new-technologies.md` | The `/research` process, and the frontmatter requirement for new gotcha files |
| `datadog-environment.md` | AI Gateway env vars, and stripping them so subprocesses reach the Anthropic API |
| `gh-fork-gotchas.md` | `gh pr create` targeting upstream instead of the fork |
| `git-workflow.md` | Branching, CodeRabbit review process, triage rubric, commit conventions |
| `infrastructure-safety.md` | Backups, permission gates, cloud resource lifecycle |
| `issue-juggling.md` | Autonomous multi-issue workflow |
| `macos-image-processing.md` | `sips` and filenames with spaces, screenshot narrow no-break space |
| `testing-rules.md` | TDD cycle, always/never lists, test tier requirements |
| `vals-secrets.md` | Injecting secrets with `vals exec` instead of extracting them |
| `writing-voice.md` | Whitney's voice rules for anything she puts her name on |

## Loaded on demand (`paths:`-scoped)

### Observability and OpenTelemetry

| Rule | Fires on | Covers |
|---|---|---|
| `otel-semconv-gotchas.md` | instrumentation, otel, semconv, telemetry, tracing files | Stable vs incubating entry-points, DB/HTTP attribute renames, deprecated `SEMATTRS_*` |
| `otel-logs-bridge-gotchas.md` | instrumentation, logger, otel files, `package.json` | `sdk-logs` still experimental, `console.log` has no automatic bridge, init order, `traceBased` drops |
| `otel-span-metrics-connector-gotchas.md` | collector YAML, span-metric files | Cardinality limit defaults to unlimited, ms→s unit gate, Exemplars not TraceId, sampler placement |
| `ddot-gotchas.md` | collector and Datadog YAML, ddot files | Agent-embedded not standalone, curated component list, `routingprocessor` removed in v7.71.0 |
| `datadog-span-based-metrics-gotchas.md` | collector YAML, span-metric files, instrumentation | Auto vs custom metrics, fixed tag set, `trace.*` namespace collision, filter vs group-by cardinality |
| `datadog-log-trace-gotchas.md` | instrumentation, logger, otel files, `.vals.yaml` | 64-bit decimal `dd.trace_id` not required, `service.name` not auto-remapped, OTLP vs file pipeline |
| `weaver-gotchas.md` | weaver files, `registry_manifest.y*ml`, `live-check*.ts` | v0.22.1 auto-escaping defaults, definition schema format, `HOME` propagation to subprocesses |
| `is-scoring-gotchas.md` | `evaluation/`, collector YAML, `.vals.yaml` | Binary preferred over Docker, required Docker flags, port 4318 conflict, LaunchAgent setup |
| `pino-gotchas.md` | pino, logger, instrumentation files, `package.json` | v10 is current, IITM ESM loader hook on Node v22+, MCP servers must log to stderr |

### Publishing and media

| Rule | Fires on | Covers |
|---|---|---|
| `linkedin-api-gotchas.md` | linkedin files | Silent `commentary` truncation on unescaped reserved characters, alt text is write-only |
| `social-video-upload-gotchas.md` | bluesky, mastodon, linkedin, video, social files | Bluesky service token audience, Mastodon async 202 poll, LinkedIn four-step upload and ETag stripping |
| `microblog-api-gotchas.md` | microblog files, `src/**/*.js` | Dual auth tokens, `editPage` parameter order, feed-based cross-posting |
| `yt-dlp-gotchas.md` | yt-dlp, youtube files, workflow YAML | Format selectors, ffmpeg-absent merge exits 0, PO tokens, Chrome cookies unreadable |
| `presentation-slides.md` | `.qmd`, `slides/`, `_quarto.y*ml`, `custom.scss` | Progressive reveal patterns, readability at conference scale, speaker notes voice |
| `quarto-revealjs-capabilities.md` | `.qmd`, `_quarto.y*ml`, `slides/`, `custom.scss` | What the slide stack can do — layout, animation, backgrounds, Mermaid, presenter tools |
| `mmdc-gotchas.md` | `.mmd`, `.qmd`, `slides/` | Puppeteer peer dependency, Apple Silicon Chrome path, `npx -p` flag, invisible long labels |

### Tooling and platform

| Rule | Fires on | Covers |
|---|---|---|
| `typescript-cli-gotchas.md` | `tsconfig*.json`, tsc files, `verify.json` | TS5112 hard error in 6.x, `--ignoreConfig` version gate, errors go to stdout |
| `sharp-gotchas.md` | `.js`, `.ts`, `package.json` | Node >= 20.9.0, Homebrew libvips triggers a source build, `fit: inside` must be explicit |
| `kyverno-gotchas.md` | YAML, kyverno files | Version numbering, GKE firewall, subjects matching |
| `datadog-mcp-gotchas.md` | `.mcp.json`, settings files | Official plugin install, OAuth vs key-based auth, `vals exec` incompatibility, `env` block bug |
| `gog-cli-gotchas.md` | gog files, `gogcli-safety-hook.py` | `--help` false positive in the safety hook, `--values-json` flag, `docs find-replace` unreliability |
| `eval-github-pat.md` | `evaluation/`, `.vals.yaml`, spiny-orb files | Fine-grained PAT setup, dry-run verification against a non-existent branch |
| `bats-bash-testing.md` | `.bats`, `tests/**/*.sh` | `assert_output` is not built in, `run` subshell semantics, mock bleed into bats internals |
| `hooks-reference.md` | `.claude/`, `hooks/`, `.sh` | What every native git hook and Claude Code hook checks |
| `branch-protection.md` | branch-protection files, `CLAUDE.md` | The docs-only exemption and its exact conditions |
| `prd-dependency-management.md` | `prds/**/*.md`, `PROGRESS.md` | Recovering from cross-PRD dependencies |

### Language rules

`languages/go.md`, `languages/javascript.md`, `languages/python.md`, `languages/shell.md`, and `languages/typescript.md` are each scoped to their own file extension.

## Adding a rule

Write the `paths:` frontmatter in the same edit that creates the file, scoped to the narrowest set of files where the rule would change what gets written. Prefer name-based globs (`**/*linkedin*`) over extension-wide ones; reach for `**/*.ts` only when the rule governs how ordinary source files in that language must be written. Then add a row to the table above.

If a technology has no plausible file trigger — the rule is about running a CLI rather than editing anything — say so in the pull request rather than inventing a glob that will never match.
