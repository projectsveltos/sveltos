---
title: Resource Deployment Order
description: Describe how Sveltos can be instructed to follow an order when deploying resources
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

## Introduction to _dependsOn_

ClusterProfile instances can leverage other ClusterProfiles to establish a deployment order for add-ons and applications. The *dependsOn* fields enables the definition of prerequisite ClusterProfiles. Within any managed cluster that matches the current ClusterProfile, the deployment of different add-ons and applications will start once all add-ons and applications in the specified dependency ClusterProfiles have been successfully deployed.

### Example: Kyverno ClusterProfiles

The below examaple displays a ClusterProfile which encapsulates all Kyverno policies for a cluster and declares a ClusterProfile dependency named `kyverno`, which is responsible for installing the Kyverno Helm chart.

!!! example ""
    ```yaml
    ---
      apiVersion: config.projectsveltos.io/v1beta1
      kind: ClusterProfile
      metadata:
        name: kyverno-policies
      spec:
        clusterSelector:
          matchLabels:
            env: fv
        dependsOn:
        - kyverno
        policyRefs:
        - deploymentType: Remote
          kind: ConfigMap
          name: disallow-latest-tag
          namespace: default
          kind: ConfigMap
          name: restrict-wildcard-verbs
          namespace: default
    ```
[^1]

!!! example ""
    ```yaml
      ---
      apiVersion: config.projectsveltos.io/v1beta1
      kind: ClusterProfile
      metadata:
        name: kyverno
      spec:
        clusterSelector:
          matchLabels:
            env: fv
        helmCharts:
        - chartName: kyverno/kyverno
          chartVersion: v3.0.1
          helmChartAction: Install
          releaseName: kyverno-latest
          releaseNamespace: kyverno
          repositoryName: kyverno
          repositoryURL: https://kyverno.github.io/kyverno/
    ```

### Example: Kyverno and Kubevela ClusterProfile

In the below YAML definitions, the ClusterProfile instance *cp-kubevela* relies on the ClusterProfile instance *cp-kyverno*. That means that the *cp-kyverno* ClusterProfile add-ons will get deployed to clusters matching the label set to `env=prod` and afterwards, the ClusterProfile `cp-kubevela` will take place.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile 
    metadata: 
      name: cp-kubevela
    spec:
      dependsOn:
      - cp-kyverno
      clusterSelector:
        matchLabels:
          env: production
      syncMode: Continuous
      helmCharts:
      - repositoryURL: https://kubevela.github.io/charts
        repositoryName: kubevela
        chartName: kubevela/vela-core
        chartVersion: 1.9.6
        releaseName: kubevela-core-latest
        releaseNamespace: vela-system
        helmChartAction: Install
    ```

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: cp-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.0.1
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
    ```

The above example is equivalent of creating a single ClusterProfile. 

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: cp-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.0.1
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
      - repositoryURL: https://kubevela.github.io/charts
        repositoryName: kubevela
        chartName: kubevela/vela-core
        chartVersion: 1.9.6
        releaseName: kubevela-core-latest
        releaseNamespace: vela-system
        helmChartAction: Install
    ```

!!! note
    Separate ClusterProfiles promote better organization and maintainability, especially when different teams or individuals manage different ClusterProfiles.

```
$ wget https://raw.githubusercontent.com/kyverno/policies/main/best-practices/disallow-latest-tag/disallow-latest-tag.yaml

$ kubectl create configmap disallow-latest-tag --from-file disallow-latest-tag.yaml

$ wget https://raw.githubusercontent.com/kyverno/policies/main/other/res/restrict-wildcard-verbs/restrict-wildcard-verbs.yaml

$ kubectl create configmap restrict-wildcard-verbs --from-file restrict-wildcard-verbs.yaml
```
[^1]: To create the ConfigMaps with Kyverno policies used in this example
