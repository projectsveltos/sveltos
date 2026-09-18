---
title: Restricting sveltos-agent RBAC in Pull Mode
description: A worked example narrowing sveltos-agent's ClusterRole and pairing it with namespace-scoped watch mode, so a Pull Mode managed cluster's owner can grant Sveltos read access to only the namespaces and resource kinds it actually needs.
tags:
    - Kubernetes
    - add-ons
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## Why This Matters

[Restricting sveltos-applier to Specific Namespaces](register_cluster_pull_mode.md#restricting-sveltos-applier-to-specific-namespaces) only covers part of a Pull Mode managed cluster's Sveltos footprint. `sveltos-agent`, the component that evaluates Classifiers, HealthChecks, EventSources and Reloaders, runs in the same cluster and, by default, is also granted a cluster-wide `ClusterRole`: a wildcard `get`/`list`/`watch` grant across every group and resource, so it can evaluate whatever `resourceSelectors` any Classifier/HealthCheck/EventSource happens to target. `drift-detection-manager`, which watches whatever a `ClusterProfile`/`Profile` with `syncMode: ContinuousWithDriftDetection` deploys, runs there too with the same kind of cluster-wide wildcard `ClusterRole` (narrowed the same way via [Drift Detection Manager Overrides](../getting_started/install/air_gapped_installation.md#drift-detection-manager-overrides)). Restricting `sveltos-applier` alone leaves both of those broader credentials untouched.

This page walks through narrowing sveltos-agent's own footprint too, so registering a cluster in Pull Mode doesn't implicitly also grant Sveltos read access to the whole cluster.

## Overview

Three pieces work together:

1. **`agent.projectsveltos.io/watch-namespaces`** on the `SveltosCluster`, restricts sveltos-agent's own watches (Classifier/HealthCheck/EventSource `resourceSelectors`, Reloader's ConfigMap/Secret/target watches) to the listed namespaces. It's the same annotation already used for `sveltos-applier` (previous section) and for agentless mode ([Namespace-Scoped Watch Mode](../getting_started/install/agentless_limited_rbac.md#the-fix-namespace-scoped-watch-mode)); one annotation controls all of them.
2. **A `sveltosagent.projectsveltos.io/config-override-ref` patch**, narrows the `ClusterRole` classifier hands sveltos-agent, removing the wildcard rule.
3. **Namespaced `Role`/`RoleBinding`s you create yourself**, grant back, per namespace, exactly the resource kinds your Classifiers/HealthChecks/EventSources/Reloaders for this cluster actually target.

!!! warning
    Actually restricting the watches requires a valid Sveltos Enterprise or Enterprise Plus license granting the `NamespaceScopedAgents` feature, the same one agentless mode needs. Without one, `--watch-namespaces` is ignored by sveltos-agent and its watches proceed cluster-wide, which will fail against a namespace-scoped credential. Contact `support@projectsveltos.io` to explore license options.

!!! warning
    Classifier does not yet generate a narrowed RBAC bundle for sveltos-agent in Pull Mode: it always ships the same cluster-wide `ClusterRole` shown below, the same as it does today for `sveltos-applier`. Steps 2 and 3 below are something you apply yourself, on top of what Sveltos generates, the same way you already do for `sveltos-applier`'s `ClusterRole` (see [Sveltos Applier Overrides](../getting_started/install/air_gapped_installation.md#sveltos-applier-overrides)).

## Worked Example

Example environment: a cluster registered in Pull Mode (`prod-cluster` in namespace `monitoring`, following [Register Cluster Pull Mode](register_cluster_pull_mode.md)), with Classifiers/HealthChecks/EventSources/Reloaders that only ever target `Deployments`, `ConfigMaps` and `Secrets` in namespace `team-a`.

### 1. Restrict the watch to `team-a`

Already covered in [Restricting sveltos-applier to Specific Namespaces](register_cluster_pull_mode.md#restricting-sveltos-applier-to-specific-namespaces): add (or reuse) the annotation on the `SveltosCluster`.

```yaml hl_lines="6"
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: prod-cluster
  namespace: monitoring
  annotations:
    agent.projectsveltos.io/watch-namespaces: "team-a"
```

This is the same annotation, and it's enough by itself to also scope sveltos-agent's watches; no separate annotation is needed for it.

### 2. Narrow sveltos-agent's ClusterRole

By default, sveltos-agent's `ClusterRole` (`sveltos-agent-manager-role`, [as classifier applies it](https://raw.githubusercontent.com/projectsveltos/classifier/refs/heads/main/pkg/agent/sveltos-agent.yaml)) includes this rule, which is what lets it evaluate arbitrary `resourceSelectors` cluster-wide:

```yaml
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "impersonate", "list", "watch"]
```

Create a config-override ConfigMap that removes it, referenced via the `sveltosagent.projectsveltos.io/config-override-ref` annotation:

```yaml hl_lines="6"
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: prod-cluster
  namespace: monitoring
  annotations:
    sveltosagent.projectsveltos.io/config-override-ref: default/sveltos-agent-rbac-override
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sveltos-agent-rbac-override
  namespace: default
data:
  clusterrole-patch: |-
      patch: |-
        - op: remove
          path: /rules/1
      target:
        kind: ClusterRole
        name: sveltos-agent-manager-role
```

Check the `ClusterRole` sveltos-agent is actually running with before applying this: the exact rule index depends on the release. `classifierreports`, `eventreports`, `healthcheckreports` and `reloaderreports` already share one rule with `create`/`delete`/`get`/`list`/`patch`/`update`/`watch`, so removing the wildcard rule alone doesn't take `watch` away from any of them.

!!! note
    If a `getPatchesFromConfigMap`-applied patch ever needs more than one op against the same object (for example, removing a rule *and* separately adding a verb elsewhere), put every op for that object in one `patch:` document, not one ConfigMap key per op. `getPatchesFromConfigMap` iterates a ConfigMap's keys in Go map order, which isn't deterministic, so index-based ops split across separate keys could apply in either order across reconciles. One key applies its ops as a single ordered [RFC6902](https://www.rfc-editor.org/rfc/rfc6902) sequence instead.

!!! warning
    Unlike the example in [Sveltos Agent Overrides](../getting_started/install/air_gapped_installation.md#sveltos-agent-overrides), don't `remove path: /rules` wholesale here: that also removes sveltos-agent's ability to create/update its own report CRs (`classifierreports`, `eventreports`, `healthcheckreports`, `reloaderreports`) and to `impersonate` tenant-admin ServiceAccounts, both unrelated to `--watch-namespaces` and needed regardless (see the breakdown below).

### 3. Grant back what's actually needed, per namespace

sveltos-agent's remaining permissions fall into three groups.

**Stays cluster-scoped, unaffected by `--watch-namespaces`**, already granted by the narrowed `ClusterRole`, nothing to add:

- `lib.projectsveltos.io`: `classifiers`, `healthchecks`, `eventsources`, `reloaders` (+ `/finalizers`), `debuggingconfigurations`, these CRs are themselves cluster-scoped.
- `authentication.k8s.io/tokenreviews`, `authorization.k8s.io/subjectaccessreviews`, used for sveltos-agent's own `SelfSubjectRulesReview` pre-check.

**Needs a `Role` in sveltos-agent's own namespace (`projectsveltos`)**, not part of `--watch-namespaces`, it's where sveltos-agent itself runs and writes reports:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sveltos-agent-scoped-reports
  namespace: projectsveltos
rules:
- apiGroups: ["lib.projectsveltos.io"]
  resources:
  - classifierreports
  - eventreports
  - healthcheckreports
  - reloaderreports
  - classifierreports/status
  - eventreports/status
  - healthcheckreports/status
  - reloaderreports/status
  verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["impersonate"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sveltos-agent-scoped-reports
  namespace: projectsveltos
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: sveltos-agent-scoped-reports
subjects:
- kind: ServiceAccount
  name: sveltos-agent-manager
  namespace: projectsveltos
```

!!! note
    The `apps`/`deployments` `list` rule above is unrelated to any Classifier/HealthCheck/EventSource/Reloader: sveltos-agent lists Deployments in its own namespace at startup to detect whether `sveltos-applier` (deployed there too) is present, which is how it tells Pull Mode apart from plain push mode. It's namespace-scoped to `projectsveltos` already, `list` is the only verb it needs, but it still has to be granted explicitly once the wildcard rule is gone.

**Needs a `Role` in each namespace listed in `--watch-namespaces`**, the resource kinds your Classifiers/HealthChecks/EventSources/Reloaders for this cluster actually target; here, `Deployments`, `ConfigMaps` and `Secrets` in `team-a`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: sveltos-agent-scoped-reader
  namespace: team-a
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sveltos-agent-scoped-reader
  namespace: team-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: sveltos-agent-scoped-reader
subjects:
- kind: ServiceAccount
  name: sveltos-agent-manager
  namespace: projectsveltos
```

If a Reloader targets a `Deployment`/`StatefulSet`/`DaemonSet` by name in one of these namespaces, sveltos-agent reads it individually rather than listing/watching it, so `get` alone would be enough for that specific kind if you'd rather not grant `list`/`watch` on it too. In practice it's simplest to grant all three together, as above.

### 4. Verify

Bump sveltos-agent's log verbosity via the same override ConfigMap (a `deployment-patch` key targeting the `Deployment`'s `--v` arg can sit next to `clusterrole-patch` above, see [Sveltos Agent Overrides](../getting_started/install/air_gapped_installation.md#sveltos-agent-overrides) for that patch shape), then check its logs for `forbidden` after a Classifier/HealthCheck/EventSource/Reloader reconciles:

```bash
kubectl logs -n projectsveltos deployment/sveltos-agent-manager | grep -i forbidden
```

A cluster-wide `List`/`Watch` still reaching past `team-a` shows up here immediately, as `<resource> is forbidden ... at the cluster scope`, meaning something is still being requested cluster-wide outside the namespaced `Role`s above, most often because a `resourceSelector` or Reloader target names a namespace you haven't also granted a `Role` in.

Once the logs are clean, a Report for a resource in `team-a` populates normally, and one whose `resourceSelector` would otherwise match cluster-wide comes back with an empty match set for anything outside `team-a`, not an error: namespaces outside `--watch-namespaces` are never queried at all, so there's nothing there to be denied.

## Next Steps

Continue with [Registration Pull Mode](register_cluster_pull_mode.md) validation, or apply the same narrowing to `sveltos-applier`'s own `ClusterRole` via [Sveltos Applier Overrides](../getting_started/install/air_gapped_installation.md#sveltos-applier-overrides).
