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

- **Mode 2:** Sveltos agents will be created, per managed cluster, in the management cluster[^2]. The agents, while centrally located, will still monitor their designated managed cluster’s API server. Sveltos leaves no footprint on managed clusters in this mode.

### Mode 1: Local Agent Mode (Manifest)

Execute the below commands.

```sh
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/manifest.yaml

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/default-instances.yaml
```

### Mode 2: Centralised Agent Mode (Manifest)

If you do not want to have any Sveltos agent in any **managed cluster**, run the commands below.

```sh
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/agents_in_mgmt_cluster_manifest.yaml

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/default-instances.yaml
```

!!! warning
    Both deployment methods install Sveltos in the `projectsveltos` namespace.

## Deployment Options

Sveltos can be installed as a `Helm Chart` or with `Kustomize`. By default, **Mode 1** will get deployed unless otherwise specified.

!!! warning
    Ensure Sveltos is deployed in the `projectsveltos` namespace.

### Helm Installation

??? note "Helm Chart Upgrade Notes"
    When deploying Sveltos with Helm, the `helm upgrade` command will not automatically update Sveltos's Custom Resource Definitions (CRDs) if they have changed in the new chart version. This is a standard Helm behavior to prevent accidental changes to CRDs that might disrupt existing resources. Manually update of the CRDs before upgrading Sveltos is required.
    ```sh
    $ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/crds/sveltos_crds.yaml
    ```
    Sveltos offers a dedicated Helm chart for managing its CRDs, which is the recommended and most reliable approach.
    ```sh
    $ helm install projectsveltos/sveltos-crds projectsveltos/sveltos-crds
    ```
#### Retrieve Latest Helm Chart

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
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/base\?timeout\=120\&ref\=v0.57.2 |kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/default-instances.yaml
```

#### Mode 2: Centralised Agent Mode

```sh
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/overlays/agentless-mode\?timeout\=120\&ref\=v0.57.2 |kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/default-instances.yaml
```

## Sveltos Verification

Get the Sveltos status and verify that all pods are **Up** and **Running**.

```
projectsveltos access-manager-69d7fd69fc-7r4lw         2/2     Running   0  40s
projectsveltos addon-controller-df8965884-x7hp5        2/2     Running   0  40s
projectsveltos classifier-manager-6489f67447-52xd6     2/2     Running   0  40s
projectsveltos hc-manager-7b6d7c4968-x8f7b             2/2     Running   0  39s
projectsveltos sc-manager-cb6786669-9qzdw              2/2     Running   0  40s
projectsveltos event-manager-7b885dbd4c-tmn6m          2/2     Running   0  40s
```

## Optional Components

### Sveltos Dashboard

To include the Sveltos Dashboard, follow the instructions found in the [dashboard](../optional/dashboard.md) section.

<iframe width="560" height="315" src="https://www.youtube.com/embed/FjFtvrG8LWQ?si=mS8Yt2pleGsl33fK" title="Sveltos Dashboard" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### Grafana Dashboard
Sveltos also offers a Grafana dashboard to help users track and visualize a number of operational metrics. More can be found in the [Sveltos Grafana Dashboard](../optional/grafanadashboard.md) section.

## Next Steps

Continue with the **sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).

[^1]: sveltos-agent will be deployed if there is at least one Classifier instance in the management cluster. Drift detection manager will be deployed if there is a ClusterProfile instance with SyncMode set to *ContinuousWithDriftDetection*.
[^2]: If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error: *error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/v0.57.2/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*
[^3]: Sveltos collects **minimal**, **anonymised** data. That includes the `version information` alognside `cluster management data` (number of managed SveltosClusters, CAPI clusters, number of ClusterProdiles/Profiles and ClusterSummaries). To **opt-out**, for Helm-based installations use ```helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace --set telemetry.disabled=true``` and for manual deployment use the ```--disable-telemetry=true``` flag in the Sveltos `addon-controller` configuration.