---
title: Snapshot
description: Snapshot is a Configuration Snapshot and Rollback tool for Sveltos. Snapshot allows an administrator to perform snapshots of the configuration.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## What is a Snapshot?

Snapshot is a **Configuration Snapshot** and **Rollback** tool for Sveltos. Specifically, the tool allows an administrator to perform the tasks like:

- Live snapshots of the running Sveltos configuration;
- Recurring snapshots;
- Versioned storage of the configuration;
- Full viewing of any snapshot configuration including the differences between snapshots;
- Rollback to any previous configuration snapshot; Full or Partial.

## General Overview

The snapshot feature allows to capture a complete Sveltos policy configuration at an instant in time. Using snapshots from different timestamps, it is possibly to identify what configuration changes occurred between snapshots, and roll back and forward policy configurations to any saved configuration snapshot.

Operations using snapshots, such as capture, diff, and rollback, are performed with the Sveltos CLI, [sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI").

Checkout Youtube for a [Sveltos introduction to Snapshots](https://www.youtube.com/watch?v=ALcp1_Nj9r4).

## Snapshot CRD

[Sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") when running as a Pod in the management cluster, can be configured to collect configuration snapshots.
*Snapshot* CRD is used for that.

!!! example "Example - Snapshot"
    ```yaml
    ---
    apiVersion: utils.projectsveltos.io/v1beta1
    kind: Snapshot
    metadata:
      name: hourly
    spec:
      schedule: "0 * * * *" # (1)
      storage: /collection # (2)
    ```

    1. Specifies when a snapshot needs to be collected. It is in [Cron format](https://en.wikipedia.org/wiki/Cron).

    2. Represents a directory where snapshots will be stored. It must be an existing directory (on a PersistentVolume mounted by sveltosctl)

### Snapshot diff

[sveltoctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") snapshot diff can be used to display all the configuration changes between two snapshots:

```
$ sveltosctl snapshot diff --snapshot=hourly  --from-sample=2022-10-10:22:00:00 --to-sample=2022-10-10:23:00:00 
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

If resources contained in Secrets/ConfigMaps referenced by ClusterProfile were modified, the option *raw-diff* can be used to determine what changed.

```
$ sveltosctl snapshot  diff --snapshot=hourly --from-sample=2023-01-17:14:56:00 --to-sample=2023-01-17:15:56:00
+-------------------------------------------+--------------------------+-----------+-----------------------+----------+--------------------------------+
|                  CLUSTER                  |      RESOURCE TYPE       | NAMESPACE |         NAME          |  ACTION  |            MESSAGE             |
+-------------------------------------------+--------------------------+-----------+-----------------------+----------+--------------------------------+
| default/capi--sveltos-management-workload | kyverno.io/ClusterPolicy |           | add-default-resources | modified | use --raw-diff option to see   |
|                                           |                          |           |                       |          | diff                           |
+-------------------------------------------+--------------------------+-----------+-----------------------+----------+--------------------------------+

$ sveltosctl snapshot  diff --snapshot=hourly --from-sample=2023-01-17:14:56:00 --to-sample=2023-01-17:15:56:00 --raw-diff
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

Rollback is the feature in which a previous configuration snapshot is used to replace a current configuration deployed by Sveltos. Rollback can be executed with the below granularities:

- namespace: Rolls back only ConfigMaps/Secrets and Cluster labels in the defined namespace. If no namespace is defined, **all namespaces** are updated;
- cluster: Rolls back only labels for a cluster with this name. If no cluster name is specified, labels for **all clusters** are updated;
- clusterprofile: Rolls back only ClusterProfiles with this name. If no ClusterProfile name is specified, **all ClusterProfiles** are updated;

When all the configuration files for a particular version are used to replace the current configuration, it is referred to as a full rollback.

Checkout Youtube for a [Sveltos, introduction to Rollback](https://www.youtube.com/watch?v=sTo6RcWP1BQ).

### Example - PHP Guestbook application with Redis

This example shows how to deploy a multi-tier web application in Kubernetes using Sveltos and how to use snapshot to quickly see changes.

The application consists of the below components:

1. A single-instance Redis to store guestbook entries
2. Multiple web frontend instances

The first step is to create two ConfigMaps:

```
$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/snapshot_example/database.yaml

$ kubectl create configmap database --from-file database.yaml
```

```
$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/snapshot_example/frontend.yaml

$ kubectl create configmap frontend --from-file frontend.yaml
```

The [database.yaml](../../assets/snapshot_example/database.yaml) ConfigMap contains the definition of a single replica Redis Pod, exposed via a service.

The [frontend.yaml](../../assets/snapshot_example/frontend.yaml) ConfigMap contains the definition of the guestbook application. The guestbook app uses a PHP frontend that is configured to communicate with either the Redis follower or leader Services, depending on whether the request is a read or a write.

Once the ConfigMaps have been created, you can create a ClusterProfile instance:

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/snapshot_example/clusterprofile.yaml
```

This will deploy all necessary resources in all managed cluster matching ClusterProfile cluster selector field.

```
$ sveltosctl show addons 
+-----------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
|           CLUSTER           |  RESOURCE TYPE  | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILES |
+-----------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
| default/clusterapi-workload | :Service        | test      | frontend       | N/A     | 2023-08-26 04:53:22 -0700 PDT | guestbook        |
| default/clusterapi-workload | apps:Deployment | test      | redis-leader   | N/A     | 2023-08-26 04:53:21 -0700 PDT | guestbook        |
| default/clusterapi-workload | :Service        | test      | redis-leader   | N/A     | 2023-08-26 04:53:21 -0700 PDT | guestbook        |
| default/clusterapi-workload | apps:Deployment | test      | redis-follower | N/A     | 2023-08-26 04:53:21 -0700 PDT | guestbook        |
| default/clusterapi-workload | :Service        | test      | redis-follower | N/A     | 2023-08-26 04:53:22 -0700 PDT | guestbook        |
| default/clusterapi-workload | apps:Deployment | test      | frontend       | N/A     | 2023-08-26 04:53:22 -0700 PDT | guestbook        |
+-----------------------------+-----------------+-----------+----------------+---------+-------------------------------+------------------+
```

If you want guests to be able to access your guestbook, you must configure the frontend Service to be externally visible, so a client can request the Service from outside the Kubernetes cluster. However, a Kubernetes user can use ```kubectl port-forward``` to access the service even though it uses a ClusterIP.

Cluster in this example, was created with [__make quickstart__](../install/quick_start.md) available in [addon-controller repo](https://github.com/projectsveltos/addon-controller)

```
$ KUBECONFIG=test/fv/workload_kubeconfig kubectl port-forward -n test service/frontend 8080:80
```

Load the page http://localhost:8080 in your browser to view your guestbook

![Guestbook](../../assets/snapshot_example/guestbook.png)

The Sveltos snapshot feature allows you to take snapshots of your Kubernetes configuration at regular intervals. This can be useful for tracking changes of the configuration over time, or for debugging purposes.

```
$ sveltosctl snapshot list 
+-----------------+---------------------+
| SNAPSHOT POLICY |        DATE         |
+-----------------+---------------------+
| hourly          | 2023-08-26:05:00:00 |
+-----------------+---------------------+
```

Let's assume, later on a change is made. For instance, the __redis-follower__ Service label selector is inadvertently modified.

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/snapshot_example/database_broken.yaml
```

Entries in the database are not visible anymore. Of course we can debug this issue. 
But if we simply want to see what has changed we can take a new snapshot

```
$ sveltosctl snapshot list
+-----------------+---------------------+
| SNAPSHOT POLICY |        DATE         |
+-----------------+---------------------+
| hourly          | 2023-08-26:05:00:00 |
| hourly          | 2023-08-26:05:20:00 |
+-----------------+---------------------+
```

and then look at the configuration differences

```
$ sveltosctl snapshot diff --snapshot=hourly --from-sample=2023-08-26:05:00:00 --to-sample=2023-08-26:05:20:00
+-----------------------------------+---------------+-----------+----------------+----------+--------------------------------+
|              CLUSTER              | RESOURCE TYPE | NAMESPACE |      NAME      |  ACTION  |            MESSAGE             |
+-----------------------------------+---------------+-----------+----------------+----------+--------------------------------+
| default/capi--clusterapi-workload | /Service      | test      | redis-follower | modified | use --raw-diff option to see   |
|                                   |               |           |                |          | diff                           |
+-----------------------------------+---------------+-----------+----------------+----------+--------------------------------+
```

```
$ sveltosctl snapshot diff --snapshot=hourly --from-sample=2023-08-26:05:00:00 --to-sample=2023-08-26:05:20:00 --raw-diff
--- /Service test/redis-follower from /collection/snapshot/hourly/2023-08-26:05:00:00
+++ /Service test/redis-follower from /collection/snapshot/hourly/2023-08-26:05:20:00
@@ -13,7 +13,7 @@
     # the port that this service should serve on
   - port: 6379
   selector:
-    app: redis
+    app: redis-follower
     role: follower
     tier: backend
```

To fix this, we can simply ask Sveltos to revert back to working snapshot

```
$ kubectl exec -it -n projectsveltos sveltosctl-0 -- ./sveltosctl snapshot rollback --snapshot=hourly --sample=2023-08-26:05:00:00
```
