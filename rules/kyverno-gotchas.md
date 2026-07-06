---
description: Kyverno gotchas — version numbering, GKE firewall requirements, subjects matching, Helm migration
paths: ["**/*.yaml", "**/*.yml", "**/kyverno*"]
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

## `kinds` is required in `resources` even when using subject scoping

Kyverno rejects a ClusterPolicy at apply time if the `resources` block doesn't include at least one `kinds` entry:

```text
admission webhook "validate-policy.kyverno.svc" denied the request:
at least one element must be specified in a kind block, the kind attribute is mandatory when working with the resources element
```

For an allowlist that blocks all non-approved types, use `kinds: ["*"]` to intercept all resource types and let the deny conditions do the filtering:

```yaml
resources:
  kinds: ["*"]      # required — wildcard captures all resource types
  operations: ["CREATE"]
```

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

## Policy validation webhook times out when named kinds are in `exclude` blocks and cluster has unavailable API groups

When applying or updating a ClusterPolicy that has an `exclude` block with named resource kinds (e.g. `SelfSubjectReview`, `TokenReview`), Kyverno's policy validation webhook (`validate-policy.kyverno.svc`) must discover all API resources to validate those kind names. If any API group is unavailable (common: `metrics.k8s.io/v1beta1` not responding), the discovery hangs and the webhook times out with:

```text
Internal error occurred: failed calling webhook "validate-policy.kyverno.svc": context deadline exceeded
```

**Fix:** Use only `kinds: ["*"]` (wildcard) in the `exclude` block — the wildcard bypasses named-kind validation entirely. Do NOT list specific kinds like `SelfSubjectReview` in the exclude block when the cluster has flaky API groups.

```yaml
exclude:
  any:
    - resources:
        kinds: ["*"]   # wildcard: no kind validation needed
```

Note: `kinds: ["*"]` in exclude matches all resources, so use subject or namespace scoping to narrow what gets excluded.

## Raise API client rate limits in CRD-heavy environments (Crossplane)

Kyverno's default API client rate limit is 20 QPS / 50 burst. On startup, Kyverno walks every API group to discover resource types for its webhook rules. With 300+ Crossplane CRDs, this discovery walk saturates the default rate limit, causing delays and timeouts that can cause Kyverno to lose its leadership lease and trigger the exit-0 restart loop.

Set both controllers to 100/100 at install time:

```bash
--set admissionController.container.extraArgs.clientRateLimitQPS=100
--set admissionController.container.extraArgs.clientRateLimitBurst=100
--set backgroundController.container.extraArgs.clientRateLimitQPS=100
--set backgroundController.container.extraArgs.clientRateLimitBurst=100
```

Community starting point for large clusters. Some operators use 500/500 but that increases API server pressure.

## Exclude apiextensions.k8s.io from webhook rules via matchConditions

With `kinds: ["*"]` in a Kyverno policy, the API server sends ALL admission requests to Kyverno — including every CRD registration from Crossplane's 300+ provider CRDs. This adds significant webhook round-trip overhead during the CRD flood window and can contribute to API server degradation on managed control planes (GKE).

`matchConditions` (CEL expressions, K8s 1.27+) run inside the API server before it decides to call the webhook. The API server skips the call entirely for matching requests:

```bash
--set-json 'config.webhooks.matchConditions=[{"name":"exclude-crd-resources","expression":"!(request.resource.group == \"apiextensions.k8s.io\")"}]'
```

This is a true webhook-level exclusion — unlike `resourceFilters` which only tells Kyverno to discard the request after the call is already made.

## Kyverno does not discover CRDs registered after startup (v1.17.1 / chart 3.7.1)

Kyverno only discovers API resources at startup. CRDs registered after Kyverno starts are invisible to it — admission requests for those resource types are denied with:

```text
admission webhook "validate.kyverno.svc-fail" denied the request:
resource <name> not found in group <group>/<version>
```

This happens even when the policy uses `kinds: ["*"]` (wildcard), because Kyverno still tries to look up the incoming GVK in its internal registry during request processing.

**Fix:** Restart the Kyverno admission controller after the new CRDs are registered. This forces a full API re-discovery:

```bash
kubectl rollout restart deployment/kyverno-admission-controller -n kyverno
kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=120s
```

**Pattern in cluster-whisperer:** Crossplane installs ~300 CRDs after Kyverno starts. The `ClusterProviderConfig` CRD from `provider-kubernetes` is never picked up via watch — Kyverno must be restarted before it can be applied. No amount of waiting fixes this; a restart is required every time.

## GKE: set `forceFailurePolicyIgnore` to prevent Konnectivity deadlock

When Kyverno restarts (e.g., after API discovery changes from a CRD flood), its admission webhooks are briefly unreachable. With `failurePolicy: Fail`, the Kubernetes API server denies any admission request — including `TokenReview` — that passes through the webhook during the outage. `TokenReview` is what GKE's Konnectivity agents use to re-authenticate their tunnel to the control plane. If those requests fail, Konnectivity loses all agents and returns "No agent available" for `kubectl logs`, `kubectl exec`, and all admission webhook calls — even after Kyverno recovers.

Note: `config.resourceFilters` already excludes `TokenReview` from Kyverno *policy evaluation*, but that filtering happens *after* the webhook call is received. If Kyverno is unreachable, the call fails before filtering occurs.

**`resourceFilters` is NOT webhook-level exclusion.** Adding a resource type to `config.resourceFilters` or `config.resourceFiltersInclude` tells Kyverno to discard the request internally, but the Kubernetes API server still calls the Kyverno webhook for those resources. The full call is made before Kyverno discards it. This does not reduce webhook round-trip volume.

To reduce CRD registration webhook overhead (e.g., during Crossplane provider install — 300+ CRDs each triggering a round-trip), `resourceFiltersInclude` provides marginal help (Kyverno returns faster internally):

```bash
--set 'config.resourceFiltersInclude[0]=[CustomResourceDefinition,*,*]'
```

`resourceFiltersInclude` appends to the default filter list without replacing it. Supported since chart ~3.3.x (app v1.12.0+).

**True webhook-level exclusion** (API server skips the call entirely) requires either:
- **matchConditions** (CEL expressions, K8s 1.27+): `config.matchConditions` in the Helm chart values — runs before the request reaches Kyverno, preventing the call entirely
- **Scoped policy kinds**: Kyverno dynamically builds its webhook rules based on installed policies. If no policy matches `CustomResourceDefinition`, Kyverno removes it from webhook rules. Policies using `kinds: ["*"]` force CRDs into the rules.

**Primary fix for the Crossplane + GKE instability** is `forceFailurePolicyIgnore` (eliminates 10s timeout accumulation during Kyverno restarts) plus an API server kubectl probe before retrying failed Helm steps.

**Fix:** Install Kyverno with `failurePolicy: Ignore` on all webhooks:

```bash
helm install kyverno kyverno/kyverno \
  --set features.forceFailurePolicyIgnore.enabled=true \
  ...
```

Policies are still enforced when Kyverno is running. `failurePolicy: Ignore` only affects the brief window when Kyverno is restarting. GKE explicitly recommends this for any webhook that might create circular dependencies with system components.

## Kyverno native OTLP export is broken — gRPC-Go v1.63 dns resolver regression (verified chart 3.7.1 / app v1.17.1)

Kyverno's built-in OTel exporter (enabled via `admissionController.tracing.enabled: true` / `otelConfig: grpc`) fails with:

```text
name resolver error: produced zero addresses
```

even against a bare ClusterIP address like `10.96.x.x:4317`. The bug is a regression introduced in gRPC-Go v1.63: `grpc.NewClient()` defaults to the `dns` resolver instead of `passthrough`, causing it to treat literal IP addresses as hostnames to be looked up. DNS resolution of a ClusterIP returns zero A records, so the connection never opens — zero spans and zero metrics reach the Collector.

The bug is baked into Kyverno's bundled binary. There is no operator-level workaround. A fork would need to replace `grpc.NewClient("<host>:<port>")` with `grpc.Dial("passthrough:///<host>:<port>")` (even though `grpc.Dial` is deprecated in v1.63+, it still defaults to `passthrough` — the problem is specifically that `grpc.NewClient` does not). The gRPC-Go issue is tracked at https://github.com/grpc/grpc-go/issues/7625.

**Recommended alternative:** Use the Datadog Agent Autodiscovery openmetrics check instead of native OTLP. Kyverno's admission controller serves Prometheus metrics on port 8000. Add a pod annotation to enable the Agent `kyverno` check:

```yaml
# in admissionController.podAnnotations (Helm values)
ad.datadoghq.com/kyverno.checks: |
  {
    "kyverno": {
      "instances": [{"openmetrics_endpoint": "http://%%host%%:8000/metrics"}]
    }
  }
```

The Agent check emits `kyverno.*` dot-format names, which are compatible with the official Datadog OOTB Kyverno dashboard. This is the same proven Autodiscovery pattern used for Falco, cert-manager, and Istio.
