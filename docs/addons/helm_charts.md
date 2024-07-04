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
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector:
    matchLabels:
      env: prod
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.2.5
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

In the above YAML definition, we install Kyverno on a managed cluster with the label selector set to *env=prod*.

### Example: Multiple Helm charts

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
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.2.5
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
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.2.5
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

### Template-based Referencing for ValuesFrom

In the ValuesFrom section, we can express ConfigMap and Secret names as templates and dynamically generate them using cluster information. This allows for easier management and reduces redundancy.

Available cluster information :

- cluster namespace: use `.Cluster.metadata.namespace`
- cluster name: `.Cluster.metadata.name` 
- cluster type: `.Cluster.kind` 

Consider two SveltosCluster instances in the _civo_ namespace:

```bash
kubectl get sveltoscluster -n civo --show-labels
NAME             READY   VERSION        LABELS
pre-production   true    v1.29.2+k3s1   env=civo,projectsveltos.io/k8s-version=v1.29.2
production       true    v1.28.7+k3s1   env=civo,projectsveltos.io/k8s-version=v1.28.7
```

Additionally, there are four ConfigMaps within the civo namespace:

```bash
kubectl get configmap -n civo                                                   
NAME                                  DATA   AGE
admission-controller-pre-production   1      8m31s
admission-controller-production       1      7m49s
cleanup-controller-pre-production     1      8m48s
cleanup-controller-production         1      8m1s
```

The only difference between these ConfigMaps is the admissionController and cleanupController __replicas__ setting: 1 for _pre-production_ and 3 for _production_.

Following ClusterProfile:

1. *Matches both SveltosClusters*
2. *Dynamic ConfigMap Selection*:
    - For the `pre-production` cluster, the profile should use the `admission-controller-pre-production` and `cleanup-controller-pre-production` ConfigMaps.
    - For the `production` cluster, the profile should use the `admission-controller-production` and `cleanup-controller-production` ConfigMaps.

```yaml hl_lines="21-27"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector:
    matchLabels:
      env: civo
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.2.5
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
    values: |
      backgroundController:
        replicas: 3
    valuesFrom:
    - kind: ConfigMap
      name: cleanup-controller-{{ .Cluster.metadata.name }}
      namespace: civo
    - kind: ConfigMap
      name: admission-controller-{{ .Cluster.metadata.name }}
      namespace: civo
```

### Example: Express Helm Values as Templates

Both the __values__ section and the content stored in referenced ConfigMaps and Secrets can be written using templates. 
Sveltos will instantiate these templates using resources in the management cluster. Finally Sveltos deploy the Helm chart with the final, resolved values.
See the template section [template section](../template/template_generic_examples.md) for details.

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-calico
spec:
  clusterSelector:
    matchLabels:
      env: prod
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
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-cilium-v1-26
spec:
  clusterSelector:
    matchLabels:
      env: fv
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
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: vault
spec:
  clusterSelector:
    matchLabels:
      env: fv
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
