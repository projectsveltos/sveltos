---
title: How to install Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
    - Robin Afflerbach
---

## What is Sveltos?

Sveltos is a set of Kubernetes controllers deployed in the management cluster. From the management cluster, it can manage add-ons and applications to multiple clusters.

## Installation Modes

Sveltos supports two modes: **Mode 1** and **Mode 2**.

- **Mode 1:** Will deploy up to two agents, *sveltos-agent* and *drift-detection-manager*[^1], in each **managed cluster**.

- **Mode 2:** Sveltos agents will be created, per managed cluster, in the management cluster[^2]. The agents, while centrally located, will still monitor their designated managed cluster’s API server.

### Mode 1: Local Agent Mode

To install Sveltos in mode 1, run the commands below.

```sh
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-instances.yaml
```

### Mode 2: Centralised Agent Mode

If you do not want to have any Sveltos agent in any **managed cluster**, run the commands below.

```sh
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/agents_in_mgmt_cluster_manifest.yaml

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-instances.yaml
```

Sveltos uses the git-flow branching model. The base branch is dev. If you are looking for latest features, please use the dev branch. If you are looking for a stable version, please use the main branch or tags labeled as v0.x.x.

!!! warning
    Both deployments will perform the Sveltos installation in the `projectsveltos` namespace.

!!! tip 
    For production environments, using a release tag instead of the 'main' branch is recommended to ensure a smooth upgrade process for Sveltos applications.

## Deployment Options

Sveltos can be installed as a Helm chart or with Kustomize. By default, **Mode 1** will get deployed unless otherwise specified.

!!! warning
    Ensure Sveltos is deployed in the `projectsveltos` namespace. This is a requirement.

### Helm Installation

!!! note
    When deploying Sveltos with Helm, the `helm upgrade` command won't automatically update Sveltos's Custom Resource Definitions (CRDs) if they have changed in the new chart version. This is a standard Helm behavior to prevent accidental changes to CRDs that might disrupt existing resources.  Therefore, you must manually update the CRDs before upgrading Sveltos itself.
    ```sh
    kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/crds/sveltos_crds.yaml
    ```
    Sveltos offers a dedicated Helm chart for managing its CRDs, which is the recommended and most reliable approach.
    ```sh
    helm install projectsveltos/sveltos-crds  projectsveltos/sveltos-crds
    ``` 
```sh
$ helm repo add projectsveltos https://projectsveltos.github.io/helm-charts

$ helm repo update
```

#### Mode 1: Local Agent Mode

```sh
$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace

$ helm list -n projectsveltos
```

#### Mode 2: Centralised Agent Mode

```sh
$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace --set agent.managementCluster=true

$ helm list -n projectsveltos
```

### Kustomize Installation

#### Mode 1: Local Agent Mode

```sh
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/base\?timeout\=120\&ref\=main |kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-instances.yaml
```

#### Mode 2: Centralised Agent Mode

```sh
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/overlays/agentless-mode\?timeout\=120\&ref\=main |kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-instances.yaml
```

## Sveltos Verification

Get the Sveltos status and verify that all pods are Up and Running.

```
projectsveltos access-manager-69d7fd69fc-7r4lw         2/2     Running   0  40s
projectsveltos addon-controller-df8965884-x7hp5        2/2     Running   0  40s
projectsveltos classifier-manager-6489f67447-52xd6     2/2     Running   0  40s
projectsveltos hc-manager-7b6d7c4968-x8f7b             2/2     Running   0  39s
projectsveltos sc-manager-cb6786669-9qzdw              2/2     Running   0  40s
projectsveltos event-manager-7b885dbd4c-tmn6m          2/2     Running   0  40s
```

## Sveltos Dashboard

The Sveltos Dashboard is an optional component of Sveltos. To include it in the deployment, follow the instructions found in the [dashboard](./dashboard.md) section.

!!! note
    **_v0.38.4_** is the first Sveltos release that includes the dashboard and it is compatible with Kubernetes **_v1.28.0_** and higher.

## Grafana Dashboard
Sveltos also offers a Grafana dashboard to help users track and visualize a number of operational metrics. Instructions on setting up the Grafana dashboard can be found in the [sveltos-grafana dashboard](./grafanadashboard.md) section.

![dashboard](../../assets/dashboard.png)

## v1alpha1 CRDs

For the last couple of months, Sveltos CRDs have been using the **v1beta1** version. If the **v1alpha1** version is used, please upgrade to the latest release! The release pages can be found [here](https://github.com/projectsveltos/libsveltos/releases).

## Next Steps

Continue with the **Sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).

[^1]: sveltos-agent will be deployed if there is at least one Classifier instance in the management cluster. Drift detection manager will be deployed if there is a ClusterProfile instance with SyncMode set to *ContinuousWithDriftDetection*.
[^2]: If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error: *error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*