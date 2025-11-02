---
title: Sveltos - Kubernetes Add-on Controller | Manage and Deploy Add-ons
description: Sveltos is a Kubernetes add-on controller for a fleet of clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - carvel ytt
    - jsonnet
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

<script async defer src="https://buttons.github.io/buttons.js"></script>

<a class="github-button" href="https://github.com/projectsveltos/sveltos-manager" data-icon="icon-park:star" data-show-count="true" aria-label="Star projectsveltos/sveltos-manager on GitHub">Star</a>


[<img src="https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/logo.png" width="200" alt="Sveltos logo">](https://github.com/projectsveltos "Manage Kubernetes add-ons")

<h1>Sveltos Kubernetes Add-on Controller - Simplify Add-on Management in Kubernetes</h1>

## What is Sveltos?

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a Kubernetes add-on controller. It makes deploying and managing Kubernetes add-ons and applications easier across **multiple** clusters. This works for on-prem, cloud, or multitenant setups.

!!! note
    Sveltos is not a replacement for GitOps. It's designed to be an extension for GitOps workflows when managing multiple clusters.

Here's how it works:

- **Sveltos runs in a management cluster**. It helps users deploy and manage Kubernetes add-ons and applications. This works for any cluster in the fleet, including the management cluster.
- **GitOps principles**. You can still use GitOps tools to push your configuration to the management cluster. Then, Sveltos takes over, distributing the desired state to your managed clusters.
- **Sveltos supports a variety of add-on formats**. This includes Helm charts, raw YAML/JSON, Kustomize, Carvel ytt, and Jsonnet. This flexibility allows you to manage your add-ons using the format that best suits your needs.
- **Sveltos provides a powerful template and event framework**. This framework empowers you to better manage your fleet of clusters by customising deployments and reacting to cluster events.

![Sveltos in the management cluster](assets/multi-clusters.png)

## Features

* **🔄 Orchestrated Deployment Order**: Sveltos deploys custom resources in our defined order. This ensures deployments are predictable and controlled.
* **🧩 Templating**: Patching the rendered resources made easy! Represent add-ons and applications as templates. Sveltos automatically adds cluster-specific details. This makes it easy to manage consistent deployments across different clusters.
* **👥 Multitenancy**: Designed for multitenancy from the beginning. Use `ClusterProfile` and `Profile` resources for complete isolation or tenant sharing in clusters.
* **⚡ Events**: Deploy add-ons and applications in response to specific events using [Lua](https://www.lua.org/) or [CEL](https://cel.dev/). Adapt deployments dynamically to defined needs and use cases.
* **📢 Observability**: Get notifications through Slack, Teams, Discord, WebEx, Telegram, SMTP, or Kubernetes events. Easily integrate with other tools to trigger actions or workflows.
* **🛡️ Pull Mode**: Deploy add-ons and applications in restricted environments; clusters behind firewalls, air-gapped setups, edge environments with limited bandwidth, and secure, highly regulated infrastructures.
* **🚦 Progressive Rollouts**: Perform phased rollouts of cluster configurations and add-ons. Define the configuration once. Then, list the deployment stages in order. There's no need to manage multiple `ClusterProfile` resources.

## Why Sveltos?

Sveltos was created to tackle the real challenges of managing multi-cluster add-ons. Many CI/CD tools find this tough. Sveltos can enhance or replace current GitOps tools. Its integration with Flux CD improves scalability and automation across different environments.

Sveltos stands out with features like multitenancy, agent-based drift detection, and resource optimisation. With powerful templating, an event framework, and progressive rollouts, teams can safely and reliably deploy Kubernetes add-ons and applications. These capabilities lower operational costs, whether we run workloads on-site or in the cloud.

## Enterprise Offering


Interested in our enterprise offering? [Enterprise offering](https://sveltos.projectsveltos.io/#pricing)


## 😻 Contributing to projectsveltos

We love to hear from you! We believe in the power of community and collaboration!

Your ideas and feedback are important to us. Whether you want to report a bug, suggest a new feature, or stay updated with our latest news, we are here for you.

1. Open a bug/feature enhancement on GitHub [![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/projectsveltos/sveltos-manager/issues "Contribute to Sveltos: open issues")
1. Chat with us on Slack in the #projectsveltos channel [![Slack](https://img.shields.io/badge/join%20slack-%23projectsveltos-brighteen)](https://join.slack.com/t/projectsveltos/shared_invite/zt-1hraownbr-W8NTs6LTimxLPB8Erj8Q6Q)
1. If you prefer to reach out directly, just shoot us an [email](mailto:support@projectsveltos.io)

We are always thrilled to welcome new members to our community, and your contributions are always appreciated. Do not be shy - join us today and let's make Sveltos the best it can be! ❤️

## Support us

!!! tip ""
    If you like the project, please <a href="https://github.com/projectsveltos/sveltos-manager" title="Manage Kubernetes add-ons" target="_blank">give us a</a> <a href="https://github.com/projectsveltos/sveltos-manager" title="Manage Kubernetes add-ons" target="_blank" class="heart">:octicons-star-fill-24:</a> if you haven't done so yet. Your support means a lot to us. **Thank you :pray:.**


[:star: projectsveltos](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons"){:target="_blank" .md-button}

<!-- If you like the project, please [give us a](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons") [:octicons-star-fill-24:{ .heart }](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons") if you haven't done so yet. Your support means a lot to us. **Thank you :pray:.** -->
