#!/usr/bin/env bash
# ABOUTME: SessionStart hook that detects running Kind and GKE clusters
# ABOUTME: Outputs a JSON reminder with additionalContext when clusters are found
set -uo pipefail

# Read and discard stdin (SessionStart passes JSON payload, we don't need it)
cat > /dev/null

REMINDERS=""
# Checks that could not run are reported separately, so the message never
# claims a cluster was detected when what happened was a failure to look.
PROBLEMS=""

# ── Kind clusters ──────────────────────────────────────────────────

if command -v kind &>/dev/null; then
    # A failed listing is not an empty listing. Discarding the error here would
    # report "no Kind clusters" whenever the container runtime is unreachable,
    # which is the same silent-success defect the GKE half had.
    KIND_OUTPUT=$(kind get clusters 2>&1)
    KIND_STATUS=$?

    # An unreachable container runtime is the one failure worth staying quiet about:
    # no daemon means no Kind cluster can be running, so there is nothing to warn
    # about, and Colima is stopped most of the time here. Warning on it would put a
    # notice in every session that is always true and never actionable.
    if (( KIND_STATUS != 0 )) && [[ "$KIND_OUTPUT" == *"failed to connect to the docker API"* ]]; then
        KIND_STATUS=0
        KIND_OUTPUT=""
    fi

    if (( KIND_STATUS != 0 )); then
        KIND_ERROR=$(printf '%s' "$KIND_OUTPUT" | head -1)
        KIND_ERROR=${KIND_ERROR//\\/\\\\}
        PROBLEMS="${PROBLEMS}Kind check failed, so local clusters cannot be detected.\n"
        PROBLEMS="${PROBLEMS}  kind said: ${KIND_ERROR}\n\n"
        KIND_OUTPUT=""
    fi

    if [[ -n "$KIND_OUTPUT" ]]; then
        while IFS= read -r cluster; do
            [[ -z "$cluster" ]] && continue
            REMINDERS="${REMINDERS}Kind cluster running: ${cluster} (local resources only)\n"
            REMINDERS="${REMINDERS}  Teardown: kind delete cluster --name ${cluster}\n\n"
        done <<< "$KIND_OUTPUT"
    fi
fi

# ── GKE clusters ──────────────────────────────────────────────────

if command -v gcloud &>/dev/null; then
    # Resolve the project explicitly. Depending on ambient gcloud config and
    # discarding the error left this check silent for months while the project
    # was unset, so an unusable configuration has to be loud instead.
    GKE_PROJECT=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')

    if [[ -z "$GKE_PROJECT" || "$GKE_PROJECT" == "(unset)" ]]; then
        PROBLEMS="${PROBLEMS}GKE check did not run: no gcloud project is configured, so cloud clusters cannot be detected.\n"
        PROBLEMS="${PROBLEMS}  Fix: gcloud config set project PROJECT_ID\n\n"
        GKE_OUTPUT=""
    else
        # No name filter: a forgotten cluster is likely the one that never got
        # a conventional name, so every cluster in the project is reported.
        GKE_OUTPUT=$(gcloud container clusters list \
            --project "$GKE_PROJECT" \
            --format='value(name,zone)' \
            2>&1)
        GKE_STATUS=$?

        if (( GKE_STATUS != 0 )); then
            GKE_ERROR=$(printf '%s' "$GKE_OUTPUT" | head -1)
            GKE_ERROR=${GKE_ERROR//\\/\\\\}
            PROBLEMS="${PROBLEMS}GKE check failed for project ${GKE_PROJECT}, so cloud clusters cannot be detected.\n"
            PROBLEMS="${PROBLEMS}  gcloud said: ${GKE_ERROR}\n\n"
            GKE_OUTPUT=""
        fi
    fi

    if [[ -n "$GKE_OUTPUT" ]]; then
        while IFS=$'\t' read -r name zone; do
            [[ -z "$name" ]] && continue
            REMINDERS="${REMINDERS}GKE cluster running: ${name} (${zone}) — costs money (~\$0.19-0.57/hr)\n"
            if [[ "$name" == cluster-whisperer* ]]; then
                REMINDERS="${REMINDERS}  Teardown: ./demo/cluster/teardown.sh\n\n"
            elif [[ "$name" == kubecon-gitops* ]]; then
                REMINDERS="${REMINDERS}  Teardown: ./scripts/teardown-cluster.sh\n\n"
            else
                REMINDERS="${REMINDERS}  Teardown: gcloud container clusters delete ${name} --zone ${zone} --project ${GKE_PROJECT}\n\n"
            fi
        done <<< "$GKE_OUTPUT"
    fi
fi

# ── Output ─────────────────────────────────────────────────────────

if [[ -z "$REMINDERS" && -z "$PROBLEMS" ]]; then
    # Nothing running and every check completed — silent exit
    exit 0
fi

# Build the reminder message
FULL_MESSAGE=""
if [[ -n "$REMINDERS" ]]; then
    FULL_MESSAGE="Running clusters detected — review and tear down if no longer needed:\n\n${REMINDERS}"
fi
if [[ -n "$PROBLEMS" ]]; then
    FULL_MESSAGE="${FULL_MESSAGE}Cluster check could not complete, so a running cluster may be going unreported:\n\n${PROBLEMS}"
fi

# Escape for JSON: replace newlines with \n, escape quotes and backslashes
JSON_MESSAGE=$(printf '%b' "$FULL_MESSAGE" | python3 -c "
import sys, json
text = sys.stdin.read().rstrip()
print(json.dumps(text))
" 2>/dev/null)

# An empty JSON_MESSAGE would emit invalid JSON, which a hook runner skips
# silently — the same invisible failure this script was just repaired to avoid.
if [[ -z "$JSON_MESSAGE" ]]; then
    echo "check-running-clusters: failed to encode the reminder message" >&2
    exit 0
fi

printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": %s}}\n' "$JSON_MESSAGE"
