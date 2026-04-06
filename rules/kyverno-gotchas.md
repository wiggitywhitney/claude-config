---
description: Kyverno gotchas — version numbering, GKE firewall requirements, subjects matching, Helm migration
paths: ["**/*.yaml", "**/*.yml", "**/kyverno*", "**/cluster-whisperer*"]
---

# Kyverno Gotchas

## Version numbering is split

Helm chart version and Kyverno app version are **independent numbers**.
- Helm chart `3.7.1` deploys app `v1.17.1`
- Always pin `--version 3.7.1` in the Helm install command
- GitHub releases show `v1.17.x` tags — there is no "Kyverno v3" application

## GKE private clusters require a firewall rule

Port 9443 must be open from the control plane to worker nodes. Without it, the webhook is unreachable and policies silently don't fire (or API requests time out). Only affects private GKE clusters, not standard/public.

## `subjects` matching requires `background: false`

ClusterPolicies that use `match.any[].subjects` to scope by ServiceAccount only work on live admission requests — the subject info is absent during background scans. Missing `background: false` causes unexpected behavior.

## `subjects` syntax: sibling of `resources`, same indentation

```yaml
match:
  any:
    - resources:
        operations: ["CREATE"]
      subjects:          # <-- same level as resources
        - kind: ServiceAccount
          name: my-sa
          namespace: my-namespace
```

`namespace` is required in the subjects entry for ServiceAccount kind.

## Helm chart v2 → v3 migration is not a direct upgrade

If Kyverno was previously installed with the old chart, uninstall first then reinstall. Direct `helm upgrade` is blocked. Fresh installs are unaffected.

## Policy exceptions scope changed (CVE-2024-48921)

Chart v3 restricts policy exceptions to the `kyverno` namespace by default (was all namespaces). Set `--set features.policyExceptions.namespace=*` to restore old behavior if needed.
