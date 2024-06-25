---
title: Projectsveltos Sharding
description: Sveltos can manage add-ons and applications in hundreds of clusters, and it can be scaled horizontally by easily adding an annotation to managed clusters.
tags:
    - Kubernetes
    - add-ons
    - horizontal scaling
authors:
    - Gianluca Mardente
---

## Introduction to Sharding

When Sveltos is managing hundreds of managed clusters and thousands of applications, it is advisable to adopt a sharding strategy to distribute the load across multiple Sveltos controllers instances.

Sveltos has a controller running in the management cluster, called the ```shard controller```, which watches for cluster annotations. When it detects a new cluster shard, the shard controller deploys automatically a new set of Projectsveltos controllers to manage that shard.

To update the sharding policy, add the annotation ```sharding.projectsveltos.io/key``` to the managed clusters.


![Event driven add-ons deployment in action](../assets/sharding.gif)

## Sharding Benefits

The benefits of using a sharding strategy include:

1. __Improved performance__: By distributing the load across multiple instances of Sveltos controllers, sharding can improve the performance of Sveltos.
2. __Increased scalability__: Sharding allows Sveltos to manage a larger number of managed clusters and applications.
3. __Reduced risk__: If one instance of a Sveltos controller fails, the other instances can continue to manage the applications in their respective cluster shards.