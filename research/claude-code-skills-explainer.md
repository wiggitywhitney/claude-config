# Claude Code Skills: What They Are and How to Make Them

---

## What Are Skills?

Skills are reusable capabilities for AI agents. They're folders containing a markdown file (SKILL.md) with instructions, scripts, and resources that an agent can load when needed.

Think of it this way: MCP servers give Claude *access* to external tools (GitHub, Google Calendar, Datadog). Skills give Claude *expertise* in how to use those tools effectively. You need both.

A skill can be as simple as a single markdown file that says "when the user asks to summarize a PR, run `gh pr diff` and explain the changes." Or it can be a full directory with scripts, templates, reference docs, and example outputs.

## Skills Follow an Open Standard

Skills aren't locked to Claude Code. They follow the **Agent Skills** open standard (agentskills.io), which means the same skill works across 25+ AI tools: Claude Code, Cursor, GitHub Copilot, Gemini CLI, OpenAI Codex, and others.

This matters for our hackathon because the skills we build aren't just useful for Claude Code users on the team. Anyone using a compatible coding agent can pick them up.

## How Do Skills Work?

### Progressive Disclosure (The Key Architectural Concept)

Skills don't dump everything into memory at once. They load in three stages:

1. **Always loaded**: Just the `name` and `description` fields (~100 tokens per skill). This is how Claude knows what skills exist.
2. **On activation**: The full SKILL.md body loads when the skill is triggered.
3. **On demand**: Referenced files (scripts, templates, examples) load only when Claude decides it needs them.

Why does this matter? Because the `description` field is doing 90% of the work. It's the only part always in context. If your description is vague, Claude won't know when to use your skill. If it's specific and enumerates trigger scenarios, Claude will match it reliably.

### Invoking a Skill

Two ways:

- **User invokes it**: Type `/skill-name` in Claude Code (like a slash command). You can pass arguments: `/fix-issue 123`
- **Claude invokes it**: If the description matches what you're doing, Claude can trigger the skill automatically.

You control this with frontmatter settings (more on that below).

## Anatomy of a Skill

### The Simplest Possible Skill

Create a directory and a single file:

```text
~/.claude/skills/my-skill/
└── SKILL.md
```

The SKILL.md has YAML frontmatter at the top, then markdown instructions:

```yaml
---
name: pr-summary
description: Summarizes a pull request. Use when the user asks to review, summarize, or explain a PR.
---

Summarize the current pull request:

1. Run `gh pr diff` to get the changes
2. Run `gh pr view` to get the PR description
3. Provide a concise summary of what changed and why
```

That's it. That's a working skill.

### A More Complex Skill

Skills can include supporting files:

```text
my-skill/
├── SKILL.md           # Required. Instructions + frontmatter.
├── scripts/           # Executable code Claude can run
│   └── validate.py
├── templates/         # Files Claude fills in rather than generating from scratch
│   └── outreach.md
├── examples/          # Example outputs showing expected format
│   └── sample.md
└── reference.md       # Detailed docs loaded only when needed
```

SKILL.md references these files so Claude knows they exist. Claude only loads them when it determines they're needed (progressive disclosure level 3).

### Frontmatter Fields

The 5 core fields:

| Field                      | What It Does                                                                                                                |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `name`                     | Sets the slash command name. Optional in Claude Code (falls back to directory name). Lowercase, hyphens only, max 64 chars. |
| `description`              | Loaded into context **at all times**. Tells Claude when to use this skill. The most important field.                        |
| `allowed-tools`            | Restricts which tools the skill can use (e.g., `Read, Grep, Glob` for read-only).                                           |
| `disable-model-invocation` | Set `true` to prevent Claude from auto-triggering. User must type `/skill-name`.                                            |
| `user-invocable`           | Set `false` to hide from the `/` menu. Only Claude can trigger it.                                                          |

Additional fields worth knowing:

| Field           | What It Does                                                                                                                      |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `argument-hint` | UI hint shown during autocomplete. Example: `[issue-number]` shows `/fix-issue [issue-number]` so users know to pass an argument. |
| `model`         | Override which model runs when this skill is active.                                                                              |
| `context`       | Set to `fork` to run in an isolated subagent context.                                                                             |

### Arguments and Variables

Users can pass arguments after the skill name: `/my-skill some-argument`

Access them in your SKILL.md:

| Variable | What It Contains |
|---|---|
| `$ARGUMENTS` | The full argument string |
| `$0`, `$1`, `$2` | Individual space-separated arguments |
| `` !`command` `` | Dynamic context injection. Runs a shell command and injects the output before Claude sees the content. |

Example of dynamic context injection:

```markdown
## Current PR context
- PR diff: !`gh pr diff`
- PR comments: !`gh pr view --comments`
```

When the skill loads, those commands run first and their output replaces the placeholders. Claude gets fresh, real-time data.

## Tool Restrictions

By default, skills have access to ALL of Claude's tools (Read, Write, Edit, Bash, etc.). You can lock that down with `allowed-tools`.

### Read-Only Skills

The simplest restriction drops Bash entirely:

```yaml
allowed-tools: Read, Grep, Glob
```

### Granular CLI Restrictions

You can allow specific Bash commands using pattern matching:

```yaml
allowed-tools: Bash(gh pr view *), Bash(gh pr list *), Bash(gh issue view *), Read, Grep
```

The `Bash()` syntax uses prefix matching with wildcards. A space before `*` enforces a word boundary. Claude Code is smart about shell chaining, so `gh pr view && rm -rf /` won't sneak through a `Bash(gh pr view *)` rule.

**One caveat**: the docs describe argument-level Bash patterns as "fragile" since they're prefix-based. For truly bulletproof restrictions, you'd add a PreToolUse hook as a validation layer. For our hackathon, patterns are plenty.

## Best Practices

### Write Descriptions Like Search Keywords

Your description is the only thing always in context. Be exhaustive about when to trigger:

**Bad**: "Helps with guest outreach"

**Good**: "Manages guest speaker outreach for conference talks and podcast episodes. Use when the user mentions 'guest booking,' 'speaker outreach,' 'invite a guest,' 'find speakers,' or wants to draft outreach emails for Datadog Illuminated or Software Defined Interviews."

Write in third person ("Manages guest outreach" not "I help with guest outreach").

### Assume Claude Is Already Smart

This is the number one mistake people make. Don't explain what a CLI tool is. Don't explain what markdown is. Only add context Claude doesn't already have. Every token competes with conversation history, other skills, and the actual request.

### Keep SKILL.md Under 500 Lines

It should be a router, not an encyclopedia. Define the workflow, point to supporting files for details. Claude loads those files on demand.

### Keep File References One Level Deep

`SKILL.md` -> `reference.md` is fine. `SKILL.md` -> `advanced.md` -> `details.md` is bad. Claude may not follow deeply nested chains.

### Use Scripts for Deterministic Operations

If something should be reliable and repeatable (file parsing, API calls with specific parameters, validation checks), put it in a script. Scripts are faster, cheaper (zero tokens for execution), and impossible to misinterpret.

### Use `disable-model-invocation: true` for Anything with Side Effects

Deploy scripts, message senders, anything that does something irreversible. You don't want Claude deciding on its own to run it.

## How to Create a Skill

### Option 1: By Hand

```bash
mkdir -p .claude/skills/my-skill
# Then create SKILL.md with your editor
```

Write the frontmatter, write the instructions, test it by typing `/my-skill` in Claude Code.

### Option 2: Use the Skill Creator

Anthropic publishes a meta-skill that teaches Claude how to make skills. Install it:

```bash
npx skillsadd anthropics/skills/skill-creator
```

It comes with:
- `init_skill.py` for scaffolding a new skill directory with template files
- `package_skill.py` for packaging a skill into a distributable `.skill` file
- `quick_validate.py` for checking structure, frontmatter, and description quality

### Practical Advice for First-Timers

**Start by doing the task manually with Claude, then extract the pattern.** Have a conversation where you do the workflow (book a guest, draft an outreach email, whatever). Notice what information you keep repeating. That's your skill.

**Test with a fresh Claude session.** Your skill works in your head because you have context. A fresh session only has the skill content. If it breaks, your instructions need more detail.

**Iterate.** Write a minimal version, try it, watch where Claude goes off-track, add instructions for those specific failure modes. Don't try to anticipate everything upfront.

## How to Distribute Skills

This is directly relevant to our hackathon since our final product is skills the broader advocacy team can use.

### Project Skills (Simplest for a Team)

Put skills in `.claude/skills/` inside a shared repo and commit them to version control. Anyone who clones the repo gets the skills.

```text
our-hackathon-repo/
├── .claude/
│   └── skills/
│       ├── guest-outreach/
│       │   └── SKILL.md
│       └── talk-prep/
│           └── SKILL.md
├── README.md
└── ...
```

This is the easiest option for our team. No installation steps, no package management. Clone the repo, get the skills.

### Plugins (Broader Distribution)

For sharing beyond a single repo, package skills into a Claude Code plugin. The team can install it with:

```bash
claude plugin install github:our-org/our-skills-repo
```

Or add it through the plugin marketplace. Plugins namespace their skills as `plugin-name:skill-name` so they never conflict with local skills.

### The `npx skillsadd` Approach

Skills listed on skills.sh (the community directory run by Vercel, not Anthropic) can be installed with:

```bash
npx skillsadd owner/repo/skill-name
```

This works well for public distribution. If we want the broader community to use our skills, we could publish them here.

### Package with `package_skill.py`

The skill-creator's `package_skill.py` script bundles a skill into a `.skill` file (a zip) that can be shared directly. It validates the skill before packaging.

### Where Skills Live (Priority Order)

When the same skill name exists in multiple locations, higher priority wins:

1. **Enterprise** (managed settings, all org users)
2. **Personal** (`~/.claude/skills/`, all your projects)
3. **Project** (`.claude/skills/` in a repo, shared via git)
4. **Plugin** (via marketplace, namespaced as `plugin-name:skill-name`)

### Recommendation for Our Hackathon

Open question: How do we want to distribute?

**One idea**: Start with **project skills** in a shared repo. Each team member builds their skill in `.claude/skills/` and commits it. We can demo them on presentation day by cloning the repo. If we want to distribute to the broader team afterward, we promote each one to a plugin.

**Another idea**: Each work separately in our own repos. Package as a plugin to distribute to the team

## Resources

- **Official docs**: https://code.claude.com/docs/en/skills
- **Open standard spec**: https://agentskills.io
- **Anthropic's example skills**: https://github.com/anthropics/skills
- **Community skill directory** (Vercel): https://skills.sh
- **Skill creator install**: `npx skillsadd anthropics/skills/skill-creator`
