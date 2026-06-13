---
title: Resource Deployment Order - depends-on
description: Describe how Sveltos can be instructed to follow an order when deploying resources
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

Managing multiple applications across different teams, each of them requiring the presence of the __cert-manager__, consider utilizing a ClusterProfile to deploy cert-manager **centrally**.

This approach enables other ClusterProfiles, responsible for deploying applications that depend on cert-manager, to leverage the `dependsOn` field to ensure the cert-manager is present prior to application deployment.

To guarantee that cert-manager is not only deployed but also functional, employ the __validateHealths__ flag. The below ClusterProfile will deploy cert-manager in any cluster matching the label selector `env=fv` and subsequently wait for all deployments in the cert-manager namespace to reach a healthy state (active replicas matching requested replicas) before setting the ClusterProfile as `provisioned`.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: cert-manager
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      helmCharts:
      - repositoryURL:    https://charts.jetstack.io
        repositoryName:   jetstack
        chartName:        jetstack/cert-manager
        chartVersion:     v1.13.2
        releaseName:      cert-manager
        releaseNamespace: cert-manager
        helmChartAction:  Install
        values: |
          installCRDs: true
      validateHealths:
      - name: deployment-health
        featureID: Helm
        group: "apps"
        version: "v1"
        kind: "Deployment"
        namespace: cert-manager
        script: |
          function evaluate()
            local hs = {healthy = false, message = "available replicas not matching requested replicas"}
            if obj.status and obj.status.availableReplicas ~= nil and obj.status.availableReplicas == obj.spec.replicas then
              hs.healthy = true
            end
            return hs
          end
    ```

#### Common Expression Language (CEL) for Health Validation

Alternatively, you can use Common Expression Language ([CEL](https://cel.dev)), which offers a more concise way to define the same health rule. The example below uses a CEL expression to check if the _availableReplicas_ are equal to the _requested replicas_. The result is the same as the Lua script, providing a healthy and succinct way to validate the state of your deployments.


!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: cert-manager
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      helmCharts:
      - repositoryURL:    https://charts.jetstack.io
        repositoryName:   jetstack
        chartName:        jetstack/cert-manager
        chartVersion:     v1.13.2
        releaseName:      cert-manager
        releaseNamespace: cert-manager
        helmChartAction:  Install
        values: |
          installCRDs: true
      validateHealths:
      - name: deployment-health
        featureID: Helm
        group: "apps"
        version: "v1"
        kind: "Deployment"
        namespace: cert-manager
        evaluateCEL:
        - name: deployment_replicas
          rule: resource.status.availableReplicas == resource.spec.replicas
    ```


## Metric-Based Health Validation

In addition to checking Kubernetes resource state, `validateHealths` entries can query a **Prometheus-compatible metrics endpoint** to gate deployment on live application signals. For example, Sveltos can confirm an error rate is below a threshold before considering a release healthy.

### How it works

Add a `metricSource` field with the URL of the Prometheus endpoint, and one or more `metricQueries`. Each query is a named PromQL expression that must return a **scalar** value. Sveltos evaluates each query and exposes the results as a global `metrics` table inside the Lua `evaluate()` function. The key of each entry is the `name` given to the query.

```yaml
validateHealths:
- name: error-rate-low
  featureID: Helm
  metricSource:
    url: http://prometheus-server.monitoring.svc:9090
  metricQueries:
  - name: errorRate
    query: >-
      sum(rate(http_requests_errors_total{namespace="my-app"}[5m]))
      /
      sum(rate(http_requests_total{namespace="my-app"}[5m]))
  script: |
    function evaluate()
      if metrics["errorRate"] > 0.05 then
        return {healthy = false, message = "error rate above 5%: " .. metrics["errorRate"]}
      end
      return {healthy = true, message = ""}
    end
```

The check above prevents Sveltos from marking the Helm feature as healthy until the error rate falls at or below 5 %. If the check fails, Sveltos retries according to the normal requeue interval. No deployment progress is marked until `healthy = true` is returned.

### Push mode vs. pull mode

| Mode | Who queries the endpoint |
|------|--------------------------|
| **Push** | The `addon-controller` running in the **management** cluster. The `metricSource.url` must be reachable from the management cluster. |
| **Pull** | The `sveltos-applier` agent running **inside the managed cluster**. The URL is resolved via in-cluster DNS, so a cluster-local Prometheus service name (e.g. `http://prometheus-server.monitoring.svc:9090`) works without any external exposure. |

### Combining metrics with resource checks

A single `validateHealths` entry supports only one evaluation path. To combine Kubernetes resource state with a metric check, add two entries under `validateHealths`: one using `script` or `evaluateCEL` against resource state, and one using `metricSource` + `metricQueries`. Both must pass before the feature is considered healthy.

### Example: Nginx and Cert Manager

In the below example, the ClusterPofile to deploy the __nginx ingress__ depends on the __cert-manager__ ClusterProfile defined above.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: ingress-nginx
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      helmCharts:
      - repositoryURL:    https://kubernetes.github.io/ingress-nginx
        repositoryName:   ingress-nginx
        chartName:        ingress-nginx/ingress-nginx
        chartVersion:     "4.8.4"
        releaseName:      ingress-nginx
        releaseNamespace: ingress-nginx
        helmChartAction:  Install
      dependsOn:
      - cert-manager
    ```

