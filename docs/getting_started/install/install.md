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

!!!tip
    Once Sveltos is deployed to the **management** cluster, it is automatically registered in the `mgmt` namespace with the name `mgmt`. Add-ons and applications can be deployed as soon as the appropriate Kubernetes labels are added to the cluster. For more details, see the [registration section](../../register/register-cluster.md/#register-management-cluster).

### Mode 1: Local Agent Mode (Manifest)

Execute the below commands.

```sh
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v1.4.0/manifest/manifest.yaml
```

### Mode 2: Centralized Agent Mode (Manifest)

If you do not want to have any Sveltos agent in any **managed cluster**, run the commands below.

```sh
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/v1.4.0/manifest/agents_in_mgmt_cluster_manifest.yaml
```

!!! warning
    Sveltos is deployed in the `projectsveltos` namespace.

## Deployment Options

Sveltos can be installed as a `Helm Chart` or with `Kustomize`. By default, **Mode 1** will get deployed unless otherwise specified.

!!! warning
    Ensure Sveltos is deployed in the `projectsveltos` namespace.

### Helm Installation

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

#### Mode 2: Centralized Agent Mode

```sh
$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace --set agent.managementCluster=true

$ helm list -n projectsveltos
```

### Kustomize Installation

#### Mode 1: Local Agent Mode

```sh
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/base\?timeout\=120\&ref\=v1.4.0 |kubectl apply -f -
```

#### Mode 2: Centralized Agent Mode

```sh
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/overlays/agentless-mode\?timeout\=120\&ref\=v1.4.0 |kubectl apply -f -
```

## Sveltos Verification

Get the Sveltos status and verify that all pods are **Up** and **Running**.

```
$ kubectl get pods -n projectsveltos
NAME                                      READY   STATUS    RESTARTS   AGE
access-manager-d968dc949-gsznw            1/1     Running   0          3m22s
addon-controller-ddb67b8b-stkxd           1/1     Running   0          3m22s
classifier-manager-666fbf775f-2w9ct       1/1     Running   0          3m22s
event-manager-84688bcf8b-x88sq            1/1     Running   0          3m22s
hc-manager-694984b5c-j6kf8                1/1     Running   0          3m22s
mcp-server-6d578c594d-lgl6z               1/1     Running   0          3m22s
sc-manager-5bfff7fdc8-fd94g               1/1     Running   0          3m22s
shard-controller-d858df478-9qcr2          1/1     Running   0          3m22s
sveltos-agent-manager-7f4dbc8955-k56g6    1/1     Running   0          2m19s
techsupport-controller-584c96df59-dcdhh   1/1     Running   0          3m22s
```

!!!note "Upgrade Information"
    - **Sveltos v1.1.1 and later**
        - **Manifest:** Simply apply the latest manifest available. The YAML directly updates CRDs and all components.
        - **Helm Chart:** The Sveltos Helm chart automatically updates CRDs before other components using a built-in Job.
    - **Sveltos v1.1.0 and earlier**
        - **Helm Chart:** Follow the standard [Helm chart upgrade process](https://helm.sh/docs/helm/helm_upgrade/).
        - **Sveltos Helm Chart and CRDs Helm Chart:** If Sveltos was initially deployed using separate Helm charts for Sveltos and its CRDs, this approach must be maintained for all upgrades. Switching to the combined chart installation or upgrade is **not supported**. The Sveltos CRDs Helm chart should be upgraded first, followed by the main Sveltos chart.

## Optional Components

### Sveltos Dashboard

To include the Sveltos Dashboard, follow the instructions found in the [dashboard](../optional/dashboard.md) section.

<iframe width="560" height="315" src="https://www.youtube.com/embed/FjFtvrG8LWQ?si=mS8Yt2pleGsl33fK" title="Sveltos Dashboard" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### Grafana Dashboard
Sveltos also offers a Grafana dashboard to help users track and visualize a number of operational metrics. More can be found in the [Sveltos Grafana Dashboard](../optional/grafanadashboard.md) section.

## Next Steps

Continue with the **sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).

[^1]: sveltos-agent will be deployed if there is at least one Classifier instance in the management cluster. Drift detection manager will be deployed if there is a ClusterProfile instance with SyncMode set to *ContinuousWithDriftDetection*.
[^2]: If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error: *error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/v1.4.0/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*
[^3]: Sveltos collects **minimal**, **anonymised** data. That includes the `version information` alognside `cluster management data` (number of managed SveltosClusters, CAPI clusters, number of ClusterProdiles/Profiles and ClusterSummaries). To **opt-out**, for Helm-based installations use ```helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace --set telemetry.disabled=true``` and for manual deployment use the ```--disable-telemetry=true``` flag in the Sveltos `addon-controller` configuration.
