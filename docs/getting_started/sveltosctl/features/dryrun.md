---
title: Sveltos dry run
description: Sveltos' DryRun mode, a powerful feature that lets you test important changes without any actual impact on your managed clusters. Learn how to configure your ClusterProfile with DryRun syncMode and run a safe simulation of planned operations. Receive detailed reports on potential changes, inspect them, and validate configurations before applying them. Experience peace of mind in managing your clusters with Sveltos' risk-free DryRun mode.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - helm
    - clusterapi
    - dry run
authors:
    - Gianluca Mardente
---

## What is the DryRun mode in Kubernetes?

In Kubernetes, the "dry run" functionality allows users to simulate the execution of the commands they want to apply.

## Sveltos DryRun - Explained

Sveltos takes it one step further. Imagine we are about to perform important changes to a ClusterProfile, but we are unsure what the results will be. The risk of uncertainty is big and we do not want to  cause any unwanted side effects to the Production environment. That's where the DryRun syncMode configuration comes in!

By deploying a ClusterProfile with the `syncMode` set to `DryRun`, we can launch a simulation of all the operations that would normally be executed in a live run. The best part? No actual changes will be performed to the matching clusters during this dry run workflow.

### Configuraton Example

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  syncMode: DryRun
  ...
```

Once the dry run workflow is complete, you'll receive a detailed list of all the potential changes that would have been made to the matching cluster. This allows us to carefully inspect and validate the changes before deploying the new ClusterProfile configuration.

If you are interested in viewing the change list, you can check out the generated Custom Resource Definition (CRD) with the name ClusterReport.

Below is a snippet from the sveltosctl utility.

```
$ sveltosctl show dryrun

+-------------------------------------+--------------------------+-----------+----------------+-----------+--------------------------------+------------------+
|               CLUSTER               |      RESOURCE TYPE       | NAMESPACE |      NAME      |  ACTION   |            MESSAGE             | CLUSTER PROFILE  |
+-------------------------------------+--------------------------+-----------+----------------+-----------+--------------------------------+------------------+
| default/sveltos-management-workload | helm release             | kyverno   | kyverno-latest | Install   |                                | dryrun           |
| default/sveltos-management-workload | helm release             | nginx     | nginx-latest   | Install   |                                | dryrun           |
| default/sveltos-management-workload | :Pod                     | default   | nginx          | No Action | Object already deployed.       | dryrun           |
|                                     |                          |           |                |           | And policy referenced by       |                  |
|                                     |                          |           |                |           | ClusterProfile has not changed |                  |
|                                     |                          |           |                |           | since last deployment.         |                  |
| default/sveltos-management-workload | kyverno.io:ClusterPolicy |           | no-gateway     | Create    |                                | dryrun           |
+-------------------------------------+--------------------------+-----------+----------------+-----------+--------------------------------+------------------+
```

To view **detailed** line-by-line changes for each resource, use the `--raw-diff` option with the `sveltosctl show dryrun` command.

```
$ sveltosctl show dryrun --raw-diff
Cluster: default/clusterapi-workload
--- deployed: ClusterPolicy disallow-latest-tag
+++ proposed: ClusterPolicy disallow-latest-tag
@@ -49,10 +49,10 @@
               name: validate-image-tag
               skipBackgroundRequests: true
               validate:
-                message: Using a mutable image tag e.g. 'latest' is not allowed.
+                message: Using a mutable image tag e.g. 'latest' is not allowed in this cluster.
                 pattern:
                     spec:
                         containers:
                             - image: '!*:latest'
-        validationFailureAction: audit
+        validationFailureAction: Enforce
     status: ""

Cluster: default/clusterapi-workload
--- deployed: Deployment nginx-deployment
+++ proposed: Deployment nginx-deployment
@@ -22,7 +22,7 @@
         uid: 9ba8bbc1-02fa-4cbb-9073-fe657482277d
     spec:
         progressDeadlineSeconds: 600
-        replicas: 3
+        replicas: 1
         revisionHistoryLimit: 10
         selector:
             matchLabels:
```

Sveltos can also detect changes to deployed Helm charts:

```
sveltosctl show dryrun
+-----------------------------+---------------+------------+----------------+---------------+--------------------------------+-----------------------------------+
|           CLUSTER           | RESOURCE TYPE | NAMESPACE  |      NAME      |    ACTION     |            MESSAGE             |              PROFILE              |
+-----------------------------+---------------+------------+----------------+---------------+--------------------------------+-----------------------------------+
| default/clusterapi-workload | helm release  | kyverno    | kyverno-latest | Update Values | use --raw-diff to see full     | ClusterProfile/deploy-kyverno     |
|                             |               |            |                |               | diff for helm values           |                                   |
| default/clusterapi-workload | helm release  | prometheus | prometheus     | Upgrade       | Current version: "23.4.0".     | ClusterProfile/prometheus-grafana |
|                             |               |            |                |               | Would move to version:         |                                   |
|                             |               |            |                |               | "26.0.0"                       |                                   |
| default/clusterapi-workload | helm release  | grafana    | grafana        | Upgrade       | Current version: "6.58.9".     | ClusterProfile/prometheus-grafana |
|                             |               |            |                |               | Would move to version: "8.6.4" |                                   |
+-----------------------------+---------------+------------+----------------+---------------+--------------------------------+-----------------------------------+
```

```
sveltosctl show dryrun --raw-diff
Profile: ClusterProfile:deploy-kyverno Cluster: default/clusterapi-workload
--- deployed values
+++ proposed values
@@ -1,6 +1,6 @@
 admissionController:
     replicas: 3
 backgroundController:
-    replicas: 1
+    replicas: 3
 reportsController:
-    replicas: 1
+    replicas: 3
```

## More Resources

For a quick demonstration of the dry run mode, watch the [Sveltos, introduction to DryRun mode](https://www.youtube.com/watch?v=gfWN_QJAL6k&t=4s) video on YouTube.
