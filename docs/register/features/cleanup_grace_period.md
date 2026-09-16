---
title: Cleanup Grace Period
description: Learn how to use SveltosCluster.Spec.CleanupGracePeriod to delay removal of a deleted SveltosCluster, giving management-cluster automation a window to clean up before it disappears.
tags:
    - Kubernetes
    - add-ons
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

Deleting a `SveltosCluster` normally removes it right away: unlike a ClusterAPI
`Cluster`, there is no infrastructure provider holding a finalizer on it, so
nothing keeps the object around during teardown.

That is fine for the `SveltosCluster` object itself, but it also means
nothing else gets a chance to react while it still exists. In particular, the
[event-driven cleanup pattern](../../events/examples/cluster_deletion_cleanup.md)
that lets you run a `Job` in the management cluster while a cluster is
deleting depends on the cluster object still being there, with a
`deletionTimestamp`, long enough to be evaluated.

__SveltosCluster.Spec.CleanupGracePeriod__ closes that gap. When set,
Sveltos holds its own finalizer on the `SveltosCluster` for that long after
deletion is requested, before actually removing it:

```yaml hl_lines="6"
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: prod-cluster
  namespace: civo
spec:
  cleanupGracePeriod: 10m
```

With this set, deleting `prod-cluster` keeps the `SveltosCluster` present
(with `metadata.deletionTimestamp` set) for 10 minutes before Sveltos removes
it, instead of disappearing immediately.

!!!note
    This field is optional and nil by default. If it is not set, a
    `SveltosCluster` is removed immediately on deletion, exactly as before
    this field existed.

By itself, this only delays removal; it does not run any cleanup. Pair it
with an `EventSource`/`EventTrigger` using `includeDeletingResources: true`
against this `SveltosCluster` to actually act during that window. See
[Event Driven Cleanup on Cluster Deletion](../../events/examples/cluster_deletion_cleanup.md).
