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

## Example: Deploy Kyverno with Flux and Sveltos

Imagine a repository like [this](https://github.com/gianlucam76/yaml_flux.git) containing a kyverno directory with all the YAML needed to deploy Kyverno. 

Below, we demonstrate how to leverage Flux and Sveltos to automatically deploy Kyverno to managed clusters.

### Step 1: Configure Flux in the Management Cluster

Run Flux in your management cluster and configure it to synchronize the Git repository containing your Kyverno manifests. Use a __GitRepository__ resource similar to the below.

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

### Step 2: Create a Sveltos ClusterProfile

Define a Sveltos ClusterProfile referencing the flux-system Git repository and defining the Kyverno directory as the source of the deployment.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno-resources
spec:
  clusterSelector: env=fv
  policyRefs:
  - kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: kyverno
```

This ClusterProfile targets clusters with the __env=fv__ label and fetches relevant deployment information from the Kyverno directory within the flux-system Git repository managed by Flux.

## Example: Template with Git Repository/Bucket Content

The content within the Git repository or other sources referenced by a Sveltos ClusterProfile can also be a template[^1].To enable templating, annotate the referenced GitRepository instance with __"projectsveltos.io/template: true"__. 
When Sveltos processes the template, it will perform the below.

- Read the content of all files inside the specified path
- Instantiate the templates ultilising the data from resources in the management cluster, similar to how it currently works with referenced Secrets and ConfigMaps

This allows dynamic deployment customisation based on the specific characteristics of the clusters, further enhancing flexibility and automation.

Let's try it out! The content in the "template" directory of this [repository](https://github.com/gianlucam76/yaml_flux.git) serves as the perfect example.

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

Add the __projectsveltos.io/template: "true"__ annotation to the __GitRepository__ resources created further above.

The below ClusterProfile demonstrates how this works.

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

The ClusterProfile will use the information from the "Cluster" resource in the management cluster to populate the template and then deploy it.

An example of __ConfigMap__ deployed in a managed cluster is found below.

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
