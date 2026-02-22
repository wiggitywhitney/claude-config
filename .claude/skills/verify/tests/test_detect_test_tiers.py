"""Tests for detect-test-tiers.sh Go test tier detection.

Exercises detect-test-tiers.sh with Go project configurations:
- Go project with no tests
- Go project with unit tests only (_test.go without build tags)
- Go project with integration tests (build tags and directory conventions)
- Go project with e2e tests (build tags, envtest, Kind)
- Go project with all tiers
- Edge cases (mixed build tags, nested directories)
- Node.js regression tests
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_harness import TestResults, script_path, run_script, TempDir, write_file

DETECT = script_path("detect-test-tiers.sh")


def _run_detect(project_dir):
    """Run detect-test-tiers.sh against a directory."""
    exit_code, stdout = run_script(DETECT, project_dir)
    return stdout.strip()


def run_tests():
    t = TestResults("detect-test-tiers.sh Go detection tests")
    t.header()

    with TempDir() as tmp:
        # ── Setup: Go project with no tests ──
        go_no_tests = os.path.join(tmp, "go-no-tests")
        os.makedirs(go_no_tests)
        write_file(go_no_tests, "go.mod", "module example.com/test\n")
        write_file(go_no_tests, "main.go",
                   "package main\n\nfunc main() {}\n")

        # ── Setup: Go project with unit tests only ──
        go_unit_only = os.path.join(tmp, "go-unit-only")
        os.makedirs(os.path.join(go_unit_only, "pkg", "handler"))
        write_file(go_unit_only, "go.mod", "module example.com/test\n")
        write_file(go_unit_only, "pkg/handler/handler_test.go",
                   'package handler\n\nimport "testing"\n\n'
                   'func TestHandleRequest(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')

        # ── Setup: Go project with integration build tag ──
        go_integration_tag = os.path.join(tmp, "go-integration-tag")
        os.makedirs(os.path.join(go_integration_tag, "pkg"))
        write_file(go_integration_tag, "go.mod", "module example.com/test\n")
        write_file(go_integration_tag, "pkg/db_test.go",
                   'package pkg\n\nimport "testing"\n\n'
                   'func TestDBConnection(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')
        write_file(go_integration_tag, "pkg/db_integration_test.go",
                   '//go:build integration\n\n'
                   'package pkg\n\nimport "testing"\n\n'
                   'func TestDBIntegration(t *testing.T) {\n'
                   '\tt.Log("integration test")\n}\n')

        # ── Setup: Go project with tests/integration/ directory ──
        go_integration_dir = os.path.join(tmp, "go-integration-dir")
        os.makedirs(os.path.join(go_integration_dir, "tests", "integration"))
        write_file(go_integration_dir, "go.mod", "module example.com/test\n")
        write_file(go_integration_dir, "main_test.go",
                   'package main\n\nimport "testing"\n\n'
                   'func TestMain(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')
        write_file(go_integration_dir, "tests/integration/api_test.go",
                   'package integration\n\nimport "testing"\n\n'
                   'func TestAPI(t *testing.T) {\n'
                   '\tt.Log("integration test")\n}\n')

        # ── Setup: Go project with e2e build tag ──
        go_e2e_tag = os.path.join(tmp, "go-e2e-tag")
        os.makedirs(os.path.join(go_e2e_tag, "test"))
        write_file(go_e2e_tag, "go.mod", "module example.com/test\n")
        write_file(go_e2e_tag, "main_test.go",
                   'package main\n\nimport "testing"\n\n'
                   'func TestMain(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')
        write_file(go_e2e_tag, "test/e2e_test.go",
                   '//go:build e2e\n\n'
                   'package test\n\nimport "testing"\n\n'
                   'func TestE2E(t *testing.T) {\n'
                   '\tt.Log("e2e test")\n}\n')

        # ── Setup: Go project with envtest (Kubebuilder) ──
        go_envtest = os.path.join(tmp, "go-envtest")
        os.makedirs(os.path.join(go_envtest, "internal", "controller"))
        write_file(go_envtest, "go.mod", "module example.com/test\n")
        write_file(go_envtest, "internal/controller/suite_test.go",
                   'package controller\n\nimport (\n\t"testing"\n\n'
                   '\t"sigs.k8s.io/controller-runtime/pkg/envtest"\n)\n\n'
                   'var testEnv *envtest.Environment\n\n'
                   'func TestMain(m *testing.M) {\n'
                   '\ttestEnv = &envtest.Environment{}\n}\n')

        # ── Setup: Go project with Kind cluster ──
        go_kind = os.path.join(tmp, "go-kind")
        os.makedirs(os.path.join(go_kind, "test", "e2e"))
        write_file(go_kind, "go.mod", "module example.com/test\n")
        write_file(go_kind, "main_test.go",
                   'package main\n\nimport "testing"\n\n'
                   'func TestMain(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')
        write_file(go_kind, "test/e2e/cluster_test.go",
                   'package e2e\n\nimport (\n\t"testing"\n\n'
                   '\t"sigs.k8s.io/kind/pkg/cluster"\n)\n\n'
                   'func TestClusterSetup(t *testing.T) {\n'
                   '\tprovider := cluster.NewProvider()\n'
                   '\t_ = provider\n}\n')

        # ── Setup: Go project with all three tiers ──
        go_all_tiers = os.path.join(tmp, "go-all-tiers")
        os.makedirs(os.path.join(go_all_tiers, "pkg"))
        os.makedirs(os.path.join(go_all_tiers, "test", "e2e"))
        write_file(go_all_tiers, "go.mod", "module example.com/test\n")
        write_file(go_all_tiers, "pkg/handler_test.go",
                   'package pkg\n\nimport "testing"\n\n'
                   'func TestHandler(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')
        write_file(go_all_tiers, "pkg/handler_integration_test.go",
                   '//go:build integration\n\n'
                   'package pkg\n\nimport "testing"\n\n'
                   'func TestHandlerIntegration(t *testing.T) {\n'
                   '\tt.Log("integration test")\n}\n')
        write_file(go_all_tiers, "test/e2e/e2e_test.go",
                   '//go:build e2e\n\n'
                   'package e2e\n\nimport "testing"\n\n'
                   'func TestEndToEnd(t *testing.T) {\n'
                   '\tt.Log("e2e test")\n}\n')

        # ── Setup: Go project with tests/e2e/ directory (no build tag) ──
        go_e2e_dir = os.path.join(tmp, "go-e2e-dir")
        os.makedirs(os.path.join(go_e2e_dir, "tests", "e2e"))
        write_file(go_e2e_dir, "go.mod", "module example.com/test\n")
        write_file(go_e2e_dir, "main_test.go",
                   'package main\n\nimport "testing"\n\n'
                   'func TestMain(t *testing.T) {\n'
                   '\tt.Log("unit test")\n}\n')
        write_file(go_e2e_dir, "tests/e2e/smoke_test.go",
                   'package e2e\n\nimport "testing"\n\n'
                   'func TestSmoke(t *testing.T) {\n'
                   '\tt.Log("e2e test")\n}\n')

        # ── Setup: Go project with only build-tagged tests ──
        go_only_tagged = os.path.join(tmp, "go-only-tagged")
        os.makedirs(os.path.join(go_only_tagged, "pkg"))
        write_file(go_only_tagged, "go.mod", "module example.com/test\n")
        write_file(go_only_tagged, "pkg/integration_test.go",
                   '//go:build integration\n\n'
                   'package pkg\n\nimport "testing"\n\n'
                   'func TestIntegration(t *testing.T) {\n'
                   '\tt.Log("integration only")\n}\n')

        # ═══ Section 1: Go project with no tests ═══
        t.section("Go project with no tests")

        output = _run_detect(go_no_tests)
        t.assert_project_type("detected as go project", output, "go")
        t.assert_tier("no unit tests detected", output, "unit", "False")
        t.assert_tier("no integration tests detected", output, "integration", "False")
        t.assert_tier("no e2e tests detected", output, "e2e", "False")

        # ═══ Section 2: Go project with unit tests only ═══
        t.section("Go project with unit tests only")

        output = _run_detect(go_unit_only)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("no integration tests", output, "integration", "False")
        t.assert_tier("no e2e tests", output, "e2e", "False")

        # ═══ Section 3: Go integration via build tag ═══
        t.section("Go integration tests (build tag)")

        output = _run_detect(go_integration_tag)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("integration detected via build tag", output, "integration", "True")
        t.assert_tier("no e2e tests", output, "e2e", "False")

        # ═══ Section 4: Go integration via directory convention ═══
        t.section("Go integration tests (directory convention)")

        output = _run_detect(go_integration_dir)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("integration detected via directory", output, "integration", "True")
        t.assert_tier("no e2e tests", output, "e2e", "False")

        # ═══ Section 5: Go e2e via build tag ═══
        t.section("Go e2e tests (build tag)")

        output = _run_detect(go_e2e_tag)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("no integration tests", output, "integration", "False")
        t.assert_tier("e2e detected via build tag", output, "e2e", "True")

        # ═══ Section 6: Go e2e via envtest ═══
        t.section("Go e2e tests (envtest)")

        output = _run_detect(go_envtest)
        t.assert_tier("e2e detected via envtest import", output, "e2e", "True")

        # ═══ Section 7: Go e2e via Kind ═══
        t.section("Go e2e tests (Kind)")

        output = _run_detect(go_kind)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("e2e detected via Kind import", output, "e2e", "True")

        # ═══ Section 8: Go e2e via tests/e2e/ directory ═══
        t.section("Go e2e tests (directory convention)")

        output = _run_detect(go_e2e_dir)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("no integration tests", output, "integration", "False")
        t.assert_tier("e2e detected via directory", output, "e2e", "True")

        # ═══ Section 9: Go project with all tiers ═══
        t.section("Go project with all tiers")

        output = _run_detect(go_all_tiers)
        t.assert_tier("unit tests detected", output, "unit", "True")
        t.assert_tier("integration tests detected", output, "integration", "True")
        t.assert_tier("e2e tests detected", output, "e2e", "True")

        # ═══ Section 10: Go project with only tagged tests ═══
        t.section("Go project with only tagged tests (no unit)")

        output = _run_detect(go_only_tagged)
        t.assert_tier("no unit tests (all files have build tags)", output, "unit", "False")
        t.assert_tier("integration detected via build tag", output, "integration", "True")
        t.assert_tier("no e2e tests", output, "e2e", "False")

        # ═══ Section 11: Node.js regression ═══
        t.section("Node.js regression")

        node_proj = os.path.join(tmp, "node-regression")
        os.makedirs(os.path.join(node_proj, "tests", "unit"))
        os.makedirs(os.path.join(node_proj, "tests", "integration"))
        write_file(node_proj, "package.json", '{"scripts":{"test":"vitest"}}')
        write_file(node_proj, "tests/unit/example.test.js",
                   'describe("unit", () => {})')
        write_file(node_proj, "tests/integration/api.test.js",
                   'describe("int", () => {})')

        output = _run_detect(node_proj)
        t.assert_project_type("Node.js still detected correctly", output, "node-javascript")
        t.assert_tier("Node.js unit still works", output, "unit", "True")
        t.assert_tier("Node.js integration still works", output, "integration", "True")
        t.assert_tier("Node.js e2e still correctly absent", output, "e2e", "False")

    exit_code = t.summary()
    return t.passed, t.failed, t.total


if __name__ == "__main__":
    passed, failed, total = run_tests()
    sys.exit(0 if failed == 0 else 1)
