---
title: Sveltos Resources and Controller Map
description: Mapping between Sveltos resources and the controllers that manage and create them
---

# Resource and Controller Mapping

The following table shows the main resources handled by Sveltos and the controllers (or entities) that "manage" or "create" them. Use this as a reference for operational design role assignments and troubleshooting.

|              Resource              |   Managing Controller   |      Creating by      |                                                              Annotation                                                              |
| ---------------------------------- | ----------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| AccessRequests                     | Access Manager          | User                  |                                                                                                                                      |
| ClassifierReports                  | Classifier Manager      | Sveltos Agent         |                                                                                                                                      |
| Classifiers                        | Classifier Manager      | User / Install script |                                                                                                                                      |
| ClusterConfigurations              | Unknown                 | Unknown               |                                                                                                                                      |
| ClusterHealthChecks                | HealthCheck Manager     | User                  |                                                                                                                                      |
| ClusterProfiles / Profiles         | Add-on Controller        | Event Manager / User  |                                                                                                                                      |
| ClusterReports                     | Unknown                 | Unknown               |                                                                                                                                      |
| ClusterSets / Sets                 | Add-on Controller        | User                  |                                                                                                                                      |
| ClusterSummaries                   | Add-on Controller        | Add-on Controller      | Useful when debugging ClusterProfiles                                                                                                |
| ConfigMap/Secret for EventTriggers | Event Manager           | User                  |                                                                                                                                      |
| DebuggingConfigurations            | All Controllers         | User / Install script | Useful for adjusting controller log level when filing bug reports                                                                    |
| EventReports                       | Event Manager           | Sveltos Agent         | Useful when debugging EventSources                                                                                                   |
| EventSources                       | Event Manager           | User                  | Event Manager deploys EventSource instances to managed clusters                                                                      |
| EventTriggers                      | Event Manager           | User                  |                                                                                                                                      |
| HealthCheckReports                 | HealthCheck Manager     | Sveltos Agent         |                                                                                                                                      |
| HealthChecks                       | HealthCheck Manager     | User                  | HealthCheck Manager deploys HealthCheck instances to managed clusters                                                                |
| ReloaderReports                    | Add-on Controller        | Sveltos Agent         |                                                                                                                                      |
| Reloaders                          | Add-on Controller        | User                  |                                                                                                                                      |
| ResourceSummaries                  | Add-on Controller        | Add-on Controller      |                                                                                                                                      |
| RoleRequests                       | Access Manager          | User                  |                                                                                                                                      |
| SveltosClusters                    | SveltosCluster Controller | User                | Periodically connects to cluster and runs readiness and liveness checks                                                             |
| TechSupports                       | TechSupport Controller  | TechSupport Controller | Collects logs/events/resources from managed cluster and management cluster                                                          |
| Sveltos Agent (Deployment)         | Not Applicable          | Classifier Manager    | Ensure one agent per cluster. If no agent is present, EventReports are not generated; recreate the Classifier to redeploy the agent. |

## Notes

- **Managing Controller**: Controller that monitors the resource state and makes adjustments as needed
- **Creating Controller**: Entity (controller or user) that initially creates the resource
- **User**: Resources created manually by users
- **Unknown**: Items where a clear relationship has not yet been established
- **All Controllers**: Resources managed collaboratively by all controllers

## Controller Overview

Based on the Sveltos architecture, here are the main controllers and their responsibilities:

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
