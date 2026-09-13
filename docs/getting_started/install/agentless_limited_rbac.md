---
title: Running Agents with Limited RBAC in Agentless Mode
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn how to run Sveltos against a managed cluster without needing broad read access to it, so the cluster owner keeps control of what Sveltos can see.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## Why This Matters

Sveltos is often run by one party on behalf of another. A company selling managed Kubernetes clusters to its own customers may use Sveltos to deploy and maintain a subset of resources on their behalf. Inside a single organization, a platform team may provision clusters that application teams then own and run.

In both cases, the party running Sveltos should not need broad read access to the cluster to do its job, and the cluster owner should not have to grant it. A customer paying for a managed cluster expects that nobody else, including the vendor's own tooling, can read anything beyond what that tooling is actually responsible for. An application team that owns a cluster the platform team provisioned should not have to hand that platform team's tooling a credential that can see everything running in it, just because the platform team happens to run Sveltos on their behalf.

Agentless mode is what makes this possible: it lets you grant Sveltos read access to only the resource kinds it manages, in only the namespaces it's responsible for, and nothing else.

## How Sveltos Watches a Managed Cluster

When a managed cluster is registered with Sveltos, `sveltos-agent` is deployed for it automatically. If any `ClusterProfile` or `Profile` with `syncMode: ContinuousWithDriftDetection` matches that cluster, `drift-detection-manager` is deployed for it too.

Depending on the Sveltos mode, these components are deployed in the **management** cluster (agentless mode, `agent.managementCluster=true`, also called Centralized Agent mode) or directly inside the **managed** cluster (the default mode). Everything covered below only applies to agentless mode. In the default mode, both components are deployed inside the managed cluster with a `ClusterRole` Sveltos provisions itself, so there is no separate credential for the cluster owner to restrict in the first place.

In agentless mode, `sveltos-agent` and `drift-detection-manager` run in the management cluster and reach each managed cluster through its own registered credential. By default, both components watch resources **cluster-wide**: across every namespace in the managed cluster, regardless of what that credential is actually meant to see.

## What RBAC Do They Actually Need?

There is no fixed, one-size-fits-all Role to grant. `sveltos-agent` and `drift-detection-manager` only need `get`/`list`/`watch` on whatever resource kinds your `ClusterProfiles`/`Classifiers` actually target in that cluster, not on every resource type Kubernetes has. This alone is already a meaningful boundary: a customer or application team can see exactly, kind by kind, what Sveltos is able to read.

That's only half of it, though. Take a `ClusterProfile` that only ever deploys `Deployments` and `ConfigMaps` into the `team-a` namespace: the credential only needs `get`/`list`/`watch` on those two kinds. But by default, `sveltos-agent` and `drift-detection-manager` still watch `Deployments` and `ConfigMaps` **cluster-wide**, not just in `team-a`. A cluster-wide watch needs a `ClusterRole`; a `Role` scoped to `team-a` alone can't satisfy it, no matter how correctly the resource kinds are scoped. Narrowing the resource kinds isn't enough by itself: the watch also has to be narrowed to the same namespace, which is exactly what the next section covers.

## The Fix: Namespace-Scoped Watch Mode

[Namespace-Scoped Watch Mode](../../features/configuration_drift.md#namespace-scoped-watch-mode) closes that gap: adding the `agent.projectsveltos.io/watch-namespaces` annotation to the Cluster or SveltosCluster instance, with a comma-separated list of namespaces, restricts both components' watches to just those namespaces. Once the watch itself is scoped to `team-a`, a `Role` granting `get`/`list`/`watch` on `Deployments` and `ConfigMaps` in `team-a` becomes sufficient: the credential and the watch scope now match, and Sveltos is never able to see anything outside the boundary the cluster owner agreed to.

!!! example ""
    ```yaml hl_lines="6"
    apiVersion: cluster.x-k8s.io/v1beta1
    kind: Cluster
    metadata:
      name: my-cluster
      annotations:
        agent.projectsveltos.io/watch-namespaces: "team-a,team-b"
    ```

## Worked Example

1. On the managed cluster, create a `ServiceAccount`, `Role`, and `RoleBinding` scoped to the namespace(s) and resource kinds your `ClusterProfiles`/`Classifiers` for this cluster actually need:

    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: sveltos-limited
      namespace: team-a
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: sveltos-limited-role
      namespace: team-a
    rules:
    - apiGroups: ["apps"]
      resources: ["deployments"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: sveltos-limited-rolebinding
      namespace: team-a
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: sveltos-limited-role
    subjects:
    - kind: ServiceAccount
      name: sveltos-limited
      namespace: team-a
    ```

2. Generate a kubeconfig from that ServiceAccount and register the cluster following the [Programmatic Registration](../../register/register-cluster.md#programmatic-registration) steps, instead of the default `sveltosctl generate kubeconfig --create` (which grants `cluster-admin`).

3. Add the `agent.projectsveltos.io/watch-namespaces` annotation to the Cluster or SveltosCluster resource, listing the same namespace(s) the Role grants access to:

    ```yaml
    apiVersion: cluster.x-k8s.io/v1beta1
    kind: Cluster
    metadata:
      name: my-cluster
      annotations:
        agent.projectsveltos.io/watch-namespaces: "team-a"
    ```

With both pieces in place, `sveltos-agent` and `drift-detection-manager` watch only `team-a`, matching exactly what the registered credential is allowed to see: nothing else in the cluster is visible to Sveltos, no matter who is running it.

!!! warning
    Restricting the actual **watches** requires a valid Sveltos Enterprise or Enterprise Plus license granting the `NamespaceScopedAgents` feature. Without one, the annotation is ignored for that purpose and watches proceed cluster-wide, which will still fail against a namespace-scoped credential. Contact `support@projectsveltos.io` to explore license options.

## Next Steps

Continue with the **sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).
