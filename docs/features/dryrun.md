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
---
apiVersion: config.projectsveltos.io/v1alpha1
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

## More Resources

For a quick demonstration of the dry run mode, watch the [Sveltos, introduction to DryRun mode](https://www.youtube.com/watch?v=gfWN_QJAL6k&t=4s) video on YouTube.
