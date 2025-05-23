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

When Sveltos is managing **hundreds** of clusters and **thousands** of applications, it is recommended to adopt a sharding strategy to distribute the load across multiple Sveltos controller instances.

Sveltos has a controller running in the **management** cluster called the `shard controller`. It watches for cluster annotations. When it detects a new cluster shard, the `shard controller` automatically deploys a new set of Sveltos controllers to manage the shard.

How does Sveltos distribute the load? This is done by adding the special annotation `sharding.projectsveltos.io/key` to the **managed** clusters of interest. By default, all clusters are managed by the same Sveltos controller. When no more **managed** clusters have a special annotation set, Sveltos **automatically** brings down the extra Sveltos controllers.

For more information, have a look at the `.gif` below.

![Event driven add-ons deployment in action](../assets/sharding.gif)

## Sharding Benefits

The benefits of using a sharding strategy include:

1. __Improved performance__: By distributing the load across multiple instances of Sveltos controllers, sharding can improve the performance of Sveltos.
1. __Increased scalability__: Sharding allows Sveltos to manage a larger number of managed clusters and applications.
1. __Reduced risk__: If one instance of a Sveltos controller fails, the other instances can continue to manage the applications in their respective cluster shards.