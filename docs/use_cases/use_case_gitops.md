---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | GitOps | Flux Integration
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
    - Eleni Grosdouli
---

## Sveltos and GitOps

Flux is a CNCF graduate project that offers users a set of continuous and progressive delivery solutions for Kubernetes which are open and extensible.

By integrating Flux with Sveltos, we can automate the synchronisation of any desired Kubernetes add-ons, removing any manual steps and ensuring consistent deployment across different clusters.

![Flux and Sveltos Integration](../assets/flux_and_sveltos.png)

## What are the benefits?

1. **Centralized Configuration:** Store `YAML/JSON` manifests in a central Git repository or Bucket.
2. **Continuous Synchronisation:** **Flux** in the **management cluster** ensures continuous synchronisation of configurations.
3. **Consistent Deployments:** Use Sveltos `ClusterProfiles`, `Profiles` to reliably deploy Kubernetes add-ons in matching clusters.

## How it works?

Store all required Kubernetes resources in a Git repository and let Flux handle continuous synchronisation. Below, we show how to use Flux and Sveltos to deploy a HelloWorld application across multiple managed clusters.

👉 **[Explore the Example Repository](https://github.com/gianlucam76/kustomize/)**

### Step 1: Configure Flux in the Management Cluster

Install and run Flux in the management cluster. Configure it to synchronise the Git repository which contains the `HelloWorld` manifests. Use a GitRepository resource similar to the below YAML definitions. More information about the Flux installation can be found [here](https://medium.com/r/?url=https%3A%2F%2Ffluxcd.io%2Fflux%2Finstallation%2F).

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
  annotations:
    projectsveltos.io/template: "true" # (1)
spec:
  interval: 1m0s # (2)
  ref:
    branch: main
  secretRef:
    name: flux-system
  timeout: 60s
  url: https://github.com/gianlucam76/kustomize.git # (3)
```

1. Enable Sveltos templating functionality. More information have a look [here](../template/intro_template.md).
2. How often to sync with the reposiroty
3. Reflects the repository we want to use

The above definition will look for updates of the main branch of the specified repository every minute.

!!! Info
    If you use the Flux CLI to bootstrap a Git repo, the `GitRepository` Kubernetes resource will be created from Flux automatically.

### Step 2: Create a Sveltos ClusterProfile

Define a Sveltos ClusterProfile referencing to the `flux-system` `GitRepository` resource and define the HelloWorld directory as the deployment source. In the below YAML definition, an application will get deployed on the managed cluster with the label selector set to *env=fv*.


```yaml
cat > cluster_profile_flux.yaml <<EOF
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-helloworld-resources
spec:
  clusterSelector:
    matchLabels:
      env: fv
  policyRefs:
  - kind: GitRepository
    name: flux-system
    namespace: flux-system
    path: ./helloWorld/
    targetNamespace: eng
EOF
```

Whenever there is a change in the Git repository, Sveltos will leverage the Kustomize SDK to retrieve a list of resources to deploy to any cluster matching the label selector `env=fv` in the `eng` namespace.

!!! note
    The GitRepository or Bucket content can also be a template. Sveltos will take the content of the files and instantiate them by the use of the data resources in the management cluster. For the templates deployment, we will have to ensure the `GitRepository` Kubernetes resource includes the `projectsveltos.io/template: "true"` annotation.

## More Resources

For more information about the Sveltos and Flux integration, have a look [here](../addons/example_flux_sources.md).
