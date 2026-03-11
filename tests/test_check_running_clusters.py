#!/usr/bin/env python3
# ABOUTME: Tests for check-running-clusters.sh — SessionStart hook for cluster lifecycle reminders.
# ABOUTME: Validates Kind/GKE detection, graceful degradation, output format, and silent no-op behavior.
"""Tests for check-running-clusters.sh — SessionStart hook for cluster lifecycle reminders.

Validates:
- Silent (no stdout) when no clusters are running
- Silent when neither kind nor gcloud is installed
- Detects running Kind clusters and includes teardown hint
- Detects running GKE clusters with cost warning and teardown hint
- Detects both Kind and GKE clusters simultaneously
- Gracefully skips kind check when kind is not installed
- Gracefully skips gcloud check when gcloud is not installed
- Output is valid JSON with additionalContext field
"""

import json
import os
import stat
import subprocess
import sys

# Import test harness from verify tests
TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(TESTS_DIR)
VERIFY_TESTS_DIR = os.path.join(REPO_DIR, ".claude", "skills", "verify", "tests")
sys.path.insert(0, VERIFY_TESTS_DIR)

from test_harness import TestResults, TempDir, write_file

SCRIPT = os.path.join(REPO_DIR, "scripts", "check-running-clusters.sh")


def make_session_input(cwd="/tmp/test"):
    """Build SessionStart hook event JSON."""
    return json.dumps({
        "session_id": "test-session-123",
        "cwd": cwd,
    })


def make_stub(directory, name, stdout="", exit_code=0):
    """Create a stub executable script that outputs given text."""
    path = os.path.join(directory, name)
    with open(path, "w") as f:
        f.write(f"#!/usr/bin/env bash\n")
        if stdout:
            f.write(f'echo "{stdout}"\n')
        f.write(f"exit {exit_code}\n")
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return path


def make_gcloud_stub(directory, output_lines):
    """Create a gcloud stub that responds to 'container clusters list' with given output."""
    path = os.path.join(directory, "gcloud")
    # The stub checks if 'container' and 'clusters' and 'list' are in args
    lines_output = "\\n".join(output_lines) if output_lines else ""
    with open(path, "w") as f:
        f.write("#!/usr/bin/env bash\n")
        f.write('if [[ "$*" == *"container"*"clusters"*"list"* ]]; then\n')
        if lines_output:
            f.write(f'  printf "%b\\n" "{lines_output}"\n')
        f.write("  exit 0\n")
        f.write("fi\n")
        f.write("exit 0\n")
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return path


def run_hook(json_input, bin_dir=None, env_override=None):
    """Run the hook script with optional PATH override for stub binaries."""
    env = os.environ.copy()
    if bin_dir:
        env["PATH"] = bin_dir + ":" + env.get("PATH", "")
    if env_override:
        env.update(env_override)
    result = subprocess.run(
        ["bash", SCRIPT],
        input=json_input,
        capture_output=True,
        text=True,
        env=env,
    )
    return result.returncode, result.stdout, result.stderr


def run_tests():
    t = TestResults("check-running-clusters.sh tests")
    t.header()

    # ─── Section 1: Silent when no clusters ───
    t.section("Silent when no clusters running")

    # kind returns empty, gcloud returns empty
    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_gcloud_stub(bin_dir, [])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("no clusters → exit 0", exit_code, 0)
        t.assert_equal("no clusters → no stdout", stdout.strip(), "")

    # ─── Section 2: Missing tools (graceful degradation) ───
    t.section("Graceful degradation — missing tools")

    # Neither kind nor gcloud installed (empty PATH with just basic utils)
    with TempDir() as bin_dir:
        # Only provide basic tools, not kind or gcloud
        make_stub(bin_dir, "which", exit_code=1)

        exit_code, stdout, stderr = run_hook(
            make_session_input(),
            env_override={"PATH": bin_dir + ":/usr/bin:/bin"},
        )
        t.assert_equal("no tools installed → exit 0", exit_code, 0)
        t.assert_equal("no tools installed → no stdout", stdout.strip(), "")

    # ─── Section 3: Kind cluster detection ───
    t.section("Kind cluster detection")

    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="test-cluster")
        make_gcloud_stub(bin_dir, [])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("kind cluster → exit 0", exit_code, 0)
        t.assert_contains("kind cluster → mentions Kind", stdout, "Kind")
        t.assert_contains("kind cluster → mentions cluster name", stdout, "test-cluster")
        t.assert_contains("kind cluster → mentions local resources", stdout, "local")
        # Should be valid JSON
        try:
            parsed = json.loads(stdout)
            t.assert_contains("kind cluster → has additionalContext", str(parsed), "additionalContext")
        except json.JSONDecodeError:
            t._fail("kind cluster → valid JSON", f"Output is not valid JSON: {stdout}")

    # Multiple Kind clusters
    with TempDir() as bin_dir:
        # kind get clusters returns one cluster per line
        path = os.path.join(bin_dir, "kind")
        with open(path, "w") as f:
            f.write("#!/usr/bin/env bash\n")
            f.write('printf "cluster-a\\ncluster-b\\n"\n')
        os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        make_gcloud_stub(bin_dir, [])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("multiple kind clusters → exit 0", exit_code, 0)
        t.assert_contains("multiple kind clusters → mentions cluster-a", stdout, "cluster-a")
        t.assert_contains("multiple kind clusters → mentions cluster-b", stdout, "cluster-b")

    # ─── Section 4: GKE cluster detection ───
    t.section("GKE cluster detection")

    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_gcloud_stub(bin_dir, ["cluster-whisperer-dev\tus-central1-a"])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("gke cluster → exit 0", exit_code, 0)
        t.assert_contains("gke cluster → mentions GKE", stdout, "GKE")
        t.assert_contains("gke cluster → mentions cluster name", stdout, "cluster-whisperer-dev")
        t.assert_contains("gke cluster → mentions cost", stdout, "cost")
        try:
            parsed = json.loads(stdout)
            t.assert_contains("gke cluster → has additionalContext", str(parsed), "additionalContext")
        except json.JSONDecodeError:
            t._fail("gke cluster → valid JSON", f"Output is not valid JSON: {stdout}")

    # ─── Section 5: Both Kind and GKE clusters ───
    t.section("Both Kind and GKE clusters")

    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="dev-cluster")
        make_gcloud_stub(bin_dir, ["kubecon-gitops-demo\tus-west1-b"])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("both clusters → exit 0", exit_code, 0)
        t.assert_contains("both clusters → mentions Kind", stdout, "Kind")
        t.assert_contains("both clusters → mentions GKE", stdout, "GKE")
        t.assert_contains("both clusters → mentions dev-cluster", stdout, "dev-cluster")
        t.assert_contains("both clusters → mentions kubecon-gitops-demo", stdout, "kubecon-gitops-demo")

    # ─── Section 6: Teardown command hints ───
    t.section("Teardown command hints")

    # cluster-whisperer prefix → ./demo/cluster/teardown.sh
    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_gcloud_stub(bin_dir, ["cluster-whisperer-test\tus-central1-a"])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_contains(
            "cluster-whisperer → teardown hint",
            stdout, "teardown"
        )

    # kubecon-gitops prefix → ./scripts/teardown-cluster.sh
    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_gcloud_stub(bin_dir, ["kubecon-gitops-prod\tus-west1-a"])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_contains(
            "kubecon-gitops → teardown hint",
            stdout, "teardown"
        )

    # Kind cluster → kind delete cluster
    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="my-cluster")
        make_gcloud_stub(bin_dir, [])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_contains(
            "kind → teardown hint",
            stdout, "kind delete cluster"
        )

    # ─── Section 7: gcloud check skipped when not installed ───
    t.section("Partial tool availability")

    # Only kind installed, gcloud missing
    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="local-cluster")
        # No gcloud stub — it won't be found in PATH

        exit_code, stdout, stderr = run_hook(
            make_session_input(),
            env_override={"PATH": bin_dir + ":/usr/bin:/bin"},
        )
        t.assert_equal("kind only, no gcloud → exit 0", exit_code, 0)
        t.assert_contains("kind only → still detects kind cluster", stdout, "local-cluster")

    # Only gcloud installed, kind missing
    with TempDir() as bin_dir:
        make_gcloud_stub(bin_dir, ["cluster-whisperer-x\tus-east1-b"])
        # No kind stub

        exit_code, stdout, stderr = run_hook(
            make_session_input(),
            env_override={"PATH": bin_dir + ":/usr/bin:/bin"},
        )
        t.assert_equal("gcloud only, no kind → exit 0", exit_code, 0)
        t.assert_contains("gcloud only → still detects gke cluster", stdout, "cluster-whisperer-x")

    # ─── Section 8: kind error handling ───
    t.section("Error handling")

    # kind returns error (e.g., Docker not running)
    with TempDir() as bin_dir:
        make_stub(bin_dir, "kind", stdout="", exit_code=1)
        make_gcloud_stub(bin_dir, [])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("kind error → exit 0 (graceful)", exit_code, 0)
        t.assert_equal("kind error → no stdout", stdout.strip(), "")

    return t.summary()


if __name__ == "__main__":
    sys.exit(run_tests())
