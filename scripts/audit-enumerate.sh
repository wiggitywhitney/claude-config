#!/usr/bin/env bash
# ABOUTME: Deterministic enumerations behind PRD #109 Milestone A4's audit inventories.
# ABOUTME: Four subcommands — hooks, skills, repos, pairs — each emitting newline-delimited JSON on stdout.

set -uo pipefail

# Enumeration is deterministic; classification is not. This script only enumerates. A completeness
# claim backed by a model looking around is not a completeness claim, so every table in
# docs/research/claude-config-repo-audit.md is rendered from this output rather than typed by hand.
#
# Output contract, pinned by PRD #109 Decision 56: newline-delimited JSON, one object per row, no
# wrapping array, nothing but JSON on stdout. Progress and warnings go to stderr so stdout stays
# safe to pipe. "Machine-readable" alone was too loose — it invites one agent to pick JSON and the
# next to pick TSV, which is the one-decision-two-places drift this milestone exists to catalogue.
#
# Lifespan differs by subcommand (Decision 56). `repos` and `pairs` are meant to outlive the audit:
# config sprawl regrows once nobody is looking, and Milestone C1's coupled-pair warning hook needs
# `pairs` as its discovery function, derived by construction rather than from a hand-maintained list.
# `hooks` and `skills` exist to produce this audit and Milestone C1 is expected to retire them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly USAGE="usage: audit-enumerate.sh <hooks|skills|repos|pairs> [repo_root] [search_root]

  hooks   Claude Code hooks from every settings file, plus native git hooks
  skills  skills and .claude/commands definitions, with slash-command collisions
  repos   every directory under search_root carrying a .claude directory
  pairs   coupled pairs, derived by construction

repo_root defaults to this script's parent. search_root applies to 'repos' only
and defaults to ~/Documents/Repositories."

SUBCOMMAND="${1:-}"
REPO_ROOT="${2:-$(dirname "$SCRIPT_DIR")}"
SEARCH_ROOT="${3:-$HOME/Documents/Repositories}"

if [ -z "$SUBCOMMAND" ]; then
    printf '%s\n' "$USAGE" >&2
    exit 64
fi

case "$SUBCOMMAND" in
    hooks|skills|repos|pairs) ;;
    *)
        printf 'audit-enumerate.sh: unknown subcommand %s\n\n%s\n' "$SUBCOMMAND" "$USAGE" >&2
        exit 64
        ;;
esac

if [ ! -d "$REPO_ROOT" ]; then
    printf 'audit-enumerate.sh: repo_root is not a directory: %s\n' "$REPO_ROOT" >&2
    exit 66
fi

# Each subcommand is a python3 pass. The enumeration is filesystem and JSON work, which python3 does
# without the quoting hazards that make the equivalent bash both longer and easier to get wrong.
export AE_REPO_ROOT="$REPO_ROOT"
export AE_SEARCH_ROOT="$SEARCH_ROOT"

case "$SUBCOMMAND" in

hooks)
python3 <<'PY'
import json, os, shlex
from pathlib import Path

repo = Path(os.environ["AE_REPO_ROOT"])
rows = []

# Every settings file that can declare hooks. Reading only one of these is the defect Milestone A2
# found twice: a check whose notion of a set comes from one file cannot see a violation in another.
SETTINGS = [
    ("config/settings.json", "tracked"),
    ("config/settings.template.json", "template"),
    (".claude/settings.json", "project"),
    (".claude/settings.local.json", "project-local"),
]

def resolve(command, repo):
    """First token of a hook command, resolved against the repo, or None if unresolvable."""
    try:
        tokens = shlex.split(command)
    except ValueError:
        return None
    if not tokens:
        return None
    target = tokens[0]
    for var in ("$CLAUDE_PROJECT_DIR", "${CLAUDE_PROJECT_DIR}", "$HOME", "${HOME}"):
        if target.startswith(var):
            base = str(repo) if "CLAUDE" in var else os.path.expanduser("~")
            target = base + target[len(var):]
    p = Path(target)
    return p if p.is_absolute() else repo / p

for rel, source in SETTINGS:
    path = repo / rel
    if not path.is_file():
        continue
    try:
        settings = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        print(f"warning: could not read {rel}: {exc}", file=__import__("sys").stderr)
        continue
    for event, matchers in sorted((settings.get("hooks") or {}).items()):
        for matcher in matchers or []:
            for hook in matcher.get("hooks") or []:
                command = hook.get("command", "")
                target = resolve(command, repo)
                rows.append({
                    "kind": "claude-code",
                    "source": source,
                    "source_file": rel,
                    "event": event,
                    "matcher": matcher.get("matcher", ""),
                    "command": command,
                    "command_exists": bool(target and target.is_file()),
                })

# Native git hooks live as files, not settings entries, and are a separate enforcement tier.
git_hooks = repo / "hooks" / "git"
if git_hooks.is_dir():
    for path in sorted(git_hooks.iterdir()):
        if path.is_dir() or path.name.startswith("."):
            continue
        rows.append({
            "kind": "git",
            "source": "git",
            "source_file": str(path.relative_to(repo)),
            "event": path.name,
            "matcher": "",
            "command": str(path.relative_to(repo)),
            "command_exists": True,
            "executable": os.access(path, os.X_OK),
        })

rows.sort(key=lambda r: (r["kind"], r["source_file"], r["event"], r["command"]))
for row in rows:
    print(json.dumps(row, sort_keys=True))
PY
;;

skills)
python3 <<'PY'
import json, os
from pathlib import Path

repo = Path(os.environ["AE_REPO_ROOT"])
rows = []

def frontmatter_name(path):
    """The name: field from YAML frontmatter, or None. Parsed narrowly on purpose."""
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    body = text.split("---", 2)
    if len(body) < 3:
        return None
    for line in body[1].splitlines():
        if line.startswith("name:"):
            return line[len("name:"):].strip().strip("'\"")
    return None

skills_dir = repo / ".claude" / "skills"
if skills_dir.is_dir():
    for entry in sorted(skills_dir.iterdir()):
        # A skill is a directory carrying SKILL.md. A loose .md file directly in skills/ is not a
        # skill — recording it as one is how an inert symlink reads as a live override.
        if entry.is_dir():
            skill_md = entry / "SKILL.md"
            if skill_md.is_file():
                rows.append({
                    "kind": "skill",
                    "name": entry.name,
                    "declared_name": frontmatter_name(skill_md),
                    "path": str(skill_md.relative_to(repo)),
                    "bytes": skill_md.stat().st_size,
                    "is_symlink": skill_md.is_symlink() or entry.is_symlink(),
                    "effective": True,
                })
        elif entry.suffix == ".md":
            rows.append({
                "kind": "loose-md",
                "name": entry.stem,
                "declared_name": frontmatter_name(entry),
                "path": str(entry.relative_to(repo)),
                "bytes": entry.stat().st_size if entry.exists() else 0,
                "is_symlink": entry.is_symlink(),
                # Installed, but Claude Code does not load it — the inert-symlink case.
                "effective": False,
            })

# A command file and a skill both produce a slash command, and the skill wins on collision. A sweep
# that enumerates only .claude/skills/ reports a repo clean while a command file does something.
commands_dir = repo / ".claude" / "commands"
if commands_dir.is_dir():
    for entry in sorted(commands_dir.rglob("*.md")):
        rows.append({
            "kind": "command",
            "name": entry.stem,
            "declared_name": frontmatter_name(entry),
            "path": str(entry.relative_to(repo)),
            "bytes": entry.stat().st_size,
            "is_symlink": entry.is_symlink(),
            "effective": True,
        })

skill_names = {r["name"] for r in rows if r["kind"] == "skill"}
for row in rows:
    collides = row["kind"] == "command" and row["name"] in skill_names
    row["collision"] = collides
    if collides:
        # The skill wins, so the command file is dead weight that still looks authoritative.
        row["effective"] = False

rows.sort(key=lambda r: (r["name"], r["kind"]))
for row in rows:
    print(json.dumps(row, sort_keys=True))
PY
;;

pairs)
python3 <<'PY'
import json, os, re, subprocess
from pathlib import Path

repo = Path(os.environ["AE_REPO_ROOT"])
rows = []

def add(derivation, a, b, target_exists, note=""):
    rows.append({
        "derivation": derivation,
        "a": a,
        "b": b,
        "target_exists": target_exists,
        "note": note,
    })

# Class 1 — a *.v1-yolo.md variant beside a SKILL.md. Two files encoding one lifecycle definition;
# four of the five divergences found during scoping were this shape.
skills_dir = repo / ".claude" / "skills"
if skills_dir.is_dir():
    for variant in sorted(skills_dir.rglob("*.v1-yolo.md")):
        partner = variant.parent / "SKILL.md"
        add("yolo-variant",
            str(partner.relative_to(repo)),
            str(variant.relative_to(repo)),
            partner.is_file(),
            "" if partner.is_file() else "variant has no SKILL.md partner")

# Class 2 — a rule or skill naming a script path. The rule and the script encode one decision, and
# the rule goes stale silently when the script moves.
# The lookbehind matters: without it, `~/.claude/skills/verify/scripts/detect-project.sh` matches as
# a repo-relative `scripts/detect-project.sh` and gets reported broken, because the suffix of a
# longer path looks identical to a short path. Only match where a path actually begins.
SCRIPT_REF = re.compile(r"(?<![A-Za-z0-9._/~-])(?:scripts|hooks)/[A-Za-z0-9._/-]+\.(?:sh|py|ts|js)")
for source_dir in ("rules", ".claude/skills"):
    base = repo / source_dir
    if not base.is_dir():
        continue
    for doc in sorted(base.rglob("*.md")):
        try:
            text = doc.read_text(errors="replace")
        except OSError:
            continue
        # A path in a SKILL.md is relative to the skill's own directory, not the repo root — a
        # SKILL.md saying `bash scripts/foo.sh` means <skill>/scripts/foo.sh. Resolving against the
        # repo root alone reported four live references in verify/ and write-docs/ as broken. Try
        # both bases and record which one resolved, so the row says where the partner actually is.
        bases = [repo]
        if doc.name == "SKILL.md" or ".claude/skills/" in str(doc):
            bases.insert(0, doc.parent)
        for ref in sorted(set(SCRIPT_REF.findall(text))):
            resolved, base_used = None, None
            for base in bases:
                candidate = base / ref
                if candidate.is_file():
                    resolved, base_used = candidate, base
                    break
            found = resolved is not None
            add("rule-names-script",
                str(doc.relative_to(repo)),
                str(resolved.relative_to(repo)) if found else ref,
                found,
                "" if found else "named script resolves against neither the skill directory nor the repo root",
                )
            if found and base_used != repo:
                rows[-1]["note"] = "resolved relative to the skill directory"

# Class 3 — a tracked file differing between main and an unmerged local branch (Decision 28).
# Reported, not trusted: an ordinary branch edit is not two places encoding one decision, so this
# class may be mostly false positives. Milestone C1 decides whether it belongs in the pair hook or
# in a separate stale-branch and data-loss check. The property the other classes lack is that the
# stale half is known in advance — main cannot reflect an unmerged branch's work.
def git(*args):
    try:
        out = subprocess.run(["git", "-C", str(repo), *args],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout if out.returncode == 0 else None

if (repo / ".git").exists():
    branches = git("branch", "--no-merged", "main", "--format=%(refname:short)") or ""
    for branch in sorted(filter(None, (b.strip() for b in branches.splitlines()))):
        changed = git("diff", "--name-only", f"main...{branch}") or ""
        for rel in sorted(filter(None, (c.strip() for c in changed.splitlines()))):
            add("branch-vs-main",
                rel,
                f"{branch}:{rel}",
                (repo / rel).is_file(),
                f"unmerged branch {branch}; reported for Milestone C1 triage, not assumed to be a pair")

rows.sort(key=lambda r: (r["derivation"], r["a"], r["b"]))
for row in rows:
    print(json.dumps(row, sort_keys=True))
PY
;;

repos)
python3 <<'PY'
import json, os
from pathlib import Path

search = Path(os.environ["AE_SEARCH_ROOT"])
rows = []

if not search.is_dir():
    # An unreadable or missing search root must not read as "no repos carry Claude Code
    # configuration" — an empty result and a failed sweep look identical downstream.
    import sys
    print(f"error: search root is not a directory: {search}", file=sys.stderr)
    sys.exit(1)

def skills_of(claude_dir):
    """Two counts, deliberately separate: what is installed, and what actually runs.

    A loose .md directly in skills/ is installed and inert — Claude Code loads a skill from
    skills/<name>/SKILL.md. The nine YOLO symlinks look like live overrides and are not, so an
    inventory reporting only file presence would describe the repo wrongly.
    """
    skills_dir = claude_dir / "skills"
    installed, effective = 0, 0
    if skills_dir.is_dir():
        for entry in sorted(skills_dir.iterdir()):
            if entry.is_dir():
                installed += 1
                if (entry / "SKILL.md").is_file():
                    effective += 1
            elif entry.suffix == ".md":
                installed += 1
    return installed, effective

# maxdepth 2 equivalent: a repo directory directly under the search root. Deliberately not deeper —
# a .claude inside node_modules or a nested clone is not a repo of Whitney's.
for repo_dir in sorted(p for p in search.iterdir() if p.is_dir()) if search.is_dir() else []:
    claude_dir = repo_dir / ".claude"
    if not claude_dir.is_dir():
        continue
    installed, effective = skills_of(claude_dir)
    commands_dir = claude_dir / "commands"
    git_hooks_dir = repo_dir / ".git" / "hooks"
    installed_git_hooks = []
    if git_hooks_dir.is_dir():
        installed_git_hooks = sorted(
            h.name for h in git_hooks_dir.iterdir()
            if not h.name.endswith(".sample") and not h.is_dir()
        )
    rows.append({
        "repo": repo_dir.name,
        "path": str(repo_dir),
        "has_project_claude_md": (claude_dir / "CLAUDE.md").is_file(),
        "has_root_claude_md": (repo_dir / "CLAUDE.md").is_file(),
        "skills_installed": installed,
        "skills_effective": effective,
        "commands": len(sorted(commands_dir.rglob("*.md"))) if commands_dir.is_dir() else 0,
        "has_settings_json": (claude_dir / "settings.json").is_file(),
        "has_settings_local": (claude_dir / "settings.local.json").is_file(),
        "git_hooks": installed_git_hooks,
        "skip_dotfiles": sorted(p.name for p in repo_dir.glob(".skip-*")),
    })

rows.sort(key=lambda r: r["repo"])
for row in rows:
    print(json.dumps(row, sort_keys=True))
PY
;;

esac
