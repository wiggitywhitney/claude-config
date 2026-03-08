#!/usr/bin/env python3
# ABOUTME: Tests for the acceptance-gate GitHub Actions workflow template (PRD 35, M3)
# ABOUTME: Validates YAML structure, required fields, timeouts, secrets, and customization points
"""Tests for templates/acceptance-gate-ci.yml — GitHub Actions workflow template.

Validates:
- YAML is valid and parseable
- workflow_dispatch trigger is present (required for gh workflow run)
- Job timeout is at least 45 minutes (Decision 7)
- Secrets are referenced for API key injection
- Verbose reporter is configured for vitest
- Node.js setup is included
- Checkout uses the dispatched ref (not default branch)
"""

import os
import sys

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.join(TESTS_DIR, "..", "..", "..", "..")
sys.path.insert(0, TESTS_DIR)

from test_harness import TestResults

TEMPLATE_PATH = os.path.join(REPO_DIR, "templates", "acceptance-gate-ci.yml")


def _load_yaml():
    """Load and parse the workflow template. Returns (dict, error_string)."""
    try:
        import yaml
    except ImportError:
        # PyYAML not available — parse minimally
        return None, "PyYAML not installed"

    if not os.path.exists(TEMPLATE_PATH):
        return None, f"Template not found: {TEMPLATE_PATH}"

    with open(TEMPLATE_PATH) as f:
        try:
            data = yaml.safe_load(f)
            return data, None
        except yaml.YAMLError as e:
            return None, f"YAML parse error: {e}"


def _load_raw():
    """Load the raw template content as a string."""
    if not os.path.exists(TEMPLATE_PATH):
        return None
    with open(TEMPLATE_PATH) as f:
        return f.read()


def run_tests():
    t = TestResults("workflow-template")
    t.header()

    # ── File exists ──
    t.section("File existence")

    if not os.path.exists(TEMPLATE_PATH):
        t._fail("template file exists", f"Not found: {TEMPLATE_PATH}")
        return t.passed, t.failed, t.total

    t._pass("template file exists")

    # ── YAML validity ──
    t.section("YAML validity")

    data, err = _load_yaml()
    if err:
        t._fail(f"YAML parseable ({err})")
        return t.passed, t.failed, t.total

    t._pass("YAML parseable")

    if not isinstance(data, dict):
        t._fail("YAML is a mapping")
        return t.passed, t.failed, t.total

    t._pass("YAML is a mapping")

    # ── Trigger configuration ──
    t.section("Trigger configuration")

    triggers = data.get("on", data.get(True, {}))
    if isinstance(triggers, dict) and "workflow_dispatch" in triggers:
        t._pass("workflow_dispatch trigger present")
    else:
        t._fail("workflow_dispatch trigger present",
                f"Got triggers: {list(triggers.keys()) if isinstance(triggers, dict) else triggers}")

    # ── Job configuration ──
    t.section("Job configuration")

    jobs = data.get("jobs", {})
    if not jobs:
        t._fail("at least one job defined")
        return t.passed, t.failed, t.total

    t._pass("at least one job defined")

    # Find the main acceptance gate job
    main_job = None
    main_job_name = None
    for name, job in jobs.items():
        if "acceptance" in name.lower() or "test" in name.lower():
            main_job = job
            main_job_name = name
            break

    if not main_job:
        # Use the first job
        main_job_name = list(jobs.keys())[0]
        main_job = jobs[main_job_name]

    # Timeout check (Decision 7: at least 45 minutes)
    timeout = main_job.get("timeout-minutes", 0)
    if timeout >= 45:
        t._pass(f"job timeout >= 45 minutes (got {timeout})")
    else:
        t._fail(f"job timeout >= 45 minutes", f"Got: {timeout}")

    # ── Steps validation ──
    t.section("Steps validation")

    steps = main_job.get("steps", [])
    step_names = []
    step_uses = []
    for step in steps:
        if "name" in step:
            step_names.append(step["name"])
        if "uses" in step:
            step_uses.append(step["uses"])

    # Checkout step
    has_checkout = any("actions/checkout" in u for u in step_uses)
    if has_checkout:
        t._pass("checkout step present")
    else:
        t._fail("checkout step present")

    # Node.js setup
    has_node_setup = any("actions/setup-node" in u for u in step_uses)
    if has_node_setup:
        t._pass("Node.js setup step present")
    else:
        t._fail("Node.js setup step present")

    # ── Raw content checks ──
    t.section("Content checks")

    raw = _load_raw()

    # Verbose reporter
    if "--reporter=verbose" in raw or "--reporter verbose" in raw:
        t._pass("verbose reporter configured")
    else:
        t._fail("verbose reporter configured",
                "Expected --reporter=verbose in workflow")

    # Secrets reference for API key
    if "secrets." in raw and ("API_KEY" in raw or "api_key" in raw.lower()):
        t._pass("secrets reference for API key")
    else:
        t._fail("secrets reference for API key",
                "Expected secrets.ANTHROPIC_API_KEY or similar")

    # Checkout uses dispatched ref (not default branch)
    if "github.ref" in raw or "github.event.inputs" in raw:
        t._pass("checkout uses dispatched ref")
    else:
        t._fail("checkout uses dispatched ref",
                "Expected github.ref or github.event.inputs.ref in checkout")

    # ── Documentation checks ──
    t.section("Documentation")

    # File should have comments explaining customization
    comment_lines = [line for line in raw.split("\n") if line.strip().startswith("#")]
    if len(comment_lines) >= 5:
        t._pass(f"has documentation comments ({len(comment_lines)} comment lines)")
    else:
        t._fail(f"has documentation comments",
                f"Expected >= 5 comment lines, got {len(comment_lines)}")

    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
