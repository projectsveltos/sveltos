---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease
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

## What is Sveltos?

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a set of Kubernetes controllers that run in the management cluster. From the management cluster, Sveltos can manage add-ons and applications on a fleet of managed Kubernetes clusters.

Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters, but it doesn't stop there. You can easily [register](../register/register-cluster.md) any other cluster (on-prem, Cloud) and manage Kubernetes add-ons seamlessly.

![Sveltos managing clusters](../assets/multi-clusters.png)

## How it works?

[ClusterProfile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1alpha1/clusterprofile_types.go "ClusterProfile to manage Kubernetes add-ons") is the CustomerResourceDefinition used to instruct Sveltos which add-ons to deploy on a set of clusters.

By creating a **ClusterProfile** instance, you can easily deploy:

- Helm charts;
- resources assembled with Kustomize;
- raw Kubernetes YAML/JSON manifests;

across a set of Kubernetes clusters.

Define which Kubernetes add-ons to deploy and where:

1. Select one or more clusters using a Kubernetes [label selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors "Kubernetes label selector");
2. List the Kubernetes add-ons that need to be deployed on selected clusters

It is as simple as that!

## Example - Kyverno ClusterProfile

The below example deploys a Kyverno helm chart in every cluster with the label *env=prod*.

### Step 1: Register Clusters
The first step is to ensure the CAPI clusters are successfully registered with Sevltos. If you have not registered the clusters yet, follow the instructions mentioned [here](../register/register-cluster.md).

If you already register the CAPI clusters, ensure they are listed and ready to receive add-ons.

```bash
kubectl get sveltosclusters -n projectsveltos --show-labels

NAME        READY   VERSION          LABELS
cluster12   true    v1.26.9+rke2r1   sveltos-agent=present
cluster13   true    v1.26.9+rke2r1   sveltos-agent=present
```

**Please note:** The CAPI clusters are registered in the **projectsveltos** namespace. If you register the clusters in a different namespace, update the command mentioned above.

### Step 2: Add Kubernetes Label
The second step is to assign a specific label to the Sveltos Clusters to receive specific add-ons. In this example, we will assign the label *env=prod*.

```bash
kubectl label sveltosclusters cluster12 env=prod -n projectsveltos
kubectl label sveltosclusters cluster13 env=prod -n projectsveltos
kubectl get sveltosclusters -n projectsveltos --show-labels

NAME        READY   VERSION          LABELS
cluster12   true    v1.26.9+rke2r1   env=prod,sveltos-agent=present
cluster13   true    v1.26.9+rke2r1   env=prod,sveltos-agent=present
```

### Step 3: Create the ClusterProfile

The third step is to create a ClusterProfile Kubernetes resource and apply it to the management cluster.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=prod
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.1.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

```bash
kubectl apply -f "kyverno_cluster_profile.yaml"

kubectl exec -it -n projectsveltos sveltosctl-0 -- ./sveltosctl show addons

+--------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
|         CLUSTER          | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILES |
+--------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
| projectsveltos/cluster12 | helm chart    | kyverno   | kyverno-latest | 3.1.1   | 2023-12-16 00:14:17 -0800 PST | kyverno          |
| projectsveltos/cluster13 | helm chart    | kyverno   | kyverno-latest | 3.1.1   | 2023-12-16 00:14:17 -0800 PST | kyverno          |
+--------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
```

![Sveltos in action](../assets/addons.png)

![Sveltos in action](../assets/addons_deployment.gif)

## More Resources

For a quick add-ons example, watch the [Sveltos introduction](https://www.youtube.com/watch?v=Ai5Mr9haWKM "Sveltos introduction: Kubernetes add-ons management") video on YouTube.
