#!/usr/bin/env python3
"""Check markdown files for bare code blocks (no language specifier).

Usage: check-markdown-codeblocks.py <file>

Tracks open/close state to distinguish opening fences from closing fences.
Only opening fences without a language specifier are flagged.

Exit codes:
  0 — All code blocks have language specifiers (or file is not markdown)
  1 — Found bare code blocks without language specifiers
  2 — Invalid arguments
"""

import sys
import os


def check_file(filepath):
    violations = []
    inside_code_block = False
    line_number = 0

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line_number += 1
            stripped = line.strip()

            # Check for fence lines (``` optionally followed by language)
            # strip() handles up to 3 spaces of indentation per CommonMark spec
            if stripped.startswith("```"):
                if not inside_code_block:
                    # Opening fence — check for language specifier
                    after_fence = stripped[3:].strip()
                    if not after_fence:
                        violations.append(line_number)
                    inside_code_block = True
                else:
                    # Closing fence
                    inside_code_block = False

    return violations


def main():
    if len(sys.argv) < 2:
        print("ERROR: Usage: check-markdown-codeblocks.py <file>", file=sys.stderr)
        sys.exit(2)

    filepath = sys.argv[1]

    # Only check markdown files
    ext = os.path.splitext(filepath)[1].lower()
    if ext not in (".md", ".mdx", ".markdown"):
        sys.exit(0)

    # Skip files that don't exist (e.g., deleted before hook ran)
    if not os.path.isfile(filepath):
        sys.exit(0)

    violations = check_file(filepath)

    if violations:
        count = len(violations)
        print(f"Found {count} bare code block{'s' if count > 1 else ''} (no language specifier) in {filepath}:")
        for ln in violations:
            print(f"  Line {ln}")
        print()
        print("Add a language specifier (e.g., bash, json, text) after the opening triple backticks.")
        if count > 1:
            print(f"Fix ALL {count} code blocks in a single edit to avoid repeated hook violations.")
            print("Some may be pre-existing in the file, not from your current change. Fix them anyway.")
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
