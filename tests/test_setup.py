#!/usr/bin/env python3
"""Tests for setup.sh — template resolution, merge, and settings generation.

Validates:
- $CLAUDE_CONFIG_DIR placeholder resolution
- Output is valid JSON
- All hook script paths in generated output exist on disk
- Merge: hooks are merged (add new, preserve existing)
- Merge: permissions are unioned (add new, preserve existing)
- Merge: backup created before modification
- Merge: idempotent (running twice produces same result)
- Edge cases: missing template, invalid template, empty existing settings
"""

import json
import os
import subprocess
import sys
import tempfile
import shutil
import glob as globmod

# Import test harness from verify tests
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(TESTS_DIR)
VERIFY_TESTS_DIR = os.path.join(REPO_DIR, ".claude", "skills", "verify", "tests")
sys.path.insert(0, VERIFY_TESTS_DIR)

from test_harness import TestResults, TempDir, write_file

SETUP_SCRIPT = os.path.join(REPO_DIR, "setup.sh")
TEMPLATE_FILE = os.path.join(REPO_DIR, "settings.template.json")


# ── Merge Test Helpers ─────────────────────────────────────────────

def _make_hook_script(tmp_dir, name):
    """Create a dummy executable script in tmp_dir. Returns its path."""
    path = os.path.join(tmp_dir, name)
    with open(path, "w") as f:
        f.write("#!/bin/bash\nexit 0\n")
    os.chmod(path, 0o755)
    return path


def _make_template(tmp_dir, hooks=None, permissions=None, extra_keys=None):
    """Create a settings template JSON in tmp_dir.

    Uses absolute paths to real scripts in tmp_dir (not $CLAUDE_CONFIG_DIR
    placeholders) so hook path validation passes in tests.

    hooks: dict of event_type -> list of (matcher, [script_names])
    permissions: dict of allow/deny/ask -> list of strings
    extra_keys: dict of additional top-level keys
    """
    template = {}

    if hooks:
        template["hooks"] = {}
        for event_type, matchers in hooks.items():
            template["hooks"][event_type] = []
            for matcher_pattern, script_names in matchers:
                hook_list = []
                for name in script_names:
                    # Create the real script file so path validation passes
                    script_path = _make_hook_script(tmp_dir, name)
                    hook_list.append({
                        "type": "command",
                        "command": script_path,
                    })
                template["hooks"][event_type].append({
                    "matcher": matcher_pattern,
                    "hooks": hook_list,
                })

    if permissions:
        template["permissions"] = permissions

    if extra_keys:
        template.update(extra_keys)

    path = os.path.join(tmp_dir, "template.json")
    with open(path, "w") as f:
        json.dump(template, f, indent=2)
    return path


def _make_existing_settings(tmp_dir, content):
    """Write an existing settings.json in tmp_dir. Returns its path."""
    path = os.path.join(tmp_dir, "settings.json")
    with open(path, "w") as f:
        json.dump(content, f, indent=2)
    return path


def _find_backups(tmp_dir):
    """Find all .backup.* files in tmp_dir."""
    return sorted(globmod.glob(os.path.join(tmp_dir, "settings.json.backup.*")))


def run_setup(*args, env=None, cwd=None):
    """Run setup.sh with given arguments. Returns (exit_code, stdout, stderr)."""
    cmd = [SETUP_SCRIPT, *args]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
    )
    return result.returncode, result.stdout, result.stderr


def test_template_exists(t):
    """Template file must exist in repo root."""
    t.section("Template file")
    exists = os.path.isfile(TEMPLATE_FILE)
    t.assert_equal("settings.template.json exists", exists, True)


def test_template_has_placeholders(t):
    """Template must contain $CLAUDE_CONFIG_DIR placeholders."""
    t.section("Template placeholders")
    with open(TEMPLATE_FILE) as f:
        content = f.read()

    t.assert_contains(
        "template contains $CLAUDE_CONFIG_DIR",
        content, "$CLAUDE_CONFIG_DIR"
    )
    t.assert_not_contains(
        "template has no hardcoded home paths",
        content, "/Users/"
    )


def test_template_is_valid_json_structure(t):
    """Template with placeholders replaced should be valid JSON."""
    t.section("Template JSON structure")
    with open(TEMPLATE_FILE) as f:
        content = f.read()

    # Replace placeholder with a dummy path to validate JSON structure
    resolved = content.replace("$CLAUDE_CONFIG_DIR", "/tmp/fake-repo")
    try:
        data = json.loads(resolved)
        t.assert_equal("template resolves to valid JSON", True, True)
    except json.JSONDecodeError as e:
        t.assert_equal(f"template resolves to valid JSON (error: {e})", False, True)

    # Verify expected top-level keys
    t.assert_equal("has permissions key", "permissions" in data, True)
    t.assert_equal("has hooks key", "hooks" in data, True)
    t.assert_equal("has model key", "model" in data, True)


def test_resolve_to_stdout(t):
    """setup.sh with no --output should print resolved JSON to stdout."""
    t.section("Resolve to stdout")
    exit_code, stdout, stderr = run_setup()

    t.assert_equal("exits 0", exit_code, 0)

    # stdout should be valid JSON
    try:
        data = json.loads(stdout)
        t.assert_equal("stdout is valid JSON", True, True)
    except json.JSONDecodeError:
        t.assert_equal("stdout is valid JSON", False, True)
        return

    # No placeholders should remain
    t.assert_not_contains(
        "no $CLAUDE_CONFIG_DIR in output",
        stdout, "$CLAUDE_CONFIG_DIR"
    )

    # Paths should be resolved to real repo path
    t.assert_contains(
        "paths resolved to repo directory",
        stdout, REPO_DIR
    )


def test_resolve_to_file(t):
    """setup.sh --output FILE should write resolved JSON to file."""
    t.section("Resolve to file")
    with TempDir() as tmp:
        output_path = os.path.join(tmp, "settings.json")
        exit_code, stdout, stderr = run_setup("--output", output_path)

        t.assert_equal("exits 0", exit_code, 0)
        t.assert_equal("output file created", os.path.isfile(output_path), True)

        with open(output_path) as f:
            content = f.read()

        try:
            data = json.loads(content)
            t.assert_equal("output file is valid JSON", True, True)
        except json.JSONDecodeError:
            t.assert_equal("output file is valid JSON", False, True)
            return

        t.assert_not_contains(
            "no placeholders in output file",
            content, "$CLAUDE_CONFIG_DIR"
        )


def test_all_hook_paths_exist(t):
    """Every hook command path in the resolved output must exist on disk."""
    t.section("Hook path validation")
    exit_code, stdout, stderr = run_setup()

    if exit_code != 0:
        t.assert_equal("setup.sh must succeed for path validation", exit_code, 0)
        return

    data = json.loads(stdout)
    hooks = data.get("hooks", {})
    all_paths_valid = True
    checked = 0

    for event_type, matchers in hooks.items():
        for matcher in matchers:
            for hook in matcher.get("hooks", []):
                path = hook.get("command", "")
                if path:
                    checked += 1
                    exists = os.path.isfile(path)
                    t.assert_equal(
                        f"hook path exists: {os.path.basename(path)}",
                        exists, True
                    )
                    if not exists:
                        all_paths_valid = False

    t.assert_equal(f"checked {checked} hook paths (expected 10)", checked, 10)


def test_validate_flag(t):
    """setup.sh --validate should check paths and report without writing."""
    t.section("Validate mode")
    exit_code, stdout, stderr = run_setup("--validate")

    t.assert_equal("validate exits 0 when all paths exist", exit_code, 0)
    t.assert_contains("validate reports success", stdout, "valid")


def test_custom_template(t):
    """setup.sh --template FILE should use a custom template."""
    t.section("Custom template")
    with TempDir() as tmp:
        # Create a minimal template
        template = {
            "hooks": {
                "PreToolUse": [
                    {
                        "matcher": "Bash",
                        "hooks": [
                            {
                                "type": "command",
                                "command": "$CLAUDE_CONFIG_DIR/scripts/google-mcp-safety-hook.py"
                            }
                        ]
                    }
                ]
            }
        }
        template_path = write_file(tmp, "custom.template.json", json.dumps(template, indent=2))
        exit_code, stdout, stderr = run_setup("--template", template_path)

        t.assert_equal("exits 0 with custom template", exit_code, 0)

        data = json.loads(stdout)
        hook_path = data["hooks"]["PreToolUse"][0]["hooks"][0]["command"]
        t.assert_contains(
            "custom template paths resolved",
            hook_path, REPO_DIR
        )
        t.assert_not_contains(
            "no placeholder in resolved path",
            hook_path, "$CLAUDE_CONFIG_DIR"
        )


def test_missing_template_fails(t):
    """setup.sh should fail if template file doesn't exist."""
    t.section("Error handling")
    exit_code, stdout, stderr = run_setup("--template", "/nonexistent/template.json")

    t.assert_equal("exits non-zero for missing template", exit_code != 0, True)
    t.assert_contains("error mentions template", stderr.lower(), "template")


def test_idempotent(t):
    """Running setup.sh twice produces identical output."""
    t.section("Idempotency")
    _, stdout1, _ = run_setup()
    _, stdout2, _ = run_setup()

    t.assert_equal("two runs produce identical output", stdout1, stdout2)


# ── Milestone 2: Merge Tests ───────────────────────────────────────

def test_merge_creates_file_when_none_exists(t):
    """--merge TARGET should create the file if it doesn't exist."""
    t.section("Merge: create new file")
    with TempDir() as tmp:
        script_path = _make_hook_script(tmp, "hook-a.sh")
        template_path = _make_template(tmp, hooks={
            "PreToolUse": [("Bash", ["hook-a.sh"])],
        })
        target_path = os.path.join(tmp, "settings.json")

        exit_code, stdout, stderr = run_setup(
            "--merge", target_path,
            "--template", template_path,
        )

        t.assert_equal("exits 0", exit_code, 0)
        created = os.path.isfile(target_path)
        t.assert_equal("target file created", created, True)
        if not created:
            return

        with open(target_path) as f:
            data = json.load(f)
        t.assert_equal("has hooks", "hooks" in data, True)
        # No backup needed when file didn't exist
        t.assert_equal("no backup created", len(_find_backups(tmp)), 0)


def test_merge_creates_backup(t):
    """--merge should back up existing settings.json before modifying."""
    t.section("Merge: backup creation")
    with TempDir() as tmp:
        existing = {"model": "sonnet"}
        existing_path = _make_existing_settings(tmp, existing)
        template_path = _make_template(tmp, extra_keys={"model": "opus"})

        exit_code, stdout, stderr = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        backups = _find_backups(tmp)
        t.assert_equal("backup file created", len(backups), 1)
        if not backups:
            return

        # Backup should contain original content
        with open(backups[0]) as f:
            backup_data = json.load(f)
        t.assert_equal("backup has original model", backup_data["model"], "sonnet")


def test_merge_hooks_adds_new_matcher(t):
    """Merge should add hook matchers from template that don't exist in target."""
    t.section("Merge: hooks — add new matcher")
    with TempDir() as tmp:
        # Existing has a Write|Edit PostToolUse hook
        existing_hook_path = _make_hook_script(tmp, "existing-hook.sh")
        existing = {
            "hooks": {
                "PostToolUse": [{
                    "matcher": "Write|Edit",
                    "hooks": [{"type": "command", "command": existing_hook_path}],
                }]
            }
        }
        existing_path = _make_existing_settings(tmp, existing)

        # Template adds a PreToolUse Bash hook
        template_path = _make_template(tmp, hooks={
            "PreToolUse": [("Bash", ["template-hook.sh"])],
        })

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        # Existing PostToolUse hook preserved
        post_matchers = merged.get("hooks", {}).get("PostToolUse", [])
        t.assert_equal("existing PostToolUse preserved", len(post_matchers), 1)
        t.assert_equal(
            "existing matcher preserved",
            post_matchers[0]["matcher"], "Write|Edit"
        )

        # Template PreToolUse hook added
        pre_matchers = merged.get("hooks", {}).get("PreToolUse", [])
        t.assert_equal("template PreToolUse added", len(pre_matchers), 1)
        t.assert_equal(
            "template matcher added",
            pre_matchers[0]["matcher"], "Bash"
        )


def test_merge_hooks_preserves_existing_matcher(t):
    """Merge should not duplicate a matcher that already exists in target."""
    t.section("Merge: hooks — preserve existing matcher")
    with TempDir() as tmp:
        # Both existing and template have a Bash PreToolUse matcher
        existing_hook_path = _make_hook_script(tmp, "existing-bash-hook.sh")
        existing = {
            "hooks": {
                "PreToolUse": [{
                    "matcher": "Bash",
                    "hooks": [{"type": "command", "command": existing_hook_path}],
                }]
            }
        }
        existing_path = _make_existing_settings(tmp, existing)

        # Template also has Bash matcher with a different hook
        template_path = _make_template(tmp, hooks={
            "PreToolUse": [("Bash", ["template-bash-hook.sh"])],
        })

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        pre_matchers = merged.get("hooks", {}).get("PreToolUse", [])
        t.assert_equal("still one Bash matcher", len(pre_matchers), 1)

        # Both hooks should be present in the merged matcher
        commands = [h["command"] for h in pre_matchers[0]["hooks"]]
        t.assert_equal("has 2 hooks in merged matcher", len(commands), 2)
        t.assert_contains("existing hook preserved", commands[0], "existing-bash-hook.sh")
        t.assert_contains("template hook added", commands[1], "template-bash-hook.sh")


def test_merge_hooks_no_duplicate_commands(t):
    """Merge should not duplicate hook commands that already exist."""
    t.section("Merge: hooks — no duplicate commands")
    with TempDir() as tmp:
        # Existing and template both have same hook command
        shared_hook_path = _make_hook_script(tmp, "shared-hook.sh")
        existing = {
            "hooks": {
                "PreToolUse": [{
                    "matcher": "Bash",
                    "hooks": [{"type": "command", "command": shared_hook_path}],
                }]
            }
        }
        existing_path = _make_existing_settings(tmp, existing)

        # Template references same script via $CLAUDE_CONFIG_DIR placeholder
        # which resolves to tmp dir
        template_path = _make_template(tmp, hooks={
            "PreToolUse": [("Bash", ["shared-hook.sh"])],
        })

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        commands = [
            h["command"]
            for h in merged["hooks"]["PreToolUse"][0]["hooks"]
        ]
        t.assert_equal("no duplicate commands", len(commands), 1)


def test_merge_permissions_union(t):
    """Merge should union permission lists without duplicates."""
    t.section("Merge: permissions — union lists")
    with TempDir() as tmp:
        existing = {
            "permissions": {
                "allow": ["Bash(git status*)", "WebSearch"],
                "deny": ["Bash(sudo *)"],
                "ask": ["Bash(git merge*)"],
            }
        }
        existing_path = _make_existing_settings(tmp, existing)

        template_path = _make_template(tmp, permissions={
            "allow": ["Bash(git status*)", "Bash(git log *)", "WebFetch"],
            "deny": ["Bash(sudo *)", "Bash(rm -rf /)"],
            "ask": ["Bash(git rebase*)"],
        })

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        perms = merged["permissions"]

        # Allow: existing 2 + 2 new (git log, WebFetch) = 4
        t.assert_equal("allow has 4 entries", len(perms["allow"]), 4)
        t.assert_contains("allow has existing entry", str(perms["allow"]), "WebSearch")
        t.assert_contains("allow has new entry", str(perms["allow"]), "WebFetch")
        t.assert_contains("allow has new entry", str(perms["allow"]), "Bash(git log *)")

        # Deny: existing 1 + 1 new = 2
        t.assert_equal("deny has 2 entries", len(perms["deny"]), 2)
        t.assert_contains("deny has new entry", str(perms["deny"]), "Bash(rm -rf /)")

        # Ask: existing 1 + 1 new = 2
        t.assert_equal("ask has 2 entries", len(perms["ask"]), 2)
        t.assert_contains("ask has new entry", str(perms["ask"]), "Bash(git rebase*)")


def test_merge_permissions_preserves_existing_only(t):
    """Merge should preserve existing permission entries even if template has none."""
    t.section("Merge: permissions — preserve when template empty")
    with TempDir() as tmp:
        existing = {
            "permissions": {
                "allow": ["Bash(git status*)"],
                "deny": ["Bash(sudo *)"],
            }
        }
        existing_path = _make_existing_settings(tmp, existing)

        # Template has no permissions
        template_path = _make_template(tmp, extra_keys={"model": "opus"})

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        perms = merged["permissions"]
        t.assert_equal("allow preserved", perms["allow"], ["Bash(git status*)"])
        t.assert_equal("deny preserved", perms["deny"], ["Bash(sudo *)"])


def test_merge_other_keys_no_overwrite(t):
    """Merge should not overwrite existing top-level keys like model."""
    t.section("Merge: other keys — no overwrite")
    with TempDir() as tmp:
        existing = {"model": "sonnet", "alwaysThinkingEnabled": False}
        existing_path = _make_existing_settings(tmp, existing)

        template_path = _make_template(tmp, extra_keys={
            "model": "opus",
            "alwaysThinkingEnabled": True,
            "skipDangerousModePermissionPrompt": True,
        })

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        # Existing values preserved
        t.assert_equal("model not overwritten", merged["model"], "sonnet")
        t.assert_equal("thinking not overwritten", merged["alwaysThinkingEnabled"], False)
        # New key added
        t.assert_equal(
            "new key added",
            merged["skipDangerousModePermissionPrompt"], True
        )


def test_merge_empty_existing(t):
    """Merge into an empty {} settings.json should produce template content."""
    t.section("Merge: empty existing")
    with TempDir() as tmp:
        existing_path = _make_existing_settings(tmp, {})

        template_path = _make_template(tmp,
            hooks={"PreToolUse": [("Bash", ["hook.sh"])]},
            permissions={"allow": ["WebSearch"]},
            extra_keys={"model": "opus"},
        )

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            merged = json.load(f)

        t.assert_equal("has hooks", "hooks" in merged, True)
        t.assert_equal("has permissions", "permissions" in merged, True)
        t.assert_equal("has model", merged.get("model"), "opus")


def test_merge_idempotent(t):
    """Running --merge twice produces the same result."""
    t.section("Merge: idempotent")
    with TempDir() as tmp:
        existing = {
            "permissions": {"allow": ["WebSearch"]},
            "model": "sonnet",
        }
        existing_path = _make_existing_settings(tmp, existing)

        template_path = _make_template(tmp,
            hooks={"PreToolUse": [("Bash", ["hook.sh"])]},
            permissions={"allow": ["WebSearch", "WebFetch"]},
            extra_keys={"model": "opus"},
        )

        # First merge
        exit_code, _, _ = run_setup("--merge", existing_path, "--template", template_path)
        t.assert_equal("first merge exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            first_result = json.load(f)

        # Second merge (remove backup from first run to isolate)
        for b in _find_backups(tmp):
            os.remove(b)

        exit_code, _, _ = run_setup("--merge", existing_path, "--template", template_path)
        t.assert_equal("second merge exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            second_result = json.load(f)

        t.assert_equal("idempotent merge", first_result, second_result)


def test_merge_output_is_valid_json(t):
    """Merged output must always be valid JSON."""
    t.section("Merge: valid JSON output")
    with TempDir() as tmp:
        existing = {
            "permissions": {"allow": ["Bash(git status*)"]},
            "hooks": {
                "PreToolUse": [{
                    "matcher": "Bash",
                    "hooks": [{"type": "command", "command": _make_hook_script(tmp, "e.sh")}],
                }]
            },
            "model": "sonnet",
        }
        existing_path = _make_existing_settings(tmp, existing)

        template_path = _make_template(tmp,
            hooks={"PreToolUse": [("Bash", ["t.sh"]), ("Write|Edit", ["t2.sh"])]},
            permissions={"allow": ["WebFetch"], "deny": ["Bash(sudo *)"]},
            extra_keys={"model": "opus", "alwaysThinkingEnabled": True},
        )

        exit_code, _, _ = run_setup(
            "--merge", existing_path,
            "--template", template_path,
        )
        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            return

        with open(existing_path) as f:
            content = f.read()

        try:
            json.loads(content)
            t.assert_equal("merged output is valid JSON", True, True)
        except json.JSONDecodeError:
            t.assert_equal("merged output is valid JSON", False, True)


# ── Milestone 3: Symlink Tests ─────────────────────────────────────

def test_symlinks_creates_claude_md_symlink(t):
    """--symlinks should create CLAUDE.md symlink in claude dir."""
    t.section("Symlinks: CLAUDE.md")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            t.assert_equal(f"stderr: {stderr}", False, True)
            return

        link_path = os.path.join(claude_dir, "CLAUDE.md")
        t.assert_equal("CLAUDE.md symlink created", os.path.islink(link_path), True)
        if os.path.islink(link_path):
            target = os.path.realpath(link_path)
            expected = os.path.realpath(os.path.join(REPO_DIR, "global", "CLAUDE.md"))
            t.assert_equal("CLAUDE.md points to repo global/CLAUDE.md", target, expected)


def test_symlinks_creates_rules_symlink(t):
    """--symlinks should create rules/ symlink in claude dir."""
    t.section("Symlinks: rules/")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            t.assert_equal(f"stderr: {stderr}", False, True)
            return

        link_path = os.path.join(claude_dir, "rules")
        t.assert_equal("rules symlink created", os.path.islink(link_path), True)
        if os.path.islink(link_path):
            target = os.path.realpath(link_path)
            expected = os.path.realpath(os.path.join(REPO_DIR, "rules"))
            t.assert_equal("rules points to repo rules/", target, expected)


def test_symlinks_creates_skills_verify_symlink(t):
    """--symlinks should create skills/verify symlink in claude dir."""
    t.section("Symlinks: skills/verify")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(os.path.join(claude_dir, "skills"))

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            t.assert_equal(f"stderr: {stderr}", False, True)
            return

        link_path = os.path.join(claude_dir, "skills", "verify")
        t.assert_equal("skills/verify symlink created", os.path.islink(link_path), True)
        if os.path.islink(link_path):
            target = os.path.realpath(link_path)
            expected = os.path.realpath(os.path.join(REPO_DIR, ".claude", "skills", "verify"))
            t.assert_equal("skills/verify points to repo", target, expected)


def test_symlinks_creates_skills_dir_if_missing(t):
    """--symlinks should create skills/ parent directory if it doesn't exist."""
    t.section("Symlinks: creates skills/ parent dir")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)
        # Don't create skills/ — let setup.sh create it

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            t.assert_equal(f"stderr: {stderr}", False, True)
            return

        skills_dir = os.path.join(claude_dir, "skills")
        t.assert_equal("skills/ directory created", os.path.isdir(skills_dir), True)

        link_path = os.path.join(skills_dir, "verify")
        t.assert_equal("skills/verify symlink created", os.path.islink(link_path), True)


def test_symlinks_idempotent(t):
    """Running --symlinks twice should produce same result without errors."""
    t.section("Symlinks: idempotent")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)

        # First run
        exit_code1, _, stderr1 = run_setup("--symlinks", "--claude-dir", claude_dir)
        t.assert_equal("first run exits 0", exit_code1, 0)
        if exit_code1 != 0:
            t.assert_equal(f"stderr: {stderr1}", False, True)
            return

        # Capture symlink targets after first run
        targets_1 = {}
        for name in ["CLAUDE.md", "rules"]:
            path = os.path.join(claude_dir, name)
            if os.path.islink(path):
                targets_1[name] = os.readlink(path)
        verify_path = os.path.join(claude_dir, "skills", "verify")
        if os.path.islink(verify_path):
            targets_1["skills/verify"] = os.readlink(verify_path)

        # Second run
        exit_code2, _, stderr2 = run_setup("--symlinks", "--claude-dir", claude_dir)
        t.assert_equal("second run exits 0", exit_code2, 0)

        # Verify same targets
        for name in ["CLAUDE.md", "rules"]:
            path = os.path.join(claude_dir, name)
            if os.path.islink(path):
                t.assert_equal(
                    f"{name} target unchanged",
                    os.readlink(path), targets_1[name]
                )
        if os.path.islink(verify_path):
            t.assert_equal(
                "skills/verify target unchanged",
                os.readlink(verify_path), targets_1["skills/verify"]
            )


def test_symlinks_skips_correct_existing(t):
    """--symlinks should skip creation if correct symlink already exists."""
    t.section("Symlinks: skip correct existing")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)

        # Pre-create correct symlink
        expected_target = os.path.join(REPO_DIR, "global", "CLAUDE.md")
        os.symlink(expected_target, os.path.join(claude_dir, "CLAUDE.md"))

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        # Symlink should still point to same target
        link_path = os.path.join(claude_dir, "CLAUDE.md")
        t.assert_equal("symlink still correct", os.readlink(link_path), expected_target)


def test_symlinks_updates_wrong_symlink(t):
    """--symlinks should update a symlink that points to the wrong target."""
    t.section("Symlinks: update wrong symlink")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)

        # Pre-create wrong symlink
        wrong_target = os.path.join(tmp, "wrong-claude.md")
        with open(wrong_target, "w") as f:
            f.write("wrong")
        os.symlink(wrong_target, os.path.join(claude_dir, "CLAUDE.md"))

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            t.assert_equal(f"stderr: {stderr}", False, True)
            return

        link_path = os.path.join(claude_dir, "CLAUDE.md")
        t.assert_equal("symlink is still a link", os.path.islink(link_path), True)
        expected_target = os.path.join(REPO_DIR, "global", "CLAUDE.md")
        t.assert_equal("symlink updated to correct target", os.readlink(link_path), expected_target)


def test_symlinks_errors_on_regular_file(t):
    """--symlinks should error if a regular file exists at symlink target."""
    t.section("Symlinks: error on regular file")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(claude_dir)

        # Pre-create regular file where symlink should go
        regular_file = os.path.join(claude_dir, "CLAUDE.md")
        with open(regular_file, "w") as f:
            f.write("existing content")

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits non-zero", exit_code != 0, True)
        t.assert_contains("error mentions CLAUDE.md", stderr, "CLAUDE.md")


def test_symlinks_errors_on_regular_directory(t):
    """--symlinks should error if a regular directory exists at symlink target."""
    t.section("Symlinks: error on regular directory")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        os.makedirs(os.path.join(claude_dir, "rules"))

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits non-zero", exit_code != 0, True)
        t.assert_contains("error mentions rules", stderr, "rules")


def test_symlinks_standalone_scripts_in_repo(t):
    """Standalone scripts (safety hooks) should exist in repo scripts/ directory."""
    t.section("Symlinks: standalone scripts in repo")
    scripts_dir = os.path.join(REPO_DIR, "scripts")
    for script_name in ["google-mcp-safety-hook.py", "gogcli-safety-hook.py"]:
        path = os.path.join(scripts_dir, script_name)
        t.assert_equal(f"{script_name} exists in repo", os.path.isfile(path), True)
        if os.path.isfile(path):
            t.assert_equal(
                f"{script_name} is executable",
                os.access(path, os.X_OK), True
            )


def test_symlinks_creates_claude_dir_if_missing(t):
    """--symlinks should create the claude dir if it doesn't exist."""
    t.section("Symlinks: creates claude dir")
    with TempDir() as tmp:
        claude_dir = os.path.join(tmp, ".claude")
        # Don't create it — let setup.sh handle it

        exit_code, stdout, stderr = run_setup("--symlinks", "--claude-dir", claude_dir)

        t.assert_equal("exits 0", exit_code, 0)
        if exit_code != 0:
            t.assert_equal(f"stderr: {stderr}", False, True)
            return

        t.assert_equal("claude dir created", os.path.isdir(claude_dir), True)
        t.assert_equal(
            "CLAUDE.md symlink created",
            os.path.islink(os.path.join(claude_dir, "CLAUDE.md")), True
        )


def run_tests():
    t = TestResults("setup.sh — template resolution, merge, and symlinks")
    t.header()

    # Milestone 1: template resolution
    test_template_exists(t)
    test_template_has_placeholders(t)
    test_template_is_valid_json_structure(t)
    test_resolve_to_stdout(t)
    test_resolve_to_file(t)
    test_all_hook_paths_exist(t)
    test_validate_flag(t)
    test_custom_template(t)
    test_missing_template_fails(t)
    test_idempotent(t)

    # Milestone 2: merge
    test_merge_creates_file_when_none_exists(t)
    test_merge_creates_backup(t)
    test_merge_hooks_adds_new_matcher(t)
    test_merge_hooks_preserves_existing_matcher(t)
    test_merge_hooks_no_duplicate_commands(t)
    test_merge_permissions_union(t)
    test_merge_permissions_preserves_existing_only(t)
    test_merge_other_keys_no_overwrite(t)
    test_merge_empty_existing(t)
    test_merge_idempotent(t)
    test_merge_output_is_valid_json(t)

    # Milestone 3: symlinks
    test_symlinks_creates_claude_md_symlink(t)
    test_symlinks_creates_rules_symlink(t)
    test_symlinks_creates_skills_verify_symlink(t)
    test_symlinks_creates_skills_dir_if_missing(t)
    test_symlinks_idempotent(t)
    test_symlinks_skips_correct_existing(t)
    test_symlinks_updates_wrong_symlink(t)
    test_symlinks_errors_on_regular_file(t)
    test_symlinks_errors_on_regular_directory(t)
    test_symlinks_standalone_scripts_in_repo(t)
    test_symlinks_creates_claude_dir_if_missing(t)

    exit_code = t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
