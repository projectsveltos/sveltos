---
title: Sveltos MCP Server - A Management Tool
description: The Sveltos Management Cluster Protocol (MCP) Server connects AI tools to your Sveltos-managed Kubernetes environment, enabling natural language analysis and automation for multi-cluster management.
tags:
    - MCP
    - Kubernetes
    - multi-cluster management
    - AI
    - automation
    - SRE
authors:
    - Gianluca Mardente
    - Eleni Grosdouli
---

!!!video
    To learn more about the Sveltos MCP Server, check out the [Video](../assets/dashboard_mcp.mov)! 😊

Sveltos has an integrated Model Context Protocol (MCP) server that connects AI assistants and chatbots to the Sveltos management cluster. It provides a **structured**, **programmatic** interface that allows AI agents to interact with Sveltos using natural language. This enables powerful features such as automated troubleshooting, real-time cluster analysis, and streamlined operational tasks across all the clusters Sveltos manages.

## How does it work?

The Sveltos MCP Server acts as a communication layer between AI agents and the Sveltos-managed infrastructure. Instead of an AI directly executing _kubectl_ commands on individual clusters, it sends requests to the MCP Server using the [MCP](https://modelcontextprotocol.io/docs/getting-started/intro). The server then translates these high-level requests into specific Sveltos tool calls.

The described process is not a simple command translation; it involves performing comprehensive checks on cluster statuses, the state of the Sveltos deployments, and the state of the Sveltos Custom Resources. Additionally, the server correlates the state of different resources that are tied to each other, providing a holistic view of the system's health. By consolidating these checks, the MCP Server provides a **single**, **unified** result to the AI, which can then present the findings to a user in a clear, conversational format.

This abstraction allows AI to perform complex operations, such as diagnosing deployment failures or comparing cluster configurations, with a single, high-level instruction, making Sveltos a powerful tool for automated, multi-cluster management.

## Key Capabilities

The Sveltos MCP Server empowers AI with the ability to:

- **Verify Installation Health**: The AI can instantly check the health of all Sveltos components on the management cluster and confirm that agents are correctly deployed — either in each managed cluster or running centrally in the management cluster in agentless mode. This is the best starting point when something looks wrong.

- **Analyze Cluster State**: The AI can read the operational status of all Sveltos-managed clusters, including the health of Sveltos agents and the state of deployed resources. It can list every managed cluster, filter by label selector (e.g. `env=production`), and get a single source of truth for your entire fleet.

- **Inspect Deployed Resources**: The AI can list all Kubernetes resources and Helm charts that Sveltos has successfully deployed on a given cluster, or instantly surface all deployment failures without having to inspect individual profiles one by one.

- **Automate Troubleshooting**: When a user reports an issue, the AI can use the MCP Server's tools to perform diagnostic checks automatically. For example, it can call the `analyze_profile_deployment` tool to investigate a deployment failure, identify the specific error, and provide a resolution plan. It can also list every ClusterProfile and Profile targeting a cluster with per-feature status (Helm, Resources, Kustomize) and pending dependencies.

- **Deep-Dive into Helm and Kustomize**: The AI can retrieve detailed information about a specific Helm release — combining Sveltos metadata with the actual Helm state from the workload cluster (deployed, failed, pending-upgrade, user values) — or verify that every Flux source (GitRepository, OCIRepository, Bucket) and plain source (ConfigMap, Secret) referenced by Kustomize profiles exists and is ready.

- **Trace Profile Dependencies**: The AI can walk the full `DependsOn` chain of a profile on a cluster and identify the root-cause node when a profile is stalled because a dependency is not yet provisioned.

- **Ensure Configuration Consistency**: The `compare_managed_clusters` tool allows AI to proactively monitor for configuration drift between clusters. It can quickly identify what is common, different, or unique across two clusters and alert operators to potential compliance issues or misconfigurations.

- **Streamline Operations**: The server's tools enable AI to handle routine operational tasks, such as listing profiles whose updates are currently queued (and whether the hold is due to a suspended cluster or a `MaxUpdate` throttle), or previewing the changes that DryRun-mode profiles would apply before committing to live deployment. This frees up human operators to focus on more complex tasks.

- **Trace Event-Driven Deployments**: The AI can follow an event-driven deployment end-to-end — from EventSource detection on the managed cluster, through EventTrigger evaluation, to the creation and deployment of the resulting dynamic ClusterProfile — and identify exactly where the chain breaks. It can also list all ClusterProfiles dynamically created by EventTriggers and map each back to its originating event.

- **Monitor Health Checks**: The AI can trace the full health-check pipeline for a cluster: validating that ClusterHealthCheck selectors match, confirming HealthCheck resource distribution, inspecting HealthCheckReports for resource-level results (Healthy, Degraded, Progressing), and reporting notification delivery status.

- **Manage Progressive Delivery**: The AI can list all ClusterPromotion pipelines with their current stage and whether any pipeline is blocked waiting for manual approval. It can also provide a detailed per-stage breakdown of a single pipeline — selector, trigger type, approval state, timing configuration, and runtime status — so it can explain exactly what is blocking a promotion.

## Integrated Dashboard Functionality

The [Sveltos dashboard](../getting_started/optional/dashboard.md) is designed to enhance users' troubleshooting experience by integrating a built-in Sveltos MCP client. The client connects directly to the Sveltos MCP server, providing powerful diagnostic capabilities right from the user interface.

The integrated client can:

- **Debug Sveltos Installation**: Instantly verify the health of the Sveltos installation on the **management** cluster. The client talks to the server, which runs comprehensive checks to ensure all Sveltos components are running correctly. It also verifies and checks the status of the Sveltos agents deployed across all the managed clusters. This ensures that every cluster is properly configured and communicating with the management cluster.

- **Diagnose Deployment Issues**: The dashboard can be used to pinpoint deployment problems on any Sveltos **managed** cluster. The MCP client sends a request to the server, which analyzes the state of Sveltos' resources and deployments, and returns a detailed report on any failures or inconsistencies.

[🎥 Dashboard MCP Video](../assets/dashboard_mcp.mov)

The seamless integration transforms the dashboard from a simple monitoring tool into a **proactive**, **powerful** debugging console, leveraging the full capabilities of the Sveltos MCP server to simplify multi-cluster management.

!!!note
    You can test the **Sveltos MCP Server** directly from the Sveltos dashboard to verify your Sveltos installation and diagnose failures on a given cluster. If you want to integrate the Sveltos MCP Server with your AI Site Reliability Engineering (SRE) tools, contact us at `support@projectsveltos.io`  to discuss licensing options tailored to your specific needs.

## Kubernetes Deployment Details

The Sveltos MCP Server is deployed in the _projectsveltos_ namespace.

- Deployment: _mcp-server_
- Service: _mcp-server_

The service type is _ClusterIP_, which means it is only accessible from within the cluster. If you need to expose the Sveltos MCP Server to external clients, you'll need to change the service type from ClusterIP to a different type, such as LoadBalancer or NodePort.
