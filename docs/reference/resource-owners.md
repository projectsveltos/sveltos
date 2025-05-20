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
| ClusterProfiles / Profiles         | Add-on Controller       | Event Manager / User  |                                                                                                                                      |
| ClusterReports                     | Unknown                 | Unknown               |                                                                                                                                      |
| ConfigMap/Secret for EventTriggers | Event Manager           | User                  |                                                                                                                                      |
| ClusterSets / Sets                 | Add-on Controller       | User                  |                                                                                                                                      |
| ClusterSummaries                   | Add-on Controller       | Add-on Controller     | Useful when debugging ClusterProfiles                                                                                                |
| DebuggingConfigurations            | All Controllers         | User / Install script | Useful for adjusting controller log level when filing bug reports                                                                    |
| EventReports                       | Event Manager           | Sveltos Agent         | Useful when debugging EventSources                                                                                                   |
| EventSources                       | Event Manager           | User                  |                                                                                                                                      |
| EventTriggers                      | Event Manager           | User                  |                                                                                                                                      |
| ConfigMap/Secret for EventTriggers | Event Manager           | User                  |                                                                                                                                      |
| HealthCheckReports                 | HealthCheck Manager     | Sveltos Agent         |                                                                                                                                      |
| HealthChecks                       | HealthCheck Manager     | User                  |                                                                                                                                      |
| ReloaderReports                    | Add-on Controller       | Sveltos Agent         |                                                                                                                                      |
| Reloaders                          | Add-on Controller       | User                  |                                                                                                                                      |
| ResourceSummaries                  | Add-on Controller       | Unknown               |                                                                                                                                      |
| RoleRequests                       | Access Manager          | User                  |                                                                                                                                      |
| SveltosClusters                    | SveltosCluster Manager  | User                  |                                                                                                                                      |
| TechSupports                       | TechSupports Controller | Unknown               |                                                                                                                                      |
| Sveltos Agent (Deployment)         | Not Applicable          | Classifier Controller | Ensure one agent per cluster. If no agent is present, EventReports are not generated; recreate the Classifier to redeploy the agent. |

## Notes

- **Managing Controller**: Controller that monitors the resource state and makes adjustments as needed
- **Creating Controller**: Entity (controller or user) that initially creates the resource
- **User**: Resources created manually by users
- **Unknown**: Items where a clear relationship has not yet been established
- **All Controllers**: Resources managed collaboratively by all controllers

## Related Information

For more details on Sveltos architecture and each controller, please refer to the following documents:

- [Installing Sveltos](../getting_started/install/install.md)
- [Cluster Registration](../register/register-cluster.md)
- [Add-on Distribution](../addons/addons.md)
