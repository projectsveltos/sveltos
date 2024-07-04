---
title: Post Renderer Patches
description: Post renderer patches can be applied to Helm Chart, Kustomize and YAML/JSON.
tags:
    - Kubernetes
    - add-ons
    - rolling upgrades
authors:
    - Gianluca Mardente
---

Sveltos offers a powerful capability called post-rendering. This allows you to make adjustments to generated manifests before deploying them to your managed clusters.

Imagine you're installing a Helm chart that lacks built-in label configuration. You want to add a `enviroment: production` label to all deployed instances. Here's where post-rendering shines! By using a post-render patch, you can achieve this without modifying the original chart.

The provided YAML snippet demonstrates this concept. It defines a ClusterProfile that targets deployments and injects a `enviroment: production` label using a strategic merge patch. This ensures all deployments receive the label during installation.


```yaml hl_lines="21-30"
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.1.4
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
  policyRefs:
  - name: disallow-latest
    namespace: default
    kind: ConfigMap
  patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: ".*"
    patch: |
      - op: add
        path: /metadata/labels/environment
        value: production
```