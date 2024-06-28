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

## Helm Chart Deployment

The ClusterProfile *spec.helmCharts* can list a number of Helm charts to get deployed to the managed clusters with a specific label selector.

!!! note 
    Sveltos will deploy the Helm charts in the exact order they are defined (top-down approach).

### Example: Single Helm chart

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
    chartVersion:     v3.1.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

In the above YAML definition, we install Kyverno on a managed cluster with the label selector set to *env=prod*.

### Example: Multiple Helm charts

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
    helmChartAction:  Install
```

In the above YAML definition, we first install the Prometheus community Helm chart and afterwards the Grafana Helm chart. The two defined Helm charts will get deployed on a managed cluster with the label selector set to *env=fv*.

### Example: Update Helm Chart Values

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
    chartVersion:     v3.1.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
    values: |
      admissionController:
        replicas: 1
```

### Example: Update Helm Chart Values From Referenced ConfigMap/Secret

Sveltos allows you to manage Helm chart values using ConfigMaps/Secrets. 

For instance, we can create a file __cleanup-controller.yaml__ with following content

```yaml
cleanupController:
  livenessProbe:
    httpGet:
      path: /health/liveness
      port: 9443
      scheme: HTTPS
    initialDelaySeconds: 16
    periodSeconds: 31
    timeoutSeconds: 5
    failureThreshold: 2
    successThreshold: 1
```

then create a ConfigMap with it:

```
kubectl create configmap cleanup-controller --from-file=cleanup-controller.yaml
```

We can then create another file __admission_controller.yaml__ with following content:

```yaml
admissionController:
  readinessProbe:
    httpGet:
      path: /health/readiness
      port: 9443
      scheme: HTTPS
    initialDelaySeconds: 6
    periodSeconds: 11
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
```

then create a ConfigMap with it:

```
kubectl create configmap admission-controller --from-file=admission-controller.yaml
```

Within your Sveltos ClusterProfile YAML, define the helmCharts section. Here, you specify the Helm chart details and leverage valuesFrom to reference the ConfigMaps. 
This injects the probe configurations from the ConfigMaps into the Helm chart values during deployment.

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
    chartVersion:     v3.1.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
    values: |
      admissionController:
        replicas: 1
    valuesFrom:
    - kind: ConfigMap
      name: cleanup-controller
      namespace: default
    - kind: ConfigMap
      name: admission-controller
      namespace: default        
```

### Example: Express Helm Values as Templates

Both the __values__ section and the content stored in referenced ConfigMaps and Secrets can be written using templates. 
Sveltos will instantiate these templates using resources in the management cluster. Finally Sveltos deploy the Helm chart with the final, resolved values.

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

### Example: OCI Registry

!!! tip
    For OCI charts, the chartName needs to have whole URL.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: vault
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    oci://registry-1.docker.io/bitnamicharts/vault
    repositoryName:   oci-vault
    chartName:        oci://registry-1.docker.io/bitnamicharts/vault
    chartVersion:     0.7.2
    releaseName:      vault
    releaseNamespace: vault
    helmChartAction:  Install
```
