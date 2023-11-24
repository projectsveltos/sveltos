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

There are two ways to do this:

1. Using the _helmCharts_ field in a ClusterProfile: The helmCharts field allows you to specify a list of Helm charts that need to be deployed. Sveltos will deploy the Helm charts in the order that they are listed in this field.
2. Using the _policyRefs_ field in a ClusterProfile: The policyRefs field allows you to reference a list of ConfigMap and Secret resources whose contents need to be deployed. Sveltos will deploy the resources in the order that they are listed in this field.

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

## ClusterProfile dependsOn field

A ClusterProfile instance can rely on other ClusterProfiles to specify a deployment order for add-ons and applications. The *dependsOn* property defines a list of prerequisite ClusterProfiles. In any managed cluster that matches this ClusterProfile, the add-ons and applications defined in this instance will only be deployed after all add-ons and applications in the specified dependency ClusterProfiles have been successfully deployed.

 For example, if the ClusterProfile instance *cp-kubevela* relies on the ClusterProfile instance *cp-kyverno*, this can be configured by simply setting the dependsOn field in the *cp-kubevela* ClusterProfile.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile 
metadata: 
  name: cp-kubevela
spec:
  dependsOn:
  - cp-kyverno
  clusterSelector: env=production
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

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: cp-kyverno
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

This is equivalent of creating a single ClusterProfile. 

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: cp-kyverno
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
  - repositoryURL: https://kubevela.github.io/charts
    repositoryName: kubevela
    chartName: kubevela/vela-core
    chartVersion: 1.9.6
    releaseName: kubevela-core-latest
    releaseNamespace: vela-system
    helmChartAction: Install
```

Separate ClusterProfiles promote better organization and maintainability, especially when different teams or individuals manage different ClusterProfiles.
