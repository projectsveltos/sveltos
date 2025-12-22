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

## Flux Sources

Sveltos can seamlessly integrate with __Flux__[^1] to automatically deploy YAML manifests or Helm charts stored in a Git repository or a Bucket. This powerful combination allows you to manage Kubernetes configurations in a central location and leverage Sveltos to target deployments across clusters.

## Example: Deploy Nginx Ingress with Flux and Sveltos

Imagine a repository like [this](https://github.com/gianlucam76/yaml_flux.git) containing an _nginx-ingress_ directory with all the required YAML resources for deployment[^2]. In the steps below we demonstrate how to leverage Flux and Sveltos to automatically perform the deployment.

### Step 1: Configure Flux in the Management Cluster

Install Flux in the **management** cluster and configure it to synchronise the Git repository containing the Nginx manifests. More information about the Flux installation can be found [here](https://fluxcd.io/flux/installation/).

Deploy a __GitRepository__ resource similar to the below.

!!! example "GitRepository Resource"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux-system
      namespace: flux-system
    spec:
      interval: 1m0s
      ref:
        branch: main
      secretRef:
        name: flux-system
      timeout: 60s
      url: https://github.com/gianlucam76/yaml_flux.git
    ```

### Step 2: Create a Sveltos ClusterProfile

Define a Sveltos ClusterProfile referencing the flux-system GitRepository and specify the _nginx-ingress_ directory as the source of the deployment.

!!! example "Sveltos ClusterProfile Nginx Ingress"
    ```yaml
    cat > clusterprofile_nginx_ingress.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-nginx-ingress
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      policyRefs:
      - kind: GitRepository
        name: flux-system
        namespace: flux-system
        path: nginx-ingress
    EOF
    ```

The `ClusterProfile` targets clusters with the __env=fv__ label and fetches relevant deployment information from the _nginx-ingress_ directory within the flux-system Git repository managed by Flux.

```
$ sveltosctl show addons
+-----------------------------+----------------------------------------------+-----------+---------------------------------------+---------+-------------------------------+-------------------------------------+
|           CLUSTER           |                RESOURCE TYPE                 | NAMESPACE |                 NAME                  | VERSION |             TIME              |              PROFILES               |
+-----------------------------+----------------------------------------------+-----------+---------------------------------------+---------+-------------------------------+-------------------------------------+
| default/clusterapi-workload | :ConfigMap                                   | default   | nginx-ingress-leader                  | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | rbac.authorization.k8s.io:ClusterRole        |           | nginx-stable-nginx-ingress            | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | rbac.authorization.k8s.io:RoleBinding        | default   | nginx-stable-nginx-ingress            | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | apps:Deployment                              | default   | nginx-stable-nginx-ingress-controller | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | :ServiceAccount                              | default   | nginx-stable-nginx-ingress            | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | :ConfigMap                                   | default   | nginx-stable-nginx-ingress            | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | rbac.authorization.k8s.io:ClusterRoleBinding |           | nginx-stable-nginx-ingress            | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | rbac.authorization.k8s.io:Role               | default   | nginx-stable-nginx-ingress            | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | :Service                                     | default   | nginx-stable-nginx-ingress-controller | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
| default/clusterapi-workload | networking.k8s.io:IngressClass               |           | nginx                                 | N/A     | 2024-03-23 11:43:10 +0100 CET | ClusterProfile/deploy-nginx-ingress |
+-----------------------------+----------------------------------------------+-----------+---------------------------------------+---------+-------------------------------+-------------------------------------+
```

## Example: Deploy Kyverno policies with Flux and Sveltos

### Step 1: Configure Flux in the Management Cluster

Install Flux in the **management** cluster and configure it to synchronise the Git repository containing the Kyverno manifests.

Deploy a __GitRepository__ resource similar to the below.

!!! example "GitRepository Resource"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux-system
      namespace: flux-system
    spec:
      interval: 1m0s
      ref:
        branch: main
      secretRef:
        name: flux-system
      timeout: 60s
      url: https://github.com/gianlucam76/yaml_flux.git
    ```

### Step 2: Create a Sveltos ClusterProfile

Define a ClusterProfile to deploy the Kyverno helm chart.

!!! example "Sveltos ClusterProfile Kyverno"
    ```yaml
    cat > clusterprofile_kyverno.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
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
        chartVersion:     v3.3.3
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
    EOF
    ```

Define a Sveltos `ClusterProfile` referencing the flux-system GitRepository and defining the __kyverno__ directory as the source of the deployment.

The mentioned directory contains a list of Kyverno ClusterPolicies.

!!! example "Sveltos ClusterProfile Kyverno Policies"
    ```yaml
    cat > clusterprofile_kyverno_policies.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-kyverno-policies
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      policyRefs:
      - kind: GitRepository
        name: flux-system
        namespace: flux-system
        path: kyverno
      dependsOn:
      - deploy-kyverno
    EOF
    ```

The above `ClusterProfile` targets clusters with the __env=fv__ label and fetches relevant deployment information from the _kyverno_ directory within the flux-system Git repository managed by Flux.

The Kyverno Helm chart and all the Kyverno policies contained in the Git repository under the _kyverno_ directory are deployed:

```
$ sveltosctl show addons
+-----------------------------+--------------------------+-----------+---------------------------+---------+-------------------------------+----------------------------------------+
|           CLUSTER           |      RESOURCE TYPE       | NAMESPACE |           NAME            | VERSION |             TIME              |                PROFILES                |
+-----------------------------+--------------------------+-----------+---------------------------+---------+-------------------------------+----------------------------------------+
| default/clusterapi-workload | helm chart               | kyverno   | kyverno-latest            | 3.2.5   | 2024-03-23 11:39:30 +0100 CET | ClusterProfile/deploy-kyverno          |
| default/clusterapi-workload | kyverno.io:ClusterPolicy |           | restrict-image-registries | N/A     | 2024-03-23 11:40:11 +0100 CET | ClusterProfile/deploy-kyverno-policies |
| default/clusterapi-workload | kyverno.io:ClusterPolicy |           | disallow-latest-tag       | N/A     | 2024-03-23 11:40:11 +0100 CET | ClusterProfile/deploy-kyverno-policies |
| default/clusterapi-workload | kyverno.io:ClusterPolicy |           | require-ro-rootfs         | N/A     | 2024-03-23 11:40:11 +0100 CET | ClusterProfile/deploy-kyverno-policies |
+-----------------------------+--------------------------+-----------+---------------------------+---------+-------------------------------+----------------------------------------+
```

## Example: Reference Helm Charts from Flux Sources

Sveltos allows us to deploy Helm charts from various sources, including traditional **HTTP** repositories, **OCI** registries, and Flux **sources**. This section focuses on using Flux sources as a Helm chart repository.

### Utilise Flux GitRepository as a Helm Chart Source

To deploy Helm charts from a Flux GitRepository, specify the `repositoryURL` in the `ClusterProfile` using the following format:

```
<flux source kind>://<flux source namespace>/<flux source name>/<path>
```
More information about the command arguments defined above.

- `<flux source kind>`: The type of Flux source. For Git repositories, this is `gitrepository` (available options: `ocirepository` and `bucket`)
- `<flux source namespace>`: The Kubernetes namespace where the Flux GitRepository is located
- `<flux source name>`: The name of the Flux GitRepository
- `<path>`: The relative path within the Git repository to the directory containing the Helm charts

!!! note
    Use the ```kubectl get gitrepository.source.toolkit.fluxcd.io -A``` command to get a view of the existing syncronised repositories.

#### Scenario

Let's assume we have a Flux GitRepository named `flux-system` in the `flux-system` namespace.

The GitRepository resource is configured to synchronise the `https://github.com/projectsveltos/helm-charts.git/` repository. The Helm charts are located in the `charts/projectsveltos` directory within the mentioned repository.

To deploy the `projectsveltos` chart using Sveltos, we can create a `ClusterProfile` with the below `helmCharts` options.

```yaml
helmCharts:
  - repositoryURL:    gitrepository://flux-system/flux-system/charts/projectsveltos
    releaseName:      projectsveltos
    releaseNamespace: projectsveltos
    helmChartAction:  Install
```

## Example: Template with Git Repository/Bucket Content

The content within the Git repository or other sources referenced by a Sveltos `ClusterProfile` can be templates[^3].To enable templating, annotate the referenced `GitRepository` instance with __"projectsveltos.io/template: true"__.

When Sveltos processes the template, it will perform the below.

- Read the content of all files inside the specified path
- Instantiate the templates ultilising the data from resources in the management cluster, similar to how it currently works with referenced Secrets and ConfigMaps

This allows dynamic deployment customisation based on the specific characteristics of the clusters, further enhancing flexibility and automation.

Let's try it out! The content in the "template" directory of the [repository](https://github.com/gianlucam76/yaml_flux.git) serves as the perfect example.

### Template Definition

!!! example "ConfigMap Definition"
    ```yaml
    cat > cm.yaml <<EOF
    # Sveltos will instantiate this template before deploying to matching managed cluster
    # Sveltos will get the ClusterAPI Cluster instance representing the cluster in the
    # managed cluster, and use that resource data to instintiate this ConfigMap before
    # deploying it
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: {{ .Cluster.metadata.name }}
      namespace: default
    data:
      controlPlaneEndpoint: "{{ .Cluster.spec.controlPlaneEndpoint.host }}:{{ .Cluster.spec.controlPlaneEndpoint.port }}"
    EOF
    ```

### GitRepository Definition

!!! note
    Add the __projectsveltos.io/template: ok__ annotation to the __GitRepository__ resources created further above.

!!! example "GitRepository Resource"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux-system
      namespace: flux-system
      annotations:
        projectsveltos.io/template: ok
    spec:
      interval: 1m0s
      ref:
        branch: main
      secretRef:
        name: flux-system
      timeout: 60s
      url: https://github.com/gianlucam76/yaml_flux.git
    ```

### ClusterProfile Definition

!!! example "Sveltos ClusterProfile Flux Definition"
    ```yaml
    cat > clusterprofile_flux.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: flux-template-example
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      policyRefs:
      - kind: GitRepository
        name: flux-system
        namespace: flux-system
        path: template
    EOF
    ```

The `ClusterProfile` will use the information from the "Cluster" resource in the management cluster to populate the template and deploy it.

An example of a deployed __ConfigMap__ in the managed cluster can be found below.

!!! example ""
    ```yaml
    ---
    apiVersion: v1
    data:
      controlPlaneEndpoint: 172.18.0.4:6443
    kind: ConfigMap
    metadata:
      ...
      name: clusterapi-workload
      namespace: default
      ...
    ```

### Express Path as Template

The __path__ field within a policyRefs object in Sveltos can be defined using a template. This allows to dynamically set the path based on information from the cluster itself.

!!! example "Sveltos ClusterProfile Flux Region West"
    ```yaml
    cat > clusterprofile_flux_region_west.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: flux-system
    spec:
      clusterSelector:
        matchLabels:
          region: west
      syncMode: Continuous
      policyRefs:
      - kind: GitRepository
        name: flux-system
        namespace: flux-system
        path: '{{ index .Cluster.metadata.annotations "environment" }}/helloWorld'
    EOF
    ```

Sveltos uses the cluster instance in the management cluster to populate the template in the path field. The template expression ```{{ index .Cluster.metadata.annotations "environment" }}``` retrieves the value of the annotation named __environment__ from the cluster's metadata.

For example:

1. **Cluster A**: If cluster A has an annotation environment: production, the resulting path will be: production/helloWorld.
1. **Cluster B**: If cluster B has an annotation environment: pre-production, the resulting path will be: pre-production/helloWorld.

The mentioned approach allows for flexible configuration based on individual cluster environments. Remember to adapt the provided resources to your specific repository structure, cluster configuration, and desired templating logic.

A more complex example can be when we want to express the __path__ field as a template using __if__ statements.

!!! example "Sveltos ClusterProfile Flux Template __path__"
    ```yaml
    cat > clusterprofile_flux_template_path.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: flux-system
    spec:
      clusterSelector:
        matchLabels:
          region: west
      templateResourceRefs:
      - resource:
          apiVersion: lib.projectsveltos.io/v1beta1
          kind: SveltosCluster
          name: "{{ .Cluster.metadata.name }}"
        identifier: Cluster
      syncMode: Continuous
      policyRefs:
      - kind: GitRepository
        name: flux-system
        namespace: flux-system
        path: |-
          {{$path := index .Cluster.metadata.labels "projectsveltos.io/k8s-version" }}{{- if eq $path "v1.29.8"}}system/prod
          {{- else}}system/test
          {{- end}}
    EOF
    ```

Effectively, by defining the `templateResourceRefs` at the beginning of the ClusterProfile we can retrieve the **Sveltos managed clusters** Kubernetes version. The information is used at the `policyRefs` definition when we set the __path__ as a template with __if__ statements.

[^1]: The below __ClusterProfile__ allows us to install the Flux Controllers in the **management** cluster. However, before applying it, ensure the management cluster has labels that match the specified `clusterSelector`.
```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: flux
spec:
  clusterSelector:
    matchLabels:
      cluster: mgmt
  helmCharts:
  - chartName: flux2/flux2
    chartVersion: 2.12.4
    helmChartAction: Install
    releaseName: flux2
    releaseNamespace: flux2
    repositoryName: flux2
    repositoryURL: https://fluxcd-community.github.io/helm-charts
```
[^2]: The YAML was obtained by running ```helm template nginx-stable nginx-stable/nginx-ingress```.
[^3]: Do you want to dive deeper into Sveltos's templating features? Check out this [section](../template/examples/template_generic.md).
