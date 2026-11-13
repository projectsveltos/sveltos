---
title: Event Driven Cleanup on Cluster Deletion - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - clusterapi
    - Sveltos
    - event driven
    - cluster deletion
    - cleanup
authors:
    - Gianluca Mardente
---

## The Problem: Cloud Resources That Outlive the Cluster

Tools like Karpenter, CNI plugins, and cloud controller managers create cloud
resources (EC2 instances, load balancers, EBS/disk volumes, network
interfaces, security groups) on behalf of a Kubernetes cluster. Normally
those tools clean up after themselves when the cluster is deleted. But that
cleanup depends on the cluster's own API server still being reachable, and
on the infrastructure provider's control plane still answering requests.

By the time a `Cluster` is deleting, that is often no longer true. A common
failure mode with Cluster API on AWS (CAPA): Karpenter deprovisions nodes
through the EKS control plane, but CAPA deletes the control plane before
Karpenter gets a chance to remove the EC2 instances it manages. Those
instances, and the network interfaces attached to them, keep a reference to
the cluster's security group. CAPA cannot delete that security group while
the reference exists, and `Cluster` deletion stalls.

The fix has to run somewhere that survives the managed cluster going away:
the **management** cluster.

## Detecting a Cluster That Has Started Deleting

Sveltos normally excludes a resource from matching as soon as
`metadata.deletionTimestamp` is set, on the assumption that a resource being
removed is not something to act on. `ResourceSelector` (used by `EventSource`,
among others) has an opt-in field to disable that behavior:

```yaml
resourceSelectors:
- group: cluster.x-k8s.io
  version: v1beta2
  kind: Cluster
  includeDeletingResources: true
```

With `includeDeletingResources: true`, a `Cluster` that has started deleting
still matches. This works reliably for Cluster API clusters because the
infrastructure provider (CAPA, CAPZ, CAPG, etc.) holds its own finalizer on
the `Cluster` until its part of the teardown finishes. The object, and its
labels and annotations, stay around for as long as that takes. Nothing about
`includeDeletingResources` changes when the `Cluster` object is actually
removed; it only changes whether Sveltos still considers it a match while
it lingers with a `deletionTimestamp`.

!!!note
    This field is opt-in and defaults to `false`. Every other Sveltos feature
    that matches resources (Classifier, HealthCheck, etc.) keeps ignoring
    deleting resources unless you explicitly set this field.

### SveltosCluster: No Provider Finalizer to Rely On

The reliability above comes from something Sveltos does not control: the
infrastructure provider's own finalizer on a ClusterAPI `Cluster`. A cluster
registered directly as a `SveltosCluster`, with no ClusterAPI involved, has no
equivalent. Nothing holds that object open during deletion, so it can
disappear before `includeDeletingResources` gets a chance to evaluate it.

[`SveltosCluster.Spec.CleanupGracePeriod`](../../register/features/cleanup_grace_period.md)
closes that gap. When set, Sveltos holds its own finalizer on the
`SveltosCluster` for that long after deletion is requested:

```yaml hl_lines="6"
apiVersion: lib.projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: prod-cluster
  namespace: civo
spec:
  cleanupGracePeriod: 10m
```

With that in place, the same pattern documented below works for a bare
`SveltosCluster` exactly as it does for a ClusterAPI `Cluster`: target
`kind: SveltosCluster` (group `lib.projectsveltos.io`) in the `EventSource`'s
`resourceSelectors` instead of `kind: Cluster`, and the `Job` gets the same
guaranteed window.

## Running the Cleanup Job in the Management Cluster

Since Sveltos is deployed to the management cluster, it is automatically
registered there as a `SveltosCluster` named `mgmt` in the `mgmt` namespace
(see [Register Management Cluster](../../register/register-cluster.md#register-management-cluster)).
An `EventTrigger` can watch for the event in that same cluster and deploy
the cleanup `Job` back into it, using
[`destinationCluster`](./cross_cluster_configuration.md) to keep the target
explicit.

### EventSource: a Cluster That Started Deleting

!!! example "Example - EventSource Definition"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: deleting-eks-clusters
    spec:
      collectResources: true
      resourceSelectors:
      - group: cluster.x-k8s.io
        version: v1beta2
        kind: Cluster
        includeDeletingResources: true
        evaluateCEL:
        - name: eks_cluster_deleting
          rule: >
            has(resource.metadata.deletionTimestamp) &&
            resource.metadata.labels["provider-type"] == "aws" &&
            "eks-name" in resource.metadata.annotations
    ```

`collectResources: true` is required: the `EventTrigger` template below needs
the full `Cluster` object (its labels and annotations), not just its name and
namespace.

### EventTrigger: Deploy the Cleanup Job to the Management Cluster

!!! example "Example - EventTrigger Definition"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: eks-teardown-cleanup
    spec:
      sourceClusterSelector:
        matchLabels:
          sveltos.projectsveltos.io/cluster-name: mgmt
      destinationCluster:
        kind: SveltosCluster
        apiVersion: lib.projectsveltos.io/v1beta1
        name: mgmt
        namespace: mgmt
      eventSourceName: deleting-eks-clusters
      oneForEvent: true
      policyRefs:
      - name: eks-cleanup-job
        namespace: default
        kind: ConfigMap
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: eks-cleanup-job
      namespace: default
      annotations:
        projectsveltos.io/template: ok
    data:
      job.yaml: |
        apiVersion: batch/v1
        kind: Job
        metadata:
          name: eks-cleanup-{{ .Resource.metadata.name }}
          namespace: default
        spec:
          backoffLimit: 6
          template:
            spec:
              restartPolicy: OnFailure
              containers:
              - name: cleanup
                image: my-registry/eks-cleanup:latest
                env:
                - name: EKS_NAME
                  value: '{{ index .Resource.metadata.annotations "eks-name" }}'
                - name: REGION
                  value: '{{ index .Resource.metadata.annotations "region" }}'
    ```

| Setting                  | Explanation |
|---------------------------|-------------|
| `sourceClusterSelector`   | Matches the management cluster (`mgmt/mgmt`), so the `EventSource` above is evaluated there and not in a managed cluster. |
| `destinationCluster`      | Points at the `mgmt` cluster, so the Job lands in the **management** cluster, not in the workload cluster being deleted. |
| `oneForEvent: true`       | Gives every deleting cluster its own `ClusterProfile`, so one cluster's cleanup does not depend on, or interfere with, another's. |

`{{ .Resource.metadata.name }}`, and any label or annotation on the deleting
`Cluster`, are available to the template exactly as they would be for a live
resource. Templating reads the object with a direct lookup, not through the
(deletion-excluding) matching path.

## What This Gives You

1. **A live signal, while the resource still exists.** The `Job` is created
   as soon as `deletionTimestamp` is set, not after the `Cluster` is gone,
   by which point nothing could target it anymore.
2. **The `Job` runs in the management cluster**, so it does not depend on
   the workload cluster's API server, which may already be unreachable.
3. **No Sveltos-held finalizer, no blocking.** Sveltos does not hold up
   `Cluster` deletion itself; whatever already keeps the `Cluster` object
   present during teardown (the infrastructure provider's own finalizer, for
   a Cluster API cluster) gives the `Job` the time it needs. A `Job` that
   polls its cloud provider until a control plane is confirmed gone, before
   acting, works the same way it would run anywhere else.
4. **Automatic cleanup once the cluster is actually gone.** When the
   `Cluster` object is finally removed, it stops matching the `EventSource`,
   and Sveltos removes the `ClusterProfile` (and the `Job` it deployed) that
   was created for it, the same way it does for any other event-driven
   `ClusterProfile` that stops matching.
5. **Failure is visible, not silent.** Deployment status for the `Job` is
   tracked the same way as any other Sveltos-deployed resource, on the
   generated `ClusterProfile`'s `ClusterSummary`.

!!! warning
    `includeDeletingResources` only helps while the resource object still
    exists. It does not, by itself, keep an object around longer than it
    otherwise would be. For a Cluster API cluster this is not a problem, since
    the infrastructure provider already holds the object open for the
    duration of its own teardown. For a `SveltosCluster`, set
    [`Spec.CleanupGracePeriod`](../../register/features/cleanup_grace_period.md)
    to get the same guarantee. Any other resource with nothing else blocking
    its deletion can still disappear before Sveltos evaluates it.
