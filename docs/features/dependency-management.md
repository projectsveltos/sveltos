---
title: Dependency Management
description: Discover how you can automatically manage declarative dependencies in your Sveltos resources with Renovate. Learn how to use the Sveltos manager to update dependencies in Helm-Charts for Sveltos resources.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - renovate
    - dependencies
    - dependency
authors:
    - Oliver Baehler
---

## Dependency Management

_Dependency Management_ is a crucial aspect of maintaining a healthy and secure Kubernetes environment. It ensures that all resources and configurations are up-to-date. In the context of Sveltos, dependency management is particularly important when using Helm-Charts to deploy resources.

Renovate is a tool that helps you automate dependency management in your Sveltos resources. It uses the Sveltos manager to update dependencies in Helm-Charts for Sveltos resources.

## Prerequisites

Before you can use Renovate to manage dependencies in your Sveltos resources, you need to have Renovate already configured for your Git-Repository. If you haven't set up Renovate yet, follow the [Renovate Getting Started Guide](https://docs.renovatebot.com/getting-started/use-cases/). The following documentation shows you how to configure Renovate for Sveltos resources for a public Github-Repository.

You can manage your Github organisations/repositories via [https://developer.mend.io](https://developer.mend.io).

## Configure Renovate

For [Github repositories](https://docs.renovatebot.com/modules/platform/github/) you can use the [Renovate Github App](https://github.com/apps/renovate). You need to authroize the Renovate Github App for your repository/organisation, where you would like to use it. Renovate will then automatically create a configuration file in your repository.

## Sveltos Manager

**Note:** The Sveltos manager was introduced with version [38.124.0](https://github.com/renovatebot/renovate/releases/tag/38.124.0) of Renovate. You must use this version or newer to use the [Sveltos manager](https://docs.renovatebot.com/modules/manager/sveltos/).

The Sveltos manager for renovate supports dependency management for [`helmCharts`](https://projectsveltos.github.io/sveltos/addons/helm_charts/) specs for all relevant sveltos resources. Refer to the upstream manager documentation for a detailed explanation.

A very simple configuration for the Sveltos manager looks like this:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended", ":dependencyDashboard"],
  "prHourlyLimit": 0,
  "prConcurrentLimit": 0,
  "branchConcurrentLimit": 0,
  "sveltos": {
      "fileMatch": ["^.*/*\\.yaml$"]
  }
}
```

As stated in the [manager documentation](https://docs.renovatebot.com/modules/manager/sveltos/), you must define a `fileMatch` pattern. This pattern tells Renovate which files to consider for dependency updates. In the example above, Renovate will only consider files named `profile.yaml` for dependency updates. This could also be any yaml file (`**.yaml`) or the convetions you are using in your repository.

With this config all the limits for branches and PRs are set to `0`, which means that Renovate will not be limited. This is required for large repositories with many dependencies. See more [Configurations](https://docs.renovatebot.com/configuration-options/) for Renovate.
