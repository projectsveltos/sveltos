---
title: Sveltos EventTrigger - Templating with oneForEvent false
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - Sveltos
    - EventTrigger
    - Templating
    - oneForEvent
    - multi-cluster
    - cluster-management
authors:
    - Eleni Grosdouli
    - Gianluca Mardente
---

# Templating when oneForEvent is false

The following resources are available for instantiation if the `EventTrigger` has `oneForEvent` set to `false`.

| Name | Meaning | Availability |
| :--- | :--- | :--- |
| **MatchingResources** | A list of references to all resources that triggered an event, including their **apiVersion**, **kind**, **name**, and **namespace**. | Always available if Kubernetes resources were a match. |
| **Resources** | A list of the full Kubernetes resources that triggered the events. All of their fields are available for templating. | Only if `collectResource` is set to `true` in the `eventSource`. |
| **CloudEvents** | A list of the raw CloudEvents that triggered the `EventTrigger`. | Only if the events were from NATS.io. |
| **Cluster** | The `SveltosCluster` or CAPI Cluster instance where the events occurred. | Always available |
