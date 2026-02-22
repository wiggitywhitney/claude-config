#!/usr/bin/env python3
"""Test runner — discovers test_*.py files, runs each module's run_tests(), prints combined summary.

Usage:
    python3 run_tests.py                    # Run all tests
    python3 run_tests.py check_commit       # Run tests matching 'check_commit'
    python3 run_tests.py detect_project     # Run tests matching 'detect_project'
"""

import importlib
import os
import sys
import time

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))

# Colors
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
RED = "\033[0;31m"
NC = "\033[0m"


def discover_test_modules(filter_str=None):
    """Find test_*.py files, excluding test_harness.py.

    If filter_str is provided, only include modules whose name contains it.
    Returns list of module names (without .py extension).
    """
    modules = []
    for filename in sorted(os.listdir(TESTS_DIR)):
        if (filename.startswith("test_")
                and filename.endswith(".py")
                and filename != "test_harness.py"):
            module_name = filename[:-3]  # strip .py
            if filter_str is None or filter_str in module_name:
                modules.append(module_name)
    return modules


def run_all(filter_str=None):
    """Discover and run test modules, print combined summary."""
    # Ensure tests dir is on the path for imports
    if TESTS_DIR not in sys.path:
        sys.path.insert(0, TESTS_DIR)

    modules = discover_test_modules(filter_str)
    if not modules:
        if filter_str:
            print(f"{RED}No test modules matching '{filter_str}'{NC}")
        else:
            print(f"{RED}No test modules found{NC}")
        return 1

    total_passed = 0
    total_failed = 0
    total_tests = 0
    module_results = []
    start_time = time.time()

    for module_name in modules:
        try:
            mod = importlib.import_module(module_name)
            passed, failed, count = mod.run_tests()
            total_passed += passed
            total_failed += failed
            total_tests += count
            module_results.append((module_name, passed, failed, count))
        except Exception as e:
            print(f"\n{RED}ERROR{NC} loading {module_name}: {e}")
            total_failed += 1
            total_tests += 1
            module_results.append((module_name, 0, 1, 1))

    elapsed = time.time() - start_time

    # Combined summary
    print(f"\n{YELLOW}{'=' * 50}{NC}")
    print(f"{YELLOW}Combined Results ({len(modules)} module(s), {elapsed:.1f}s){NC}")
    print(f"{YELLOW}{'=' * 50}{NC}")
    for module_name, passed, failed, count in module_results:
        status = f"{GREEN}PASS{NC}" if failed == 0 else f"{RED}FAIL{NC}"
        print(f"  {status} {module_name} ({passed}/{count})")
    print()
    print(
        f"  Total: {total_tests} | "
        f"{GREEN}Passed: {total_passed}{NC} | "
        f"{RED}Failed: {total_failed}{NC} | "
        f"Time: {elapsed:.1f}s"
    )
    print()

    return 0 if total_failed == 0 else 1


if __name__ == "__main__":
    filter_str = sys.argv[1] if len(sys.argv) > 1 else None
    sys.exit(run_all(filter_str))
