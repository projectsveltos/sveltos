---
title: Sveltos Configuration Drift
description: Discover how Sveltos tackles Configuration Drift - the common challenge of maintaining consistency in an evolving environment. Learn how Sveltos monitors and rectifies configuration drift in managed clusters, ensuring your systems remain consistent and predictable. Explore the proactive approach to prevent unexpected issues caused by configuration drift with Sveltos. Configuration drift recovery made simple.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - helm
    - clusterapi
    - configuration drift detection
authors:
    - Gianluca Mardente
---

## Configuration Drift

_Configuration drift_ is a commonly used term to describe a change that takes place in an environment. Drift is an issue as it causes systems and parts of a system which supposed to be consistent, to become inconsistent and unpredictable. In our case, _configuration drift_ is a change of a resource deployed by Sveltos down the managed clusters.

Sveltos allows users to set the `sync` mode within a ClusterProfile to *ContinuousWithDriftDetection*. It enables Sveltos to monitor the state of managed clusters and detect configuration drift for any of the resources deployed by a ClusterProfile.

```yaml hl_lines="7"
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  syncMode: ContinuousWithDriftDetection
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.3.3
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

When Sveltos detects a configuration drift, it will automatically re-sync the cluster state back to its original state which is described in the management cluster. Sveltos deploys a service in each managed cluster and configures it with a list of Kubernetes resources deployed for each ClusterProfile in SyncModeContinuousWithDriftDetection mode.

The service starts a watcher for each GroupVersionKind with at least one resource to watch. When any watched resources are modified (labels, annotations, spec or rules sections), the service notifies the management cluster about potential configuration drifts. The management cluster then reacts by redeploying affected ClusterProfiles.

This way, Sveltos ensures that the systems are always consistent and predictable, preventing unexpected issues caused by the configuration drifts.

![Configuration drift recovery](../assets/reconcile_configuration_drift.gif)

## Ignore Annotation

You can stop certain resources from being tracked for configuration drift. This is done by adding a special annotation `projectsveltos.io/driftDetectionIgnore` to those resources.

For instance, following ClusterProfile will deploy Kyverno helm chart. Patches are used to apply annotation to the Kyverno `kyverno-admission-controller` deployment. 
This means any changes made to resources deployed by the Helm chart itself will be flagged as a configuration drift. However, any modifications directly to the kyverno-admission-controller deployment won't be detected as drift.

```yaml hl_lines="18-27"
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: ContinuousWithDriftDetection
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.3.3
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
      patches:
      - target:
          group: apps
          version: v1
          kind: Deployment
          name: "kyverno-admission-controller"
        patch: |
          - op: add
            path: /metadata/annotations/projectsveltos.io~1driftDetectionIgnore
            value: "ok"
```

## Ignore Fields

You can optionally specify fields to be excluded from drift detection using JSON Pointers.

Here's an example configuration in YAML format:

```yaml hl_lines="18-22"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: nginx
spec:
  clusterSelector:
    matchLabels:
      env: prod
  syncMode: ContinuousWithDriftDetection
  helmCharts:
  - repositoryURL:    https://helm.nginx.com/stable/
    repositoryName:   nginx-stable
    chartName:        nginx-stable/nginx-ingress
    chartVersion:     1.3.1
    releaseName:      nginx-latest
    releaseNamespace: nginx
    helmChartAction:  Install
  driftExclusions:
  - paths:
    - "/spec/replicas"
    target:
      kind: Deployment
```

## Customize drift-detection-manager configuration

In some cases, you might want to tailor the deployment of the drift-detection-manager[^1]. To achieve this, the `addon-controller` pod now accepts a new argument named `drift-detection-config`.

This argument points to a ConfigMap within the projectsveltos namespace. The ConfigMap holds patches that will be applied to the drift-detection-manager before its deployment in the managed cluster.

Here's an example:

```yaml
apiVersion: v1
data:
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: drift-detection-manager
    spec:
      template:
        spec:
          containers:
          - name: manager
            image: docker.io/projectsveltos/drift-detection-manager:dev
            resources:
              requests:
                memory: 256Mi
            securityContext:
              readOnlyRootFilesystem: true
kind: ConfigMap
metadata:
  name: drift-detection
  namespace: projectsveltos
```

Along with creating the ConfigMap, you'll also need to configure the addon-controller deployment to use it. To do this, add the following argument to the deployment:

```yaml
- args:
  ...
  - --drift-detection-config=drift-detection
```

With this configuration, the drift-detection-manager will be deployed in each managed cluster with the following settings:

- Request memory: 256Mi
- Image: projectsveltos/drift-detection-manager:dev

[^1]: Same is valid for `sveltos-agent`. classifier pod now accepts a new argument named `sveltos-agent-config`. It points to a ConfigMap in the projectsveltos namespace. The ConfigMap holds patches that will be applied to the sveltos-agent before its deployment in the managed cluster.