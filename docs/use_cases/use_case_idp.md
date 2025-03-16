---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | Build an IDP
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Eleni Grosdouli
---

## What is an Internal Developer Platform?

There are many definitions around what an Internal Developer Platform or as commonly known IDP is. An easy-to-understand definition from [Atlassian](https://www.atlassian.com/developer-experience/internal-developer-platform) is the following:
> An internal developer platform (IDP) is a self-service interface between developers and the underlying infrastructure, tools, and processes required to build, deploy, and manage software applications.

## Sveltos Event Framework and IDP

On top of managing add-ons and applications, Sveltos can be used as a framework to build an Internal Developer Platform. Sveltos [Event Framework](../events/addon_event_deployment.md) allows platform teams to **define events**, and **respond** to events by deploying resources.

### How it works?

Imagine an event like the creation of a **new service** or a **namespace** in a specified cluster. Sveltos can **automatically respond** to such `events` by deploying new resources either within the same cluster or across different clusters.

This cross-cluster feature makes it easy to **automate** tasks across different clusters. For example, when a namespace with a specific label is created in a cluster, Sveltos can automatically set up a new database in a dedicated cluster reserved for databases.

For easy to follow deployment examples, check out the [Event Framework Section](../events/db-as-a-service-multiple-db-per-cluster.md).


## Sveltos and NATS Integration

[NATS](https://nats.io/) is a lightweight, high-performance messaging system optimized for speed and scalability. It excels at publish/subscribe communication. [JetStream](https://docs.nats.io/nats-concepts/jetstream) enhances NATS with robust streaming and data management features, including message persistence, flow control, and ordered delivery, creating a powerful platform for modern distributed systems.

With this integration in place, Sveltos can connect to a NATS server and listen for CloudEvents published on NATS subjects. That means Sveltos is not limited to events related to Kubernetes resources!

- [Check out: Explore Sveltos and NATS Integration Example](https://medium.com/itnext/kubernetes-on-autopilot-event-driven-automation-across-clusters-addeb535d20f)


## Sveltos in Action: Real-World Scenarios

👉 [How to Create Event-Driven Resources in Kubernetes by Colin Lacy](https://www.youtube.com/watch?v=4mOWuOF0gWY)

👉 [Automate vCluster Management in EKS with Sveltos and Helm by Colin Lacy](https://www.youtube.com/watch?v=GQM7Qn9rWVU&t=264s)

👉 [Building Your Own Event-Driven Internal Developer Platform with GitOps and Sveltos by Artem Lajko](https://medium.com/itnext/building-your-own-event-driven-internal-developer-platform-with-gitops-and-sveltos-cbe3de4920d5)

👉 [Click-to-Cluster: GitOps EKS Provisioning by Gianluca Mardente](https://medium.com/itnext/click-to-cluster-gitops-eks-provisioning-8c9d3908cb24)