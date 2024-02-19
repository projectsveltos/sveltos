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
