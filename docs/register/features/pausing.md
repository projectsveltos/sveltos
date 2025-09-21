---
title: Pause Cluster
description: Learn how to temporarily halt all Sveltos updates to a cluster using the SveltosCluster.Spec.Paused field. This is useful for maintenance, troubleshooting, and gaining granular control over deployments. tags
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

To temporarily halt all updates and deployments to a specific cluster, use the __SveltosCluster.Spec.Paused__ field. When set to `true`, it instructs Sveltos to pause **all** operations for that cluster.

What does this mean? No new add-ons, applications, or configurations will be deployed, and any existing ones managed by Sveltos will not be updated, even if their corresponding ClusterProfile or Profile is changed.

This feature is particularly useful for:

- **Maintenance**: Pausing a cluster while you perform manual updates or troubleshoot issues.

- **Troubleshooting**: Temporarily stopping Sveltos from applying changes to a cluster that is experiencing problems.

- **Control**: Gaining fine-grained control over when a cluster receives updates, which is important in environments where changes must be carefully coordinated.

To resume operations, set the __SveltosCluster.Spec.Paused__ back to `false` or delete the field. Sveltos will resume its reconciliation loop and apply any pending changes.