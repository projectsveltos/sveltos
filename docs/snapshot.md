Snapback is a Configuration Snapshot and Rollback tool for Sveltos. Specifically, the tool allows an administrator to perform the following tasks:

- Live snapshots of the running Sveltos configuration;
- Recurring snapshots;
- Versioned storage of the configuration;
- Full viewing of any snapshot configuration including the differences between snapshots;
- Rollback to any previous configuration snapshot; Full or Partial.

### General Overview

The snapshot feature allows to capture a complete Sveltos policy configuration at an instant in time. Using snapshots from different timestamps, it is possibly to see what configuration changes occurred between two snapshots, and roll back and forward policy configurations to any saved configuration snapshot.

Operations using snapshots, such as capture, diff, and rollback, are performed with the Sveltos command line interface, [sveltosctl](https://github.com/projectsveltos/sveltosctl).

For a demonstration of snapshots, watch the video [Sveltos, introduction to Snapshots](https://www.youtube.com/watch?v=ALcp1_Nj9r4) on YouTube.

### Rollback

Rollback is a feature in which a previous configuration snapshot is used to replace the current configuration deployed by Sveltos. Rollback can be executed with the following granularities:

- namespace — rolls back only ConfigMaps/Secrets and Cluster labels in this namespace. If no namespace is specified, all namespaces are updated;
- cluster — rolls back only labels for a cluster with this name. If no cluster name is specified, labels for all clusters are updated;
- clusterprofile — rolls back only ClusterProfiles with this name. If no ClusterProfile name is specified, all ClusterProfiles are updated;

When all of the configuration files for a particular version are used to replace the current configuration, this is referred to as a full rollback.

For a demonstration of rollback, watch the video [Sveltos, introduction to Rollback](https://www.youtube.com/watch?v=sTo6RcWP1BQ) on YouTube.

### Snapshot CRD

Snapshot CRD is used to configure Sveltos to periodically take snapshots. Here is a quick example. 
For more information on this CRD fields, please read [here](configuration.md#snapshot)

```yaml
---
---
apiVersion: utils.projectsveltos.io/v1alpha1
kind: Snapshot
metadata:
  name: hourly
spec:
  schedule: "0 * * * *"
  storage: /snapshot
```