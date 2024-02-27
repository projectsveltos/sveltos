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
    - Eleni Grosdouli
---

## What is Sveltos?

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a set of Kubernetes controllers that run in the management cluster. From the management cluster, Sveltos can manage add-ons and applications on a fleet of managed Kubernetes clusters.

Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters, but it doesn't stop there. You can easily [register](../register/register-cluster.md) any other cluster (on-prem, Cloud) and manage Kubernetes add-ons seamlessly.

![Sveltos managing clusters](../assets/multi-clusters.png)

## Platform Administrators and Multicloud Environment

In today's fast-paced and ever-evolving IT landscape, where the [multicloud](https://www.google.com/search?q=what+is+a+multicloud&oq=what+is+a+multicloud&gs_lcrp=EgZjaHJvbWUyBggAEEUYOdIBCDQyNzBqMGoxqAIAsAIA&sourceid=chrome&ie=UTF-8) concept is becoming increasingly popular, automating the creation of Kubernetes clusters and managing their lifecycle programmatically is a crucial task for Kubernetes platform administrators.

The cluster creation is one aspect that various open-source solutions exist to assist, but managing Kubernetes add-ons and deployments across numerous clusters presents its own challenges. In such scenarios, a central management cluster for observability and control is incredibly useful. Sveltos is an open-source project to programmatically deploy Kubernetes add-ons in a great number of Kubernetes clusters (on-prem, Cloud).

### Central Kubernetes Management Cluster

What are the benefits of a central Kubernetes management cluster to manage other clusters?

- **Centralised Management:** A cluster management cluster allows administrators to manage multiple clusters from a single place, making it easier to maintain consistency and reduce the risk of configuration issues.

- **Consistency:** It allows administrators to automate processes to ensure consistent configurations and deployments across clusters, reducing the risk of errors and enhancing reliability.

- **Scalability:** It can assist organisations to scale their infrastructure by easing the creation, deployment, and management of multiple clusters.

- **Cost Optimisation:** Centralising control enables efficient resource usage and reduces operational costs associated with managing Kubernetes clusters.

- **Better Security:** A cluster management cluster can be configured with security-related add-ons, such as network policies and secrets management, to ensure all managed clusters are securely deployed.

- **Increased Automation:** It can be integrated with a continuous integration/continuous deployment (CI/CD) pipeline, making it easier to automate the deployment of new clusters and add-ons, and reducing the time and effort involved in managing the infrastructure.

### Sveltos add-on Managament Solution

Sveltos allows platform administrators to utilise the CRD with the name `ClusterProfile` to perform Kubernetes [add-on](../addons/addons.md) deployment. Within a Sveltos ClusterProfile, we define the below points.

1. What Kubernetes add-ons to get deployed (Helm charts, Kustomize, YAML/JSON manifests)?
2. Where should they get deployed?
3. List the add-ons deployed

### Example YAML Definition

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
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
  policyRefs:
  - name: disallow-latest-tag # Reference a ConfigMap that contains a Kyverno ClusterPolicy
    namespace: default
    kind: ConfigMap
```

The above YAML definition will install Kyverno and once the deployment is Ready, a Kyverno policy will get deployed to the cluster matching the Sveltos label selector `env=prod`.

Additionally, Sveltos offers the ability of the [configuration drift detection](../features/configuration_drift.md). Platform administrators do not have to worry about the managed clusters' state. Sveltos monitors the state and when it detects a configuration drift, it will re-sync the cluster state back to the original state described in the management cluster.

## More Resources

For more information about the Sveltos add-on deployment capabilities, have a look [here](../addons/addons.md).