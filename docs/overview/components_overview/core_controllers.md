---
title: Sveltos Controllers and Agents
description: Reference of the Sveltos controllers, installation jobs, and per-managed-cluster agents, including which components are mandatory and which are optional.
tags:
    - Kubernetes
    - Architecture
    - Controllers
authors:
    - Eleni Grosdouli
---

# Sveltos Controllers and Agents

Sveltos runs as a set of controllers in the management cluster, backed by installation jobs and per-cluster agents. Some controllers are mandatory and cannot be disabled, while others are optional and can be turned on or off depending on the features in use. This page outlines each component and its role. For more details about Sveltos' architecture, take a look at the [comprehensive documentation](../architecture/architecture.md), or for a quick reference, check out the [visual representation](https://github.com/projectsveltos/sveltos/blob/main/docs/assets/architecture-controllers.png).

## Core Controllers (Mandatory)

These controllers are **always** deployed and cannot be disabled.

| Controller | Purpose |
|---|---|
| **addon-controller** | Deploys Helm charts and Kubernetes resources. |
| **classifier-manager** | Deploys `sveltos-agent` and classifies clusters. |
| **event-manager** | Core of the event framework. Creates Profiles in response to events. |
| **sveltoscluster-manager** | Verifies `SveltosCluster` connectivity. Renews the token when necessary. |
| **healthcheck-manager** | Sends notifications when resources are deployed or fail to be deployed. |

## Optional Controllers

These controllers can be enabled or disabled depending on the features and use cases covered.

| Controller | Purpose |
|---|---|
| **access-manager** | Grants permissions to tenant admins inside managed clusters. |
| **shard-controller** | Enables horizontal scaling. |
| **techsupport** | Collects logs, events, and resources from mgmt and managed clusters. |
| **mcp-server** | MCP server. AI tools can inspect and manage the Sveltos fleet. |

## Installation Jobs

These run at **install** and **upgrade** time. They are not long-running controllers.

| Job | Purpose |
|---|---|
| **crd-manager** | Installs and upgrades all Sveltos CRDs before the controllers start. |
| **register-mgmt-cluster** | Registers the management cluster as a `SveltosCluster`. |

## Per Managed Cluster Agents

These agents handle work that requires direct access to a managed cluster.

| Agent | Purpose |
|---|---|
| **sveltos-agent** | Evaluates `Classifier`, `EventSource`, and `HealthCheck` against the resources in a cluster. |
| **drift-detection-manager** | Detects and reports configuration drifts. |
| **sveltos-applier** | In pull mode, fetches configuration from the management cluster. |