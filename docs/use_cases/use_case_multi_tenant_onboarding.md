---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | Multi-tenancy
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Gianluca Mardente
---

## Advanced Multi-Tenant Onboarding with patchesFrom

When managing a fleet of customer clusters, we typically deploy a standard set of "Day 2" agents (monitoring, logging, security).
While 90% of customers use the base configuration, 10% require specific tweaks due to their unique infrastructure (e.g., Service Meshes, specialized hardware, or strict taints).

Instead of creating a unique `ClusterProfile` for every customer, you can use a single profile that dynamically "plucks" patches from the environment if they exist.

### Use Case: Standard Agent with Customer-Specific Requirements

In this example, we deploy a standard Monitoring Agent. We will handle three types of clusters:

1. **Standard Cluster**: Gets the base configuration.
1. **Istio-enabled Cluster**: Needs a sidecar injection annotation.
1. **Specialized Hardware Cluster**: Needs tolerations and a nodeSelector to run on specific nodes.

#### The Global ClusterProfile

This profile is applied to all customer clusters. It looks for a ConfigMap named `customer-override-{{ .Cluster.metadata.name }}`.

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-monitoring-agents
spec:
  patchesFrom:
  - kind: ConfigMap
    name: "customer-override-{{ .Cluster.metadata.name }}"
    namespace: "default"
    optional: true # Crucial: Standard clusters won't have this CM
  clusterSelector:
    matchLabels:
      onboarding: completed
  policyRefs:
  - name: monitoring-agent-base
    namespace: default
    kind: ConfigMap
```

#### Scenario A: The Istio Customer (Annotation Patch)

For a cluster named `customer-blue-istio`, we create a patch to enable sidecar injection. Strategic merge allows us to simply add to the `annotations` map without touching the rest of the spec.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: customer-override-customer-blue-istio
  namespace: default
data:
  istio-patch: |-
    patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: monitoring-agent
      spec:
        template:
          metadata:
            annotations:
              sidecar.istio.io/inject: "true"
    target:
      kind: Deployment
      name: monitoring-agent
```

#### Scenario B: The Bare-Metal Customer (Tolerations & NodeSelector)

For a cluster named `customer-red-highperf`, the agent must run on high-performance nodes that are tainted to prevent other workloads from running there.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: customer-override-customer-red-highperf
  namespace: default
data:
  placement-patch: |-
    patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: monitoring-agent
      spec:
        template:
          spec:
            nodeSelector:
              hardware: high-perf-ssd
            tolerations:
            - key: "hardware-dedicated"
              operator: "Exists"
              effect: "NoSchedule"
    target:
      kind: Deployment
      name: monitoring-agent
```

### Why this is superior for Onboarding

**Decoupled Lifecycle**: The Platform Team manages the ClusterProfile and the base monitoring-agent-base ConfigMap.
The Customer Support or Onboarding Team only needs to create a small "Override ConfigMap" during the cluster setup phase.
They don't need permission to edit the Global ClusterProfile.

**Conflict-Free Customization**: Because Sveltos uses `Strategic Merge Patches/JSON Patches`, if a customer needs both Istio and Tolerations, you can simply put both patches in the same ConfigMap.
Sveltos will merge them intelligently into the base manifest.

For more information on `patchesFrom`, have a look [here](../features/post-renderer-patches.md).
