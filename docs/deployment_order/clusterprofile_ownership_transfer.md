---
title: Zero-Downtime Helm Chart Upgrades - Transferring Ownership Between ClusterProfiles
description: How to move a managed cluster from one ClusterProfile to another (for example to roll out a new CNI Helm chart version) without Sveltos uninstalling and reinstalling the release.
tags:
    - Kubernetes
    - add-ons
    - ClusterProfile
    - upgrades
    - helm
authors:
    - Gianluca Mardente
---

## The Problem

Some Helm releases, a CNI, an ingress controller, a service mesh, should never be fully removed and reinstalled just to move to a new version. A brief network outage while the CNI is uninstalled and reinstalled is often unacceptable.

Teams frequently keep `ClusterProfile` resources immutable in Git and roll out changes by creating a *new* `ClusterProfile` rather than editing the existing one. This is done deliberately: editing an existing `ClusterProfile` in place immediately rolls the change out to every cluster matching its `clusterSelector`. Sveltos does offer its own controls for that (see [Add-on Rollout Strategy](rolling_update_strategy.md) and [Progressive Rollout Across Clusters](progressive_rollout.md), which stage a change across the clusters already matching a single `ClusterProfile`), but many teams additionally want the coarser, explicit control of deciding cluster by cluster whether it should pick up a new `ClusterProfile` at all, which is why they create a new `ClusterProfile` with its own selector rather than editing the existing one in place.

That pattern raises a question. If cluster `X` currently matches `ClusterProfile` **A** (which deploys a CNI Helm chart), and you want to move it to `ClusterProfile` **B** (which deploys a newer version of the same chart), what actually happens on the cluster when you make `X` stop matching **A** and start matching **B**?

If you simply relabel the cluster so it stops matching **A** at the same time it starts matching **B**, Sveltos's default `stopMatchingBehavior` (`WithdrawPolicies`) removes everything **A** deployed, including uninstalling the Helm release for the CNI, before **B** installs it again. That uninstall/reinstall cycle is the outage you're trying to avoid.

## The Solution: Overlap, Don't Swap

For Helm charts, Sveltos tracks, per release, which `ClusterSummary` currently owns it. When a `ClusterSummary` is being torn down (because its cluster stopped matching the parent `ClusterProfile`/`Profile`), Sveltos checks whether another `ClusterSummary` on the same cluster already wants to manage that same Helm release. If one exists, ownership of the release is **handed over** to that other `ClusterSummary` in place: the release is *upgraded*, not uninstalled and reinstalled.

This means the outage isn't caused by the ownership model itself. It's caused by removing the old match and adding the new match in the same step, before the new `ClusterSummary` has had a chance to exist. The fix is to make the cluster match **both** `ClusterProfiles` for a brief overlap window, and only *then* remove it from the old one:

1. The cluster starts matching the new `ClusterProfile` **while still matching the old one**. This creates a second `ClusterSummary` for the same Helm release. Sveltos detects the conflict, and the new `ClusterSummary` reports `FailedNonRetriable`, but it does nothing destructive. The chart already deployed by the old `ClusterProfile` is left untouched.
2. Only after that second `ClusterSummary` exists do you make the cluster stop matching the old `ClusterProfile`. Sveltos tears down the old `ClusterSummary`, sees the new one is waiting to take over the same release, and hands over ownership in place. If the new `ClusterProfile` deploys a different chart version, Sveltos performs a Helm **upgrade** to that version, not an uninstall followed by an install.

If, instead, you removed the old match and added the new match at the same time (or removed the old one first), there is no overlap window: the old `ClusterSummary` is torn down with nothing yet waiting to take over, so `WithdrawPolicies` uninstalls the release before the new `ClusterSummary` is even created.

## Example: Rolling Out a New CNI Chart Version to a Subset of Clusters

Two `ClusterProfiles` are created up front, both immutable once committed. The first is already rolled out to every cluster; the second targets only the clusters you're ready to migrate.

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: cni-v1
spec:
  clusterSelector:
    matchLabels:
      cni-version: v1
  helmCharts:
  - repositoryURL:    <cni-repo-url>
    repositoryName:   cni
    chartName:        cni/cni-chart
    chartVersion:     1.18.12
    releaseName:      cni
    releaseNamespace: kube-system
    helmChartAction:  Install
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: cni-v2
spec:
  clusterSelector:
    matchLabels:
      cni-migrate-v2: "true"
  helmCharts:
  - repositoryURL:    <cni-repo-url>
    repositoryName:   cni
    chartName:        cni/cni-chart
    chartVersion:     1.19.6
    releaseName:      cni
    releaseNamespace: kube-system
    helmChartAction:  Install
```

Note that `cni-v2` uses a distinct selector label (`cni-migrate-v2`) rather than a value change on the same label. This keeps the two `ClusterProfiles` from ever racing to claim a cluster based on the same key, and makes the migration state of any given cluster visible directly from its labels.

Migrate a cluster by moving its labels through three states:

| Step | Cluster labels | Matches | Result |
|------|-----------------|---------|--------|
| 0, start | `cni-version: v1` | `cni-v1` only | `cni-v1` owns the `ClusterSummary`. CNI 1.18.12 is deployed. |
| 1, onboard | `cni-version: v1`, `cni-migrate-v2: "true"` | `cni-v1` **and** `cni-v2` | A second `ClusterSummary` (owned by `cni-v2`) is created and reports a conflict. Nothing changes on the cluster yet. The CNI keeps running as deployed by `cni-v1`. |
| 2, cut over | `cni-migrate-v2: "true"` (drop `cni-version: v1`) | `cni-v2` only | `cni-v1`'s `ClusterSummary` is torn down. Ownership of the Helm release transfers to `cni-v2`'s `ClusterSummary` in place. Sveltos performs a Helm **upgrade** from 1.18.12 to 1.19.6. There is no uninstall/reinstall step. |

Step 1 is the important one: apply the `cni-migrate-v2: "true"` label to a cluster *without removing* `cni-version: v1`, verify the second `ClusterSummary` exists (`kubectl get clustersummary -A`) and reports the conflict as expected, and only then remove `cni-version: v1` in a follow-up change. Doing both label changes in the same commit collapses the overlap window to zero and reintroduces the outage.

## Verifying the Handover

```bash
# Step 1: confirm both ClusterSummaries exist for the migrating cluster
kubectl get clustersummary -A -o wide

# Step 2, after cutover: confirm only the v2 ClusterSummary remains,
# and that the Helm release was upgraded rather than reinstalled
kubectl get clustersummary -A -o wide
helm history <release-name> -n <release-namespace> --kube-context <managed-cluster>
```

A successful in-place transfer shows a single Helm release revision incrementing (an `upgrade` in `helm history`), never a `REVISION 1` with a new install timestamp following an uninstall.

## Alternative: Resolving the Conflict with Tiers Instead

The overlap-then-cutover choreography above isn't the only way to hand off a Helm release between two `ClusterProfiles`. [Tiers](tiers.md) resolve the same "two `ClusterProfiles` target the same resource on the same cluster" conflict using priority instead of a timed cutover: give the new `ClusterProfile` a lower `tier` value, and it always wins over the old one for that release, for as long as both keep matching the cluster. For raw manifests (`policyRefs`) and Kustomize output (`kustomizationRefs`), tiers are not just an alternative, they're the only option, since the in-place handover described above is Helm-specific.

Tiers are the simpler option when you're fine with the cluster matching both `ClusterProfiles` indefinitely. There's no ordering to get right, since the resolution happens by priority on every reconciliation rather than by which `ClusterSummary` was there first. The tradeoff: the old `ClusterProfile` is still silently in the loop. If the new one ever stops matching the cluster (a bad label change, a selector typo), Sveltos falls back to the old `ClusterProfile` and reverts the release to whatever it manages, which may not be what you want for something like a CNI version.

Use the overlap-then-cutover approach in this page when you want a clean, permanent handoff with the old `ClusterProfile` fully out of the picture afterward. That's the common case when `ClusterProfiles` are treated as immutable and a new one is created per upgrade. Use tiers when a lightweight, permanent override is enough and you don't need to fully retire the old match.

## Caveats

- **This page covers Helm charts (`spec.helmCharts`) only.** The in-place handover described here relies on Sveltos tracking Helm release ownership per `releaseName`/`releaseNamespace`. There is no equivalent mechanism for raw Kubernetes manifests deployed via `policyRefs` or Kustomize output deployed via `kustomizationRefs`: moving one of those between `ClusterProfiles` follows the default `stopMatchingBehavior` and is removed by the old `ClusterSummary` before the new one applies it, regardless of any overlap window. For those resource types, use [Tiers](tiers.md) instead: tiers resolve ownership by priority rather than by handover, and apply to raw manifests and Kustomize output as well as Helm charts.
- This only works if the *same* Helm release (same `releaseName` and `releaseNamespace`) is targeted by both `ClusterProfiles`. If the new `ClusterProfile` renames the release or moves it to a different namespace, Sveltos has no way to know it's the "same" release, and the old one is removed independently of the new one being installed.
- The overlap window only needs to be long enough for the second `ClusterSummary` to be created and reconciled at least once, seconds, not minutes, but the two label changes must land as separate reconciliations, not a single atomic update.
- This pattern applies to any Helm based add-on managed by `ClusterProfile`/`Profile`, not just CNIs. It is the general mechanism Sveltos uses whenever ownership of a Helm release moves from one `ClusterSummary` to another. See [Custom Resource Ownership](../internals/cr-ownership.md) for the underlying `ClusterProfile`/`Profile` → `ClusterSummary` ownership model.
