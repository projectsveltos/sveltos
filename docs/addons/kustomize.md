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

## Example: Introduction to Kustomize and Sveltos

The below YAML snippet demonstrates how Sveltos utilizes a Flux GitRepository. The git repository, located at [https://github.com/gianlucam76/kustomize](https://github.com/gianlucam76/kustomize), comprises multiple kustomize directories. In this example, Sveltos executes Kustomize on the `helloWorld` directory and deploys the Kustomize output to the `eng` namespace for every managed cluster matching the Sveltos *clusterSelector*.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-system
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  kustomizationRefs:
  - namespace: flux-system
    name: flux-system
    kind: GitRepository
    path: ./helloWorld/
    targetNamespace: eng
```

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
  url: ssh://git@github.com/gianlucam76/kustomize
```

```bash
$ sveltosctl show addons
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
|               CLUSTER               |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILES |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
| default/sveltos-management-workload | apps:Deployment | eng       | the-deployment | N/A     | 2023-05-16 00:48:11 -0700 PDT | flux-system      |
| default/sveltos-management-workload | :Service        | eng       | the-service    | N/A     | 2023-05-16 00:48:11 -0700 PDT | flux-system      |
| default/sveltos-management-workload | :ConfigMap      | eng       | the-map        | N/A     | 2023-05-16 00:48:11 -0700 PDT | flux-system      |
+-------------------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
```

## Substitution and Templating

The Kustomize build process can generate parameterized YAML manifests. Sveltos can then instantiate these manifests using values provided in two locations:

1. `spec.kustomizationRefs.Values`: This field defines a list of key-value pairs directly within the ClusterProfile. These values are readily available for Sveltos to substitute into the template.
2. `spec.kustomizationRefs.ValuesFrom`: This field allows referencing external sources like ConfigMaps or Secrets. Their data sections contain key-value pairs that Sveltos can inject during template instantiation.

### Example of Sveltos Value Injection

Consider a Kustomize build output that includes a template for a deployment manifest:

```yaml
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

Now, imagine Sveltos receives a ClusterProfile containing the following key-value pairs:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-system
spec:
  kustomizationRefs:
  - deploymentType: Remote
    kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: ./template/helloWorld/
    targetNamespace: eng
    values:
      Region: east
      Version: v1.2.0
```

During deployment, Sveltos injects these values into the template, replacing the placeholders:

- {{ default "west" .Region }} is replaced with "east" (from the ClusterProfile's values).
- {{ .Version }} is replaced with "v1.2.0" (from the ClusterProfile's values).

This process transforms the template into the following concrete deployment manifest:

```yaml
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

### Dynamic Values with Nested Templates

Sveltos offers the capability to define key-value pairs where the value itself can be another template. This nested template can reference resources present in the management cluster.

 For example, consider the following key-value pair within a ClusterProfile:

```yaml
  Region:  {{ index .Cluster.metadata.labels "region" }}
  Version: v1.2.0
```

In this scenario, the value Region isn't a static string, but a template referencing the .Cluster.metadata.labels.region property. During deployment, Sveltos retrieves information from the management cluster's Cluster instance (represented here as .Cluster). It then extracts the value associated with the "region" label using the index function and assigns it to the Region key-value pair.

This mechanism allows you to dynamically populate values based on the management cluster's configuration, ensuring deployments adapt to specific environments.

### Summary

This summary outlines how Sveltos manages deployments using Kustomize and key-value pairs:

1. **Kustomize Build**: Sveltos initiates a Kustomize build process to prepare the deployment manifest template.
2. **Value Collection**: Sveltos gathers key-value pairs for deployment customization from two sources:

    - Directly defined values within the ClusterProfile's spec.kustomizationRefs.values field.
    - ConfigMap/Secret references specified in spec.kustomizationRefs.valuesFrom. Sveltos extracts key-value pairs from the data section of these referenced resources.

3. **Optional: Nested Template Processing (Advanced Usage)**: For advanced scenarios, a key-value pair's value itself can be a template. Sveltos evaluates these nested templates using data available in the context, such as information from the management cluster. This allows dynamic value construction based on the management cluster's configuration.
4. **Template Instantiation**: Finally, Sveltos uses the processed key-value pairs to substitute placeholder values within the Kustomize build output. These placeholders are typically denoted by _{{ .VariableName }}_.
  
This process ensures that deployments are customized with appropriate values based on the ClusterProfile configuration and, optionally, the management cluster's state.

This is a fully working example:

1. Flux is used to sync git repository https://github.com/gianlucam76/kustomize
2. The Kustomize build of `template/helloWorld` is a template
3. key-value pairs (`Values` field) are expressed as template, so Sveltos will instatiate those using the Cluster instance
4. instantiated key-value pairs are used by Sveltos to instantiate the output of the Kustomize build
5. resources are finally deployed to managed cluster

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-system
spec:
  clusterSelector: env=fv
  kustomizationRefs:
  - deploymentType: Remote
    kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: ./template/helloWorld/
    targetNamespace: eng
    values:
      Region: '{{ index .Cluster.metadata.labels "region" }}'
      Version: v1.2.0
  reloader: false
  stopMatchingBehavior: WithdrawPolicies
  syncMode: Continuous
```

with GitRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
  ...
spec:
  interval: 1m0s
  ref:
    branch: main
  secretRef:
    name: flux-system
  timeout: 60s
  url: https://github.com/gianlucam76/kustomize.git
```

```
sveltosctl show addons 
+-----------------------------+-----------------+-----------+----------------+---------+--------------------------------+----------------------------+
|           CLUSTER           |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |              TIME              |          PROFILES          |
+-----------------------------+-----------------+-----------+----------------+---------+--------------------------------+----------------------------+
| default/clusterapi-workload | apps:Deployment | eng       | the-deployment | N/A     | 2024-05-01 11:43:54 +0200 CEST | ClusterProfile/flux-system |
| default/clusterapi-workload | :Service        | eng       | the-service    | N/A     | 2024-05-01 11:43:54 +0200 CEST | ClusterProfile/flux-system |
| default/clusterapi-workload | :ConfigMap      | eng       | the-map        | N/A     | 2024-05-01 11:43:54 +0200 CEST | ClusterProfile/flux-system |
+-----------------------------+-----------------+-----------+----------------+---------+--------------------------------+----------------------------+
```

### Kustomize with ConfigMaps

If you have directories containing Kustomize resources, you can include them in a ConfigMap (or a Secret) and have a ClusterProfile reference it.

In this example, we are cloning the git repository `https://github.com/gianlucam76/kustomize` locally, and then we create a `kustomize.tar.gz` with the content of the helloWorldWithOverlays directory.

```bash
$ git clone git@github.com:gianlucam76/kustomize.git 

$ tar -czf kustomize.tar.gz -C kustomize/helloWorldWithOverlays .

$ kubectl create configmap kustomize --from-file=kustomize.tar.gz
```

The below ClusterProfile will use the Kustomize SDK to get all the resources needed for deployment. Then will deploy these in the `production` namespace of the managed clusters with the Sveltos clusterSelector set to *env=fv*.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kustomize-with-configmap 
spec:
  clusterSelector: env=fv
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
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
|               CLUSTER               |  RESOURCE TYPE  | NAMESPACE  |           NAME            | VERSION |             TIME              |     CLUSTER PROFILES     |
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
| default/sveltos-management-workload | apps:Deployment | production | production-the-deployment | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
| default/sveltos-management-workload | :Service        | production | production-the-service    | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
| default/sveltos-management-workload | :ConfigMap      | production | production-the-map        | N/A     | 2023-05-16 00:59:13 -0700 PDT | kustomize-with-configmap |
+-------------------------------------+-----------------+------------+---------------------------+---------+-------------------------------+--------------------------+
```
