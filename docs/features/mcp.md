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

The __Sveltos Management Cluster Protocol__ (MCP) Server is a management tool that connects AI assistants and chatbots to the Sveltos management cluster. It provides a **structured**, **programmatic** interface that allows AI agents to interact with Sveltos using natural language. This enables powerful features such as automated troubleshooting, real-time cluster analysis, and streamlined operational tasks across all the clusters Sveltos manages.

## How does it work?

The Sveltos MCP Server acts as a communication layer between AI agents and the Sveltos-managed infrastructure. Instead of an AI directly executing _kubectl_ commands on individual clusters, it sends requests to the MCP Server using the [Management Cluster Protocol (MCP)](https://modelcontextprotocol.io/docs/getting-started/intro). The server then translates these high-level requests into specific Sveltos tool calls.

The described process is not a simple command translation; it involves performing comprehensive checks on cluster statuses, the state of the Sveltos deployments, and the state of the Sveltos Custom Resources. Additionally, the server correlates the state of different resources that are tied to each other, providing a holistic view of the system's health. By consolidating these checks, the MCP Server provides a **single**, **unified** result to the AI, which can then present the findings to a user in a clear, conversational format.

This abstraction allows AI to perform complex operations, such as diagnosing deployment failures or comparing cluster configurations, with a single, high-level instruction, making Sveltos a powerful tool for automated, multi-cluster management.

## Key Capabilities

The Sveltos MCP Server empowers AI with the ability to:

- **Analyze Cluster State**: The AI can read the operational status of all Sveltos-managed clusters, including the health of Sveltos agents and the state of deployed resources. This provides a single source of truth for your entire fleet.

- **Automate Troubleshooting**: When a user reports an issue, the AI can use the MCP Server's tools to perform diagnostic checks automatically. For example, it can call the analyze_profile_deployment tool to investigate a deployment failure, identify the specific error, and provide a resolution plan.

- **Ensure Configuration Consistency**: The compare_managed_clusters tool allows AI to proactively monitor for configuration drift between clusters. It can quickly identify what's different and alert operators to potential compliance issues or misconfigurations.

- **Streamline Operations**: The server's tools enable AI to handle routine operational tasks, such as listing deployed resources on a cluster or verifying the Sveltos installation status. This frees up human operators to focus on more complex tasks.

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
