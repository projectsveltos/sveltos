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
---

## What is Sveltos?

Sveltos is a set of Kubernetes controllers deployed in the management cluster. From the management cluster, it can manage add-ons and applications to multiple clusters.

!!! note
    `cert-manager` is required in the management cluster.

## Installation Modes

Sveltos supports two modes: **Mode 1** and **Mode 2**.

- **Mode 1:** Will deploy up to two agents, *sveltos-agent* and *drift-detection-manager*[^1], in each **managed cluster**.

- **Mode 2:** Sveltos agents will be created, per managed cluster, in the management cluster[^2]. The agents, while centrally located, will still monitor their designated managed cluster’s API server.

### Mode 1: Local Agent Mode

To install Sveltos in mode 1, run the commands below.

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```

### Mode 2: Centralised Agent Mode

If you do not want to have any Sveltos agent in any **managed cluster**, run the commands below.

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/agents_in_mgmt_cluster_manifest.yaml

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```

Sveltos uses the git-flow branching model. The base branch is dev. If you are looking for latest features, please use the dev branch. If you are looking for a stable version, please use the main branch or tags labeled as v0.x.x.

!!! warning
    Both deployments will perform the Sveltos installation in the `projectsveltos` namespace.

## Deployment Options

Sveltos can be installed as a Helm chart or with Kustomize. By default, **Mode 1** will get deployed unless otherwise specified.

!!! warning
    Ensure Sveltos is deployed in the `projectsveltos` namespace. This is a requirement.

### Helm Installation

```
$ helm repo add projectsveltos https://projectsveltos.github.io/helm-charts

$ helm repo update

$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace

$ helm list -n projectsveltos
```

### Kustomize Installation

#### Mode 1: Local Agent Mode

```
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/base\?timeout\=120\&ref\=main |kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```

#### Mode 2: Centralised Agent Mode

```
$ kustomize build https://github.com/projectsveltos/sveltos.git//kustomize/overlays/agentless-mode\?timeout\=120\&ref\=main |kubectl apply -f -

$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
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

## Next Steps

Contiunue with the **Sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).

[^1]: sveltos-agent will be deployed if there is at least one Classifier instance in the management cluster. Drift detection manager will be deployed if there is a ClusterProfile instance with SyncMode set to *ContinuousWithDriftDetection*.
[^2]: If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error: *error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*
