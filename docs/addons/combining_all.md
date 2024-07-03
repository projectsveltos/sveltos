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

## Scenario

A ClusterProfile can have a combination of Helm charts, raw YAML/JSON, and Kustomize configurations.

Consider a scenario where you want to utilize Kyverno to prevent the deployment of images with the 'latest' tag[^1]. To achieve this, you can create a ClusterProfile that:

- Deploys the Kyverno Helm chart
- Deploys a Kyverno policy that enforces image validation, ensuring the image specifies a tag other than 'latest'

Download the Kyverno policy and create a ConfigMap containing the policy within the management cluster.

```
$ wget https://raw.githubusercontent.com/kyverno/policies/main/best-practices/disallow-latest-tag/disallow-latest-tag.yaml

$ kubectl create configmap disallow-latest-tag --from-file disallow-latest-tag.yaml
```

To deploy Kyverno and a ClusterPolicy across all managed clusters matching the Sveltos label selector *env=fv*, utilize the below ClusterProfile."

!!! example "Example - ClusterProfile Kyverno Deployment"
    ```yaml
      ---
      apiVersion: config.projectsveltos.io/v1alpha1
      kind: ClusterProfile
      metadata:
        name: kyverno
      spec:
        clusterSelector: env=fv
        helmCharts:
        - chartName: kyverno/kyverno
          chartVersion: v3.0.1
          helmChartAction: Install
          releaseName: kyverno-latest
          releaseNamespace: kyverno
          repositoryName: kyverno
          repositoryURL: https://kyverno.github.io/kyverno/
        policyRefs:
        - kind: ConfigMap
          name: disallow-latest-tag
          namespace: default
    ```

[^1]: The **':latest'** tag is mutable and can lead to unexpected errors if the image changes. A best practice is to use an immutable tag that maps to a specific version of an application Pod. 
