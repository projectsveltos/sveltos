---
title: Resource Deployment Order - Manifest Order
description: Describe how Sveltos can be instructed to follow an order when deploying resources
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

## Introduction to Deployment Resource Order

When Kubernetes resources are deployed in a cluster, it is sometimes necessary to deploy them in a specific order. For example, a CustomResourceDefinition (CRD) 
must exist before a custom resources of that type can be created.

Sveltos can assist solving this problem by allowing users to specify the order in which Kubernetes resources are deployed.

## ClusterProfile Order

1. ClusterProfile _helmCharts_ field: The `helmCharts` field allows users to specify a list of Helm charts that need to get deployed. Sveltos will deploy the Helm charts in the order they appear in the list (top-down approach).
2. ClusterProfile _policyRefs_ field: The `policyRefs` field allows you to reference a list of ConfigMap and Secret resources whose contents need to get deployed. Sveltos will deploy the resources in the order they appear (top-down approach).
3. ClusterProfile _kustomizationRefs_ field: The `kustomizationRefs` field allows you to reference a list of sources containing kustomization files. Sveltos will deploy the resources in the order they appear in the list (top-down approach)

### Example: Prometheus and Grafana definition

- The below ClusterProfile definition will first deploy the Prometheus Helm chart and then the Grafana Helm chart.

!!! example "Example - ClusterProfile Monitoring"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: prometheus-grafana
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      helmCharts:
      - repositoryURL:    https://prometheus-community.github.io/helm-charts
        repositoryName:   prometheus-community
        chartName:        prometheus-community/prometheus
        chartVersion:     26.0.0
        releaseName:      prometheus
        releaseNamespace: prometheus
        helmChartAction:  Install
      - repositoryURL:    https://grafana.github.io/helm-charts
        repositoryName:   grafana
        chartName:        grafana/grafana
        chartVersion:     8.6.4
        releaseName:      grafana
        releaseNamespace: grafana
        helmChartAction:  Install
    ```

![Sveltos Helm Chart Order](../assets/helm_chart_order.gif)

### Example: PostgreSQL Resource Deployment

- The below ClusterProfile will first deploy the ConfigMap resource named `postgresql-deployment` and then the ConfigMap resource named `postgresql-service`.

!!! Example "Example - ClusterProfile Database"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: postgresql
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      policyRefs:
      - name: postgresql-deployment
        namespace: default
        kind: ConfigMap
      - name: postgresql-service
        namespace: default
        kind: ConfigMap
    ```
