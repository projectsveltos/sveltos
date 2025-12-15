---
title: Force Redeployment of Cluster Add-ons
description: Use sveltosctl to manually trigger a full re-application and reconciliation of all add-ons and resources on a target cluster.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - helm
    - reconciliation
    - cluster management
authors:
    - Gianluca Mardente
---

# Cluster Operations

This section details advanced cluster management commands available via the `sveltosctl` CLI tool.

## Force Redeploy Cluster Add-ons

The `sveltosctl redeploy cluster` command provides a manual mechanism to force Sveltos to re-apply all configured add-ons and resources on a specified target cluster. This is achieved by resetting the cluster's internal reconciliation status, compelling the Addon Controller to immediately re-process all associated `ClusterProfile` or `Profile` configurations.

This command is invaluable when you need to trigger a rolling update or configuration re-application without making dummy changes to the `ClusterProfile`/`Profile` specification.

### 📝 Command Usage

```bash
sveltosctl redeploy cluster \
    --namespace=<CLUSTER_NAMESPACE> \
    --cluster=<CLUSTER_NAME> \
    --cluster-type=<TYPE> \
    [--verbose]
```
