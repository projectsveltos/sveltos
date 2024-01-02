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

<a class="github-button" href="https://github.com/projectsveltos/sveltos-manager" data-icon="icon-park:star" data-show-count="true" aria-label="Star projectsveltos/sveltos-manager on GitHub">Star</a>

[<img src="https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/logo.png" width="200" alt="Sveltos logo">](https://github.com/projectsveltos "Manage Kubernetes add-ons")

<h1>Sveltos Kubernetes Add-on Controller - Simplify Add-on Management in Kubernetes</h1>

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a Kubernetes add-on controller that simplifies the deployment and management of add-ons and applications across multiple clusters. Sveltos runs in the management cluster and can programmatically deploy and manage add-ons and applications on any cluster in the fleet, including the management cluster itself. Sveltos supports a variety of add-on formats, including Helm charts, raw YAML/JSON, Kustomize, Carvel ytt, and Jsonnet.

![Sveltos in the management cluster](assets/multi-clusters.png)

Sveltos allows add-ons and applications to be represented as templates. Before deploying to managed clusters, Sveltos instantiates these templates. Sveltos can gather the information required to instantiate the templates from either the management cluster or the managed clusters themselves.

With templates, the same add-on configuration can be used across all of the managed clusters, while still allowing for some variation, such as different add-on configuration values. This approach facilitates the definition and deployment of add-ons and applications in a reusable manner, enabling the application of these definitions across multiple clusters with minimal adjustments. This strategy significantly reduces administrative overhead, particularly in environments managing a large number of clusters.

Sveltos provides precise control over add-on deployment order. Add-ons within a ClusterProfile are deployed in the exact order they appear, ensuring a predictable and controlled rollout. Furthermore, ClusterProfiles can depend on others, guaranteeing that dependent add-ons only deploy after their dependencies are fully operational. Finally Sveltos' event-driven framework offers additional flexibility. This framework allows for deploying add-ons and applications in response to specific events, enabling dynamic and adaptable deployments based on your needs.

But that's not all! Sveltos not only helps you scale the number of clusters you can manage, but it also provides visibility into exactly which add-ons are installed on each cluster. So you can stay on top of your cluster management game and never miss a beat.

![Sveltos addons](assets/addons.png)

## 😻 Contributing to projectsveltos
We love to hear from our community!

We believe in the power of community and collaboration, and that's where you come in!

We would love to hear your suggestions, contributions, and feedback to make our project even better! Whether you want to report a bug, request a new feature, or just stay up-to-date with the latest news, we've got you covered.

We would love your suggestions, contributions, and help! 

1. Open a bug/feature enhancement on github [![contributions welcome](https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat)](https://github.com/projectsveltos/sveltos-manager/issues "Contribute to Sveltos: open issues")
2. Chat with us on the Slack in the #projectsveltos channel [![Slack](https://img.shields.io/badge/join%20slack-%23projectsveltos-brighteen)](https://join.slack.com/t/projectsveltos/shared_invite/zt-1hraownbr-W8NTs6LTimxLPB8Erj8Q6Q)
3. If you prefer to reach out directly, just shoot us an [email](mailto:support@projectsveltos.io)

We are always thrilled to welcome new members to our community, and your contributions are always appreciated. So don't be shy - join us today and let's make Sveltos the best it can be! ❤️

## Support us

{==

If you like the project, please [give us a](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons")  [:octicons-star-fill-24:{ .heart }](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons") if you haven't done so yet. Your support means a lot to us. **Thank you :pray:.**

==}

[:star: projectsveltos](https://github.com/projectsveltos/sveltos-manager "Manage Kubernetes add-ons"){ .md-button .md-button--primary }

<script async defer src="https://buttons.github.io/buttons.js"></script>
