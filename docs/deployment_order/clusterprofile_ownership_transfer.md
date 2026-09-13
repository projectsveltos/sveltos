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

That pattern raises a question. If cluster `X` currently matches `ClusterProfile` **A** (which deploys a CNI Helm chart), and we want to move it to `ClusterProfile` **B** (which deploys a newer version of the same chart), what actually happens on the cluster when we make `X` stop matching **A** and start matching **B**?

If we relabel the cluster to stop matching **A** and start matching **B** at the same time, Sveltos's default `stopMatchingBehavior` (`WithdrawPolicies`) removes everything **A** deployed. That includes uninstalling the Helm release for the CNI, before **B** installs it again. That uninstall/reinstall cycle is the outage we're trying to avoid.

!!! note
    The overlap-then-cutover technique on this page still works. But for a simpler version bump, [`transitionFrom`](transition_from.md) gives us the same in-place handover with just one label change: no overlap window to time, no second label to introduce. It also covers raw manifests and Kustomize output, not just Helm charts.

    Want the overlap-based approach anyway, for example because we want the old `ClusterProfile` to keep acting as a live fallback? Keep reading. Otherwise, see [`transitionFrom`](transition_from.md) for the simpler option.

## The Solution: Overlap, Don't Swap

For Helm charts, Sveltos tracks, per release, which `ClusterSummary` currently owns it. When a `ClusterSummary` is being torn down (because its cluster stopped matching the parent `ClusterProfile`/`Profile`), Sveltos checks whether another `ClusterSummary` on the same cluster already wants to manage that same Helm release. If one exists, ownership of the release is **handed over** to that other `ClusterSummary` in place: the release is *upgraded*, not uninstalled and reinstalled.

This means the outage isn't caused by the ownership model itself. It's caused by removing the old match and adding the new match in the same step, before the new `ClusterSummary` has had a chance to exist. The fix is to make the cluster match **both** `ClusterProfiles` for a brief overlap window, and only *then* remove it from the old one:

1. The cluster starts matching the new `ClusterProfile` **while still matching the old one**. This creates a second `ClusterSummary` for the same Helm release. Sveltos detects the conflict, and the new `ClusterSummary` reports `FailedNonRetriable`, but it does nothing destructive. The chart already deployed by the old `ClusterProfile` is left untouched.
2. Only after that second `ClusterSummary` exists do we make the cluster stop matching the old `ClusterProfile`. Sveltos tears down the old `ClusterSummary`, sees the new one is waiting to take over the same release, and hands over ownership in place. If the new `ClusterProfile` deploys a different chart version, Sveltos performs a Helm **upgrade** to that version, not an uninstall followed by an install.

If, instead, we removed the old match and added the new match at the same time (or removed the old one first), there is no overlap window: the old `ClusterSummary` is torn down with nothing yet waiting to take over, so `WithdrawPolicies` uninstalls the release before the new `ClusterSummary` is even created.

## Example: Rolling Out a New CNI Chart Version to a Subset of Clusters

Two `ClusterProfiles` are created up front, both immutable once committed. The first is already rolled out to every cluster; the second targets only the clusters we're ready to migrate.

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

## Alternatives

The overlap-then-cutover technique above isn't the only way to hand off a Helm release between two `ClusterProfiles`. Two alternatives resolve the same conflict without an overlap window:

| Option | How it resolves the conflict | Best used when |
|---|---|---|
| [`transitionFrom`](transition_from.md) | Name the old `ClusterProfile` in the new one's `transitionFrom`. A single label change gets us the same in-place handover this page's overlap window achieves manually, and it covers raw manifests and Kustomize output as well as Helm charts. | Use it unless we specifically want the old `ClusterProfile` to keep acting as a live fallback. |
| [Tiers](tiers.md) | Give the new `ClusterProfile` a lower `tier` value. It always wins over the old one for that release, for as long as both keep matching the cluster. | We're fine with the cluster matching both `ClusterProfiles` indefinitely, and we want the old `ClusterProfile` to remain a live fallback: if the new one ever stops matching (a bad label change, a selector typo), Sveltos falls back to it and reverts the release to whatever it manages. |

`transitionFrom` and the overlap technique on this page both intend a clean, permanent handoff instead, with the old `ClusterProfile` fully out of the picture afterward, which is why a stuck or absent successor blocks cleanup rather than silently falling back.

Use the overlap-then-cutover approach on this page specifically when we want that same clean, permanent handoff but need to keep the old `ClusterProfile` matching for a while as a deliberate rollback window, longer than `transitionFrom`'s deploy-and-verify handover takes. Otherwise, prefer `transitionFrom`: it's less to get wrong (no timing, no second label) and it isn't Helm-specific.

## Caveats

- **This page's overlap-then-cutover technique covers Helm charts (`spec.helmCharts`) only.** The in-place handover it relies on is Sveltos tracking Helm release ownership per `releaseName`/`releaseNamespace`; there is no equivalent handover for raw Kubernetes manifests deployed via `policyRefs` or Kustomize output deployed via `kustomizationRefs` using this specific overlap mechanism. For those resource types (and for Helm charts too, if we'd rather avoid the overlap window entirely), use [`transitionFrom`](transition_from.md) or [Tiers](tiers.md) instead: both resolve ownership without relying on Helm-specific release tracking, and apply to raw manifests and Kustomize output as well as Helm charts.
- This only works if the *same* Helm release (same `releaseName` and `releaseNamespace`) is targeted by both `ClusterProfiles`. If the new `ClusterProfile` renames the release or moves it to a different namespace, Sveltos has no way to know it's the "same" release, and the old one is removed independently of the new one being installed.
- The overlap window only needs to be long enough for the second `ClusterSummary` to be created and reconciled at least once, seconds, not minutes, but the two label changes must land as separate reconciliations, not a single atomic update.
- This pattern applies to any Helm based add-on managed by `ClusterProfile`/`Profile`, not just CNIs. It is the general mechanism Sveltos uses whenever ownership of a Helm release moves from one `ClusterSummary` to another. See [Custom Resource Ownership](../internals/cr-ownership.md) for the underlying `ClusterProfile`/`Profile` → `ClusterSummary` ownership model.
