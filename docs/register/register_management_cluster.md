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

When Sveltos is deployed, it automatically registers the management cluster.

```bash
$  kubectl get sveltoscluster -A --show-labels
NAMESPACE   NAME   READY   VERSION   LABELS
mgmt        mgmt   true    v1.29.1   <none>
```

If you want to add labels:

```bash
$ kubectl label sveltoscluster -n mgmt mgmt cluster=mgmt
```