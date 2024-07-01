---
title: Sveltos ClusterSet/Set
description: Sveltos' ClusterSet lets you manage groups of clusters and automatically deploy your applications to healthy ones. If a cluster fails, Sveltos automatically picks another to keep things running smoothly.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - dynamic deployment
    - failover
    - high availability
authors:
    - Gianluca Mardente
---

## ClusterSet and Set

Sveltos offers two resources, `ClusterSet` and `Set`, to manage groups of clusters and dynamically select a subset of those clusters for deployments based on specific criteria. 
This enables automated deployments and failover across healthy clusters in your environment.

### Key Capabilities

1. Selection: Choose clusters using a defined clusterSelector (e.g., label matching).
2. Capping: Limit the number of selected clusters with maxReplicas.
3. Failover: If a selected cluster becomes unavailable, Sveltos automatically picks another healthy one from the matching pool to maintain the desired number of active clusters (up to the maxReplicas limit).

### Referencing ClusterSet/Set in a ClusterProfile/Profile
A ClusterProfile or Profile can reference a ClusterSet or Set by specifying its name. The add-ons defined in the profile will only be deployed to the currently selected clusters within the referenced set.

The add-ons defined in the ClusterProfile/Profile will be deployed only to the currently selected clusters within the referenced ClusterSet/Set. 
This enables dynamic deployment management based on the available and healthy clusters in the set.

This feature is particularly useful for scenarios where you want to implement active/passive failover: create a ClusterSet/Set with maxReplicas: 1 and have it match two clusters in the clusterSelector. 
This ensures only one cluster is active at a time. If the active cluster goes down, the backup cluster will be automatically selected for deployments.

### Active/Passive Failover Example

This scenario demonstrates active/passive failover with a ClusterSet.

![Cluster Failover](../assets/clusterset.gif)

#### Register Clusters: 

We have two Civo clusters registered with Sveltos, all labeled `env:prod`.

```
$ kubectl get sveltoscluster -A --show-labels
NAMESPACE  NAME    READY  VERSION    LABELS
civo    cluster1  true  v1.29.2+k3s1  env=prod
civo    cluster2  true  v1.28.7+k3s1  env=prod
```

#### Create a ClusterSet

A ClusterSet named __prod__ is created with `clusterSelector` to match all prod clusters and `maxReplicas: 1` to ensure only one cluster is active at a time.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterSet
    metadata:
      name: prod
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      maxReplicas: 1
    ```

#### Sveltos Detects Matching Clusters
Sveltos identifies both clusters as matches (`status.matchingClusterRefs`) and selects one (e.g., cluster2) as the active cluster (`status.selectedClusterRefs`).

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterSet
    metadata:
      name: prod
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      maxReplicas: 1
    status:
      matchingClusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster1
        namespace: civo
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster2
        namespace: civo
      namespace: civo
      selectedClusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster2
        namespace: civo
    ```

#### Deploy a ClusterProfile
A ClusterProfile named kyverno is deployed referencing the prod ClusterSet.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: kyverno
    spec:
      helmCharts:
      - chartName: kyverno/kyverno
        chartVersion: v3.0.1
        helmChartAction: Install
        releaseName: kyverno-latest
        releaseNamespace: kyverno
        repositoryName: kyverno
        repositoryURL: https://kyverno.github.io/kyverno/
      setRefs:
      - prod # name of the ClusterSet
    ```

#### Sveltos Deploys Kyverno
Sveltos deploys the Kyverno charts specified in the ClusterProfile onto the cluster selected by the ClusterSet (e.g., civo/cluster3).

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: kyverno
    spec:
      helmCharts:
      - chartName: kyverno/kyverno
        chartVersion: v3.0.1
        helmChartAction: Install
        releaseName: kyverno-latest
        releaseNamespace: kyverno
        repositoryName: kyverno
        repositoryURL: https://kyverno.github.io/kyverno/
      setRefs:
      - prod
    status:
      matchingClusters:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster2
        namespace: civo
    ```

```
$ sveltosctl show addons  
+---------------+---------------+-----------+----------------+---------+-------------------------------+------------------------+
|    CLUSTER    | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              |        PROFILES        |
+---------------+---------------+-----------+----------------+---------+-------------------------------+------------------------+
| civo/cluster2 | helm chart    | kyverno   | kyverno-latest | 3.0.1   | 2024-03-13 10:19:06 +0100 CET | ClusterProfile/kyverno |
+---------------+---------------+-----------+----------------+---------+-------------------------------+------------------------+
```

#### Selected Cluster Becomes Unhealthy

If the cluster selected by `ClusterSet` instance becomes unhealthy, Sveltos detects that and ClusterSet selects another healthy cluster out of the matching ones.

In this example, __cluster2__ was deleted.

Sveltos detected that and marked the cluster as not ready

```
$ kubectl get sveltoscluster -A
NAMESPACE NAME   READY VERSION
civo    cluster1 true  v1.29.2+k3s1
civo    cluster2       v1.28.7+k3s1
```

#### ClusterSet Selects New Cluster

The ClusterSet automatically picks another healthy cluster from the matching ones (e.g., __cluster1__) as the new active cluster.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterSet
    metadata:
      name: prod
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      maxReplicas: 1
    status:
      matchingClusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster1
        namespace: civo
      selectedClusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster1
        namespace: civo
    ```

#### ClusterProfile Re-deploys Add-ons

The ClusterProfile reacts to the change and re-deploys its add-ons (Kyverno in this case) to the newly selected cluster (civo/cluster1).

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: kyverno
    spec:
      helmCharts:
      - chartName: kyverno/kyverno
        chartVersion: v3.0.1
        helmChartAction: Install
        releaseName: kyverno-latest
        releaseNamespace: kyverno
        repositoryName: kyverno
        repositoryURL: https://kyverno.github.io/kyverno/
      setRefs:
      - prod
    status:
      matchingClusters:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: cluster1
        namespace: civo
    ```

```
$ sveltosctl show addons  
+---------------+---------------+-----------+----------------+---------+-------------------------------+------------------------+
|    CLUSTER    | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              |        PROFILES        |
+---------------+---------------+-----------+----------------+---------+-------------------------------+------------------------+
| civo/cluster1 | helm chart    | kyverno   | kyverno-latest | 3.0.1   | 2024-03-13 10:27:46 +0100 CET | ClusterProfile/kyverno |
+---------------+---------------+-----------+----------------+---------+-------------------------------+------------------------+
```

## Summary

ClusterSet and Set in Sveltos provide a powerful mechanism for managing cluster deployments and enabling automated failover for high availability in your applications.
