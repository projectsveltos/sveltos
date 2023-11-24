---
title: How to install
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

Sveltos is a set of Kubernetes controllers deployed in the management cluster. From the management cluster, Sveltos can manage add-ons and applications in multiple clusters.

## Installation

To install Sveltos, run the following commands:

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```
[^2]

In this mode, Sveltos will deploy up to two agents, *sveltos-agent* and *drift-detection-manager*[^1], in each managed clusters.
If you don't want to have any Sveltos agent in any managed cluster, run the following commands:

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/agents_in_mgmt_cluster_manifest.yaml
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```

In this mode, Sveltos agents will be created, per managed cluster, in the management cluster itself.

Sveltos uses the git-flow branching model. The base branch is dev. If you are looking for latest features, please use the dev branch. If you are looking for a stable version, please use the main branch or tags labeled as v0.x.x.

## Install using helm

```
helm repo add projectsveltos https://projectsveltos.github.io/helm-charts
helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace
```

Please note that Sveltos pods assume to be running in the *projectsveltos* namespace.

## Get Sveltos Status​

Get Sveltos status and verify all pods are up and running

```
projectsveltos access-manager-69d7fd69fc-7r4lw         2/2     Running   0  40s
projectsveltos addon-controller-df8965884-x7hp5        2/2     Running   0  40s
projectsveltos classifier-manager-6489f67447-52xd6     2/2     Running   0  40s
projectsveltos hc-manager-7b6d7c4968-x8f7b             2/2     Running   0  39s
projectsveltos sc-manager-cb6786669-9qzdw              2/2     Running   0  40s
projectsveltos event-manager-7b885dbd4c-tmn6m          2/2     Running   0  40s
```

[^1]: sveltos-agent will be deployed if there is at least one Classifier instance in the management cluster. Drift detection manager will be deployed if there is a ClusterProfile instance with SyncMode set to *ContinuousWithDriftDetection*.
[^2]: If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error: *error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*