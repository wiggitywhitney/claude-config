"""Tests for check-test-tiers.sh hook.

Exercises the hook with:
- Non-push/PR commands (should passthrough)
- Projects with all test tiers (should passthrough)
- Projects missing test tiers (should warn with allow)
- Dotfile opt-outs (.skip-e2e, .skip-integration)
- Unknown project types (should passthrough)
- Edge cases
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import (
    TestResults, hook_path, make_hook_input, TempDir, write_file,
)

HOOK = hook_path("check-test-tiers.sh")


def _setup_projects(base_dir):
    """Create test project directories with various tier configurations.

    Returns a dict of project_name -> path.
    """
    projects = {}

    # Project with all tiers (Node.js)
    p = os.path.join(base_dir, "all-tiers")
    os.makedirs(os.path.join(p, "tests", "unit"))
    os.makedirs(os.path.join(p, "tests", "integration"))
    os.makedirs(os.path.join(p, "tests", "e2e"))
    write_file(p, "package.json", '{"scripts":{"test":"vitest"}}')
    write_file(p, "tests/unit/example.test.js",
               'describe("unit", () => { it("works", () => {}) })')
    projects["all"] = p

    # Project with unit only
    p = os.path.join(base_dir, "unit-only")
    os.makedirs(os.path.join(p, "src"))
    write_file(p, "package.json", '{"scripts":{"test":"vitest"}}')
    write_file(p, "src/app.test.js",
               'describe("test", () => { it("works", () => {}) })')
    projects["unit"] = p

    # Project with no tests
    p = os.path.join(base_dir, "no-tests")
    os.makedirs(os.path.join(p, "src"))
    write_file(p, "package.json", '{"scripts":{"start":"node index.js"}}')
    projects["none"] = p

    # Project with unit + integration, missing e2e
    p = os.path.join(base_dir, "no-e2e")
    os.makedirs(os.path.join(p, "tests", "unit"))
    os.makedirs(os.path.join(p, "tests", "integration"))
    write_file(p, "package.json", '{"scripts":{"test":"vitest"}}')
    write_file(p, "tests/unit/example.test.js", 'describe("unit", () => {})')
    write_file(p, "tests/integration/api.test.js",
               'describe("integration", () => {})')
    projects["no_e2e"] = p

    # Project with .skip-e2e dotfile
    p = os.path.join(base_dir, "skip-e2e")
    os.makedirs(os.path.join(p, "tests", "unit"))
    os.makedirs(os.path.join(p, "tests", "integration"))
    write_file(p, "package.json", '{"scripts":{"test":"vitest"}}')
    write_file(p, "tests/unit/example.test.js", 'describe("unit", () => {})')
    write_file(p, "tests/integration/api.test.js",
               'describe("integration", () => {})')
    write_file(p, ".skip-e2e")
    projects["skip_e2e"] = p

    # Project with .skip-integration dotfile
    p = os.path.join(base_dir, "skip-integration")
    os.makedirs(os.path.join(p, "src"))
    write_file(p, "package.json", '{"scripts":{"test":"vitest"}}')
    write_file(p, "src/app.test.js", 'describe("test", () => {})')
    write_file(p, ".skip-integration")
    projects["skip_int"] = p

    # Project with both skip dotfiles
    p = os.path.join(base_dir, "skip-both")
    os.makedirs(os.path.join(p, "src"))
    write_file(p, "package.json", '{"scripts":{"test":"vitest"}}')
    write_file(p, "src/app.test.js", 'describe("test", () => {})')
    write_file(p, ".skip-e2e")
    write_file(p, ".skip-integration")
    projects["skip_both"] = p

    # Unknown project (no package.json, no pyproject.toml)
    p = os.path.join(base_dir, "unknown")
    os.makedirs(p)
    write_file(p, "README.md", "just a readme")
    projects["unknown"] = p

    return projects


def run_tests():
    t = TestResults("check-test-tiers.sh tests")
    t.header()

    with TempDir() as base_dir:
        proj = _setup_projects(base_dir)

        # ─── Section 1: Non-push/PR commands (silent passthrough) ───
        t.section("Non-push/PR commands (should passthrough)")

        t.assert_silent("git status passes through",
                        HOOK, make_hook_input("git status", proj["none"]))

        t.assert_silent("git commit passes through",
                        HOOK, make_hook_input(
                            'git commit -m "feat: add feature"', proj["none"]))

        t.assert_silent("npm test passes through",
                        HOOK, make_hook_input("npm test", proj["none"]))

        t.assert_silent("git log passes through",
                        HOOK, make_hook_input("git log --oneline", proj["none"]))

        # ─── Section 2: All tiers present (silent passthrough) ───
        t.section("All tiers present (should passthrough)")

        t.assert_silent("push with all tiers passes through",
                        HOOK, make_hook_input("git push origin main", proj["all"]))

        t.assert_silent("PR create with all tiers passes through",
                        HOOK, make_hook_input(
                            'gh pr create --title "test"', proj["all"]))

        # ─── Section 3: Missing tiers (should warn, not block) ───
        t.section("Missing tiers (should warn with allow)")

        t.assert_allow_with_warning("push with no tests warns about unit",
                                    HOOK, make_hook_input("git push", proj["none"]),
                                    "unit")

        t.assert_allow_with_warning("push with no tests warns about integration",
                                    HOOK, make_hook_input("git push", proj["none"]),
                                    "integration")

        t.assert_allow_with_warning("push with no tests warns about e2e",
                                    HOOK, make_hook_input("git push", proj["none"]),
                                    "e2e")

        t.assert_allow_with_warning("PR with unit-only warns about integration",
                                    HOOK, make_hook_input(
                                        'gh pr create --title "test"', proj["unit"]),
                                    "integration")

        t.assert_allow_with_warning("PR with unit-only warns about e2e",
                                    HOOK, make_hook_input(
                                        'gh pr create --title "test"', proj["unit"]),
                                    "e2e")

        t.assert_allow_with_warning("push missing e2e warns about e2e",
                                    HOOK, make_hook_input("git push", proj["no_e2e"]),
                                    "e2e")

        # ─── Section 3b: Silent allow — no permissionDecisionReason ───
        t.section("Silent allow — warning in additionalContext only")

        t.assert_allow_no_reason(
            "push warning uses additionalContext only (no permissionDecisionReason)",
            HOOK, make_hook_input("git push", proj["none"]), "unit")

        t.assert_allow_no_reason(
            "PR warning uses additionalContext only (no permissionDecisionReason)",
            HOOK, make_hook_input('gh pr create --title "test"', proj["unit"]),
            "integration")

        # ─── Section 4: Never blocks (should never deny) ───
        t.section("Never blocks (should never deny)")

        t.assert_allow("push with no tests never denies",
                       HOOK, make_hook_input("git push", proj["none"]))

        t.assert_allow("PR with no tests never denies",
                       HOOK, make_hook_input(
                           'gh pr create --title "test"', proj["none"]))

        t.assert_allow("push with unit-only never denies",
                       HOOK, make_hook_input("git push", proj["unit"]))

        # ─── Section 5: Dotfile opt-outs ───
        t.section("Dotfile opt-outs (should suppress warnings)")

        t.assert_silent(".skip-e2e suppresses e2e warning",
                        HOOK, make_hook_input("git push", proj["skip_e2e"]))

        t.assert_allow_with_warning(".skip-integration still warns about e2e",
                                    HOOK, make_hook_input("git push", proj["skip_int"]),
                                    "e2e")

        t.assert_silent(
            ".skip-e2e + .skip-integration suppresses all non-unit warnings",
            HOOK, make_hook_input("git push", proj["skip_both"]))

        # ─── Section 6: Unknown project types (silent passthrough) ───
        t.section("Unknown project types (should passthrough)")

        t.assert_silent("push in unknown project passes through",
                        HOOK, make_hook_input("git push", proj["unknown"]))

        t.assert_silent("PR create in unknown project passes through",
                        HOOK, make_hook_input(
                            'gh pr create --title "test"', proj["unknown"]))

        # ─── Section 7: Edge cases ───
        t.section("Edge cases")

        t.assert_silent("empty command",
                        HOOK, make_hook_input("", proj["none"]))

        t.assert_silent("malformed JSON handled gracefully",
                        HOOK, '{"broken": true}')

        t.assert_allow_with_warning("chained push command still triggers",
                                    HOOK, make_hook_input(
                                        "git add . && git push", proj["none"]),
                                    "unit")

        t.assert_allow_with_warning("push with -C flag triggers",
                                    HOOK, make_hook_input(
                                        f"git -C {proj['none']} push", "/tmp"),
                                    "unit")

    t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
