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

Lets say we have two different environments: `staging`and `production`

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
