---
title: Resource Deployment Order - Smooth Transitions with transitionFrom
description: Move a cluster from one ClusterProfile/Profile to another that deploys mostly the same resources, without undeploying and redeploying what they have in common.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
    - transition
authors:
    - Gianluca Mardente
---

## The Problem

A common pattern is moving a cluster from one `ClusterProfile` to another. This usually involves the same resources, just at a different version or configuration. For example, a cluster matches `sbom-scanner-v1` via the label `sbom: v1`. `sbom-scanner-v1` and `sbom-scanner-v2` deploy the same set of resources, just at different versions. The operator wants to move the cluster to `sbom-scanner-v2` by changing the cluster's label from `sbom: v1` to `sbom: v2`.

Changing the label to switch from `sbom-scanner-v1` to `sbom-scanner-v2` undeploys everything managed by `sbom-scanner-v1` first, then deploys `sbom-scanner-v2`, including any shared resources. This happens because `sbom-scanner-v1` and `sbom-scanner-v2` are reconciled by independent, unsynchronized loops, so there's no guaranteed order between them: `sbom-scanner-v1` can finish tearing down well before `sbom-scanner-v2` even starts deploying. A plain label swap always undeploys-then-redeploys, even when the two profiles are nearly identical.

## The Solution: _transitionFrom_

A `ClusterProfile`/`Profile` can declare, via `transitionFrom`, that it is replacing one or more other `ClusterProfile`/`Profile` instances. For any cluster where the new instance now matches and the named instance previously deployed:

- Teardown of the named instance's resources on that cluster is deferred until the new instance reaches `Provisioned`.
- The new instance may take over resources currently owned by the named instance, regardless of `tier`.

Once the new instance reaches `Provisioned`, the old instance's next reconcile finds nothing left to wait on and cleanly undeploys whatever's left, resources exclusive to it.

!!! note "transitionFrom always wins the resource conflict, regardless of tier"
    This is not "wins on a tie" or "wins only if `tier` is equal." A [tier](tiers.md) mismatch normally means the **lower** `tier` value wins the conflict. `transitionFrom` overrides that check entirely: the new instance takes over the named instance's resources even if the new instance's `tier` is numerically **higher** (lower priority) than the old one's, or unset (default `100`) on both sides. `tier` only decides conflicts between instances that have no declared `transitionFrom` relationship with each other; once one is declared, it settles that specific conflict on its own.

    This is deliberate, not an oversight: [teardown deferral](#deletion-order-and-status) above has no `tier` awareness at all, it defers purely on whether a named, matching successor exists and is `Provisioned`. If the resource takeover *could* be blocked by `tier`, a successor given a higher `tier` for unrelated reasons elsewhere in the fleet could never reach `Provisioned` for the shared resource, and the predecessor's teardown would then wait on it forever, a real deadlock, not a partial degradation. Keeping `transitionFrom` unconditional on `tier` is what avoids that.

Unlike the [tier-based](tiers.md) and [overlap-then-cutover](clusterprofile_ownership_transfer.md) methods, `transitionFrom` is simpler. It needs no overlap window, no second label, and no manual two-step rollout: just one label change does the job. This works for raw manifests (`policyRefs`), Kustomize output (`kustomizationRefs`), and Helm charts alike.

### Example

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: sbom-scanner-v1
    spec:
      clusterSelector:
        matchLabels:
          sbom: v1
      policyRefs:
      - kind: ConfigMap
        name: sbom-scanner-config
        namespace: default
    ```

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: sbom-scanner-v2
    spec:
      clusterSelector:
        matchLabels:
          sbom: v2
      transitionFrom:
      - sbom-scanner-v1
      policyRefs:
      - kind: ConfigMap
        name: sbom-scanner-config-v2
        namespace: default
    ```

With both `ClusterProfiles` created, changing a cluster's label from `sbom: v1` to `sbom: v2` in a single change is enough: `sbom-scanner-v1`'s resources stay in place until `sbom-scanner-v2` is `Provisioned` on that cluster, and any resource both profiles manage in common is updated in place rather than deleted and recreated.

## Restrictions

`transitionFrom` only works between resources of the same kind, the same restriction [`dependsOn`](depends_on.md) has: a `ClusterProfile` can only name other `ClusterProfiles` in its `transitionFrom` list, and a `Profile` can only name other `Profiles` in the same namespace.

If a `transitionFrom` entry names an instance of the wrong kind, or one that never actually matches the cluster in question, Sveltos treats it as a silent no-op: it doesn't block the predecessor's teardown, and it doesn't grant the named instance any takeover rights.

## Multiple Successors

More than one `ClusterProfile`/`Profile` can independently declare `transitionFrom` naming the same predecessor. This is useful when a single profile is divided into several smaller ones. When that happens, teardown of the predecessor waits until all currently-matching successors reach `Provisioned`, not just one, since each may be responsible for taking over a different subset of the shared resources.

## Deletion Order and Status

While a predecessor's teardown is deferred, its `Status.Dependencies` field reports which successor it's waiting on, the same status field [`dependsOn`](depends_on.md#deletion-order) uses to report a live dependent. A successor whose selector matches the cluster but never reaches `Provisioned` (a bad manifest, an unreachable cluster) blocks the predecessor's teardown indefinitely: there is currently no timeout or escape hatch, so `transitionFrom` should name a successor we expect to actually converge.

## Helm Charts

For Helm charts specifically, `transitionFrom` supersedes the [overlap-then-cutover technique](clusterprofile_ownership_transfer.md). That page's approach, matching both `ClusterProfiles` briefly and then cutting over, still works, but `transitionFrom` gets us the same in-place handover with a single label change and no timing window to get right. Unlike the overlap technique, `transitionFrom` also applies to raw manifests and Kustomize output, not just Helm releases.
