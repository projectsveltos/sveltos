### Configuration Drift

_Configuration drift_ is a common term to describe a change that takes place in an environment. Drift is an issue because it causes systems and parts of a system that are supposed to be consistent, to become inconsistent and unpredictable.

In our case, _configuration drift_ is a change of a resource deployed by Sveltos in one of the managed clusters.

When sync mode is set to *SyncModeContinuousWithDriftDetection* for a ClusterProfile, Sveltos monitors the state of managed clusters and when it detects a configuration drift for one of the resource deployed because of that ClusterProfile, it re-syncs the cluster state back to the state described in the management cluster.

In order to achieve so, when in this mode:

- Sveltos deploys a service in each managed cluster and configures this service with list of kubernetes resources deployed because of each ClusterProfile in SyncModeContinuousWithDriftDetection mode;
- service starts a watcher for each GroupVersionKind with at least one resource to watch;
- when one of the resources being watched is modified (labels, annotations, spec or rules sections), service notifies management cluster about a potential configuration drift;
- management cluster reacts by redeploying afftected ClusterProfiles.

![Configuration drift recovery](assets/reconcile_configuration_drift.gif)
