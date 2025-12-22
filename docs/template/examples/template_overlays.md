---
title: Templates Generic Examples
description: Overlay pattern for deploying add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - template
authors:
    - Gianluca Mardente
---

This Sveltos configuration utilizes a powerful overlay pattern to dynamically deploy the Kyverno Helm chart.
It targets all clusters with the label `zone: us-east-2` while customizing the deployment for each one. The core of this pattern is the runtime matching of cluster metadata.

By using Go templates within the **templateResourceRefs** section, the ClusterProfile dynamically constructs the names of ConfigMaps:

- kyverno-{{.Cluster.metadata.labels.environment}}-version
- kyverno-{{.Cluster.metadata.labels.environment}}-values.

At deployment time, Sveltos fetches the specific ConfigMap that matches the environment label of each target cluster.
This allows you to maintain a single, reusable ClusterProfile that acts as a blueprint, while the individual ConfigMaps serve as overlays that provide the unique version and values
for each specific environment (e.g., staging, production).

This method effectively decouples the deployment logic from the configuration data, enabling a scalable and maintainable GitOps workflow for managing add-ons across diverse Kubernetes clusters.

```yaml hl_lines="19 26 32"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector:
    matchLabels:
      zone: us-east-2
  syncMode: Continuous
  templateResourceRefs:
  - resource:
      apiVersion: cluster.x-k8s.io/v1beta2
      kind: Cluster
      name: "{{ .Cluster.metadata.name }}"
    identifier: Cluster
  - resource:
      apiVersion: v1
      kind: ConfigMap
      name: "kyverno-{{- if index .Cluster.metadata.labels `environment` -}}{{- index .Cluster.metadata.labels `environment` -}}{{- end -}}-version"
      namespace: default
    identifier: Version
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     "{{- index (getResource `Version`).data `chartVersion` -}}"
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
    valuesFrom:
    - kind: ConfigMap
      name: kyverno-{{- if index .Cluster.metadata.labels `environment` -}}{{- index .Cluster.metadata.labels `environment` -}}{{- end -}}-values
      namespace: default
      optional: true
```

With this Sveltos configuration, the specific ConfigMaps used for the Kyverno deployment depend entirely on the environment label of the target cluster.

When a cluster has the label `environment: production`, the ClusterProfile's Go templates resolve to the following:

- Version ConfigMap: _kyverno-production-version_
- Values ConfigMap: _kyverno-production-values_

Sveltos will use these ConfigMaps to install the Kyverno Helm chart with 3 replicas for both the admissionController and backgroundController, as specified in the production ConfigMap. This is a classic example of a production-level, high-availability configuration.

When a cluster has the label `environment: staging`, the ClusterProfile's Go templates resolve to the following:

- Version ConfigMap: _kyverno-staging-version_
- Values ConfigMap: _kyverno-staging-values_

In this case, Sveltos will install Kyverno with all controllers set to 1 replica, which is typical for a staging or testing environment to conserve resources.

This demonstrates how a single ClusterProfile can manage multiple environments by dynamically selecting the correct configuration "overlay" at runtime based on the cluster's labels.

```yaml
apiVersion: v1
data:
  chartVersion:     3.5.1
kind: ConfigMap
metadata:
  name: kyverno-production-version
  namespace: default
---
apiVersion: v1
data:
  values: |2
          admissionController:
            replicas: 3
          backgroundController:
            replicas: 3
          cleanupController:
            replicas: 1
          reportsController:
            replicas: 1
kind: ConfigMap
metadata:
  name: kyverno-production-values
  namespace: default
```

```yaml
apiVersion: v1
data:
  chartVersion:     3.5.1
kind: ConfigMap
metadata:
  name: kyverno-staging-version
  namespace: default
---
apiVersion: v1
data:
  values: |2
          admissionController:
            replicas: 1
          backgroundController:
            replicas: 1
          cleanupController:
            replicas: 1
          reportsController:
            replicas: 1
kind: ConfigMap
metadata:
  name: kyverno-staging-values
  namespace: default
```