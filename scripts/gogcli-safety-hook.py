#!/usr/bin/env python3
"""
gogcli Safety Hook for Claude Code

PreToolUse hook on Bash that catches destructive or people-affecting
gog commands before execution. Hard denies with a clear explanation.
Claude should give Whitney the command to run in her own terminal.

Blocked categories:
- DESTRUCTIVE: delete, trash, remove, purge, clear (data loss)
- OUTREACH: send email, reply, forward, chat messages, DMs
- CALENDAR WITH PEOPLE: create/update events with attendees, propose times
- SHARING: drive permissions, drive comments (notifies collaborators)
- ACCOUNT SAFETY: gmail delegation, vacation auto-reply, appscript run
- CLASSROOM: announcements, invitations (notifies students/parents)

Allowed without intervention:
- All read operations (list, search, get, read, export, download)
- Personal writes (drafts, labels, filters, personal tasks, personal
  calendar events without attendees, docs/sheets/slides creation and editing,
  contacts, forms, focus time, OOO, working location)
"""

import json
import re
import sys
import datetime

DEBUG = True
DEBUG_LOG = "/tmp/gogcli-hook-debug.log"


def log(message: str):
    if DEBUG:
        with open(DEBUG_LOG, "a") as f:
            f.write(f"{message}\n")


def deny(reason: str, command: str) -> dict:
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"Blocked: {reason}\n"
                f"Command: {command}\n"
                f"Give the user the command to run in their terminal."
            ),
        }
    }


def extract_gog_command(bash_command: str) -> str | None:
    """Extract the gog portion from a bash command, if present."""
    match = re.search(r"\bgog\s+.+", bash_command)
    return match.group(0) if match else None


# --- Destructive operations (data loss) ---

DESTRUCTIVE_KEYWORDS = [
    r"\bdelete\b",
    r"\btrash\b",
    r"\bpurge\b",
    r"\bwipe\b",
]

# These words are destructive as subcommands but harmless as flags.
# "gog auth remove" = destructive. "--remove INBOX" = just archiving.
# "gog tasks clear" = destructive. "--clear-cache" = harmless.
DESTRUCTIVE_SUBCOMMANDS_ONLY = [
    r"(?<!--)\bremove\b",
    r"(?<!--)\bclear\b",
]


def check_destructive(cmd: str) -> dict | None:
    # Filter and label management are personal config, not data destruction
    if re.search(r"\bgog\s+gmail\s+(filters|labels)\b", cmd, re.IGNORECASE):
        return None
    for pattern in DESTRUCTIVE_KEYWORDS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return deny("this command would delete or trash data.", cmd)
    for pattern in DESTRUCTIVE_SUBCOMMANDS_ONLY:
        if re.search(pattern, cmd, re.IGNORECASE):
            return deny("this command would delete or remove data.", cmd)
    return None


# --- Outreach operations (messages to other people) ---

OUTREACH_COMMANDS = [
    # Gmail
    r"\bgog\s+gmail\s+send\b",
    # Chat
    r"\bgog\s+chat\s+messages\s+send\b",
    r"\bgog\s+chat\s+send-dm\b",
    r"\bgog\s+chat\s+send\b",
    # Classroom (notifies students/parents)
    r"\bgog\s+classroom\s+announcements\b",
    r"\bgog\s+classroom\s+invitations\b",
]


def check_outreach(cmd: str) -> dict | None:
    for pattern in OUTREACH_COMMANDS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return deny(
                "this command would send a message or notification to other people.",
                cmd,
            )
    return None


# --- Calendar operations that involve other people ---

CALENDAR_WRITE_COMMANDS = [
    r"\bgog\s+calendar\s+create\b",
    r"\bgog\s+calendar\s+update\b",
]

ATTENDEE_FLAGS = [
    r"--attendee",
    r"--invite",
    r"--guest",
]

# These calendar commands always involve other people
CALENDAR_PEOPLE_COMMANDS = [
    r"\bgog\s+calendar\s+invitations\b",
    r"\bgog\s+calendar\s+propose-time\b",
]


def check_calendar(cmd: str) -> dict | None:
    # Commands that always involve other people
    for pattern in CALENDAR_PEOPLE_COMMANDS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return deny(
                "this command would interact with other people's calendars.",
                cmd,
            )

    # Create/update: only block if attendees are specified
    is_cal_write = any(
        re.search(p, cmd, re.IGNORECASE) for p in CALENDAR_WRITE_COMMANDS
    )
    if is_cal_write:
        has_attendees = any(
            re.search(p, cmd, re.IGNORECASE) for p in ATTENDEE_FLAGS
        )
        if has_attendees:
            return deny(
                "this command would create/update a calendar event with other people.",
                cmd,
            )

    return None


# --- Sharing and collaboration (notifies other people) ---

SHARING_COMMANDS = [
    r"\bgog\s+drive\s+permissions\b",
    r"\bgog\s+drive\s+comments\b",
]


def check_sharing(cmd: str) -> dict | None:
    for pattern in SHARING_COMMANDS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return deny(
                "this command would share files or notify collaborators.",
                cmd,
            )
    return None


# --- Account safety (dangerous account-level changes) ---

ACCOUNT_SAFETY_COMMANDS = [
    # Grants others access to your Gmail
    r"\bgog\s+gmail\s+delegation\b",
    # Sets auto-replies that go to other people
    r"\bgog\s+gmail\s+vacation\b",
    # Executes arbitrary Apps Script code
    r"\bgog\s+appscript\s+run\b",
    # Pub/Sub push notifications (infrastructure change)
    r"\bgog\s+gmail\s+watch\b",
]


def check_account_safety(cmd: str) -> dict | None:
    for pattern in ACCOUNT_SAFETY_COMMANDS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return deny(
                "this command would change account-level settings or execute code.",
                cmd,
            )
    return None


def main():
    log(f"\n--- gogcli hook triggered at {datetime.datetime.now()} ---")

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        log(f"JSON decode error: {e}")
        sys.exit(1)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")
    log(f"Bash command: {command}")

    gog_cmd = extract_gog_command(command)
    if not gog_cmd:
        log("Not a gog command, allowing")
        sys.exit(0)

    log(f"Extracted gog command: {gog_cmd}")

    decision = (
        check_destructive(gog_cmd)
        or check_outreach(gog_cmd)
        or check_calendar(gog_cmd)
        or check_sharing(gog_cmd)
        or check_account_safety(gog_cmd)
    )

    if decision:
        log(f"Decision: DENY - {json.dumps(decision)}")
        print(json.dumps(decision))
    else:
        log("Decision: allow (safe read/personal-write operation)")

    sys.exit(0)


if __name__ == "__main__":
    main()
