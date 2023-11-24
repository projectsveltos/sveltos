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

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a set of Kubernetes controllers that run in the management cluster. From the management cluster, Sveltos can manage add-ons and applications on a fleet of managed Kubernetes clusters.

Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters, but it doesn't stop there. You can easily [register](../register/register-cluster.md) any other cluster (like GKE, for instance) with Sveltos and manage Kubernetes add-ons on all clusters seamlessly.

![Sveltos managing clusters](../assets/multi-clusters.png)

## How does Sveltos work?

[ClusterProfile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1alpha1/clusterprofile_types.go "ClusterProfile to manage Kubernetes add-ons") is the CustomerResourceDefinition used to instruct Sveltos on which add-ons to deploy on a set of clusters. 
By creating a ClusterProfile instance, you can easily deploy:

- Helm charts;
- resources assembled with Kustomize;
- raw Kubernetes YAML/JSON manifests;

across a set of Kubernetes clusters. 

All you need to do is define which Kubernetes add-ons to deploy and where to deploy them:

1. Select one or more clusters using a Kubernetes [label selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors "Kubernetes label selector");
2. List the Kubernetes add-ons that need to be deployed on the selected clusters.

It's as simple as that!

Here is an example that deploys Kyverno helm chart in all clusters with label *env:prod*:

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
    chartVersion:     v3.0.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

![Sveltos in action](../assets/addons.png)

![Sveltos in action](../assets/addons_deployment.gif)

For a quick video of Sveltos, watch the video [Sveltos introduction](https://www.youtube.com/watch?v=Ai5Mr9haWKM "Sveltos introduction: Kubernetes add-ons management") on YouTube.
