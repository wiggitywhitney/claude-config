#!/usr/bin/env python3
"""
Google MCP Safety Hook for Claude Code

Implements defense-in-depth safety guardrails for Google API MCP servers.
This PreToolUse hook handles HARD BLOCKS only (deny decisions).

User approval for sensitive operations (delete, edit) is handled via
permissions.ask in settings.json, not via hooks.

Hard blocks implemented:
- Calendar: Guest/attendee additions blocked (The Tim Problem)
- YouTube: Delete and upload operations blocked
- Drive: Delete operations blocked
- Sheets: Write to non-staging sheets blocked

Hook receives JSON on stdin, outputs JSON decision to stdout.
"""

import json
import sys
import datetime

# Sheets allowed for writes (all others blocked)
ALLOWED_SHEET_IDS = {
    "1eatUotHm4YOin1_rsqRSb71wY4S-lh5SsGInJVznBts",  # Staging sheet (Thunder workflow)
    "14SKb5lOhlOznUTx7gJhH4KHidFOaxNwF5dx4cXNssz4",  # Datadog Illuminated tracker
}

# Debug logging
DEBUG = True
DEBUG_LOG = "/tmp/google-mcp-hook-debug.log"

def log(message: str):
    """Write debug message to log file."""
    if DEBUG:
        with open(DEBUG_LOG, "a") as f:
            f.write(f"{message}\n")

def make_decision(decision: str, reason: str) -> dict:
    """Create a properly formatted PreToolUse hook decision."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason
        }
    }

def check_calendar(tool_name: str, tool_input: dict) -> dict | None:
    """
    Safety checks for Google Calendar MCP tools.

    Hard blocks:
    - Adding guests/attendees (The Tim Problem - wrong person invited)

    User approval (via permissions.ask):
    - Delete operations
    """
    # Hard block: Adding guests/attendees (The Tim Problem)
    if "attendee" in tool_name.lower() or "guest" in tool_name.lower():
        return make_decision("deny",
            "Adding calendar guests is blocked. Add attendees manually in Google Calendar to avoid inviting the wrong person.")

    # Check for attendees in event creation/update
    if "create" in tool_name.lower() or "update" in tool_name.lower():
        attendees = tool_input.get("attendees", [])
        if attendees:
            return make_decision("deny",
                "Adding calendar guests is blocked. Create the event without attendees, then add them manually in Google Calendar.")

    # Allow all other operations (delete handled by permissions.ask)
    return None

def check_youtube(tool_name: str, tool_input: dict) -> dict | None:
    """
    Safety checks for YouTube MCP tools.

    Hard blocks:
    - Delete video (too destructive)
    - Upload video (not needed)

    User approval (via permissions.ask):
    - Edit operations (title, description)
    """
    # Hard block: Delete operations
    if "delete" in tool_name.lower():
        return make_decision("deny",
            "Deleting YouTube videos is blocked. This operation is too destructive.")

    # Hard block: Upload operations
    if "upload" in tool_name.lower():
        return make_decision("deny",
            "Uploading YouTube videos is blocked. Upload videos through YouTube Studio.")

    # Allow all other operations (edit handled by permissions.ask when configured)
    return None

def check_drive(tool_name: str, tool_input: dict) -> dict | None:
    """
    Safety checks for Google Drive MCP tools.

    Hard blocks:
    - Delete operations (too destructive)

    User approval (via permissions.ask):
    - Edit operations
    """
    # Hard block: Delete operations
    if "delete" in tool_name.lower():
        return make_decision("deny",
            "Deleting Drive files is blocked. Delete files manually in Google Drive.")

    # Allow all other operations (edit handled by permissions.ask when configured)
    return None

def check_sheets(tool_name: str, tool_input: dict) -> dict | None:
    """
    Safety checks for Google Sheets MCP tools.

    Hard blocks:
    - Delete operations (too destructive)
    - Write to non-staging sheets (protects live Content Manager spreadsheet)
    """
    # Hard block: Delete operations
    if "delete" in tool_name.lower():
        return make_decision("deny",
            "Deleting spreadsheets/sheets is blocked. Delete manually in Google Sheets.")

    # Check write operations - only allow writes to staging sheet
    if "write" in tool_name.lower() or "update" in tool_name.lower() or "append" in tool_name.lower():
        # Different MCP servers use different parameter names for spreadsheet ID
        spreadsheet_id = tool_input.get("spreadsheetId",
                         tool_input.get("spreadsheet_id",
                         tool_input.get("fileId", "")))

        if ALLOWED_SHEET_IDS:
            if spreadsheet_id in ALLOWED_SHEET_IDS:
                return None  # Allow writes to approved sheets
            else:
                return make_decision("deny",
                    f"Writing to this spreadsheet is blocked. Only approved sheets can be written to. Add the sheet ID to ALLOWED_SHEET_IDS in the safety hook to allow writes.")

    # Allow: Read operations
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
    log(f"Tool input: {json.dumps(tool_input, indent=2)}")

    # Route to appropriate checker based on MCP server
    decision = None

    if "calendar" in tool_name.lower():
        decision = check_calendar(tool_name, tool_input)
    elif "youtube" in tool_name.lower():
        decision = check_youtube(tool_name, tool_input)
    elif "drive" in tool_name.lower() and "sheet" not in tool_name.lower():
        decision = check_drive(tool_name, tool_input)
    elif "sheet" in tool_name.lower() or "spreadsheet" in tool_name.lower():
        decision = check_sheets(tool_name, tool_input)

    log(f"Decision: {json.dumps(decision) if decision else 'None (allow)'}")

    # Output decision if we have one
    if decision:
        print(json.dumps(decision))

    # Exit 0 regardless - no decision means default behavior (allow)
    sys.exit(0)

if __name__ == "__main__":
    main()
