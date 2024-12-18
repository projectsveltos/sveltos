---
title: Telemetry
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## Telemetry

As an open-source project, Sveltos relies on user insights to guide its development. Telemetry data helps us:

- **Prioritize Features**: Identify the most commonly used features and focus on enhancing them.
- **Improve Performance**: Analyze usage patterns to optimize Sveltos' performance and resource utilization.
- **Make Informed Decisions**: Use data-driven insights to shape the future of Sveltos.

By choosing to participate in telemetry, users contribute to the ongoing improvement of Sveltos and help ensure it meets the needs of the community.

## What Data Do We Collect?

We collect minimal, anonymized data about Sveltos usage:

- **Version Information**: To track the distribution of different Sveltos versions.
- **Cluster Management Data**: To understand the scale and complexity of Sveltos deployments. This includes:
    1. Number of managed SveltosClusters
    1. Number of managed CAPI Clusters
    1. Number of ClusterProfiles/Profiles
    1. Number of ClusterSummaries

## How We Protect Your Privacy

- **Anonymized Data**: All data is collected and processed anonymously, without any personally identifiable information.
- **Secure Storage**: Telemetry data is stored securely and access is strictly controlled by the Sveltos maintainers.

## Opting-Out of Telemetry

To **opt-out** from the telemetry data, use the options below depending on the deployment method in place.

### Helm-Based Deployments

```
$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace --set telemetry.disabled=true
```

### Manual Deployments

Set the `--disable-telemetry=true` flag in the Sveltos addon-controller configuration.


### Requesting Data Erasure

You have the right to request the erasure of your data under certain circumstances. To initiate a data erasure request, please contact us at [support@projectsveltos.io](mailto:support@projectsveltos.io).
