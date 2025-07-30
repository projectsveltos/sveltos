---
title: Example - Flux Sources with Sveltos EventFramework
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Event Driven
    - Generators
    - Secrets Example
authors:
    - Eleni Grosdouli
---

## Sveltos and Flux Sources

Most common use cases utilise the power of Sveltos together with [Flux](https://fluxcd.io/flux/get-started/) to deliver seamless GitOps workflows for deployments across a fleet of clusters. In this example, we combine the power of the Sveltos Event Framework, enabling operators to easily synchronise and deploy Kubernetes manifests or Helm charts stored in a source control system.

### Install and Configure Flux

If you have not done so already, refer to the [Flux section](../../addons/example_flux_sources.md) to learn how to install Flux, set up Flux sources, and see how Sveltos makes use of them.

#### Flux Source

After installing Flux on the management cluster, we can create a `GitRepository` resource and define the repository we want to synchronise.

!!! Example "Flux GitRepository"

    ```yaml
    ---
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: GitRepository
    metadata:
      name: test
      namespace: flux-system
    spec:
      interval: 1m0s
      ref:
        branch: main
      secretRef:
        name: github-creds
      timeout: 60s
      url: https://<GitHub domain>/<group name>/<repository name>.git 
    ```

### EventFramework

In this example, we want to automatically deploy Kubernetes manifests and/or Helm charts from a specific Flux source whenever new clusters are registered with Sveltos and have the label _env: test_.

!!! Example "EventSource"

    ```yaml hl_lines="12-15"
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: cluster-registration
    spec:
      collectResources: true
      resourceSelectors:
      - group: "lib.projectsveltos.io"
        version: "v1beta1"
        kind: "SveltosCluster"
        labelFilters:
        - key: env
          operation: Equal
          value: test
    ```

!!! Example "EventTrigger"

    ```yaml hl_lines="7-9 11-12 17-21"
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: deploy-app
    spec:
      sourceClusterSelector:
        matchLabels:
          cluster: mgmt
      destinationCluster:
        name: "{{ .Resource.metadata.name }}"
        namespace: "{{ .Resource.metadata.namespace }}"
        kind: SveltosCluster
        apiVersion: lib.projectsveltos.io/v1beta1
      eventSourceName: cluster-registration
      oneForEvent: true
      policyRefs:
      - kind: GitRepository
        name: test
        namespace: flux-system
        path: "{{ .Resource.metadata.name }}"
    ```

So, what happens with the `EventTrigger` manifest?

First, we match the Sveltos management cluster as the source cluster. Next, we dynamically define the destination cluster using information from the Sveltos management cluster. Finally, we specify the `Path` we want to deploy to the matching destination cluster, also in a dynamic way.

### What does this look like in practice?

Every time a new cluster is registered with Sveltos and has the label _env: test_, an event is triggered. Sveltos then dynamically deploys the relevant Kubernetes manifests and/or Helm charts to that cluster, using the Flux source defined in the initial step. The Path used is the **name** of the matching cluster.

This means the corresponding folder must exist within the specified Flux source. If it does not, Sveltos will not deploy anything to the cluster.