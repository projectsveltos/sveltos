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

ClusterProfile *Spec.HelmCharts* can list all the Helm charts you want to deploy. Sveltos will deploy the Helm charts in the exact order you define them.

## Single Helm chart

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=prod
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.0.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

## Multiple Helm charts

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: prometheus-grafana
spec:
  clusterSelector: env=fv
  helmCharts:
  - repositoryURL:    https://prometheus-community.github.io/helm-charts
    repositoryName:   prometheus-community
    chartName:        prometheus-community/prometheus
    chartVersion:     23.4.0
    releaseName:      prometheus
    releaseNamespace: prometheus
    helmChartAction:  Install
  - repositoryURL:    https://grafana.github.io/helm-charts
    repositoryName:   grafana
    chartName:        grafana/grafana
    chartVersion:     6.58.9
    releaseName:      grafana
    releaseNamespace: grafana
```

## Passing values to Helm chart

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.0.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
    values: |
      admissionController:
        replicas: 1
```

## Expressing Helm values as templates

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-calico
spec:
  clusterSelector: env=prod
  helmCharts:
  - repositoryURL:    https://projectcalico.docs.tigera.io/charts
    repositoryName:   projectcalico
    chartName:        projectcalico/tigera-operator
    chartVersion:     v3.24.5
    releaseName:      calico
    releaseNamespace: tigera-operator
    helmChartAction:  Install
    values: |
      installation:
        calicoNetwork:
          ipPools:
          {{ range $cidr := .Cluster.spec.clusterNetwork.pods.cidrBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-cilium-v1-26
spec:
  clusterSelector: env=fv
  helmCharts:
  - chartName: cilium/cilium
    chartVersion: 1.12.12
    helmChartAction: Install
    releaseName: cilium
    releaseNamespace: kube-system
    repositoryName: cilium
    repositoryURL: https://helm.cilium.io/
    values: |
      k8sServiceHost: "{{ .Cluster.spec.controlPlaneEndpoint.host }}"
      k8sServicePort: "{{ .Cluster.spec.controlPlaneEndpoint.port }}"
      hubble:
        enabled: false
      nodePort:
        enabled: true
      kubeProxyReplacement: strict
      operator:
        replicas: 1
        updateStrategy:
          rollingUpdate:
            maxSurge: 0
            maxUnavailable: 1
```