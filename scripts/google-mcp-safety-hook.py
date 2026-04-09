#!/usr/bin/env python3
# ABOUTME: PreToolUse safety hook that blocks destructive YouTube MCP operations.
# ABOUTME: Denies YouTube video deletion and upload via MCP tools.
"""
YouTube MCP Safety Hook for Claude Code

Implements defense-in-depth safety guardrails for YouTube MCP tools.
Calendar, Drive, and Sheets safety moved to gogcli-safety-hook.py (PRD #33).

Hard blocks implemented:
- YouTube: Delete and upload operations blocked

Hook receives JSON on stdin, outputs JSON decision to stdout.
"""

import json
import os
import sys
import datetime
from pathlib import Path

# Debug logging — opt-in via CLAUDE_HOOK_DEBUG=1
DEBUG = os.getenv("CLAUDE_HOOK_DEBUG") == "1"
DEBUG_LOG = Path(
    os.getenv(
        "CLAUDE_HOOK_DEBUG_LOG",
        str(Path.home() / ".claude" / "logs" / "google-mcp-hook-debug.log"),
    )
)

def log(message: str):
    """Write debug message to log file."""
    if DEBUG:
        try:
            DEBUG_LOG.parent.mkdir(parents=True, exist_ok=True)
            with open(DEBUG_LOG, "a", encoding="utf-8") as f:
                f.write(f"{message}\n")
        except OSError:
            pass

def make_decision(decision: str, reason: str) -> dict:
    """Create a properly formatted PreToolUse hook decision."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason
        }
    }

def check_youtube(tool_name: str, _tool_input: dict) -> dict | None:
    """
    Safety checks for YouTube MCP tools.

    Hard blocks:
    - Delete video (too destructive)
    - Upload video (not needed)
    """
    if "delete" in tool_name.lower():
        return make_decision("deny",
            "Deleting YouTube videos is blocked. This operation is too destructive.")

    if "upload" in tool_name.lower():
        return make_decision("deny",
            "Uploading YouTube videos is blocked. Upload videos through YouTube Studio.")

    return None

def main():
    log(f"\n--- Hook triggered at {datetime.datetime.now()} ---")

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        log(f"JSON decode error: {e}")
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    log(f"Tool name: {tool_name}")

    decision = None
    if "youtube" in tool_name.lower():
        decision = check_youtube(tool_name, tool_input)

    log(f"Decision: {json.dumps(decision) if decision else 'None (allow)'}")

    if decision:
        print(json.dumps(decision))

    sys.exit(0)

if __name__ == "__main__":
    main()
