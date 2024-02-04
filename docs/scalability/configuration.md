---
title: Projectsveltos horizontal scaling
description: Sveltos can manage add-ons and applications in hundreds of clusters, and it can be scaled horizontally by easily adding an annotation to managed clusters.
tags:
    - Kubernetes
    - add-ons
    - vertical scaling
authors:
    - Gianluca Mardente
---

The below arguments can be used to customize Sveltos add-on controller.

1. *concurrent-reconciles*: By default the Sveltos manager reconcilers runs with a **parallelism** set to **10**. This arg can be used to change level of parallelism for ClusterProfiles and ClusterSummary;
2. *worker-number*: The number of workers performing long running task. By default it is set to **20**. Increase it number if the managed clusters is above 100.

More infromation can be found in the folllowing [Medium post](https://medium.com/@gianluca.mardente/how-to-handle-long-running-tasks-in-kubernetes-reconciliation-loop-3cc04bfa2681) on how Sveltos handles long running task. 