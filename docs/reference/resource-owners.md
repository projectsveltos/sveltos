---
title: Sveltos Resources and Controller Map
description: Mapping between Sveltos resources and the controllers that manage and create them
authors:
    - kahirokunn
---

# Resource and Controller Mapping

The following table maps Sveltos resources to their managing controllers and shows where resources are located in different deployment modes (Local vs Centralized Agent Mode). Use this as a reference for operational design, troubleshooting, and understanding controller responsibilities in your Sveltos deployment.

|              Resource              |    Managing Controller    |      Creating by       | Resource Location (Local Agent Mode) | Resource Location (Centralized Agent Mode) |                                                              Annotation                                                              |
| ---------------------------------- | ------------------------- | ---------------------- | ------------------------------------ | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| AccessRequests                     | Access Manager            | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClassifierReports                  | Classifier Manager        | Sveltos Agent          | Managed Cluster                      | Management Cluster                         |                                                                                                                                      |
| Classifiers                        | Classifier Manager        | User / Install script  | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClusterConfigurations              | Unknown                   | Unknown                | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClusterHealthChecks                | HealthCheck Manager       | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClusterProfiles / Profiles         | Add-on Controller         | Event Manager / User   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClusterReports                     | Unknown                   | Unknown                | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClusterSets / Sets                 | Add-on Controller         | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ClusterSummaries                   | Add-on Controller         | Add-on Controller      | Management Cluster                   | Management Cluster                         | Useful when debugging ClusterProfiles                                                                                                |
| ConfigMap/Secret for EventTriggers | Event Manager             | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| DebuggingConfigurations            | All Controllers           | User / Install script  | Management Cluster                   | Management Cluster                         | Useful for adjusting controller log level when filing bug reports                                                                    |
| EventReports                       | Event Manager             | Sveltos Agent          | Managed Cluster                      | Management Cluster                         | Useful when debugging EventSources                                                                                                   |
| EventSources                       | Event Manager             | User                   | Managed Cluster                      | Management Cluster                         | Event Manager deploys EventSource instances to managed clusters                                                                      |
| EventTriggers                      | Event Manager             | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| HealthCheckReports                 | HealthCheck Manager       | Sveltos Agent          | Managed Cluster                      | Management Cluster                         |                                                                                                                                      |
| HealthChecks                       | HealthCheck Manager       | User                   | Managed Cluster                      | Management Cluster                         | HealthCheck Manager deploys HealthCheck instances to managed clusters                                                                |
| ReloaderReports                    | Add-on Controller         | Sveltos Agent          | Managed Cluster                      | Management Cluster                         |                                                                                                                                      |
| Reloaders                          | Add-on Controller         | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| ResourceSummaries                  | Add-on Controller         | Add-on Controller      | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| RoleRequests                       | Access Manager            | User                   | Management Cluster                   | Management Cluster                         |                                                                                                                                      |
| SveltosClusters                    | SveltosCluster Controller | User                   | Management Cluster                   | Management Cluster                         | Periodically connects to cluster and runs readiness and liveness checks                                                              |
| TechSupports                       | TechSupport Controller    | TechSupport Controller | Management Cluster                   | Management Cluster                         | Collects logs/events/resources from managed cluster and management cluster                                                           |
| Sveltos Agent (Deployment)         | Not Applicable            | Classifier Manager     | Managed Cluster                      | Management Cluster                         | Ensure one agent per cluster. If no agent is present, EventReports are not generated; recreate the Classifier to redeploy the agent. |

## Notes

- **Managing Controller**: Controller that monitors the resource state and makes adjustments as needed
- **Creating Controller**: Entity (controller or user) that initially creates the resource
- **Resource Location (Local Agent Mode)**: Where the resource is located when using Local Agent Mode (Mode 1) - agents deployed in managed clusters
- **Resource Location (Centralized Agent Mode)**: Where the resource is located when using Centralized Agent Mode (Mode 2) - agents centralized in management cluster
- **User**: Resources created manually by users
- **Unknown**: Items where a clear relationship has not yet been established
- **All Controllers**: Resources managed collaboratively by all controllers

## Controller Overview

Based on the Sveltos architecture, here are the main controllers and their responsibilities:

**Deployment Modes:**

- **Local Agent Mode (Mode 1)**: Sveltos agents (sveltos-agent and drift-detection-manager) are deployed in each managed cluster
- **Centralized Agent Mode (Mode 2)**: Sveltos agents are created per managed cluster in the management cluster, leaving no footprint on managed clusters

**Controllers:**

- **SveltosCluster Controller**: Manages SveltosCluster instances, periodically connects to clusters and runs readiness/liveness checks
- **Add-on Controller**: Manages ClusterProfile/Profile instances, creates ClusterSummary for matching clusters and deploys resources
- **Classifier Manager**: Deploys Classifier instances to managed clusters and sveltos-agent deployment, processes ClassifierReports to update cluster labels
- **Event Manager**: Manages EventTrigger instances, deploys EventSource instances to managed clusters and processes EventReports to create new ClusterProfiles
- **HealthCheck Manager**: Manages ClusterHealthChecks, deploys HealthCheck instances to managed clusters and processes HealthReports for notifications
- **TechSupport Controller**: Manages TechSupport instances, collects logs/events/resources from clusters and delivers tech support messages
- **Shard Controller**: Manages deployment and undeployment of Sveltos instances when clusters are marked as belonging to different shards

## Related Information

For more details on Sveltos architecture and each controller, please refer to the following documents:

- [Installing Sveltos](../getting_started/install/install.md)
- [Cluster Registration](../register/register-cluster.md)
- [Add-on Distribution](../addons/addons.md)
