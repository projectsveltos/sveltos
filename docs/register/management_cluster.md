---
title: Managed add-ons and applications in the management cluster
description: Instruct Sveltos to manage add-ons and applications in the management cluster as well
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

## Register Management Cluster

Apart from having Sveltos to manage add-ons on managed clusters, you can have it on **management clusters** as well. By management cluster, we refer to the cluster where Sveltos is deployed.

### Option 1: sveltosctl Approach

To register the management cluster to Sveltos, the **sveltosctl** binary can be used. If the **sveltosctl** binary is not installed in your system, follow the instructions **[here](../install/sveltosctl.md)**.

**Please note:** The kubeconfig should point to the management cluster.

```
$ sveltosctl register mgmt-cluster
```

This will create a SveltosCluster in the namespace __mgmt__ representing the management cluster.

### Option 2: Standard Register Cluster Approach

If you want to register the management cluster as any other cluster with Sveltos, follow the instructions found [here](register-cluster.md).

Once the management cluster is registered, Sveltos can be used to deploy helm charts, kustomize files, and YAMLs to the management cluster as well. This makes it easier to manage add-ons and applications across multiple clusters, including the management cluster.
