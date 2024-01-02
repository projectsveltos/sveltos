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

When deploying Kubernetes resources in a cluster, it is sometimes necessary to deploy them in a specific order. For example, a CustomResourceDefinition (CRD) 
must exist before any custom resources of that type can be created.

Sveltos can help you solve this problem by allowing you to specify the order in which Kubernetes resources are deployed.

## ClusterProfile order

1. Using the _helmCharts_ field in a ClusterProfile: The helmCharts field allows you to specify a list of Helm charts that need to be deployed. Sveltos will deploy the Helm charts in the order that they are listed in this field.
2. Using the _policyRefs_ field in a ClusterProfile: The policyRefs field allows you to reference a list of ConfigMap and Secret resources whose contents need to be deployed. Sveltos will deploy the resources in the order that they are listed in this field.
3. Using the _kustomizationRefs_ field in a ClusterProfile: The kustomizationRefs field allows you to reference a list of sources containing kustomization files. Sveltos will deploy the resources in the order that they are listed in this field.

Here are some examples:

- The following ClusterProfile will first deploy the Prometheus Helm chart and then the Grafana Helm chart:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: prometheus-grafana
spec:
  clusterSelector: env=fv
  syncMode: Continuous
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
    helmChartAction:  Install
```

![Sveltos Helm Chart Order](../assets/helm_chart_order.gif)

- The following ClusterProfile will first deploy the ConfigMap resource named postgresql-deployment and then the ConfigMap resource named postgresql-service:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: postgresql
spec:
  clusterSelector: env=fv
  policyRefs:
  - name: postgresql-deployment
    namespace: default
    kind: ConfigMap
  - name: postgresql-service
    namespace: default
    kind: ConfigMap
```
