---
title: Recources by Sveltos
description: Discover how Sveltos tackles Configuration Drift - the common challenge of maintaining consistency in an evolving environment. Learn how Sveltos monitors and rectifies configuration drift in managed clusters, ensuring your systems remain consistent and predictable. Explore the proactive approach to prevent unexpected issues caused by configuration drift with Sveltos. Configuration drift recovery made simple.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - helm
    - clusterapi
    - configuration drift detection
authors:
    - Gianluca Mardente
---

### Configuration Drift

_Configuration drift_ is a common term to describe a change that takes place in an environment. Drift is an issue because it causes systems and parts of a system that are supposed to be consistent, to become inconsistent and unpredictable.

In our case, _configuration drift_ is a change of a resource deployed by Sveltos in one of the managed clusters.

With Sveltos, you can set the sync mode to *ContinuousWithDriftDetection* for a ClusterProfile. This allows Sveltos to monitor the state of managed clusters and detect configuration drift for any of the resources deployed because of that ClusterProfile.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  syncMode: ContinuousWithDriftDetection
  ...
```

When Sveltos detects a configuration drift, it automatically re-syncs the cluster state back to the state described in the management cluster. In order to achieve this, Sveltos deploys a service in each managed cluster and configures it with a list of Kubernetes resources deployed for each ClusterProfile in SyncModeContinuousWithDriftDetection mode.

The service then starts a watcher for each GroupVersionKind with at least one resource to watch. When any of the watched resources are modified (labels, annotations, spec or rules sections), the service notifies the management cluster about a potential configuration drift. The management cluster then reacts by redeploying affected ClusterProfiles.

This way, Sveltos ensures that your systems are always consistent and predictable, preventing any unexpected issues caused by configuration drift.

![Configuration drift recovery](assets/reconcile_configuration_drift.gif)
