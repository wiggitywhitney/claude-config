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


def make_gcloud_stub(directory, output_lines, project="test-project"):
    """Create a gcloud stub that responds to 'container clusters list' with given output.

    Also answers `config get-value project`, which the hook resolves before
    listing so that an unconfigured project is reported rather than swallowed.
    """
    path = os.path.join(directory, "gcloud")
    # The stub checks if 'container' and 'clusters' and 'list' are in args
    lines_output = "\\n".join(output_lines) if output_lines else ""
    with open(path, "w") as f:
        f.write("#!/usr/bin/env bash\n")
        f.write('if [[ "$*" == *"config"*"get-value"*"project"* ]]; then\n')
        if project:
            f.write(f'  echo "{project}"\n')
        f.write("  exit 0\n")
        f.write("fi\n")
        f.write('if [[ "$*" == *"container"*"clusters"*"list"* ]]; then\n')
        if lines_output:
            f.write(f'  printf "%b\\n" "{lines_output}"\n')
        f.write("  exit 0\n")
        f.write("fi\n")
        f.write("exit 0\n")
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return path


def make_recording_gcloud_stub(directory, args_file, project="", clusters=None,
                               list_exit=0):
    """gcloud stub that records its argv and answers both calls the hook makes.

    Responds to `config get-value project` with the given project (empty when
    unset) and to `container clusters list` with the given rows.
    """
    clusters = clusters or []
    lines_output = "\\n".join(clusters)
    path = os.path.join(directory, "gcloud")
    with open(path, "w") as f:
        f.write("#!/usr/bin/env bash\n")
        f.write(f'echo "$*" >> "{args_file}"\n')
        f.write('if [[ "$*" == *"config"*"get-value"*"project"* ]]; then\n')
        if project:
            f.write(f'  echo "{project}"\n')
        f.write("  exit 0\n")
        f.write("fi\n")
        f.write('if [[ "$*" == *"container"*"clusters"*"list"* ]]; then\n')
        if lines_output:
            f.write(f'  printf "%b\\n" "{lines_output}"\n')
        if list_exit != 0:
            f.write('  echo "ERROR: something went wrong" >&2\n')
        f.write(f"  exit {list_exit}\n")
        f.write("fi\n")
        f.write("exit 0\n")
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    # Ensure the file exists even if the stub is never called.
    open(args_file, "a").close()
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
        # Previously asserted silence. Silence here is the defect: a failed listing
        # is not an empty listing, and reporting nothing hides that Kind was never
        # actually inspected.
        t.assert_contains("kind error → reports the failure rather than staying silent",
                          stdout, "Kind check failed")

    # ─── Section 9: documented output envelope ───
    t.section("Output uses the documented hookSpecificOutput envelope")

    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        make_stub(bin_dir, "kind", stdout="test-cluster", exit_code=0)
        make_recording_gcloud_stub(bin_dir, args_file, project="demo-proj", clusters=[])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        try:
            parsed = json.loads(stdout)
        except json.JSONDecodeError:
            parsed = {}
            t._fail("envelope → valid JSON", f"Output is not valid JSON: {stdout}")

        hso = parsed.get("hookSpecificOutput", {})
        t.assert_equal("nests output under hookSpecificOutput",
                       isinstance(hso, dict) and hso != {}, True)
        t.assert_equal("names the hook event", hso.get("hookEventName"), "SessionStart")
        t.assert_contains("carries the message in additionalContext",
                          hso.get("additionalContext", ""), "test-cluster")
        t.assert_equal("no bare top-level additionalContext",
                       "additionalContext" in parsed, False)

    # ─── Section 9b: Kind failures are reported, not swallowed ───
    t.section("Kind check failure is visible, not silent")

    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        make_stub(bin_dir, "kind", stdout="", exit_code=1)
        make_recording_gcloud_stub(bin_dir, args_file, project="demo-proj", clusters=[])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("failing kind → exit 0", exit_code, 0)
        t.assert_contains("failing kind → reports the check could not run",
                          stdout, "Kind check failed")

    # A container runtime that is not running means no Kind cluster can exist,
    # so that specific failure is not worth a warning at every session start.
    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        path = os.path.join(bin_dir, "kind")
        with open(path, "w") as f:
            f.write("#!/usr/bin/env bash\n")
            f.write('echo "ERROR: failed to list clusters: failed to connect to the docker API at unix:///x/docker.sock" >&2\n')
            f.write("exit 1\n")
        os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
        make_recording_gcloud_stub(bin_dir, args_file, project="demo-proj", clusters=[])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("unreachable container runtime → exit 0", exit_code, 0)
        t.assert_equal("unreachable container runtime → stays silent", stdout.strip(), "")

    # ─── Section 9c: teardown commands name the project explicitly ───
    t.section("Generic GKE teardown names the project")

    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_recording_gcloud_stub(bin_dir, args_file, project="demo-proj",
                                   clusters=["unconventional-name\tus-central1-a"])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_contains("generic teardown passes --project",
                          stdout, "--project demo-proj")

    # ─── Section 10: the GKE check must never fail silently ───
    t.section("GKE check failure is visible, not silent")

    # A configured project, an explicit --project argument, and no name filter.
    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_recording_gcloud_stub(bin_dir, args_file, project="demo-proj",
                                   clusters=["oddly-named-cluster\tus-central1-a"])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        with open(args_file) as f:
            recorded = f.read()

        t.assert_equal("configured project → exit 0", exit_code, 0)
        t.assert_contains("passes the project explicitly", recorded, "--project demo-proj")
        t.assert_not_contains("passes no hardcoded cluster-name filter", recorded, "--filter=name~")
        t.assert_contains("reports a cluster whose name matches no known prefix",
                          stdout, "oddly-named-cluster")

    # No project configured — the check cannot run, and must say so.
    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_recording_gcloud_stub(bin_dir, args_file, project="", clusters=[])

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        with open(args_file) as f:
            recorded = f.read()
        t.assert_equal("unset project → exit 0", exit_code, 0)
        t.assert_not_contains("unset project → never attempts the listing",
                              recorded, "container clusters list")
        t.assert_contains("unset project → warns that the check did not run",
                          stdout, "no gcloud project")
        t.assert_contains("unset project → names the fix", stdout, "gcloud config set project")

    # gcloud is configured but the list call fails — also must not be silent.
    with TempDir() as bin_dir:
        args_file = os.path.join(bin_dir, "args.txt")
        make_stub(bin_dir, "kind", stdout="", exit_code=0)
        make_recording_gcloud_stub(bin_dir, args_file, project="demo-proj",
                                   clusters=[], list_exit=1)

        exit_code, stdout, stderr = run_hook(make_session_input(), bin_dir=bin_dir)
        t.assert_equal("failing list call → exit 0", exit_code, 0)
        t.assert_contains("failing list call → warns the check failed", stdout, "GKE check failed")

    return t.summary()


if __name__ == "__main__":
    sys.exit(run_tests())
