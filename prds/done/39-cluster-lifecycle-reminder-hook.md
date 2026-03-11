# PRD #39: Global Cluster Lifecycle Reminder Hook

**Status**: Complete
**Priority**: Medium
**Created**: 2026-03-11

## Problem

The current approach to cluster lifecycle management mandates teardown in PRD exit gates and a global CLAUDE.md rule ("A PRD cannot close until provisioned resources are torn down or handed off"). This creates friction during active development — clusters are legitimately needed across multiple sessions, and forcing teardown at PRD boundaries is premature. Meanwhile, the rule relies on Claude remembering to check and write warnings to MEMORY.md, which is fragile and doesn't reliably prevent forgotten clusters from accumulating costs (GKE clusters cost ~$0.19-$0.57/hr depending on configuration).

## Solution

Replace mandatory teardown rules with a global **SessionStart hook** that detects running Kind and GKE clusters and reminds the user, letting them decide whether to tear down or keep running. This shifts from "mandate teardown" to "ensure awareness."

Three changes:
1. **New SessionStart hook script** in claude-config that checks for running clusters globally
2. **Soften the global CLAUDE.md** infrastructure safety rule to remove mandatory teardown language
3. **Remove cluster teardown steps from PRDs** in cluster-whisperer and kubecon-2026-gitops

## Success Criteria

- When a Claude Code session starts and Kind or GKE clusters are running, the user sees a reminder with cluster names and the relevant teardown command
- When no clusters are running, the hook is silent (no noise)
- The global CLAUDE.md no longer mandates teardown at PRD close
- Existing PRDs no longer include cluster teardown as a milestone/exit gate
- The hook works regardless of which repo the session is in (global scope)

## Milestones

- [x] M1: Create the cluster-check script that detects running Kind and GKE clusters and outputs a reminder
- [x] M2: Wire the script as a global SessionStart hook in `~/.claude/settings.json`
- [x] M3: Soften the infrastructure safety rule in global `~/.claude/CLAUDE.md`
- [x] M4: Remove cluster teardown milestones/exit gates from PRDs in cluster-whisperer and kubecon-2026-gitops
- [x] M5: Tests for the cluster-check script
- [x] M6: End-to-end verification — start a session with a Kind cluster running and confirm the reminder appears

## Design Notes

- **Hook type**: SessionStart — catches forgotten clusters from previous sessions right when the user starts a new session and can act on it. SessionEnd exists but is cleanup/logging only (cannot show messages). Stop hook fires on every response (too noisy).
- **Scope**: Global hook in `~/.claude/settings.json`, not per-project. Forgotten clusters cost money regardless of which repo you're in.
- **Both Kind and GKE**: Kind clusters are free but consume local resources. GKE clusters cost money. The reminder should differentiate urgency (e.g., "GKE cluster running — costs ~$0.57/hr" vs "Kind cluster running — local resources only").
- **Cluster detection**: `kind get clusters` for Kind, `gcloud container clusters list --format='value(name,zone)' --filter="name~^cluster-whisperer OR name~^kubecon-gitops"` for GKE. The GKE filter uses known project prefixes.
- **Teardown command hints**: The reminder should include the specific teardown command for each detected cluster (e.g., `./demo/cluster/teardown.sh` for cluster-whisperer clusters, `./scripts/teardown-cluster.sh` for kubecon-gitops clusters).
- **Graceful degradation**: If `kind` or `gcloud` are not installed, skip that check silently. Don't error on missing tools.
- **Output format**: Return JSON with `additionalContext` containing the reminder text, following the existing SessionStart hook pattern.
- **Script location**: `scripts/check-running-clusters.sh` in claude-config repo, symlinked or referenced by absolute path from global settings.

## Out of Scope

- Automatic teardown (the whole point is to let the user decide)
- Monitoring cluster costs in real-time
- Clusters from other projects not using the `cluster-whisperer-*` or `kubecon-gitops-*` naming prefixes
- Changes to the setup/teardown scripts themselves

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-11 | SessionStart hook over SessionEnd | SessionEnd is cleanup-only, can't show messages. SessionStart catches forgotten clusters when user can act. |
| 2026-03-11 | Global scope, not per-project | Forgotten clusters cost money regardless of current repo |
| 2026-03-11 | Both Kind and GKE with differentiated urgency | Kind is free (local resources), GKE costs money — user should know the difference |
| 2026-03-11 | Replace mandatory teardown with awareness | Clusters are legitimately needed across sessions; forcing teardown creates friction |
