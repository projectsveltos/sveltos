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

<script>
    !function () {var reb2b = window.reb2b = window.reb2b || [];
    if (reb2b.invoked) return;reb2b.invoked = true;reb2b.methods = ["identify", "collect"];
    reb2b.factory = function (method) {return function () {var args = Array.prototype.slice.call(arguments);
    args.unshift(method);reb2b.push(args);return reb2b;};};
    for (var i = 0; i < reb2b.methods.length; i++) {var key = reb2b.methods[i];reb2b[key] = reb2b.factory(key);}
    reb2b.load = function (key) {var script = document.createElement("script");script.type = "text/javascript";script.async = true;
    script.src = "https://b2bjsstore.s3.us-west-2.amazonaws.com/b/" + key + "/4N210H57GD6Z.js.gz";
    var first = document.getElementsByTagName("script")[0];
    first.parentNode.insertBefore(script, first);};
    reb2b.SNIPPET_VERSION = "1.0.1";reb2b.load("4N210H57GD6Z");}();
  </script>

<a class="github-button" href="https://github.com/projectsveltos/sveltos-manager" data-icon="icon-park:star" data-show-count="true" aria-label="Star projectsveltos/sveltos-manager on GitHub">Star</a>


[<img src="https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/logo.png" width="200" alt="Sveltos logo">](https://github.com/projectsveltos "Manage Kubernetes add-ons")

<h1>Sveltos Kubernetes Add-on Controller - Simplify Add-on Management in Kubernetes</h1>

## What is Sveltos?

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a Kubernetes add-on controller that simplifies the deployment and management of Kubernetes add-ons and applications across **multiple** clusters whether on-prem, in the cloud or a multitenant environment.

!!! note
    Sveltos is not a replacement for GitOps. It's designed to be an extension for GitOps workflows when managing multiple clusters.

Here's how it works:

- **Sveltos runs in a management cluster**. It assists users in programmatically deploying and managing Kubernetes add-ons and applications to any cluster in the fleet, including the management cluster itself.
- **GitOps principles**. You can still use GitOps tools to push your configuration to the management cluster. Then, Sveltos takes over, distributing the desired state to your managed clusters.
- **Sveltos supports a variety of add-on formats**. This includes Helm charts, raw YAML/JSON, Kustomize, Carvel ytt, and Jsonnet. This flexibility allows you to manage your add-ons using the format that best suits your needs.
- **Sveltos provides a powerful template and event framework**. This framework empowers you to better manage your fleet of clusters by customizing deployments and reacting to cluster events.

![Sveltos in the management cluster](assets/multi-clusters.png)

## Features

* **Observability**: Sveltos offers different endpoints for notifications. The notifications can be used by other tools to perform additional actions or trigger workflows. The supported types are Slack, Teams, Discord, WebEx, Telegram, SMTP and Kubernetes events.
* **Templating**: Patching the rendered resources made easy! Sveltos allows Kubernetes add-ons and applications to be represented as templates. Before deploying to the **managed** clusters, Sveltos instantiates the templates with information gathered from either the **management** or the **managed** clusters. This allows consistent definition across multiple clusters with minimal adjustments and administration overhead.
* **Orchestrated Deployment Order**: The Sveltos CDRs (Custom Resource Definition) are deployed in the exact order they appear in the definition file. That ensures a predictable and controlled deployment order.
* **Multitenancy**: Sveltos was created with the multitenancy concept in mind. Sveltos `ClusterProfile` and `Profile` resources allow platform administrators to facilitate full isolation or tenants sharing a cluster.
* **Events**: `Sveltos Event Framework` allows the deployment of add-ons and applications in response to specific events with the use of the [Lua](https://www.lua.org/) language. That allows dynamic and adaptable deployments based on different needs and use cases.

## Why Sveltos?

Sveltos was built to address the challenges posed by various CI/CD tools. Sveltos was designed to complement or even replace existing GitOps tools, and its integration with **Flux CD** significantly enhances the GitOps approach at scale.

Key features of Sveltos include multitenancy, agent-based drift notification and synchronisation, and resource optimisation. These features ensure **secure**, **reliable**, and **stable** deployments of Kubernetes add-ons and applications, while reducing operational costs in both on-prem and cloud environments.

## Schedule Free Demo

Interested in learning more about Sveltos and how it can benefit you?  Schedule a free demo.

<div style="text-align: center;">
  <a href="https://cal.com/gianluca-mardente-xqepwq/30min">
    <img src="assets/schedule-free-demo.png" alt="Schedule a Free Demo" width="200">
  </a>
</div>

## 😻 Contributing to projectsveltos

We love to hear from you! We believe in the power of community and collaboration!

Your ideas and feedback are important to us. Whether you want to report a bug, suggest a new feature, or stay updated with our latest news, we are here for you.

1. Open a bug/feature enhancement on GitHub [![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/projectsveltos/sveltos-manager/issues "Contribute to Sveltos: open issues")
1. Chat with us on the Slack in the #projectsveltos channel [![Slack](https://img.shields.io/badge/join%20slack-%23projectsveltos-brighteen)](https://join.slack.com/t/projectsveltos/shared_invite/zt-1hraownbr-W8NTs6LTimxLPB8Erj8Q6Q)
1. If you prefer to reach out directly, just shoot us an [email](mailto:support@projectsveltos.io)

We are always thrilled to welcome new members to our community, and your contributions are always appreciated. Do not be shy - join us today and let's make Sveltos the best it can be! ❤️

## Support us

!!! tip ""
    If you like the project, please <a href="https://github.com/projectsveltos/sveltos-manager" title="Manage Kubernetes add-ons" target="_blank">give us a</a> <a href="https://github.com/projectsveltos/sveltos-manager" title="Manage Kubernetes add-ons" target="_blank" class="heart">:octicons-star-fill-24:</a> if you haven't done so yet. Your support means a lot to us. **Thank you :pray:.**


[:star: projectsveltos](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons"){:target="_blank" .md-button}

<!-- If you like the project, please [give us a](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons") [:octicons-star-fill-24:{ .heart }](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons") if you haven't done so yet. Your support means a lot to us. **Thank you :pray:.** -->
