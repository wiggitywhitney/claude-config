"""Tests for check-commit-message.sh hook.

Exercises the hook with:
- Non-commit commands (should passthrough silently)
- Clean commit messages (should passthrough silently)
- AI/Claude references in various formats (should deny)
- False-positive resistance (file paths containing "claude")
- All three message formats: heredoc, -m, --message
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, hook_path, make_hook_input

HOOK = hook_path("check-commit-message.sh")


def run_tests():
    t = TestResults("check-commit-message.sh tests")
    t.header()

    # ─── Section 1: Non-commit commands (silent passthrough) ───
    t.section("Non-commit commands (should passthrough)")

    t.assert_allow("git status passes through",
                   HOOK, make_hook_input("git status"))

    t.assert_allow("git push passes through",
                   HOOK, make_hook_input("git push origin main"))

    t.assert_allow("git log passes through",
                   HOOK, make_hook_input("git log --oneline -5"))

    t.assert_allow("npm test passes through",
                   HOOK, make_hook_input("npm test"))

    t.assert_allow("ls passes through",
                   HOOK, make_hook_input("ls -la"))

    # ─── Section 2: Clean commit messages (silent passthrough) ───
    t.section("Clean commit messages (should passthrough)")

    t.assert_allow("clean -m message",
                   HOOK, make_hook_input('git commit -m "fix: resolve null pointer in login flow"'))

    t.assert_allow("clean --message message",
                   HOOK, make_hook_input('git commit --message="feat: add user authentication"'))

    t.assert_allow("clean heredoc message",
                   HOOK, make_hook_input(
                       'git commit -m "$(cat <<\'EOF\'\n'
                       'fix: resolve null pointer in login flow\n'
                       'EOF\n)"'))

    t.assert_allow("commit with --amend and no message",
                   HOOK, make_hook_input("git commit --amend --no-edit"))

    t.assert_allow("chained clean commit",
                   HOOK, make_hook_input('git add . && git commit -m "refactor: extract helper function"'))

    # ─── Section 3: AI reference patterns with -m (should deny) ───
    t.section("AI reference patterns with -m (should deny)")

    t.assert_deny("blocks 'Claude Code' reference",
                  HOOK, make_hook_input('git commit -m "feat: add login - built with Claude Code"'))

    t.assert_deny("blocks 'claude' reference",
                  HOOK, make_hook_input('git commit -m "fix: bug found by claude"'))

    t.assert_deny("blocks 'Anthropic' reference",
                  HOOK, make_hook_input('git commit -m "feat: using Anthropic API patterns"'))

    t.assert_deny("blocks 'Generated with' reference",
                  HOOK, make_hook_input('git commit -m "docs: generated with AI tooling"'))

    t.assert_deny("blocks 'Co-Authored-By Claude' reference",
                  HOOK, make_hook_input(
                      'git commit -m "feat: add feature\n\n'
                      'Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"'))

    t.assert_deny("blocks 'AI assistant' reference",
                  HOOK, make_hook_input('git commit -m "refactor: suggested by AI assistant"'))

    t.assert_deny("blocks 'AI-generated' reference",
                  HOOK, make_hook_input('git commit -m "docs: AI-generated documentation"'))

    t.assert_deny("blocks 'language model' reference",
                  HOOK, make_hook_input('git commit -m "feat: language model integration"'))

    t.assert_deny("blocks case-insensitive 'CLAUDE'",
                  HOOK, make_hook_input('git commit -m "fix: CLAUDE found this bug"'))

    # ─── Section 4: AI references in heredoc format (should deny) ───
    t.section("AI references in heredoc format (should deny)")

    t.assert_deny("blocks Claude in heredoc",
                  HOOK, make_hook_input(
                      'git commit -m "$(cat <<\'EOF\'\n'
                      'feat: add feature\n\n'
                      'Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>\n'
                      'EOF\n)"'))

    t.assert_deny("blocks Generated with in heredoc",
                  HOOK, make_hook_input(
                      'git commit -m "$(cat <<\'EOF\'\n'
                      'Generated with Claude Code\n'
                      'EOF\n)"'))

    # ─── Section 5: False-positive resistance ───
    t.section("False-positive resistance")

    t.assert_allow("file path with 'claude' in git add does not trigger",
                   HOOK, make_hook_input(
                       'git add claude-config/hooks/test.sh && git commit -m "fix: update hook logic"'))

    t.assert_allow("file path with 'claude' in -C flag does not trigger",
                   HOOK, make_hook_input(
                       'git -C /path/to/claude-config commit -m "fix: update hook"'))

    t.assert_allow("~/.claude/ path in commit message does not trigger",
                   HOOK, make_hook_input(
                       'git commit -m "feat: symlink config from ~/.claude/ directory"'))

    t.assert_allow("CLAUDE.md filename in commit message does not trigger",
                   HOOK, make_hook_input(
                       'git commit -m "docs: update CLAUDE.md with new rules"'))

    t.assert_allow(".claude/settings.json path in commit message does not trigger",
                   HOOK, make_hook_input(
                       'git commit -m "fix: update .claude/settings.json deny list"'))

    t.assert_allow("claude-config repo name in commit message does not trigger",
                   HOOK, make_hook_input(
                       'git commit -m "feat: track global config in claude-config repo"'))

    t.assert_allow("multiple path references with claude do not trigger",
                   HOOK, make_hook_input(
                       'git commit -m "feat: symlink ~/.claude/CLAUDE.md to claude-config/global/"'))

    t.assert_allow("LLM in technical context does not trigger",
                   HOOK, make_hook_input(
                       'git commit -m "feat: add LLM token counting for API calls"'))

    # ─── Section 6: Edge cases ───
    t.section("Edge cases")

    t.assert_allow("empty command",
                   HOOK, make_hook_input(""))

    t.assert_allow("malformed JSON handled gracefully",
                   HOOK, '{"broken": true}')

    t.assert_allow("commit with -a flag and clean message",
                   HOOK, make_hook_input('git commit -a -m "fix: resolve race condition"'))

    t.assert_deny("commit with -a flag and AI reference",
                  HOOK, make_hook_input('git commit -a -m "fix: claude found race condition"'))

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
