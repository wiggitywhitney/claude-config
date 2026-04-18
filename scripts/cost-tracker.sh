#!/usr/bin/env bash
# ABOUTME: Parse Claude Code session JSONL files to report token cost by repo and model.
# ABOUTME: Reads ~/.claude/projects/ (or $CLAUDE_PROJECTS_DIR). Usage: cost-tracker.sh [DAYS] [--repo NAME]

set -uo pipefail

DAYS=7
REPO_FILTER=""
PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo) [[ $# -lt 2 ]] && { echo "Error: --repo requires a value" >&2; exit 1; }; REPO_FILTER="$2"; shift 2 ;;
        [0-9]*) DAYS="$1"; shift ;;
        *) echo "Usage: cost-tracker.sh [DAYS] [--repo NAME]" >&2; exit 1 ;;
    esac
done

# Compute ISO cutoff using macOS system date (avoids GNU date shadow)
CUTOFF=$(/bin/date -v "-${DAYS}d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
         python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc)-timedelta(days=${DAYS})).strftime('%Y-%m-%dT%H:%M:%SZ'))")

if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo "No sessions found in $PROJECTS_DIR"
    exit 0
fi

# Parse all JSONL files → aggregate costs → print report
find "$PROJECTS_DIR" -name "*.jsonl" -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null \
    | jq -Rr --arg cutoff "$CUTOFF" '
        try (
            fromjson |
            select(
                .type == "assistant" and
                (.sessionId // "") != "" and
                (.timestamp // "") >= $cutoff
            ) | [
            (.sessionId),
            (.cwd // "" | gsub(".*/"; "")),
            (.message.model // "unknown"),
            (.message.usage.input_tokens // 0 | tostring),
            (.message.usage.cache_creation_input_tokens // 0 | tostring),
            (.message.usage.cache_read_input_tokens // 0 | tostring),
            (.message.usage.output_tokens // 0 | tostring)
        ] | @tsv
        ) catch empty
    ' \
    | awk -v repo_filter="$REPO_FILTER" -v days="$DAYS" '
        BEGIN {
            # Pricing per million tokens (input, cache_create, cache_read, output)
            # Rates verified against https://docs.anthropic.com/en/docs/about-claude/models/all-models (2026-04-18)
            ir["claude-opus-4-7"]            = 5.00
            ccr["claude-opus-4-7"]           = 6.25
            crr["claude-opus-4-7"]           = 0.50
            outr["claude-opus-4-7"]          = 25.00

            ir["claude-opus-4-6"]            = 5.00
            ccr["claude-opus-4-6"]           = 6.25
            crr["claude-opus-4-6"]           = 0.50
            outr["claude-opus-4-6"]          = 25.00

            ir["claude-opus-4-5-20251101"]   = 5.00
            ccr["claude-opus-4-5-20251101"]  = 6.25
            crr["claude-opus-4-5-20251101"]  = 0.50
            outr["claude-opus-4-5-20251101"] = 25.00

            ir["claude-opus-4-1-20250805"]   = 15.00
            ccr["claude-opus-4-1-20250805"]  = 18.75
            crr["claude-opus-4-1-20250805"]  = 1.50
            outr["claude-opus-4-1-20250805"] = 75.00

            ir["claude-sonnet-4-6"]          = 3.00
            ccr["claude-sonnet-4-6"]         = 3.75
            crr["claude-sonnet-4-6"]         = 0.30
            outr["claude-sonnet-4-6"]        = 15.00

            ir["claude-sonnet-4-5-20250929"] = 3.00
            ccr["claude-sonnet-4-5-20250929"]= 3.75
            crr["claude-sonnet-4-5-20250929"]= 0.30
            outr["claude-sonnet-4-5-20250929"]= 15.00

            ir["claude-haiku-4-5-20251001"]  = 1.00
            ccr["claude-haiku-4-5-20251001"] = 1.25
            crr["claude-haiku-4-5-20251001"] = 0.10
            outr["claude-haiku-4-5-20251001"]= 5.00

            # Default: Opus 4.7 rates for unknown models (safe overestimate)
            default_ir   = 5.00
            default_ccr  = 6.25
            default_crr  = 0.50
            default_outr = 25.00
        }

        {
            sid=$1; repo=$2; model=$3
            inp=$4+0; cc=$5+0; cr=$6+0; out=$7+0

            if (repo_filter != "" && repo != repo_filter) next
            if (sid == "") next

            if (!(sid in sess_repo)) {
                sess_repo[sid] = repo
                sess_model[sid] = model
                session_count++
            }
            sess_input[sid]  += inp
            sess_cc[sid]     += cc
            sess_cr[sid]     += cr
            sess_output[sid] += out
        }

        END {
            if (session_count == 0) {
                print "No sessions found for the requested period."
                exit 0
            }

            # Compute per-session costs and accumulate totals
            total_cost = 0
            total_inp = 0; total_cc = 0; total_cr = 0; total_out = 0

            for (sid in sess_repo) {
                repo  = sess_repo[sid]
                model = sess_model[sid]
                inp   = sess_input[sid]
                cc    = sess_cc[sid]
                cr    = sess_cr[sid]
                out   = sess_output[sid]

                _ir   = (model in ir)   ? ir[model]   : default_ir
                _ccr  = (model in ccr)  ? ccr[model]  : default_ccr
                _crr  = (model in crr)  ? crr[model]  : default_crr
                _outr = (model in outr) ? outr[model] : default_outr

                cost = (inp * _ir + cc * _ccr + cr * _crr + out * _outr) / 1000000

                total_cost      += cost
                total_inp       += inp
                total_cc        += cc
                total_cr        += cr
                total_out       += out

                repo_cost[repo]   += cost
                model_cost[model] += cost
            }

            # Cache hit ratio: cache_read / (input + cache_create + cache_read)
            total_side = total_inp + total_cc + total_cr
            cache_ratio = (total_side > 0) ? total_cr / total_side : 0
            cache_pct = int(cache_ratio * 100 + 0.5)
            cache_indicator = (cache_ratio >= 0.70) ? "✓" : "⚠"

            # Header
            printf "\n=== Claude Code Cost Report: Last %d Days ===\n\n", days

            # Summary line
            sess_label = (session_count == 1) ? "session" : "sessions"
            printf "Total:  $%.2f  (%d %s)\n", total_cost, session_count, sess_label
            printf "Cache:  %d%% %s\n", cache_pct, cache_indicator
            if (cache_ratio < 0.70) {
                printf "        (below 70%% — consider longer system prompts to improve cache hits)\n"
            }

            # By Repo (sort by cost descending — print to temp array, then sort output)
            printf "\n── By Repo ──────────────────────────────────────────\n"
            n = 0
            for (repo in repo_cost) {
                n++
                repo_names[n] = repo
                repo_costs[n] = repo_cost[repo]
            }
            # Insertion sort descending by cost
            for (i = 2; i <= n; i++) {
                key_name = repo_names[i]
                key_cost = repo_costs[i]
                j = i - 1
                while (j >= 1 && repo_costs[j] < key_cost) {
                    repo_names[j+1] = repo_names[j]
                    repo_costs[j+1] = repo_costs[j]
                    j--
                }
                repo_names[j+1] = key_name
                repo_costs[j+1] = key_cost
            }
            limit = (n > 5) ? 5 : n
            for (i = 1; i <= limit; i++) {
                pct = (total_cost > 0) ? int(repo_costs[i] / total_cost * 100 + 0.5) : 0
                printf "  %-30s $%6.2f  %3d%%\n", repo_names[i], repo_costs[i], pct
            }
            if (n > 5) printf "  ... and %d more repos\n", n - 5

            # By Model
            printf "\n── By Model ─────────────────────────────────────────\n"
            m = 0
            for (model in model_cost) {
                m++
                model_names[m] = model
                model_costs[m] = model_cost[model]
            }
            for (i = 2; i <= m; i++) {
                key_name = model_names[i]
                key_cost = model_costs[i]
                j = i - 1
                while (j >= 1 && model_costs[j] < key_cost) {
                    model_names[j+1] = model_names[j]
                    model_costs[j+1] = model_costs[j]
                    j--
                }
                model_names[j+1] = key_name
                model_costs[j+1] = key_cost
            }
            for (i = 1; i <= m; i++) {
                pct = (total_cost > 0) ? int(model_costs[i] / total_cost * 100 + 0.5) : 0
                printf "  %-36s $%6.2f  %3d%%\n", model_names[i], model_costs[i], pct
            }
            printf "\n"
        }
    '
