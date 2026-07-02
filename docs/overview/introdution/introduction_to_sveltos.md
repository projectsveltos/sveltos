---
title: Introduction to Sveltos. The Kubernetes add-ons management for tens of clusters
description: Projectsveltos extends the functionality of Cluster API with a solution for managing the installation, configuration & deletion of Kubernetes cluster add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Eleni Grosdouli
---

# What is Sveltos?

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a [Kubernetes fleet management controller](https://github.com/projectsveltos/addon-controller). It deploys and manages add-ons and applications across a fleet of clusters using label-based matching. Sveltos' power comes into play when teams have to manage multiple clusters across different environments (on-prem, cloud) that require different configurations.

### What is the difference between a GitOps Controller and Sveltos?

Sveltos does not compete with GitOps controllers like ArgoCD or Flux. Instead, it extends their capabilities. A GitOps controller monitors a repository and syncs manifests. In contrast, Sveltos applies these manifests across the entire fleet. Its configurations are cluster-agnostic; they do not reference a specific cluster. Instead, they target clusters by labels, which means when a new cluster joins the fleet, it requires no configuration changes, only the right labels. One configuration can serve any number of clusters that meet the defined criteria.

## Features Overview

Sveltos comes with a rich set of features designed for the modern era of Continuous Deployments (CD) within the DevOps, GitOps, and Platform Engineering space. The following outline could cover a wide range of [use cases](../../use_cases/) while giving the teams the ability to expand existing or even new use cases based on their needs.

* **🔄 Orchestrated Deployment Order**: Deploy resources in a defined order using simple Custom Resource Definitions (CRDs). Predictable, controlled rollouts.
* **👥 Multitenancy**: Use `ClusterProfile` for fleet-wide policies and `Profile` for namespace-scoped tenant isolation.
* **🧩 Templating**: Define add-ons and applications as templates; Sveltos instantiates them per cluster using cluster metadata.
* **⚡ Event-driven Framework**: Trigger deployments from in-cluster or NATS events, with matching logic written in [Lua](https://www.lua.org/) or [CEL](https://cel.dev/).
* **📢 Observability**: Notifications via Slack, Teams, Discord, Webex, Telegram, SMTP, or Kubernetes events.
* **🛡️ Pull Mode**: Deploy into restricted environments: air-gapped, edge, or behind firewalls.
* **🚦 Progressive rollouts**: Phased deployments from a single configuration; no need to maintain multiple profiles.

## Sveltos for Edge Deployments

Sveltos is built with edge constraints in mind. Agents are lightweight and only deploy what is actually needed. Resource consumption scales with what you ask Sveltos to do.Nothing more. To explore Sveltos' capabilities at a large scale, take a look at [Artem Lajko's post "GitOps for 15,000+ Clusters: What Large-Scale Testing with vCluster Taught Us"](https://itnext.io/gitops-for-15-000-clusters-what-large-scale-testing-with-vcluster-taught-us-41e4b0d43e0b).

## Next Steps

To get an understanding of the Sveltos architecture and the individual components, continue with the [architecture](../architecture/architecture.md) section. To get started with Sveltos, take a look at the [quick start guide](../../getting_started/install/quick_start.md) or go directly to the [Sveltos installation](../../getting_started/install/install.md) and the [registration details](../../register/register-cluster.md).
