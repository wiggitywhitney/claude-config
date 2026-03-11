#!/usr/bin/env bash
# ABOUTME: SessionStart hook that detects running Kind and GKE clusters
# ABOUTME: Outputs a JSON reminder with additionalContext when clusters are found
set -uo pipefail

# Read and discard stdin (SessionStart passes JSON payload, we don't need it)
cat > /dev/null

REMINDERS=""

# ── Kind clusters ──────────────────────────────────────────────────

if command -v kind &>/dev/null; then
    KIND_OUTPUT=$(kind get clusters 2>/dev/null || true)
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
    GKE_OUTPUT=$(gcloud container clusters list \
        --format='value(name,zone)' \
        --filter="name~^cluster-whisperer OR name~^kubecon-gitops" \
        2>/dev/null || true)
    if [[ -n "$GKE_OUTPUT" ]]; then
        while IFS=$'\t' read -r name zone; do
            [[ -z "$name" ]] && continue
            REMINDERS="${REMINDERS}GKE cluster running: ${name} (${zone}) — costs money (~\$0.19-0.57/hr)\n"
            if [[ "$name" == cluster-whisperer* ]]; then
                REMINDERS="${REMINDERS}  Teardown: ./demo/cluster/teardown.sh\n\n"
            elif [[ "$name" == kubecon-gitops* ]]; then
                REMINDERS="${REMINDERS}  Teardown: ./scripts/teardown-cluster.sh\n\n"
            else
                REMINDERS="${REMINDERS}  Teardown: gcloud container clusters delete ${name} --zone ${zone}\n\n"
            fi
        done <<< "$GKE_OUTPUT"
    fi
fi

# ── Output ─────────────────────────────────────────────────────────

if [[ -z "$REMINDERS" ]]; then
    # No clusters running — silent exit
    exit 0
fi

# Build the reminder message
HEADER="Running clusters detected — review and tear down if no longer needed:"
FULL_MESSAGE="${HEADER}\n\n${REMINDERS}"

# Escape for JSON: replace newlines with \n, escape quotes and backslashes
JSON_MESSAGE=$(printf '%b' "$FULL_MESSAGE" | python3 -c "
import sys, json
text = sys.stdin.read().rstrip()
print(json.dumps(text))
" 2>/dev/null)

printf '{"additionalContext": %s}\n' "$JSON_MESSAGE"
