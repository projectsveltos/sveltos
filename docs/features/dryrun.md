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

# DryRun mode

Imagine you're about to make some important changes to your ClusterProfile, but you're not entirely sure what the results will be. You don't want to risk causing any unwanted side effects, right? Well, that's where the DryRun syncMode configuration comes in!

By deploying your ClusterProfile with this configuration, you can launch a simulation of all the operations that would normally be executed in a live run. The best part? No actual changes will be made to the matching clusters during this dry run workflow, so you can rest easy knowing that there won't be any surprises.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  syncMode: DryRun
  ...
```

Once the dry run workflow is complete, you'll receive a detailed list of all the potential changes that would have been made to each matching cluster. This allows you to carefully inspect and validate these changes before deploying the new ClusterProfile configuration.

If you're interested in viewing this change list, you can check out the generated Custom Resource Definition (CRD) called ClusterReport. But let's be real, it's much simpler to just use the sveltosctl CLI command, like this:

```
./bin/sveltosctl show dryrun

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

For a demonstration of dry run mode, watch the video [Sveltos, introduction to DryRun mode](https://www.youtube.com/watch?v=gfWN_QJAL6k&t=4s) on YouTube.