---
title: Sveltos - Kubernetes Add-on Controller | Manage and Deploy Add-ons
description: Sveltos is a lightweight application that simplifies the deployment and management of add-ons in Kubernetes clusters. With Sveltos Kubernetes add-on controller, automate the deployment process and ensure consistency across your cluster environment.
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

[Sveltos](https://github.com/projectsveltos "Manage Kubernetes add-ons") is a Kubernetes add-on controller that simplifies the deployment and management of add-ons and applications across multiple clusters. It runs in the management cluster and can programmatically deploy and manage add-ons and applications on any cluster in the fleet, including the management cluster itself. Sveltos supports a variety of add-on formats, including Helm charts, raw YAML, Kustomize, Carvel ytt, and Jsonnet.

![Sveltos in the management cluster](assets/multi-clusters.png)


Sveltos allows you to represent add-ons and applications as templates. Before deploying to managed clusters, Sveltos instantiates these templates. Sveltos can gather the information required to instantiate the templates from either the management cluster or the managed clusters themselves.

This enables you to use the same add-on configuration across all of your clusters, while still allowing for some variation, such as different add-on configuration values. In other words, Sveltos lets you define add-ons and applications in a reusable way. You can then deploy these definitions to multiple clusters, with minor adjustments as needed. This can save you a lot of time and effort, especially if you manage a large number of clusters.

Sveltos also has an event-driven framework that allows you to deploy add-ons and applications in an orderly manner, or to deploy add-ons in response to certain events.

But that's not all! Sveltos not only helps you scale the number of clusters you can manage, but it also provides visibility into exactly which add-ons are installed on each cluster. So you can stay on top of your cluster management game and never miss a beat.

## Add-on Distribution

* Deploy [add-ons](addons.md) across multiple clusters
* Support for Helm charts, Kustomize, YAML, [Carvel ytt](ytt_extension.md) and [Jsonnet](jsonnet_extension.md)
* [Deploy Kubernetes Resources in a Controlled and Orderly Manner](https://projectsveltos.github.io/sveltos/manifest_order/)
* Configurable deployment strategies
* Automatic rollbacks

## Templates

* Create [templates](template.md) to express add-ons
* Use templates to instantiate add-ons from management cluster values

## Addon Compliances

* Define custom [add-on compliances](addon_compliance.md)
* Enforce compliances when deploying add-ons

## Event Driven Framework

* Deploy add-ons in response to [events](addon_event_deployment.md)
* Define events in Lua scripts
* Configure framework for [cross-cluster configuration](https://projectsveltos.github.io/sveltos/addon_event_deployment/#cross-clusters)

## Other Features

* [Centralised Resource Display for Multiple Kubernetes Clusters](show_resources.md)
* [Configuration drift detection](configuration_drift.md)
* [Dry run](dryrun.md)
* [Notifications](notifications.md)
* Kubernetes [cluster classification](labels_management.md)
* [Multi-tenancy](multi-tenancy.md)
* [Techsupport](techsupport.md)
* [Snapshot and rollback](snapshot.md)

![Sveltos addons](assets/addons.png)

## Core Concepts

Sveltos is a set of Kubernetes custom resource definitions (CRDs) and controllers to deploy kubernetes add-ons across multiple Kubernetes clusters.

1. [ClusterProfile CRD](addons.md#deep-dive-clusterprofile-crd) is the CRD used to instruct Sveltos on which add-ons to deploy on a set of clusters;
2. [Sveltos manager](addons.md#sveltos-manager-controller-configuration) is a controller running in the management cluster. It watches for *ClusterProfile* instances and *cluster* instances (both CAPI Cluster and SveltosCluster). It orchestrates Kubernetes addon deployments: when a cluster is a match for a ClusterProfile instance, all add-ons listed in the ClusterProfile instance are deployed in the cluster;
3. [EventBasedAddOn CRD](https://raw.githubusercontent.com/projectsveltos/event-manager/main/api/v1alpha1/eventbasedaddon_types.go) is the CRD to instruct Sveltos to deploy add-ons and applications in response to events. [EventSource](https://raw.githubusercontent.com/projectsveltos/libsveltos/main/api/v1alpha1/eventsource_type.go) is the CRD used to define what an event is. Events can be defined using Lua script.
4. [Event manager](addon_event_deployment.md) is a controller running in the management cluster. With the help of the agent running in the managed clusters, it responds to events instructing Sveltos to deploy new set of add-ons and applications;
5. [Classifier CRD](labels_management.md#deep-dive-classifier-crd) is the CRD used to instructs Sveltos on how to classify a cluster;
6. [Classifier](labels_management.md#classifier-controller-configuration) is a controller running in the management cluster. Its counterpart, *Classifier Agent* is a controller running in each managed cluster. Classifier distributes Classifier CRD instances to any managed cluster. Classifier Agent watches for cluster runtime state (kubernetes version and/or resources deployed) and Classifier CRD instances. It reports back to management cluster whether a managed cluster is a match or not for each Classifier instance;
7. [Drift detection manager](configuration_drift.md#configuration-drift) is a controller running in each managed cluster. It watches for Kubernetes resources deployed by ClusterProfiles set in SyncModeContinuousWithDriftDetection mode. Anytime it detects a possible configuration drift, it informs management cluster so that a re-sync happens and the cluster state is brought back to the desidered state expressed in the management cluster;
8. [ClusterHealthCheck](notifications.md#clusterhealthcheck) is the CRD used to configure Sveltos to send notifications when certain conditions happen;
9. [Shard controller](sharding.md) is a controller running in the management cluster. It watches for managed cluster annotations. When it detects a new cluster shard, the shard controller automatically deploys a new set of Projectsveltos controllers to manage that shard.
10. [RoleRequest CRD](multi-tenancy.md#rolerequest-crd) is the CRD used to allow platform admin to grant permissions to tenant admins;
11. [Sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") is the Sveltos CLI; 
12. [Techsupport CRD](techsupport.md#techsupport-crd) is the CRD used to instruct Sveltos to collect tech support, both logs and resources, from managed clusetrs;
13. [Snapshot CRD](snapshot.md#snapshot-crd) is the CRD used to instruct Sveltos on collecting configuration snapshots;
14.  [SveltosCluster](register-cluster.md#register-cluster) is the CRD used to register a cluster with Sveltos (only non CAPI powered cluster needs to be manually registered with Sveltos);

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
