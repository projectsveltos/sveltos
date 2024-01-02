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

Following arguments can be used to customize Sveltos add-on controller:

1. *concurrent-reconciles*: by default Sveltos manager reconcilers runs with a parallelism set to 10. This arg can be used to change level of parallelism for ClusterProfiles and ClusterSummary;
2. *worker-number*: number of workers performing long running task. By default this is set to 20. Increase it number of managed clusters is above 100. Read this [Medium post](https://medium.com/@gianluca.mardente/how-to-handle-long-running-tasks-in-kubernetes-reconciliation-loop-3cc04bfa2681) to know more about how Sveltos handles long running task. 