---
title: Register Cluster - Claudie Cluster
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

# Per-Cluster Maintenance Windows

Sveltos offers precise control over updates with per-cluster maintenance windows. This means updates are deployed only during these designated periods, minimizing disruption to your workloads.

For instance, you can configure `cluster1` to receive updates every Friday from 8 PM to Monday 7 AM:

```yaml hl_lines="7-9"
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: cluster1
  namespace: civo
spec:
  activeWindow:
    from: 0 20 * * 5  # Friday 8PM (0 hour, 20th minute, any day of month, any month, Friday)
    to: 0 7 * * 1    # Monday 7AM (0 hour, 7th minute, any day of month, any month, Monday)
```