---
title: Register Cluster
description: Sveltos comes with support to automatically discover ClusterAPI powered clusters. Any other cluster (GKE for instance) can easily be registered with Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters. If Sveltos is deployed in a management cluster with ClusterAPI (CAPI), no further action is required for Sveltos to manage add-ons on CAPI-powered clusters. 
Sveltos will watch for *clusters.cluster.x-k8s.io"* instances and program those accordingly.