---
title: Sveltos EventTrigger - Templating with oneForEvent false
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - Sveltos
    - EventTrigger
    - Templating
    - oneForEvent
    - multi-cluster
    - cluster-management
authors:
    - Eleni Grosdouli
    - Gianluca Mardente
---

# Templating when oneForEvent is false

The following resources are available during template instantiation if the `EventTrigger` has `oneForEvent` set to `false`.

| Name | Meaning | Availability |
| :--- | :--- | :--- |
| **MatchingResources** | A list of references to all resources that triggered an event, including their **apiVersion**, **kind**, **name**, and **namespace**. | Always available if Kubernetes resources were a match. |
| **Resources** | A list of the full Kubernetes resources that triggered the events. All of their fields are available for templating. | Only if `collectResource` is set to `true` in the `eventSource`. |
| **CloudEvents** | A list of the raw CloudEvents that triggered the `EventTrigger`. | Only if the events were from NATS.io. |
| **Cluster** | The `SveltosCluster` or CAPI Cluster instance where the events occurred. | Always available |

## Example: Enforce a Default NetworkPolicy Across All Namespaces

### Scenario

A platform team wants every namespace in each managed cluster to have a default-deny ingress `NetworkPolicy`. Namespaces are created frequently by different teams. Creating one `ClusterProfile` per namespace (i.e. `oneForEvent: true`) would produce hundreds of `ClusterProfiles`. Instead, `oneForEvent: false` produces **one** `ClusterProfile` per cluster that covers all namespaces together and is automatically reconciled whenever the namespace list changes.

### EventSource

The `EventSource` watches every `Namespace` in the managed cluster. `collectResources: false` is sufficient — the template only needs each namespace's name, not the full `Namespace` object.

!!! example "Example — EventSource"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: namespace-watcher
    spec:
      collectResources: false
      resourceSelectors:
        - group: ""
          version: "v1"
          kind: "Namespace"
    ```

To skip system namespaces, add a `evaluateCEL` rule to the selector:

!!! example "Example — EventSource excluding system namespaces"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: namespace-watcher
    spec:
      collectResources: false
      resourceSelectors:
        - group: ""
          version: "v1"
          kind: "Namespace"
          evaluateCEL:
            - name: skip_system_namespaces
              rule: >
                !resource.metadata.name.startsWith("kube-") &&
                resource.metadata.name != "projectsveltos"
    ```

### EventTrigger

`oneForEvent: false` instructs Sveltos to create a **single** `ClusterProfile` that aggregates all matching namespaces.

!!! example "Example — EventTrigger"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: namespace-networkpolicy-enforcer
    spec:
      sourceClusterSelector:
        matchLabels:
          env: production
      eventSourceName: namespace-watcher
      oneForEvent: false
      policyRefs:
        - name: default-deny-per-namespace
          namespace: default
          kind: ConfigMap
    ```

### ConfigMap — Template Using MatchingResources

Because `oneForEvent: false`, the template receives `.MatchingResources` — a **slice** of `corev1.ObjectReference` values, one per namespace. Each entry exposes `.APIVersion`, `.Kind`, `.Namespace`, and `.Name`. For cluster-scoped resources like `Namespace`, `.Namespace` is empty and `.Name` is the namespace name.

!!! example "Example — ConfigMap with range .MatchingResources"
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: default-deny-per-namespace
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok
    data:
      networkpolicies.yaml: |
        {{- range .MatchingResources }}
        ---
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        metadata:
          name: default-deny-ingress
          namespace: {{ .Name }}
        spec:
          podSelector: {}
          policyTypes:
            - Ingress
        {{- end }}
    ```

`{{- range .MatchingResources }}` iterates every namespace that matched the `EventSource`. For each entry, `{{ .Name }}` resolves to the namespace name. The rendered output is a single multi-document YAML applied by the one generated `ClusterProfile`.

### What Happens at Runtime

1. The Sveltos agent in each matching cluster detects all `Namespace` resources and reports them to the management cluster in a single `EventReport`.
2. The event-manager creates **one** `ClusterProfile` because `oneForEvent: false`.
3. Before deploying, the `ConfigMap` template is instantiated with the current `MatchingResources` slice: one `NetworkPolicy` block is rendered per namespace.
4. When a new namespace is created, the `EventSource` fires again. Sveltos re-instantiates the template with the updated namespace list and reconciles — the new namespace's `NetworkPolicy` is added automatically.
5. When a namespace is deleted, the same reconcile loop runs and the corresponding `NetworkPolicy` entry is removed from the rendered output. Sveltos withdraws it from the cluster.

### oneForEvent: true vs. oneForEvent: false

| | `oneForEvent: true` | `oneForEvent: false` |
|---|---|---|
| ClusterProfiles created | One per matching resource | One for all matching resources |
| Template variable | `.MatchingResource` (single `ObjectReference`) | `.MatchingResources` (slice of `ObjectReference`) |
| Full resource data | `.Resource` (if `collectResources: true`) | `.Resources` (if `collectResources: true`) |
| Scales to 200 namespaces as | 200 ClusterProfiles | 1 ClusterProfile |
| Good when | Each resource needs its own independent config | The same config is applied once, referencing all resources |
