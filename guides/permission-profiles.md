# Permission Profiles Guide

Claude Code's `settings.json` controls which tools and commands Claude can use autonomously (`allow`), which require user approval (`ask`), and which are always blocked (`deny`). This guide explains how to configure permissions at three trust levels.

## How Permissions Work

Permissions are set in `~/.claude/settings.json` under the `permissions` key. They complement hooks — permissions control *whether* Claude can run a command, hooks validate *what happens* when it does.

| Mechanism | Purpose | Example |
|---|---|---|
| **Permissions** | Tool-level access control | "Can Claude run `git push` without asking?" |
| **Hooks** | Validation gates on allowed actions | "When Claude pushes, does verification pass?" |
| **Deny list** | Hard block on dangerous operations | "Claude can never read `.env` files" |

## The Three Tiers

### Conservative

For learning, sensitive projects, or unfamiliar codebases. Claude asks before most actions.

- **Auto-allow:** Read-only operations (Read, Glob, Grep, git status/log/diff/branch)
- **Ask for:** All writes (Write, Edit), all bash commands, git commit/push
- **Best for:** First time using Claude Code, working in production repos, onboarding new team members

### Balanced

For daily development. Claude handles routine operations; asks for destructive or sharing actions.

- **Auto-allow:** Read-only + npm/pnpm scripts, git status/log/diff, build/test/lint commands
- **Ask for:** git commit, git push, rm, file writes in some workflows
- **Best for:** Active development where you want to review commits before they happen

### Autonomous

For trusted automation and experienced users. Claude works independently; asks only for irreversible actions.

- **Auto-allow:** Everything above + Write, Edit, git add/commit/push, node, npm install, gh CLI, file operations
- **Ask for:** git merge, git rebase, git branch -D, npm publish
- **Best for:** YOLO mode, PRD-driven workflows, CI-like autonomous operation

## Universal Deny List

All tiers share the same deny list. These are always blocked regardless of trust level:

```json
"deny": [
  "Read(.env)", "Read(.env.*)", "Read(**/.env)", "Read(**/.env.*)",
  "Read(*.pem)", "Read(**/*.pem)", "Read(*.key)", "Read(**/*.key)",
  "Read(~/.ssh/**)", "Read(~/.aws/**)", "Read(~/.docker/**)",
  "Read(**/credentials*)", "Read(**/secrets/**)", "Read(**/.npmrc)",
  "Read(id_rsa*)", "Read(id_ed25519*)",
  "Bash(sudo *)", "Bash(sudo)",
  "Bash(rm -rf /)", "Bash(rm -rf ~*)", "Bash(rm -rf /*)",
  "Bash(chmod 777 *)", "Bash(> /dev/*)",
  "Bash(curl * | bash*)", "Bash(curl * | sh*)",
  "Bash(wget * | bash*)", "Bash(wget * | sh*)"
]
```

## Reference Implementation

Whitney's `~/.claude/settings.json` is the autonomous tier in production. To tier down from autonomous:

1. **Autonomous → Balanced:** Move `git commit`, `git push`, `Write`, `Edit`, `rm` from `allow` to `ask`.
2. **Balanced → Conservative:** Move npm/pnpm scripts, git status/log/diff from `allow` to `ask`. Remove auto-allow for most bash commands.

The pattern: each tier moves commands from `allow` → `ask` → removed, increasing the friction Claude encounters before acting.

## When to Change Tiers

- Starting a new project in an unfamiliar codebase → **Conservative** until you understand the patterns
- Daily feature development → **Balanced** or **Autonomous** depending on comfort
- Running PRD workflows or YOLO mode → **Autonomous** with hooks as the safety net
- Working in production infrastructure → **Conservative** regardless of experience
