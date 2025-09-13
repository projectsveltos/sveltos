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

## Introduction to Kustomize and Sveltos

Sveltos can seamlessly integrate with [Flux](https://fluxcd.io/flux/) to automatically deploy Kustomize code in a Git repository or a Bucket. This powerful combination allows you to manage Kubernetes configurations in a central location and leverage Sveltos to target deployments across clusters.

## Sveltos and Flux Sources

The example demonstrates how Sveltos utilizes a Flux GitRepository[^1]. The git repository is located [here](https://github.com/gianlucam76/kustomize) and comprises multiple kustomize directories. Sveltos executes Kustomize on the `helloWorld` directory and deploys the Kustomize output to the `eng` namespace for every Sveltos **managed** cluster matching the defined *clusterSelector*.

!!! example "Sveltos ClusterProfile"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: hello-world
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      kustomizationRefs:
      - namespace: flux2
        name: flux2
        kind: GitRepository
        path: ./helloWorld/
        targetNamespace: eng
    ```

!!! example "Flux GitRepository Resource"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux2
      namespace: flux2
    spec:
      interval: 1m0s
      ref:
        branch: main
      timeout: 60s
      url: ssh://git@github.com/gianlucam76/kustomize
    ```

!!! note
    Deploy both YAML manifest files to the Sveltos management cluster.

```bash
$ sveltosctl show addons
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+---------------------------------+
|               CLUSTER               |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |             TIME              |           PROFILES              |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+---------------------------------+
| default/sveltos-management-workload | apps:Deployment | eng       | the-deployment | N/A     | 2023-05-16 00:48:11 -0700 PDT | ClusterProfile/hello-world      |
| default/sveltos-management-workload | :Service        | eng       | the-service    | N/A     | 2023-05-16 00:48:11 -0700 PDT | ClusterProfile/hello-world      |
| default/sveltos-management-workload | :ConfigMap      | eng       | the-map        | N/A     | 2023-05-16 00:48:11 -0700 PDT | ClusterProfile/hello-world      |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+---------------------------------+
```

## Substitution and Templating

The Kustomize build process can generate parameterized YAML manifests. Sveltos can then instantiate the manifests using values provided in two locations.

1. `spec.kustomizationRefs.Values`: The field defines a list of key-value pairs directly within the ClusterProfile. These values are readily available for Sveltos to substitute into the template.
1. `spec.kustomizationRefs.ValuesFrom`: The field allows referencing external sources like ConfigMaps or Secrets. Their data sections contain key-value pairs that Sveltos can inject during template instantiation.

### Example: Sveltos Value Injection

Consider a Kustomize build output that includes a template for a deployment manifest.

!!! example ""
    ```yaml
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp-deployment
      namespace:  test
      labels:
        region: {{ default "west" .Region }}  # Placeholder for region with default value "west"
    spec:
      ...
      image: nginx:{{ .Version }}  # Placeholder for image version
    ```

Imagine Sveltos receives a `ClusterProfile` containing the below key-value pairs.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: hello-world-with-values
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      kustomizationRefs:
      - deploymentType: Remote
        kind: GitRepository
        name: flux2
        namespace: flux2
        path: ./template/helloWorld/
        targetNamespace: eng
        values:
          Region: east
          Version: v1.2.0
    ```

During deployment, Sveltos injects these values into the template, replacing the below placeholders.

- {{ default "west" .Region }} is replaced with "east" (from the ClusterProfile's values).
- {{ .Version }} is replaced with "v1.2.0" (from the ClusterProfile's values).

Taking this approach, we tranform the template into a concrete deployment manifest like the below.

!!! example ""
    ```yaml
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: myapp-deployment
      namespace:  test
      labels:
        region: east # Replaced value
    spec:
      ...
      image: nginx:v1.2.0 # Replaced value
    ```

### Example: Template-based Referencing for ValuesFrom

In the _ValuesFrom_ section, we can express `ConfigMap` and `Secret` names as templates and dynamically generate them using cluster information. This allows for easier management and reduces redundancy.

Available cluster information:

- cluster namespace: use `.Cluster.metadata.namespace`
- cluster name: `.Cluster.metadata.name`
- cluster type: `.Cluster.kind`

Consider two SveltosCluster instances in the _civo_ namespace.

```bash
$ kubectl get sveltoscluster -n civo --show-labels
NAME             READY   VERSION        LABELS
pre-production   true    v1.29.2+k3s1   env=civo,projectsveltos.io/k8s-version=v1.29.2
production       true    v1.28.7+k3s1   env=civo,projectsveltos.io/k8s-version=v1.28.7
```

There are two ConfigMaps within the _civo_ namespace. The ConfigMaps Data sections contain the same keys but different values.

```bash
$ kubectl get configmap -n civo
NAME                                  DATA   AGE
hello-world-pre-production            2      9m40s
hello-world-production                2      9m45s
```

The below Sveltos ClusterProfile includes the following.

1. *Matches both SveltosClusters*
1. *Dynamic ConfigMap Selection*:
    - For the `pre-production` cluster, the profile should use the `hello-world-pre-production` ConfigMap.
    - For the `production` cluster, the profile should use the `hello-world-production` ConfigMap.

!!! example ""
    ```yaml  hl_lines="16-19"
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: hello-world-with-values
    spec:
      clusterSelector:
        matchLabels:
          env: civo
      kustomizationRefs:
      - deploymentType: Remote
        kind: GitRepository
        name: flux-system
        namespace: flux-system
        path: ./template/helloWorld/
        targetNamespace: eng
        valuesFrom:
        - kind: ConfigMap
          name: hello-world-{{ .Cluster.metadata.name }}
          namespace: civo
    ```

### Example: Dynamic Values with Nested Templates

Sveltos offers the capability to define key-value pairs where the value itself can be another template. The nested template can reference resources present in the **management** cluster. For example, consider the below key-value pair within a ClusterProfile.

```yaml
  Region:  {{ index .Cluster.metadata.labels "region" }}
  Version: v1.2.0
```

The value Region is not a static string, but a template referencing the _.Cluster.metadata.labels.region_ property.

During deployment, Sveltos retrieves information from the **management** cluster's Cluster instance (represented here as .Cluster). It then extracts the value associated with the "region" label using the index function and assigns it to the Region key-value pair.

This mechanism allows us to dynamically populate values based on the **management** cluster's configuration, ensuring deployments adapt to specific environments.

### Components

To specify reusable configuration pieces from Kustomize, we can use the _components_ field within a Sveltos ClusterProfile. This allows us to include external components, defined in separate directories, into the main Kustomization.

The _components_ field is a list that points to the directories containing the Kustomize components. Each component should have its own kustomization.yaml file. The paths are relative to the Kustomization we are working

```yaml hl_lines="16-18"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: component-demo
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  kustomizationRefs:
  - namespace: flux-system
    name: flux-system
    kind: GitRepository
    path: ./import_components/overlays/community/
    targetNamespace: eng
    components:
    - ../../components/external_db
    - ../../components/recaptcha
```

In this example, the kustomizationRefs points to _import_components/overlays/community/kustomization.yaml_. This file will then pull in the two components specified: _external_db_ and _recaptcha_, which are located two directories up in the components folder. This structure enables a modular and reusable approach to configuration.

The repo being used here can be found [here](https://github.com/gianlucam76/kustomize/blob/main/import_components/overlays/community/kustomization.yaml)

### Example: All-in-One

The section outlines how Sveltos manages deployments using Kustomize and key-value pairs.

1. **Kustomize Build**: Sveltos initiates a Kustomize build process to prepare the deployment manifest template.
1. **Value Collection**: Sveltos gathers key-value pairs for deployment customization from two sources:
    - Directly defined values within the ClusterProfile's spec.kustomizationRefs.values field.
    - ConfigMap/Secret references specified in spec.kustomizationRefs.valuesFrom. Sveltos extracts key-value pairs from the data section of these referenced resources.

1. **Optional: Nested Template Processing (Advanced Usage)**: For advanced scenarios, a key-value pair's value itself can be a template. Sveltos evaluates these nested templates using data available in the context, such as information from the management cluster. This allows dynamic value construction based on the management cluster's configuration.
1. **Template Instantiation**: Finally, Sveltos uses the processed key-value pairs to substitute placeholder values within the Kustomize build output. These placeholders are typically denoted by _{{ .VariableName }}_.

This process ensures deployments are customized with appropriate values based on the ClusterProfile configuration and, optionally, the management cluster's state.

Fully working example:

1. Flux is used to sync git repository https://github.com/gianlucam76/kustomize
1. The Kustomize build of `template/helloWorld` is a template
1. key-value pairs (`Values` field) are expressed as template, so Sveltos will instatiate those using the Cluster instance
1. Instantiated key-value pairs are used by Sveltos to instantiate the output of the Kustomize build
1. Resources are finally deployed to the managed cluster

!!! example "Sveltos ClusterProfile"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: hello-world-with-template
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      kustomizationRefs:
      - deploymentType: Remote
        kind: GitRepository
        name: flux2
        namespace: flux2
        path: ./template/helloWorld/
        targetNamespace: eng
        values:
          Region: '{{ index .Cluster.metadata.labels "region" }}'
          Version: v1.2.0
      reloader: false
      stopMatchingBehavior: WithdrawPolicies
      syncMode: Continuous
    ```

!!! example "Flux GitRepository Resource"
    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: flux2
      namespace: flux2
    spec:
      interval: 1m0s
      ref:
        branch: main
      timeout: 60s
      url: https://github.com/gianlucam76/kustomize.git
    ```

```bash
$ sveltosctl show addons
+-----------------------------+-----------------+-----------+----------------+---------+--------------------------------+----------------------------+
|           CLUSTER           |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |              TIME              |          PROFILES          |
+-----------------------------+-----------------+-----------+----------------+---------+--------------------------------+--------------------------------------+
| default/clusterapi-workload | apps:Deployment | eng       | the-deployment | N/A     | 2024-05-01 11:43:54 +0200 CEST | ClusterProfile/hello-world-with-template |
| default/clusterapi-workload | :Service        | eng       | the-service    | N/A     | 2024-05-01 11:43:54 +0200 CEST | ClusterProfile/hello-world-with-template |
| default/clusterapi-workload | :ConfigMap      | eng       | the-map        | N/A     | 2024-05-01 11:43:54 +0200 CEST | ClusterProfile/hello-world-with-template |
+-----------------------------+-----------------+-----------+----------------+---------+--------------------------------+--------------------------------------+
```

### Example: Express Path as Template

The __path__ field within a _kustomizationRef_ object in Sveltos can be defined using a template. This allows you to dynamically set the path based on information from the cluster itself.

```yaml
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
  kustomizationRefs:
  - namespace: flux2
    name: flux2
    kind: GitRepository
    path: '{{ index .Cluster.metadata.annotations "environment" }}/helloWorld'
    targetNamespace: eng
```

Sveltos uses the cluster instance in the **management** cluster to populate the template in the path field. The template expression ```{{ index .Cluster.metadata.annotations "environment" }}``` retrieves the value of the annotation named __environment__ from the cluster's metadata.

For instance:

1. Cluster A: If cluster A has an annotation environment: production, the resulting path will be: production/helloWorld.
1. Cluster B: If cluster B has an annotation environment: pre-production, the resulting path will be: pre-production/helloWorld.

This approach allows for flexible configuration based on individual cluster environments.

### Example: Kustomize with ConfigMaps

Directories containing Kustomize resources can be included in a ConfigMap (or a Secret) and use a Sveltos ClusterProfile to reference it.

In this example, we are cloning the git repository `https://github.com/gianlucam76/kustomize` locally, then we create a `kustomize.tar.gz` with the content of the helloWorldWithOverlays directory.

```bash
$ git clone git@github.com:gianlucam76/kustomize.git

$ tar -czf kustomize.tar.gz -C kustomize/helloWorldWithOverlays .

$ kubectl create configmap kustomize --from-file=kustomize.tar.gz
```

The below ClusterProfile will use the Kustomize SDK to get all the resources needed for deployment. Then will deploy these in the `production` namespace of the managed clusters with the Sveltos clusterSelector set to *env=fv*.

!!! example "Sveltos ClusterProfile"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: kustomize-with-configmap
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      kustomizationRefs:
      - namespace: default
        name: kustomize
        kind: ConfigMap
        path: ./overlays/production/
        targetNamespace: production
    ```

```bash
$ sveltosctl show addons
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+---------------------------------+
|               CLUSTER               |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |             TIME              |           PROFILES              |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+---------------------------------+
| default/sveltos-management-workload | apps:Deployment | production | production-the-deployment | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
| default/sveltos-management-workload | :Service        | production | production-the-service    | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
| default/sveltos-management-workload | :ConfigMap      | production | production-the-map        | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
```

## Next Steps

For a better understanding of the Sveltos and Flux integration, check out the Flux Sources examples [here](./example_flux_sources.md).

[^1]: This __ClusterProfile__ allows you to install Flux in your management cluster. However, before applying it, ensure your management cluster has labels that match the specified clusterSelector.
```yaml
---
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
