# Infrastructure Safety

- When dealing with infrastructure directly (Kubernetes clusters, databases, cloud resources), always make a backup of any files you edit.
- NEVER render a system unbootable or overwrite any database or datastore without explicit permission.
- List planned infrastructure commands before executing so the user can review scope.
- Only apply Kubernetes resource manifests directly. Do not run host-level setup scripts unless explicitly asked.
- **Cloud resource lifecycle:** Every `setup-*.sh` must have a corresponding `teardown-*.sh`. A global SessionStart hook (`scripts/check-running-clusters.sh` in claude-config) reports the clusters it can see with a teardown command for each, and says so when it could not look. That reminder is why there are no mandatory teardown gates. Its silence is not proof that nothing is running: it sees Kind clusters and GKE clusters in the one project the local `gcloud` config names, and nothing else. If it reports that a check could not complete, treat the cloud state as unknown and run `gcloud container clusters list --project PROJECT_ID` before concluding nothing is up. When provisioning new cloud resources, mention the teardown command so the user knows how to clean up later.
