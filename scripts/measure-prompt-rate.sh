#!/usr/bin/env bash
# ABOUTME: Reports approval-prompt rate per hundred tool calls from the PermissionRequest/PreToolUse event log.
# ABOUTME: Breaks the rate down by permission mode and by inferred trigger class over a stated time window.

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: measure-prompt-rate.sh --log PATH [--since ISO8601] [--until ISO8601]

Reports the approval-prompt rate over a window of the permission event log.

  --log PATH        JSONL event log written by the PermissionRequest,
                    PermissionDenied, and PreToolUse hooks
  --since ISO8601   Count only records logged at or after this instant
  --until ISO8601   Count only records logged at or before this instant

Timestamps are the UTC 'logged_at' field the hooks add, in the form
2026-08-04T10:00:00Z. Omitting a bound leaves that side of the window open.

The denominator is PreToolUse, so the reported figure is a rate rather than a
raw count: a session that simply ran more commands is not a session with more
friction. Tool-call count is the sample size to judge a window by. Elapsed
hours are printed too, but only as a span: they include time away from the
keyboard and time blocked waiting on an approval, so two windows of equal
length can hold very different amounts of work.

Trigger classes are inferred from the shape of the command, not read from a
prompt reason string. Reason strings are not present in any on-disk record
(PRD #109, Decision 44), so a class here is a well-founded guess about why a
prompt fired, not the reason the UI gave.
USAGE
}

LOG=""
SINCE=""
UNTIL=""

# A valued option with no value must report the documented usage error rather
# than tripping `shift 2` under `set -e`, which exits with a bare shell error.
require_value() {
  if [ "$2" -lt 2 ]; then
    printf 'measure-prompt-rate.sh: %s requires a value\n' "$1" >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --log)
      require_value "$1" "$#"
      LOG="$2"
      shift 2
      ;;
    --since)
      require_value "$1" "$#"
      SINCE="$2"
      shift 2
      ;;
    --until)
      require_value "$1" "$#"
      UNTIL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'measure-prompt-rate.sh: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$LOG" ]; then
  printf 'measure-prompt-rate.sh: --log is required\n' >&2
  exit 2
fi

if [ ! -f "$LOG" ]; then
  printf 'measure-prompt-rate.sh: log file not found: %s\n' "$LOG" >&2
  exit 2
fi

if ! command -v jq > /dev/null 2>&1; then
  printf 'measure-prompt-rate.sh: jq is required and was not found on PATH\n' >&2
  exit 2
fi

# Flatten each in-window record to: event, permission mode, trigger class, epoch, ISO.
#
# Class precedence is deliberate and ordered most-specific first. ask-rule leads
# because a command reaching a configured ask rule prompts in every permission
# mode, including auto and bypassPermissions, so it is the one class no mode
# change can remedy. Filing such a command under a shape class it also happens
# to match would overstate how much a mode change can fix.
EVENTS=$(
  jq -r --arg since "$SINCE" --arg until "$UNTIL" '
    def classify:
      if (.tool_name // "") != "Bash" then "non-bash"
      else (.tool_input.command // "") as $c
        | if ($c | test("(^[[:space:]]*|[;&|][[:space:]]*)rm([[:space:]]|$)"))
             or ($c | test("(^[[:space:]]*|[;&|][[:space:]]*)git[[:space:]]+merge")) then "ask-rule"
          elif ($c | test("<<")) then "heredoc"
          elif ($c | test("\\$\\(|`|\\$\\{|\\$[A-Za-z_]")) then "expansion"
          elif ($c | test("(^|[;&|] *)cd ")) then "cd-chain"
          else "other"
          end
      end;
    select(type == "object")
    | select(.logged_at != null)
    | select(($since == "") or (.logged_at >= $since))
    | select(($until == "") or (.logged_at <= $until))
    | [ (.hook_event_name // "unknown"),
        (.permission_mode // "unknown"),
        classify,
        (.logged_at | fromdateiso8601),
        .logged_at
      ] | @tsv
  ' "$LOG"
)

if [ -z "$EVENTS" ]; then
  printf 'measure-prompt-rate.sh: no records with a logged_at timestamp in the requested window\n' >&2
  exit 1
fi

# 'log' is an awk built-in (logarithm), so the log path is passed as logpath.
printf '%s\n' "$EVENTS" | awk -F '\t' -v logpath="$LOG" '
  {
    if (min_epoch == "" || $4 < min_epoch) { min_epoch = $4; min_iso = $5 }
    if (max_epoch == "" || $4 > max_epoch) { max_epoch = $4; max_iso = $5 }
    modes[$2] = 1
  }
  $1 == "PreToolUse"       { calls++; mode_calls[$2]++ }
  $1 == "PermissionRequest" { prompts++; mode_prompts[$2]++; class_prompts[$3]++ }
  $1 == "PermissionDenied"  { denials++ }
  END {
    if (calls == 0) {
      printf "measure-prompt-rate.sh: no PreToolUse events in the window, so there is no denominator to divide by\n" > "/dev/stderr"
      exit 1
    }

    hours = (max_epoch - min_epoch) / 3600

    printf "Prompt rate — %s\n", logpath
    printf "Window:      %s .. %s (%.1f hours elapsed)\n", min_iso, max_iso, hours
    printf "             Elapsed time includes idle gaps — time away from the\n"
    printf "             keyboard, and time blocked waiting on an approval. It\n"
    printf "             is a span, not a measure of work. Compare windows by\n"
    printf "             rate and by tool-call count, not by hours.\n"
    printf "Tool calls:  %d   (the sample size that matters)\n", calls
    printf "Prompts:     %d\n", prompts + 0
    printf "Denials:     %d\n", denials + 0
    printf "Rate:        %.1f prompts per 100 tool calls\n", (prompts * 100) / calls

    printf "\nBy permission mode:\n"
    for (m in modes) {
      c = mode_calls[m] + 0
      p = mode_prompts[m] + 0
      if (c > 0) {
        printf "  %-14s %4d prompts / %4d calls   %5.1f per 100\n", m, p, c, (p * 100) / c
      } else {
        printf "  %-14s %4d prompts / %4d calls       n/a\n", m, p, c
      }
    }

    if (prompts > 0) {
      printf "\nBy trigger class, prompts only (inferred from command shape):\n"
      for (k in class_prompts) {
        printf "  %-14s %4d   %5.1f per 100 calls\n", k, class_prompts[k], (class_prompts[k] * 100) / calls
      }
    }
  }
'
