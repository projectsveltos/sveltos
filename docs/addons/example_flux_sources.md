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

Sveltos can seamlessly integrate with __Flux__ to automatically deploy YAML manifests stored in a Git repository or a Bucket. This powerful combination allows you to manage Kubernetes configurations in a central location and leverage Sveltos to target deployments across clusters.

## Example: Deploy Nginx Ingress with Flux and Sveltos

Imagine a repository like [this](https://github.com/gianlucam76/yaml_flux.git) containing a _nginx-ingress_ directory with all the YAML needed to deploy Nginx[^2]. 

Below, we demonstrate how to leverage Flux and Sveltos to automatically perform the deployment.

### Step 1: Configure Flux in the Management Cluster

Install and run Flux in the management cluster and configure it to synchronise the Git repository containing the Nginx manifests. More information about the Flux installation can be found [here](https://medium.com/r/?url=https%3A%2F%2Ffluxcd.io%2Fflux%2Finstallation%2F).

Use a __GitRepository__ resource similar to the below.

```yaml
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

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-nginx-ingress
spec:
  clusterSelector: env=fv
  policyRefs:
  - kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: nginx-ingress
```

This ClusterProfile targets clusters with the __env=fv__ label and fetches relevant deployment information from the _nginx-ingress_ directory within the flux-system Git repository managed by Flux.

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

Install and run Flux in your management cluster and configure it to synchronise the Git repository containing the Kyverno manifests.

Use a __GitRepository__ resource similar to the below.

```yaml
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

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.1.4
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

Define a Sveltos ClusterProfile referencing the flux-system GitRepository and defining the _kyverno__ directory as the source of the deployment.

This directory contains a list of Kyverno ClusterPolicies.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno-policies
spec:
  clusterSelector: env=fv
  policyRefs:
  - kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: kyverno
  dependsOn: 
  - deploy-kyverno
```

This ClusterProfile targets clusters with the __env=fv__ label and fetches relevant deployment information from the _kyverno__ directory within the flux-system Git repository managed by Flux.

The Kyverno Helm chart and all the Kyverno policies contained in the Git repository under the _kyverno_ directory are deployed:

```
$ sveltosctl show addons     
+-----------------------------+--------------------------+-----------+---------------------------+---------+-------------------------------+----------------------------------------+
|           CLUSTER           |      RESOURCE TYPE       | NAMESPACE |           NAME            | VERSION |             TIME              |                PROFILES                |
+-----------------------------+--------------------------+-----------+---------------------------+---------+-------------------------------+----------------------------------------+
| default/clusterapi-workload | helm chart               | kyverno   | kyverno-latest            | 3.1.4   | 2024-03-23 11:39:30 +0100 CET | ClusterProfile/deploy-kyverno          |
| default/clusterapi-workload | kyverno.io:ClusterPolicy |           | restrict-image-registries | N/A     | 2024-03-23 11:40:11 +0100 CET | ClusterProfile/deploy-kyverno-policies |
| default/clusterapi-workload | kyverno.io:ClusterPolicy |           | disallow-latest-tag       | N/A     | 2024-03-23 11:40:11 +0100 CET | ClusterProfile/deploy-kyverno-policies |
| default/clusterapi-workload | kyverno.io:ClusterPolicy |           | require-ro-rootfs         | N/A     | 2024-03-23 11:40:11 +0100 CET | ClusterProfile/deploy-kyverno-policies |
+-----------------------------+--------------------------+-----------+---------------------------+---------+-------------------------------+----------------------------------------+
```

## Example: Template with Git Repository/Bucket Content

The content within the Git repository or other sources referenced by a Sveltos ClusterProfile can be templates[^1].To enable templating, annotate the referenced `GitRepository` instance with __"projectsveltos.io/template: true"__.

When Sveltos processes the template, it will perform the below.

- Read the content of all files inside the specified path
- Instantiate the templates ultilising the data from resources in the management cluster, similar to how it currently works with referenced Secrets and ConfigMaps

This allows dynamic deployment customisation based on the specific characteristics of the clusters, further enhancing flexibility and automation.

Let's try it out! The content in the "template" directory of this [repository](https://github.com/gianlucam76/yaml_flux.git) serves as the perfect example.

### Template Definition

``` yaml
# Sveltos will instantiate this template before deploying to matching managed cluster
# Sveltos will get the ClusterAPI Cluster instance representing the cluster in the
# managed cluster, and use that resource data to instintiate this ConfigMap before
# deploying it
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Cluster.metadata.name }}
  namespace: default
data:
  controlPlaneEndpoint: "{{ .Cluster.spec.controlPlaneEndpoint.host }}:{{ .Cluster.spec.controlPlaneEndpoint.port }}"
```

### GitRepository Definition

Add the __projectsveltos.io/template: "true"__ annotation to the __GitRepository__ resources created further above.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
  annotations:
    projectsveltos.io/template: "true"
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

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-template-example
spec:
  clusterSelector: env=fv
  policyRefs:
  - kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: template
```

The ClusterProfile will use the information from the "Cluster" resource in the management cluster to populate the template and deploy it.

An example of a deployed __ConfigMap__ in the managed cluster can be found below.

```yaml
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

Remember to adapt the provided resources to your specific repository structure, cluster configuration, and desired templating logic.

[^1]: Do you want to dive deeper into Sveltos's templating features? Check out this [section](../template/template.md).
[^2]: The YAML was obtained by running ```helm template nginx-stable nginx-stable/nginx-ingress```