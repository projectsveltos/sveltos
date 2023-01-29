---
title: Snapshot
description: Snapshot is a Configuration Snapshot and Rollback tool for Sveltos. Snapshot allows an administrator to perform snapshots of the configuration.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi tenancy
authors:
    - Gianluca Mardente
---
Snapshot is a Configuration Snapshot and Rollback tool for Sveltos. Specifically, the tool allows an administrator to perform the following tasks:

- Live snapshots of the running Sveltos configuration;
- Recurring snapshots;
- Versioned storage of the configuration;
- Full viewing of any snapshot configuration including the differences between snapshots;
- Rollback to any previous configuration snapshot; Full or Partial.

## General Overview

The snapshot feature allows to capture a complete Sveltos policy configuration at an instant in time. Using snapshots from different timestamps, it is possibly to see what configuration changes occurred between two snapshots, and roll back and forward policy configurations to any saved configuration snapshot.

Operations using snapshots, such as capture, diff, and rollback, are performed with the Sveltos command line interface, [sveltosctl](https://github.com/projectsveltos/sveltosctl).

For a demonstration of snapshots, watch the video [Sveltos, introduction to Snapshots](https://www.youtube.com/watch?v=ALcp1_Nj9r4) on YouTube.

### Snapshot diff

[sveltoctl](https://github.com/projectsveltos/sveltosctl) snapshot diff can be used to display all the configuration changes between two snapshots:

```
kubectl exec -it -n projectsveltos sveltosctl-0 -- ./sveltosctl snapshot diff --snapshot=hourly  --from-sample=2022-10-10:22:00:00 --to-sample=2022-10-10:23:00:00 
+-------------------------------------+--------------------------+-----------+----------------+----------+------------------------------------+
|               CLUSTER               |      RESOURCE TYPE       | NAMESPACE |      NAME      |  ACTION  |              MESSAGE               |
+-------------------------------------+--------------------------+-----------+----------------+----------+------------------------------------+
| default/sveltos-management-workload | helm release             | mysql     | mysql          | added    |                                    |
| default/sveltos-management-workload | helm release             | nginx     | nginx-latest   | added    |                                    |
| default/sveltos-management-workload | helm release             | kyverno   | kyverno-latest | modified | To version: v2.5.0 From            |
|                                     |                          |           |                |          | version v2.5.3                     |
| default/sveltos-management-workload | /Pod                     | default   | nginx          | added    |                                    |
| default/sveltos-management-workload | kyverno.io/ClusterPolicy |           | no-gateway     | modified | To see diff compare ConfigMap      |
|                                     |                          |           |                |          | default/kyverno-disallow-gateway-2 |
|                                     |                          |           |                |          | in the from folderwith ConfigMap   |
|                                     |                          |           |                |          | default/kyverno-disallow-gateway-2 |
|                                     |                          |           |                |          | in the to folder                   |
+-------------------------------------+--------------------------+-----------+----------------+----------+------------------------------------+
```

If resources contained in Secrets/ConfigMaps referenced by ClusterProfile where modified, option *raw-diff* can be used to see exactly what was changed:

```
kubectl exec -it -n projectsveltos                      sveltosctl-0   -- ./sveltosctl snapshot  diff --snapshot=hourly --from-sample=2023-01-17:14:56:00 --to-sample=2023-01-17:15:56:00
+-------------------------------------------+--------------------------+-----------+-----------------------+----------+--------------------------------+
|                  CLUSTER                  |      RESOURCE TYPE       | NAMESPACE |         NAME          |  ACTION  |            MESSAGE             |
+-------------------------------------------+--------------------------+-----------+-----------------------+----------+--------------------------------+
| default/capi--sveltos-management-workload | kyverno.io/ClusterPolicy |           | add-default-resources | modified | use --raw-diff option to see   |
|                                           |                          |           |                       |          | diff                           |
+-------------------------------------------+--------------------------+-----------+-----------------------+----------+--------------------------------+

kubectl exec -it -n projectsveltos                      sveltosctl-0   -- ./sveltosctl snapshot  diff --snapshot=hourly --from-sample=2023-01-17:14:56:00 --to-sample=2023-01-17:15:56:00 --raw-diff
--- kyverno.io/ClusterPolicy add-default-resources from /snapshot/hourly/2023-01-17:14:56:00
+++ kyverno.io/ClusterPolicy add-default-resources from /snapshot/hourly/2023-01-17:15:56:00
@@ -37,7 +37,8 @@
               "operator": "In",
               "value": [
                 "CREATE",
-                "UPDATE"
+                "UPDATE",
+                "DELETE"
               ]
             }
           ]
```

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
