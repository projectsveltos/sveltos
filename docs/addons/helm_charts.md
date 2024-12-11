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
    chartVersion:     v3.3.3
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
    chartVersion:     v3.3.3
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
    chartVersion:     v3.3.3
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
    chartVersion:     v3.3.3
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
  - repositoryURL:    oci://registry-1.docker.io/bitnamicharts
    repositoryName:   oci-vault
    chartName:        vault
    chartVersion:     0.7.2
    releaseName:      vault
    releaseNamespace: vault
    helmChartAction:  Install
```

### Example: Private Registry

Create a file named _secret_content.yaml_ with the following content, replacing the redacted values with your actual Docker Hub username and password/token:

```
{"auths":{"https://registry-1.docker.io/v1/":{"username":"REDACTED","password":"REDACTED","auth":"username:password base64 encoded"}}}
```

Use the kubectl command to create a Secret named _regcred_ in the _default_ namespace. This command references the _secret_content.yaml_ file and sets the type to _kubernetes.io/dockerconfigjson_:

```
kubectl create secret generic regcred  --from-file=.dockerconfigjson=secret_content.yaml --type=kubernetes.io/dockerconfigjson         
```

Now you can configure your ClusterProfile to use the newly created Secret for authentication with Docker Hub.

Here's an example snippet from the ClusterProfile YAML file:

```yaml hl_lines="18-21"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: projectsveltos
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    oci://registry-1.docker.io/gianlucam76
    repositoryName:   projectsveltos
    chartName:        projectsveltos
    chartVersion:     0.38.1
    releaseName:      projectsveltos
    releaseNamespace: projectsveltos
    helmChartAction:  Install
    registryCredentialsConfig:
      credentials:
        name: regcred
        namespace: default
```

In this example, the `registryCredentialsConfig` section references the regcred Secret stored in the default namespace. This ensures that the Helm chart can access the private registry during deployment.

Another example using Harbor (on Civo cluster) as registry. Create a file named _secret_harbor_content.yaml_ with the following content, replacing the base64 encoded string with your Harbor credentials:

```
{"auths":{"https://harbor.XXXX.k8s.civo.com":{"auth":"YWRtaW46SGFyYm9yMTIzNDU="}}}
```

Create a Secret named _credentials_ in the default namespace using the secret_harbor_content.yaml file:

```
kubectl create secret generic credentials --from-file=config.json=secret_harbor_content.yaml
```

Update your ClusterProfile YAML to reference the credentials Secret:

```yaml hl_lines="18-22"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: projectsveltos
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    oci://harbor.4fc01642-cfc0-4c55-a139-d593c92b232f.k8s.civo.com/library
    repositoryName:   projectsveltos
    chartName:        projectsveltos
    chartVersion:     0.38.1
    releaseName:      projectsveltos
    releaseNamespace: projectsveltos
    helmChartAction:  Install
    registryCredentialsConfig:
      insecureSkipTLSVerify: true
      credentials:
        name: credentials
        namespace: default
```

!!! note
The `insecureSkipTLSVerify` option should only be used if your private registry does not support TLS verification. It's generally recommended to use a secure TLS connection and set the `CASecretRef` field in the `registryCredentialsConfig`

### Upgrade CRDs

Helm doesn't currently offer built-in support for [upgrading CRDs](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/#some-caveats-and-explanations). 
This was a deliberate decision to avoid potential data loss. There's also ongoing discussion within the Helm community about the ideal way to manage CRD lifecycles. Future Helm versions might address this.

For custom Helm charts, you can work around this limitation by:

- Placing CRDs in templates: Instead of the crds/ directory, include your CRDs within the chart's templates folder. This allows them to be upgraded during the chart update process.
- Separate Helm chart: As suggested by the official Helm documentation, consider creating a separate Helm chart specifically for your CRDs. This allows independent management of those resources.

However, using third-party Helm charts can be problematic as upgrading their CRDs might not be possible by default. Here's where Sveltos comes in.
Sveltos allows you to control CRD upgrades for third-party charts through the `upgradeCRDs` field within your ClusterProfile configuration.
When `upgradeCRDs` is set to true, Sveltos will initially patch all Custom Resource Definition (CRD) instances located in the Helm chart's _crds/_ directory. 
Once these CRDs are updated, Sveltos will proceed with the Helm upgrade process.

```yaml hl_lines="12-14"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
...
  helmCharts:
  - repositoryURL:    <REPO URL>
    repositoryName:   <REPO NAME>
    chartName:        <CHART NAME>
    chartVersion:     <CHART VERSION>
    releaseName:      <...>
    releaseNamespace: <...>
    options:
      upgradeOptions:
        upgradeCRDs: true
```

### Options

Sveltos allows you to configure Helm charts options during deployment.  For a complete list of Helm options, refer to the [CRD](https://github.com/projectsveltos/addon-controller/blob/806699b7aea2afba1b98b904fed439e825ddf65f/api/v1beta1/spec.go#L184).

```yaml hl_lines="14-15"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: XXXX
spec:
  ...
  helmCharts:
   - repositoryURL:    <REPO URL>
     repositoryName:   <REPO NAME>
     chartName:        <CHART NAME>
     chartVersion:     <CHART VERSION>
     releaseName:      <...>
     releaseNamespace: <...>
     options:
       disableHooks: true
```