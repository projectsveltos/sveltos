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

It is possible to have Sveltos manage add-ons and applications in both the management cluster (cluster where Sveltos is deployed) and any managed cluster. This can be done by registering the management cluster with Sveltos. 

With kubeconfig pointing to the management cluster, using sveltosctl binary simply run:

```
sveltosctl register mgmt-cluster
```

This will create a SveltosCluster in the namespace __mgmt__ representing the management cluster.
Alternative you can [register](register-cluster.md) the management cluster as you would register any other cluster with Sveltos.

Once the management cluster is registered, Sveltos can be used to deploy helm charts, kustomize files, and YAMLs to the management cluster as well. This makes it easier to manage add-ons and applications across multiple clusters, including the management cluster.
