---
title: Sveltos Custom Resource Definitions
description: Reference of the Sveltos CRDs, what each one defines, and which controller reconciles it.
tags:
    - Kubernetes
    - Architecture
    - CRDs
authors:
    - Eleni Grosdouli
---

# Sveltos Custom Resource Definitions (CRDs)

Sveltos exposes its functionality through a set of Kubernetes [CRDs](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). Users create and manage these resources through the **management cluster** API, and a dedicated controller reconciles each of them. The table below maps every CRD to what it defines and the controller responsible for it.

## CRD Reference

| CRD | What it defines | Reconciled by |
|---|---|---|
| **ClusterProfile / Profile** | What needs to be deployed on which sets of clusters. | addon-controller |
| **ClusterPromotion** | *How* and *when* the deployments safely roll out across different environments. | addon-controller |
| **Classifier** | Classify a managed cluster based on its live state. | classifier-manager |
| **ManagementClusterClassifier** | Classify a managed cluster based on resources in the control cluster. | classifier-manager |
| **EventSource** | Defines what an event is. | event-manager |
| **EventTrigger** | When the event happens, it triggers Sveltos to deploy resources. | event-manager |
| **HealthCheck** | Defines the criteria for what healthy looks like for resources. | healthcheck-manager |
| **ClusterHealthCheck** | Send notifications based on the health of Kubernetes resources. | healthcheck-manager |
| **Techsupport** | Defines which resources/logs to collect and where to send them. | techsupport |
| **RoleRequest** | Define tenant permissions. | access-manager |

## Grouping by Controller

The CRDs group naturally around the controller that owns them.

- **addon-controller**: `ClusterProfile` / `Profile`, `ClusterPromotion`. The deployment and rollout layer. What is deployed, where, and how it is promoted across environments.
- **classifier-manager**: `Classifier`, `ManagementClusterClassifier`. Cluster classification based on either the managed cluster's live state or resources in the control cluster.
- **event-manager**: `EventSource`, `EventTrigger`. The event-driven layer defines events and the actions taken when they fire.
- **healthcheck-manager**: `HealthCheck`, `ClusterHealthCheck`. Health criteria for resources and notifications based on cluster health.
- **techsupport**: `Techsupport`. Collection of logs and resources for support bundles.
- **access-manager**: `RoleRequest`. Tenant permissions for multi-tenancy.