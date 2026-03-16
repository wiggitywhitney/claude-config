---
paths: ["**/*.yaml", "**/*.yml", "**/*.sh", "**/k8s/**", "**/manifests/**", "**/Dockerfile*"]
description: Safety rules for Kubernetes clusters, databases, cloud resources, and infrastructure
---

# Infrastructure Safety

- When dealing with infrastructure directly (Kubernetes clusters, databases, cloud resources), always make a backup of any files you edit.
- NEVER render a system unbootable or overwrite any database or datastore without explicit permission.
- List planned infrastructure commands before executing so the user can review scope.
- Only apply Kubernetes resource manifests directly. Do not run host-level setup scripts unless explicitly asked.
- **Cloud resource lifecycle:** Every `setup-*.sh` must have a corresponding `teardown-*.sh`. A global SessionStart hook (`scripts/check-running-clusters.sh` in claude-config) detects running Kind and GKE clusters at session start and reminds the user — no mandatory teardown gates needed. When provisioning new cloud resources, mention the teardown command so the user knows how to clean up later.
